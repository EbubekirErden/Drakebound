import AppKit
import Combine

final class JournalEditorController:ObservableObject {
    weak var view:NSTextView?
    @Published var bold = false
    @Published var italic = false
    @Published var strike = false
    @Published var heading = "Body"
    @Published var canUndo = false
    @Published var canRedo = false
    @Published var hasSelection = false
    @Published var selectedLink = ""
    func refresh() {
        guard let view else { return }
        let range = view.selectedRange()
        let attributes = range.length > 0 && range.location < view.textStorage!.length ? view.textStorage!.attributes(at:range.location,effectiveRange:nil):view.typingAttributes
        let font = attributes[.font] as? NSFont ?? JournalText.font
        let traits = NSFontManager.shared.traits(of:font)
        bold = traits.contains(.boldFontMask); italic = traits.contains(.italicFontMask)
        strike = (attributes[.strikethroughStyle] as? Int ?? 0) != 0
        heading = font.pointSize >= 21 ? "Heading 1":font.pointSize >= 17 ? "Heading 2":"Body"
        canUndo = view.undoManager?.canUndo ?? false; canRedo = view.undoManager?.canRedo ?? false
        hasSelection = range.length > 0
        selectedLink = (attributes[.link] as? URL)?.absoluteString ?? attributes[.link] as? String ?? ""
    }
    func commit(_ text:NSAttributedString,selection:NSRange,typing:[NSAttributedString.Key:Any]? = nil,affected:NSRange? = nil) {
        guard let view,let storage = view.textStorage else { return }
        view.breakUndoCoalescing()
        // Let AppKit register the edit, then apply exact attributes rather than inheriting a surrounding link.
        let range = affected ?? NSRange(location:0,length:storage.length)
        let replacement = NSRange(location:range.location,length:range.length+text.length-storage.length)
        let fragment = text.attributedSubstring(from:replacement)
        view.performValidatedReplacement(in:range,with:fragment)
        fragment.enumerateAttributes(in:NSRange(location:0,length:fragment.length)) { attributes,part,_ in
            storage.setAttributes(attributes,range:NSRange(location:range.location+part.location,length:part.length))
        }
        view.didChangeText()
        view.breakUndoCoalescing()
        view.window?.makeFirstResponder(view)
        if let typing { view.typingAttributes = typing }
        view.setSelectedRange(NSRange(location:min(selection.location,text.length),length:min(selection.length,max(0,text.length-selection.location))))
        refresh()
    }
    func trait(_ trait:NSFontTraitMask) {
        guard let view else { return }; view.window?.makeFirstResponder(view)
        let remove = trait == .boldFontMask ? bold:italic
        let transform:(NSFont)->NSFont = { remove ? NSFontManager.shared.convert($0,toNotHaveTrait:trait):NSFontManager.shared.convert($0,toHaveTrait:trait) }
        let range = view.selectedRange()
        if range.length == 0 { var attributes = view.typingAttributes; attributes[.font] = transform(attributes[.font] as? NSFont ?? JournalText.font); view.typingAttributes = attributes; refresh(); return }
        let text = NSMutableAttributedString(attributedString:view.attributedString())
        text.enumerateAttribute(.font,in:range) { font,part,_ in text.addAttribute(.font,value:transform(font as? NSFont ?? JournalText.font),range:part) }
        commit(text,selection:range,affected:range)
    }
    func toggleStrike() {
        guard let view else { return }; let range = view.selectedRange(); let value = strike ? 0:NSUnderlineStyle.single.rawValue
        if range.length == 0 { var attributes = view.typingAttributes; attributes[.strikethroughStyle] = value; view.typingAttributes = attributes; view.window?.makeFirstResponder(view); refresh(); return }
        let text = NSMutableAttributedString(attributedString:view.attributedString()); text.addAttribute(.strikethroughStyle,value:value,range:range); commit(text,selection:range,affected:range)
    }
    func setHeading(_ name:String) {
        guard let view else { return };view.window?.makeFirstResponder(view)
        let range = JournalText.paragraphs(view.string,selection:view.selectedRange())
        let size:CGFloat = name == "Heading 1" ? 22:name == "Heading 2" ? 18:JournalText.font.pointSize
        let font = NSFont.systemFont(ofSize:size,weight:name == "Body" ? .regular:.semibold)
        if range.length == 0 { view.typingAttributes = JournalText.attributes.merging([.font:font],uniquingKeysWith:{ _,new in new }); refresh(); return }
        let text = NSMutableAttributedString(attributedString:view.attributedString()); text.addAttribute(.font,value:font,range:range)
        commit(text,selection:view.selectedRange(),typing:JournalText.attributes.merging([.font:font],uniquingKeysWith:{ _,new in new }),affected:range)
    }
    func list(_ kind:String) {
        guard let view else { return }
        let result = JournalText.list(view.attributedString(),selection:view.selectedRange(),kind:kind)
        commit(result.0,selection:result.1,affected:JournalText.paragraphs(view.string,selection:view.selectedRange()))
    }
    func check() {
        guard let view else { return }
        let range = JournalText.paragraphs(view.string,selection:view.selectedRange())
        let text = NSMutableAttributedString(attributedString:view.attributedString())
        let ns = text.string as NSString
        var positions:[Int] = []; var position = range.location
        while position < NSMaxRange(range) {
            let paragraph = ns.paragraphRange(for:NSRange(location:position,length:0))
            if ns.substring(with:paragraph).hasPrefix("☐ ") || ns.substring(with:paragraph).hasPrefix("☑ ") { positions.append(position) }
            guard NSMaxRange(paragraph) > position else { break }; position = NSMaxRange(paragraph)
        }
        let complete = positions.contains { ns.substring(with:NSRange(location:$0,length:1)) == "☐" }
        for position in positions { text.replaceCharacters(in:NSRange(location:position,length:1),with:complete ? "☑":"☐") }
        if !positions.isEmpty { commit(text,selection:view.selectedRange(),affected:range) }
    }
    func setLink(_ url:URL?) {
        guard let view,view.selectedRange().length > 0 else { return }
        let text = NSMutableAttributedString(attributedString:view.attributedString());let range = view.selectedRange()
        if let url { text.addAttribute(.link,value:url,range:range) } else { text.removeAttribute(.link,range:range) }
        commit(text,selection:range,affected:range)
    }
    func clear() {
        guard let view else { return }; let range = view.selectedRange()
        if range.length == 0 { view.typingAttributes = JournalText.attributes; view.window?.makeFirstResponder(view); refresh(); return }
        let text = NSMutableAttributedString(attributedString:view.attributedString());text.setAttributes(JournalText.attributes,range:range);commit(text,selection:range,affected:range)
    }
    func undo() { view?.undoManager?.undo(); refresh() }
    func redo() { view?.undoManager?.redo(); refresh() }
}
class JournalTextView:NSTextView {
    override func didChangeText() {
        if let storage = textStorage { JournalText.ensureReadableColors(storage); JournalText.ensureReadableTypography(storage) }
        var attributes = typingAttributes
        attributes[.font] = JournalText.readableFont(attributes[.font] as? NSFont)
        attributes[.foregroundColor] = JournalText.readableColor(attributes[.foregroundColor] as? NSColor)
        typingAttributes = attributes
        super.didChangeText()
    }
    var shortcut:((String)->Void)?
    private var keyMonitor:Any?
    deinit { if let keyMonitor { NSEvent.removeMonitor(keyMonitor) } }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor);self.keyMonitor = nil }
        guard window != nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching:.keyDown) { [weak self] event in
            guard let self,self.window?.isKeyWindow == true,self.window?.firstResponder === self else { return event }
            return self.handleShortcut(event) ? nil:event
        }
    }
    private func handleShortcut(_ event:NSEvent) -> Bool {
        let raw = event.charactersIgnoringModifiers?.lowercased() ?? ""
        // Command-I also arrives as dotless i on a Turkish keyboard layout.
        let key = ["i","ı","i\u{307}"].contains(raw) || event.keyCode == 34 ? "i":raw
        if event.modifierFlags.contains(.command),!event.modifierFlags.contains(.option),!event.modifierFlags.contains(.control),["b","i"].contains(key) { shortcut?(key); return true }
        return false
    }
    override func performKeyEquivalent(with event:NSEvent) -> Bool {
        if window?.firstResponder === self,handleShortcut(event) { return true }
        return super.performKeyEquivalent(with:event)
    }
    override func keyDown(with event:NSEvent) {
        if handleShortcut(event) { return }
        super.keyDown(with:event)
    }
    override func insertNewline(_ sender:Any?) {
        let selection = selectedRange(),ns = string as NSString
        guard selection.length == 0 else { super.insertNewline(sender); return }
        let range = ns.paragraphRange(for:NSRange(location:selection.location,length:0))
        let line = ns.substring(with:range).trimmingCharacters(in:.newlines)
        guard let list = JournalText.listPrefix(line) else { super.insertNewline(sender); return }
        if list.body.isEmpty { insertText("",replacementRange:NSRange(location:range.location,length:(list.prefix as NSString).length)) }
        else { insertText("\n"+list.next,replacementRange:selection) }
    }
}
