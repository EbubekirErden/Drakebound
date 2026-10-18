import SwiftUI
import AppKit
private struct FrameProbe:NSViewRepresentable {
 var id:String
 func makeNSView(context:Context)->NSView {let view=NSView();view.identifier=NSUserInterfaceItemIdentifier(id);return view}
 func updateNSView(_ view:NSView,context:Context) {}
}
private struct GridFixture:View {
 var body:some View {
  EqualHeightGridLayout {
   ForEach(0..<6) { i in
    VStack(alignment:.leading,spacing:8) {
     Text("Action \(i)")
     Color.clear.frame(height:CGFloat(15+i*14))
     Spacer(minLength:0)
     Text("Footer").frame(height:16).background(FrameProbe(id:"footer\(i)"))
    }.padding(12).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading).background(FrameProbe(id:"cell\(i)"))
   }
  }
 }
}
@main struct EqualHeightGridTests {
 @MainActor static func main() {
  NSApplication.shared.setActivationPolicy(.prohibited)
  for width in [260.0,520,780,1040] {
   let host=NSHostingView(rootView:GridFixture().frame(width:width))
   let window=NSWindow(contentRect:NSRect(x:0,y:0,width:width,height:900),styleMask:.borderless,backing:.buffered,defer:false)
   window.isReleasedWhenClosed=false;window.contentView=host;host.layoutSubtreeIfNeeded();RunLoop.main.run(until:Date(timeIntervalSinceNow:0.1))
   let views=descendants(host)
   func rect(_ id:String)->CGRect {let view=views.first{$0.identifier?.rawValue == id}!;return view.convert(view.bounds,to:host)}
   let columns=min(6,max(1,Int((width+8)/248)))
   for start in stride(from:0,to:6,by:columns) {
    let first=rect("cell\(start)"),footer=rect("footer\(start)")
    for i in start..<min(start+columns,6) {
     let cell=rect("cell\(i)"),foot=rect("footer\(i)")
     precondition(abs(cell.height-first.height)<0.5,"Unequal row heights at \(width)")
     precondition(abs(cell.minY-first.minY)<0.5,"Unequal row tops")
     precondition(abs(foot.minY-footer.minY)<0.5,"Unequal footer positions")
     precondition(cell.minX >= -1 && cell.maxX <= width+1)
     precondition(cell.height >= CGFloat(15+i*14)+40,"Content was clipped")
    }
   }
   window.close()
  }
  print("PASS: responsive row heights and footer alignment at one, two, three and four columns; natural content remains visible")
 }
 @MainActor static func descendants(_ view:NSView)->[NSView] {view.subviews.flatMap{[$0]+descendants($0)}}
}
