//
//  SnippetRowView.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import SwiftUI

struct SnippetRowView: View {
    let snippet: Snippet
    @EnvironmentObject var snippetManager: SnippetManager
    
    @State private var isEditing: Bool = false
    @State private var showPreview: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            Image(systemName: snippet.category.icon)
                .foregroundColor(snippet.isEnabled ? .accentColor : .secondary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(snippet.name)
                        .fontWeight(.medium)
                        .foregroundColor(snippet.isEnabled ? .primary : .secondary)
                    
                    if !snippet.isEnabled {
                        Text("Disabled")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                HStack(spacing: 8) {
                    Text("Say: \"\(snippet.trigger)\"")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(snippet.category.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(4)
                    
                    if snippet.containsPlaceholders {
                        Label("\(snippet.placeholdersList.count)", systemImage: "curlybraces")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    
                    if snippet.useCount > 0 {
                        Text("Used \(snippet.useCount)x")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Content preview
                Text(snippet.content.prefix(80) + (snippet.content.count > 80 ? "..." : ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                // Toggle enabled
                Button {
                    snippetManager.toggleEnabled(id: snippet.id)
                } label: {
                    Image(systemName: snippet.isEnabled ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(snippet.isEnabled ? .green : .secondary)
                }
                .buttonStyle(.borderless)
                .help(snippet.isEnabled ? "Disable snippet" : "Enable snippet")
                
                // Preview
                Button {
                    showPreview = true
                } label: {
                    Image(systemName: "eye")
                }
                .buttonStyle(.borderless)
                .help("Preview snippet")
                
                // Edit
                Button {
                    isEditing = true
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .help("Edit snippet")
                
                // Duplicate
                Button {
                    snippetManager.duplicateSnippet(id: snippet.id)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Duplicate snippet")
            }
        }
        .padding(.vertical, 6)
        .opacity(snippet.isEnabled ? 1.0 : 0.7)
        .sheet(isPresented: $isEditing) {
            SnippetEditorView(mode: .edit(snippet))
                .environmentObject(snippetManager)
        }
        .sheet(isPresented: $showPreview) {
            SnippetPreviewView(snippet: snippet)
                .environmentObject(snippetManager)
        }
    }
}

// MARK: - Snippet Preview View

struct SnippetPreviewView: View {
    let snippet: Snippet
    @EnvironmentObject var snippetManager: SnippetManager
    @Environment(\.dismiss) var dismiss
    
    var resolvedContent: String {
        snippetManager.resolveContent(snippet).text
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: snippet.category.icon)
                    .foregroundColor(.accentColor)
                Text(snippet.name)
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Trigger Phrase")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\"\(snippet.trigger)\"")
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Content Preview")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if snippet.containsPlaceholders {
                        Text("Placeholders resolved")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                
                ScrollView {
                    Text(resolvedContent)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .padding(8)
                .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 250)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
            }
            
            if snippet.containsPlaceholders {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Placeholders Used")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        ForEach(snippet.placeholdersList, id: \.self) { placeholder in
                            Text(placeholder)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            
            HStack {
                if let lastUsed = snippet.formattedLastUsedAt {
                    Text("Last used: \(lastUsed)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("Used \(snippet.useCount) times")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 450, height: 450)
    }
}

#Preview {
    SnippetRowView(snippet: Snippet(
        name: "Test Snippet",
        trigger: "test trigger",
        content: "This is test content with {date} placeholder",
        category: .code
    ))
    .environmentObject(SnippetManager())
    .padding()
}
