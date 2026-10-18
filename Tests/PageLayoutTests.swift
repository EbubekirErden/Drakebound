import SwiftUI
import AppKit

let ink=Color.white,accent=Color.green,paper=Color.black,surface=Color.gray
private struct LayoutProbe:NSViewRepresentable {
    var id:String
    func makeNSView(context:Context)->NSView { let v=NSView();v.identifier=NSUserInterfaceItemIdentifier(id);return v }
    func updateNSView(_ nsView:NSView,context:Context) {}
}
private struct ToolbarFixture:View {
    @State private var query=""
    var body:some View {
        PageToolbar(title:"Compendium",subtitle:"Local references",searchTitle:"Search",query:$query) {
            Button("New reference") {}.buttonStyle(PageButtonStyle()).background(LayoutProbe(id:"action1"))
            Button("Preview") {}.buttonStyle(PageButtonStyle()).background(LayoutProbe(id:"action2"))
        }
    }
}
@main struct PageLayoutTests {
    @MainActor static func main() {
        NSApplication.shared.setActivationPolicy(.prohibited)
        for width in [300.0,420,620,1000] {
            let root=ToolbarFixture().frame(width:width,alignment:.topLeading)
            let host=NSHostingView(rootView:root)
            let window=NSWindow(contentRect:NSRect(x:0,y:0,width:width,height:220),styleMask:.borderless,backing:.buffered,defer:false)
            window.isReleasedWhenClosed=false;window.contentView=host
            host.layoutSubtreeIfNeeded();RunLoop.main.run(until:Date(timeIntervalSinceNow:0.1))
            let views=descendants(host)
            let controls=views.filter { ["action1","action2"].contains($0.identifier?.rawValue ?? "") || $0 is NSTextField }
            precondition(controls.count >= 3,"Missing toolbar controls")
            verify(controls,in:host,width:width)
            window.close()
        }
        for width in [220.0,330,700] {
            let root=ControlFlowLayout { ForEach(Array([120.0,170,90,90].enumerated()),id:\.offset) { i,w in Color.clear.frame(width:w,height:i.isMultiple(of:2) ? 34:28).background(LayoutProbe(id:"flow\(i)")) } }.frame(width:width,alignment:.topLeading)
            let host=NSHostingView(rootView:root)
            let window=NSWindow(contentRect:NSRect(x:0,y:0,width:width,height:220),styleMask:.borderless,backing:.buffered,defer:false)
            window.isReleasedWhenClosed=false;window.contentView=host
            host.layoutSubtreeIfNeeded();RunLoop.main.run(until:Date(timeIntervalSinceNow:0.1))
            let controls=descendants(host).filter { $0.identifier?.rawValue.hasPrefix("flow") == true }
            precondition(controls.count == 4)
            verify(controls,in:host,width:width);window.close()
        }
        print("PASS: toolbar and filter controls remain inside their bounds without overlaps at narrow and wide widths")
    }
    @MainActor static func descendants(_ view:NSView)->[NSView] { view.subviews.flatMap { [$0]+descendants($0) } }
    @MainActor static func verify(_ views:[NSView],in host:NSView,width:Double) {
        let frames=views.map { $0.convert($0.bounds,to:host) }
        for (i,frame) in frames.enumerated() {
            precondition(frame.width > 0 && frame.height > 0,"Empty control")
            precondition(frame.minX >= -1 && frame.maxX <= width+1,"Control outside width \(width): \(frame)")
            for other in frames.dropFirst(i+1) { precondition(!frame.insetBy(dx:1,dy:1).intersects(other.insetBy(dx:1,dy:1)),"Controls overlap at width \(width)") }
        }
    }
}
