//
//  SnippetEditorView.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import SwiftUI

struct SnippetEditorView: View {
    enum Mode {
        case add
        case edit(Snippet)
        
        var title: String {
            switch self {
            case .add:
                return "Add Snippet"
            case .edit:
                return "Edit Snippet"
            }
        }
        
        var snippet: Snippet? {
            switch self {
            case .add:
                return nil
            case .edit(let snippet):
                return snippet
            }
        }
    }
    
    let mode: Mode
    @EnvironmentObject var snippetManager: SnippetManager
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = ""
    @State private var trigger: String = ""
    @State private var content: String = ""
    @State private var category: Snippet.Category = .custom
    @State private var isEnabled: Bool = true
    @State private var showDeleteConfirmation: Bool = false
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !trigger.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var triggerConflict: Bool {
        let normalizedTrigger = trigger.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return snippetManager.snippets.contains { snippet in
            snippet.trigger == normalizedTrigger && snippet.id != mode.snippet?.id
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(mode.title)
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
            .padding()
            
            Divider()
            
            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Name field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g., Email Signature", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    // Trigger field
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Trigger Phrase")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            if triggerConflict {
                                Text("Trigger already exists")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        TextField("e.g., my signature", text: $trigger)
                            .textFieldStyle(.roundedBorder)
                        Text("Say this phrase to insert the snippet")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Category picker
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Category")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("Category", selection: $category) {
                            ForEach(Snippet.Category.allCases, id: \.self) { cat in
                                Label(cat.displayName, systemImage: cat.icon).tag(cat)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    // Content editor
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Content")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(content.count) characters")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        TextEditor(text: $content)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 150, maxHeight: 250)
                            .padding(4)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                            )
                    }
                    
                    // Placeholder buttons
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Insert Placeholder")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(Snippet.placeholders, id: \.key) { placeholder in
                                Button {
                                    content += placeholder.key
                                } label: {
                                    VStack(spacing: 2) {
                                        Text(placeholder.key)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        Text(placeholder.description)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Enabled toggle
                    Toggle("Enabled", isOn: $isEnabled)
                        .toggleStyle(.switch)
                    
                    // Info for edit mode
                    if let snippet = mode.snippet {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            LabeledContent("Created", value: snippet.formattedCreatedAt)
                            if let lastUsed = snippet.formattedLastUsedAt {
                                LabeledContent("Last Used", value: lastUsed)
                            }
                            LabeledContent("Use Count", value: "\(snippet.useCount)")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Footer buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                if case .edit(let snippet) = mode {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Text("Delete")
                    }
                }
                
                Spacer()
                
                Button(mode.title == "Add Snippet" ? "Add" : "Save") {
                    saveSnippet()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid || triggerConflict)
            }
            .padding()
        }
        .frame(width: 500, height: 600)
        .onAppear {
            if let snippet = mode.snippet {
                name = snippet.name
                trigger = snippet.trigger
                content = snippet.content
                category = snippet.category
                isEnabled = snippet.isEnabled
            }
        }
        .alert("Delete Snippet", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let snippet = mode.snippet {
                    snippetManager.removeSnippet(id: snippet.id)
                }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this snippet? This action cannot be undone.")
        }
    }
    
    private func saveSnippet() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTrigger = trigger.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch mode {
        case .add:
            let newSnippet = Snippet(
                name: trimmedName,
                trigger: trimmedTrigger,
                content: trimmedContent,
                category: category,
                isEnabled: isEnabled
            )
            snippetManager.addSnippet(newSnippet)
            
        case .edit(let original):
            var updated = original
            updated.name = trimmedName
            updated.trigger = trimmedTrigger
            updated.content = trimmedContent
            updated.category = category
            updated.isEnabled = isEnabled
            snippetManager.updateSnippet(updated)
        }
        
        dismiss()
    }
}

#Preview("Add Mode") {
    SnippetEditorView(mode: .add)
        .environmentObject(SnippetManager())
}

#Preview("Edit Mode") {
    SnippetEditorView(mode: .edit(Snippet(
        name: "Test Snippet",
        trigger: "test trigger",
        content: "Test content with {date}",
        category: .code
    )))
    .environmentObject(SnippetManager())
}
