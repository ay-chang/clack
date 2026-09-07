import XCTest
@testable import Clack

final class CounterTests: XCTestCase {
    func testDrainReturnsAndClears() {
        let c = Counter()
        (0..<5).forEach { _ in c.increment() }
        XCTAssertEqual(c.drain(), 5)
        XCTAssertEqual(c.drain(), 0)
    }

    /// The tap thread writes while the main thread drains; no count may be lost.
    func testConcurrentIncrementsAreNotLost() {
        let c = Counter()
        let writers = 4
        let perWriter = 10_000
        let group = DispatchGroup()

        for _ in 0..<writers {
            DispatchQueue.global().async(group: group) {
                for _ in 0..<perWriter { c.increment() }
            }
        }

        var drained = 0
        let deadline = Date().addingTimeInterval(10)
        while group.wait(timeout: .now() + 0.001) == .timedOut, Date() < deadline {
            drained += c.drain()
        }
        group.wait()
        drained += c.drain()

        XCTAssertEqual(drained, writers * perWriter)
    }
}

final class StoreTests: XCTestCase {
    private var url: URL!
    private var store: Store!

    override func setUp() {
        super.setUp()
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("clack-test-\(UUID().uuidString).json")
        store = Store(fileURL: url)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: url)
        super.tearDown()
    }

    private func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Date())!
    }

    func testAddAccumulatesPerDay() {
        store.add(10)
        store.add(5)
        XCTAssertEqual(store.today, 15)
        XCTAssertEqual(store.allTime, 15)
    }

    func testAddIgnoresNonPositive() {
        store.add(0)
        store.add(-3)
        XCTAssertEqual(store.allTime, 0)
    }

    func testLastSevenDaysIsZeroFilledAndOrdered() {
        store.add(7, on: day(-3))
        let week = store.lastSevenDays()
        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(week.map(\.count).reduce(0, +), 7)
        XCTAssertTrue(zip(week, week.dropFirst()).allSatisfy { $0.date < $1.date })
        XCTAssertTrue(Calendar.current.isDateInToday(week.last!.date))
    }

    func testWeekTotalExcludesOlderDays() {
        store.add(100, on: day(-2))
        store.add(999, on: day(-30))
        XCTAssertEqual(store.weekTotal(), 100)
        XCTAssertEqual(store.allTime, 1099)
    }

    func testBestDay() {
        store.add(50, on: day(-5))
        store.add(120, on: day(-2))
        store.add(30)
        XCTAssertEqual(store.bestDay?.count, 120)
    }

    func testStreakCountsConsecutiveDaysEndingToday() {
        store.add(1, on: day(-2))
        store.add(1, on: day(-1))
        store.add(1)
        XCTAssertEqual(store.streak, 3)
    }

    func testStreakBreaksOnGap() {
        store.add(1, on: day(-4))
        store.add(1, on: day(-1))
        store.add(1)
        XCTAssertEqual(store.streak, 2)
    }

    func testStreakIsZeroWhenIdleForTwoDays() {
        store.add(1, on: day(-3))
        XCTAssertEqual(store.streak, 0)
    }

    func testRoundTripsThroughDisk() {
        store.add(42, on: day(-1))
        store.add(8)
        store.flushSynchronously()

        let reloaded = Store(fileURL: url)
        XCTAssertEqual(reloaded.allTime, 50)
        XCTAssertEqual(reloaded.today, 8)
    }

    func testResetClearsDisk() {
        store.add(42)
        store.flushSynchronously()
        store.reset()
        XCTAssertEqual(Store(fileURL: url).allTime, 0)
    }
}

final class FormattingTests: XCTestCase {
    func testCompactStaysNarrow() {
        XCTAssertEqual(Fmt.compact(0), "0")
        XCTAssertEqual(Fmt.compact(999), "999")
        XCTAssertEqual(Fmt.compact(1_000), "1k")
        XCTAssertEqual(Fmt.compact(1_240), "1.2k")
        XCTAssertEqual(Fmt.compact(12_400), "12k")
        XCTAssertEqual(Fmt.compact(999_999), "999k")
        XCTAssertEqual(Fmt.compact(1_240_000), "1.2M")
        XCTAssertEqual(Fmt.compact(12_400_000), "12M")

        // Four characters is the widest the menu bar item should ever get.
        for n in [0, 1, 999, 1_000, 45_678, 987_654, 5_432_100, 99_000_000] {
            XCTAssertLessThanOrEqual(Fmt.compact(n).count, 4, "\(n)")
        }
    }
}
