package content

import (
	"context"
	"database/sql"
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
	"moonlit-backend/internal/auth"
	"moonlit-backend/internal/models"
)

type ContentHandler struct {
	DB *sql.DB
}

// =========================================================================
// PUBLIC MOBILE ENDPOINTS
// =========================================================================

// GetHomeFeed serves the mobile landing home page layout
func (h *ContentHandler) GetHomeFeed(c echo.Context) error {
	userID, err := auth.GetUserID(c)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
	}

	ctx := c.Request().Context()

	// 1. Timezone-aware greeting
	hour := time.Now().Hour()
	greeting := "Good Evening"
	if hour >= 5 && hour < 12 {
		greeting = "Good Morning"
	} else if hour >= 12 && hour < 17 {
		greeting = "Good Afternoon"
	}

	// 2. Fetch user wallet balance
	var wallet models.Wallet
	_ = h.DB.QueryRowContext(ctx, `
		SELECT user_id, coins, gems, free_pass, updated_at FROM wallets WHERE user_id = $1
	`, userID).Scan(&wallet.UserID, &wallet.Coins, &wallet.Gems, &wallet.FreePass, &wallet.UpdatedAt)

	// 3. Featured story
	var featured models.Story
	var featDesc, featHook, featCover *string
	err = h.DB.QueryRowContext(ctx, `
		SELECT id, title, slug, description, hook, cover_url, free_episode_count, default_coin_price, total_episodes, is_featured, is_hot, is_editor_pick, created_at, updated_at
		FROM stories WHERE status = 'published' AND is_featured = true LIMIT 1
	`).Scan(
		&featured.ID, &featured.Title, &featured.Slug, &featDesc, &featHook, &featCover,
		&featured.FreeEpisodeCount, &featured.DefaultCoinPrice, &featured.TotalEpisodes,
		&featured.IsFeatured, &featured.IsHot, &featured.IsEditorPick, &featured.CreatedAt, &featured.UpdatedAt,
	)
	if err == nil {
		featured.Description = featDesc
		featured.Hook = featHook
		featured.CoverURL = featCover
	}

	// 4. Continue Reading List (join with stories and episodes)
	type ContinueReading struct {
		StoryID            uuid.UUID `json:"story_id"`
		StoryTitle         string    `json:"story_title"`
		StorySlug          string    `json:"story_slug"`
		CoverURL           string    `json:"cover_url"`
		EpisodeID          uuid.UUID `json:"episode_id"`
		EpisodeTitle       string    `json:"episode_title"`
		EpisodeNumber      int       `json:"episode_number"`
		ProgressPercent    float64   `json:"progress_percent"`
		LastReadAt         time.Time `json:"last_read_at"`
	}
	continueList := []ContinueReading{}
	rows, err := h.DB.QueryContext(ctx, `
		SELECT p.story_id, s.title, s.slug, COALESCE(s.cover_url, ''), p.episode_id, e.title, e.episode_number, p.progress_percent, p.last_read_at
		FROM reading_progress p
		JOIN stories s ON p.story_id = s.id
		JOIN episodes e ON p.episode_id = e.id
		WHERE p.user_id = $1 AND s.status = 'published'
		ORDER BY p.last_read_at DESC
		LIMIT 5
	`, userID)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var cr ContinueReading
			if err := rows.Scan(&cr.StoryID, &cr.StoryTitle, &cr.StorySlug, &cr.CoverURL, &cr.EpisodeID, &cr.EpisodeTitle, &cr.EpisodeNumber, &cr.ProgressPercent, &cr.LastReadAt); err == nil {
				continueList = append(continueList, cr)
			}
		}
	}

	// 5. Tonight's Picks (Editor pick or newest)
	picks := []models.Story{}
	pRows, err := h.DB.QueryContext(ctx, `
		SELECT id, title, slug, description, hook, cover_url, free_episode_count, default_coin_price, total_episodes, is_featured, is_hot, is_editor_pick, created_at, updated_at
		FROM stories WHERE status = 'published' AND is_editor_pick = true LIMIT 3
	`)
	if err == nil {
		defer pRows.Close()
		for pRows.Next() {
			var s models.Story
			var desc, hook, cover *string
			if err := pRows.Scan(&s.ID, &s.Title, &s.Slug, &desc, &hook, &cover, &s.FreeEpisodeCount, &s.DefaultCoinPrice, &s.TotalEpisodes, &s.IsFeatured, &s.IsHot, &s.IsEditorPick, &s.CreatedAt, &s.UpdatedAt); err == nil {
				s.Description = desc
				s.Hook = hook
				s.CoverURL = cover
				picks = append(picks, s)
			}
		}
	}

	// 6. Trending Now (Hot stories)
	trending := []models.Story{}
	tRows, err := h.DB.QueryContext(ctx, `
		SELECT id, title, slug, description, hook, cover_url, free_episode_count, default_coin_price, total_episodes, is_featured, is_hot, is_editor_pick, created_at, updated_at
		FROM stories WHERE status = 'published' AND is_hot = true LIMIT 5
	`)
	if err == nil {
		defer tRows.Close()
		for tRows.Next() {
			var s models.Story
			var desc, hook, cover *string
			if err := tRows.Scan(&s.ID, &s.Title, &s.Slug, &desc, &hook, &cover, &s.FreeEpisodeCount, &s.DefaultCoinPrice, &s.TotalEpisodes, &s.IsFeatured, &s.IsHot, &s.IsEditorPick, &s.CreatedAt, &s.UpdatedAt); err == nil {
				s.Description = desc
				s.Hook = hook
				s.CoverURL = cover
				trending = append(trending, s)
			}
		}
	}

	// 7. Active Banners
	banners := []models.Banner{}
	bRows, err := h.DB.QueryContext(ctx, `
		SELECT id, title, subtitle, image_url, deep_link, action_type, action_payload, placement, priority, active, start_at, end_at, target_country_codes
		FROM banners
		WHERE active = true AND placement = 'home_top'
		ORDER BY priority DESC, created_at DESC
	`)
	if err == nil {
		defer bRows.Close()
		for bRows.Next() {
			var b models.Banner
			var sub, dl, at *string
			var payload []byte
			var countries []string
			if err := bRows.Scan(&b.ID, &b.Title, &sub, &b.ImageURL, &dl, &at, &payload, &b.Placement, &b.Priority, &b.Active, &b.StartAt, &b.EndAt, &countries); err == nil {
				b.Subtitle = sub
				b.DeepLink = dl
				b.ActionType = at
				b.ActionPayload = payload
				b.TargetCountryCodes = countries
				banners = append(banners, b)
			}
		}
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"greeting":          greeting,
		"wallet":            wallet,
		"featuredStory":     featured,
		"continueReading":   continueList,
		"tonightsPicks":     picks,
		"trendingNow":       trending,
		"freeEpisodesToday": picks, // mock list
		"banners":           banners,
	})
}

