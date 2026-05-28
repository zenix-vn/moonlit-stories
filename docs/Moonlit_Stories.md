# Moonlit Stories — Product & Backend Requirements

> Status: In Progress  
> Version: 2.0  
> Updated focus: Product concept + Backend architecture + Admin CMS + Analytics dashboard  
> Target market: United States / Europe  
> Main stack direction: Go + PostgreSQL + Redis + NextJS Admin

---

# 1. Tổng quan sản phẩm

**Moonlit Stories** là ứng dụng đọc truyện tiếng Anh dành cho thị trường Mỹ và châu Âu, tập trung vào trải nghiệm đọc truyện ngắn vào ban đêm.

Ứng dụng hướng đến nhóm người dùng thích đọc các câu chuyện hấp dẫn, nhiều drama, romance, fantasy, werewolf, vampire, revenge, rebirth, cultivation fantasy, martial arts fantasy và short horror trước khi ngủ.

Điểm cốt lõi của Moonlit Stories không phải là một “thư viện sách” truyền thống, mà là một nền tảng giải trí đọc truyện theo từng tập ngắn, có tính gây nghiện, có cliffhanger, có hệ thống mở khóa, reward, streak và subscription.

## 1.1. Tên ứng dụng

**Moonlit Stories**

## 1.2. Slogan

**Addictive English Stories for Late Nights**

## 1.3. Định vị

Moonlit Stories là app đọc truyện tiếng Anh dạng episode ngắn, dễ cuốn, phù hợp đọc trước khi ngủ.

Người dùng có thể đọc miễn phí 1-3 tập đầu. Sau đó, người dùng có thể mở khóa tập tiếp theo bằng:

- Coins.
- Rewarded ads.
- Free pass.
- Daily rewards.
- Subscription.
- Limited-time offers.

## 1.4. Tư duy sản phẩm

Moonlit Stories nên được xây như một app giải trí mobile-first, không phải app đọc sách truyền thống.

Trọng tâm:

- Mở app mỗi tối.
- Nhận daily reward.
- Đọc tiếp truyện đang dở.
- Bị cuốn bởi cliffhanger.
- Unlock tập tiếp theo.
- Quay lại ngày hôm sau.

---

# 2. Đối tượng người dùng

## 2.1. Nhóm người dùng chính

- Người dùng Mỹ và châu Âu thích web novel.
- Người thích romance, drama, fantasy, werewolf, vampire.
- Người thích truyện ngắn, đọc nhanh, không cần cam kết thời gian dài.
- Người có thói quen đọc trước khi ngủ.
- Người khó ngủ, thường đọc truyện để thư giãn.
- Người thích nội dung cliffhanger, twist, revenge, rebirth.
- Người từng dùng Wattpad, WebNovel, GoodNovel, Radish, Dreame.
- Người thích nội dung drama, tiêu đề mạnh, tình tiết cuốn.

## 2.2. Nhu cầu chính

- Muốn có truyện ngắn để đọc nhanh.
- Muốn đọc vào ban đêm với giao diện dịu mắt.
- Muốn nội dung cuốn ngay từ những tập đầu.
- Muốn có nhiều cách đọc tiếp mà không bị ép trả tiền quá gắt.
- Muốn app gợi ý truyện theo mood thay vì chỉ theo genre.
- Muốn được reward khi quay lại app hằng ngày.

---

# 3. Vấn đề thị trường

Các app đọc truyện hiện tại thường có một số vấn đề:

- Giao diện khá nặng, giống kho sách hơn là app giải trí.
- Truyện dài, khó bắt đầu.
- Trải nghiệm đọc ban đêm chưa được tối ưu.
- Monetization đôi khi gây khó chịu.
- Subscription khó hiểu, subscribe rồi vẫn bị khóa nhiều nội dung.
- Recommendation thường dựa nhiều vào genre, chưa dựa vào mood/cảm xúc.
- User dễ bỏ app nếu không có thói quen quay lại hằng ngày.
- Một số app tạo cảm giác “bị hút máu” vì coin pricing không rõ ràng.

Moonlit Stories giải quyết bằng cách:

- Tập trung vào trải nghiệm đọc ban đêm.
- Mỗi episode ngắn, đọc trong 3-7 phút.
- Mở đầu bằng hook mạnh.
- Kết tập bằng cliffhanger.
- Có hệ thống daily rewards, coins, streak, nhiệm vụ.
- Cho người dùng chọn truyện theo mood.
- Tối ưu reader mode đẹp, tối, dịu mắt.
- Monetization rõ ràng và mềm hơn đối thủ.

---

# 4. Giá trị cốt lõi

## 4.1. Đọc nhanh, dễ nghiện

Mỗi episode ngắn, có nhịp nhanh, nhiều twist, không bắt người dùng đọc quá lâu.

Mục tiêu của mỗi tập:

- Có conflict rõ.
- Có cảm xúc mạnh.
- Có ít nhất một diễn biến bất ngờ.
- Kết thúc bằng cliffhanger.

## 4.2. Trải nghiệm ban đêm

App cần tối ưu cho hành vi đọc trước khi ngủ:

- Dark theme.
- Warm mode.
- Font dễ đọc.
- Line height thoải mái.
- Sleep timer.
- Ambient sound trong phase sau.
- Brightness control.
- Reader không gây mỏi mắt.

## 4.3. Miễn phí có kiểm soát

User được đọc miễn phí một phần đủ để bị cuốn, sau đó có nhiều cách đọc tiếp:

- Dùng coins.
- Xem rewarded ads.
- Dùng free pass.
- Làm nhiệm vụ.
- Đăng ký subscription.

## 4.4. Cá nhân hóa theo mood

Thay vì chỉ chọn genre, người dùng có thể chọn:

- I want drama.
- I want romance.
- I want revenge.
- I want something dark.
- I want fantasy.
- I want a strong female lead.
- I want an overpowered hero.
- I only have 5 minutes.
- I want something scary.
- I want a quick twist.

---

# 5. Thể loại nội dung

## 5.1. Romance Drama

Truyện tình cảm nhiều biến cố, phản bội, hợp đồng hôn nhân, tình yêu sai trái, bí mật thân thế.

Ví dụ:

- The Billionaire’s Fake Wife.
- His Secret Obsession.
- The CEO’s Hidden Heir.

## 5.2. Billionaire Romance

Thể loại dễ bán tại thị trường Mỹ/Âu.

