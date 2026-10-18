import SwiftUI

struct CharacterGuide:View {
    var session:CharacterGuideSession
    @ObservedObject var store:Store
    let catalog:GuideCatalog
    @State var draft:CharacterBuildDraft
    @State private var step:GuideStep
    @State private var previewVisible = true
    @State var fullPreview = false
    @State private var discard = false
    @State private var visited:Set<GuideStep> = []
    @State private var showStepIssues = false
    @State private var validationAttempt = 0
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
    @State var loadoutPage = "Spells"
    @State var loadoutSpellQuery = ""
    @State var loadoutEquipmentQuery = ""
    @State var loadoutAttackQuery = ""
    @State var loadoutSpellLevel = -1
    @State var featureListMode = "Available"
    @State var featureSearch = ""
    @State var featureGroup = "Class"
    @State var casterLevel = 1
    @State var equipmentOpen = false
    @State var originHelp = false
    @State var customOrigin:CompendiumCreation?
    var steps:[GuideStep] { draft.guideSteps }
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
                ScrollViewReader { scroll in
                    ScrollView {
                        VStack(alignment:.leading,spacing:14) {
                            if step == .features || step == .loadout { Text(step.hint).font(.system(size:11)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true) }
                            else { VStack(alignment:.leading,spacing:6) { Text(step.heading).font(.system(size:23,weight:.semibold)); Text(step.hint).font(.system(size:12)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true) } }
                            if showStepIssues && !stepIssues.isEmpty && step != .review {
                                VStack(alignment:.leading,spacing:7) { Text("Complete this step").font(.system(size:12,weight:.semibold)); ForEach(stepIssues) { issue in Label(issue.message,systemImage:"exclamationmark.circle").font(.system(size:12)).fixedSize(horizontal:false,vertical:true) } }.padding(12).frame(maxWidth:.infinity,alignment:.leading).background(gold.opacity(0.07),in:RoundedRectangle(cornerRadius:8)).foregroundStyle(gold).id("guideIssues")
                            }
                            stage
                        }.frame(maxWidth:.infinity,alignment:.leading).padding(2).padding(.bottom,18)
                    }.id(step)
                    .onChange(of:validationAttempt) { _,_ in withAnimation { scroll.scrollTo("guideIssues",anchor:.top) } }
                    .onChange(of:loadoutPage) { _,_ in scroll.scrollTo("loadoutTop",anchor:.top) }
                }
                if previewVisible { ScrollView { VStack(alignment:.leading,spacing:12) { HStack { Text(draft.isLevelUp ? "LEVEL CHANGES":"CHARACTER PREVIEW").font(.system(size:10,weight:.semibold)).foregroundStyle(.secondary); Spacer(); Button { fullPreview = true } label: { Image(systemName:"arrow.up.left.and.arrow.down.right") }.buttonStyle(.plain).help("Expand character preview") }; GuidePreview(draft:draft) }.padding(14) }.frame(width:250).background(surface.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius:10)) }
            }.padding(20).frame(maxWidth:1120,maxHeight:.infinity).frame(maxWidth:.infinity,maxHeight:.infinity)
            footer
        }.background(paper).foregroundStyle(ink).tint(accent).textFieldStyle(.roundedBorder)
        .onAppear { if draft.chosenClass.referenceID == nil { linkClassReference() } else if let entry = classReference { draft.classTemplate = entry; draft.syncClassDefaults() }; if !draft.isLevelUp,let profile = ClassProfile.named(draft.chosenClass.name) { draft.hero.saveProficiencies = profile.saves }; updateCasterLevel() }
        .onChange(of:draft.chosenClass.referenceID) { _,id in if let id,let entry = catalog.entries[id] { applyClass(entry) } }
        .onChange(of:draft.ancestryReference) { _,id in if let id,let entry = catalog.entries[id] { draft.chooseOrigin(entry) } else if id == nil { draft.ancestryTemplate = nil; draft.hero.ancestry = ""; draft.selectedFeatures.removeAll { $0.category == .ancestry } } }
        .onChange(of:draft.backgroundReference) { _,id in if let id,let entry = catalog.entries[id] { draft.chooseOrigin(entry) } else if id == nil { draft.backgroundTemplate = nil; draft.hero.background = ""; draft.selectedFeatures.removeAll { $0.category == .background } } }
        .onChange(of:draft.chosenClass.subclass) { _,_ in draft.syncClassDefaults() }
        .onChange(of:draft.classLevel) { _,_ in if let selected = subclassOptions.first(where:{ $0.name == draft.chosenClass.subclass }),draft.classLevel < selected.level { draft.chosenClass.subclass = "" }; draft.syncClassDefaults() }
        .onChange(of:steps) { _,available in if !available.contains(step) { go(to:draft.isLevelUp ? .vitality:.abilities) } }
        .onChange(of:equipmentChoice) { _,id in if let id,let entry = catalog.entries[id] { draft.hero.items.append(equipment(entry)); equipmentChoice = nil } }
        .onChange(of:featChoice) { _,id in if let id,let entry = catalog.entries[id] { if draft.isLevelUp && draft.asiAvailable { draft.featInsteadOfASI = true }; for feature in GuideRules.featureChoices(entry,from:1,through:20) where !draft.selectedFeatures.contains(where:{ $0.id == feature.id }) { draft.selectedFeatures.append(feature) }; featChoice = nil } }
        .confirmationDialog("Discard this draft?",isPresented:$discard,titleVisibility:.visible) { Button("Discard draft",role:.destructive) { store.characterGuide = nil }; Button("Keep editing",role:.cancel) {} } message: { Text("Your saved characters have not been changed.") }
        .alert("Cannot save character",isPresented:Binding(get:{ error != nil },set:{ if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
        .onExitCommand { discard = true }
        .sheet(item:$referencePreview) { GuideReferencePreview(entry:$0) }
        .sheet(isPresented:$fullPreview) { GuideFullPreview(draft:draft) }
        .sheet(item:$customOrigin) { session in ReferenceTemplateEditor(draft:ReferenceTemplateDraft(category:session.category)) { entry in draft.chooseOrigin(entry) } }

        .sheet(item:$featurePreview) { GuideFeaturePreview(feature:$0) }
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
            Spacer(); Button { previewVisible.toggle() } label: { Image(systemName:"sidebar.right") }.buttonStyle(PageButtonStyle()).help(previewVisible ? "Hide character preview":"Show character preview").accessibilityLabel(previewVisible ? "Hide character preview":"Show character preview"); Button("Preview sheet") { fullPreview = true }.buttonStyle(PageButtonStyle()); Button("Cancel") { discard = true }.buttonStyle(PageButtonStyle())
        }.padding(.horizontal,22).padding(.vertical,15).background(surface)
    }
    var progress:some View {
        let issues=draft.guideIssues
        let complete=Set(steps.filter { item in visited.contains(item) && item != .review && !issues.contains { $0.step == item } })
        return HStack(spacing:6) {
            ForEach(Array(steps.enumerated()),id:\.element) { i,item in Button { go(to:item) } label: { VStack(spacing:8) { HStack(spacing:5) { Text(complete.contains(item) ? "✓":issues.contains { $0.step == item } && visited.contains(item) ? "!":"\(i+1)").font(.system(size:9,weight:.bold)).frame(width:17,height:17).background(((complete.contains(item) || item == step) ? accent:ink).opacity(0.12)).clipShape(Circle()); Text(item.rawValue).font(.system(size:10,weight:step == item ? .semibold:.regular)).lineLimit(1) }; Capsule().fill(complete.contains(item) || item == step ? accent:ink.opacity(0.1)).frame(height:2) }.foregroundStyle(step == item ? ink:ink.opacity(0.55)).frame(maxWidth:.infinity).padding(.vertical,10).contentShape(Rectangle()) }.buttonStyle(.plain).accessibilityLabel("Step \(i+1), \(item.rawValue)").accessibilityValue(complete.contains(item) ? "Complete":issues.contains { $0.step == item } ? "Needs attention":"Not reviewed").accessibilityAddTraits(step == item ? .isSelected:[]) }
        }.padding(.horizontal,22).background(surface.opacity(0.35))
    }
    var footer:some View {
        let issues=draft.guideIssues
        let currentIssues=step == .review ? issues:issues.filter { $0.step == step }
        return HStack(spacing:12) {
            Button("Back") { go(to:steps[max(0,position-1)]) }.buttonStyle(PageButtonStyle()).disabled(position == 0)
            Text("Step \(position+1) of \(steps.count)").font(.system(size:11)).foregroundStyle(.secondary)
            Spacer(minLength:8)
            if !currentIssues.isEmpty {
                Button { showStepIssues=true;validationAttempt += 1; if step == .review,let issue=issues.first { go(to:issue.step,showProblems:true) } } label: { Label("\(currentIssues.count) \(currentIssues.count == 1 ? "item needs":"items need") attention",systemImage:"exclamationmark.circle") }.buttonStyle(.plain).font(.system(size:11)).foregroundStyle(gold)
            } else { Text("Draft · saved when you finish").font(.system(size:10)).foregroundStyle(.secondary) }
            if step == .review {
                if let issue=issues.first {
                    Button("Fix first issue") { go(to:issue.step,showProblems:true) }.buttonStyle(PageButtonStyle(prominent:true))
                } else {
                    Button(draft.isLevelUp ? "Apply level \(draft.newLevel)":"Create character") { do { try store.commitGuide(draft) } catch { self.error=error.localizedDescription } }.buttonStyle(PageButtonStyle(prominent:true))
                }
            } else {
                Button("Continue") { if currentIssues.isEmpty { go(to:steps[min(steps.count-1,position+1)]) } else { showStepIssues=true;validationAttempt += 1 } }.buttonStyle(PageButtonStyle(prominent:true))
            }
        }.padding(.horizontal,22).padding(.vertical,14).background(surface)
    }
    var stepIssues:[GuideIssue] { step == .review ? draft.guideIssues:draft.guideIssues.filter { $0.step == step } }
    func go(to destination:GuideStep,showProblems:Bool = false) { if destination == .loadout && showProblems { loadoutPage="Spells" };visited.insert(step);step=destination;showStepIssues=showProblems;validationAttempt += 1 }
    @ViewBuilder var stage:some View {
        switch step { case .identity:identityStep; case .origin:originStep; case .abilities:abilitiesStep; case .vitality:vitalityStep; case .training:trainingStep; case .features:featuresStep; case .loadout:loadoutStep; case .review:reviewStep }
    }
    var identityStep:some View {
        GuideTable {
            EditorGroup(title:"Identity") {
                EditorField(title:"Character name") { TextField("Name your adventurer",text:$draft.hero.name) }
                HStack { EditorField(title:"Rules edition") { Picker("Rules edition",selection:Binding(get:{ draft.hero.edition },set:{ draft.hero.rulesEdition = $0; draft.resetOriginBonuses(); if let profile = ClassProfile.named(draft.chosenClass.name) { selectProfile(profile.name) } else { linkClassReference() } })) { Text("2024").tag("2024"); Text("2014").tag("2014") } }; EditorField(title:"Alignment") { OptionField(title:"Alignment",value:$draft.hero.alignment,choices:alignmentChoices) } }
                Stepper("Starting level: \(draft.startingLevel)",value:$draft.startingLevel,in:1...20)
                Text("Higher-level starts use fixed HP after level 1. You can adjust HP and choose features through the starting level.").font(.caption2).foregroundStyle(.secondary)
            }
            GuideSection("Portrait",summary:"Optional") { PictureControls(data:$draft.hero.portrait,label:"Character portrait") }
        }
    }
    var originStep:some View {
        VStack(spacing:12) {
            if draft.isLevelUp { GuideSection("Advance a class",summary:"Total level \(draft.original!.level) → \(draft.newLevel)",expanded:true) {
                ForEach(draft.existingClasses) { record in Button { selectExisting(record) } label: { HStack { Image(systemName:draft.selectedClassID == record.id ? "largecircle.fill.circle":"circle").foregroundStyle(accent); Text(record.name); Spacer(); Text("\(record.level) → \(record.level+(draft.selectedClassID == record.id ? 1:0))").monospacedDigit().foregroundStyle(sky) }.font(.system(size:12)).padding(9).background(paper).clipShape(RoundedRectangle(cornerRadius:6)) }.buttonStyle(.plain) }
                Button("Multiclass into a new class") { draft.selectedClassID = UUID(); draft.chosenClass = CharacterClassLevel(id:draft.selectedClassID,name:"Fighter",level:0,hitDie:10); draft.selectedFeatures.removeAll { $0.category == .classFeature }; linkClassReference() }
                DisclosureGroup("Review existing class levels") { ForEach($draft.existingClasses) { $record in HStack { TextField("Class name",text:$record.name); Stepper("\(record.level)",value:$record.level,in:1...20).frame(width:80); Picker("Casting",selection:$record.casting) { ForEach(CastingProgression.allCases,id:\.self) { Text($0.rawValue).tag($0) } }.labelsHidden().frame(width:135) } }; Text("These levels must total \(draft.original!.level). Imported hit-dice pools supply the initial breakdown.").font(.caption2).foregroundStyle(.secondary) }
            } }
            GuideSection(draft.isLevelUp ? "Selected class":"Starting class",summary:draft.chosenClass.name+" · level \(draft.classLevel)",expanded:true) {
                if !draft.isLevelUp || !draft.existingClasses.contains(where:{ $0.id == draft.selectedClassID }) {
                    Picker("Class",selection:Binding(get:{ ClassProfile.named(draft.chosenClass.name)?.name ?? "Custom" },set:{ selectProfile($0) })) { ForEach(ClassProfile.all) { Text($0.name).tag($0.name) }; Text("Custom").tag("Custom") }
                }
                GuideReferencePicker(title:"Classes",options:classReferenceOptions,selection:$draft.chosenClass.referenceID,onPreview:{ referencePreview = $0 })
                subclassPicker
                GuideSection("Class settings",summary:"d\(draft.chosenClass.hitDie) · \(draft.chosenClass.casting.rawValue)") {
                    EditorField(title:"Class name") { TextField("Class name",text:$draft.chosenClass.name).disabled(draft.isLevelUp && draft.existingClasses.contains { $0.id == draft.selectedClassID }) }
                    HStack { Picker("Hit die",selection:$draft.chosenClass.hitDie) { ForEach([6,8,10,12],id:\.self) { Text("d\($0)").tag($0) } }; Picker("Casting",selection:$draft.chosenClass.casting) { ForEach(CastingProgression.allCases,id:\.self) { Text($0.rawValue).tag($0) } } }
                }
                if draft.isLevelUp && draft.classLevel == 1 { Text("Check the multiclass prerequisites and starting benefits in Preview. New classes do not automatically grant saving throw proficiencies.").font(.caption).foregroundStyle(gold) }
                if catalog.classes.isEmpty { Text("Import a Fight Club compendium for class features and previews. Custom classes work without a compendium.").font(.caption).foregroundStyle(.secondary) }
            }
            if !draft.isLevelUp { originChoices }

        }
    }
    var abilitiesStep:some View {
        GuideTable {
            if draft.isLevelUp && !draft.improvementFeatures.isEmpty {
                GuideSection("Class ability choices",summary:"\(draft.improvementFeatures.count) choices",expanded:true) { ForEach(draft.improvementFeatures) { feature in Button("Configure "+(feature.source ?? feature.name)) { improvementFeature=feature } }; ForEach(0..<6,id:\.self) { i in HStack { Text(abilities[i]); Spacer(); Text("\(draft.original!.scores[i]) → \(draft.result.scores[i])").foregroundStyle(sky) }.font(.caption) } }
            } else {
            GuideSection(draft.isLevelUp ? "Ability improvement":"Generate & assign",summary:!draft.isLevelUp && draft.abilityMethod == .pointBuy ? "\(27-draft.pointCost) / 27 points remaining":"Class level \(draft.classLevel)",expanded:true) {
                if !draft.isLevelUp {
                    Picker("Method",selection:Binding(get:{ draft.abilityMethod },set:{ draft.changeAbilityMethod($0) })) { ForEach(AbilityGeneration.allCases,id:\.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.menu)
                    if draft.abilityMethod != .manual { Button("Prioritize class abilities") { draft.prioritizeAbilities() }.font(.caption) }

                    if draft.abilityMethod == .rolled { HStack { Button(draft.rollDetails.isEmpty ? "Roll six scores":"Reroll six scores") { do { let rolls = try draft.rollAbilities(); if let last = rolls.last { store.record(last) } } catch { self.error = error.localizedDescription } }; Text("4d6 per score · drop the lowest").font(.caption2).foregroundStyle(.secondary) } }
                    originBonusControls
                } else {
                    if draft.asiAvailable { Picker("Class feature choice",selection:$draft.featInsteadOfASI) { Text("Ability Score Improvement").tag(false); Text("Another feat").tag(true) }.pickerStyle(.menu); Text("This milestone comes from \(draft.chosenClass.name) level \(draft.classLevel). An ASI grants two ability points, up to 20; choose another feat in Features instead if preferred.").font(.caption).foregroundStyle(.secondary) }
                    else { Text("No ASI is granted at this class level. Ability changes require a specific feature or an explicit override.").font(.caption).foregroundStyle(.secondary) }
                }
                VStack(spacing:0) {
                    HStack(spacing:10) { Text("Ability").frame(maxWidth:.infinity,alignment:.leading); Text(draft.isLevelUp ? "Change":"Base").frame(width:draft.isLevelUp ? 140:110); if !draft.isLevelUp { Text(draft.hero.edition == "2024" ? "Origin +":"Ancestry +").frame(width:90) };Text("Final").frame(width:45);Text("Mod").frame(width:35) }.font(.system(size:10,weight:.semibold)).foregroundStyle(.secondary).padding(.horizontal,10).padding(.vertical,9)
                    ForEach(0..<6,id:\.self) { i in abilityRow(i) }
                }.clipShape(RoundedRectangle(cornerRadius:7)).overlay(RoundedRectangle(cornerRadius:7).stroke(ink.opacity(0.07)))
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
            Text(signed(draft.result.modifier(i))).font(.system(size:12,weight:.medium)).foregroundStyle(accent).frame(width:35)
        }.modifier(GuideTableRow(index:i))
    }
    var vitalityStep:some View {
        GuideSection(draft.isLevelUp ? "Hit point gain":"Health & defenses",summary:"\(draft.result.maximumHP) maximum HP · \(draft.result.armorClass) AC",expanded:draft.isLevelUp) {
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
