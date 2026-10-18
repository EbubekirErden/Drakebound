import AppKit
import CoreGraphics

struct CharacterPDFOptions {
    var letter = false
    var spellDescriptions = false
    var featureDescriptions = false
    var equipmentDescriptions = false
    var journal = false
    var creatures = false
}

/// A print document drawn independently of the app's dark, scrolling interface.
enum CharacterPDF {
    static func data(for hero:Hero,options:CharacterPDFOptions = CharacterPDFOptions()) throws -> Data {
        let output = NSMutableData()
        guard let consumer = CGDataConsumer(data:output) else { throw CocoaError(.fileWriteUnknown) }
        var media = CGRect(x:0,y:0,width:options.letter ? 612:595.28,height:options.letter ? 792:841.89)
        guard let context = CGContext(consumer:consumer,mediaBox:&media,[kCGPDFContextTitle:hero.name+" - Character sheet",kCGPDFContextCreator:"Drakebound"] as CFDictionary) else { throw CocoaError(.fileWriteUnknown) }
        let writer = PDFSheetWriter(context:context,size:media.size,name:hero.name)
        writer.beginPage("CHARACTER SHEET")
        writer.compactCharacter(hero)
        writer.beginPage("SPELLBOOK")
        writer.compactSpells(hero)
        if options.featureDescriptions {
            writer.beginPage("FEATURE REFERENCE")
            if (hero.featureEntries ?? []).isEmpty { writer.text(hero.features) }
            for feature in hero.featureEntries ?? [] { writer.subheading(feature.name); writer.text(feature.text) }
            let resources=(hero.counters ?? [])+(hero.featureEntries ?? []).compactMap(\.counter)
            if !resources.isEmpty { writer.section("Resources"); for counter in resources { writer.text("\(counter.name): \(counter.current)/\(counter.maximum) | \(counter.resetSummary)") } }
        }
        if options.equipmentDescriptions {
            writer.beginPage("EQUIPMENT REFERENCE")
            for item in hero.items {
                writer.subheading(item.name+" ×\(item.quantity)")
                writer.text((item.equipped ? "Equipped":"Carried")+(item.attuned == true ? " | Attuned":""),size:8)
                writer.text(item.notes)
            }
            for attack in hero.attacks where !(attack.description ?? "").isEmpty { writer.subheading(attack.name); writer.text(attack.description ?? "") }
        }
        if options.spellDescriptions {
            writer.beginPage("SPELL REFERENCE")
            for spell in hero.spells.sorted(by:{ $0.level == $1.level ? $0.name < $1.name:$0.level < $1.level }) {
                writer.subheading(spell.name+" - "+(spell.level == 0 ? "Cantrip":"Level \(spell.level)"))
                writer.text("\(spell.school) | \(spell.time) | \(spell.range) | \(spell.duration) | \(spell.components)",size:8)
                writer.text(spell.text)
                for roll in spell.rolls ?? [] { writer.text(roll.name+": "+roll.expression) }
            }
        }
        if options.creatures,let creatures = hero.creatures,!creatures.isEmpty {
            writer.beginPage("CREATURES")
            for creature in creatures {
                writer.section(creature.name+" - "+(creature.isActive ? "Active":"Inactive"))
                writer.text("\(creature.kind) | \(creature.type) | HP \(creature.hp)/\(creature.maximumHP) | AC \(creature.ac) | Speed \(creature.speed) ft")
                if options.featureDescriptions { writer.text(creature.description) }
                for attack in creature.attacks { writer.subheading(attack.name+" | "+(attack.timing ?? .action).rawValue); writer.text((attack.resolution == .damage ? "":"To hit "+signed(attack.bonus)+" | ")+"Damage "+attack.damage); if options.featureDescriptions { writer.text(attack.description ?? "") } }
                for trait in creature.traits ?? [] { writer.subheading(trait.name); if options.featureDescriptions { writer.text(trait.text) } }
            }
        }
        if options.journal {
            writer.beginPage("JOURNAL")
            if let entries = hero.journalEntries,!entries.isEmpty { for entry in entries { writer.section(entry.title); writer.text(entry.description) } }
            else { writer.text(hero.notes.isEmpty ? "No journal entries recorded.":hero.notes) }
        }
        writer.finish(); context.closePDF()
        return output as Data
    }
}
private extension Hero {
    var pdfHitDice:String {
        if let pools = hitDicePools,!pools.isEmpty { return pools.map { "\(max(0,$0.total-$0.used))/\($0.total) d\($0.sides)" }.joined(separator:" + ") }
        return "\(max(0,level-hitDiceUsed))/\(level) d\(hitDie)"
    }
}

