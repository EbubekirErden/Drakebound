import SwiftUI

struct EquipmentTrainingPopover:View {
    @Binding var hero:Hero
    var done:()->Void
    @State private var contentHeight:CGFloat = 200
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            HStack { Text("Weapon & armor proficiency").font(.headline);Spacer();Button("Done",action:done).buttonStyle(PageButtonStyle()) }
            ScrollView {
                VStack(alignment:.leading,spacing:12) {
                    EquipmentTrainingRoster(hero:hero)
                    EquipmentTrainingEditor(grants:$hero.trainingGrants,source:"Manual character training",expanded:true)
                }.frame(maxWidth:.infinity,alignment:.leading).padding(1)
                    .background(GeometryReader { proxy in Color.clear.preference(key:TrainingPopoverHeight.self,value:proxy.size.height) })
            }.frame(height:min(360,max(1,contentHeight)))
        }.padding(20).frame(width:460).background(surface).foregroundStyle(ink).tint(accent)
            .onPreferenceChange(TrainingPopoverHeight.self) { height in if abs(height-contentHeight)>1 { contentHeight=height.rounded(.up) } }
    }
}
private struct TrainingPopoverHeight:PreferenceKey {
    static var defaultValue:CGFloat = 0
    static func reduce(value:inout CGFloat,nextValue:()->CGFloat) { value=max(value,nextValue()) }
}
