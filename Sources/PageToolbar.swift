import SwiftUI

enum PageControl {
    static let height: CGFloat = 34
    static let statisticHeight: CGFloat = 44
}

struct PageButtonStyle: ButtonStyle {
    var color: Color = accent
    var prominent = false
    var height: CGFloat = PageControl.height
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size:13,weight:.medium))
            .padding(.horizontal,12).frame(height:height)
            .foregroundStyle(prominent ? paper:ink)
            .background(prominent ? color:surface,in:RoundedRectangle(cornerRadius:8))
            .overlay(RoundedRectangle(cornerRadius:8).stroke(prominent ? Color.clear:ink.opacity(0.09)))
            .contentShape(RoundedRectangle(cornerRadius:8))
            .opacity(!isEnabled ? 0.4:configuration.isPressed ? 0.75:1)
    }
}

struct PageMenuStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.font(.system(size:13,weight:.medium))
            .menuStyle(.borderlessButton).menuIndicator(.visible)
            .fixedSize(horizontal:true,vertical:false)
            .padding(.horizontal,12).frame(height:PageControl.height)
            .background(surface,in:RoundedRectangle(cornerRadius:8))
            .overlay(RoundedRectangle(cornerRadius:8).stroke(ink.opacity(0.09)))
    }
}

struct PagePicker<Selection: Hashable, Options: View>: View {
    var title: String
    var selectionTitle: String
    @Binding var selection: Selection
    @ViewBuilder var options: () -> Options

    var body: some View {
        Menu {
            Picker(title,selection:$selection,content:options).pickerStyle(.inline)
        } label: {
            Text(selectionTitle)
        }.modifier(PageMenuStyle())
            .accessibilityLabel(title).accessibilityValue(selectionTitle)
    }
}

struct PageSearchField: View {
    var title: String
    @Binding var query: String
    var focus: FocusState<Bool>.Binding? = nil

    var body: some View {
        HStack(spacing:8) {
            Image(systemName:"magnifyingglass").font(.system(size:12)).foregroundStyle(.secondary)
            input.font(.system(size:13)).textFieldStyle(.plain).accessibilityLabel(title)
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName:"xmark.circle.fill").foregroundStyle(.secondary) }
                    .buttonStyle(.plain).help("Clear search").accessibilityLabel("Clear "+title.lowercased())
            }
        }.padding(.horizontal,10).frame(minWidth:140).frame(height:PageControl.height)
            .background(paper.opacity(0.65),in:RoundedRectangle(cornerRadius:8))
            .overlay(RoundedRectangle(cornerRadius:8).stroke(ink.opacity(0.09)))
    }

    @ViewBuilder private var input: some View {
        if let focus { TextField(title,text:$query).focused(focus) }
        else { TextField(title,text:$query) }
    }
}

struct PageToolbar<Actions: View>: View {
    var title: String
    var subtitle: String
    var color: Color = accent
    var searchTitle: String
    @Binding var query: String
    var focus: FocusState<Bool>.Binding? = nil
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        PageToolbarLayout {
            heading.fixedSize(horizontal:true,vertical:false)
            PageSearchField(title:searchTitle,query:$query,focus:focus)
            HStack(spacing:12) { actions() }.fixedSize(horizontal:true,vertical:false)
        }.controlSize(.regular).tint(color)
    }

    private var heading: some View {
        VStack(alignment:.leading,spacing:4) {
            Text(title).font(.system(size:19,weight:.semibold))
            Text(subtitle).font(.system(size:11)).foregroundStyle(.secondary)
        }
    }
}

