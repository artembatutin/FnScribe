//
//  WorkspaceScanner.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-02-02.
//

import Foundation
import AppKit
import Combine

/// Represents a file in the workspace
struct WorkspaceFile: Identifiable, Hashable, Codable {
    let id: UUID
    let path: String
    let name: String
    let nameWithoutExtension: String
    let fileExtension: String
    let relativePath: String
    let spokenVariants: [String]
    
    init(path: String, relativePath: String? = nil) {
        self.id = UUID()
        self.path = path
        self.name = (path as NSString).lastPathComponent
        self.fileExtension = (path as NSString).pathExtension
        self.nameWithoutExtension = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        self.relativePath = relativePath ?? self.name
        self.spokenVariants = Self.generateSpokenVariants(for: self.name, nameWithoutExtension: self.nameWithoutExtension)
    }
    
    /// Generates spoken variants for a filename
    /// "AppDelegate.swift" → ["app delegate", "AppDelegate", "app delegate swift"]
    private static func generateSpokenVariants(for filename: String, nameWithoutExtension: String) -> [String] {
        var variants: [String] = []
        
        // Original name
        variants.append(filename.lowercased())
        variants.append(nameWithoutExtension.lowercased())
        
        // Split camelCase/PascalCase into words
        let words = splitCamelCase(nameWithoutExtension)
        if words.count > 1 {
            variants.append(words.joined(separator: " ").lowercased())
        }
        
        // Split snake_case into words
        let snakeWords = nameWithoutExtension.split(separator: "_").map(String.init)
        if snakeWords.count > 1 {
            variants.append(snakeWords.joined(separator: " ").lowercased())
        }
        
        // Split kebab-case into words
        let kebabWords = nameWithoutExtension.split(separator: "-").map(String.init)
        if kebabWords.count > 1 {
            variants.append(kebabWords.joined(separator: " ").lowercased())
        }
        
        // Add variant with extension spoken
        let extWords = splitCamelCase(nameWithoutExtension)
        if !extWords.isEmpty {
            let fileExt = (filename as NSString).pathExtension
            if !fileExt.isEmpty {
                variants.append("\(extWords.joined(separator: " ")) \(fileExt)".lowercased())
            }
        }
        
        return Array(Set(variants))
    }
    
    /// Splits a camelCase or PascalCase string into words
    private static func splitCamelCase(_ text: String) -> [String] {
        var words: [String] = []
        var currentWord = ""
        
        for char in text {
            if char.isUppercase && !currentWord.isEmpty {
                words.append(currentWord)
                currentWord = String(char)
            } else {
                currentWord.append(char)
            }
        }
        
        if !currentWord.isEmpty {
            words.append(currentWord)
        }
        
        return words
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }
    
    static func == (lhs: WorkspaceFile, rhs: WorkspaceFile) -> Bool {
        lhs.path == rhs.path
    }
}

