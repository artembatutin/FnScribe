//
//  ModelManager.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import Foundation
import Combine
import WhisperKit

enum ModelManagerError: LocalizedError {
    case modelNotFound(String)
    case downloadFailed(Error)
    case deletionFailed(Error)
    case invalidModelPath
    case modelAlreadyDownloading
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound(let name):
            return "Model '\(name)' not found"
        case .downloadFailed(let error):
            return "Failed to download model: \(error.localizedDescription)"
        case .deletionFailed(let error):
            return "Failed to delete model: \(error.localizedDescription)"
        case .invalidModelPath:
            return "Invalid model storage path"
        case .modelAlreadyDownloading:
            return "Model is already being downloaded"
        }
    }
}

struct WhisperModel: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let displayName: String
    let sizeDescription: String
    let estimatedSizeMB: Int
    let isMultilingual: Bool
    
    var isEnglishOnly: Bool { name.hasSuffix(".en") }
    
    static let availableModels: [WhisperModel] = [
        WhisperModel(
            id: "openai_whisper-tiny.en",
            name: "tiny.en",
            displayName: "Tiny (English)",
            sizeDescription: "~75 MB",
            estimatedSizeMB: 75,
            isMultilingual: false
        ),
        WhisperModel(
            id: "openai_whisper-tiny",
            name: "tiny",
            displayName: "Tiny (Multilingual)",
            sizeDescription: "~75 MB",
            estimatedSizeMB: 75,
            isMultilingual: true
        ),
        WhisperModel(
            id: "openai_whisper-base.en",
            name: "base.en",
            displayName: "Base (English)",
            sizeDescription: "~140 MB",
            estimatedSizeMB: 140,
            isMultilingual: false
        ),
        WhisperModel(
            id: "openai_whisper-base",
            name: "base",
            displayName: "Base (Multilingual)",
            sizeDescription: "~140 MB",
            estimatedSizeMB: 140,
            isMultilingual: true
        ),
        WhisperModel(
            id: "openai_whisper-small.en",
            name: "small.en",
            displayName: "Small (English)",
            sizeDescription: "~460 MB",
            estimatedSizeMB: 460,
            isMultilingual: false
        ),
        WhisperModel(
            id: "openai_whisper-small",
            name: "small",
            displayName: "Small (Multilingual)",
            sizeDescription: "~460 MB",
            estimatedSizeMB: 460,
            isMultilingual: true
        ),
        WhisperModel(
            id: "openai_whisper-medium.en",
            name: "medium.en",
            displayName: "Medium (English)",
            sizeDescription: "~1.5 GB",
            estimatedSizeMB: 1500,
            isMultilingual: false
        ),
        WhisperModel(
            id: "openai_whisper-medium",
            name: "medium",
            displayName: "Medium (Multilingual)",
            sizeDescription: "~1.5 GB",
            estimatedSizeMB: 1500,
            isMultilingual: true
        ),
        WhisperModel(
            id: "openai_whisper-large-v3",
            name: "large-v3",
            displayName: "Large V3",
            sizeDescription: "~3 GB",
            estimatedSizeMB: 3000,
            isMultilingual: true
        ),
        WhisperModel(
            id: "openai_whisper-large-v3-turbo",
            name: "large-v3-turbo",
            displayName: "Large V3 Turbo",
            sizeDescription: "~1.6 GB",
            estimatedSizeMB: 1600,
            isMultilingual: true
        )
    ]
    
    static func model(forName name: String) -> WhisperModel? {
        availableModels.first { $0.name == name }
    }
    
    static func model(forId id: String) -> WhisperModel? {
        availableModels.first { $0.id == id }
    }
}

