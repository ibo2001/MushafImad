//
//  ScrollViewIntrospector.swift
//  MushafImad
//
//  Created by Assistant on 15/02/2026.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
/// A helper view that finds the nearest ancestor UIScrollView and passes it to a completion handler.
struct ScrollViewIntrospector: UIViewRepresentable {
    enum AxisHint {
        case horizontal
        case vertical
    }

    let onFind: (UIScrollView) -> Void
    let axisHint: AxisHint?
    let prefersPaging: Bool
    class Coordinator {
        var didFind = false
        var isRetrying = false
    }

    init(
        axisHint: AxisHint? = nil,
        prefersPaging: Bool = false,
        onFind: @escaping (UIScrollView) -> Void
    ) {
        self.axisHint = axisHint
        self.prefersPaging = prefersPaging
        self.onFind = onFind
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.isHidden = true
        return view
    }
    
    func makeCoordinator() -> Coordinator { Coordinator() }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            guard !context.coordinator.didFind else { return }
            self.resolveScrollView(from: uiView, coordinator: context.coordinator, attemptsRemaining: 20)
        }
    }

    private func resolveScrollView(from view: UIView, coordinator: Coordinator, attemptsRemaining: Int) {
        guard !coordinator.didFind else { return }

        if let scrollView = findAncestorScrollView(of: view) ?? findBestScrollView(from: view) {
            coordinator.didFind = true
            coordinator.isRetrying = false
            onFind(scrollView)
            return
        }

        guard attemptsRemaining > 0, !coordinator.isRetrying else { return }
        coordinator.isRetrying = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            coordinator.isRetrying = false
            self.resolveScrollView(from: view, coordinator: coordinator, attemptsRemaining: attemptsRemaining - 1)
        }
    }
    
    private func findAncestorScrollView(of view: UIView) -> UIScrollView? {
        var current = view
        while let superview = current.superview {
            if let scrollView = superview as? UIScrollView, matchesHint(scrollView) {
                return scrollView
            }
            current = superview
        }
        return nil
    }

    private func findBestScrollView(from view: UIView) -> UIScrollView? {
        guard let rootView = view.window else { return nil }
        let candidates = collectScrollViews(in: rootView).filter { matchesHint($0) }
        return candidates.max(by: { score(for: $0) < score(for: $1) })
    }

    private func collectScrollViews(in root: UIView) -> [UIScrollView] {
        var result: [UIScrollView] = []

        if let scrollView = root as? UIScrollView {
            result.append(scrollView)
        }

        for child in root.subviews {
            result.append(contentsOf: collectScrollViews(in: child))
        }

        return result
    }

    private func matchesHint(_ scrollView: UIScrollView) -> Bool {
        if prefersPaging, !scrollView.isPagingEnabled {
            return false
        }

        guard let axisHint else { return true }
        switch axisHint {
        case .horizontal:
            return scrollView.contentSize.width > scrollView.bounds.width + 1
        case .vertical:
            return scrollView.contentSize.height > scrollView.bounds.height + 1
        }
    }

    private func score(for scrollView: UIScrollView) -> CGFloat {
        var value: CGFloat = 0
        if scrollView.isPagingEnabled { value += 10_000 }
        if scrollView.isScrollEnabled { value += 500 }
        value += scrollView.bounds.width * scrollView.bounds.height
        return value
    }
}
#endif
