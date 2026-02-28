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
            destination: "Япония",
            startDate: startDate,
            endDate: endDate,
            budget: 350000,
            currency: "JPY",
            coverSystemImage: "airplane",
            flightDate: flightDate
        )

        buildDays(trip: trip, startDate: startDate, calendar: calendar)
        buildExpenses(trip: trip, startDate: startDate, calendar: calendar)
        buildJournal(trip: trip, startDate: startDate, calendar: calendar)

        context.insert(trip)
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
            Place(name: "Перекрёсток Сибуя", nameJapanese: "渋谷スクランブル交差点",
                  category: .culture, address: "Сибуя, Токио",
                  latitude: 35.6595, longitude: 139.7004,
                  isVisited: true, rating: 5, timeToSpend: "30 мин"),
            Place(name: "Статуя Хатико", nameJapanese: "忠犬ハチ公像",
                  category: .culture, address: "Станция Сибуя, Токио",
                  latitude: 35.6590, longitude: 139.7006,
                  isVisited: true, rating: 4, timeToSpend: "15 мин"),
            Place(name: "Ichiran Ramen Сибуя", nameJapanese: "一蘭 渋谷店",
                  category: .food, address: "Сибуя, Токио",
                  latitude: 35.6612, longitude: 139.6983,
                  isVisited: true, rating: 5, notes: "Лучший тонкоцу рамен", timeToSpend: "45 мин")
        ])
        tripDay1.events.append(contentsOf: [
            TripEvent(title: "Прилёт в Нариту", subtitle: "NRT → Токио",
                      category: .flight,
                      startTime: makeTime(calendar, base: day1, hour: 14, minute: 30),
                      endTime: makeTime(calendar, base: day1, hour: 15, minute: 0),
                      notes: "Терминал 1"),
            TripEvent(title: "Narita Express → Сибуя", subtitle: "Нарита → Сибуя",
                      category: .train,
                      startTime: makeTime(calendar, base: day1, hour: 15, minute: 30),
                      endTime: makeTime(calendar, base: day1, hour: 17, minute: 0),
                      notes: "JR Pass"),
            TripEvent(title: "Заселение в отель", subtitle: "Hotel Shibuya Stream",
                      category: .checkin,
                      startTime: makeTime(calendar, base: day1, hour: 17, minute: 30),
                      endTime: makeTime(calendar, base: day1, hour: 18, minute: 0))
        ])
        trip.days.append(tripDay1)

        // Day 2: Асакуса и Акихабара
        let tripDay2 = TripDay(date: day2, title: "Асакуса и Акихабара", cityName: "Токио", notes: "Утром — храмы, днём — аниме")
        tripDay2.places.append(contentsOf: [
            Place(name: "Храм Сэнсо-дзи", nameJapanese: "浅草寺",
                  category: .temple, address: "2-3-1 Асакуса, Тайто",
                  latitude: 35.7148, longitude: 139.7967,
                  isVisited: true, rating: 5, notes: "Старейший храм Токио", timeToSpend: "1,5 ч"),
            Place(name: "Улица Накамисэ", nameJapanese: "仲見世通り",
                  category: .shopping, address: "Асакуса, Тайто",
                  latitude: 35.7128, longitude: 139.7966,
                  isVisited: true, rating: 4, timeToSpend: "1 ч"),
            Place(name: "Акихабара", nameJapanese: "秋葉原電気街",
                  category: .shopping, address: "Акихабара, Тиёда",
                  latitude: 35.7023, longitude: 139.7745,
                  timeToSpend: "2 ч")
        ])
        trip.days.append(tripDay2)

        // Day 3: Харадзюку и Синдзюку
        let tripDay3 = TripDay(date: day3, title: "Харадзюку и Синдзюку", cityName: "Токио", notes: "Район моды и сады")
        tripDay3.places.append(contentsOf: [
            Place(name: "Святилище Мэйдзи", nameJapanese: "明治神宮",
                  category: .shrine, address: "1-1 Ёёги-камидзоно, Сибуя",
                  latitude: 35.6764, longitude: 139.6993,
                  timeToSpend: "1,5 ч"),
            Place(name: "Улица Такэсита", nameJapanese: "竹下通り",
                  category: .shopping, address: "Харадзюку, Сибуя",
                  latitude: 35.6716, longitude: 139.7029,
                  timeToSpend: "1 ч"),
            Place(name: "Парк Синдзюку-гёэн", nameJapanese: "新宿御苑",
                  category: .nature, address: "11 Найтомати, Синдзюку",
                  latitude: 35.6852, longitude: 139.7100,
                  notes: "Сезон цветения сакуры!", timeToSpend: "2 ч")
        ])
        trip.days.append(tripDay3)

        // Day 4: Поездка в Камакуру
        let tripDay4 = TripDay(date: day4, title: "Поездка в Камакуру", cityName: "Камакура", notes: "Поезд от станции Токио")
        tripDay4.places.append(contentsOf: [
            Place(name: "Большой Будда", nameJapanese: "鎌倉大仏",
                  category: .temple, address: "4-2-28 Хасэ, Камакура",
                  latitude: 35.3167, longitude: 139.5356,
                  timeToSpend: "1 ч"),
            Place(name: "Цуругаока Хатимангу", nameJapanese: "鶴岡八幡宮",
                  category: .shrine, address: "2-1-31 Юкиносита, Камакура",
                  latitude: 35.3258, longitude: 139.5564,
                  timeToSpend: "1,5 ч")
        ])
        tripDay4.events.append(contentsOf: [
            TripEvent(title: "JR Yokosuka Line", subtitle: "Токио → Камакура",
                      category: .train,
                      startTime: makeTime(calendar, base: day4, hour: 8, minute: 30),
                      endTime: makeTime(calendar, base: day4, hour: 9, minute: 30),
                      notes: "JR Pass, платформа 1"),
            TripEvent(title: "JR Yokosuka Line", subtitle: "Камакура → Токио",
                      category: .train,
                      startTime: makeTime(calendar, base: day4, hour: 17, minute: 0),
                      endTime: makeTime(calendar, base: day4, hour: 18, minute: 0))
        ])
        trip.days.append(tripDay4)

        // Day 5: Синкансэн в Киото
        let tripDay5 = TripDay(date: day5, title: "Синкансэн в Киото", cityName: "Киото", notes: "Переезд из Токио в Киото")
        tripDay5.events.append(contentsOf: [
            TripEvent(title: "Shinkansen Nozomi", subtitle: "Токио → Киото",
                      category: .train,
                      startTime: makeTime(calendar, base: day5, hour: 9, minute: 0),
                      endTime: makeTime(calendar, base: day5, hour: 11, minute: 15),
                      notes: "Вагон 7, место 3A. JR Pass"),
            TripEvent(title: "Заселение в рёкан", subtitle: "Traditional Ryokan Gion",
                      category: .checkin,
                      startTime: makeTime(calendar, base: day5, hour: 15, minute: 0),
                      endTime: makeTime(calendar, base: day5, hour: 16, minute: 0),
                      notes: "Онсэн доступен с 16:00")
        ])
        trip.days.append(tripDay5)

        // Day 6: Фусими Инари и Гион
        let tripDay6 = TripDay(date: day6, title: "Фусими Инари и Гион", cityName: "Киото", notes: "Прийти в Фусими Инари пораньше, чтобы избежать толп")
        tripDay6.places.append(contentsOf: [
            Place(name: "Фусими Инари Тайся", nameJapanese: "伏見稲荷大社",
                  category: .shrine, address: "68 Фукакуса Ябуноутитё, Фусими",
                  latitude: 34.9671, longitude: 135.7727,
                  notes: "Тысячи ворот тории!", timeToSpend: "3 ч"),
            Place(name: "Район Гион", nameJapanese: "祇園",
                  category: .culture, address: "Гион, Хигасияма, Киото",
                  latitude: 35.0037, longitude: 135.7756,
                  notes: "Район гейш", timeToSpend: "2 ч"),
            Place(name: "Рынок Нисики", nameJapanese: "錦市場",
                  category: .food, address: "Нисикикодзи, Накагё, Киото",
                  latitude: 35.0050, longitude: 135.7649,
                  notes: "Рай уличной еды", timeToSpend: "1,5 ч")
        ])
        trip.days.append(tripDay6)

        // Day 7: Арасияма и храмы
        let tripDay7 = TripDay(date: day7, title: "Арасияма и храмы", cityName: "Киото", notes: "Утренняя прогулка по бамбуковому лесу")
        tripDay7.places.append(contentsOf: [
            Place(name: "Бамбуковая роща", nameJapanese: "竹林の小径",
                  category: .nature, address: "Сагатэнрюдзи Сусукинобабатё, Укё",
                  latitude: 35.0170, longitude: 135.6713,
                  timeToSpend: "1 ч"),
            Place(name: "Кинкаку-дзи", nameJapanese: "金閣寺",
                  category: .temple, address: "1 Кинкакудзитё, Кита, Киото",
                  latitude: 35.0394, longitude: 135.7292,
                  notes: "Золотой павильон", timeToSpend: "1 ч")
        ])
        trip.days.append(tripDay7)

        // Day 9: Уличная еда Осаки
        let tripDay9 = TripDay(date: day9, title: "Уличная еда Осаки", cityName: "Осака", notes: "Осака — кухня Японии")
        tripDay9.places.append(contentsOf: [
            Place(name: "Дотонбори", nameJapanese: "道頓堀",
                  category: .food, address: "Дотонбори, Тюо-ку, Осака",
                  latitude: 34.6687, longitude: 135.5013,
                  notes: "Бегущий человек Glico!", timeToSpend: "3 ч"),
            Place(name: "Замок Осака", nameJapanese: "大阪城",
                  category: .culture, address: "1-1 Осакадзё, Тюо-ку, Осака",
                  latitude: 34.6873, longitude: 135.5262,
                  timeToSpend: "2 ч"),
            Place(name: "Рынок Куромон", nameJapanese: "黒門市場",
                  category: .food, address: "2-4-1 Ниппонбаси, Тюо-ку, Осака",
                  latitude: 34.6627, longitude: 135.5066,
                  notes: "Свежие сасими на завтрак", timeToSpend: "1,5 ч")
        ])
        tripDay9.events.append(
            TripEvent(title: "Shinkansen Nozomi", subtitle: "Киото → Осака",
                      category: .train,
                      startTime: makeTime(calendar, base: day9, hour: 8, minute: 0),
                      endTime: makeTime(calendar, base: day9, hour: 8, minute: 30),
                      notes: "JR Pass")
        )
        trip.days.append(tripDay9)
    }

    // MARK: - Expenses

    private static func buildExpenses(trip: Trip, startDate: Date, calendar: Calendar) {
        trip.expenses.append(contentsOf: [
            Expense(title: "JR Pass (14 дней)", amount: 50000,
                    category: .transport, date: startDate, notes: "Куплен на станции Токио"),
            Expense(title: "Рамен Ichiran", amount: 1290,
                    category: .food, date: startDate, notes: "Сет тонкоцу рамен"),
            Expense(title: "Отель Сибуя (3 ночи)", amount: 45000,
                    category: .accommodation, date: startDate),
            Expense(title: "Омамори в Сэнсо-дзи", amount: 800,
                    category: .shopping,
                    date: calendar.date(byAdding: .day, value: 1, to: startDate)!, notes: "Талисман на удачу"),
            Expense(title: "Мелон-пан", amount: 250,
                    category: .food,
                    date: calendar.date(byAdding: .day, value: 1, to: startDate)!, notes: "Из Асакусы"),
            Expense(title: "Пополнение Suica", amount: 3000,
                    category: .transport,
                    date: calendar.date(byAdding: .day, value: 1, to: startDate)!, notes: "Карта метро"),
            Expense(title: "Такояки в Дотонбори", amount: 600,
                    category: .food,
                    date: calendar.date(byAdding: .day, value: 8, to: startDate)!),
            Expense(title: "Набор матча Kit Kat", amount: 1200,
                    category: .shopping,
                    date: calendar.date(byAdding: .day, value: 2, to: startDate)!, notes: "Сувениры")
        ])
    }

    // MARK: - Journal

    private static func buildJournal(trip: Trip, startDate: Date, calendar: Calendar) {
        trip.journalEntries.append(contentsOf: [
            JournalEntry(
                date: startDate,
                title: "Первый день в Токио!",
                content: "Наконец-то прилетел в Нариту. Система поездов невероятно удобная. Перекрёсток Сибуя ночью завораживает \u{2014} сотни людей движутся в идеальной гармонии. Рамен в Ichiran \u{2014} лучший, что я пробовал. Это путешествие уже превосходит все ожидания.",
                mood: .amazing
            ),
            JournalEntry(
                date: calendar.date(byAdding: .day, value: 1, to: startDate)!,
                title: "Храмы и аниме",
                content: "Сэнсо-дзи в утреннем тумане \u{2014} волшебство. Дым благовоний, огромный фонарь у ворот Каминаримон. На улице Накамисэ столько вкусного. Акихабара днём \u{2014} перегрузка всех чувств в лучшем смысле.",
                mood: .happy
            )
        ])
    }
}