@MainActor
class ModelManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var availableModels: [WhisperModel] = WhisperModel.availableModels
    @Published private(set) var downloadedModels: Set<String> = []
    @Published private(set) var selectedModelName: String?
    @Published private(set) var downloadProgress: Double?
    @Published private(set) var isDownloading: Bool = false
    @Published private(set) var currentDownloadingModel: String?
    @Published private(set) var error: ModelManagerError?
    
    // MARK: - Private Properties
    
    private let modelStorageDirectory: URL
    private var downloadTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init() {
        // Store models in Application Support/FnScribe/Models and migrate from legacy app data if needed.
        self.modelStorageDirectory = (try? AppSupportPaths.modelsDirectory()) ??
            FileManager.default.temporaryDirectory.appendingPathComponent("FnScribeModels", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: modelStorageDirectory, withIntermediateDirectories: true)
        
        // Scan for downloaded models
        refreshDownloadedModels()
    }
    
    // MARK: - Public Methods
    
    var selectedModel: WhisperModel? {
        guard let name = selectedModelName else { return nil }
        return WhisperModel.model(forName: name)
    }
    
    func isModelDownloaded(_ model: WhisperModel) -> Bool {
        downloadedModels.contains(model.name)
    }
    
    func selectModel(_ model: WhisperModel) {
        selectedModelName = model.name
    }
    
    func selectModel(byName name: String) {
        if WhisperModel.model(forName: name) != nil {
            selectedModelName = name
        }
    }
    
    func refreshDownloadedModels() {
        var downloaded = Set<String>()
        
        // Check WhisperKit's default model location
        let hubModelsPath = modelStorageDirectory.appendingPathComponent("models/argmaxinc/whisperkit-coreml")
        
        if let contents = try? FileManager.default.contentsOfDirectory(at: hubModelsPath, includingPropertiesForKeys: nil) {
            for url in contents {
                let folderName = url.lastPathComponent
                // Match folder names like "openai_whisper-base.en" to model names
                if let model = WhisperModel.availableModels.first(where: { folderName.contains($0.id) || folderName.contains($0.name) }) {
                    downloaded.insert(model.name)
                }
            }
        }
        
        // Also check for models downloaded directly
        if let contents = try? FileManager.default.contentsOfDirectory(at: modelStorageDirectory, includingPropertiesForKeys: nil) {
            for url in contents {
                let folderName = url.lastPathComponent
                if let model = WhisperModel.availableModels.first(where: { folderName.contains($0.name) }) {
                    downloaded.insert(model.name)
                }
            }
        }
        
        downloadedModels = downloaded
    }
    
    func downloadModel(_ model: WhisperModel) async throws {
        guard !isDownloading else {
            throw ModelManagerError.modelAlreadyDownloading
        }
        
        isDownloading = true
        currentDownloadingModel = model.name
        downloadProgress = 0.0
        error = nil
        
        defer {
            isDownloading = false
            currentDownloadingModel = nil
            downloadProgress = nil
        }
        
        do {
            // Use WhisperKit's built-in model download
            let modelVariant = model.name
            
            // Download the model using WhisperKit's download mechanism
            _ = try await WhisperKit.download(
                variant: modelVariant,
                downloadBase: modelStorageDirectory,
                useBackgroundSession: false
            ) { progress in
                Task { @MainActor in
                    self.downloadProgress = progress.fractionCompleted
                }
            }
            
            // Refresh downloaded models list
            refreshDownloadedModels()
            
        } catch {
            self.error = .downloadFailed(error)
            throw ModelManagerError.downloadFailed(error)
        }
    }
    
    func deleteModel(_ model: WhisperModel) throws {
        // Find and delete the model folder
        let hubModelsPath = modelStorageDirectory.appendingPathComponent("models/argmaxinc/whisperkit-coreml")
        
        if let contents = try? FileManager.default.contentsOfDirectory(at: hubModelsPath, includingPropertiesForKeys: nil) {
            for url in contents {
                let folderName = url.lastPathComponent
                if folderName.contains(model.id) || folderName.contains(model.name) {
                    do {
                        try FileManager.default.removeItem(at: url)
                    } catch {
                        throw ModelManagerError.deletionFailed(error)
                    }
                }
            }
        }
        
        // Also check direct model folder
        let directPath = modelStorageDirectory.appendingPathComponent(model.name)
        if FileManager.default.fileExists(atPath: directPath.path) {
            do {
                try FileManager.default.removeItem(at: directPath)
            } catch {
                throw ModelManagerError.deletionFailed(error)
            }
        }
        
        // If deleted model was selected, clear selection
        if selectedModelName == model.name {
            selectedModelName = nil
        }
        
        refreshDownloadedModels()
    }
    
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        currentDownloadingModel = nil
        downloadProgress = nil
    }
    
    func getModelPath(for model: WhisperModel) -> String? {
        // Check WhisperKit's hub location first
        let hubModelsPath = modelStorageDirectory.appendingPathComponent("models/argmaxinc/whisperkit-coreml")
        
        if let contents = try? FileManager.default.contentsOfDirectory(at: hubModelsPath, includingPropertiesForKeys: nil) {
            for url in contents {
                let folderName = url.lastPathComponent
                if folderName.contains(model.id) || folderName.contains(model.name) {
                    return url.path
                }
            }
        }
        
        // Check direct path
        let directPath = modelStorageDirectory.appendingPathComponent(model.name)
        if FileManager.default.fileExists(atPath: directPath.path) {
            return directPath.path
        }
        
        return nil
    }
    
    var modelStoragePath: String {
        modelStorageDirectory.path
    }
}
