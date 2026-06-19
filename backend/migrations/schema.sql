-- Moonlit Stories Schema & Seed Data
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =========================================================================
-- 1. AUTH & USER MODULE
-- =========================================================================

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT UNIQUE,
  username TEXT,
  avatar_url TEXT,
  auth_provider TEXT NOT NULL, -- 'guest', 'email', 'google', 'apple'
  provider_user_id TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  level INT NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_login_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS user_profiles (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  display_name TEXT,
  bio TEXT,
  country_code TEXT,
  country_name TEXT,
  timezone TEXT,
  language TEXT DEFAULT 'en',
  birth_year INT,
  gender TEXT,
  reading_preference JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS user_devices (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  device_id TEXT,
  platform TEXT, -- 'ios', 'android'
  os_version TEXT,
  app_version TEXT,
  fcm_token TEXT,
  country_code TEXT,
  country_name TEXT,
  ip_address TEXT,
  last_seen_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS user_login_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  device_id TEXT,
  platform TEXT,
  app_version TEXT,
  ip_address TEXT,
  country_code TEXT,
  country_name TEXT,
  city TEXT,
  timezone TEXT,
  login_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =========================================================================
-- 2. CONTENT CMS & TAXONOMY MODULE
-- =========================================================================

CREATE TABLE IF NOT EXISTS stories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  description TEXT,
  hook TEXT,
  cover_url TEXT,
  language TEXT NOT NULL DEFAULT 'en',
  content_rating TEXT DEFAULT 'teen',
  status TEXT NOT NULL DEFAULT 'draft', -- 'draft', 'scheduled', 'published', 'archived'
  free_episode_count INT NOT NULL DEFAULT 3,
  default_coin_price INT NOT NULL DEFAULT 20,
  total_episodes INT NOT NULL DEFAULT 0,
  is_featured BOOLEAN NOT NULL DEFAULT false,
  is_hot BOOLEAN NOT NULL DEFAULT false,
  is_editor_pick BOOLEAN NOT NULL DEFAULT false,
  published_at TIMESTAMPTZ,
  created_by UUID,
  updated_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS seasons (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  story_id UUID NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
  title TEXT,
  season_number INT NOT NULL,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'draft',
  published_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(story_id, season_number)
);

CREATE TABLE IF NOT EXISTS episodes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  story_id UUID NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
  season_id UUID REFERENCES seasons(id) ON DELETE SET NULL,
  episode_number INT NOT NULL,
  title TEXT NOT NULL,
  slug TEXT,
  content_json JSONB,
  content_html TEXT,
  content_text TEXT,
  word_count INT NOT NULL DEFAULT 0,
  estimated_reading_time INT NOT NULL DEFAULT 0,
  is_free BOOLEAN NOT NULL DEFAULT false,
  coin_price INT,
  preview_text TEXT,
  audio_url TEXT,
  audio_voice_1_name TEXT NOT NULL DEFAULT 'Reader 1',
  audio_url_1 TEXT,
  audio_voice_2_name TEXT NOT NULL DEFAULT 'Reader 2',
  audio_url_2 TEXT,
  audio_voice_3_name TEXT NOT NULL DEFAULT 'Reader 3',
  audio_url_3 TEXT,
  status TEXT NOT NULL DEFAULT 'draft', -- 'draft', 'scheduled', 'published', 'archived'
  published_at TIMESTAMPTZ,
  created_by UUID,
  updated_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(story_id, episode_number)
);

-- Ensure older databases (created before audio_url was introduced) are upgraded.
ALTER TABLE IF EXISTS episodes
  ADD COLUMN IF NOT EXISTS audio_url TEXT;

-- Multi-voice narration support. audio_url remains as the legacy Reader 1 URL.
ALTER TABLE IF EXISTS episodes
  ADD COLUMN IF NOT EXISTS audio_voice_1_name TEXT NOT NULL DEFAULT 'Reader 1',
  ADD COLUMN IF NOT EXISTS audio_url_1 TEXT,
  ADD COLUMN IF NOT EXISTS audio_voice_2_name TEXT NOT NULL DEFAULT 'Reader 2',
  ADD COLUMN IF NOT EXISTS audio_url_2 TEXT,
  ADD COLUMN IF NOT EXISTS audio_voice_3_name TEXT NOT NULL DEFAULT 'Reader 3',
  ADD COLUMN IF NOT EXISTS audio_url_3 TEXT;

UPDATE episodes
SET audio_url_1 = audio_url
WHERE audio_url_1 IS NULL
  AND audio_url IS NOT NULL;

CREATE TABLE IF NOT EXISTS episode_versions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  episode_id UUID NOT NULL REFERENCES episodes(id) ON DELETE CASCADE,
  content_json JSONB,
  content_html TEXT,
  content_text TEXT,
  title TEXT,
  version_number INT NOT NULL,
  edited_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS genres (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  description TEXT,
  sort_order INT DEFAULT 0,
  active BOOLEAN DEFAULT true
);

CREATE TABLE IF NOT EXISTS tags (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  active BOOLEAN DEFAULT true
);

CREATE TABLE IF NOT EXISTS moods (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  description TEXT,
  active BOOLEAN DEFAULT true
);

CREATE TABLE IF NOT EXISTS story_genres (
  story_id UUID REFERENCES stories(id) ON DELETE CASCADE,
  genre_id UUID REFERENCES genres(id) ON DELETE CASCADE,
  PRIMARY KEY(story_id, genre_id)
);

CREATE TABLE IF NOT EXISTS story_tags (
  story_id UUID REFERENCES stories(id) ON DELETE CASCADE,
  tag_id UUID REFERENCES tags(id) ON DELETE CASCADE,
  PRIMARY KEY(story_id, tag_id)
);

CREATE TABLE IF NOT EXISTS story_moods (
  story_id UUID REFERENCES stories(id) ON DELETE CASCADE,
  mood_id UUID REFERENCES moods(id) ON DELETE CASCADE,
  PRIMARY KEY(story_id, mood_id)
);

-- =========================================================================
-- 3. READING MODULE
-- =========================================================================

CREATE TABLE IF NOT EXISTS reading_progress (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  story_id UUID NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
  episode_id UUID NOT NULL REFERENCES episodes(id) ON DELETE CASCADE,
  progress_percent NUMERIC(5,2) NOT NULL DEFAULT 0,
  current_position INT DEFAULT 0,
  last_read_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY(user_id, story_id)
);

CREATE TABLE IF NOT EXISTS reading_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  story_id UUID REFERENCES stories(id) ON DELETE CASCADE,
  episode_id UUID REFERENCES episodes(id) ON DELETE CASCADE,
  country_code TEXT,
  country_name TEXT,
  device_id TEXT,
  platform TEXT,
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at TIMESTAMPTZ,
  duration_seconds INT,
  progress_start NUMERIC(5,2),
  progress_end NUMERIC(5,2),
  completed BOOLEAN DEFAULT false
);

CREATE TABLE IF NOT EXISTS library_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  story_id UUID REFERENCES stories(id) ON DELETE CASCADE,
  type TEXT NOT NULL, -- 'saved', 'completed', 'downloaded', 'history'
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, story_id, type)
);

CREATE TABLE IF NOT EXISTS bookmarks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  story_id UUID REFERENCES stories(id) ON DELETE CASCADE,
  episode_id UUID REFERENCES episodes(id) ON DELETE CASCADE,
  position INT,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS highlights (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  story_id UUID REFERENCES stories(id) ON DELETE CASCADE,
  episode_id UUID REFERENCES episodes(id) ON DELETE CASCADE,
  start_position INT,
  end_position INT,
  text TEXT,
  color TEXT,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =========================================================================
-- 4. WALLET, COINS & UNLOCK MODULE
-- =========================================================================

CREATE TABLE IF NOT EXISTS wallets (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  coins INT NOT NULL DEFAULT 0,
  gems INT NOT NULL DEFAULT 0,
  free_pass INT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS wallet_transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  currency_type TEXT NOT NULL, -- 'coins', 'gems', 'free_pass'
  amount INT NOT NULL, -- positive or negative
  balance_after INT NOT NULL,
  reason TEXT NOT NULL, -- 'daily_checkin', 'watch_ad', 'unlock_episode', 'iap_purchase', 'admin_grant'
  ref_type TEXT, -- e.g. 'episode_unlocks', 'purchases', 'daily_checkins'
  ref_id UUID,
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS episode_unlocks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  story_id UUID NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
  episode_id UUID NOT NULL REFERENCES episodes(id) ON DELETE CASCADE,
  method TEXT NOT NULL, -- 'coins', 'free_pass', 'ad', 'subscription', 'admin'
  coins_spent INT DEFAULT 0,
  free_pass_spent INT DEFAULT 0,
  ad_session_id UUID,
  subscription_id UUID,
  unlocked_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ, -- optional, if time-limited unlock
  UNIQUE(user_id, episode_id)
);

-- =========================================================================
-- 5. REWARDS MODULE
-- =========================================================================

CREATE TABLE IF NOT EXISTS daily_checkins (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  checkin_date DATE NOT NULL,
  streak_day INT NOT NULL,
  reward_type TEXT NOT NULL,
  reward_amount INT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, checkin_date)
);

