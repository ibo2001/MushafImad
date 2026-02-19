//
//  ScrollViewIntrospector.swift
//  MushafImad
//
//  Created by Assistant on 15/02/2026.
//

import SwiftUI
import UIKit

/// A helper view that finds the nearest ancestor UIScrollView and passes it to a completion handler.
struct ScrollViewIntrospector: UIViewRepresentable {
    let onFind: (UIScrollView) -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.isHidden = true
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Dispatch async to ensure view hierarchy is engaged
        DispatchQueue.main.async {
            if let scrollView = self.findAncestorScrollView(of: uiView) {
                print("[ScrollViewIntrospector] Found UIScrollView: \(scrollView)")
                onFind(scrollView)
            } else {
                print("[ScrollViewIntrospector] Could not find ancestor UIScrollView")
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
