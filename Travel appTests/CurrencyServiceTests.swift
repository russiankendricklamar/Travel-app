import XCTest
@testable import Travel_app

final class CurrencyServiceTests: XCTestCase {
    let svc = CurrencyService.shared

    func testFormatRubBasic() {
        let result = svc.format(5000, currency: "RUB")
        XCTAssertTrue(result.contains("5"))
        XCTAssertTrue(result.contains("000") || result.contains(" 000"))
        XCTAssertTrue(result.contains("\u{20BD}"))
    }

    func testFormatRubZero() {
        let result = svc.format(0, currency: "RUB")
        XCTAssertTrue(result.contains("\u{20BD}"))
        XCTAssertTrue(result.contains("0"))
    }

    func testFormatUSD() {
        let result = svc.format(10.50, currency: "USD")
        XCTAssertTrue(result.contains("$"))
    }

    func testConvertSameCurrency() {
        let result = svc.convert(100, from: "RUB", to: "RUB")
        XCTAssertEqual(result, 100, accuracy: 0.01)
    }

    func testConvertRubToOther() {
        let result = svc.convert(1000, from: "RUB", to: "USD")
        XCTAssertTrue(result > 0, "Conversion should produce positive result")
        XCTAssertTrue(result < 1000, "1000 RUB should be less than 1000 USD")
    }

    func testSupportedCurrencies() {
        XCTAssertEqual(CurrencyService.supportedCurrencies.count, 4)
        XCTAssertTrue(CurrencyService.supportedCurrencies.contains("RUB"))
        XCTAssertTrue(CurrencyService.supportedCurrencies.contains("USD"))
        XCTAssertTrue(CurrencyService.supportedCurrencies.contains("JPY"))
        XCTAssertTrue(CurrencyService.supportedCurrencies.contains("CNY"))
    }

    func testSymbolsExist() {
        for currency in CurrencyService.supportedCurrencies {
            XCTAssertNotNil(CurrencyService.symbols[currency], "Symbol missing for \(currency)")
        }
    }
}
