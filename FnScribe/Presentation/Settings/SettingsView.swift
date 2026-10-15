//
//  SettingsView.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import SwiftUI

// MARK: - Settings Navigation

enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General"
    case hotkeys = "Hotkeys"
    case models = "Models"
    case injection = "Injection"
    case autoFocus = "Auto-Focus"
    case overlay = "Overlay"
    case dictionary = "Dictionary"
    case snippets = "Snippets"
    case fileTagging = "File Tagging"
    case permissions = "Permissions"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .general: return "gear"
        case .hotkeys: return "keyboard"
        case .models: return "cpu"
        case .injection: return "text.cursor"
        case .autoFocus: return "target"
        case .overlay: return "rectangle.on.rectangle"
        case .dictionary: return "book.closed"
        case .snippets: return "doc.text"
        case .fileTagging: return "at"
        case .permissions: return "lock.shield"
        }
    }
    
    var category: SettingsCategory {
        switch self {
        case .general, .hotkeys, .models:
            return .general
        case .injection, .autoFocus, .overlay:
            return .behavior
        case .dictionary, .snippets, .fileTagging:
            return .content
        case .permissions:
            return .system
        }
    }
}

enum SettingsCategory: String, CaseIterable {
    case general = "General"
    case behavior = "Behavior"
    case content = "Content"
    case system = "System"
    
    var sections: [SettingsSection] {
        SettingsSection.allCases.filter { $0.category == self }
    }
}