/// Scans IDE workspaces for files
@MainActor
final class WorkspaceScanner: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var workspaceFiles: [WorkspaceFile] = []
    @Published private(set) var isScanning: Bool = false
    @Published private(set) var lastScanDate: Date?
    @Published private(set) var workspaceRoot: URL?
    
    // MARK: - Private Properties
    
    private var fileWatcher: DispatchSourceFileSystemObject?
    private var watchedDirectoryFD: Int32 = -1
    
    /// File extensions to include in scans
    private let includedExtensions: Set<String> = [
        // Swift
        "swift",
        // JavaScript/TypeScript
        "js", "jsx", "ts", "tsx", "mjs", "cjs",
        // Web
        "html", "css", "scss", "sass", "less", "vue", "svelte",
        // Python
        "py", "pyw",
        // Ruby
        "rb", "erb",
        // Go
        "go",
        // Rust
        "rs",
        // C/C++
        "c", "cpp", "cc", "cxx", "h", "hpp", "hxx",
        // Java/Kotlin
        "java", "kt", "kts",
        // PHP
        "php",
        // Shell
        "sh", "bash", "zsh",
        // Config
        "json", "yaml", "yml", "toml", "xml", "plist",
        // Markdown
        "md", "mdx",
        // Other
        "sql", "graphql", "proto"
    ]
    
    /// Directories to exclude from scans
    private let excludedDirectories: Set<String> = [
        "node_modules",
        ".git",
        ".svn",
        ".hg",
        "build",
        "dist",
        "target",
        ".build",
        "DerivedData",
        "Pods",
        ".cocoapods",
        "vendor",
        "__pycache__",
        ".venv",
        "venv",
        ".idea",
        ".vscode",
        ".vs"
    ]
    
    // MARK: - Initialization
    
    init() {}
    
    deinit {
        // Clean up file watcher directly without calling MainActor method
        fileWatcher?.cancel()
        if watchedDirectoryFD >= 0 {
            close(watchedDirectoryFD)
        }
    }
    
    // MARK: - Public Methods
    
    /// Scans for workspace files from the frontmost IDE
    func scanFromFrontmostIDE() async {
        guard !isScanning else { return }
        
        isScanning = true
        defer { isScanning = false }
        
        // Try to get workspace root from accessibility
        if let root = await getWorkspaceRootFromAccessibility() {
            workspaceRoot = root
            workspaceFiles = scanDirectory(root)
            lastScanDate = Date()
        }
    }
    
    /// Scans a directory for workspace files
    func scanDirectory(_ path: URL) -> [WorkspaceFile] {
        var files: [WorkspaceFile] = []
        
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: path,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return files
        }
        
        let rootPath = path.path
        
        for case let fileURL as URL in enumerator {
            // Check if it's a directory we should skip
            let fileName = fileURL.lastPathComponent
            if excludedDirectories.contains(fileName) {
                enumerator.skipDescendants()
                continue
            }
            
            // Check if it's a file with an included extension
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  resourceValues.isRegularFile == true else {
                continue
            }
            
            let ext = fileURL.pathExtension.lowercased()
            guard includedExtensions.contains(ext) else {
                continue
            }
            
            // Calculate relative path
            let fullPath = fileURL.path
            var relativePath = fullPath
            if fullPath.hasPrefix(rootPath) {
                relativePath = String(fullPath.dropFirst(rootPath.count))
                if relativePath.hasPrefix("/") {
                    relativePath = String(relativePath.dropFirst())
                }
            }
            
            let file = WorkspaceFile(path: fullPath, relativePath: relativePath)
            files.append(file)
        }
        
        return files
    }
    
    /// Gets open files from the frontmost IDE via accessibility
    func getOpenFilesFromAccessibility() async -> [WorkspaceFile] {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontmostApp.bundleIdentifier,
              isIDEBundleId(bundleId) else {
            return []
        }
        
        let appElement = AXUIElementCreateApplication(frontmostApp.processIdentifier)
        
        // Get window titles which often contain file paths
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else {
            return []
        }
        
        var files: [WorkspaceFile] = []
        
        for window in windows {
            if let title = getStringAttribute(window, attribute: kAXTitleAttribute) {
                // Try to extract file path from window title
                if let file = extractFileFromTitle(title) {
                    files.append(file)
                }
            }
            
            // Also check document attribute
            if let document = getStringAttribute(window, attribute: kAXDocumentAttribute) {
                if let url = URL(string: document), url.isFileURL {
                    let file = WorkspaceFile(path: url.path)
                    files.append(file)
                }
            }
        }
        
        return files
    }
    
    /// Starts watching the workspace directory for changes
    func startWatching() {
        guard let root = workspaceRoot else { return }
        stopWatching()
        
        watchedDirectoryFD = open(root.path, O_EVTONLY)
        guard watchedDirectoryFD >= 0 else { return }
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: watchedDirectoryFD,
            eventMask: [.write, .delete, .rename],
            queue: .main
        )
        
        source.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                await self?.scanFromFrontmostIDE()
            }
        }
        
        source.setCancelHandler { [weak self] in
            if let fd = self?.watchedDirectoryFD, fd >= 0 {
                close(fd)
            }
            self?.watchedDirectoryFD = -1
        }
        
        source.resume()
        fileWatcher = source
    }
    
    /// Stops watching the workspace directory
    func stopWatching() {
        fileWatcher?.cancel()
        fileWatcher = nil
    }
    
    /// Refreshes the workspace files
    func refresh() async {
        await scanFromFrontmostIDE()
    }
    
    /// Clears all cached files
    func clear() {
        workspaceFiles = []
        workspaceRoot = nil
        lastScanDate = nil
        stopWatching()
    }
    
    // MARK: - Private Methods
    
    /// Gets the workspace root from the frontmost IDE via accessibility
    private func getWorkspaceRootFromAccessibility() async -> URL? {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontmostApp.bundleIdentifier,
              isIDEBundleId(bundleId) else {
            return nil
        }
        
        let appElement = AXUIElementCreateApplication(frontmostApp.processIdentifier)
        
        // Try to get from window title (VS Code shows workspace name)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement],
              let mainWindow = windows.first else {
            return nil
        }
        
        // Get window title
        if let title = getStringAttribute(mainWindow, attribute: kAXTitleAttribute) {
            // VS Code/Cursor/Windsurf format: "filename — workspace"
            // Xcode format: "filename — ProjectName"
            if let workspacePath = extractWorkspacePathFromTitle(title, bundleId: bundleId) {
                return URL(fileURLWithPath: workspacePath)
            }
        }
        
        // Try document attribute
        if let document = getStringAttribute(mainWindow, attribute: kAXDocumentAttribute),
           let url = URL(string: document), url.isFileURL {
            // Go up to find project root
            return findProjectRoot(from: url)
        }
        
        return nil
    }
    
    /// Extracts workspace path from window title
    private func extractWorkspacePathFromTitle(_ title: String, bundleId: String) -> String? {
        // VS Code variants show: "filename — FolderName"
        // Try to find the folder in common locations
        
        let components = title.components(separatedBy: " — ")
        guard components.count >= 2 else { return nil }
        
        let workspaceName = components.last?.trimmingCharacters(in: .whitespaces) ?? ""
        
        // Check common project locations
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let searchPaths = [
            homeDir.appendingPathComponent("Documents"),
            homeDir.appendingPathComponent("Projects"),
            homeDir.appendingPathComponent("Developer"),
            homeDir.appendingPathComponent("Code"),
            homeDir.appendingPathComponent("repos"),
            homeDir.appendingPathComponent("workspace"),
            homeDir
        ]
        
        for searchPath in searchPaths {
            let potentialPath = searchPath.appendingPathComponent(workspaceName)
            if FileManager.default.fileExists(atPath: potentialPath.path) {
                return potentialPath.path
            }
        }
        
        return nil
    }
    
    /// Finds the project root from a file URL
    private func findProjectRoot(from fileURL: URL) -> URL? {
        var currentDir = fileURL.deletingLastPathComponent()
        let fileManager = FileManager.default
        
        // Project root indicators
        let rootIndicators = [
            ".git",
            "Package.swift",
            "package.json",
            "Cargo.toml",
            "go.mod",
            "requirements.txt",
            "setup.py",
            "Gemfile",
            "pom.xml",
            "build.gradle",
            ".xcodeproj",
            ".xcworkspace"
        ]
        
        while currentDir.path != "/" {
            for indicator in rootIndicators {
                let indicatorPath = currentDir.appendingPathComponent(indicator)
                if fileManager.fileExists(atPath: indicatorPath.path) {
                    return currentDir
                }
            }
            currentDir = currentDir.deletingLastPathComponent()
        }
        
        return nil
    }
    
    /// Extracts a file from a window title
    private func extractFileFromTitle(_ title: String) -> WorkspaceFile? {
        // Try to find a file path in the title
        let components = title.components(separatedBy: " — ")
        guard let fileName = components.first else { return nil }
        
        // Check if it looks like a file name
        let trimmed = fileName.trimmingCharacters(in: .whitespaces)
        if trimmed.contains(".") && !trimmed.hasPrefix(".") {
            return WorkspaceFile(path: trimmed, relativePath: trimmed)
        }
        
        return nil
    }
    
    /// Checks if a bundle ID is an IDE
    private func isIDEBundleId(_ bundleId: String) -> Bool {
        let ideBundleIds = [
            "com.microsoft.VSCode",
            "com.microsoft.VSCodeInsiders",
            "com.visualstudio.code.oss",
            "com.todesktop.230313mzl4w4u92",
            "com.cursor.Cursor",
            "com.apple.dt.Xcode",
            "com.jetbrains.intellij",
            "com.jetbrains.intellij.ce",
            "com.jetbrains.WebStorm",
            "com.jetbrains.PhpStorm",
            "com.jetbrains.pycharm",
            "com.jetbrains.pycharm.ce"
        ]
        return ideBundleIds.contains(bundleId) || bundleId.hasPrefix("com.jetbrains.")
    }
    
    /// Gets a string attribute from an accessibility element
    private func getStringAttribute(_ element: AXUIElement, attribute: String) -> String? {
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &valueRef) == .success else {
            return nil
        }
        return valueRef as? String
    }
}
