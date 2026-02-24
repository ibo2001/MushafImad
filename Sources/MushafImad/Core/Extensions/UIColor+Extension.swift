//
//  UIColor+Extension.swift
//  MushafImadSPM
//
//  Created by Ibrahim Qraiqe on 10/11/2025.
//

#if canImport(UIKit)
import UIKit
import SwiftUI
@MainActor
public extension UIColor {
    static var brand900: UIColor { UIColor(Color.brand900) }
    static var brand500: UIColor { UIColor(Color.brand500) }
    static var brand100: UIColor { UIColor(Color.brand100) }
    
    static var accent900: UIColor { UIColor(Color.accent900) }
    static var accent700: UIColor { UIColor(Color.accent700) }
    static var accent500: UIColor { UIColor(Color.accent500) }
    static var accent100: UIColor { UIColor(Color.accent100) }
    
    static var naturalWhite: UIColor { UIColor(Color.naturalWhite) }
    static var naturalBlack: UIColor { UIColor(Color.naturalBlack) }
    static var naturalGray: UIColor { UIColor(Color.naturalGray) }
}
#endif

