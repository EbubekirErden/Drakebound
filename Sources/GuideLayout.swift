import SwiftUI

struct GuideSection<Content:View>:View {
    var title:String
    var summary:String
    @ViewBuilder var content:()->Content
    @State private var open:Bool
    init(_ title:String,summary:String = "",expanded:Bool = false,@ViewBuilder content:@escaping()->Content) {
        self.title=title;self.summary=summary;self.content=content;_open=State(initialValue:expanded)
    }
    var body:some View {
        VStack(alignment:.leading,spacing:0) {
            Button { withAnimation(.easeOut(duration:0.12)) { open.toggle() } } label: {
                HStack(spacing:9) { Image(systemName:open ? "chevron.down":"chevron.right").font(.system(size:10));Text(title).font(.system(size:13,weight:.semibold));Spacer(minLength:8);Text(summary).font(.system(size:11)).foregroundStyle(.secondary).lineLimit(2).multilineTextAlignment(.trailing) }.frame(minHeight:38).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel(title).accessibilityValue(open ? "Expanded":"Collapsed")
            if open { VStack(alignment:.leading,spacing:12,content:content).padding(.bottom,12) }
        }.padding(.horizontal,12).background(surface.opacity(0.65)).overlay(alignment:.bottom) { Divider().opacity(0.45) }
    }
}
struct GuideTable<Content:View>:View {
    @ViewBuilder var content:()->Content
    var body:some View { VStack(spacing:1,content:content).clipShape(RoundedRectangle(cornerRadius:9)).overlay(RoundedRectangle(cornerRadius:9).stroke(ink.opacity(0.09))) }
}
struct GuideTableRow:ViewModifier {
    var index:Int
    func body(content:Content)->some View { content.padding(.horizontal,10).padding(.vertical,8).frame(maxWidth:.infinity,alignment:.leading).background(index.isMultiple(of:2) ? surface:ink.opacity(0.025)) }
}
struct GuideExpandableRow<Actions:View,Content:View>:View {
    var title:String
    var subtitle:String
    var index:Int
    @ViewBuilder var actions:()->Actions
    @ViewBuilder var content:()->Content
    @State private var open=false
    var body:some View {
        VStack(alignment:.leading,spacing:0) {
            HStack(spacing:10) {
                Button { open.toggle() } label: { HStack(spacing:8) { Image(systemName:open ? "chevron.down":"chevron.right").font(.system(size:9));VStack(alignment:.leading,spacing:3) { Text(title).font(.system(size:12,weight:.medium)).lineLimit(2);if !subtitle.isEmpty { Text(subtitle).font(.system(size:10)).foregroundStyle(.secondary).lineLimit(2) } };Spacer(minLength:0) }.contentShape(Rectangle()) }.buttonStyle(.plain).accessibilityLabel("Details for "+title).accessibilityValue(open ? "Expanded":"Collapsed")
                HStack(spacing:10,content:actions).font(.system(size:12)).buttonStyle(.plain)
            }.frame(minHeight:30)
            if open { VStack(alignment:.leading,spacing:8,content:content).padding(.top,10).padding(.leading,17) }
        }.modifier(GuideTableRow(index:index))
    }
}
struct GuideActionMenu<Content:View>:View {
    var title:String
    @ViewBuilder var content:()->Content
    var body:some View {
        Menu(content:content,label:{ Image(systemName:"ellipsis") }).menuStyle(.borderlessButton).menuIndicator(.hidden)
            .frame(width:34,height:34).background(surface,in:RoundedRectangle(cornerRadius:8)).help(title).accessibilityLabel(title)
    }
}
