package reading

import (
	"database/sql"
	"net/http"
	"time"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
	"moonlit-backend/internal/auth"
)

type ReadingHandler struct {
	DB *sql.DB
}

type StartSessionRequest struct {
	StoryID     string `json:"story_id"`
	EpisodeID   string `json:"episode_id"`
	Platform    string `json:"platform"`
	DeviceID    string `json:"device_id"`
	CountryCode string `json:"country_code"`
	CountryName string `json:"country_name"`
}

type EndSessionRequest struct {
	SessionID       string  `json:"session_id"`
	DurationSeconds int     `json:"duration_seconds"`
	ProgressStart   float64 `json:"progress_start"`
	ProgressEnd     float64 `json:"progress_end"`
	Completed       bool    `json:"completed"`
}

type ProgressRequest struct {
	StoryID         string  `json:"story_id"`
	EpisodeID       string  `json:"episode_id"`
	ProgressPercent float64 `json:"progress_percent"`
	CurrentPosition int     `json:"current_position"`
}

type LibrarySaveRequest struct {
	StoryID string `json:"story_id"`
	Type    string `json:"type"` // 'saved', 'completed', 'downloaded', 'history'
}

// StartSession handles creating a new reading session
func (h *ReadingHandler) StartSession(c echo.Context) error {
	userID, err := auth.GetUserID(c)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
	}

	var req StartSessionRequest
	if err := c.Bind(&req); err != nil || req.StoryID == "" || req.EpisodeID == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid request body"})
	}

	storyID, err := uuid.Parse(req.StoryID)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid story ID"})
	}

	episodeID, err := uuid.Parse(req.EpisodeID)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid episode ID"})
	}

	ctx := c.Request().Context()
	sessionID := uuid.New()

	_, err = h.DB.ExecContext(ctx, `
		INSERT INTO reading_sessions (id, user_id, story_id, episode_id, country_code, country_name, device_id, platform, started_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, now())
	`, sessionID, userID, storyID, episodeID, req.CountryCode, req.CountryName, req.DeviceID, req.Platform)

	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to start reading session"})
	}

	// Trigger analytics event log async
	_, _ = h.DB.ExecContext(ctx, `
		INSERT INTO analytics_events (user_id, event_name, properties, country_code, country_name, platform)
		VALUES ($1, 'episode_started', json_build_object('story_id', $2, 'episode_id', $3, 'session_id', $4), $5, $6, $7)
	`, userID, storyID, episodeID, sessionID, req.CountryCode, req.CountryName, req.Platform)

	return c.JSON(http.StatusOK, map[string]interface{}{
		"session_id": sessionID,
	})
}

// EndSession completes or suspends a reading session
func (h *ReadingHandler) EndSession(c echo.Context) error {
	userID, err := auth.GetUserID(c)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
	}

	var req EndSessionRequest
	if err := c.Bind(&req); err != nil || req.SessionID == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid request body"})
	}

	sessionID, err := uuid.Parse(req.SessionID)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid session ID"})
	}

	ctx := c.Request().Context()

	// Get session story and episode ID to update reading progress
	var storyID, episodeID uuid.UUID
	err = h.DB.QueryRowContext(ctx, `
		SELECT story_id, episode_id FROM reading_sessions WHERE id = $1 AND user_id = $2
	`, sessionID, userID).Scan(&storyID, &episodeID)

	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{"error": "reading session not found"})
	}

	// Update session
	_, err = h.DB.ExecContext(ctx, `
		UPDATE reading_sessions
		SET ended_at = now(), duration_seconds = $1, progress_start = $2, progress_end = $3, completed = $4
		WHERE id = $5
	`, req.DurationSeconds, req.ProgressStart, req.ProgressEnd, req.Completed, sessionID)

	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to update session"})
	}

	// Update reading progress
	_, err = h.DB.ExecContext(ctx, `
		INSERT INTO reading_progress (user_id, story_id, episode_id, progress_percent, last_read_at)
		VALUES ($1, $2, $3, $4, now())
		ON CONFLICT (user_id, story_id)
		DO UPDATE SET episode_id = EXCLUDED.episode_id, progress_percent = EXCLUDED.progress_percent, last_read_at = now()
	`, userID, storyID, episodeID, req.ProgressEnd)

	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to update reading progress"})
	}

	// Add to library history automatically
	_, _ = h.DB.ExecContext(ctx, `
		INSERT INTO library_items (user_id, story_id, type, created_at)
		VALUES ($1, $2, 'history', now())
		ON CONFLICT (user_id, story_id, type) DO UPDATE SET created_at = now()
	`, userID, storyID)

	// Trigger analytics event log
	_, _ = h.DB.ExecContext(ctx, `
		INSERT INTO analytics_events (user_id, event_name, properties)
		VALUES ($1, 'episode_completed', json_build_object('story_id', $2, 'episode_id', $3, 'duration_seconds', $4, 'completed', $5))
	`, userID, storyID, episodeID, req.DurationSeconds, req.Completed)

	return c.JSON(http.StatusOK, map[string]string{"status": "updated"})
}

