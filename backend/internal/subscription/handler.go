package subscription

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
	"moonlit-backend/internal/auth"
	"moonlit-backend/internal/models"
)

type SubscriptionHandler struct {
	DB *sql.DB
}

type IAPVerifyRequest struct {
	ProductCode       string  `json:"product_code"`
	Platform          string  `json:"platform"` // 'apple', 'google', 'stripe'
	TransactionID     string  `json:"transaction_id"`
	SignedTransaction *string `json:"signed_transaction,omitempty"`
}

type RevenueCatWebhook struct {
	Event struct {
		Type           string `json:"type"` // 'INITIAL_PURCHASE', 'RENEWAL', 'CANCELLATION', 'EXPIRATION'
		AppUserID      string `json:"app_user_id"`
		ProductID      string `json:"product_id"`
		EntitlementIDs []string `json:"entitlement_ids"`
	} `json:"event"`
}

// GetProducts lists all available, active shop items (coin packs & subscription passes)
func (h *SubscriptionHandler) GetProducts(c echo.Context) error {
	rows, err := h.DB.QueryContext(c.Request().Context(), `
		SELECT id, code, name, type, COALESCE(platform, 'all'), platform_product_id, COALESCE(price, 0), currency, coin_amount, bonus_coin_amount, active
		FROM products
		WHERE active = true
	`)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to query products"})
	}
	defer rows.Close()

	products := []models.Product{}
	for rows.Next() {
		var p models.Product
		var plat, platProd *string
		var coins, bonus *int
		if err := rows.Scan(&p.ID, &p.Code, &p.Name, &p.Type, &plat, &platProd, &p.Price, &p.Currency, &coins, &bonus, &p.Active); err == nil {
			p.Platform = plat
			p.PlatformProductID = platProd
			p.CoinAmount = coins
			p.BonusCoinAmount = bonus
			products = append(products, p)
		}
	}

	return c.JSON(http.StatusOK, products)
}

