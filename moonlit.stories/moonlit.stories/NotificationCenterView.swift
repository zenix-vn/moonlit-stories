import SwiftUI

struct NotificationCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notifications: [PushNotificationItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    
    var body: some View {
        ZStack {
            // Background theme
            Color.mlBg.ignoresSafeArea()
            
            // Background gradient glow
            VStack {
                HStack {
                    Circle()
                        .fill(Color.mlPurple.opacity(0.12))
                        .frame(width: 250, height: 250)
                        .blur(radius: 70)
                        .offset(x: -60, y: -40)
                    Spacer()
                }
                Spacer()
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Bar
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .bold))
                            Text("Back")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundStyle(Color.mlPurple)
                    }
                    
                    Spacer()
                    
                    Text("Inbox")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.white)
                        .padding(.trailing, 40) // Balance back button spacer
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    Rectangle()
                        .fill(Color.mlBg.opacity(0.7))
                        .background(.ultraThinMaterial)
                        .ignoresSafeArea(edges: .top)
                )
                
                // Content
                if isLoading {
                    VStack {
                        ProgressView()
                            .tint(Color.mlPurple)
                            .scaleEffect(1.2)
                        Text("Loading notifications...")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.mlSubtext)
                            .padding(.top, 8)
                    }
                    .frame(maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "bell.slash.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.mlPink.opacity(0.8))
                        Text("Failed to load notifications")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.white)
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.mlSubtext)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxHeight: .infinity)
                } else if notifications.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 42))
                            .foregroundStyle(Color.white.opacity(0.12))
                        Text("No notifications yet")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.7))
                        Text("When you receive gifts, updates, and news, they will appear here.")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.mlSubtext)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 48)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(notifications) { item in
                                NotificationRow(item: item) {
                                    markAsRead(item: item)
                                }
                            }
                        }
                        .padding(20)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await loadNotifications()
        }
    }
    
    private func loadNotifications() async {
        do {
            let data = try await NetworkService.shared.fetchNotifications()
            await MainActor.run {
                self.notifications = data
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func markAsRead(item: PushNotificationItem) {
        guard item.status != "opened" else { return }
        
        // Optimistic UI update
        if let idx = notifications.firstIndex(where: { $0.id == item.id }) {
            notifications[idx] = PushNotificationItem(
                id: item.id,
                title: item.title,
                body: item.body,
                deepLink: item.deepLink,
                status: "opened",
                sentAt: item.sentAt,
                openedAt: ""
            )
        }
        
        Task {
            do {
                try await NetworkService.shared.openNotification(id: item.id)
            } catch {
                print("Failed to mark read: \(error)")
            }
        }
    }
}

struct NotificationRow: View {
    let item: PushNotificationItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 14) {
                // Bell Status Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(item.status != "opened" ? Color.mlPurple.opacity(0.16) : Color.white.opacity(0.04))
                        .frame(width: 40, height: 40)
                    Image(systemName: item.status != "opened" ? "bell.badge.fill" : "bell.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(item.status != "opened" ? Color.mlPurple : Color.mlSubtext)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(item.status != "opened" ? Color.white : Color.white.opacity(0.7))
                        .lineLimit(1)
                    
                    Text(item.body)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.mlSubtext)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    
                    Text(formatDate(item.sentAt))
                        .font(.system(size: 10))
                        .foregroundStyle(Color.mlSubtext.opacity(0.5))
                        .padding(.top, 2)
                }
                
                Spacer()
                
                // Pulsing dot for unread status
                if item.status != "opened" {
                    Circle()
                        .fill(Color.mlPurple)
                        .frame(width: 8, height: 8)
                        .padding(.top, 6)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.mlCard))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(item.status != "opened" ? Color.mlPurple.opacity(0.18) : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func formatDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else { return isoString }
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateStyle = .medium
        outputFormatter.timeStyle = .short
        return outputFormatter.string(from: date)
    }
}

#Preview {
    NotificationCenterView()
}
