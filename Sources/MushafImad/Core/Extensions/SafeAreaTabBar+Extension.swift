//
//  SafeAreaTabBar+Extension.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 06/11/2025.
//

import SwiftUI
#if canImport(UIKit)
import UIKit

extension UITabBarController {
    var height: CGFloat {
        return self.tabBar.frame.size.height
    }
    
    var width: CGFloat {
        return self.tabBar.frame.size.width
    }
}

extension UIApplication {
    /// Access this only on the main actor.
    @MainActor
    var keyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

private extension UIEdgeInsets {
    var swiftUiInsets: EdgeInsets {
        EdgeInsets(top: top, leading: left, bottom: bottom, trailing: right)
    }
}
#endif

/// EnvironmentKey for Safe Area Insets.
/// DO NOT access UIKit from here; only provide a default of `.zero`.
private struct SafeAreaInsetsKey: EnvironmentKey {
    static var defaultValue: EdgeInsets {
        EdgeInsets()
    }
}

extension EnvironmentValues {
    var safeAreaInsets: EdgeInsets {
        get { self[SafeAreaInsetsKey.self] }
        set { self[SafeAreaInsetsKey.self] = newValue }
    }
}

/// ViewModifier that injects the real safe area insets into the environment.
/// Usage: Add `.modifier(SafeAreaInsetsInjector())` at the root of your main view hierarchy.
struct SafeAreaInsetsInjector: ViewModifier {
    @State private var insets: EdgeInsets = .init()
    func body(content: Content) -> some View {
        content
            .onAppear {
                #if canImport(UIKit)
                if let window = UIApplication.shared.keyWindow {
                    self.insets = window.safeAreaInsets.swiftUiInsets
                }
                #endif
            }
            .environment(\.safeAreaInsets, insets)
    }
}
