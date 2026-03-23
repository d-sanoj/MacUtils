import XCTest
@testable import MacUtilsCore

final class FocusTests: XCTestCase {

    var engine: FocusEngine!

    override func setUp() {
        super.setUp()
        engine = FocusEngine(
            focusDuration: 25 * 60,
            breakDuration: 5 * 60,
            sessionsPerCycle: 4
        )
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - State Machine Transitions

    func testInitialStateIsIdle() {
        XCTAssertEqual(engine.state, .idle)
        XCTAssertEqual(engine.timeRemaining, 0)
    }

    func testStartFocusTransitionsFromIdleToFocusRunning() {
        engine.startFocus(note: "Test session")
        XCTAssertEqual(engine.state, .focusRunning)
        XCTAssertEqual(engine.timeRemaining, 25 * 60)
        XCTAssertEqual(engine.currentNote, "Test session")
        XCTAssertEqual(engine.sessionNumber, 1)
    }

    func testStartFocusOnlyWorksFromIdle() {
        engine.startFocus()
        XCTAssertEqual(engine.state, .focusRunning)

        // Calling startFocus again while running should have no effect
        engine.startFocus(note: "Second attempt")
        XCTAssertEqual(engine.state, .focusRunning)
        XCTAssertEqual(engine.currentNote, "")  // Original note, not second
    }

    func testFocusToBreakTransition() {
        engine.startFocus()
        engine.completeCurrentSession()
        XCTAssertEqual(engine.state, .breakRunning)
        XCTAssertEqual(engine.timeRemaining, 5 * 60)
    }

    func testBreakToFocusTransition() {
        engine.startFocus()
        engine.completeCurrentSession()  // Focus → Break
        XCTAssertEqual(engine.state, .breakRunning)

        engine.completeCurrentSession()  // Break → Focus
        XCTAssertEqual(engine.state, .focusRunning)
        XCTAssertEqual(engine.sessionNumber, 2)
    }

    func testFullCycleEndsAtIdle() {
        engine.startFocus()

        // Complete all focus and break sessions in a full cycle
        for session in 1...4 {
            XCTAssertEqual(engine.state, .focusRunning, "Session \(session) should be focusRunning")
            engine.completeCurrentSession()

            if session < 4 {
                XCTAssertEqual(engine.state, .breakRunning, "After session \(session) should be breakRunning")
                engine.completeCurrentSession()
            }
        }

        // After completing the 4th focus session, should go to idle
        XCTAssertEqual(engine.state, .idle)
    }

    // MARK: - Timer Countdown

    func testTickDecreasesTimeRemaining() {
        engine.startFocus()
        let initialTime = engine.timeRemaining

        let completed = engine.tick()
        XCTAssertFalse(completed)
        XCTAssertEqual(engine.timeRemaining, initialTime - 1)
    }

    func testTickReturnsTrueWhenTimerReachesZero() {
        engine = FocusEngine(focusDuration: 2, breakDuration: 1, sessionsPerCycle: 1)
        engine.startFocus()

        XCTAssertFalse(engine.tick())  // 2 → 1
        XCTAssertTrue(engine.tick())   // 1 → 0
    }

    func testTickDoesNothingWhenIdle() {
        let result = engine.tick()
        XCTAssertFalse(result)
        XCTAssertEqual(engine.timeRemaining, 0)
    }

    func testTickDoesNotGoBelowZero() {
        engine = FocusEngine(focusDuration: 1, breakDuration: 1, sessionsPerCycle: 1)
        engine.startFocus()
        engine.tick()  // 1 → 0
        engine.tick()  // Should stay at 0
        XCTAssertEqual(engine.timeRemaining, 0)
    }

    // MARK: - Session History

    func testSessionSavedOnComplete() {
        engine.startFocus(note: "Test note")
        engine.completeCurrentSession()

        XCTAssertEqual(engine.completedSessions.count, 1)
        let session = engine.completedSessions[0]
        XCTAssertEqual(session.type, .focus)
        XCTAssertEqual(session.note, "Test note")
        XCTAssertTrue(session.completed)
        XCTAssertEqual(session.duration, 25 * 60)
    }

    func testSessionSavedOnSkip() {
        engine = FocusEngine(focusDuration: 100, breakDuration: 50, sessionsPerCycle: 4)
        engine.startFocus()

        // Tick 30 seconds then skip
        for _ in 0..<30 {
            engine.tick()
        }
        engine.skip()

        XCTAssertEqual(engine.completedSessions.count, 1)
        let session = engine.completedSessions[0]
        XCTAssertFalse(session.completed)
        XCTAssertEqual(session.duration, 70, accuracy: 1)  // 100 - 30
    }

    // MARK: - Custom Durations

    func testCustomFocusDuration() {
        engine = FocusEngine(focusDuration: 45 * 60, breakDuration: 10 * 60, sessionsPerCycle: 2)
        engine.startFocus()
        XCTAssertEqual(engine.timeRemaining, 45 * 60)
        XCTAssertEqual(engine.totalDuration, 45 * 60)
    }

    func testCustomBreakDuration() {
        engine = FocusEngine(focusDuration: 25 * 60, breakDuration: 15 * 60, sessionsPerCycle: 4)
        engine.startFocus()
        engine.completeCurrentSession()
        XCTAssertEqual(engine.timeRemaining, 15 * 60)
    }

    func testCustomSessionsPerCycle() {
        engine = FocusEngine(focusDuration: 10, breakDuration: 5, sessionsPerCycle: 2)
        engine.startFocus()

        // Session 1: Focus → Break
        engine.completeCurrentSession()
        XCTAssertEqual(engine.state, .breakRunning)
        engine.completeCurrentSession()

        // Session 2: Focus → Idle (last session)
        XCTAssertEqual(engine.state, .focusRunning)
        engine.completeCurrentSession()
        XCTAssertEqual(engine.state, .idle)
    }

    // MARK: - Skip Behavior

    func testSkipAdvancesStateCorrectly() {
        engine.startFocus()
        engine.skip()  // Skip focus → should go to break
        XCTAssertEqual(engine.state, .breakRunning)

        engine.skip()  // Skip break → should go to focus (session 2)
        XCTAssertEqual(engine.state, .focusRunning)
        XCTAssertEqual(engine.sessionNumber, 2)
    }

    func testSkipOnLastSessionGoesToIdle() {
        engine = FocusEngine(focusDuration: 10, breakDuration: 5, sessionsPerCycle: 1)
        engine.startFocus()
        engine.skip()
        XCTAssertEqual(engine.state, .idle)
    }

    func testSkipDoesNothingWhenIdle() {
        engine.skip()
        XCTAssertEqual(engine.state, .idle)
        XCTAssertEqual(engine.completedSessions.count, 0)
    }

    // MARK: - Stop

    func testStopResetsToIdle() {
        engine.startFocus()
        engine.tick()
        engine.stop()
        XCTAssertEqual(engine.state, .idle)
        XCTAssertEqual(engine.timeRemaining, 0)
        XCTAssertEqual(engine.currentNote, "")
    }

    // MARK: - Formatted Time

    func testFormattedTimeRemaining() {
        engine.startFocus()
        XCTAssertEqual(engine.formattedTimeRemaining, "25:00")

        engine.tick()
        XCTAssertEqual(engine.formattedTimeRemaining, "24:59")
    }

    // MARK: - Persistence

    func testEncodeDecodeRoundTrip() throws {
        engine.startFocus(note: "Round trip test")
        engine.completeCurrentSession()

        let data = try engine.encodeSessions()

        let newEngine = FocusEngine()
        try newEngine.loadSessions(from: data)

        XCTAssertEqual(newEngine.completedSessions.count, 1)
        XCTAssertEqual(newEngine.completedSessions[0].note, "Round trip test")
        XCTAssertEqual(newEngine.completedSessions[0].type, .focus)
        XCTAssertTrue(newEngine.completedSessions[0].completed)
    }
}
