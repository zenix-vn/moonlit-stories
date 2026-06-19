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
func findProjectRoot() string {
	dir, err := os.Getwd()
	if err != nil {
		return "."
	}
	return filepath.Clean(dir)
}
