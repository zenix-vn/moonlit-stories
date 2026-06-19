import SwiftUI
import UserNotifications
import AppTrackingTransparency

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Reader Settings (AppStorage for persistence)
    @AppStorage("readerFontSize") private var readerFontSize = 16.0
    @AppStorage("readerFontName") private var readerFontName = "System"
    @AppStorage("readerTheme") private var readerTheme = "Dark"
    @AppStorage("autoUnlockEpisodes") private var autoUnlockEpisodes = false
    
    // Audio Settings
    @AppStorage("audioPlaybackSpeed") private var audioPlaybackSpeed = 1.0
    
    // Notifications & Device Settings
    @AppStorage("pushNotificationsEnabled") private var pushNotificationsEnabled = true
    @AppStorage("dailyReadingReminder") private var dailyReadingReminder = true
    
    // User profile state (binds locally, simulates save)
    @State private var displayName = ""
    @State private var email = ""
    @State private var bio = ""
    
    // Feedback alerts
    @State private var isShowingClearCacheAlert = false
    @State private var isShowingSuccessAlert = false
    @State private var successMessage = ""
    @State private var isShowingErrorAlert = false
    @State private var errorMessage = ""
    @State private var isShowingLogoutConfirmation = false
    @State private var isShowingDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
    
    // Tracking settings state
    @State private var trackingStatus: ATTrackingManager.AuthorizationStatus = .notDetermined

    let fontOptions = ["System", "Georgia", "Baskerville", "Avenir"]
    let themeOptions = ["Dark", "Charcoal", "Sepia"]

    /// App version/build read from the bundle so it never drifts from the real build.
    private var appVersionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Moonlit Stories v\(version) (Build \(build))"
    }
    
    var body: some View {
        ZStack {
            // Background matching Moonlit theme
            Color.mlBg.ignoresSafeArea()
            
            // Decorative background blurs
            VStack {
                HStack {
                    Circle()
                        .fill(Color.mlPink.opacity(0.08))
                        .frame(width: 250, height: 250)
                        .blur(radius: 60)
                        .offset(x: -80, y: -40)
                    Spacer()
                }
                Spacer()
                HStack {
                    Spacer()
                    Circle()
                        .fill(Color.mlPurple.opacity(0.08))
                        .frame(width: 300, height: 300)
                        .blur(radius: 80)
                        .offset(x: 100, y: 100)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            
            ScrollView {
                VStack(spacing: 24) {
                        
                        // SECTION 1: ACCOUNT SETTINGS
                        SettingsSectionHeader(title: "Account Settings", icon: "person.circle.fill")
                        
                        VStack(spacing: 16) {
                            CustomTextField(label: "Display Name", placeholder: "Guest User", text: $displayName)
                            CustomTextField(label: "Email Address", placeholder: "guest@moonlit.vn", text: $email, keyboardType: .emailAddress)
                            CustomTextField(label: "Bio", placeholder: "Tell stories about yourself...", text: $bio)
                            
                            Button(action: {
                                Task {
                                    do {
                                        let prefs = ReaderPreferences(
                                            fontSize: readerFontSize,
                                            fontName: readerFontName,
                                            theme: readerTheme,
                                            autoUnlockEpisodes: autoUnlockEpisodes,
                                            audioPlaybackSpeed: audioPlaybackSpeed,
                                            pushNotificationsEnabled: pushNotificationsEnabled,
                                            dailyReadingReminder: dailyReadingReminder
                                        )
                                        _ = try await NetworkService.shared.updateMe(
                                            displayName: displayName.isEmpty ? nil : displayName,
                                            email: email.isEmpty ? nil : email,
                                            bio: bio.isEmpty ? nil : bio,
                                            preferences: prefs
                                        )
                                        await MainActor.run {
                                            successMessage = "Settings saved to cloud!"
                                            isShowingSuccessAlert = true
                                        }
                                    } catch {
                                        await MainActor.run {
                                            successMessage = "Failed to save: \(error.localizedDescription)"
                                            isShowingSuccessAlert = true
                                        }
                                    }
                                }
                            }) {
                                Text("Save Changes")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.mlPurple, Color.mlPurpleDim],
                                            startPoint: .leading, endPoint: .trailing
                                        )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .padding(.top, 4)
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.mlCard))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
                        
                        // SECTION 2: READER CUSTOMIZATION
                        SettingsSectionHeader(title: "Reader Customization", icon: "book.fill")
                        
                        VStack(spacing: 18) {
                            // Font Selection
                            HStack {
                                Text("Font Family")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.white)
                                Spacer()
                                Picker("Font Family", selection: $readerFontName) {
                                    ForEach(fontOptions, id: \.self) { font in
                                        Text(font).tag(font)
                                    }
                                }
                                .pickerStyle(.menu)
                                .accentColor(Color.mlPurple)
                            }
                            
                            Divider().background(Color.white.opacity(0.08))
                            
                            // Font Size
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Font Size")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color.white)
                                    Spacer()
                                    Text("\(Int(readerFontSize)) pt")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.mlSubtext)
                                }
                                Slider(value: $readerFontSize, in: 12...32, step: 1)
                                    .tint(Color.mlPurple)
                            }
                            
                            Divider().background(Color.white.opacity(0.08))
                            
                            // Reader Theme
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Reading Theme")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.white)
                                
                                HStack(spacing: 12) {
                                    ForEach(themeOptions, id: \.self) { theme in
                                        let isSelected = readerTheme == theme
                                        Button(action: {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                readerTheme = theme
                                            }
                                        }) {
                                            Text(theme)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(isSelected ? Color.white : Color.mlSubtext)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 10)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .fill(isSelected ? Color.mlPurple : Color.white.opacity(0.04))
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .strokeBorder(isSelected ? Color.clear : Color.white.opacity(0.08), lineWidth: 1)
                                                )
                                        }
                                    }
                                }
                            }
                            
                            Divider().background(Color.white.opacity(0.08))
                            
                            // Auto Unlock
                            Toggle(isOn: $autoUnlockEpisodes) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Auto-Unlock Episodes")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color.white)
                                    Text("Spend coins automatically when entering locked chapters")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.mlSubtext)
                                }
                            }
                            .tint(Color.mlPurple)
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.mlCard))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
                        
                        // SECTION 3: AUDIO & SPEECH
                        SettingsSectionHeader(title: "Audio & Speech Settings", icon: "play.headphones.badge.fill")
                        
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Playback Speed")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color.white)
                                    Spacer()
                                    Text(String(format: "%.2fx", audioPlaybackSpeed))
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.mlSubtext)
                                }
                                Slider(value: $audioPlaybackSpeed, in: 0.5...2.0, step: 0.1)
                                    .tint(Color.mlPurple)
                            }
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.mlCard))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
                        
                        // SECTION 4: APP SETTINGS & PUSH
                        SettingsSectionHeader(title: "App Settings", icon: "bell.badge.fill")
                        
                        VStack(spacing: 16) {
                            Toggle(isOn: $pushNotificationsEnabled) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Push Notifications")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color.white)
                                    Text("Receive updates about new releases & daily rewards")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.mlSubtext)
                                }
                            }
                            .tint(Color.mlPurple)
                            
                            Divider().background(Color.white.opacity(0.08))
                            
                            Toggle(isOn: $dailyReadingReminder) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Daily Reading Reminder")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color.white)
                                    Text("Notify me to keep my reading streak alive")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.mlSubtext)
                                }
                            }
                            .tint(Color.mlPurple)
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.mlCard))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
                        
                        // SECTION 4.5: TRACKING & ADS
                        SettingsSectionHeader(title: "Tracking & Ads", icon: "hand.raised.fill")
                        
                        VStack(spacing: 16) {
                            Button(action: {
                                if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                HStack(spacing: 12) {
                                    let isAuthorized = trackingStatus == .authorized
                                    Image(systemName: isAuthorized ? "checkmark.shield.fill" : "shield.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(isAuthorized ? Color.green : Color.mlSubtext)
                                        .frame(width: 32, height: 32)
                                        .background(Circle().fill((isAuthorized ? Color.green : Color.white).opacity(0.1)))
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("App Tracking")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color.white)
                                        Text(isAuthorized ? "Personalized ads enabled" : "Personalized ads disabled")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.mlSubtext)
                                            .multilineTextAlignment(.leading)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(statusBadgeText(for: trackingStatus))
                                        .font(.system(size: 12, weight: .bold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(statusBadgeBgColor(for: trackingStatus)))
                                        .foregroundStyle(statusBadgeTextColor(for: trackingStatus))
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.mlSubtext.opacity(0.5))
                                }
                            }
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.mlCard))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
                        
                        // SECTION 4.6: PRIVACY & LEGAL
                        SettingsSectionHeader(title: "Privacy & Legal", icon: "shield.fill")
                        
                        VStack(spacing: 16) {
                            // Privacy Policy Row
                            Button(action: {
                                UIApplication.shared.open(LegalLinks.privacyPolicy)
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "shield.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(Color.green)
                                        .frame(width: 32, height: 32)
                                        .background(Circle().fill(Color.green.opacity(0.1)))
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Privacy Policy")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color.white)
                                        Text("How we protect your data")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.mlSubtext)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.mlSubtext.opacity(0.5))
                                }
                            }
                            
                            Divider().background(Color.white.opacity(0.08))
                            
                            // Terms of Use Row
                            Button(action: {
                                UIApplication.shared.open(LegalLinks.termsOfUse)
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "doc.text.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(Color.blue)
                                        .frame(width: 32, height: 32)
                                        .background(Circle().fill(Color.blue.opacity(0.1)))
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Terms of Use")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color.white)
                                        Text("Read our terms")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.mlSubtext)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.mlSubtext.opacity(0.5))
                                }
                            }
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.mlCard))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
                        
                        // SECTION 5: APP UTILITIES
                        SettingsSectionHeader(title: "Maintenance", icon: "command")
                        
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Cache Storage")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color.white)
                                    Text("Clear downloaded cover covers, background music, and logs")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.mlSubtext)
                                }
                                Spacer()
                                Button(action: {
                                    isShowingClearCacheAlert = true
                                }) {
                                    Text("Clear Cache")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color.mlPink)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Capsule().fill(Color.mlPink.opacity(0.12)))
                                }
                            }
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.mlCard))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
                        
                        // SECTION 6: LOGOUT / ACCOUNT DELETION
                        VStack(spacing: 12) {
                            Button(action: {
                                isShowingLogoutConfirmation = true
                            }) {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                    Text("Log Out")
                                }
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
                                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
                            }

                            Button(action: {
                                isShowingDeleteAccountConfirmation = true
                            }) {
                                HStack {
                                    if isDeletingAccount {
                                        ProgressView().tint(Color.mlPink)
                                    } else {
                                        Image(systemName: "trash")
                                    }
                                    Text("Delete Account")
                                }
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.mlPink)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color.mlPink.opacity(0.08)))
                                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.mlPink.opacity(0.25), lineWidth: 1))
                            }
                            .disabled(isDeletingAccount)

                            Text(appVersionText)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.mlSubtext.opacity(0.6))
                                .padding(.top, 8)
                        }
                        
                        Color.clear.frame(height: 40)
                    }
                    .padding(20)
                }
        }
        .preferredColorScheme(.dark)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Clear Cache?", isPresented: $isShowingClearCacheAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                // Drop in-memory API responses and the URL cache (covers, audio, logs).
                APICache.shared.invalidateAll()
                URLCache.shared.removeAllCachedResponses()
                withAnimation {
                    successMessage = "Cached images and audios cleared successfully!"
                    isShowingSuccessAlert = true
                }
            }
        } message: {
            Text("This will delete downloaded covers and local reader assets. Your reading history, coins, and library data will NOT be deleted.")
        }
        .alert("Success", isPresented: $isShowingSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(successMessage)
        }
        .alert("Error", isPresented: $isShowingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onChange(of: pushNotificationsEnabled) { _, isEnabled in
            guard isEnabled else { return }
            // Turning the toggle on must reflect the real OS permission state.
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                DispatchQueue.main.async {
                    switch settings.authorizationStatus {
                    case .denied:
                        // Already denied at the OS level — only Settings can re-enable it.
                        PushNotifications.openSystemSettings()
                    default:
                        PushNotifications.requestAuthorizationAndRegister()
                    }
                }
            }
        }
        .alert("Log Out", isPresented: $isShowingLogoutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Log Out", role: .destructive) {
                // Perform logout
                NetworkService.shared.logout()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to log out of Moonlit Stories?")
        }
        .alert("Delete Account", isPresented: $isShowingDeleteAccountConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await MainActor.run { isDeletingAccount = true }
                    do {
                        try await NetworkService.shared.deleteAccount()
                        await MainActor.run {
                            isDeletingAccount = false
                            dismiss()
                        }
                    } catch {
                        await MainActor.run {
                            isDeletingAccount = false
                            errorMessage = "Failed to delete account: \(error.localizedDescription)"
                            isShowingErrorAlert = true
                        }
                    }
                }
            }
        } message: {
            Text("This permanently deletes your account, coins, library, and reading history. This action cannot be undone.")
        }
        .onAppear {
            updateTrackingStatus()
            // Pre-fill local fields with profile info
            Task {
                do {
                    let me = try await NetworkService.shared.fetchMe()
                    await MainActor.run {
                        if let name = me.profile?.displayName {
                            self.displayName = name
                        }
                        if let email = me.user.email {
                            self.email = email
                        }
                        if let bio = me.profile?.bio {
                            self.bio = bio
                        }
                        // Sync preferences from cloud database
                        if let prefs = me.profile?.readingPreference {
                            if let fSize = prefs.fontSize {
                                self.readerFontSize = fSize
                            }
                            if let fName = prefs.fontName {
                                self.readerFontName = fName
                            }
                            if let theme = prefs.theme {
                                self.readerTheme = theme
                            }
                            if let auto = prefs.autoUnlockEpisodes {
                                self.autoUnlockEpisodes = auto
                            }
                            if let speed = prefs.audioPlaybackSpeed {
                                self.audioPlaybackSpeed = speed
                            }
                            if let push = prefs.pushNotificationsEnabled {
                                self.pushNotificationsEnabled = push
                            }
                            if let daily = prefs.dailyReadingReminder {
                                self.dailyReadingReminder = daily
                            }
                        }
                    }
                } catch {
                    #if DEBUG
                    print("Error fetching profile: \(error)")
                    #endif
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            updateTrackingStatus()
        }
    }
    
    private func updateTrackingStatus() {
        trackingStatus = ATTrackingManager.trackingAuthorizationStatus
    }
    
    private func statusBadgeText(for status: ATTrackingManager.AuthorizationStatus) -> String {
        switch status {
        case .authorized: return "Allowed"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not Asked"
        @unknown default: return "Unknown"
        }
    }
    
    private func statusBadgeBgColor(for status: ATTrackingManager.AuthorizationStatus) -> Color {
        switch status {
        case .authorized: return Color.green.opacity(0.15)
        case .denied: return Color.red.opacity(0.15)
        default: return Color.white.opacity(0.08)
        }
    }
    
    private func statusBadgeTextColor(for status: ATTrackingManager.AuthorizationStatus) -> Color {
        switch status {
        case .authorized: return Color.green
        case .denied: return Color.red
        default: return Color.mlSubtext
        }
    }
}

// MARK: - Helper Views

struct SettingsSectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.mlPurple)
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.mlSubtext)
            Spacer()
        }
        .padding(.leading, 4)
        .padding(.bottom, -12) // Pull section closer to headers
    }
}

struct CustomTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.mlSubtext)
            
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .font(.system(size: 14))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        }
    }
}

#Preview {
    SettingsView()
}
