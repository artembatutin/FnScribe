//
//  ModelManager.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import Foundation
import Combine
import WhisperKit
import FluidAudio

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

@MainActor
class ModelManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var availableModels: [SpeechModel] = SpeechModel.supportedParakeetModels
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
    private let catalogSession: URLSession
    
    // MARK: - Initialization
    
    init(storageDirectory: URL? = nil, catalogSession: URLSession = .shared) {
        self.catalogSession = catalogSession
        // Store models in Application Support/FnScribe/Models and migrate from legacy app data if needed.
        self.modelStorageDirectory = storageDirectory ?? (try? AppSupportPaths.modelsDirectory()) ??
            FileManager.default.temporaryDirectory.appendingPathComponent("FnScribeModels", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: self.modelStorageDirectory, withIntermediateDirectories: true)
        
        // Scan for downloaded models
        refreshDownloadedModels()
    }
    
    // MARK: - Public Methods
    
    var selectedModel: SpeechModel? {
        guard let name = selectedModelName else { return nil }
        return model(forName: name)
    }

    func model(forName name: String) -> SpeechModel? {
        availableModels.first { $0.name == name }
    }
    
    func isModelDownloaded(_ model: SpeechModel) -> Bool {
        downloadedModels.contains(model.name)
    }
    
    func selectModel(_ model: SpeechModel) {
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
            let (data, response) = try await catalogSession.data(for: request)
            guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            let folders = try JSONDecoder().decode([RepositoryEntry].self, from: data)
            let supported = Set(await WhisperKit.recommendedRemoteModels().supported)
            let remoteModels = folders.compactMap { entry -> SpeechModel? in
                guard entry.type == "directory", supported.contains(entry.path) else { return nil }
                return SpeechModel.repositoryModel(forId: entry.path)
            }
            guard !remoteModels.isEmpty else { throw URLError(.cannotParseResponse) }

            let localModels = locallyDownloadedModels()
            availableModels = Array(Dictionary(
                (SpeechModel.supportedParakeetModels + remoteModels + localModels).map { ($0.id, $0) },
                uniquingKeysWith: { remote, _ in remote }
            ).values).sorted(by: Self.sortModels)
            refreshDownloadedModels()
        } catch {
            // Keep local models usable while offline, without advertising stale downloads.
            availableModels = (SpeechModel.supportedParakeetModels + locallyDownloadedModels()).reduce(into: [SpeechModel]()) { models, model in
                if !models.contains(where: { $0.id == model.id }) { models.append(model) }
            }.sorted(by: Self.sortModels)
            refreshDownloadedModels()
            catalogError = "Couldn’t load the current model list. Check your connection and retry."
        }
    }

    private struct RepositoryEntry: Decodable {
        let path: String
        let type: String
    }

    private func locallyDownloadedModels() -> [SpeechModel] {
        let hubDirectory = modelStorageDirectory
            .appendingPathComponent("models/argmaxinc/whisperkit-coreml", isDirectory: true)
        let folders = [hubDirectory, modelStorageDirectory].flatMap { directory in
            (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        }
        let whisperModels = Array(Dictionary(folders.compactMap { folder -> (String, SpeechModel)? in
            guard AppSupportPaths.isCompleteModel(at: folder) else { return nil }
            let id = folder.lastPathComponent
            let model = SpeechModel.repositoryModel(forId: id)
                ?? SpeechModel.model(forName: id)
            guard let model else { return nil }
            return (model.id, model)
        }, uniquingKeysWith: { first, _ in first }).values)
        return whisperModels + SpeechModel.supportedParakeetModels.filter { $0.completeParakeetPath(in: modelStorageDirectory) != nil }
    }

    private static func sortModels(_ lhs: SpeechModel, _ rhs: SpeechModel) -> Bool {
        let order = ["parakeet-ultra", "parakeet-tdt", "tiny", "base", "small", "medium", "large", "distil"]
        let lhsRank = order.firstIndex(where: { lhs.name.hasPrefix($0) }) ?? order.count
        let rhsRank = order.firstIndex(where: { rhs.name.hasPrefix($0) }) ?? order.count
        return lhsRank == rhsRank ? lhs.name < rhs.name : lhsRank < rhsRank
    }
    
    func downloadModel(_ model: SpeechModel) async throws {
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
            if let version = model.backend.parakeetVersion {
                // ModelHub downloads all components as one operation, with byte progress.
                // AsrModels.download loads each component separately and resets progress.
                try await ModelHub.download(
                    version == .ultra ? .parakeetUltra : .parakeetV3,
                    to: model.parakeetDirectory(in: modelStorageDirectory).deletingLastPathComponent(),
                    variant: version == .v3 ? "int8" : nil
                ) { progress in
                    Task { @MainActor in
                        guard self.currentDownloadingModel == model.name else { return }
                        self.downloadProgress = min(1, progress.fractionCompleted * 2)
                    }
                }
            } else {
                let folder = try await WhisperKit.download(
                    variant: model.id,
                    downloadBase: modelStorageDirectory,
                    useBackgroundSession: false
                ) { progress in
                    Task { @MainActor in
                        guard self.currentDownloadingModel == model.name else { return }
                        self.downloadProgress = progress.fractionCompleted
                    }
                }
                guard AppSupportPaths.isCompleteModel(at: folder) else {
                    throw ModelManagerError.invalidModelPath
                }
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
    
    func deleteModel(_ model: SpeechModel) throws {
        if let path = model.isParakeet ? model.parakeetDirectory(in: modelStorageDirectory).path : getModelPath(for: model),
           FileManager.default.fileExists(atPath: path) {
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
    
    func getModelPath(for model: SpeechModel) -> String? {
        if model.isParakeet {
            return model.completeParakeetPath(in: modelStorageDirectory)?.path
        }
        return AppSupportPaths.completeModelPath(
            id: model.id,
            name: model.name,
            in: modelStorageDirectory
        )?.path
    }
    
    var modelStoragePath: String {
        modelStorageDirectory.path
    }
}