Mô típ:

- Contract marriage.
- Fake wife.
- Hidden child.
- Cold CEO.
- Forbidden love.
- Ex-lover returns.

## 5.3. Werewolf & Vampire

Fantasy romance phổ biến ở thị trường US/EU.

Mô típ:

- Alpha mate.
- Rejected mate.
- Vampire prince.
- Cursed bloodline.
- Pack war.
- Forbidden bond.

## 5.4. Revenge & Rebirth

Truyện báo thù, sống lại, làm lại cuộc đời.

Mô típ:

- Bị phản bội rồi trọng sinh.
- Nữ chính bị hại và quay lại trả thù.
- Nhân vật yếu trở thành kẻ mạnh.
- Biết trước tương lai để thay đổi số phận.

## 5.5. Cultivation Fantasy

Phiên bản tiếng Anh hóa của tiên hiệp/huyền huyễn.

Nên dùng thuật ngữ dễ hiểu:

- Cultivation.
- Spirit Realm.
- Sword Soul.
- Ancient Sect.
- Immortal Path.
- Heavenly Trial.

Không nên dùng quá nhiều thuật ngữ Hán Việt khó hiểu với user phương Tây.

## 5.6. Martial Arts Fantasy

Phiên bản kiếm hiệp/võ hiệp dễ tiếp cận hơn.

Mô típ:

- Sword master.
- Fallen clan.
- Ancient blade.
- Hidden technique.
- Martial tournament.
- Revenge journey.

## 5.7. Short Horror

Rất hợp với concept đọc đêm.

Mô típ:

- Tin nhắn lúc nửa đêm.
- Căn phòng bị nguyền.
- Người đã chết gửi thư.
- Ứng dụng lạ dự đoán cái chết.
- Câu chuyện 3-5 phút nhưng ám ảnh.

## 5.8. Mystery Chat Stories

Truyện dạng tin nhắn, nhật ký, hồ sơ điều tra.

Đặc điểm:

- Đọc nhanh.
- Dễ viral.
- Phù hợp mobile.
- Có thể kết hợp audio/sound effect sau này.

---

# 6. Gameplay đọc truyện

Moonlit Stories nên được thiết kế giống một entertainment app hơn là app đọc sách truyền thống.

## 6.1. Vòng lặp chính

1. User mở app vào buổi tối.
2. Nhận daily reward.
3. App gợi ý truyện theo mood.
4. User đọc 1-3 tập miễn phí.
5. Tập miễn phí kết thúc bằng cliffhanger.
6. User mở khóa tập tiếp theo bằng coins, ads, free pass hoặc premium.
7. App ghi nhận reading progress và streak.
8. User nhận nhiệm vụ/reward.
9. User quay lại ngày hôm sau để nhận reward và đọc tiếp.

## 6.2. Cấu trúc mỗi truyện

Mỗi truyện nên chia thành season.

- 1 season: 30-80 episodes.
- 1 episode: 800-1,500 từ.
- Thời gian đọc: 3-7 phút.
- 3 tập đầu: cực mạnh, phải khiến user muốn đọc tiếp.
- Mỗi tập có 1 twist nhỏ.
- Mỗi 5 tập có 1 twist lớn.
- Cuối season mở ra conflict mới.

## 6.3. Công thức một episode

Một episode nên có cấu trúc:

1. Mở bằng tình huống căng.
2. Có conflict rõ ràng.
3. Có cảm xúc mạnh.
4. Có một diễn biến bất ngờ.
5. Kết bằng cliffhanger.

Ví dụ cliffhanger:

> When Emma opened the envelope, she saw a photo of herself... taken tomorrow.

> The system notification appeared: Mission failed. Host will die in 10 minutes.

> Then the prince knelt before her enemy — and called her Mother.

---

# 7. Hệ thống mở khóa nội dung

## 7.1. Free episodes

Mặc định mỗi truyện cho đọc miễn phí:

- Episode 1: Free.
- Episode 2: Free.
- Episode 3: Free.
- Episode 4 trở đi: Locked.

Episode 3 phải kết thúc bằng cliffhanger mạnh để kích thích user mở khóa.

## 7.2. Unlock options

Khi user gặp tập bị khóa, popup mở khóa hiển thị các lựa chọn:

- Use coins.
- Watch ad.
- Use free pass.
- Go premium.
- Complete task to earn coins.

Ví dụ:

**Unlock Episode 4**

- Use 20 Coins.
- Watch Ad to Unlock.
- Use 1 Free Pass.
- Subscribe MoonPass.

## 7.3. Coin economy

Người dùng kiếm coins bằng:

- Daily check-in: 5-50 coins.
- Watch rewarded ad: 10 coins.
- Read 10 minutes: 5 coins.
- Finish 1 episode: 5 coins.
- Comment on a story: 5 coins.
- Share a story: 10 coins.
- Invite friend: 50 coins.
- Weekly streak reward: 100 coins.

Chi phí mở khóa:

- Truyện thường: 10-20 coins/tập.
- Truyện hot: 20-30 coins/tập.
- Full season bundle: giảm 20-30%.

## 7.4. Coin packs

Gợi ý coin packs:

| Price | Coins |
|---|---:|
| $0.99 | 120 |
| $4.99 | 700 |
| $9.99 | 1,500 |
| $19.99 | 3,500 |
| $49.99 | 10,000 |

Nên luôn cho cảm giác có bonus value.

---

# 8. Subscription strategy

## 8.1. Nguyên tắc

Không nên làm subscription gây cảm giác “subscribe rồi vẫn phải trả quá nhiều”.

Moonlit Stories nên tạo lợi thế bằng mô hình:

- Rõ ràng.
- Giá mềm.
- Có daily unlock.
- Không ads.
- Có bonus reward.
- Không hứa unlimited toàn bộ library nếu chưa kiểm soát được economics.

## 8.2. MVP subscription

MVP chỉ nên launch:

```txt
Free
MoonPass $5.99/month
Coin Packs
```

## 8.3. MoonPass

**MoonPass — $5.99/month**

Bao gồm:

- No ads.
- 1 daily premium unlock.
- 2x daily rewards.
- Offline reading.
- 10 bonus passes/month.
- Cozy themes.

Đây nên là package chính để push.

## 8.4. MoonPass Plus

**MoonPass Plus — $9.99/month**

Bao gồm:

