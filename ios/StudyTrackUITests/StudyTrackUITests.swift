import XCTest

final class StudyTrackUITests: XCTestCase {
    @MainActor func testOnboardingAndSubjectCreation() throws {
        let app = XCUIApplication(); app.launchArguments = ["-uitesting"]; app.launch()
        let name = app.textFields["onboarding.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 15)); name.tap(); name.typeText("Student")
        let semester = app.textFields["onboarding.semester"]; semester.tap(); semester.typeText("Fall")
        app.buttons["onboarding.start"].tap()
        XCTAssertTrue(app.tabBars.buttons["科目"].waitForExistence(timeout: 10))
        app.tabBars.buttons["科目"].tap(); app.buttons["subjects.add"].tap()
        let subject = app.textFields["subject.name"]; XCTAssertTrue(subject.waitForExistence(timeout: 5)); subject.tap(); subject.typeText("Math")
        app.buttons["subject.save"].tap()
        XCTAssertTrue(app.staticTexts["Math"].waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.lifetime = .keepAlways; add(attachment)
    }
}
