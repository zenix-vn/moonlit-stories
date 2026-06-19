package main

import (
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
	"moonlit-backend/internal/ai"
	"moonlit-backend/internal/analytics"
	"moonlit-backend/internal/auth"
	"moonlit-backend/internal/banner"
	"moonlit-backend/internal/config"
	"moonlit-backend/internal/content"
	"moonlit-backend/internal/database"
	"moonlit-backend/internal/reading"
	"moonlit-backend/internal/redis"
	"moonlit-backend/internal/rewards"
	"moonlit-backend/internal/subscription"
	"moonlit-backend/internal/wallet"
)

func main() {
	// 1. Load Configurations
	cfg, err := config.LoadConfig()
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	fmt.Printf("Starting Moonlit Stories Backend in %s environment...\n", cfg.Env)

	// 2. Initialize Database Connection
	db, err := database.InitDB(cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
	}
	defer db.Close()
	fmt.Println("Connected to PostgreSQL database successfully.")

	// Run Database Schema Auto-Migration/Setup if tables are missing
	if err := runAutoMigration(db); err != nil {
		log.Printf("Warning during database auto-migration: %v\n", err)
	}

	// Sync subscription products configuration dynamically at boot
	if err := syncSubscriptionProducts(db); err != nil {
		log.Printf("Warning: Failed to sync subscription products: %v\n", err)
	}

	// 3. Initialize Redis Connection (Warning only, don't crash if Redis is not running locally)
	rdb, err := redis.InitRedis(cfg.RedisURL)
	if err != nil {
		log.Printf("Warning: Redis failed to connect (%v). Caching and rate limits will be disabled.\n", err)
	} else {
		defer rdb.Close()
		fmt.Println("Connected to Redis successfully.")
	}

	// 4. Initialize Web Framework (Echo)
	e := echo.New()
	e.Static("/uploads", cfg.UploadDir)

	// Register Standard Middlewares
	e.Use(middleware.Logger())
	e.Use(middleware.Recover())
	e.Use(middleware.CORSWithConfig(middleware.CORSConfig{
		AllowOrigins: []string{"*"},
		AllowHeaders: []string{echo.HeaderOrigin, echo.HeaderContentType, echo.HeaderAccept, echo.HeaderAuthorization},
		AllowMethods: []string{http.MethodGet, http.MethodHead, http.MethodPut, http.MethodPatch, http.MethodPost, http.MethodDelete},
	}))

	// Define Handlers
	authHandler := &auth.AuthHandler{DB: db, Config: cfg}
	contentHandler := &content.ContentHandler{DB: db, UploadDir: cfg.UploadDir, PublicBaseURL: cfg.PublicBaseURL}
	readingHandler := &reading.ReadingHandler{DB: db}
	walletHandler := &wallet.WalletHandler{DB: db}
	rewardsHandler := &rewards.RewardsHandler{DB: db}
	bannerHandler := &banner.BannerConfigHandler{DB: db}
	subHandler := &subscription.SubscriptionHandler{DB: db}
	analyticsHandler := &analytics.AnalyticsHandler{DB: db}
	aiHandler := &ai.AIHandler{DB: db}

	// =========================================================================
	// PUBLIC AND WEBHOOK ROUTING (UNAUTHENTICATED)
	// =========================================================================
	e.GET("/", func(c echo.Context) error {
		return c.JSON(http.StatusOK, map[string]string{
			"app":     "Moonlit Stories Backend",
			"version": "1.0.0",
			"status":  "running",
		})
	})

	e.GET("/terms", serveTermsPage)
	e.GET("/privacy", servePrivacyPage)
	e.GET("/support", serveSupportPage)

	// Auth group
	e.POST("/v1/auth/guest", authHandler.GuestLogin)
	e.POST("/admin/auth/login", authHandler.AdminLogin)

	// RevenueCat Webhook (verified internally)
	e.POST("/v1/iap/webhook/revenuecat", subHandler.RevenueCatWebhook)

	// =========================================================================
	// MOBILE APP AUTHENTICATED ROUTING
	// =========================================================================
	v1 := e.Group("/v1")
	v1.Use(auth.UserAuthMiddleware(cfg.JWTSecret))

	// User info
	v1.GET("/me", authHandler.GetCurrentUser)
	v1.PATCH("/me", authHandler.UpdateCurrentUser)
	v1.DELETE("/me", authHandler.DeleteCurrentUser)
	v1.POST("/notifications/register", authHandler.RegisterPushToken)
	v1.GET("/notifications", authHandler.ListNotifications)
	v1.POST("/notifications/:id/open", authHandler.OpenNotification)

	// Content feed
	v1.GET("/home", contentHandler.GetHomeFeed)
	v1.GET("/discover", contentHandler.GetDiscoverFeed)
	v1.GET("/genres", contentHandler.GetGenres)
	v1.GET("/moods", contentHandler.GetMoods)
	v1.GET("/stories/:slug", contentHandler.GetStoryBySlug)

	// Episodes detail & verification
	v1.GET("/episodes/:episodeId", contentHandler.GetEpisodeDetail)
	v1.GET("/episodes/:episodeId/access", contentHandler.GetEpisodeAccess)
	v1.GET("/stories/:slug/episodes", contentHandler.GetStoryEpisodes)

	// Reading module
	v1.POST("/reading/session/start", readingHandler.StartSession)
	v1.POST("/reading/session/end", readingHandler.EndSession)
	v1.POST("/reading/progress", readingHandler.UpdateProgress)
	v1.GET("/library", readingHandler.GetLibrary)
	v1.POST("/library/save", readingHandler.AddToLibrary)
	v1.DELETE("/library/save/:storyId", readingHandler.RemoveFromLibrary)

	// Wallet module & unlocking
	v1.GET("/wallet", walletHandler.GetWallet)
	v1.GET("/wallet/transactions", walletHandler.GetTransactions)
	v1.POST("/episodes/:episodeId/unlock/coins", walletHandler.UnlockWithCoins)
	v1.POST("/episodes/:episodeId/unlock/free-pass", walletHandler.UnlockWithFreePass)
	v1.POST("/episodes/:episodeId/unlock/ad", walletHandler.UnlockWithAd)

	// Rewards & Streaks
	v1.GET("/rewards/dashboard", rewardsHandler.GetRewardsDashboard)
	v1.POST("/rewards/checkin", rewardsHandler.ClaimDailyCheckin)
	v1.GET("/tasks/daily", rewardsHandler.GetDailyTasks)
	v1.POST("/tasks/:taskId/claim", rewardsHandler.ClaimTaskReward)

	// Banners & config
	v1.GET("/banners", bannerHandler.GetBanners)
	v1.POST("/banners/:bannerId/impression", bannerHandler.RecordImpression)
	v1.POST("/banners/:bannerId/click", bannerHandler.RecordClick)
	v1.GET("/app/config", bannerHandler.GetAppConfig)
	v1.GET("/app/feature-flags", bannerHandler.GetFeatureFlags)

	// Monetization
	v1.GET("/products", subHandler.GetProducts)
	v1.POST("/iap/verify", subHandler.VerifyIAPPurchase)
	v1.GET("/me/subscription", subHandler.GetUserSubscription)

	// Analytics (optionally supports auth context but registers to event list)
	v1.POST("/events", analyticsHandler.LogEvent)

	// =========================================================================
	// ADMIN PANEL ROUTING
	// =========================================================================
	adminGroup := e.Group("/admin")
	adminGroup.Use(auth.AdminAuthMiddleware(cfg.AdminJWTSecret))

	adminGroup.GET("/me", func(c echo.Context) error {
		adminID := c.Get("admin_id")
		roles := c.Get("admin_roles")
		return c.JSON(http.StatusOK, map[string]interface{}{
			"id":    adminID,
			"roles": roles,
		})
	})

	// Dashboard analytics
	adminGroup.GET("/dashboard/overview", analyticsHandler.AdminDashboardOverview, auth.HasRoleCheck("super_admin", "editor"))
	adminGroup.GET("/dashboard/recent-activity", analyticsHandler.AdminDashboardRecentActivity, auth.HasRoleCheck("super_admin", "editor"))
	adminGroup.GET("/dashboard/country-activity", analyticsHandler.AdminDashboardCountryActivity, auth.HasRoleCheck("super_admin", "editor"))

	// User management
	adminGroup.GET("/users", authHandler.AdminListUsers, auth.HasRoleCheck("super_admin", "editor"))
	adminGroup.PATCH("/users/:id", authHandler.AdminUpdateUser, auth.HasRoleCheck("super_admin", "editor"))
	adminGroup.GET("/notifications/campaigns", authHandler.AdminListCampaigns, auth.HasRoleCheck("super_admin", "editor"))
	adminGroup.POST("/notifications/campaign", authHandler.AdminCreateCampaign, auth.HasRoleCheck("super_admin", "editor"))

	// Content CRUD
	adminGroup.GET("/stories", contentHandler.AdminListStories, auth.HasRoleCheck("editor", "writer"))
	adminGroup.POST("/stories", contentHandler.AdminCreateStory, auth.HasRoleCheck("editor"))
	adminGroup.GET("/stories/:id", contentHandler.AdminGetStoryByID)
	adminGroup.PATCH("/stories/:id", contentHandler.AdminUpdateStory, auth.HasRoleCheck("editor"))
	adminGroup.PATCH("/stories/:id/publish", contentHandler.AdminPublishStory, auth.HasRoleCheck("editor"))
	adminGroup.DELETE("/stories/:id", contentHandler.AdminDeleteStory, auth.HasRoleCheck("editor"))
	adminGroup.GET("/stories/:id/genres-moods", contentHandler.AdminGetStoryGenresMoods)
	adminGroup.PUT("/stories/:id/genres-moods", contentHandler.AdminUpdateStoryGenresMoods, auth.HasRoleCheck("editor"))
	adminGroup.GET("/stories/:storyId/episodes", contentHandler.AdminListEpisodes)
	adminGroup.POST("/stories/:storyId/episodes", contentHandler.AdminCreateEpisode, auth.HasRoleCheck("editor"))
	adminGroup.GET("/episodes/:id", contentHandler.AdminGetEpisodeByID)
	adminGroup.PATCH("/episodes/:id", contentHandler.AdminUpdateEpisode, auth.HasRoleCheck("editor"))
	adminGroup.DELETE("/episodes/:id", contentHandler.AdminDeleteEpisode, auth.HasRoleCheck("editor"))
	adminGroup.POST("/uploads/audio", contentHandler.AdminUploadAudio, auth.HasRoleCheck("editor"))
	adminGroup.GET("/banners", bannerHandler.AdminListBanners, auth.HasRoleCheck("editor", "super_admin"))
	adminGroup.POST("/banners", bannerHandler.AdminCreateBanner, auth.HasRoleCheck("editor", "super_admin"))
	adminGroup.PATCH("/banners/:id", bannerHandler.AdminUpdateBanner, auth.HasRoleCheck("editor", "super_admin"))
	adminGroup.DELETE("/banners/:id", bannerHandler.AdminDeleteBanner, auth.HasRoleCheck("editor", "super_admin"))

	// Admin app config & feature flags
	adminGroup.GET("/app-config", bannerHandler.AdminGetAppConfig, auth.HasRoleCheck("editor", "super_admin"))
	adminGroup.PATCH("/app-config/:key", bannerHandler.AdminUpdateAppConfig, auth.HasRoleCheck("editor", "super_admin"))
	adminGroup.GET("/feature-flags", bannerHandler.AdminGetFeatureFlags, auth.HasRoleCheck("editor", "super_admin"))
	adminGroup.PATCH("/feature-flags/:key", bannerHandler.AdminUpdateFeatureFlag, auth.HasRoleCheck("editor", "super_admin"))

	// AI story generation
	adminGroup.POST("/ai/stories/generate-outline", aiHandler.GenerateOutline, auth.HasRoleCheck("editor"))
	adminGroup.POST("/ai/stories/save-outline", aiHandler.SaveOutline, auth.HasRoleCheck("editor"))
	adminGroup.GET("/ai/stories/:id/context", aiHandler.GetAIContext, auth.HasRoleCheck("editor"))
	adminGroup.POST("/ai/stories/:id/generate-episode", aiHandler.GenerateNextEpisode, auth.HasRoleCheck("editor"))
	adminGroup.POST("/ai/stories/:id/regenerate-episode", aiHandler.RegenerateLastEpisode, auth.HasRoleCheck("editor"))

	// 5. Start HTTP Server
	portAddr := fmt.Sprintf(":%s", cfg.Port)
	fmt.Printf("Moonlit Stories API Server running on %s\n", portAddr)
	e.Logger.Fatal(e.Start(portAddr))
}