// VerifyIAPPurchase records an App Store / Play purchase after client-side StoreKit verification.
// Production deployments should pair this with App Store Server API or RevenueCat webhooks.
func (h *SubscriptionHandler) VerifyIAPPurchase(c echo.Context) error {
	userID, err := auth.GetUserID(c)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
	}

	var req IAPVerifyRequest
	if err := c.Bind(&req); err != nil || req.ProductCode == "" || req.TransactionID == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid request body"})
	}

	ctx := c.Request().Context()

	tx, err := h.DB.BeginTx(ctx, nil)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "could not start transaction"})
	}
	defer tx.Rollback()

	// 1. Get product details
	var productID uuid.UUID
	var prodType string
	var coinAmt, bonusAmt sql.NullInt64
	var price float64
	var currency string
	err = tx.QueryRowContext(ctx, `
		SELECT id, type, coin_amount, bonus_coin_amount, COALESCE(price, 0), COALESCE(currency, 'USD')
		FROM products
		WHERE code = $1 AND active = true
	`, req.ProductCode).Scan(&productID, &prodType, &coinAmt, &bonusAmt, &price, &currency)

	if err == sql.ErrNoRows {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "product not found or inactive"})
	} else if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "database product query failed"})
	}

	// 2. Check if transaction has already been verified to prevent double spending
	var dummy uuid.UUID
	err = tx.QueryRowContext(ctx, `
		SELECT id FROM purchases WHERE platform_transaction_id = $1 AND platform = $2
	`, req.TransactionID, req.Platform).Scan(&dummy)

	if err == nil {
		// Already processed. Return current wallet details
		var wallet models.Wallet
		_ = tx.QueryRowContext(ctx, "SELECT coins, free_pass FROM wallets WHERE user_id = $1", userID).Scan(&wallet.Coins, &wallet.FreePass)
		sub := fetchActiveSubscription(ctx, tx, userID)
		return c.JSON(http.StatusOK, map[string]interface{}{
			"status":       "already_processed",
			"wallet":       wallet,
			"subscription": sub,
		})
	}

	purchaseID := uuid.New()
	purchasedAt := time.Now()
	rawPayload, _ := json.Marshal(map[string]interface{}{
		"product_code":       req.ProductCode,
		"platform":           req.Platform,
		"transaction_id":     req.TransactionID,
		"signed_transaction": req.SignedTransaction,
	})

	// 3. Process Product based on type
	if prodType == "coin_pack" {
		totalCoins := int(coinAmt.Int64) + int(bonusAmt.Int64)

		// Lock wallet
		var currentCoins int
		err = tx.QueryRowContext(ctx, `
			SELECT coins FROM wallets WHERE user_id = $1 FOR UPDATE
		`, userID).Scan(&currentCoins)
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to lock wallet"})
		}

		newCoins := currentCoins + totalCoins

		// Update Wallet
		_, err = tx.ExecContext(ctx, `
			UPDATE wallets SET coins = $1, updated_at = now() WHERE user_id = $2
		`, newCoins, userID)
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to credit wallet coins"})
		}

		// Insert Transaction Log
		_, err = tx.ExecContext(ctx, `
			INSERT INTO wallet_transactions (user_id, currency_type, amount, balance_after, reason, ref_type, ref_id)
			VALUES ($1, 'coins', $2, $3, 'iap_purchase', 'purchases', $4)
		`, userID, totalCoins, newCoins, purchaseID)
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to log wallet transaction"})
		}

	} else if prodType == "subscription" {
		var expiresAt time.Time
		switch req.ProductCode {
		case "moonpass_weekly":
			expiresAt = purchasedAt.AddDate(0, 0, 7)
		case "moonpass_quarterly":
			expiresAt = purchasedAt.AddDate(0, 3, 0)
		case "moonpass_yearly":
			expiresAt = purchasedAt.AddDate(1, 0, 0)
		case "moonpass_monthly":
			expiresAt = purchasedAt.AddDate(0, 1, 0)
		default:
			expiresAt = purchasedAt.AddDate(0, 1, 0) // Fallback to 1 month
		}

		var subscriptionID uuid.UUID
		err = tx.QueryRowContext(ctx, `
			UPDATE subscriptions
			SET product_id = $1,
			    platform = $2,
			    status = 'active',
			    expires_at = $3,
			    latest_transaction_id = $4,
			    raw_payload = $5,
			    updated_at = now()
			WHERE user_id = $6
			  AND (
			    original_transaction_id = $4
			    OR latest_transaction_id = $4
			    OR (status = 'active' AND product_id = $1)
			  )
			RETURNING id
		`, productID, req.Platform, expiresAt, req.TransactionID, rawPayload, userID).Scan(&subscriptionID)
		if err == sql.ErrNoRows {
			subscriptionID = uuid.New()
			_, err = tx.ExecContext(ctx, `
				INSERT INTO subscriptions (id, user_id, product_id, platform, status, started_at, expires_at, original_transaction_id, latest_transaction_id, raw_payload)
				VALUES ($1, $2, $3, $4, 'active', $5, $6, $7, $7, $8)
			`, subscriptionID, userID, productID, req.Platform, purchasedAt, expiresAt, req.TransactionID, rawPayload)
		}
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to activate subscription"})
		}

		_, _ = tx.ExecContext(ctx, `DELETE FROM subscription_entitlements WHERE subscription_id = $1`, subscriptionID)

		// Insert entitlements used by app access checks and future premium audio gating.
		_, err = tx.ExecContext(ctx, `
			INSERT INTO subscription_entitlements (subscription_id, entitlement_code, entitlement_value)
			VALUES ($1, 'UNLIMITED_EPISODES', 'true'::jsonb),
			       ($1, 'PREMIUM_AUDIO', 'true'::jsonb),
			       ($1, 'NO_ADS', 'true'::jsonb)
		`, subscriptionID)
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to record subscription entitlements"})
		}
	}

	// 4. Save Purchase record
	_, err = tx.ExecContext(ctx, `
		INSERT INTO purchases (id, user_id, product_id, platform, platform_transaction_id, original_transaction_id, price, currency, status, purchased_at, raw_payload)
		VALUES ($1, $2, $3, $4, $5, $5, $6, $7, 'completed', $8, $9)
	`, purchaseID, userID, productID, req.Platform, req.TransactionID, price, currency, purchasedAt, rawPayload)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to save purchase record"})
	}

	if err := tx.Commit(); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to commit verification"})
	}

	// Fetch fresh wallet
	var wallet models.Wallet
	_ = h.DB.QueryRowContext(ctx, `
		SELECT user_id, coins, gems, free_pass, updated_at FROM wallets WHERE user_id = $1
	`, userID).Scan(&wallet.UserID, &wallet.Coins, &wallet.Gems, &wallet.FreePass, &wallet.UpdatedAt)
	sub := fetchActiveSubscription(ctx, h.DB, userID)

	// Log analytics
	_, _ = h.DB.ExecContext(ctx, `
		INSERT INTO analytics_events (user_id, event_name, properties)
		VALUES ($1, 'coin_pack_purchased', json_build_object('product_code', $2, 'platform', $3, 'price', $4))
	`, userID, req.ProductCode, req.Platform, price)

	return c.JSON(http.StatusOK, map[string]interface{}{
		"status":       "success",
		"wallet":       wallet,
		"subscription": sub,
	})
}

