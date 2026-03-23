import MacUtilsCore
import Foundation
import AppKit

/// Manages the Focus (Pomodoro) timer state and UI updates.
final class FocusManager: ObservableObject {

    @Published var state: FocusState = .idle
    @Published var timeRemaining: TimeInterval = 0
    @Published var totalDuration: TimeInterval = 0
    @Published var currentNote: String = ""
    @Published var sessionNumber: Int = 1
    @Published var isPaused: Bool = false
    @Published var completedSessions: [FocusSession] = []

    var focusDuration: TimeInterval {
        get { TimeInterval(Settings.focusDuration) * 60 }
        set { Settings.focusDuration = Int(newValue / 60) }
    }

    var breakDuration: TimeInterval {
        get { TimeInterval(Settings.breakDuration) * 60 }
        set { Settings.breakDuration = Int(newValue / 60) }
    }

    var sessionsPerCycle: Int {
        get { Settings.sessionsPerCycle }
        set { Settings.sessionsPerCycle = newValue }
    }

    private var timer: DispatchSourceTimer?

    init() {
        loadSessions()
    }

    // MARK: - Timer Control

    func startFocus(note: String = "") {
        guard state == .idle else { return }
        currentNote = note
        sessionNumber = 1
        state = .focusRunning
        totalDuration = focusDuration
        timeRemaining = focusDuration
        isPaused = false
        startTimer()
    }

    func pause() {
        isPaused = true
        timer?.suspend()
    }

    func resume() {
        isPaused = false
        timer?.resume()
    }

    func skip() {
        guard state != .idle else { return }
        timer?.cancel()
        timer = nil

        let sessionType: FocusSession.SessionType = (state == .focusRunning) ? .focus : .breakTime
        let duration = (state == .focusRunning) ? focusDuration : breakDuration

        let session = FocusSession(
            date: Date(),
            duration: duration - timeRemaining,
            type: sessionType,
            note: currentNote,
            completed: false
        )
        completedSessions.append(session)
        saveSessions()

        transitionToNextState()
    }

    func stop() {
        timer?.cancel()
        timer = nil
        state = .idle
        timeRemaining = 0
        totalDuration = 0
        currentNote = ""
        isPaused = false
    }

    // MARK: - Timer Logic

    private func startTimer() {
        timer?.cancel()

        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(deadline: .now() + 1, repeating: 1.0)
        source.setEventHandler { [weak self] in
            self?.tick()
        }
        source.resume()
        timer = source
    }

    private func tick() {
        guard state != .idle else { return }
        timeRemaining = max(0, timeRemaining - 1)

        if timeRemaining <= 0 {
            completeCurrentSession()
        }
    }

    private func completeCurrentSession() {
        timer?.cancel()
        timer = nil

        let sessionType: FocusSession.SessionType = (state == .focusRunning) ? .focus : .breakTime
        let duration = (state == .focusRunning) ? focusDuration : breakDuration

        let session = FocusSession(
            date: Date(),
            duration: duration,
            type: sessionType,
            note: currentNote,
            completed: true
        )
        completedSessions.append(session)
        saveSessions()

        // Send notification
        sendNotification(session: session)

        // Play chime
        NSSound(named: "Hero")?.play()

        // Auto-transition after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.transitionToNextState()
        }
    }

    private func transitionToNextState() {
        switch state {
        case .focusRunning:
            if sessionNumber >= sessionsPerCycle {
                state = .idle
                timeRemaining = 0
                totalDuration = 0
            } else {
                state = .breakRunning
                totalDuration = breakDuration
                timeRemaining = breakDuration
                if Settings.focusAutoStartBreak {
                    startTimer()
                }
            }
        case .breakRunning:
            sessionNumber += 1
            state = .focusRunning
            totalDuration = focusDuration
            timeRemaining = focusDuration
            if Settings.focusAutoStartFocus {
                startTimer()
            }
        case .idle:
            break
        }
    }

    // MARK: - Formatting

    var formattedTimeRemaining: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return (totalDuration - timeRemaining) / totalDuration
    }

    var todaySessionCount: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return completedSessions.filter { session in
            session.type == .focus && session.completed && calendar.startOfDay(for: session.date) == today
        }.count
    }

    var thisWeekSessionCount: Int {
        let calendar = Calendar.current
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) else { return 0 }
        return completedSessions.filter { session in
            session.type == .focus && session.completed && session.date >= weekStart
        }.count
    }

    var thisWeekHours: Double {
        let calendar = Calendar.current
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) else { return 0 }
        let totalSeconds = completedSessions.filter { session in
            session.type == .focus && session.completed && session.date >= weekStart
        }.reduce(0.0) { $0 + $1.duration }
        return totalSeconds / 3600.0
    }

    // MARK: - Notifications

    private func sendNotification(session: FocusSession) {
        let content = UNMutableNotificationContent()
        content.title = session.type == .focus ? "Focus session complete!" : "Break time's over!"
        content.body = session.note.isEmpty
            ? "Session \(sessionNumber) of \(sessionsPerCycle) finished."
            : session.note
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    // MARK: - Persistence

    private func saveSessions() {
        guard let data = try? JSONEncoder().encode(completedSessions) else { return }
        Settings.focusSessionsData = data
    }

    private func loadSessions() {
        guard let data = Settings.focusSessionsData else { return }
        completedSessions = (try? JSONDecoder().decode([FocusSession].self, from: data)) ?? []
    }

    func clearHistory() {
        completedSessions.removeAll()
        saveSessions()
    }
}

import UserNotifications
