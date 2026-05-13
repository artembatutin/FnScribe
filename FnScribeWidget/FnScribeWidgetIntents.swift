//
//  FnScribeWidgetIntents.swift
//  FnScribeWidget
//
//  Created by Codex on 2026-05-01.
//

import AppIntents
import WidgetKit

enum TaskPageDirection: String {
    case previous
    case next
}

struct CreateQuickTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Task"
    static var description = IntentDescription("Creates a new todo task in FnScribe.")

    func perform() async throws -> some IntentResult {
        var workspace = SharedTaskWorkspace.load()
        let timestamp = Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short

        workspace.tasks.append(
            TaskItem(
                title: "New task \(formatter.string(from: timestamp))",
                status: .todo,
                priority: .medium,
                createdAt: timestamp,
                updatedAt: timestamp
            )
        )

        try SharedTaskWorkspace.save(workspace)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct UpdateTaskStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Update Task Status"

    @Parameter(title: "Task ID")
    var taskID: String

    @Parameter(title: "Status")
    var status: String

    init() {
        taskID = ""
        status = TaskStatus.todo.rawValue
    }

    init(taskID: String, status: String) {
        self.taskID = taskID
        self.status = status
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: taskID),
              let status = TaskStatus(persistedRawValue: status)
        else {
            return .result()
        }

        var workspace = SharedTaskWorkspace.load()
        guard let index = workspace.tasks.firstIndex(where: { $0.id == id }) else {
            return .result()
        }

        let timestamp = Date()
        workspace.tasks[index].status = status
        workspace.tasks[index].updatedAt = timestamp
        workspace.tasks[index].completedAt = status == .done ? timestamp : nil

        try SharedTaskWorkspace.save(workspace)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct StartTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Task"

    @Parameter(title: "Task ID")
    var taskID: String

    init() {
        taskID = ""
    }

    init(taskID: String) {
        self.taskID = taskID
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: taskID) else {
            return .result()
        }

        var workspace = SharedTaskWorkspace.load()
        guard let index = workspace.tasks.firstIndex(where: { $0.id == id }) else {
            return .result()
        }

        workspace.tasks[index].status = .inProgress
        workspace.tasks[index].updatedAt = Date()

        try SharedTaskWorkspace.save(workspace)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct ChangeTaskPageIntent: AppIntent {
    static var title: LocalizedStringResource = "Change Task Page"

    @Parameter(title: "Widget Family")
    var familyIdentifier: String

    @Parameter(title: "Direction")
    var direction: String

    init() {
        familyIdentifier = ""
        direction = TaskPageDirection.next.rawValue
    }

    init(familyIdentifier: String, direction: String) {
        self.familyIdentifier = familyIdentifier
        self.direction = direction
    }

    func perform() async throws -> some IntentResult {
        guard let pageDirection = TaskPageDirection(rawValue: direction) else {
            return .result()
        }

        let currentPage = SharedTaskWorkspace.widgetTaskPageIndex(for: familyIdentifier)
        let updatedPage = switch pageDirection {
        case .previous:
            max(currentPage - 1, 0)
        case .next:
            currentPage + 1
        }

        SharedTaskWorkspace.setWidgetTaskPageIndex(updatedPage, for: familyIdentifier)
        WidgetCenter.shared.reloadTimelines(ofKind: SharedTaskWorkspace.widgetKind)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
