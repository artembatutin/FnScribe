//
//  FnScribeWidget.swift
//  FnScribeWidget
//
//  Created by Codex on 2026-05-01.
//

import AppIntents
import SwiftUI
import WidgetKit

struct FnScribeTasksEntry: TimelineEntry {
    let date: Date
    let openTaskCount: Int
    let visibleTasks: [TaskItem]
    let currentPage: Int
    let totalPages: Int
    let familyIdentifier: String
    let projectNames: [UUID: String]
}

struct FnScribeTasksProvider: TimelineProvider {
    func placeholder(in context: Context) -> FnScribeTasksEntry {
        let project = TaskProject(name: "Website")
        let tasks = [
            TaskItem(title: "Review captured tasks", status: .todo, priority: .high, projectID: project.id),
            TaskItem(title: "Send a follow-up", status: .inProgress, priority: .medium)
        ]

        return FnScribeTasksEntry(
            date: Date(),
            openTaskCount: tasks.count,
            visibleTasks: tasks,
            currentPage: 0,
            totalPages: 1,
            familyIdentifier: FnScribeWidgetLayout.familyIdentifier(for: context.family),
            projectNames: [project.id: project.name]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FnScribeTasksEntry) -> Void) {
        completion(entry(for: context.family))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FnScribeTasksEntry>) -> Void) {
        completion(Timeline(entries: [entry(for: context.family)], policy: .after(Date().addingTimeInterval(60))))
    }

    private func entry(for family: WidgetFamily) -> FnScribeTasksEntry {
        let workspace = SharedTaskWorkspace.load()
        let projectNames = Dictionary(
            uniqueKeysWithValues: workspace.projects
                .filter { !$0.isArchived }
                .map { ($0.id, $0.name) }
        )
        let familyIdentifier = FnScribeWidgetLayout.familyIdentifier(for: family)
        let openTasks = workspace.tasks
            .sortedForDisplay
            .filter { $0.status != .done }
        let currentPage = SharedTaskWorkspace.clampWidgetTaskPageIndex(
            pageCount: max(Int(ceil(Double(openTasks.count) / Double(FnScribeWidgetLayout.taskCapacity(for: family)))), 1),
            for: familyIdentifier
        )
        let taskPage = TaskPagination.slice(
            items: openTasks,
            pageSize: FnScribeWidgetLayout.taskCapacity(for: family),
            pageIndex: currentPage
        )

        return FnScribeTasksEntry(
            date: Date(),
            openTaskCount: openTasks.count,
            visibleTasks: taskPage.items,
            currentPage: taskPage.pageIndex,
            totalPages: taskPage.totalPages,
            familyIdentifier: familyIdentifier,
            projectNames: projectNames
        )
    }
}

struct FnScribeWidget: Widget {
    let kind = SharedTaskWorkspace.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FnScribeTasksProvider()) { entry in
            FnScribeTasksWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    FnScribeWidgetBackground()
                }
        }
        .configurationDisplayName("FnScribe Tasks")
        .description("Review tasks from FnScribe and update them from your desktop.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
        .contentMarginsDisabled()
    }
}

