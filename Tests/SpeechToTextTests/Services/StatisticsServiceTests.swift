import XCTest
@testable import SpeechToText

final class StatisticsServiceTests: XCTestCase {

    var userDefaults: UserDefaults!
    var service: StatisticsService!

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: "com.speechtotext.stats.tests")!
        userDefaults.removePersistentDomain(forName: "com.speechtotext.stats.tests")
        service = StatisticsService(userDefaults: userDefaults)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: "com.speechtotext.stats.tests")
        super.tearDown()
    }

    // MARK: - Record Session Tests

    func test_recordSession_incrementsTotalSessions() async throws {
        // Given
        let session = RecordingSession(
            language: "en",
            state: .completed
        )

        // When
        try await service.recordSession(session)

        // Then
        let stats = await service.getTodayStats()
        XCTAssertEqual(stats.totalSessions, 1)
    }

    func test_recordSession_incrementsSuccessfulSessionsWhenInsertionSucceeds() async throws {
        // Given
        var session = RecordingSession(language: "en")
        session.insertionSuccess = true

        // When
        try await service.recordSession(session)

        // Then
        let stats = await service.getTodayStats()
        XCTAssertEqual(stats.successfulSessions, 1)
        XCTAssertEqual(stats.failedSessions, 0)
    }

    func test_recordSession_incrementsFailedSessionsWhenInsertionFails() async throws {
        // Given
        var session = RecordingSession(language: "en")
        session.insertionSuccess = false

        // When
        try await service.recordSession(session)

        // Then
        let stats = await service.getTodayStats()
        XCTAssertEqual(stats.successfulSessions, 0)
        XCTAssertEqual(stats.failedSessions, 1)
    }

    func test_recordSession_updatesWordCount() async throws {
        // Given
        var session = RecordingSession(language: "en")
        session.transcribedText = "Hello world test"
        session.insertionSuccess = true

        // When
        try await service.recordSession(session)

        // Then
        let stats = await service.getTodayStats()
        XCTAssertEqual(stats.totalWordsTranscribed, 3)
    }

    func test_recordSession_updatesDuration() async throws {
        // Given
        var session = RecordingSession(language: "en")
        session.endTime = session.startTime.addingTimeInterval(5.0) // 5 seconds

        // When
        try await service.recordSession(session)

        // Then
        let stats = await service.getTodayStats()
        XCTAssertEqual(stats.totalDurationSeconds, 5.0, accuracy: 0.1)
    }

    func test_recordSession_updatesAverageConfidence() async throws {
        // Given
        var session1 = RecordingSession(language: "en")
        session1.confidenceScore = 0.8

        var session2 = RecordingSession(language: "en")
        session2.confidenceScore = 0.9

        // When
        try await service.recordSession(session1)
        try await service.recordSession(session2)

        // Then
        let stats = await service.getTodayStats()
        XCTAssertEqual(stats.averageConfidence, 0.85, accuracy: 0.01)
    }

    func test_recordSession_updatesLanguageBreakdown() async throws {
        // Given
        var sessionEn = RecordingSession(language: "en")
        sessionEn.transcribedText = "Hello world"
        sessionEn.insertionSuccess = true

        var sessionFr = RecordingSession(language: "fr")
        sessionFr.transcribedText = "Bonjour monde"
        sessionFr.insertionSuccess = true

        // When
        try await service.recordSession(sessionEn)
        try await service.recordSession(sessionFr)

        // Then
        let stats = await service.getTodayStats()
        XCTAssertEqual(stats.languageBreakdown.count, 2)

        let enStats = stats.languageBreakdown.first { $0.languageCode == "en" }
        XCTAssertNotNil(enStats)
        XCTAssertEqual(enStats?.sessionCount, 1)
        XCTAssertEqual(enStats?.wordCount, 2)

        let frStats = stats.languageBreakdown.first { $0.languageCode == "fr" }
        XCTAssertNotNil(frStats)
        XCTAssertEqual(frStats?.sessionCount, 1)
        XCTAssertEqual(frStats?.wordCount, 2)
    }

    func test_recordSession_updatesErrorBreakdown() async throws {
        // Given
        var session1 = RecordingSession(language: "en")
        session1.insertionSuccess = false
        session1.errorMessage = "Microphone error occurred"

        var session2 = RecordingSession(language: "en")
        session2.insertionSuccess = false
        session2.errorMessage = "Permission denied"

        // When
        try await service.recordSession(session1)
        try await service.recordSession(session2)

        // Then
        let stats = await service.getTodayStats()
        XCTAssertGreaterThanOrEqual(stats.errorBreakdown.count, 1)
    }

    // MARK: - Get Today Stats Tests

    func test_getTodayStats_returnsEmptyStatsWhenNoSessions() async {
        // Given/When
        let stats = await service.getTodayStats()

        // Then
        XCTAssertEqual(stats.totalSessions, 0)
        XCTAssertEqual(stats.successfulSessions, 0)
        XCTAssertEqual(stats.failedSessions, 0)
    }

    func test_getTodayStats_returnsOnlyTodaysSessions() async throws {
        // Given
        let session = RecordingSession(language: "en")

        // When
        try await service.recordSession(session)

        // Then
        let stats = await service.getTodayStats()
        let calendar = Calendar.current
        XCTAssertTrue(calendar.isDateInToday(stats.date))
        XCTAssertEqual(stats.totalSessions, 1)
    }

    // MARK: - Get Stats For Date Tests

    func test_getStatsForDate_returnsEmptyStatsForDateWithNoSessions() async {
        // Given
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        // When
        let stats = await service.getStatsForDate(yesterday)

        // Then
        XCTAssertEqual(stats.totalSessions, 0)
    }

    // MARK: - Get Aggregated Stats Tests

    func test_getAggregatedStats_returnsEmptyStatsWhenNoSessions() async {
        // Given/When
        let aggregated = await service.getAggregatedStats()

        // Then
        XCTAssertEqual(aggregated.today.totalSessions, 0)
        XCTAssertEqual(aggregated.thisWeek.totalSessions, 0)
        XCTAssertEqual(aggregated.thisMonth.totalSessions, 0)
        XCTAssertEqual(aggregated.allTime.totalSessions, 0)
    }

    func test_getAggregatedStats_aggregatesTodaysSessions() async throws {
        // Given
        let session1 = RecordingSession(language: "en")
        let session2 = RecordingSession(language: "fr")

        // When
        try await service.recordSession(session1)
        try await service.recordSession(session2)

        // Then
        let aggregated = await service.getAggregatedStats()
        XCTAssertEqual(aggregated.today.totalSessions, 2)
        XCTAssertEqual(aggregated.thisWeek.totalSessions, 2)
        XCTAssertEqual(aggregated.thisMonth.totalSessions, 2)
        XCTAssertEqual(aggregated.allTime.totalSessions, 2)
    }

    // MARK: - Clear All Tests

    func test_clearAll_removesAllStatistics() async throws {
        // Given
        let session = RecordingSession(language: "en")
        try await service.recordSession(session)
        let initialStats = await service.getTodayStats()
        XCTAssertEqual(initialStats.totalSessions, 1)

        // When
        await service.clearAll()

        // Then
        let stats = await service.getTodayStats()
        XCTAssertEqual(stats.totalSessions, 0)
    }

    // MARK: - Cleanup Old Stats Tests

    func test_cleanupOldStats_removesStatsOlderThanRetentionPeriod() async throws {
        // Given
        // Create stats for today
        let todaySession = RecordingSession(language: "en")
        try await service.recordSession(todaySession)

        // When
        try await service.cleanupOldStats(retentionDays: 7)

        // Then
        // Today's stats should still exist
        let stats = await service.getTodayStats()
        XCTAssertEqual(stats.totalSessions, 1)
    }

    func test_cleanupOldStats_doesNothingWhenRetentionDaysIsZero() async throws {
        // Given
        let session = RecordingSession(language: "en")
        try await service.recordSession(session)

        // When
        try await service.cleanupOldStats(retentionDays: 0)

        // Then
        let stats = await service.getTodayStats()
        XCTAssertEqual(stats.totalSessions, 1)
    }

    // MARK: - Multiple Sessions Tests

    func test_recordMultipleSessions_aggregatesCorrectly() async throws {
        // Given
        var session1 = RecordingSession(language: "en")
        session1.transcribedText = "Hello"
        session1.insertionSuccess = true
        session1.confidenceScore = 0.9
        session1.endTime = session1.startTime.addingTimeInterval(2.0)

        var session2 = RecordingSession(language: "en")
        session2.transcribedText = "World test"
        session2.insertionSuccess = true
        session2.confidenceScore = 0.8
        session2.endTime = session2.startTime.addingTimeInterval(3.0)

        var session3 = RecordingSession(language: "fr")
        session3.transcribedText = "Bonjour"
        session3.insertionSuccess = false
        session3.errorMessage = "Test error"

        // When
        try await service.recordSession(session1)
        try await service.recordSession(session2)
        try await service.recordSession(session3)

        // Then
        let stats = await service.getTodayStats()
        XCTAssertEqual(stats.totalSessions, 3)
        XCTAssertEqual(stats.successfulSessions, 2)
        XCTAssertEqual(stats.failedSessions, 1)
        XCTAssertEqual(stats.totalWordsTranscribed, 3) // "Hello" + "World test"
        XCTAssertEqual(stats.totalDurationSeconds, 5.0, accuracy: 0.1)
        XCTAssertEqual(stats.languageBreakdown.count, 2)
        XCTAssertGreaterThanOrEqual(stats.errorBreakdown.count, 1)
    }

    // MARK: - Error Type Extraction Tests

    func test_errorTypeExtraction_identifiesPermissionErrors() async throws {
        // Given
        var session = RecordingSession(language: "en")
        session.insertionSuccess = false
        session.errorMessage = "Permission denied by user"

        // When
        try await service.recordSession(session)

        // Then
        let stats = await service.getTodayStats()
        let errorTypes = stats.errorBreakdown.map { $0.errorType }
        XCTAssertTrue(errorTypes.contains("permission_denied"))
    }

    func test_errorTypeExtraction_identifiesMicrophoneErrors() async throws {
        // Given
        var session = RecordingSession(language: "en")
        session.insertionSuccess = false
        session.errorMessage = "Microphone not available"

        // When
        try await service.recordSession(session)

        // Then
        let stats = await service.getTodayStats()
        let errorTypes = stats.errorBreakdown.map { $0.errorType }
        XCTAssertTrue(errorTypes.contains("microphone_error"))
    }

    func test_errorTypeExtraction_identifiesAccessibilityErrors() async throws {
        // Given
        var session = RecordingSession(language: "en")
        session.insertionSuccess = false
        session.errorMessage = "Accessibility permission required"

        // When
        try await service.recordSession(session)

        // Then
        let stats = await service.getTodayStats()
        let errorTypes = stats.errorBreakdown.map { $0.errorType }
        XCTAssertTrue(errorTypes.contains("accessibility_error"))
    }
}
