package analytics

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"time"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
)

type AnalyticsHandler struct {
	DB *sql.DB
}

type EventLogRequest struct {
	EventName   string          `json:"event_name"`
	Properties  json.RawMessage `json:"properties"`
	AnonymousID *string         `json:"anonymous_id,omitempty"`
	SessionID   *string         `json:"session_id,omitempty"`
	Platform    *string         `json:"platform,omitempty"`
	AppVersion  *string         `json:"app_version,omitempty"`
	CountryCode *string         `json:"country_code,omitempty"`
	CountryName *string         `json:"country_name,omitempty"`
}

// LogEvent ingests a client behavioral event
func (h *AnalyticsHandler) LogEvent(c echo.Context) error {
	var req EventLogRequest
	if err := c.Bind(&req); err != nil || req.EventName == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid event format, event_name is required"})
	}

	ctx := c.Request().Context()
	eventID := uuid.New()

	// Try to get authenticated user ID if present (optional)
	var userID *uuid.UUID
	if val := c.Get("user_id"); val != nil {
		if idStr, ok := val.(string); ok {
			if parsed, err := uuid.Parse(idStr); err == nil {
				userID = &parsed
			}
		}
	}

	_, err := h.DB.ExecContext(ctx, `
		INSERT INTO analytics_events (id, user_id, anonymous_id, session_id, event_name, properties, country_code, country_name, platform, app_version, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, now())
	`, eventID, userID, req.AnonymousID, req.SessionID, req.EventName, req.Properties, req.CountryCode, req.CountryName, req.Platform, req.AppVersion)

	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to record analytics event"})
	}

	// Dynamic task progress updating based on specific events!
	if userID != nil && req.EventName == "episode_completed" {
		// Log progress for daily task 'finish_1_ep' (daily reading task code: 'finish_1_ep')
		todayStr := timeNowStr()
		_, _ = h.DB.ExecContext(ctx, `
			INSERT INTO user_task_progress (user_id, task_id, task_date, progress, completed_at)
			VALUES ($1, '30000000-0000-0000-0000-000000000002', $2, 1, now())
			ON CONFLICT (user_id, task_id, task_date)
			DO UPDATE SET progress = user_task_progress.progress + 1,
			              completed_at = CASE WHEN user_task_progress.progress + 1 >= 1 THEN now() ELSE user_task_progress.completed_at END
		`, *userID, todayStr)
	}

	return c.JSON(http.StatusOK, map[string]string{"status": "logged", "event_id": eventID.String()})
}

// Helper to get date string
func timeNowStr() string {
	return time.Now().Format("2006-01-02")
}
