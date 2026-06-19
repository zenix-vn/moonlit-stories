package analytics

import (
	"database/sql"
	"net/http"
	"time"

	"github.com/labstack/echo/v4"
)

// AdminDashboardOverview returns top-line, near-real-time platform metrics for
// the admin dashboard (last 24 hours).
func (h *AnalyticsHandler) AdminDashboardOverview(c echo.Context) error {
	ctx := c.Request().Context()

	var dau, subscribers, unlocks int
	var revenue float64

	// Daily active users: any authenticated activity in the last 24h.
	_ = h.DB.QueryRowContext(ctx, `
		SELECT COUNT(DISTINCT user_id) FROM (
			SELECT user_id FROM reading_sessions WHERE started_at > now() - interval '24 hours' AND user_id IS NOT NULL
			UNION
			SELECT user_id FROM analytics_events WHERE created_at > now() - interval '24 hours' AND user_id IS NOT NULL
			UNION
			SELECT user_id FROM user_login_events WHERE login_at > now() - interval '24 hours' AND user_id IS NOT NULL
		) t`).Scan(&dau)

	_ = h.DB.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM subscriptions
		WHERE status = 'active' AND (expires_at IS NULL OR expires_at > now())`).Scan(&subscribers)

	_ = h.DB.QueryRowContext(ctx, `
		SELECT COALESCE(SUM(price), 0) FROM purchases
		WHERE status = 'completed' AND COALESCE(purchased_at, created_at) > now() - interval '24 hours'`).Scan(&revenue)

	_ = h.DB.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM episode_unlocks
		WHERE unlocked_at > now() - interval '24 hours'`).Scan(&unlocks)

	return c.JSON(http.StatusOK, map[string]interface{}{
		"dau":         dau,
		"subscribers": subscribers,
		"revenue":     revenue,
		"unlocks":     unlocks,
	})
}

// AdminDashboardRecentActivity returns the most recent user activity across
// reading sessions, episode unlocks, and subscription starts.
func (h *AnalyticsHandler) AdminDashboardRecentActivity(c echo.Context) error {
	ctx := c.Request().Context()

	rows, err := h.DB.QueryContext(ctx, `
		SELECT a.ts,
		       COALESCE(u.email, 'guest_' || left(a.user_id::text, 8)) AS user_label,
		       a.country,
		       a.action,
		       a.story,
		       a.episode,
		       EXISTS(
		           SELECT 1 FROM subscriptions s
		           WHERE s.user_id = a.user_id
		             AND s.status = 'active'
		             AND (s.expires_at IS NULL OR s.expires_at > now())
		       ) AS is_subscriber
		FROM (
		    SELECT rs.user_id, rs.started_at AS ts, rs.country_code AS country,
		           'Reading' AS action, st.title AS story,
		           'Ep ' || e.episode_number AS episode
		    FROM reading_sessions rs
		    LEFT JOIN stories st ON st.id = rs.story_id
		    LEFT JOIN episodes e ON e.id = rs.episode_id
		    WHERE rs.started_at > now() - interval '7 days'

		    UNION ALL

		    SELECT eu.user_id, eu.unlocked_at, NULL,
		           CASE eu.method
		               WHEN 'coins' THEN 'Unlocked by Coins'
		               WHEN 'free_pass' THEN 'Unlocked by Free Pass'
		               WHEN 'subscription' THEN 'Unlocked by MoonPass'
		               WHEN 'ad' THEN 'Unlocked by Ad'
		               ELSE 'Unlocked'
		           END,
		           st.title, 'Ep ' || e.episode_number
		    FROM episode_unlocks eu
		    LEFT JOIN stories st ON st.id = eu.story_id
		    LEFT JOIN episodes e ON e.id = eu.episode_id
		    WHERE eu.unlocked_at > now() - interval '7 days'

		    UNION ALL

		    SELECT sub.user_id, COALESCE(sub.started_at, sub.created_at), NULL,
		           'Subscribed', '-', '-'
		    FROM subscriptions sub
		    WHERE COALESCE(sub.started_at, sub.created_at) > now() - interval '7 days'
		) a
		LEFT JOIN users u ON u.id = a.user_id
		ORDER BY a.ts DESC
		LIMIT 25`)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to load recent activity"})
	}
	defer rows.Close()

	type activityItem struct {
		Time    string `json:"time"`
		User    string `json:"user"`
		Country string `json:"country"`
		Action  string `json:"action"`
		Story   string `json:"story"`
		Episode string `json:"episode"`
		Sub     string `json:"sub"`
	}

	items := make([]activityItem, 0, 25)
	for rows.Next() {
		var ts time.Time
		var user string
		var country, story, episode sql.NullString
		var action string
		var isSub bool
		if err := rows.Scan(&ts, &user, &country, &action, &story, &episode, &isSub); err != nil {
			continue
		}
		sub := "Free"
		if isSub {
			sub = "MoonPass"
		}
		items = append(items, activityItem{
			Time:    ts.Format("15:04"),
			User:    user,
			Country: nullOr(country, "—"),
			Action:  action,
			Story:   nullOr(story, "-"),
			Episode: nullOr(episode, "-"),
			Sub:     sub,
		})
	}

	return c.JSON(http.StatusOK, items)
}

