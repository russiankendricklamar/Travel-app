import Foundation
import SwiftData

enum SampleData {

    static func seed(into context: ModelContext) {
        let calendar = Calendar.current
        let startDate = calendar.date(
            from: DateComponents(year: 2026, month: 3, day: 15)
        )!
        let endDate = calendar.date(
            from: DateComponents(year: 2026, month: 3, day: 28)
        )!
        let flightDate = calendar.date(
            from: DateComponents(year: 2026, month: 3, day: 13, hour: 10, minute: 0)
        )!

        let trip = Trip(
            name: "Путешествие по Японии",
            country: "Япония",
            startDate: startDate,
            endDate: endDate,
            budget: 500000,
            currency: "RUB",
            coverSystemImage: "airplane",
            flightDate: flightDate,
            flightNumber: "SU260"
        )

        buildDays(trip: trip, startDate: startDate, calendar: calendar)
        buildExpenses(trip: trip, startDate: startDate, calendar: calendar)
        buildTickets(trip: trip, startDate: startDate, calendar: calendar)

        context.insert(trip)
        try? context.save()
    }

    // MARK: - Helper

    private static func makeTime(_ calendar: Calendar, base: Date, hour: Int, minute: Int = 0) -> Date {
        var comps = calendar.dateComponents([.year, .month, .day], from: base)
        comps.hour = hour
        comps.minute = minute
        return calendar.date(from: comps)!
    }

    // MARK: - Days