// GetDiscoverFeed searches and filters stories by genre or mood
func (h *ContentHandler) GetDiscoverFeed(c echo.Context) error {
	genreSlug := c.QueryParam("genre")
	moodSlug := c.QueryParam("mood")
	search := c.QueryParam("search")

	ctx := c.Request().Context()
	query := `
		SELECT DISTINCT s.id, s.title, s.slug, s.description, s.hook, s.cover_url, s.free_episode_count, s.default_coin_price, s.total_episodes, s.is_featured, s.is_hot, s.is_editor_pick, s.created_at, s.updated_at
		FROM stories s
		LEFT JOIN story_genres sg ON s.id = sg.story_id
		LEFT JOIN genres g ON sg.genre_id = g.id
		LEFT JOIN story_moods sm ON s.id = sm.story_id
		LEFT JOIN moods m ON sm.mood_id = m.id
		WHERE s.status = 'published'
	`
	args := []interface{}{}
	argIndex := 1

	if genreSlug != "" {
		query += " AND g.slug = $" + strconv.Itoa(argIndex)
		args = append(args, genreSlug)
		argIndex++
	}

	if moodSlug != "" {
		query += " AND m.slug = $" + strconv.Itoa(argIndex)
		args = append(args, moodSlug)
		argIndex++
	}

	if search != "" {
		query += " AND (s.title ILIKE $" + strconv.Itoa(argIndex) + " OR s.description ILIKE $" + strconv.Itoa(argIndex) + ")"
		args = append(args, "%"+search+"%")
		argIndex++
	}

	query += " ORDER BY s.is_featured DESC, s.created_at DESC"

	rows, err := h.DB.QueryContext(ctx, query, args...)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "database query failed"})
	}
	defer rows.Close()

	stories := []models.Story{}
	for rows.Next() {
		var s models.Story
		var desc, hook, cover *string
		if err := rows.Scan(&s.ID, &s.Title, &s.Slug, &desc, &hook, &cover, &s.FreeEpisodeCount, &s.DefaultCoinPrice, &s.TotalEpisodes, &s.IsFeatured, &s.IsHot, &s.IsEditorPick, &s.CreatedAt, &s.UpdatedAt); err == nil {
			s.Description = desc
			s.Hook = hook
			s.CoverURL = cover
			stories = append(stories, s)
		}
	}

	return c.JSON(http.StatusOK, stories)
}

