import XCTest

@MainActor
final class TaskCaptureServiceTests: XCTestCase {
    func testTaskCommandDetectionRequiresLeadingKeyword() throws {
        let manager = TaskManager(workspaceFileURL: temporaryURL())
        let service = TaskCaptureService(taskManager: manager)

        XCTAssertTrue(service.isTaskCommand("task draft the launch email"))
        XCTAssertFalse(service.isTaskCommand("please task draft the launch email"))
        XCTAssertFalse(service.isTaskCommand("draft the launch email"))
    }

    func testDefaultMetadataWhenSpeechContainsOnlyTitle() throws {
        let manager = TaskManager(workspaceFileURL: temporaryURL())
        let service = TaskCaptureService(taskManager: manager)

        let result = try service.parse("task draft the launch email")

        XCTAssertEqual(result.title, "draft the launch email")
        XCTAssertEqual(result.status, .todo)
        XCTAssertEqual(result.priority, .medium)
        XCTAssertNil(result.projectID)
        XCTAssertTrue(result.labelIDs.isEmpty)
    }

    func testExactProjectAndLabelMatchingUsesExistingTaxonomyOnly() throws {
        let manager = TaskManager(workspaceFileURL: temporaryURL())
        let project = try XCTUnwrap(manager.createProject(name: "Roadmap"))
        let label = try XCTUnwrap(manager.createLabel(name: "Deep Work", colorToken: .grape))
        let service = TaskCaptureService(taskManager: manager)

        let matched = try service.parse("task roadmap deep work draft release plan")
        XCTAssertEqual(matched.projectID, project.id)
        XCTAssertEqual(matched.labelIDs, [label.id])
        XCTAssertEqual(matched.title, "draft release plan")

        let unmatched = try service.parse("task road map deep work draft release plan")
        XCTAssertNil(unmatched.projectID)
        XCTAssertEqual(unmatched.labelIDs, [label.id])
        XCTAssertEqual(unmatched.title, "road map draft release plan")
    }

    func testLongestMatchWinsForOverlappingProjectNames() throws {
        let manager = TaskManager(workspaceFileURL: temporaryURL())
        let longer = try XCTUnwrap(manager.createProject(name: "Client Success"))
        _ = manager.createProject(name: "Client")
        let label = try XCTUnwrap(manager.createLabel(name: "Ops"))
        let service = TaskCaptureService(taskManager: manager)

        let result = try service.parse("task client success ops high priority review renewals")

        XCTAssertEqual(result.projectID, longer.id)
        XCTAssertEqual(result.labelIDs, [label.id])
        XCTAssertEqual(result.priority, .high)
        XCTAssertEqual(result.title, "review renewals")
    }

    func testCurrentStatusPhrasesAreRemovedFromTitle() throws {
        let manager = TaskManager(workspaceFileURL: temporaryURL())
        let service = TaskCaptureService(taskManager: manager)

        let todo = try service.parse("task todo draft release notes")
        XCTAssertEqual(todo.status, .todo)
        XCTAssertEqual(todo.title, "draft release notes")

        let inProgress = try service.parse("task in-progress investigate crash")
        XCTAssertEqual(inProgress.status, .inProgress)
        XCTAssertEqual(inProgress.title, "investigate crash")
    }

    func testEmptyTitleAfterMetadataRemovalFails() throws {
        let manager = TaskManager(workspaceFileURL: temporaryURL())
        let service = TaskCaptureService(taskManager: manager)

        XCTAssertThrowsError(try service.parse("task urgent done")) { error in
            XCTAssertEqual(error as? TaskCaptureError, .emptyTitle)
        }
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("task_workspace.json")
    }
}
