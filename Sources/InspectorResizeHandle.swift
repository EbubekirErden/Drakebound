import SwiftUI

// Track the pointer in a fixed ancestor coordinate space. Only commit the width at release,
// so large compendium result grids are not laid out or persisted for every mouse movement.
struct InspectorResizeHandle:View {
    @Binding var width:Double
    var minimum:Double = 300
    var maximum:Double = 540
    var coordinateSpace = "compendiumViewport"
    @GestureState private var translation:CGFloat = 0
    private var current:Double { min(maximum,max(minimum,width)) }
    private var proposed:Double { min(maximum,max(minimum,current-translation)) }
    var body:some View {
        Rectangle().fill(ink.opacity(0.1)).frame(width:7)
            .overlay { Capsule().fill(ink.opacity(0.25)).frame(width:2,height:30) }
            .overlay { if translation != 0 { Rectangle().fill(accent).frame(width:2).offset(x:current-proposed).allowsHitTesting(false) } }
            .contentShape(Rectangle())
            .onHover { inside in if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() } }
            .gesture(DragGesture(minimumDistance:2,coordinateSpace:.named(coordinateSpace))
                .updating($translation) { value,state,_ in state=value.translation.width }
                .onEnded { value in width=min(maximum,max(minimum,current-value.translation.width)) })
            .help("Drag to resize · width applies on release").accessibilityLabel("Detail inspector width")
            .accessibilityValue("\(Int(current)) points")
            .accessibilityAdjustableAction { direction in width=min(maximum,max(minimum,current+(direction == .increment ? 20:-20))) }
    }
}
