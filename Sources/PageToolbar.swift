import SwiftUI

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
        }.padding(.horizontal,10).frame(minWidth:140).frame(height:34)
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
        ViewThatFits(in:.horizontal) {
            HStack(spacing:12) {
                heading.fixedSize(horizontal:true,vertical:false)
                Spacer(minLength:8)
                PageSearchField(title:searchTitle,query:$query,focus:focus).frame(width:200)
                actions().fixedSize(horizontal:true,vertical:false)
            }
            VStack(alignment:.leading,spacing:10) {
                heading
                HStack(spacing:10) {
                    PageSearchField(title:searchTitle,query:$query,focus:focus)
                    actions().fixedSize(horizontal:true,vertical:false)
                }
            }
        }.controlSize(.regular).tint(color)
    }

    private var heading: some View {
        VStack(alignment:.leading,spacing:4) {
            Text(title).font(.system(size:19,weight:.semibold))
            Text(subtitle).font(.system(size:11)).foregroundStyle(.secondary)
        }
    }
}