// Keep a single presentation anchor for each action as the toolbar changes rows.
private struct PageToolbarLayout: Layout {
    func sizeThatFits(proposal:ProposedViewSize,subviews:Subviews,cache:inout ()) -> CGSize {
        let heading=subviews[0].sizeThatFits(.unspecified),actions=subviews[2].sizeThatFits(.unspecified)
        let width=proposal.width ?? heading.width+200+actions.width+32
        let rowHeight=max(PageControl.height,actions.height)
        if width >= heading.width+200+actions.width+32 { return CGSize(width:width,height:max(heading.height,rowHeight)) }
        if width >= 140+actions.width+12 { return CGSize(width:width,height:heading.height+10+rowHeight) }
        return CGSize(width:width,height:heading.height+10+PageControl.height+10+actions.height)
    }
    func placeSubviews(in bounds:CGRect,proposal:ProposedViewSize,subviews:Subviews,cache:inout ()) {
        let heading=subviews[0].sizeThatFits(.unspecified),actions=subviews[2].sizeThatFits(.unspecified)
        let inline=bounds.width >= heading.width+200+actions.width+32
        let separateActions=bounds.width < 140+actions.width+12
        let rowHeight=max(PageControl.height,actions.height)
        let rowY=inline ? bounds.minY+(bounds.height-rowHeight)/2:bounds.minY+heading.height+10
        subviews[0].place(at:CGPoint(x:bounds.minX,y:inline ? bounds.minY+(bounds.height-heading.height)/2:bounds.minY),anchor:.topLeading,proposal:ProposedViewSize(heading))
        let searchWidth=separateActions ? bounds.width:inline ? 200:bounds.width-actions.width-12
        let searchX=inline ? bounds.maxX-actions.width-12-searchWidth:bounds.minX
        subviews[1].place(at:CGPoint(x:searchX,y:separateActions ? rowY:rowY+(rowHeight-PageControl.height)/2),anchor:.topLeading,proposal:ProposedViewSize(width:searchWidth,height:PageControl.height))
        subviews[2].place(at:CGPoint(x:separateActions ? bounds.minX:bounds.maxX-actions.width,y:separateActions ? rowY+PageControl.height+10:rowY+(rowHeight-actions.height)/2),anchor:.topLeading,proposal:ProposedViewSize(actions))
    }
}

// Filters retain their own controls and popover anchors while wrapping onto additional rows.
struct ControlFlowLayout:Layout {
    var spacing:CGFloat = 8
    private func arrange(width:CGFloat,subviews:Subviews)->(CGSize,[CGPoint],[CGSize]) {
        var points:[CGPoint]=[],sizes:[CGSize]=[]
        var x:CGFloat=0,y:CGFloat=0,rowHeight:CGFloat=0
        var rowStart=0
        func centerRow() { for index in rowStart..<points.count { points[index].y += (rowHeight-sizes[index].height)/2 } }
        for view in subviews {
            let ideal=view.sizeThatFits(.unspecified)
            let size=view.sizeThatFits(ProposedViewSize(width:min(ideal.width,width),height:nil))
            if x > 0 && x+size.width > width { centerRow();rowStart=points.count;x=0;y += rowHeight+spacing;rowHeight=0 }
            points.append(CGPoint(x:x,y:y));sizes.append(size)
            x += size.width+spacing;rowHeight=max(rowHeight,size.height)
        }
        centerRow()
        return (CGSize(width:width,height:y+rowHeight),points,sizes)
    }
    func sizeThatFits(proposal:ProposedViewSize,subviews:Subviews,cache:inout ()) -> CGSize {
        arrange(width:max(1,proposal.width ?? subviews.reduce(CGFloat(0)) { $0+$1.sizeThatFits(.unspecified).width+spacing }),subviews:subviews).0
    }
    func placeSubviews(in bounds:CGRect,proposal:ProposedViewSize,subviews:Subviews,cache:inout ()) {
        let (_,points,sizes)=arrange(width:max(1,bounds.width),subviews:subviews)
        for index in subviews.indices { subviews[index].place(at:CGPoint(x:bounds.minX+points[index].x,y:bounds.minY+points[index].y),anchor:.topLeading,proposal:ProposedViewSize(sizes[index])) }
    }
}
struct ActiveFilterChip:View {
    var title:String
    var clear:()->Void
    var body:some View {
        Button(action:clear) { HStack(spacing:6) { Text(title).lineLimit(1);Image(systemName:"xmark").font(.system(size:8,weight:.semibold)) }.font(.system(size:11)).padding(.horizontal,9).frame(height:28).background(accent.opacity(0.09),in:Capsule()) }
            .buttonStyle(.plain).foregroundStyle(accent).help("Remove filter: "+title).accessibilityLabel("Remove filter: "+title)
    }
}
