import Foundation
import OSLog

/// Centralized logging utility using os.Logger for production-ready logging
enum AppLogger {
    /// Logger for app lifecycle and delegate events
    static let app = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.speechtotext", category: "app")

    /// Logger for service layer operations
    static let service = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.speechtotext", category: "service")

    /// Logger for view model operations
    static let viewModel = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.speechtotext", category: "viewModel")

    /// Logger for audio processing and capture
    static let audio = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.speechtotext", category: "audio")

    /// Logger for permissions and system integration
    static let system = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.speechtotext", category: "system")

    /// Logger for statistics and analytics
    static let analytics = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.speechtotext", category: "analytics")
}
