//
//  RoundedCorner+Shape.swift
//  Mushaf
//
//  Created by Ibrahim Qraiqe on 28/10/2025.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit

// Cross-platform corner type
public struct RectCorner: OptionSet, Sendable {
    public let rawValue: UInt
    
    public static let topLeft = RectCorner(rawValue: 1 << 0)
    public static let topRight = RectCorner(rawValue: 1 << 1)
    public static let bottomLeft = RectCorner(rawValue: 1 << 2)
    public static let bottomRight = RectCorner(rawValue: 1 << 3)
    public static let allCorners: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
    
    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }
}

typealias UIRectCorner = RectCorner
#endif

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        #if canImport(UIKit)
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
        #elseif canImport(AppKit)
        // On macOS, use a simple rounded rect for all corners
        let path = NSBezierPath()
        path.appendRoundedRect(rect, xRadius: radius, yRadius: radius)
        
        let cgPath = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)
        for i in 0..<path.elementCount {
            let element = path.element(at: i, associatedPoints: &points)
            switch element {
            case .moveTo:
                cgPath.move(to: points[0])
            case .lineTo:
                cgPath.addLine(to: points[0])
            case .curveTo:
                cgPath.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .cubicCurveTo:
                cgPath.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo:
                cgPath.addQuadCurve(to: points[1], control: points[0])
            case .closePath:
                cgPath.closeSubpath()
            @unknown default:
                break
            }
        }
        return Path(cgPath)
        #else
        return Path(rect)
        #endif
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}
