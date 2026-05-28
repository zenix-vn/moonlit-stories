package models

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

// =========================================================================
// 1. AUTH & USER MODULE
// =========================================================================

type User struct {
	ID           uuid.UUID  `json:"id"`
	Email        *string    `json:"email,omitempty"`
	Username     *string    `json:"username,omitempty"`
	AvatarURL    *string    `json:"avatar_url,omitempty"`
	AuthProvider string     `json:"auth_provider"` // 'guest', 'email', 'google', 'apple'
	ProviderID   *string    `json:"provider_user_id,omitempty"`
	Status       string     `json:"status"` // 'active', 'banned'
	Level        int        `json:"level"`
	CreatedAt    time.Time  `json:"created_at"`
	UpdatedAt    time.Time  `json:"updated_at"`
	LastLoginAt  *time.Time `json:"last_login_at,omitempty"`
}

type UserProfile struct {
	UserID            uuid.UUID       `json:"user_id"`
	DisplayName       *string         `json:"display_name,omitempty"`
	Bio               *string         `json:"bio,omitempty"`
	CountryCode       *string         `json:"country_code,omitempty"`
	CountryName       *string         `json:"country_name,omitempty"`
	Timezone          *string         `json:"timezone,omitempty"`
	Language          string          `json:"language"`
	BirthYear         *int            `json:"birth_year,omitempty"`
	Gender            *string         `json:"gender,omitempty"`
	ReadingPreference json.RawMessage `json:"reading_preference,omitempty"`
	CreatedAt         time.Time       `json:"created_at"`
	UpdatedAt         time.Time       `json:"updated_at"`
}

type UserDevice struct {
	ID          uuid.UUID  `json:"id"`
	UserID      uuid.UUID  `json:"user_id"`
	DeviceID    string     `json:"device_id"`
	Platform    string     `json:"platform"`
	OSVersion   string     `json:"os_version"`
	AppVersion  string     `json:"app_version"`
	FCMToken    *string    `json:"fcm_token,omitempty"`
	CountryCode *string    `json:"country_code,omitempty"`
	CountryName *string    `json:"country_name,omitempty"`
	IPAddress   *string    `json:"ip_address,omitempty"`
	LastSeenAt  *time.Time `json:"last_seen_at,omitempty"`
	CreatedAt   time.Time  `json:"created_at"`
}

type UserLoginEvent struct {
	ID          uuid.UUID `json:"id"`
	UserID      uuid.UUID `json:"user_id"`
	DeviceID    string    `json:"device_id"`
	Platform    string    `json:"platform"`
	AppVersion  string    `json:"app_version"`
	IPAddress   string    `json:"ip_address"`
	CountryCode string    `json:"country_code"`
	CountryName string    `json:"country_name"`
	City        string    `json:"city"`
	Timezone    string    `json:"timezone"`
	LoginAt     time.Time `json:"login_at"`
}

// =========================================================================
// 2. CONTENT CMS & TAXONOMY MODULE
// =========================================================================

type Story struct {
	ID                uuid.UUID  `json:"id"`
	Title             string     `json:"title"`
	Slug              string     `json:"slug"`
	Description       *string    `json:"description,omitempty"`
	Hook              *string    `json:"hook,omitempty"`
	CoverURL          *string    `json:"cover_url,omitempty"`
	Language          string     `json:"language"`
	ContentRating     string     `json:"content_rating"`
	Status            string     `json:"status"` // 'draft', 'published', etc.
	FreeEpisodeCount  int        `json:"free_episode_count"`
	DefaultCoinPrice  int        `json:"default_coin_price"`
	TotalEpisodes     int        `json:"total_episodes"`
	IsFeatured        bool       `json:"is_featured"`
	IsHot             bool       `json:"is_hot"`
	IsEditorPick      bool       `json:"is_editor_pick"`
	PublishedAt       *time.Time `json:"published_at,omitempty"`
	CreatedBy         *uuid.UUID `json:"created_by,omitempty"`
	UpdatedBy         *uuid.UUID `json:"updated_by,omitempty"`
	CreatedAt         time.Time  `json:"created_at"`
	UpdatedAt         time.Time  `json:"updated_at"`

	// Joined details for API representations
	Genres []string `json:"genres,omitempty"`
	Moods  []string `json:"moods,omitempty"`
}

