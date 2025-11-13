//
//  VerseFasel.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 04/11/2025.
//

import SwiftUI

public struct VerseFasel: View {
    public let number: Int
    public var scale: CGFloat = 1.0
    private let balance:CGFloat = 3.69
    
    public init(number: Int, scale: CGFloat = 1.0) {
        self.number = number
        self.scale = scale
    }
    
    public var body: some View {
       let baseWidth: CGFloat = 21 * balance
       let baseHeight: CGFloat = 27 * balance
       let baseFontSize: CGFloat = 14 * balance
       let basePadding: CGFloat = 2 * balance

        ZStack {
            MushafAssets.image(named: "fasel")
                .resizable()
                .scaledToFit()
                .offset(y:-4 * scale)
            
            Text("\(number)")
                .font(.alQuranAlKareem(size: baseFontSize  * scale))
                .padding(.horizontal,basePadding * scale)
                .minimumScaleFactor(0.3)
        }
        .frame(width: baseWidth * scale, height: baseHeight * scale)
    }
}

#Preview {
    VerseFasel(number: 286)
}
