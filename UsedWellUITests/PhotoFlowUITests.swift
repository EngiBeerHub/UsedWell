import UIKit
import XCTest

final class PhotoFlowUITests: UIFlowTestCase {

  @MainActor func testPhotosPickerSaveRemoveCancelAndRetry() throws {
    try requireSeededPhotoLibrary()
    let app = XCUIApplication()
    app.launchArguments = [
      "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-lastAcknowledgedRegion", "US"
    ]
    app.launchEnvironment["USEDWELL_FIXTURE"] = "home-review"
    app.launchEnvironment["USEDWELL_FAIL_SAVE"] = "1"
    app.launchEnvironment["USEDWELL_RESET_PREFERENCES"] = "1"
    app.launch()
    let featured = app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "featured-item")
    ).firstMatch
    XCTAssertTrue(featured.waitForExistence(timeout: 5))
    featured.tap()
    app.buttons["edit-item"].tap()
    choosePhoto(app)
    let remove = app.buttons["remove-item-photo"]
    reveal(remove, app)
    XCTAssertTrue(remove.waitForExistence(timeout: 10))
    XCTAssertTrue(app.buttons["save-item"].isEnabled)
    capture("en-US-photo-draft", app)
    app.buttons["save-item"].tap()
    let failure = app.alerts.firstMatch
    XCTAssertTrue(failure.waitForExistence(timeout: 3))
    failure.buttons.firstMatch.tap()
    XCTAssertTrue(remove.exists)
    app.buttons["save-item"].tap()
    XCTAssertTrue(app.buttons["edit-item"].waitForExistence(timeout: 3))
    capture("en-US-photo-detail", app)
    app.buttons["edit-item"].tap()
    XCTAssertTrue(remove.waitForExistence(timeout: 3))
    remove.tap()
    XCTAssertFalse(remove.exists)
    app.buttons["Cancel"].tap()
    app.buttons["edit-item"].tap()
    XCTAssertTrue(remove.waitForExistence(timeout: 3))
    remove.tap()
    app.buttons["save-item"].tap()
    app.buttons["edit-item"].tap()
    XCTAssertFalse(remove.exists)
    app.buttons["Cancel"].tap()
  }

  @MainActor func testAddPhotoCancelThenSave() throws {
    try requireSeededPhotoLibrary()
    let app = XCUIApplication()
    app.launchArguments = [
      "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-lastAcknowledgedRegion", "US"
    ]
    app.launchEnvironment["USEDWELL_FIXTURE"] = "empty"
    app.launchEnvironment["USEDWELL_RESET_PREFERENCES"] = "1"
    app.launch()
    app.buttons["add-first-item"].tap()
    choosePhoto(app)
    reveal(app.buttons["remove-item-photo"], app)
    XCTAssertTrue(app.buttons["remove-item-photo"].waitForExistence(timeout: 10))
    app.buttons["Cancel"].tap()
    app.buttons["add-first-item"].tap()
    XCTAssertFalse(app.buttons["remove-item-photo"].exists)
    choosePhoto(app)
    reveal(app.buttons["remove-item-photo"], app)
    XCTAssertTrue(app.buttons["remove-item-photo"].waitForExistence(timeout: 10))
    reveal(app.textFields["item-name"], app)
    app.textFields["item-name"].tap()
    app.textFields["item-name"].typeText("Photo Camera")
    reveal(app.textFields["purchase-price"], app)
    app.textFields["purchase-price"].tap()
    app.textFields["purchase-price"].typeText("3100")
    app.buttons["save-item"].tap()
    let later = app.alerts.buttons["Not Now"]
    if later.waitForExistence(timeout: 2) { later.tap() }
    let item = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Photo Camera"))
      .firstMatch
    XCTAssertTrue(item.waitForExistence(timeout: 3))
    item.tap()
    app.buttons["edit-item"].tap()
    XCTAssertTrue(app.buttons["remove-item-photo"].waitForExistence(timeout: 3))
  }

  private func requireSeededPhotoLibrary() throws {
    try XCTSkipUnless(
      ProcessInfo.processInfo.environment["USEDWELL_PHOTOS_PICKER_SEEDED"] == "1",
      "Real Photos picker integration: seed a disposable Simulator with simctl addmedia, "
        + "then set USEDWELL_PHOTOS_PICKER_SEEDED=1 in the test runner environment.")
  }

  @MainActor private func choosePhoto(_ app: XCUIApplication) {
    app.buttons["choose-item-photo"].tap()
    // Uses the real system picker. Seed a disposable Simulator with `simctl addmedia` first.
    let photo = app.images.matching(NSPredicate(format: "label BEGINSWITH %@", "Photo,"))
      .firstMatch
    XCTAssertTrue(
      photo.waitForExistence(timeout: 10), "The Simulator photo library needs a test image")
    capture("en-US-photo-picker", app)
    photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    // Selection dismisses the picker before the asynchronous image import has finished.
    XCTAssertTrue(
      app.buttons["remove-item-photo"].waitForExistence(timeout: 30),
      "The selected seeded photo must finish importing before editing or saving")
  }

  @MainActor func testPhotoVisualStatesAndHistory() throws {
    let photoPath = try makePhotoFixture()
    for language in ["ja", "en"] {
      for variant in ["under", "90", "100", "over", "long"] {
        checkVisualVariant(language: language, variant: variant, photoPath: photoPath)
      }
    }
  }

  @MainActor func testPhotoPolishJapaneseAndEnglish() throws {
    let photoPath = try makePhotoFixture()
    for language in ["ja", "en"] {
      for variant in ["99", "over"] {
        checkVisualVariant(language: language, variant: variant, photoPath: photoPath, polish: true)
      }
    }
  }

  @MainActor func testPhotoFitJapaneseAndEnglish() throws {
    let photoPath = try makePhotoFixture()
    for language in ["ja", "en"] {
      checkVisualVariant(language: language, variant: "99", photoPath: photoPath, polish: true)
    }
  }

  @MainActor private func checkVisualVariant(
    language: String, variant: String, photoPath: String?, polish: Bool = false
  ) {
    let app = XCUIApplication()
    let region = language == "ja" ? "JP" : "US"
    app.launchArguments = [
      "-AppleLanguages", "(\(language))", "-AppleLocale", "\(language)_\(region)",
      "-lastAcknowledgedRegion", region
    ]
    if variant == "long" {
      app.launchArguments += [
        "-UIPreferredContentSizeCategoryName",
        "UICTContentSizeCategoryAccessibilityXXXL"
      ]
    }
    app.launchEnvironment["USEDWELL_FIXTURE"] = "home-photo-\(variant)"
    app.launchEnvironment["USEDWELL_PHOTO_FIXTURE_PATH"] = photoPath
    app.launchEnvironment["USEDWELL_RESET_PREFERENCES"] = "1"
    app.launch()
    let featured = app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "featured-item")
    ).firstMatch
    XCTAssertTrue(featured.waitForExistence(timeout: 5))
    let photoItem = photoItem(app, featured: featured, variant: variant)
    checkFeaturedStatus(photoItem, variant: variant, language: language)
    capture("\(language)-\(region)-photo-\(variant)-home", app)
    if variant == "long" {
      app.swipeUp()
      capture("\(language)-\(region)-photo-long-scroll", app)
    }
    if variant != "long" {
      photoItem.tap()
      XCTAssertTrue(app.buttons["edit-item"].waitForExistence(timeout: 3))
      XCTAssertFalse(app.staticTexts[language == "ja" ? "使用中" : "In use"].exists)
      capture("\(language)-\(region)-photo-\(variant)-detail", app)
      if photoPath != nil {
        checkPhotoEditor(
          app, language: language, name: "\(language)-\(region)-photo-\(variant)-edit")
      }
      app.navigationBars.buttons.firstMatch.tap()
    }
    if polish { checkFallback(app, language: language, region: region, variant: variant) }
    let history = app.buttons[language == "ja" ? "これまで使ったもの" : "Past Items"]
    reveal(history, app)
    history.tap()
    XCTAssertTrue(
      app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "history-item-"))
        .firstMatch.waitForExistence(timeout: 3))
    capture("\(language)-\(region)-photo-\(variant)-history", app)
    if variant == "over" { checkHistoryDetail(app, language: language, region: region) }
    app.terminate()
  }

  @MainActor private func photoItem(
    _ app: XCUIApplication, featured: XCUIElement, variant: String
  ) -> XCUIElement {
    // At 67%, the phone is below the 83% Mac in the unchanged review ranking.
    let photoItem =
      variant == "under"
      ? app.buttons.matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@",
          "regular-item-", "iPhone 15 Pro")
      ).firstMatch
      : featured
    if variant == "under" {
      XCTAssertTrue(featured.label.hasPrefix("MacBook Air"), featured.label)
      reveal(photoItem, app)
    }
    return photoItem
  }

  @MainActor private func checkFeaturedStatus(
    _ featured: XCUIElement, variant: String, language: String
  ) {
    let percentage = ["under": "67%", "90": "90%", "99": "99%", "100": "100%", "over": "133%"]
    if let expected = percentage[variant] {
      XCTAssertTrue(featured.label.contains(expected), featured.label)
    }
    XCTAssertFalse(featured.label.contains(language == "ja" ? "使用中" : "In use"))
  }

  @MainActor private func checkPhotoEditor(_ app: XCUIApplication, language: String, name: String) {
    app.buttons["edit-item"].tap()
    XCTAssertTrue(app.buttons["remove-item-photo"].waitForExistence(timeout: 3))
    capture(name, app)
    app.buttons[language == "ja" ? "キャンセル" : "Cancel"].tap()
  }

  @MainActor private func checkFallback(
    _ app: XCUIApplication, language: String, region: String, variant: String
  ) {
    let fallback = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "MacBook Air"))
      .firstMatch
    reveal(fallback, app)
    capture("\(language)-\(region)-photo-\(variant)-mixed-rows", app)
    fallback.tap()
    XCTAssertTrue(app.buttons["edit-item"].waitForExistence(timeout: 3))
    capture("\(language)-\(region)-photo-\(variant)-fallback-detail", app)
    app.buttons["edit-item"].tap()
    XCTAssertFalse(app.buttons["remove-item-photo"].exists)
    capture("\(language)-\(region)-photo-\(variant)-fallback-edit", app)
    app.buttons[language == "ja" ? "キャンセル" : "Cancel"].tap()
    app.navigationBars.buttons.firstMatch.tap()
  }

  @MainActor private func checkHistoryDetail(
    _ app: XCUIApplication, language: String, region: String
  ) {
    let cases = [("Past iPhone", "133%"), ("Past Bag", "88%"), ("Past Watch", "100%")]
    for (name, percentage) in cases {
      let past = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
      reveal(past, app)
      past.tap()
      XCTAssertFalse(app.buttons["edit-item"].exists)
      capture("\(language)-\(region)-photo-history-\(percentage)-detail", app)
      let finalProgress = app.staticTexts["final-progress"]
      reveal(finalProgress, app)
      XCTAssertTrue(finalProgress.label.contains(percentage), finalProgress.label)
      capture("\(language)-\(region)-photo-history-\(percentage)-info", app)
      app.navigationBars.buttons.firstMatch.tap()
    }
  }

  @MainActor private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
    revealElement(element, in: app)
  }

  @MainActor private func capture(_ name: String, _ app: XCUIApplication) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}

extension PhotoFlowUITests {
  @MainActor fileprivate func makePhotoFixture() throws -> String {
    if let path = ProcessInfo.processInfo.environment["USEDWELL_PHOTO_FIXTURE_PATH"] {
      XCTAssertNotNil(UIImage(contentsOfFile: path), "The supplied photo fixture must be readable")
      return path
    }
    // A landscape image with contrasting edges makes aspect-fit evidence self-contained.
    let image = UIGraphicsImageRenderer(size: CGSize(width: 480, height: 240)).image { context in
      UIColor.systemTeal.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 480, height: 240))
      UIColor.systemRed.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 40, height: 240))
      UIColor.systemBlue.setFill()
      context.fill(CGRect(x: 440, y: 0, width: 40, height: 240))
    }
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("png")
    try XCTUnwrap(image.pngData()).write(to: url)
    addTeardownBlock { try FileManager.default.removeItem(at: url) }
    return url.path
  }

}
