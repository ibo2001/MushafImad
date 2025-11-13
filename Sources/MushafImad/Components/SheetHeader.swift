//
//  SheetHeader.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 09/11/2025.
//

import SwiftUI

public struct SheetHeader<Content: View>: View {
    public let alignment: VerticalAlignment
    @ViewBuilder public let content: () -> Content
    @Environment(\.dismiss) private var dismiss

    public init(
        alignment: VerticalAlignment,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.alignment = alignment
        self.content = content
    }

    public var body: some View {
        HStack(alignment: alignment) {
            if alignment == .center {
                Spacer(minLength: 44)
            }
            content()
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
            }
            .frame(width: 44, height: 44)
            .background(.secondary.opacity(0.16), in: Circle())
            .foregroundStyle(.secondary)
        }
        .frame(height:60)
    }
}

#Preview {
    SheetHeader(alignment:.center) {
        Text("Ameen")
            .frame(maxWidth:.infinity)
    }
    .padding()
}
