import SwiftUI

struct CroppedImage: View {
    var data: Data?
    var crop: BannerCrop
    var body: some View {
        GeometryReader { g in
            if let image = LocalImage.display(data) {
                let scale = max(g.size.width/max(1,image.size.width),g.size.height/max(1,image.size.height))*crop.zoom
                let width = image.size.width*scale; let height = image.size.height*scale
                Image(nsImage:image).resizable().frame(width:width,height:height).offset(x:(g.size.width-width)*crop.x,y:(g.size.height-height)*crop.y)
            }
        }.clipped().allowsHitTesting(false)
        // Cropping clips pixels, not hit testing. Decorative oversized images must
        // never intercept controls above or below the visible banner.
    }
}
struct CharacterBanner: View {
    @Binding var hero: Hero
    @Binding var expanded: Bool
    var previewAspectRatio: CGFloat
    var edit: ()->Void
    var more: AnyView
    var levelUp:(()->Void)? = nil
    @State var cropping = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack(alignment:.bottomLeading) {
            Rectangle().fill(surface.gradient)
            CroppedImage(data:hero.portrait,crop:hero.bannerCrop ?? BannerCrop())
            LinearGradient(colors:[paper.opacity(0.88),paper.opacity(0.3),.clear],startPoint:.leading,endPoint:.trailing)
            LinearGradient(colors:[.clear,.black.opacity(0.6)],startPoint:.top,endPoint:.bottom)
            HStack(alignment:.bottom) {
                VStack(alignment:.leading,spacing:8) {
                    Text(hero.name).font(.system(size:27,weight:.semibold)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.65)
                    Text("\(hero.ancestry) · \(hero.characterClass) · Level \(hero.level)").font(.system(size:12)).foregroundStyle(.white.opacity(0.8)).lineLimit(1)
                    if !hero.canAct { Label("Actions unavailable · active condition",systemImage:"exclamationmark.circle").font(.caption).foregroundStyle(gold) }
                }
                Spacer()
            }.padding(20)
        }.overlay(alignment:.topTrailing) {
            HStack(spacing:10) {
                if let levelUp { Button("Level up",action:levelUp).disabled(hero.level >= 20) }
                Button { cropping = true } label: { Image(systemName:"crop").frame(width:20,height:20) }.help("Choose the visible part of the banner").accessibilityLabel("Frame character banner")
                Button {
                    withAnimation(reduceMotion ? nil:.easeInOut(duration:0.2)) { expanded.toggle() }
                } label: { Image(systemName:expanded ? "arrow.down.right.and.arrow.up.left":"arrow.up.left.and.arrow.down.right").frame(width:20,height:20) }
                    .help(expanded ? "Compact banner":"Expand banner").accessibilityLabel(expanded ? "Compact banner":"Expand banner")
                Button("Edit",action:edit)
                more
            }.padding(8).background(paper.opacity(0.85),in:RoundedRectangle(cornerRadius:10)).padding(12)
        }.clipShape(RoundedRectangle(cornerRadius:12)).overlay(RoundedRectangle(cornerRadius:12).stroke(.white.opacity(0.08)))
        .sheet(isPresented:$cropping) { BannerEditor(hero:$hero,previewAspectRatio:previewAspectRatio) }
    }
}
struct BannerEditor: View {
    @Binding var hero: Hero
    @State var crop: BannerCrop
    var previewAspectRatio: CGFloat
    @Environment(\.dismiss) var dismiss
    init(hero:Binding<Hero>,previewAspectRatio:CGFloat = 3.5) { _hero = hero; _crop = State(initialValue:hero.wrappedValue.bannerCrop ?? BannerCrop()); self.previewAspectRatio = previewAspectRatio }
    var body: some View {
        VStack(alignment:.leading,spacing:18) {
            Text("Banner framing").font(.headline)
            CroppedImage(data:hero.portrait,crop:crop).aspectRatio(previewAspectRatio,contentMode:.fit).background(surface).clipShape(RoundedRectangle(cornerRadius:10))
            if hero.portrait == nil { Text("Add a character image in Edit → Portrait to create a banner.").font(.caption).foregroundStyle(.secondary) }
            HStack { Text("Left / right").frame(width:90,alignment:.leading); Slider(value:$crop.x,in:0...1) }
            HStack { Text("Top / bottom").frame(width:90,alignment:.leading); Slider(value:$crop.y,in:0...1) }
            HStack { Text("Zoom").frame(width:90,alignment:.leading); Slider(value:$crop.zoom,in:1...3) }
            Text("Framing is saved separately. Your full image remains available.").font(.caption).foregroundStyle(.secondary)
            HStack { Button("Reset framing") { crop = BannerCrop() }; Spacer(); Button("Cancel") { dismiss() }; Button("Apply banner") { hero.bannerCrop = crop; dismiss() }.buttonStyle(.borderedProminent) }
        }.padding(24).frame(width:700).tint(accent)
    }
}