// GetGenres lists active genres
func (h *ContentHandler) GetGenres(c echo.Context) error {
	rows, err := h.DB.QueryContext(c.Request().Context(), `
		SELECT id, name, slug, description, sort_order, active FROM genres WHERE active = true ORDER BY sort_order ASC
	`)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "database query failed"})
	}
	defer rows.Close()

	genres := []models.Genre{}
	for rows.Next() {
		var g models.Genre
		var desc *string
		if err := rows.Scan(&g.ID, &g.Name, &g.Slug, &desc, &g.SortOrder, &g.Active); err == nil {
			g.Description = desc
			genres = append(genres, g)
		}
	}
	return c.JSON(http.StatusOK, genres)
}

// GetMoods lists active moods
func (h *ContentHandler) GetMoods(c echo.Context) error {
	rows, err := h.DB.QueryContext(c.Request().Context(), `
		SELECT id, name, slug, description, active FROM moods WHERE active = true
	`)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "database query failed"})
	}
	defer rows.Close()

	moods := []models.Mood{}
	for rows.Next() {
		var m models.Mood
		var desc *string
		if err := rows.Scan(&m.ID, &m.Name, &m.Slug, &desc, &m.Active); err == nil {
			m.Description = desc
			moods = append(moods, m)
		}
	}
	return c.JSON(http.StatusOK, moods)
}

