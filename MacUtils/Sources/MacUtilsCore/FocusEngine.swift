import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Focus Module Core Logic

/// Represents the state of the Focus timer
public enum FocusState: String, Codable, Equatable {
    case idle
    case focusRunning
    case breakRunning
}

/// Represents a completed focus session
public struct FocusSession: Codable, Equatable, Identifiable {
    public let id: UUID
    public let date: Date
    public let duration: TimeInterval
    public let type: SessionType
    public let note: String
    public let completed: Bool

    public enum SessionType: String, Codable, Equatable {
        case focus
        case breakTime = "break"
    }

    public init(id: UUID = UUID(), date: Date = Date(), duration: TimeInterval, type: SessionType, note: String, completed: Bool) {
        self.id = id
        self.date = date
        self.duration = duration
        self.type = type
        self.note = note
        self.completed = completed
    }
}

/// Core logic for the Focus (Pomodoro) timer.
/// Manages state transitions, timing, and session history.
/// The actual DispatchSourceTimer is handled in the app layer.
public final class FocusEngine {

    public private(set) var state: FocusState = .idle
    public private(set) var timeRemaining: TimeInterval = 0
    public private(set) var totalDuration: TimeInterval = 0
    public private(set) var sessionNumber: Int = 1
    public private(set) var currentNote: String = ""
    public private(set) var completedSessions: [FocusSession] = []

    public var focusDuration: TimeInterval
    public var breakDuration: TimeInterval
    public var sessionsPerCycle: Int

    public init(focusDuration: TimeInterval = 25 * 60,
                breakDuration: TimeInterval = 5 * 60,
                sessionsPerCycle: Int = 4) {
        self.focusDuration = focusDuration
        self.breakDuration = breakDuration
        self.sessionsPerCycle = max(1, sessionsPerCycle)
    }

    // MARK: - State Transitions

    /// Start a new focus session from idle
    public func startFocus(note: String = "") {
        guard state == .idle else { return }
        currentNote = note
        sessionNumber = 1
        state = .focusRunning
        totalDuration = focusDuration
        timeRemaining = focusDuration
    }

    /// Called every second to tick the timer down
    /// Returns true if the timer reached zero
    @discardableResult
    public func tick() -> Bool {
        guard state == .focusRunning || state == .breakRunning else { return false }
        timeRemaining = max(0, timeRemaining - 1)
        return timeRemaining <= 0
    }

    /// Complete the current session and transition to next state
    public func completeCurrentSession() {
        let sessionType: FocusSession.SessionType
        let duration: TimeInterval

        switch state {
        case .focusRunning:
            sessionType = .focus
            duration = focusDuration
        case .breakRunning:
            sessionType = .breakTime
            duration = breakDuration
        case .idle:
            return
        }

        let session = FocusSession(
            date: Date(),
            duration: duration,
            type: sessionType,
            note: currentNote,
            completed: true
        )
        completedSessions.append(session)

        transitionToNextState()
    }

    /// Skip the current session and advance to the next state
    public func skip() {
        guard state != .idle else { return }

        let sessionType: FocusSession.SessionType
        let duration: TimeInterval

        switch state {
        case .focusRunning:
            sessionType = .focus
            duration = focusDuration
        case .breakRunning:
            sessionType = .breakTime
            duration = breakDuration
        case .idle:
            return
        }

        let session = FocusSession(
            date: Date(),
            duration: duration - timeRemaining,
            type: sessionType,
            note: currentNote,
            completed: false
        )
        completedSessions.append(session)

        transitionToNextState()
    }

    /// Stop the timer and return to idle
    public func stop() {
        state = .idle
        timeRemaining = 0
        totalDuration = 0
        currentNote = ""
    }

    /// Transition to the next state based on current state
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
            }
        case .breakRunning:
            sessionNumber += 1
            state = .focusRunning
            totalDuration = focusDuration
            timeRemaining = focusDuration
        case .idle:
            break
        }
    }

    /// Format time remaining as MM:SS
    public var formattedTimeRemaining: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Today's completed focus sessions count
    public var todaySessionCount: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return completedSessions.filter { session in
            session.type == .focus && session.completed && calendar.startOfDay(for: session.date) == today
        }.count
    }

    // MARK: - Persistence

    public func encodeSessions() throws -> Data {
        try JSONEncoder().encode(completedSessions)
    }

    public func loadSessions(from data: Data) throws {
        completedSessions = try JSONDecoder().decode([FocusSession].self, from: data)
    }
}
