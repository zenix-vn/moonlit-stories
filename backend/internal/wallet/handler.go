package wallet

import (
	"database/sql"
	"net/http"
	"time"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
	"moonlit-backend/internal/auth"
	"moonlit-backend/internal/models"
)

type WalletHandler struct {
	DB *sql.DB
}

type UnlockResponse struct {
	Status        string    `json:"status"` // 'unlocked', 'already_unlocked'
	UnlockedAt    time.Time `json:"unlocked_at"`
	CoinsLeft     int       `json:"coins_left"`
	FreePassesLeft int      `json:"free_passes_left"`
}

// GetWallet returns current user's balance
func (h *WalletHandler) GetWallet(c echo.Context) error {
	userID, err := auth.GetUserID(c)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
	}

	ctx := c.Request().Context()
	var wallet models.Wallet

	err = h.DB.QueryRowContext(ctx, `
		SELECT user_id, coins, gems, free_pass, updated_at FROM wallets WHERE user_id = $1
	`, userID).Scan(&wallet.UserID, &wallet.Coins, &wallet.Gems, &wallet.FreePass, &wallet.UpdatedAt)

	if err == sql.ErrNoRows {
		return c.JSON(http.StatusNotFound, map[string]string{"error": "wallet not found"})
	} else if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to query wallet"})
	}

	return c.JSON(http.StatusOK, wallet)
}

// GetTransactions returns transaction history
func (h *WalletHandler) GetTransactions(c echo.Context) error {
	userID, err := auth.GetUserID(c)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
	}

	ctx := c.Request().Context()
	rows, err := h.DB.QueryContext(ctx, `
		SELECT id, user_id, currency_type, amount, balance_after, reason, ref_type, ref_id, created_at
		FROM wallet_transactions
		WHERE user_id = $1
		ORDER BY created_at DESC
		LIMIT 50
	`, userID)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to fetch transactions"})
	}
	defer rows.Close()

	txs := []models.WalletTransaction{}
	for rows.Next() {
		var tx models.WalletTransaction
		var refType *string
		var refID *uuid.UUID
		if err := rows.Scan(&tx.ID, &tx.UserID, &tx.CurrencyType, &tx.Amount, &tx.BalanceAfter, &tx.Reason, &refType, &refID, &tx.CreatedAt); err == nil {
			tx.RefType = refType
			tx.RefID = refID
			txs = append(txs, tx)
		}
	}

	return c.JSON(http.StatusOK, txs)
}

