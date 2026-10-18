import AppKit

final class TestJournalView:JournalTextView {
    let history = UndoManager()
    override var undoManager:UndoManager? { history }
}
@main struct JournalTests {
    static func main() throws {
        let source = "🌙 Moon gate\nFind the keeper\nBring the silver key\n"
        let text = NSMutableAttributedString(string:source,attributes:JournalText.attributes)
        let view = TestJournalView(frame:NSRect(x:0,y:0,width:400,height:200))
        view.isRichText = true;view.allowsUndo = true;view.textStorage!.setAttributedString(text)
        view.history.groupsByEvent = false
        let controller = JournalEditorController();controller.view = view
        let title = (source as NSString).range(of:"Moon gate")
        view.setSelectedRange(title);controller.refresh()
        view.history.beginUndoGrouping();controller.trait(.boldFontMask);view.history.endUndoGrouping()
        let bold = view.textStorage!.attribute(.font,at:title.location,effectiveRange:nil) as! NSFont
        assert(NSFontManager.shared.traits(of:bold).contains(.boldFontMask))
        view.history.undo()
        let regular = view.textStorage!.attribute(.font,at:title.location,effectiveRange:nil) as! NSFont
        assert(!NSFontManager.shared.traits(of:regular).contains(.boldFontMask))
        view.history.redo()
        let recovered = view.textStorage!.attribute(.font,at:title.location,effectiveRange:nil) as! NSFont
        assert(NSFontManager.shared.traits(of:recovered).contains(.boldFontMask))
        view.setSelectedRange(title);controller.refresh()
        view.history.beginUndoGrouping();controller.trait(.italicFontMask);controller.setLink(URL(string:"https://example.com/gate")!);view.history.endUndoGrouping()
        // Commands also arrive through keyDown, including Caps Lock/function modifier flags.
        view.shortcut = { key in controller.trait(key == "b" ? .boldFontMask:.italicFontMask) }
        let event = NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:[.command,.capsLock],timestamp:0,windowNumber:0,context:nil,characters:"B",charactersIgnoringModifiers:"B",isARepeat:false,keyCode:11)!
        view.history.beginUndoGrouping();view.keyDown(with:event);view.history.endUndoGrouping()
        assert(!controller.bold)
        view.history.beginUndoGrouping();view.keyDown(with:event);view.history.endUndoGrouping()
        assert(controller.bold)
        let turkish = NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:.command,timestamp:0,windowNumber:0,context:nil,characters:"ı",charactersIgnoringModifiers:"ı",isARepeat:false,keyCode:34)!
        view.history.beginUndoGrouping();view.keyDown(with:turkish);view.history.endUndoGrouping();assert(!controller.italic)
        view.history.beginUndoGrouping();view.keyDown(with:turkish);view.history.endUndoGrouping();assert(controller.italic)
        let rtf = JournalText.write(view.attributedString())!
        let decoded = JournalText.read(rtf,plain:source)
        assert(decoded.string == source)
        let font = decoded.attribute(.font,at:title.location,effectiveRange:nil) as! NSFont
        let traits = NSFontManager.shared.traits(of:font)
        assert(traits.contains(.boldFontMask) && traits.contains(.italicFontMask))
        assert(decoded.attribute(.link,at:title.location,effectiveRange:nil) != nil)
        assert(JournalText.read(rtf,plain:"Edited plain text").string == "Edited plain text")
        assert(JournalText.read(Data([0,1,2]),plain:source).string == source)
        // Pasted/saved dark ink must become readable without flattening rich formatting.
        let pasted = NSMutableAttributedString(string:"Dark link and highlight",attributes:[.font:NSFont.boldSystemFont(ofSize:18),.foregroundColor:NSColor.black])
        pasted.addAttribute(.link,value:URL(string:"https://example.com")!,range:NSRange(location:0,length:9))
        let highlight = NSColor(calibratedRed:1,green:0.85,blue:0.2,alpha:1)
        pasted.addAttribute(.foregroundColor,value:highlight,range:NSRange(location:14,length:9))
        let rawRTF = try pasted.data(from:NSRange(location:0,length:pasted.length),documentAttributes:[.documentType:NSAttributedString.DocumentType.rtf])
        let readable = JournalText.read(rawRTF,plain:pasted.string)
        assert(readable.string == pasted.string)
        assert((readable.attribute(.foregroundColor,at:0,effectiveRange:nil) as! NSColor).isEqual(JournalText.color))
        assert(readable.attribute(.link,at:0,effectiveRange:nil) != nil)
        assert((readable.attribute(.font,at:0,effectiveRange:nil) as! NSFont).pointSize == 18)
        assert(NSFontManager.shared.traits(of:readable.attribute(.font,at:0,effectiveRange:nil) as! NSFont).contains(.boldFontMask))
        assert(JournalText.readableColor(highlight).isEqual(highlight))
        assert(JournalText.readableColor(nil).isEqual(JournalText.color))
        assert(JournalText.readableColor(NSColor.black.withAlphaComponent(0)).isEqual(JournalText.color))
        let written = JournalText.read(JournalText.write(pasted),plain:pasted.string)
        assert((written.attribute(.foregroundColor,at:0,effectiveRange:nil) as! NSColor).isEqual(JournalText.color))
        view.textStorage!.setAttributedString(pasted)
        view.typingAttributes = [.font:JournalText.font,.foregroundColor:NSColor.black]
        view.didChangeText()
        assert((view.textStorage!.attribute(.foregroundColor,at:0,effectiveRange:nil) as! NSColor).isEqual(JournalText.color))
        assert((view.typingAttributes[.foregroundColor] as! NSColor).isEqual(JournalText.color))
        view.textStorage!.setAttributedString(decoded)
        let end = (source as NSString).range(of:"Find the keeper\nBring the silver key\n")
        let bullets = JournalText.list(decoded,selection:end,kind:"bullet")
        assert(bullets.0.string == "🌙 Moon gate\n• Find the keeper\n• Bring the silver key\n")
        let removed = JournalText.list(bullets.0,selection:bullets.1,kind:"bullet")
        assert(removed.0.string == source)
        let numbers = JournalText.list(decoded,selection:end,kind:"number")
        assert(numbers.0.string.contains("1. Find the keeper\n2. Bring the silver key\n"))
        let check = JournalText.list(NSAttributedString(string:""),selection:NSRange(location:0,length:0),kind:"check")
        assert(check.0.string == "☐ ")
        assert(JournalText.listPrefix("17. Get supplies")!.next == "18. ")
        assert(JournalText.listPrefix("☑ Get supplies")!.next == "☐ ")
        assert(JournalText.link("javascript:alert(1)") == nil && JournalText.link("file:///etc/passwd") == nil)
        assert(JournalText.link("https://example.com") != nil && JournalText.link("mailto:keeper@example.com") != nil)
        view.textStorage!.setAttributedString(NSAttributedString(string:"☐ Find the keeper",attributes:JournalText.attributes))
        view.setSelectedRange(NSRange(location:3,length:0))
        view.history.beginUndoGrouping();controller.check();view.history.endUndoGrouping()
        assert(view.string == "☑ Find the keeper")
        view.history.beginUndoGrouping();controller.check();view.history.endUndoGrouping()
        assert(view.string == "☐ Find the keeper")
        view.textStorage!.setAttributedString(decoded);view.setSelectedRange(title)
        view.history.beginUndoGrouping();controller.setHeading("Heading 1");view.history.endUndoGrouping()
        assert((view.textStorage!.attribute(.font,at:title.location,effectiveRange:nil) as! NSFont).pointSize == 22)
        view.history.beginUndoGrouping();controller.clear();view.history.endUndoGrouping()
        assert(view.textStorage!.attribute(.link,at:title.location,effectiveRange:nil) == nil)
        view.history.undo();assert(view.textStorage!.attribute(.link,at:title.location,effectiveRange:nil) != nil)
        view.history.redo();assert(view.textStorage!.attribute(.link,at:title.location,effectiveRange:nil) == nil)
        // Formatting followed by replacement typing must undo as two independent edits.
        view.textStorage!.setAttributedString(decoded);view.setSelectedRange(title);view.history.removeAllActions();controller.refresh()
        view.history.beginUndoGrouping();controller.setHeading("Heading 1");view.history.endUndoGrouping()
        view.history.beginUndoGrouping();view.insertText("\n",replacementRange:title);view.breakUndoCoalescing();view.history.endUndoGrouping()
        assert(!view.string.contains("Moon gate"))
        view.history.undo()
        assert(view.string == source && (view.textStorage!.attribute(.font,at:title.location,effectiveRange:nil) as! NSFont).pointSize == 22)
        view.history.undo()
        assert(view.string == source && (view.textStorage!.attribute(.font,at:title.location,effectiveRange:nil) as! NSFont).pointSize == 13)
        var hero = Hero.sample
        let note = JournalEntry(title:"Gate",description:source,richText:rtf)
        hero.journalEntries = [note]
        try validate(Archive(heroes:[hero],library:[]))
        let saved = try JSONDecoder().decode(Hero.self,from:JSONEncoder().encode(hero))
        assert(saved.journalEntries!.first! == note)
        assert(JournalText.read(saved.journalEntries![0].richText,plain:source).attribute(.link,at:title.location,effectiveRange:nil) != nil)
        let legacy = try JSONDecoder().decode(JournalEntry.self,from:JSONSerialization.data(withJSONObject:["id":UUID().uuidString,"title":"Old note","description":source]))
        assert(legacy.description == source && legacy.richText == nil)
        hero.journalEntries![0].richText = Data(count:5_000_001)
        do { try validateContent(hero);fatalError("Oversized note accepted") } catch {}
        print("PASS: visual formatting/undo/redo, Unicode and RTF style/link round trips, plain fallback, lists/checklists/headings, legacy notes, backup validation")
    }
}
