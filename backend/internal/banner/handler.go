package banner

import (
	"database/sql"
	"encoding/json"
	"net/http"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
	"moonlit-backend/internal/auth"
	"moonlit-backend/internal/models"
)

type BannerConfigHandler struct {
	DB *sql.DB
}

type adminFeatureFlagUpdateRequest struct {
	Enabled bool `json:"enabled"`
}

type adminCreateBannerRequest struct {
	Title       string  `json:"title"`
	Subtitle    *string `json:"subtitle"`
	ImageURL    string  `json:"image_url"`
	DeepLink    *string `json:"deep_link"`
	Placement   string  `json:"placement"`
	Priority    int     `json:"priority"`
	Active      bool    `json:"active"`
	ActionType  *string `json:"action_type"`
}

type adminUpdateBannerRequest struct {
	Title      *string `json:"title"`
	Subtitle   *string `json:"subtitle"`
	ImageURL   *string `json:"image_url"`
	DeepLink   *string `json:"deep_link"`
	Placement  *string `json:"placement"`
	Priority   *int    `json:"priority"`
	Active     *bool   `json:"active"`
	ActionType *string `json:"action_type"`
}

// GetBanners fetches active banners based on placement location
func (h *BannerConfigHandler) GetBanners(c echo.Context) error {
	placement := c.QueryParam("placement")
	if placement == "" {
		placement = "home_top"
	}

	ctx := c.Request().Context()
	rows, err := h.DB.QueryContext(ctx, `
		SELECT id, title, subtitle, image_url, deep_link, action_type, action_payload, placement, priority, active, start_at, end_at
		FROM banners
		WHERE active = true AND placement = $1 AND (start_at IS NULL OR start_at <= now()) AND (end_at IS NULL OR end_at >= now())
		ORDER BY priority DESC, created_at DESC
	`, placement)

	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to query banners"})
	}
	defer rows.Close()

	banners := []models.Banner{}
	for rows.Next() {
		var b models.Banner
		var sub, dl, at *string
		var payload []byte
		if err := rows.Scan(&b.ID, &b.Title, &sub, &b.ImageURL, &dl, &at, &payload, &b.Placement, &b.Priority, &b.Active, &b.StartAt, &b.EndAt); err == nil {
			b.Subtitle = sub
			b.DeepLink = dl
			b.ActionType = at
			b.ActionPayload = payload
			b.TargetCountryCodes = []string{}
			banners = append(banners, b)
		}
	}

	return c.JSON(http.StatusOK, banners)
}

// RecordImpression logs when a user views a banner
func (h *BannerConfigHandler) RecordImpression(c echo.Context) error {
	userID, err := auth.GetUserID(c)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
	}

	bannerID, err := uuid.Parse(c.Param("bannerId"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid banner ID"})
	}

	ctx := c.Request().Context()

	// Get banner placement for analytics
	var placement string
	_ = h.DB.QueryRowContext(ctx, "SELECT placement FROM banners WHERE id = $1", bannerID).Scan(&placement)

	_, err = h.DB.ExecContext(ctx, `
		INSERT INTO banner_impressions (banner_id, user_id, placement, shown_at)
		VALUES ($1, $2, $3, now())
	`, bannerID, userID, placement)

	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to log impression"})
	}

	// Log analytics event
	_, _ = h.DB.ExecContext(ctx, `
		INSERT INTO analytics_events (user_id, event_name, properties)
		VALUES ($1, 'banner_impression', json_build_object('banner_id', $2, 'placement', $3))
	`, userID, bannerID, placement)

	return c.JSON(http.StatusOK, map[string]string{"status": "recorded"})
}

// RecordClick logs when a user clicks a banner
func (h *BannerConfigHandler) RecordClick(c echo.Context) error {
	userID, err := auth.GetUserID(c)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
	}

	bannerID, err := uuid.Parse(c.Param("bannerId"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid banner ID"})
	}

	ctx := c.Request().Context()

	// Get banner placement for analytics
	var placement string
	_ = h.DB.QueryRowContext(ctx, "SELECT placement FROM banners WHERE id = $1", bannerID).Scan(&placement)

	_, err = h.DB.ExecContext(ctx, `
		INSERT INTO banner_clicks (banner_id, user_id, placement, clicked_at)
		VALUES ($1, $2, $3, now())
	`, bannerID, userID, placement)

	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to log click"})
	}

	// Log analytics event
	_, _ = h.DB.ExecContext(ctx, `
		INSERT INTO analytics_events (user_id, event_name, properties)
		VALUES ($1, 'banner_clicked', json_build_object('banner_id', $2, 'placement', $3))
	`, userID, bannerID, placement)

	return c.JSON(http.StatusOK, map[string]string{"status": "recorded"})
}

