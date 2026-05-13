//
//  TaskModels.swift
//  FnScribe
//
//  Created by Codex on 2026-04-22.
//

import Foundation
import SwiftUI

enum TaskStatus: String, CaseIterable, Codable, Identifiable {
    case todo
    case inProgress = "in-progress"
    case done

    var id: String { rawValue }

    init?(persistedRawValue rawValue: String) {
        switch rawValue {
        case "todo", "inbox", "next":
            self = .todo
        case "in-progress", "inProgress":
            self = .inProgress
        case "done":
            self = .done
        default:
            return nil
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        guard let status = TaskStatus(persistedRawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown task status: \(rawValue)"
            )
        }
        self = status
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var displayName: String {
        switch self {
        case .todo:
            return "Todo"
        case .inProgress:
            return "In Progress"
        case .done:
            return "Done"
        }
    }

    var shortName: String {
        switch self {
        case .todo:
            return "Todo"
        case .inProgress:
            return "Doing"
        case .done:
            return "Done"
        }
    }

    var tintColor: Color {
        switch self {
        case .todo:
            return .blue
        case .inProgress:
            return .orange
        case .done:
            return .green
        }
    }
}

enum TaskPriority: String, CaseIterable, Codable, Identifiable {
    case low
    case medium
    case high
    case urgent

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var sortRank: Int {
        switch self {
        case .urgent:
            return 3
        case .high:
            return 2
        case .medium:
            return 1
        case .low:
            return 0
        }
    }

    var tintColor: Color {
        switch self {
        case .low:
            return .secondary
        case .medium:
            return .blue
        case .high:
            return .orange
        case .urgent:
            return .red
        }
    }
}

enum TaskSource: String, CaseIterable, Codable {
    case manual
    case voiceTask
}

enum TaxonomyColorToken: String, CaseIterable, Codable, Identifiable {
    case slate
    case blue
    case green
    case amber
    case coral
    case rose
    case grape

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var color: Color {
        switch self {
        case .slate:
            return Color(nsColor: .secondaryLabelColor)
        case .blue:
            return .blue
        case .green:
            return .green
        case .amber:
            return .orange
        case .coral:
            return .red
        case .rose:
            return .pink
        case .grape:
            return .purple
        }
    }
}

struct TaskProject: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var isArchived: Bool
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct TaskLabel: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var colorToken: TaxonomyColorToken
    var isArchived: Bool
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        colorToken: TaxonomyColorToken = .blue,
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.colorToken = colorToken
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct TaskItem: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var title: String
    var notes: String?
    var status: TaskStatus
    var priority: TaskPriority
    var projectID: UUID?
    var labelIDs: [UUID]
    var source: TaskSource
    let createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var originalTranscript: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case notes
        case status
        case priority
        case projectID
        case labelIDs
        case source
        case createdAt
        case updatedAt
        case completedAt
        case originalTranscript
    }

    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        status: TaskStatus = .todo,
        priority: TaskPriority = .medium,
        projectID: UUID? = nil,
        labelIDs: [UUID] = [],
        source: TaskSource = .manual,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil,
        originalTranscript: String? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.status = status
        self.priority = priority
        self.projectID = projectID
        self.labelIDs = labelIDs
        self.source = source
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.originalTranscript = originalTranscript
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let createdAt = container.decodeSafely(Date.self, forKey: .createdAt) ?? Date()
        let title = container.decodeSafely(String.self, forKey: .title)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        self.id = container.decodeSafely(UUID.self, forKey: .id) ?? UUID()
        self.title = title.flatMap { $0.isEmpty ? nil : $0 } ?? "Untitled Task"
        self.notes = container.decodeSafely(String.self, forKey: .notes)
        self.status = container.decodeSafely(TaskStatus.self, forKey: .status) ?? .todo
        self.priority = container.decodeSafely(TaskPriority.self, forKey: .priority) ?? .medium
        self.projectID = container.decodeSafely(UUID.self, forKey: .projectID)
        self.labelIDs = container.decodeSafely([UUID].self, forKey: .labelIDs) ?? []
        self.source = container.decodeSafely(TaskSource.self, forKey: .source) ?? .manual
        self.createdAt = createdAt
        self.updatedAt = container.decodeSafely(Date.self, forKey: .updatedAt) ?? createdAt
        self.completedAt = container.decodeSafely(Date.self, forKey: .completedAt)
        self.originalTranscript = container.decodeSafely(String.self, forKey: .originalTranscript)
    }

    static func displaySort(lhs: TaskItem, rhs: TaskItem) -> Bool {
        if lhs.status == .done, rhs.status != .done {
            return false
        }
        if lhs.status != .done, rhs.status == .done {
            return true
        }
        if lhs.priority.sortRank != rhs.priority.sortRank {
            return lhs.priority.sortRank > rhs.priority.sortRank
        }
        return lhs.updatedAt > rhs.updatedAt
    }
}

