//
//  PlaceholderResolver.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import Foundation
import AppKit

struct PlaceholderResolver {
    
    struct ResolutionContext {
        let date: Date
        let appName: String?
        let clipboard: String?
        let selectedText: String?
        
        init(
            date: Date = Date(),
            appName: String? = nil,
            clipboard: String? = nil,
            selectedText: String? = nil
        ) {
            self.date = date
            self.appName = appName
            self.clipboard = clipboard
            self.selectedText = selectedText
        }
    }
    
    struct ResolvedContent {
        let text: String
        let cursorPosition: Int?
    }
    
    func resolve(_ content: String, context: ResolutionContext) -> ResolvedContent {
        var result = content
        
        // Resolve date placeholders
        result = resolveDate(in: result, date: context.date)
        result = resolveTime(in: result, date: context.date)
        result = resolveDateTime(in: result, date: context.date)
        
        // Resolve app placeholder
        result = resolveApp(in: result, appName: context.appName)
        
        // Resolve clipboard placeholder
        result = resolveClipboard(in: result, clipboard: context.clipboard)
        
        // Resolve selected text placeholder
        result = resolveSelected(in: result, selectedText: context.selectedText)
        
        // Resolve cursor placeholder and get position
        let (finalText, cursorPosition) = resolveCursor(in: result)
        
        return ResolvedContent(text: finalText, cursorPosition: cursorPosition)
    }
    
    private func resolveDate(in content: String, date: Date) -> String {
        guard content.contains("{date}") else { return content }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let dateString = formatter.string(from: date)
        
        return content.replacingOccurrences(of: "{date}", with: dateString)
    }
    
    private func resolveTime(in content: String, date: Date) -> String {
        guard content.contains("{time}") else { return content }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        let timeString = formatter.string(from: date)
        
        return content.replacingOccurrences(of: "{time}", with: timeString)
    }
    
    private func resolveDateTime(in content: String, date: Date) -> String {
        guard content.contains("{datetime}") else { return content }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let dateTimeString = formatter.string(from: date)
        
        return content.replacingOccurrences(of: "{datetime}", with: dateTimeString)
    }
    
    private func resolveApp(in content: String, appName: String?) -> String {
        guard content.contains("{app}") else { return content }
        return content.replacingOccurrences(of: "{app}", with: appName ?? "Unknown")
    }
    
    private func resolveClipboard(in content: String, clipboard: String?) -> String {
        guard content.contains("{clipboard}") else { return content }
        
        let clipboardContent: String
        if let provided = clipboard {
            clipboardContent = provided
        } else {
            clipboardContent = NSPasteboard.general.string(forType: .string) ?? ""
        }
        
        return content.replacingOccurrences(of: "{clipboard}", with: clipboardContent)
    }
    
    private func resolveSelected(in content: String, selectedText: String?) -> String {
        guard content.contains("{selected}") else { return content }
        return content.replacingOccurrences(of: "{selected}", with: selectedText ?? "")
    }
    
    private func resolveCursor(in content: String) -> (String, Int?) {
        guard let range = content.range(of: "{cursor}") else {
            return (content, nil)
        }
        
        let position = content.distance(from: content.startIndex, to: range.lowerBound)
        let result = content.replacingOccurrences(of: "{cursor}", with: "")
        
        return (result, position)
    }
}