// GetAppConfig retrieves dynamic app configurations
func (h *BannerConfigHandler) GetAppConfig(c echo.Context) error {
	ctx := c.Request().Context()
	var value []byte

	err := h.DB.QueryRowContext(ctx, "SELECT value FROM app_configs WHERE key = 'system_config'").Scan(&value)
	if err == sql.ErrNoRows {
		// Return dummy config if empty
		dummy := map[string]interface{}{
			"free_episode_count":         3,
			"default_episode_coin_price": 20,
			"maintenance_mode":           false,
			"min_supported_version":      "1.0.0",
		}
		return c.JSON(http.StatusOK, dummy)
	} else if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to retrieve configs"})
	}

	var parsed map[string]interface{}
	_ = json.Unmarshal(value, &parsed)

	return c.JSON(http.StatusOK, parsed)
}

// GetFeatureFlags retrieves list of feature flags
func (h *BannerConfigHandler) GetFeatureFlags(c echo.Context) error {
	ctx := c.Request().Context()
	rows, err := h.DB.QueryContext(ctx, "SELECT key, enabled, rollout_percentage, target_country_codes, description FROM feature_flags")
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to query feature flags"})
	}
	defer rows.Close()

	flags := []models.FeatureFlag{}
	for rows.Next() {
		var f models.FeatureFlag
		var desc *string
		var countries []string
		if err := rows.Scan(&f.Key, &f.Enabled, &f.RolloutPercentage, &countries, &desc); err == nil {
			f.Description = desc
			f.TargetCountryCodes = countries
			flags = append(flags, f)
		}
	}

	return c.JSON(http.StatusOK, flags)
}

// AdminGetAppConfig retrieves configurable JSON blob by key (default: system_config)
func (h *BannerConfigHandler) AdminGetAppConfig(c echo.Context) error {
	ctx := c.Request().Context()
	key := c.QueryParam("key")
	if key == "" {
		key = "system_config"
	}

	var value []byte
	err := h.DB.QueryRowContext(ctx, "SELECT value FROM app_configs WHERE key = $1", key).Scan(&value)
	if err == sql.ErrNoRows {
		return c.JSON(http.StatusNotFound, map[string]string{"error": "config key not found"})
	}
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to retrieve configs"})
	}

	var parsed map[string]interface{}
	if err := json.Unmarshal(value, &parsed); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "invalid config payload"})
	}

	return c.JSON(http.StatusOK, parsed)
}

// AdminUpdateAppConfig upserts JSON config by key
func (h *BannerConfigHandler) AdminUpdateAppConfig(c echo.Context) error {
	ctx := c.Request().Context()
	key := c.Param("key")
	if key == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "missing config key"})
	}

	var payload map[string]interface{}
	if err := c.Bind(&payload); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid json body"})
	}

	valueBytes, err := json.Marshal(payload)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "failed to marshal payload"})
	}

	_, err = h.DB.ExecContext(ctx, `
		INSERT INTO app_configs (key, value, description)
		VALUES ($1, $2::jsonb, 'Updated from admin panel')
		ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now()
	`, key, string(valueBytes))
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to update config"})
	}

	return c.JSON(http.StatusOK, map[string]string{"status": "updated", "key": key})
}

// AdminGetFeatureFlags lists all feature flags
func (h *BannerConfigHandler) AdminGetFeatureFlags(c echo.Context) error {
	return h.GetFeatureFlags(c)
}

// AdminUpdateFeatureFlag updates enabled status by key
func (h *BannerConfigHandler) AdminUpdateFeatureFlag(c echo.Context) error {
	ctx := c.Request().Context()
	key := c.Param("key")
	if key == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "missing feature flag key"})
	}

	var req adminFeatureFlagUpdateRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid json body"})
	}

	res, err := h.DB.ExecContext(ctx, `
		UPDATE feature_flags
		SET enabled = $2, updated_at = now()
		WHERE key = $1
	`, key, req.Enabled)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to update feature flag"})
	}

	rows, _ := res.RowsAffected()
	if rows == 0 {
		return c.JSON(http.StatusNotFound, map[string]string{"error": "feature flag not found"})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{"status": "updated", "key": key, "enabled": req.Enabled})
}

