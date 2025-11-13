//
//  HizbProgressPie.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 31/10/2025.
//

import SwiftUI

public struct HizbProgressPie: Shape {
    public let progress: CGFloat

    public init(progress: CGFloat) {
        self.progress = progress
    }

    public func path(in rect: CGRect) -> Path {
        let clampedProgress = max(0, min(progress, 1))
        guard clampedProgress > 0 else { return Path() }

        var path = Path()
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let startAngle = Angle.degrees(0)
        let endAngle = Angle.degrees(Double(clampedProgress) * 360)

        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()

        return path
    }
}

#Preview {
    HizbProgressPie(progress: 0.75)
}