// GetStoryBySlug returns full story detail including list of episodes (without content)
func (h *ContentHandler) GetStoryBySlug(c echo.Context) error {
	slug := c.Param("slug")
	ctx := c.Request().Context()

	var s models.Story
	var desc, hook, cover *string

	err := h.DB.QueryRowContext(ctx, `
		SELECT id, title, slug, description, hook, cover_url, free_episode_count, default_coin_price, total_episodes, is_featured, is_hot, is_editor_pick, created_at, updated_at
		FROM stories WHERE slug = $1 AND status = 'published'
	`, slug).Scan(
		&s.ID, &s.Title, &s.Slug, &desc, &hook, &cover, &s.FreeEpisodeCount, &s.DefaultCoinPrice, &s.TotalEpisodes, &s.IsFeatured, &s.IsHot, &s.IsEditorPick, &s.CreatedAt, &s.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return c.JSON(http.StatusNotFound, map[string]string{"error": "story not found"})
	} else if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "database query failed"})
	}

	s.Description = desc
	s.Hook = hook
	s.CoverURL = cover

	// Fetch genres
	gRows, err := h.DB.QueryContext(ctx, `
		SELECT g.name FROM genres g JOIN story_genres sg ON g.id = sg.genre_id WHERE sg.story_id = $1
	`, s.ID)
	if err == nil {
		defer gRows.Close()
		for gRows.Next() {
			var name string
			if err := gRows.Scan(&name); err == nil {
				s.Genres = append(s.Genres, name)
			}
		}
	}

	// Fetch moods
	mRows, err := h.DB.QueryContext(ctx, `
		SELECT m.name FROM moods m JOIN story_moods sm ON m.id = sm.mood_id WHERE sm.story_id = $1
	`, s.ID)
	if err == nil {
		defer mRows.Close()
		for mRows.Next() {
			var name string
			if err := mRows.Scan(&name); err == nil {
				s.Moods = append(s.Moods, name)
			}
		}
	}

	// Fetch episodes metadata (exclude body text for security / locking)
	type EpisodeMeta struct {
		ID                   uuid.UUID `json:"id"`
		EpisodeNumber        int       `json:"episode_number"`
		Title                string    `json:"title"`
		IsFree               bool      `json:"is_free"`
		CoinPrice            int       `json:"coin_price"`
		WordCount            int       `json:"word_count"`
		EstimatedReadingTime int       `json:"estimated_reading_time"`
		PublishedAt          time.Time `json:"published_at"`
	}
	episodes := []EpisodeMeta{}
	eRows, err := h.DB.QueryContext(ctx, `
		SELECT id, episode_number, title, is_free, COALESCE(coin_price, 20), word_count, estimated_reading_time, COALESCE(published_at, created_at)
		FROM episodes
		WHERE story_id = $1 AND status = 'published'
		ORDER BY episode_number ASC
	`, s.ID)
	if err == nil {
		defer eRows.Close()
		for eRows.Next() {
			var em EpisodeMeta
			if err := eRows.Scan(&em.ID, &em.EpisodeNumber, &em.Title, &em.IsFree, &em.CoinPrice, &em.WordCount, &em.EstimatedReadingTime, &em.PublishedAt); err == nil {
				episodes = append(episodes, em)
			}
		}
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"story":    s,
		"episodes": episodes,
	})
}

// GetEpisodeAccess checks if the current user has rights to read the episode
func (h *ContentHandler) GetEpisodeAccess(c echo.Context) error {
	userID, err := auth.GetUserID(c)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
	}

	episodeID, err := uuid.Parse(c.Param("episodeId"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid episode ID"})
	}

	ctx := c.Request().Context()
	hasAccess, method, coinPrice, isFree, err := h.CheckAccess(ctx, userID, episodeID)
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"has_access": hasAccess,
		"method":     method,
		"coin_price": coinPrice,
		"is_free":    isFree,
	})
}

