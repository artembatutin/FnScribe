//
//  TaskCaptureService.swift
//  FnScribe
//
//  Created by Codex on 2026-04-22.
//

import Foundation

enum TaskCaptureError: LocalizedError {
    case notTaskCommand
    case emptyTitle

    var errorDescription: String? {
        switch self {
        case .notTaskCommand:
            return "The recording does not start with the task command."
        case .emptyTitle:
            return "Task title is empty after removing metadata."
        }
    }
}

@MainActor
class TaskCaptureService {
    private enum CandidateKind: String {
        case project
        case label
        case status
        case priority
    }

    private struct Candidate {
        let kind: CandidateKind
        let start: Int
        let end: Int
        let length: Int
        let normalizedPhrase: String
        let projectID: UUID?
        let labelID: UUID?
        let status: TaskStatus?
        let priority: TaskPriority?
    }

    private struct PhraseRecord {
        let normalizedPhrase: String
        let tokens: [String]
    }

    private let taskManager: TaskManager

    init(taskManager: TaskManager) {
        self.taskManager = taskManager
    }

    func isTaskCommand(_ text: String) -> Bool {
        let tokens = tokenize(text).map(\.normalized)
        return tokens.first == "task"
    }

    func parse(_ text: String) throws -> TaskCaptureResult {
        let allTokens = tokenize(text)
        guard allTokens.first?.normalized == "task" else {
            throw TaskCaptureError.notTaskCommand
        }

        let commandBodyTokens = Array(allTokens.dropFirst())
        var consumed = Array(repeating: false, count: commandBodyTokens.count)

        var status: TaskStatus = .todo
        var priority: TaskPriority = .medium
        var projectID: UUID?
        var labelIDs: [UUID] = []

        let candidates = buildCandidates(in: commandBodyTokens)
        let selected = selectCandidates(candidates)

        for candidate in selected {
            for index in candidate.start...candidate.end {
                consumed[index] = true
            }

            switch candidate.kind {
            case .project:
                projectID = candidate.projectID
            case .label:
                if let labelID = candidate.labelID, !labelIDs.contains(labelID) {
                    labelIDs.append(labelID)
                }
            case .status:
                if let detected = candidate.status {
                    status = detected
                }
            case .priority:
                if let detected = candidate.priority {
                    priority = detected
                }
            }
        }

        let title = cleanedTitle(from: commandBodyTokens, consumed: consumed)
        guard !title.isEmpty else {
            throw TaskCaptureError.emptyTitle
        }

        return TaskCaptureResult(
            title: title,
            status: status,
            priority: priority,
            projectID: projectID,
            labelIDs: labelIDs,
            originalTranscript: text
        )
    }

    func createTask(from text: String) throws -> TaskItem {
        let capture = try parse(text)
        return taskManager.createTask(
            title: capture.title,
            status: capture.status,
            priority: capture.priority,
            projectID: capture.projectID,
            labelIDs: capture.labelIDs,
            source: .voiceTask,
            originalTranscript: capture.originalTranscript
        )
    }

