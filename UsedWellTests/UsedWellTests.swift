import Foundation
import Testing

@testable import UsedWell

@MainActor struct UsedWellTests {
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
  }

  private var start: Date { date(1970, 1, 1) }

  @Test func purchasePriceValidationUsesAllowedRange() {
    #expect(PurchasePrice.validationMessage(for: nil) != nil)
    #expect(PurchasePrice.validationMessage(for: 0) != nil)
    #expect(PurchasePrice.validationMessage(for: 1) == nil)
    #expect(PurchasePrice.validationMessage(for: 100_000) == nil)
    #expect(PurchasePrice.validationMessage(for: 9_999_999) == nil)
    #expect(PurchasePrice.validationMessage(for: 10_000_000) != nil)
  }

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

    let scheduledReviewDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: reviewDate)!
    let scheduledTargetDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: targetDate)!

    #expect(plans.map(\.milestone) == [.review, .goal])
    #expect(plans.map(\.date) == [scheduledReviewDate, scheduledTargetDate])
    #expect(plans.allSatisfy { calendar.component(.hour, from: $0.date) == 9 })
    #expect(plans.allSatisfy { calendar.component(.minute, from: $0.date) == 0 })
    #expect(plans[0].identifier.hasSuffix(".90"))
    #expect(plans[1].identifier.hasSuffix(".100"))
  }

  @Test func notificationPlansSkipPastMilestones() {
    let item = notificationDetails(targetMonths: 10)
    let targetDate = calendar.date(byAdding: .month, value: 10, to: start)!
    let targetDays = calendar.dateComponents([.day], from: start, to: targetDate).day!
    let afterReview = calendar.date(
      byAdding: .day, value: Int(ceil(Double(targetDays) * 0.9)), to: start)!
    let afterScheduledReview = calendar.date(
      bySettingHour: 9, minute: 1, second: 0, of: afterReview)!

    let plans = NotificationPlanner.plans(
      for: item, after: afterScheduledReview,
      calendar: calendar)

    #expect(plans.map(\.milestone) == [.goal])
    #expect(
      NotificationPlanner.plans(
        for: item,
        after: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: targetDate)!,
        calendar: calendar
      ).isEmpty)
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

  private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
  }
}

