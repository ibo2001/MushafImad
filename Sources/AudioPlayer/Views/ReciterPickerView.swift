import SwiftUI

public struct ReciterPickerView: View {
    public let reciters: [ReciterService.ReciterInfo]
    public let selectedReciter: ReciterService.ReciterInfo?
    private let onSelect: (ReciterService.ReciterInfo) -> Void
    @AppStorage("selectedReciterId") private var savedReciterId: Int = 0
    
    public init(
        reciters: [ReciterService.ReciterInfo],
        selectedReciter: ReciterService.ReciterInfo?,
        onSelect: @escaping (ReciterService.ReciterInfo) -> Void
    ) {
        self.reciters = reciters
        self.selectedReciter = selectedReciter
        self.onSelect = onSelect
        _savedReciterId = AppStorage(wrappedValue: selectedReciter?.id ?? 0, "selectedReciterId")
    }

    public var body: some View {
        VStack(alignment: .center) {
            SheetHeader(alignment: .center, content: {
                Text("Reader's choice")
                    .font(.system(size: 17,weight: .semibold))
            })
            Picker("Reader's choice", selection: $savedReciterId) {
                ForEach(reciters) {
                    Text($0.displayName)
                }
            }
            .pickerStyle(.wheel)
        }
        .padding(.horizontal, 16)
        .onChange(of: savedReciterId) {
            if let reciter = reciters.first(where: { $0.id == savedReciterId }) {
                onSelect(reciter)
            }
        }
        .onAppear {
            if let selectedReciter, savedReciterId != selectedReciter.id {
                savedReciterId = selectedReciter.id
            }
        }
    }
}

#Preview {
    ReciterPickerView(reciters: ReciterService.shared.availableReciters, selectedReciter: ReciterService.shared.availableReciters.first!) { rec in
        
    }
}
