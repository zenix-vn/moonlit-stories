import SwiftUI
import UIKit

struct HelpFeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var feedbackText = ""
    @State private var isSending = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    private let supportEmail = "support@moonlit.vn"
    private let faqItems = [
        (title: "How do I restore purchases?", description: "Open App Store purchases and use the same Apple ID to restore your MoonPass or coin packs."),
        (title: "Why can’t I unlock an episode?", description: "Locked chapters require coins, free passes, or an active MoonPass subscription. Check your wallet balance first."),
        (title: "How do I cancel subscription?", description: "Subscriptions are managed through Apple App Store. Cancel anytime from your Apple account settings."),
        (title: "How do I report a bug?", description: "Use the feedback form below or send an email to support@moonlit.vn with a description of the issue.")
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                Text("Need help with Moonlit Stories? Browse common questions or send a message directly to our support team.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.mlSubtext)
                    .frame(maxWidth: .infinity, alignment: .leading)

                helpStatsCard
                faqSection
                contactSection
                feedbackForm
                sendButton
                Text("Our support team replies within 24 hours. For urgent account issues, include your registered email.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.mlSubtext.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            .padding(20)
        }
        .background(Color.mlBg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .navigationTitle("Help & Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Help & Feedback", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private var helpStatsCard: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Support Hours")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.mlSubtext)
                Text("24/7 Help Center")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.white)
                Text("Response time usually within 24 hours.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.mlSubtext.opacity(0.8))
            }
            Spacer()
            Image(systemName: "ladybug.fill")
                .font(.system(size: 28))
                .foregroundStyle(LinearGradient(colors: [Color.mlPink, Color.mlPurple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 60, height: 60)
                .background(Circle().fill(Color.white.opacity(0.05)))
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.mlCard))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var faqSection: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Frequently Asked Questions")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.white)
                Spacer()
            }

            ForEach(0..<faqItems.count, id: \.self) { index in
                let item = faqItems[index]
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white)
                    Text(item.description)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.mlSubtext)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.mlCard.opacity(0.88)))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.05), lineWidth: 1))
            }
        }
    }

    private var contactSection: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Contact Support")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.white)
                Spacer()
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Email")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.mlSubtext)
                    Text(supportEmail)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white)
                }
                Spacer()
                Button(action: copySupportEmail) {
                    Text("Copy")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.mlPurple)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.mlPurple.opacity(0.12)))
                }
            }

            Button(action: openSupportMail) {
                Text("Send an email")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.mlPurple))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.mlCard))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var feedbackForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Send Feedback")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.white)

            Text("Your feedback helps us improve the app. Describe the issue or feature request below.")
                .font(.system(size: 12))
                .foregroundStyle(Color.mlSubtext)

            TextEditor(text: $feedbackText)
                .frame(minHeight: 140)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.04)))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                .foregroundStyle(Color.white)
                .font(.system(size: 14))
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.mlCard))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var sendButton: some View {
        Button(action: sendFeedbackEmail) {
            HStack {
                if isSending {
                    ProgressView().tint(.white).scaleEffect(0.8)
                } else {
                    Text("Send Feedback")
                        .font(.system(size: 14, weight: .bold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.mlPink))
            .foregroundStyle(Color.white)
        }
        .disabled(isSending)
    }

    private func openSupportMail() {
        sendFeedbackEmail()
    }

    private func copySupportEmail() {
        UIPasteboard.general.string = supportEmail
        alertMessage = "Support email copied to clipboard."
        showAlert = true
    }

    private func sendFeedbackEmail() {
        guard let encodedBody = feedbackText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            alertMessage = "Unable to prepare email content."
            showAlert = true
            return
        }

        isSending = true
        let subject = "Moonlit Stories Feedback"
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let model = UIDevice.current.model
        let bodyText = feedbackText.isEmpty ? "" : "\n\(feedbackText)"
        let bodyPrefix = "App Version: \(version)%0D%0ADevice: \(model)%0D%0A\(bodyText)"
        let escapedBody = bodyPrefix.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "mailto:\(supportEmail)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Feedback")&body=\(escapedBody)"

        guard let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) else {
            isSending = false
            alertMessage = "Unable to open Mail. Please make sure you have an email account configured."
            showAlert = true
            return
        }

        UIApplication.shared.open(url) { success in
            Task { @MainActor in
                isSending = false
                if success {
                    alertMessage = "Email composer opened. Thank you for your feedback."
                } else {
                    alertMessage = "Could not open Mail. Try copying the support email instead."
                }
                showAlert = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        HelpFeedbackView()
    }
}
