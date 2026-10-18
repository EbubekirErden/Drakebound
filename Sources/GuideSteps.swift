import SwiftUI

extension CharacterGuide {
    var featuresStep:some View {
        VStack(spacing:14) {
            EditorGroup(title:"Available choices") {
                if let entry = classReference,entry.fields.contains(where:{ $0.name == "autolevel" && Int($0.attributes["level"] ?? "0") == draft.classLevel && $0.attributes["scoreImprovement"]?.uppercased() == "YES" }) { Label("Ability improvement milestone · choose the increase in Abilities, or add the feat you select below.",systemImage:"sparkles").font(.caption).foregroundStyle(gold) }
                HStack { ForEach(["Class","Ancestry","Background"],id:\.self) { group in Button(group) { featureGroup = group }.buttonStyle(.plain).font(.system(size:11,weight:.medium)).padding(.horizontal,10).padding(.vertical,7).background((featureGroup == group ? accent:ink).opacity(featureGroup == group ? 0.15:0.03)).clipShape(RoundedRectangle(cornerRadius:6)) }; Spacer() }
                TextField("Search features or subclass name",text:$featureSearch)
                Text("Ancestry and background traits are granted automatically. Core class features start selected; optional choices and the chosen subclass stay separate.").font(.caption2).foregroundStyle(.secondary)
                if candidates.isEmpty { Text("No matching choices. Choose a reference in Class & origin, or add a custom feature below.").font(.caption).foregroundStyle(.secondary).padding(.vertical,8) }
                LazyVStack(spacing:6) { ForEach(candidates) { feature in
                    let selected = draft.selectedFeatures.contains { $0.id == feature.id }
                    let required = draft.requiredOriginIDs.contains(feature.id)
                    let known = (draft.original?.featureEntries ?? []).contains { $0.name == feature.name && $0.text == feature.text }
                    HStack(spacing:9) {
                        Button { if selected { draft.selectedFeatures.removeAll { $0.id == feature.id } } else { draft.selectedFeatures.append(feature); if CharacterBuildDraft.isAbilityImprovement(feature) { improvementFeature=feature } } } label: { Image(systemName:selected || known ? "checkmark.square.fill":"square").foregroundStyle(selected ? accent:Color.secondary) }.buttonStyle(.plain).disabled(known || required).help(known ? "Already on character":"Select feature").accessibilityLabel("Select \(feature.name)")
                        Button { openFeatureChoice(feature) } label: { VStack(alignment:.leading,spacing:4) { Text(feature.name).font(.system(size:12,weight:.medium)); Text(known ? "Already on character":feature.source ?? "").font(.system(size:10)).foregroundStyle(.secondary) }.frame(maxWidth:.infinity,alignment:.leading) }.buttonStyle(.plain)
                        Button { featurePreview = feature } label: { Image(systemName:"eye") }.help("Preview feature")
                    }.padding(9).background(surface).clipShape(RoundedRectangle(cornerRadius:6))
                } }
            }
            EditorGroup(title:"Selected features & feats · \(draft.selectedFeatures.count)") {
                if !draft.isLevelUp || draft.featChoiceAvailable { GuideReferencePicker(title:"Feats",options:eligibleFeats,selection:$featChoice,onPreview:{ referencePreview = $0 }) }
                ForEach(FeatureCategory.allCases,id:\.self) { category in
                    let entries=draft.selectedFeatures.filter { ($0.category ?? .other) == category }
                    if !entries.isEmpty { DisclosureGroup("\(category.rawValue) · \(entries.count)") {
                ForEach(SelectionRules.outline(entries)) { row in
                    let feature=row.feature
                     HStack { Button { if CharacterBuildDraft.isAbilityImprovement(feature) { improvementFeature=feature } else { featureEditor=feature } } label: { VStack(alignment:.leading,spacing:3) { Text(feature.name).font(.system(size:12)); Text(CharacterBuildDraft.isAbilityImprovement(feature) ? draft.improvementSummary(feature):feature.counter?.resetSummary ?? feature.source ?? "").font(.system(size:10)).foregroundStyle(.secondary) }.frame(maxWidth:.infinity,alignment:.leading) }.buttonStyle(.plain); Button { if CharacterBuildDraft.isAbilityImprovement(feature) { improvementFeature=feature } else { featureEditor=feature } } label: { Group { if CharacterBuildDraft.isAbilityImprovement(feature) { Text(draft.abilityImprovements[feature.id] == nil ? "Choose…":"Edit choice").font(.caption) } else { Image(systemName:"pencil") } } }.help(CharacterBuildDraft.isAbilityImprovement(feature) ? "Choose ability increases or a feat":"Edit description, rolls, uses & recovery"); if !draft.requiredOriginIDs.contains(feature.id) { Button { draft.selectedFeatures.removeAll { $0.id == feature.id } } label: { Image(systemName:"minus.circle") }.help("Remove selection") } }.padding(.leading,CGFloat(row.depth)*14) }
                    }.font(.caption) }
                }
                Button("Custom feature") { featureEditor = CharacterFeature(name:"",category:.classFeature,source:"\(draft.chosenClass.name) · Level \(draft.classLevel)") }
            }
            EditorGroup(title:"Effects & resources") {
                Text("Configure numeric bonuses and usage limits explicitly. Each counter has independent rest reset choices.").font(.caption2).foregroundStyle(.secondary)
                ForEach(draft.hero.bonuses ?? []) { bonus in Button { bonusEditor = bonus } label: { HStack { Text(bonus.name); Spacer(); Text(bonusSummary(bonus,hero:draft.result)).foregroundStyle(gold); Image(systemName:"pencil") }.font(.caption) }.buttonStyle(.plain) }
                ForEach(draft.hero.counters ?? []) { counter in Button { counterEditor = counter } label: { HStack { Text(counter.name); Spacer(); Text("\(counter.current)/\(counter.maximum) · \(counter.resetSummary)").foregroundStyle(gold); Image(systemName:"pencil") }.font(.caption) }.buttonStyle(.plain) }
                HStack { Button("Add bonus") { bonusEditor = Bonus() }; Button("Add counter") { counterEditor = ResourceCounter() } }
            }
        }
    }
    var candidates:[CharacterFeature] {
        if featureGroup == "Class",let entry = classReference {
            return GuideRules.classChoices(entry,from:draft.isLevelUp ? draft.classLevel:1,through:draft.classLevel).filter { $0.subclass == nil || GuideRules.belongs($0,to:draft.chosenClass.subclass) }.map(\.feature).filter { featureSearch.isEmpty || $0.name.localizedCaseInsensitiveContains(featureSearch) }
        }
        let entry = featureGroup == "Ancestry" ? draft.ancestryTemplate:draft.backgroundTemplate
        return entry.map(GuideRules.originFeatures)?.filter { featureSearch.isEmpty || $0.name.localizedCaseInsensitiveContains(featureSearch) } ?? []
    }
    var eligibleFeats:[CompendiumEntry] { catalog.feats.filter { GuideRules.featMinimumLevel($0) <= draft.newLevel } }
    var loadoutStep:some View {
        VStack(spacing:14) {
            DisclosureGroup("Features & choices · \(draft.result.featureEntries?.count ?? 0)") { ForEach(draft.result.featureEntries ?? []) { feature in Button { openFeatureChoice(feature) } label: { HStack { Text(feature.name); Spacer(); Image(systemName:CharacterBuildDraft.isAbilityImprovement(feature) ? "slider.horizontal.3":"eye") }.font(.caption).padding(.vertical,4) }.buttonStyle(.plain) } }
            EditorGroup(title:"Spellcasting & slots") {
                Picker("Default casting ability",selection:$draft.hero.castingAbility) { ForEach(0..<6,id:\.self) { Text(abilities[$0]).tag($0) } }
                HStack { if let entry = classReference, draft.resultingClasses.count == 1, GuideRules.importedSlots(entry,at:draft.classLevel) != nil { Button("Use imported class table") { draft.hero.slots = GuideRules.importedSlots(entry,at:draft.classLevel)!; draft.hero.slotsRecoverOnShortRest = entry.value("slotsReset") == "S" } }; Spacer(); Button("Caster table…") { updateCasterLevel(); equipmentOpen = true } }
                Text("Class tables may include optional subclass spellcasting. Check your chosen class and subclass before applying. Slot totals preserve already-spent uses.").font(.caption2).foregroundStyle(.secondary)
                LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:14),count:3),spacing:10) { ForEach(0..<9,id:\.self) { i in VStack(alignment:.leading,spacing:4) { Stepper("L\(i+1) · \(draft.hero.slots[i])",value:$draft.hero.slots[i],in:0...20).font(.system(size:12)); if draft.hero.usedSlots[i] > 0 { Text("\(draft.hero.usedSlots[i]) spent").font(.system(size:9)).foregroundStyle(.secondary) } } } }
                Toggle("Recover these slots on a short rest",isOn:Binding(get:{ draft.hero.slotsRecoverOnShortRest ?? false },set:{ draft.hero.slotsRecoverOnShortRest = $0 })).font(.caption)
                if draft.resultingClasses.contains(where:{ $0.casting == .pact }) && draft.resultingClasses.count > 1 { Text("Mixed Pact Magic needs a separate manual counter for pact slots. This slot grid has one recovery policy for all its slots; use it for ordinary Spellcasting and keep pact uses separate.").font(.caption).foregroundStyle(gold) }
            }
            EditorGroup(title:"Spellbook · \(draft.hero.spells.count)") {
                HStack { Button("Browse spells") { spellBrowser = true }; Button("Custom spell") { var spell = Spell(name:"",level:0); spell.sourceClassID = draft.selectedClassID; spell.sourceClassName = draft.chosenClass.name; spell.castingAbility = classCastingAbility; spellEditor = spell }; Spacer(); Menu("Preparation") { Button("Prepare all") { for i in draft.hero.spells.indices { draft.hero.spells[i].prepared=true } }; Button("Unprepare all level 1+") { for i in draft.hero.spells.indices where draft.hero.spells[i].level > 0 { draft.hero.spells[i].prepared=false } } }.help("Changes all spells in this draft; review your class allowance.") }
                ForEach(draft.hero.spells) { spell in HStack(spacing:9) { Toggle("Prepare \(spell.name)",isOn:Binding(get:{ draft.hero.spells.first { $0.id == spell.id }?.prepared ?? false },set:{ value in if let i = draft.hero.spells.firstIndex(where:{ $0.id == spell.id }) { draft.hero.spells[i].prepared = value } })).labelsHidden().toggleStyle(.checkbox); Button { spellEditor = spell } label: { Text(spell.name).font(.system(size:12)).frame(maxWidth:.infinity,alignment:.leading) }.buttonStyle(.plain); Text(spell.level == 0 ? "Cantrip":"L\(spell.level)").font(.caption2).foregroundStyle(sky); Button { draft.hero.spells.removeAll { $0.id == spell.id } } label: { Image(systemName:"minus.circle") }.help("Remove spell from draft") } }
            }
            if !draft.isLevelUp { starterEquipmentChoices }
            EditorGroup(title:"Equipment · \(draft.hero.items.count)") {
                GuideReferencePicker(title:"Equipment",options:catalog.items,selection:$equipmentChoice,onPreview:{ referencePreview = $0 })
                HStack { Button("Custom item") { itemEditor = Item(name:"") }; Spacer(); CurrencyButton(hero:$draft.hero) }
                Text("Select your class and background’s equipment or starting wealth. Edit items to configure armor and effects; equipping them updates the preview.").font(.caption2).foregroundStyle(.secondary)
                ForEach(draft.hero.items) { item in HStack(spacing:9) {
                    Toggle("Equip \(item.name)",isOn:Binding(get:{ draft.hero.items.first { $0.id == item.id }?.equipped ?? false },set:{ value in draft.hero.setItemEquipped(item.id,value,compendium:store.compendium) })).labelsHidden().toggleStyle(.checkbox)
                    Button { itemEditor = item } label: { VStack(alignment:.leading,spacing:3) { Text(item.name).font(.system(size:12)); Text("\(item.equipmentKind.rawValue) · ×\(item.quantity)").font(.system(size:10)).foregroundStyle(.secondary) }.frame(maxWidth:.infinity,alignment:.leading) }.buttonStyle(.plain)
                    if [.melee,.ranged,.staff].contains(item.equipmentKind) { Button { attackEditor = suggestedAttack(item) } label: { Image(systemName:"scope") }.help("Configure an attack for this weapon") }
                    Button { itemEditor = item } label: { Image(systemName:"pencil") }.help("Edit equipment")
                    Button { draft.hero.items.removeAll { $0.id == item.id } } label: { Image(systemName:"minus.circle") }.help("Remove item from draft")
                } }
                DisclosureGroup("Attacks · \(draft.hero.attacks.count)") { ForEach(draft.hero.attacks) { attack in HStack { Button(attack.name) { attackEditor = attack }; Spacer(); Text(attack.damage).font(.caption).foregroundStyle(coral); Button { draft.hero.removeWeaponAttack(attack.id) } label: { Image(systemName:"minus.circle") } } }; Button("Custom attack") { attackEditor = Attack(name:"") } }
            }
        }.popover(isPresented:$equipmentOpen) { CasterTableView(draft:draft,catalog:catalog,level:$casterLevel) { slots in draft.hero.slots = slots; equipmentOpen = false } }

    }
    var reviewStep:some View {
        VStack(spacing:14) {
            EditorGroup(title:"Ready for review") {
                HStack { Portrait(data:draft.hero.portrait,name:draft.hero.name,size:46); VStack(alignment:.leading,spacing:5) { Text(draft.result.name).font(.system(size:20,weight:.semibold)); Text(draft.result.characterClass).font(.caption).foregroundStyle(sky) }; Spacer(); Button("Preview sheet") { fullPreview = true } }
                if draft.problems.isEmpty { Label("Required fields are ready",systemImage:"checkmark.circle.fill").font(.caption).foregroundStyle(leaf) }
                else { ForEach(draft.problems,id:\.self) { Text($0).font(.caption).foregroundStyle(gold) } }
                if !draft.isLevelUp && draft.hero.items.isEmpty { Text("No starting equipment selected. You can add it now or from Equipment later.").font(.caption).foregroundStyle(gold) }
                if draft.selectedFeatures.isEmpty { Text("No new reference features selected. Review Features for your class, ancestry, and background.").font(.caption).foregroundStyle(gold) }
                Text("Confirm choice limits and prerequisites from your class and origin previews. The guide applies the explicit scores, proficiencies, effects, and resources you selected; it does not interpret rules from descriptions.").font(.caption2).foregroundStyle(.secondary)
            }
            EditorGroup(title:draft.isLevelUp ? "Before → after":"Character summary") {
                ForEach(Array(draft.changeSummary.enumerated()),id:\.offset) { _,line in Text(line).font(.system(size:12)).frame(maxWidth:.infinity,alignment:.leading) }
                if draft.isLevelUp { Text("Current HP: \(draft.original!.hp) → \(draft.result.hp). Spent slots and hit dice remain spent. A pre-level-up backup and a Journal entry are saved when you apply.").font(.caption).foregroundStyle(.secondary) }
            }
            EditorGroup(title:"Your choices") { Text("\(skills.filter { draft.result.effectiveSkillRank($0.0) > 0 }.count) trained skills · \((0..<6).filter { draft.result.isSaveProficient($0) }.count) proficient saves").font(.caption); Text("\(draft.selectedFeatures.count) new features · \((draft.hero.bonuses ?? []).count) explicit bonuses · \((draft.hero.counters ?? []).count) counters").font(.caption); Text("\(draft.hero.spells.count) spells · \(draft.hero.spells.filter(\.prepared).count) prepared · \(draft.hero.items.count) items").font(.caption) }
        }
    }
    var classReferenceOptions:[CompendiumEntry] {
        guard draft.isLevelUp,let prior = draft.existingClasses.first(where:{ $0.id == draft.selectedClassID }) else { return catalog.classes }
        let base = ClassProfile.named(prior.name)?.name ?? prior.name
        return catalog.classes.filter { (ClassProfile.named($0.name)?.name ?? $0.name).caseInsensitiveCompare(base) == .orderedSame }
    }
    var classCastingAbility:Int {
        if let entry = classReference,let i = abilities.firstIndex(where:{ $0.caseInsensitiveCompare(entry.value("spellAbility")) == .orderedSame }) { return i }
        return ClassProfile.named(draft.chosenClass.name)?.casting ?? draft.hero.castingAbility
    }
    func linkClassReference() {
        let name = draft.chosenClass.name
        let match = catalog.classes.first { $0.name == name+(draft.hero.edition == "2024" ? " [2024]":"") } ?? catalog.classReference(name,edition:draft.hero.edition)
        draft.chosenClass.referenceID = match?.id
    }
    func selectExisting(_ record:CharacterClassLevel) {
        draft.classTemplate = nil
        draft.selectedClassID = record.id; draft.chosenClass = record; draft.selectedFeatures.removeAll { $0.category == .classFeature }
        if record.referenceID == nil { linkClassReference() } else if let entry = classReference { draft.classTemplate = entry; draft.syncClassDefaults() }; updateCasterLevel()
    }
    func selectProfile(_ name:String) {
        draft.selectedFeatures.removeAll { $0.category == .classFeature }
        draft.chosenClass.referenceID = nil; draft.classTemplate = nil; draft.classSkillChoices = []
        guard let profile = ClassProfile.named(name) else { draft.chosenClass.name = "Custom class"; draft.chosenClass.casting = .custom; return }
        draft.chosenClass.subclass = ""; draft.chosenClass.name = profile.name; draft.chosenClass.hitDie = profile.die; draft.chosenClass.casting = profile.progression
        if !draft.isLevelUp { draft.hero.saveProficiencies = profile.saves; draft.hero.castingAbility = profile.casting; draft.hero.slots = profile.progression == .full ? GuideRules.slots(at:draft.startingLevel):Array(repeating:0,count:9) }
        linkClassReference(); updateCasterLevel()
    }
    func applyClass(_ entry:CompendiumEntry) {
        draft.selectedFeatures.removeAll { $0.category == .classFeature }
        if (ClassProfile.named(draft.chosenClass.name)?.name ?? draft.chosenClass.name) != (ClassProfile.named(entry.name)?.name ?? entry.name) { draft.chosenClass.subclass = "" }
        draft.classTemplate = entry
        draft.classSkillChoices = draft.classSkillChoices.intersection(classSkillOptions)
        draft.chosenClass.name = entry.name
        if let die = Int(entry.value("hd")),[6,8,10,12].contains(die) { draft.chosenClass.hitDie = die }
        draft.chosenClass.casting = ClassProfile.named(entry.name)?.progression ?? .custom
        if !draft.isLevelUp {
            let saves = abilities.enumerated().filter { entry.value("proficiency").localizedCaseInsensitiveContains($0.element+" Saving Throws") }.map(\.offset)
            draft.hero.saveProficiencies = saves; draft.hero.castingAbility = classCastingAbility
            draft.hero.slots = Array(repeating:0,count:9); draft.hero.slotsRecoverOnShortRest = false
            if draft.chosenClass.casting != .none,let slots = GuideRules.importedSlots(entry,at:draft.classLevel) { draft.hero.slots = slots; draft.hero.slotsRecoverOnShortRest = entry.value("slotsReset") == "S" }
        }
        draft.syncClassDefaults(); updateCasterLevel()
    }
    func updateCasterLevel() { casterLevel = min(20,draft.resultingClasses.reduce(0) { $0+$1.casting.contribution($1.level,edition:draft.hero.edition) }) }
    func equipment(_ entry:CompendiumEntry) -> Item {
        var item = entry.item()
        if let ac = Int(entry.value("ac")),(0...30).contains(ac) {
            if item.equipmentKind == .shield { item.bonuses = [Bonus(name:entry.name,target:"ac",amount:ac)] }
            else if [.lightArmor,.mediumArmor,.heavyArmor].contains(item.equipmentKind) { item.armorBase = ac; item.armorAddsDexterity = item.equipmentKind != .heavyArmor; item.armorDexterityCap = item.equipmentKind == .mediumArmor ? 2:20 }
        }
        return item
    }
    func suggestedAttack(_ item:Item) -> Attack {
        if let existing = draft.hero.attacks.first(where:{ $0.name == item.name }) { return existing }
        let entry = catalog.items.first { $0.name == item.name }
        let damage = entry?.value("dmg1") ?? ""
        return Attack(name:item.name,ability:item.equipmentKind == .ranged ? 1:0,proficient:draft.result.weaponTraining(for:item) ?? true,damage:(try? Dice.roll(damage)) == nil ? "1d6":damage,type:entry.map { (["B":"Bludgeoning","P":"Piercing","S":"Slashing"][ $0.value("dmgType")] ?? $0.value("dmgType")) } ?? "",description:item.notes,equipmentID:item.id)
    }
}
