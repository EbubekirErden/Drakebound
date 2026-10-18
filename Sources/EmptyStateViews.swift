import SwiftUI

/// Explicit geometry keeps intrinsic-size placeholders centered in leading stacks and scroll content.
struct CenteredEmptyState: View {
    var title: String
    var systemImage: String
    var description: Text
    var height: CGFloat?
    init(_ title: String, systemImage: String, description: Text, height: CGFloat? = nil) {
        self.title = title; self.systemImage = systemImage; self.description = description; self.height = height
    }
    var body: some View {
        GeometryReader { area in
            ContentUnavailableView(title, systemImage: systemImage, description: description)
                .frame(width: area.size.width, height: area.size.height, alignment: .center)
        }.frame(height: height).frame(maxWidth: .infinity)
    }
}
