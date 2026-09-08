import Foundation
import Testing

@testable import UsedWell

@MainActor struct DateCalculationRefreshTests {
  private var calendar: Calendar {
    var value = Calendar(identifier: .gregorian)
    value.timeZone = TimeZone(secondsFromGMT: 0)!
    return value
  }

  @Test func referenceDayUpdatesStatusCostsDurationAndHomePriority() {
    let phone = Item(
      name: "Phone", category: .phone, purchaseDate: date(2026, 7, 25), purchasePrice: 3100,
      targetMonths: 1)
    let longer = Item(
      name: "Longer", category: .camera, purchaseDate: date(2026, 6, 27), purchasePrice: 6100,
      targetMonths: 2)
    let before = date(2026, 8, 21)
    let review = date(2026, 8, 22)
    let reordered = date(2026, 8, 23)
    let goal = date(2026, 8, 25)
    #expect(phone.status(asOf: before, calendar: calendar) == .stillUsing)
    #expect(phone.status(asOf: review, calendar: calendar) == .considerReplacing)
    #expect(phone.status(asOf: goal, calendar: calendar) == .goalAchieved)
    #expect(phone.progress(asOf: goal, calendar: calendar) == 1)
    #expect(phone.currentDailyCost(asOf: before, calendar: calendar) == 3100.0 / 27)
    #expect(phone.currentDailyCost(asOf: review, calendar: calendar) == 3100.0 / 28)
    #expect(
      phone.usageDurationText(asOf: before, calendar: calendar, locale: Locale(identifier: "en_US"))
        == "27 days")
    #expect(
      phone.usageDurationText(asOf: review, calendar: calendar, locale: Locale(identifier: "en_US"))
        == "28 days")
    #expect(
      Item.activeItemsForReview([phone, longer], asOf: before, calendar: calendar).first === longer)
    #expect(
      Item.activeItemsForReview([phone, longer], asOf: reordered, calendar: calendar).first
        === phone)
    phone.completedDate = review
    #expect(phone.currentDailyCost(asOf: goal, calendar: calendar) == 3100.0 / 28)
    #expect(phone.status(asOf: goal, calendar: calendar) == .considerReplacing)
    #expect(Item.activeItemsForReview([phone, longer], asOf: goal, calendar: calendar).count == 1)
  }

  private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day))!
  }
}
