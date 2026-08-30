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
    app.launch()

    // Use XCTAssert and related functions to verify your tests produce the correct results.
    // XCUIAutomation Documentation
    // https://developer.apple.com/documentation/xcuiautomation
  }

  @MainActor
  func testCompactPurchaseDatePickerStaysStableDuringRepeatedChanges() throws {
    let app = XCUIApplication()
    app.launch()
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

  private func openItemEditor(in app: XCUIApplication) {
    let firstItemButton = app.buttons["最初の愛用品を登録"]
    if firstItemButton.waitForExistence(timeout: 2) {
      firstItemButton.tap()
    } else {
      app.buttons["愛用品を追加"].tap()
    }
  }

  private func purchaseDateButton(in app: XCUIApplication) -> XCUIElement {
    app.buttons.matching(
      NSPredicate(format: "value MATCHES %@", "[0-9]{4}/[0-9]{2}/[0-9]{2}")
    ).firstMatch
  }

  private func selectFirstCalendarDay(in app: XCUIApplication) {
    let calendarDay = app.buttons.matching(
      NSPredicate(format: "label MATCHES %@", ".*day, .* [0-9]+$")
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