// GetEpisodeDetail fetches full episode detail if unlocked/free, otherwise returns 403 Forbidden with preview
func (h *ContentHandler) GetEpisodeDetail(c echo.Context) error {
	userID, err := auth.GetUserID(c)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
	}

	episodeID, err := uuid.Parse(c.Param("episodeId"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid episode ID"})
	}

	ctx := c.Request().Context()

	// Check access
	hasAccess, method, coinPrice, isFree, err := h.CheckAccess(ctx, userID, episodeID)
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{"error": err.Error()})
	}

	var ep models.Episode
	var contentJSON []byte
	var contentHTML, contentText, previewText, slug *string
	var seasonID *uuid.UUID

	err = h.DB.QueryRowContext(ctx, `
		SELECT id, story_id, season_id, episode_number, title, slug, content_json, content_html, content_text, word_count, estimated_reading_time, is_free, coin_price, preview_text, status, published_at, created_at, updated_at
		FROM episodes WHERE id = $1 AND status = 'published'
	`, episodeID).Scan(
		&ep.ID, &ep.StoryID, &seasonID, &ep.EpisodeNumber, &ep.Title, &slug, &contentJSON, &contentHTML, &contentText,
		&ep.WordCount, &ep.EstimatedReadingTime, &ep.IsFree, &ep.CoinPrice, &previewText, &ep.Status, &ep.PublishedAt, &ep.CreatedAt, &ep.UpdatedAt,
	)
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{"error": "episode not found"})
	}

	ep.Slug = slug
	ep.SeasonID = seasonID
	ep.PreviewText = previewText

	if !hasAccess {
		// Hide full content, only return preview text (first paragraph)
		emptyJSON, _ := json.Marshal(map[string]string{})
		ep.ContentJSON = emptyJSON
		ep.ContentHTML = nil
		ep.ContentText = previewText
		return c.JSON(http.StatusForbidden, map[string]interface{}{
			"error":      "episode is locked",
			"has_access": false,
			"coin_price": coinPrice,
			"is_free":    isFree,
			"episode":    ep,
		})
	}

	// Populate full contents
	ep.ContentJSON = contentJSON
	ep.ContentHTML = contentHTML
	ep.ContentText = contentText

	return c.JSON(http.StatusOK, map[string]interface{}{
		"has_access": true,
		"method":     method,
		"episode":    ep,
	})
}

// CheckAccess contains the core logic to evaluate access eligibility
func (h *ContentHandler) CheckAccess(ctx context.Context, userID uuid.UUID, episodeID uuid.UUID) (bool, string, int, bool, error) {
	var isFree bool
	var coinPrice int
	var storyID uuid.UUID

	// Get episode metadata
	err := h.DB.QueryRowContext(ctx, `
		SELECT is_free, COALESCE(coin_price, 20), story_id FROM episodes WHERE id = $1 AND status = 'published'
	`, episodeID).Scan(&isFree, &coinPrice, &storyID)
	if err == sql.ErrNoRows {
		return false, "", 0, false, errorsNew("episode not found")
	} else if err != nil {
		return false, "", 0, false, err
	}

	// 1. If it's free, return true
	if isFree {
		return true, "free", coinPrice, isFree, nil
	}

	// 2. Check if user already unlocked this episode
	var unlockMethod string
	err = h.DB.QueryRowContext(ctx, `
		SELECT method FROM episode_unlocks WHERE user_id = $1 AND episode_id = $2
	`, userID, episodeID).Scan(&unlockMethod)

	if err == nil {
		return true, unlockMethod, coinPrice, isFree, nil
	}

	// 3. Check if user has active subscription (which grants access to all episodes or ad-free reading)
	var subStatus string
	err = h.DB.QueryRowContext(ctx, `
		SELECT status FROM subscriptions WHERE user_id = $1 AND status = 'active' AND expires_at > now()
		LIMIT 1
	`, userID).Scan(&subStatus)

	if err == nil {
		// Active subscription grants read access
		return true, "subscription", coinPrice, isFree, nil
	}

	// No access found
	return false, "", coinPrice, isFree, nil
}

// =========================================================================
// ADMIN ENDPOINTS (CMS CRUD)
// =========================================================================

// AdminListStories lists stories in the CMS panel
func (h *ContentHandler) AdminListStories(c echo.Context) error {
	rows, err := h.DB.QueryContext(c.Request().Context(), `
		SELECT id, title, slug, status, free_episode_count, default_coin_price, total_episodes, is_featured, is_hot, is_editor_pick, created_at, updated_at
		FROM stories
		ORDER BY created_at DESC
	`)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "database query failed"})
	}
	defer rows.Close()

	stories := []models.Story{}
	for rows.Next() {
		var s models.Story
		if err := rows.Scan(&s.ID, &s.Title, &s.Slug, &s.Status, &s.FreeEpisodeCount, &s.DefaultCoinPrice, &s.TotalEpisodes, &s.IsFeatured, &s.IsHot, &s.IsEditorPick, &s.CreatedAt, &s.UpdatedAt); err == nil {
			stories = append(stories, s)
		}
	}
	return c.JSON(http.StatusOK, stories)
}

