//
//  SnippetsSettingsView.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import SwiftUI
import UniformTypeIdentifiers

struct SnippetsSettingsView: View {
    @EnvironmentObject var snippetManager: SnippetManager
    @EnvironmentObject var settingsStore: SettingsStore
    
    @State private var showAddSnippet: Bool = false
    @State private var showLoadBuiltIn: Bool = false
    @State private var showClearConfirmation: Bool = false
    @State private var importResult: String?
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            if snippetManager.isLoading {
                ProgressView("Loading snippets...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                snippetsListView
            }
        }
        .task {
            await snippetManager.load()
        }
        .sheet(isPresented: $showAddSnippet) {
            SnippetEditorView(mode: .add)
                .environmentObject(snippetManager)
        }
        .alert("Load Built-in Snippets", isPresented: $showLoadBuiltIn) {
            Button("Load") {
                snippetManager.loadBuiltInSnippets()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will add \(BuiltInSnippets.snippets.count) built-in snippets for email, code, meetings, and more. Existing snippets will not be overwritten.")
        }
        .alert("Clear Snippets", isPresented: $showClearConfirmation) {
            Button("Clear All", role: .destructive) {
                snippetManager.clearAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all your snippets. This action cannot be undone.")
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                Toggle("Enable Snippets", isOn: $settingsStore.snippetsEnabled)
                    .toggleStyle(.switch)
                
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Snippets Library")
                        .font(.headline)
                    Text("\(snippetManager.totalSnippets) snippets (\(snippetManager.enabledCount) enabled)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Menu {
                        Button {
                            showLoadBuiltIn = true
                        } label: {
                            Label("Load Built-in Snippets", systemImage: "sparkles")
                        }
                        
                        Divider()
                        
                        Button {
                            exportSnippets()
                        } label: {
                            Label("Export...", systemImage: "square.and.arrow.up")
                        }
                        
                        Button {
                            importSnippets()
                        } label: {
                            Label("Import...", systemImage: "square.and.arrow.down")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            showClearConfirmation = true
                        } label: {
                            Label("Clear All...", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                    
                    Button {
                        showAddSnippet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search snippets...", text: $snippetManager.searchText)
                    .textFieldStyle(.plain)
                
                if !snippetManager.searchText.isEmpty {
                    Button {
                        snippetManager.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    SnippetCategoryFilterButton(
                        title: "All",
                        isSelected: snippetManager.selectedCategory == nil,
                        count: snippetManager.snippets.count
                    ) {
                        snippetManager.selectedCategory = nil
                    }
                    
                    ForEach(Snippet.Category.allCases, id: \.self) { category in
                        let count = snippetManager.snippetsByCategory[category]?.count ?? 0
                        SnippetCategoryFilterButton(
                            title: category.displayName,
                            isSelected: snippetManager.selectedCategory == category,
                            count: count
                        ) {
                            snippetManager.selectedCategory = category
                        }
                    }
                }
            }
            
            if let result = importResult {
                Text(result)
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.top, 4)
            }
        }
        .padding()
    }
    
    private var snippetsListView: some View {
        Group {
            if snippetManager.filteredSnippets.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No snippets found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Add snippets manually or load built-in snippets to get started.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Load Built-in Snippets") {
                        showLoadBuiltIn = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(snippetManager.filteredSnippets) { snippet in
                        SnippetRowView(snippet: snippet)
                            .environmentObject(snippetManager)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let snippet = snippetManager.filteredSnippets[index]
                            snippetManager.removeSnippet(id: snippet.id)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }
    
    private func exportSnippets() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = AppBranding.snippetsExportFileName
        
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                do {
                    try await snippetManager.exportSnippets(to: url)
                    importResult = "Exported successfully!"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        importResult = nil
                    }
                } catch {
                    importResult = "Export failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func importSnippets() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                do {
                    let count = try await snippetManager.importSnippets(from: url)
                    importResult = "Imported \(count) snippets!"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        importResult = nil
                    }
                } catch {
                    importResult = "Import failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Category Filter Button

struct SnippetCategoryFilterButton: View {
    let title: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                Text("(\(count))")
                    .foregroundColor(.secondary)
            }
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SnippetsSettingsView()
        .environmentObject(SnippetManager())
        .environmentObject(SettingsStore())
        .frame(width: 500, height: 450)
}
