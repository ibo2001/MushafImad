//
//  FloatingToastView.swift
//  MushafImad
//
//  Created by Assistant on 10/11/2025.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Visual representation of a toast notification surfaced by `ToastManager`.
public struct FloatingToastView: View {
    public let item: ToastManager.ToastItem
    public let onDismiss: () -> Void
    public let onAction: (ToastManager.ToastAction) -> Void
    
    @State private var hasTriggeredFeedback = false
    
    public init(
        item: ToastManager.ToastItem,
        onDismiss: @escaping () -> Void,
        onAction: @escaping (ToastManager.ToastAction) -> Void
    ) {
        self.item = item
        self.onDismiss = onDismiss
        self.onAction = onAction
    }
    
    public var body: some View {
        HStack(spacing: 16) {
            Image(systemName: item.systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(item.accentColor)
                .padding(10)
                .background(item.accentColor.opacity(0.14), in: Circle())
            
            Text(item.message)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(item.textColor)
            
            Spacer(minLength: 12)
            
            if let action = item.action {
                Button {
                    onAction(action)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: action.icon)
                            .font(.system(size: 14, weight: .semibold))
                        Text(action.title)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(item.actionTint)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(item.actionTint.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(item.backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(item.accentColor.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: item.accentColor.opacity(0.20), radius: 18, x: 0, y: 12)
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture {
            onDismiss()
        }
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear {
            guard !hasTriggeredFeedback else { return }
            hasTriggeredFeedback = true
#if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
        }
    }
}

/// Convenience overlay that hosts the floating toast above current UI.
public struct ToastOverlayView: View {
    @EnvironmentObject private var toastManager: ToastManager
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    
    public init() {}
    
    public var body: some View {
        VStack {
            Spacer()
            if let toast = toastManager.toast {
                FloatingToastView(
                    item: toast,
                    onDismiss: toastManager.hide,
                    onAction: { action in
                        toastManager.hide()
                        action.handler()
                    }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, safeAreaInsets.bottom + 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(
            .spring(response: 0.45, dampingFraction: 0.85),
            value: toastManager.toast?.id
        )
        .allowsHitTesting(toastManager.toast != nil)
    }
}

#Preview("Success Toast") {
    VStack {
        Spacer()
        FloatingToastView(
            item: ToastManager.ToastItem(
                message: "The verse has been added to your favorites.",
                systemImage: "bookmark.fill",
                backgroundColor: Color(hex: "#E8F6E2"),
                accentColor: Color(hex: "#3A7150"),
                textColor: Color(hex: "#2C5D3E"),
                actionTint: Color(hex: "#3A7150"),
                duration: 0,
                action: .init(
                    title: "Add to favorites",
                    icon: "chevron.backward",
                    handler: {}
                )
            ),
            onDismiss: {},
            onAction: { _ in }
        )
        .padding()
        Spacer()
    }
    .environment(\.layoutDirection, .rightToLeft)
}


