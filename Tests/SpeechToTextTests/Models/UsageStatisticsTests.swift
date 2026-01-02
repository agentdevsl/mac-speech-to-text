import XCTest
@testable import SpeechToText

final class UsageStatisticsTests: XCTestCase {

    // MARK: - Initialization Tests

    func test_initialization_createsUsageStatisticsWithDefaultValues() {
        // Given/When
        let stats = UsageStatistics()

        // Then
        XCTAssertNotNil(stats.id)
        XCTAssertNotNil(stats.date)
        XCTAssertEqual(stats.totalSessions, 0)
        XCTAssertEqual(stats.successfulSessions, 0)
        XCTAssertEqual(stats.failedSessions, 0)
        XCTAssertEqual(stats.totalWordsTranscribed, 0)
        XCTAssertEqual(stats.totalDurationSeconds, 0)
        XCTAssertEqual(stats.averageConfidence, 0.0)
        XCTAssertTrue(stats.languageBreakdown.isEmpty)
        XCTAssertTrue(stats.errorBreakdown.isEmpty)
    }

    func test_initialization_createsUsageStatisticsWithCustomValues() {
        // Given
        let id = UUID()
        let date = Date()
        let languageStats = [LanguageStats(languageCode: "en", sessionCount: 5, wordCount: 100)]
        let errorStats = [ErrorStats(errorType: "network_error", count: 2)]

        // When
        let stats = UsageStatistics(
            id: id,
            date: date,
            totalSessions: 10,
            successfulSessions: 8,
            failedSessions: 2,
            totalWordsTranscribed: 500,
            totalDurationSeconds: 120.0,
            averageConfidence: 0.85,
            languageBreakdown: languageStats,
            errorBreakdown: errorStats
        )

        // Then
        XCTAssertEqual(stats.id, id)
        XCTAssertEqual(stats.date, date)
        XCTAssertEqual(stats.totalSessions, 10)
        XCTAssertEqual(stats.successfulSessions, 8)
        XCTAssertEqual(stats.failedSessions, 2)
        XCTAssertEqual(stats.totalWordsTranscribed, 500)
        XCTAssertEqual(stats.totalDurationSeconds, 120.0)
        XCTAssertEqual(stats.averageConfidence, 0.85)
        XCTAssertEqual(stats.languageBreakdown.count, 1)
        XCTAssertEqual(stats.errorBreakdown.count, 1)
    }

    // MARK: - Success Rate Tests

    func test_successRate_returnsZeroWhenNoSessions() {
        // Given
        let stats = UsageStatistics()

        // When
        let successRate = stats.successRate

        // Then
        XCTAssertEqual(successRate, 0.0)
    }

    func test_successRate_calculatesCorrectlyWithSessions() {
        // Given
        let stats = UsageStatistics(
            totalSessions: 10,
            successfulSessions: 7,
            failedSessions: 3
        )

        // When
        let successRate = stats.successRate

        // Then
        XCTAssertEqual(successRate, 0.7, accuracy: 0.01)
    }

    func test_successRate_returns100PercentWhenAllSuccessful() {
        // Given
        let stats = UsageStatistics(
            totalSessions: 5,
            successfulSessions: 5,
            failedSessions: 0
        )

        // When
        let successRate = stats.successRate

        // Then
        XCTAssertEqual(successRate, 1.0)
    }

    // MARK: - Average Words Per Session Tests

    func test_averageWordsPerSession_returnsZeroWhenNoSessions() {
        // Given
        let stats = UsageStatistics()

        // When
        let averageWords = stats.averageWordsPerSession

        // Then
        XCTAssertEqual(averageWords, 0.0)
    }

    func test_averageWordsPerSession_calculatesCorrectly() {
        // Given
        let stats = UsageStatistics(
            totalSessions: 5,
            totalWordsTranscribed: 250
        )

        // When
        let averageWords = stats.averageWordsPerSession

        // Then
        XCTAssertEqual(averageWords, 50.0)
    }

    // MARK: - LanguageStats Tests

    func test_languageStats_initialization_createsWithDefaultValues() {
        // Given/When
        let languageStats = LanguageStats(languageCode: "en")

        // Then
        XCTAssertNotNil(languageStats.id)
        XCTAssertEqual(languageStats.languageCode, "en")
        XCTAssertEqual(languageStats.sessionCount, 0)
        XCTAssertEqual(languageStats.wordCount, 0)
    }