// AdminCreateStory creates a new story in CMS
func (h *ContentHandler) AdminCreateStory(c echo.Context) error {
	adminID, _ := uuid.Parse(c.Get("admin_id").(string))
	var s models.Story
	if err := c.Bind(&s); err != nil || s.Title == "" || s.Slug == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid request body"})
	}

	ctx := c.Request().Context()
	s.ID = uuid.New()

	_, err := h.DB.ExecContext(ctx, `
		INSERT INTO stories (id, title, slug, description, hook, cover_url, free_episode_count, default_coin_price, total_episodes, is_featured, is_hot, is_editor_pick, status, created_by, updated_by)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 0, $9, $10, $11, 'draft', $12, $12)
	`, s.ID, s.Title, s.Slug, s.Description, s.Hook, s.CoverURL, s.FreeEpisodeCount, s.DefaultCoinPrice, s.IsFeatured, s.IsHot, s.IsEditorPick, adminID)

	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to create story in db: " + err.Error()})
	}

	// Audit Log
	_, _ = h.DB.ExecContext(ctx, `
		INSERT INTO admin_audit_logs (admin_user_id, action, entity_type, entity_id, created_at)
		VALUES ($1, 'create_story', 'stories', $2, now())
	`, adminID, s.ID)

	return c.JSON(http.StatusCreated, s)
}

// AdminGetStoryByID retrieves details of a story in CMS
func (h *ContentHandler) AdminGetStoryByID(c echo.Context) error {
	storyID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid ID"})
	}

	ctx := c.Request().Context()
	var s models.Story
	var desc, hook, cover *string

	err = h.DB.QueryRowContext(ctx, `
		SELECT id, title, slug, description, hook, cover_url, status, free_episode_count, default_coin_price, total_episodes, is_featured, is_hot, is_editor_pick, created_at, updated_at
		FROM stories WHERE id = $1
	`, storyID).Scan(
		&s.ID, &s.Title, &s.Slug, &desc, &hook, &cover, &s.Status, &s.FreeEpisodeCount, &s.DefaultCoinPrice, &s.TotalEpisodes, &s.IsFeatured, &s.IsHot, &s.IsEditorPick, &s.CreatedAt, &s.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return c.JSON(http.StatusNotFound, map[string]string{"error": "story not found"})
	} else if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "database error"})
	}

	s.Description = desc
	s.Hook = hook
	s.CoverURL = cover

	return c.JSON(http.StatusOK, s)
}

// AdminUpdateStory updates metadata of a story in CMS
func (h *ContentHandler) AdminUpdateStory(c echo.Context) error {
	adminID, _ := uuid.Parse(c.Get("admin_id").(string))
	storyID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid ID"})
	}

	var req models.Story
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid request body"})
	}

	ctx := c.Request().Context()

	// Get before data for audit
	var beforeTitle, beforeStatus string
	_ = h.DB.QueryRowContext(ctx, "SELECT title, status FROM stories WHERE id = $1", storyID).Scan(&beforeTitle, &beforeStatus)

	_, err = h.DB.ExecContext(ctx, `
		UPDATE stories
		SET title = $1, slug = $2, description = $3, hook = $4, cover_url = $5, free_episode_count = $6, default_coin_price = $7, is_featured = $8, is_hot = $9, is_editor_pick = $10, status = $11, updated_by = $12, updated_at = now()
		WHERE id = $13
	`, req.Title, req.Slug, req.Description, req.Hook, req.CoverURL, req.FreeEpisodeCount, req.DefaultCoinPrice, req.IsFeatured, req.IsHot, req.IsEditorPick, req.Status, adminID, storyID)

	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to update story"})
	}

	beforeJSON, _ := json.Marshal(map[string]string{"title": beforeTitle, "status": beforeStatus})
	afterJSON, _ := json.Marshal(map[string]string{"title": req.Title, "status": req.Status})

	// Audit Log
	_, _ = h.DB.ExecContext(ctx, `
		INSERT INTO admin_audit_logs (admin_user_id, action, entity_type, entity_id, before_data, after_data, created_at)
		VALUES ($1, 'update_story', 'stories', $2, $3, $4, now())
	`, adminID, storyID, beforeJSON, afterJSON)

	return c.JSON(http.StatusOK, map[string]string{"status": "updated"})
}

