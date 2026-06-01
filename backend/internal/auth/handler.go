package auth

import (
	"database/sql"
	"encoding/json"
	"fmt"
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
		usernameGen := "user_" + newUserID.String()[:8]

		// Create user record
		_, err = tx.ExecContext(ctx, `
			INSERT INTO users (id, username, auth_provider, status, level, created_at, updated_at)
			VALUES ($1, $2, 'guest', 'active', 1, now(), now())
		`, newUserID, usernameGen)
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to create user: " + err.Error()})
		}

		// Create user profile
		displayName := "Guest_" + newUserID.String()[:8]
		_, err = tx.ExecContext(ctx, `
			INSERT INTO user_profiles (user_id, display_name, country_code, country_name, timezone, language, created_at, updated_at)
			VALUES ($1, $2, $3, $4, $5, 'en', now(), now())
		`, newUserID, displayName, req.CountryCode, req.CountryName, req.Timezone)
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to create profile: " + err.Error()})
		}

		// Create wallet with 500 free starter coins as a welcome gift
		_, err = tx.ExecContext(ctx, `
			INSERT INTO wallets (user_id, coins, gems, free_pass, updated_at)
			VALUES ($1, 500, 0, 0, now())
		`, newUserID)
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to create wallet: " + err.Error()})
		}

		// Create streak record
		_, err = tx.ExecContext(ctx, `
			INSERT INTO user_streaks (user_id, current_streak, longest_streak, updated_at)
			VALUES ($1, 0, 0, now())
		`, newUserID)
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to create streak record: " + err.Error()})
		}

		// Create device record
		_, err = tx.ExecContext(ctx, `
			INSERT INTO user_devices (user_id, device_id, platform, os_version, app_version, fcm_token, country_code, country_name, ip_address, last_seen_at)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, now())
		`, newUserID, req.DeviceID, req.Platform, req.OSVersion, req.AppVersion, req.FCMToken, req.CountryCode, req.CountryName, c.RealIP())
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to register device: " + err.Error()})
		}

		// Log ledger transaction for starter coins
		_, err = tx.ExecContext(ctx, `
			INSERT INTO wallet_transactions (user_id, currency_type, amount, balance_after, reason, ref_type, ref_id, created_at)
			VALUES ($1, 'coins', 500, 500, 'starter_bonus', 'users', $1, now())
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

	// Fetch real user stats
	var durationSeconds int
	_ = h.DB.QueryRowContext(ctx, "SELECT COALESCE(SUM(duration_seconds), 0) FROM reading_sessions WHERE user_id = $1", userID).Scan(&durationSeconds)
	readingHours := float64(durationSeconds) / 3600.0

	var currentStreak int
	_ = h.DB.QueryRowContext(ctx, "SELECT COALESCE(current_streak, 0) FROM user_streaks WHERE user_id = $1", userID).Scan(&currentStreak)

	var unlockedEpisodes int
	_ = h.DB.QueryRowContext(ctx, "SELECT COUNT(*) FROM episode_unlocks WHERE user_id = $1", userID).Scan(&unlockedEpisodes)

	return c.JSON(http.StatusOK, map[string]interface{}{
		"user":    user,
		"profile": profile,
		"wallet":  wallet,
		"stats": map[string]interface{}{
			"reading_hours":      readingHours,
			"active_streak":      currentStreak,
			"episodes_unlocked":  unlockedEpisodes,
		},
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

type UpdateUserRequest struct {
	DisplayName       *string                 `json:"display_name,omitempty"`
	Bio               *string                 `json:"bio,omitempty"`
	Email             *string                 `json:"email,omitempty"`
	Username          *string                 `json:"username,omitempty"`
	AvatarURL         *string                 `json:"avatar_url,omitempty"`
	Language          *string                 `json:"language,omitempty"`
	CountryCode       *string                 `json:"country_code,omitempty"`
	CountryName       *string                 `json:"country_name,omitempty"`
	ReadingPreference *map[string]interface{} `json:"reading_preference,omitempty"`
}

func (h *AuthHandler) UpdateCurrentUser(c echo.Context) error {
	userID, err := GetUserID(c)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
	}

	var req UpdateUserRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid request body"})
	}

	ctx := c.Request().Context()
	tx, err := h.DB.BeginTx(ctx, nil)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to start transaction"})
	}
	defer tx.Rollback()

	if req.Email != nil || req.Username != nil || req.AvatarURL != nil {
		query := "UPDATE users SET updated_at = now()"
		var args []interface{}
		idx := 1
		if req.Email != nil {
			query += fmt.Sprintf(", email = $%d", idx)
			args = append(args, *req.Email)
			idx++
		}
		if req.Username != nil {
			query += fmt.Sprintf(", username = $%d", idx)
			args = append(args, *req.Username)
			idx++
		}
		if req.AvatarURL != nil {
			query += fmt.Sprintf(", avatar_url = $%d", idx)
			args = append(args, *req.AvatarURL)
			idx++
		}
		query += fmt.Sprintf(" WHERE id = $%d", idx)
		args = append(args, userID)

		_, err = tx.ExecContext(ctx, query, args...)
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to update user details: " + err.Error()})
		}
	}

	if req.DisplayName != nil || req.Bio != nil || req.Language != nil || req.CountryCode != nil || req.CountryName != nil || req.ReadingPreference != nil {
		query := "UPDATE user_profiles SET updated_at = now()"
		var args []interface{}
		idx := 1
		if req.DisplayName != nil {
			query += fmt.Sprintf(", display_name = $%d", idx)
			args = append(args, *req.DisplayName)
			idx++
		}
		if req.Bio != nil {
			query += fmt.Sprintf(", bio = $%d", idx)
			args = append(args, *req.Bio)
			idx++
		}
		if req.Language != nil {
			query += fmt.Sprintf(", language = $%d", idx)
			args = append(args, *req.Language)
			idx++
		}
		if req.CountryCode != nil {
			query += fmt.Sprintf(", country_code = $%d", idx)
			args = append(args, *req.CountryCode)
			idx++
		}
		if req.CountryName != nil {
			query += fmt.Sprintf(", country_name = $%d", idx)
			args = append(args, *req.CountryName)
			idx++
		}
		if req.ReadingPreference != nil {
			prefBytes, err := json.Marshal(req.ReadingPreference)
			if err != nil {
				return c.JSON(http.StatusBadRequest, map[string]string{"error": "failed to serialize reading preferences"})
			}
			query += fmt.Sprintf(", reading_preference = $%d", idx)
			args = append(args, prefBytes)
			idx++
		}
		query += fmt.Sprintf(" WHERE user_id = $%d", idx)
		args = append(args, userID)

		_, err = tx.ExecContext(ctx, query, args...)
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to update profile details: " + err.Error()})
		}
	}

	if err := tx.Commit(); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to commit transaction"})
	}

	return h.GetCurrentUser(c)
}

type AdminUserListItem struct {
	ID          string  `json:"id"`
	Email       *string `json:"email"`
	Username    *string `json:"username"`
	AvatarURL   *string `json:"avatar_url"`
	Status      string  `json:"status"`
	Level       int     `json:"level"`
	DisplayName *string `json:"display_name"`
	Coins       int     `json:"coins"`
	Gems        int     `json:"gems"`
	FreePass    int     `json:"free_pass"`
	CreatedAt   string  `json:"created_at"`
}

func (h *AuthHandler) AdminListUsers(c echo.Context) error {
	ctx := c.Request().Context()
	rows, err := h.DB.QueryContext(ctx, `
		SELECT u.id, u.email, u.username, u.avatar_url, u.status, u.level, u.created_at,
		       p.display_name, w.coins, w.gems, w.free_pass
		FROM users u
		LEFT JOIN user_profiles p ON u.id = p.user_id
		LEFT JOIN wallets w ON u.id = w.user_id
		ORDER BY u.created_at DESC
	`)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to query users: " + err.Error()})
	}
	defer rows.Close()

	users := []AdminUserListItem{}
	for rows.Next() {
		var item AdminUserListItem
		var email, username, avatarURL, displayName *string
		var createdAt time.Time
		err := rows.Scan(
			&item.ID, &email, &username, &avatarURL, &item.Status, &item.Level, &createdAt,
			&displayName, &item.Coins, &item.Gems, &item.FreePass,
		)
		if err == nil {
			item.Email = email
			item.Username = username
			item.AvatarURL = avatarURL
			item.DisplayName = displayName
			item.CreatedAt = createdAt.Format(time.RFC3339)
			users = append(users, item)
		}
	}
	return c.JSON(http.StatusOK, users)
}

type AdminUpdateUserRequest struct {
	Status      *string `json:"status,omitempty"`
	Level       *int    `json:"level,omitempty"`
	GrantCoins  *int    `json:"grant_coins,omitempty"`
	DisplayName *string `json:"display_name,omitempty"`
}

func (h *AuthHandler) AdminUpdateUser(c echo.Context) error {
	targetUserID := c.Param("id")
	if _, err := uuid.Parse(targetUserID); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid user ID format"})
	}

	var req AdminUpdateUserRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid request body"})
	}

	ctx := c.Request().Context()
	tx, err := h.DB.BeginTx(ctx, nil)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to start transaction"})
	}
	defer tx.Rollback()

	if req.Status != nil || req.Level != nil {
		query := "UPDATE users SET updated_at = now()"
		var args []interface{}
		idx := 1
		if req.Status != nil {
			query += fmt.Sprintf(", status = $%d", idx)
			args = append(args, *req.Status)
			idx++
		}
		if req.Level != nil {
			query += fmt.Sprintf(", level = $%d", idx)
			args = append(args, *req.Level)
			idx++
		}
		query += fmt.Sprintf(" WHERE id = $%d", idx)
		args = append(args, targetUserID)

		_, err = tx.ExecContext(ctx, query, args...)
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to update user: " + err.Error()})
		}
	}

	if req.DisplayName != nil {
		_, err = tx.ExecContext(ctx, `
			UPDATE user_profiles SET display_name = $1, updated_at = now() WHERE user_id = $2
		`, *req.DisplayName, targetUserID)
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to update profile: " + err.Error()})
		}
	}

	if req.GrantCoins != nil && *req.GrantCoins != 0 {
		var currentCoins int
		err = tx.QueryRowContext(ctx, "SELECT coins FROM wallets WHERE user_id = $1 FOR UPDATE", targetUserID).Scan(&currentCoins)
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to fetch wallet: " + err.Error()})
		}
		newCoins := currentCoins + *req.GrantCoins
		_, err = tx.ExecContext(ctx, "UPDATE wallets SET coins = $1, updated_at = now() WHERE user_id = $2", newCoins, targetUserID)
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to update wallet balance: " + err.Error()})
		}

		// Log transaction
		_, err = tx.ExecContext(ctx, `
			INSERT INTO wallet_transactions (user_id, currency_type, amount, balance_after, reason, ref_type, ref_id)
			VALUES ($1, 'coins', $2, $3, 'admin_grant', 'users', $1)
		`, targetUserID, *req.GrantCoins, newCoins)
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to log transaction: " + err.Error()})
		}
	}

	if err := tx.Commit(); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to commit transaction"})
	}

	return c.JSON(http.StatusOK, map[string]string{"status": "success"})
}

type RegisterPushTokenRequest struct {
	Token    string  `json:"token"`
	Platform *string `json:"platform"`
}

func (h *AuthHandler) RegisterPushToken(c echo.Context) error {
	userID, err := GetUserID(c)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
	}

	var req RegisterPushTokenRequest
	if err := c.Bind(&req); err != nil || req.Token == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "token is required"})
	}

	platform := "ios"
	if req.Platform != nil {
		platform = *req.Platform
	}

	ctx := c.Request().Context()
	_, err = h.DB.ExecContext(ctx, `
		INSERT INTO push_tokens (user_id, token, platform, active, updated_at)
		VALUES ($1, $2, $3, true, now())
	`, userID, req.Token, platform)
	if err != nil {
		// Update if token constraint is violated
		_, err = h.DB.ExecContext(ctx, `
			UPDATE push_tokens
			SET token = $2, platform = $3, active = true, updated_at = now()
			WHERE user_id = $1
		`, userID, req.Token, platform)
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to register push token: " + err.Error()})
		}
	}

	return c.JSON(http.StatusOK, map[string]string{"status": "success"})
}

type NotificationItem struct {
	ID        string  `json:"id"`
	Title     string  `json:"title"`
	Body      string  `json:"body"`
	DeepLink  *string `json:"deep_link"`
	Status    string  `json:"status"`
	SentAt    string  `json:"sent_at"`
	OpenedAt  *string `json:"opened_at"`
}

func (h *AuthHandler) ListNotifications(c echo.Context) error {
	userID, err := GetUserID(c)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
	}

	ctx := c.Request().Context()
	rows, err := h.DB.QueryContext(ctx, `
		SELECT l.id, c.title, c.body, c.deep_link, l.status, l.sent_at, l.opened_at
		FROM push_logs l
		JOIN push_campaigns c ON l.campaign_id = c.id
		WHERE l.user_id = $1
		ORDER BY l.sent_at DESC
	`, userID)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to query notifications: " + err.Error()})
	}
	defer rows.Close()

	notifications := []NotificationItem{}
	for rows.Next() {
		var item NotificationItem
		var deepLink *string
		var sentAt time.Time
		var openedTime sql.NullTime
		err := rows.Scan(&item.ID, &item.Title, &item.Body, &deepLink, &item.Status, &sentAt, &openedTime)
		if err == nil {
			item.DeepLink = deepLink
			item.SentAt = sentAt.Format(time.RFC3339)
			if openedTime.Valid {
				tStr := openedTime.Time.Format(time.RFC3339)
				item.OpenedAt = &tStr
			}
			notifications = append(notifications, item)
		}
	}

	return c.JSON(http.StatusOK, notifications)
}

func (h *AuthHandler) OpenNotification(c echo.Context) error {
	userID, err := GetUserID(c)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
	}
	logID := c.Param("id")

	ctx := c.Request().Context()
	_, err = h.DB.ExecContext(ctx, `
		UPDATE push_logs
		SET status = 'opened', opened_at = now()
		WHERE id = $1 AND user_id = $2
	`, logID, userID)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to update notification status: " + err.Error()})
	}

	return c.JSON(http.StatusOK, map[string]string{"status": "success"})
}

type CreateCampaignRequest struct {
	Name     string  `json:"name"`
	Title    string  `json:"title"`
	Body     string  `json:"body"`
	DeepLink *string `json:"deep_link"`
}

type AdminCampaignListItem struct {
	ID        string  `json:"id"`
	Name      string  `json:"name"`
	Title     string  `json:"title"`
	Body      string  `json:"body"`
	DeepLink  *string `json:"deep_link"`
	Status    string  `json:"status"`
	CreatedAt string  `json:"created_at"`
}

func (h *AuthHandler) AdminListCampaigns(c echo.Context) error {
	ctx := c.Request().Context()
	rows, err := h.DB.QueryContext(ctx, `
		SELECT id, name, title, body, deep_link, status, created_at
		FROM push_campaigns
		ORDER BY created_at DESC
	`)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to query campaigns: " + err.Error()})
	}
	defer rows.Close()

	campaigns := []AdminCampaignListItem{}
	for rows.Next() {
		var item AdminCampaignListItem
		var deepLink *string
		var createdAt time.Time
		err := rows.Scan(&item.ID, &item.Name, &item.Title, &item.Body, &deepLink, &item.Status, &createdAt)
		if err == nil {
			item.DeepLink = deepLink
			item.CreatedAt = createdAt.Format(time.RFC3339)
			campaigns = append(campaigns, item)
		}
	}
	return c.JSON(http.StatusOK, campaigns)
}

func (h *AuthHandler) AdminCreateCampaign(c echo.Context) error {
	var req CreateCampaignRequest
	if err := c.Bind(&req); err != nil || req.Name == "" || req.Title == "" || req.Body == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "name, title, and body are required"})
	}

	ctx := c.Request().Context()
	tx, err := h.DB.BeginTx(ctx, nil)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to start transaction"})
	}
	defer tx.Rollback()

	campaignID := uuid.New()
	_, err = tx.ExecContext(ctx, `
		INSERT INTO push_campaigns (id, name, title, body, deep_link, status, created_at)
		VALUES ($1, $2, $3, $4, $5, 'sent', now())
	`, campaignID, req.Name, req.Title, req.Body, req.DeepLink)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to create campaign: " + err.Error()})
	}

	_, err = tx.ExecContext(ctx, `
		INSERT INTO push_logs (user_id, campaign_id, status, sent_at)
		SELECT id, $1, 'sent', now()
		FROM users
		WHERE status = 'active'
	`, campaignID)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to fan-out push logs: " + err.Error()})
	}

	if err := tx.Commit(); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to commit transaction"})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{"status": "success", "campaign_id": campaignID.String()})
}