    private static func buildDays(trip: Trip, startDate: Date, calendar: Calendar) {
        let day1 = startDate
        let day2 = calendar.date(byAdding: .day, value: 1, to: startDate)!
        let day3 = calendar.date(byAdding: .day, value: 2, to: startDate)!
        let day4 = calendar.date(byAdding: .day, value: 3, to: startDate)!
        let day5 = calendar.date(byAdding: .day, value: 4, to: startDate)!
        let day6 = calendar.date(byAdding: .day, value: 5, to: startDate)!
        let day7 = calendar.date(byAdding: .day, value: 6, to: startDate)!
        let day9 = calendar.date(byAdding: .day, value: 8, to: startDate)!

        // Day 1: Прилёт и Сибуя
        let tripDay1 = TripDay(date: day1, title: "Прилёт и Сибуя", cityName: "Токио", notes: "Первый день в Токио!")
        tripDay1.places.append(contentsOf: [
            Place(name: "Перекрёсток Сибуя", nameLocal: "渋谷スクランブル交差点",
                  category: .culture, address: "Сибуя, Токио",
                  latitude: 35.6595, longitude: 139.7004,
                  isVisited: true, rating: 5, timeToSpend: "30 мин"),
            Place(name: "Статуя Хатико", nameLocal: "忠犬ハチ公像",
                  category: .culture, address: "Станция Сибуя, Токио",
                  latitude: 35.6590, longitude: 139.7006,
                  isVisited: true, rating: 4, timeToSpend: "15 мин"),
            Place(name: "Ichiran Ramen Сибуя", nameLocal: "一蘭 渋谷店",
                  category: .food, address: "Сибуя, Токио",
                  latitude: 35.6612, longitude: 139.6983,
                  isVisited: true, rating: 5, notes: "Лучший тонкоцу рамен", timeToSpend: "45 мин")
        ])
        tripDay1.events.append(contentsOf: [
            TripEvent(title: "Прилёт в Нариту", subtitle: "NRT → Токио",
                      category: .flight,
                      startTime: makeTime(calendar, base: day1, hour: 14, minute: 30),
                      endTime: makeTime(calendar, base: day1, hour: 15, minute: 0),
                      notes: "Терминал 1",
                      startLatitude: 35.7647, startLongitude: 140.3864,
                      endLatitude: 35.7647, endLongitude: 140.3864),
            TripEvent(title: "Narita Express → Сибуя", subtitle: "Нарита → Сибуя",
                      category: .train,
                      startTime: makeTime(calendar, base: day1, hour: 15, minute: 30),
                      endTime: makeTime(calendar, base: day1, hour: 17, minute: 0),
                      notes: "JR Pass",
                      startLatitude: 35.7647, startLongitude: 140.3864,
                      endLatitude: 35.6580, endLongitude: 139.7016),
            TripEvent(title: "Заселение в отель", subtitle: "Hotel Shibuya Stream",
                      category: .checkin,
                      startTime: makeTime(calendar, base: day1, hour: 17, minute: 30),
                      endTime: makeTime(calendar, base: day1, hour: 18, minute: 0),
                      latitude: 35.6585, longitude: 139.7013)
        ])
        trip.days.append(tripDay1)

        // Day 2: Асакуса и Акихабара
        let tripDay2 = TripDay(date: day2, title: "Асакуса и Акихабара", cityName: "Токио", notes: "Утром — храмы, днём — аниме")
        tripDay2.places.append(contentsOf: [
            Place(name: "Храм Сэнсо-дзи", nameLocal: "浅草寺",
                  category: .temple, address: "2-3-1 Асакуса, Тайто",
                  latitude: 35.7148, longitude: 139.7967,
                  isVisited: true, rating: 5, notes: "Старейший храм Токио", timeToSpend: "1,5 ч"),
            Place(name: "Улица Накамисэ", nameLocal: "仲見世通り",
                  category: .shopping, address: "Асакуса, Тайто",
                  latitude: 35.7128, longitude: 139.7966,
                  isVisited: true, rating: 4, timeToSpend: "1 ч"),
            Place(name: "Акихабара", nameLocal: "秋葉原電気街",
                  category: .shopping, address: "Акихабара, Тиёда",
                  latitude: 35.7023, longitude: 139.7745,
                  timeToSpend: "2 ч")
        ])
        trip.days.append(tripDay2)

        // Day 3: Харадзюку и Синдзюку
        let tripDay3 = TripDay(date: day3, title: "Харадзюку и Синдзюку", cityName: "Токио", notes: "Район моды и сады")
        tripDay3.places.append(contentsOf: [
            Place(name: "Святилище Мэйдзи", nameLocal: "明治神宮",
                  category: .shrine, address: "1-1 Ёёги-камидзоно, Сибуя",
                  latitude: 35.6764, longitude: 139.6993,
                  timeToSpend: "1,5 ч"),
            Place(name: "Улица Такэсита", nameLocal: "竹下通り",
                  category: .shopping, address: "Харадзюку, Сибуя",
                  latitude: 35.6716, longitude: 139.7029,
                  timeToSpend: "1 ч"),
            Place(name: "Парк Синдзюку-гёэн", nameLocal: "新宿御苑",
                  category: .nature, address: "11 Найтомати, Синдзюку",
                  latitude: 35.6852, longitude: 139.7100,
                  notes: "Сезон цветения сакуры!", timeToSpend: "2 ч")
        ])
        trip.days.append(tripDay3)

        // Day 4: Поездка в Камакуру
        let tripDay4 = TripDay(date: day4, title: "Поездка в Камакуру", cityName: "Камакура", notes: "Поезд от станции Токио")
        tripDay4.places.append(contentsOf: [
            Place(name: "Большой Будда", nameLocal: "鎌倉大仏",
                  category: .temple, address: "4-2-28 Хасэ, Камакура",
                  latitude: 35.3167, longitude: 139.5356,
                  timeToSpend: "1 ч"),
            Place(name: "Цуругаока Хатимангу", nameLocal: "鶴岡八幡宮",
                  category: .shrine, address: "2-1-31 Юкиносита, Камакура",
                  latitude: 35.3258, longitude: 139.5564,
                  timeToSpend: "1,5 ч")
        ])
        tripDay4.events.append(contentsOf: [
            TripEvent(title: "JR Yokosuka Line", subtitle: "Токио → Камакура",
                      category: .train,
                      startTime: makeTime(calendar, base: day4, hour: 8, minute: 30),
                      endTime: makeTime(calendar, base: day4, hour: 9, minute: 30),
                      notes: "JR Pass, платформа 1",
                      startLatitude: 35.6812, startLongitude: 139.7671,
                      endLatitude: 35.3190, endLongitude: 139.5467),
            TripEvent(title: "JR Yokosuka Line", subtitle: "Камакура → Токио",
                      category: .train,
                      startTime: makeTime(calendar, base: day4, hour: 17, minute: 0),
                      endTime: makeTime(calendar, base: day4, hour: 18, minute: 0),
                      startLatitude: 35.3190, startLongitude: 139.5467,
                      endLatitude: 35.6812, endLongitude: 139.7671)
        ])
        trip.days.append(tripDay4)

        // Day 5: Синкансэн в Киото
        let tripDay5 = TripDay(date: day5, title: "Синкансэн в Киото", cityName: "Киото", notes: "Переезд из Токио в Киото")
        tripDay5.events.append(contentsOf: [
            TripEvent(title: "Shinkansen Nozomi", subtitle: "Токио → Киото",
                      category: .train,
                      startTime: makeTime(calendar, base: day5, hour: 9, minute: 0),
                      endTime: makeTime(calendar, base: day5, hour: 11, minute: 15),
                      notes: "Вагон 7, место 3A. JR Pass",
                      startLatitude: 35.6812, startLongitude: 139.7671,
                      endLatitude: 34.9856, endLongitude: 135.7581),
            TripEvent(title: "Заселение в рёкан", subtitle: "Traditional Ryokan Gion",
                      category: .checkin,
                      startTime: makeTime(calendar, base: day5, hour: 15, minute: 0),
                      endTime: makeTime(calendar, base: day5, hour: 16, minute: 0),
                      notes: "Онсэн доступен с 16:00",
                      latitude: 35.0037, longitude: 135.7756)
        ])
        trip.days.append(tripDay5)

        // Day 6: Фусими Инари и Гион
        let tripDay6 = TripDay(date: day6, title: "Фусими Инари и Гион", cityName: "Киото", notes: "Прийти в Фусими Инари пораньше, чтобы избежать толп")
        tripDay6.places.append(contentsOf: [
            Place(name: "Фусими Инари Тайся", nameLocal: "伏見稲荷大社",
                  category: .shrine, address: "68 Фукакуса Ябуноутитё, Фусими",
                  latitude: 34.9671, longitude: 135.7727,
                  notes: "Тысячи ворот тории!", timeToSpend: "3 ч"),
            Place(name: "Район Гион", nameLocal: "祇園",
                  category: .culture, address: "Гион, Хигасияма, Киото",
                  latitude: 35.0037, longitude: 135.7756,
                  notes: "Район гейш", timeToSpend: "2 ч"),
            Place(name: "Рынок Нисики", nameLocal: "錦市場",
                  category: .food, address: "Нисикикодзи, Накагё, Киото",
                  latitude: 35.0050, longitude: 135.7649,
                  notes: "Рай уличной еды", timeToSpend: "1,5 ч")
        ])
        trip.days.append(tripDay6)

        // Day 7: Арасияма и храмы
        let tripDay7 = TripDay(date: day7, title: "Арасияма и храмы", cityName: "Киото", notes: "Утренняя прогулка по бамбуковому лесу")
        tripDay7.places.append(contentsOf: [
            Place(name: "Бамбуковая роща", nameLocal: "竹林の小径",
                  category: .nature, address: "Сагатэнрюдзи Сусукинобабатё, Укё",
                  latitude: 35.0170, longitude: 135.6713,
                  timeToSpend: "1 ч"),
            Place(name: "Кинкаку-дзи", nameLocal: "金閣寺",
                  category: .temple, address: "1 Кинкакудзитё, Кита, Киото",
                  latitude: 35.0394, longitude: 135.7292,
                  notes: "Золотой павильон", timeToSpend: "1 ч")
        ])
        trip.days.append(tripDay7)

        // Day 9: Уличная еда Осаки
        let tripDay9 = TripDay(date: day9, title: "Уличная еда Осаки", cityName: "Осака", notes: "Осака — кухня Японии")
        tripDay9.places.append(contentsOf: [
            Place(name: "Дотонбори", nameLocal: "道頓堀",
                  category: .food, address: "Дотонбори, Тюо-ку, Осака",
                  latitude: 34.6687, longitude: 135.5013,
                  notes: "Бегущий человек Glico!", timeToSpend: "3 ч"),
            Place(name: "Замок Осака", nameLocal: "大阪城",
                  category: .culture, address: "1-1 Осакадзё, Тюо-ку, Осака",
                  latitude: 34.6873, longitude: 135.5262,
                  timeToSpend: "2 ч"),
            Place(name: "Рынок Куромон", nameLocal: "黒門市場",
                  category: .food, address: "2-4-1 Ниппонбаси, Тюо-ку, Осака",
                  latitude: 34.6627, longitude: 135.5066,
                  notes: "Свежие сасими на завтрак", timeToSpend: "1,5 ч")
        ])
        tripDay9.events.append(
            TripEvent(title: "Shinkansen Nozomi", subtitle: "Киото → Осака",
                      category: .train,
                      startTime: makeTime(calendar, base: day9, hour: 8, minute: 0),
                      endTime: makeTime(calendar, base: day9, hour: 8, minute: 30),
                      notes: "JR Pass",
                      startLatitude: 34.9856, startLongitude: 135.7581,
                      endLatitude: 34.7024, endLongitude: 135.4959)
        )
        trip.days.append(tripDay9)
    }

