# Moonlit Stories Backend & Admin Dashboard Specification

> Version: 1.0  
> Target stack: Go + PostgreSQL + Redis + NextJS Admin  
> Product: Moonlit Stories  
> Market: US / EU  
> App type: Mobile-first serialized story reading entertainment app

---

# 1. Mục tiêu tài liệu

Tài liệu này mô tả chi tiết kiến trúc backend cho ứng dụng **Moonlit Stories**, bao gồm:

- Backend API cho mobile app.
- Admin Dashboard bằng NextJS.
- CMS quản lý truyện, episode, genre, tag, mood.
- Dashboard quan sát user realtime/gần realtime.
- Theo dõi user đăng nhập từ quốc gia nào.
- Theo dõi user gần đây đang đọc truyện gì.
- Theo dõi user subscription.
- Phân loại New User / Returning User.
- Quản lý banner trong app.
- Quản lý cấu hình API/app config.
- Quản lý coins, unlock, rewards, ads, subscription.
- Tracking analytics phục vụ growth và monetization.
- Thiết kế database PostgreSQL.
- Gợi ý API endpoints.
- Gợi ý module backend Go.

Moonlit Stories không nên được xây như một app đọc sách truyền thống. Backend cần phục vụ một hệ thống **reading entertainment economy**, nơi người dùng đọc truyện theo tập ngắn, bị cuốn bởi cliffhanger, mở khóa bằng coins/ads/free pass/subscription và quay lại mỗi đêm.

---

# 2. Định hướng kiến trúc

## 2.1. Kiến trúc đề xuất

Giai đoạn MVP nên dùng kiến trúc:

```txt
Go Modular Monolith
+ PostgreSQL
+ Redis
+ Worker Queue
+ S3/R2 Storage
+ NextJS Admin CMS
```

Không nên tách microservices quá sớm.

Lý do:

- Dự án cần ra MVP nhanh.
- Logic liên quan chặt giữa user, wallet, unlock, subscription, reward.
- Microservices sẽ làm tăng chi phí vận hành.
- Modular monolith vẫn có thể scale tốt trong giai đoạn đầu.
- Sau này module analytics, notification, recommendation có thể tách riêng.

## 2.2. Sơ đồ tổng quan

```txt
Mobile App
  |
  | REST API / GraphQL API
  v
Go Backend API
  |
  |-- Auth Module
  |-- User Module
  |-- Content Module
  |-- Reading Module
  |-- Unlock Module
  |-- Wallet Module
  |-- Reward Module
  |-- Subscription Module
  |-- Ads Module
  |-- Banner Module
  |-- App Config Module
  |-- Notification Module
  |-- Analytics Module
  |-- Admin Module
  |
  +--> PostgreSQL
  +--> Redis
  +--> S3 / Cloudflare R2
  +--> Queue Worker
  +--> Firebase Cloud Messaging
  +--> RevenueCat / Apple / Google IAP
  +--> AdMob / AppLovin
```

## 2.3. Thành phần chính

| Thành phần | Công nghệ | Vai trò |
|---|---|---|
| Public API | Go | API cho mobile app |
| Admin API | Go | API cho NextJS Admin |
| Admin UI | NextJS | Dashboard + CMS |
| Database | PostgreSQL | Lưu dữ liệu chính |
| Cache | Redis | Cache home, session, rate limit, queue |
| Worker | Go | Push, analytics aggregation, scheduled publish |
| Storage | S3 / Cloudflare R2 | Cover, banner, audio, assets |
| Analytics | PostgreSQL trước, sau có thể dùng ClickHouse/BigQuery | Tracking behavior |
| IAP | RevenueCat hoặc Apple/Google verification | Subscription + coin packs |
| Push | FCM | Push notification |

---

# 3. Công nghệ đề xuất

## 3.1. Backend Go

Khuyến nghị:

```txt
Language: Go
Framework: Echo hoặc Fiber
ORM: Ent hoặc SQLC
Database: PostgreSQL
Cache: Redis
Queue: Asynq hoặc River
Auth: JWT
Storage: Cloudflare R2 hoặc AWS S3
```

### Nên chọn Ent hay SQLC?

| Option | Ưu điểm | Nhược điểm | Khuyến nghị |
|---|---|---|---|
| Ent | Schema rõ, type-safe, migration tốt | Hơi nặng hơn SQLC | Phù hợp app nhiều quan hệ |
| SQLC | SQL rõ ràng, hiệu năng tốt | Viết SQL nhiều | Phù hợp team thích kiểm soát query |
| GORM | Dễ dùng | Dễ sinh query khó kiểm soát | Không ưu tiên cho hệ thống tiền/transaction |

Khuyến nghị cuối:

```txt
Go + Ent + PostgreSQL + Redis + Asynq
```

## 3.2. Admin Frontend

```txt
NextJS
TypeScript
TailwindCSS
shadcn/ui
TanStack Query
React Hook Form
Zod
TipTap / Lexical Editor
Recharts / Tremor / ECharts
```

Admin không nên chứa business logic chính. Admin chỉ gọi Admin API từ Go backend.

## 3.3. Mobile App

Backend nên thiết kế API phù hợp cho:

```txt
React Native hoặc Flutter
Firebase Analytics / Amplitude
RevenueCat
AdMob / AppLovin
Firebase Cloud Messaging
```

---

# 4. Backend module overview

Backend nên chia module rõ như sau:

```txt
internal/
  auth/
  user/
  content/
  reading/
  wallet/
  unlock/
  rewards/
  subscription/
  ads/
  banner/
  appconfig/
  notification/
  analytics/
  admin/
  storage/
  recommendation/
```

Mỗi module nên có:

```txt
handler.go
service.go
repository.go
model.go
dto.go
```

Ví dụ:

```txt
internal/content/
  handler.go
  admin_handler.go
  service.go
  repository.go
  dto.go
```

---

# 5. Auth & User Module

## 5.1. Mục tiêu

- Cho phép user dùng app nhanh.
- Hỗ trợ guest account.
- Hỗ trợ login Apple/Google.
- Theo dõi quốc gia, thiết bị, lần đăng nhập gần đây.
- Phục vụ dashboard phân tích user mới/quay lại.

## 5.2. Loại tài khoản

```txt
guest
email
google
apple
```

## 5.3. Database

