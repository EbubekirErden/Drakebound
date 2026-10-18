import SwiftUI
extension View {
    func editorBorder() -> some View { self.scrollContentBackground(.hidden).padding(8).background(paper.opacity(0.55)).clipShape(RoundedRectangle(cornerRadius:10)).overlay(RoundedRectangle(cornerRadius:10).stroke(ink.opacity(0.1))) }
}

struct EditorGroup<Content:View>:View {
    var title:String
    var badge:String? = nil
    var badgeColor:Color = accent
    @ViewBuilder var content:()->Content
    var body:some View { VStack(alignment:.leading,spacing:12) { HStack { Text(title.uppercased()).font(.system(size:9,weight:.semibold)).tracking(1).foregroundStyle(.secondary); Spacer(minLength:0); if let badge { Text(badge).font(.system(size:10,weight:.medium)).foregroundStyle(badgeColor).monospacedDigit() } }.frame(height:14); content() }.padding(14).frame(maxWidth:.infinity,alignment:.leading).background(paper.opacity(0.6)).clipShape(RoundedRectangle(cornerRadius:9)).overlay(RoundedRectangle(cornerRadius:9).stroke(ink.opacity(0.09))) }
}
struct EditorField<Content:View>:View {
    var title:String
    @ViewBuilder var content:()->Content
    var body:some View { VStack(alignment:.leading,spacing:5) { Text(title).font(.system(size:10)).foregroundStyle(.secondary); content().labelsHidden() }.frame(maxWidth:.infinity,alignment:.leading) }
}
struct BorderedTextEditor:View {
    @Binding var text:String
    var height:CGFloat = 90
    var body:some View { TextEditor(text:$text).font(.system(size:12)).scrollContentBackground(.hidden).frame(height:height).padding(7).background(surface).clipShape(RoundedRectangle(cornerRadius:7)).overlay(RoundedRectangle(cornerRadius:7).stroke(ink.opacity(0.12))) }
}
struct DetailText:View {
    var text:String
    var body:some View {
        if text.count > 1400 { ScrollView { Text(text).font(.system(size:13)).lineSpacing(4).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading) }.frame(height:290) }
        else if !text.isEmpty { Text(text).font(.system(size:13)).lineSpacing(4).textSelection(.enabled).fixedSize(horizontal:false,vertical:true).frame(maxWidth:.infinity,alignment:.leading) }
    }
}
struct AttackRollField:View {
    var title:String
    var value:String
    var subtitle:String = ""
    var color:Color
    var body:some View { VStack(spacing:4) { Text(title).font(.system(size:8,weight:.bold)).tracking(1).foregroundStyle(.secondary); Text(value).font(.system(size:21,weight:.semibold,design:.rounded)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.35); if !subtitle.isEmpty { Text(subtitle).font(.system(size:9)).foregroundStyle(color.opacity(0.7)).lineLimit(1) } }.frame(maxWidth:.infinity).frame(height:66).background(color.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius:8)) }
}
struct AttackDescription:View {
    var name:String
    var text:String
    var edit:(()->Void)? = nil
    var body:some View { VStack(alignment:.leading,spacing:14) { HStack { Text(name).font(.system(size:17,weight:.semibold)); Spacer(); if let edit { Button("Edit",action:edit) } }; if text.isEmpty { Text("No description yet. Add range, properties, targeting, and special effects in Edit.").font(.caption).foregroundStyle(.secondary) } else { DetailText(text:text) } }.padding(20).frame(width:440) }
}
