import SwiftUI

struct GIFGridItemView: View {
    let result: GIFResult
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        AnimatedGIFView(url: result.previewURL)
            .frame(height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        isSelected ? Color.accentColor : Color.clear,
                        lineWidth: 2
                    )
            )
            .overlay(
                // Hover / selected highlight
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .onTapGesture(perform: onTap)
    }
}
