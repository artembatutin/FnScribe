import AppKit
import XCTest

@MainActor
final class ClipboardPasteTransactionTests: XCTestCase {
    func testDelayedPasteReadsDictationBeforeOldClipboardIsRestored() async throws {
        let pasteboard = NSPasteboard(name: .init(UUID().uuidString))
        pasteboard.clearContents()
        pasteboard.setString("older copied text", forType: .string)
        let transaction = ClipboardPasteTransaction(pasteboard: pasteboard, restoreDelay: 0.25)
        var delayedRead: Task<String?, Never>?

        try await transaction.paste(text: "fresh dictation", preserveClipboard: true, focusDelay: 0) {
            delayedRead = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 100_000_000)
                return pasteboard.string(forType: .string)
            }
        }

        let pastedText = await delayedRead?.value
        XCTAssertEqual(pastedText, "fresh dictation")
        XCTAssertEqual(pasteboard.string(forType: .string), "older copied text")
    }

    func testNewCopyDuringPasteIsNotOverwrittenByRestore() async throws {
        let pasteboard = NSPasteboard(name: .init(UUID().uuidString))
        pasteboard.clearContents()
        pasteboard.setString("older copied text", forType: .string)
        let transaction = ClipboardPasteTransaction(pasteboard: pasteboard, restoreDelay: 0.01)

        try await transaction.paste(text: "fresh dictation", preserveClipboard: true, focusDelay: 0) {
            pasteboard.clearContents()
            pasteboard.setString("new user copy", forType: .string)
        }

        XCTAssertEqual(pasteboard.string(forType: .string), "new user copy")
    }

    func testChangedClipboardBeforePasteDoesNotPostShortcut() async throws {
        let pasteboard = NSPasteboard(name: .init(UUID().uuidString))
        pasteboard.clearContents()
        pasteboard.setString("older copied text", forType: .string)
        let transaction = ClipboardPasteTransaction(pasteboard: pasteboard, restoreDelay: 0)
        var postedPaste = false
        let externalCopy = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 20_000_000)
            pasteboard.clearContents()
            pasteboard.setString("new user copy", forType: .string)
        }

        do {
            try await transaction.paste(text: "fresh dictation", preserveClipboard: true, focusDelay: 0.1) {
                postedPaste = true
            }
            XCTFail("Expected the changed clipboard to stop injection")
        } catch ClipboardPasteTransactionError.clipboardChanged {
            // The shortcut must not paste unrelated clipboard contents.
        }
        await externalCopy.value
        XCTAssertFalse(postedPaste)
        XCTAssertEqual(pasteboard.string(forType: .string), "new user copy")
    }
}
