import SwiftUI

struct CurrencyButton:View {
    @Binding var hero:Hero
    @State private var open=false
    var body:some View {
        Button { open=true } label: { Label(hero.currencyBalances[0].formatted+" gp",systemImage:"banknote").font(.caption) }.help("Manage coins and custom currencies").popover(isPresented:$open) { CurrencyPopup(hero:$hero) }
    }
}
struct CurrencyPopup:View {
    @Binding var hero:Hero
    @State private var selected="gp"
    @State private var amount=""
    @State private var operation=CurrencyOperation.add
    @State private var customName=""
    @State private var error:String?
    @Environment(\.dismiss) private var dismiss
    var currency:CurrencyBalance { hero.currencyBalances.first { $0.id == selected } ?? hero.currencyBalances[0] }
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            HStack { Text("Currency").font(.headline);Spacer();Button("Done") { dismiss() } }
            Picker("Currency",selection:$selected) { ForEach(hero.currencyBalances) { Text($0.name+" · "+$0.formatted).tag($0.id) } }
            Text(currency.formatted+" "+currency.name).font(.system(size:26,weight:.semibold,design:.rounded)).foregroundStyle(gold).frame(maxWidth:.infinity)
            Picker("Change",selection:$operation) { ForEach(CurrencyOperation.allCases,id:\.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
            TextField("Amount · e.g. 12.50",text:$amount).textFieldStyle(.roundedBorder).onSubmit(apply)
            HStack { Text("Two decimal places · no automatic conversion").font(.caption2).foregroundStyle(.secondary);Spacer();Button("Apply",action:apply).buttonStyle(.borderedProminent).disabled(CurrencyBalance.parse(amount) == nil) }
            if let error { Text(error).font(.caption).foregroundStyle(coral) }
            Divider()
            DisclosureGroup("Add custom currency") { HStack { TextField("Currency name",text:$customName);Button("Add") { do { selected=try hero.addCurrency(named:customName);customName="";error=nil } catch { self.error=error.localizedDescription } }.disabled(customName.trimmingCharacters(in:.whitespaces).isEmpty) }.padding(.top,7) }.font(.caption)
        }.padding(18).frame(width:370).background(surface).foregroundStyle(ink).tint(gold)
    }
    func apply() { guard let value=CurrencyBalance.parse(amount) else { return };do { try hero.changeCurrency(selected,amount:value,operation:operation);amount="";error=nil } catch { self.error=error.localizedDescription } }
}