type Season struct {
	ID           uuid.UUID  `json:"id"`
	StoryID      uuid.UUID  `json:"story_id"`
	Title        *string    `json:"title,omitempty"`
	SeasonNumber int        `json:"season_number"`
	Description  *string    `json:"description,omitempty"`
	Status       string     `json:"status"`
	PublishedAt  *time.Time `json:"published_at,omitempty"`
	CreatedAt    time.Time  `json:"created_at"`
	UpdatedAt    time.Time  `json:"updated_at"`
}

type Episode struct {
	ID                    uuid.UUID       `json:"id"`
	StoryID               uuid.UUID       `json:"story_id"`
	SeasonID              *uuid.UUID      `json:"season_id,omitempty"`
	EpisodeNumber         int             `json:"episode_number"`
	Title                 string          `json:"title"`
	Slug                  *string         `json:"slug,omitempty"`
	ContentJSON           json.RawMessage `json:"content_json,omitempty"`
	ContentHTML           *string         `json:"content_html,omitempty"`
	ContentText           *string         `json:"content_text,omitempty"`
	WordCount             int             `json:"word_count"`
	EstimatedReadingTime  int             `json:"estimated_reading_time"` // in seconds
	IsFree                bool            `json:"is_free"`
	CoinPrice             *int            `json:"coin_price,omitempty"`
	PreviewText           *string         `json:"preview_text,omitempty"`
	Status                string          `json:"status"`
	PublishedAt           *time.Time      `json:"published_at,omitempty"`
	CreatedBy             *uuid.UUID      `json:"created_by,omitempty"`
	UpdatedBy             *uuid.UUID      `json:"updated_by,omitempty"`
	CreatedAt             time.Time       `json:"created_at"`
	UpdatedAt             time.Time       `json:"updated_at"`
}

type Genre struct {
	ID          uuid.UUID `json:"id"`
	Name        string    `json:"name"`
	Slug        string    `json:"slug"`
	Description *string   `json:"description,omitempty"`
	SortOrder   int       `json:"sort_order"`
	Active      bool      `json:"active"`
}

type Tag struct {
	ID     uuid.UUID `json:"id"`
	Name   string    `json:"name"`
	Slug   string    `json:"slug"`
	Active bool      `json:"active"`
}

type Mood struct {
	ID          uuid.UUID `json:"id"`
	Name        string    `json:"name"`
	Slug        string    `json:"slug"`
	Description *string   `json:"description,omitempty"`
	Active      bool      `json:"active"`
}

// =========================================================================
// 3. READING MODULE
// =========================================================================

type ReadingProgress struct {
	UserID          uuid.UUID `json:"user_id"`
	StoryID         uuid.UUID `json:"story_id"`
	EpisodeID       uuid.UUID `json:"episode_id"`
	ProgressPercent float64   `json:"progress_percent"`
	CurrentPosition int       `json:"current_position"`
	LastReadAt      time.Time `json:"last_read_at"`
}

type ReadingSession struct {
	ID              uuid.UUID  `json:"id"`
	UserID          uuid.UUID  `json:"user_id"`
	StoryID         uuid.UUID  `json:"story_id"`
	EpisodeID       uuid.UUID  `json:"episode_id"`
	CountryCode     *string    `json:"country_code,omitempty"`
	CountryName     *string    `json:"country_name,omitempty"`
	DeviceID        *string    `json:"device_id,omitempty"`
	Platform        *string    `json:"platform,omitempty"`
	StartedAt       time.Time  `json:"started_at"`
	EndedAt         *time.Time `json:"ended_at,omitempty"`
	DurationSeconds *int       `json:"duration_seconds,omitempty"`
	ProgressStart   *float64   `json:"progress_start,omitempty"`
	ProgressEnd     *float64   `json:"progress_end,omitempty"`
	Completed       bool       `json:"completed"`
}