// UnlockWithCoins locks and deducts coins in a PostgreSQL transaction
func (h *WalletHandler) UnlockWithCoins(c echo.Context) error {
	userID, err := auth.GetUserID(c)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
	}

	episodeID, err := uuid.Parse(c.Param("episodeId"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid episode ID"})
	}

	ctx := c.Request().Context()

	// Begin Transaction to prevent race conditions (double spend, negative balance)
	tx, err := h.DB.BeginTx(ctx, nil)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "could not start transaction"})
	}
	defer tx.Rollback()

	// 1. Get episode details
	var isFree bool
	var coinPrice int
	var storyID uuid.UUID
	err = tx.QueryRowContext(ctx, `
		SELECT is_free, COALESCE(coin_price, 20), story_id FROM episodes WHERE id = $1
	`, episodeID).Scan(&isFree, &coinPrice, &storyID)
	if err == sql.ErrNoRows {
		return c.JSON(http.StatusNotFound, map[string]string{"error": "episode not found"})
	} else if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to query episode"})
	}

	if isFree {
		return c.JSON(http.StatusOK, UnlockResponse{
			Status: "already_unlocked",
		})
	}

	// 2. Check if already unlocked
	var unlockID uuid.UUID
	err = tx.QueryRowContext(ctx, `
		SELECT id FROM episode_unlocks WHERE user_id = $1 AND episode_id = $2
	`, userID, episodeID).Scan(&unlockID)
	if err == nil {
		// Already unlocked
		var wallet models.Wallet
		_ = tx.QueryRowContext(ctx, "SELECT coins, free_pass FROM wallets WHERE user_id = $1", userID).Scan(&wallet.Coins, &wallet.FreePass)
		return c.JSON(http.StatusOK, UnlockResponse{
			Status:         "already_unlocked",
			CoinsLeft:      wallet.Coins,
			FreePassesLeft: wallet.FreePass,
		})
	} else if err != sql.ErrNoRows {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "database unlock check failed"})
	}

	// 3. Acquire Wallet row lock
	var coins int
	var freePasses int
	err = tx.QueryRowContext(ctx, `
		SELECT coins, free_pass FROM wallets WHERE user_id = $1 FOR UPDATE
	`, userID).Scan(&coins, &freePasses)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to lock wallet"})
	}

	// 4. Validate Balance
	if coins < coinPrice {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "insufficient coins"})
	}

	// 5. Deduct coins
	newBalance := coins - coinPrice
	_, err = tx.ExecContext(ctx, `
		UPDATE wallets SET coins = $1, updated_at = now() WHERE user_id = $2
	`, newBalance, userID)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to deduct balance"})
	}

	// 6. Record episode unlock
	newUnlockID := uuid.New()
	unlockedAt := time.Now()
	_, err = tx.ExecContext(ctx, `
		INSERT INTO episode_unlocks (id, user_id, story_id, episode_id, method, coins_spent, unlocked_at)
		VALUES ($1, $2, $3, $4, 'coins', $5, $6)
	`, newUnlockID, userID, storyID, episodeID, coinPrice, unlockedAt)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to register unlock"})
	}

	// 7. Ledger transaction log
	_, err = tx.ExecContext(ctx, `
		INSERT INTO wallet_transactions (user_id, currency_type, amount, balance_after, reason, ref_type, ref_id, created_at)
		VALUES ($1, 'coins', $2, $3, 'unlock_episode', 'episode_unlocks', $4, now())
	`, userID, -coinPrice, newBalance, newUnlockID)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to log transaction"})
	}

	// Commit transaction
	if err := tx.Commit(); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to commit transaction"})
	}

	// Trigger analytics logging async or in-place
	_, _ = h.DB.ExecContext(ctx, `
		INSERT INTO analytics_events (user_id, event_name, properties)
		VALUES ($1, 'episode_unlocked_by_coin', json_build_object('story_id', $2, 'episode_id', $3, 'coins_spent', $4))
	`, userID, storyID, episodeID, coinPrice)

	return c.JSON(http.StatusOK, UnlockResponse{
		Status:         "unlocked",
		UnlockedAt:     unlockedAt,
		CoinsLeft:      newBalance,
		FreePassesLeft: freePasses,
	})
}

// UnlockWithFreePass unlocks an episode using a Free Pass token
func (h *WalletHandler) UnlockWithFreePass(c echo.Context) error {
	userID, err := auth.GetUserID(c)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
	}

	episodeID, err := uuid.Parse(c.Param("episodeId"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid episode ID"})
	}

	ctx := c.Request().Context()

	tx, err := h.DB.BeginTx(ctx, nil)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to start transaction"})
	}
	defer tx.Rollback()

	// 1. Get episode details
	var isFree bool
	var storyID uuid.UUID
	err = tx.QueryRowContext(ctx, `
		SELECT is_free, story_id FROM episodes WHERE id = $1
	`, episodeID).Scan(&isFree, &storyID)
	if err == sql.ErrNoRows {
		return c.JSON(http.StatusNotFound, map[string]string{"error": "episode not found"})
	} else if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "database error"})
	}

	if isFree {
		return c.JSON(http.StatusOK, UnlockResponse{
			Status: "already_unlocked",
		})
	}

	// 2. Check if already unlocked
	var unlockID uuid.UUID
	err = tx.QueryRowContext(ctx, `
		SELECT id FROM episode_unlocks WHERE user_id = $1 AND episode_id = $2
	`, userID, episodeID).Scan(&unlockID)
	if err == nil {
		var wallet models.Wallet
		_ = tx.QueryRowContext(ctx, "SELECT coins, free_pass FROM wallets WHERE user_id = $1", userID).Scan(&wallet.Coins, &wallet.FreePass)
		return c.JSON(http.StatusOK, UnlockResponse{
			Status:         "already_unlocked",
			CoinsLeft:      wallet.Coins,
			FreePassesLeft: wallet.FreePass,
		})
	}

	// 3. Lock Wallet
	var coins, freePasses int
	err = tx.QueryRowContext(ctx, `
		SELECT coins, free_pass FROM wallets WHERE user_id = $1 FOR UPDATE
	`, userID).Scan(&coins, &freePasses)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to lock wallet"})
	}

	if freePasses < 1 {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "no free passes available"})
	}

	// 4. Deduct Pass
	newPasses := freePasses - 1
	_, err = tx.ExecContext(ctx, `
		UPDATE wallets SET free_pass = $1, updated_at = now() WHERE user_id = $2
	`, newPasses, userID)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to update passes"})
	}

	// 5. Register Unlock
	newUnlockID := uuid.New()
	unlockedAt := time.Now()
	_, err = tx.ExecContext(ctx, `
		INSERT INTO episode_unlocks (id, user_id, story_id, episode_id, method, free_pass_spent, unlocked_at)
		VALUES ($1, $2, $3, $4, 'free_pass', 1, $5)
	`, newUnlockID, userID, storyID, episodeID, unlockedAt)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to insert unlock"})
	}

	// 6. Ledger transaction log
	_, err = tx.ExecContext(ctx, `
		INSERT INTO wallet_transactions (user_id, currency_type, amount, balance_after, reason, ref_type, ref_id, created_at)
		VALUES ($1, 'free_pass', -1, $2, 'unlock_episode', 'episode_unlocks', $3, now())
	`, userID, newPasses, newUnlockID)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to write transaction"})
	}

	if err := tx.Commit(); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to commit unlock"})
	}

	// Analytics
	_, _ = h.DB.ExecContext(ctx, `
		INSERT INTO analytics_events (user_id, event_name, properties)
		VALUES ($1, 'episode_unlocked_by_free_pass', json_build_object('story_id', $2, 'episode_id', $3))
	`, userID, storyID, episodeID)

	return c.JSON(http.StatusOK, UnlockResponse{
		Status:         "unlocked",
		UnlockedAt:     unlockedAt,
		CoinsLeft:      coins,
		FreePassesLeft: newPasses,
	})
}

