import XCTest
@testable import Kye

/// Deterministic scheduler: captures scheduled work so the test fires it manually.
private final class ManualScheduler: DebounceScheduling {
    private final class Token: DebounceToken {
        var cancelled = false
        func cancel() { cancelled = true }
    }

    private var scheduled: [(token: Token, work: () -> Void)] = []

    func schedule(after interval: TimeInterval, _ work: @escaping () -> Void) -> DebounceToken {
        let token = Token()
        scheduled.append((token, work))
        return token
    }

    func fireAll() {
        let live = scheduled.filter { !$0.token.cancelled }
        scheduled.removeAll()
        live.forEach { $0.work() }
    }
}

final class DebouncerTests: XCTestCase {

    func testRapidSignalsCoalesceIntoOneFire() {
        var fireCount = 0
        let scheduler = ManualScheduler()
        let debouncer = Debouncer(interval: 0.3, scheduler: scheduler) { fireCount += 1 }

        debouncer.signal()
        debouncer.signal()
        debouncer.signal()
        scheduler.fireAll()

        XCTAssertEqual(fireCount, 1, "three rapid signals should coalesce into a single fire")
    }

    func testCancelPreventsPendingFire() {
        var fireCount = 0
        let scheduler = ManualScheduler()
        let debouncer = Debouncer(interval: 0.3, scheduler: scheduler) { fireCount += 1 }

        debouncer.signal()
        debouncer.cancel()
        scheduler.fireAll()

        XCTAssertEqual(fireCount, 0, "cancel must drop the pending fire")
    }
}
