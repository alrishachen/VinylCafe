import SwiftUI

/// Album/track artwork with a graceful vinyl-record placeholder when there's no URL
/// (e.g. a hand-entered record, or before Spotify is connected).
struct CoverArtView: View {
    let url: String?
    var size: CGFloat = 56
    var cornerRadius: CGFloat = 8

    var body: some View {
        Group {
            if let url, let parsed = URL(string: url) {
                AsyncImage(url: parsed) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        placeholder
                    case .empty:
                        ZStack { placeholder; ProgressView() }
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(colors: [Color(.systemGray4), Color(.systemGray5)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "opticaldisc.fill")
                .font(.system(size: size * 0.42))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    HStack {
        CoverArtView(url: nil, size: 80)
        CoverArtView(url: nil, size: 56)
    }
    .padding()
}
