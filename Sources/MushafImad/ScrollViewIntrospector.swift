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
    let onFind: (UIScrollView) -> Void
    class Coordinator { var didFind = false }
    
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
            if let scrollView = self.findAncestorScrollView(of: uiView) {
                context.coordinator.didFind = true
                onFind(scrollView)
            }
        }
    }
    
    private func findAncestorScrollView(of view: UIView) -> UIScrollView? {
        var current = view
        while let superview = current.superview {
            if let scrollView = superview as? UIScrollView {
                return scrollView
            }
            current = superview
        }
        return nil
    }
}
#endif
