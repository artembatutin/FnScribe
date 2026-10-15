//
//  DictionarySettingsView.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import SwiftUI
import UniformTypeIdentifiers

struct DictionarySettingsView: View {
    @EnvironmentObject var dictionaryManager: DictionaryManager
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var sentenceRefiner: SentenceRefiner
    @EnvironmentObject var correctionLearner: CorrectionLearner
    
    @State private var showAddEntry: Bool = false
    @State private var showImportExport: Bool = false
    @State private var showLoadDeveloperTerms: Bool = false
    @State private var showClearConfirmation: Bool = false
    @State private var importResult: String?
    @State private var showSuggestions = false
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            Picker("Dictionary content", selection: $showSuggestions) {
                Text("Entries (\(dictionaryManager.totalEntries))").tag(false)
                Text("Suggestions (\(dictionaryManager.suggestions.count))").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 8)

            if let error = dictionaryManager.lastError {
                Text(error).font(.caption).foregroundColor(.red).padding(.horizontal)
            }
            if dictionaryManager.isLoading {
                ProgressView("Loading dictionary...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if showSuggestions {
                suggestionsListView
            } else {
                entriesListView
            }
        }
        .task {
            await dictionaryManager.load()
            sentenceRefiner.refreshAvailability()
        }
        .onChange(of: settingsStore.autoLearnCorrections) { _, enabled in
            if !enabled { correctionLearner.stopMonitoring() }
        }
        .onChange(of: settingsStore.dictionaryEnabled) { _, enabled in
            if !enabled { correctionLearner.stopMonitoring() }
        }
        .sheet(isPresented: $showAddEntry) {
            AddDictionaryEntryView()
                .environmentObject(dictionaryManager)
        }
        .alert("Load Developer Terms", isPresented: $showLoadDeveloperTerms) {
            Button("Load") {
                dictionaryManager.loadDeveloperTerms()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will add \(DeveloperTermsDatabase.terms.count) common developer terms to your dictionary. Existing entries will not be overwritten.")
        }
        .alert("Clear Dictionary", isPresented: $showClearConfirmation) {
            Button("Clear All", role: .destructive) {
                dictionaryManager.clearAll()
            }
            Button("Clear Suggestions and Ignored Words") {
                dictionaryManager.clearSuggestions()
            }
            Button("Clear Auto-Learned Only") {
                dictionaryManager.clearAutoLearned()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose what to clear from your dictionary.")
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                Toggle("Enable Dictionary", isOn: $settingsStore.dictionaryEnabled)
                    .toggleStyle(.switch)
                
                Spacer()
                
                Toggle("Auto-Learn", isOn: $settingsStore.autoLearnCorrections)
                    .toggleStyle(.switch)
                    .help("Learn a related spelling change when you copy your corrected dictation within 30 seconds.")
                    .disabled(!settingsStore.dictionaryEnabled)
            }
            
            HStack {
                Toggle("Suggest unusual words", isOn: $settingsStore.detectUnusualWords)
                    .toggleStyle(.switch)
                    .disabled(!settingsStore.dictionaryEnabled)
                    .help("Collect unfamiliar words from dictation for you to review and add to your dictionary.")
                Spacer()
                Toggle("Refine sentences", isOn: $settingsStore.sentenceRefinementEnabled)
                    .toggleStyle(.switch)
                    .help("Fix grammar locally, adding Apple Intelligence sentence rewriting when available.")
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    Text(sentenceRefiner.modelAvailability)
                        .font(.caption).foregroundColor(.secondary)
                    Spacer(minLength: 8)
                    Button("Refresh") { sentenceRefiner.refreshAvailability() }
                        .buttonStyle(.borderless).font(.caption)
                        .help("Check Apple Intelligence availability")
                }
                if settingsStore.sentenceRefinementEnabled, let status = sentenceRefiner.lastStatus {
                    Text(status).font(.caption).foregroundColor(.secondary)
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Personal Dictionary")
                        .font(.headline)
                    Text("\(dictionaryManager.totalEntries) entries (\(dictionaryManager.manualCount) manual, \(dictionaryManager.autoLearnedCount) auto-learned)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Menu {
                        Button {
                            showLoadDeveloperTerms = true
                        } label: {
                            Label("Load Developer Terms", systemImage: "chevron.left.forwardslash.chevron.right")
                        }
                        
                        Divider()
                        
                        Button {
                            exportDictionary()
                        } label: {
                            Label("Export...", systemImage: "square.and.arrow.up")
                        }
                        
                        Button {
                            importDictionary()
                        } label: {
                            Label("Import...", systemImage: "square.and.arrow.down")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            showClearConfirmation = true
                        } label: {
                            Label("Clear...", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                    
                    Button {
                        showAddEntry = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(!dictionaryManager.isLoaded)
                }
            }
            
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search entries...", text: $dictionaryManager.searchText)
                    .textFieldStyle(.plain)
                
                if !dictionaryManager.searchText.isEmpty {
                    Button {
                        dictionaryManager.searchText = ""
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
                    CategoryFilterButton(
                        title: "All",
                        isSelected: dictionaryManager.selectedCategory == nil,
                        count: dictionaryManager.entries.count
                    ) {
                        dictionaryManager.selectedCategory = nil
                    }
                    
                    ForEach(DictionaryEntry.Category.allCases, id: \.self) { category in
                        let count = dictionaryManager.entriesByCategory[category]?.count ?? 0
                        CategoryFilterButton(
                            title: category.displayName,
                            isSelected: dictionaryManager.selectedCategory == category,
                            count: count
                        ) {
                            dictionaryManager.selectedCategory = category
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
    
    private var suggestionsListView: some View {
        let search = dictionaryManager.searchText.lowercased()
        let suggestions = dictionaryManager.suggestions.filter {
            search.isEmpty || $0.word.lowercased().contains(search) || $0.context.lowercased().contains(search)
        }
        return Group {
            if suggestions.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "text.magnifyingglass").font(.largeTitle).foregroundColor(.secondary)
                    Text("No vocabulary suggestions yet").font(.headline)
                    Text("With unusual-word suggestions enabled, dictate normally. Unfamiliar names and words will appear here for review.")
                        .font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
                }
                .padding().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(suggestions) { suggestion in
                    VocabularySuggestionRow(suggestion: suggestion,
                        onAdd: { dictionaryManager.acceptSuggestion(suggestion, writtenForm: $0) },
                        onIgnore: { dictionaryManager.ignoreSuggestion(suggestion) })
                }
                .listStyle(.inset)
            }
        }
    }

    private var entriesListView: some View {
        Group {
            if dictionaryManager.filteredEntries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "book.closed")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No entries found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Add entries manually or load developer terms to get started.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(dictionaryManager.filteredEntries) { entry in
                        DictionaryEntryRowView(entry: entry)
                            .environmentObject(dictionaryManager)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let entry = dictionaryManager.filteredEntries[index]
                            dictionaryManager.removeEntry(id: entry.id)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }
    
    private func exportDictionary() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = AppBranding.dictionaryExportFileName
        
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                do {
                    try await dictionaryManager.exportEntries(to: url)
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
    
    private func importDictionary() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                do {
                    let count = try await dictionaryManager.importEntries(from: url)
                    importResult = "Imported \(count) entries!"
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

struct CategoryFilterButton: View {
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

// MARK: - Dictionary Entry Row

struct DictionaryEntryRowView: View {
    let entry: DictionaryEntry
    @EnvironmentObject var dictionaryManager: DictionaryManager
    
    @State private var isEditing: Bool = false
    @State private var editedSpokenForm: String = ""
    @State private var editedWrittenForm: String = ""
    @State private var editedCategory: DictionaryEntry.Category = .custom
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.category.icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("\"\(entry.spokenForm)\"")
                        .foregroundColor(.secondary)
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(entry.writtenForm)
                        .fontWeight(.medium)
                }
                
                HStack(spacing: 8) {
                    Text(entry.category.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(4)
                    
                    if entry.isAutoLearned {
                        Label("Auto", systemImage: "sparkles")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    
                    if entry.useCount > 0 {
                        Text("Used \(entry.useCount)x")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Button {
                editedSpokenForm = entry.spokenForm
                editedWrittenForm = entry.writtenForm
                editedCategory = entry.category
                isEditing = true
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $isEditing) {
            EditDictionaryEntryView(
                entry: entry,
                spokenForm: $editedSpokenForm,
                writtenForm: $editedWrittenForm,
                category: $editedCategory
            )
            .environmentObject(dictionaryManager)
        }
    }
}

// MARK: - Add Dictionary Entry View

struct AddDictionaryEntryView: View {
    @EnvironmentObject var dictionaryManager: DictionaryManager
    @Environment(\.dismiss) var dismiss
    
    @State private var spokenForm: String = ""
    @State private var writtenForm: String = ""
    @State private var category: DictionaryEntry.Category = .custom
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Dictionary Entry")
                .font(.headline)
            
            Form {
                TextField("Spoken Form (e.g., \"super base\")", text: $spokenForm)
                TextField("Written Form (e.g., \"Supabase\")", text: $writtenForm)
                
                Picker("Category", selection: $category) {
                    ForEach(DictionaryEntry.Category.allCases, id: \.self) { cat in
                        Label(cat.displayName, systemImage: cat.icon).tag(cat)
                    }
                }
            }
            .formStyle(.grouped)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Add") {
                    dictionaryManager.addEntry(
                        spokenForm: spokenForm,
                        writtenForm: writtenForm,
                        category: category
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(spokenForm.isEmpty || writtenForm.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 280)
    }
}

// MARK: - Edit Dictionary Entry View

struct EditDictionaryEntryView: View {
    let entry: DictionaryEntry
    @Binding var spokenForm: String
    @Binding var writtenForm: String
    @Binding var category: DictionaryEntry.Category
    
    @EnvironmentObject var dictionaryManager: DictionaryManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Dictionary Entry")
                .font(.headline)
            
            Form {
                TextField("Spoken Form", text: $spokenForm)
                TextField("Written Form", text: $writtenForm)
                
                Picker("Category", selection: $category) {
                    ForEach(DictionaryEntry.Category.allCases, id: \.self) { cat in
                        Label(cat.displayName, systemImage: cat.icon).tag(cat)
                    }
                }
                
                Section {
                    LabeledContent("Created", value: entry.formattedCreatedAt)
                    if let lastUsed = entry.formattedLastUsedAt {
                        LabeledContent("Last Used", value: lastUsed)
                    }
                    LabeledContent("Use Count", value: "\(entry.useCount)")
                }
            }
            .formStyle(.grouped)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button(role: .destructive) {
                    dictionaryManager.removeEntry(id: entry.id)
                    dismiss()
                } label: {
                    Text("Delete")
                }
                
                Button("Save") {
                    var updated = entry
                    updated.spokenForm = spokenForm.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    updated.writtenForm = writtenForm.trimmingCharacters(in: .whitespacesAndNewlines)
                    updated.category = category
                    dictionaryManager.updateEntry(updated)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(spokenForm.isEmpty || writtenForm.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 380)
    }
}

#Preview {
    DictionarySettingsView()
        .environmentObject(DictionaryManager())
        .environmentObject(SentenceRefiner())
        .environmentObject(CorrectionLearner())
        .frame(width: 500, height: 450)
}

private struct VocabularySuggestionRow: View {
    let suggestion: VocabularySuggestion
    let onAdd: (String) -> Void
    let onIgnore: () -> Void
    @State private var writtenForm: String

    init(suggestion: VocabularySuggestion, onAdd: @escaping (String) -> Void, onIgnore: @escaping () -> Void) {
        self.suggestion = suggestion
        self.onAdd = onAdd
        self.onIgnore = onIgnore
        _writtenForm = State(initialValue: suggestion.alternatives.first ?? suggestion.word)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(suggestion.word).font(.headline)
                Spacer()
                Text("Heard \(suggestion.occurrences)×").font(.caption).foregroundColor(.secondary)
            }
            Text(suggestion.context).font(.caption).foregroundColor(.secondary).lineLimit(2)
            HStack {
                TextField("Written spelling", text: $writtenForm).textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Written spelling for \(suggestion.word)")
                Button("Add correction") { onAdd(writtenForm) }
                    .disabled(writtenForm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Keep spelling") { onAdd(suggestion.word) }
                Button("Ignore", action: onIgnore).buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 6)
    }
}
