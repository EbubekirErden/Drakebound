import SwiftUI

// Disclosure preferences belong to the interface and never enter a character archive.
struct SheetCard<Content:View>:View {
    var title:String
    var tip:HelpTopic?
    var summary:String
    @ViewBuilder var content:Content
    @AppStorage private var collapsed:Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    init(title:String,tip:HelpTopic? = nil,summary:String = "",@ViewBuilder content:()->Content) {
        self.title=title;self.tip=tip;self.summary=summary;self.content=content()
        _collapsed=AppStorage(wrappedValue:false,"sheetSectionCollapsed."+title)
    }
    var body:some View {
        VStack(alignment:.leading,spacing:collapsed ? 0:10) {
            HStack(spacing:10) {
                Button {
                    withAnimation(reduceMotion ? nil:.easeOut(duration:0.15)) { collapsed.toggle() }
                } label: {
                    HStack(spacing:8) {
                        Image(systemName:collapsed ? "chevron.right":"chevron.down").font(.system(size:9,weight:.semibold))
                        Text(title.uppercased()).font(.system(size:10,weight:.bold)).tracking(1.2)
                        Spacer(minLength:8)
                        if collapsed && !summary.isEmpty { Text(summary).font(.system(size:11)).foregroundStyle(.secondary).lineLimit(2).multilineTextAlignment(.trailing) }
                    }.foregroundStyle(sectionColor(title)).frame(minHeight:24).contentShape(Rectangle())
                }.buttonStyle(.plain).help((collapsed ? "Expand ":"Collapse ")+title.lowercased()).accessibilityLabel(title).accessibilityValue(collapsed ? "Collapsed":"Expanded")
                if let tip { TipButton(topic:tip) }
            }
            if !collapsed { content }
        }.padding(14).frame(maxWidth:.infinity,alignment:.leading).background(surface,in:RoundedRectangle(cornerRadius:9)).overlay(RoundedRectangle(cornerRadius:9).stroke(ink.opacity(0.08)))
    }
}
struct SheetDisplayMenu:View {
    @AppStorage("sheetSectionCollapsed.Abilities & saves") private var abilities=false
    @AppStorage("sheetSectionCollapsed.Skills") private var skills=false
    @AppStorage("sheetSectionCollapsed.Features & traits") private var features=false
    @AppStorage("sheetSectionCollapsed.Feats & bonuses") private var bonuses=false
    @AppStorage("sheetSectionCollapsed.Attacks") private var attacks=false
    @AppStorage("sheetSectionCollapsed.Resources") private var resources=false
    @AppStorage("sheetSectionCollapsed.Conditions") private var conditions=false
    @AppStorage("sheetSectionCollapsed.Attacks & resources") private var readiness=false
    var body:some View {
        Button("Compact Sheet") { abilities=true;skills=true;features=true;bonuses=true;attacks=false;resources=false;conditions=false;readiness=false }
        Button("Expand all Sheet sections") { abilities=false;skills=false;features=false;bonuses=false;attacks=false;resources=false;conditions=false;readiness=false }
    }
}
