package rewards

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"time"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
	"moonlit-backend/internal/auth"
	"moonlit-backend/internal/models"
)

type RewardsHandler struct {
	DB *sql.DB
}

type RewardConfig struct {
	Day    int    `json:"day"`
	Type   string `json:"type"` // 'coins', 'free_pass'
	Amount int    `json:"amount"`
}

type SystemConfigVal struct {
	DailyCheckinRewards []RewardConfig `json:"daily_checkin_rewards"`
}

// GetRewardsDashboard returns streak details, checkin history, and daily task progress
func (h *RewardsHandler) GetRewardsDashboard(c echo.Context) error {
	userID, err := auth.GetUserID(c)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
	}

	ctx := c.Request().Context()
	todayStr := time.Now().Format("2006-01-02")

	// 1. Get streak details
	var streak models.UserStreak
	var lastActiveDate *string
	err = h.DB.QueryRowContext(ctx, `
		SELECT user_id, current_streak, longest_streak, last_active_date, updated_at
		FROM user_streaks WHERE user_id = $1
	`, userID).Scan(&streak.UserID, &streak.CurrentStreak, &streak.LongestStreak, &lastActiveDate, &streak.UpdatedAt)
	if err == nil {
		streak.LastActiveDate = lastActiveDate
	}

	// 2. Check if checked in today
	var checkedInToday bool
	var dummy uuid.UUID
	err = h.DB.QueryRowContext(ctx, `
		SELECT id FROM daily_checkins WHERE user_id = $1 AND checkin_date = $2
	`, userID, todayStr).Scan(&dummy)
	if err == nil {
		checkedInToday = true
	}

	// 3. Load checkin config to show next reward
	rewardsConfig := getDefaultCheckinConfig()
	var configJSON []byte
	err = h.DB.QueryRowContext(ctx, "SELECT value FROM app_configs WHERE key = 'system_config'").Scan(&configJSON)
	if err == nil {
		var sysConfig SystemConfigVal
		if err := json.Unmarshal(configJSON, &sysConfig); err == nil && len(sysConfig.DailyCheckinRewards) > 0 {
			rewardsConfig = sysConfig.DailyCheckinRewards
		}
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"streak":           streak,
		"checked_in_today": checkedInToday,
		"rewards_calendar": rewardsConfig,
		"today_date":       todayStr,
	})
}

