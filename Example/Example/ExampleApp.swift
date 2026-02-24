//
//  ExampleApp.swift
//  Example
//
//  Created by Ibrahim Qraiqe on 12/11/2025.
//

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
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
        #endif

        #if os(macOS)
        MenuBarExtra {
            MenuBarPlayerView()
        } label: {
            Image(systemName: "book.fill")
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}

#if os(iOS)
extension ExampleApp {
    var overlayedContent: some View {
        ContentView()
            .environmentObject(ReciterService.shared)
            .environmentObject(toastManager)
            .overlay(ToastOverlayView())
    }
}
#endif
