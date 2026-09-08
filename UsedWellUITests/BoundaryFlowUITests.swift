import XCTest

final class BoundaryFlowUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  @MainActor func testItemSaveFailureKeepsInputAndRetrySavesOnce() {
    let app = launch(fixture: "empty", failedSave: 1)
    app.buttons["add-first-item"].tap()
    app.textFields["item-name"].tap()
    app.textFields["item-name"].typeText("Retry Camera")
    app.textFields["purchase-price"].tap()
    app.textFields["purchase-price"].typeText("3100")
    app.buttons["save-item"].tap()
    acknowledgeSaveFailure(app)
    XCTAssertEqual(app.textFields["item-name"].value as? String, "Retry Camera")
    XCTAssertTrue(app.textFields["purchase-price"].exists)
    capture("item-save-failure", app)
    app.buttons["save-item"].tap()
    dismissPermission(app)
    XCTAssertTrue(itemButton("Retry Camera", app).waitForExistence(timeout: 3))
    itemButton("Retry Camera", app).tap()
    XCTAssertTrue(app.buttons["edit-item"].waitForExistence(timeout: 3))
    capture("item-save-retry", app)
  }

  @MainActor func testItemEditFailureDoesNotChangeDetailUntilRetry() {
    let app = launch(fixture: "screenshots", failedSave: 1)
    openPhone(app)
    app.buttons["edit-item"].tap()
    let name = app.textFields["item-name"]
    name.tap()
    name.typeText(" revised")
    let draft = name.value as? String
    app.buttons["save-item"].tap()
    acknowledgeSaveFailure(app)
    XCTAssertEqual(name.value as? String, draft)
    app.buttons["Cancel"].tap()
    XCTAssertTrue(app.staticTexts["iPhone 15 Pro"].waitForExistence(timeout: 3))
    app.buttons["edit-item"].tap()
    XCTAssertEqual(name.value as? String, "iPhone 15 Pro")
    name.tap()
    name.typeText(" revised")
    let retried = name.value as? String
    app.buttons["save-item"].tap()
    XCTAssertTrue(app.staticTexts[retried ?? ""].waitForExistence(timeout: 3))
  }

  @MainActor func testNoteSaveFailureKeepsBodyAndRetryPersists() {
    let app = launch(fixture: "screenshots", failedSave: 1)
    openPhone(app)
    reveal(app.buttons["add-usage-note"], app)
    app.buttons["add-usage-note"].tap()
    let text = app.textViews["usage-note-text"]
    XCTAssertTrue(text.waitForExistence(timeout: 3))
    text.tap()
    text.typeText("Keep this draft for retry")
    app.buttons["save-usage-note"].tap()
    acknowledgeSaveFailure(app)
    XCTAssertTrue((text.value as? String)?.contains("Keep this draft for retry") == true)
    capture("note-save-failure", app)
    app.buttons["save-usage-note"].tap()
    let row = app.buttons.matching(
      NSPredicate(format: "label CONTAINS %@", "Keep this draft for retry")
    ).firstMatch
    reveal(row, app)
    row.tap()
    XCTAssertTrue(app.textViews["usage-note-text"].waitForExistence(timeout: 3))
    XCTAssertTrue(
      (app.textViews["usage-note-text"].value as? String)?.contains("Keep this draft for retry")
        == true)
  }

  @MainActor func testNoteDeleteFailureRetainsEditorAndCanRetry() {
    let app = launch(fixture: "screenshots", failedSave: 1)
    openPhone(app)
    let row = app.buttons["usage-note-row"].firstMatch
    reveal(row, app)
    row.tap()
    let body = app.textViews["usage-note-text"].value as? String
    app.buttons["delete-usage-note"].tap()
    app.alerts.buttons["Delete"].tap()
    acknowledgeSaveFailure(app)
    XCTAssertEqual(app.textViews["usage-note-text"].value as? String, body)
    app.buttons["delete-usage-note"].tap()
    app.alerts.buttons["Delete"].tap()
    XCTAssertTrue(app.buttons["edit-item"].waitForExistence(timeout: 3))
    XCTAssertFalse(
      app.buttons.matching(NSPredicate(format: "label CONTAINS %@", body ?? "")).firstMatch.exists)
  }

  @MainActor func testCompletionSaveFailureStaysActiveUntilRetry() {
    let app = launch(fixture: "screenshots", failedSave: 1)
    openPhone(app)
    complete(app)
    acknowledgeSaveFailure(app)
    XCTAssertTrue(app.buttons["edit-item"].exists)
    XCTAssertFalse(app.alerts["Well Used"].exists)
    reveal(app.buttons["complete-item"], app)
    complete(app)
    XCTAssertTrue(app.alerts.buttons["Done"].waitForExistence(timeout: 3))
    app.alerts.buttons["Done"].tap()
    reveal(app.buttons["Past Items"], app)
    app.buttons["Past Items"].tap()
    XCTAssertTrue(itemButton("iPhone 15 Pro", app).waitForExistence(timeout: 3))
  }

  @MainActor func testDeleteFailurePreservesDetailAndNotesUntilRetry() {
    let app = launch(fixture: "screenshots", failedSave: 1)
    openPhone(app)
    deleteItem(app)
    acknowledgeSaveFailure(app)
    XCTAssertTrue(app.buttons["edit-item"].exists)
    reveal(app.buttons["usage-note-row"].firstMatch, app, upward: false)
    XCTAssertTrue(app.buttons["usage-note-row"].firstMatch.exists)
    deleteItem(app)
    XCTAssertTrue(app.buttons["add-item"].waitForExistence(timeout: 3))
    XCTAssertFalse(itemButton("iPhone 15 Pro", app).exists)
  }

  @MainActor func testDayChangeRefreshesHomePriorityAndOpenDetail() {
    let app = launch(fixture: "day-boundary")
    XCTAssertTrue(
      app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "featured-item"))
        .firstMatch.label.contains("Long Goal"))
    app.buttons["advance-day"].tap()
    app.buttons["advance-day"].tap()
    XCTAssertTrue(
      app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "featured-item"))
        .firstMatch.label.contains("Boundary Phone"))
    itemButton("Boundary Phone", app).tap()
    XCTAssertTrue(app.staticTexts["Time owned, 29 days"].waitForExistence(timeout: 3))
    app.buttons["advance-day"].tap()
    XCTAssertTrue(app.staticTexts["Time owned, 30 days"].waitForExistence(timeout: 3))
    app.buttons["advance-day"].tap()
    XCTAssertTrue(app.staticTexts["Goal reached"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["100%"].exists)
    XCTAssertTrue(app.staticTexts["Time owned, 1 month"].exists)
    capture("detail-day-boundary", app)
  }

  @MainActor func testForegroundRefreshesDetailWithoutResettingDraft() {
    let app = launch(fixture: "day-boundary")
    itemButton("Boundary Phone", app).tap()
    XCTAssertTrue(app.staticTexts["Time owned, 27 days"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["Now, $115"].exists)
    app.buttons["advance-unobserved-day"].tap()
    XCTAssertTrue(app.staticTexts["Time owned, 27 days"].exists)
    XCUIDevice.shared.press(.home)
    app.activate()
    XCTAssertTrue(app.staticTexts["Time owned, 28 days"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Now, $111"].exists)
    XCTAssertTrue(app.staticTexts["Thinking about replacing it"].exists)
    app.buttons["edit-item"].tap()
    let name = app.textFields["item-name"]
    name.tap()
    name.typeText(" retained draft")
    let draft = name.value as? String
    XCUIDevice.shared.press(.home)
    app.activate()
    XCTAssertEqual(name.value as? String, draft)
  }

  @MainActor private func acknowledgeSaveFailure(_ app: XCUIApplication) {
    XCTAssertTrue(
      app.alerts.staticTexts[
        "Could not save your changes. Please try again."
      ].waitForExistence(timeout: 3))
    capture("save-failure-alert", app)
    app.alerts.buttons["OK"].tap()
  }

  @MainActor private func launch(fixture: String, failedSave: Int? = nil) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = [
      "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-lastAcknowledgedRegion", "US"
    ]
    app.launchEnvironment["USEDWELL_FIXTURE"] = fixture
    app.launchEnvironment["USEDWELL_RESET_PREFERENCES"] = "1"
    if let failedSave { app.launchEnvironment["USEDWELL_FAIL_SAVE"] = String(failedSave) }
    app.launch()
    XCTAssertTrue(app.buttons["add-item"].waitForExistence(timeout: 5))
    return app
  }

  @MainActor private func itemButton(_ name: String, _ app: XCUIApplication) -> XCUIElement {
    app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
  }

  @MainActor private func openPhone(_ app: XCUIApplication) {
    itemButton("iPhone 15 Pro", app).tap()
    XCTAssertTrue(app.buttons["edit-item"].waitForExistence(timeout: 3))
  }

  @MainActor private func complete(_ app: XCUIApplication) {
    reveal(app.buttons["complete-item"], app)
    app.buttons["complete-item"].tap()
    app.alerts.buttons["Finish Using Today"].tap()
  }

  @MainActor private func deleteItem(_ app: XCUIApplication) {
    reveal(app.buttons["delete-item"], app)
    app.buttons["delete-item"].tap()
    app.alerts.buttons["Delete Permanently"].tap()
  }

  @MainActor private func dismissPermission(_ app: XCUIApplication) {
    let later = app.alerts.buttons["Not Now"]
    if later.waitForExistence(timeout: 2) { later.tap() }
  }

  @MainActor private func reveal(
    _ element: XCUIElement, _ app: XCUIApplication, upward: Bool = true
  ) {
    for _ in 0..<8 {
      if element.isHittable { return }
      if upward { app.swipeUp() } else { app.swipeDown() }
    }
    XCTAssertTrue(element.isHittable)
  }

  @MainActor private func capture(_ name: String, _ app: XCUIApplication) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