struct TaskPageSlice<Item> {
    let items: [Item]
    let pageIndex: Int
    let totalPages: Int

    var hasPreviousPage: Bool {
        pageIndex > 0
    }

    var hasNextPage: Bool {
        pageIndex + 1 < totalPages
    }
}

enum TaskPagination {
    static func slice<Item>(items: [Item], pageSize: Int, pageIndex: Int) -> TaskPageSlice<Item> {
        let normalizedPageSize = max(pageSize, 1)
        let totalPages = max(Int(ceil(Double(items.count) / Double(normalizedPageSize))), 1)
        let clampedPageIndex = min(max(pageIndex, 0), totalPages - 1)
        let startIndex = min(clampedPageIndex * normalizedPageSize, items.count)
        let endIndex = min(startIndex + normalizedPageSize, items.count)
        let pageItems = startIndex < endIndex ? Array(items[startIndex..<endIndex]) : []

        return TaskPageSlice(
            items: pageItems,
            pageIndex: clampedPageIndex,
            totalPages: totalPages
        )
    }
}

extension Array where Element == TaskItem {
    var sortedForDisplay: [TaskItem] {
        sorted(by: TaskItem.displaySort(lhs:rhs:))
    }
}

struct TaskWorkspaceStore: Codable, Equatable {
    var schemaVersion: Int = 1
    var tasks: [TaskItem] = []
    var projects: [TaskProject] = []
    var labels: [TaskLabel] = []

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case tasks
        case projects
        case labels
    }

    init(
        schemaVersion: Int = 1,
        tasks: [TaskItem] = [],
        projects: [TaskProject] = [],
        labels: [TaskLabel] = []
    ) {
        self.schemaVersion = schemaVersion
        self.tasks = tasks
        self.projects = projects
        self.labels = labels
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = container.decodeSafely(Int.self, forKey: .schemaVersion) ?? 1
        tasks = container.decodeLossyArray(TaskItem.self, forKey: .tasks)
        projects = container.decodeLossyArray(TaskProject.self, forKey: .projects)
        labels = container.decodeLossyArray(TaskLabel.self, forKey: .labels)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(tasks, forKey: .tasks)
        try container.encode(projects, forKey: .projects)
        try container.encode(labels, forKey: .labels)
    }
}

private extension KeyedDecodingContainer {
    func decodeSafely<Value: Decodable>(_ type: Value.Type, forKey key: Key) -> Value? {
        try? decodeIfPresent(type, forKey: key)
    }

    func decodeLossyArray<Value: Decodable>(_ type: Value.Type, forKey key: Key) -> [Value] {
        guard let values = try? decodeIfPresent(LossyDecodableArray<Value>.self, forKey: key) else {
            return []
        }
        return values.elements
    }
}

private struct LossyDecodableArray<Element: Decodable>: Decodable {
    var elements: [Element] = []

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        while !container.isAtEnd {
            if let element = try? container.decode(Element.self) {
                elements.append(element)
            } else {
                _ = try? container.decode(DiscardedDecodableValue.self)
            }
        }
    }
}

private struct DiscardedDecodableValue: Decodable {
    init(from decoder: Decoder) throws {
        if var unkeyedContainer = try? decoder.unkeyedContainer() {
            while !unkeyedContainer.isAtEnd {
                _ = try? unkeyedContainer.decode(DiscardedDecodableValue.self)
            }
            return
        }

        if let keyedContainer = try? decoder.container(keyedBy: DynamicCodingKey.self) {
            for key in keyedContainer.allKeys {
                _ = try? keyedContainer.decode(DiscardedDecodableValue.self, forKey: key)
            }
            return
        }

        _ = try? decoder.singleValueContainer()
    }
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

struct TaskFilterState: Equatable {
    var selectedProjectID: UUID?
    var selectedLabelID: UUID?
    var selectedStatus: TaskStatus?
    var selectedPriority: TaskPriority?
    var searchText: String = ""

    static let `default` = TaskFilterState()
}

struct TaskCaptureResult: Equatable {
    let title: String
    let status: TaskStatus
    let priority: TaskPriority
    let projectID: UUID?
    let labelIDs: [UUID]
    let originalTranscript: String
}