private final class PDFSheetWriter {
    let context:CGContext; let size:CGSize; let name:String
    var margin:CGFloat = 36
    var columnWidth:CGFloat?
    var y:CGFloat = 0; var page = 0; var topic = ""
    var width:CGFloat { columnWidth ?? size.width-2*margin }
    var bottom:CGFloat { size.height-42 }
    init(context:CGContext,size:CGSize,name:String) { self.context=context; self.size=size; self.name=name }
    func beginPage(_ heading:String) {
        if page > 0 { endPage() }
        topic = heading; page += 1; context.beginPDFPage(nil)
        context.saveGState(); context.translateBy(x:0,y:size.height); context.scaleBy(x:1,y:-1)
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(cgContext:context,flipped:true)
        draw("FELLOWSHIP 5E  /  "+heading,in:CGRect(x:margin,y:22,width:width,height:15),size:8,bold:true,color:.darkGray)
        y = 48
    }
    func endPage() {
        draw(name,in:CGRect(x:margin,y:size.height-25,width:width-55,height:13),size:8,color:.gray)
        draw("\(page)",in:CGRect(x:size.width-margin-40,y:size.height-25,width:40,height:13),size:8,color:.gray)
        NSGraphicsContext.restoreGraphicsState(); context.restoreGState(); context.endPDFPage()
    }
    func finish() { endPage() }
    func ensure(_ h:CGFloat) { if y+h > bottom { beginPage(topic) } }
    func gap(_ h:CGFloat) { y += h }
    func columns(left:()->Void,right:()->Void) {
        ensure(410)
        let top = y; let originalMargin = margin
        let w = (width-14)/2
        columnWidth = w; left(); let leftBottom = y
        y = top; margin = originalMargin+w+14; right()
        y = max(y,leftBottom); margin = originalMargin; columnWidth = nil
    }
    func attrs(_ size:CGFloat,_ bold:Bool = false,_ color:NSColor = .black) -> [NSAttributedString.Key:Any] {
        let p = NSMutableParagraphStyle(); p.lineBreakMode = .byWordWrapping; p.lineSpacing = 2
        return [.font:bold ? NSFont.boldSystemFont(ofSize:size):NSFont.systemFont(ofSize:size),.foregroundColor:color,.paragraphStyle:p]
    }
    func draw(_ text:String,in rect:CGRect,size:CGFloat = 9,bold:Bool = false,color:NSColor = .black) { (text as NSString).draw(with:rect,options:[.usesLineFragmentOrigin,.usesFontLeading],attributes:attrs(size,bold,color)) }
    func height(_ text:String,width:CGFloat,size:CGFloat = 9,bold:Bool = false) -> CGFloat { ceil((text as NSString).boundingRect(with:NSSize(width:width,height:100000),options:[.usesLineFragmentOrigin,.usesFontLeading],attributes:attrs(size,bold)).height) }
    // TextKit returns complete glyph lines that fit; even very long notes continue without truncation.
    func text(_ text:String,size fontSize:CGFloat = 9,bold:Bool = false) {
        guard !text.isEmpty else { return }
        var remainder = text
        while !remainder.isEmpty {
            ensure(fontSize+9)
            let storage = NSTextStorage(string:remainder,attributes:attrs(fontSize,bold))
            let layout = NSLayoutManager(); storage.addLayoutManager(layout)
            let container = NSTextContainer(size:NSSize(width:width,height:bottom-y-4)); container.lineFragmentPadding = 0; layout.addTextContainer(container)
            let glyphs = layout.glyphRange(for:container)
            guard glyphs.length > 0 else { beginPage(topic); continue }
            layout.drawBackground(forGlyphRange:glyphs,at:NSPoint(x:margin,y:y)); layout.drawGlyphs(forGlyphRange:glyphs,at:NSPoint(x:margin,y:y))
            let chars = layout.characterRange(forGlyphRange:glyphs,actualGlyphRange:nil)
            y += ceil(layout.usedRect(for:container).height)+5
            remainder = (remainder as NSString).substring(from:NSMaxRange(chars))
            if !remainder.isEmpty { beginPage(topic) }
        }
    }
    func section(_ title:String) {
        ensure(65); y += 9
        NSColor(calibratedWhite:0.91,alpha:1).setFill(); NSBezierPath(roundedRect:CGRect(x:margin,y:y,width:width,height:23),xRadius:3,yRadius:3).fill()
        draw(title.uppercased(),in:CGRect(x:margin+8,y:y+5,width:width-16,height:18),size:10,bold:true); y += 31
    }
    func subheading(_ title:String) { ensure(55); y += 6; text(title,size:10,bold:true) }
    func tiles(_ values:[(String,String)]) {
        ensure(56); let cell = width/CGFloat(values.count)
        for (i,value) in values.enumerated() {
            let x = margin+CGFloat(i)*cell
            NSColor.lightGray.setStroke(); NSBezierPath(roundedRect:CGRect(x:x,y:y,width:cell-6,height:48),xRadius:4,yRadius:4).stroke()
            draw(value.0,in:CGRect(x:x+8,y:y+6,width:cell-20,height:12),size:7,bold:true,color:.darkGray)
            draw(value.1,in:CGRect(x:x+8,y:y+21,width:cell-20,height:24),size:15,bold:true)
        }; y += 56
    }
    func table(headers:[String],widths:[CGFloat],rows:[[String]]) {
        func row(_ values:[String],header:Bool) {
            let h = max(16,zip(values,widths).map { height($0.0,width:width*$0.1-12,size:9,bold:header)+3 }.max() ?? 21)
            ensure(h)
            var x = margin
            for (i,value) in values.enumerated() {
                let w = width*widths[i]
                (header ? NSColor(calibratedWhite:0.93,alpha:1):NSColor.white).setFill(); NSBezierPath(rect:CGRect(x:x,y:y,width:w,height:h)).fill()
                NSColor(calibratedWhite:0.8,alpha:1).setStroke(); let border=NSBezierPath(rect:CGRect(x:x,y:y,width:w,height:h)); border.lineWidth=0.4; border.stroke()
                draw(value,in:CGRect(x:x+6,y:y+2,width:w-12,height:h-3),bold:header); x += w
            }; y += h
        }
        row(headers,header:true)
        for values in rows {
            let needed = max(16,zip(values,widths).map { height($0.0,width:width*$0.1-12)+3 }.max() ?? 21)
            if y+needed > bottom { beginPage(topic); row(headers,header:true) }
            if needed > bottom-80 { for (i,value) in values.enumerated() { subheading(headers[i]); text(value) } }
            else { row(values,header:false) }
        }; y += 5
    }
}