// AdminListBanners returns all banners for CMS management
func (h *BannerConfigHandler) AdminListBanners(c echo.Context) error {
	ctx := c.Request().Context()

	rows, err := h.DB.QueryContext(ctx, `
		SELECT id, title, subtitle, image_url, deep_link, action_type, action_payload, placement, priority, active, start_at, end_at, created_at, updated_at
		FROM banners
		ORDER BY priority DESC, created_at DESC
	`)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to query banners"})
	}
	defer rows.Close()

	banners := []models.Banner{}
	for rows.Next() {
		var b models.Banner
		var sub, deep, actionType *string
		var payload []byte
		if scanErr := rows.Scan(&b.ID, &b.Title, &sub, &b.ImageURL, &deep, &actionType, &payload, &b.Placement, &b.Priority, &b.Active, &b.StartAt, &b.EndAt, &b.CreatedAt, &b.UpdatedAt); scanErr == nil {
			b.Subtitle = sub
			b.DeepLink = deep
			b.ActionType = actionType
			b.ActionPayload = payload
			b.TargetCountryCodes = []string{}
			banners = append(banners, b)
		}
	}

	return c.JSON(http.StatusOK, banners)
}

// AdminCreateBanner creates a banner placement
func (h *BannerConfigHandler) AdminCreateBanner(c echo.Context) error {
	ctx := c.Request().Context()
	adminIDAny := c.Get("admin_id")

	var req adminCreateBannerRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid json body"})
	}
	if req.Title == "" || req.ImageURL == "" || req.Placement == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "title, image_url and placement are required"})
	}

	var created models.Banner
	var adminUUID *uuid.UUID
	if idStr, ok := adminIDAny.(string); ok {
		if parsed, parseErr := uuid.Parse(idStr); parseErr == nil {
			adminUUID = &parsed
		}
	}

	err := h.DB.QueryRowContext(ctx, `
		INSERT INTO banners (title, subtitle, image_url, deep_link, action_type, placement, priority, active, created_by, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, now())
		RETURNING id, title, subtitle, image_url, deep_link, action_type, placement, priority, active, created_at, updated_at
	`, req.Title, req.Subtitle, req.ImageURL, req.DeepLink, req.ActionType, req.Placement, req.Priority, req.Active, adminUUID).Scan(
		&created.ID, &created.Title, &created.Subtitle, &created.ImageURL, &created.DeepLink, &created.ActionType,
		&created.Placement, &created.Priority, &created.Active, &created.CreatedAt, &created.UpdatedAt,
	)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to create banner"})
	}

	return c.JSON(http.StatusCreated, created)
}

// AdminUpdateBanner updates mutable banner fields
func (h *BannerConfigHandler) AdminUpdateBanner(c echo.Context) error {
	ctx := c.Request().Context()
	bannerID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid banner id"})
	}

	var req adminUpdateBannerRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid json body"})
	}

	res, err := h.DB.ExecContext(ctx, `
		UPDATE banners
		SET
			title = COALESCE($2, title),
			subtitle = COALESCE($3, subtitle),
			image_url = COALESCE($4, image_url),
			deep_link = COALESCE($5, deep_link),
			placement = COALESCE($6, placement),
			priority = COALESCE($7, priority),
			active = COALESCE($8, active),
			action_type = COALESCE($9, action_type),
			updated_at = now()
		WHERE id = $1
	`, bannerID, req.Title, req.Subtitle, req.ImageURL, req.DeepLink, req.Placement, req.Priority, req.Active, req.ActionType)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to update banner"})
	}

	rows, _ := res.RowsAffected()
	if rows == 0 {
		return c.JSON(http.StatusNotFound, map[string]string{"error": "banner not found"})
	}

	return c.JSON(http.StatusOK, map[string]string{"status": "updated"})
}

// AdminDeleteBanner deletes a banner
func (h *BannerConfigHandler) AdminDeleteBanner(c echo.Context) error {
	ctx := c.Request().Context()
	bannerID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid banner id"})
	}

	res, err := h.DB.ExecContext(ctx, `DELETE FROM banners WHERE id = $1`, bannerID)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to delete banner"})
	}

	rows, _ := res.RowsAffected()
	if rows == 0 {
		return c.JSON(http.StatusNotFound, map[string]string{"error": "banner not found"})
	}

	return c.JSON(http.StatusOK, map[string]string{"status": "deleted"})
}