// AdminListEpisodes lists episodes of a story in CMS
func (h *ContentHandler) AdminListEpisodes(c echo.Context) error {
	storyID, err := uuid.Parse(c.Param("storyId"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid story ID"})
	}

	rows, err := h.DB.QueryContext(c.Request().Context(), `
		SELECT id, story_id, episode_number, title, is_free, COALESCE(coin_price, 20), word_count, estimated_reading_time, status, created_at, updated_at
		FROM episodes
		WHERE story_id = $1
		ORDER BY episode_number ASC
	`, storyID)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "database query failed"})
	}
	defer rows.Close()

	episodes := []models.Episode{}
	for rows.Next() {
		var ep models.Episode
		if err := rows.Scan(&ep.ID, &ep.StoryID, &ep.EpisodeNumber, &ep.Title, &ep.IsFree, &ep.CoinPrice, &ep.WordCount, &ep.EstimatedReadingTime, &ep.Status, &ep.CreatedAt, &ep.UpdatedAt); err == nil {
			episodes = append(episodes, ep)
		}
	}
	return c.JSON(http.StatusOK, episodes)
}

// AdminCreateEpisode creates a new episode in CMS
func (h *ContentHandler) AdminCreateEpisode(c echo.Context) error {
	adminID, _ := uuid.Parse(c.Get("admin_id").(string))
	storyID, err := uuid.Parse(c.Param("storyId"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid story ID"})
	}

	var ep models.Episode
	if err := c.Bind(&ep); err != nil || ep.Title == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid request body"})
	}

	ctx := c.Request().Context()
	ep.ID = uuid.New()
	ep.StoryID = storyID

	// Estimate reading time: 200 words per minute average (12 seconds per 40 words)
	wordCount := len(getString(ep.ContentText)) / 5 // raw approximation
	if wordCount == 0 {
		wordCount = 100
	}
	estReadingTime := wordCount * 60 / 200 // in seconds

	// Insert
	_, err = h.DB.ExecContext(ctx, `
		INSERT INTO episodes (id, story_id, season_id, episode_number, title, slug, content_json, content_html, content_text, word_count, estimated_reading_time, is_free, coin_price, preview_text, status, created_by, updated_by)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, 'draft', $15, $15)
	`, ep.ID, storyID, ep.SeasonID, ep.EpisodeNumber, ep.Title, ep.Slug, ep.ContentJSON, ep.ContentHTML, ep.ContentText, wordCount, estReadingTime, ep.IsFree, ep.CoinPrice, ep.PreviewText, adminID)

	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to create episode: " + err.Error()})
	}

	// Update story total_episodes count
	_, _ = h.DB.ExecContext(ctx, "UPDATE stories SET total_episodes = (SELECT COUNT(*) FROM episodes WHERE story_id = $1 AND status = 'published') WHERE id = $1", storyID)

	// Audit Log
	_, _ = h.DB.ExecContext(ctx, `
		INSERT INTO admin_audit_logs (admin_user_id, action, entity_type, entity_id, created_at)
		VALUES ($1, 'create_episode', 'episodes', $2, now())
	`, adminID, ep.ID)

	return c.JSON(http.StatusCreated, ep)
}