// ClaimDailyCheckin handles the daily streak checkin
func (h *RewardsHandler) ClaimDailyCheckin(c echo.Context) error {
	userID, err := auth.GetUserID(c)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
	}

	ctx := c.Request().Context()
	todayTime := time.Now()
	todayStr := todayTime.Format("2006-01-02")
	yesterdayStr := todayTime.AddDate(0, 0, -1).Format("2006-01-02")

	// 1. Check if already checked in today
	var dummy uuid.UUID
	err = h.DB.QueryRowContext(ctx, `
		SELECT id FROM daily_checkins WHERE user_id = $1 AND checkin_date = $2
	`, userID, todayStr).Scan(&dummy)
	if err == nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "already checked in today"})
	}

	// 2. Load rewards configuration
	rewardsConfig := getDefaultCheckinConfig()
	var configJSON []byte
	_ = h.DB.QueryRowContext(ctx, "SELECT value FROM app_configs WHERE key = 'system_config'").Scan(&configJSON)
	var sysConfig SystemConfigVal
	if len(configJSON) > 0 {
		_ = json.Unmarshal(configJSON, &sysConfig)
		if len(sysConfig.DailyCheckinRewards) > 0 {
			rewardsConfig = sysConfig.DailyCheckinRewards
		}
	}

	tx, err := h.DB.BeginTx(ctx, nil)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "could not start transaction"})
	}
	defer tx.Rollback()

	// 3. Lock streak record
	var currentStreak, longestStreak int
	var lastActive *string
	err = tx.QueryRowContext(ctx, `
		SELECT current_streak, longest_streak, last_active_date FROM user_streaks WHERE user_id = $1 FOR UPDATE
	`, userID).Scan(&currentStreak, &longestStreak, &lastActive)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to lock user streak"})
	}

	// 4. Calculate new streak day
	newStreak := 1
	if lastActive != nil {
		if *lastActive == yesterdayStr {
			newStreak = currentStreak + 1
		} else if *lastActive == todayStr {
			return c.JSON(http.StatusBadRequest, map[string]string{"error": "already checked in today"})
		}
	}

	// Loop back after 7 days
	streakDayIndex := (newStreak - 1) % 7
	reward := rewardsConfig[streakDayIndex]

	// Update streak stats
	if newStreak > longestStreak {
		longestStreak = newStreak
	}

	_, err = tx.ExecContext(ctx, `
		UPDATE user_streaks
		SET current_streak = $1, longest_streak = $2, last_active_date = $3, updated_at = now()
		WHERE user_id = $4
	`, newStreak, longestStreak, todayStr, userID)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to update streak"})
	}

	// 5. Lock Wallet
	var coins, freePasses int
	err = tx.QueryRowContext(ctx, `
		SELECT coins, free_pass FROM wallets WHERE user_id = $1 FOR UPDATE
	`, userID).Scan(&coins, &freePasses)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to lock wallet"})
	}

	// Apply rewards
	newCoins := coins
	newPasses := freePasses
	var balanceAfter int

	if reward.Type == "coins" {
		newCoins += reward.Amount
		balanceAfter = newCoins
		_, err = tx.ExecContext(ctx, "UPDATE wallets SET coins = $1, updated_at = now() WHERE user_id = $2", newCoins, userID)
	} else {
		newPasses += reward.Amount
		balanceAfter = newPasses
		_, err = tx.ExecContext(ctx, "UPDATE wallets SET free_pass = $1, updated_at = now() WHERE user_id = $2", newPasses, userID)
	}

	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to credit reward"})
	}

	// 6. Record Daily Checkin
	checkinID := uuid.New()
	_, err = tx.ExecContext(ctx, `
		INSERT INTO daily_checkins (id, user_id, checkin_date, streak_day, reward_type, reward_amount, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, now())
	`, checkinID, userID, todayStr, streakDayIndex+1, reward.Type, reward.Amount)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to save check-in log"})
	}

	// 7. Ledger transaction log
	_, err = tx.ExecContext(ctx, `
		INSERT INTO wallet_transactions (user_id, currency_type, amount, balance_after, reason, ref_type, ref_id, created_at)
		VALUES ($1, $2, $3, $4, 'daily_checkin', 'daily_checkins', $5, now())
	`, userID, reward.Type, reward.Amount, balanceAfter, checkinID)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to log transaction"})
	}

	if err := tx.Commit(); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to commit check-in"})
	}

	// Log analytics
	_, _ = h.DB.ExecContext(ctx, `
		INSERT INTO analytics_events (user_id, event_name, properties)
		VALUES ($1, 'daily_checkin_claimed', json_build_object('streak_day', $2, 'reward_type', $3, 'reward_amount', $4))
	`, userID, streakDayIndex+1, reward.Type, reward.Amount)

	return c.JSON(http.StatusOK, map[string]interface{}{
		"status":        "claimed",
		"reward_type":   reward.Type,
		"reward_amount": reward.Amount,
		"streak_day":    streakDayIndex + 1,
		"total_streak":  newStreak,
		"coins":         newCoins,
		"free_passes":   newPasses,
	})
}

// GetDailyTasks lists active tasks and current progress
func (h *RewardsHandler) GetDailyTasks(c echo.Context) error {
	userID, err := auth.GetUserID(c)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
	}

	ctx := c.Request().Context()
	todayStr := time.Now().Format("2006-01-02")

	// Left join active tasks with user progress for today
	type TaskProgressDetail struct {
		TaskID       uuid.UUID  `json:"task_id"`
		Code         string     `json:"code"`
		Title        string     `json:"title"`
		Description  string     `json:"description"`
		TargetEvent  string     `json:"target_event"`
		TargetValue  int        `json:"target_value"`
		RewardType   string     `json:"reward_type"`
		RewardAmount int        `json:"reward_amount"`
		Progress     int        `json:"progress"`
		CompletedAt  *time.Time `json:"completed_at,omitempty"`
		ClaimedAt    *time.Time `json:"claimed_at,omitempty"`
	}

	rows, err := h.DB.QueryContext(ctx, `
		SELECT t.id, t.code, t.title, COALESCE(t.description, ''), t.target_event, t.target_value, t.reward_type, t.reward_amount,
		       COALESCE(p.progress, 0), p.completed_at, p.claimed_at
		FROM tasks t
		LEFT JOIN user_task_progress p ON t.id = p.task_id AND p.user_id = $1 AND p.task_date = $2
		WHERE t.active = true
	`, userID, todayStr)

	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to query tasks"})
	}
	defer rows.Close()

	tasks := []TaskProgressDetail{}
	for rows.Next() {
		var tp TaskProgressDetail
		if err := rows.Scan(&tp.TaskID, &tp.Code, &tp.Title, &tp.Description, &tp.TargetEvent, &tp.TargetValue, &tp.RewardType, &tp.RewardAmount, &tp.Progress, &tp.CompletedAt, &tp.ClaimedAt); err == nil {
			tasks = append(tasks, tp)
		}
	}

	return c.JSON(http.StatusOK, tasks)
}

