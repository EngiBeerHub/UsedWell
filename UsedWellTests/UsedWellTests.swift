import Foundation
import Testing

@testable import UsedWell

@MainActor struct UsedWellTests {
  private let calendar = Calendar(identifier: .gregorian)
  private let start = Date(timeIntervalSince1970: 0)

  @Test func progressStatusBoundaries() {
    let item = Item(
      name: "Phone", category: .phone, purchaseDate: start, purchasePrice: 120_000, targetMonths: 1)
    let days = item.targetDays(calendar: calendar)
    let before = calendar.date(byAdding: .day, value: Int(Double(days) * 0.89), to: start)!
    let review = calendar.date(byAdding: .day, value: Int(ceil(Double(days) * 0.9)), to: start)!
    #expect(item.status(asOf: before, calendar: calendar) == .stillUsing)
    #expect(item.status(asOf: review, calendar: calendar) == .considerReplacing)
    #expect(
      item.status(asOf: item.targetDate(calendar: calendar), calendar: calendar) == .goalAchieved)
  }
  @Test func dailyCostsDecreaseWithLongerUse() {
    let item = Item(
      name: "Camera", category: .camera, purchaseDate: start, purchasePrice: 100_000,
      targetMonths: 24)
    let current = calendar.date(byAdding: .month, value: 12, to: start)!
    #expect(
      item.currentDailyCost(asOf: current, calendar: calendar)
        > item.targetDailyCost(calendar: calendar))
    #expect(item.targetDailyCost(calendar: calendar) > item.extendedDailyCost(calendar: calendar))
  }
  @Test func completedItemUsesCompletionDateForCost() {
    let completion = calendar.date(byAdding: .day, value: 100, to: start)!
    let item = Item(
      name: "Bag", category: .bag, purchaseDate: start, purchasePrice: 10_000, targetMonths: 12,
      completedDate: completion)
    #expect(item.elapsedDays(asOf: .now, calendar: calendar) == 100)
    #expect(item.currentDailyCost(asOf: .now, calendar: calendar) == 100)
  }
  @Test func statusPriorityOrder() {
    #expect(ReplacementStatus.goalAchieved > .considerReplacing)
    #expect(ReplacementStatus.considerReplacing > .stillUsing)
  }
}
