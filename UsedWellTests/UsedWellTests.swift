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
    let oneYearLater = calendar.date(byAdding: .year, value: 1, to: current)!
    let expectedDays = calendar.dateComponents([.day], from: start, to: oneYearLater).day!
    #expect(
      item.extendedDailyCost(asOf: current, calendar: calendar) == 100_000 / Double(expectedDays))
  }
  @Test func completedValuesStayFixedAfterCompletion() {
    let completion = calendar.date(byAdding: .day, value: 100, to: start)!
    let muchLater = calendar.date(byAdding: .year, value: 10, to: completion)!
    let item = Item(
      name: "Watch", category: .watch, purchaseDate: start, purchasePrice: 20_000, targetMonths: 12,
      completedDate: completion)

    #expect(
      item.progress(asOf: completion, calendar: calendar)
        == item.progress(asOf: muchLater, calendar: calendar))
    #expect(
      item.currentDailyCost(asOf: completion, calendar: calendar)
        == item.currentDailyCost(asOf: muchLater, calendar: calendar))
    #expect(
      item.remainingText(asOf: completion, calendar: calendar)
        == item.remainingText(asOf: muchLater, calendar: calendar))
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
  @Test func remainingDurationUsesYearsAndMonths() {
    let item = Item(
      name: "Computer", category: .computer, purchaseDate: start, purchasePrice: 200_000,
      targetMonths: 26)
    #expect(item.remainingText(asOf: start, calendar: calendar) == "目標まであと約2年2か月")

    let overTarget = calendar.date(byAdding: .month, value: 40, to: start)!
    #expect(
      item.remainingText(asOf: overTarget, calendar: calendar)
        == "目標を約1年2か月超えて使えています")
  }

  @Test func detailedRemainingDurationUsesDaysNearTarget() {
    let item = Item(
      name: "Phone", category: .phone, purchaseDate: start, purchasePrice: 100_000, targetMonths: 1)
    let targetDate = item.targetDate(calendar: calendar)

    #expect(
      item.remainingText(asOf: targetDate, calendar: calendar, usesDayPrecision: true) == "今日が目標日です"
    )
    #expect(
      item.remainingText(
        asOf: calendar.date(byAdding: .day, value: -1, to: targetDate)!, calendar: calendar,
        usesDayPrecision: true) == "目標まであと1日")
    #expect(
      item.remainingText(
        asOf: calendar.date(byAdding: .day, value: -29, to: targetDate)!, calendar: calendar,
        usesDayPrecision: true) == "目標まであと29日")
    #expect(
      item.remainingText(
        asOf: calendar.date(byAdding: .day, value: 1, to: targetDate)!, calendar: calendar,
        usesDayPrecision: true) == "目標を1日超えて使えています")
    #expect(
      item.remainingText(
        asOf: calendar.date(byAdding: .day, value: 29, to: targetDate)!, calendar: calendar,
        usesDayPrecision: true) == "目標を29日超えて使えています")
  }

  @Test func detailedRemainingDurationUsesMonthsAtThirtyDays() {
    let item = Item(
      name: "Phone", category: .phone, purchaseDate: start, purchasePrice: 100_000, targetMonths: 3)
    let targetDate = item.targetDate(calendar: calendar)

    #expect(
      item.remainingText(
        asOf: calendar.date(byAdding: .day, value: -30, to: targetDate)!, calendar: calendar,
        usesDayPrecision: true) == "目標まであと約1か月")
    #expect(
      item.remainingText(
        asOf: calendar.date(byAdding: .day, value: 30, to: targetDate)!, calendar: calendar,
        usesDayPrecision: true) == "目標を約1か月超えて使えています")
  }
  @Test func targetDateAddsConfiguredMonths() {
    let item = Item(
      name: "Bag", category: .bag, purchaseDate: start, purchasePrice: 50_000, targetMonths: 38)
    #expect(item.targetDurationText == "3年2か月")
    #expect(
      item.targetDate(calendar: calendar) == calendar.date(byAdding: .month, value: 38, to: start))
  }

  @Test func notificationPlansIncludeFutureMilestones() {
    let item = notificationDetails(targetMonths: 10)
    let plans = NotificationPlanner.plans(for: item, after: start, calendar: calendar)
    let targetDate = calendar.date(byAdding: .month, value: 10, to: start)!
    let targetDays = calendar.dateComponents([.day], from: start, to: targetDate).day!
    let reviewDate = calendar.date(
      byAdding: .day, value: Int(ceil(Double(targetDays) * 0.9)), to: start)!

    #expect(plans.map(\.milestone) == [.review, .goal])
    #expect(plans.map(\.date) == [reviewDate, targetDate])
    #expect(plans[0].identifier.hasSuffix(".90"))
    #expect(plans[1].identifier.hasSuffix(".100"))
  }

  @Test func notificationPlansSkipPastMilestones() {
    let item = notificationDetails(targetMonths: 10)
    let targetDate = calendar.date(byAdding: .month, value: 10, to: start)!
    let targetDays = calendar.dateComponents([.day], from: start, to: targetDate).day!
    let afterReview = calendar.date(
      byAdding: .day, value: Int(ceil(Double(targetDays) * 0.9)), to: start)!

    let plans = NotificationPlanner.plans(
      for: item, after: calendar.date(byAdding: .day, value: 1, to: afterReview)!,
      calendar: calendar)

    #expect(plans.map(\.milestone) == [.goal])
    #expect(NotificationPlanner.plans(for: item, after: targetDate, calendar: calendar).isEmpty)
  }

  @Test func completedItemsHaveNoNotificationPlans() {
    let item = notificationDetails(targetMonths: 10, isCompleted: true)
    #expect(NotificationPlanner.plans(for: item, after: start, calendar: calendar).isEmpty)
  }

  private func notificationDetails(
    targetMonths: Int, isCompleted: Bool = false
  ) -> ItemNotificationDetails {
    ItemNotificationDetails(
      id: UUID(), name: "Phone", purchaseDate: start, targetMonths: targetMonths,
      isCompleted: isCompleted)
  }
}
