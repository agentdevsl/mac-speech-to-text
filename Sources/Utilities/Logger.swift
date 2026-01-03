import Foundation
import OSLog

/// Centralized logging utility using os.Logger for production-ready logging
enum AppLogger {
    /// Subsystem identifier for all loggers
    private static let subsystem = Bundle.main.bundleIdentifier ?? Constants.App.bundleIdentifier

    /// Logger for app lifecycle and delegate events
    static let app = Logger(subsystem: subsystem, category: "app")

    /// Logger for service layer operations
    static let service = Logger(subsystem: subsystem, category: "service")

    /// Logger for view model operations
    static let viewModel = Logger(subsystem: subsystem, category: "viewModel")

    /// Logger for audio processing and capture
    static let audio = Logger(subsystem: subsystem, category: "audio")

    /// Logger for permissions and system integration
    static let system = Logger(subsystem: subsystem, category: "system")

    /// Logger for statistics and analytics
    static let analytics = Logger(subsystem: subsystem, category: "analytics")
}
