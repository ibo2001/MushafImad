//
//  PageFooter.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 31/10/2025.
//

import SwiftUI
public struct PageFooterView: View {
    public let pageNumber: Int
    public let isRight: Bool
    
    public var scale: CGFloat = 1.0
    public var hPadding: CGFloat = 30
    
    public init(
        pageNumber: Int,
        isRight: Bool,
        scale: CGFloat = 1.0,
        hPadding: CGFloat = 30
    ) {
        self.pageNumber = pageNumber
        self.isRight = isRight
        self.scale = scale
        self.hPadding = hPadding
    }

    private var deviceScaleFactor: CGFloat {
        #if canImport(UIKit)
        return UIScreen.main.bounds.width > UIScreen.main.bounds.height ? 2.5 : 1.0
        #else
        return 1.0
        #endif
    }

    private var baseWidth: CGFloat { 42 * deviceScaleFactor }
    
    private var baseHeight: CGFloat { 26 * deviceScaleFactor }
    
    private var baseFont: CGFloat { 32 * deviceScaleFactor }
    
    private var basePadding: CGFloat { 16 * deviceScaleFactor }
    private var footerContent: some View {
        MushafAssets.image(named: "pagenumb")
            .resizable()
            .frame(width: baseWidth, height: baseHeight)
            .overlay {
                Text(pageNumber.toArabic)
                    .font(.uthmanicTN1Bold(size: baseFont))
                    .frame(maxWidth: .infinity)
                    .minimumScaleFactor(0.2)
                    .offset(y:-2)
            }
    }
    
    public var body: some View {
        HStack {
            if isRight {
                footerContent
                Spacer()
            } else {
                Spacer()
                footerContent
            }
        }
        .padding(.horizontal, hPadding)
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.3), value: isRight)
    }
}

#Preview {
    PageFooterView(pageNumber: 604, isRight: true)
}
