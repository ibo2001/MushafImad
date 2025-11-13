//
//  HizbProgressView.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 31/10/2025.
//

import SwiftUI

/// Compact badge displaying hizb number and fractional completion.
public struct HizbProgressView: View {
    public let hizbInfo: HizbDisplayInfo
    public var fillColor: Color = .white

    private var progress: CGFloat {
        CGFloat(max(0, min(hizbInfo.fraction, 1)))
    }

    private var remaining: CGFloat {
        CGFloat(max(0, min(1 - progress, 1)))
    }

    public init(hizbInfo: HizbDisplayInfo, fillColor: Color = .white) {
        self.hizbInfo = hizbInfo
        self.fillColor = fillColor
    }

    public var body: some View {
        HStack(spacing: 4) {
            if remaining > 0 {
                ZStack {
                    Circle()
                        .fill(.brand900)

                    HizbProgressPie(progress: remaining)
                        .fill(fillColor)
                        .rotationEffect(.degrees(-90))

                    Circle()
                        .stroke(.brand900, lineWidth: 1)
                }
                .frame(width: 16, height: 16)
            }
            

            Text("Hizb \(hizbInfo.number)")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("The Hizb \(hizbInfo.number)")
        .accessibilityValue("Progress \(hizbInfo.formattedFraction)")
    }
}
