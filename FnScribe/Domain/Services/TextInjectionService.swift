//
//  TextInjectionService.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import Foundation
import Combine

/// Service that orchestrates text injection with settings and permissions
@MainActor
class TextInjectionService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var isInjecting: Bool = false
    @Published private(set) var lastResult: InjectionResult?
    @Published private(set) var lastError: TextInjectionError?
    
    // MARK: - Dependencies
    
    private let textInjector: TextInjector
    private let settingsStore: SettingsStore
    private let permissionsManager: PermissionsManager
    private let adapterRegistry: AdapterRegistry
    private let inputFieldDetector: InputFieldDetector?
    private var waitingInjections: [CheckedContinuation<Void, Never>] = []
    
    // MARK: - Initialization
    
    init(textInjector: TextInjector, settingsStore: SettingsStore, permissionsManager: PermissionsManager, adapterRegistry: AdapterRegistry? = nil, inputFieldDetector: InputFieldDetector? = nil) {
        self.textInjector = textInjector
        self.settingsStore = settingsStore
        self.permissionsManager = permissionsManager
        self.adapterRegistry = adapterRegistry ?? AdapterRegistry()
        self.inputFieldDetector = inputFieldDetector
        
        // Apply settings to injector
        applySettings()
    }
    
    // MARK: - Public Methods
    
    /// Injects text using the configured settings
    /// - Parameter text: The text to inject
    /// - Returns: The result of the injection
    @discardableResult
    func inject(text: String) async throws -> InjectionResult {
        await beginInjection()
        defer { endInjection() }
        try Task.checkCancellation()

        // Check permissions first
        try verifyPermissions()
        
        // Apply current settings
        applySettings()
        
        do {
            // Get the appropriate adapter for the current app
            let adapter = adapterRegistry.getAdapter()
            
            // Check for per-app config override
            if let bundleId = frontmostAppBundleId,
               let appConfig = adapterRegistry.getConfig(for: bundleId),
               appConfig.enabled {
                // Use per-app configuration
                let result = try await textInjector.inject(text: text, mode: appConfig.injectionMode)
                lastResult = result
                return result
            }
            
            // Use adapter for injection
            let result = try await adapter.inject(text: text, using: textInjector)
            lastResult = result
            return result
        } catch let error as TextInjectionError {
            lastError = error
            throw error
        } catch {
            let injectionError = TextInjectionError.keystrokeSimulationFailed
            lastError = injectionError
            throw injectionError
        }
    }
    
    /// Injects text with a specific mode, overriding settings
    /// - Parameters:
    ///   - text: The text to inject
    ///   - mode: The injection mode to use
    /// - Returns: The result of the injection
    @discardableResult
    func inject(text: String, mode: InjectionMode) async throws -> InjectionResult {
        await beginInjection()
        defer { endInjection() }
        try Task.checkCancellation()

        // Check permissions first
        try verifyPermissions()
        
        // Apply current settings (except mode)
        applySettings()
        
        do {
            let result = try await textInjector.inject(text: text, mode: mode)
            lastResult = result
            return result
        } catch let error as TextInjectionError {
            lastError = error
            throw error
        } catch {
            let injectionError = TextInjectionError.keystrokeSimulationFailed
            lastError = injectionError
            throw injectionError
        }
    }
    
    /// Checks if injection is possible with current permissions
    var canInject: Bool {
        permissionsManager.accessibilityGranted
    }
    
    /// Gets the name of the current frontmost application
    var frontmostAppName: String? {
        textInjector.getFrontmostAppName()
    }
    
    /// Gets the bundle identifier of the current frontmost application
    var frontmostAppBundleId: String? {
        textInjector.getFrontmostAppBundleId()
    }
    
    /// Gets the current adapter name for the frontmost application
    var currentAdapterName: String {
        adapterRegistry.getAdapter().displayName
    }
    
    /// Gets information about the current frontmost application and its adapter
    var frontmostAppInfo: (bundleId: String, name: String, adapter: String)? {
        adapterRegistry.getFrontmostAppInfo()
    }
    
    // MARK: - Adapter Configuration
    
    /// Gets the per-app configuration for a bundle identifier
    func getAppConfig(for bundleId: String) -> AppInjectionConfig? {
        adapterRegistry.getConfig(for: bundleId)
    }
    
    /// Sets the per-app configuration
    func setAppConfig(_ config: AppInjectionConfig) {
        adapterRegistry.setConfig(config)
    }
    
    /// Removes the per-app configuration
    func removeAppConfig(for bundleId: String) {
        adapterRegistry.removeConfig(for: bundleId)
    }
    
    /// Gets or creates a default config for the current frontmost app
    func getOrCreateCurrentAppConfig() -> AppInjectionConfig? {
        guard let bundleId = frontmostAppBundleId,
              let name = frontmostAppName else {
            return nil
        }
        return adapterRegistry.getOrCreateConfig(for: bundleId, displayName: name)
    }
    
    // MARK: - Permission Handling

    private func beginInjection() async {
        if isInjecting {
            await withCheckedContinuation { continuation in
                waitingInjections.append(continuation)
            }
        }
        isInjecting = true
        lastError = nil
    }

    private func endInjection() {
        if waitingInjections.isEmpty {
            isInjecting = false
        } else {
            waitingInjections.removeFirst().resume()
        }
    }
    
    /// Verifies that required permissions are granted
    private func verifyPermissions() throws {
        // Refresh permissions state
        permissionsManager.refreshAllPermissions()
        
        guard permissionsManager.accessibilityGranted else {
            throw TextInjectionError.accessibilityNotGranted
        }
        
        // Input monitoring is needed for keystroke simulation
        if settingsStore.injectionMode == .keystrokeSimulation ||
           (settingsStore.injectionMode == .hybrid && !permissionsManager.inputMonitoringGranted) {
            // For hybrid mode, we can fall back to clipboard if input monitoring isn't available
            if settingsStore.injectionMode == .keystrokeSimulation && !permissionsManager.inputMonitoringGranted {
                throw TextInjectionError.inputMonitoringNotGranted
            }
        }
    }
    
    /// Opens system settings for accessibility permissions
    func openAccessibilitySettings() {
        permissionsManager.openAccessibilitySettings()
    }
    
    /// Opens system settings for input monitoring permissions
    func openInputMonitoringSettings() {
        permissionsManager.openInputMonitoringSettings()
    }
    
    // MARK: - Settings
    
    /// Applies current settings to the text injector
    private func applySettings() {
        textInjector.preserveClipboard = settingsStore.preserveClipboard
        textInjector.keystrokeDelay = settingsStore.typingDelay
    }
}