    // MARK: - Expenses

    // MARK: - Tickets

    private static func buildTickets(trip: Trip, startDate: Date, calendar: Calendar) {
        let day5 = calendar.date(byAdding: .day, value: 4, to: startDate)!

        // F1 Suzuka — привязан к trip, не к конкретному дню (день 12, за пределами sample days)
        let f1Ticket = Ticket(
            title: "F1 Гран-при Сузука",
            venue: "Suzuka International Racing Course",
            category: .f1,
            barcodeType: .qr,
            barcodeContent: "F1-SUZUKA-2026-A12-R08-S45",
            eventDate: calendar.date(byAdding: .day, value: 11, to: startDate)!,
            seatInfo: "Трибуна A12, Ряд 8, Место 45",
            notes: "Ворота открываются в 8:00. Гонка в 14:00"
        )
        trip.tickets.append(f1Ticket)

        // TeamLab Borderless — привязан к day 2 (Асакуса/Акихабара)
        let teamlabTicket = Ticket(
            title: "TeamLab Borderless",
            venue: "Azabudai Hills, Токио",
            category: .museum,
            barcodeType: .qr,
            barcodeContent: "TEAMLAB-20260316-1400-2ADL",
            eventDate: makeTime(calendar, base: calendar.date(byAdding: .day, value: 1, to: startDate)!, hour: 14),
            seatInfo: "Вход 14:00–14:30",
            notes: "Не забыть удобную обувь"
        )
        trip.tickets.append(teamlabTicket)
        // Привязка к дню 2
        if let day2 = trip.days.first(where: { calendar.isDate($0.date, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: startDate)!) }) {
            day2.tickets.append(teamlabTicket)
        }