// UnlockWithAd unlocks the episode after watching a rewarded advertisement
func (h *WalletHandler) UnlockWithAd(c echo.Context) error {
	userID, err := auth.GetUserID(c)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
	}

	episodeID, err := uuid.Parse(c.Param("episodeId"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid episode ID"})
	}

	ctx := c.Request().Context()

	// In production, we would check if a rewarded ad session exists and is verified
	// For MVP, we simulate server verification and directly unlock
	var isFree bool
	var storyID uuid.UUID
	err = h.DB.QueryRowContext(ctx, `
		SELECT is_free, story_id FROM episodes WHERE id = $1
	`, episodeID).Scan(&isFree, &storyID)
	if err == sql.ErrNoRows {
		return c.JSON(http.StatusNotFound, map[string]string{"error": "episode not found"})
	} else if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "database error"})
	}

	if isFree {
		return c.JSON(http.StatusOK, UnlockResponse{Status: "already_unlocked"})
	}

	// Check if already unlocked
	var unlockID uuid.UUID
	err = h.DB.QueryRowContext(ctx, `
		SELECT id FROM episode_unlocks WHERE user_id = $1 AND episode_id = $2
	`, userID, episodeID).Scan(&unlockID)
	if err == nil {
		var wallet models.Wallet
		_ = h.DB.QueryRowContext(ctx, "SELECT coins, free_pass FROM wallets WHERE user_id = $1", userID).Scan(&wallet.Coins, &wallet.FreePass)
		return c.JSON(http.StatusOK, UnlockResponse{
			Status:         "already_unlocked",
			CoinsLeft:      wallet.Coins,
			FreePassesLeft: wallet.FreePass,
		})
	}

	// Insert Unlock directly (ad rewarded)
	newUnlockID := uuid.New()
	unlockedAt := time.Now()
	_, err = h.DB.ExecContext(ctx, `
		INSERT INTO episode_unlocks (id, user_id, story_id, episode_id, method, unlocked_at)
		VALUES ($1, $2, $3, $4, 'ad', $5)
	`, newUnlockID, userID, storyID, episodeID, unlockedAt)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to register ad unlock"})
	}

	var wallet models.Wallet
	_ = h.DB.QueryRowContext(ctx, "SELECT coins, free_pass FROM wallets WHERE user_id = $1", userID).Scan(&wallet.Coins, &wallet.FreePass)

	// Analytics
	_, _ = h.DB.ExecContext(ctx, `
		INSERT INTO analytics_events (user_id, event_name, properties)
		VALUES ($1, 'episode_unlocked_by_ad', json_build_object('story_id', $2, 'episode_id', $3))
	`, userID, storyID, episodeID)

	return c.JSON(http.StatusOK, UnlockResponse{
		Status:         "unlocked",
		UnlockedAt:     unlockedAt,
		CoinsLeft:      wallet.Coins,
		FreePassesLeft: wallet.FreePass,
	})
}