// AdminGetEpisodeByID retrieves details of an episode
func (h *ContentHandler) AdminGetEpisodeByID(c echo.Context) error {
	episodeID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid ID"})
	}

	ctx := c.Request().Context()
	var ep models.Episode
	var contentJSON []byte
	var contentHTML, contentText, previewText, slug *string
	var seasonID *uuid.UUID

	err = h.DB.QueryRowContext(ctx, `
		SELECT id, story_id, season_id, episode_number, title, slug, content_json, content_html, content_text, word_count, estimated_reading_time, is_free, coin_price, preview_text, status, published_at, created_at, updated_at
		FROM episodes WHERE id = $1
	`, episodeID).Scan(
		&ep.ID, &ep.StoryID, &seasonID, &ep.EpisodeNumber, &ep.Title, &slug, &contentJSON, &contentHTML, &contentText,
		&ep.WordCount, &ep.EstimatedReadingTime, &ep.IsFree, &ep.CoinPrice, &previewText, &ep.Status, &ep.PublishedAt, &ep.CreatedAt, &ep.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return c.JSON(http.StatusNotFound, map[string]string{"error": "episode not found"})
	} else if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "database error"})
	}

	ep.Slug = slug
	ep.SeasonID = seasonID
	ep.ContentJSON = contentJSON
	ep.ContentHTML = contentHTML
	ep.ContentText = contentText
	ep.PreviewText = previewText

	return c.JSON(http.StatusOK, ep)
}

// AdminUpdateEpisode updates episode properties
func (h *ContentHandler) AdminUpdateEpisode(c echo.Context) error {
	adminID, _ := uuid.Parse(c.Get("admin_id").(string))
	episodeID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid ID"})
	}

	var req models.Episode
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid request body"})
	}

	ctx := c.Request().Context()

	// Get before data for audit
	var beforeTitle, beforeStatus string
	var storyID uuid.UUID
	_ = h.DB.QueryRowContext(ctx, "SELECT title, status, story_id FROM episodes WHERE id = $1", episodeID).Scan(&beforeTitle, &beforeStatus, &storyID)

	wordCount := len(getString(req.ContentText)) / 5
	if wordCount == 0 {
		wordCount = 100
	}
	estReadingTime := wordCount * 60 / 200

	_, err = h.DB.ExecContext(ctx, `
		UPDATE episodes
		SET title = $1, slug = $2, content_json = $3, content_html = $4, content_text = $5, word_count = $6, estimated_reading_time = $7, is_free = $8, coin_price = $9, preview_text = $10, status = $11, updated_by = $12, updated_at = now()
		WHERE id = $13
	`, req.Title, req.Slug, req.ContentJSON, req.ContentHTML, req.ContentText, wordCount, estReadingTime, req.IsFree, req.CoinPrice, req.PreviewText, req.Status, adminID, episodeID)

	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to update episode"})
	}

	// Update story total_episodes count
	_, _ = h.DB.ExecContext(ctx, "UPDATE stories SET total_episodes = (SELECT COUNT(*) FROM episodes WHERE story_id = $1 AND status = 'published') WHERE id = $1", storyID)

	beforeJSON, _ := json.Marshal(map[string]string{"title": beforeTitle, "status": beforeStatus})
	afterJSON, _ := json.Marshal(map[string]string{"title": req.Title, "status": req.Status})

	// Audit Log
	_, _ = h.DB.ExecContext(ctx, `
		INSERT INTO admin_audit_logs (admin_user_id, action, entity_type, entity_id, before_data, after_data, created_at)
		VALUES ($1, 'update_episode', 'episodes', $2, $3, $4, now())
	`, adminID, episodeID, beforeJSON, afterJSON)

	return c.JSON(http.StatusOK, map[string]string{"status": "updated"})
}

// Helpers
func getString(p *string) string {
	if p == nil {
		return ""
	}
	return *p
}

func errorsNew(msg string) error {
	return &CustomError{message: msg}
}

type CustomError struct {
	message string
}

func (e *CustomError) Error() string {
	return e.message
}