// AdminDashboardCountryActivity returns active users, subscribers, and revenue
// broken down by country (last 7 days of activity).
func (h *AnalyticsHandler) AdminDashboardCountryActivity(c echo.Context) error {
	ctx := c.Request().Context()

	type countryItem struct {
		Country     string  `json:"country"`
		Code        string  `json:"code"`
		ActiveUsers int     `json:"active_users"`
		Subscribers int     `json:"subscribers"`
		Revenue     float64 `json:"revenue"`
	}

	order := []string{}
	byCode := map[string]*countryItem{}

	// Active users per country.
	rows, err := h.DB.QueryContext(ctx, `
		SELECT country_code, MAX(country_name) AS country_name, COUNT(DISTINCT user_id) AS active_users
		FROM (
			SELECT country_code, country_name, user_id FROM reading_sessions
			WHERE started_at > now() - interval '7 days' AND user_id IS NOT NULL AND country_code IS NOT NULL
			UNION ALL
			SELECT country_code, country_name, user_id FROM user_login_events
			WHERE login_at > now() - interval '7 days' AND user_id IS NOT NULL AND country_code IS NOT NULL
		) t
		GROUP BY country_code
		ORDER BY active_users DESC
		LIMIT 10`)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to load country activity"})
	}
	for rows.Next() {
		var code string
		var name sql.NullString
		var active int
		if err := rows.Scan(&code, &name, &active); err != nil {
			continue
		}
		item := &countryItem{Country: nullOr(name, code), Code: code, ActiveUsers: active}
		byCode[code] = item
		order = append(order, code)
	}
	rows.Close()

	// Subscribers per country (profile country).
	subRows, err := h.DB.QueryContext(ctx, `
		SELECT up.country_code, COUNT(*)
		FROM subscriptions s
		JOIN user_profiles up ON up.user_id = s.user_id
		WHERE s.status = 'active' AND (s.expires_at IS NULL OR s.expires_at > now())
		  AND up.country_code IS NOT NULL
		GROUP BY up.country_code`)
	if err == nil {
		for subRows.Next() {
			var code string
			var count int
			if err := subRows.Scan(&code, &count); err == nil {
				if item, ok := byCode[code]; ok {
					item.Subscribers = count
				}
			}
		}
		subRows.Close()
	}

	// Revenue per country (profile country).
	revRows, err := h.DB.QueryContext(ctx, `
		SELECT up.country_code, COALESCE(SUM(p.price), 0)
		FROM purchases p
		JOIN user_profiles up ON up.user_id = p.user_id
		WHERE p.status = 'completed' AND up.country_code IS NOT NULL
		GROUP BY up.country_code`)
	if err == nil {
		for revRows.Next() {
			var code string
			var rev float64
			if err := revRows.Scan(&code, &rev); err == nil {
				if item, ok := byCode[code]; ok {
					item.Revenue = rev
				}
			}
		}
		revRows.Close()
	}

	result := make([]countryItem, 0, len(order))
	for _, code := range order {
		result = append(result, *byCode[code])
	}

	return c.JSON(http.StatusOK, result)
}

func nullOr(s sql.NullString, fallback string) string {
	if s.Valid && s.String != "" {
		return s.String
	}
	return fallback
}
