import AppKit

enum ClipboardPasteTransactionError: Error {
    case clipboardChanged
    case clipboardUnavailable
}

/// Keeps dictation on the pasteboard until the receiving app can handle Cmd+V.
/// AppKit does not acknowledge when another process reads a posted paste event.
struct ClipboardPasteTransaction {
    let pasteboard: NSPasteboard
    var restoreDelay: TimeInterval = 1.0

    func paste(
        text: String,
        preserveClipboard: Bool,
        focusDelay: TimeInterval,
        postPaste: () -> Void
    ) async throws {
        let previousContents = preserveClipboard ? snapshot() : nil
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            if preserveClipboard {
                restoreIfOwned(previousContents, changeCount: pasteboard.changeCount)
            }
            throw ClipboardPasteTransactionError.clipboardUnavailable
        }
        let dictationChangeCount = pasteboard.changeCount

        do {
            try await Task.sleep(nanoseconds: UInt64(max(0, focusDelay) * 1_000_000_000))
        } catch {
            if preserveClipboard {
                restoreIfOwned(previousContents, changeCount: dictationChangeCount)
            }
            throw error
        }

        // A clipboard manager or another copy may have replaced our text while
        // focus was settling. Never send Cmd+V with different clipboard data.
        guard pasteboard.changeCount == dictationChangeCount,
              pasteboard.string(forType: .string) == text else {
            throw ClipboardPasteTransactionError.clipboardChanged
        }

        postPaste()

        // Cancellation must not restore the old clipboard immediately after
        // posting Cmd+V. The target may read it on a later event-loop turn.
        let restoreDelayNanoseconds = UInt64(max(0, restoreDelay) * 1_000_000_000)
        let pasteWindow = Task.detached {
            try? await Task.sleep(nanoseconds: restoreDelayNanoseconds)
        }
        await pasteWindow.value

        if preserveClipboard {
            restoreIfOwned(previousContents, changeCount: dictationChangeCount)
        }
    }

    private func snapshot() -> [NSPasteboard.PasteboardType: Data]? {
        guard let types = pasteboard.types else { return nil }
        var contents: [NSPasteboard.PasteboardType: Data] = [:]
        for type in types {
            if let data = pasteboard.data(forType: type) {
                contents[type] = data
            }
        }
        return contents.isEmpty ? nil : contents
    }

    private func restoreIfOwned(
        _ contents: [NSPasteboard.PasteboardType: Data]?,
        changeCount: Int
    ) {
        guard pasteboard.changeCount == changeCount else { return }
        pasteboard.clearContents()
        for (type, data) in contents ?? [:] {
            pasteboard.setData(data, forType: type)
        }
    }
}
