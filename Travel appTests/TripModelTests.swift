import XCTest
@testable import Travel_app

final class TripModelTests: XCTestCase {

    func testTripTotalDays() {
        let trip = makeTrip(startOffset: 0, endOffset: 7)
        XCTAssertEqual(trip.totalDays, 7)
    }

    func testTripTotalDaysZero() {
        let trip = makeTrip(startOffset: 0, endOffset: 0)
        XCTAssertEqual(trip.totalDays, 0)
    }

    func testTripIsUpcoming() {
        let trip = makeTrip(startOffset: 5, endOffset: 10)
        XCTAssertTrue(trip.isUpcoming)
        XCTAssertFalse(trip.isActive)
        XCTAssertFalse(trip.isPast)
    }

    func testTripIsPast() {
        let trip = makeTrip(startOffset: -10, endOffset: -3)
        XCTAssertTrue(trip.isPast)
        XCTAssertFalse(trip.isActive)
        XCTAssertFalse(trip.isUpcoming)
    }

    func testTripTotalSpent() {
        let trip = makeTrip(startOffset: 0, endOffset: 7)
        trip.expenses = [
            Expense(title: "Food", amount: 500, category: .food, date: Date()),
            Expense(title: "Hotel", amount: 3000, category: .accommodation, date: Date())
        ]
        XCTAssertEqual(trip.totalSpent, 3500, accuracy: 0.01)
    }

    func testTripRemainingBudget() {
        let trip = makeTrip(startOffset: 0, endOffset: 7)
        trip.expenses = [
            Expense(title: "Food", amount: 2000, category: .food, date: Date())
        ]
        XCTAssertEqual(trip.remainingBudget, 98000, accuracy: 0.01)
    }

    func testTripBudgetUsedPercent() {
        let trip = makeTrip(startOffset: 0, endOffset: 7)
        trip.expenses = [
            Expense(title: "Big", amount: 50000, category: .other, date: Date())
        ]
        XCTAssertEqual(trip.budgetUsedPercent, 0.5, accuracy: 0.01)
    }

    func testTripBudgetUsedPercentZeroBudget() {
        let cal = Calendar.current
        let trip = Trip(
            name: "Test", destination: "Test",
            startDate: Date(), endDate: cal.date(byAdding: .day, value: 3, to: Date())!,
            budget: 0, currency: "RUB", coverSystemImage: "airplane"
        )
        XCTAssertEqual(trip.budgetUsedPercent, 0)
    }

    func testTripPhasePreTrip() {
        let trip = makeTrip(startOffset: 5, endOffset: 10)
        XCTAssertEqual(trip.phase, .preTrip)
    }

    func testTripPhasePostTrip() {
        let trip = makeTrip(startOffset: -10, endOffset: -3)
        XCTAssertEqual(trip.phase, .postTrip)
    }

    func testTripProgress() {
        let trip = makeTrip(startOffset: 0, endOffset: 10)
        XCTAssertTrue(trip.progress >= 0)
        XCTAssertTrue(trip.progress <= 1)
    }

    func testTripCountdownToStartNilWhenActive() {
        let trip = makeTrip(startOffset: -1, endOffset: 5)
        XCTAssertNil(trip.countdownToStart)
    }

    func testTripCountdownToStartExistsWhenUpcoming() {
        let trip = makeTrip(startOffset: 5, endOffset: 10)
        XCTAssertNotNil(trip.countdownToStart)
    }

    func testExpenseByCategoryEmpty() {
        let trip = makeTrip(startOffset: 0, endOffset: 7)
        XCTAssertTrue(trip.expensesByCategory.isEmpty)
    }

    func testExpenseByCategorySorted() {
        let trip = makeTrip(startOffset: 0, endOffset: 7)
        trip.expenses = [
            Expense(title: "Small", amount: 100, category: .food, date: Date()),
            Expense(title: "Big", amount: 5000, category: .accommodation, date: Date())
        ]
        let byCategory = trip.expensesByCategory
        XCTAssertEqual(byCategory.first?.category, .accommodation)
    }

    func testTripDayIsToday() {
        let day = TripDay(date: Date(), title: "Today", cityName: "Moscow")
        XCTAssertTrue(day.isToday)
    }

    func testTripDayIsFuture() {
        let future = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        let day = TripDay(date: future, title: "Future", cityName: "Paris")
        XCTAssertTrue(day.isFuture)
        XCTAssertFalse(day.isToday)
    }

    func testTripEventDuration() {
        let start = Date()
        let end = start.addingTimeInterval(3600) // 1 hour
        let event = TripEvent(title: "Test", subtitle: "", category: .tour, startTime: start, endTime: end)
        XCTAssertEqual(event.duration, 3600, accuracy: 1)
    }

    func testTripEventFormattedDuration() {
        let start = Date()
        let end = start.addingTimeInterval(5400) // 1.5 hours
        let event = TripEvent(title: "Test", subtitle: "", category: .tour, startTime: start, endTime: end)
        XCTAssertEqual(event.formattedDuration, "1\u{0447} 30\u{043C}\u{0438}\u{043D}")
    }

    func testPlaceCoordinate() {
        let place = Place(name: "Test", nameLocal: "", category: .culture, address: "", latitude: 55.75, longitude: 37.62)
        XCTAssertEqual(place.coordinate.latitude, 55.75, accuracy: 0.001)
        XCTAssertEqual(place.coordinate.longitude, 37.62, accuracy: 0.001)
    }

    // MARK: - Helpers

    private func makeTrip(startOffset: Int, endOffset: Int) -> Trip {
        let cal = Calendar.current
        return Trip(
            name: "Test Trip", destination: "Test",
            startDate: cal.date(byAdding: .day, value: startOffset, to: Date())!,
            endDate: cal.date(byAdding: .day, value: endOffset, to: Date())!,
            budget: 100000, currency: "RUB", coverSystemImage: "airplane"
        )
    }
}
