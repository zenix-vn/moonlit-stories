import Foundation
import AppTrackingTransparency
import AdSupport
import UIKit

@MainActor
final class ATTManager {
    static let shared = ATTManager()
    
    private init() {}
    
    /// Requests tracking authorization, waiting for the application state to be active.
    /// This is crucial for iOS 15+ where requesting tracking permission when the app is in the background fails silently.
    func requestTrackingPermission() async -> ATTrackingManager.AuthorizationStatus {
        let currentStatus = ATTrackingManager.trackingAuthorizationStatus
        guard currentStatus == .notDetermined else {
            return currentStatus
        }
        
        // If the app is not active yet, wait until didBecomeActiveNotification is received
        if UIApplication.shared.applicationState != .active {
            await waitForAppToBecomeActive()
        }
        
        // Re-check status in case it was determined while waiting
        let statusAfterActive = ATTrackingManager.trackingAuthorizationStatus
        guard statusAfterActive == .notDetermined else {
            return statusAfterActive
        }
        
        return await withCheckedContinuation { continuation in
            ATTrackingManager.requestTrackingAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
    
    private func waitForAppToBecomeActive() async {
        _ = await NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification).first { _ in true }
    }
}
