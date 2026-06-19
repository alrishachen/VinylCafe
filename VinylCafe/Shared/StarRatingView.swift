import SwiftUI

/// Read-only star display supporting half-stars.
struct StarsView: View {
    let stars: Double
    var size: CGFloat = 14
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: symbol(for: i))
                    .font(.system(size: size))
                    .foregroundStyle(.yellow)
            }
        }
    }
    private func symbol(for index: Int) -> String {
        let value = Double(index)
        if stars >= value { return "star.fill" }
        if stars >= value - 0.5 { return "star.leadinghalf.filled" }
        return "star"
    }
}

/// Interactive half-star picker. Tap a star for whole, tap its left half for a half star.
/// Tapping the current value clears it (sets to 0).
struct StarRatingView: View {
    @Binding var stars: Double
    var size: CGFloat = 30

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...5, id: \.self) { i in
                star(for: i)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Rating")
        .accessibilityValue("\(stars, specifier: "%.1f") of 5 stars")
    }

    private func star(for index: Int) -> some View {
        let value = Double(index)
        let symbol: String = {
            if stars >= value { return "star.fill" }
            if stars >= value - 0.5 { return "star.leadinghalf.filled" }
            return "star"
        }()
        return Image(systemName: symbol)
            .font(.system(size: size))
            .foregroundStyle(stars >= value - 0.5 ? .yellow : Color(.systemGray3))
            .contentShape(Rectangle())
            .overlay(
                HStack(spacing: 0) {
                    Color.clear.contentShape(Rectangle())
                        .onTapGesture { set(value - 0.5) }
                    Color.clear.contentShape(Rectangle())
                        .onTapGesture { set(value) }
                }
            )
    }

    private func set(_ newValue: Double) {
        stars = (stars == newValue) ? 0 : newValue
    }
}

#Preview {
    struct Demo: View {
        @State var stars = 3.5
        var body: some View {
            VStack(spacing: 24) {
                StarRatingView(stars: $stars)
                StarsView(stars: stars, size: 20)
                Text("\(stars, specifier: "%.1f")")
            }.padding()
        }
    }
    return Demo()
}
