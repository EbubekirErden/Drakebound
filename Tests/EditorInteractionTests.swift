import SwiftUI
import AppKit
let ink=Color.white
let paper=Color.black
let surface=Color.gray
@MainActor enum Probe { static var size=CGSize.zero }
@main struct EditorInteractionTests {
 @MainActor static func main() {
  let app=NSApplication.shared;app.setActivationPolicy(.regular)
  let host=NSHostingView(rootView:DismissibleDetail(dismiss:{}) { GeometryReader { geo in Color.gray.onAppear { Probe.size=geo.size }.onChange(of:geo.size) { _,size in Probe.size=size } } }.frame(width:1000,height:800))
  let window=NSWindow(contentRect:NSRect(x:100,y:100,width:1000,height:800),styleMask:.borderless,backing:.buffered,defer:false)
  window.isReleasedWhenClosed=false;window.contentView=host;window.makeKeyAndOrderFront(nil)
  RunLoop.main.run(until:Date(timeIntervalSinceNow:0.4))
  let before=Probe.size;print("Before",before);fflush(stdout)
  func send(_ type:NSEvent.EventType,_ x:Double,_ y:Double) {
   let event=NSEvent.mouseEvent(with:type,location:NSPoint(x:x,y:y),modifierFlags:[],timestamp:ProcessInfo.processInfo.systemUptime,windowNumber:window.windowNumber,context:nil,eventNumber:1,clickCount:1,pressure:type == .leftMouseUp ? 0:1)!
   app.sendEvent(event);RunLoop.main.run(until:Date(timeIntervalSinceNow:0.15))
  }
  // Default panel is centered at 660×580; handle is inset 15 points from its lower-right corner.
  send(.leftMouseDown,815,125)
  send(.leftMouseDragged,835,110)
  send(.leftMouseDragged,855,95)
  let during=Probe.size;print("During",during);fflush(stdout)
  send(.leftMouseUp,855,95)
  RunLoop.main.run(until:Date(timeIntervalSinceNow:0.5))
  let after=Probe.size;print("After",after);fflush(stdout)
  precondition(during.width>before.width && during.height>before.height,"Drag did not resize")
  precondition(after == during,"Releasing drag reset size")
  send(.leftMouseDown,855,95);send(.leftMouseUp,855,95)
  precondition(Probe.size.width>after.width,"Click did not expand panel")
  send(.leftMouseDown,969,31);send(.leftMouseUp,969,31)
  precondition(Probe.size == before,"Second click did not restore panel")
  window.close();print("PASS: detail resize persists after release; click expands and restores")
  var draft="- First 🐉"
  let textHost=NSHostingView(rootView:MarkdownInput(text:Binding(get:{ draft },set:{ draft=$0 })).frame(width:500,height:180))
  let textWindow=NSWindow(contentRect:NSRect(x:100,y:100,width:500,height:180),styleMask:.borderless,backing:.buffered,defer:false)
  textWindow.isReleasedWhenClosed=false;textWindow.contentView=textHost;textWindow.makeKeyAndOrderFront(nil)
  RunLoop.main.run(until:Date(timeIntervalSinceNow:0.2))
  func editor(_ view:NSView) -> MarkdownTextView? { if let text=view as? MarkdownTextView { return text };return view.subviews.compactMap(editor).first }
  let input=editor(textHost)!
  textWindow.makeFirstResponder(input);input.setSelectedRange(NSRange(location:(draft as NSString).length,length:0));input.insertNewline(nil)
  precondition(draft == "- First 🐉\n- ","Native editor did not save list continuation")
  input.insertNewline(nil);precondition(draft == "- First 🐉\n","Empty bullet did not end list")
  input.breakUndoCoalescing();RunLoop.main.run(until:Date(timeIntervalSinceNow:0.2))
  input.insertText("Pasted **text**",replacementRange:input.selectedRange())
  precondition(draft.hasSuffix("Pasted **text**"));precondition(!input.isRichText,"Paste must stay portable plain text")
  input.breakUndoCoalescing();RunLoop.main.run(until:Date(timeIntervalSinceNow:0.2));input.undoManager?.undo();RunLoop.main.run(until:Date(timeIntervalSinceNow:0.2));precondition(!draft.hasSuffix("Pasted **text**"),"Editor undo failed")
  input.undoManager?.redo();RunLoop.main.run(until:Date(timeIntervalSinceNow:0.2));precondition(draft.hasSuffix("Pasted **text**"),"Editor redo failed")
  textWindow.close();print("PASS: native description edits, Unicode, list continuation/exit, plain text insertion, undo, and redo")
 }
}
