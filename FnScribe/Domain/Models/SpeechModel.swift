import Foundation

struct SpeechModel: Identifiable, Equatable, Hashable, Sendable {
    let id: String
    let name: String
    let displayName: String
    let sizeDescription: String
    let estimatedSizeMB: Int
    let isMultilingual: Bool

    enum Backend: String, Sendable {
        case whisperKit, parakeetV3, parakeetUltra
    }

    var backend: Backend = .whisperKit
    var isParakeet: Bool { backend != .whisperKit }
    var detail: String {
        isParakeet ? "25 languages · Automatic language detection · \(sizeDescription)" : sizeDescription
    }

    static let parakeetModels: [SpeechModel] = [
        SpeechModel(id: "FluidInference/parakeet-ultra-coreml", name: "parakeet-ultra",
                    displayName: "Parakeet Ultra (Recommended)", sizeDescription: "~630 MB",
                    estimatedSizeMB: 630, isMultilingual: true, backend: .parakeetUltra),
        SpeechModel(id: "FluidInference/parakeet-tdt-0.6b-v3-coreml", name: "parakeet-tdt-0.6b-v3",
                    displayName: "Parakeet V3", sizeDescription: "~485 MB",
                    estimatedSizeMB: 485, isMultilingual: true, backend: .parakeetV3)
    ]

    static var supportedParakeetModels: [SpeechModel] {
        #if arch(arm64)
        return parakeetModels
        #else
        return []
        #endif
    }

    /// Use FluidAudio's repository folder names so each variant has its own cache.
    func parakeetDirectory(in storage: URL) -> URL {
        storage.appendingPathComponent("parakeet", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
    }

    /// A folder alone is not an installed model. Require all compiled components and vocabulary.
    func completeParakeetPath(in storage: URL, fileManager: FileManager = .default) -> URL? {
        guard isParakeet else { return nil }
        let directory = parakeetDirectory(in: storage)
        let components = ["Preprocessor", "Encoder", "Decoder", "JointDecisionv3"]
        guard components.allSatisfy({ component in
            ["coremldata.bin", "model.mil", "weights/weight.bin"].allSatisfy { file in
                let path = directory.appendingPathComponent("\(component).mlmodelc/\(file)").path
                let size = (try? fileManager.attributesOfItem(atPath: path)[.size]) as? NSNumber
                return (size?.intValue ?? 0) > 0
            }
        }), let data = try? Data(contentsOf: directory.appendingPathComponent("parakeet_vocab.json")),
        let vocabulary = try? JSONSerialization.jsonObject(with: data) as? [String: String],
        (0..<8192).allSatisfy({ vocabulary[String($0)] != nil }) else { return nil }
        return directory
    }

    var isEnglishOnly: Bool { name.hasSuffix(".en") || name.contains(".en_") }

    private static let whisperModels: [SpeechModel] = [
        SpeechModel(
            id: "openai_whisper-tiny.en",
            name: "tiny.en",
            displayName: "Tiny (English)",
            sizeDescription: "~75 MB",
            estimatedSizeMB: 75,
            isMultilingual: false
        ),
        SpeechModel(
            id: "openai_whisper-tiny",
            name: "tiny",
            displayName: "Tiny (Multilingual)",
            sizeDescription: "~75 MB",
            estimatedSizeMB: 75,
            isMultilingual: true
        ),
        SpeechModel(
            id: "openai_whisper-base.en",
            name: "base.en",
            displayName: "Base (English)",
            sizeDescription: "~140 MB",
            estimatedSizeMB: 140,
            isMultilingual: false
        ),
        SpeechModel(
            id: "openai_whisper-base",
            name: "base",
            displayName: "Base (Multilingual)",
            sizeDescription: "~140 MB",
            estimatedSizeMB: 140,
            isMultilingual: true
        ),
        SpeechModel(
            id: "openai_whisper-small.en",
            name: "small.en",
            displayName: "Small (English)",
            sizeDescription: "~460 MB",
            estimatedSizeMB: 460,
            isMultilingual: false
        ),
        SpeechModel(
            id: "openai_whisper-small",
            name: "small",
            displayName: "Small (Multilingual)",
            sizeDescription: "~460 MB",
            estimatedSizeMB: 460,
            isMultilingual: true
        ),
        SpeechModel(
            id: "openai_whisper-medium.en",
            name: "medium.en",
            displayName: "Medium (English)",
            sizeDescription: "~1.5 GB",
            estimatedSizeMB: 1500,
            isMultilingual: false
        ),
        SpeechModel(
            id: "openai_whisper-medium",
            name: "medium",
            displayName: "Medium (Multilingual)",
            sizeDescription: "~1.5 GB",
            estimatedSizeMB: 1500,
            isMultilingual: true
        ),
        SpeechModel(
            id: "openai_whisper-large-v3",
            name: "large-v3",
            displayName: "Large V3",
            sizeDescription: "~3 GB",
            estimatedSizeMB: 3000,
            isMultilingual: true
        ),
        SpeechModel(
            id: "openai_whisper-large-v3_turbo",
            name: "large-v3-turbo",
            displayName: "Large V3 Turbo",
            sizeDescription: "~1.6 GB",
            estimatedSizeMB: 1600,
            isMultilingual: true
        )
    ]

    static func model(forName name: String) -> SpeechModel? {
        (whisperModels + parakeetModels).first { $0.name == name }
    }

    static func model(forId id: String) -> SpeechModel? {
        (whisperModels + parakeetModels).first { $0.id == id }
    }

    static func repositoryModel(forId id: String) -> SpeechModel? {
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
        return SpeechModel(
            id: id,
            name: name,
            displayName: displayName,
            sizeDescription: "Size varies",
            estimatedSizeMB: 0,
            isMultilingual: !rawName.contains(".en")
        )
    }
}
