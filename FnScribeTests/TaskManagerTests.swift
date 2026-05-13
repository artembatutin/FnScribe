import XCTest

@MainActor
final class TaskManagerTests: XCTestCase {
    func testTaskWorkspacePersistsAcrossReloads() throws {
        let workspaceURL = temporaryURL()
        let manager = TaskManager(workspaceFileURL: workspaceURL)
        let project = try XCTUnwrap(manager.createProject(name: "Operations"))
        let label = try XCTUnwrap(manager.createLabel(name: "Admin", colorToken: .amber))

        let task = manager.createTask(
            title: "Close the month-end checklist",
            status: .todo,
            priority: .urgent,
            projectID: project.id,
            labelIDs: [label.id],
            source: .voiceTask,
            originalTranscript: "task operations admin urgent close the month-end checklist"
        )

        let reloaded = TaskManager(workspaceFileURL: workspaceURL)

        XCTAssertEqual(reloaded.tasks.count, 1)
        XCTAssertEqual(reloaded.projects.count, 1)
        XCTAssertEqual(reloaded.labels.count, 1)
        XCTAssertEqual(reloaded.tasks.first?.id, task.id)
        XCTAssertEqual(reloaded.tasks.first?.projectID, project.id)
        XCTAssertEqual(reloaded.tasks.first?.labelIDs, [label.id])
        XCTAssertEqual(reloaded.tasks.first?.source, .voiceTask)
    }