type LibraryItem struct {
	ID        uuid.UUID `json:"id"`
	UserID    uuid.UUID `json:"user_id"`
	StoryID   uuid.UUID `json:"story_id"`
	Type      string    `json:"type"` // 'saved', 'completed', 'downloaded', 'history'
	CreatedAt time.Time `json:"created_at"`
}

type Bookmark struct {
	ID        uuid.UUID `json:"id"`
	UserID    uuid.UUID `json:"user_id"`
	StoryID   uuid.UUID `json:"story_id"`
	EpisodeID uuid.UUID `json:"episode_id"`
	Position  int       `json:"position"`
	Note      *string   `json:"note,omitempty"`
	CreatedAt time.Time `json:"created_at"`
}

type Highlight struct {
	ID            uuid.UUID `json:"id"`
	UserID        uuid.UUID `json:"user_id"`
	StoryID       uuid.UUID `json:"story_id"`
	EpisodeID     uuid.UUID `json:"episode_id"`
	StartPosition int       `json:"start_position"`
	EndPosition   int       `json:"end_position"`
	Text          string    `json:"text"`
	Color         string    `json:"color"`
	Note          *string   `json:"note,omitempty"`
	CreatedAt     time.Time `json:"created_at"`
}

// =========================================================================
// 4. WALLET, COINS & UNLOCK MODULE
// =========================================================================

type Wallet struct {
	UserID    uuid.UUID `json:"user_id"`
	Coins     int       `json:"coins"`
	Gems      int       `json:"gems"`
	FreePass  int       `json:"free_pass"`
	UpdatedAt time.Time `json:"updated_at"`
}

type WalletTransaction struct {
	ID           uuid.UUID       `json:"id"`
	UserID       uuid.UUID       `json:"user_id"`
	CurrencyType string          `json:"currency_type"` // 'coins', 'gems', 'free_pass'
	Amount       int             `json:"amount"`
	BalanceAfter int             `json:"balance_after"`
	Reason       string          `json:"reason"`
	RefType      *string         `json:"ref_type,omitempty"`
	RefID        *uuid.UUID      `json:"ref_id,omitempty"`
	Metadata     json.RawMessage `json:"metadata,omitempty"`
	CreatedAt    time.Time       `json:"created_at"`
}

type EpisodeUnlock struct {
	ID             uuid.UUID  `json:"id"`
	UserID         uuid.UUID  `json:"user_id"`
	StoryID        uuid.UUID  `json:"story_id"`
	EpisodeID      uuid.UUID  `json:"episode_id"`
	Method         string     `json:"method"` // 'coins', 'free_pass', 'ad', 'subscription', 'admin'
	CoinsSpent     int        `json:"coins_spent"`
	FreePassSpent  int        `json:"free_pass_spent"`
	AdSessionID    *uuid.UUID `json:"ad_session_id,omitempty"`
	SubscriptionID *uuid.UUID `json:"subscription_id,omitempty"`
	UnlockedAt     time.Time  `json:"unlocked_at"`
	ExpiresAt      *time.Time `json:"expires_at,omitempty"`
}

// =========================================================================
// 5. REWARDS MODULE
// =========================================================================

type DailyCheckin struct {
	ID           uuid.UUID `json:"id"`
	UserID       uuid.UUID `json:"user_id"`
	CheckinDate  string    `json:"checkin_date"` // YYYY-MM-DD
	StreakDay    int       `json:"streak_day"`
	RewardType   string    `json:"reward_type"`
	RewardAmount int       `json:"reward_amount"`
	CreatedAt    time.Time `json:"created_at"`
}

type UserStreak struct {
	UserID         uuid.UUID  `json:"user_id"`
	CurrentStreak  int        `json:"current_streak"`
	LongestStreak  int        `json:"longest_streak"`
	LastActiveDate *string    `json:"last_active_date,omitempty"` // YYYY-MM-DD
	UpdatedAt      time.Time  `json:"updated_at"`
}

