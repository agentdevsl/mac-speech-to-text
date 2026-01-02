import Foundation

/// Service for managing usage statistics with privacy preservation
class StatisticsService {
    private let userDefaults: UserDefaults
    private let statsKey = "com.speechtotext.statistics"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    /// Record a completed session
    func recordSession(_ session: RecordingSession) throws {
        var todayStats = getTodayStats()

        todayStats.totalSessions += 1

        if session.insertionSuccess {
            todayStats.successfulSessions += 1
            todayStats.totalWordsTranscribed += session.wordCount
        } else {
            todayStats.failedSessions += 1
        }

        todayStats.totalDurationSeconds += session.duration

        // Update average confidence (weighted average)
        if todayStats.totalSessions > 1 {
            let oldWeight = Double(todayStats.totalSessions - 1)
            let newWeight = 1.0
            todayStats.averageConfidence =
                (todayStats.averageConfidence * oldWeight + session.confidenceScore * newWeight) /
                Double(todayStats.totalSessions)
        } else {
            todayStats.averageConfidence = session.confidenceScore
        }

        // Update language breakdown
        if let index = todayStats.languageBreakdown.firstIndex(where: { $0.languageCode == session.language }) {
            todayStats.languageBreakdown[index].sessionCount += 1
            todayStats.languageBreakdown[index].wordCount += session.wordCount
        } else {
            todayStats.languageBreakdown.append(
                LanguageStats(languageCode: session.language, sessionCount: 1, wordCount: session.wordCount)
            )
        }

        // Update error breakdown if failed
        if !session.insertionSuccess, let errorMessage = session.errorMessage {
            let errorType = extractErrorType(from: errorMessage)
            if let index = todayStats.errorBreakdown.firstIndex(where: { $0.errorType == errorType }) {
                todayStats.errorBreakdown[index].count += 1
            } else {
                todayStats.errorBreakdown.append(ErrorStats(errorType: errorType, count: 1))
            }
        }

        try saveStats(todayStats)
    }

    /// Get today's statistics
    func getTodayStats() -> UsageStatistics {
        let today = Calendar.current.startOfDay(for: Date())
        return getStatsForDate(today)
    }

    /// Get statistics for a specific date
    func getStatsForDate(_ date: Date) -> UsageStatistics {
        let allStats = loadAllStats()
        let startOfDay = Calendar.current.startOfDay(for: date)

        if let stats = allStats.first(where: { Calendar.current.isDate($0.date, inSameDayAs: startOfDay) }) {
            return stats
        }

        return UsageStatistics(date: startOfDay)
    }

    /// Get aggregated statistics across different periods
    func getAggregatedStats() -> AggregatedStats {
        let allStats = loadAllStats()
        let calendar = Calendar.current
        let now = Date()

        let today = allStats.filter { calendar.isDateInToday($0.date) }
            .reduce(into: UsageStatistics(date: calendar.startOfDay(for: now))) { result, stats in
                result = merge(result, with: stats)
            }

        let thisWeek = allStats.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .weekOfYear) }
            .reduce(into: UsageStatistics(date: calendar.startOfDay(for: now))) { result, stats in
                result = merge(result, with: stats)
            }

        let thisMonth = allStats.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
            .reduce(into: UsageStatistics(date: calendar.startOfDay(for: now))) { result, stats in
                result = merge(result, with: stats)
            }

        let allTime = allStats.reduce(into: UsageStatistics(date: calendar.startOfDay(for: now))) { result, stats in
            result = merge(result, with: stats)
        }

        return AggregatedStats(today: today, thisWeek: thisWeek, thisMonth: thisMonth, allTime: allTime)
    }

    /// Clear all statistics
    func clearAll() {
        userDefaults.removeObject(forKey: statsKey)
        userDefaults.synchronize()
    }

    /// Clear statistics older than retention period
    func cleanupOldStats(retentionDays: Int) throws {
        guard retentionDays > 0 else { return }

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date())!
        let allStats = loadAllStats()
        let recentStats = allStats.filter { $0.date >= cutoffDate }

        try saveAllStats(recentStats)
    }

    // MARK: - Private Helpers

    private func loadAllStats() -> [UsageStatistics] {
        guard let data = userDefaults.data(forKey: statsKey),
              let stats = try? JSONDecoder().decode([UsageStatistics].self, from: data) else {
            return []
        }
        return stats
    }

    private func saveAllStats(_ stats: [UsageStatistics]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(stats)
        userDefaults.set(data, forKey: statsKey)
        userDefaults.synchronize()
    }

    private func saveStats(_ stats: UsageStatistics) throws {
        var allStats = loadAllStats()

        // Remove existing stats for this date
        allStats.removeAll { Calendar.current.isDate($0.date, inSameDayAs: stats.date) }

        // Add new stats
        allStats.append(stats)

        try saveAllStats(allStats)
    }

    private func merge(_ lhs: UsageStatistics, with rhs: UsageStatistics) -> UsageStatistics {
        var result = lhs

        result.totalSessions += rhs.totalSessions
        result.successfulSessions += rhs.successfulSessions
        result.failedSessions += rhs.failedSessions
        result.totalWordsTranscribed += rhs.totalWordsTranscribed
        result.totalDurationSeconds += rhs.totalDurationSeconds

        // Weighted average for confidence
        if result.totalSessions > 0 {
            result.averageConfidence =
                (lhs.averageConfidence * Double(lhs.totalSessions) + rhs.averageConfidence * Double(rhs.totalSessions)) /
                Double(result.totalSessions)
        }

        // Merge language breakdown
        for rhsLang in rhs.languageBreakdown {
            if let index = result.languageBreakdown.firstIndex(where: { $0.languageCode == rhsLang.languageCode }) {
                result.languageBreakdown[index].sessionCount += rhsLang.sessionCount
                result.languageBreakdown[index].wordCount += rhsLang.wordCount
            } else {
                result.languageBreakdown.append(rhsLang)
            }
        }

        // Merge error breakdown
        for rhsError in rhs.errorBreakdown {
            if let index = result.errorBreakdown.firstIndex(where: { $0.errorType == rhsError.errorType }) {
                result.errorBreakdown[index].count += rhsError.count
            } else {
                result.errorBreakdown.append(rhsError)
            }
        }

        return result
    }

    private func extractErrorType(from message: String) -> String {
        let lowercased = message.lowercased()
        if lowercased.contains("permission") {
            return "permission_denied"
        } else if lowercased.contains("microphone") {
            return "microphone_error"
        } else if lowercased.contains("accessibility") {
            return "accessibility_error"
        } else if lowercased.contains("model") {
            return "model_error"
        } else if lowercased.contains("transcription") {
            return "transcription_error"
        } else {
            return "unknown_error"
        }
    }
}