struct CreatureBanner:View {
    @Binding var creature:Creature
    var edit:()->Void
    var remove:()->Void
    @State private var framing = false
    var body:some View {
        ZStack(alignment:.bottomLeading) {
            Rectangle().fill(sky.opacity(0.08).gradient)
            CroppedImage(data:creature.image,crop:creature.bannerCrop ?? BannerCrop())
            LinearGradient(colors:[paper.opacity(0.8),paper.opacity(0.12)],startPoint:.leading,endPoint:.trailing)
            LinearGradient(colors:[.clear,.black.opacity(0.65)],startPoint:.top,endPoint:.bottom)
            HStack(alignment:.bottom) {
                VStack(alignment:.leading,spacing:7) {
                    Text(creature.name).font(.system(size:24,weight:.semibold)).foregroundStyle(.white)
                    Text(creature.type.isEmpty ? "Custom creature":creature.type).font(.caption).foregroundStyle(.white.opacity(0.8))
                    HStack(spacing:14) { Label("AC \(creature.ac)",systemImage:"shield"); Label("\(creature.speed) ft",systemImage:"figure.walk") }.font(.system(size:11)).foregroundStyle(sky)
                }; Spacer()
                Button { framing = true } label: { Image(systemName:"crop") }.help("Frame creature banner")
                Button("Edit",action:edit)
                Menu { CreatureLayoutPicker(creature:$creature);Button("Remove creature",role:.destructive,action:remove) } label: { Image(systemName:"ellipsis") }.menuStyle(.borderlessButton).frame(width:20)
            }.padding(18)
        }.frame(height:250).contentShape(Rectangle()).clipShape(RoundedRectangle(cornerRadius:10))
        .sheet(isPresented:$framing) { CreatureBannerEditor(creature:$creature) }
    }
}
struct CreatureBannerEditor:View {
    @Binding var creature:Creature
    @State private var crop:BannerCrop
    @Environment(\.dismiss) private var dismiss
    init(creature:Binding<Creature>) { _creature = creature; _crop = State(initialValue:creature.wrappedValue.bannerCrop ?? BannerCrop()) }
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            Text("\(creature.name) · image framing").font(.headline)
            CroppedImage(data:creature.image,crop:crop).frame(width:creature.imageLayout == nil || creature.imageLayout == .banner ? 612:150,height:creature.imageLayout == nil || creature.imageLayout == .banner ? 250:250).background(surface).clipShape(RoundedRectangle(cornerRadius:10))
            if creature.image == nil { Text("Add an image in the creature editor.").font(.caption).foregroundStyle(.secondary) }
            HStack { Text("Left / right").frame(width:90,alignment:.leading); Slider(value:$crop.x,in:0...1) }
            HStack { Text("Top / bottom").frame(width:90,alignment:.leading); Slider(value:$crop.y,in:0...1) }
            HStack { Text("Zoom").frame(width:90,alignment:.leading); Slider(value:$crop.zoom,in:1...3) }
            HStack { Button("Reset") { crop = BannerCrop() }; Spacer(); Button("Cancel") { dismiss() }; Button("Apply banner") { creature.bannerCrop = crop; dismiss() }.buttonStyle(.borderedProminent) }
        }.padding(24).frame(width:660)
    }
}

struct CreatureLayoutPicker:View {
    @Binding var creature:Creature
    var body:some View { Picker("Image layout",selection:Binding(get:{ creature.imageLayout ?? .banner },set:{ creature.imageLayout=$0 })) { ForEach(CreatureImageLayout.allCases,id:\.self) { Text($0.rawValue).tag($0) } } }
}
struct CreatureCompactHeader:View {
    @Binding var creature:Creature
    var edit:()->Void
    var remove:()->Void
    @State private var framing=false
    var body:some View {
        HStack(alignment:.top) { VStack(alignment:.leading,spacing:7) { Text(creature.name).font(.title2.bold());Text(creature.type).font(.caption).foregroundStyle(.secondary);HStack { Label("AC \(creature.ac)",systemImage:"shield");Label("\(creature.speed) ft",systemImage:"figure.walk") }.font(.caption).foregroundStyle(sky) };Spacer();Button { framing=true } label: { Image(systemName:"crop") };Button("Edit",action:edit);Menu { CreatureLayoutPicker(creature:$creature);Button("Remove creature",role:.destructive,action:remove) } label: { Image(systemName:"ellipsis") }.menuStyle(.borderlessButton).frame(width:20) }.sheet(isPresented:$framing) { CreatureBannerEditor(creature:$creature) }
    }
}