- 3 daily unlocks.
- No ads.
- Unlimited access to selected collections.
- Faster unlock cooldown.
- Exclusive stories.
- Early access.

## 8.5. VIP Night Unlimited

**VIP Night Unlimited — $14.99/month**

Bao gồm:

- Unlimited reading trong selected library.
- Exclusive premium stories.
- Audio bedtime stories.
- Ambient sounds.
- VIP badge.
- Special events.

Lưu ý: Không nên unlimited toàn bộ library ngay từ đầu.

## 8.6. Weekly Pass

**Weekly Pass — $1.99/week**

Dành cho traffic từ TikTok/Reels:

- No ads.
- 1 unlock/day.
- Low friction.
- Dễ convert user mới.

## 8.7. Revenue mix kỳ vọng

| Revenue source | Tỷ trọng kỳ vọng |
|---|---:|
| Coin whales | 40-50% |
| Subscription | 25-35% |
| Rewarded ads | 20-30% |

---

# 9. Retention và gamification

## 9.1. Daily check-in

Ví dụ reward 7 ngày:

| Day | Reward |
|---|---:|
| Day 1 | 10 coins |
| Day 2 | 15 coins |
| Day 3 | 20 coins |
| Day 4 | 30 coins |
| Day 5 | 40 coins |
| Day 6 | 50 coins |
| Day 7 | 1 Free Pass |

## 9.2. Reading streak

Phần thưởng:

- 3-day streak: 20 coins.
- 7-day streak: Free Pass.
- 14-day streak: Night Chest.
- 30-day streak: Premium Trial 24h.

## 9.3. Daily tasks

- Read for 10 minutes.
- Finish 1 episode.
- Watch an ad.
- Share a story.
- Comment on a story.
- Try a new genre.
- Add a story to library.

## 9.4. Weekly quests

- Read 20 episodes.
- Complete 1 story arc.
- Invite 1 friend.
- Unlock 5 episodes.
- Maintain 7-day streak.

## 9.5. Lucky chest

Có thể để phase sau.

Phần thưởng:

- Coins.
- Free Pass.
- Discount coupon.
- Premium trial.
- Exclusive cover.
- Avatar frame.

---

# 10. Push notification

Push notification cần viết theo kiểu drama, không viết khô.

Không nên:

> New chapter available.

Nên dùng:

> He finally discovered her secret. Episode 12 is now unlocked.

> You stopped right before the biggest twist.

> Your 7-day streak reward is waiting.

> She lied. Again. Read what happens next.

> Your free MoonPass expires in 2 hours.

> A new episode of Reborn as the Villain Queen is live.

## 10.1. Các loại push

- New episode.
- Continue reading.
- Daily reward.
- Streak reminder.
- Subscription offer.
- Comeback.
- Free pass expiring.
- Story recommendation.

---

# 11. Tính năng chính của mobile app

## 11.1. Home Screen

Home là màn hình quan trọng nhất, cần tạo cảm giác muốn đọc ngay.

Thành phần:

- Greeting: Good Evening.
- Coin balance.
- Free pass balance.
- Featured story banner.
- Continue Reading.
- Tonight’s Picks.
- Trending Now.
- Free Episodes Today.
- Recommended by Mood.
- Promotion banner.
- Bottom navigation.

Mood tổng thể:

- Dark.
- Premium.
- Fantasy.
- Cozy.
- Late-night.
- Purple/blue gradient.
- Card ảnh truyện lớn, cảm xúc mạnh.

## 11.2. Reader Screen

Reader phải cực kỳ đẹp và dễ đọc.

Tính năng:

- Dark mode.
- Warm mode.
- Font size control.
- Font family selection.
- Brightness control.
- Scroll mode.
- Page mode.
- Reading progress.
- Estimated time left.
- Bookmark.
- Highlight.
- Sleep timer.
- Ambient sound.

## 11.3. Unlock Screen

Màn hình mở khóa tập tiếp theo.

Các option:

- Use coins.
- Watch ad.
- Use free pass.
- Go premium.
- Earn coins.

Popup nên nhẹ, không gây khó chịu.

## 11.4. Discover Screen

Discover không chỉ lọc theo genre mà theo mood.

Mood filter:

- Drama.
- Romance.
- Revenge.
- Dark.
- Fantasy.
- Strong heroine.
- Overpowered hero.
- Short horror.
- Emotional.
- Mystery.

Genre filter:

- Billionaire.
- Werewolf.
- Vampire.
- Cultivation.
- Martial Arts.
- Horror.
- Mystery.
- Rebirth.
- System.
- Isekai.

## 11.5. Rewards Screen

Bao gồm:

- Daily check-in.
- Streak.
- Daily tasks.
- Weekly quests.
- Lucky chest.
- Invite friends.
- Watch ads.
- Coin history.

## 11.6. Library Screen

Bao gồm:

- Continue Reading.
- Saved.
- Completed.
- Downloaded.
- Unlocked Episodes.
- Reading History.

## 11.7. Profile Screen

Bao gồm:

- Avatar.
- Username.
- Level.
- Coin balance.
- Free pass balance.
- Subscription status.
- Reading stats.
- Purchase history.
- Settings.
- Help & support.

---

# 12. UI/UX định hướng thiết kế

## 12.1. Visual style

Phong cách:

- Dark fantasy.
- Premium mobile app.
- Cozy night reading.
- Purple/indigo accent.
- Soft glow.
- Rounded cards.
- High-quality covers.
- Clean typography.

## 12.2. Color palette

| Token | Color |
|---|---|
| Background | `#050816` |
| Surface | `#101426` |
| Card | `#171B31` |
| Primary Purple | `#8B5CF6` |
| Secondary Purple | `#A855F7` |
| Gold Coin | `#FBBF24` |
| Text Primary | `#F8FAFC` |
| Text Secondary | `#CBD5E1` |
| Border | `#2D334A` |

## 12.3. Typography

Gợi ý:

- Heading: Playfair Display / Georgia-like serif.
- Body reading: Merriweather / Literata / Georgia.
- UI text: Inter / SF Pro / Roboto.

---

# 13. Hệ thống nội dung ban đầu

MVP nên có:

- 30 truyện.
- Mỗi truyện 10-30 episodes.
- 3 tập đầu miễn phí.
- Ít nhất 5 genre chính:
  - Billionaire Romance.
  - Werewolf Romance.
  - Rebirth/Revenge.
  - Cultivation Fantasy.
  - Short Horror.

