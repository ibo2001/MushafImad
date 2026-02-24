//
//  PageHeader.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 31/10/2025.
//

import SwiftUI

public struct PageHeaderView: View {
    public let page: Page
    public var horizentalPadding: CGFloat = 16
    
    public init(page: Page, horizentalPadding: CGFloat = 16) {
        self.page = page
        self.horizentalPadding = horizentalPadding
    }
    
    public var body: some View {
        HStack {
            // Use the new PageHeader functionality for better formatted display
            let headerDisplay = getPageHeaderDisplay(page: page)
            
            HStack(spacing: 25) {
                if let juz = headerDisplay.juz {
                    Text(juz)
                        .font(.system(size: 14, weight: .medium))
                }
                
                if let hizb = headerDisplay.hizb {
                    HizbProgressView(hizbInfo: hizb)
                }
            }
            
            Spacer()
            
            ForEach(headerDisplay.titles, id:\.self) { title in
                Text("سورة \(title)")
                    .font(.chapterNames(size: 24))
            }
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.brand900)
        .padding(.horizontal, horizentalPadding)
        .environment(\.layoutDirection, .rightToLeft)
    }
    
    public func getPageHeaderDisplay(page: Page) -> (juz: String?, hizb: HizbDisplayInfo?, titles: [String]) {
        // Get the header for the current Mushaf type (defaulting to 1441)
        guard let header = page.header1441 else {
            return (nil, nil, [])
        }
        let titles:[String] = header.chapters.map { $0.arabicTitle }
        // Format Juz display
        let juzDisplay: String? = header.part.map { "الجزء \($0.number)" }
        
        // Format Hizb display
        let hizbDisplay: HizbDisplayInfo? = header.quarter.map { quarter in
            HizbDisplayInfo(number: quarter.hizbNumber, hizbFraction: quarter.hizbFraction)
        }
        
        return (juzDisplay, hizbDisplay, titles)
    }
}
