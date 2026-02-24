//
//  ToastManager.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 10/11/2025.
//

import SwiftUI
import Combine

/// Observable coordinator for displaying temporary toast notifications.
@MainActor
public final class ToastManager: ObservableObject {
    /// Represents an optional button displayed alongside the toast message.
    public struct ToastAction {
        public let title: LocalizedStringKey
        public let icon: String
        public let handler: () -> Void
        
        public init(title: LocalizedStringKey, icon: String, handler: @escaping () -> Void) {
            self.title = title
            self.icon = icon
            self.handler = handler
        }
    }
    
    /// Configuration object describing the visuals and behavior of a toast.
    public struct ToastItem: Identifiable {
        public let id = UUID()
        public let message: LocalizedStringKey
        public let systemImage: String
        public let backgroundColor: Color
        public let accentColor: Color
        public let textColor: Color
        public let actionTint: Color
        public let duration: TimeInterval
        public let action: ToastAction?
        
        public init(
            message: LocalizedStringKey,
            systemImage: String,
            backgroundColor: Color,
            accentColor: Color,
            textColor: Color,
            actionTint: Color? = nil,
            duration: TimeInterval = 3,
            action: ToastAction? = nil
        ) {
            self.message = message
            self.systemImage = systemImage
            self.backgroundColor = backgroundColor
            self.accentColor = accentColor
            self.textColor = textColor
            self.actionTint = actionTint ?? accentColor
            self.duration = duration
            self.action = action
        }
    }
    
    @Published public private(set) var toast: ToastItem?
    
    private var dismissTask: Task<Void, Never>?
    
    public init() {}
    
    /// Present a toast, replacing any currently visible toast with animation.
    public func show(_ item: ToastItem) {
        dismissTask?.cancel()
        dismissTask = nil
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            toast = item
        }
        
        guard item.duration > 0 else { return }
        
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(item.duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }
    
    /// Dismiss the current toast and cancel any pending auto dismissal.
    public func hide() {
        dismissTask?.cancel()
        dismissTask = nil
        
        withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
            toast = nil
        }
    }
}

public extension ToastManager.ToastItem {
    static func success(
        message: LocalizedStringKey,
        systemImage: String = "checkmark.circle.fill",
        backgroundColor: Color = Color(hex: "#E8F6E2"),
        accentColor: Color = Color(hex: "#3A7150"),
        textColor: Color = Color(hex: "#2C5D3E"),
        actionTint: Color? = nil,
        duration: TimeInterval = 3,
        action: ToastManager.ToastAction? = nil
    ) -> Self {
        ToastManager.ToastItem(
            message: message,
            systemImage: systemImage,
            backgroundColor: backgroundColor,
            accentColor: accentColor,
            textColor: textColor,
            actionTint: actionTint ?? accentColor,
            duration: duration,
            action: action
        )
    }
    
    static func warning(
        message: LocalizedStringKey,
        systemImage: String = "exclamationmark.triangle.fill",
        backgroundColor: Color = Color(hex: "#FFF4E5"),
        accentColor: Color = Color(hex: "#C06014"),
        textColor: Color = Color(hex: "#7E3D0C"),
        actionTint: Color? = nil,
        duration: TimeInterval = 3,
        action: ToastManager.ToastAction? = nil
    ) -> Self {
        ToastManager.ToastItem(
            message: message,
            systemImage: systemImage,
            backgroundColor: backgroundColor,
            accentColor: accentColor,
            textColor: textColor,
            actionTint: actionTint ?? accentColor,
            duration: duration,
            action: action
        )
    }
}


