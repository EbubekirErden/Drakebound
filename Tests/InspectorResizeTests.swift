import SwiftUI
import AppKit
let ink=Color.white
let accent=Color.teal
@MainActor private enum InspectorProbe { static var width=0.0 }
private struct InspectorTestPane:View {
    @State private var width=360.0
    var body:some View {
        HStack(spacing:0) {
            Color.gray.frame(maxWidth:.infinity)
            InspectorResizeHandle(width:$width,maximum:440)
            Color.black.frame(width:width)
        }.coordinateSpace(name:"compendiumViewport").onAppear { InspectorProbe.width=width }.onChange(of:width) { _,value in InspectorProbe.width=value }
    }
}
@main struct InspectorResizeTests {
    @MainActor static func main() {
        let app=NSApplication.shared;app.setActivationPolicy(.regular)
        let host=NSHostingView(rootView:InspectorTestPane().frame(width:1000,height:600))
        let window=NSWindow(contentRect:NSRect(x:100,y:100,width:1000,height:600),styleMask:.borderless,backing:.buffered,defer:false)
        window.isReleasedWhenClosed=false;window.contentView=host;window.makeKeyAndOrderFront(nil)
        RunLoop.main.run(until:Date(timeIntervalSinceNow:0.3))
        func send(_ type:NSEvent.EventType,_ x:Double) {
            let event=NSEvent.mouseEvent(with:type,location:NSPoint(x:x,y:300),modifierFlags:[],timestamp:ProcessInfo.processInfo.systemUptime,windowNumber:window.windowNumber,context:nil,eventNumber:1,clickCount:1,pressure:type == .leftMouseUp ? 0:1)!
            app.sendEvent(event);RunLoop.main.run(until:Date(timeIntervalSinceNow:0.12))
        }
        send(.leftMouseDown,636);send(.leftMouseDragged,616);send(.leftMouseDragged,586)
        precondition(InspectorProbe.width == 360,"Large results must not reflow or persist width during the drag")
        send(.leftMouseUp,586);precondition(InspectorProbe.width == 410,"Width did not commit once on release")
        RunLoop.main.run(until:Date(timeIntervalSinceNow:0.3));precondition(InspectorProbe.width == 410,"Committed width snapped back")
        send(.leftMouseDown,586);send(.leftMouseDragged,900);send(.leftMouseUp,900);precondition(InspectorProbe.width == 300,"Minimum width not enforced")
        send(.leftMouseDown,696);send(.leftMouseDragged,300);send(.leftMouseUp,300);precondition(InspectorProbe.width == 440,"Maximum width not enforced")
        window.close();print("PASS: stable inspector drag guide, release-only width updates, no snap-back, and width limits")
    }
}