    private func buildCandidates(in tokens: [Token]) -> [Candidate] {
        var candidates: [Candidate] = []

        let uniqueProjects = Dictionary(grouping: taskManager.activeProjects, by: { normalizePhrase($0.name) })
        let uniqueLabels = Dictionary(grouping: taskManager.activeLabels, by: { normalizePhrase($0.name) })

        for (phrase, projects) in uniqueProjects where projects.count == 1 {
            let project = projects[0]
            let record = PhraseRecord(normalizedPhrase: phrase, tokens: phrase.split(separator: " ").map(String.init))
            candidates.append(contentsOf: matches(for: record, in: tokens).map {
                Candidate(
                    kind: .project,
                    start: $0.start,
                    end: $0.end,
                    length: record.tokens.count,
                    normalizedPhrase: record.normalizedPhrase,
                    projectID: project.id,
                    labelID: nil,
                    status: nil,
                    priority: nil
                )
            })
        }

        for (phrase, labels) in uniqueLabels where labels.count == 1 {
            let label = labels[0]
            let record = PhraseRecord(normalizedPhrase: phrase, tokens: phrase.split(separator: " ").map(String.init))
            candidates.append(contentsOf: matches(for: record, in: tokens).map {
                Candidate(
                    kind: .label,
                    start: $0.start,
                    end: $0.end,
                    length: record.tokens.count,
                    normalizedPhrase: record.normalizedPhrase,
                    projectID: nil,
                    labelID: label.id,
                    status: nil,
                    priority: nil
                )
            })
        }

        let statuses: [(String, TaskStatus)] = [
            ("in-progress", .inProgress),
            ("in progress", .inProgress),
            ("to do", .todo),
            ("todo", .todo),
            ("done", .done)
        ]

        for (phrase, value) in statuses {
            let record = phraseRecord(for: phrase)
            candidates.append(contentsOf: matches(for: record, in: tokens).map {
                Candidate(
                    kind: .status,
                    start: $0.start,
                    end: $0.end,
                    length: record.tokens.count,
                    normalizedPhrase: record.normalizedPhrase,
                    projectID: nil,
                    labelID: nil,
                    status: value,
                    priority: nil
                )
            })
        }

        let priorities: [(String, TaskPriority)] = [
            ("urgent priority", .urgent),
            ("high priority", .high),
            ("medium priority", .medium),
            ("low priority", .low),
            ("urgent", .urgent)
        ]

        for (phrase, value) in priorities {
            let record = phraseRecord(for: phrase)
            candidates.append(contentsOf: matches(for: record, in: tokens).map {
                Candidate(
                    kind: .priority,
                    start: $0.start,
                    end: $0.end,
                    length: record.tokens.count,
                    normalizedPhrase: record.normalizedPhrase,
                    projectID: nil,
                    labelID: nil,
                    status: nil,
                    priority: value
                )
            })
        }

        return candidates
    }

    private func phraseRecord(for phrase: String) -> PhraseRecord {
        let normalizedPhrase = normalizePhrase(phrase)
        return PhraseRecord(
            normalizedPhrase: normalizedPhrase,
            tokens: normalizedPhrase.split(separator: " ").map(String.init)
        )
    }

    private func selectCandidates(_ candidates: [Candidate]) -> [Candidate] {
        let sorted = candidates.sorted {
            if $0.length != $1.length {
                return $0.length > $1.length
            }
            if $0.start != $1.start {
                return $0.start < $1.start
            }
            return $0.kind.rawValue < $1.kind.rawValue
        }

        var selected: [Candidate] = []
        var occupied: Set<Int> = []

        for candidate in sorted {
            let span = Set(candidate.start...candidate.end)
            if !occupied.isDisjoint(with: span) {
                continue
            }

            let sameSpanMatches = candidates.filter {
                $0.start == candidate.start && $0.end == candidate.end
            }
            let distinctKinds = Set(sameSpanMatches.map(\.kind))
            let distinctEntities = Set(sameSpanMatches.map(\.normalizedPhrase))
            if distinctKinds.count > 1 && distinctEntities.count == 1 {
                continue
            }

            selected.append(candidate)
            occupied.formUnion(span)
        }

        return selected.sorted { $0.start < $1.start }
    }

    private func matches(for phrase: PhraseRecord, in tokens: [Token]) -> [(start: Int, end: Int)] {
        guard !phrase.tokens.isEmpty, tokens.count >= phrase.tokens.count else { return [] }

        var results: [(start: Int, end: Int)] = []
        for start in 0...(tokens.count - phrase.tokens.count) {
            let slice = tokens[start..<(start + phrase.tokens.count)].map(\.normalized)
            if slice == phrase.tokens {
                results.append((start, start + phrase.tokens.count - 1))
            }
        }
        return results
    }

    private func cleanedTitle(from tokens: [Token], consumed: [Bool]) -> String {
        let remaining = zip(tokens, consumed).compactMap { token, isConsumed -> String? in
            guard !isConsumed else { return nil }
            return token.original
        }

        return remaining.joined(separator: " ").replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func tokenize(_ text: String) -> [Token] {
        text
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .map { Token(original: $0, normalized: normalizeToken($0)) }
            .filter { !$0.normalized.isEmpty }
    }

    private func normalizePhrase(_ text: String) -> String {
        tokenize(text).map(\.normalized).joined(separator: " ")
    }

    private func normalizeToken(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }
}

private struct Token {
    let original: String
    let normalized: String
}
