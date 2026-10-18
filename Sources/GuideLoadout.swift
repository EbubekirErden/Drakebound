import SwiftUI

extension CharacterGuide {
    var loadoutStep:some View {
        VStack(alignment:.leading,spacing:12) {
            Picker("Loadout section",selection:$loadoutPage) { Text("Spells").tag("Spells");Text("Equipment").tag("Equipment");Text("Attacks").tag("Attacks") }.pickerStyle(.segmented).labelsHidden().frame(maxWidth:.infinity).frame(height:PageControl.height).id("loadoutTop")
            switch loadoutPage { case "Equipment":guideInventory;case "Attacks":guideAttacks;default:guideSpellbook }
            GuideSection("Feature reference",summary:"\(draft.result.featureEntries?.count ?? 0) total") {
                ForEach(Array((draft.result.featureEntries ?? []).enumerated()),id:\.element.id) { index,feature in
                    Button { openFeatureChoice(feature) } label: { HStack { Text(feature.name);Spacer();Image(systemName:CharacterBuildDraft.isAbilityImprovement(feature) ? "slider.horizontal.3":"eye") }.font(.system(size:12)).modifier(GuideTableRow(index:index)) }.buttonStyle(.plain)
                }
            }
        }.popover(isPresented:$equipmentOpen) { CasterTableView(draft:draft,catalog:catalog,level:$casterLevel) { slots in draft.hero.slots=slots;equipmentOpen=false } }
    }
    var guideSlots:some View {
        GuideSection("Casting & slots",summary:"\(draft.hero.slots.reduce(0,+)) slots · \(abilities[draft.hero.castingAbility])") {
            HStack(spacing:10) {
                PagePicker(title:"Default casting ability",selectionTitle:abilities[draft.hero.castingAbility],selection:$draft.hero.castingAbility) { ForEach(0..<6,id:\.self) { Text(abilities[$0]).tag($0) } }.frame(width:165)
                Spacer(minLength:0)
                Button("Caster table…") { updateCasterLevel();equipmentOpen=true }.buttonStyle(PageButtonStyle())
            }
            if let entry=classReference,draft.resultingClasses.count == 1,GuideRules.importedSlots(entry,at:draft.classLevel) != nil {
                Button("Use imported class table") { draft.hero.slots=GuideRules.importedSlots(entry,at:draft.classLevel)!;draft.hero.slotsRecoverOnShortRest=entry.value("slotsReset") == "S" }.buttonStyle(PageButtonStyle())
            }
            LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:1),count:3),spacing:1) { ForEach(0..<9,id:\.self) { i in
                VStack(alignment:.leading,spacing:4) { Stepper("L\(i+1) · \(draft.hero.slots[i])",value:$draft.hero.slots[i],in:0...20).font(.system(size:12));Text("\(draft.hero.usedSlots[i]) spent").font(.system(size:10)).foregroundStyle(.secondary) }.modifier(GuideTableRow(index:i/3))
            } }
            Toggle("Recover these slots on a short rest",isOn:Binding(get:{ draft.hero.slotsRecoverOnShortRest ?? false },set:{ draft.hero.slotsRecoverOnShortRest=$0 })).font(.system(size:12))
            Text("Check your chosen class and subclass before applying a slot table. Already-spent uses stay preserved.").font(.system(size:11)).foregroundStyle(.secondary)
            if draft.resultingClasses.contains(where:{ $0.casting == .pact }) && draft.resultingClasses.count > 1 { Text("Mixed Pact Magic needs a separate manual counter for pact slots. This grid has one recovery policy; keep pact uses separate from ordinary Spellcasting.").font(.system(size:11)).foregroundStyle(gold) }
        }
    }
    var guideSpellbook:some View {
        VStack(alignment:.leading,spacing:12) {
            PageToolbar(title:"Spellbook",subtitle:"\(draft.hero.spells.count) spells · \(draft.hero.spells.filter(\.prepared).count) prepared",color:sky,searchTitle:"Search draft spells…",query:$loadoutSpellQuery) {
                Button { spellBrowser=true } label: { Label("Browse spells",systemImage:"plus") }.buttonStyle(PageButtonStyle(color:sky,prominent:true))
                GuideActionMenu(title:"Spellbook options") {
                    Button("Custom spell…") { createGuideSpell() }
                    Divider()
                    Button("Prepare all") { for i in draft.hero.spells.indices { draft.hero.spells[i].prepared=true } }
                    Button("Unprepare all level 1+") { for i in draft.hero.spells.indices where draft.hero.spells[i].level > 0 { draft.hero.spells[i].prepared=false } }
                }
            }
            HStack(spacing:10) {
                PagePicker(title:"Spell level",selectionTitle:loadoutSpellLevel < 0 ? "All levels":loadoutSpellLevel == 0 ? "Cantrips":"Level \(loadoutSpellLevel)",selection:$loadoutSpellLevel) { Text("All levels").tag(-1);Text("Cantrips").tag(0);ForEach(1...9,id:\.self) { Text("Level \($0)").tag($0) } }.frame(width:130)
                Button("Custom spell") { createGuideSpell() }.buttonStyle(PageButtonStyle())
                Spacer(minLength:0)
                if !loadoutSpellQuery.isEmpty || loadoutSpellLevel != -1 { Button("Clear") { loadoutSpellQuery="";loadoutSpellLevel = -1 }.buttonStyle(.plain).font(.system(size:11)).foregroundStyle(accent) }
            }
            guideSlots
            GuideTable {
                if guideSpells.isEmpty { Text(draft.hero.spells.isEmpty ? "Browse spells or create a custom spell to begin.":"No spells match these filters.").font(.system(size:12)).foregroundStyle(.secondary).padding(20).frame(maxWidth:.infinity,alignment:.leading) }
                ForEach(Array(guideSpells.enumerated()),id:\.element.id) { index,spell in
                    GuideExpandableRow(title:spell.name,subtitle:(spell.level == 0 ? "Cantrip":"Level \(spell.level)")+" · "+spell.school+(spell.sourceClassName.map { " · "+$0 } ?? ""),index:index) {
                        Toggle("Prepare \(spell.name)",isOn:Binding(get:{ draft.hero.spells.first { $0.id == spell.id }?.prepared ?? false },set:{ value in if let i=draft.hero.spells.firstIndex(where:{ $0.id == spell.id }) { draft.hero.spells[i].prepared=value } })).labelsHidden().toggleStyle(.checkbox).help("Prepare "+spell.name)
                        Button { spellEditor=spell } label: { Image(systemName:"pencil") }.help("Edit "+spell.name).accessibilityLabel("Edit "+spell.name)
                        Button { draft.hero.spells.removeAll { $0.id == spell.id } } label: { Image(systemName:"minus.circle") }.help("Remove spell from draft").accessibilityLabel("Remove "+spell.name)
                    } content: {
                        Text(spell.time+" · "+spell.range+" · "+spell.duration).font(.system(size:11)).foregroundStyle(sky)
                        DescriptionText(text:spell.text.isEmpty ? "No description yet.":spell.text)
                    }
                }
            }
        }
    }
    var guideSpells:[Spell] { draft.hero.spells.filter { spell in (loadoutSpellLevel < 0 || spell.level == loadoutSpellLevel) && CompendiumSearch.matches(name:spell.name,summary:spell.school,classes:spell.classes ?? "",source:spell.sourceClassName ?? "",query:loadoutSpellQuery) } }
    func createGuideSpell() { var spell=Spell(name:"",level:0);spell.sourceClassID=draft.selectedClassID;spell.sourceClassName=draft.chosenClass.name;spell.castingAbility=classCastingAbility;spellEditor=spell }
    var guideInventory:some View {
        VStack(alignment:.leading,spacing:12) {
            PageToolbar(title:"Equipment",subtitle:"\(draft.hero.items.count) items",searchTitle:"Search draft equipment…",query:$loadoutEquipmentQuery) {
                Button("Custom item") { itemEditor=Item(name:"") }.buttonStyle(PageButtonStyle(prominent:true))
                CurrencyButton(hero:$draft.hero).buttonStyle(PageButtonStyle())
            }
            GuideReferencePicker(title:"Equipment",options:catalog.items,selection:$equipmentChoice,onPreview:{ referencePreview=$0 })
            if !draft.isLevelUp { starterEquipmentChoices }
            GuideTable {
                if guideItems.isEmpty { Text(draft.hero.items.isEmpty ? "Choose starting equipment, browse the compendium, or create a custom item.":"No equipment matches your search.").font(.system(size:12)).foregroundStyle(.secondary).padding(20).frame(maxWidth:.infinity,alignment:.leading) }
                ForEach(Array(guideItems.enumerated()),id:\.element.id) { index,item in
                    GuideExpandableRow(title:item.name,subtitle:"\(item.equipmentKind.rawValue) · ×\(item.quantity)",index:index) {
                        Toggle("Equip \(item.name)",isOn:Binding(get:{ draft.hero.items.first { $0.id == item.id }?.equipped ?? false },set:{ value in draft.hero.setItemEquipped(item.id,value,compendium:store.compendium) })).labelsHidden().toggleStyle(.checkbox).help("Equip "+item.name)
                        if [.melee,.ranged,.staff].contains(item.equipmentKind) { Button { attackEditor=suggestedAttack(item) } label: { Image(systemName:"scope") }.help("Configure an attack for this weapon").accessibilityLabel("Configure attack for "+item.name) }
                        Button { itemEditor=item } label: { Image(systemName:"pencil") }.help("Edit "+item.name).accessibilityLabel("Edit "+item.name)
                        Button { draft.hero.items.removeAll { $0.id == item.id } } label: { Image(systemName:"minus.circle") }.help("Remove item from draft").accessibilityLabel("Remove "+item.name)
                    } content: { DescriptionText(text:item.notes.isEmpty ? "No description yet. Edit this item to configure armor, properties, and effects.":item.notes) }
                }
            }
            Text("Equipping items updates the character preview. Edit an item for armor, attunement, and effects.").font(.system(size:11)).foregroundStyle(.secondary)
        }
    }
    var guideItems:[Item] { draft.hero.items.filter { CompendiumSearch.matches(name:$0.name,summary:$0.equipmentKind.rawValue,classes:"",source:$0.sourceType ?? "",query:loadoutEquipmentQuery) } }
    var guideAttacks:some View {
        VStack(alignment:.leading,spacing:12) {
            PageToolbar(title:"Attacks",subtitle:"\(draft.hero.attacks.count) configured",searchTitle:"Search draft attacks…",query:$loadoutAttackQuery) {
                Button("Custom attack") { attackEditor=Attack(name:"") }.buttonStyle(PageButtonStyle(prominent:true))
            }
            GuideTable {
                if guideAttackRows.isEmpty { Text(draft.hero.attacks.isEmpty ? "Equipped weapons can create linked attacks. Configure an equipment attack or add a custom attack.":"No attacks match your search.").font(.system(size:12)).foregroundStyle(.secondary).padding(20).frame(maxWidth:.infinity,alignment:.leading) }
                ForEach(Array(guideAttackRows.enumerated()),id:\.element.id) { index,attack in
                    GuideExpandableRow(title:attack.name,subtitle:attack.damage,index:index) {
                        Button { attackEditor=attack } label: { Image(systemName:"pencil") }.help("Edit "+attack.name).accessibilityLabel("Edit "+attack.name)
                        Button { draft.hero.removeWeaponAttack(attack.id) } label: { Image(systemName:"minus.circle") }.help("Remove "+attack.name).accessibilityLabel("Remove "+attack.name)
                    } content: { DescriptionText(text:(attack.description ?? "").isEmpty ? "No description yet.":(attack.description ?? "")) }
                }
            }
        }
    }
    var guideAttackRows:[Attack] { draft.hero.attacks.filter { CompendiumSearch.matches(name:$0.name,summary:$0.damage,classes:"",source:"",query:loadoutAttackQuery) } }
}
