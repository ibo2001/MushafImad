//
//  ContentView.swift
//  Example
//
//  Created by Ibrahim Qraiqe on 12/11/2025.
//

import SwiftUI
import MushafImad

#if os(iOS)
// iOS-specific ContentView
struct ContentView: View {
    var body: some View {
        ContentView_iOS()
    }
}
#elseif os(macOS)
// macOS-specific ContentView
struct ContentView: View {
    var body: some View {
        ContentView_macOS()
    }
}
#endif

#Preview {
    ContentView()
        .environmentObject(ReciterService.shared)
        .environmentObject(ToastManager())
}
