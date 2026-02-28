import Foundation
import CoreLocation

enum SampleData {

    struct TripData {
        let trip: Trip
        let days: [TripDay]
        let expenses: [Expense]
        let journalEntries: [JournalEntry]
    }

    static func build() -> TripData {
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
            id: UUID(),
            name: "Путешествие по Японии",
            destination: "Япония",
            startDate: startDate,
            endDate: endDate,
            budget: 350000,
            currency: "JPY",
            coverSystemImage: "airplane",
            flightDate: flightDate
        )

        let days = buildDays(startDate: startDate, calendar: calendar)
        let expenses = buildExpenses(startDate: startDate, calendar: calendar)
        let journalEntries = buildJournal(startDate: startDate, calendar: calendar)

        return TripData(
            trip: trip,
            days: days,
            expenses: expenses,
            journalEntries: journalEntries
        )
    }

    // MARK: - Helper

    private static func makeTime(_ calendar: Calendar, base: Date, hour: Int, minute: Int = 0) -> Date {
        var comps = calendar.dateComponents([.year, .month, .day], from: base)
        comps.hour = hour
        comps.minute = minute
        return calendar.date(from: comps)!
    }

    // MARK: - Days

    private static func buildDays(startDate: Date, calendar: Calendar) -> [TripDay] {
        let day1 = startDate
        let day2 = calendar.date(byAdding: .day, value: 1, to: startDate)!
        let day3 = calendar.date(byAdding: .day, value: 2, to: startDate)!
        let day4 = calendar.date(byAdding: .day, value: 3, to: startDate)!
        let day6 = calendar.date(byAdding: .day, value: 5, to: startDate)!
        let day7 = calendar.date(byAdding: .day, value: 6, to: startDate)!
        let day9 = calendar.date(byAdding: .day, value: 8, to: startDate)!

        return [
            TripDay(
                id: UUID(),
                date: day1,
                title: "Прилёт и Сибуя",
                cityName: "Токио",
                places: [
                    Place(
                        id: UUID(), name: "Перекрёсток Сибуя", nameJapanese: "渋谷スクランブル交差点",
                        category: .culture, address: "Сибуя, Токио",
                        coordinate: CLLocationCoordinate2D(latitude: 35.6595, longitude: 139.7004),
                        isVisited: true, rating: 5, notes: "", timeToSpend: "30 мин"
                    ),
                    Place(
                        id: UUID(), name: "Статуя Хатико", nameJapanese: "忠犬ハチ公像",
                        category: .culture, address: "Станция Сибуя, Токио",
                        coordinate: CLLocationCoordinate2D(latitude: 35.6590, longitude: 139.7006),
                        isVisited: true, rating: 4, notes: "", timeToSpend: "15 мин"
                    ),
                    Place(
                        id: UUID(), name: "Ichiran Ramen Сибуя", nameJapanese: "一蘭 渋谷店",
                        category: .food, address: "Сибуя, Токио",
                        coordinate: CLLocationCoordinate2D(latitude: 35.6612, longitude: 139.6983),
                        isVisited: true, rating: 5, notes: "Лучший тонкоцу рамен", timeToSpend: "45 мин"
                    )
                ],
                events: [
                    TripEvent(
                        id: UUID(), title: "Прилёт в Нариту",
                        subtitle: "NRT → Токио",
                        category: .flight,
                        startTime: makeTime(calendar, base: day1, hour: 14, minute: 30),
                        endTime: makeTime(calendar, base: day1, hour: 15, minute: 0),
                        notes: "Терминал 1"
                    ),
                    TripEvent(
                        id: UUID(), title: "Narita Express → Сибуя",
                        subtitle: "Нарита → Сибуя",
                        category: .train,
                        startTime: makeTime(calendar, base: day1, hour: 15, minute: 30),
                        endTime: makeTime(calendar, base: day1, hour: 17, minute: 0),
                        notes: "JR Pass"
                    ),
                    TripEvent(
                        id: UUID(), title: "Заселение в отель",
                        subtitle: "Hotel Shibuya Stream",
                        category: .checkin,
                        startTime: makeTime(calendar, base: day1, hour: 17, minute: 30),
                        endTime: makeTime(calendar, base: day1, hour: 18, minute: 0),
                        notes: ""
                    )
                ],
                notes: "Первый день в Токио!"
            ),
            TripDay(
                id: UUID(),
                date: day2,
                title: "Асакуса и Акихабара",
                cityName: "Токио",
                places: [
                    Place(
                        id: UUID(), name: "Храм Сэнсо-дзи", nameJapanese: "浅草寺",
                        category: .temple, address: "2-3-1 Асакуса, Тайто",
                        coordinate: CLLocationCoordinate2D(latitude: 35.7148, longitude: 139.7967),
                        isVisited: true, rating: 5, notes: "Старейший храм Токио", timeToSpend: "1,5 ч"
                    ),
                    Place(
                        id: UUID(), name: "Улица Накамисэ", nameJapanese: "仲見世通り",
                        category: .shopping, address: "Асакуса, Тайто",
                        coordinate: CLLocationCoordinate2D(latitude: 35.7128, longitude: 139.7966),
                        isVisited: true, rating: 4, notes: "", timeToSpend: "1 ч"
                    ),
                    Place(
                        id: UUID(), name: "Акихабара", nameJapanese: "秋葉原電気街",
                        category: .shopping, address: "Акихабара, Тиёда",
                        coordinate: CLLocationCoordinate2D(latitude: 35.7023, longitude: 139.7745),
                        isVisited: false, rating: nil, notes: "", timeToSpend: "2 ч"
                    )
                ],
                events: [],
                notes: "Утром — храмы, днём — аниме"
            ),
            TripDay(
                id: UUID(),
                date: day3,
                title: "Харадзюку и Синдзюку",
                cityName: "Токио",
                places: [
                    Place(
                        id: UUID(), name: "Святилище Мэйдзи", nameJapanese: "明治神宮",
                        category: .shrine, address: "1-1 Ёёги-камидзоно, Сибуя",
                        coordinate: CLLocationCoordinate2D(latitude: 35.6764, longitude: 139.6993),
                        isVisited: false, rating: nil, notes: "", timeToSpend: "1,5 ч"
                    ),
                    Place(
                        id: UUID(), name: "Улица Такэсита", nameJapanese: "竹下通り",
                        category: .shopping, address: "Харадзюку, Сибуя",
                        coordinate: CLLocationCoordinate2D(latitude: 35.6716, longitude: 139.7029),
                        isVisited: false, rating: nil, notes: "", timeToSpend: "1 ч"
                    ),
                    Place(
                        id: UUID(), name: "Парк Синдзюку-гёэн", nameJapanese: "新宿御苑",
                        category: .nature, address: "11 Найтомати, Синдзюку",
                        coordinate: CLLocationCoordinate2D(latitude: 35.6852, longitude: 139.7100),
                        isVisited: false, rating: nil, notes: "Сезон цветения сакуры!", timeToSpend: "2 ч"
                    )
                ],
                events: [],
                notes: "Район моды и сады"
            ),
            TripDay(
                id: UUID(),
                date: day4,
                title: "Поездка в Камакуру",
                cityName: "Камакура",
                places: [
                    Place(
                        id: UUID(), name: "Большой Будда", nameJapanese: "鎌倉大仏",
                        category: .temple, address: "4-2-28 Хасэ, Камакура",
                        coordinate: CLLocationCoordinate2D(latitude: 35.3167, longitude: 139.5356),
                        isVisited: false, rating: nil, notes: "", timeToSpend: "1 ч"
                    ),
                    Place(
                        id: UUID(), name: "Цуругаока Хатимангу", nameJapanese: "鶴岡八幡宮",
                        category: .shrine, address: "2-1-31 Юкиносита, Камакура",
                        coordinate: CLLocationCoordinate2D(latitude: 35.3258, longitude: 139.5564),
                        isVisited: false, rating: nil, notes: "", timeToSpend: "1,5 ч"
                    )
                ],
                events: [
                    TripEvent(
                        id: UUID(), title: "JR Yokosuka Line",
                        subtitle: "Токио → Камакура",
                        category: .train,
                        startTime: makeTime(calendar, base: day4, hour: 8, minute: 30),
                        endTime: makeTime(calendar, base: day4, hour: 9, minute: 30),
                        notes: "JR Pass, платформа 1"
                    ),
                    TripEvent(
                        id: UUID(), title: "JR Yokosuka Line",
                        subtitle: "Камакура → Токио",
                        category: .train,
                        startTime: makeTime(calendar, base: day4, hour: 17, minute: 0),
                        endTime: makeTime(calendar, base: day4, hour: 18, minute: 0),
                        notes: ""
                    )
                ],
                notes: "Поезд от станции Токио"
            ),
            TripDay(
                id: UUID(),
                date: calendar.date(byAdding: .day, value: 4, to: startDate)!,
                title: "Синкансэн в Киото",
                cityName: "Киото",
                places: [],
                events: [
                    TripEvent(
                        id: UUID(), title: "Shinkansen Nozomi",
                        subtitle: "Токио → Киото",
                        category: .train,
                        startTime: makeTime(calendar, base: calendar.date(byAdding: .day, value: 4, to: startDate)!, hour: 9, minute: 0),
                        endTime: makeTime(calendar, base: calendar.date(byAdding: .day, value: 4, to: startDate)!, hour: 11, minute: 15),
                        notes: "Вагон 7, место 3A. JR Pass"
                    ),
                    TripEvent(
                        id: UUID(), title: "Заселение в рёкан",
                        subtitle: "Traditional Ryokan Gion",
                        category: .checkin,
                        startTime: makeTime(calendar, base: calendar.date(byAdding: .day, value: 4, to: startDate)!, hour: 15, minute: 0),
                        endTime: makeTime(calendar, base: calendar.date(byAdding: .day, value: 4, to: startDate)!, hour: 16, minute: 0),
                        notes: "Онсэн доступен с 16:00"
                    )
                ],
                notes: "Переезд из Токио в Киото"
            ),
            TripDay(
                id: UUID(),
                date: day6,
                title: "Фусими Инари и Гион",
                cityName: "Киото",
                places: [
                    Place(
                        id: UUID(), name: "Фусими Инари Тайся", nameJapanese: "伏見稲荷大社",
                        category: .shrine, address: "68 Фукакуса Ябуноутитё, Фусими",
                        coordinate: CLLocationCoordinate2D(latitude: 34.9671, longitude: 135.7727),
                        isVisited: false, rating: nil, notes: "Тысячи ворот тории!", timeToSpend: "3 ч"
                    ),
                    Place(
                        id: UUID(), name: "Район Гион", nameJapanese: "祇園",
                        category: .culture, address: "Гион, Хигасияма, Киото",
                        coordinate: CLLocationCoordinate2D(latitude: 35.0037, longitude: 135.7756),
                        isVisited: false, rating: nil, notes: "Район гейш", timeToSpend: "2 ч"
                    ),
                    Place(
                        id: UUID(), name: "Рынок Нисики", nameJapanese: "錦市場",
                        category: .food, address: "Нисикикодзи, Накагё, Киото",
                        coordinate: CLLocationCoordinate2D(latitude: 35.0050, longitude: 135.7649),
                        isVisited: false, rating: nil, notes: "Рай уличной еды", timeToSpend: "1,5 ч"
                    )
                ],
                events: [],
                notes: "Прийти в Фусими Инари пораньше, чтобы избежать толп"
            ),
            TripDay(
                id: UUID(),
                date: day7,
                title: "Арасияма и храмы",
                cityName: "Киото",
                places: [
                    Place(
                        id: UUID(), name: "Бамбуковая роща", nameJapanese: "竹林の小径",
                        category: .nature, address: "Сагатэнрюдзи Сусукинобабатё, Укё",
                        coordinate: CLLocationCoordinate2D(latitude: 35.0170, longitude: 135.6713),
                        isVisited: false, rating: nil, notes: "", timeToSpend: "1 ч"
                    ),
                    Place(
                        id: UUID(), name: "Кинкаку-дзи", nameJapanese: "金閣寺",
                        category: .temple, address: "1 Кинкакудзитё, Кита, Киото",
                        coordinate: CLLocationCoordinate2D(latitude: 35.0394, longitude: 135.7292),
                        isVisited: false, rating: nil, notes: "Золотой павильон", timeToSpend: "1 ч"
                    )
                ],
                events: [],
                notes: "Утренняя прогулка по бамбуковому лесу"
            ),
            TripDay(
                id: UUID(),
                date: day9,
                title: "Уличная еда Осаки",
                cityName: "Осака",
                places: [
                    Place(
                        id: UUID(), name: "Дотонбори", nameJapanese: "道頓堀",
                        category: .food, address: "Дотонбори, Тюо-ку, Осака",
                        coordinate: CLLocationCoordinate2D(latitude: 34.6687, longitude: 135.5013),
                        isVisited: false, rating: nil, notes: "Бегущий человек Glico!", timeToSpend: "3 ч"
                    ),
                    Place(
                        id: UUID(), name: "Замок Осака", nameJapanese: "大阪城",
                        category: .culture, address: "1-1 Осакадзё, Тюо-ку, Осака",
                        coordinate: CLLocationCoordinate2D(latitude: 34.6873, longitude: 135.5262),
                        isVisited: false, rating: nil, notes: "", timeToSpend: "2 ч"
                    ),
                    Place(
                        id: UUID(), name: "Рынок Куромон", nameJapanese: "黒門市場",
                        category: .food, address: "2-4-1 Ниппонбаси, Тюо-ку, Осака",
                        coordinate: CLLocationCoordinate2D(latitude: 34.6627, longitude: 135.5066),
                        isVisited: false, rating: nil, notes: "Свежие сасими на завтрак", timeToSpend: "1,5 ч"
                    )
                ],
                events: [
                    TripEvent(
                        id: UUID(), title: "Shinkansen Nozomi",
                        subtitle: "Киото → Осака",
                        category: .train,
                        startTime: makeTime(calendar, base: day9, hour: 8, minute: 0),
                        endTime: makeTime(calendar, base: day9, hour: 8, minute: 30),
                        notes: "JR Pass"
                    )
                ],
                notes: "Осака — кухня Японии"
            )
        ]
    }

    // MARK: - Expenses

    private static func buildExpenses(startDate: Date, calendar: Calendar) -> [Expense] {
        [
            Expense(id: UUID(), title: "JR Pass (14 дней)", amount: 50000,
                    category: .transport, date: startDate, notes: "Куплен на станции Токио"),
            Expense(id: UUID(), title: "Рамен Ichiran", amount: 1290,
                    category: .food, date: startDate, notes: "Сет тонкоцу рамен"),
            Expense(id: UUID(), title: "Отель Сибуя (3 ночи)", amount: 45000,
                    category: .accommodation, date: startDate, notes: ""),
            Expense(id: UUID(), title: "Омамори в Сэнсо-дзи", amount: 800,
                    category: .shopping,
                    date: calendar.date(byAdding: .day, value: 1, to: startDate)!, notes: "Талисман на удачу"),
            Expense(id: UUID(), title: "Мелон-пан", amount: 250,
                    category: .food,
                    date: calendar.date(byAdding: .day, value: 1, to: startDate)!, notes: "Из Асакусы"),
            Expense(id: UUID(), title: "Пополнение Suica", amount: 3000,
                    category: .transport,
                    date: calendar.date(byAdding: .day, value: 1, to: startDate)!, notes: "Карта метро"),
            Expense(id: UUID(), title: "Такояки в Дотонбори", amount: 600,
                    category: .food,
                    date: calendar.date(byAdding: .day, value: 8, to: startDate)!, notes: ""),
            Expense(id: UUID(), title: "Набор матча Kit Kat", amount: 1200,
                    category: .shopping,
                    date: calendar.date(byAdding: .day, value: 2, to: startDate)!, notes: "Сувениры")
        ]
    }

    // MARK: - Journal

    private static func buildJournal(startDate: Date, calendar: Calendar) -> [JournalEntry] {
        [
            JournalEntry(
                id: UUID(),
                date: startDate,
                title: "Первый день в Токио!",
                content: "Наконец-то прилетел в Нариту. Система поездов невероятно удобная. Перекрёсток Сибуя ночью завораживает \u{2014} сотни людей движутся в идеальной гармонии. Рамен в Ichiran \u{2014} лучший, что я пробовал. Это путешествие уже превосходит все ожидания.",
                mood: .amazing
            ),
            JournalEntry(
                id: UUID(),
                date: calendar.date(byAdding: .day, value: 1, to: startDate)!,
                title: "Храмы и аниме",
                content: "Сэнсо-дзи в утреннем тумане \u{2014} волшебство. Дым благовоний, огромный фонарь у ворот Каминаримон. На улице Накамисэ столько вкусного. Акихабара днём \u{2014} перегрузка всех чувств в лучшем смысле.",
                mood: .happy
            )
        ]
    }
}