// UpdateProgress updates reading progress directly
func (h *ReadingHandler) UpdateProgress(c echo.Context) error {
	userID, err := auth.GetUserID(c)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
	}

	var req ProgressRequest
	if err := c.Bind(&req); err != nil || req.StoryID == "" || req.EpisodeID == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid request body"})
	}

	storyID, _ := uuid.Parse(req.StoryID)
	episodeID, _ := uuid.Parse(req.EpisodeID)
	ctx := c.Request().Context()

	_, err = h.DB.ExecContext(ctx, `
		INSERT INTO reading_progress (user_id, story_id, episode_id, progress_percent, current_position, last_read_at)
		VALUES ($1, $2, $3, $4, $5, now())
		ON CONFLICT (user_id, story_id)
		DO UPDATE SET episode_id = EXCLUDED.episode_id, progress_percent = EXCLUDED.progress_percent, current_position = EXCLUDED.current_position, last_read_at = now()
	`, userID, storyID, episodeID, req.ProgressPercent, req.CurrentPosition)

	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to update progress"})
	}

	return c.JSON(http.StatusOK, map[string]string{"status": "saved"})
}

// GetLibrary fetches the user's reading lists
func (h *ReadingHandler) GetLibrary(c echo.Context) error {
	userID, err := auth.GetUserID(c)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
	}

	ctx := c.Request().Context()
	libType := c.QueryParam("type") // 'saved', 'completed', 'history'

	var rows *sql.Rows
	if libType != "" {
		rows, err = h.DB.QueryContext(ctx, `
			SELECT s.id, s.title, s.slug, s.description, s.cover_url, l.type, l.created_at
			FROM library_items l
			JOIN stories s ON l.story_id = s.id
			WHERE l.user_id = $1 AND l.type = $2 AND s.status = 'published'
			ORDER BY l.created_at DESC
		`, userID, libType)
	} else {
		rows, err = h.DB.QueryContext(ctx, `
			SELECT s.id, s.title, s.slug, s.description, s.cover_url, l.type, l.created_at
			FROM library_items l
			JOIN stories s ON l.story_id = s.id
			WHERE l.user_id = $1 AND s.status = 'published'
			ORDER BY l.created_at DESC
		`, userID)
	}

	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "database query failed"})
	}
	defer rows.Close()

	type LibraryItemDetail struct {
		StoryID     uuid.UUID `json:"story_id"`
		Title       string    `json:"title"`
		Slug        string    `json:"slug"`
		Description string    `json:"description"`
		CoverURL    string    `json:"cover_url"`
		Type        string    `json:"type"`
		SavedAt     time.Time `json:"saved_at"`
	}

	library := []LibraryItemDetail{}
	for rows.Next() {
		var item LibraryItemDetail
		var desc, cover *string
		if err := rows.Scan(&item.StoryID, &item.Title, &item.Slug, &desc, &cover, &item.Type, &item.SavedAt); err == nil {
			if desc != nil {
				item.Description = *desc
			}
			if cover != nil {
				item.CoverURL = *cover
			}
			library = append(library, item)
		}
	}

	return c.JSON(http.StatusOK, library)
}

// AddToLibrary adds a story to user library
func (h *ReadingHandler) AddToLibrary(c echo.Context) error {
	userID, err := auth.GetUserID(c)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
	}

	var req LibrarySaveRequest
	if err := c.Bind(&req); err != nil || req.StoryID == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid request body"})
	}

	storyID, err := uuid.Parse(req.StoryID)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid story ID"})
	}

	if req.Type == "" {
		req.Type = "saved"
	}

	ctx := c.Request().Context()

	_, err = h.DB.ExecContext(ctx, `
		INSERT INTO library_items (user_id, story_id, type, created_at)
		VALUES ($1, $2, $3, now())
		ON CONFLICT (user_id, story_id, type) DO UPDATE SET created_at = now()
	`, userID, storyID, req.Type)

	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to add to library"})
	}

	return c.JSON(http.StatusOK, map[string]string{"status": "saved"})
}

// RemoveFromLibrary removes a story from user library
func (h *ReadingHandler) RemoveFromLibrary(c echo.Context) error {
	userID, err := auth.GetUserID(c)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
	}

	storyID, err := uuid.Parse(c.Param("storyId"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid story ID"})
	}

	libType := c.QueryParam("type")
	if libType == "" {
		libType = "saved"
	}

	ctx := c.Request().Context()

	_, err = h.DB.ExecContext(ctx, `
		DELETE FROM library_items WHERE user_id = $1 AND story_id = $2 AND type = $3
	`, userID, storyID, libType)

	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to delete from library"})
	}

	return c.JSON(http.StatusOK, map[string]string{"status": "removed"})
}
