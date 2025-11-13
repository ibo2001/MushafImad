//
//  Bundle+Mushaf.swift
//  MushafImadSPM
//
//  Created by Assistant on 10/11/2025.
//

import Foundation

extension Bundle {
    static var mushafResources: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return .main
        #endif
    }
}


