import SwiftUI
import CoreTransferable
import UniformTypeIdentifiers

extension UTType {
    static let drakeboundListReorder=UTType(exportedAs:"local.fellowship.five.list-reorder",conformingTo:.data)
}
extension ListReorderToken:Transferable {
    static var transferRepresentation:some TransferRepresentation { CodableRepresentation(contentType:.drakeboundListReorder) }
}
struct ListReorderGrip:View {
    var token:ListReorderToken
    var name:String
    var enabled=true
    private var grip:some View { Image(systemName:"line.3.horizontal").font(.system(size:11)).foregroundStyle(.secondary).frame(width:20,height:28).contentShape(Rectangle()) }
    var body:some View {
        Group {
            if enabled { grip.draggable(token) { Label(name,systemImage:"line.3.horizontal").font(.system(size:12)).padding(10).background(surface,in:RoundedRectangle(cornerRadius:7)) } }
            else { grip.opacity(0.3) }
        }.help(enabled ? "Drag to reorder "+name:"No other entries in this group").accessibilityLabel("Reorder "+name)
    }
}
struct ListReorderDropTarget:ViewModifier {
    var accept:(ListReorderToken)->Bool
    @State private var targeted=false
    func body(content:Content)->some View {
        content
            .overlay(RoundedRectangle(cornerRadius:9).stroke(targeted ? accent:Color.clear,lineWidth:2).allowsHitTesting(false))
            .dropDestination(for:ListReorderToken.self) { tokens,_ in guard tokens.count == 1,let token=tokens.first else { return false };return accept(token) } isTargeted: { targeted=$0 }
    }
}
