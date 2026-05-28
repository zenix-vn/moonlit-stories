package auth

import (
	"database/sql"
	"net/http"
	"time"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
	"golang.org/x/crypto/bcrypt"
	"moonlit-backend/internal/config"
	"moonlit-backend/internal/models"
)

type AuthHandler struct {
	DB     *sql.DB
	Config *config.Config
}

type GuestLoginRequest struct {
	DeviceID    string  `json:"device_id"`
	Platform    string  `json:"platform"`
	OSVersion   string  `json:"os_version"`
	AppVersion  string  `json:"app_version"`
	FCMToken    *string `json:"fcm_token,omitempty"`
	CountryCode string  `json:"country_code"`
	CountryName string  `json:"country_name"`
	Timezone    string  `json:"timezone"`
}

type AdminLoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

// GuestLogin handles guest login or signs up a new guest user
func (h *AuthHandler) GuestLogin(c echo.Context) error {
	var req GuestLoginRequest
	if err := c.Bind(&req); err != nil || req.DeviceID == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid request body, device_id is required"})
	}

	ctx := c.Request().Context()

	// 1. Check if user already exists for this device_id
	var user models.User
	var email, username, avatarURL, providerUserID *string
	var lastLoginAt *time.Time

	err := h.DB.QueryRowContext(ctx, `
		SELECT u.id, u.email, u.username, u.avatar_url, u.auth_provider, u.provider_user_id, u.status, u.level, u.created_at, u.updated_at, u.last_login_at
		FROM users u
		JOIN user_devices d ON u.id = d.user_id
		WHERE d.device_id = $1 AND u.auth_provider = 'guest'
		LIMIT 1
	`, req.DeviceID).Scan(
		&user.ID, &email, &username, &avatarURL, &user.AuthProvider, &providerUserID, &user.Status, &user.Level, &user.CreatedAt, &user.UpdatedAt, &lastLoginAt,
	)

	isNewUser := false

	if err == sql.ErrNoRows {
		// New User Flow
		isNewUser = true

		// Use transaction to ensure consistency
		tx, err := h.DB.BeginTx(ctx, nil)
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": "transaction start failed"})
		}
		defer tx.Rollback()

		// Generate User ID
		newUserID := uuid.New()

		// Create user record
		_, err = tx.ExecContext(ctx, `
			INSERT INTO users (id, auth_provider, status, level, created_at, updated_at)
			VALUES ($1, 'guest', 'active', 1, now(), now())
		`, newUserID)
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to create user"})
		}

		// Create user profile
		displayName := "Guest_" + newUserID.String()[:8]
		_, err = tx.ExecContext(ctx, `
			INSERT INTO user_profiles (user_id, display_name, country_code, country_name, timezone, language, created_at, updated_at)
			VALUES ($1, $2, $3, $4, $5, 'en', now(), now())
		`, newUserID, displayName, req.CountryCode, req.CountryName, req.Timezone)
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to create profile"})
		}

		// Create wallet with 100 free starter coins as a welcome gift
		_, err = tx.ExecContext(ctx, `
			INSERT INTO wallets (user_id, coins, gems, free_pass, updated_at)
			VALUES ($1, 100, 0, 0, now())
		`, newUserID)
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to create wallet"})
		}

		// Create streak record
		_, err = tx.ExecContext(ctx, `
			INSERT INTO user_streaks (user_id, current_streak, longest_streak, updated_at)
			VALUES ($1, 0, 0, now())
		`, newUserID)
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to create streak record"})
		}

		// Create device record
		_, err = tx.ExecContext(ctx, `
			INSERT INTO user_devices (user_id, device_id, platform, os_version, app_version, fcm_token, country_code, country_name, ip_address, last_seen_at)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, now())
		`, newUserID, req.DeviceID, req.Platform, req.OSVersion, req.AppVersion, req.FCMToken, req.CountryCode, req.CountryName, c.RealIP())
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to register device"})
		}

		// Log ledger transaction for starter coins
		_, err = tx.ExecContext(ctx, `
			INSERT INTO wallet_transactions (user_id, currency_type, amount, balance_after, reason, ref_type, ref_id, created_at)
			VALUES ($1, 'coins', 100, 100, 'starter_bonus', 'users', $1, now())
		`, newUserID)
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to log wallet transaction"})
		}

		err = tx.Commit()
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to commit transaction"})
		}

		// Fetch the created user
		err = h.DB.QueryRowContext(ctx, `
			SELECT id, email, username, avatar_url, auth_provider, provider_user_id, status, level, created_at, updated_at, last_login_at
			FROM users WHERE id = $1
		`, newUserID).Scan(
			&user.ID, &email, &username, &avatarURL, &user.AuthProvider, &providerUserID, &user.Status, &user.Level, &user.CreatedAt, &user.UpdatedAt, &lastLoginAt,
		)
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to fetch created user"})
		}
	} else if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "database query failed"})
	}

	// Update pointer fields
	user.Email = email
	user.Username = username
	user.AvatarURL = avatarURL
	user.ProviderID = providerUserID
	user.LastLoginAt = lastLoginAt

	// Check if user is banned
	if user.Status == "banned" {
		return c.JSON(http.StatusForbidden, map[string]string{"error": "user account is banned"})
	}

	// Log Login Event
	LogLoginEvent(ctx, h.DB, user.ID, req.DeviceID, req.Platform, req.AppVersion, c.RealIP(), req.CountryCode, req.CountryName, "", req.Timezone)

	// Fetch updated wallet
	var wallet models.Wallet
	_ = h.DB.QueryRowContext(ctx, `
		SELECT user_id, coins, gems, free_pass, updated_at FROM wallets WHERE user_id = $1
	`, user.ID).Scan(&wallet.UserID, &wallet.Coins, &wallet.Gems, &wallet.FreePass, &wallet.UpdatedAt)

	// Generate JWT
	token, err := GenerateUserToken(user.ID.String(), h.Config.JWTSecret)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "token generation failed"})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"token":       token,
		"user":        user,
		"wallet":      wallet,
		"is_new_user": isNewUser,
	})
}

