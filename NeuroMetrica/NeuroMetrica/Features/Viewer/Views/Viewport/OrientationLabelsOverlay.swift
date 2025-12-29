import SwiftUI

struct OrientationLabelsOverlay: View {
    let labels: ViewportOrientationLabels

    var body: some View {
        ZStack {
            labelText(labels.top)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 6)

            labelText(labels.bottom)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 6)

            labelText(labels.left)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.leading, 8)

            labelText(labels.right)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .padding(.trailing, 8)
        }
        .allowsHitTesting(false)
    }

    private func labelText(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.white)
            .shadow(color: Color.black.opacity(0.7), radius: 1)
    }
}