    func testFilteringCombinesSidebarAndToolbarFilters() throws {
        let manager = TaskManager(workspaceFileURL: temporaryURL())
        let engineering = try XCTUnwrap(manager.createProject(name: "Engineering"))
        let marketing = try XCTUnwrap(manager.createProject(name: "Marketing"))
        let urgent = try XCTUnwrap(manager.createLabel(name: "Urgent", colorToken: .coral))
        let writing = try XCTUnwrap(manager.createLabel(name: "Writing", colorToken: .blue))

        _ = manager.createTask(
            title: "Ship the onboarding update",
            status: .todo,
            priority: .urgent,
            projectID: engineering.id,
            labelIDs: [urgent.id]
        )
        _ = manager.createTask(
            title: "Draft blog post outline",
            status: .inProgress,
            priority: .medium,
            projectID: marketing.id,
            labelIDs: [writing.id]
        )

        let filtered = manager.filteredTasks(using: TaskFilterState(
            selectedProjectID: engineering.id,
            selectedLabelID: urgent.id,
            selectedStatus: .todo,
            selectedPriority: .urgent,
            searchText: "onboarding"
        ))

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.title, "Ship the onboarding update")
    }

    func testCreateTaskReloadsExternallyUpdatedWorkspaceBeforeSaving() throws {
        let workspaceURL = temporaryURL()
        let manager = TaskManager(workspaceFileURL: workspaceURL)

        _ = manager.createTask(title: "Existing dashboard task")

        var externalWorkspace = try decodeWorkspace(at: workspaceURL)
        externalWorkspace.tasks.append(TaskItem(title: "Existing widget task", status: .todo))
        try encodeWorkspace(externalWorkspace, to: workspaceURL)

        _ = manager.createTask(title: "New dashboard task")

        let reloaded = TaskManager(workspaceFileURL: workspaceURL)
        XCTAssertEqual(Set(reloaded.tasks.map(\.title)), [
            "Existing dashboard task",
            "Existing widget task",
            "New dashboard task"
        ])
    }

    func testTaskManagerObservesExternallyUpdatedWorkspace() async throws {
        let workspaceURL = temporaryURL()
        let manager = TaskManager(workspaceFileURL: workspaceURL)
        let task = manager.createTask(title: "Widget-completable task", status: .todo)

        var externalWorkspace = try decodeWorkspace(at: workspaceURL)
        let completedAt = Date().addingTimeInterval(5)
        guard let index = externalWorkspace.tasks.firstIndex(where: { $0.id == task.id }) else {
            return XCTFail("Expected task to be persisted before external update")
        }
        externalWorkspace.tasks[index].status = .done
        externalWorkspace.tasks[index].updatedAt = completedAt
        externalWorkspace.tasks[index].completedAt = completedAt
        try encodeWorkspace(externalWorkspace, to: workspaceURL)

        try await waitUntil {
            manager.tasks.first(where: { $0.id == task.id })?.status == .done
        }

        XCTAssertEqual(manager.tasks.first(where: { $0.id == task.id })?.completedAt, completedAt)
    }

    func testLegacyStatusesDecodeAsCurrentStatuses() throws {
        let json = """
        {
          "schemaVersion": 1,
          "tasks": [
            {
              "id": "\(UUID().uuidString)",
              "title": "Legacy inbox task",
              "status": "inbox",
              "priority": "medium",
              "labelIDs": [],
              "source": "manual",
              "createdAt": 0,
              "updatedAt": 0
            },
            {
              "id": "\(UUID().uuidString)",
              "title": "Legacy next task",
              "status": "next",
              "priority": "medium",
              "labelIDs": [],
              "source": "manual",
              "createdAt": 0,
              "updatedAt": 0
            },
            {
              "id": "\(UUID().uuidString)",
              "title": "Legacy in progress task",
              "status": "inProgress",
              "priority": "medium",
              "labelIDs": [],
              "source": "manual",
              "createdAt": 0,
              "updatedAt": 0
            }
          ],
          "projects": [],
          "labels": []
        }
        """

        let workspace = try JSONDecoder().decode(TaskWorkspaceStore.self, from: Data(json.utf8))

        XCTAssertEqual(workspace.tasks.map(\.status), [.todo, .todo, .inProgress])
    }

    func testTaskWorkspaceDecodingKeepsValidTasksWhenARecordIsMalformed() throws {
        let json = """
        {
          "schemaVersion": 1,
          "tasks": [
            {
              "id": "\(UUID().uuidString)",
              "title": "Valid task",
              "status": "todo",
              "priority": "medium",
              "createdAt": 0,
              "updatedAt": 0
            },
            "malformed task"
          ],
          "projects": [],
          "labels": []
        }
        """

        let workspace = try JSONDecoder().decode(TaskWorkspaceStore.self, from: Data(json.utf8))

        XCTAssertEqual(workspace.tasks.map(\.title), ["Valid task"])
        XCTAssertEqual(workspace.tasks.first?.labelIDs, [])
        XCTAssertEqual(workspace.tasks.first?.source, .manual)
    }

    func testTaskOrderingKeepsOpenHigherPriorityTasksFirst() {
        let now = Date()
        let tasks = [
            TaskItem(
                title: "Done urgent",
                status: .done,
                priority: .urgent,
                createdAt: now,
                updatedAt: now.addingTimeInterval(30)
            ),
            TaskItem(
                title: "Todo high recent",
                status: .todo,
                priority: .high,
                createdAt: now,
                updatedAt: now.addingTimeInterval(20)
            ),
            TaskItem(
                title: "In progress medium",
                status: .inProgress,
                priority: .medium,
                createdAt: now,
                updatedAt: now.addingTimeInterval(40)
            ),
            TaskItem(
                title: "Todo high older",
                status: .todo,
                priority: .high,
                createdAt: now,
                updatedAt: now.addingTimeInterval(10)
            )
        ]

        XCTAssertEqual(tasks.sortedForDisplay.map(\.title), [
            "Todo high recent",
            "Todo high older",
            "In progress medium",
            "Done urgent"
        ])
    }

    func testTaskPaginationClampsOutOfRangePageRequests() {
        let slice = TaskPagination.slice(items: Array(1...5), pageSize: 2, pageIndex: 9)

        XCTAssertEqual(slice.items, [5])
        XCTAssertEqual(slice.pageIndex, 2)
        XCTAssertEqual(slice.totalPages, 3)
        XCTAssertTrue(slice.hasPreviousPage)
        XCTAssertFalse(slice.hasNextPage)
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("task_workspace.json")
    }

    private func decodeWorkspace(at url: URL) throws -> TaskWorkspaceStore {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(TaskWorkspaceStore.self, from: data)
    }

    private func encodeWorkspace(_ workspace: TaskWorkspaceStore, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(workspace)
        try data.write(to: url, options: .atomic)
    }

    private func waitUntil(
        timeout: TimeInterval = 2,
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if condition() {
                return
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        XCTFail("Condition was not met within \(timeout) seconds")
    }
}
