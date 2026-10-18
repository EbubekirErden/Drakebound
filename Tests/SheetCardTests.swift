import SwiftUI
import AppKit

let ink=Color.white,surface=Color.gray
func sectionColor(_ title:String)->Color { .green }
enum HelpTopic { case fixture }
struct TipButton:View { var topic:HelpTopic;var body:some View { Text("Help") } }
private struct ContentProbe:NSViewRepresentable {
    func makeNSView(context:Context)->NSView { let view=NSView();view.identifier=NSUserInterfaceItemIdentifier("folding-content");return view }
    func updateNSView(_ view:NSView,context:Context) {}
}
@main struct SheetCardTests {
    @MainActor static func main() {
        NSApplication.shared.setActivationPolicy(.regular)
        let suite="local.drakebound.sheet-folding-tests."+UUID().uuidString
        let preferences=UserDefaults(suiteName:suite)!
        defer { preferences.removePersistentDomain(forName:suite) }
        let key="sheetSectionCollapsed.Test section"
        func makeWindow()->NSWindow {
            let root=VStack(spacing:0) { SheetCard(title:"Test section",summary:"Retained summary") { ContentProbe().frame(height:100) };Spacer(minLength:0) }.defaultAppStorage(preferences).frame(width:400,height:320,alignment:.top)
            let host=NSHostingView(rootView:root)
            let window=NSWindow(contentRect:NSRect(x:0,y:0,width:400,height:320),styleMask:.borderless,backing:.buffered,defer:false)
            window.isReleasedWhenClosed=false;window.contentView=host;window.makeKeyAndOrderFront(nil)
            host.layoutSubtreeIfNeeded();pause();return window
        }
        var window=makeWindow()
        precondition(hasContent(window.contentView!));precondition(!preferences.bool(forKey:key))
        click(window,at:NSPoint(x:120,y:294));pause()
        precondition(preferences.bool(forKey:key),"Header did not persist collapse")
        precondition(!hasContent(window.contentView!),"Collapsed section still displays controls")
        window.close();window=makeWindow()
        precondition(!hasContent(window.contentView!),"Collapse was lost after recreating section")
        click(window,at:NSPoint(x:120,y:294));pause()
        precondition(!preferences.bool(forKey:key));precondition(hasContent(window.contentView!),"Expanding did not restore controls")
        window.close()
        print("PASS: section header folds, persists in isolated preferences, restores on recreation, and reopens its controls without a Store")
    }
    @MainActor static func pause() { RunLoop.main.run(until:Date(timeIntervalSinceNow:0.25)) }
    @MainActor static func hasContent(_ view:NSView)->Bool { view.identifier?.rawValue == "folding-content" || view.subviews.contains(where:hasContent) }
    @MainActor static func click(_ window:NSWindow,at point:NSPoint) {
        for type in [NSEvent.EventType.leftMouseDown,.leftMouseUp] { NSApp.sendEvent(NSEvent.mouseEvent(with:type,location:point,modifierFlags:[],timestamp:ProcessInfo.processInfo.systemUptime,windowNumber:window.windowNumber,context:nil,eventNumber:1,clickCount:1,pressure:type == .leftMouseDown ? 1:0)!) }
    }
}