// GetUserSubscription details
func (h *SubscriptionHandler) GetUserSubscription(c echo.Context) error {
	userID, err := auth.GetUserID(c)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
	}

	ctx := c.Request().Context()
	var sub models.Subscription
	var prodID *uuid.UUID
	var start, expire, cancel *time.Time
	var origTx, latTx *string

	err = h.DB.QueryRowContext(ctx, `
		SELECT id, user_id, product_id, platform, status, started_at, expires_at, canceled_at, original_transaction_id, latest_transaction_id
		FROM subscriptions
		WHERE user_id = $1 AND status = 'active' AND expires_at > now()
		LIMIT 1
	`, userID).Scan(&sub.ID, &sub.UserID, &prodID, &sub.Platform, &sub.Status, &start, &expire, &cancel, &origTx, &latTx)

	if err == sql.ErrNoRows {
		return c.JSON(http.StatusOK, map[string]interface{}{
			"is_subscribed": false,
		})
	} else if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "database error"})
	}

	sub.ProductID = prodID
	sub.StartedAt = start
	sub.ExpiresAt = expire
	sub.CanceledAt = cancel
	sub.OriginalTransactionID = origTx
	sub.LatestTransactionID = latTx

	return c.JSON(http.StatusOK, map[string]interface{}{
		"is_subscribed": true,
		"subscription":  sub,
	})
}

type subscriptionQuerier interface {
	QueryRowContext(ctx context.Context, query string, args ...interface{}) *sql.Row
}

func fetchActiveSubscription(ctx context.Context, q subscriptionQuerier, userID uuid.UUID) *models.Subscription {
	var sub models.Subscription
	var prodID *uuid.UUID
	var start, expire, cancel *time.Time
	var origTx, latTx *string

	err := q.QueryRowContext(ctx, `
		SELECT id, user_id, product_id, platform, status, started_at, expires_at, canceled_at, original_transaction_id, latest_transaction_id
		FROM subscriptions
		WHERE user_id = $1 AND status = 'active' AND expires_at > now()
		ORDER BY expires_at DESC
		LIMIT 1
	`, userID).Scan(&sub.ID, &sub.UserID, &prodID, &sub.Platform, &sub.Status, &start, &expire, &cancel, &origTx, &latTx)
	if err != nil {
		return nil
	}

	sub.ProductID = prodID
	sub.StartedAt = start
	sub.ExpiresAt = expire
	sub.CanceledAt = cancel
	sub.OriginalTransactionID = origTx
	sub.LatestTransactionID = latTx
	return &sub
}

// RevenueCatWebhook handles server-side webhook updates from RevenueCat
func (h *SubscriptionHandler) RevenueCatWebhook(c echo.Context) error {
	var webhook RevenueCatWebhook
	if err := c.Bind(&webhook); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid webhook payload"})
	}

	ctx := c.Request().Context()
	appUserID, err := uuid.Parse(webhook.Event.AppUserID)
	if err != nil {
		// Log and skip, could be anonymous ID
		return c.JSON(http.StatusOK, map[string]string{"status": "ignored_non_uuid_user"})
	}

	switch webhook.Event.Type {
	case "INITIAL_PURCHASE", "RENEWAL":
		// Find product
		var productID uuid.UUID
		var productCode string
		var productArg interface{} = nil
		if err := h.DB.QueryRowContext(ctx, "SELECT id, code FROM products WHERE platform_product_id = $1", webhook.Event.ProductID).Scan(&productID, &productCode); err == nil {
			productArg = productID
		}

		var durationInterval string
		switch productCode {
		case "moonpass_weekly":
			durationInterval = "1 week"
		case "moonpass_quarterly":
			durationInterval = "3 months"
		case "moonpass_yearly":
			durationInterval = "1 year"
		default:
			durationInterval = "1 month"
		}

		res, _ := h.DB.ExecContext(ctx, fmt.Sprintf(`
			UPDATE subscriptions
			SET product_id = $1,
			    platform = 'revenuecat',
			    status = 'active',
			    expires_at = now() + interval '%s',
			    latest_transaction_id = $2,
			    updated_at = now()
			WHERE user_id = $3 AND status = 'active'
		`, durationInterval), productArg, webhook.Event.ProductID, appUserID)
		rowsAffected, _ := res.RowsAffected()
		if rowsAffected == 0 {
			_, _ = h.DB.ExecContext(ctx, fmt.Sprintf(`
				INSERT INTO subscriptions (id, user_id, product_id, platform, status, started_at, expires_at, latest_transaction_id)
				VALUES ($1, $2, $3, 'revenuecat', 'active', now(), now() + interval '%s', $4)
			`, durationInterval), uuid.New(), appUserID, productArg, webhook.Event.ProductID)
		}

	case "CANCELLATION", "EXPIRATION":
		// Deactivate subscription
		_, _ = h.DB.ExecContext(ctx, `
			UPDATE subscriptions SET status = 'expired', updated_at = now() WHERE user_id = $1
		`, appUserID)
	}

	return c.JSON(http.StatusOK, map[string]string{"status": "received"})
}