Mỗi truyện cần:

- Cover đẹp.
- Hook dưới 200 ký tự.
- Tags rõ ràng.
- 3 episode đầu cực mạnh.
- Episode 3 có cliffhanger mạnh.
- Lịch publish rõ ràng.

---

# 14. Series mẫu

## 14.1. Reborn as the Villain Queen

Genre:

- Fantasy.
- Rebirth.
- Revenge.
- Romance.

Hook:

> Executed for a crime she didn’t commit, Queen Elara wakes up five years earlier — on the day she met the man who betrayed her.

## 14.2. The Billionaire’s Fake Wife

Genre:

- Billionaire.
- Romance.
- Drama.

Hook:

> She signed a one-year marriage contract. But the man she married already knew her real identity.

## 14.3. My Werewolf Ex Is My Boss

Genre:

- Werewolf.
- Romance.
- Drama.

Hook:

> She escaped her alpha mate three years ago. Now he owns the company she works for.

## 14.4. The Last Sword Saint

Genre:

- Martial Arts Fantasy.
- Cultivation.
- Action.

Hook:

> In a world where sword spirits choose their masters, the weakest boy awakens the oldest blade in history.

## 14.5. 11:59 PM

Genre:

- Short Horror.
- Mystery.
- Supernatural.

Hook:

> Every night at 11:59, Lily receives a text from someone who died last year.

## 14.6. Bound by the Moon

Genre:

- Werewolf.
- Fantasy Romance.
- Forbidden Love.

Hook:

> She was born without a wolf. He was the alpha who was ordered to kill her.

## 14.7. His Secret Obsession

Genre:

- Romance.
- Thriller.
- Drama.

Hook:

> He watched her from the shadows for years. Now she has no choice but to marry him.

## 14.8. The System Chose Me

Genre:

- System.
- Leveling.
- Urban Fantasy.

Hook:

> A failed student receives a mysterious notification: Complete the mission, or lose one year of your life.

---

# 15. Community nhẹ

Không nên xây mạng xã hội phức tạp ngay từ đầu.

Nên có:

- Comment theo episode.
- Like comment.
- Vote nhân vật.
- Poll cuối tập.
- Review truyện.
- Follow truyện.
- Badge top reader.

Ví dụ poll:

> Should Elara forgive him?

Options:

- Never.
- Only if he suffers first.
- Yes, but not now.
- I don’t trust him.

---

# 16. AI-assisted content workflow

Có thể dùng AI để hỗ trợ sản xuất nội dung, nhưng không nên publish tự động.

Quy trình đề xuất:

1. Editor tạo concept truyện.
2. AI hỗ trợ outline season.
3. AI tạo draft episode.
4. Human editor chỉnh thoại, pacing, văn hóa, logic.
5. AI hỗ trợ tạo cliffhanger variants.
6. Editor duyệt lần cuối.
7. Publish lên app.

AI có thể hỗ trợ:

- Outline truyện.
- Viết bản nháp.
- Tóm tắt tập trước.
- Tạo hook.
- Gợi ý title.
- Localize thuật ngữ fantasy.
- Viết push notification.
- Tạo mô tả truyện.
- Tạo tags.

---

# 17. Backend architecture

## 17.1. Định hướng backend

Backend của Moonlit Stories không nên chỉ là CRUD truyện.

Backend cần phục vụ:

- Content CMS.
- Reader progress.
- Wallet/coins/free pass.
- Episode unlock.
- Rewarded ads.
- Subscription entitlement.
- Daily reward/streak.
- Push notification.
- Banner/app config remote control.
- Analytics dashboard.
- Admin operation.

## 17.2. Stack đề xuất

```txt
Backend: Go
Framework: Echo hoặc Fiber
Database: PostgreSQL
ORM/Query: Ent hoặc SQLC
Cache: Redis
Queue Worker: Asynq hoặc River
Storage: Cloudflare R2 hoặc AWS S3
Admin CMS: NextJS
Payment/IAP: RevenueCat hoặc Apple/Google verification
Push: Firebase Cloud Messaging
Ads: AdMob/AppLovin
Analytics: PostgreSQL events trước, sau có thể dùng ClickHouse/BigQuery
```

Khuyến nghị chính:

```txt
Go + Ent + PostgreSQL + Redis + Asynq + NextJS Admin
```

## 17.3. Kiến trúc tổng quan

```txt
Mobile App
  |
  | REST API / GraphQL API
  v
Go Backend API
  |
  |-- Auth / User
  |-- Story / Episode
  |-- Reader Progress
  |-- Unlock / Coin Wallet
  |-- Reward / Streak / Tasks
  |-- Subscription / IAP
  |-- Ads Reward Verification
  |-- Recommendation / Mood
  |-- Banner / App Config
  |-- Push Notification
  |-- Analytics Events
  |-- Admin API
  |
PostgreSQL
Redis
S3/R2 Storage
Queue Worker
  |
NextJS Admin CMS
```

## 17.4. Backend module structure

```txt
internal/
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
```

Mỗi module nên có:

```txt
handler.go
service.go
repository.go
dto.go
model.go
```

---

# 18. Database model tổng quan

## 18.1. Auth & User

```txt
users
user_profiles
user_devices
user_login_events
```

Dùng để:

- Quản lý user.
- Biết user từ quốc gia nào.
- Biết thiết bị/app version.
- Biết lần đăng nhập gần đây.
- Phân loại New User / Returning User.

## 18.2. Content

```txt
stories
seasons
episodes
episode_versions
genres
tags
moods
story_genres
story_tags
story_moods
```

Dùng để:

- Quản lý truyện.
- Quản lý episode.
- Quản lý version nội dung.
- Gắn genre/tag/mood.
- Publish/schedule/archive.

## 18.3. Reading

```txt
reading_progress
reading_sessions
library_items
bookmarks
highlights
```

Dùng để:

- Theo dõi user đọc truyện gì.
- Biết user đọc tới đâu.
- Biết thời lượng đọc.
- Hiển thị Continue Reading.
- Làm dashboard recent reading.

## 18.4. Wallet & Unlock

```txt
wallets
wallet_transactions
episode_unlocks
```

Dùng để:

- Lưu coin/free pass balance.
- Ghi lịch sử cộng/trừ.
- Mở khóa episode.
- Audit giao dịch.

## 18.5. Rewards

