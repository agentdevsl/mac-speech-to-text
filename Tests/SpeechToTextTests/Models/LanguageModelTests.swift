import XCTest
@testable import SpeechToText

final class LanguageModelTests: XCTestCase {

    // MARK: - Initialization Tests

    func test_initialization_createsLanguageModelWithDefaultValues() {
        // Given
        let languageCode = "en"
        let displayName = "English"
        let modelPath = URL(fileURLWithPath: "/tmp/model.bin")
        let fileSize: Int64 = 1024 * 1024 * 100 // 100MB

        // When
        let model = LanguageModel(
            languageCode: languageCode,
            displayName: displayName,
            modelPath: modelPath,
            fileSize: fileSize
        )

        // Then
        XCTAssertNotNil(model.id)
        XCTAssertEqual(model.languageCode, languageCode)
        XCTAssertEqual(model.displayName, displayName)
        XCTAssertEqual(model.modelPath, modelPath)
        XCTAssertEqual(model.downloadStatus, .notDownloaded)
        XCTAssertEqual(model.fileSize, fileSize)
        XCTAssertNil(model.downloadedAt)
        XCTAssertNil(model.lastUsed)
        XCTAssertEqual(model.version, "0.6b-v3")
        XCTAssertEqual(model.checksumSHA256, "")
    }

    func test_initialization_createsLanguageModelWithCustomValues() {
        // Given
        let id = UUID()
        let downloadedAt = Date()
        let lastUsed = Date()
        let version = "1.0.0"
        let checksum = "abc123"

        // When
        let model = LanguageModel(
            id: id,
            languageCode: "fr",
            displayName: "Français",
            modelPath: URL(fileURLWithPath: "/tmp/fr.bin"),
            downloadStatus: .downloaded,
            fileSize: 1024,
            downloadedAt: downloadedAt,
            lastUsed: lastUsed,
            version: version,
            checksumSHA256: checksum
        )

        // Then
        XCTAssertEqual(model.id, id)
        XCTAssertEqual(model.downloadStatus, .downloaded)
        XCTAssertEqual(model.downloadedAt, downloadedAt)
        XCTAssertEqual(model.lastUsed, lastUsed)
        XCTAssertEqual(model.version, version)
        XCTAssertEqual(model.checksumSHA256, checksum)
    }

    // MARK: - DownloadStatus Tests

    func test_downloadStatus_isDownloaded_returnsTrueWhenDownloaded() {
        // Given
        let status = DownloadStatus.downloaded

        // When/Then
        XCTAssertTrue(status.isDownloaded)
    }

    func test_downloadStatus_isDownloaded_returnsFalseWhenNotDownloaded() {
        // Given
        let status = DownloadStatus.notDownloaded

        // When/Then
        XCTAssertFalse(status.isDownloaded)
    }

    func test_downloadStatus_isDownloading_returnsTrueWhenDownloading() {
        // Given
        let status = DownloadStatus.downloading(progress: 0.5, bytesDownloaded: 1024)

        // When/Then
        XCTAssertTrue(status.isDownloading)
    }

    func test_downloadStatus_isDownloading_returnsFalseWhenNotDownloading() {
        // Given
        let status = DownloadStatus.downloaded

        // When/Then
        XCTAssertFalse(status.isDownloading)
    }

    func test_downloadStatus_displayText_returnsCorrectTextForNotDownloaded() {
        // Given
        let status = DownloadStatus.notDownloaded

        // When
        let displayText = status.displayText

        // Then
        XCTAssertEqual(displayText, "Not downloaded")
    }

    func test_downloadStatus_displayText_returnsCorrectTextForDownloading() {
        // Given
        let status = DownloadStatus.downloading(progress: 0.75, bytesDownloaded: 1024)

        // When
        let displayText = status.displayText

        // Then
        XCTAssertEqual(displayText, "Downloading 75%")
    }

    func test_downloadStatus_displayText_returnsCorrectTextForDownloaded() {
        // Given
        let status = DownloadStatus.downloaded

        // When
        let displayText = status.displayText

        // Then
        XCTAssertEqual(displayText, "Downloaded")
    }

    func test_downloadStatus_displayText_returnsCorrectTextForError() {
        // Given
        let status = DownloadStatus.error(message: "Network timeout")

        // When
        let displayText = status.displayText

        // Then
        XCTAssertEqual(displayText, "Error: Network timeout")
    }

    // MARK: - SupportedLanguage Tests

    func test_supportedLanguage_displayName_returnsCorrectName() {
        // Given/When/Then
        XCTAssertEqual(SupportedLanguage.en.displayName, "English")
        XCTAssertEqual(SupportedLanguage.es.displayName, "Español")
        XCTAssertEqual(SupportedLanguage.fr.displayName, "Français")
        XCTAssertEqual(SupportedLanguage.de.displayName, "Deutsch")
    }

    func test_supportedLanguage_nativeName_matchesDisplayName() {
        // Given
        let language = SupportedLanguage.en

        // When/Then
        XCTAssertEqual(language.nativeName, language.displayName)
    }

    func test_supportedLanguage_isSupported_returnsTrueForSupportedLanguage() {
        // Given/When
        let isSupported = SupportedLanguage.isSupported("en")

        // Then
        XCTAssertTrue(isSupported)
    }

    func test_supportedLanguage_isSupported_returnsFalseForUnsupportedLanguage() {
        // Given/When
        let isSupported = SupportedLanguage.isSupported("zh")

        // Then
        XCTAssertFalse(isSupported)
    }

    func test_supportedLanguage_from_returnsLanguageForValidCode() {
        // Given/When
        let language = SupportedLanguage.from(code: "en")

        // Then
        XCTAssertNotNil(language)
        XCTAssertEqual(language, .en)
    }

    func test_supportedLanguage_from_returnsNilForInvalidCode() {
        // Given/When
        let language = SupportedLanguage.from(code: "invalid")

        // Then
        XCTAssertNil(language)
    }

    func test_supportedLanguage_allCases_contains25Languages() {
        // Given/When
        let allLanguages = SupportedLanguage.allCases

        // Then
        XCTAssertEqual(allLanguages.count, 25)
    }

    // MARK: - Codable Tests

    func test_languageModel_encodesAndDecodes() throws {
        // Given
        let original = LanguageModel(
            languageCode: "en",
            displayName: "English",
            modelPath: URL(fileURLWithPath: "/tmp/model.bin"),
            downloadStatus: .downloading(progress: 0.5, bytesDownloaded: 1024),
            fileSize: 2048
        )

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(LanguageModel.self, from: data)

        // Then
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.languageCode, original.languageCode)
        XCTAssertEqual(decoded.displayName, original.displayName)
        XCTAssertEqual(decoded.modelPath, original.modelPath)
        XCTAssertEqual(decoded.fileSize, original.fileSize)
    }
}