// ClaimTaskReward claims the coins/gems for a completed task
func (h *RewardsHandler) ClaimTaskReward(c echo.Context) error {
	userID, err := auth.GetUserID(c)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
	}

	taskID, err := uuid.Parse(c.Param("taskId"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid task ID"})
	}

	ctx := c.Request().Context()
	todayStr := time.Now().Format("2006-01-02")

	tx, err := h.DB.BeginTx(ctx, nil)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "could not start transaction"})
	}
	defer tx.Rollback()

	// 1. Get task progress detail
	var progress int
	var targetValue int
	var rewardType string
	var rewardAmount int
	var completedAt *time.Time
	var claimedAt *time.Time
	var progressID uuid.UUID

	err = tx.QueryRowContext(ctx, `
		SELECT p.id, p.progress, t.target_value, t.reward_type, t.reward_amount, p.completed_at, p.claimed_at
		FROM user_task_progress p
		JOIN tasks t ON p.task_id = t.id
		WHERE p.user_id = $1 AND p.task_id = $2 AND p.task_date = $3
		FOR UPDATE
	`, userID, taskID, todayStr).Scan(&progressID, &progress, &targetValue, &rewardType, &rewardAmount, &completedAt, &claimedAt)

	if err == sql.ErrNoRows {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "no progress recorded for this task today"})
	} else if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "database error"})
	}

	// 2. Check if completed
	if progress < targetValue {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "task is not completed yet"})
	}

	// 3. Check if already claimed
	if claimedAt != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "reward already claimed"})
	}

	// 4. Lock and update wallet balance
	var coins, freePasses int
	err = tx.QueryRowContext(ctx, `
		SELECT coins, free_pass FROM wallets WHERE user_id = $1 FOR UPDATE
	`, userID).Scan(&coins, &freePasses)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to lock wallet"})
	}

	newCoins := coins
	newPasses := freePasses
	var balanceAfter int

	if rewardType == "coins" {
		newCoins += rewardAmount
		balanceAfter = newCoins
		_, err = tx.ExecContext(ctx, "UPDATE wallets SET coins = $1, updated_at = now() WHERE user_id = $2", newCoins, userID)
	} else {
		newPasses += rewardAmount
		balanceAfter = newPasses
		_, err = tx.ExecContext(ctx, "UPDATE wallets SET free_pass = $1, updated_at = now() WHERE user_id = $2", newPasses, userID)
	}

	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to credit task reward"})
	}

	// 5. Update task progress claimed_at status
	_, err = tx.ExecContext(ctx, `
		UPDATE user_task_progress SET claimed_at = now() WHERE id = $1
	`, progressID)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to update progress logs"})
	}

	// 6. Ledger transaction log
	_, err = tx.ExecContext(ctx, `
		INSERT INTO wallet_transactions (user_id, currency_type, amount, balance_after, reason, ref_type, ref_id, created_at)
		VALUES ($1, $2, $3, $4, 'task_reward', 'user_task_progress', $5, now())
	`, userID, rewardType, rewardAmount, balanceAfter, progressID)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to record transaction"})
	}

	if err := tx.Commit(); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to commit claim"})
	}

	// Analytics
	_, _ = h.DB.ExecContext(ctx, `
		INSERT INTO analytics_events (user_id, event_name, properties)
		VALUES ($1, 'task_claimed', json_build_object('task_id', $2, 'reward_type', $3, 'reward_amount', $4))
	`, userID, taskID, rewardType, rewardAmount)

	return c.JSON(http.StatusOK, map[string]interface{}{
		"status":        "claimed",
		"reward_type":   rewardType,
		"reward_amount": rewardAmount,
		"coins":         newCoins,
		"free_passes":   newPasses,
	})
}

// Default check-in reward configurations if DB app_configs is missing
func getDefaultCheckinConfig() []RewardConfig {
	return []RewardConfig{
		{Day: 1, Type: "coins", Amount: 10},
		{Day: 2, Type: "coins", Amount: 15},
		{Day: 3, Type: "coins", Amount: 20},
		{Day: 4, Type: "coins", Amount: 30},
		{Day: 5, Type: "coins", Amount: 40},
		{Day: 6, Type: "coins", Amount: 50},
		{Day: 7, Type: "free_pass", Amount: 1},
	}
}
