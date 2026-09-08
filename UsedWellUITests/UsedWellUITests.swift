//
//  UsedWellUITests.swift
//  UsedWellUITests
//
//  Created by RyosukeSeki on 2026/08/23.
//

import XCTest

final class UsedWellUITests: XCTestCase {

  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.

    // In UI tests it is usually best to stop immediately when a failure occurs.
    continueAfterFailure = false

    // Set any initial state required before each UI test here.
  }

  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }

  @MainActor
  func testExample() throws {
    // UI tests must launch the application that they test.
    let app = XCUIApplication()
    app.launchArguments = ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
    app.launchEnvironment["USEDWELL_FIXTURE"] = "empty"
    app.launch()

    // Use XCTAssert and related functions to verify your tests produce the correct results.
    // XCUIAutomation Documentation
    // https://developer.apple.com/documentation/xcuiautomation
  }

  @MainActor
  func testCompactPurchaseDatePickerStaysStableDuringRepeatedChanges() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
    launchJapaneseFixture(app)
    openItemEditor(in: app)

    let purchaseDatePicker = app.datePickers["purchase-date-picker"]
    XCTAssertTrue(purchaseDatePicker.waitForExistence(timeout: 2))
    let purchaseDateButton = purchaseDateButton(in: app)
    XCTAssertTrue(purchaseDateButton.waitForExistence(timeout: 2))
    let initialPurchaseDateValue = purchaseDateButton.value as? String
    let purchaseDateFrame = purchaseDatePicker.frame
    purchaseDatePicker.tap()

    let yearMonthButton = app.buttons["DatePicker.Show"]
    XCTAssertTrue(yearMonthButton.waitForExistence(timeout: 2))
    let calendarHeaderY = yearMonthButton.frame.minY
    yearMonthButton.tap()

    let yearWheel = app.pickerWheels.element(boundBy: 0)
    let monthWheel = app.pickerWheels.element(boundBy: 1)
    XCTAssertTrue(yearWheel.waitForExistence(timeout: 2))
    XCTAssertTrue(monthWheel.exists)
    let wheelY = monthWheel.frame.minY
    addScreenshot(named: "Year-Month Selector Before Stress", app: app)

    for _ in 0..<6 {
      monthWheel.swipeDown()
      XCTAssertEqual(monthWheel.frame.minY, wheelY, accuracy: 1)
    }
    yearWheel.swipeDown()
    XCTAssertEqual(monthWheel.frame.minY, wheelY, accuracy: 1)
    addScreenshot(named: "Year-Month Selector After Stress", app: app)

    app.buttons["DatePicker.Hide"].tap()
    XCTAssertEqual(yearMonthButton.frame.minY, calendarHeaderY, accuracy: 1)
    addScreenshot(named: "Calendar After First Stress Cycle", app: app)
    dismissCompactDatePicker(in: app)
    assertFrame(of: purchaseDatePicker, equals: purchaseDateFrame)

    purchaseDatePicker.tap()
    XCTAssertTrue(yearMonthButton.waitForExistence(timeout: 2))
    yearMonthButton.tap()
    XCTAssertTrue(monthWheel.waitForExistence(timeout: 2))
    monthWheel.swipeUp()
    yearWheel.swipeUp()
    app.buttons["DatePicker.Hide"].tap()
    XCTAssertEqual(yearMonthButton.frame.minY, calendarHeaderY, accuracy: 1)
    addScreenshot(named: "Calendar After Second Stress Cycle", app: app)
    dismissCompactDatePicker(in: app)
    assertFrame(of: purchaseDatePicker, equals: purchaseDateFrame)

    purchaseDatePicker.tap()
    selectFirstCalendarDay(in: app)
    dismissCompactDatePicker(in: app)
    XCTAssertTrue(purchaseDateButton.waitForExistence(timeout: 2))
    assertFrame(of: purchaseDatePicker, equals: purchaseDateFrame)
    XCTAssertNotEqual(purchaseDateButton.value as? String, initialPurchaseDateValue)
  }

  @MainActor func testHomeReviewOrderValuesAndNavigation() {
    let app = launchHomeFixture("home-review")
    let featured = homeFeatured(app)
    XCTAssertTrue(featured.waitForExistence(timeout: 5))
    for value in [
      "iPhone 15 Pro", "2 years 11 months", "Thinking about replacing it", "99%", "$148 per day"
    ] {
      XCTAssertTrue(featured.label.contains(value), featured.label)
    }
    captureHome("en-US-home-review", app)
    let names = ["iPhone 15 Pro", "Review Camera", "MacBook Air", "Leather bag"]
    for name in names {
      let row = homeRegular(name, app)
      revealHome(row, app)
      XCTAssertTrue(row.exists)
      // Compare document order, including rows that began below the viewport.
      let rows = app.buttons.matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "regular-item-"))
      let visibleNames = rows.allElementsBoundByIndex.map(\.label)
      let indices = names.compactMap { name in visibleNames.firstIndex { $0.hasPrefix(name) } }
      XCTAssertEqual(indices, indices.sorted())
    }
    let phone = homeRegular("iPhone 15 Pro", app)
    for _ in 0..<8 {
      if featured.isHittable { break }
      app.swipeDown()
    }
    featured.tap()
    XCTAssertTrue(app.buttons["edit-item"].waitForExistence(timeout: 3))
    app.navigationBars.buttons.firstMatch.tap()
    revealHome(phone, app)
    phone.tap()
    XCTAssertTrue(app.buttons["edit-item"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["Time owned, 2 years 11 months"].exists)
    XCTAssertTrue(app.staticTexts["99%"].exists)
    app.navigationBars.buttons.firstMatch.tap()
    let history = app.buttons["Past Items"]
    revealHome(history, app)
    history.tap()
    XCTAssertTrue(
      app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Past Watch")).firstMatch
        .exists)
  }

  @MainActor func testHomeOverGoalAndNewItemValues() {
    for (fixture, duration, percentage, cost) in [
      ("home-over", "4 years 0 months", "133%", "$109 per day"),
      ("home-new", "0 days", "0%", "$159,800 per day")
    ] {
      let app = launchHomeFixture(fixture)
      let featured = homeFeatured(app)
      XCTAssertTrue(featured.waitForExistence(timeout: 5))
      for value in [duration, percentage, cost] {
        XCTAssertTrue(featured.label.contains(value), featured.label)
      }
      if fixture == "home-over" {
        XCTAssertTrue(featured.label.contains("Goal reached"))
      }
      captureHome("en-US-\(fixture)", app)
      let row = homeRegular("iPhone 15 Pro", app)
      revealHome(row, app)
      XCTAssertTrue(row.exists)
      XCTAssertTrue(row.label.contains(duration))
      row.tap()
      XCTAssertTrue(app.buttons["edit-item"].waitForExistence(timeout: 3))
      revealHome(app.buttons["complete-item"], app)
      XCTAssertTrue(app.buttons["complete-item"].exists)
      app.terminate()
    }
  }

  @MainActor func testHomeLongNameAtAccessibilitySize() {
    let app = launchHomeFixture("home-long", accessibility: true)
    let featured = homeFeatured(app)
    XCTAssertTrue(featured.waitForExistence(timeout: 5))
    XCTAssertTrue(featured.label.contains("travel and family photographs"))
    XCTAssertTrue(featured.label.contains("12 years 11 months"))
    captureHome("en-US-home-accessibility-top", app)
    app.swipeUp()
    captureHome("en-US-home-accessibility-context", app)
    let history = app.buttons["Past Items"]
    revealHome(history, app)
    XCTAssertTrue(history.isHittable)
    captureHome("en-US-home-accessibility-bottom", app)
    history.tap()
    XCTAssertTrue(app.navigationBars["Past Items"].waitForExistence(timeout: 3))
  }

  @MainActor func testHomeToolbarAddAndJapaneseHierarchy() {
    let app = launchHomeFixture("home-new", japanese: true)
    let featured = homeFeatured(app)
    XCTAssertTrue(featured.waitForExistence(timeout: 5))
    XCTAssertTrue(featured.label.contains("0日"))
    XCTAssertTrue(featured.label.contains("まだ使いたい"))
    app.buttons["add-item"].tap()
    XCTAssertTrue(app.textFields["item-name"].waitForExistence(timeout: 3))
    app.textFields["item-name"].tap()
    app.textFields["item-name"].typeText("Home Added")
    app.textFields["purchase-price"].tap()
    app.textFields["purchase-price"].typeText("12000")
    app.buttons["save-item"].tap()
    let later = app.alerts.buttons["後で"]
    if later.waitForExistence(timeout: 2) { later.tap() }
    let added = homeRegular("Home Added", app)
    revealHome(added, app)
    XCTAssertTrue(added.exists)
    captureHome("ja-JP-home-added", app)
  }

  @MainActor private func launchJapaneseFixture(_ app: XCUIApplication) {
    app.launchEnvironment["USEDWELL_FIXTURE"] = "empty"
    app.launch()
  }

  private func openItemEditor(in app: XCUIApplication) {
    let firstItemButton = app.buttons["add-first-item"]
    if firstItemButton.waitForExistence(timeout: 2) {
      firstItemButton.tap()
    } else {
      app.buttons["add-item"].tap()
    }
  }

  private func purchaseDateButton(in app: XCUIApplication) -> XCUIElement {
    app.buttons.matching(
      NSPredicate(format: "value MATCHES %@", "[0-9]{4}/[0-9]{2}/[0-9]{2}")
    ).firstMatch
  }

  private func selectFirstCalendarDay(in app: XCUIApplication) {
    let calendarDay = app.buttons.matching(
      NSPredicate(format: "label MATCHES %@", "[0-9]+月[0-9]+日 .*曜日")
    ).firstMatch
    XCTAssertTrue(calendarDay.waitForExistence(timeout: 2))
    calendarDay.tap()
  }

  private func assertFrame(of element: XCUIElement, equals frame: CGRect) {
    XCTAssertEqual(element.frame.minY, frame.minY, accuracy: 1)
    XCTAssertEqual(element.frame.height, frame.height, accuracy: 1)
  }

  private func dismissCompactDatePicker(in app: XCUIApplication) {
    app.navigationBars.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
  }

  private func addScreenshot(named name: String, app: XCUIApplication) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  @MainActor
  func testLaunchPerformance() throws {
    // This measures how long it takes to launch your application.
    measure(metrics: [XCTApplicationLaunchMetric()]) {
      XCUIApplication().launch()
    }
  }
}

