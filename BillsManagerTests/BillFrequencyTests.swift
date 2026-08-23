import XCTest
@testable import BillsManager

final class BillFrequencyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: year, month: month, day: day, hour: 9))!
    }

    func testOnceHasNoNextDate() {
        XCTAssertNil(BillFrequency.once.nextDueDate(from: date(year: 2026, month: 1, day: 1), anchorDay: 1))
    }

    func testDailyAddsOneDay() {
        let start = date(year: 2026, month: 1, day: 15)
        let next = BillFrequency.daily.nextDueDate(from: start)
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day], from: next!), DateComponents(year: 2026, month: 1, day: 16))
    }

    func testMonthlyAnchorDoesNotDriftFromJanuary31() {
        // Uses Calendar.current internally; skip if the host calendar is not Gregorian.
        guard Calendar.current.identifier == .gregorian else { return }

        let jan31 = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 31, hour: 9))!
        let feb = BillFrequency.monthly.nextDueDate(from: jan31, anchorDay: 31)!
        XCTAssertEqual(Calendar.current.component(.month, from: feb), 2)
        XCTAssertEqual(Calendar.current.component(.day, from: feb), 28)

        let mar = BillFrequency.monthly.nextDueDate(from: feb, anchorDay: 31)!
        XCTAssertEqual(Calendar.current.component(.month, from: mar), 3)
        XCTAssertEqual(Calendar.current.component(.day, from: mar), 31)
    }
}

final class CurrencyFormatterTests: XCTestCase {
    func testParsePositiveDecimal() {
        let locale = Locale(identifier: "en_US")
        XCTAssertEqual(CurrencyFormatter.parseAmount("12.50", locale: locale), 12.50)
        XCTAssertNil(CurrencyFormatter.parseAmount("0", locale: locale))
        XCTAssertNil(CurrencyFormatter.parseAmount("-1", locale: locale))
        XCTAssertNil(CurrencyFormatter.parseAmount("", locale: locale))
    }

    func testValidLast4() {
        XCTAssertTrue(CurrencyFormatter.isValidLast4("1234"))
        XCTAssertFalse(CurrencyFormatter.isValidLast4("12"))
        XCTAssertFalse(CurrencyFormatter.isValidLast4("12ab"))
    }
}

final class ProFeatureLimitTests: XCTestCase {
    func testFreeCapsMatchStoreCopy() {
        XCTAssertEqual(ProFeature.freeCustomCategoryLimit, 5)
        XCTAssertEqual(ProFeature.freeAccountLimit, 3)
    }
}
