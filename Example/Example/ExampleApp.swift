//
//  ExampleApp.swift
//  Example
//
//  Created by Ibrahim Qraiqe on 12/11/2025.
//

#if !SWIFT_PACKAGE
import SwiftUI
import MushafImad

@main
struct ExampleApp: App {
    @StateObject private var toastManager = ToastManager()
    
    init() {
        FontRegistrar.registerFontsIfNeeded()
        do {
            try RealmService.shared.initialize()
        } catch {
            AppLogger.shared.error("Failed to initialize Realm: \(error.localizedDescription)", category: .realm)
        }
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ReciterService.shared)
                .environmentObject(toastManager)
                .overlay(ToastOverlayView())
        }
    }
}
#endif
