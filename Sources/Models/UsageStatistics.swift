import Foundation

/// Aggregated usage metrics without storing sensitive content
struct UsageStatistics: Codable, Identifiable {
    let id: UUID
    let date: Date
    var totalSessions: Int
    var successfulSessions: Int
    var failedSessions: Int
    var totalWordsTranscribed: Int
    var totalDurationSeconds: TimeInterval
    var averageConfidence: Double
    var languageBreakdown: [LanguageStats]
    var errorBreakdown: [ErrorStats]

    init(id: UUID = UUID(),
         date: Date = Date(),
         totalSessions: Int = 0,
         successfulSessions: Int = 0,
         failedSessions: Int = 0,
         totalWordsTranscribed: Int = 0,
         totalDurationSeconds: TimeInterval = 0,
         averageConfidence: Double = 0.0,
         languageBreakdown: [LanguageStats] = [],
         errorBreakdown: [ErrorStats] = []) {
        self.id = id
        self.date = date
        self.totalSessions = totalSessions
        self.successfulSessions = successfulSessions
        self.failedSessions = failedSessions
        self.totalWordsTranscribed = totalWordsTranscribed
        self.totalDurationSeconds = totalDurationSeconds
        self.averageConfidence = averageConfidence
        self.languageBreakdown = languageBreakdown
        self.errorBreakdown = errorBreakdown
    }

    var successRate: Double {
        guard totalSessions > 0 else { return 0.0 }
        return Double(successfulSessions) / Double(totalSessions)
    }

    var averageWordsPerSession: Double {
        guard totalSessions > 0 else { return 0.0 }
        return Double(totalWordsTranscribed) / Double(totalSessions)
    }
}

struct LanguageStats: Codable, Identifiable {
    let id: UUID
    let languageCode: String
    var sessionCount: Int
    var wordCount: Int

    init(id: UUID = UUID(), languageCode: String, sessionCount: Int = 0, wordCount: Int = 0) {
        self.id = id
        self.languageCode = languageCode
        self.sessionCount = sessionCount
        self.wordCount = wordCount
    }
}

struct ErrorStats: Codable, Identifiable {
    let id: UUID
    let errorType: String
    var count: Int

    init(id: UUID = UUID(), errorType: String, count: Int = 0) {
        self.id = id
        self.errorType = errorType
        self.count = count
    }
}

/// Aggregated statistics across different time periods
struct AggregatedStats {
    let today: UsageStatistics
    let thisWeek: UsageStatistics
    let thisMonth: UsageStatistics
    let allTime: UsageStatistics

    init(today: UsageStatistics = UsageStatistics(),
         thisWeek: UsageStatistics = UsageStatistics(),
         thisMonth: UsageStatistics = UsageStatistics(),
         allTime: UsageStatistics = UsageStatistics()) {
        self.today = today
        self.thisWeek = thisWeek
        self.thisMonth = thisMonth
        self.allTime = allTime
    }

    static let empty = AggregatedStats()
}
