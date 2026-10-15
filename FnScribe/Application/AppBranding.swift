//
//  AppBranding.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import Foundation

enum AppBranding {
    nonisolated static let displayName = "FnScribe"
    nonisolated static let bundleIdentifier = "quartzarts.FnScribe"
    nonisolated static let onboardingWindowTitle = "Welcome to FnScribe"
    nonisolated static let dashboardWindowTitle = "FnScribe Dashboard"
    nonisolated static let settingsWindowTitle = "FnScribe Settings"
    nonisolated static let historyExportFileName = "FnScribe_History"
    nonisolated static let dictionaryExportFileName = "fnscribe-dictionary.json"
    nonisolated static let snippetsExportFileName = "fnscribe-snippets.json"
}

enum AppSupportPaths {
    private nonisolated static let currentDirectoryName = AppBranding.displayName

    nonisolated static func appSupportDirectory(fileManager: FileManager = .default) throws -> URL {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let currentDirectory = applicationSupport.appendingPathComponent(currentDirectoryName, isDirectory: true)

        if !fileManager.fileExists(atPath: currentDirectory.path) {
            try fileManager.createDirectory(at: currentDirectory, withIntermediateDirectories: true)
        }

        return currentDirectory
    }

    nonisolated static func fileURL(_ fileName: String, fileManager: FileManager = .default) throws -> URL {
        try appSupportDirectory(fileManager: fileManager).appendingPathComponent(fileName)
    }

    nonisolated static func modelsDirectory(fileManager: FileManager = .default) throws -> URL {
        let directory = try appSupportDirectory(fileManager: fileManager)
            .appendingPathComponent("Models", isDirectory: true)

        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        return directory
    }

    nonisolated static func completeModelPath(
        id: String,
        name: String,
        in storageDirectory: URL,
        fileManager: FileManager = .default
    ) -> URL? {
        let hubPath = storageDirectory
            .appendingPathComponent("models/argmaxinc/whisperkit-coreml", isDirectory: true)
            .appendingPathComponent(id, isDirectory: true)
        let legacyPaths = [id, name].map {
            storageDirectory.appendingPathComponent($0, isDirectory: true)
        }
        return ([hubPath] + legacyPaths).first {
            isCompleteModel(at: $0, fileManager: fileManager)
        }
    }

    nonisolated static func isCompleteModel(
        at folder: URL,
        fileManager: FileManager = .default
    ) -> Bool {
        ["MelSpectrogram", "AudioEncoder", "TextDecoder"].allSatisfy { name in
            let compiledPath = folder.appendingPathComponent("\(name).mlmodelc").path
            let packageModelPath = folder
                .appendingPathComponent("\(name).mlpackage/Data/com.apple.CoreML/model.mlmodel")
                .path
            var isDirectory: ObjCBool = false
            return (fileManager.fileExists(atPath: compiledPath, isDirectory: &isDirectory) &&
                    isDirectory.boolValue) ||
                fileManager.fileExists(atPath: packageModelPath)
        }
    }
}
