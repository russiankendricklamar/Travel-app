import Foundation
import CoreLocation
import Observation

@Observable
final class TripStore {

    // MARK: - State

    var trip: Trip
    var days: [TripDay]
    var expenses: [Expense]
    var journalEntries: [JournalEntry]

    // MARK: - Trip Phase

    var phase: TripPhase {
        if trip.isUpcoming { return .preTrip }
        if trip.isActive { return .active }
        return .postTrip
    }

    // MARK: - Computed Properties

    var totalSpent: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }

    var remainingBudget: Double {
        trip.budget - totalSpent
    }

    var budgetUsedPercent: Double {
        guard trip.budget > 0 else { return 0 }
        return totalSpent / trip.budget
    }

    var allPlaces: [Place] {
        days.flatMap(\.places)
    }

    var placesVisitedCount: Int {
        allPlaces.filter(\.isVisited).count
    }

    var totalPlacesCount: Int {
        allPlaces.count
    }

    var expensesByCategory: [(category: ExpenseCategory, total: Double)] {
        ExpenseCategory.allCases.compactMap { category in
            let total = expenses
                .filter { $0.category == category }
                .reduce(0) { $0 + $1.amount }
            guard total > 0 else { return nil }
            return (category: category, total: total)
        }
        .sorted { $0.total > $1.total }
    }

    var recentExpenses: [Expense] {
        Array(expenses.sorted { $0.date > $1.date }.prefix(5))
    }

    var todayDay: TripDay? {
        days.first { $0.isToday }
    }

    /// Days sorted by date
    var sortedDays: [TripDay] {
        days.sorted { $0.date < $1.date }
    }

    /// Current or next upcoming day
    var activeDay: TripDay? {
        if let today = todayDay { return today }
        return days
            .filter { $0.isFuture }
            .sorted { $0.date < $1.date }
            .first
    }

    // MARK: - Init

    init() {
        let sampleData = SampleData.build()
        self.trip = sampleData.trip
        self.days = sampleData.days
        self.expenses = sampleData.expenses
        self.journalEntries = sampleData.journalEntries

        autoCompletePastDays()
    }

    // MARK: - Smart Time Awareness

    /// Auto-mark all places as visited for days that have already passed
    func autoCompletePastDays() {
        for dayIndex in days.indices {
            guard days[dayIndex].isPast else { continue }
            for placeIndex in days[dayIndex].places.indices {
                if !days[dayIndex].places[placeIndex].isVisited {
                    days[dayIndex].places[placeIndex].isVisited = true
                }
            }
        }
    }

    // MARK: - Actions

    func togglePlaceVisited(dayId: UUID, placeId: UUID) {
        guard let dayIndex = days.firstIndex(where: { $0.id == dayId }),
              let placeIndex = days[dayIndex].places.firstIndex(where: { $0.id == placeId }) else {
            return
        }
        days[dayIndex].places[placeIndex] = {
            var place = days[dayIndex].places[placeIndex]
            place.isVisited.toggle()
            return place
        }()
    }

    func addExpense(_ expense: Expense) {
        expenses.append(expense)
    }

    func deleteExpense(at offsets: IndexSet) {
        let sorted = expenses.sorted { $0.date > $1.date }
        let idsToRemove = offsets.map { sorted[$0].id }
        expenses.removeAll { idsToRemove.contains($0.id) }
    }

    func addJournalEntry(_ entry: JournalEntry) {
        journalEntries.append(entry)
    }

    func deleteJournalEntry(at offsets: IndexSet) {
        let sorted = journalEntries.sorted { $0.date > $1.date }
        let idsToRemove = offsets.map { sorted[$0].id }
        journalEntries.removeAll { idsToRemove.contains($0.id) }
    }

    func ratePlace(dayId: UUID, placeId: UUID, rating: Int) {
        guard let dayIndex = days.firstIndex(where: { $0.id == dayId }),
              let placeIndex = days[dayIndex].places.firstIndex(where: { $0.id == placeId }) else {
            return
        }
        days[dayIndex].places[placeIndex] = {
            var place = days[dayIndex].places[placeIndex]
            place.rating = rating
            return place
        }()
    }
}
