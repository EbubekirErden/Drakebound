import SwiftUI

struct CustomEditorFrame: ViewModifier {
    func body(content: Content) -> some View {
        let screen = NSScreen.main?.visibleFrame.size ?? CGSize(width:1200,height:900)
        content.frame(width:min(920,max(580,screen.width-100)),height:min(760,max(520,screen.height-140)))
    }
}

struct EditorColumns<Leading:View,Trailing:View>: View {
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing
    var body: some View {
        EditorColumnsLayout {
            VStack(alignment:.leading,spacing:12,content:leading)
            VStack(alignment:.leading,spacing:12,content:trailing)
        }
    }
}

private struct EditorColumnsLayout: Layout {
    private let gap:CGFloat = 16
    func sizeThatFits(proposal:ProposedViewSize,subviews:Subviews,cache:inout ()) -> CGSize {
        let width = proposal.width ?? 880
        let columnWidth = width >= 740 ? (width-gap)/2:width
        let sizes = subviews.map { $0.sizeThatFits(ProposedViewSize(width:columnWidth,height:nil)) }
        return CGSize(width:width,height:width >= 740 ? max(sizes[0].height,sizes[1].height):sizes[0].height+gap+sizes[1].height)
    }
    func placeSubviews(in bounds:CGRect,proposal:ProposedViewSize,subviews:Subviews,cache:inout ()) {
        let sideBySide = bounds.width >= 740
        let width = sideBySide ? (bounds.width-gap)/2:bounds.width
        let first = subviews[0].sizeThatFits(ProposedViewSize(width:width,height:nil))
        subviews[0].place(at:bounds.origin,anchor:.topLeading,proposal:ProposedViewSize(width:width,height:first.height))
        subviews[1].place(at:CGPoint(x:sideBySide ? bounds.minX+width+gap:bounds.minX,y:sideBySide ? bounds.minY:bounds.minY+first.height+gap),anchor:.topLeading,proposal:ProposedViewSize(width:width,height:nil))
    }
}

struct EditorRowStyle: ViewModifier {
    var index:Int
    func body(content:Content) -> some View {
        content.padding(12).frame(maxWidth:.infinity,alignment:.leading)
            .background(index.isMultiple(of:2) ? surface:ink.opacity(0.045),in:RoundedRectangle(cornerRadius:8))
            .overlay(RoundedRectangle(cornerRadius:8).stroke(ink.opacity(0.06)))
    }
}