```txt
daily_checkins
user_streaks
tasks
user_task_progress
reward_logs
```

Dùng để:

- Daily check-in.
- Reading streak.
- Daily tasks.
- Weekly quests.
- Reward history.

## 18.6. Commerce

```txt
products
purchases
subscriptions
subscription_entitlements
```

Dùng để:

- Coin packs.
- Subscription.
- IAP verification.
- Subscription entitlement.

## 18.7. Ads

```txt
ad_reward_sessions
```

Dùng để:

- Verify rewarded ads.
- Mở khóa bằng ads.
- Cộng coins qua ads.

## 18.8. Banner & Config

```txt
banners
banner_impressions
banner_clicks
app_configs
feature_flags
```

Dùng để:

- Quản lý banner trong app.
- Đo CTR banner.
- Remote config.
- Feature flags.
- Force update/maintenance mode.

## 18.9. Notification

```txt
push_tokens
push_templates
push_campaigns
push_logs
```

Dùng để:

- Gửi push.
- Quản lý campaign.
- Theo dõi push sent/opened.

## 18.10. Analytics

```txt
analytics_events
daily_user_metrics
daily_story_metrics
daily_country_metrics
```

Dùng để:

- Tracking hành vi user.
- Dashboard.
- Report theo ngày.
- Story performance.
- Country performance.

## 18.11. Admin

```txt
admin_users
admin_roles
admin_user_roles
admin_audit_logs
```

Dùng để:

- Admin login.
- Phân quyền.
- Audit thao tác nhạy cảm.

---

# 19. Admin Dashboard

## 19.1. Mục tiêu dashboard

Dashboard cần giúp chủ app quan sát:

1. User gần đây đăng nhập từ nước nào.
2. User gần đây đang đọc truyện gì.
3. User nào đang subscribe.
4. User nào là New User.
5. User nào là Returning User.
6. Truyện nào đang được đọc nhiều.
7. Episode nào bị drop-off nhiều.
8. Banner nào có CTR tốt.
9. Revenue đến từ coins, subscription hay ads.
10. Quốc gia nào có user/revenue tốt nhất.

## 19.2. Dashboard overview

Các card chính:

- DAU.
- New Users.
- Returning Users.
- Active Subscribers.
- Revenue Today.
- Coin Purchases.
- Episode Unlocks.
- Rewarded Ad Unlocks.
- Average Reading Time.
- D1 Retention.
- Push Open Rate.
- Banner CTR.

## 19.3. Recent Activity

Bảng realtime/gần realtime:

| Time | User | Country | Device | Action | Story | Episode | Subscription |
|---|---|---|---|---|---|---|---|
| 22:31 | emma***@gmail.com | US | iOS | Reading | Reborn as the Villain Queen | Ep 4 | Free |
| 22:30 | guest_81231 | GB | Android | Unlocked by Ad | 11:59 PM | Ep 6 | Free |
| 22:28 | anna***@icloud.com | CA | iOS | Subscribed | - | - | MoonPass |

Actions có thể gồm:

- App opened.
- Login.
- Reading.
- Episode completed.
- Unlock by coin.
- Unlock by ad.
- Unlock by free pass.
- Subscribe.
- Purchase coins.
- Click banner.
- Open push.

## 19.4. User Geography Dashboard

Hiển thị theo quốc gia:

| Country | New Users | Returning Users | Active Users | Subscribers | Revenue | Avg Reading Time | Top Story |
|---|---:|---:|---:|---:|---:|---:|---|

Dùng để biết thị trường nào đang tốt.

## 19.5. New vs Returning Dashboard

Định nghĩa:

**New User**

User có `created_at` nằm trong khoảng thời gian đang lọc.

**Returning User**

User có `app_opened/session_started` trong khoảng thời gian đang lọc và `created_at` trước khoảng thời gian đó.

Chart cần có:

- New Users.
- Returning Users.
- Total Active Users.
- Returning Rate.

## 19.6. Subscription Dashboard

Theo dõi:

- Active subscribers.
- New subscriptions today.
- Canceled today.
- Expired users.
- MRR.
- Revenue by plan.
- Revenue by country.
- Platform split: iOS/Android.

Bảng:

| User | Country | Plan | Status | Started At | Expires At | Platform | Revenue |
|---|---|---|---|---|---|---|---|

## 19.7. Story Performance Dashboard

Theo dõi:

- Story views.
- Unique readers.
- Episode starts.
- Episode completions.
- Unlocks.
- Revenue.
- Completion rate.
- Average reading time.
- Drop-off by episode.

Funnel quan trọng:

```txt
Episode 1 started
Episode 1 completed
Episode 2 started
Episode 2 completed
Episode 3 completed
Episode 4 locked viewed
Episode 4 unlocked
```

Đây là funnel sống còn vì app monetization sau 3 tập free.

## 19.8. Banner Dashboard

Theo dõi:

- Impressions.
- Clicks.
- CTR.
- Conversion.
- Revenue attributed.
- Performance by placement.
- Performance by country.
- Performance by user segment.

---

# 20. Admin CMS

## 20.1. Dashboard

Route:

```txt
/admin/dashboard
```

Chức năng:

- Overview metrics.
- User activity.
- Revenue summary.
- Top stories.
- Recent subscriptions.
- Country activity.

## 20.2. Story Management

Route:

```txt
/admin/stories
/admin/stories/new
/admin/stories/:id
```

Chức năng:

- Tạo/sửa/xóa story.
- Upload cover.
- Chọn genre/tag/mood.
- Set free episode count.
- Set default coin price.
- Set featured/hot/editor pick.
- Publish/schedule/archive.
- Xem analytics của story.

## 20.3. Episode Editor

Route:

```txt
/admin/stories/:storyId/episodes
/admin/episodes/:episodeId/edit
```

Chức năng:

- Rich text editor.
- Preview mobile reader.
- Word count tự động.
- Estimated reading time tự động.
- Draft.
- Schedule publish.
- Publish.
- Archive.
- Version history.
- Rollback version.
- Set free/locked.
- Set coin price override.

## 20.4. Taxonomy

Route:

```txt
/admin/taxonomy
```

Quản lý:

- Genres.
- Tags.
- Moods.
- Sort order.
- Active/inactive.

## 20.5. User Management

Route:

```txt
/admin/users
/admin/users/:id
```

Chức năng:

