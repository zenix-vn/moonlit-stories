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

// GetBanners fetches active banners based on placement location
func (h *BannerConfigHandler) GetBanners(c echo.Context) error {
	placement := c.QueryParam("placement")
	if placement == "" {
		placement = "home_top"
	}

	ctx := c.Request().Context()
	rows, err := h.DB.QueryContext(ctx, `
		SELECT id, title, subtitle, image_url, deep_link, action_type, action_payload, placement, priority, active, start_at, end_at, target_country_codes
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
		var countries []string
		if err := rows.Scan(&b.ID, &b.Title, &sub, &b.ImageURL, &dl, &at, &payload, &b.Placement, &b.Priority, &b.Active, &b.StartAt, &b.EndAt, &countries); err == nil {
			b.Subtitle = sub
			b.DeepLink = dl
			b.ActionType = at
			b.ActionPayload = payload
			b.TargetCountryCodes = countries
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
