import SwiftUI

enum GuideStep:String,CaseIterable {
    case identity = "Identity", origin = "Class & origin", abilities = "Abilities", vitality = "Hit points", training = "Training", features = "Features", loadout = "Spells & gear", review = "Review"
    var heading:String { switch self { case .identity:return "Meet your adventurer"; case .origin:return "Choose your path"; case .abilities:return "Shape your abilities"; case .vitality:return "Grow your resilience"; case .training:return "Choose your training"; case .features:return "Make your feature choices"; case .loadout:return "Prepare for adventure"; case .review:return "Review your character" } }
    var hint:String { switch self { case .identity:return "Start with a name and rules edition. You can add a portrait now or later."; case .origin:return "Use a familiar class, browse your compendium, or enter a custom option."; case .abilities:return "Assign scores and any explicit increases. The preview updates as you choose."; case .vitality:return "Choose fixed HP, roll a hit die, or enter your table’s roll."; case .training:return "Record only the saves, skills, languages, and tools your choices grant."; case .features:return "Read and select the features you gain. Subclass and optional features are individual choices."; case .loadout:return "Set slot totals, choose spells, and add equipment. Preview any choice before adding it."; case .review:return "Check the full preview and changes, then save when everything is ready." } }
}

struct CharacterGuide:View {
    var session:CharacterGuideSession
    @ObservedObject var store:Store
    let catalog:GuideCatalog
    @State var draft:CharacterBuildDraft
    @State private var step:GuideStep
    @State private var previewVisible = true
    @State var fullPreview = false
    @State private var discard = false
    @State private var error:String?
    @State var referencePreview:CompendiumEntry?
    @State var improvementFeature:CharacterFeature?
    @State var featureEditor:CharacterFeature?
    @State var featurePreview:CharacterFeature?
    @State var bonusEditor:Bonus?
    @State var counterEditor:ResourceCounter?
    @State var spellEditor:Spell?
    @State var itemEditor:Item?
    @State var attackEditor:Attack?
    @State var spellBrowser = false
    @State var equipmentChoice:UUID?
    @State var featChoice:UUID?
    @State var featureSearch = ""
    @State var featureGroup = "Class"
    @State var casterLevel = 1
    @State var equipmentOpen = false
    @State var originHelp = false
    @State var customOrigin:CompendiumCreation?
    var steps:[GuideStep] { draft.isLevelUp ? [.origin]+(draft.asiAvailable || !draft.abilityOverrideReason.isEmpty ? [.abilities]:[])+[.vitality,.training,.features,.loadout,.review]:[.identity,.origin,.abilities,.training,.features,.loadout,.review] }
    var position:Int { steps.firstIndex(of:step) ?? 0 }
    var classReference:CompendiumEntry? { draft.chosenClass.referenceID.flatMap { catalog.entries[$0] } }
    @MainActor init(session:CharacterGuideSession,store:Store) {
        self.session = session; self.store = store; catalog = GuideCatalog(compendium:store.compendium,library:store.library)
        _draft = State(initialValue:CharacterBuildDraft(hero:session.original)); _step = State(initialValue:session.original == nil ? .identity:.origin)
    }
    var body:some View {
        VStack(spacing:0) {
            header
            progress
            HStack(alignment:.top,spacing:18) {
                ScrollView {
                    VStack(alignment:.leading,spacing:16) {
                        VStack(alignment:.leading,spacing:6) { Text(step.heading).font(.system(size:23,weight:.semibold)); Text(step.hint).font(.system(size:12)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true) }
                        stage
                    }.frame(maxWidth:.infinity,alignment:.leading).padding(2).padding(.bottom,18)
                }.id(step)
                if previewVisible { ScrollView { VStack(alignment:.leading,spacing:12) { HStack { Text("LIVE PREVIEW").font(.system(size:9,weight:.semibold)).tracking(1).foregroundStyle(.secondary); Spacer(); Button { fullPreview = true } label: { Image(systemName:"arrow.up.left.and.arrow.down.right") }.buttonStyle(.plain).help("Expand character preview") }; GuidePreview(draft:draft) }.padding(14) }.frame(width:250).background(surface.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius:10)) }
            }.padding(20).frame(maxWidth:1120,maxHeight:.infinity).frame(maxWidth:.infinity,maxHeight:.infinity)
            footer
        }.background(paper).foregroundStyle(ink).tint(accent).textFieldStyle(.roundedBorder)
        .onAppear { if draft.chosenClass.referenceID == nil { linkClassReference() } else if let entry = classReference { draft.classTemplate = entry; draft.syncClassDefaults() }; if !draft.isLevelUp,let profile = ClassProfile.named(draft.chosenClass.name) { draft.hero.saveProficiencies = profile.saves }; updateCasterLevel() }
        .onChange(of:draft.chosenClass.referenceID) { _,id in if let id,let entry = catalog.entries[id] { applyClass(entry) } }
        .onChange(of:draft.ancestryReference) { _,id in if let id,let entry = catalog.entries[id] { draft.chooseOrigin(entry) } else if id == nil { draft.ancestryTemplate = nil; draft.hero.ancestry = ""; draft.selectedFeatures.removeAll { $0.category == .ancestry } } }
        .onChange(of:draft.backgroundReference) { _,id in if let id,let entry = catalog.entries[id] { draft.chooseOrigin(entry) } else if id == nil { draft.backgroundTemplate = nil; draft.hero.background = ""; draft.selectedFeatures.removeAll { $0.category == .background } } }
        .onChange(of:draft.chosenClass.subclass) { _,_ in draft.syncClassDefaults() }
        .onChange(of:draft.classLevel) { _,_ in if let selected = subclassOptions.first(where:{ $0.name == draft.chosenClass.subclass }),draft.classLevel < selected.level { draft.chosenClass.subclass = "" }; draft.syncClassDefaults() }
        .onChange(of:draft.asiAvailable) { _,allowed in if !allowed && step == .abilities { step = .vitality } }
        .onChange(of:equipmentChoice) { _,id in if let id,let entry = catalog.entries[id] { draft.hero.items.append(equipment(entry)); equipmentChoice = nil } }
        .onChange(of:featChoice) { _,id in if let id,let entry = catalog.entries[id] { if draft.isLevelUp && draft.asiAvailable { draft.featInsteadOfASI = true }; for feature in GuideRules.featureChoices(entry,from:1,through:20) where !draft.selectedFeatures.contains(where:{ $0.id == feature.id }) { draft.selectedFeatures.append(feature) }; featChoice = nil } }
        .confirmationDialog("Discard this draft?",isPresented:$discard,titleVisibility:.visible) { Button("Discard draft",role:.destructive) { store.characterGuide = nil }; Button("Keep editing",role:.cancel) {} } message: { Text("Your saved characters have not been changed.") }
        .alert("Cannot save character",isPresented:Binding(get:{ error != nil },set:{ if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
        .onExitCommand { discard = true }
        .sheet(item:$referencePreview) { GuideReferencePreview(entry:$0) }
        .sheet(isPresented:$fullPreview) { GuideFullPreview(draft:draft) }
        .sheet(item:$customOrigin) { session in ReferenceTemplateEditor(draft:ReferenceTemplateDraft(category:session.category)) { entry in draft.chooseOrigin(entry) } }

        .sheet(item:$featurePreview) { feature in VStack(alignment:.leading,spacing:14) { HStack { Text(feature.name).font(.title2.bold()); Spacer(); Button("Done") { featurePreview = nil } }; Text(feature.source ?? "").font(.caption).foregroundStyle(sky); ScrollView { Text(feature.text).font(.system(size:13)).lineSpacing(4).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading) } }.padding(22).frame(width:640,height:580).background(surface) }
        .sheet(item:$improvementFeature) { feature in GuidedImprovementEditor(feature:feature,draft:draft,feats:eligibleFeats) { choice in do { try draft.configureImprovement(feature,choice:choice) } catch { self.error=error.localizedDescription } } }
        .sheet(item:$featureEditor) { feature in FeatureEditor(feature:feature,hero:draft.result,allowDelete:!draft.requiredOriginIDs.contains(feature.id),onSave:{ updated in if let i = draft.selectedFeatures.firstIndex(where:{ $0.id == updated.id }) { draft.selectedFeatures[i] = updated } else { draft.selectedFeatures.append(updated) } },onDelete:{ draft.selectedFeatures.removeAll { $0.id == feature.id } }) }
        .sheet(item:$bonusEditor) { bonus in BonusEditor(bonus:bonus,hero:draft.result,onSave:{ updated in var list = draft.hero.bonuses ?? []; if let i = list.firstIndex(where:{ $0.id == updated.id }) { list[i] = updated } else { list.append(updated) }; draft.hero.bonuses = list },onDelete:{ draft.hero.bonuses?.removeAll { $0.id == bonus.id } }) }
        .sheet(item:$counterEditor) { counter in CounterEditor(counter:counter,onSave:{ updated in var list = draft.hero.counters ?? []; if let i = list.firstIndex(where:{ $0.id == updated.id }) { list[i] = updated } else { list.append(updated) }; draft.hero.counters = list },onDelete:{ draft.hero.counters?.removeAll { $0.id == counter.id } }) }
        .sheet(isPresented:$spellBrowser) { GuideSpellBrowser(catalog:catalog,className:draft.chosenClass.name,alreadyKnown:draft.hero.spells,hero:draft.result,onAdd:{ spell in var copy = spell; copy.id = UUID(); copy.castingAbility = classCastingAbility; copy.prepared = copy.level == 0; copy.sourceClassID = draft.selectedClassID; copy.sourceClassName = draft.chosenClass.name; draft.hero.spells.append(copy) },buildDraft:draft,onSlots:{ draft.hero.slots=$0 }) }
        .sheet(item:$spellEditor) { spell in SpellEditor(spell:spell,hero:draft.result) { updated in if let i = draft.hero.spells.firstIndex(where:{ $0.id == updated.id }) { draft.hero.spells[i] = updated } else { draft.hero.spells.append(updated) } } }
        .sheet(item:$itemEditor) { item in ItemEditor(item:item,hero:draft.result) { updated in if let i = draft.hero.items.firstIndex(where:{ $0.id == updated.id }) { draft.hero.items[i] = updated } else { draft.hero.items.append(updated) };draft.hero.synchronizeWeaponAttacks(compendium:store.compendium) } }
        .sheet(item:$attackEditor) { attack in AttackEditor(attack:attack) { updated in if let i = draft.hero.attacks.firstIndex(where:{ $0.id == updated.id }) { draft.hero.attacks[i] = updated } else { draft.hero.attacks.append(updated) } } }
    }
    var header:some View {
        HStack(spacing:12) {
            Image(systemName:draft.isLevelUp ? "arrow.up.circle":"person.crop.circle.badge.plus").font(.system(size:22)).foregroundStyle(accent)
            VStack(alignment:.leading,spacing:3) { Text(draft.isLevelUp ? "Level up · \(draft.original!.level) → \(draft.newLevel)":"Create a character").font(.system(size:17,weight:.semibold)); Text(draft.isLevelUp ? draft.hero.name:"A guided start to your next adventure").font(.system(size:10)).foregroundStyle(.secondary) }
            Spacer(); Button { previewVisible.toggle() } label: { Label(previewVisible ? "Hide preview":"Show preview",systemImage:"sidebar.right") }; Button("Preview sheet") { fullPreview = true }; Button("Cancel") { discard = true }
        }.padding(.horizontal,22).padding(.vertical,15).background(surface)
    }
    var progress:some View {
        HStack(spacing:6) {
            ForEach(Array(steps.enumerated()),id:\.element) { i,item in Button { step = item } label: { VStack(spacing:8) { HStack(spacing:5) { Text(i < position ? "✓":"\(i+1)").font(.system(size:9,weight:.bold)).frame(width:17,height:17).background((i <= position ? accent:ink).opacity(0.12)).clipShape(Circle()); Text(item.rawValue).font(.system(size:10,weight:step == item ? .semibold:.regular)).lineLimit(1) }; Capsule().fill(i <= position ? accent:ink.opacity(0.1)).frame(height:2) }.foregroundStyle(step == item ? ink:ink.opacity(0.55)).frame(maxWidth:.infinity).padding(.vertical,10).contentShape(Rectangle()) }.buttonStyle(.plain).accessibilityLabel("Step \(i+1), \(item.rawValue)").accessibilityAddTraits(step == item ? .isSelected:[]) }
        }.padding(.horizontal,22).background(surface.opacity(0.35))
    }
    var footer:some View {
        VStack(alignment:.leading,spacing:8) {
            if let issue = stepProblems.first { Label(issue,systemImage:"exclamationmark.circle").font(.caption).foregroundStyle(gold) }
            HStack { Button("Back") { step = steps[max(0,position-1)] }.disabled(position == 0); Text("Step \(position+1) of \(steps.count)").font(.caption).foregroundStyle(.secondary); Spacer(); Text("Character draft · saved when you finish").font(.system(size:10)).foregroundStyle(.secondary)
                if step == .review { Button(draft.isLevelUp ? "Apply level \(draft.newLevel)":"Create character") { do { try store.commitGuide(draft) } catch { self.error = error.localizedDescription } }.buttonStyle(.borderedProminent).disabled(!draft.problems.isEmpty) }
                else { Button("Continue") { step = steps[min(steps.count-1,position+1)] }.buttonStyle(.borderedProminent).disabled(!stepProblems.isEmpty) }
            }
        }.padding(.horizontal,22).padding(.vertical,14).background(surface)
    }
    var stepProblems:[String] {
        if step == .review { return draft.problems }
        return draft.problems.filter { text in switch step { case .identity:return text.contains("name."); case .origin:return (text.contains("class") && !text.contains("class skills") && !text.contains("ability")) || text.contains("level 20") || text.contains("ancestry") || text.contains("background"); case .abilities:return text.contains("Point buy") || text.localizedCaseInsensitiveContains("ability") || text.contains("ASI") || text.contains("six"); case .training:return text.contains("class skills"); case .vitality:return text.contains("HP"); case .loadout:return text.contains("Slot"); default:return false } }
    }
    @ViewBuilder var stage:some View {
        switch step { case .identity:identityStep; case .origin:originStep; case .abilities:abilitiesStep; case .vitality:vitalityStep; case .training:trainingStep; case .features:featuresStep; case .loadout:loadoutStep; case .review:reviewStep }
    }
    var identityStep:some View {
        VStack(spacing:14) {
            EditorGroup(title:"Identity") {
                EditorField(title:"Character name") { TextField("Name your adventurer",text:$draft.hero.name) }
                HStack { EditorField(title:"Rules edition") { Picker("Rules edition",selection:Binding(get:{ draft.hero.edition },set:{ draft.hero.rulesEdition = $0; draft.resetOriginBonuses(); if let profile = ClassProfile.named(draft.chosenClass.name) { selectProfile(profile.name) } else { linkClassReference() } })) { Text("2024").tag("2024"); Text("2014").tag("2014") } }; EditorField(title:"Alignment") { OptionField(title:"Alignment",value:$draft.hero.alignment,choices:alignmentChoices) } }
                Stepper("Starting level: \(draft.startingLevel)",value:$draft.startingLevel,in:1...20)
                Text("Higher-level starts use fixed HP after level 1. You can adjust HP and choose features through the starting level.").font(.caption2).foregroundStyle(.secondary)
            }
            EditorGroup(title:"Portrait · optional") { PictureControls(data:$draft.hero.portrait,label:"Character portrait") }
        }
    }
    var originStep:some View {
        VStack(spacing:14) {
            if draft.isLevelUp { EditorGroup(title:"Advance a class") {
                ForEach(draft.existingClasses) { record in Button { selectExisting(record) } label: { HStack { Image(systemName:draft.selectedClassID == record.id ? "largecircle.fill.circle":"circle").foregroundStyle(accent); Text(record.name); Spacer(); Text("\(record.level) → \(record.level+(draft.selectedClassID == record.id ? 1:0))").monospacedDigit().foregroundStyle(sky) }.font(.system(size:12)).padding(9).background(paper).clipShape(RoundedRectangle(cornerRadius:6)) }.buttonStyle(.plain) }
                Button("Multiclass into a new class") { draft.selectedClassID = UUID(); draft.chosenClass = CharacterClassLevel(id:draft.selectedClassID,name:"Fighter",level:0,hitDie:10); draft.selectedFeatures.removeAll { $0.category == .classFeature }; linkClassReference() }
                DisclosureGroup("Review existing class levels") { ForEach($draft.existingClasses) { $record in HStack { TextField("Class name",text:$record.name); Stepper("\(record.level)",value:$record.level,in:1...20).frame(width:80); Picker("Casting",selection:$record.casting) { ForEach(CastingProgression.allCases,id:\.self) { Text($0.rawValue).tag($0) } }.labelsHidden().frame(width:135) } }; Text("These levels must total \(draft.original!.level). Imported hit-dice pools supply the initial breakdown.").font(.caption2).foregroundStyle(.secondary) }
            } }
            EditorGroup(title:draft.isLevelUp ? "Selected class · level \(draft.classLevel)":"Starting class") {
                if !draft.isLevelUp || !draft.existingClasses.contains(where:{ $0.id == draft.selectedClassID }) {
                    Picker("Quick choice",selection:Binding(get:{ ClassProfile.named(draft.chosenClass.name)?.name ?? "Custom" },set:{ selectProfile($0) })) { ForEach(ClassProfile.all) { Text($0.name).tag($0.name) }; Text("Custom").tag("Custom") }
                }
                GuideReferencePicker(title:"Classes",options:classReferenceOptions,selection:$draft.chosenClass.referenceID,onPreview:{ referencePreview = $0 })
                EditorField(title:"Class name") { TextField("Class name",text:$draft.chosenClass.name).disabled(draft.isLevelUp && draft.existingClasses.contains { $0.id == draft.selectedClassID }) }
                subclassPicker

                HStack { Picker("Hit die",selection:$draft.chosenClass.hitDie) { ForEach([6,8,10,12],id:\.self) { Text("d\($0)").tag($0) } }; Picker("Casting",selection:$draft.chosenClass.casting) { ForEach(CastingProgression.allCases,id:\.self) { Text($0.rawValue).tag($0) } } }
                if draft.isLevelUp && draft.classLevel == 1 { Text("Check the multiclass prerequisites and starting benefits in Preview. New classes do not automatically grant saving throw proficiencies.").font(.caption).foregroundStyle(gold) }
                if catalog.classes.isEmpty { Text("Import a Fight Club compendium for class features and previews. Custom classes work without a compendium.").font(.caption).foregroundStyle(.secondary) }
            }
            if !draft.isLevelUp { originChoices }

        }
    }
    var abilitiesStep:some View {
        VStack(spacing:14) {
            if draft.isLevelUp && !draft.improvementFeatures.isEmpty {
                EditorGroup(title:"Class ability choices") { ForEach(draft.improvementFeatures) { feature in Button("Configure "+(feature.source ?? feature.name)) { improvementFeature=feature } }; ForEach(0..<6,id:\.self) { i in HStack { Text(abilities[i]); Spacer(); Text("\(draft.original!.scores[i]) → \(draft.result.scores[i])").foregroundStyle(sky) }.font(.caption) } }
            } else {
            EditorGroup(title:draft.isLevelUp ? "Ability improvement · class level \(draft.classLevel)":"Generate & assign",badge:!draft.isLevelUp && draft.abilityMethod == .pointBuy ? "\(27-draft.pointCost) / 27 remaining":nil,badgeColor:draft.pointCost > 27 ? coral:accent) {
                if !draft.isLevelUp {
                    Picker("Method",selection:Binding(get:{ draft.abilityMethod },set:{ draft.changeAbilityMethod($0) })) { ForEach(AbilityGeneration.allCases,id:\.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.menu)
                    if draft.abilityMethod != .manual { Button("Prioritize class abilities") { draft.prioritizeAbilities() }.font(.caption) }

                    if draft.abilityMethod == .rolled { HStack { Button(draft.rollDetails.isEmpty ? "Roll six scores":"Reroll six scores") { do { let rolls = try draft.rollAbilities(); if let last = rolls.last { store.record(last) } } catch { self.error = error.localizedDescription } }; Text("4d6 per score · drop the lowest").font(.caption2).foregroundStyle(.secondary) } }
                    originBonusControls
                    HStack { Text("Ability").frame(maxWidth:.infinity,alignment:.leading); Text("Base").frame(width:110); Text(draft.hero.edition == "2024" ? "Background +":"Ancestry +").frame(width:90); Text("Final").frame(width:45) }.font(.system(size:10,weight:.semibold)).foregroundStyle(.secondary)
                } else {
                    if draft.asiAvailable { Picker("Class feature choice",selection:$draft.featInsteadOfASI) { Text("Ability Score Improvement").tag(false); Text("Another feat").tag(true) }.pickerStyle(.menu); Text("This milestone comes from \(draft.chosenClass.name) level \(draft.classLevel). An ASI grants two ability points, up to 20; choose another feat in Features instead if preferred.").font(.caption).foregroundStyle(.secondary) }
                    else { Text("No ASI is granted at this class level. Ability changes require a specific feature or an explicit override.").font(.caption).foregroundStyle(.secondary) }
                }
                ForEach(0..<6,id:\.self) { i in abilityRow(i) }
                if !draft.rollDetails.isEmpty && draft.abilityMethod == .rolled && !draft.isLevelUp { DisclosureGroup("Dice breakdown") { ForEach(Array(draft.rollDetails.enumerated()),id:\.offset) { i,text in Text("Score \(i+1): \(text)").font(.caption).foregroundStyle(.secondary) } } }
            }
            }
            if !draft.isLevelUp { vitalityStep }
        }
    }
    func abilityRow(_ i:Int) -> some View {
        HStack(spacing:10) {
            Text(abilities[i]).font(.system(size:12)).frame(maxWidth:.infinity,alignment:.leading)
            if draft.isLevelUp { Text("\(draft.original!.scores[i]) →").font(.caption).foregroundStyle(.secondary); Stepper("\(draft.hero.scores[i])",value:$draft.hero.scores[i],in:1...30).frame(width:95).disabled((!draft.asiAvailable || draft.featInsteadOfASI) && draft.abilityOverrideReason.isEmpty) }
            else {
                if draft.abilityMethod == .standard || draft.abilityMethod == .rolled { Picker(abilities[i],selection:Binding(get:{ draft.assignments[i] },set:{ draft.assign($0,to:i) })) { ForEach(0..<6,id:\.self) { Text("\(draft.abilityPool[$0])\(draft.abilityMethod == .rolled ? " · #\($0+1)":"")").tag($0) } }.labelsHidden().frame(width:110) }
                else { Stepper("\(draft.manualScores[i])",value:$draft.manualScores[i],in:draft.abilityMethod == .pointBuy ? 8...15:1...30).frame(width:110) }
                Picker(abilities[i]+" origin increase",selection:$draft.originAdjustments[i]) {
                    if draft.originBonusMethod == .reference { Text(signed(draft.originAdjustments[i])).tag(draft.originAdjustments[i]) }
                    else { ForEach(draft.originBonusMethod == .custom ? Array(-5...5):Array(0...(draft.originBonusMethod == .threeOnes ? 1:2)),id:\.self) { Text(signed($0)).tag($0) } }
                }.labelsHidden().frame(width:90).disabled(draft.originBonusMethod == .reference || (draft.originBonusMethod != .custom && !draft.originAbilityChoices.contains(i)))
            }
            Text("\(draft.result.effectiveScore(i))").font(.system(size:14,weight:.semibold,design:.rounded)).foregroundStyle(sky).frame(width:45)
        }.padding(.vertical,5)
    }
    var vitalityStep:some View {
        EditorGroup(title:draft.isLevelUp ? "Hit point gain":"Health & defenses") {
            if draft.isLevelUp {
                Picker("HP method",selection:$draft.hpMethod) { ForEach(HPGrowth.allCases,id:\.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                if draft.hpMethod == .average { Text("Fixed value: \(draft.chosenClass.hitDie/2+1) + Constitution \(signed(draft.result.modifier(2)))").font(.caption) }
                else { HStack { Stepper("Die result: \(draft.hpDieResult)",value:$draft.hpDieResult,in:1...draft.chosenClass.hitDie); if draft.hpMethod == .rolled { Button("Roll d\(draft.chosenClass.hitDie)") { if let roll = try? Dice.roll("1d\(draft.chosenClass.hitDie)",label:"Level-up HP") { draft.hpDieResult = roll.total; draft.hasHPRoll = true; store.record(roll) } } } } }
                let retro = (draft.result.modifier(2)-draft.original!.modifier(2))*draft.original!.level
                if retro != 0 { Text("Constitution change also adjusts earlier levels: \(signed(retro)) HP.").font(.caption).foregroundStyle(sky) }
                Toggle("Increase current HP by the change in maximum",isOn:$draft.increaseCurrentHP).font(.caption)
                Toggle("Calculate unarmored base AC from Dexterity",isOn:$draft.autoUnarmoredAC).font(.caption)
                Text("This does not perform a rest. Spent hit dice, slots, conditions, and counters are preserved.").font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("Level 1: maximum d\(draft.chosenClass.hitDie) + Constitution \(signed(draft.result.modifier(2))). Later starting levels use the fixed value.").font(.caption).foregroundStyle(.secondary)
                Toggle("Calculate unarmored AC from Dexterity",isOn:$draft.autoUnarmoredAC).font(.caption)
                if !draft.autoUnarmoredAC { Stepper("Base AC: \(draft.hero.ac)",value:$draft.hero.ac,in:0...50) }
                Stepper("Speed: \(draft.hero.speed) ft",value:$draft.hero.speed,in:0...300,step:5)
            }
            Stepper("Additional HP adjustment: \(signed(draft.hpAdjustment))",value:$draft.hpAdjustment,in:-200...200)
            HStack { Text("Maximum HP").font(.caption); Spacer(); Text(draft.isLevelUp ? "\(draft.original!.maximumHP) → \(draft.result.maximumHP)":"\(draft.result.maximumHP)").font(.system(size:24,weight:.semibold,design:.rounded)).foregroundStyle(leaf) }
        }
    }
    var trainingStep:some View { guideTraining }
}