    func test_languageStats_initialization_createsWithCustomValues() {
        // Given/When
        let languageStats = LanguageStats(
            languageCode: "fr",
            sessionCount: 10,
            wordCount: 200
        )

        // Then
        XCTAssertEqual(languageStats.languageCode, "fr")
        XCTAssertEqual(languageStats.sessionCount, 10)
        XCTAssertEqual(languageStats.wordCount, 200)
    }

    // MARK: - ErrorStats Tests

    func test_errorStats_initialization_createsWithDefaultValues() {
        // Given/When
        let errorStats = ErrorStats(errorType: "network_error")

        // Then
        XCTAssertNotNil(errorStats.id)
        XCTAssertEqual(errorStats.errorType, "network_error")
        XCTAssertEqual(errorStats.count, 0)
    }

    func test_errorStats_initialization_createsWithCustomValues() {
        // Given/When
        let errorStats = ErrorStats(errorType: "permission_denied", count: 5)

        // Then
        XCTAssertEqual(errorStats.errorType, "permission_denied")
        XCTAssertEqual(errorStats.count, 5)
    }

    // MARK: - AggregatedStats Tests

    func test_aggregatedStats_initialization_createsWithDefaultValues() {
        // Given/When
        let aggregated = AggregatedStats()

        // Then
        XCTAssertEqual(aggregated.today.totalSessions, 0)
        XCTAssertEqual(aggregated.thisWeek.totalSessions, 0)
        XCTAssertEqual(aggregated.thisMonth.totalSessions, 0)
        XCTAssertEqual(aggregated.allTime.totalSessions, 0)
    }

    func test_aggregatedStats_initialization_createsWithCustomValues() {
        // Given
        let today = UsageStatistics(totalSessions: 5)
        let thisWeek = UsageStatistics(totalSessions: 20)
        let thisMonth = UsageStatistics(totalSessions: 50)
        let allTime = UsageStatistics(totalSessions: 200)

        // When
        let aggregated = AggregatedStats(
            today: today,
            thisWeek: thisWeek,
            thisMonth: thisMonth,
            allTime: allTime
        )

        // Then
        XCTAssertEqual(aggregated.today.totalSessions, 5)
        XCTAssertEqual(aggregated.thisWeek.totalSessions, 20)
        XCTAssertEqual(aggregated.thisMonth.totalSessions, 50)
        XCTAssertEqual(aggregated.allTime.totalSessions, 200)
    }

    func test_aggregatedStats_empty_hasZeroSessions() {
        // Given/When
        let empty = AggregatedStats.empty

        // Then
        XCTAssertEqual(empty.today.totalSessions, 0)
        XCTAssertEqual(empty.thisWeek.totalSessions, 0)
        XCTAssertEqual(empty.thisMonth.totalSessions, 0)
        XCTAssertEqual(empty.allTime.totalSessions, 0)
    }

    // MARK: - Codable Tests

    func test_usageStatistics_encodesAndDecodes() throws {
        // Given
        let languageStats = [LanguageStats(languageCode: "en", sessionCount: 5, wordCount: 100)]
        let errorStats = [ErrorStats(errorType: "network_error", count: 2)]

        let original = UsageStatistics(
            totalSessions: 10,
            successfulSessions: 8,
            failedSessions: 2,
            totalWordsTranscribed: 500,
            totalDurationSeconds: 120.0,
            averageConfidence: 0.85,
            languageBreakdown: languageStats,
            errorBreakdown: errorStats
        )

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(UsageStatistics.self, from: data)

        // Then
        XCTAssertEqual(decoded.totalSessions, original.totalSessions)
        XCTAssertEqual(decoded.successfulSessions, original.successfulSessions)
        XCTAssertEqual(decoded.failedSessions, original.failedSessions)
        XCTAssertEqual(decoded.totalWordsTranscribed, original.totalWordsTranscribed)
        XCTAssertEqual(decoded.totalDurationSeconds, original.totalDurationSeconds)
        XCTAssertEqual(decoded.averageConfidence, original.averageConfidence)
        XCTAssertEqual(decoded.languageBreakdown.count, 1)
        XCTAssertEqual(decoded.errorBreakdown.count, 1)
    }
}
