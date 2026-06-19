import Foundation

#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

// MARK: - CrashReporter
// Thin abstraction over Firebase Crashlytics. Compiles and no-ops until the
// Firebase SPM package is added, so the rest of the app can call it freely.

enum CrashReporter {

    /// Attach a non-fatal error to the next crash report / log stream.
    static func record(_ error: Error) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().record(error: error)
        #endif
        #if DEBUG
        print("[CrashReporter] \(error.localizedDescription)")
        #endif
    }

    /// Breadcrumb log included with subsequent crash reports.
    static func log(_ message: String) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().log(message)
        #endif
    }

    /// Associate reports with the current user for easier triage.
    static func setUserID(_ id: String) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setUserID(id)
        #endif
    }

    /// Custom key/value attached to crash reports.
    static func setValue(_ value: Any, forKey key: String) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
        #endif
    }
}
