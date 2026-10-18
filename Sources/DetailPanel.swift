import SwiftUI

struct DismissibleDetail<Content:View>:View {
    var dismiss:()->Void
    @ViewBuilder var content:()->Content
    // Content never determines the panel size. Only the viewport or an explicit resize does.
    @State private var requestedSize = CGSize(width:660,height:580)
    @State private var resizeStart:CGSize?
    var body:some View {
        GeometryReader { viewport in
            let size = fitted(requestedSize,in:viewport.size)
            ZStack {
                Button(action:dismiss) { Color.black.opacity(0.48).contentShape(Rectangle()) }.buttonStyle(.plain).accessibilityLabel("Close details")
                content().padding(.bottom,28).frame(width:size.width,height:size.height)
                    .background(surface).clipShape(RoundedRectangle(cornerRadius:14))
                    .overlay(RoundedRectangle(cornerRadius:14).stroke(ink.opacity(0.12)))
                    .contentShape(Rectangle()).onTapGesture { }
                    .overlay(alignment:.bottomTrailing) {
                        Image(systemName:"arrow.up.left.and.arrow.down.right").font(.system(size:10,weight:.semibold)).foregroundStyle(.secondary)
                            .frame(width:24,height:24).background(paper.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius:5)).contentShape(Rectangle()).padding(3)
                            .onTapGesture { requestedSize = size.width >= viewport.size.width-40 && size.height >= viewport.size.height-40 ? CGSize(width:660,height:580):CGSize(width:viewport.size.width-32,height:viewport.size.height-32) }
                            .help("Click to expand or restore · drag to resize")
                            .accessibilityLabel("Expand or restore details")
                            .accessibilityAdjustableAction { direction in
                                let change:CGFloat = direction == .increment ? 40:-40
                                requestedSize = fitted(CGSize(width:size.width+change,height:size.height+change),in:viewport.size)
                            }
                            .gesture(DragGesture(minimumDistance:2,coordinateSpace:.named("detailViewport")).onChanged { value in
                                if resizeStart == nil { resizeStart = size }
                                let start = resizeStart ?? size
                                requestedSize = fitted(CGSize(width:start.width+value.translation.width*2,height:start.height+value.translation.height*2),in:viewport.size)
                            }.onEnded { _ in resizeStart = nil })
                    }
                    .shadow(color:.black.opacity(0.5),radius:28,y:10)
            }.frame(width:viewport.size.width,height:viewport.size.height)
                .coordinateSpace(name:"detailViewport")
        }.onExitCommand(perform:dismiss)
    }
    private func fitted(_ requested:CGSize,in viewport:CGSize) -> CGSize {
        let maximum = CGSize(width:max(1,viewport.width-32),height:max(1,viewport.height-32))
        return CGSize(width:min(maximum.width,max(540,requested.width)),height:min(maximum.height,max(440,requested.height)))
    }
}