extension UsedWellUITests {
  @MainActor private func launchHomeFixture(
    _ fixture: String, japanese: Bool = false, accessibility: Bool = false
  ) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = [
      "-AppleLanguages", japanese ? "(ja)" : "(en)",
      "-AppleLocale", japanese ? "ja_JP" : "en_US",
      "-lastAcknowledgedRegion", japanese ? "JP" : "US"
    ]
    if accessibility {
      app.launchArguments += [
        "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
      ]
    }
    app.launchEnvironment["USEDWELL_FIXTURE"] = fixture
    app.launchEnvironment["USEDWELL_RESET_PREFERENCES"] = "1"
    app.launch()
    return app
  }

  @MainActor private func homeFeatured(_ app: XCUIApplication) -> XCUIElement {
    app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "featured-item"))
      .firstMatch
  }

  @MainActor private func homeRegular(_ name: String, _ app: XCUIApplication) -> XCUIElement {
    app.buttons.matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "regular-item-", name)
    ).firstMatch
  }

  @MainActor private func revealHome(_ element: XCUIElement, _ app: XCUIApplication) {
    for _ in 0..<20 {
      if element.isHittable { return }
      app.swipeUp()
    }
  }

  @MainActor private func captureHome(_ name: String, _ app: XCUIApplication) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

}