struct SettingsView: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var permissionsManager: PermissionsManager
    
    @State private var selectedSection: SettingsSection = .general
    
    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
        .frame(minWidth: 720, minHeight: 520)
        .frame(idealWidth: 800, idealHeight: 580)
    }
    
    // MARK: - Sidebar
    
    private var sidebar: some View {
        List(selection: $selectedSection) {
            ForEach(SettingsCategory.allCases, id: \.self) { category in
                Section {
                    ForEach(category.sections) { section in
                        sidebarRow(for: section)
                            .tag(section)
                    }
                } header: {
                    Text(category.rawValue)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
    }
    
    private func sidebarRow(for section: SettingsSection) -> some View {
        Label {
            Text(section.rawValue)
        } icon: {
            Image(systemName: section.icon)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Detail View
    
    @ViewBuilder
    private var detailView: some View {
        switch selectedSection {
        case .general:
            GeneralSettingsView()
        case .hotkeys:
            HotkeySettingsView()
        case .models:
            ModelSettingsView()
        case .injection:
            InjectionSettingsView()
        case .autoFocus:
            InputFieldSettingsView()
        case .overlay:
            OverlaySettingsView()
        case .dictionary:
            DictionarySettingsView()
        case .snippets:
            SnippetsSettingsView()
        case .fileTagging:
            FileTaggingSettingsView()
        case .permissions:
            PermissionsSettingsView()
        }
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @EnvironmentObject var settingsStore: SettingsStore
    
    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: $settingsStore.launchAtLogin)
                Toggle("Play Feedback Sounds", isOn: $settingsStore.playFeedbackSounds)
                Toggle("Show Overlay", isOn: $settingsStore.showOverlay)
            } header: {
                Text("General")
            }
            
            Section {
                Toggle("Save History", isOn: $settingsStore.saveHistory)
                
                if settingsStore.saveHistory {
                    Stepper("Max History Items: \(settingsStore.maxHistoryItems)",
                            value: $settingsStore.maxHistoryItems,
                            in: 10...500,
                            step: 10)
                }
            } header: {
                Text("History")
            }

            Section {
                Toggle("Enable Syntax Transformations", isOn: $settingsStore.syntaxTransformEnabled)

                Toggle("Case Transformations", isOn: $settingsStore.caseTransformationsEnabled)
                    .disabled(!settingsStore.syntaxTransformEnabled)

                Toggle("CLI Patterns", isOn: $settingsStore.cliPatternsEnabled)
                    .disabled(!settingsStore.syntaxTransformEnabled)

                Picker("Code Symbols", selection: Binding(
                    get: { settingsStore.codeSymbolsMode },
                    set: { settingsStore.codeSymbolsMode = $0 }
                )) {
                    ForEach(CodeSymbolsMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .disabled(!settingsStore.syntaxTransformEnabled)

                Text(settingsStore.codeSymbolsMode.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Syntax")
            }
            
            Section {
                Button("Reset to Defaults") {
                    settingsStore.resetToDefaults()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Hotkey Settings

struct HotkeySettingsView: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var hotkeyManager: HotkeyManager
    
    @State private var selectedPreset: HotkeyPreset = .fn
    @State private var showConflictWarning: Bool = false
    
    var body: some View {
        Form {
            Section {
                Picker("Trigger Mode", selection: Binding(
                    get: { settingsStore.triggerMode },
                    set: { settingsStore.triggerMode = $0 }
                )) {
                    ForEach(TriggerMode.allCases, id: \.self) { mode in
                        VStack(alignment: .leading) {
                            Text(mode.displayName)
                        }
                        .tag(mode)
                    }
                }
                
                Text(settingsStore.triggerMode.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Trigger Mode")
            }
            
            Section {
                // Current hotkey display
                HStack {
                    Text("Current Hotkey")
                    Spacer()
                    HotkeyBadgeView(keyCombo: hotkeyManager.currentKeyCombo)
                }
                
                // Preset selection
                Picker("Preset", selection: $selectedPreset) {
                    ForEach(HotkeyPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .onChange(of: selectedPreset) { _, newPreset in
                    if newPreset != .custom, let keyCombo = newPreset.keyCombo {
                        if hotkeyManager.checkForConflicts(with: keyCombo) {
                            showConflictWarning = true
                        } else {
                            hotkeyManager.registerPreset(newPreset)
                        }
                    }
                }
                
                // Custom hotkey recorder
                if selectedPreset == .custom {
                    HotkeyRecorderView()
                }
                
                // Status indicator
                HStack {
                    Image(systemName: hotkeyManager.isListening ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(hotkeyManager.isListening ? .green : .red)
                    Text(hotkeyManager.isListening ? "Hotkey active" : "Hotkey inactive")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Hotkey")
            }
            
            Section {
                if settingsStore.triggerMode == .pushToTalk {
                    Text("Hold the hotkey to record, release to transcribe and inject text.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Press the hotkey once to start recording, press again to stop and transcribe.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if hotkeyManager.isHotkeyPressed {
                    HStack {
                        Image(systemName: "mic.fill")
                            .foregroundColor(.red)
                        Text("Hotkey is currently pressed")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            } header: {
                Text("Instructions")
            }
            
            if let error = hotkeyManager.lastError {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Warning")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            updateSelectedPreset()
        }
        .alert("Hotkey Conflict", isPresented: $showConflictWarning) {
            Button("Use Anyway") {
                if let keyCombo = selectedPreset.keyCombo {
                    hotkeyManager.registerHotkey(keyCombo)
                }
            }
            Button("Cancel", role: .cancel) {
                updateSelectedPreset()
            }
        } message: {
            Text("This hotkey may conflict with system shortcuts or other applications. Using it might cause unexpected behavior.")
        }
    }
    
    private func updateSelectedPreset() {
        let currentCombo = hotkeyManager.currentKeyCombo
        if currentCombo == .fnKey {
            selectedPreset = .fn
        } else if currentCombo == .controlSpace {
            selectedPreset = .controlSpace
        } else if currentCombo == .optionSpace {
            selectedPreset = .optionSpace
        } else {
            selectedPreset = .custom
        }
    }
}

// MARK: - Hotkey Badge View

struct HotkeyBadgeView: View {
    let keyCombo: KeyCombo
    
    var body: some View {
        Text(keyCombo.displayName)
            .font(.system(.body, design: .rounded))
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.15))
            .foregroundColor(.accentColor)
            .cornerRadius(6)
    }
}

// MARK: - Hotkey Recorder View

struct HotkeyRecorderView: View {
    @EnvironmentObject var hotkeyManager: HotkeyManager
    
    var body: some View {
        HStack {
            Text("Custom Hotkey")
            Spacer()
            
            if hotkeyManager.isRecordingHotkey {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Press keys...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Cancel") {
                        hotkeyManager.cancelRecordingHotkey()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            } else {
                Button("Record Hotkey") {
                    hotkeyManager.startRecordingHotkey { newKeyCombo in
                        // Hotkey recorded and registered
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}

// MARK: - Model Settings

struct ModelSettingsView: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var modelManager: ModelManager
    @EnvironmentObject var speechRecognizer: SpeechRecognizer
    
    @State private var showDeleteConfirmation = false
    @State private var modelToDelete: SpeechModel?
    @State private var operationError: String?

    private var selectedModel: SpeechModel? {
        modelManager.model(forName: settingsStore.selectedModel)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Speech models")
                        .font(.title2.weight(.semibold))
                    Text("Choose a model to use for dictation on this Mac.")
                        .foregroundColor(.secondary)
                }

                selectedModelCard

                if let error = operationError ?? speechRecognizer.error?.localizedDescription {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Available models")
                            .font(.headline)
                        Spacer()
                        if modelManager.isRefreshingCatalog {
                            ProgressView().controlSize(.small)
                        } else {
                            Button("Refresh") {
                                Task { await modelManager.refreshCatalog() }
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    Text("Parakeet Ultra and V3 support 25 languages with automatic language detection on Apple Silicon. Downloaded models work offline. Whisper models remain available for other languages.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let catalogError = modelManager.catalogError {
                        Text(catalogError)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if modelManager.availableModels.isEmpty && !modelManager.isRefreshingCatalog {
                        Text("No models available yet. Refresh to load the catalog.")
                            .foregroundColor(.secondary)
                    }

                    LazyVStack(spacing: 0) {
                        ForEach(modelManager.availableModels) { model in
                            if model.id != modelManager.availableModels.first?.id {
                                Divider().padding(.leading, 16)
                            }
                            ModelRowView(
                                model: model,
                                isSelected: settingsStore.selectedModel == model.name,
                                isDownloaded: modelManager.isModelDownloaded(model),
                                isDownloading: modelManager.currentDownloadingModel == model.name,
                                downloadProgress: modelManager.currentDownloadingModel == model.name ? modelManager.downloadProgress : nil,
                                isBusy: modelManager.isDownloading || speechRecognizer.isLoading,
                                isLoading: speechRecognizer.isLoading && settingsStore.selectedModel == model.name,
                                isModelLoaded: speechRecognizer.currentModelName == model.name && speechRecognizer.isModelLoaded,
                                onUse: { activate(model) },
                                onDownload: { downloadAndActivate(model) },
                                onDelete: {
                                    modelToDelete = model
                                    showDeleteConfirmation = true
                                }
                            )
                        }
                    }
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(24)
        }
        .alert("Delete Model", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                modelToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let model = modelToDelete {
                    do {
                        if settingsStore.selectedModel == model.name {
                            speechRecognizer.unloadModel()
                            AppDependencies.shared.appState.isModelLoaded = false
                        }
                        try modelManager.deleteModel(model)
                        operationError = nil
                    } catch {
                        operationError = error.localizedDescription
                    }
                }
                modelToDelete = nil
            }
        } message: {
            if let model = modelToDelete {
                Text("Are you sure you want to delete '\(model.displayName)'? You can download it again later.")
            }
        }
        .task {
            modelManager.refreshDownloadedModels()
            await modelManager.refreshCatalog()
        }
    }

    private var selectedModelCard: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelectedModelLoaded ? "checkmark.circle.fill" : "waveform")
                .font(.title2)
                .foregroundColor(isSelectedModelLoaded ? .green : .accentColor)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text("Current model")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(selectedModel?.displayName ?? "None selected")
                    .font(.headline)
                Text(currentStatus)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if speechRecognizer.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
    }

    private var currentStatus: String {
        if speechRecognizer.isLoading {
            return selectedModel?.isParakeet == true
                ? "Preparing model for this Mac. The first load can take a few minutes."
                : "Loading model…"
        }
        if isSelectedModelLoaded { return "Ready for dictation" }
        guard let selectedModel else { return "Choose a model below" }
        return modelManager.isModelDownloaded(selectedModel)
            ? "Downloaded. Select Load model below to use it."
            : "Download this model below to get started."
    }

    private var isSelectedModelLoaded: Bool {
        speechRecognizer.isModelLoaded &&
            speechRecognizer.currentModelName == settingsStore.selectedModel
    }

    private func activate(_ model: SpeechModel) {
        operationError = nil
        settingsStore.selectedModel = model.name
        modelManager.selectModel(model)
        Task {
            await AppDependencies.shared.loadSelectedModel()
        }
    }

    private func downloadAndActivate(_ model: SpeechModel) {
        operationError = nil
        Task {
            do {
                try await modelManager.downloadModel(model)
                activate(model)
            } catch {
                operationError = error.localizedDescription
            }
        }
    }
}

struct ModelRowView: View {
    let model: SpeechModel
    let isSelected: Bool
    let isDownloaded: Bool
    let isDownloading: Bool
    let downloadProgress: Double?
    let isBusy: Bool
    let isLoading: Bool
    let isModelLoaded: Bool
    let onUse: () -> Void
    let onDownload: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(model.displayName)
                        .fontWeight(isSelected ? .semibold : .medium)
                    if isSelected { Text("Selected").font(.caption2).foregroundColor(.accentColor) }
                }
                Text("\(model.detail)  ·  \(isDownloaded ? "Downloaded" : "Not downloaded")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer(minLength: 8)
            
            if isDownloading {
                VStack(alignment: .trailing, spacing: 3) {
                    ProgressView(value: downloadProgress ?? 0)
                        .frame(width: 110)
                    Text("Downloading \(Int((downloadProgress ?? 0) * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if isDownloaded {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading…").font(.caption).foregroundColor(.secondary)
                } else if isModelLoaded {
                    Label("Ready", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Button(isSelected ? "Load model" : "Use model", action: onUse)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(isBusy)
                }
                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete \(model.displayName)")
                .accessibilityLabel("Delete \(model.displayName)")
                .disabled(isBusy)
            } else {
                Button("Download & use", action: onDownload)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isBusy)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Injection Settings

struct InjectionSettingsView: View {
    @EnvironmentObject var settingsStore: SettingsStore
    
    var body: some View {
        Form {
            Section {
                Toggle("Auto-inject after transcription", isOn: $settingsStore.autoInject)
            } header: {
                Text("Behavior")
            }
            
            Section {
                Picker("Injection Mode", selection: Binding(
                    get: { settingsStore.injectionMode },
                    set: { settingsStore.injectionMode = $0 }
                )) {
                    ForEach(InjectionMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                
                Text(settingsStore.injectionMode.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if settingsStore.injectionMode == .clipboardPaste || settingsStore.injectionMode == .hybrid {
                    Toggle("Preserve Clipboard Contents", isOn: $settingsStore.preserveClipboard)
                }
            } header: {
                Text("Method")
            }
            
            if settingsStore.injectionMode == .keystrokeSimulation || settingsStore.injectionMode == .hybrid {
                Section {
                    Slider(value: $settingsStore.typingDelay, in: 0.001...0.1, step: 0.001) {
                        Text("Typing Delay: \(String(format: "%.3f", settingsStore.typingDelay))s")
                    }
                } header: {
                    Text("Keystroke Settings")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Input Field Settings

struct InputFieldSettingsView: View {
    @EnvironmentObject var inputFieldDetector: InputFieldDetector
    
    @State private var newPatternText: String = ""
    @State private var newPatternMatchType: InputFieldPattern.MatchType = .placeholder
    @State private var showAddPattern: Bool = false
    @State private var testResult: String?
    @State private var isTestingDetection: Bool = false
    
    var body: some View {
        Form {
            Section {
                Toggle("Auto-focus Input Fields", isOn: $inputFieldDetector.autoFocusEnabled)
                
                Text("Automatically detect and focus input fields (like 'Ask anything') before injecting text.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Auto-Focus")
            }
            
            Section {
                ForEach(inputFieldDetector.patterns) { pattern in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pattern.pattern)
                                .fontWeight(.medium)
                            Text(pattern.matchType.rawValue.capitalized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { pattern.enabled },
                            set: { newValue in
                                var updated = pattern
                                updated.enabled = newValue
                                inputFieldDetector.updatePattern(updated)
                            }
                        ))
                        .labelsHidden()
                        
                        Button(role: .destructive) {
                            inputFieldDetector.removePattern(pattern)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                
                if showAddPattern {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Pattern (e.g., 'Ask anything')", text: $newPatternText)
                            .textFieldStyle(.roundedBorder)
                        
                        Picker("Match Type", selection: $newPatternMatchType) {
                            Text("Placeholder").tag(InputFieldPattern.MatchType.placeholder)
                            Text("Title").tag(InputFieldPattern.MatchType.title)
                            Text("Value").tag(InputFieldPattern.MatchType.value)
                            Text("Any").tag(InputFieldPattern.MatchType.any)
                        }
                        .pickerStyle(.segmented)
                        
                        HStack {
                            Button("Add") {
                                if !newPatternText.isEmpty {
                                    let pattern = InputFieldPattern(
                                        pattern: newPatternText,
                                        matchType: newPatternMatchType
                                    )
                                    inputFieldDetector.addPattern(pattern)
                                    newPatternText = ""
                                    showAddPattern = false
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(newPatternText.isEmpty)
                            
                            Button("Cancel") {
                                newPatternText = ""
                                showAddPattern = false
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 4)
                } else {
                    Button {
                        showAddPattern = true
                    } label: {
                        Label("Add Pattern", systemImage: "plus")
                    }
                }
            } header: {
                Text("Detection Patterns")
            }
            
            Section {
                HStack {
                    Button {
                        Task {
                            isTestingDetection = true
                            if let field = await inputFieldDetector.scanForInputField() {
                                testResult = "Found: \(field.role)\nPlaceholder: \(field.placeholder ?? "none")\nApp: \(field.appName)\nConfidence: \(String(format: "%.0f%%", field.confidence * 100))"
                            } else {
                                testResult = "No matching input field found in the frontmost application."
                            }
                            isTestingDetection = false
                        }
                    } label: {
                        if isTestingDetection {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Text("Test Detection")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isTestingDetection)
                    
                    Button("Test Focus") {
                        Task {
                            _ = await inputFieldDetector.scanAndFocus()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                if let result = testResult {
                    Text(result)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }
            } header: {
                Text("Test")
            }
            
            Section {
                Button("Reset to Defaults") {
                    inputFieldDetector.resetPatternsToDefaults()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Overlay Settings

struct OverlaySettingsView: View {
    @EnvironmentObject var settingsStore: SettingsStore
    
    var body: some View {
        Form {
            Section {
                Toggle("Show Overlay", isOn: $settingsStore.showOverlay)
                
                Text("Display a floating overlay during dictation showing status and transcription preview.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Visibility")
            }
            
            if settingsStore.showOverlay {
                Section {
                    Picker("Position", selection: $settingsStore.overlayPosition) {
                        ForEach(OverlayPosition.allCases, id: \.rawValue) { position in
                            Text(position.displayName).tag(position.rawValue)
                        }
                    }
                } header: {
                    Text("Position")
                }
                
                Section {
                    VStack(alignment: .leading) {
                        Text("Opacity: \(Int(settingsStore.overlayOpacity * 100))%")
                        Slider(value: $settingsStore.overlayOpacity, in: 0.5...1.0, step: 0.05)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Size: \(String(format: "%.1fx", settingsStore.overlaySize))")
                        Slider(value: $settingsStore.overlaySize, in: 0.8...1.5, step: 0.1)
                    }
                } header: {
                    Text("Appearance")
                }
                
                Section {
                    VStack(alignment: .leading) {
                        Text("Auto-hide Delay: \(String(format: "%.1f", settingsStore.overlayAutoHideDelay))s")
                        Slider(value: $settingsStore.overlayAutoHideDelay, in: 0.5...5.0, step: 0.5)
                    }
                    
                    Text("How long the overlay stays visible after transcription completes.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Behavior")
                }
                
                Section {
                    Toggle("Real-time Streaming", isOn: $settingsStore.streamingTranscriptionEnabled)
                    
                    Text("Display transcription text as you speak, rather than waiting until recording stops.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if settingsStore.streamingTranscriptionEnabled {
                        VStack(alignment: .leading) {
                            Text("Update Interval: \(String(format: "%.1f", settingsStore.streamingChunkDuration))s")
                            Slider(value: $settingsStore.streamingChunkDuration, in: 0.5...2.0, step: 0.25)
                        }
                        
                        Text("How frequently the streaming text is updated. Lower values provide faster feedback but may be less accurate.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Streaming Transcription")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - File Tagging Settings

struct FileTaggingSettingsView: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var workspaceScanner: WorkspaceScanner
    @EnvironmentObject var fileTagger: FileTagger
    
    @State private var testInput: String = ""
    @State private var testOutput: String = ""
    @State private var isScanning: Bool = false
    
    var body: some View {
        Form {
            Section {
                Toggle("Enable File Tagging", isOn: $settingsStore.fileTaggingEnabled)
                
                Text("Automatically convert spoken file mentions like \"at app delegate\" to @AppDelegate.swift tags in IDEs.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("File Tagging")
            }
            
            if settingsStore.fileTaggingEnabled {
                Section {
                    Toggle("Auto-scan Workspace", isOn: $settingsStore.autoScanWorkspace)
                    
                    Text("Automatically scan the workspace for files when recording starts in an IDE.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Workspace Scanning")
                }
                
                Section {
                    HStack {
                        Text("Workspace Files")
                        Spacer()
                        Text("\(workspaceScanner.workspaceFiles.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    if let root = workspaceScanner.workspaceRoot {
                        HStack {
                            Text("Workspace Root")
                            Spacer()
                            Text(root.lastPathComponent)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    if let lastScan = workspaceScanner.lastScanDate {
                        HStack {
                            Text("Last Scan")
                            Spacer()
                            Text(lastScan, style: .relative)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Button {
                            Task {
                                isScanning = true
                                await workspaceScanner.scanFromFrontmostIDE()
                                isScanning = false
                            }
                        } label: {
                            if isScanning {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Text("Scan Now")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isScanning)
                        
                        Button("Clear Cache") {
                            workspaceScanner.clear()
                        }
                        .buttonStyle(.bordered)
                    }
                } header: {
                    Text("Workspace Status")
                }
                
                Section {
                    TextField("Test input (e.g., 'at app delegate')", text: $testInput)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Test File Tagging") {
                        testOutput = fileTagger.processFileMentions(testInput)
                    }
                    .buttonStyle(.bordered)
                    .disabled(testInput.isEmpty || workspaceScanner.workspaceFiles.isEmpty)
                    
                    if !testOutput.isEmpty {
                        HStack {
                            Text("Result:")
                            Text(testOutput)
                                .foregroundColor(.blue)
                                .fontWeight(.medium)
                        }
                    }
                    
                    if workspaceScanner.workspaceFiles.isEmpty {
                        Text("Scan a workspace first to test file tagging.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Test")
                }
                
                if !workspaceScanner.workspaceFiles.isEmpty {
                    Section {
                        ForEach(workspaceScanner.workspaceFiles.prefix(10)) { file in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.name)
                                    .fontWeight(.medium)
                                Text(file.relativePath)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        if workspaceScanner.workspaceFiles.count > 10 {
                            Text("... and \(workspaceScanner.workspaceFiles.count - 10) more files")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Scanned Files (Preview)")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Permissions Settings

struct PermissionsSettingsView: View {
    @EnvironmentObject var permissionsManager: PermissionsManager
    
    var body: some View {
        Form {
            Section {
                permissionRow(
                    title: "Microphone",
                    description: "Required to capture audio for transcription",
                    granted: permissionsManager.microphoneGranted
                ) {
                    Task {
                        await permissionsManager.requestMicrophoneAccess()
                    }
                }
                
                permissionRow(
                    title: "Accessibility",
                    description: "Required to inject text into applications",
                    granted: permissionsManager.accessibilityGranted
                ) {
                    permissionsManager.openAccessibilitySettings()
                }
                
                permissionRow(
                    title: "Input Monitoring",
                    description: "Required for global hotkey detection",
                    granted: permissionsManager.inputMonitoringGranted
                ) {
                    permissionsManager.openInputMonitoringSettings()
                }
                
                permissionRow(
                    title: "Speech Recognition",
                    description: "Optional, for Apple Speech Recognition fallback",
                    granted: permissionsManager.speechRecognitionGranted
                ) {
                    Task {
                        await permissionsManager.requestSpeechRecognition()
                    }
                }
            } header: {
                Text("Permissions")
            }
            
            Section {
                Button("Refresh Permissions") {
                    permissionsManager.refreshAllPermissions()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private func permissionRow(title: String, description: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(granted ? .green : .red)
                    Text(title)
                }
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !granted {
                Button("Grant") {
                    action()
                }
            }
        }
    }
}

#Preview {
    let settingsStore = SettingsStore()
    let permissionsManager = PermissionsManager()
    let workspaceScanner = WorkspaceScanner()
    SettingsView()
        .environmentObject(settingsStore)
        .environmentObject(permissionsManager)
        .environmentObject(ModelManager())
        .environmentObject(SpeechRecognizer())
        .environmentObject(HotkeyManager(settingsStore: settingsStore))
        .environmentObject(SessionManager(settingsStore: settingsStore))
        .environmentObject(InputFieldDetector())
        .environmentObject(TextInjectionService(
            textInjector: TextInjector(),
            settingsStore: settingsStore,
            permissionsManager: permissionsManager
        ))
        .environmentObject(workspaceScanner)
        .environmentObject(FileTagger(workspaceScanner: workspaceScanner))
}
