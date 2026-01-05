import Foundation
import Observation

/// Observable app-wide state management
@Observable @MainActor
class AppState {
    var settings: UserSettings
    var statistics: AggregatedStats
    var currentSession: RecordingSession?
    var isRecording: Bool = false
    var showOnboarding: Bool = false
    var showSettings: Bool = false
    var errorMessage: String?

    // Voice trigger monitoring state (for menu bar indicator)
    var voiceTriggerState: VoiceTriggerState = .idle

    // Services
    let fluidAudioService: FluidAudioService
    let permissionService: PermissionService
    let settingsService: SettingsService
    let statisticsService: StatisticsService

    /// Task for loading statistics - tracked for proper lifecycle management
    @ObservationIgnored private var loadingTask: Task<Void, Never>?
    /// nonisolated copy for deinit access (deinit cannot access MainActor-isolated state)
    @ObservationIgnored private nonisolated(unsafe) var deinitLoadingTask: Task<Void, Never>?
    /// Observer for voice trigger state changes
    @ObservationIgnored private var voiceTriggerStateObserver: NSObjectProtocol?
    /// nonisolated copy for deinit access
    @ObservationIgnored private nonisolated(unsafe) var deinitVoiceTriggerStateObserver: NSObjectProtocol?

    init() {
        // Initialize services
        self.fluidAudioService = FluidAudioService()
        self.permissionService = PermissionService()
        self.settingsService = SettingsService()
        self.statisticsService = StatisticsService()

        // Load settings
        self.settings = settingsService.load()

        // Load statistics asynchronously (actor isolation)
        // Track the task for proper lifecycle management
        self.statistics = .empty
        let task = Task { [weak self] in
            guard let self else { return }
            self.statistics = await statisticsService.getAggregatedStats()
        }
        loadingTask = task
        deinitLoadingTask = task

        // Check if onboarding needed
        self.showOnboarding = !settings.onboarding.completed

        // Observe voice trigger state changes from AppDelegate
        let observer = NotificationCenter.default.addObserver(
            forName: .voiceTriggerStateChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            if let state = notification.userInfo?["state"] as? VoiceTriggerState {
                self.voiceTriggerState = state
            }
        }
        voiceTriggerStateObserver = observer
        deinitVoiceTriggerStateObserver = observer
    }

    deinit {
        deinitLoadingTask?.cancel()
        if let observer = deinitVoiceTriggerStateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Initialize FluidAudio on app startup
    func initializeFluidAudio() async {
        do {
            try await fluidAudioService.initialize(language: settings.language.defaultLanguage)
        } catch {
            errorMessage = "Failed to initialize speech recognition: \(error.localizedDescription)"
        }
    }

    /// Start a new recording session
    func startRecording() {
        currentSession = RecordingSession(
            language: settings.language.defaultLanguage,
            state: .recording
        )
        isRecording = true
    }

    /// Stop recording and transition to transcribing
    func stopRecording() {
        guard var session = currentSession else { return }
        session.endTime = Date()
        session.state = .transcribing
        currentSession = session
        isRecording = false
    }

    /// Complete session successfully
    func completeSession() async {
        guard var session = currentSession else { return }
        session.state = .completed
        session.insertionSuccess = true

        // Record statistics
        do {
            try await statisticsService.recordSession(session)
            statistics = await statisticsService.getAggregatedStats()
        } catch {
            errorMessage = "Failed to record statistics: \(error.localizedDescription)"
        }

        currentSession = nil
    }

    /// Cancel current session
    func cancelSession() {
        guard var session = currentSession else { return }
        session.state = .cancelled
        currentSession = nil
        isRecording = false
    }

    /// Update settings
    func updateSettings(_ newSettings: UserSettings) {
        do {
            try settingsService.save(newSettings)
            settings = newSettings
        } catch {
            errorMessage = "Failed to save settings: \(error.localizedDescription)"
        }
    }

    /// Complete onboarding
    func completeOnboarding() {
        do {
            try settingsService.completeOnboarding()
            settings = settingsService.load()
            showOnboarding = false
        } catch {
            errorMessage = "Failed to complete onboarding: \(error.localizedDescription)"
        }
    }

    /// Refresh statistics
    func refreshStatistics() async {
        statistics = await statisticsService.getAggregatedStats()
    }
}