// runAutoMigration runs migrations/schema.sql on database startup if users table is missing
func runAutoMigration(db *sql.DB) error {
	var exists bool
	err := db.QueryRow(`
		SELECT EXISTS (
			SELECT FROM information_schema.tables 
			WHERE table_name = 'users'
		)
	`).Scan(&exists)

	if err != nil {
		return fmt.Errorf("failed to check database initialization: %v", err)
	}

	if exists {
		fmt.Println("Database tables are already initialized. Skipping auto-migration.")
		return nil
	}

	fmt.Println("Database users table not found. Performing auto-migration...")

	// Locate schema.sql relative to workspace or binary
	pathsToTry := []string{
		"migrations/schema.sql",
		"backend/migrations/schema.sql",
		"../migrations/schema.sql",
	}

	var schemaSQL []byte
	var fileReadErr error

	for _, path := range pathsToTry {
		schemaSQL, fileReadErr = os.ReadFile(path)
		if fileReadErr == nil {
			fmt.Printf("Loaded schema migrations script from: %s\n", path)
			break
		}
	}

	if fileReadErr != nil {
		// Fallback: search parents
		dir, _ := os.Getwd()
		log.Printf("Current working directory: %s\n", dir)
		return fmt.Errorf("could not load schema migrations file: %v", fileReadErr)
	}

	// Execute queries
	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// Execute block
	// Standard split by semicolon could fail for procedures but is fine for standard seed SQL queries
	queries := strings.Split(string(schemaSQL), ";\n")
	for _, q := range queries {
		q = strings.TrimSpace(q)
		if q == "" {
			continue
		}
		if _, err := tx.Exec(q); err != nil {
			return fmt.Errorf("failed to execute query: %s. Error: %v", q, err)
		}
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("failed to commit migrations: %v", err)
	}

	fmt.Println("Database schemas and seed data created successfully.")
	return nil
}

