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
  func testPurchaseDatePickerLayoutStaysStableDuringRepeatedWheelChanges() throws {
    let app = XCUIApplication()
    app.launch()

    let firstItemButton = app.buttons["最初の愛用品を登録"]
    if firstItemButton.waitForExistence(timeout: 2) {
      firstItemButton.tap()
    } else {
      app.buttons["愛用品を追加"].tap()
    }

    let purchaseDateButton = app.buttons["purchase-date-picker"]
    XCTAssertTrue(purchaseDateButton.waitForExistence(timeout: 2))
    let initialPurchaseDateLabel = purchaseDateButton.label
    purchaseDateButton.tap()

    let inlineDatePicker = app.datePickers["inline-purchase-date-picker"]
    XCTAssertTrue(inlineDatePicker.waitForExistence(timeout: 2))

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

    yearMonthButton.tap()
    monthWheel.swipeUp()
    yearWheel.swipeUp()
    app.buttons["DatePicker.Hide"].tap()
    XCTAssertEqual(yearMonthButton.frame.minY, calendarHeaderY, accuracy: 1)
    addScreenshot(named: "Calendar After Second Stress Cycle", app: app)

    let calendarDay = app.buttons.matching(
      NSPredicate(format: "label MATCHES %@", ".*day, .* [0-9]+$")
    ).firstMatch
    XCTAssertTrue(calendarDay.waitForExistence(timeout: 2))
    calendarDay.tap()
    XCTAssertEqual(yearMonthButton.frame.minY, calendarHeaderY, accuracy: 1)
    XCTAssertNotEqual(purchaseDateButton.label, initialPurchaseDateLabel)

    purchaseDateButton.tap()
    XCTAssertFalse(inlineDatePicker.waitForExistence(timeout: 1))
  }

  @MainActor
  func testEditPurchaseDatePickerLayoutStaysStableAfterDateSelections() throws {
    let app = XCUIApplication()
    app.launch()

    createItem(named: "Date Picker Edit Test", app: app)

    let itemButton = app.buttons.matching(
      NSPredicate(format: "label BEGINSWITH %@", "Date Picker Edit Test")
    ).firstMatch
    XCTAssertTrue(itemButton.waitForExistence(timeout: 2))
    itemButton.tap()

    let editButton = app.buttons["編集"]
    XCTAssertTrue(editButton.waitForExistence(timeout: 2))
    editButton.tap()

    let purchaseDateButton = app.buttons["purchase-date-picker"]
    XCTAssertTrue(purchaseDateButton.waitForExistence(timeout: 2))
    purchaseDateButton.tap()

    let yearMonthButton = app.buttons["DatePicker.Show"]
    XCTAssertTrue(yearMonthButton.waitForExistence(timeout: 2))
    let calendarHeaderY = yearMonthButton.frame.minY

    app.buttons["DatePicker.PreviousMonth"].tap()
    selectCalendarDay(app: app)
    XCTAssertEqual(yearMonthButton.frame.minY, calendarHeaderY, accuracy: 1)
    addScreenshot(named: "Edit Calendar After Previous Month Selection", app: app)

    yearMonthButton.tap()
    let yearWheel = app.pickerWheels.element(boundBy: 0)
    let monthWheel = app.pickerWheels.element(boundBy: 1)
    XCTAssertTrue(yearWheel.waitForExistence(timeout: 2))
    XCTAssertTrue(monthWheel.exists)
    let wheelY = monthWheel.frame.minY
    monthWheel.swipeDown()
    yearWheel.swipeDown()
    XCTAssertEqual(monthWheel.frame.minY, wheelY, accuracy: 1)
    app.buttons["DatePicker.Hide"].tap()
    XCTAssertEqual(yearMonthButton.frame.minY, calendarHeaderY, accuracy: 1)

    selectCalendarDay(app: app)
    XCTAssertEqual(yearMonthButton.frame.minY, calendarHeaderY, accuracy: 1)
    addScreenshot(named: "Edit Calendar After Year Month Selection", app: app)

    purchaseDateButton.tap()
    XCTAssertFalse(app.datePickers["inline-purchase-date-picker"].waitForExistence(timeout: 1))
    purchaseDateButton.tap()
    XCTAssertTrue(yearMonthButton.waitForExistence(timeout: 2))
    XCTAssertEqual(yearMonthButton.frame.minY, calendarHeaderY, accuracy: 1)

    selectCalendarDay(app: app)
    XCTAssertEqual(yearMonthButton.frame.minY, calendarHeaderY, accuracy: 1)
    purchaseDateButton.tap()
    app.buttons["save-item"].tap()

    XCTAssertTrue(editButton.waitForExistence(timeout: 2))
  }

  @MainActor
  private func createItem(named name: String, app: XCUIApplication) {
    let firstItemButton = app.buttons["最初の愛用品を登録"]
    if firstItemButton.waitForExistence(timeout: 2) {
      firstItemButton.tap()
    } else {
      app.buttons["愛用品を追加"].tap()
    }

    let nameField = app.textFields["item-name"]
    XCTAssertTrue(nameField.waitForExistence(timeout: 2))
    nameField.tap()
    nameField.typeText(name)

    let priceField = app.textFields["purchase-price"]
    priceField.tap()
    priceField.typeText("1000")
    app.buttons["save-item"].tap()

    let laterButton = app.buttons["後で"]
    if laterButton.waitForExistence(timeout: 2) {
      laterButton.tap()
    }
  }

  private func selectCalendarDay(app: XCUIApplication) {
    let calendarDays = app.buttons.matching(
      NSPredicate(format: "label MATCHES %@", ".*day, .* [0-9]+$")
    )
    XCTAssertGreaterThan(calendarDays.count, 0)
    let calendarDay = calendarDays.element(boundBy: min(7, calendarDays.count - 1))
    XCTAssertTrue(calendarDay.waitForExistence(timeout: 2))
    calendarDay.tap()
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