        // Shinkansen Токио → Киото — привязан к day 5
        let shinkansenTicket = Ticket(
            title: "Shinkansen Nozomi 225",
            venue: "Станция Токио → Станция Киото",
            category: .transport,
            barcodeType: .code128,
            barcodeContent: "JR-NOZOMI225-0900-7-3A",
            eventDate: makeTime(calendar, base: day5, hour: 9),
            seatInfo: "Вагон 7, Место 3A",
            notes: "JR Pass. Платформа 14-19"
        )
        trip.tickets.append(shinkansenTicket)
        if let tripDay5 = trip.days.first(where: { calendar.isDate($0.date, inSameDayAs: day5) }) {
            tripDay5.tickets.append(shinkansenTicket)
        }
    }

    // MARK: - Expenses

    private static func buildExpenses(trip: Trip, startDate: Date, calendar: Calendar) {
        trip.expenses.append(contentsOf: [
            Expense(title: "JR Pass (14 дней)", amount: 29000,
                    category: .transport, date: startDate, notes: "Куплен на станции Токио"),
            Expense(title: "Рамен Ichiran", amount: 750,
                    category: .food, date: startDate, notes: "Сет тонкоцу рамен"),
            Expense(title: "Отель Сибуя (3 ночи)", amount: 26000,
                    category: .accommodation, date: startDate),
            Expense(title: "Омамори в Сэнсо-дзи", amount: 460,
                    category: .shopping,
                    date: calendar.date(byAdding: .day, value: 1, to: startDate)!, notes: "Талисман на удачу"),
            Expense(title: "Мелон-пан", amount: 145,
                    category: .food,
                    date: calendar.date(byAdding: .day, value: 1, to: startDate)!, notes: "Из Асакусы"),
            Expense(title: "Пополнение Suica", amount: 1740,
                    category: .transport,
                    date: calendar.date(byAdding: .day, value: 1, to: startDate)!, notes: "Карта метро"),
            Expense(title: "Такояки в Дотонбори", amount: 350,
                    category: .food,
                    date: calendar.date(byAdding: .day, value: 8, to: startDate)!),
            Expense(title: "Набор матча Kit Kat", amount: 700,
                    category: .shopping,
                    date: calendar.date(byAdding: .day, value: 2, to: startDate)!, notes: "Сувениры")
        ])
    }

}
