import SwiftUI

enum PageControl {
    static let height: CGFloat = 34
}

struct PageButtonStyle: ButtonStyle {
    var color: Color = accent
    var prominent = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size:13,weight:.medium))
            .padding(.horizontal,12).frame(height:PageControl.height)
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

// Keep one copy of the actions so popovers have one stable presentation anchor.
private struct PageToolbarLayout: Layout {
    private func sizes(_ subviews:Subviews) -> (CGSize,CGSize) {
        (subviews[0].sizeThatFits(.unspecified),subviews[2].sizeThatFits(.unspecified))
    }
    func sizeThatFits(proposal:ProposedViewSize,subviews:Subviews,cache:inout ()) -> CGSize {
        let (heading,actions) = sizes(subviews)
        let width = proposal.width ?? heading.width+200+actions.width+32
        let inline = width >= heading.width+200+actions.width+32
        let rowHeight = max(PageControl.height,actions.height)
        return CGSize(width:width,height:inline ? max(heading.height,rowHeight):heading.height+10+rowHeight)
    }
    func placeSubviews(in bounds:CGRect,proposal:ProposedViewSize,subviews:Subviews,cache:inout ()) {
        let (heading,actions) = sizes(subviews)
        let inline = bounds.width >= heading.width+200+actions.width+32
        let rowHeight = max(PageControl.height,actions.height)
        let rowY = inline ? bounds.minY+(bounds.height-rowHeight)/2:bounds.minY+heading.height+10
        subviews[0].place(at:CGPoint(x:bounds.minX,y:inline ? bounds.minY+(bounds.height-heading.height)/2:bounds.minY),anchor:.topLeading,proposal:ProposedViewSize(heading))
        let searchWidth = inline ? 200:max(140,bounds.width-actions.width-12)
        let searchX = inline ? bounds.maxX-actions.width-12-searchWidth:bounds.minX
        subviews[1].place(at:CGPoint(x:searchX,y:rowY+(rowHeight-PageControl.height)/2),anchor:.topLeading,proposal:ProposedViewSize(width:searchWidth,height:PageControl.height))
        subviews[2].place(at:CGPoint(x:bounds.maxX-actions.width,y:rowY+(rowHeight-actions.height)/2),anchor:.topLeading,proposal:ProposedViewSize(actions))
    }
}