type Task struct {
	ID          uuid.UUID `json:"id"`
	Code        string    `json:"code"`
	Title       string    `json:"title"`
	Description *string   `json:"description,omitempty"`
	Type        string    `json:"type"`
	TargetEvent string    `json:"target_event"`
	TargetValue int       `json:"target_value"`
	RewardType  string    `json:"reward_type"`
	RewardAmount int       `json:"reward_amount"`
	Active      bool      `json:"active"`
	CreatedAt   time.Time `json:"created_at"`
}

type UserTaskProgress struct {
	ID          uuid.UUID  `json:"id"`
	UserID      uuid.UUID  `json:"user_id"`
	TaskID      uuid.UUID  `json:"task_id"`
	TaskDate    string     `json:"task_date"` // YYYY-MM-DD
	Progress    int        `json:"progress"`
	CompletedAt *time.Time `json:"completed_at,omitempty"`
	ClaimedAt   *time.Time `json:"claimed_at,omitempty"`
}

// =========================================================================
// 6. SUBSCRIPTION & MONETIZATION MODULE
// =========================================================================

type Product struct {
	ID                uuid.UUID       `json:"id"`
	Code              string          `json:"code"`
	Name              string          `json:"name"`
	Type              string          `json:"type"` // 'coin_pack', 'subscription'
	Platform          *string         `json:"platform,omitempty"`
	PlatformProductID *string         `json:"platform_product_id,omitempty"`
	Price             float64         `json:"price"`
	Currency          string          `json:"currency"`
	CoinAmount        *int            `json:"coin_amount,omitempty"`
	BonusCoinAmount   *int            `json:"bonus_coin_amount,omitempty"`
	Active            bool            `json:"active"`
	Metadata          json.RawMessage `json:"metadata,omitempty"`
	CreatedAt         time.Time       `json:"created_at"`
}

type Purchase struct {
	ID                    uuid.UUID       `json:"id"`
	UserID                *uuid.UUID      `json:"user_id,omitempty"`
	ProductID             *uuid.UUID      `json:"product_id,omitempty"`
	Platform              string          `json:"platform"`
	PlatformTransactionID *string         `json:"platform_transaction_id,omitempty"`
	OriginalTransactionID *string         `json:"original_transaction_id,omitempty"`
	Price                 float64         `json:"price"`
	Currency              string          `json:"currency"`
	Status                string          `json:"status"`
	PurchasedAt           *time.Time      `json:"purchased_at,omitempty"`
	RawPayload            json.RawMessage `json:"raw_payload,omitempty"`
	CreatedAt             time.Time       `json:"created_at"`
}

type Subscription struct {
	ID                    uuid.UUID       `json:"id"`
	UserID                uuid.UUID       `json:"user_id"`
	ProductID             *uuid.UUID      `json:"product_id,omitempty"`
	Platform              string          `json:"platform"`
	Status                string          `json:"status"`
	StartedAt             *time.Time      `json:"started_at,omitempty"`
	ExpiresAt             *time.Time      `json:"expires_at,omitempty"`
	CanceledAt            *time.Time      `json:"canceled_at,omitempty"`
	OriginalTransactionID *string         `json:"original_transaction_id,omitempty"`
	LatestTransactionID   *string         `json:"latest_transaction_id,omitempty"`
	RawPayload            json.RawMessage `json:"raw_payload,omitempty"`
	CreatedAt             time.Time       `json:"created_at"`
	UpdatedAt             time.Time       `json:"updated_at"`
}

type SubscriptionEntitlement struct {
	ID             uuid.UUID       `json:"id"`
	SubscriptionID uuid.UUID       `json:"subscription_id"`
	EntitlementCode string          `json:"entitlement_code"`
	EntitlementVal json.RawMessage `json:"entitlement_value,omitempty"`
	CreatedAt      time.Time       `json:"created_at"`
}