- Search user.
- Filter by country.
- Filter New/Returning.
- Filter subscription status.
- View reading history.
- View login history.
- View wallet transactions.
- View purchases.
- View subscription.
- Ban/unban user.
- Grant coins/free pass.

Các thao tác grant coins/free pass phải có audit log.

## 20.6. Subscription Management

Route:

```txt
/admin/subscriptions
```

Chức năng:

- Xem active subscriptions.
- Xem canceled/expired.
- Search theo email/user.
- Filter theo plan/platform/country.
- Xem receipt/webhook payload.

## 20.7. Banner Management

Route:

```txt
/admin/banners
/admin/banners/new
/admin/banners/:id
```

Chức năng:

- Tạo banner.
- Upload image.
- Chọn placement.
- Target country.
- Target user type.
- Target subscription status.
- Set priority.
- Set start/end time.
- Active/inactive.
- Xem impressions/clicks/CTR.

Placement:

- home_top.
- home_mid.
- reader_end.
- unlock_popup.
- reward_screen.
- profile_top.
- discover_top.

Target user type:

- all_users.
- new_users.
- returning_users.
- free_users.
- subscribers.
- non_subscribers.

## 20.8. Push Notification Management

Route:

```txt
/admin/push
/admin/push/campaigns
/admin/push/templates
```

Chức năng:

- Tạo campaign.
- Chọn target segment.
- Schedule.
- Send test notification.
- Preview notification.
- Xem sent/opened stats.

## 20.9. App Config / API Management

Route:

```txt
/admin/app-config
/admin/api-management
```

Chức năng:

- Maintenance mode.
- Force update.
- Min supported app version.
- Reward config.
- Coin price config.
- Ads config.
- Feature flags.
- API health.
- Webhook secrets.
- External service status.
- Rate limit config.
- Error logs.

---

# 21. Admin roles & permissions

## 21.1. Roles

- super_admin.
- admin.
- content_manager.
- editor.
- writer.
- marketing.
- support.
- finance.
- analyst.

## 21.2. Permission matrix

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

## 21.3. Audit log bắt buộc

Các thao tác phải ghi audit:

- Publish story.
- Edit published episode.
- Rollback episode version.
- Grant coins.
- Grant free pass.
- Ban user.
- Change app config.
- Send push campaign.
- Change product config.
- Change banner.

---

# 22. Public Mobile API

## 22.1. Auth

```txt
POST /v1/auth/guest
POST /v1/auth/google
POST /v1/auth/apple
POST /v1/auth/refresh
GET  /v1/me
PATCH /v1/me
```

## 22.2. Home

```txt
GET /v1/home
GET /v1/home/sections
```