struct FnScribeTasksWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: FnScribeTasksEntry

    private var isSmall: Bool {
        family == .systemSmall
    }

    private var isExtraLarge: Bool {
        family == .systemExtraLarge
    }

    private var showsPagination: Bool {
        entry.totalPages > 1
    }

    private var tasksURL: URL {
        URL(string: "fnscribe://tasks")!
    }

    private var newTaskURL: URL {
        URL(string: "fnscribe://tasks/new")!
    }

    private func projectName(for task: TaskItem) -> String? {
        guard let projectID = task.projectID else { return nil }
        return entry.projectNames[projectID]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isSmall ? 8 : 12) {
            header

            if entry.visibleTasks.isEmpty {
                emptyState
            } else {
                VStack(spacing: isSmall ? 6 : 8) {
                    ForEach(entry.visibleTasks) { task in
                        FnScribeWidgetTaskRow(
                            task: task,
                            projectName: projectName(for: task),
                            compact: isSmall,
                            spacious: isExtraLarge && !showsPagination
                        )
                    }
                }
            }

            Spacer(minLength: 0)

            if showsPagination {
                paginationControls
            } else if !isSmall {
                footer
            }
        }
        .padding(isSmall ? 12 : 16)
        .widgetURL(tasksURL)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: "waveform")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                Text("FnScribe")
                    .font(.headline.weight(.semibold))
            }

            Spacer(minLength: 0)

            Text("\(entry.openTaskCount) open")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.primary.opacity(0.07), in: Capsule())

            Link(destination: newTaskURL) {
                Image(systemName: "plus")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 28)
                    .background(.blue.gradient, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "checkmark.circle")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.green)

            Text("No open tasks")
                .font(.subheadline.weight(.semibold))

            Text("Your captured tasks are clear.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Link(destination: newTaskURL) {
                Label("New", systemImage: "plus")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(height: 32)
                    .padding(.horizontal, 14)
                    .background(.blue.gradient, in: Capsule())
            }
            .buttonStyle(.plain)

            Link(destination: tasksURL) {
                Label("Open FnScribe", systemImage: "arrow.up.forward.app")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(height: 32)
                    .padding(.horizontal, 12)
                    .background(.primary.opacity(0.08), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var paginationControls: some View {
        HStack(spacing: 10) {
            paginationButton(
                iconName: "chevron.up",
                direction: TaskPageDirection.previous.rawValue,
                enabled: entry.currentPage > 0
            )

            VStack(spacing: 4) {
                Text("Page \(entry.currentPage + 1) of \(entry.totalPages)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("\(entry.openTaskCount) tasks")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            paginationButton(
                iconName: "chevron.down",
                direction: TaskPageDirection.next.rawValue,
                enabled: entry.currentPage + 1 < entry.totalPages
            )
        }
    }

    private func paginationButton(iconName: String, direction: String, enabled: Bool) -> some View {
        Button(intent: ChangeTaskPageIntent(familyIdentifier: entry.familyIdentifier, direction: direction)) {
            Image(systemName: iconName)
                .font(.caption.weight(.bold))
                .foregroundStyle(enabled ? .white : .secondary)
                .frame(width: 30, height: 30)
                .background(
                    enabled
                        ? AnyShapeStyle(.blue.gradient)
                        : AnyShapeStyle(.primary.opacity(0.08)),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.7)
    }
}

private struct FnScribeWidgetTaskRow: View {
    let task: TaskItem
    let projectName: String?
    let compact: Bool
    let spacious: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Button(intent: UpdateTaskStatusIntent(taskID: task.id.uuidString, status: TaskStatus.done.rawValue)) {
                ZStack {
                    Circle()
                        .stroke(task.priority.tintColor, lineWidth: 2)
                        .frame(width: compact ? 16 : 18, height: compact ? 16 : 18)

                    Circle()
                        .fill(task.priority.tintColor.opacity(0.14))
                        .frame(width: compact ? 8 : 10, height: compact ? 8 : 10)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(compact || spacious ? 2 : 1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    if let projectName {
                        FnScribeWidgetBadge(title: projectName, color: .teal)
                    }

                    FnScribeWidgetBadge(title: task.status.shortName, color: task.status.tintColor)
                    FnScribeWidgetBadge(title: task.priority.displayName, color: task.priority.tintColor)
                }
                .lineLimit(1)
            }

            Spacer(minLength: 0)

            if !compact, task.status == .todo {
                Button(intent: StartTaskIntent(taskID: task.id.uuidString)) {
                    Text("Start")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(.blue.opacity(0.14), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, compact ? 9 : 12)
        .padding(.vertical, spacious ? 11 : compact ? 8 : 10)
        .background(.primary.opacity(0.075), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(task.priority.tintColor)
                .frame(width: 3)
                .padding(.vertical, 10)
        }
    }
}

private struct FnScribeWidgetBadge: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

private struct FnScribeWidgetBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color(nsColor: .controlBackgroundColor),
                Color.blue.opacity(0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(.primary.opacity(0.035))
    }
}

private enum FnScribeWidgetLayout {
    static func taskCapacity(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall:
            return 2
        case .systemMedium:
            return 2
        case .systemLarge:
            return 3
        case .systemExtraLarge:
            return 4
        @unknown default:
            return 3
        }
    }

    static func familyIdentifier(for family: WidgetFamily) -> String {
        switch family {
        case .systemSmall:
            return "systemSmall"
        case .systemMedium:
            return "systemMedium"
        case .systemLarge:
            return "systemLarge"
        case .systemExtraLarge:
            return "systemExtraLarge"
        @unknown default:
            return "unknown"
        }
    }
}