CREATE TABLE IF NOT EXISTS user_streaks (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  current_streak INT NOT NULL DEFAULT 0,
  longest_streak INT NOT NULL DEFAULT 0,
  last_active_date DATE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS tasks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code TEXT UNIQUE NOT NULL, -- e.g. 'read_10_min', 'comment_story'
  title TEXT NOT NULL,
  description TEXT,
  type TEXT NOT NULL, -- 'daily', 'weekly'
  target_event TEXT NOT NULL, -- e.g. 'read_duration', 'write_comment'
  target_value INT NOT NULL,
  reward_type TEXT NOT NULL, -- 'coins', 'free_pass'
  reward_amount INT NOT NULL,
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS user_task_progress (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  task_id UUID REFERENCES tasks(id) ON DELETE CASCADE,
  task_date DATE NOT NULL,
  progress INT NOT NULL DEFAULT 0,
  completed_at TIMESTAMPTZ,
  claimed_at TIMESTAMPTZ,
  UNIQUE(user_id, task_id, task_date)
);

-- =========================================================================
-- 6. SUBSCRIPTION & MONETIZATION MODULE
-- =========================================================================

CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code TEXT UNIQUE NOT NULL, -- pack code e.g. 'coin_pack_99', 'moonpass_monthly'
  name TEXT NOT NULL,
  type TEXT NOT NULL, -- 'coin_pack', 'subscription'
  platform TEXT, -- 'ios', 'android', 'all'
  platform_product_id TEXT,
  price NUMERIC(10,2),
  currency TEXT DEFAULT 'USD',
  coin_amount INT,
  bonus_coin_amount INT,
  active BOOLEAN DEFAULT true,
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS purchases (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  product_id UUID REFERENCES products(id) ON DELETE SET NULL,
  platform TEXT NOT NULL, -- 'apple', 'google', 'stripe'
  platform_transaction_id TEXT,
  original_transaction_id TEXT,
  price NUMERIC(10,2),
  currency TEXT,
  status TEXT NOT NULL, -- 'completed', 'refunded', 'failed'
  purchased_at TIMESTAMPTZ,
  raw_payload JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS subscriptions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id) ON DELETE SET NULL,
  platform TEXT NOT NULL, -- 'apple', 'google', 'revenuecat'
  status TEXT NOT NULL, -- 'active', 'expired', 'canceled'
  started_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  canceled_at TIMESTAMPTZ,
  original_transaction_id TEXT,
  latest_transaction_id TEXT,
  raw_payload JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS subscription_entitlements (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  subscription_id UUID REFERENCES subscriptions(id) ON DELETE CASCADE,
  entitlement_code TEXT NOT NULL, -- 'NO_ADS', 'DAILY_UNLOCKS'
  entitlement_value JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =========================================================================
-- 7. ADS REWARD MODULE
-- =========================================================================

CREATE TABLE IF NOT EXISTS ad_reward_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  provider TEXT NOT NULL, -- 'admob', 'applovin'
  placement TEXT NOT NULL, -- 'unlock_episode', 'earn_coins'
  reward_type TEXT NOT NULL, -- 'coins', 'free_pass', 'episode_unlock'
  reward_amount INT,
  episode_id UUID REFERENCES episodes(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'verified', 'expired'
  provider_event_id TEXT,
  verification_payload JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  verified_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ
);

-- =========================================================================
-- 8. BANNERS MODULE
-- =========================================================================

CREATE TABLE IF NOT EXISTS banners (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  subtitle TEXT,
  image_url TEXT NOT NULL,
  deep_link TEXT,
  action_type TEXT,
  action_payload JSONB,
  placement TEXT NOT NULL, -- 'home_top', 'discover_top', 'reader_end'
  priority INT NOT NULL DEFAULT 0,
  active BOOLEAN DEFAULT true,
  start_at TIMESTAMPTZ,
  end_at TIMESTAMPTZ,
  target_country_codes TEXT[], -- e.g. ['US', 'CA']
  target_user_type TEXT, -- 'all_users', 'new_users', 'returning_users'
  target_subscription_status TEXT, -- 'all', 'free', 'subscribers'
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS banner_impressions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  banner_id UUID REFERENCES banners(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  placement TEXT,
  country_code TEXT,
  shown_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS banner_clicks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  banner_id UUID REFERENCES banners(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  placement TEXT,
  country_code TEXT,
  clicked_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =========================================================================
-- 9. APP CONFIG MODULE
-- =========================================================================

CREATE TABLE IF NOT EXISTS app_configs (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  description TEXT,
  updated_by UUID,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS feature_flags (
  key TEXT PRIMARY KEY,
  enabled BOOLEAN NOT NULL DEFAULT false,
  rollout_percentage INT DEFAULT 100,
  target_country_codes TEXT[],
  description TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =========================================================================
-- 10. NOTIFICATION MODULE
-- =========================================================================

CREATE TABLE IF NOT EXISTS push_tokens (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  platform TEXT, -- 'ios', 'android'
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS push_templates (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code TEXT UNIQUE NOT NULL,
  title_template TEXT NOT NULL,
  body_template TEXT NOT NULL,
  deep_link_template TEXT,
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS push_campaigns (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  deep_link TEXT,
  target_type TEXT, -- 'all', 'subscribers', 'inactive'
  target_payload JSONB,
  scheduled_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'draft', -- 'draft', 'scheduled', 'sent', 'failed'
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS push_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  campaign_id UUID REFERENCES push_campaigns(id) ON DELETE SET NULL,
  token_id UUID REFERENCES push_tokens(id) ON DELETE SET NULL,
  status TEXT NOT NULL, -- 'sent', 'failed', 'opened'
  error_message TEXT,
  sent_at TIMESTAMPTZ,
  opened_at TIMESTAMPTZ
);

-- =========================================================================
-- 11. ANALYTICS MODULE
-- =========================================================================

CREATE TABLE IF NOT EXISTS analytics_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  anonymous_id TEXT,
  session_id TEXT,
  event_name TEXT NOT NULL,
  properties JSONB,
  country_code TEXT,
  country_name TEXT,
  platform TEXT,
  app_version TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS daily_user_metrics (
  metric_date DATE PRIMARY KEY,
  new_users INT DEFAULT 0,
  returning_users INT DEFAULT 0,
  active_users INT DEFAULT 0,
  subscribers INT DEFAULT 0,
  revenue NUMERIC(12,2) DEFAULT 0.00,
  ad_unlocks INT DEFAULT 0,
  coin_unlocks INT DEFAULT 0,
  subscription_starts INT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS daily_story_metrics (
  metric_date DATE,
  story_id UUID REFERENCES stories(id) ON DELETE CASCADE,
  views INT DEFAULT 0,
  readers INT DEFAULT 0,
  episode_starts INT DEFAULT 0,
  episode_completions INT DEFAULT 0,
  unlocks INT DEFAULT 0,
  revenue NUMERIC(12,2) DEFAULT 0.00,
  PRIMARY KEY(metric_date, story_id)
);

CREATE TABLE IF NOT EXISTS daily_country_metrics (
  metric_date DATE,
  country_code TEXT,
  country_name TEXT,
  new_users INT DEFAULT 0,
  returning_users INT DEFAULT 0,
  active_users INT DEFAULT 0,
  revenue NUMERIC(12,2) DEFAULT 0.00,
  PRIMARY KEY(metric_date, country_code)
);

-- =========================================================================
-- 12. ADMIN ROLE-BASED ACCESS CONTROL (RBAC) & AUDIT MODULE
-- =========================================================================

CREATE TABLE IF NOT EXISTS admin_users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT UNIQUE NOT NULL,
  name TEXT,
  password_hash TEXT, -- bcrypt hash
  status TEXT DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS admin_roles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code TEXT UNIQUE NOT NULL, -- 'super_admin', 'editor', 'writer', 'support'
  name TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS admin_user_roles (
  admin_user_id UUID REFERENCES admin_users(id) ON DELETE CASCADE,
  role_id UUID REFERENCES admin_roles(id) ON DELETE CASCADE,
  PRIMARY KEY(admin_user_id, role_id)
);

CREATE TABLE IF NOT EXISTS admin_audit_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  admin_user_id UUID REFERENCES admin_users(id) ON DELETE SET NULL,
  action TEXT NOT NULL, -- e.g. 'publish_story', 'grant_coins'
  entity_type TEXT NOT NULL,
  entity_id UUID,
  before_data JSONB,
  after_data JSONB,
  ip_address TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS story_ai_contexts (
  story_id UUID PRIMARY KEY REFERENCES stories(id) ON DELETE CASCADE,
  outline TEXT NOT NULL,
  characters JSONB NOT NULL DEFAULT '[]'::jsonb,
  setting TEXT NOT NULL,
  episode_summaries JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =========================================================================
-- INDEXES FOR PERFORMANCE
-- =========================================================================
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);
CREATE INDEX IF NOT EXISTS idx_user_login_events_login_at ON user_login_events(login_at);
CREATE INDEX IF NOT EXISTS idx_user_login_events_country ON user_login_events(country_code);

CREATE INDEX IF NOT EXISTS idx_reading_sessions_started_at ON reading_sessions(started_at);
CREATE INDEX IF NOT EXISTS idx_reading_sessions_user ON reading_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_reading_sessions_story ON reading_sessions(story_id);

CREATE INDEX IF NOT EXISTS idx_analytics_events_name_time ON analytics_events(event_name, created_at);
CREATE INDEX IF NOT EXISTS idx_analytics_events_user_time ON analytics_events(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_analytics_events_country_time ON analytics_events(country_code, created_at);

CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_subscriptions_user ON subscriptions(user_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_purchases_platform_transaction
  ON purchases(platform, platform_transaction_id)
  WHERE platform_transaction_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_episode_unlocks_user_episode ON episode_unlocks(user_id, episode_id);

-- =========================================================================
-- SEED DATA
-- =========================================================================

-- Insert Roles
INSERT INTO admin_roles (id, code, name) VALUES 
  ('11111111-1111-1111-1111-111111111111', 'super_admin', 'Super Administrator'),
  ('22222222-2222-2222-2222-222222222222', 'editor', 'Content Editor'),
  ('33333333-3333-3333-3333-333333333333', 'writer', 'Content Writer')
ON CONFLICT (code) DO NOTHING;

-- Insert default admin user: admin@moonlitstories.com / admin123 (bcrypt hash of 'admin123' is $2a$10$wNlh8gGgWk8fT9j8Xq21XOfJ7Zl.m3G3YxW9K.3sYyPeezMwqg4eq)
INSERT INTO admin_users (id, email, name, password_hash, status) VALUES
  ('00000000-0000-0000-0000-000000000000', 'admin@moonlitstories.com', 'System Admin', '$2a$10$wNlh8gGgWk8fT9j8Xq21XOfJ7Zl.m3G3YxW9K.3sYyPeezMwqg4eq', 'active')
ON CONFLICT (email) DO NOTHING;

-- Assign Admin Role
INSERT INTO admin_user_roles (admin_user_id, role_id) VALUES
  ('00000000-0000-0000-0000-000000000000', '11111111-1111-1111-1111-111111111111')
ON CONFLICT DO NOTHING;

-- Insert Taxonomy: Genres
INSERT INTO genres (id, name, slug, description, sort_order) VALUES
  ('10000000-0000-0000-0000-000000000001', 'Billionaire Romance', 'billionaire-romance', 'Stories about cold CEO billionaires, contract marriages, and secret babies', 1),
  ('10000000-0000-0000-0000-000000000002', 'Werewolf & Vampire', 'werewolf-vampire', 'Alpha mates, rejected mates, vampire princes, and pack conflicts', 2),
  ('10000000-0000-0000-0000-000000000003', 'Revenge & Rebirth', 'revenge-rebirth', 'Strong leads getting executed, reincarnating, and seeking sweet justice', 3),
  ('10000000-0000-0000-0000-000000000004', 'Cultivation Fantasy', 'cultivation-fantasy', 'Dao seekers, martial techniques, sword spirits, and immortal ascending', 4),
  ('10000000-0000-0000-0000-000000000005', 'Short Horror', 'short-horror', 'Scary late-night chat logs, haunted spaces, and creepy mysteries', 5)
ON CONFLICT (slug) DO NOTHING;

-- Insert Taxonomy: Moods
INSERT INTO moods (id, name, slug, description) VALUES
  ('20000000-0000-0000-0000-000000000001', 'I Want Drama', 'i-want-drama', 'High stakes emotional rollercoasters'),
  ('20000000-0000-0000-0000-000000000002', 'I Want Revenge', 'i-want-revenge', 'Characters returning to destroy their enemies'),
  ('20000000-0000-0000-0000-000000000003', 'I Only Have 5 Minutes', 'i-only-have-5-minutes', 'Ultra fast-paced stories for quick reads'),
  ('20000000-0000-0000-0000-000000000004', 'I Want Something Dark', 'i-want-something-dark', 'Scary, psychological, or dark romance tales')
ON CONFLICT (slug) DO NOTHING;

-- Insert App Config
INSERT INTO app_configs (key, value, description) VALUES
  ('system_config', '{
    "free_episode_count": 3,
    "default_episode_coin_price": 20,
    "home_hero_card": {
      "metric": "1000+",
      "title": "Werewolf Novels",
      "subtitle": "Romance stories · Love episodes",
      "cta_text": "Start Reading",
      "cta_deep_link": ""
    },
    "daily_checkin_rewards": [
      {"day": 1, "type": "coins", "amount": 10},
      {"day": 2, "type": "coins", "amount": 15},
      {"day": 3, "type": "coins", "amount": 20},
      {"day": 4, "type": "coins", "amount": 30},
      {"day": 5, "type": "coins", "amount": 40},
      {"day": 6, "type": "coins", "amount": 50},
      {"day": 7, "type": "free_pass", "amount": 1}
    ],
    "rewarded_ad_coin_amount": 10,
    "maintenance_mode": false,
    "min_supported_version": "1.0.0"
  }'::jsonb, 'Global application configuration variables')
ON CONFLICT (key) DO NOTHING;

-- Insert Tasks
INSERT INTO tasks (id, code, title, description, type, target_event, target_value, reward_type, reward_amount) VALUES
  ('30000000-0000-0000-0000-000000000001', 'read_10_min', 'Read for 10 Minutes', 'Spend 10 minutes reading any story tonight', 'daily', 'read_duration', 600, 'coins', 5),
  ('30000000-0000-0000-0000-000000000002', 'finish_1_ep', 'Finish 1 Episode', 'Complete reading a full episode', 'daily', 'complete_episode', 1, 'coins', 5),
  ('30000000-0000-0000-0000-000000000003', 'watch_ad', 'Watch Rewarded Ad', 'Watch a sponsored video to earn coins', 'daily', 'watch_ad', 1, 'coins', 10),
  ('30000000-0000-0000-0000-000000000004', 'comment_story', 'Leave a Review', 'Write a comment/review on any story', 'daily', 'comment', 1, 'coins', 5)
ON CONFLICT (code) DO NOTHING;

-- Insert Products
INSERT INTO products (id, code, name, type, platform, platform_product_id, price, coin_amount, bonus_coin_amount) VALUES
  ('40000000-0000-0000-0000-000000000001', 'coin_pack_99', 'Starter Coins', 'coin_pack', 'all', 'com.moonlit.coins.99', 0.99, 120, 0),
  ('40000000-0000-0000-0000-000000000002', 'coin_pack_499', 'Reader Bundle', 'coin_pack', 'all', 'com.moonlit.coins.499', 4.99, 700, 50),
  ('40000000-0000-0000-0000-000000000003', 'coin_pack_999', 'Binge Chest', 'coin_pack', 'all', 'com.moonlit.coins.999', 9.99, 1500, 150),
  ('40000000-0000-0000-0000-000000000004', 'moonpass_weekly', 'MoonPass Weekly', 'subscription', 'all', 'com.moonlit.weekly_2_99usd', 2.99, NULL, NULL),
  ('40000000-0000-0000-0000-000000000005', 'moonpass_monthly', 'MoonPass Monthly', 'subscription', 'all', 'com.moonlit.monthly_5_99usd', 5.99, NULL, NULL),
  ('40000000-0000-0000-0000-000000000006', 'moonpass_quarterly', 'MoonPass Quarterly', 'subscription', 'all', 'com.moonlit.quarterly_14_99usd', 14.99, NULL, NULL),
  ('40000000-0000-0000-0000-000000000007', 'moonpass_yearly', 'MoonPass Yearly', 'subscription', 'all', 'com.moonlit.yearly_29_99usd', 29.99, NULL, NULL),
  ('40000000-0000-0000-0000-000000000008', 'moonpass_daily', 'MoonPass Daily', 'subscription', 'all', 'com.moonlit.daily_0_99usd', 0.99, NULL, NULL)
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name,
  platform_product_id = EXCLUDED.platform_product_id,
  price = EXCLUDED.price,
  active = EXCLUDED.active;

-- Seed Stories for testing
INSERT INTO stories (id, title, slug, description, hook, cover_url, status, free_episode_count, default_coin_price, is_featured, is_hot, is_editor_pick, published_at) VALUES
  ('50000000-0000-0000-0000-000000000001', 'Reborn as the Villain Queen', 'reborn-as-the-villain-queen', 'Executed for a crime she did not commit, Queen Elara wakes up five years earlier—on the day she met the man who betrayed her. Can she rewrite history?', 'Executed for a crime she did not commit, Queen Elara wakes up five years earlier — on the day she met the man who betrayed her.', 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?q=80&w=400', 'published', 3, 20, true, true, false, now()),
  ('50000000-0000-0000-0000-000000000002', 'The Billionaire Fake Wife', 'the-billionaire-fake-wife', 'She signed a one-year marriage contract. But the cold CEO she married already knew her real identity, and he has no intention of letting her go.', 'She signed a one-year marriage contract. But the man she married already knew her real identity.', 'https://images.unsplash.com/photo-1507679799987-c73779587ccf?q=80&w=400', 'published', 3, 20, false, true, true, now()),
  ('50000000-0000-0000-0000-000000000003', 'My Werewolf Ex Is My Boss', 'my-werewolf-ex-is-my-boss', 'She escaped her alpha mate three years ago. Now, he owns the corporate empire she works for, and his wolf has caught her scent.', 'She escaped her alpha mate three years ago. Now he owns the company she works for.', 'https://images.unsplash.com/photo-1557008075-7f2c5efa4cfd?q=80&w=400', 'published', 3, 20, false, false, false, now())
ON CONFLICT (slug) DO NOTHING;

-- Assign Genres to Stories
INSERT INTO story_genres (story_id, genre_id) VALUES
  ('50000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000003'), -- Revenge & Rebirth
  ('50000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001'), -- Billionaire Romance
  ('50000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000002')  -- Werewolf & Vampire
ON CONFLICT DO NOTHING;

-- Assign Moods to Stories
INSERT INTO story_moods (story_id, mood_id) VALUES
  ('50000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002'), -- Revenge
  ('50000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000001'), -- Drama
  ('50000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000001')  -- Drama
ON CONFLICT DO NOTHING;

-- Seed Banners for app placements
INSERT INTO banners (id, title, subtitle, image_url, deep_link, placement, priority, active, start_at) VALUES
  (
    '70000000-0000-0000-0000-000000000001',
    'New Release: Villain Queen',
    'Read Episode 1 free tonight',
    'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?q=80&w=900',
    'moonlit://story/reborn-as-the-villain-queen',
    'home_top',
    5,
    true,
    now() - interval '1 day'
  ),
  (
    '70000000-0000-0000-0000-000000000003',
    '1000+ Werewolf Novels',
    'Romance stories · Love episodes',
    'https://images.unsplash.com/photo-1557008075-7f2c5efa4cfd?q=80&w=900',
    'moonlit://discover',
    'home_top',
    4,
    true,
    now() - interval '1 day'
  ),
  (
    '70000000-0000-0000-0000-000000000002',
    'Coin Sale: 20% Off Bundle',
    'Limited offer for binge readers',
    'https://images.unsplash.com/photo-1507679799987-c73779587ccf?q=80&w=900',
    'moonlit://store/coins',
    'home_mid',
    3,
    true,
    now() - interval '1 day'
  )
ON CONFLICT (id) DO NOTHING;

-- Seed Episodes for Story 1: Reborn as the Villain Queen
INSERT INTO episodes (id, story_id, episode_number, title, slug, content_text, preview_text, is_free, coin_price, word_count, estimated_reading_time, status, published_at) VALUES
  ('60000000-0000-0000-0000-000000000011', '50000000-0000-0000-0000-000000000001', 1, 'The Execution Guild', 'the-execution-guild', 'The poison tasted like sweet wine. As the executioner pressed the glass to my lips, the Duke laughed. Five years of devotion, all to end in this dungeon. "May your next life be wiser, Elara," he sneered. I closed my eyes, letting the darkness consume me.

It did not hurt. That was what surprised me most. I had imagined fire in my veins, writhing agony, the kind of death they gave traitors. Instead, it felt like slipping into a warm bath, like the lanterns of the palace slowly dimming one by one.

Five years. Five years I had served the Duke faithfully. I had abandoned my family''s name for him. I had whispered his enemies'' secrets into his ear. I had smiled at dinners where they toasted to my ruin. All of it—wasted.

"Did she really think we loved her?" The Duchess''s voice drifted through the darkness, cold as marble. "How terribly naive."

I wanted to scream. I wanted to rise from the floor and claw that smirk off her painted face. But my body would not obey. My fingers grew cold. The dungeon ceiling swam above me.

Then—silence.

Then—light.

I woke up gasping for air in my warm bed. Sunlight. Silk sheets. The scent of jasmine from the open window. I bolted upright, heart hammering so hard I could feel it in my teeth.

It was the morning of my eighteenth birthday. The day I met him. The day everything began.

My maids stood at the door, looking startled at my sudden movement. "My Lady? Are you well? You look as though you have seen a ghost."

I pressed a hand to my chest. Alive. I was alive. Young, untouched, unmarked by poison or grief.

Five years of memories crashed over me like a wave — every betrayal, every whispered secret, every tear I swallowed in silence. I remembered them all.

And for the first time in five years, I smiled.

"I am perfectly well," I said softly. "Better than I have ever been."', 'The poison tasted like sweet wine. As the executioner pressed the glass to my lips, the Duke laughed...', true, 0, 1200, 300, 'published', now()),
  ('60000000-0000-0000-0000-000000000012', '50000000-0000-0000-0000-000000000001', 2, 'Birthday Wishes', 'birthday-wishes', 'My maids rushed in, holding the crimson dress I had worn on that fateful day. The fabric was beautiful — blood-red silk threaded with gold, the kind of gown that made men stare and women whisper. In my previous life, I had worn it with pride the first time I met Duke Ravencrest.

Today, I would not touch it.

"My Lady, the Duke of Ravencrest has arrived," they cheered, faces bright with excitement. "He has brought winter roses from his greenhouse — the white ones, my lady! They say he grew them specially."

I looked in the mirror. No poison scars. No dungeon pallor beneath my eyes. Just a girl of eighteen, soft-cheeked and bright-eyed, with her whole ruinous future ahead of her — or so everyone thought.

Not me. Not anymore.

"Fetch the black lace dress," I said.

My maids exchanged glances. "But... My Lady, black is for—"

"For women who know what they want." I kept my voice light, pleasant. "And today, I want black lace."

There was a pause, and then the youngest of my maids — sweet Petra, who would one day give testimony against me at my trial — hurried to the wardrobe.

Let the Duke know that the girl he planned to deceive was already dead. What stood in her place was something older. Something patient. Something that had already seen how his story ended.

I took the black gown from Petra''s trembling hands and held it up to the light. Perfect.

"Also," I added, "please send a message to my father. Tell him I wish to meet with him before the evening banquet. Privately."

My maids looked alarmed. My father and I had not spoken privately in two years — that was another thing the Duke had arranged, quietly driving a wedge between us so I would have no one to run to.

Not this time.

"Yes, My Lady," Petra whispered.

I turned back to the mirror. In my reflection, I saw not the naive girl I had been, but the queen I was going to become. The villain queen, they would call me later. They had no idea how right they were.', 'My maids rushed in, holding the crimson dress I had worn on that fateful day...', true, 0, 1150, 285, 'published', now()),
  ('60000000-0000-0000-0000-000000000013', '50000000-0000-0000-0000-000000000001', 3, 'Red and Black', 'red-and-black', 'Duke Ravencrest stood at the bottom of the grand staircase, holding a bouquet of rare winter roses. White roses. He had always known that white roses were my mother''s favorite — which was precisely why he had chosen them. Even his gifts were calculated.

When he saw me descending the stairs in black lace instead of his beloved crimson, his smile faltered. Just for a moment. Just long enough for me to notice.

"Lady Elara." He recovered quickly, extending the roses. "You look... different tonight. I expected red."

I descended the last step and stopped, leaving exactly enough distance between us that it would look respectful but feel like a rejection. I had learned the geometry of power in my five lost years. "Red is for blood, Duke Ravencrest," I said pleasantly. "I prefer the color of a fresh grave."

A ripple of silence moved through the assembled guests nearby. I watched his jaw tighten almost imperceptibly.

"How... poetic," he said.

I smiled and walked past him without taking the roses.

I could feel his gaze on my back like a brand. Good. Let him wonder. Let him recalibrate. In my previous life, I had spent years learning to read him. Tonight, he could spend an evening trying to read me.

I was crossing toward the refreshment table when I felt a different kind of attention — sharper, more amused. I looked up.

Crown Prince Arthur stood on the upper balcony, half in shadow, a crystal glass of dark wine in his hand. He was watching me with an expression I had never seen on his face before: genuine curiosity.

In my previous life, Arthur had been a distant figure. A name attached to political arrangements, a face glimpsed at court ceremonies. He had not been present the night of my execution. Or had he?

I held his gaze for three full seconds — which was, in court terms, almost scandalous — and then turned away.

Behind me, I heard the soft scrape of his glass being set down on the balcony railing.

He was coming down.', 'Duke Ravencrest stood at the bottom of the grand staircase, holding a bouquet of rare winter roses...', true, 0, 1300, 325, 'published', now()),
  ('60000000-0000-0000-0000-000000000014', '50000000-0000-0000-0000-000000000001', 4, 'The Prince''s Gambit', 'the-princes-gambit', 'Crown Prince Arthur intercepted me at the garden fountain, appearing from behind a topiary hedge as though he had been waiting there all evening.

"A fresh grave," he said, picking up the conversation as though we had been in the middle of it. "That is quite a thing to say to a man at his own welcome banquet."

"His welcome banquet?" I raised an eyebrow. "I was under the impression it was my birthday celebration."

"And yet Ravencrest seems to be the one being celebrated." Arthur tilted his head. "Tell me, Lady Elara — in my experience, when a woman appears at her own party in mourning colors and tells her suitor she prefers graveyards, it usually means one of two things. Either she is very dramatic, or she is very dangerous."

I met his eyes. In the lamplight they were darker than I remembered from court portraits — not brown, but something closer to smoke. "Which do you think I am, Your Highness?"

He studied me for a long moment. "I think," he said slowly, "that you are the most interesting person in this room. And that Ravencrest has no idea."

I said nothing. Silence, I had learned, was a better weapon than words.

Arthur reached into his coat and produced a gold pocket watch — antique, with a crest I did not recognize on the cover. He set it on the edge of the fountain between us. "I have a proposition. Not a romantic one," he added quickly, and I caught the ghost of amusement in his voice. "A strategic one. Duke Ravencrest intends to use you against your father''s house. I intend to use Ravencrest''s ambitions against him. These goals are not incompatible."

I looked at the watch. Then at him. "And what do you offer in exchange for my cooperation?"

"Protection. Information. And the satisfaction of watching Ravencrest''s face when he realizes the girl he chose as his pawn is not a pawn at all."

A pause. The fountain murmured between us.

"Keep your watch," I said. "I do not need protection. But information — that, I will consider." I turned to go, then stopped. "One question, Your Highness. That mark on your neck — the crescent and blade. Where did you get it?"

The silence that followed was the longest of the evening.', 'Crown Prince Arthur intercepted me at the garden fountain, appearing from behind a topiary hedge...', false, 20, 1100, 275, 'published', now()),
  ('60000000-0000-0000-0000-000000000015', '50000000-0000-0000-0000-000000000001', 5, 'The Dark Treaty', 'the-dark-treaty', 'We met in the palace library at midnight. Three candles, two chairs, one purpose.

Arthur had dismissed his guard. I had told my maids I was unwell and retiring early. Neither of us mentioned these facts. Some arrangements are better left unspoken.

He spread a document between us on the reading table — small, dense, written in the private cipher used by the Crown''s intelligence division. I could read it. That surprised him; I saw it in the slight widening of his eyes. I had spent three of my five lost years learning ciphers, poisons, court law, and the weak points of every noble house in the kingdom. Knowledge is the only inheritance that cannot be taken from you.

"The terms," Arthur said, keeping his voice low. "You provide access to Ravencrest''s private correspondence — he trusts you with his household keys, yes? You feed me information about his alliance with House Maren. In exchange, I ensure your father''s house is protected from the tariff legislation Ravencrest plans to push through the winter session."

"And the mark," I said. "The crescent and blade on your neck. I want to know what it means before I sign anything."

His jaw tightened. For a moment I thought he would refuse. Then he said, "It is a brand. Given to members of an old order that predates the kingdom. The Duskwalkers. They are the reason Ravencrest wants your father''s lands — there is something buried there. Something old. Something that order has been hunting for two generations."

The words hit me like cold water.

In my previous life, I had died not knowing any of this. The Duke had used me and discarded me and I had never understood why I specifically had been chosen. But if my father''s estate held something the Duskwalkers wanted—

I looked down at the document. Then I picked up the quill.

As I signed my name, I noticed the mark on Arthur''s neck more clearly in the candlelight. A crescent moon, pierced by a blade.

The same mark that had been burned into the palm of the assassin who had poured my poison.

I finished signing and set down the quill.

"Tell me everything," I said, "about the Duskwalkers."', 'We met in the palace library at midnight. Three candles, two chairs, one purpose...', false, 20, 1400, 350, 'published', now())
ON CONFLICT (story_id, episode_number) DO NOTHING;

-- Update story 1 total_episodes count
UPDATE stories SET total_episodes = 5 WHERE id = '50000000-0000-0000-0000-000000000001';

-- =========================================================================
-- Seed Episodes for Story 2: The Billionaire Fake Wife
-- =========================================================================
INSERT INTO episodes (id, story_id, episode_number, title, slug, content_text, preview_text, is_free, coin_price, word_count, estimated_reading_time, status, published_at) VALUES
  ('60000000-0000-0000-0000-000000000021', '50000000-0000-0000-0000-000000000002', 1, 'The Contract', 'the-contract', 'The conference room smelled of expensive cologne and bad decisions.

I had been waiting forty minutes. The assistant — immaculate in a charcoal suit — had told me Mr. Kade Blackwell would arrive momentarily, and then stood there with the polished stillness of someone trained never to show emotion. I was starting to wonder if "momentarily" meant something different to billionaires.

I was not supposed to be here. I was a translator — a very good one, fluent in five languages — not someone who sat in the top-floor offices of Blackwell Industries signing documents that would upend her entire life. But my little sister''s medical bills did not care about what I was supposed to be doing. They just kept arriving, white envelopes stacked neatly on my kitchen counter like some kind of paper monument to despair.

The door opened.

Kade Blackwell was taller than his photographs. He wore no tie, the top two buttons of his shirt open, his dark hair slightly disheveled as though he''d been running his hands through it. He carried a tablet in one hand and did not look up from it as he crossed the room and sat across from me.

"Miss Chen." Not a question. Not a greeting, exactly. Just my name, stated like a fact.

"Mr. Blackwell." Two could play at that.

He set the tablet down and looked at me for the first time. His eyes were the particular gray of a storm over the Atlantic — cold and vast and entirely unmoved.

"You read the terms," he said.

"Twelve times." I folded my hands on the table. "One year. Public appearances, three per week minimum. No romantic involvement with other parties. Separate residences unless required by appearance schedule. Monthly compensation of—"

"I know what the terms say," he interrupted quietly. "I wrote them."

"Then you know they are extremely thorough."

"I know they are necessary." He leaned back in his chair, and for just a moment something moved behind those gray eyes — something that wasn''t coldness. "The board votes in fourteen months. My grandfather''s will requires that I be married for at least one year of that period. You need money. The arrangement is mutually beneficial."

I looked at the contract on the table between us. One year of my life for enough money to clear every debt, fund my sister''s surgery, and start over.

"There''s one thing that isn''t in the contract," I said.

He raised an eyebrow — just barely.

"You already know who I am," I said. "Not just as a translator. You know something about me that you haven''t shared. I''d like to know what it is before I sign."

The silence stretched between us. The city spread forty floors below the windows, indifferent and glittering.

"Sign first," Kade Blackwell said. "Then we can discuss what I know."

I picked up the pen.', 'The conference room smelled of expensive cologne and bad decisions...', true, 0, 1280, 320, 'published', now()),
  ('60000000-0000-0000-0000-000000000022', '50000000-0000-0000-0000-000000000002', 2, 'Moving In', 'moving-in', 'The penthouse was exactly what I expected and nothing like I expected.

I had expected cold. Expensive minimalism, the kind of apartment that looked like a furniture showroom and felt like living in a museum. What I found was — well, it was still cold, and it was definitely expensive. But there were books. Everywhere. Stacked on the kitchen counter, arranged in precarious towers beside the couch, three open simultaneously on the coffee table with different colored bookmarks. A man who read like that, in overlapping simultaneous conversations with multiple texts, was not simple.

The housekeeper, Mrs. Park, showed me to my wing with cheerful efficiency. Wing. I had a wing. My entire apartment from before could have fit inside the closet.

"Mr. Blackwell takes his coffee at six-thirty," Mrs. Park informed me. "He does not eat breakfast but he pretends he will. He works until two a.m. most nights and is not pleasant before eight. He keeps the study locked. He has never," she added with the particular emphasis of someone delivering vital information, "brought anyone home before."

I filed all of this away. "Thank you, Mrs. Park."

"Also," she said, pausing at the door, "your room has a lock. From the inside. Just so you know."

I blinked. She gave me a satisfied nod and left.

That evening, I found Kade standing at the floor-to-ceiling windows overlooking the city, a glass of whiskey in his hand. He had changed into dark slacks and a white shirt, sleeves rolled to the elbows. He was barefoot. Somehow, inexplicably, this made him seem more dangerous rather than less.

"The staff think we met at a conference in Vienna," he said, without turning around. "Six months ago. You were translating for a shipping negotiation. I was there for the acquisition. We have been conducting a long-distance relationship since."

"And if someone asks me about Vienna?"

"I''ll send you the briefing file."

I crossed my arms. "You have a briefing file."

"I have several." He finally turned, and in the city-light his expression was unreadable. "For different scenarios. Different guests. Different levels of scrutiny."

"You''ve done this before," I said slowly.

"No." And something in the flatness of his voice made me believe him. "But I prepare for contingencies. It is what I do." He looked at me steadily. "You asked what I know about you. Before you signed."

I had almost forgotten. "Yes."

"Your mother''s name was Wei Liling. She worked for my grandfather''s company as a research consultant, twenty-six years ago." He paused. "They had an agreement. One that was never fulfilled. I intend to correct that."

The whiskey glass caught the light as he set it on the windowsill.

"You are not a random choice, Miss Chen," he said. "You were never a random choice."', 'The penthouse was exactly what I expected and nothing like I expected...', true, 0, 1150, 288, 'published', now()),
  ('60000000-0000-0000-0000-000000000023', '50000000-0000-0000-0000-000000000002', 3, 'The First Public Appearance', 'the-first-public-appearance', 'The charity gala was on a Thursday, which seemed wrong for an event this calculated. Galas felt like Saturday things — excessive, glittering, designed for people with nowhere better to be. But the Blackwell Foundation''s annual fundraiser answered to no one''s sense of timing.

My dress had appeared in the closet that morning without explanation: midnight blue silk, cut simply enough that it cost more than a car payment, with enough structure to make me look like someone who belonged in rooms like this. I recognized the designer. I recognized what it meant that he''d had it tailored to my measurements, which were not in any public record.

He had been preparing for me. Before I even signed the contract.

I turned that thought over in my mind the entire elevator ride down.

Kade was waiting in the lobby. He looked up when I appeared, and for the duration of exactly one second, his expression did something I couldn''t name. Then it was gone, replaced by the smooth, slightly bored neutrality that was apparently his public face.

"You''ll do," he said.

"Charming," I replied.

He offered his arm — not warmly, but with the precision of someone who had thought through every gesture in advance. I took it. We walked out into the flash of cameras.

The event was everything I expected. Three hundred people who all knew each other, in a room designed to make you feel that knowing the right people was the only thing that mattered. I translated for Kade twice when a delegation from a French investment firm approached. He watched me with an expression I was starting to recognize — not quite surprise, but something adjacent to it.

"You actually are fluent," he said, during a brief pause near the windows.

"I actually am," I agreed.

"I meant—" He stopped. Started again. "Most people list skills on a résumé and then perform a diminished version when tested."

"Is that what happened with the last person you hired for something like this?"

He looked at me sharply. "There was no last person."

"Then how do you know what most people do?"

A pause. I had the distinct impression I had surprised him. Given what Mrs. Park had told me about him, I suspected that was rare.

Before he could respond, a woman in red arrived at his elbow — poised, stunning, with the particular kind of smile that meant this was not a social visit.

"Kade." Her voice was warm as summer rain. "I had no idea you were bringing a guest."

"Vivienne." His tone was entirely neutral. "Allow me to introduce my wife."

My stomach dropped — not because I hadn''t known this moment would come, but because of the way he said the word. Not like a lie. Like something he''d practiced saying so many times it had become its own kind of truth.

Vivienne''s smile did not waver. But her eyes, when they found mine, were absolutely arctic.', 'The charity gala was on a Thursday, which seemed wrong for an event this calculated...', true, 0, 1320, 330, 'published', now()),
  ('60000000-0000-0000-0000-000000000024', '50000000-0000-0000-0000-000000000002', 4, 'The Woman in Red', 'the-woman-in-red', 'Vivienne Harlow was not someone you forgot.

Over the next two hours, I assembled her profile from fragments: the way she spoke to Kade with the familiarity of old habit; the way his jaw tightened infinitesimally each time she touched his arm; the fact that every person who knew her dropped their voices slightly when they mentioned her, as though she were a weather event you talked around.

She had been his fiancée. I found that out from an elderly woman in pearls who materialized at my side near the champagne table with the specific energy of someone who wants to be useful.

"Two years ago," the woman confided. "Tremendous scandal. No one knows quite what happened. He ended it very suddenly, and she—" She lowered her voice. "She did not take it gracefully."

I looked across the room to where Vivienne was listening to Kade with a soft smile and calculating eyes.

"Thank you," I told the woman. I stored the information carefully. Every piece mattered.

On the ride home, Kade sat on the opposite side of the car and said nothing for eleven blocks. Then: "She''ll try to speak with you alone."

"I know."

"She will ask questions designed to expose inconsistencies in our story."

"I know." I turned to look at him in the passing city lights. "You should know she already asked me two while you were speaking to the Beaumont group."

Silence. "What did she ask?"

"Whether you snore. And what you ordered the first time we had dinner together."

Another pause. "What did you say?"

"I said some things are private." I looked back out the window. "And that the restaurant was in Vienna, so I doubted she knew it."

He was quiet for a long time. When I finally glanced back, he was watching me with an expression I could not read at all.

"She is not just a jealous ex-girlfriend," he said finally.

"I know that too," I replied. "She works for someone who wants to stop the board vote. Someone who knew about your grandfather''s arrangement." I paused. "The same arrangement that involves my mother."

The car stopped at a light. In the sudden silence, I heard Kade exhale slowly.

"How long have you known?" he asked.

"Since the gala started," I said. "When she looked at me the first time. She recognized the name. Not me — the name. Chen. My mother''s name. Whatever your grandfather promised hers, it involves my family."

The light changed. The city moved.

"I should have told you everything before you signed," Kade said finally.

"Yes," I agreed. "You should have." I turned to face him fully. "So now you will."', 'Vivienne Harlow was not someone you forgot...', false, 20, 1200, 300, 'published', now()),
  ('60000000-0000-0000-0000-000000000025', '50000000-0000-0000-0000-000000000002', 5, 'The Real Deal', 'the-real-deal', 'He told me everything. Or as close to everything as a man like Kade Blackwell got.

We sat in the kitchen at midnight — me with tea, him with nothing, his elbows on the counter, the city lights far below us — and he laid it out in the same precise, measured way he did everything. No drama. No softening. Just facts, delivered like documents.

Twenty-six years ago, his grandfather Marcus Blackwell had partnered with Wei Liling on a research project. Not a business project — a personal one. Something involving genetic research, a private archive, and a very specific inheritance clause buried in a trust document that had been kept sealed since Marcus''s death.

The clause, Kade explained, could only be activated by a direct descendant of Marcus Blackwell who was legally married to a descendant of Wei Liling.

"You arranged this entire marriage," I said slowly, "because of a clause in a trust."

"Yes."

"What''s in the trust?"

"Proof." He looked at his hands on the counter. "Marcus discovered something about the Blackwell board members. Financial crimes. Hidden for thirty years. The proof is sealed in the trust and can only be released when the clause is fulfilled." He paused. "The current board members are the children and grandchildren of the original criminals. They know the trust exists. They''ve been trying to access it for a decade."

"Vivienne works for them."

"She was recruited two years ago. That was why I ended the engagement." His voice was flat, but his knuckles were white against the counter. "I didn''t know at first. When I found out—"

"You ended it," I finished.

"Immediately."

I sat with that for a moment. The scale of it. The fact that my mother''s work, her name, her choices twenty-six years ago, had somehow reached forward through time and landed me here, in this kitchen, married to this man.

"The board vote," I said. "They want to remove you before you can access the trust."

"Yes. If I''m voted out, control passes to a committee they own. The trust stays sealed permanently."

"And you thought—" I stopped. Started again. "You thought marrying me would both fulfill the clause and buy you time."

"I thought it would solve multiple problems efficiently." He finally looked up. And in his eyes, for the first time, was something that was not strategy or control or careful calculation. "I did not think," he said quietly, "that it would feel like this."

The kitchen was very quiet.

"Like what?" I asked.

He did not answer immediately. When he did, it was just two words.

"Like something real."', 'He told me everything. Or as close to everything as a man like Kade Blackwell got...', false, 20, 1300, 325, 'published', now())
ON CONFLICT (story_id, episode_number) DO NOTHING;

-- Update story 2 total_episodes count
UPDATE stories SET total_episodes = 5 WHERE id = '50000000-0000-0000-0000-000000000002';

-- =========================================================================
-- Seed Episodes for Story 3: My Werewolf Ex Is My Boss
-- =========================================================================
INSERT INTO episodes (id, story_id, episode_number, title, slug, content_text, preview_text, is_free, coin_price, word_count, estimated_reading_time, status, published_at) VALUES
  ('60000000-0000-0000-0000-000000000031', '50000000-0000-0000-0000-000000000003', 1, 'The New Job', 'the-new-job', 'The elevator doors opened on the forty-second floor, and I walked straight into the worst morning of my adult life.

I''d had bad mornings before. The morning my apartment flooded. The morning I failed my licensing exam the first time. The morning three years ago when I packed a single bag, drove to the nearest bus station with no particular destination in mind, and spent eighteen hours in transit just to put enough miles between myself and Ashford Creek to breathe again.

This morning was worse than all of those.

Because standing in the glass-walled lobby of Merrick Holdings'' headquarters, in a slate-gray suit that probably cost more than my monthly rent, was Ethan Merrick.

My ex. My mate. The alpha who had walked away and let me go — or so I''d told myself, for three years, every time I woke up at 2 a.m. with my heart still trying to locate him through the bond we''d never properly severed.

He hadn''t seen me yet. He was speaking to a woman in a blue blazer, his head bent slightly toward her, listening with that particular focused attention he gave to things that mattered to him. I''d spent four years memorizing the way he listened.

I had approximately six seconds to leave before he turned around.

I turned to leave.

"Miss Calloway." His voice. God, his voice. Three years and it still landed in my chest like a key turning in a lock. "You must be the new senior copywriter."

I stopped. Turned back slowly. Arranged my face into something professional and hopefully opaque.

Ethan Merrick was looking at me with an expression I''d never seen on him before. It was not the expression of a man surprised to see his ex-girlfriend. It was the expression of a man who had known exactly who was walking through those doors.

He''d known. He''d hired me knowing.

"Mr. Merrick," I said. My voice was impressively steady. I was going to note that in my personal record of small victories.

"Welcome to Merrick Holdings." His eyes did not leave mine. In them was something complicated — something old and unresolved and very much alive. "I trust you''ll find the role... fulfilling."

Behind me, the elevator doors closed with a soft chime.

I was trapped.', 'The elevator doors opened on the forty-second floor, and I walked straight into the worst morning of my adult life...', true, 0, 1260, 315, 'published', now()),
  ('60000000-0000-0000-0000-000000000032', '50000000-0000-0000-0000-000000000003', 2, 'Still The Alpha', 'still-the-alpha', 'The first week, I was impressively professional.

I attended every meeting. I delivered my copywriting briefs ahead of schedule. I smiled at the right moments and kept my head down and did not think about the fact that Ethan Merrick''s office was forty feet from my desk and that the bond between us — the one I had spent three years trying to convince myself had faded — was apparently not dead so much as sleeping.

Now it was awake.

I felt him before I saw him, which had always been the problem. A pull at the back of my awareness, a gravitational shift when he entered a room. Wolves knew their mates by scent, by that particular biological certainty that overrode everything rational. I was not a wolf — my mother was human and my father was a mid-rank pack member — which meant I got the mate bond without the full toolkit to manage it. All the longing, none of the natural suppression.

Fun situation.

On Friday, he called me into his office.

His office was all glass and dark wood, the city spread wide behind him. He stood when I entered, which was so aggressively courteous it felt like a power move.

"Your brief on the Harmon campaign was exceptional," he said. No preamble. No asking how I was settling in.

"Thank you."

"I want you on the Nexus account." He turned to look at the city. "It''s my most important client. I need my best people on it."

"You have senior writers who''ve been here for years."

"I have competent writers who''ve been here for years." He glanced back. "You''re different."

The word landed between us with more weight than it should have. We both knew it.

"Ethan—" I started.

"Mr. Merrick, in the office." His voice was quiet, not unkind. "I know what you''re going to say. I know you think I hired you because of what we were."

"Didn''t you?"

He turned to face me fully. In the afternoon light his eyes were the gold-flecked amber I had tried so hard to forget. "I hired you," he said, "because you''re the best. And because I owe you answers I''ve been too much of a coward to give for three years." He paused. "I''m done being a coward."

I looked at him. At the man who had let me go, who had never called, who had apparently tracked me down and built me a job and waited for me to walk through his door.

"You have exactly one chance to say what you need to say," I told him. "After that, we keep this professional."

He nodded.

"I didn''t let you go," he said. "I pushed you away. Because the night you left, someone threatened your life to control me. And the only way to protect you was to make sure you were no longer something that could be used against me."

The city hummed forty-two floors below us.

"I''ve been watching over you since," he said. "From a distance. The way alphas do, when they''re trying not to be selfish."

My throat was very tight. "Three years, Ethan."

"I know." His voice broke on it, just slightly. "I know."', 'The first week, I was impressively professional...', true, 0, 1190, 298, 'published', now()),
  ('60000000-0000-0000-0000-000000000033', '50000000-0000-0000-0000-000000000003', 3, 'The Pack Problem', 'the-pack-problem', 'The problem with knowing the truth was that it did not make things simpler. It made them unbearably complicated in a new direction.

Ethan had protected me. Had watched over me from a distance for three years, refusing to let himself be close enough to be weaponized. I understood that, with the rational part of my brain. The irrational part — the part that had cried for four months straight after I left Ashford Creek — was less accommodating.

I threw myself into the Nexus account. It was the only thing I could control.

Two weeks in, a man arrived in the lobby asking for Ethan. Tall, broad-shouldered, with the particular way of moving that pack wolves had — liquid and watchful, always assessing exits. He looked at me as I passed the reception desk and his eyes changed, just slightly.

He had caught my scent. He knew who I was.

I kept walking.

That evening, staying late to finish a layout, I heard voices from Ethan''s office. His door was ajar. I was not trying to listen. I was not.

"She came back." The other man''s voice — the wolf from the lobby.

"She got a job here," Ethan said. Something careful in his voice.

"The same thing. Callum is going to find out. And when he does—"

"I know."

"He''s been waiting for her to resurface for two years, Ethan. He thinks she''s the key to the succession. If he gets to her before you—"

"He won''t." The calm in Ethan''s voice was not peaceful. It was the calm of someone who had already decided something. "She''s under my protection now. Pack law is clear."

"Pack law is also clear that you rejected the mate bond."

"I withdrew from it. That is not the same thing."

A long pause.

"You''d better be sure," the other wolf said. "Because Callum doesn''t argue. He acts."

I stood very still in the corridor. My heart was doing something complicated. Mate bond. Succession. A name I did not know — Callum — and the particular heaviness of a threat that had just become very real.

I walked back to my desk, sat down, and started making a list of everything I did not know.

It was a long list.', 'The problem with knowing the truth was that it did not make things simpler...', true, 0, 1200, 300, 'published', now()),
  ('60000000-0000-0000-0000-000000000034', '50000000-0000-0000-0000-000000000003', 4, 'Callum''s Visit', 'callums-visit', 'Callum arrived on a Tuesday, which felt appropriately inconvenient.

I had just handed in the final Nexus campaign files and was waiting for Ethan''s sign-off when the temperature in the office changed. Not literally — the AC was running perfectly — but the energy shifted, the way it does when something large and certain enters a room.

He was maybe thirty-five, copper-haired, with the kind of physical presence that had nothing to do with size and everything to do with expectation. Like a man who had never walked into a room that wasn''t already his.

He found me immediately. Eyes like amber, sharper than Ethan''s — less warm. The look of someone who identified assets and obstacles.

"You must be Maya Calloway," he said. Just my name, delivered like a claim.

"I must be," I agreed.

He smiled. It did not reach his eyes. "I''ve been looking for you."

"I wasn''t hiding." Which was technically true. I had just moved to a city twelve hours away and built an entirely new life.

"No." He tilted his head. "Ethan was hiding you. There''s a difference." He glanced toward the glass office where I could see Ethan''s silhouette on a call. "He''s alpha of Ashford Creek in name only, you know. The pack hasn''t formally ratified the succession. Until they do, any pack member can challenge his authority." He paused. "Including by claiming a prior right to his mate."

The word hung in the air. His mate. It was not how Callum would experience the bond — he wasn''t my mate, the connection didn''t work that way, biology was not that cruel. But pack law, apparently, was.

"I''m not a member of Ashford Creek pack," I said.

"Your father was." His smile sharpened. "Blood inheritance. It''s in the pack charter." He leaned in, dropping his voice. "I''m not your enemy, Maya. I''m offering you a choice that Ethan never gave you. Come back to Ashford Creek. Recognize the rightful succession. Live freely, under legitimate pack protection. No more running."

"And if I don''t?"

"Then Ethan declares formal mate bond, formally reclaims alpha authority, and we have a very public, very messy succession conflict." He straightened. "Which he might win. Or might not. These things can go either way."

He was halfway to the elevator when Ethan''s office door opened.

Ethan stepped out. He looked at Callum, then at me. Something moved through his expression that was not quite anger and not quite fear — the look of a man watching something he''d hoped to prevent.

"Callum." His voice was very quiet.

"Ethan." Callum pressed the elevator button. "Nice office. I''ll see you in Ashford Creek."

The doors closed.

In the sudden silence, Ethan crossed the floor toward me. He stopped two feet away. His eyes searched my face.

"How much did he tell you?" he asked.

"Enough," I said. "Ethan — what is it that my father actually was in the Ashford Creek pack?"

He closed his eyes briefly. When he opened them, the gold in his irises was brighter than usual. "Beta," he said. "Your father was the pack''s beta. Which means by inheritance law—"

"I''m the beta''s heir," I finished. "Which means I have a vote in the succession."

"Yes."

I absorbed this. Somewhere in the city below us, traffic moved, oblivious. "You knew this when you hired me."

"I knew it when I found you three years ago," he said. "It was one more reason to keep you away. And one more reason Callum wants to get to you first."

I looked at him for a long time. "You should have told me everything. From the beginning."

"I know," he said. For the second time since I''d come back, his voice broke slightly. "I was afraid of what you''d do if you knew how complicated it was."

"Run again?" I asked.

"Yes."

I considered my options. Callum''s invitation. Ethan''s history of protecting me without telling me. The bond that was absolutely not sleeping anymore.

"Tell me everything," I said. "And this time, leave nothing out."', 'Callum arrived on a Tuesday, which felt appropriately inconvenient...', false, 20, 1350, 338, 'published', now()),
  ('60000000-0000-0000-0000-000000000035', '50000000-0000-0000-0000-000000000003', 5, 'The Alpha Decision', 'the-alpha-decision', 'We were in his apartment by nine, which was not romantic and very much not the point. Mrs. Kim, his housekeeper, brought coffee and biscuits with the practiced efficiency of someone who had long stopped being surprised by anything Ethan Merrick did at inconvenient hours.

He told me everything.

Ashford Creek pack had been in flux since his father''s death two years ago. By pack law, the alpha succession required ratification by the senior pack members — including the beta''s vote. Without that ratification, Ethan held the role in practice but not in law. Callum, who was a distant cousin and had spent two years building alliances among the dissenting pack factions, was positioning to force a formal challenge.

The beta''s heir''s vote would be decisive. My vote.

"You could have just asked me to vote for you," I said.

"I didn''t want your vote." He wrapped his hands around his coffee mug. "I wanted — I want — you to come back for the right reasons. Not because I engineered it."

"You hired me at your company."

"Yes." He didn''t look away. "That was — the line between engineering and hoping. I''m aware."

I looked at him across the kitchen table. The man who had driven me away to protect me. Who had watched over me from a distance for three years. Who had clearly been making terrible decisions on my behalf with, apparently, excellent intentions.

"Here is what I want to know," I said. "If I vote for you. If I come back to Ashford Creek. If the succession is ratified and the pack settles." I paused. "What happens to us?"

He was very still.

"What do you want to happen?" he asked quietly.

I thought about the bond — the pull that had never faded, that had gotten louder every day since I walked into that lobby. I thought about three years of trying to call it grief and finding it was something else entirely. Something with teeth. Something that didn''t let go.

"I want answers before decisions," I said. "I want to know who threatened me three years ago and why. I want to know what my father knew about this pack that he never told me. And I want—" I stopped.

"What?" His voice was barely above a whisper.

"I want you to stop protecting me from information and let me make my own choices." I met his eyes. "Including choices about you."

The gold in his irises flared.

Outside the windows, the city was beginning to quiet. Somewhere across the skyline, I imagined Callum in a hotel room, making his own plans for tomorrow.

Tomorrow could wait.

Tonight, for the first time in three years, Ethan Merrick reached across a kitchen table and covered my hand with his.

Neither of us said anything. We did not need to.

The bond, patient as winter, settled warm around us like it was finally, finally home.', 'We were in his apartment by nine, which was not romantic and very much not the point...', false, 20, 1280, 320, 'published', now())
ON CONFLICT (story_id, episode_number) DO NOTHING;

-- Update story 3 total_episodes count
UPDATE stories SET total_episodes = 5 WHERE id = '50000000-0000-0000-0000-000000000003';

-- =========================================================================
-- Seed Story 4: The Billionaire''s Hidden Heir
-- =========================================================================
INSERT INTO stories (id, title, slug, description, hook, cover_url, status, free_episode_count, default_coin_price, is_featured, is_hot, is_editor_pick, published_at) VALUES
  ('50000000-0000-0000-0000-000000000004', 'The Billionaire''s Hidden Heir', 'the-billionaires-hidden-heir',
   'Sophia Chen thought she was applying for a nanny position. She never expected her new employer to be the man she spent one forbidden night with five years ago — or that he would recognize their son''s eyes the moment he opened the door.',
   'She thought it was just a nanny job. Then she saw who answered the door.',
   'https://images.unsplash.com/photo-1560472354-b33ff0c44a43?q=80&w=400',
   'published', 3, 20, false, true, true, now())
ON CONFLICT (slug) DO NOTHING;

INSERT INTO story_genres (story_id, genre_id) VALUES
  ('50000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000001')
ON CONFLICT DO NOTHING;

INSERT INTO story_moods (story_id, mood_id) VALUES
  ('50000000-0000-0000-0000-000000000004', '20000000-0000-0000-0000-000000000001')
ON CONFLICT DO NOTHING;

INSERT INTO episodes (id, story_id, episode_number, title, slug, content_text, preview_text, is_free, coin_price, word_count, estimated_reading_time, status, published_at) VALUES
  ('60000000-0000-0000-0000-000000000041', '50000000-0000-0000-0000-000000000004', 1, 'The Interview', 'the-interview', 'The address led me to a brownstone in the Upper West Side that had the particular quiet of old money. Not the flashy silence of new wealth — no security cameras at the gate, no intercom with a camera, no polished brass plaque announcing that someone important lived here. Just a house, large and handsome and discreet, in the way that only things that have never needed to prove themselves can be.

I adjusted Noah''s collar for the third time. He was four and a half and had opinions about collars. "It''s scratchy," he informed me, for the record.

"I know, baby. Ten minutes."

The job listing had been specific: live-in nanny, bilingual English-Mandarin preferred, full-time. Start date flexible. The agency had given me the address and told me the employer was private, which in New York meant wealthy and which I had long since stopped being surprised by.

The door opened before I could ring the bell.

The man who opened it was not the household assistant I had expected. He was in a dark suit, no tie, reading something on his phone, and he had the distracted half-attention of someone who opens doors on autopilot. He started to speak — probably something like come in, the interview is through here — and then he looked up.

The phone dropped a half-inch in his hand.

Five years. Five years and the recognition was instant and complete, the kind that bypassed all the careful layers of forgetting I''d built and landed straight in my chest.

Liam Park.

He looked the same and entirely different. The same structured jaw, the same dark eyes, the same quality of attention that had made me feel, at twenty-three and very much out of my depth at a conference party, like I was the only person in the room. Older now. The kind of older that suited men with good bones.

He was looking at Noah.

Noah, who had my nose and his father''s eyes and no idea about any of this.

"I—" I said.

"Ms. Chen," he said. His voice had always been like that — low, precise, with a stillness underneath it. "Please come in."

He stepped back from the door. His expression gave away nothing. But his eyes, when they found mine over Noah''s head, said everything.

He knew. He had known from the moment he looked at his son''s face.

I walked inside.', 'The address led me to a brownstone in the Upper West Side that had the particular quiet of old money...', true, 0, 1250, 313, 'published', now()),
  ('60000000-0000-0000-0000-000000000042', '50000000-0000-0000-0000-000000000004', 2, 'Five Years', 'five-years', 'The housekeeper — Mrs. Zhou, warm and efficient — took Noah to the garden with a plate of fruit and the promise of a sandbox, leaving Liam and me in the study.

It was a good room for difficult conversations. Books on three walls, two leather chairs angled toward each other, afternoon light from a tall window. The kind of room designed for truth.

"Sit," he said. Not unkind. Just quiet.

I sat.

He did not. He moved to the window and stood there for a moment, hands in his pockets, looking at the garden where Noah was already investigating the sandbox with the focused enthusiasm of a child who had never met dirt he didn''t like.

"His name," Liam said.

"Noah."

"How old?"

"Four and a half."

He did the math in the silence that followed. We both knew the math.

"You didn''t contact me," he said.

"I didn''t know how to find you." Which was true and also not complete. "I tried once. After I found out. The number I had was disconnected. The conference organizers said you''d listed under a company name that dissolved the following year." I paused. "And I was — I was twenty-three and terrified and I made a choice."

He turned from the window. "To raise him alone."

"To raise him," I said carefully. "I have an excellent support system. My mother, my sister. He''s thriving. He''s happy. He is—" My voice was steady, I was proud of that. "He is my whole world, Mr. Park."

"Liam." Something moved through his expression — not anger, something more complicated. "Please. Given the circumstances."

"Liam." The name felt strange after five years of not allowing myself to use it even in my own head.

He came and sat in the chair across from me. In the light I could see the faint shadows under his eyes — the mark of someone who slept shorter than he wanted to, who carried something. "I need to ask you something and I need you to answer honestly."

"I''ve been honest."

"Were you aware of who I was when you applied for this position?"

I looked at him steadily. "No. The listing didn''t include your name. I needed the work. My translation contracts have been slow this year and I have—" I stopped. "I have responsibilities."

He nodded slowly. "I believe you."

"Why?"

He glanced toward the window, toward Noah. "Because of the way you looked when I opened the door. You looked like someone who had seen a ghost." He paused. "And because whatever you may have chosen five years ago, you''ve clearly been doing your best for him."

The afternoon was very quiet around us.

"I know this is complicated," I said. "You don''t have to — I''m not asking for anything. I applied for a job. If you want to give it to someone else, I completely understand."

"I''m giving it to you," he said immediately. "But not just because I need a nanny."

I looked at him.

"He''s my son," Liam said. "And I''ve missed four and a half years." His voice was very controlled but something underneath it was not controlled at all. "I''d like to not miss any more."', 'The housekeeper — Mrs. Zhou, warm and efficient — took Noah to the garden with a plate of fruit...', true, 0, 1180, 295, 'published', now()),
  ('60000000-0000-0000-0000-000000000043', '50000000-0000-0000-0000-000000000004', 3, 'Living Arrangements', 'living-arrangements', 'Noah liked Liam immediately, which was either heartwarming or the universe testing me.

By the end of the first week, they had established a routine. Liam worked mornings from his home office — I learned he was the CEO of Park Capital, which explained the brownstone and the careful, watchful quality he''d had even at twenty-eight at a conference networking party. Afternoons, if he could manage it, he emerged for whatever Noah was doing: sandbox, picture books, the highly specific game Noah had invented that involved cushion forts and dragon rules that changed depending on Noah''s mood.

I watched them and tried not to feel anything about it.

I did not entirely succeed.

The complications were predictable and arrived on schedule. His mother called every evening and I could hear her voice from across the house — warm and worried and landing frequently on the phrase "the situation." His sister, Mina, appeared in person on Thursday. She was sharp-eyed and kind and looked at me the way women look at complications they haven''t decided whether to like yet.

"He was different after that conference," Mina told me, in the kitchen, out of earshot of everyone else. "Distracted in a way he never is. He doesn''t get distracted."

I busied myself with Noah''s lunch. "That must have been a difficult time for him."

"He looked for you," Mina said. "For about six months. Found dead ends everywhere." She paused. "I''m telling you this because I want you to understand that his reaction to this situation is not — he is not a man who walked away. He tried to find his way back."

I looked up. "Why are you telling me this?"

"Because he won''t," she said simply. "He thinks if he tells you that, it''ll look like pressure. He''s trying very hard not to pressure you." She picked up her coffee. "It''s making him insane, for the record."

That evening, after Noah was asleep, Liam knocked on my sitting room door. "I made tea," he said. "If you want."

We sat in the kitchen with our cups and the kind of silence that has learned to be comfortable without quite meaning to.

"Mina likes you," he said finally.

"She interviewed me very thoroughly."

"She does that." A hint of something almost like warmth. "She vetted my last three board members the same way." He looked at his cup. "Sophia. I want you to know — this arrangement is yours to define. What you need, what you''re comfortable with. I meant what I said about wanting to be in his life. But I''m not trying to rewrite yours."

I thought about what Mina had said. Six months of looking.

"What if," I said slowly, "I don''t entirely know what I want yet?"

"Then we take time," he said. "We have time."

Outside, the city hummed. Noah slept down the hall. The tea went warm between us.

"Tell me about him," Liam said quietly. "Everything I missed. From the beginning."

So I did.', 'Noah liked Liam immediately, which was either heartwarming or the universe testing me...', true, 0, 1200, 300, 'published', now()),
  ('60000000-0000-0000-0000-000000000044', '50000000-0000-0000-0000-000000000004', 4, 'The Board Meeting', 'the-board-meeting', 'The letter arrived on a Monday, which in my experience was when bad things preferred to announce themselves.

It was from Park Capital''s board of directors — which I only knew because Liam left it on the kitchen counter, face-up, clearly not in the spirit of secrecy. Either he trusted me or he wanted me to see it. With Liam, I was learning, these were sometimes the same thing.

The relevant paragraph: ...the existence of an unrecognized child and the nature of the current domestic arrangement may present reputational concerns to investors. The board respectfully requests clarification of Mr. Park''s personal situation before the Q3 stakeholder presentation...

I read it three times.

"The board is worried about optics," I said, when Liam came in.

"The board is worried about several things," he said mildly. He poured coffee. "They''ve been looking for leverage since last year''s acquisition. This is opportunistic."

"But it''s a real problem."

"Not in the way they intend it." He turned. "Sophia. I need to tell you something, and I want you to hear it completely before you respond."

I sat.

"I want to publicly acknowledge Noah," he said. "Not for the board — or not only for the board. I want him to have my name, if you''ll allow it. I want to be his father in every way that matters, not just the ones I can do quietly." He paused. "And I want to handle the board situation by giving them nothing to leverage. Which means being transparent about what our situation actually is."

"And what is our situation, actually?"

He set down his coffee cup. "I don''t know yet. I know what I''d like it to be." He looked at me steadily. "I''d like to have the chance to do this properly. Court you, in whatever modern version of that looks like. Take time. Not pretend to be something we''re not for the board''s convenience, but build something real, if you''ll give me the chance."

The kitchen was very quiet.

Noah''s laugh drifted in from the garden, where Mrs. Zhou was teaching him to water plants.

"You know," I said slowly, "for a man who runs a major capital firm, you''re surprisingly bad at being strategic about things you actually want."

Something moved through his expression. "I know."

"It''s—" I stopped. Started again. "It''s actually one of the things I''ve noticed. That you''re very careful and very capable about everything except the things that matter to you personally."

"Yes," he said quietly.

I looked at my hands on the table. Then at him.

"Yes," I said.

He blinked.

"Yes, you can acknowledge Noah. Yes, I''ll give you the chance." I met his eyes. "But Liam — we do it honestly. Not for the board. Not for optics. Because it''s what''s right and because—" I paused. "Because Noah deserves a father who chose to be there. And maybe because I''d like to find out what this could be."

Outside, Noah shouted in delight about a worm.

Liam exhaled slowly. And then, for the first time since I''d walked back into his life, he smiled — not the careful professional smile I''d seen in the office, but something genuine, something that reached his eyes.

"Okay," he said. "Yes. Honestly."', 'The letter arrived on a Monday, which in my experience was when bad things preferred to announce themselves...', false, 20, 1350, 338, 'published', now()),
  ('60000000-0000-0000-0000-000000000045', '50000000-0000-0000-0000-000000000004', 5, 'The Press Conference', 'the-press-conference', 'Liam addressed the board on a Wednesday afternoon, with me in the room and Noah with Mrs. Zhou on the third floor.

He was precise and brief. He had a son. He was committed to being present in his son''s life. He was developing a personal relationship with his son''s mother, which was a private matter. Any attempt to use this situation as corporate leverage would be addressed as the hostile action it represented.

Four of the seven board members looked at their shoes.

Outside the boardroom, in the corridor, he stopped and turned to me. "Well," he said.

"You were terrifying," I said. "It was impressive."

"Was it too much?"

"For the board? No." I paused. "For me? Possibly."

He was quiet for a moment. Then he said: "I was thinking — Noah asked this morning if you''d always be there. If this was home now."

My chest tightened. "What did you say?"

"I said that was something we were working on." He met my eyes. "Is that — the right answer?"

I thought about the kitchen and the tea going warm between us. I thought about six months of searching and dead ends. I thought about a sandbox in a garden in the Upper West Side, and a boy who had his father''s eyes, and the fact that life sometimes circles back to things you''d thought were behind you.

"That''s the right answer," I said.

He exhaled.

"Sophia." He said my name like it was something he''d been holding carefully. "Whatever pace you need. Whatever form this takes. I just — I want you to know that I''m not going anywhere. Not this time."

Down the corridor, we could hear the distant sound of Noah laughing at something Mrs. Zhou had said.

"Neither am I," I said.

And that, it turned out, was enough to start with.', 'Liam addressed the board on a Wednesday afternoon, with me in the room and Noah with Mrs. Zhou on the third floor...', false, 20, 1200, 300, 'published', now())
ON CONFLICT (story_id, episode_number) DO NOTHING;

UPDATE stories SET total_episodes = 5 WHERE id = '50000000-0000-0000-0000-000000000004';

-- =========================================================================
-- Seed Story 5: The Last Sword Saint
-- =========================================================================
INSERT INTO stories (id, title, slug, description, hook, cover_url, status, free_episode_count, default_coin_price, is_featured, is_hot, is_editor_pick, published_at) VALUES
  ('50000000-0000-0000-0000-000000000005', 'The Last Sword Saint', 'the-last-sword-saint',
   'Wei Liang was the weakest disciple in the Celestial Blade Sect — until the day he discovered a shattered divine sword buried beneath the sect ruins, and with it, the memory of the master who had hidden it there: himself, in a past life.',
   'The weakest disciple. The forgotten ruins. The sword that remembered him.',
   'https://images.unsplash.com/photo-1578662996442-48f60103fc96?q=80&w=400',
   'published', 3, 20, true, false, true, now())
ON CONFLICT (slug) DO NOTHING;

INSERT INTO story_genres (story_id, genre_id) VALUES
  ('50000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000004')
ON CONFLICT DO NOTHING;

INSERT INTO story_moods (story_id, mood_id) VALUES
  ('50000000-0000-0000-0000-000000000005', '20000000-0000-0000-0000-000000000002'),
  ('50000000-0000-0000-0000-000000000005', '20000000-0000-0000-0000-000000000001')
ON CONFLICT DO NOTHING;

INSERT INTO episodes (id, story_id, episode_number, title, slug, content_text, preview_text, is_free, coin_price, word_count, estimated_reading_time, status, published_at) VALUES
  ('60000000-0000-0000-0000-000000000051', '50000000-0000-0000-0000-000000000005', 1, 'The Broken Disciple', 'the-broken-disciple', 'In the Celestial Blade Sect, there were three ways to be nobody.

The first was to be poor. The second was to be talentless. Wei Liang had achieved both with what his fellow disciples called remarkable efficiency. His spirit root was weak — so weak that the sect''s intake examiner had paused for a long time before writing his name in the registry, and even then had done so in lighter ink than everyone else, as though expecting to erase it.

The third way to be nobody was worse: to be an orphan with no backing, no master willing to claim you, no older sect brother to cover for your mistakes. Wei Liang had that too.

He survived by being useful. Sweeping courtyards. Hauling water. Repairing tool handles. The outer sect accepted him the way a kitchen accepts a cockroach — not warmly, but with the resigned acknowledgment that some things simply persist regardless of your opinion of them.

He was seventeen when everything changed.

It began with the ruins.

The old section of the sect grounds — the part that had collapsed during some forgotten disaster three generations ago — was forbidden. Not dramatically forbidden, with posted guards and formal proclamation. Just quietly forbidden in the way that dangerous places accumulate, until younger disciples stopped walking near it and older ones stopped explaining why.

Wei Liang had been avoiding it for four years. Then one evening, chasing a runaway spirit crane whose escaped condition he would definitely be blamed for, he found himself at the edge of the rubble field at dusk, the crane somewhere ahead of him in the shadows between fallen stones.

He went in.

The crane had settled on top of what appeared to be a stone seal, half-buried in the ground, its surface so worn by time that the carvings on it were barely visible. The crane pecked at it with the interest of an animal that knows something a human does not.

Wei Liang crouched and brushed away the debris.

The seal hummed.

Not audibly. Not the way a sound fills a room. The hum went through his hands, up his arms, into his chest, and settled behind his sternum like a key finding a lock it had been searching for across a very long time.

Then the ground cracked open, and the sword came up.

It was shattered — blade in three pieces, hilt wrapped in something that had once been leather and was now mostly memory. It should have been junk. Old junk, forgotten and worthless.

But when Wei Liang''s hand closed around the hilt, seventeen years of forgotten things rushed through him like a tide.

He had been here before. He had hidden this sword here. He had died here. And his name, the name beneath Wei Liang, the name that the three broken pieces of this blade still knew—

Was Sword Saint Qian Yen. The greatest swordsman in the history of the Celestial Blade Sect.

The crane had flown to his shoulder and was watching him with enormous golden eyes.

"Well," Wei Liang said, to the sword and the ruins and the accumulated weight of a life he had apparently already lived. "That explains a great deal."', 'In the Celestial Blade Sect, there were three ways to be nobody...', true, 0, 1350, 338, 'published', now()),
  ('60000000-0000-0000-0000-000000000052', '50000000-0000-0000-0000-000000000005', 2, 'The Sword''s Memory', 'the-swords-memory', 'He did not tell anyone.

This was, in retrospect, the most important decision he made in the weeks following the discovery. The urge to tell someone — the crane, at minimum — was significant. But Wei Liang had spent four years being dismissed and overlooked and quietly written off, and he had developed a corresponding instinct for when information was more useful held than shared.

He carried the three pieces of the broken sword back to his quarters in the outer disciple dormitory, wrapped in his spare cultivation robe. He hid them under a loose floorboard he''d identified during his first week for exactly this kind of contingency.

Then he sat on his sleeping mat and waited to see what the memories did.

They came in fragments, the way dreams dissolve in the morning: impressions first, then images, then sounds, then — eventually — coherence. He had been Qian Yen. Forty years of a life already lived, compressed into a series of flashes: the weight of a full sword in a hand that had never doubted it; the cold clarity of the Sword Heart technique, which his current cultivation base would have laughed at the idea of achieving; the face of a man in black robes who had come to him three days before the disaster that had destroyed this section of the sect.

That man. That was the thing that mattered.

Qian Yen had known, three days before the collapse, that it was coming. He had known because the man in black had told him — not as a warning but as a threat. Submit the Celestial Scroll of Sword Origins, or the sect will suffer.

Qian Yen had refused. He had hidden the scroll and the sword and sealed them into the ruins, and then he had died buying time for the evacuation of the outer disciples. And the man in black had never found what he was looking for.

Wei Liang opened his eyes. The dormitory around him was dark; hours had passed. Somewhere in the building, someone was snoring. From outside came the faint sound of night insects.

The Celestial Scroll of Sword Origins was still here. Somewhere in the ruins, in a secondary seal. He knew, with a certainty that bypassed logic and went straight to muscle memory, exactly where.

He also knew that the man in black — or whoever he worked for — had not given up. They had simply been waiting for the seal to weaken with time.

Which it was now doing.

Which was why the sword had come up when Wei Liang touched the outer seal.

He looked at the floorboard concealing his previous life''s broken blade.

He had three pieces of a shattered divine sword, no master, no cultivation base worth mentioning, and the complete technical memories of a Sword Saint.

The situation was not ideal. It was also, he thought, something like an opportunity.

"Alright," he said to the sleeping dormitory. "Let''s begin."', 'He did not tell anyone. This was, in retrospect, the most important decision he made...', true, 0, 1280, 320, 'published', now()),
  ('60000000-0000-0000-0000-000000000053', '50000000-0000-0000-0000-000000000005', 3, 'First Sword Steps', 'first-sword-steps', 'Relearning things you already know is a particular kind of frustrating.

Wei Liang''s current body had a weak spirit root, mediocre cultivation base, and four years of physical conditioning designed for hauling water rather than sword work. Qian Yen''s memories included techniques that required a cultivation level Wei Liang would not achieve for years, reflexes built over decades of daily practice, and a physical frame that had been at its peak when the sword was sealed.

He could not do what he remembered. Not yet. Not even close.

What he could do was practice the foundation forms — the basic thirty-six movements of the Celestial Blade method, which he had drilled ten thousand times in a life he technically hadn''t lived yet. His body did not have the strength for them. His spirit root could not channel the required qi flow.

But the pattern was correct. The alignment, the weight distribution, the geometry of each stance — all of it landed with the precision of something deeply remembered rather than newly learned.

On the third morning, Elder Fen caught him practicing.

Elder Fen was a minor figure in the sect — responsible for outer disciple records, old enough that most disciples forgot he was there. He had passed Wei Liang in the courtyard, stopped, and stared.

"Where did you learn that form?" he asked.

Wei Liang stopped mid-movement. "I... studied the manuals in the outer library, Elder."

Fen''s expression was unreadable. "That form has not been in the outer library for sixty years. It was removed after the collapse of the old section." He was quiet for a moment. "Show me the next sequence."

Wei Liang showed him.

The elder''s face cycled through several expressions in quick succession. Then he said, very carefully: "Come to my study this evening."

He turned and walked away without another word.

Wei Liang stood in the empty courtyard and considered the mathematics of the situation. If Fen reported this to the senior elders, questions would be asked. If questions were asked, the ruins would be investigated. If the ruins were investigated...

But Fen had not gone immediately to the senior elders. He had said this evening.

Which meant he wanted information first.

Which meant he knew something.

The crane landed on Wei Liang''s shoulder, its golden eyes judgmental in the specific way of animals who find humans unnecessarily complicated.

"I know," Wei Liang told it. "Let''s see what the elder knows first."', 'Relearning things you already know is a particular kind of frustrating...', true, 0, 1240, 310, 'published', now()),
  ('60000000-0000-0000-0000-000000000054', '50000000-0000-0000-0000-000000000005', 4, 'The Elder''s Secret', 'the-elders-secret', 'Elder Fen''s study was small and unremarkable and contained, behind a false panel in the bookshelf that Wei Liang noted with professional appreciation, a sealed wooden case that smelled faintly of old lacquer and a cultivation method he recognized.

The Sword Origins method. A simplified version, a copy, not the original scroll. But a copy made with enough care that it retained some resonance.

Fen was watching him when he turned around. "You can sense it," the old man said. Not a question.

"Yes."

Fen sat. The lamp between them was low, which in Wei Liang''s experience of humans meant either intimacy or caution. Possibly both. "My teacher''s teacher was an outer disciple during the collapse," Fen said. "He survived because Sword Saint Qian Yen held the eastern passage until the evacuation was complete. He saw Qian Yen die." He paused. "He also saw Qian Yen seal the sword and the scroll into the ruins before the end."

Wei Liang said nothing.

"I have been watching for sixty years," Fen said. "Watching for the seal to weaken. Watching for whoever the Sword Saint hid those things for." He looked at Wei Liang steadily. "He said, at the end, that when the sword recognized someone, that person should be trusted. That they would know what to do." He paused. "Does the sword recognize you?"

"Yes," Wei Liang said.

Fen exhaled slowly. "Then you understand what is hidden in those ruins."

"The Celestial Scroll of Sword Origins. And the reason someone tried to destroy the sect to get it."

"The Black Moon Pavilion." Fen''s voice dropped. "They are not gone. They have been patient. And in recent months, their agents have been in the region again." He looked directly at Wei Liang. "You have very little time. And I imagine very little cultivation base."

"Correct on both counts," Wei Liang agreed.

"Then we have work to do." The elder stood, moving toward the false panel. "The copy is incomplete and insufficient for the full technique. But it will give your body a framework while your — shall we say, memories — provide the rest." He stopped. "I will not ask how you know what you know. The Sword Saint sealed certain things for a reason and it is not my place to pry. But I will ask this: do you know why the Black Moon Pavilion wants the scroll so desperately?"

Wei Liang thought of the black-robed man from his recovered memories. Of the threat delivered with cold patience. Of the thing he had understood, in that moment, was at stake.

"Yes," he said. "The Celestial Scroll doesn''t just contain the sword technique. It contains proof of what the Pavilion has been hiding for two hundred years." He paused. "Names. Actions. The origin of their power."

Fen nodded slowly. "Then you understand. This is not only about martial cultivation." He handed Wei Liang the sealed case. "Begin tonight."', 'Elder Fen''s study was small and unremarkable and contained, behind a false panel in the bookshelf...', false, 20, 1300, 325, 'published', now()),
  ('60000000-0000-0000-0000-000000000055', '50000000-0000-0000-0000-000000000005', 5, 'The First Battle', 'the-first-battle', 'The Black Moon Pavilion''s agent arrived three weeks later, which was slightly faster than Wei Liang had estimated and significantly faster than his cultivation base was ready for.

He was in the ruins when it happened. He had been coming here every night, retrieving pieces of Qian Yen''s memories from the stone seal, rebuilding the technique in the only body available to him. Fen''s copy had given him a framework. His memories provided the architecture. The actual qi cultivation was the limiting factor — a weak spirit root was a weak spirit root, and three weeks of intensive practice had moved him forward without solving the underlying problem.

What three weeks had done was sharpen his instincts.

So when the shadow moved at the edge of the ruins — too deliberate, too careful, not the movement of an animal — he knew.

The agent was young. That was the first surprise. Wei Liang had expected something seasoned, something angular and experienced. What he got was someone maybe twenty, in dark outer robes, with a cultivation base that was honestly not exceptional but was significantly more developed than his own.

"Outer disciple," the agent said. His voice was bored. "You''ve been coming here every night for three weeks. We assumed you''d found something."

"I was looking for a crane," Wei Liang said.

"Amusing." The agent raised one hand, and the qi gathered in a shape Wei Liang recognized — a compression technique, designed for incapacitation. "Give me what you''ve found and you can go back to hauling water."

Wei Liang thought about the three pieces of the broken sword under his floorboard. He thought about the Celestial Scroll''s secondary seal, which he had located but not yet opened. He thought about Fen, who was seventy-three and not in a condition to fight anyone.

He reached behind him and picked up a piece of broken masonry.

The agent stared at it. "You can''t be serious."

"The thing about a weak spirit root," Wei Liang said conversationally, "is that everyone assumes they know exactly what you can do." He shifted his weight — the Foundation Step of the Celestial Blade method, invisible to anyone who didn''t know what they were looking at. "They''re usually wrong about the ceiling."

He moved.

Not fast by the standards of a developed cultivator. But with a precision that his opponent, used to opponents who broadcast their intentions through qi movement, had no framework to predict. The masonry piece was a distraction. The elbow strike that followed it was not.

The agent went down hard.

Wei Liang stood over him, breathing carefully, cataloguing the ways this had nearly gone wrong. "I need you to deliver a message to whoever sent you," he said. "The ruins hold nothing you''re looking for. And the outer disciple who''s been coming here at night?" He paused. "You should probably look into who he was, in a previous life, before you send anyone else."

He left the agent in the rubble and walked back toward the outer dormitory, the night air cool around him.

Behind him, the ruins were quiet. The secondary seal was waiting.

Tomorrow, he thought, he would open it.

Tonight, he allowed himself something he had not permitted in four years of survival: he looked up at the stars and felt, for the first time in this lifetime, like himself.', 'The Black Moon Pavilion''s agent arrived three weeks later, which was slightly faster than Wei Liang had estimated...', false, 20, 1320, 330, 'published', now())
ON CONFLICT (story_id, episode_number) DO NOTHING;

UPDATE stories SET total_episodes = 5 WHERE id = '50000000-0000-0000-0000-000000000005';