### users

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY,
  email TEXT UNIQUE,
  username TEXT,
  avatar_url TEXT,
  auth_provider TEXT NOT NULL,
  provider_user_id TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  level INT NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_login_at TIMESTAMPTZ
);
```

### user_profiles

```sql
CREATE TABLE user_profiles (
  user_id UUID PRIMARY KEY REFERENCES users(id),
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
```

### user_devices

```sql
CREATE TABLE user_devices (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  device_id TEXT,
  platform TEXT,
  os_version TEXT,
  app_version TEXT,
  fcm_token TEXT,
  country_code TEXT,
  country_name TEXT,
  ip_address INET,
  last_seen_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### user_login_events

```sql
CREATE TABLE user_login_events (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  device_id TEXT,
  platform TEXT,
  app_version TEXT,
  ip_address INET,
  country_code TEXT,
  country_name TEXT,
  city TEXT,
  timezone TEXT,
  login_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

## 5.4. Phân loại New User / Returning User

### New User

User được tính là New User nếu:

```txt
created_at nằm trong khoảng thời gian lọc
```

Ví dụ dashboard hôm nay:

```sql
SELECT COUNT(*)
FROM users
WHERE created_at >= date_trunc('day', now());
```

### Returning User

User được tính là Returning User nếu:

```txt
User có login/app_open trong khoảng thời gian lọc
AND created_at trước khoảng thời gian đó
```

Ví dụ dashboard hôm nay:

```sql
SELECT COUNT(DISTINCT user_id)
FROM analytics_events
WHERE event_name = 'app_opened'
AND created_at >= date_trunc('day', now())
AND user_id IN (
  SELECT id FROM users WHERE created_at < date_trunc('day', now())
);
```

---

# 6. Content CMS Module

## 6.1. Mục tiêu

Quản lý toàn bộ nội dung truyện:

- Story.
- Season.
- Episode.
- Genre.
- Tag.
- Mood.
- Cover.
- Hook.
- Publish schedule.
- Free episodes.
- Coin price.
- Featured / trending / recommended.

## 6.2. Database

### stories

```sql
CREATE TABLE stories (
  id UUID PRIMARY KEY,
  title TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  description TEXT,
  hook TEXT,
  cover_url TEXT,
  language TEXT NOT NULL DEFAULT 'en',
  content_rating TEXT DEFAULT 'teen',
  status TEXT NOT NULL DEFAULT 'draft',
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
```

### seasons

```sql
CREATE TABLE seasons (
  id UUID PRIMARY KEY,
  story_id UUID NOT NULL REFERENCES stories(id),
  title TEXT,
  season_number INT NOT NULL,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'draft',
  published_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(story_id, season_number)
);
```

### episodes

```sql
CREATE TABLE episodes (
  id UUID PRIMARY KEY,
  story_id UUID NOT NULL REFERENCES stories(id),
  season_id UUID REFERENCES seasons(id),
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
  status TEXT NOT NULL DEFAULT 'draft',
  published_at TIMESTAMPTZ,
  created_by UUID,
  updated_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(story_id, episode_number)
);
```

### episode_versions

```sql
CREATE TABLE episode_versions (
  id UUID PRIMARY KEY,
  episode_id UUID NOT NULL REFERENCES episodes(id),
  content_json JSONB,
  content_html TEXT,
  content_text TEXT,
  title TEXT,
  version_number INT NOT NULL,
  edited_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### genres

```sql
CREATE TABLE genres (
  id UUID PRIMARY KEY,
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  description TEXT,
  sort_order INT DEFAULT 0,
  active BOOLEAN DEFAULT true
);
```

### tags

```sql
CREATE TABLE tags (
  id UUID PRIMARY KEY,
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  active BOOLEAN DEFAULT true
);
```

### moods

```sql
CREATE TABLE moods (
  id UUID PRIMARY KEY,
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  description TEXT,
  active BOOLEAN DEFAULT true
);
```

### story_genres

```sql
CREATE TABLE story_genres (
  story_id UUID REFERENCES stories(id),
  genre_id UUID REFERENCES genres(id),
  PRIMARY KEY(story_id, genre_id)
);
```

### story_tags

```sql
CREATE TABLE story_tags (
  story_id UUID REFERENCES stories(id),
  tag_id UUID REFERENCES tags(id),
  PRIMARY KEY(story_id, tag_id)
);
```

### story_moods

```sql
CREATE TABLE story_moods (
  story_id UUID REFERENCES stories(id),
  mood_id UUID REFERENCES moods(id),
  PRIMARY KEY(story_id, mood_id)
);
```

## 6.3. Admin CMS chức năng

### Story Management

Admin có thể:

- Tạo story mới.
- Sửa title, hook, description.
- Upload cover.
- Chọn genre/tag/mood.
- Set trạng thái:
  - draft
  - scheduled
  - published
  - archived
- Set số episode free.
- Set giá coin mặc định.
- Set featured/hot/editor pick.
- Xem performance của story:
  - views
  - readers
  - unlocks
  - revenue
  - completion rate
  - drop-off episode.

### Episode Editor

Admin có thể:

- Soạn thảo episode bằng rich text editor.
- Lưu draft.
- Preview trên mobile frame.
- Publish ngay.
- Schedule publish.
- Set episode free/locked.
- Set coin price riêng.
- Xem word count.
- Xem estimated reading time.
- Xem version history.
- Rollback version cũ.

### Content Workflow

```txt
Draft -> Review -> Scheduled -> Published -> Archived
```

Gợi ý role:

| Role | Quyền |
|---|---|
| Writer | Tạo/sửa draft |
| Editor | Duyệt nội dung |
| Content Manager | Publish/schedule/archive |
| Admin | Toàn quyền |

---

# 7. Reading Module

## 7.1. Mục tiêu

Theo dõi user đọc gì, đọc đến đâu, đọc trong bao lâu.

Đây là module phục vụ trực tiếp dashboard yêu cầu:

> User ở nước nào đăng nhập gần đây, đọc truyện gì.

## 7.2. Database

### reading_progress

```sql
CREATE TABLE reading_progress (
  user_id UUID NOT NULL REFERENCES users(id),
  story_id UUID NOT NULL REFERENCES stories(id),
  episode_id UUID NOT NULL REFERENCES episodes(id),
  progress_percent NUMERIC(5,2) NOT NULL DEFAULT 0,
  current_position INT DEFAULT 0,
  last_read_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY(user_id, story_id)
);
```

### reading_sessions

```sql
CREATE TABLE reading_sessions (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  story_id UUID REFERENCES stories(id),
  episode_id UUID REFERENCES episodes(id),
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
```

### library_items

```sql
CREATE TABLE library_items (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  story_id UUID REFERENCES stories(id),
  type TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, story_id, type)
);
```

`type` có thể là:

```txt
saved
completed
downloaded
history
```

### bookmarks

```sql
CREATE TABLE bookmarks (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  story_id UUID REFERENCES stories(id),
  episode_id UUID REFERENCES episodes(id),
  position INT,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### highlights

```sql
CREATE TABLE highlights (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  story_id UUID REFERENCES stories(id),
  episode_id UUID REFERENCES episodes(id),
  start_position INT,
  end_position INT,
  text TEXT,
  color TEXT,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

## 7.3. API

```txt
POST /reading/session/start
POST /reading/session/end
POST /reading/progress
GET  /reading/continue
GET  /library
POST /library/save
DELETE /library/save/:storyId
POST /bookmarks
POST /highlights
```

## 7.4. Dashboard query: user gần đây đọc truyện gì

```sql
SELECT 
  rs.started_at,
  u.id AS user_id,
  u.email,
  up.country_name,
  rs.platform,
  s.title AS story_title,
  e.episode_number,
  e.title AS episode_title,
  rs.duration_seconds
FROM reading_sessions rs
JOIN users u ON u.id = rs.user_id
LEFT JOIN user_profiles up ON up.user_id = u.id
JOIN stories s ON s.id = rs.story_id
JOIN episodes e ON e.id = rs.episode_id
ORDER BY rs.started_at DESC
LIMIT 100;
```

---

# 8. Wallet, Coins & Unlock Module

## 8.1. Mục tiêu

Hệ thống coins là phần rất nhạy cảm. Không được chỉ lưu `users.coins` rồi cộng/trừ tuỳ tiện.

Cần có:

- Wallet balance.
- Wallet transaction ledger.
- Idempotent unlock.
- Audit đầy đủ.
- Không cho số dư âm.
- Không unlock trùng.

## 8.2. Database

### wallets

```sql
CREATE TABLE wallets (
  user_id UUID PRIMARY KEY REFERENCES users(id),
  coins INT NOT NULL DEFAULT 0,
  gems INT NOT NULL DEFAULT 0,
  free_pass INT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### wallet_transactions

```sql
CREATE TABLE wallet_transactions (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  currency_type TEXT NOT NULL,
  amount INT NOT NULL,
  balance_after INT NOT NULL,
  reason TEXT NOT NULL,
  ref_type TEXT,
  ref_id UUID,
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### episode_unlocks

```sql
CREATE TABLE episode_unlocks (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  story_id UUID NOT NULL REFERENCES stories(id),
  episode_id UUID NOT NULL REFERENCES episodes(id),
  method TEXT NOT NULL,
  coins_spent INT DEFAULT 0,
  free_pass_spent INT DEFAULT 0,
  ad_session_id UUID,
  subscription_id UUID,
  unlocked_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ,
  UNIQUE(user_id, episode_id)
);
```

## 8.3. Unlock rule

User được đọc episode nếu:

```txt
episode.is_free = true
OR user đã unlock episode
OR subscription entitlement cho phép đọc
OR episode thuộc selected unlimited collection
OR admin grant access
```

Tất cả logic check access phải đi qua một service duy nhất:

```go
AccessService.CanReadEpisode(userID, episodeID)
```

## 8.4. Transaction khi unlock bằng coins

Pseudo flow:

```txt
BEGIN TRANSACTION

1. Check episode exists.
2. Check user already unlocked episode.
3. Lock wallet row.
4. Check coin balance.
5. Deduct coins.
6. Insert wallet transaction.
7. Insert episode_unlock.
8. Commit.

END
```

Không được để app mobile tự tính giá unlock. Giá phải lấy từ backend.

## 8.5. API

```txt
GET  /wallet
GET  /wallet/transactions
GET  /episodes/:episodeId/access
POST /episodes/:episodeId/unlock/coins
POST /episodes/:episodeId/unlock/free-pass
POST /episodes/:episodeId/unlock/ad
```

---

# 9. Reward, Daily Check-in, Streak & Quest Module

## 9.1. Mục tiêu

Tăng retention hằng ngày.

MVP nên có:

- Daily check-in.
- Reading streak.
- Daily tasks.
- Weekly tasks.
- Reward log.

Lucky chest để phase sau.

## 9.2. Database

### daily_checkins

```sql
CREATE TABLE daily_checkins (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  checkin_date DATE NOT NULL,
  streak_day INT NOT NULL,
  reward_type TEXT NOT NULL,
  reward_amount INT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, checkin_date)
);
```

### user_streaks

```sql
CREATE TABLE user_streaks (
  user_id UUID PRIMARY KEY REFERENCES users(id),
  current_streak INT NOT NULL DEFAULT 0,
  longest_streak INT NOT NULL DEFAULT 0,
  last_active_date DATE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### tasks

```sql
CREATE TABLE tasks (
  id UUID PRIMARY KEY,
  code TEXT UNIQUE NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  type TEXT NOT NULL,
  target_event TEXT NOT NULL,
  target_value INT NOT NULL,
  reward_type TEXT NOT NULL,
  reward_amount INT NOT NULL,
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### user_task_progress

```sql
CREATE TABLE user_task_progress (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  task_id UUID REFERENCES tasks(id),
  task_date DATE NOT NULL,
  progress INT NOT NULL DEFAULT 0,
  completed_at TIMESTAMPTZ,
  claimed_at TIMESTAMPTZ,
  UNIQUE(user_id, task_id, task_date)
);
```

## 9.3. API

```txt
GET  /rewards/dashboard
POST /rewards/checkin
GET  /tasks/daily
POST /tasks/:taskId/claim
```

## 9.4. Reward rule

Reward phải đi qua wallet transaction.

Không nên:

```txt
users.coins += 10
```

Nên:

```txt
WalletService.AddCoins(userID, 10, "daily_checkin")
```

---

# 10. Subscription & IAP Module

## 10.1. Mục tiêu

Quản lý:

- Coin packs.
- Subscription.
- Apple IAP.
- Google Play Billing.
- RevenueCat webhook.
- User đang subscribe hay không.
- Subscription entitlement.

## 10.2. Subscription model đề xuất

MVP nên có:

```txt
Free
MoonPass - $5.99/month
Coin Packs
```

Sau đó mở rộng:

```txt
MoonPass Plus - $9.99/month
VIP Night Unlimited - $14.99/month
Weekly Pass - $1.99/week
```

## 10.3. Database

### products

```sql
CREATE TABLE products (
  id UUID PRIMARY KEY,
  code TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  platform TEXT,
  platform_product_id TEXT,
  price NUMERIC(10,2),
  currency TEXT,
  coin_amount INT,
  bonus_coin_amount INT,
  active BOOLEAN DEFAULT true,
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### purchases

```sql
CREATE TABLE purchases (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  product_id UUID REFERENCES products(id),
  platform TEXT NOT NULL,
  platform_transaction_id TEXT,
  original_transaction_id TEXT,
  price NUMERIC(10,2),
  currency TEXT,
  status TEXT NOT NULL,
  purchased_at TIMESTAMPTZ,
  raw_payload JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### subscriptions

```sql
CREATE TABLE subscriptions (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  product_id UUID REFERENCES products(id),
  platform TEXT NOT NULL,
  status TEXT NOT NULL,
  started_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  canceled_at TIMESTAMPTZ,
  original_transaction_id TEXT,
  latest_transaction_id TEXT,
  raw_payload JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### subscription_entitlements

```sql
CREATE TABLE subscription_entitlements (
  id UUID PRIMARY KEY,
  subscription_id UUID REFERENCES subscriptions(id),
  entitlement_code TEXT NOT NULL,
  entitlement_value JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

## 10.4. Entitlement examples

```json
{
  "NO_ADS": true,
  "DAILY_UNLOCKS": 1,
  "REWARD_MULTIPLIER": 2,
  "OFFLINE_READING": true,
  "SELECTED_COLLECTION_ACCESS": true
}
```

## 10.5. API

```txt
GET  /products
POST /iap/verify
POST /iap/webhook/revenuecat
POST /iap/webhook/apple
POST /iap/webhook/google
GET  /me/subscription
```

## 10.6. Dashboard: user nào subscribe

```sql
SELECT 
  u.id,
  u.email,
  u.username,
  p.name AS product_name,
  s.status,
  s.started_at,
  s.expires_at,
  up.country_name
FROM subscriptions s
JOIN users u ON u.id = s.user_id
JOIN products p ON p.id = s.product_id
LEFT JOIN user_profiles up ON up.user_id = u.id
WHERE s.status = 'active'
ORDER BY s.started_at DESC;
```

---

# 11. Ads Reward Module

## 11.1. Mục tiêu

Quản lý reward từ ads:

- Watch ad để unlock episode.
- Watch ad để nhận coins.
- Watch ad để mở chest.
- Watch ad để nhân đôi reward.

## 11.2. Database

### ad_reward_sessions

```sql
CREATE TABLE ad_reward_sessions (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  provider TEXT NOT NULL,
  placement TEXT NOT NULL,
  reward_type TEXT NOT NULL,
  reward_amount INT,
  episode_id UUID REFERENCES episodes(id),
  status TEXT NOT NULL DEFAULT 'pending',
  provider_event_id TEXT,
  verification_payload JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  verified_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ
);
```

## 11.3. API

```txt
POST /ads/reward-session
POST /ads/reward-verify
POST /ads/webhook/:provider
```

## 11.4. Rule

- Một ad reward session chỉ được claim một lần.
- Session phải có expiry.
- Reward phải được cộng bằng WalletService.
- Unlock bằng ad phải tạo `episode_unlocks`.

---

# 12. Banner & App Placement Module

## 12.1. Mục tiêu

Admin có thể quản lý banner trong app mà không cần update mobile app.

Banner dùng cho:

- Home featured banner.
- Promotion banner.
- Subscription upsell.
- Coin sale.
- New story release.
- Event.
- Daily reward.
- App feature promotion.

## 12.2. Database

### banners

```sql
CREATE TABLE banners (
  id UUID PRIMARY KEY,
  title TEXT NOT NULL,
  subtitle TEXT,
  image_url TEXT NOT NULL,
  deep_link TEXT,
  action_type TEXT,
  action_payload JSONB,
  placement TEXT NOT NULL,
  priority INT NOT NULL DEFAULT 0,
  active BOOLEAN DEFAULT true,
  start_at TIMESTAMPTZ,
  end_at TIMESTAMPTZ,
  target_country_codes TEXT[],
  target_user_type TEXT,
  target_subscription_status TEXT,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### banner_impressions

```sql
CREATE TABLE banner_impressions (
  id UUID PRIMARY KEY,
  banner_id UUID REFERENCES banners(id),
  user_id UUID REFERENCES users(id),
  placement TEXT,
  country_code TEXT,
  shown_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### banner_clicks

```sql
CREATE TABLE banner_clicks (
  id UUID PRIMARY KEY,
  banner_id UUID REFERENCES banners(id),
  user_id UUID REFERENCES users(id),
  placement TEXT,
  country_code TEXT,
  clicked_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

## 12.3. Placement examples

```txt
home_top
home_mid
reader_end
unlock_popup
reward_screen
profile_top
discover_top
```

## 12.4. Targeting examples

```txt
all_users
new_users
returning_users
free_users
subscribers
non_subscribers
country: US, CA, GB, AU
```

## 12.5. API

```txt
GET  /banners?placement=home_top
POST /banners/:id/impression
POST /banners/:id/click
```

## 12.6. Admin Banner Management

Admin có thể:

- Upload banner image.
- Chọn placement.
- Set thời gian chạy.
- Set target country.
- Set target user type.
- Set target subscription status.
- Set priority.
- Xem impression/click/CTR.

---

# 13. App Config & API Management Module

## 13.1. Mục tiêu

Cho phép điều chỉnh hành vi app từ backend:

- Bật/tắt feature.
- Cấu hình số episode free mặc định.
- Cấu hình giá unlock.
- Cấu hình reward.
- Cấu hình ads placement.
- Cấu hình app minimum version.
- Cấu hình maintenance mode.
- Cấu hình payment products.
- Cấu hình home sections.

## 13.2. Database

### app_configs

```sql
CREATE TABLE app_configs (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  description TEXT,
  updated_by UUID,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

Example:

```json
{
  "free_episode_count": 3,
  "default_episode_coin_price": 20,
  "daily_checkin_rewards": [10, 15, 20, 30, 40, 50, 1],
  "rewarded_ad_coin_amount": 10,
  "maintenance_mode": false,
  "min_supported_version": "1.0.0"
}
```

### feature_flags

```sql
CREATE TABLE feature_flags (
  key TEXT PRIMARY KEY,
  enabled BOOLEAN NOT NULL DEFAULT false,
  rollout_percentage INT DEFAULT 100,
  target_country_codes TEXT[],
  description TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

## 13.3. API

```txt
GET /app/config
GET /app/feature-flags
```

## 13.4. Admin Config Management

Admin có thể:

- Bật/tắt feature.
- Set maintenance mode.
- Set force update.
- Set reward config.
- Set ads config.
- Set home layout.
- Set unlock pricing.
- Quản lý API keys/tích hợp external services.

---

# 14. Notification Module

## 14.1. Mục tiêu

Gửi push notification theo hướng drama, cá nhân hóa.

Loại push:

- New episode.
- Continue reading.
- Daily reward.
- Streak reminder.
- Subscription offer.
- Comeback.
- Free pass expiring.
- Story recommendation.

## 14.2. Database

### push_tokens

```sql
CREATE TABLE push_tokens (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  token TEXT NOT NULL,
  platform TEXT,
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### push_templates

```sql
CREATE TABLE push_templates (
  id UUID PRIMARY KEY,
  code TEXT UNIQUE NOT NULL,
  title_template TEXT NOT NULL,
  body_template TEXT NOT NULL,
  deep_link_template TEXT,
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### push_campaigns

```sql
CREATE TABLE push_campaigns (
  id UUID PRIMARY KEY,
  name TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  deep_link TEXT,
  target_type TEXT,
  target_payload JSONB,
  scheduled_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'draft',
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### push_logs

```sql
CREATE TABLE push_logs (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  campaign_id UUID REFERENCES push_campaigns(id),
  token_id UUID REFERENCES push_tokens(id),
  status TEXT NOT NULL,
  error_message TEXT,
  sent_at TIMESTAMPTZ,
  opened_at TIMESTAMPTZ
);
```

## 14.3. API

```txt
POST /devices/push-token
DELETE /devices/push-token
POST /push/opened
```

## 14.4. Worker jobs

```txt
send_push_campaign
send_new_episode_push
send_daily_reward_reminder
send_continue_reading_reminder
send_streak_reminder
```

---

# 15. Analytics Module

## 15.1. Mục tiêu

Theo dõi hành vi user để tối ưu:

- Retention.
- Unlock conversion.
- Revenue.
- Story performance.
- Episode drop-off.
- Subscription conversion.
- Ads conversion.
- Country performance.

## 15.2. Database

### analytics_events

```sql
CREATE TABLE analytics_events (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
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
```

## 15.3. Event list

### App lifecycle

```txt
app_opened
app_backgrounded
session_started
session_ended
```

### Auth

```txt
signup_completed
login_completed
guest_created
account_linked
```

### Story

```txt
story_viewed
story_saved
story_shared
story_followed
```

### Episode

```txt
episode_started
episode_progress_updated
episode_completed
episode_locked_viewed
```

### Unlock

```txt
unlock_popup_viewed
episode_unlocked_by_coin
episode_unlocked_by_ad
episode_unlocked_by_free_pass
episode_unlocked_by_subscription
```

### Reward

```txt
daily_checkin_viewed
daily_checkin_claimed
task_completed
task_claimed
```

### Ads

```txt
rewarded_ad_started
rewarded_ad_completed
rewarded_ad_failed
```

### Purchase

```txt
coin_pack_viewed
coin_pack_purchased
subscription_page_viewed
subscription_started
subscription_canceled
```

### Push

```txt
push_received
push_opened
```

### Banner

```txt
banner_impression
banner_clicked
```

## 15.4. Aggregated tables

Để dashboard nhanh, nên có bảng aggregate theo ngày.

### daily_user_metrics

```sql
CREATE TABLE daily_user_metrics (
  metric_date DATE PRIMARY KEY,
  new_users INT DEFAULT 0,
  returning_users INT DEFAULT 0,
  active_users INT DEFAULT 0,
  subscribers INT DEFAULT 0,
  revenue NUMERIC(12,2) DEFAULT 0,
  ad_unlocks INT DEFAULT 0,
  coin_unlocks INT DEFAULT 0,
  subscription_starts INT DEFAULT 0
);
```

### daily_story_metrics

```sql
CREATE TABLE daily_story_metrics (
  metric_date DATE,
  story_id UUID REFERENCES stories(id),
  views INT DEFAULT 0,
  readers INT DEFAULT 0,
  episode_starts INT DEFAULT 0,
  episode_completions INT DEFAULT 0,
  unlocks INT DEFAULT 0,
  revenue NUMERIC(12,2) DEFAULT 0,
  PRIMARY KEY(metric_date, story_id)
);
```

### daily_country_metrics

```sql
CREATE TABLE daily_country_metrics (
  metric_date DATE,
  country_code TEXT,
  country_name TEXT,
  new_users INT DEFAULT 0,
  returning_users INT DEFAULT 0,
  active_users INT DEFAULT 0,
  revenue NUMERIC(12,2) DEFAULT 0,
  PRIMARY KEY(metric_date, country_code)
);
```

Worker sẽ chạy định kỳ để aggregate dữ liệu.

---

# 16. Admin Dashboard

## 16.1. Mục tiêu

Dashboard cần trả lời nhanh các câu hỏi:

1. User gần đây đăng nhập từ nước nào?
2. User gần đây đang đọc truyện gì?
3. User nào đang subscribe?
4. User nào là New User?
5. User nào là Returning User?
6. Truyện nào đang được đọc nhiều?
7. Episode nào bị drop-off nhiều?
8. Banner nào đang có CTR tốt?
9. Revenue đến từ đâu?
10. Ads unlock / coin unlock / subscription unlock tỷ lệ thế nào?

## 16.2. Dashboard chính

### Overview Cards

```txt
- DAU
- New Users
- Returning Users
- Active Subscribers
- Revenue Today
- Coin Purchases
- Episode Unlocks
- Rewarded Ad Unlocks
- Average Reading Time
- D1 Retention
```

### Charts

```txt
- New vs Returning Users by day
- Active users by country
- Revenue by day
- Top stories by readers
- Top stories by revenue
- Unlock method breakdown
- Subscription conversion
- Banner CTR
```

### Realtime / Recent Activity Table

Bảng này rất quan trọng theo yêu cầu của bạn.

Columns:

```txt
Time
User
Country
Device
Action
Story
Episode
Subscription Status
```

Example:

| Time | User | Country | Action | Story | Episode | Sub |
|---|---|---|---|---|---|---|
| 22:31 | emma***@gmail.com | US | Reading | Reborn as the Villain Queen | Ep 4 | Free |
| 22:30 | guest_81231 | GB | Unlocked by Ad | 11:59 PM | Ep 6 | Free |
| 22:28 | anna***@icloud.com | CA | Subscribed | - | - | MoonPass |

## 16.3. User Geography Dashboard

### Map / Table

```txt
Country
New Users
Returning Users
Active Users
Subscribers
Revenue
Average Reading Time
Top Story
```

### Query example

```sql
SELECT
  country_code,
  country_name,
  COUNT(DISTINCT user_id) AS active_users
FROM analytics_events
WHERE created_at >= now() - interval '24 hours'
GROUP BY country_code, country_name
ORDER BY active_users DESC;
```

## 16.4. Recent Reading Dashboard

### Filters

```txt
Date range
Country
Story
Genre
Subscription status
User type: new/returning
Platform
```

### Table columns

```txt
User
Country
Story
Episode
Started At
Duration
Progress
Completed
Unlock Method
```

## 16.5. Subscription Dashboard

### Cards

```txt
Active Subscribers
New Subscriptions Today
Canceled Today
MRR
Trial Users
Expired Users
```

### Table columns

```txt
User
Country
Plan
Status
Started At
Expires At
Platform
Revenue
```

### Filters

```txt
Plan
Country
Platform
Status
Date range
```

## 16.6. New vs Returning Dashboard

### Definition

```txt
New User:
- Account created in selected time range.

Returning User:
- Account created before selected time range.
- Has app_opened/session_started in selected time range.
```

### Chart

```txt
Line chart:
- New Users
- Returning Users
- Total Active Users
```

### Table

```txt
Date
New Users
Returning Users
Total Active
Returning Rate
```

## 16.7. Story Performance Dashboard

### Cards

```txt
Total Readers
Episode Starts
Episode Completions
Unlocks
Revenue
Completion Rate
Average Reading Time
```

### Per episode funnel

```txt
Episode 1 started
Episode 1 completed
Episode 2 started
Episode 2 completed
Episode 3 completed
Episode 4 locked viewed
Episode 4 unlocked
```

Đây là funnel sống còn, vì app của bạn monetization sau 3 tập free.

## 16.8. Banner Dashboard

### Cards

```txt
Impressions
Clicks
CTR
Conversion
Revenue attributed
```

### Table

```txt
Banner
Placement
Country
Impressions
Clicks
CTR
Start At
End At
Status
```

---

# 17. Admin CMS Pages

## 17.1. Dashboard

Route:

```txt
/admin/dashboard
```

Features:

- Overview metrics.
- User activity.
- Revenue summary.
- Top stories.
- Recent subscriptions.
- Country activity.

## 17.2. Stories

Route:

```txt
/admin/stories
/admin/stories/new
/admin/stories/:id
```

Features:

- Story list.
- Filter by status/genre/tag/mood.
- Create/edit story.
- Upload cover.
- Publish/schedule/archive.
- View analytics.

## 17.3. Episodes

Route:

```txt
/admin/stories/:storyId/episodes
/admin/episodes/:episodeId/edit
```

Features:

- Episode list.
- Rich text editor.
- Preview mobile reader.
- Version history.
- Publish schedule.
- Price/free config.

## 17.4. Genres / Tags / Moods

Route:

```txt
/admin/taxonomy
```

Features:

- Manage genres.
- Manage tags.
- Manage moods.
- Sort order.
- Active/inactive.

## 17.5. Users

Route:

```txt
/admin/users
/admin/users/:id
```

Features:

- User list.
- Filter by country.
- Filter by new/returning.
- Filter by subscription status.
- View reading history.
- View wallet transaction.
- View purchases.
- Support actions.

Support actions:

```txt
- Grant coins
- Grant free pass
- Ban user
- Restore user
- View activity log
```

All support actions must be audit logged.

## 17.6. Subscriptions

Route:

```txt
/admin/subscriptions
```

Features:

- Active subscriptions.
- Expired.
- Canceled.
- Search by user/email.
- Filter by platform.
- Filter by plan.
- View raw receipt/webhook payload.

## 17.7. Purchases

Route:

```txt
/admin/purchases
```

Features:

- Coin pack purchases.
- Refund status.
- Platform transaction ID.
- Revenue report.

## 17.8. Wallet

Route:

```txt
/admin/wallet-transactions
```

Features:

- Search wallet history.
- Filter by reason.
- Filter by currency type.
- View balance changes.

## 17.9. Banners

Route:

```txt
/admin/banners
/admin/banners/new
/admin/banners/:id
```

Features:

- Create banner.
- Upload image.
- Select placement.
- Target user segment.
- Target country.
- Schedule.
- Priority.
- View impressions/clicks.

## 17.10. Push Notifications

Route:

```txt
/admin/push
/admin/push/campaigns
/admin/push/templates
```

Features:

- Create campaign.
- Select target segment.
- Schedule.
- Preview notification.
- Send test notification.
- View sent/opened stats.

## 17.11. App Config

Route:

```txt
/admin/app-config
```

Features:

- Maintenance mode.
- Force update.
- Min supported app version.
- Reward config.
- Coin price config.
- Ads config.
- Feature flags.

## 17.12. API Management

Route:

```txt
/admin/api-management
```

Features:

- View API health.
- Manage internal API keys.
- Manage webhook secrets.
- View external service status.
- Rate limit config.
- Error logs.

---

# 18. Admin Roles & Permissions

## 18.1. Roles

```txt
super_admin
admin
content_manager
editor
writer
marketing
support
finance
analyst
```

## 18.2. Permission matrix

| Permission | Super Admin | Content Manager | Editor | Writer | Marketing | Support | Finance | Analyst |
|---|---|---|---|---|---|---|---|---|
| Manage stories | Yes | Yes | Yes | Draft only | No | No | No | View |
| Publish story | Yes | Yes | No | No | No | No | No | No |
| Manage banners | Yes | No | No | No | Yes | No | No | View |
| Manage users | Yes | No | No | No | No | Yes | View | View |
| Grant coins | Yes | No | No | No | No | Limited | No | No |
| View revenue | Yes | No | No | No | View | No | Yes | View |
| Manage app config | Yes | No | No | No | No | No | No | No |
| Send push | Yes | No | No | No | Yes | No | No | No |

## 18.3. Database

### admin_users

```sql
CREATE TABLE admin_users (
  id UUID PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  name TEXT,
  password_hash TEXT,
  status TEXT DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### admin_roles

```sql
CREATE TABLE admin_roles (
  id UUID PRIMARY KEY,
  code TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL
);
```

### admin_user_roles

```sql
CREATE TABLE admin_user_roles (
  admin_user_id UUID REFERENCES admin_users(id),
  role_id UUID REFERENCES admin_roles(id),
  PRIMARY KEY(admin_user_id, role_id)
);
```

### admin_audit_logs

```sql
CREATE TABLE admin_audit_logs (
  id UUID PRIMARY KEY,
  admin_user_id UUID REFERENCES admin_users(id),
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id UUID,
  before_data JSONB,
  after_data JSONB,
  ip_address INET,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

---

# 19. Public Mobile API Design

## 19.1. Auth

```txt
POST /v1/auth/guest
POST /v1/auth/google
POST /v1/auth/apple
POST /v1/auth/refresh
GET  /v1/me
PATCH /v1/me
```

## 19.2. Home

```txt
GET /v1/home
GET /v1/home/sections
```

Response example:

```json
{
  "greeting": "Good Evening",
  "wallet": {
    "coins": 1250,
    "freePass": 2
  },
  "featuredStory": {},
  "continueReading": [],
  "tonightsPicks": [],
  "trendingNow": [],
  "freeEpisodesToday": [],
  "banners": []
}
```

## 19.3. Discover

```txt
GET /v1/discover
GET /v1/genres
GET /v1/tags
GET /v1/moods
GET /v1/stories?genre=werewolf&mood=revenge
```

## 19.4. Story & Episode

```txt
GET /v1/stories/:slug
GET /v1/stories/:storyId/episodes
GET /v1/episodes/:episodeId
GET /v1/episodes/:episodeId/access
```

## 19.5. Reading

```txt
POST /v1/reading/session/start
POST /v1/reading/session/end
POST /v1/reading/progress
GET  /v1/reading/continue
GET  /v1/library
```

## 19.6. Unlock

```txt
POST /v1/episodes/:episodeId/unlock/coins
POST /v1/episodes/:episodeId/unlock/free-pass
POST /v1/episodes/:episodeId/unlock/ad
```

## 19.7. Rewards

```txt
GET  /v1/rewards/dashboard
POST /v1/rewards/checkin
GET  /v1/tasks/daily
POST /v1/tasks/:taskId/claim
```

## 19.8. Wallet

```txt
GET /v1/wallet
GET /v1/wallet/transactions
```

## 19.9. IAP

```txt
GET  /v1/products
POST /v1/iap/verify
POST /v1/iap/webhook/revenuecat
```

## 19.10. Banner

```txt
GET  /v1/banners?placement=home_top
POST /v1/banners/:bannerId/impression
POST /v1/banners/:bannerId/click
```

## 19.11. Analytics

```txt
POST /v1/events
POST /v1/events/batch
```

## 19.12. App Config

```txt
GET /v1/app/config
```

---

# 20. Admin API Design

## 20.1. Admin Auth

```txt
POST /admin/auth/login
POST /admin/auth/logout
GET  /admin/me
```

## 20.2. Dashboard

```txt
GET /admin/dashboard/overview
GET /admin/dashboard/recent-activity
GET /admin/dashboard/countries
GET /admin/dashboard/new-returning-users
GET /admin/dashboard/subscriptions
```

## 20.3. Stories

```txt
GET    /admin/stories
POST   /admin/stories
GET    /admin/stories/:id
PATCH  /admin/stories/:id
DELETE /admin/stories/:id
POST   /admin/stories/:id/publish
POST   /admin/stories/:id/archive
```

## 20.4. Episodes

```txt
GET    /admin/stories/:storyId/episodes
POST   /admin/stories/:storyId/episodes
GET    /admin/episodes/:id
PATCH  /admin/episodes/:id
POST   /admin/episodes/:id/publish
POST   /admin/episodes/:id/schedule
GET    /admin/episodes/:id/versions
POST   /admin/episodes/:id/rollback/:versionId
```

## 20.5. Users

```txt
GET   /admin/users
GET   /admin/users/:id
GET   /admin/users/:id/activity
GET   /admin/users/:id/reading-history
GET   /admin/users/:id/wallet-transactions
POST  /admin/users/:id/grant-coins
POST  /admin/users/:id/grant-free-pass
POST  /admin/users/:id/ban
POST  /admin/users/:id/unban
```

## 20.6. Subscriptions

```txt
GET /admin/subscriptions
GET /admin/subscriptions/:id
GET /admin/purchases
```

## 20.7. Banners

```txt
GET    /admin/banners
POST   /admin/banners
GET    /admin/banners/:id
PATCH  /admin/banners/:id
DELETE /admin/banners/:id
GET    /admin/banners/:id/analytics
```

## 20.8. Push

```txt
GET   /admin/push/campaigns
POST  /admin/push/campaigns
POST  /admin/push/campaigns/:id/send-test
POST  /admin/push/campaigns/:id/schedule
GET   /admin/push/templates
POST  /admin/push/templates
```

## 20.9. App Config

```txt
GET   /admin/app-config
PATCH /admin/app-config/:key
GET   /admin/feature-flags
PATCH /admin/feature-flags/:key
```

---

# 21. Dashboard Data Design

## 21.1. Recent user login by country

Source:

```txt
user_login_events
```

Query:

```sql
SELECT
  login_at,
  user_id,
  country_code,
  country_name,
  platform,
  app_version,
  ip_address
FROM user_login_events
ORDER BY login_at DESC
LIMIT 100;
```

## 21.2. User recently reading what story

Source:

```txt
reading_sessions
reading_progress
stories
episodes
```

Query:

```sql
SELECT
  rs.started_at,
  rs.user_id,
  rs.country_name,
  s.title AS story_title,
  e.episode_number,
  e.title AS episode_title,
  rs.duration_seconds,
  rs.completed
FROM reading_sessions rs
JOIN stories s ON s.id = rs.story_id
JOIN episodes e ON e.id = rs.episode_id
ORDER BY rs.started_at DESC
LIMIT 100;
```

## 21.3. User subscriptions

Source:

```txt
subscriptions
products
users
user_profiles
```

Query:

```sql
SELECT
  s.user_id,
  u.email,
  p.name AS plan,
  s.status,
  s.started_at,
  s.expires_at,
  up.country_name
FROM subscriptions s
JOIN users u ON u.id = s.user_id
JOIN products p ON p.id = s.product_id
LEFT JOIN user_profiles up ON up.user_id = u.id
ORDER BY s.started_at DESC;
```

## 21.4. New vs Returning Users

Source:

```txt
users
analytics_events
```

New users:

```sql
SELECT COUNT(*)
FROM users
WHERE created_at BETWEEN $1 AND $2;
```

Returning users:

```sql
SELECT COUNT(DISTINCT ae.user_id)
FROM analytics_events ae
JOIN users u ON u.id = ae.user_id
WHERE ae.event_name = 'app_opened'
AND ae.created_at BETWEEN $1 AND $2
AND u.created_at < $1;
```

---

# 22. Worker Jobs

Worker nên tách khỏi API process.

## 22.1. Job types

```txt
aggregate_daily_metrics
send_push_campaign
send_new_episode_notification
publish_scheduled_episode
expire_ad_reward_sessions
sync_subscription_status
generate_story_metrics
cleanup_old_events
```

## 22.2. Scheduled jobs

| Job | Frequency |
|---|---|
| aggregate_daily_metrics | Every 15 minutes / hourly |
| publish_scheduled_episode | Every minute |
| expire_ad_reward_sessions | Every 5 minutes |
| sync_subscription_status | Every hour |
| cleanup_old_events | Daily |

---

# 23. Storage

## 23.1. Storage provider

Khuyến nghị:

```txt
Cloudflare R2
```

Lý do:

- Rẻ.
- Không tính egress kiểu AWS S3.
- Phù hợp ảnh cover/banner/audio.

## 23.2. Asset types

```txt
story_cover
banner_image
avatar
audio_story
ambient_sound
editor_upload
```

## 23.3. Database asset table

```sql
CREATE TABLE media_assets (
  id UUID PRIMARY KEY,
  url TEXT NOT NULL,
  storage_key TEXT NOT NULL,
  type TEXT NOT NULL,
  mime_type TEXT,
  size_bytes BIGINT,
  width INT,
  height INT,
  uploaded_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

---

# 24. Security

## 24.1. API Security

- JWT access token ngắn hạn.
- Refresh token dài hạn.
- Rate limit login.
- Rate limit unlock.
- Validate app version.
- Validate device id.
- Không tin client về coin balance, unlock price, reward amount.

## 24.2. Admin Security

- Admin login riêng.
- Bắt buộc 2FA sau này.
- Role-based access control.
- Audit log tất cả thao tác nhạy cảm.
- Không cho editor sửa wallet/user subscription.
- Grant coins phải có lý do.
- Grant coins phải có limit theo role.

## 24.3. Payment Security

- Verify receipt phía backend.
- Lưu raw payload.
- Idempotent transaction.
- Không cộng coins nếu transaction id đã tồn tại.
- Webhook phải verify signature.

## 24.4. Ads Security

- Reward session có expiry.
- Một session chỉ claim được một lần.
- Nên dùng server-side verification nếu ad network hỗ trợ.
- Không tin client báo xem ads thành công.

---

# 25. Performance & Scaling

## 25.1. PostgreSQL indexes quan trọng

```sql
CREATE INDEX idx_users_created_at ON users(created_at);
CREATE INDEX idx_user_login_events_login_at ON user_login_events(login_at);
CREATE INDEX idx_user_login_events_country ON user_login_events(country_code);

CREATE INDEX idx_reading_sessions_started_at ON reading_sessions(started_at);
CREATE INDEX idx_reading_sessions_user ON reading_sessions(user_id);
CREATE INDEX idx_reading_sessions_story ON reading_sessions(story_id);

CREATE INDEX idx_analytics_events_name_time ON analytics_events(event_name, created_at);
CREATE INDEX idx_analytics_events_user_time ON analytics_events(user_id, created_at);
CREATE INDEX idx_analytics_events_country_time ON analytics_events(country_code, created_at);

CREATE INDEX idx_subscriptions_status ON subscriptions(status);
CREATE INDEX idx_subscriptions_user ON subscriptions(user_id);
CREATE INDEX idx_episode_unlocks_user_episode ON episode_unlocks(user_id, episode_id);
```

## 25.2. Cache strategy

Cache bằng Redis:

```txt
home payload
story detail
episode list
genres/tags/moods
app config
feature flags
active banners
```

TTL gợi ý:

```txt
home: 1-5 minutes
story detail: 5-15 minutes
taxonomy: 1 hour
app config: 1-5 minutes
banner: 1-5 minutes
```

## 25.3. Analytics scaling

MVP:

```txt
analytics_events trong PostgreSQL
```

Khi lớn:

```txt
PostgreSQL -> Kafka/Queue -> ClickHouse/BigQuery
```

Không nên scale quá sớm.

---

# 26. MVP Scope

## 26.1. Backend MVP bắt buộc

```txt
Auth guest/social
User profile
Story/episode API
Admin CMS story/episode
Reading progress
Reading session
Wallet
Coin unlock
Free pass unlock
Rewarded ad unlock
Daily check-in
Basic streak
Subscription verify
Banner management
App config
Push token
Basic push campaign
Analytics event tracking
Admin dashboard overview
```

## 26.2. Chưa cần ở MVP

```txt
Author portal
Revenue share
Advanced AI writing assistant
Audio stories
Ambient sound management
Lucky chest phức tạp
Referral system
A/B testing engine đầy đủ
ClickHouse
Kafka
Microservices
```

---

# 27. Implementation Roadmap

## Phase 1: Foundation

Thời gian dự kiến: 2-3 tuần

```txt
- Setup Go project
- Setup PostgreSQL migration
- Setup Redis
- Auth guest/social
- User/device/login event
- Admin auth
- Basic RBAC
- Storage upload
```

## Phase 2: Content CMS

Thời gian dự kiến: 3-4 tuần

```txt
- Story CRUD
- Episode CRUD
- Rich text editor
- Genre/tag/mood
- Publish/schedule
- Story API
- Episode API
```

## Phase 3: Reading & Unlock

Thời gian dự kiến: 3-4 tuần

```txt
- Reading progress
- Reading sessions
- Wallet
- Wallet transactions
- Episode unlock
- Free pass
- Access service
```

## Phase 4: Monetization

Thời gian dự kiến: 3-4 tuần

```txt
- Product config
- IAP verify
- Subscription
- Entitlements
- Rewarded ad sessions
- Purchase dashboard
```

## Phase 5: Retention

Thời gian dự kiến: 2-3 tuần

```txt
- Daily check-in
- Streak
- Daily tasks
- Push token
- Push campaign
- Banner management
```

## Phase 6: Dashboard & Analytics

Thời gian dự kiến: 3-4 tuần

```txt
- Event tracking
- Recent activity dashboard
- Country dashboard
- New vs returning dashboard
- Subscription dashboard
- Story performance dashboard
- Banner analytics
```

---

# 28. Recommended Folder Structure

```txt
moonlit-backend/
  cmd/
    api/
      main.go
    worker/
      main.go

  internal/
    config/
    database/
    redis/
    server/
    middleware/

    auth/
    user/
    admin/
    content/
    reading/
    wallet/
    unlock/
    rewards/
    subscription/
    ads/
    banner/
    appconfig/
    notification/
    analytics/
    storage/
    recommendation/

  ent/
    schema/

  migrations/

  pkg/
    jwt/
    errors/
    response/
    pagination/
    validator/
    logger/
```

---

# 29. Các nguyên tắc kỹ thuật quan trọng

## 29.1. Không tin client

Client không được quyết định:

```txt
coin balance
episode price
unlock status
reward amount
subscription status
ad completion
```

Backend là nguồn sự thật.

## 29.2. Mọi giao dịch tiền ảo phải có ledger

Bất kỳ cộng/trừ coins/free pass đều phải ghi vào:

```txt
wallet_transactions
```

## 29.3. Unlock phải idempotent

Không được trừ coins 2 lần nếu user bấm unlock nhiều lần.

## 29.4. Dashboard phải dựa trên event chuẩn

Không nên mỗi chỗ log một kiểu. Tất cả event nên đi qua:

```txt
AnalyticsService.Track()
```

## 29.5. Admin action phải audit

Các thao tác sau bắt buộc audit:

```txt
publish story
edit published episode
grant coins
ban user
change app config
send push campaign
change product config
change banner
```

---

# 30. Kết luận

Backend của Moonlit Stories nên được thiết kế như một hệ thống giải trí đọc truyện theo tập, không chỉ là CRUD truyện.

Các phần sống còn gồm:

```txt
1. Content CMS mạnh
2. Reading progress/session tracking
3. Wallet transaction ledger
4. Episode unlock engine
5. Subscription entitlement
6. Ads reward verification
7. Daily reward/streak
8. Banner/app config remote control
9. Push notification
10. Analytics dashboard
```

Dashboard admin cần tập trung vào 4 nhóm bạn yêu cầu:

```txt
1. User gần đây đăng nhập từ quốc gia nào và đang đọc truyện gì
2. User nào đang subscribe
3. User nào là New User / Returning User
4. Quản lý truyện, episode, API config, banner, push, monetization
```

Hướng triển khai tốt nhất:

```txt
Go modular monolith
PostgreSQL
Redis
Asynq worker
Cloudflare R2
NextJS Admin
RevenueCat/IAP
FCM
Internal analytics events
```

Làm chắc các bảng sau ngay từ đầu:

```txt
users
user_login_events
reading_sessions
analytics_events
wallets
wallet_transactions
episode_unlocks
subscriptions
banners
admin_audit_logs
```

Nếu các bảng này được thiết kế tốt, bạn sẽ có nền tảng đủ mạnh để vận hành, đo lường và tối ưu Moonlit Stories ở thị trường US/EU.
