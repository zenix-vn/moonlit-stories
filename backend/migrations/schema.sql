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
  status TEXT NOT NULL DEFAULT 'draft', -- 'draft', 'scheduled', 'published', 'archived'
  published_at TIMESTAMPTZ,
  created_by UUID,
  updated_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(story_id, episode_number)
);

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
  ('40000000-0000-0000-0000-000000000004', 'moonpass_monthly', 'MoonPass Monthly', 'subscription', 'all', 'com.moonlit.moonpass.monthly', 5.99, NULL, NULL)
ON CONFLICT (code) DO NOTHING;

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

-- Seed Episodes for Story 1: Reborn as the Villain Queen
INSERT INTO episodes (id, story_id, episode_number, title, slug, content_text, is_free, coin_price, word_count, estimated_reading_time, status, published_at) VALUES
  ('60000000-0000-0000-0000-000000000011', '50000000-0000-0000-0000-000000000001', 1, 'The Execution Guild', 'the-execution-guild', 'The poison tasted like sweet wine. As the executioner pressed the glass to my lips, the Duke laughed. Five years of devotion, all to end in this dungeon. "May your next life be wiser, Elara," he sneered. I closed my eyes, letting the darkness consume me. But instead of cold death, I woke up gasping for air in my warm bed. It was the morning of my eighteenth birthday. The day I met him.', true, 0, 1200, 240, 'published', now()),
  ('60000000-0000-0000-0000-000000000012', '50000000-0000-0000-0000-000000000001', 2, 'Birthday Wishes', 'birthday-wishes', 'My maids rushed in, holding the crimson dress I had worn on that fateful day. "My Lady, the Duke of Ravencrest has arrived," they cheered. I looked in the mirror. No poison scars, no dungeon pale. I was young, rich, and alive. And this time, I would not wear red. "Fetch the black lace dress," I instructed. Let the duke know that the girl he plans to deceive is already dead.', true, 0, 1150, 230, 'published', now()),
  ('60000000-0000-0000-0000-000000000013', '50000000-0000-0000-0000-000000000001', 3, 'Red and Black', 'red-and-black', 'Duke Ravencrest stood in the ballroom, holding a bouquet of rare winter roses. When he saw me descending the stairs in black lace, his smile faltered. "Elara, you look... different. I expected red." I walked past him, brushing my fingers against his sleeve. "Red is for blood, Duke Ravencrest. I prefer the color of a fresh grave." When I turned around, I caught the Crown Prince staring at me from the balcony with a dangerous smirk.', true, 0, 1300, 260, 'published', now()),
  ('60000000-0000-0000-0000-000000000014', '50000000-0000-0000-0000-000000000001', 4, 'Locked Intentions', 'locked-intentions', 'The Crown Prince, Arthur, intercepted me by the garden fountain. "A grave? A bit dramatic, Lady Elara." I curtsied slowly. "The truth is often dramatic, Your Highness." He leaned in, his eyes dark with intrigue. "The Duke seems disappointed. Have you broken his heart already?" "I am just starting," I whispered. He chuckled, presenting a gold pocket watch. "Then let us begin. Tell me, Elara, do you believe in ghosts?"', false, 20, 1100, 220, 'published', now()),
  ('60000000-0000-0000-0000-000000000015', '50000000-0000-0000-0000-000000000001', 5, 'The Dark Treaty', 'the-dark-treaty', 'We signed a pact in the library. Duke Ravencrest will try to ruin Elara, but Arthur will shield her in exchange for the southern army support. As they sealed the pact, Elara noticed a hidden mark on Arthur''s neck—the same mark the assassin who killed her had. Could it be?', false, 20, 1400, 280, 'published', now())
ON CONFLICT (story_id, episode_number) DO NOTHING;