func syncSubscriptionProducts(db *sql.DB) error {
	query := `
		INSERT INTO products (code, name, type, platform, platform_product_id, price, coin_amount, bonus_coin_amount, active)
		VALUES
		  ('moonpass_weekly', 'MoonPass Weekly', 'subscription', 'all', 'com.moonlit.weekly_2_99usd', 2.99, NULL, NULL, true),
		  ('moonpass_monthly', 'MoonPass Monthly', 'subscription', 'all', 'com.moonlit.monthly_5_99usd', 5.99, NULL, NULL, true),
		  ('moonpass_quarterly', 'MoonPass Quarterly', 'subscription', 'all', 'com.moonlit.quarterly_14_99usd', 14.99, NULL, NULL, true),
		  ('moonpass_yearly', 'MoonPass Yearly', 'subscription', 'all', 'com.moonlit.yearly_29_99usd', 29.99, NULL, NULL, true)
		ON CONFLICT (code) DO UPDATE SET
		  name = EXCLUDED.name,
		  platform_product_id = EXCLUDED.platform_product_id,
		  price = EXCLUDED.price,
		  active = EXCLUDED.active;
	`
	_, err := db.Exec(query)
	if err != nil {
		return fmt.Errorf("failed to sync subscription products: %w", err)
	}
	fmt.Println("Subscription products synced successfully.")
	return nil
}

