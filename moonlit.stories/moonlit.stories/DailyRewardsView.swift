import SwiftUI

struct DailyRewardsView: View {
    @State private var dashboard: RewardsDashboard? = nil
    @State private var tasks: [DailyTaskProgress] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var isCheckingIn = false
    @State private var claimingTaskId: String? = nil

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                headerSection

                if isLoading {
                    loadingSection
                } else if let dashboard {
                    checkinSummary(dashboard: dashboard)
                    rewardCalendarSection(dashboard: dashboard)
                    taskSection(dashboard: dashboard)
                } else {
                    emptyStateSection
                }

                Spacer().frame(height: 40)
            }
            .padding(20)
        }
        .background(Color.mlBg.ignoresSafeArea())
        .navigationTitle("Daily Rewards")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Check in every day and earn coins, free passes, and streak rewards.")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.white)
                .lineLimit(3)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.mlPink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var loadingSection: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(Color.mlPurple)
                .scaleEffect(1.1)
            Text("Loading rewards...")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.mlSubtext)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.mlCard.opacity(0.85)))
    }

    private func checkinSummary(dashboard: RewardsDashboard) -> some View {
        let nextRewardDay = (dashboard.streak.currentStreak % 7) + 1
        let nextReward = dashboard.rewardsCalendar.first { $0.day == nextRewardDay }

        return VStack(spacing: 18) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(dashboard.checkedInToday ? "Checked in today" : "Today’s reward is waiting")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white)
                    Text(dashboard.checkedInToday ? "Great job! Your streak is active." : "Tap to claim today’s check-in reward.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.mlSubtext)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Streak")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.mlSubtext)
                    Text("\(dashboard.streak.currentStreak)d")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.mlGold)
                }
            }

            if let nextReward {
                HStack(spacing: 12) {
                    rewardBadge(for: nextReward)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Next reward")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.mlSubtext)
                        Text("Day \(nextReward.day): +\(nextReward.amount) \(nextReward.type == "free_pass" ? "pass" : "coins")")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.white)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)))
            }

            Button(action: { Task { await claimDailyCheckin() } }) {
                HStack {
                    if isCheckingIn {
                        ProgressView().tint(.white).scaleEffect(0.85)
                    } else {
                        Text(dashboard.checkedInToday ? "Already checked in" : "Check in now")
                            .font(.system(size: 14, weight: .bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(dashboard.checkedInToday ? Color.mlCard.opacity(0.4) : Color.mlPurple)
                .foregroundStyle(Color.white)
                .clipShape(Capsule())
            }
            .disabled(dashboard.checkedInToday || isCheckingIn)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 24).fill(Color.mlCard.opacity(0.92)))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func rewardCalendarSection(dashboard: RewardsDashboard) -> some View {
        VStack(spacing: 14) {
            sectionHeader("Weekly Check-in Rewards")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                let activeDay = dashboard.checkedInToday ? ((dashboard.streak.currentStreak % 7) + 1) : ((dashboard.streak.currentStreak % 7) + 1)
                ForEach(dashboard.rewardsCalendar) { reward in
                    VStack(spacing: 8) {
                        Text("Day \(reward.day)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.mlSubtext)
                        rewardBadge(for: reward, compact: true)
                        Text(reward.type == "free_pass" ? "+\(reward.amount) pass" : "+\(reward.amount) coins")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.white)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 16)
                        .fill(reward.day == activeDay ? Color.mlPurple.opacity(0.18) : Color.white.opacity(0.04)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(reward.day == activeDay ? Color.mlPurple : Color.white.opacity(0.06), lineWidth: reward.day == activeDay ? 1.5 : 1)
                    )
                }
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 24).fill(Color.mlCard.opacity(0.92)))
    }

    private func taskSection(dashboard: RewardsDashboard) -> some View {
        VStack(spacing: 14) {
            sectionHeader("Daily Tasks")

            if tasks.isEmpty {
                Text("No active tasks available right now. Come back after your next story session.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.mlSubtext)
                    .padding(.vertical, 20)
            } else {
                ForEach(tasks) { task in
                    VStack(spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            rewardBadge(for: task.rewardType, amount: task.rewardAmount)
                                .frame(width: 42, height: 42)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(task.title)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.white)
                                Text(task.description)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.mlSubtext)
                                    .lineLimit(2)
                            }
                            Spacer()
                        }

                        ProgressView(value: min(Double(task.progress) / Double(max(task.targetValue, 1)), 1.0))
                            .tint(task.isCompleted ? Color.mlGold : Color.mlPurple)
                        HStack {
                            Text("\(task.progress)/\(task.targetValue)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.mlSubtext)
                            Spacer()
                            if task.isClaimed {
                                Text("Claimed")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.mlGold)
                            } else if task.isCompleted {
                                Button(action: { Task { await claimTask(task) } }) {
                                    HStack {
                                        if claimingTaskId == task.taskID {
                                            ProgressView().tint(.white).scaleEffect(0.8)
                                        } else {
                                            Text("Claim")
                                                .font(.system(size: 12, weight: .bold))
                                        }
                                    }
                                    .frame(minWidth: 80)
                                    .padding(.vertical, 8)
                                    .background(Color.mlPurple)
                                    .foregroundStyle(Color.white)
                                    .clipShape(Capsule())
                                }
                                .disabled(claimingTaskId != nil)
                            } else {
                                Text("In progress")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.mlSubtext)
                            }
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.mlCard.opacity(0.88)))
                    .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
                }
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 24).fill(Color.mlCard.opacity(0.92)))
    }

    private var emptyStateSection: some View {
        VStack(spacing: 12) {
            Text("Unable to load rewards right now.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white)
            Button("Retry") {
                Task { await loadData() }
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Color.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 28)
            .background(Capsule().fill(Color.mlPurple))
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .background(RoundedRectangle(cornerRadius: 24).fill(Color.mlCard.opacity(0.92)))
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.white)
            Spacer()
        }
    }

    private func rewardBadge(for reward: RewardCalendarItem, compact: Bool = false) -> some View {
        let badgeColor = reward.type == "free_pass" ? Color.mlPink : Color.mlGold
        let label = reward.type == "free_pass" ? "PASS" : "COIN"

        return VStack(spacing: compact ? 4 : 8) {
            Text(label)
                .font(.system(size: compact ? 9 : 10, weight: .black))
                .foregroundStyle(badgeColor)
                .padding(.horizontal, compact ? 8 : 10)
                .padding(.vertical, compact ? 4 : 6)
                .background(Capsule().fill(badgeColor.opacity(0.12)))
            Text("+\(reward.amount)")
                .font(.system(size: compact ? 12 : 15, weight: .bold))
                .foregroundStyle(Color.white)
        }
        .frame(maxWidth: .infinity)
    }

    private func rewardBadge(for rewardType: String, amount: Int) -> some View {
        let badgeColor = rewardType == "free_pass" ? Color.mlPink : Color.mlGold
        return ZStack {
            Circle()
                .fill(badgeColor.opacity(0.15))
            VStack(spacing: 2) {
                Image(systemName: rewardType == "free_pass" ? "ticket.fill" : "bitcoinsign.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(badgeColor)
                Text("+\(amount)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white)
            }
        }
    }

    private func loadData() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            async let dashboardTask = NetworkService.shared.fetchRewardsDashboard()
            async let dailyTasksTask = NetworkService.shared.fetchDailyTasks()

            let (dashboard, tasks) = try await (dashboardTask, dailyTasksTask)

            await MainActor.run {
                self.dashboard = dashboard
                self.tasks = tasks
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func claimDailyCheckin() async {
        guard !isCheckingIn else { return }
        isCheckingIn = true
        errorMessage = nil

        do {
            let response = try await NetworkService.shared.claimDailyCheckin()
            NotificationCenter.default.post(name: NSNotification.Name("WalletBalanceChanged"), object: nil)
            await loadData()
            if response.rewardType == "free_pass" {
                await MainActor.run {
                    errorMessage = "You claimed +\(response.rewardAmount) free pass!"
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }

        await MainActor.run {
            self.isCheckingIn = false
        }
    }

    private func claimTask(_ task: DailyTaskProgress) async {
        guard claimingTaskId == nil else { return }
        claimingTaskId = task.taskID
        errorMessage = nil

        do {
            let _ = try await NetworkService.shared.claimTaskReward(taskId: task.taskID)
            NotificationCenter.default.post(name: NSNotification.Name("WalletBalanceChanged"), object: nil)
            await loadData()
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }

        await MainActor.run {
            claimingTaskId = nil
        }
    }
}

#Preview {
    NavigationStack {
        DailyRewardsView()
    }
}
