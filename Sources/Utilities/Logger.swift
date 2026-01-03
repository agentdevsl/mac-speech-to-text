import Foundation
import OSLog

/// Log level for controlling verbosity
enum LogLevel: Int, Comparable {
    case error = 0
    case warning = 1
    case info = 2
    case debug = 3
    case trace = 4

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Centralized logging utility using os.Logger for production-ready logging
enum AppLogger {
    /// Subsystem identifier for all loggers
    private static let subsystem = Bundle.main.bundleIdentifier ?? Constants.App.bundleIdentifier

    /// Current log level - set to .trace for maximum debug output
    static var currentLevel: LogLevel = .trace

    /// Enable expensive debug checks (object addresses, etc.)
    static var enableExpensiveLogging = true

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

    // MARK: - Level-Controlled Logging

    static func trace(
        _ logger: Logger,
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard currentLevel >= .trace else { return }
        let fileName = (file as NSString).lastPathComponent
        logger.debug(
            "TRACE [\(fileName, privacy: .public):\(line, privacy: .public)] \(function, privacy: .public) - \(message(), privacy: .public)"
        )
    }

    static func debug(
        _ logger: Logger,
        _ message: @autoclosure () -> String,
        file: String = #file,
        line: Int = #line
    ) {
        guard currentLevel >= .debug else { return }
        let fileName = (file as NSString).lastPathComponent
        logger.debug("DEBUG [\(fileName, privacy: .public):\(line, privacy: .public)] \(message(), privacy: .public)")
    }

    static func info(
        _ logger: Logger,
        _ message: @autoclosure () -> String,
        file: String = #file,
        line: Int = #line
    ) {
        guard currentLevel >= .info else { return }
        let fileName = (file as NSString).lastPathComponent
        logger.info("INFO [\(fileName, privacy: .public):\(line, privacy: .public)] \(message(), privacy: .public)")
    }

    static func warning(
        _ logger: Logger,
        _ message: @autoclosure () -> String,
        file: String = #file,
        line: Int = #line
    ) {
        guard currentLevel >= .warning else { return }
        let fileName = (file as NSString).lastPathComponent
        logger.warning("WARN [\(fileName, privacy: .public):\(line, privacy: .public)] \(message(), privacy: .public)")
    }

    static func error(
        _ logger: Logger,
        _ message: @autoclosure () -> String,
        file: String = #file,
        line: Int = #line
    ) {
        let fileName = (file as NSString).lastPathComponent
        logger.error("ERROR [\(fileName, privacy: .public):\(line, privacy: .public)] \(message(), privacy: .public)")
    }

    static func lifecycle(
        _ logger: Logger,
        _ object: AnyObject,
        event: String,
        file: String = #file,
        line: Int = #line
    ) {
        guard currentLevel >= .debug, enableExpensiveLogging else { return }
        let fileName = (file as NSString).lastPathComponent
        let typeName = String(describing: type(of: object))
        let address = Unmanaged.passUnretained(object).toOpaque()
        logger.debug(
            "LIFECYCLE [\(fileName, privacy: .public):\(line, privacy: .public)] \(typeName, privacy: .public)@\(String(describing: address), privacy: .public) - \(event, privacy: .public)"
        )
    }

    static func stateChange<T>(
        _ logger: Logger,
        from: T,
        to: T,
        context: String = "",
        file: String = #file,
        line: Int = #line
    ) {
        guard currentLevel >= .debug else { return }
        let fileName = (file as NSString).lastPathComponent
        let ctx = context.isEmpty ? "" : " (\(context))"
        logger.debug(
            "STATE [\(fileName, privacy: .public):\(line, privacy: .public)] \(String(describing: from), privacy: .public) -> \(String(describing: to), privacy: .public)\(ctx, privacy: .public)"
        )
    }
}
