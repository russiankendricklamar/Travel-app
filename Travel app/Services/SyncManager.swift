import Foundation
import SwiftData
import Supabase

@MainActor
@Observable
final class SyncManager {
    static let shared = SyncManager()

    enum SyncState: Equatable {
        case idle
        case syncing
        case error(String)
    }

    var state: SyncState = .idle

    var lastSyncDate: Date? {
        get {
            guard let userID = SupabaseManager.shared.currentUserID else { return nil }
            let key = "lastSyncDate_\(userID.uuidString)"
            let ts = UserDefaults.standard.double(forKey: key)
            return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
        }
        set {
            guard let userID = SupabaseManager.shared.currentUserID else { return }
            let key = "lastSyncDate_\(userID.uuidString)"
            if let date = newValue {
                UserDefaults.standard.set(date.timeIntervalSince1970, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }

    private var lastSyncAttempt: Date = .distantPast
    private let minimumInterval: TimeInterval = 60 // debounce 60s
    @ObservationIgnored
    private lazy var engine = SyncEngine(client: SupabaseManager.shared.client)

    private init() {}

    // MARK: - Public

    /// Sync if enough time has passed and we're online + signed in
    func syncIfNeeded() async {
        guard canSync else { return }
        guard Date().timeIntervalSince(lastSyncAttempt) >= minimumInterval else { return }
        await performSync()
    }

    /// Force sync (manual button)
    func forceSync() async {
        guard canSync else {
            state = .error("Нет подключения или не авторизован")
            return
        }
        await performSync()
    }

    private var canSync: Bool {
        SupabaseManager.shared.currentUserID != nil && OfflineCacheManager.shared.isOnline
    }

    // MARK: - Core Sync

    private func performSync() async {
        guard let userID = SupabaseManager.shared.currentUserID else { return }
        state = .syncing
        lastSyncAttempt = Date()

        let syncStart = Date()
        let since = lastSyncDate ?? Date.distantPast

        do {
            // Get model context from the shared container
            guard let container = await getModelContainer() else {
                state = .error("Нет доступа к данным")
                return
            }
            let context = ModelContext(container)

            // PUSH (local → remote), then PULL (remote → local)
            // Order: parents first
            try await pushTrips(context: context, userID: userID, since: since)
            try await pushTripDays(context: context, userID: userID, since: since)
            try await pushPlaces(context: context, userID: userID, since: since)
            try await pushTripEvents(context: context, userID: userID, since: since)
            try await pushExpenses(context: context, userID: userID, since: since)
            try await pushTickets(context: context, userID: userID, since: since)
            try await pushPackingItems(context: context, userID: userID, since: since)
            try await pushJournalEntries(context: context, userID: userID, since: since)
            try await pushRoutePoints(context: context, userID: userID, since: since)
            try await pushBucketListItems(context: context, userID: userID, since: since)

            // PULL
            try await pullTrips(context: context, userID: userID, since: since)
            try await pullTripDays(context: context, userID: userID, since: since)
            try await pullPlaces(context: context, userID: userID, since: since)
            try await pullTripEvents(context: context, userID: userID, since: since)
            try await pullExpenses(context: context, userID: userID, since: since)
            try await pullTickets(context: context, userID: userID, since: since)
            try await pullPackingItems(context: context, userID: userID, since: since)
            try await pullJournalEntries(context: context, userID: userID, since: since)
            try await pullRoutePoints(context: context, userID: userID, since: since)
            try await pullBucketListItems(context: context, userID: userID, since: since)

            try context.save()
            lastSyncDate = syncStart
            state = .idle
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    @MainActor
    private func getModelContainer() -> ModelContainer? {
        // Access via the shared model container
        try? ModelContainer(for: Trip.self, JournalEntry.self, BucketListItem.self, PackingItem.self, OfflineMapCache.self)
    }

    // MARK: - Push Helpers

    private func pushTrips(context: ModelContext, userID: UUID, since: Date) async throws {
        let descriptor = FetchDescriptor<Trip>(predicate: #Predicate { $0.updatedAt > since })
        let trips = try context.fetch(descriptor)
        guard !trips.isEmpty else { return }

        let dtos = trips.map { trip in
            TripDTO(
                id: trip.id,
                userId: userID,
                name: trip.name,
                destination: trip.destination,
                startDate: SyncDateFormatter.dateString(from: trip.startDate),
                endDate: SyncDateFormatter.dateString(from: trip.endDate),
                budget: trip.budget,
                currency: trip.currency,
                coverSystemImage: trip.coverSystemImage,
                flightDate: trip.flightDate.map { SyncDateFormatter.string(from: $0) },
                flightNumber: trip.flightNumber,
                updatedAt: SyncDateFormatter.string(from: trip.updatedAt),
                isDeleted: trip.isDeleted
            )
        }
        try await engine.push(table: "trips", records: dtos)
    }

    private func pushTripDays(context: ModelContext, userID: UUID, since: Date) async throws {
        let descriptor = FetchDescriptor<TripDay>(predicate: #Predicate { $0.updatedAt > since })
        let days = try context.fetch(descriptor)
        guard !days.isEmpty else { return }

        let dtos = days.compactMap { day -> TripDayDTO? in
            guard let tripId = day.trip?.id else { return nil }
            return TripDayDTO(
                id: day.id,
                userId: userID,
                tripId: tripId,
                date: SyncDateFormatter.dateString(from: day.date),
                title: day.title,
                cityName: day.cityName,
                notes: day.notes,
                sortOrder: day.sortOrder,
                updatedAt: SyncDateFormatter.string(from: day.updatedAt),
                isDeleted: day.isDeleted
            )
        }
        try await engine.push(table: "trip_days", records: dtos)
    }

    private func pushPlaces(context: ModelContext, userID: UUID, since: Date) async throws {
        let descriptor = FetchDescriptor<Place>(predicate: #Predicate { $0.updatedAt > since })
        let places = try context.fetch(descriptor)
        guard !places.isEmpty else { return }

        let dtos = places.compactMap { place -> PlaceDTO? in
            guard let dayId = place.day?.id else { return nil }
            return PlaceDTO(
                id: place.id,
                userId: userID,
                dayId: dayId,
                name: place.name,
                nameLocal: place.nameLocal,
                category: place.category.rawValue,
                address: place.address,
                latitude: place.latitude,
                longitude: place.longitude,
                isVisited: place.isVisited,
                rating: place.rating ?? 0,
                notes: place.notes,
                timeToSpend: place.timeToSpend,
                sortOrder: place.sortOrder,
                updatedAt: SyncDateFormatter.string(from: place.updatedAt),
                isDeleted: place.isDeleted
            )
        }
        try await engine.push(table: "places", records: dtos)
    }

    private func pushTripEvents(context: ModelContext, userID: UUID, since: Date) async throws {
        let descriptor = FetchDescriptor<TripEvent>(predicate: #Predicate { $0.updatedAt > since })
        let events = try context.fetch(descriptor)
        guard !events.isEmpty else { return }

        let dtos = events.compactMap { event -> TripEventDTO? in
            guard let dayId = event.day?.id else { return nil }
            return TripEventDTO(
                id: event.id,
                userId: userID,
                dayId: dayId,
                title: event.title,
                subtitle: event.subtitle,
                category: event.category.rawValue,
                startTime: SyncDateFormatter.string(from: event.startTime),
                endTime: SyncDateFormatter.string(from: event.endTime),
                notes: event.notes,
                sortOrder: event.sortOrder,
                latitude: event.latitude ?? 0,
                longitude: event.longitude ?? 0,
                startLatitude: event.startLatitude ?? 0,
                startLongitude: event.startLongitude ?? 0,
                endLatitude: event.endLatitude ?? 0,
                endLongitude: event.endLongitude ?? 0,
                updatedAt: SyncDateFormatter.string(from: event.updatedAt),
                isDeleted: event.isDeleted
            )
        }
        try await engine.push(table: "trip_events", records: dtos)
    }

    private func pushExpenses(context: ModelContext, userID: UUID, since: Date) async throws {
        let descriptor = FetchDescriptor<Expense>(predicate: #Predicate { $0.updatedAt > since })
        let expenses = try context.fetch(descriptor)
        guard !expenses.isEmpty else { return }

        let dtos = expenses.compactMap { expense -> ExpenseDTO? in
            guard let tripId = expense.trip?.id else { return nil }
            return ExpenseDTO(
                id: expense.id,
                userId: userID,
                tripId: tripId,
                title: expense.title,
                amount: expense.amount,
                category: expense.category.rawValue,
                date: SyncDateFormatter.dateString(from: expense.date),
                notes: expense.notes,
                updatedAt: SyncDateFormatter.string(from: expense.updatedAt),
                isDeleted: expense.isDeleted
            )
        }
        try await engine.push(table: "expenses", records: dtos)
    }

    private func pushTickets(context: ModelContext, userID: UUID, since: Date) async throws {
        let descriptor = FetchDescriptor<Ticket>(predicate: #Predicate { $0.updatedAt > since })
        let tickets = try context.fetch(descriptor)
        guard !tickets.isEmpty else { return }

        let dtos = tickets.compactMap { ticket -> TicketDTO? in
            guard let tripId = ticket.trip?.id else { return nil }
            return TicketDTO(
                id: ticket.id,
                userId: userID,
                tripId: tripId,
                dayId: ticket.day?.id,
                title: ticket.title,
                venue: ticket.venue,
                categoryRaw: ticket.categoryRaw,
                barcodeTypeRaw: ticket.barcodeTypeRaw,
                barcodeContent: ticket.barcodeContent,
                eventDate: SyncDateFormatter.string(from: ticket.eventDate),
                expirationDate: ticket.expirationDate.map { SyncDateFormatter.string(from: $0) },
                seatInfo: ticket.seatInfo,
                notes: ticket.notes,
                updatedAt: SyncDateFormatter.string(from: ticket.updatedAt),
                isDeleted: ticket.isDeleted
            )
        }
        try await engine.push(table: "tickets", records: dtos)
    }

    private func pushPackingItems(context: ModelContext, userID: UUID, since: Date) async throws {
        let descriptor = FetchDescriptor<PackingItem>(predicate: #Predicate { $0.updatedAt > since })
        let items = try context.fetch(descriptor)
        guard !items.isEmpty else { return }

        let dtos = items.compactMap { item -> PackingItemDTO? in
            guard let tripId = item.trip?.id else { return nil }
            return PackingItemDTO(
                id: item.id,
                userId: userID,
                tripId: tripId,
                name: item.name,
                category: item.category,
                isPacked: item.isPacked,
                quantity: item.quantity,
                isAiSuggested: item.isAISuggested,
                sortOrder: item.sortOrder,
                updatedAt: SyncDateFormatter.string(from: item.updatedAt),
                isDeleted: item.isDeleted
            )
        }
        try await engine.push(table: "packing_items", records: dtos)
    }

    private func pushJournalEntries(context: ModelContext, userID: UUID, since: Date) async throws {
        let descriptor = FetchDescriptor<JournalEntry>(predicate: #Predicate { $0.updatedAt > since })
        let entries = try context.fetch(descriptor)
        guard !entries.isEmpty else { return }

        let dtos = entries.compactMap { entry -> JournalEntryDTO? in
            guard let dayId = entry.day?.id else { return nil }
            return JournalEntryDTO(
                id: entry.id,
                userId: userID,
                dayId: dayId,
                placeId: entry.place?.id,
                text: entry.text,
                mood: entry.mood,
                timestamp: SyncDateFormatter.string(from: entry.timestamp),
                isStandalone: entry.isStandalone,
                latitude: entry.latitude ?? 0,
                longitude: entry.longitude ?? 0,
                updatedAt: SyncDateFormatter.string(from: entry.updatedAt),
                isDeleted: entry.isDeleted
            )
        }
        try await engine.push(table: "journal_entries", records: dtos)
    }

    private func pushRoutePoints(context: ModelContext, userID: UUID, since: Date) async throws {
        let descriptor = FetchDescriptor<RoutePoint>(predicate: #Predicate { $0.updatedAt > since })
        let points = try context.fetch(descriptor)
        guard !points.isEmpty else { return }

        let dtos = points.compactMap { point -> RoutePointDTO? in
            guard let dayId = point.day?.id else { return nil }
            return RoutePointDTO(
                id: point.id,
                userId: userID,
                dayId: dayId,
                latitude: point.latitude,
                longitude: point.longitude,
                timestamp: SyncDateFormatter.string(from: point.timestamp),
                updatedAt: SyncDateFormatter.string(from: point.updatedAt),
                isDeleted: point.isDeleted
            )
        }
        try await engine.push(table: "route_points", records: dtos)
    }

    private func pushBucketListItems(context: ModelContext, userID: UUID, since: Date) async throws {
        let descriptor = FetchDescriptor<BucketListItem>(predicate: #Predicate { $0.updatedAt > since })
        let items = try context.fetch(descriptor)
        guard !items.isEmpty else { return }

        let dtos = items.map { item in
            BucketListItemDTO(
                id: item.id,
                userId: userID,
                name: item.name,
                destination: item.destination,
                category: item.category,
                notes: item.notes,
                latitude: item.latitude ?? 0,
                longitude: item.longitude ?? 0,
                dateAdded: SyncDateFormatter.string(from: item.dateAdded),
                isConverted: item.isConverted,
                photoStoragePath: item.photoStoragePath,
                updatedAt: SyncDateFormatter.string(from: item.updatedAt),
                isDeleted: item.isDeleted
            )
        }
        try await engine.push(table: "bucket_list_items", records: dtos)
    }

    // MARK: - Pull Helpers

    private func pullTrips(context: ModelContext, userID: UUID, since: Date) async throws {
        let remoteDtos: [TripDTO] = try await engine.pull(table: "trips", since: since, userID: userID)
        let descriptor = FetchDescriptor<Trip>()
        let localTrips = try context.fetch(descriptor)
        let localMap = Dictionary(uniqueKeysWithValues: localTrips.map { ($0.id, $0) })

        for dto in remoteDtos {
            let remoteUpdatedAt = SyncDateFormatter.date(from: dto.updatedAt) ?? Date.distantPast

            if let local = localMap[dto.id] {
                // Conflict: remote wins only if newer
                guard remoteUpdatedAt > local.updatedAt else { continue }
                if dto.isDeleted {
                    context.delete(local)
                } else {
                    local.name = dto.name
                    local.destination = dto.destination
                    local.startDate = SyncDateFormatter.dateFromDateString(dto.startDate ?? "") ?? local.startDate
                    local.endDate = SyncDateFormatter.dateFromDateString(dto.endDate ?? "") ?? local.endDate
                    local.budget = dto.budget
                    local.currency = dto.currency
                    local.coverSystemImage = dto.coverSystemImage ?? local.coverSystemImage
                    local.flightDate = dto.flightDate.flatMap { SyncDateFormatter.date(from: $0) }
                    local.flightNumber = dto.flightNumber
                    local.updatedAt = remoteUpdatedAt
                    local.isDeleted = dto.isDeleted
                }
            } else if !dto.isDeleted {
                let trip = Trip(
                    id: dto.id,
                    name: dto.name,
                    destination: dto.destination,
                    startDate: SyncDateFormatter.dateFromDateString(dto.startDate ?? "") ?? Date(),
                    endDate: SyncDateFormatter.dateFromDateString(dto.endDate ?? "") ?? Date(),
                    budget: dto.budget,
                    currency: dto.currency,
                    coverSystemImage: dto.coverSystemImage ?? "airplane",
                    flightDate: dto.flightDate.flatMap { SyncDateFormatter.date(from: $0) },
                    flightNumber: dto.flightNumber
                )
                trip.updatedAt = remoteUpdatedAt
                context.insert(trip)
            }
        }
    }

    private func pullTripDays(context: ModelContext, userID: UUID, since: Date) async throws {
        let remoteDtos: [TripDayDTO] = try await engine.pull(table: "trip_days", since: since, userID: userID)
        let descriptor = FetchDescriptor<TripDay>()
        let localDays = try context.fetch(descriptor)
        let localMap = Dictionary(uniqueKeysWithValues: localDays.map { ($0.id, $0) })

        let tripDescriptor = FetchDescriptor<Trip>()
        let trips = try context.fetch(tripDescriptor)
        let tripMap = Dictionary(uniqueKeysWithValues: trips.map { ($0.id, $0) })

        for dto in remoteDtos {
            let remoteUpdatedAt = SyncDateFormatter.date(from: dto.updatedAt) ?? Date.distantPast

            if let local = localMap[dto.id] {
                guard remoteUpdatedAt > local.updatedAt else { continue }
                if dto.isDeleted {
                    context.delete(local)
                } else {
                    local.date = SyncDateFormatter.dateFromDateString(dto.date) ?? local.date
                    local.title = dto.title
                    local.cityName = dto.cityName
                    local.notes = dto.notes
                    local.sortOrder = dto.sortOrder
                    local.updatedAt = remoteUpdatedAt
                    local.isDeleted = dto.isDeleted
                    if local.trip?.id != dto.tripId {
                        local.trip = tripMap[dto.tripId]
                    }
                }
            } else if !dto.isDeleted {
                let day = TripDay(
                    id: dto.id,
                    date: SyncDateFormatter.dateFromDateString(dto.date) ?? Date(),
                    title: dto.title,
                    cityName: dto.cityName,
                    notes: dto.notes,
                    sortOrder: dto.sortOrder
                )
                day.updatedAt = remoteUpdatedAt
                day.trip = tripMap[dto.tripId]
                context.insert(day)
            }
        }
    }

    private func pullPlaces(context: ModelContext, userID: UUID, since: Date) async throws {
        let remoteDtos: [PlaceDTO] = try await engine.pull(table: "places", since: since, userID: userID)
        let descriptor = FetchDescriptor<Place>()
        let localPlaces = try context.fetch(descriptor)
        let localMap = Dictionary(uniqueKeysWithValues: localPlaces.map { ($0.id, $0) })

        let dayDescriptor = FetchDescriptor<TripDay>()
        let days = try context.fetch(dayDescriptor)
        let dayMap = Dictionary(uniqueKeysWithValues: days.map { ($0.id, $0) })

        for dto in remoteDtos {
            let remoteUpdatedAt = SyncDateFormatter.date(from: dto.updatedAt) ?? Date.distantPast

            if let local = localMap[dto.id] {
                guard remoteUpdatedAt > local.updatedAt else { continue }
                if dto.isDeleted {
                    context.delete(local)
                } else {
                    local.name = dto.name
                    local.nameLocal = dto.nameLocal
                    local.category = PlaceCategory(rawValue: dto.category) ?? .culture
                    local.address = dto.address
                    local.latitude = dto.latitude
                    local.longitude = dto.longitude
                    local.isVisited = dto.isVisited
                    local.rating = dto.rating
                    local.notes = dto.notes
                    local.timeToSpend = dto.timeToSpend
                    local.sortOrder = dto.sortOrder
                    local.updatedAt = remoteUpdatedAt
                    local.isDeleted = dto.isDeleted
                    if local.day?.id != dto.dayId {
                        local.day = dayMap[dto.dayId]
                    }
                }
            } else if !dto.isDeleted {
                let place = Place(
                    id: dto.id,
                    name: dto.name,
                    nameLocal: dto.nameLocal,
                    category: PlaceCategory(rawValue: dto.category) ?? .culture,
                    address: dto.address,
                    latitude: dto.latitude,
                    longitude: dto.longitude,
                    isVisited: dto.isVisited,
                    rating: dto.rating,
                    notes: dto.notes,
                    timeToSpend: dto.timeToSpend
                )
                place.sortOrder = dto.sortOrder
                place.updatedAt = remoteUpdatedAt
                place.day = dayMap[dto.dayId]
                context.insert(place)
            }
        }
    }

    private func pullTripEvents(context: ModelContext, userID: UUID, since: Date) async throws {
        let remoteDtos: [TripEventDTO] = try await engine.pull(table: "trip_events", since: since, userID: userID)
        let descriptor = FetchDescriptor<TripEvent>()
        let localEvents = try context.fetch(descriptor)
        let localMap = Dictionary(uniqueKeysWithValues: localEvents.map { ($0.id, $0) })

        let dayDescriptor = FetchDescriptor<TripDay>()
        let days = try context.fetch(dayDescriptor)
        let dayMap = Dictionary(uniqueKeysWithValues: days.map { ($0.id, $0) })

        for dto in remoteDtos {
            let remoteUpdatedAt = SyncDateFormatter.date(from: dto.updatedAt) ?? Date.distantPast

            if let local = localMap[dto.id] {
                guard remoteUpdatedAt > local.updatedAt else { continue }
                if dto.isDeleted {
                    context.delete(local)
                } else {
                    local.title = dto.title
                    local.subtitle = dto.subtitle
                    local.category = EventCategory(rawValue: dto.category) ?? .other
                    local.startTime = dto.startTime.flatMap { SyncDateFormatter.date(from: $0) } ?? local.startTime
                    local.endTime = dto.endTime.flatMap { SyncDateFormatter.date(from: $0) } ?? local.endTime
                    local.notes = dto.notes
                    local.sortOrder = dto.sortOrder
                    local.latitude = dto.latitude == 0 ? nil : dto.latitude
                    local.longitude = dto.longitude == 0 ? nil : dto.longitude
                    local.startLatitude = dto.startLatitude == 0 ? nil : dto.startLatitude
                    local.startLongitude = dto.startLongitude == 0 ? nil : dto.startLongitude
                    local.endLatitude = dto.endLatitude == 0 ? nil : dto.endLatitude
                    local.endLongitude = dto.endLongitude == 0 ? nil : dto.endLongitude
                    local.updatedAt = remoteUpdatedAt
                    local.isDeleted = dto.isDeleted
                    if local.day?.id != dto.dayId {
                        local.day = dayMap[dto.dayId]
                    }
                }
            } else if !dto.isDeleted {
                let event = TripEvent(
                    id: dto.id,
                    title: dto.title,
                    subtitle: dto.subtitle,
                    category: EventCategory(rawValue: dto.category) ?? .other,
                    startTime: dto.startTime.flatMap { SyncDateFormatter.date(from: $0) } ?? Date(),
                    endTime: dto.endTime.flatMap { SyncDateFormatter.date(from: $0) } ?? Date(),
                    notes: dto.notes,
                    latitude: dto.latitude == 0 ? nil : dto.latitude,
                    longitude: dto.longitude == 0 ? nil : dto.longitude,
                    startLatitude: dto.startLatitude == 0 ? nil : dto.startLatitude,
                    startLongitude: dto.startLongitude == 0 ? nil : dto.startLongitude,
                    endLatitude: dto.endLatitude == 0 ? nil : dto.endLatitude,
                    endLongitude: dto.endLongitude == 0 ? nil : dto.endLongitude
                )
                event.sortOrder = dto.sortOrder
                event.updatedAt = remoteUpdatedAt
                event.day = dayMap[dto.dayId]
                context.insert(event)
            }
        }
    }

    private func pullExpenses(context: ModelContext, userID: UUID, since: Date) async throws {
        let remoteDtos: [ExpenseDTO] = try await engine.pull(table: "expenses", since: since, userID: userID)
        let descriptor = FetchDescriptor<Expense>()
        let localExpenses = try context.fetch(descriptor)
        let localMap = Dictionary(uniqueKeysWithValues: localExpenses.map { ($0.id, $0) })

        let tripDescriptor = FetchDescriptor<Trip>()
        let trips = try context.fetch(tripDescriptor)
        let tripMap = Dictionary(uniqueKeysWithValues: trips.map { ($0.id, $0) })

        for dto in remoteDtos {
            let remoteUpdatedAt = SyncDateFormatter.date(from: dto.updatedAt) ?? Date.distantPast

            if let local = localMap[dto.id] {
                guard remoteUpdatedAt > local.updatedAt else { continue }
                if dto.isDeleted {
                    context.delete(local)
                } else {
                    local.title = dto.title
                    local.amount = dto.amount
                    local.category = ExpenseCategory(rawValue: dto.category) ?? .other
                    local.date = SyncDateFormatter.dateFromDateString(dto.date ?? "") ?? local.date
                    local.notes = dto.notes
                    local.updatedAt = remoteUpdatedAt
                    local.isDeleted = dto.isDeleted
                    if local.trip?.id != dto.tripId {
                        local.trip = tripMap[dto.tripId]
                    }
                }
            } else if !dto.isDeleted {
                let expense = Expense(
                    id: dto.id,
                    title: dto.title,
                    amount: dto.amount,
                    category: ExpenseCategory(rawValue: dto.category) ?? .other,
                    date: SyncDateFormatter.dateFromDateString(dto.date ?? "") ?? Date(),
                    notes: dto.notes
                )
                expense.updatedAt = remoteUpdatedAt
                expense.trip = tripMap[dto.tripId]
                context.insert(expense)
            }
        }
    }

    private func pullTickets(context: ModelContext, userID: UUID, since: Date) async throws {
        let remoteDtos: [TicketDTO] = try await engine.pull(table: "tickets", since: since, userID: userID)
        let descriptor = FetchDescriptor<Ticket>()
        let localTickets = try context.fetch(descriptor)
        let localMap = Dictionary(uniqueKeysWithValues: localTickets.map { ($0.id, $0) })

        let tripDescriptor = FetchDescriptor<Trip>()
        let trips = try context.fetch(tripDescriptor)
        let tripMap = Dictionary(uniqueKeysWithValues: trips.map { ($0.id, $0) })

        let dayDescriptor = FetchDescriptor<TripDay>()
        let days = try context.fetch(dayDescriptor)
        let dayMap = Dictionary(uniqueKeysWithValues: days.map { ($0.id, $0) })

        for dto in remoteDtos {
            let remoteUpdatedAt = SyncDateFormatter.date(from: dto.updatedAt) ?? Date.distantPast

            if let local = localMap[dto.id] {
                guard remoteUpdatedAt > local.updatedAt else { continue }
                if dto.isDeleted {
                    context.delete(local)
                } else {
                    local.title = dto.title
                    local.venue = dto.venue
                    local.categoryRaw = dto.categoryRaw
                    local.barcodeTypeRaw = dto.barcodeTypeRaw
                    local.barcodeContent = dto.barcodeContent
                    local.eventDate = dto.eventDate.flatMap { SyncDateFormatter.date(from: $0) } ?? local.eventDate
                    local.expirationDate = dto.expirationDate.flatMap { SyncDateFormatter.date(from: $0) }
                    local.seatInfo = dto.seatInfo
                    local.notes = dto.notes
                    local.updatedAt = remoteUpdatedAt
                    local.isDeleted = dto.isDeleted
                    local.trip = tripMap[dto.tripId]
                    local.day = dto.dayId.flatMap { dayMap[$0] }
                }
            } else if !dto.isDeleted {
                let ticket = Ticket(
                    id: dto.id,
                    title: dto.title,
                    venue: dto.venue,
                    category: TicketCategory(rawValue: dto.categoryRaw) ?? .other,
                    barcodeType: BarcodeType(rawValue: dto.barcodeTypeRaw) ?? .qr,
                    barcodeContent: dto.barcodeContent,
                    eventDate: dto.eventDate.flatMap { SyncDateFormatter.date(from: $0) } ?? Date(),
                    expirationDate: dto.expirationDate.flatMap { SyncDateFormatter.date(from: $0) },
                    seatInfo: dto.seatInfo,
                    notes: dto.notes
                )
                ticket.updatedAt = remoteUpdatedAt
                ticket.trip = tripMap[dto.tripId]
                ticket.day = dto.dayId.flatMap { dayMap[$0] }
                context.insert(ticket)
            }
        }
    }

    private func pullPackingItems(context: ModelContext, userID: UUID, since: Date) async throws {
        let remoteDtos: [PackingItemDTO] = try await engine.pull(table: "packing_items", since: since, userID: userID)
        let descriptor = FetchDescriptor<PackingItem>()
        let localItems = try context.fetch(descriptor)
        let localMap = Dictionary(uniqueKeysWithValues: localItems.map { ($0.id, $0) })

        let tripDescriptor = FetchDescriptor<Trip>()
        let trips = try context.fetch(tripDescriptor)
        let tripMap = Dictionary(uniqueKeysWithValues: trips.map { ($0.id, $0) })

        for dto in remoteDtos {
            let remoteUpdatedAt = SyncDateFormatter.date(from: dto.updatedAt) ?? Date.distantPast

            if let local = localMap[dto.id] {
                guard remoteUpdatedAt > local.updatedAt else { continue }
                if dto.isDeleted {
                    context.delete(local)
                } else {
                    local.name = dto.name
                    local.category = dto.category
                    local.isPacked = dto.isPacked
                    local.quantity = dto.quantity
                    local.isAISuggested = dto.isAiSuggested
                    local.sortOrder = dto.sortOrder
                    local.updatedAt = remoteUpdatedAt
                    local.isDeleted = dto.isDeleted
                    if local.trip?.id != dto.tripId {
                        local.trip = tripMap[dto.tripId]
                    }
                }
            } else if !dto.isDeleted {
                let item = PackingItem(
                    id: dto.id,
                    name: dto.name,
                    category: dto.category,
                    isPacked: dto.isPacked,
                    quantity: dto.quantity,
                    isAISuggested: dto.isAiSuggested,
                    sortOrder: dto.sortOrder
                )
                item.updatedAt = remoteUpdatedAt
                item.trip = tripMap[dto.tripId]
                context.insert(item)
            }
        }
    }

    private func pullJournalEntries(context: ModelContext, userID: UUID, since: Date) async throws {
        let remoteDtos: [JournalEntryDTO] = try await engine.pull(table: "journal_entries", since: since, userID: userID)
        let descriptor = FetchDescriptor<JournalEntry>()
        let localEntries = try context.fetch(descriptor)
        let localMap = Dictionary(uniqueKeysWithValues: localEntries.map { ($0.id, $0) })

        let dayDescriptor = FetchDescriptor<TripDay>()
        let days = try context.fetch(dayDescriptor)
        let dayMap = Dictionary(uniqueKeysWithValues: days.map { ($0.id, $0) })

        let placeDescriptor = FetchDescriptor<Place>()
        let places = try context.fetch(placeDescriptor)
        let placeMap = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0) })

        for dto in remoteDtos {
            let remoteUpdatedAt = SyncDateFormatter.date(from: dto.updatedAt) ?? Date.distantPast

            if let local = localMap[dto.id] {
                guard remoteUpdatedAt > local.updatedAt else { continue }
                if dto.isDeleted {
                    context.delete(local)
                } else {
                    local.text = dto.text
                    local.mood = dto.mood
                    local.timestamp = SyncDateFormatter.date(from: dto.timestamp) ?? local.timestamp
                    local.isStandalone = dto.isStandalone
                    local.latitude = dto.latitude == 0 ? nil : dto.latitude
                    local.longitude = dto.longitude == 0 ? nil : dto.longitude
                    local.updatedAt = remoteUpdatedAt
                    local.isDeleted = dto.isDeleted
                    local.day = dayMap[dto.dayId]
                    local.place = dto.placeId.flatMap { placeMap[$0] }
                }
            } else if !dto.isDeleted {
                let entry = JournalEntry(
                    id: dto.id,
                    text: dto.text,
                    mood: dto.mood,
                    timestamp: SyncDateFormatter.date(from: dto.timestamp) ?? Date(),
                    isStandalone: dto.isStandalone,
                    latitude: dto.latitude == 0 ? nil : dto.latitude,
                    longitude: dto.longitude == 0 ? nil : dto.longitude
                )
                entry.updatedAt = remoteUpdatedAt
                entry.day = dayMap[dto.dayId]
                entry.place = dto.placeId.flatMap { placeMap[$0] }
                context.insert(entry)
            }
        }
    }

    private func pullRoutePoints(context: ModelContext, userID: UUID, since: Date) async throws {
        let remoteDtos: [RoutePointDTO] = try await engine.pull(table: "route_points", since: since, userID: userID)
        let descriptor = FetchDescriptor<RoutePoint>()
        let localPoints = try context.fetch(descriptor)
        let localMap = Dictionary(uniqueKeysWithValues: localPoints.map { ($0.id, $0) })

        let dayDescriptor = FetchDescriptor<TripDay>()
        let days = try context.fetch(dayDescriptor)
        let dayMap = Dictionary(uniqueKeysWithValues: days.map { ($0.id, $0) })

        for dto in remoteDtos {
            let remoteUpdatedAt = SyncDateFormatter.date(from: dto.updatedAt) ?? Date.distantPast

            if let local = localMap[dto.id] {
                guard remoteUpdatedAt > local.updatedAt else { continue }
                if dto.isDeleted {
                    context.delete(local)
                } else {
                    local.latitude = dto.latitude
                    local.longitude = dto.longitude
                    local.timestamp = SyncDateFormatter.date(from: dto.timestamp) ?? local.timestamp
                    local.updatedAt = remoteUpdatedAt
                    local.isDeleted = dto.isDeleted
                    local.day = dayMap[dto.dayId]
                }
            } else if !dto.isDeleted {
                let point = RoutePoint(
                    latitude: dto.latitude,
                    longitude: dto.longitude,
                    timestamp: SyncDateFormatter.date(from: dto.timestamp) ?? Date()
                )
                point.id = dto.id
                point.updatedAt = remoteUpdatedAt
                point.day = dayMap[dto.dayId]
                context.insert(point)
            }
        }
    }

    private func pullBucketListItems(context: ModelContext, userID: UUID, since: Date) async throws {
        let remoteDtos: [BucketListItemDTO] = try await engine.pull(table: "bucket_list_items", since: since, userID: userID)
        let descriptor = FetchDescriptor<BucketListItem>()
        let localItems = try context.fetch(descriptor)
        let localMap = Dictionary(uniqueKeysWithValues: localItems.map { ($0.id, $0) })

        for dto in remoteDtos {
            let remoteUpdatedAt = SyncDateFormatter.date(from: dto.updatedAt) ?? Date.distantPast

            if let local = localMap[dto.id] {
                guard remoteUpdatedAt > local.updatedAt else { continue }
                if dto.isDeleted {
                    context.delete(local)
                } else {
                    local.name = dto.name
                    local.destination = dto.destination
                    local.category = dto.category
                    local.notes = dto.notes
                    local.latitude = dto.latitude == 0 ? nil : dto.latitude
                    local.longitude = dto.longitude == 0 ? nil : dto.longitude
                    local.dateAdded = SyncDateFormatter.date(from: dto.dateAdded) ?? local.dateAdded
                    local.isConverted = dto.isConverted
                    local.photoStoragePath = dto.photoStoragePath
                    local.updatedAt = remoteUpdatedAt
                    local.isDeleted = dto.isDeleted
                }
            } else if !dto.isDeleted {
                let item = BucketListItem(
                    id: dto.id,
                    name: dto.name,
                    destination: dto.destination,
                    category: dto.category,
                    notes: dto.notes,
                    latitude: dto.latitude == 0 ? nil : dto.latitude,
                    longitude: dto.longitude == 0 ? nil : dto.longitude,
                    dateAdded: SyncDateFormatter.date(from: dto.dateAdded) ?? Date(),
                    isConverted: dto.isConverted
                )
                item.photoStoragePath = dto.photoStoragePath
                item.updatedAt = remoteUpdatedAt
                context.insert(item)
            }
        }
    }
}