// =========================================================================
// 7. BANNERS MODULE
// =========================================================================

type Banner struct {
	ID                       uuid.UUID       `json:"id"`
	Title                    string          `json:"title"`
	Subtitle                 *string         `json:"subtitle,omitempty"`
	ImageURL                 string          `json:"image_url"`
	DeepLink                 *string         `json:"deep_link,omitempty"`
	ActionType               *string         `json:"action_type,omitempty"`
	ActionPayload            json.RawMessage `json:"action_payload,omitempty"`
	Placement                string          `json:"placement"`
	Priority                 int             `json:"priority"`
	Active                   bool            `json:"active"`
	StartAt                  *time.Time      `json:"start_at,omitempty"`
	EndAt                    *time.Time      `json:"end_at,omitempty"`
	TargetCountryCodes       []string        `json:"target_country_codes,omitempty"`
	TargetUserType           *string         `json:"target_user_type,omitempty"`
	TargetSubscriptionStatus *string         `json:"target_subscription_status,omitempty"`
	CreatedBy                *uuid.UUID      `json:"created_by,omitempty"`
	CreatedAt                time.Time       `json:"created_at"`
	UpdatedAt                time.Time       `json:"updated_at"`
}

// =========================================================================
// 8. APP CONFIG MODULE
// =========================================================================

type AppConfig struct {
	Key         string          `json:"key"`
	Value       json.RawMessage `json:"value"`
	Description *string         `json:"description,omitempty"`
	UpdatedBy   *uuid.UUID      `json:"updated_by,omitempty"`
	UpdatedAt   time.Time       `json:"updated_at"`
}

type FeatureFlag struct {
	Key                string    `json:"key"`
	Enabled            bool      `json:"enabled"`
	RolloutPercentage  int       `json:"rollout_percentage"`
	TargetCountryCodes []string  `json:"target_country_codes,omitempty"`
	Description        *string   `json:"description,omitempty"`
	UpdatedAt          time.Time `json:"updated_at"`
}

// =========================================================================
// 9. ANALYTICS MODULE
// =========================================================================

type AnalyticsEvent struct {
	ID          uuid.UUID       `json:"id"`
	UserID      *uuid.UUID      `json:"user_id,omitempty"`
	AnonymousID *string         `json:"anonymous_id,omitempty"`
	SessionID   *string         `json:"session_id,omitempty"`
	EventName   string          `json:"event_name"`
	Properties  json.RawMessage `json:"properties,omitempty"`
	CountryCode *string         `json:"country_code,omitempty"`
	CountryName *string         `json:"country_name,omitempty"`
	Platform    *string         `json:"platform,omitempty"`
	AppVersion  *string         `json:"app_version,omitempty"`
	CreatedAt   time.Time       `json:"created_at"`
}

// =========================================================================
// 10. ADMIN USERS & RBAC MODULE
// =========================================================================

type AdminUser struct {
	ID           uuid.UUID  `json:"id"`
	Email        string     `json:"email"`
	Name         *string    `json:"name,omitempty"`
	PasswordHash string     `json:"-"`
	Status       string     `json:"status"`
	CreatedAt    time.Time  `json:"created_at"`
	UpdatedAt    time.Time  `json:"updated_at"`
	Roles        []string   `json:"roles,omitempty"`
}

type AdminRole struct {
	ID   uuid.UUID `json:"id"`
	Code string    `json:"code"`
	Name string    `json:"name"`
}

type AdminAuditLog struct {
	ID          uuid.UUID       `json:"id"`
	AdminUserID *uuid.UUID      `json:"admin_user_id,omitempty"`
	Action      string          `json:"action"`
	EntityType  string          `json:"entity_type"`
	EntityID    *uuid.UUID      `json:"entity_id,omitempty"`
	BeforeData  json.RawMessage `json:"before_data,omitempty"`
	AfterData   json.RawMessage `json:"after_data,omitempty"`
	IPAddress   *string         `json:"ip_address,omitempty"`
	CreatedAt   time.Time       `json:"created_at"`
}