private extension PDFSheetWriter {
    var ink:NSColor { NSColor(calibratedWhite:0.14,alpha:1) }
    func rule(_ rect:CGRect) {
        NSColor(calibratedWhite:0.77,alpha:1).setStroke()
        let path = NSBezierPath(roundedRect:rect,xRadius:4,yRadius:4); path.lineWidth=0.6; path.stroke()
    }
    func label(_ title:String,_ rect:CGRect) {
        NSColor(calibratedWhite:0.94,alpha:1).setFill(); NSBezierPath(rect:rect).fill()
        draw(title.uppercased(),in:rect.insetBy(dx:5,dy:4),size:8,bold:true,color:ink)
    }
    func clipped(_ text:String,_ rect:CGRect,size:CGFloat = 9,bold:Bool = false) {
        NSGraphicsContext.saveGraphicsState(); NSBezierPath(rect:rect).addClip()
        let p=NSMutableParagraphStyle(); p.lineBreakMode = .byTruncatingTail
        (text as NSString).draw(in:rect,withAttributes:[.font:bold ? NSFont.boldSystemFont(ofSize:size):NSFont.systemFont(ofSize:size),.foregroundColor:ink,.paragraphStyle:p])
        NSGraphicsContext.restoreGraphicsState()
    }
    func compactCharacter(_ hero:Hero) {
        let m:CGFloat=28, gap:CGFloat=9, full=size.width-56, end=size.height-40
        clipped(hero.name,CGRect(x:m,y:47,width:full,height:29),size:22,bold:true)
        clipped("\(hero.characterClass)  ·  Level \(hero.level)  ·  \(hero.edition)",CGRect(x:m,y:78,width:full,height:15),size:10)
        clipped("\(hero.ancestry)  ·  \(hero.background)  ·  \(hero.alignment)",CGRect(x:m,y:96,width:full,height:14),size:9)
        let cell=(full-5*gap)/6
        for i in 0..<6 {
            let x=m+CGFloat(i)*(cell+gap)
            rule(CGRect(x:x,y:118,width:cell,height:60))
            clipped(String(abilities[i].prefix(3)).uppercased(),CGRect(x:x+7,y:124,width:cell-14,height:11),size:8,bold:true)
            clipped("\(hero.effectiveScore(i))",CGRect(x:x+7,y:136,width:cell-14,height:24),size:19,bold:true)
            clipped("Modifier "+signed(hero.modifier(i)),CGRect(x:x+7,y:162,width:cell-14,height:11),size:7)
        }
        let top:CGFloat=190, usable=full-2*gap, left=usable*0.25, mid=usable*0.35, right=usable-left-mid
        let mx=m+left+gap, rx=mx+mid+gap
        // Saving throws and skills share one narrow strip, as on a paper character sheet.
        var ly=top
        label("Saving throws",CGRect(x:m,y:ly,width:left,height:20)); ly+=25
        for i in 0..<6 {
            let mark=hero.isSaveProficient(i) ? "●":"○"
            clipped(mark+" "+String(abilities[i].prefix(3)),CGRect(x:m+4,y:ly,width:left-42,height:15),size:9)
            clipped(signed(hero.saveBonus(i)+hero.testPenalty),CGRect(x:m+left-32,y:ly,width:30,height:15),size:9,bold:true); ly+=17
        }
        ly+=7; label("Skills",CGRect(x:m,y:ly,width:left,height:20)); ly+=25
        for skill in skills {
            let rank=hero.effectiveSkillRank(skill.0)
            clipped((rank > 0 ? "● ":"○ ")+skill.0,CGRect(x:m+3,y:ly,width:left-35,height:15),size:8)
            clipped(signed(hero.skillBonus(skill.0,skill.1)+hero.testPenalty),CGRect(x:m+left-30,y:ly,width:29,height:15),size:9,bold:true); ly+=17
        }
        clipped("● Trained   ○ Untrained",CGRect(x:m,y:ly+7,width:left,height:13),size:7)
        label("Proficiency  "+signed(hero.proficiency),CGRect(x:m,y:ly+29,width:left,height:21))
        label("Passive perception  \(hero.passivePerception)",CGRect(x:m,y:ly+55,width:left,height:21))
        // Combat and resource controls are kept together rather than spread across pages.
        var cy=top
        let cw=(mid-10)/3
        for (i,stat) in [("AC",String(hero.armorClass)),("INIT",signed(hero.initiative+hero.testPenalty)),("SPEED","\(hero.movement) ft")].enumerated() {
            let x=mx+CGFloat(i)*(cw+5); rule(CGRect(x:x,y:cy,width:cw,height:44))
            clipped(stat.0,CGRect(x:x+5,y:cy+5,width:cw-10,height:11),size:7,bold:true)
            clipped(stat.1,CGRect(x:x+5,y:cy+20,width:cw-10,height:20),size:13,bold:true)
        }
        cy+=52; label("Hit points",CGRect(x:mx,y:cy,width:mid,height:20)); cy+=25
        clipped("\(hero.hp) / \(hero.maximumHP)",CGRect(x:mx+5,y:cy,width:mid*0.60,height:26),size:21,bold:true)
        clipped("Temp  \(hero.tempHP)",CGRect(x:mx+mid*0.62,y:cy+5,width:mid*0.38,height:17),size:9)
        cy+=32
        clipped("Hit dice  "+hero.pdfHitDice,CGRect(x:mx+4,y:cy,width:mid-8,height:14),size:8);cy+=18
        clipped("Death saves  \(hero.deathSuccesses) ✓ / \(hero.deathFailures) ✕",CGRect(x:mx+4,y:cy,width:mid-8,height:14),size:8);cy+=18
        clipped("Inspiration  "+(hero.inspiration ? "●":"○"),CGRect(x:mx+4,y:cy,width:mid-8,height:14),size:8);cy+=23
        label("Attacks",CGRect(x:mx,y:cy,width:mid,height:20));cy+=25
        let attacks=hero.readyAttacks
        if attacks.isEmpty { clipped("No ready attacks",CGRect(x:mx+4,y:cy,width:mid-8,height:14),size:8);cy+=19 }
        for attack in attacks.prefix(5) {
            clipped(attack.name,CGRect(x:mx+4,y:cy,width:mid-8,height:15),size:9,bold:true);cy+=15
            clipped(signed(hero.attackBonus(attack)+hero.testPenalty)+" to hit  ·  "+hero.expression(attack.damage,bonus:hero.damageBonus(attack),targets:hero.attackTargets(attack,damage:true))+" "+attack.type,CGRect(x:mx+4,y:cy,width:mid-8,height:14),size:8);cy+=22
        }
        if attacks.count > 5 { clipped("+\(attacks.count-5) other attacks",CGRect(x:mx+4,y:cy,width:mid-8,height:12),size:7);cy+=17 }
        cy+=3;label("Resources",CGRect(x:mx,y:cy,width:mid,height:20));cy+=25
        let counters=(hero.counters ?? [])+(hero.featureEntries ?? []).compactMap(\.counter)
        let counterCapacity=min(7,max(0,Int((end-80-cy)/32)))
        for counter in counters.prefix(counterCapacity) {
            clipped(counter.name,CGRect(x:mx+4,y:cy,width:mid-47,height:14),size:8,bold:true)
            clipped("\(counter.current)/\(counter.maximum)",CGRect(x:mx+mid-40,y:cy,width:37,height:14),size:9,bold:true);cy+=14
            clipped(counter.resetSummary,CGRect(x:mx+4,y:cy,width:mid-8,height:12),size:7);cy+=18
        }
        if counters.count > counterCapacity { clipped("+\(counters.count-counterCapacity) other resources",CGRect(x:mx+4,y:cy,width:mid-8,height:12),size:7);cy+=15 }
        cy+=4;label("Conditions",CGRect(x:mx,y:min(cy,end-58),width:mid,height:20))
        clipped((hero.conditions.isEmpty ? "None":hero.conditions.joined(separator:", "))+" · Exhaustion \(hero.exhaustionLevel ?? 0)",CGRect(x:mx+4,y:min(cy,end-58)+25,width:mid-8,height:14),size:8)
        // Only a short feature index and carried inventory are needed during play.
        var ry=top
        label("Features & traits",CGRect(x:rx,y:ry,width:right,height:20));ry+=25
        let features=hero.pdfEssentialFeatures
        let maxFeatures=18
        for name in features.prefix(maxFeatures) { clipped(name,CGRect(x:rx+4,y:ry,width:right-8,height:13),size:8);ry+=12.5 }
        if features.count > maxFeatures { clipped("+\(features.count-maxFeatures) more · reference appendix",CGRect(x:rx+4,y:ry,width:right-8,height:12),size:7);ry+=14 }
        ry+=9;label("Equipment",CGRect(x:rx,y:ry,width:right,height:20));ry+=25
        clipped("\(hero.gold) gp  ·  "+String(format:"%.1f lb",hero.items.reduce(0) { $0+Double($1.quantity)*$1.weight }),CGRect(x:rx+4,y:ry,width:right-8,height:13),size:8,bold:true);ry+=19
        let inventory=hero.items.sorted { $0.equipped != $1.equipped ? $0.equipped:$0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let capacity=max(0,Int((end-ry-22)/12.5))
        for item in inventory.prefix(capacity) {
            clipped((item.equipped ? "● ":"○ ")+item.name+(item.quantity > 1 ? " ×\(item.quantity)":"")+(item.attuned == true ? " [A]":""),CGRect(x:rx+4,y:ry,width:right-8,height:13),size:8);ry+=12.5
        }
        if inventory.count > capacity { clipped("+\(inventory.count-capacity) more · equipment appendix",CGRect(x:rx+4,y:ry,width:right-8,height:12),size:7);ry+=14 }
        clipped("● Equipped   [A] Attuned",CGRect(x:rx+4,y:min(ry+5,end-12),width:right-8,height:12),size:7)
        y=end
    }
    func compactSpells(_ hero:Hero) {
        let m:CGFloat=28, full=size.width-56, gap:CGFloat=14, cw=(full-gap)/2, end=size.height-43
        clipped(hero.name+" · Spellbook",CGRect(x:m,y:47,width:full,height:25),size:20,bold:true)
        let stats="\(abilities[hero.castingAbility])  |  Save DC \(hero.spellDC)  |  Attack \(signed(hero.spellAttack+hero.testPenalty))"
        clipped(stats,CGRect(x:m,y:80,width:full,height:16),size:10,bold:true)
        var slotText=hero.slots.indices.filter { hero.slots[$0] > 0 }.map { "L\($0+1)  \(max(0,hero.slots[$0]-hero.usedSlots[$0]))/\(hero.slots[$0])" }.joined(separator:"     ")
        if slotText.isEmpty { slotText="No spell slots" }
        label("Slots remaining / total",CGRect(x:m,y:106,width:full,height:20))
        clipped(slotText,CGRect(x:m+5,y:132,width:full-10,height:16),size:10)
        clipped("● Prepared   ○ Unprepared   C Concentration   R Ritual   A Action   B Bonus   Rx Reaction",CGRect(x:m,y:157,width:full,height:13),size:7)
        if let spell=hero.concentratingSpell { clipped("Concentrating: "+spell.name,CGRect(x:m,y:173,width:full,height:13),size:8,bold:true) }
        let start:CGFloat=195
        let spells=hero.spells.sorted { $0.level == $1.level ? $0.name.localizedStandardCompare($1.name) == .orderedAscending:$0.level < $1.level }
        // Balance columns by measured row count rather than giving each spell level a separate panel/page.
        let levelCount=Set(spells.map(\.level)).count
        let totalHeight=CGFloat(spells.count)*28+CGFloat(levelCount)*23
        let target=min(end-start,max(100,ceil(totalHeight/2)))
        var column=0,sy=start,lastLevel = -1,shown=0
        for spell in spells {
            let heading=spell.level != lastLevel
            let needed:CGFloat=28+(heading ? 23:0)
            if column == 0 && sy+needed > start+target && shown > 0 { column=1;sy=start;lastLevel = -1 }
            guard sy+28+(spell.level != lastLevel ? 23:0) <= end-18 else { break }
            let x=m+CGFloat(column)*(cw+gap)
            if spell.level != lastLevel {
                label(spell.level == 0 ? "Cantrips":"Level \(spell.level)",CGRect(x:x,y:sy,width:cw,height:18));sy+=23;lastLevel=spell.level
            }
            clipped(spell.prepared ? "●":"○",CGRect(x:x+3,y:sy,width:12,height:12),size:8)
            clipped(spell.name,CGRect(x:x+17,y:sy,width:cw-20,height:13),size:9,bold:true);sy+=14
            let time=spell.time.lowercased().contains("reaction") ? "Rx":spell.time.lowercased().contains("bonus") ? "B":spell.time.lowercased().contains("action") ? "A":spell.time
            let flags=[spell.requiresConcentration ? "C":nil,spell.ritual == true ? "R":nil,spell.castingAbility.flatMap { $0 == hero.castingAbility ? nil:String(abilities[$0].prefix(3)).uppercased() }].compactMap { $0 }.joined(separator:" · ")
            clipped(time+" · "+spell.range+(flags.isEmpty ? "":" · "+flags),CGRect(x:x+17,y:sy,width:cw-20,height:12),size:7.5);sy+=14;shown+=1
        }
        if shown < spells.count { clipped("\(spells.count-shown) additional spells: include the spell reference appendix for the complete list.",CGRect(x:m,y:end-10,width:full,height:13),size:8) }
        if spells.isEmpty { clipped("No spells recorded",CGRect(x:m,y:start,width:full,height:20),size:10) }
        y=end
    }
}
private extension Hero {
    var pdfEssentialFeatures:[String] {
        let omit=["description","languages","specialty","suggested characteristics","multiclass features","spellcasting","expanding and replacing a spellbook","wizard subclass","ability score improvement"]
        if (featureEntries ?? []).isEmpty {
            return features.components(separatedBy:"\n\n").compactMap { $0.components(separatedBy:"\n").first }.filter { !$0.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty }
        }
        var seen=Set<String>()
        return (featureEntries ?? []).compactMap { feature in
            let name=feature.name.replacingOccurrences(of:"^Level [0-9]+: ",with:"",options:.regularExpression)
            let lower=name.lowercased()
            guard !omit.contains(lower),!lower.hasPrefix("becoming a "),!lower.hasPrefix("multiclass "),!lower.hasPrefix("optional rule:"),seen.insert(lower).inserted else { return nil }
            return name
        }
    }
}
