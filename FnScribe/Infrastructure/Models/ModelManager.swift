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
            return "The model download is incomplete. Please try downloading it again."
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
    
    var isEnglishOnly: Bool { name.hasSuffix(".en") || name.contains(".en_") }
    
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
            id: "openai_whisper-large-v3_turbo",
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

    static func repositoryModel(forId id: String) -> WhisperModel? {
        guard id.hasPrefix("openai_whisper-") || id.hasPrefix("distil-whisper_") else { return nil }
        if let known = model(forId: id) { return known }

        let rawName = id
            .replacingOccurrences(of: "openai_whisper-", with: "")
            .replacingOccurrences(of: "distil-whisper_", with: "distil-")
        let name = rawName.replacingOccurrences(of: "_turbo", with: "-turbo")
        let displayName = name
            .replacingOccurrences(of: ".en", with: " (English)")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
        return WhisperModel(
            id: id,
            name: name,
            displayName: displayName,
            sizeDescription: "Size varies",
            estimatedSizeMB: 0,
            isMultilingual: !rawName.contains(".en")
        )
    }
}

@MainActor
class ModelManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var availableModels: [WhisperModel] = []
    @Published private(set) var isRefreshingCatalog = false
    @Published private(set) var catalogError: String?
    @Published private(set) var downloadedModels: Set<String> = []
    @Published private(set) var selectedModelName: String?
    @Published private(set) var downloadProgress: Double?
    @Published private(set) var isDownloading: Bool = false
    @Published private(set) var currentDownloadingModel: String?
    @Published private(set) var error: ModelManagerError?
    
    // MARK: - Private Properties
    
    private let modelStorageDirectory: URL
    
    // MARK: - Initialization
    
    init() {
        // Store models in Application Support/FnScribe/Models and migrate from legacy app data if needed.
        self.modelStorageDirectory = (try? AppSupportPaths.modelsDirectory()) ??
            FileManager.default.temporaryDirectory.appendingPathComponent("FnScribeModels", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: self.modelStorageDirectory, withIntermediateDirectories: true)
        
        // Scan for downloaded models
        refreshDownloadedModels()
    }
    
    // MARK: - Public Methods
    
    var selectedModel: WhisperModel? {
        guard let name = selectedModelName else { return nil }
        return model(forName: name)
    }

    func model(forName name: String) -> WhisperModel? {
        availableModels.first { $0.name == name }
    }
    
    func isModelDownloaded(_ model: WhisperModel) -> Bool {
        downloadedModels.contains(model.name)
    }
    
    func selectModel(_ model: WhisperModel) {
        selectedModelName = model.name
    }
    
    func selectModel(byName name: String) {
        if model(forName: name) != nil {
            selectedModelName = name
        }
    }
    
    func refreshDownloadedModels() {
        let localModels = locallyDownloadedModels()
        let listed = Set(availableModels.map(\.id))
        availableModels += localModels.filter { !listed.contains($0.id) }
        availableModels.sort(by: Self.sortModels)
        downloadedModels = Set(availableModels.compactMap { model in
            getModelPath(for: model) == nil ? nil : model.name
        })
    }

    func refreshCatalog() async {
        guard !isRefreshingCatalog else { return }
        isRefreshingCatalog = true
        catalogError = nil
        defer { isRefreshingCatalog = false }

        do {
            // List actual folders as well as supported variants: WhisperKit's support
            // config can include old names even when their folders are gone.
            let url = URL(string: "https://huggingface.co/api/models/argmaxinc/whisperkit-coreml/tree/main?recursive=false&limit=1000")!
            var request = URLRequest(url: url)
            request.timeoutInterval = 20
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            let folders = try JSONDecoder().decode([RepositoryEntry].self, from: data)
            let supported = Set(await WhisperKit.recommendedRemoteModels().supported)
            let remoteModels = folders.compactMap { entry -> WhisperModel? in
                guard entry.type == "directory", supported.contains(entry.path) else { return nil }
                return WhisperModel.repositoryModel(forId: entry.path)
            }
            guard !remoteModels.isEmpty else { throw URLError(.cannotParseResponse) }

            let localModels = locallyDownloadedModels()
            availableModels = Array(Dictionary(
                (remoteModels + localModels).map { ($0.id, $0) },
                uniquingKeysWith: { remote, _ in remote }
            ).values).sorted(by: Self.sortModels)
            refreshDownloadedModels()
        } catch {
            // Keep local models usable while offline, without advertising stale downloads.
            availableModels = locallyDownloadedModels().sorted(by: Self.sortModels)
            refreshDownloadedModels()
            catalogError = "Couldn’t load the current model list. Check your connection and retry."
        }
    }

    private struct RepositoryEntry: Decodable {
        let path: String
        let type: String
    }

    private func locallyDownloadedModels() -> [WhisperModel] {
        let hubDirectory = modelStorageDirectory
            .appendingPathComponent("models/argmaxinc/whisperkit-coreml", isDirectory: true)
        let folders = [hubDirectory, modelStorageDirectory].flatMap { directory in
            (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        }
        return Array(Dictionary(folders.compactMap { folder -> (String, WhisperModel)? in
            guard AppSupportPaths.isCompleteModel(at: folder) else { return nil }
            let id = folder.lastPathComponent
            let model = WhisperModel.repositoryModel(forId: id)
                ?? WhisperModel.model(forName: id)
            guard let model else { return nil }
            return (model.id, model)
        }, uniquingKeysWith: { first, _ in first }).values)
    }

    private static func sortModels(_ lhs: WhisperModel, _ rhs: WhisperModel) -> Bool {
        let order = ["tiny", "base", "small", "medium", "large", "distil"]
        let lhsRank = order.firstIndex(where: { lhs.name.hasPrefix($0) }) ?? order.count
        let rhsRank = order.firstIndex(where: { rhs.name.hasPrefix($0) }) ?? order.count
        return lhsRank == rhsRank ? lhs.name < rhs.name : lhsRank < rhsRank
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
            // The exact folder name avoids WhisperKit's wildcard matching
            // confusing base with base.en or large-v3 with large-v3-turbo.
            let modelVariant = model.id
            
            // Download the model using WhisperKit's download mechanism
            let folder = try await WhisperKit.download(
                variant: modelVariant,
                downloadBase: modelStorageDirectory,
                useBackgroundSession: false
            ) { progress in
                Task { @MainActor in
                    self.downloadProgress = progress.fractionCompleted
                }
            }
            
            guard AppSupportPaths.isCompleteModel(at: folder) else {
                throw ModelManagerError.invalidModelPath
            }
            refreshDownloadedModels()
            guard isModelDownloaded(model) else {
                throw ModelManagerError.invalidModelPath
            }
            
        } catch {
            let failure = ModelManagerError.downloadFailed(error)
            self.error = failure
            throw failure
        }
    }
    
    func deleteModel(_ model: WhisperModel) throws {
        if let path = getModelPath(for: model) {
            do {
                try FileManager.default.removeItem(atPath: path)
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
    
    func getModelPath(for model: WhisperModel) -> String? {
        AppSupportPaths.completeModelPath(
            id: model.id,
            name: model.name,
            in: modelStorageDirectory
        )?.path
    }
    
    var modelStoragePath: String {
        modelStorageDirectory.path
    }
}