@MainActor struct CalendarSemanticsTests {
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
  }

  @Test func targetDayUsesCalendarDatesAtEveryTimeOfDay() {
    let purchaseDate = date(2026, 7, 25, hour: 17)
    let item = Item(
      name: "Phone", category: .phone, purchaseDate: purchaseDate, purchasePrice: 120_000,
      targetMonths: 1)
    let targetDay = date(2026, 8, 25)

    #expect(item.targetDate(calendar: calendar) == targetDay)
    for hour in [0, 9, 12, 23] {
      let asOf = date(2026, 8, 25, hour: hour)
      #expect(
        item.elapsedDays(asOf: asOf, calendar: calendar) == item.targetDays(calendar: calendar))
      #expect(item.progress(asOf: asOf, calendar: calendar) == 1)
      #expect(item.status(asOf: asOf, calendar: calendar) == .goalAchieved)
      #expect(item.remainingText(asOf: asOf, calendar: calendar) == "今日が目標日です")
      #expect(item.usageDurationText(asOf: asOf, calendar: calendar) == "1か月")
      #expect(
        item.currentDailyCost(asOf: asOf, calendar: calendar)
          == item.targetDailyCost(calendar: calendar))
    }
  }

  @Test func progressHasConsistentReviewGoalAndOverGoalBoundaries() {
    let purchaseDate = date(2026, 7, 25, hour: 17)
    let item = Item(
      name: "Phone", category: .phone, purchaseDate: purchaseDate, purchasePrice: 120_000,
      targetMonths: 1)
    let reviewDay = calendar.date(
      byAdding: .day, value: Int(ceil(Double(item.targetDays(calendar: calendar)) * 0.9)),
      to: item.purchaseDay(calendar: calendar))!
    let beforeReview = calendar.date(byAdding: .day, value: -1, to: reviewDay)!
    let afterTarget = calendar.date(
      byAdding: .day, value: 1, to: item.targetDate(calendar: calendar))!

    #expect(item.progress(asOf: beforeReview, calendar: calendar) < 0.9)
    #expect(item.status(asOf: beforeReview, calendar: calendar) == .stillUsing)
    #expect(item.progress(asOf: reviewDay, calendar: calendar) >= 0.9)
    #expect(item.progress(asOf: reviewDay, calendar: calendar) < 1)
    #expect(item.status(asOf: reviewDay, calendar: calendar) == .considerReplacing)
    #expect(item.progress(asOf: item.targetDate(calendar: calendar), calendar: calendar) == 1)
    #expect(item.progress(asOf: afterTarget, calendar: calendar) > 1)
    #expect(item.status(asOf: afterTarget, calendar: calendar) == .goalAchieved)
  }

  @Test func targetDatesHandleMonthEndYearBoundaryAndLeapYears() {
    assertTargetDate(date(2025, 1, 31, hour: 18), is: date(2025, 2, 28))
    assertTargetDate(date(2024, 1, 31, hour: 18), is: date(2024, 2, 29))
    assertTargetDate(date(2025, 12, 31, hour: 18), is: date(2026, 1, 31))
  }

  @Test func targetDayRemainsStableAcrossDaylightSavingTime() {
    var daylightSavingCalendar = Calendar(identifier: .gregorian)
    daylightSavingCalendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    let purchaseDate = daylightSavingCalendar.date(
      from: DateComponents(year: 2026, month: 3, day: 8, hour: 17))!
    let targetDate = daylightSavingCalendar.date(
      from: DateComponents(year: 2026, month: 4, day: 8))!
    let item = Item(
      name: "Camera", category: .camera, purchaseDate: purchaseDate, purchasePrice: 100_000,
      targetMonths: 1)

    #expect(item.targetDate(calendar: daylightSavingCalendar) == targetDate)
    #expect(item.progress(asOf: targetDate, calendar: daylightSavingCalendar) == 1)
    #expect(item.status(asOf: targetDate, calendar: daylightSavingCalendar) == .goalAchieved)
  }

  @Test func notificationPlansUseLocalNineAMAndSkipPastMilestones() {
    let purchaseDate = date(2026, 7, 25, hour: 22)
    let item = ItemNotificationDetails(
      id: UUID(), name: "Phone", purchaseDate: purchaseDate, targetMonths: 1, isCompleted: false)
    let plans = NotificationPlanner.plans(for: item, after: date(2026, 7, 25), calendar: calendar)

    #expect(plans.count == 2)
    #expect(plans.allSatisfy { calendar.component(.hour, from: $0.date) == 9 })
    #expect(plans.allSatisfy { calendar.component(.minute, from: $0.date) == 0 })
    let review = plans.first(where: { $0.milestone == .review })!
    #expect(
      NotificationPlanner.plans(
        for: item, after: calendar.date(byAdding: .minute, value: 1, to: review.date)!,
        calendar: calendar
      ).map(\.milestone) == [.goal])
  }

  @Test func duplicateLegacyNotificationIDsAreRepairedToUniqueValues() {
    let duplicateID = UUID()
    let items = (1...3).map { index in
      let item = Item(
        name: "Item \(index)", category: .other, purchaseDate: date(1970, 1, 1),
        purchasePrice: index, targetMonths: 1)
      item.notificationID = duplicateID
      return item
    }

    let repair = Item.repairDuplicateNotificationIDs(in: items)

    #expect(repair.staleIDs == [duplicateID])
    #expect(repair.repairedItems.count == 3)
    #expect(Set(items.map(\.notificationID)).count == 3)
    #expect(!items.map(\.notificationID).contains(duplicateID))
  }

  private func assertTargetDate(_ purchaseDate: Date, is expectedTargetDate: Date) {
    let item = Item(
      name: "Calendar", category: .other, purchaseDate: purchaseDate, purchasePrice: 1,
      targetMonths: 1)
    #expect(item.targetDate(calendar: calendar) == expectedTargetDate)
    #expect(item.progress(asOf: expectedTargetDate, calendar: calendar) == 1)
  }

  private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
  }
}