func findProjectRoot() string {
	dir, err := os.Getwd()
	if err != nil {
		return "."
	}
	return filepath.Clean(dir)
}

func serveTermsPage(c echo.Context) error {
	return c.HTML(http.StatusOK, termsHTML)
}

func servePrivacyPage(c echo.Context) error {
	return c.HTML(http.StatusOK, privacyHTML)
}

func serveSupportPage(c echo.Context) error {
	return c.HTML(http.StatusOK, supportHTML)
}

const termsHTML = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Terms of Use - Moonlit Stories</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <style>
        :root {
            --bg-color: #06040C;
            --card-bg: #120E22;
            --text-color: #FFFFFF;
            --subtext-color: #9E9CA5;
            --primary-color: #8A56E2;
            --accent-pink: #F35B8C;
            --border-color: rgba(255, 255, 255, 0.08);
        }
        body {
            background-color: var(--bg-color);
            color: var(--text-color);
            font-family: 'Inter', system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 0;
            display: flex;
            justify-content: center;
        }
        .container {
            max-width: 800px;
            width: 100%;
            padding: 40px 20px;
        }
        .header {
            text-align: center;
            margin-bottom: 40px;
            padding-bottom: 20px;
            border-bottom: 1px solid var(--border-color);
        }
        .logo {
            font-size: 28px;
            font-weight: 700;
            background: linear-gradient(135deg, var(--primary-color), var(--accent-pink));
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            margin-bottom: 8px;
            display: inline-block;
        }
        .subtitle {
            color: var(--subtext-color);
            font-size: 14px;
            margin: 0;
        }
        .card {
            background-color: var(--card-bg);
            border: 1px solid var(--border-color);
            border-radius: 16px;
            padding: 32px;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.2);
        }
        h1, h2, h3 {
            color: #FFFFFF;
            margin-top: 24px;
            margin-bottom: 12px;
        }
        h1 {
            font-size: 24px;
            border-bottom: 1px solid var(--border-color);
            padding-bottom: 8px;
            margin-top: 0;
        }
        h2 {
            font-size: 18px;
        }
        p, li {
            color: var(--subtext-color);
            font-size: 14px;
            margin-bottom: 16px;
        }
        ul, ol {
            padding-left: 20px;
            margin-bottom: 16px;
        }
        li {
            margin-bottom: 8px;
        }
        a {
            color: var(--primary-color);
            text-decoration: none;
            font-weight: 500;
            transition: color 0.2s;
        }
        a:hover {
            color: var(--accent-pink);
        }
        .footer {
            text-align: center;
            margin-top: 40px;
            font-size: 12px;
            color: var(--subtext-color);
            opacity: 0.7;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">Moonlit Stories</div>
            <p class="subtitle">Terms of Use</p>
        </div>
        <div class="card">
            <h1>Terms of Use</h1>
            <p><strong>Effective Date:</strong> June 19, 2026</p>
            <p>Welcome to Moonlit Stories. By accessing or using our mobile application (the "App") or our website, you agree to be bound by these Terms of Use ("Terms"). Please read them carefully.</p>
            
            <h2>1. Acceptance of Terms</h2>
            <p>By downloading, installing, or using Moonlit Stories, you represent that you are at least 13 years of age (or the minimum age of consent in your jurisdiction) and that you agree to abide by all the conditions set forth in these Terms. If you do not agree, do not use the App.</p>
            
            <h2>2. User Accounts</h2>
            <p>You may use the App as a guest user. We store guest account information locally on your device and identify it via a unique device identifier (Identifier for Vendor). You are responsible for maintaining the security of your device and account. Zenix is not liable for any loss of account progress, coins, or subscriptions resulting from device loss or formatting.</p>
            
            <h2>3. Virtual Items (Coins and Free Passes)</h2>
            <p>The App offers virtual currency ("Coins") and promotional "Free Passes" that can be used to unlock premium episodes of stories. Coins may be purchased through the App Store or earned via promotional events. Virtual items have no monetary value, cannot be redeemed for real currency, and are non-transferable. All sales of virtual items are final and non-refundable.</p>
            
            <h2>4. Auto-Renewable Subscriptions (MoonPass)</h2>
            <p>We offer a premium subscription plan called <strong>MoonPass</strong> which grants unlimited access to all story episodes and special features.</p>
            <ul>
                <li><strong>Billing:</strong> Subscriptions are billed through your Apple ID / App Store account at confirmation of purchase.</li>
                <li><strong>Auto-Renewal:</strong> Subscription automatically renews at the specified rate unless auto-renew is turned off or cancelled at least 24 hours before the end of the current billing period.</li>
                <li><strong>Cancellation:</strong> You can manage, change, or cancel your subscription at any time by going to your App Store account settings on your Apple device. No refunds are provided for partial subscription periods.</li>
            </ul>
            
            <h2>5. Intellectual Property</h2>
            <p>All materials, including stories, written text, character designs, graphics, audio tracks, and the underlying software/code are the exclusive intellectual property of Zenix or its licensors. You are granted a limited, personal, non-exclusive, non-transferable license to access and read stories for your own personal, non-commercial entertainment. You may not copy, record, republish, distribute, or modify any story content from the App without express written consent.</p>
            
            <h2>6. User Conduct</h2>
            <p>You agree not to modify, hack, reverse engineer, or attempt to exploit bugs in the App. You agree not to use automated scripts or bots to collect coins or generate false analytics events. Abuse of the service may result in temporary or permanent suspension of your account.</p>
            
            <h2>7. Disclaimer of Warranties & Limitation of Liability</h2>
            <p>The App is provided "as is" and "as available" without any warranties of any kind. Zenix does not guarantee that the App will be uninterrupted or error-free. To the maximum extent permitted by law, Zenix shall not be liable for any direct, indirect, incidental, or consequential damages arising from your use of the App.</p>
            
            <h2>8. Changes to Terms</h2>
            <p>We reserve the right to modify these Terms at any time. We will notify you of any material changes by updating the effective date of these Terms or within the App. Your continued use of the App after changes are posted constitutes acceptance of the new Terms.</p>
            
            <h2>9. Contact Us</h2>
            <p>If you have any questions or feedback regarding these Terms, please contact us at <a href="mailto:support@moonlit.vn">support@moonlit.vn</a>.</p>
        </div>
        <div class="footer">
            &copy; 2026 Zenix. All rights reserved.
        </div>
    </div>
</body>
</html>`

const privacyHTML = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Privacy Policy - Moonlit Stories</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <style>
        :root {
            --bg-color: #06040C;
            --card-bg: #120E22;
            --text-color: #FFFFFF;
            --subtext-color: #9E9CA5;
            --primary-color: #8A56E2;
            --accent-pink: #F35B8C;
            --border-color: rgba(255, 255, 255, 0.08);
        }
        body {
            background-color: var(--bg-color);
            color: var(--text-color);
            font-family: 'Inter', system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 0;
            display: flex;
            justify-content: center;
        }
        .container {
            max-width: 800px;
            width: 100%;
            padding: 40px 20px;
        }
        .header {
            text-align: center;
            margin-bottom: 40px;
            padding-bottom: 20px;
            border-bottom: 1px solid var(--border-color);
        }
        .logo {
            font-size: 28px;
            font-weight: 700;
            background: linear-gradient(135deg, var(--primary-color), var(--accent-pink));
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            margin-bottom: 8px;
            display: inline-block;
        }
        .subtitle {
            color: var(--subtext-color);
            font-size: 14px;
            margin: 0;
        }
        .card {
            background-color: var(--card-bg);
            border: 1px solid var(--border-color);
            border-radius: 16px;
            padding: 32px;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.2);
        }
        h1, h2, h3 {
            color: #FFFFFF;
            margin-top: 24px;
            margin-bottom: 12px;
        }
        h1 {
            font-size: 24px;
            border-bottom: 1px solid var(--border-color);
            padding-bottom: 8px;
            margin-top: 0;
        }
        h2 {
            font-size: 18px;
        }
        p, li {
            color: var(--subtext-color);
            font-size: 14px;
            margin-bottom: 16px;
        }
        ul, ol {
            padding-left: 20px;
            margin-bottom: 16px;
        }
        li {
            margin-bottom: 8px;
        }
        a {
            color: var(--primary-color);
            text-decoration: none;
            font-weight: 500;
            transition: color 0.2s;
        }
        a:hover {
            color: var(--accent-pink);
        }
        .footer {
            text-align: center;
            margin-top: 40px;
            font-size: 12px;
            color: var(--subtext-color);
            opacity: 0.7;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">Moonlit Stories</div>
            <p class="subtitle">Privacy Policy</p>
        </div>
        <div class="card">
            <h1>Privacy Policy</h1>
            <p><strong>Effective Date:</strong> June 19, 2026</p>
            <p>At Moonlit Stories, we value your privacy and are committed to protecting your personal data. This Privacy Policy describes how we collect, use, and share information when you use our mobile application (the "App") or website.</p>
            
            <h2>1. Information We Collect</h2>
            <p>We collect the following types of information to provide and improve our services:</p>
            <ul>
                <li><strong>Device Identifiers:</strong> We collect your device's Identifier for Vendor (IDFV) to create and identify guest accounts. If you give consent through the App Tracking Transparency (ATT) prompt, we collect your device's Identifier for Advertisers (IDFA).</li>
                <li><strong>Optional Profile Info:</strong> If you voluntarily add it to your profile, we collect your display name, email address, and biography.</li>
                <li><strong>Purchase and Billing History:</strong> We keep track of your subscription status (MoonPass) and virtual coin balance. All transactions are securely processed by Apple ID/App Store billing, and we do not store your credit card details.</li>
                <li><strong>Usage Behavior:</strong> We record reading progress, saved stories in your library, reading durations, and in-app event actions to perform analytics and optimize content delivery.</li>
            </ul>
            
            <h2>2. How We Use Your Information</h2>
            <p>We use the collected information for the following purposes:</p>
            <ul>
                <li>To enable guest accounts and preserve reading history, coins, and subscriptions.</li>
                <li>To process purchases and verify IAP receipts.</li>
                <li>To send remote push notifications (with your permission) regarding updates, reminders, and rewards.</li>
                <li>To perform analytics and monitor the health and performance of our servers.</li>
                <li>To serve advertisements through third-party services.</li>
            </ul>
            
            <h2>3. Advertising and App Tracking (Google AdMob)</h2>
            <p>We use Google AdMob to deliver advertisements within the App. If you grant tracking permission via the App Tracking Transparency prompt, AdMob may use your IDFA to serve personalized, relevant advertisements. If you decline, AdMob will still serve advertisements, but they will be non-personalized. You can manage or revoke tracking permissions at any time via iOS Settings -> Moonlit Stories -> App Tracking.</p>
            
            <h2>4. Data Sharing and Third Parties</h2>
            <p>We do not sell your personal data. We share data only with third-party service providers acting on our behalf (e.g. database hosting, analytics services, push notification services, and Google AdMob SDK) under strict confidentiality terms.</p>
            
            <h2>5. Data Retention & Account Deletion</h2>
            <p>We retain your data as long as your account is active. You can permanently delete your account and all associated data at any time by going to the App Settings and selecting "Delete Account". This action deletes your profile, reading history, saved books, and coin balances, and cannot be undone.</p>
            
            <h2>6. Security</h2>
            <p>We implement standard technical and organizational security measures to protect your data from unauthorized access, loss, or alteration. However, no internet transmission is 100% secure, and we cannot guarantee absolute security.</p>
            
            <h2>7. Children's Privacy</h2>
            <p>The App is not intended for children under the age of 13. We do not knowingly collect personal data from children. If you believe a child has provided us with personal data, please contact us immediately.</p>
            
            <h2>8. Changes to This Policy</h2>
            <p>We may update this Privacy Policy from time to time. We will notify you of changes by updating the effective date of the policy or within the App. Continued use of the App constitutes acceptance of the updated policy.</p>
            
            <h2>9. Contact Us</h2>
            <p>For questions or requests concerning your privacy, please contact us at <a href="mailto:support@moonlit.vn">support@moonlit.vn</a>.</p>
        </div>
        <div class="footer">
            &copy; 2026 Zenix. All rights reserved.
        </div>
    </div>
</body>
</html>`

const supportHTML = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Support & Help - Moonlit Stories</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <style>
        :root {
            --bg-color: #06040C;
            --card-bg: #120E22;
            --text-color: #FFFFFF;
            --subtext-color: #9E9CA5;
            --primary-color: #8A56E2;
            --accent-pink: #F35B8C;
            --border-color: rgba(255, 255, 255, 0.08);
        }
        body {
            background-color: var(--bg-color);
            color: var(--text-color);
            font-family: 'Inter', system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 0;
            display: flex;
            justify-content: center;
        }
        .container {
            max-width: 800px;
            width: 100%;
            padding: 40px 20px;
        }
        .header {
            text-align: center;
            margin-bottom: 40px;
            padding-bottom: 20px;
            border-bottom: 1px solid var(--border-color);
        }
        .logo {
            font-size: 28px;
            font-weight: 700;
            background: linear-gradient(135deg, var(--primary-color), var(--accent-pink));
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            margin-bottom: 8px;
            display: inline-block;
        }
        .subtitle {
            color: var(--subtext-color);
            font-size: 14px;
            margin: 0;
        }
        .card {
            background-color: var(--card-bg);
            border: 1px solid var(--border-color);
            border-radius: 16px;
            padding: 32px;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.2);
            margin-bottom: 24px;
        }
        h1, h2, h3 {
            color: #FFFFFF;
            margin-top: 24px;
            margin-bottom: 12px;
        }
        h1 {
            font-size: 24px;
            border-bottom: 1px solid var(--border-color);
            padding-bottom: 8px;
            margin-top: 0;
        }
        h2 {
            font-size: 18px;
            margin-top: 24px;
            border-bottom: 1px solid var(--border-color);
            padding-bottom: 6px;
        }
        .faq-item {
            margin-bottom: 20px;
        }
        .faq-question {
            font-weight: 600;
            color: #FFFFFF;
            font-size: 15px;
            margin-bottom: 6px;
        }
        .faq-answer {
            color: var(--subtext-color);
            font-size: 14px;
            margin: 0;
        }
        p, li {
            color: var(--subtext-color);
            font-size: 14px;
            margin-bottom: 16px;
        }
        ul {
            padding-left: 20px;
            margin-bottom: 16px;
        }
        li {
            margin-bottom: 8px;
        }
        a {
            color: var(--primary-color);
            text-decoration: none;
            font-weight: 500;
            transition: color 0.2s;
        }
        a:hover {
            color: var(--accent-pink);
        }
        .contact-box {
            background: linear-gradient(135deg, rgba(138, 86, 226, 0.1), rgba(243, 91, 140, 0.1));
            border: 1px solid rgba(138, 86, 226, 0.2);
            padding: 20px;
            border-radius: 12px;
            margin-top: 20px;
            text-align: center;
        }
        .contact-email {
            font-size: 18px;
            font-weight: 700;
            margin-top: 10px;
            display: inline-block;
        }
        .footer {
            text-align: center;
            margin-top: 40px;
            font-size: 12px;
            color: var(--subtext-color);
            opacity: 0.7;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">Moonlit Stories</div>
            <p class="subtitle">Support & Help Center</p>
        </div>
        
        <div class="card">
            <h1>Support & Help</h1>
            <p>Welcome to the Moonlit Stories Support Center. We are here to help you get the most out of your reading experience. If you are facing any issues with the application, have payment questions, or want to suggest improvements, please refer to the FAQs below or contact us directly.</p>
            
            <h2>Contact Us</h2>
            <p>For support requests, content guidelines feedback, copyright inquiries, or technical assistance, you can email our support team directly. We strive to reply to all inquiries within 24 to 48 hours.</p>
            
            <div class="contact-box">
                <span style="color: #FFFFFF; font-weight: 600; display: block;">Email Support Team</span>
                <a href="mailto:support@moonlit.vn" class="contact-email">support@moonlit.vn</a>
            </div>
        </div>

        <div class="card">
            <h1>Frequently Asked Questions (FAQ)</h1>
            
            <div class="faq-item">
                <div class="faq-question">1. How do I restore my MoonPass subscription or Coins?</div>
                <p class="faq-answer">If you reinstalled the app or changed devices, you can easily restore your purchases. Go to the <strong>Settings</strong> menu in the app, tap <strong>Restore Purchases</strong> under the Account section, and sign in with your Apple ID if prompted. Your balance and subscription will sync instantly.</p>
            </div>

            <div class="faq-item">
                <div class="faq-question">2. What is MoonPass and how does billing work?</div>
                <p class="faq-answer">MoonPass is an auto-renewable subscription that gives you unlimited access to all stories and chapters. It is billed to your App Store account at the end of each billing period (monthly or annually). You can manage or cancel your subscription at any time via your device's Apple ID Subscriptions settings page.</p>
            </div>

            <div class="faq-item">
                <div class="faq-question">3. How do I earn free coins?</div>
                <p class="faq-answer">You can earn free coins by checking in daily under the <strong>Rewards</strong> tab, or by completing daily tasks and milestones inside the app.</p>
            </div>

            <div class="faq-item">
                <div class="faq-question">4. How do I delete my guest account and data?</div>
                <p class="faq-answer">If you wish to delete your account and all associated reading history, coins, and settings, go to the <strong>Settings</strong> screen in the app, tap <strong>Delete Account</strong>, and confirm the prompt. This action is permanent and cannot be undone.</p>
            </div>

            <div class="faq-item">
                <div class="faq-question">5. Why is the App Tracking Transparency (ATT) prompt appearing?</div>
                <p class="faq-answer">We use Google AdMob to serve ads that help fund the free tier of the app. The tracking permission prompt lets us deliver advertisements that are more personalized and relevant to your interests. You can enable or disable this tracking preference at any time in your device settings under <strong>Settings &gt; Moonlit Stories &gt; App Tracking</strong>.</p>
            </div>
        </div>

        <div class="footer">
            &copy; 2026 Zenix. All rights reserved.
        </div>
    </div>
</body>
</html>`

