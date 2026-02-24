//
//  VerseFasel.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 04/11/2025.
//

import SwiftUI

struct VerseFasel: View {
    let number: Int
    var scale: CGFloat = 1.0
    private let balance:CGFloat = 3.69
    
    var body: some View {
        let baseWidth: CGFloat = 21 * balance
        let baseHeight: CGFloat = 27 * balance
        let baseFontSize: CGFloat = 14 * balance
        let basePadding: CGFloat = 2 * balance
        let fs = baseFontSize  * scale
        MushafAssets.image(named: "fasel")
            .resizable()
            .frame(width: baseWidth * scale, height: baseHeight * scale,alignment: .center)
            .overlay {
                Text(number.toArabic)
                    .font(.uthmanicTN1Bold(size: fs))
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, basePadding * scale)
                    .offset(x: -1 * scale , y: 1 * scale)
            }
            .offset(x: -2, y: -4)
    }
}

#Preview {
    VerseFasel(number: 286)
}