Response nên gồm:

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
  "recommendedByMood": [],
  "banners": []
}
```

## 22.3. Discover

```txt
GET /v1/discover
GET /v1/genres
GET /v1/tags
GET /v1/moods
GET /v1/stories?genre=werewolf&mood=revenge
```

## 22.4. Story & Episode

```txt
GET /v1/stories/:slug
GET /v1/stories/:storyId/episodes
GET /v1/episodes/:episodeId
GET /v1/episodes/:episodeId/access
```

## 22.5. Reading

```txt
POST /v1/reading/session/start
POST /v1/reading/session/end
POST /v1/reading/progress
GET  /v1/reading/continue
GET  /v1/library
```

## 22.6. Unlock

```txt
POST /v1/episodes/:episodeId/unlock/coins
POST /v1/episodes/:episodeId/unlock/free-pass
POST /v1/episodes/:episodeId/unlock/ad
```

## 22.7. Rewards

```txt
GET  /v1/rewards/dashboard
POST /v1/rewards/checkin
GET  /v1/tasks/daily
POST /v1/tasks/:taskId/claim
```

## 22.8. Wallet

```txt
GET /v1/wallet
GET /v1/wallet/transactions
```

## 22.9. IAP

```txt
GET  /v1/products
POST /v1/iap/verify
POST /v1/iap/webhook/revenuecat
```

## 22.10. Banner

```txt
GET  /v1/banners?placement=home_top
POST /v1/banners/:bannerId/impression
POST /v1/banners/:bannerId/click
```

## 22.11. Analytics

```txt
POST /v1/events
POST /v1/events/batch
```

## 22.12. App Config

```txt
GET /v1/app/config
```

---

# 23. Admin API

## 23.1. Dashboard

```txt
GET /admin/dashboard/overview
GET /admin/dashboard/recent-activity
GET /admin/dashboard/countries
GET /admin/dashboard/new-returning-users
GET /admin/dashboard/subscriptions
GET /admin/dashboard/story-performance
GET /admin/dashboard/banner-performance
```

## 23.2. Stories

```txt
GET    /admin/stories
POST   /admin/stories
GET    /admin/stories/:id
PATCH  /admin/stories/:id
DELETE /admin/stories/:id
POST   /admin/stories/:id/publish
POST   /admin/stories/:id/archive
```

## 23.3. Episodes

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

## 23.4. Users

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

## 23.5. Subscriptions & Purchases

```txt
GET /admin/subscriptions
GET /admin/subscriptions/:id
GET /admin/purchases
GET /admin/products
POST /admin/products
PATCH /admin/products/:id
```

## 23.6. Banners

```txt
GET    /admin/banners
POST   /admin/banners
GET    /admin/banners/:id
PATCH  /admin/banners/:id
DELETE /admin/banners/:id
GET    /admin/banners/:id/analytics
```

## 23.7. Push

```txt
GET   /admin/push/campaigns
POST  /admin/push/campaigns
POST  /admin/push/campaigns/:id/send-test
POST  /admin/push/campaigns/:id/schedule
GET   /admin/push/templates
POST  /admin/push/templates
```

## 23.8. App Config

```txt
GET   /admin/app-config
PATCH /admin/app-config/:key
GET   /admin/feature-flags
PATCH /admin/feature-flags/:key
```

---

# 24. Analytics events

## 24.1. App lifecycle

- app_opened.
- app_backgrounded.
- session_started.
- session_ended.

## 24.2. Auth

- signup_completed.
- login_completed.
- guest_created.
- account_linked.

## 24.3. Story

- story_viewed.
- story_saved.
- story_shared.
- story_followed.

## 24.4. Episode

- episode_started.
- episode_progress_updated.
- episode_completed.
- episode_locked_viewed.

## 24.5. Unlock

- unlock_popup_viewed.
- episode_unlocked_by_coin.
- episode_unlocked_by_ad.
- episode_unlocked_by_free_pass.
- episode_unlocked_by_subscription.

## 24.6. Reward

- daily_checkin_viewed.
- daily_checkin_claimed.
- task_completed.
- task_claimed.

## 24.7. Ads

- rewarded_ad_started.
- rewarded_ad_completed.
- rewarded_ad_failed.

## 24.8. Purchase

- coin_pack_viewed.
- coin_pack_purchased.
- subscription_page_viewed.
- subscription_started.
- subscription_canceled.

## 24.9. Push

- push_received.
- push_opened.

## 24.10. Banner

- banner_impression.
- banner_clicked.

---

# 25. Backend business rules quan trọng

## 25.1. Không tin client

Client không được quyết định:

- Coin balance.
- Episode price.
- Unlock status.
- Reward amount.
- Subscription status.
- Ad completion.

Backend là nguồn sự thật.

## 25.2. Wallet phải có ledger

Không cộng/trừ coins trực tiếp vào user mà không ghi log.

Bắt buộc dùng:

```txt
wallet_transactions
```

## 25.3. Unlock phải idempotent

Nếu user bấm unlock nhiều lần, không được trừ coins nhiều lần.

Cần unique constraint:

```txt
UNIQUE(user_id, episode_id)
```

## 25.4. Wallet không được âm

Khi trừ coins/free pass cần lock wallet row bằng transaction.

## 25.5. Subscription nên dùng entitlement

Không nên hard-code logic theo tên package.

Nên dùng entitlement như:

```json
{
  "NO_ADS": true,
  "DAILY_UNLOCKS": 1,
  "REWARD_MULTIPLIER": 2,
  "OFFLINE_READING": true,
  "SELECTED_COLLECTION_ACCESS": true
}
```

## 25.6. Rewarded ads phải verify

Không tin client báo đã xem quảng cáo xong.

Nên có:

```txt
ad_reward_sessions
```

Và chỉ reward khi session được verify.

---

# 26. Worker jobs

Worker nên tách khỏi API process.

## 26.1. Job types

- aggregate_daily_metrics.
- send_push_campaign.
- send_new_episode_notification.
- publish_scheduled_episode.
- expire_ad_reward_sessions.
- sync_subscription_status.
- generate_story_metrics.
- cleanup_old_events.

## 26.2. Scheduled jobs

| Job | Frequency |
|---|---|
| aggregate_daily_metrics | Every 15 minutes / hourly |
| publish_scheduled_episode | Every minute |
| expire_ad_reward_sessions | Every 5 minutes |
| sync_subscription_status | Every hour |
| cleanup_old_events | Daily |

---

# 27. Storage

## 27.1. Provider đề xuất

Khuyến nghị dùng:

```txt
Cloudflare R2
```

Lý do:

- Rẻ.
- Phù hợp ảnh cover/banner/audio.
- Ít áp lực chi phí bandwidth hơn S3 truyền thống.

## 27.2. Asset types

- story_cover.
- banner_image.
- avatar.
- audio_story.
- ambient_sound.
- editor_upload.

---

# 28. Security

## 28.1. API security

- JWT access token ngắn hạn.
- Refresh token dài hạn.
- Rate limit login.
- Rate limit unlock.
- Validate app version.
- Validate device id.
- Không tin client về coin balance/reward/unlock.

## 28.2. Admin security

- Admin login riêng.
- Role-based access control.
- Audit log thao tác nhạy cảm.
- 2FA ở phase sau.
- Grant coins phải có lý do.
- Grant coins phải có limit theo role.

## 28.3. Payment security

- Verify receipt phía backend.
- Lưu raw payload.
- Idempotent transaction.
- Không cộng coins nếu transaction id đã tồn tại.
- Webhook phải verify signature.

## 28.4. Ads security

- Reward session có expiry.
- Một session chỉ claim một lần.
- Dùng server-side verification nếu ad network hỗ trợ.

---

# 29. Performance & scaling

## 29.1. PostgreSQL indexes quan trọng

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

## 29.2. Redis cache

Cache:

- Home payload.
- Story detail.
- Episode list.
- Genres/tags/moods.
- App config.
- Feature flags.
- Active banners.

TTL gợi ý:

| Data | TTL |
|---|---|
| home | 1-5 phút |
| story detail | 5-15 phút |
| taxonomy | 1 giờ |
| app config | 1-5 phút |
| banner | 1-5 phút |

## 29.3. Analytics scaling

MVP:

```txt
analytics_events trong PostgreSQL
```

Khi lớn:

```txt
PostgreSQL -> Queue/Kafka -> ClickHouse/BigQuery
```

Không nên scale quá sớm.

---

# 30. MVP đề xuất

## 30.1. Mục tiêu MVP

Kiểm chứng 4 thứ:

1. Người dùng có bị cuốn bởi 3 tập đầu không?
2. User có chấp nhận xem ads/mua coins để đọc tiếp không?
3. User có quay lại hằng ngày không?
4. Thể loại nào có retention và revenue tốt nhất?

## 30.2. Tính năng MVP mobile

- Authentication đơn giản.
- Home Screen.
- Discover Screen.
- Reader Screen.
- Library.
- Rewards.
- Profile.
- Coin system.
- Rewarded ads.
- In-app purchase.
- Daily check-in.
- Push notification.
- Tracking analytics.

## 30.3. Tính năng MVP admin/backend

- Admin login.
- Story CMS.
- Episode CMS.
- Genre/tag/mood.
- Banner management.
- App config.
- User dashboard.
- Recent reading dashboard.
- Subscription dashboard.
- New vs Returning dashboard.
- Wallet transaction.
- Episode unlock.
- Rewarded ad verification.
- Push campaign cơ bản.
- Analytics events.

## 30.4. Nội dung MVP

- 30 truyện.
- Mỗi truyện 10-30 episodes.
- 3 tập đầu miễn phí.
- Ít nhất 5 genre chính:
  - Billionaire Romance.
  - Werewolf Romance.
  - Rebirth/Revenge.
  - Cultivation Fantasy.
  - Short Horror.

## 30.5. Chỉ số cần đo

- D1 retention.
- D7 retention.
- D30 retention.
- Average reading time.
- Episodes read per session.
- Free-to-locked conversion.
- Ad watch rate.
- Coin purchase conversion.
- ARPDAU.
- Subscription conversion.
- Story completion rate.
- Genre performance.
- Push open rate.
- Banner CTR.
- Revenue by country.
- Revenue by story.

---

# 31. Roadmap

## Phase 1: Foundation

Mục tiêu:

- Setup backend.
- Setup database.
- Auth.
- User/device/login event.
- Admin auth.
- Storage.

Tính năng:

- Go project structure.
- PostgreSQL migration.
- Redis.
- JWT auth.
- Guest login.
- Google/Apple login.
- Admin login.
- Basic RBAC.
- Cloudflare R2 upload.

## Phase 2: Content CMS

Mục tiêu:

- Quản lý nội dung truyện.

Tính năng:

- Story CRUD.
- Episode CRUD.
- Rich text editor.
- Genre/tag/mood.
- Publish/schedule.
- Story API.
- Episode API.
- Episode version history.

## Phase 3: Reading & Unlock

Mục tiêu:

- Cho user đọc và mở khóa tập.

Tính năng:

- Reading progress.
- Reading sessions.
- Continue reading.
- Wallet.
- Wallet transactions.
- Episode unlock.
- Free pass.
- Access service.

## Phase 4: Monetization

Mục tiêu:

- Kiếm tiền bằng coins/subscription/ads.

Tính năng:

- Product config.
- IAP verify.
- Subscription.
- Entitlements.
- Rewarded ad sessions.
- Purchase dashboard.

## Phase 5: Retention

Mục tiêu:

- Tăng user quay lại.

Tính năng:

- Daily check-in.
- Streak.
- Daily tasks.
- Push token.
- Push campaign.
- Banner management.

## Phase 6: Dashboard & Analytics

Mục tiêu:

- Quan sát và tối ưu vận hành.

Tính năng:

- Event tracking.
- Recent activity dashboard.
- Country dashboard.
- New vs Returning dashboard.
- Subscription dashboard.
- Story performance dashboard.
- Banner analytics.

## Phase 7: Growth

Tính năng:

- Personalized recommendation.
- Mood engine tốt hơn.
- More daily quests.
- Lucky chest.
- Limited-time events.
- Better onboarding.
- A/B testing hooks.
- Referral system.
- Story ranking.

## Phase 8: Premium Experience

Tính năng:

- Audio bedtime stories.
- Ambient sound.
- Sleep timer nâng cao.
- Offline reading.
- Premium collections.
- Exclusive stories.
- Story bundles.
- Advanced typography.

## Phase 9: Creator Platform

Tính năng:

- Author portal.
- Revenue share.
- Submission system.
- Editor workflow.
- AI writing assistant.
- Creator analytics.
- Story marketplace.

---

# 32. Rủi ro sản phẩm

## 32.1. Nội dung không đủ cuốn

Đây là rủi ro lớn nhất.

Nếu 3 tập đầu không đủ hấp dẫn, user sẽ không mở khóa.

Cách xử lý:

- Test nhiều hook.
- A/B testing cover và title.
- Theo dõi drop-off theo từng episode.
- Dùng editor kiểm duyệt chất lượng.
- Đo free-to-locked conversion.

## 32.2. Monetization quá gắt

Nếu khóa quá sớm hoặc ads quá nhiều, user sẽ bỏ app.

Cách xử lý:

- Cho nhiều cách kiếm coins.
- Rewarded ads thay vì ép ads.
- Free pass hằng ngày.
- Giữ session đầu tiên ít quảng cáo.
- Subscription rõ ràng.

## 32.3. Nội dung tiếng Anh không tự nhiên

User Mỹ/Âu rất nhạy với tiếng Anh kém tự nhiên.

Cách xử lý:

- Có editor tiếng Anh.
- Tránh dịch máy thô.
- Localize thuật ngữ.
- Ưu tiên thoại tự nhiên.
- Pacing nhanh.

## 32.4. Cạnh tranh mạnh

Thị trường có Wattpad, WebNovel, GoodNovel, Dreame.

Cách xử lý:

- Chọn niche rõ: late-night addictive stories.
- Trải nghiệm reader tốt.
- Mood recommendation.
- Nội dung Đông-Tây kết hợp.
- Tập trung vào mobile-first entertainment.
- Monetization fair hơn đối thủ.

---

# 33. Chiến lược marketing

## 33.1. TikTok/Reels

Tạo video ngắn dạng story hook.

Ví dụ text overlay:

> She married him to save her family.  
> He married her to destroy it.

CTA:

> Read free on Moonlit Stories.

## 33.2. Facebook/Instagram ads

Creative:

- Dark fantasy cover.
- Romance drama hook.
- “Read 3 episodes free”.
- “Unlock with ads or coins”.

## 33.3. ASO keywords

Keywords:

- romance stories.
- werewolf stories.
- fantasy novels.
- billionaire romance.
- bedtime stories.
- drama stories.
- web novels.
- reading app.
- free stories.
- vampire romance.

## 33.4. App Store screenshots

Screenshot ideas:

1. Addictive stories for late nights.
2. Read 3 episodes free.
3. Unlock with coins, ads, or free pass.
4. Choose stories by mood.
5. Track your reading streak.
6. Enjoy beautiful night mode.

---

# 34. Kết luận

Moonlit Stories có thể trở thành một app đọc truyện tiếng Anh hấp dẫn nếu tập trung đúng vào 3 yếu tố:

1. Nội dung ngắn, hook mạnh, cliffhanger tốt.
2. Trải nghiệm đọc ban đêm đẹp và dễ chịu.
3. Monetization linh hoạt: coins, rewarded ads, free pass, premium.

Không nên xây app như một thư viện sách thông thường.

Nên xây như một entertainment app nơi người dùng mở mỗi đêm để đọc tiếp câu chuyện đang dang dở.

Backend cần được thiết kế đủ mạnh ngay từ đầu để hỗ trợ:

- Content CMS.
- Admin dashboard.
- Story/episode analytics.
- User country tracking.
- New/Returning user tracking.
- Subscription tracking.
- Wallet/coins/free pass.
- Unlock engine.
- Rewarded ads.
- Banner/app config.
- Push notification.
- Retention/gamification.

Stack đề xuất:

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

Các bảng sống còn cần làm chắc:

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

Nếu làm tốt phần nội dung, reader experience, dashboard đo lường và monetization mềm hơn đối thủ, Moonlit Stories có tiềm năng tốt ở thị trường Mỹ và châu Âu.
