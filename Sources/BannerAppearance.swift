import SwiftUI

struct BannerImageOverlay:View {
    var leadingOpacity:Double = 0.88
    var centerOpacity:Double = 0.3
    var bottomOpacity:Double = 0.6
    @Environment(\.colorScheme) private var colorScheme
    var body:some View {
        ZStack {
            if colorScheme == .dark {
                LinearGradient(colors:[Color.black.opacity(leadingOpacity),Color.black.opacity(centerOpacity),.clear],startPoint:.leading,endPoint:.trailing)
                LinearGradient(colors:[.clear,.black.opacity(bottomOpacity)],startPoint:.top,endPoint:.bottom)
            } else {
                LinearGradient(stops:[.init(color:paper.opacity(0.98),location:0),.init(color:paper.opacity(0.72),location:0.58),.init(color:.clear,location:1)],startPoint:.leading,endPoint:.trailing)
                LinearGradient(colors:[surface.opacity(0.10),surface.opacity(0.90)],startPoint:.top,endPoint:.bottom)
            }
        }.allowsHitTesting(false)
    }
}