// GetCurrentUser details
func (h *AuthHandler) GetCurrentUser(c echo.Context) error {
	userID, err := GetUserID(c)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
	}

	ctx := c.Request().Context()
	var user models.User
	var email, username, avatarURL, providerUserID *string
	var lastLoginAt *time.Time

	err = h.DB.QueryRowContext(ctx, `
		SELECT id, email, username, avatar_url, auth_provider, provider_user_id, status, level, created_at, updated_at, last_login_at
		FROM users WHERE id = $1
	`, userID).Scan(
		&user.ID, &email, &username, &avatarURL, &user.AuthProvider, &providerUserID, &user.Status, &user.Level, &user.CreatedAt, &user.UpdatedAt, &lastLoginAt,
	)
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{"error": "user not found"})
	}

	user.Email = email
	user.Username = username
	user.AvatarURL = avatarURL
	user.ProviderID = providerUserID
	user.LastLoginAt = lastLoginAt

	var profile models.UserProfile
	var displayName, bio, countryCode, countryName, timezone *string
	var readingPref []byte

	err = h.DB.QueryRowContext(ctx, `
		SELECT display_name, bio, country_code, country_name, timezone, language, reading_preference
		FROM user_profiles WHERE user_id = $1
	`, userID).Scan(
		&displayName, &bio, &countryCode, &countryName, &timezone, &profile.Language, &readingPref,
	)
	if err == nil {
		profile.UserID = userID
		profile.DisplayName = displayName
		profile.Bio = bio
		profile.CountryCode = countryCode
		profile.CountryName = countryName
		profile.Timezone = timezone
		profile.ReadingPreference = readingPref
	}

	var wallet models.Wallet
	_ = h.DB.QueryRowContext(ctx, `
		SELECT user_id, coins, gems, free_pass, updated_at FROM wallets WHERE user_id = $1
	`, userID).Scan(&wallet.UserID, &wallet.Coins, &wallet.Gems, &wallet.FreePass, &wallet.UpdatedAt)

	return c.JSON(http.StatusOK, map[string]interface{}{
		"user":    user,
		"profile": profile,
		"wallet":  wallet,
	})
}

// AdminLogin handles authentication for the dashboard CMS
func (h *AuthHandler) AdminLogin(c echo.Context) error {
	var req AdminLoginRequest
	if err := c.Bind(&req); err != nil || req.Email == "" || req.Password == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid request body, email and password required"})
	}

	ctx := c.Request().Context()
	var admin models.AdminUser
	var name *string

	err := h.DB.QueryRowContext(ctx, `
		SELECT id, email, name, password_hash, status, created_at, updated_at
		FROM admin_users WHERE email = $1 AND status = 'active'
	`, req.Email).Scan(&admin.ID, &admin.Email, &name, &admin.PasswordHash, &admin.Status, &admin.CreatedAt, &admin.UpdatedAt)

	if err == sql.ErrNoRows {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "invalid credentials"})
	} else if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "database query failed"})
	}

	admin.Name = name

	// Compare bcrypt password
	err = bcrypt.CompareHashAndPassword([]byte(admin.PasswordHash), []byte(req.Password))
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "invalid credentials"})
	}

	// Fetch roles
	rows, err := h.DB.QueryContext(ctx, `
		SELECT r.code
		FROM admin_roles r
		JOIN admin_user_roles ur ON r.id = ur.role_id
		WHERE ur.admin_user_id = $1
	`, admin.ID)
	if err == nil {
		defer rows.Close()
		var roles []string
		for rows.Next() {
			var roleCode string
			if err := rows.Scan(&roleCode); err == nil {
				roles = append(roles, roleCode)
			}
		}
		admin.Roles = roles
	}

	// Generate JWT for Admin
	token, err := GenerateAdminToken(admin.ID.String(), admin.Roles, h.Config.AdminJWTSecret)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "token generation failed"})
	}

	// Audit Log
	_, _ = h.DB.ExecContext(ctx, `
		INSERT INTO admin_audit_logs (admin_user_id, action, entity_type, entity_id, ip_address, created_at)
		VALUES ($1, 'login', 'admin_users', $1, $2, now())
	`, admin.ID, c.RealIP())

	return c.JSON(http.StatusOK, map[string]interface{}{
		"token": token,
		"admin": admin,
	})
}
