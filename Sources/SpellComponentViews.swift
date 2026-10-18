import SwiftUI

struct SpellComponentButtons: View {
    @Binding var value: String
    @State private var remembered: [String:String] = [:]
    var body: some View {
        HStack(spacing:2) {
            ForEach(["V","S","M"],id: \.self) { component in
                Toggle(component,isOn:Binding(get:{ SpellComponents(value).contains(component) },set:{ enabled in
                    let parsed = SpellComponents(value)
                    if let segment = parsed.segment(component) { remembered[component] = segment }
                    value = parsed.setting(component,enabled:enabled,restored:remembered[component])
                }))
                .toggleStyle(SpellComponentToggleStyle())
                .accessibilityLabel(component == "V" ? "Verbal component":component == "S" ? "Somatic component":"Material component")
                .help(component == "V" ? "Verbal":component == "S" ? "Somatic":SpellComponents(value).segment("M") ?? "Material")
            }
        }.padding(3)
            .background(ink.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius:8))
            .overlay(RoundedRectangle(cornerRadius:8).stroke(ink.opacity(0.12)))
            .fixedSize()
    }
}

private struct SpellComponentToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing:5) {
                Image(systemName:configuration.isOn ? "checkmark.circle.fill":"circle")
                    .font(.system(size:11,weight:.semibold))
                configuration.label.font(.system(size:12,weight:.semibold))
            }.frame(width:58,height:30)
                .foregroundStyle(configuration.isOn ? paper:ink.opacity(0.55))
                .background(configuration.isOn ? sky:Color.clear)
                .clipShape(RoundedRectangle(cornerRadius:5))
                .contentShape(RoundedRectangle(cornerRadius:5))
        }.buttonStyle(.plain)
            .accessibilityValue(configuration.isOn ? "On":"Off")
            .accessibilityAddTraits(configuration.isOn ? .isSelected:[])
    }
}

struct SpellMaterialField: View {
    @Binding var components: String
    var body: some View {
        if SpellComponents(components).contains("M") {
            VStack(alignment:.leading,spacing:5) {
                Text("Material requirements").font(.system(size:10)).foregroundStyle(.secondary)
                TextField("Material, cost, and whether it is consumed · optional",text:Binding(get:{ SpellComponents(components).material },set:{ components = SpellComponents(components).settingMaterial($0) }))
                    .accessibilityLabel("Material requirements")
            }.frame(maxWidth:.infinity,alignment:.leading)
        }
    }
}
