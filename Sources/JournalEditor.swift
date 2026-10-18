import SwiftUI
import AppKit

struct NativeJournalEditor:NSViewRepresentable {
    @Binding var entry:JournalEntry
    @ObservedObject var controller:JournalEditorController
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context:Context) -> NSScrollView {
        let scroll = NSScrollView();scroll.hasVerticalScroller = true;scroll.drawsBackground = false;scroll.borderType = .noBorder
        let view = JournalTextView(frame:.zero)
        view.isRichText = true;view.importsGraphics = false;view.allowsUndo = true;view.drawsBackground = false;view.isAutomaticLinkDetectionEnabled = false
        view.isAutomaticQuoteSubstitutionEnabled = false;view.isAutomaticDashSubstitutionEnabled = false
        view.minSize = NSSize(width:0,height:0);view.maxSize = NSSize(width:CGFloat.greatestFiniteMagnitude,height:CGFloat.greatestFiniteMagnitude)
        view.isVerticallyResizable = true;view.isHorizontallyResizable = false;view.autoresizingMask = .width
        view.textContainer?.containerSize = NSSize(width:0,height:CGFloat.greatestFiniteMagnitude);view.textContainer?.widthTracksTextView = true
        view.textContainerInset = NSSize(width:8,height:10);view.textColor = JournalText.color;view.insertionPointColor = .white
        view.typingAttributes = JournalText.attributes
        view.textStorage?.setAttributedString(JournalText.read(entry.richText,plain:entry.description));view.delegate = context.coordinator
        view.setAccessibilityLabel("Journal note body")
        view.shortcut = { key in controller.trait(key == "b" ? .boldFontMask:.italicFontMask) }
        scroll.documentView = view;controller.view = view;context.coordinator.lastText = entry.description;context.coordinator.lastData = entry.richText
        return scroll
    }
    func updateNSView(_ scroll:NSScrollView,context:Context) {
        context.coordinator.parent = self
        guard let view = scroll.documentView as? NSTextView else { return }
        if entry.description != context.coordinator.lastText || entry.richText != context.coordinator.lastData {
            let selection = view.selectedRange();view.textStorage?.setAttributedString(JournalText.read(entry.richText,plain:entry.description))
            view.setSelectedRange(NSRange(location:min(selection.location,view.string.utf16.count),length:0));view.undoManager?.removeAllActions()
            context.coordinator.lastText = entry.description;context.coordinator.lastData = entry.richText
        }
    }
    final class Coordinator:NSObject,NSTextViewDelegate {
        var parent:NativeJournalEditor;var lastText = "";var lastData:Data?
        init(_ parent:NativeJournalEditor) { self.parent = parent }
        func textDidChange(_ notification:Notification) {
            guard let view = notification.object as? NSTextView,let data = JournalText.write(view.attributedString()),data.count <= 5_000_000 else { return }
            var entry = parent.entry;entry.description = view.string;entry.richText = data
            lastText = entry.description;lastData = data;parent.entry = entry;parent.controller.refresh()
        }
        func textViewDidChangeSelection(_ notification:Notification) { parent.controller.refresh() }
    }
}
struct JournalRichEditor:View {
    @Binding var entry:JournalEntry
    @StateObject private var controller = JournalEditorController()
    @State private var linking = false
    @State private var address = ""
    var body:some View {
        VStack(spacing:0) {
            ScrollView(.horizontal,showsIndicators:false) {
                HStack(spacing:4) {
                    Picker("Paragraph style",selection:Binding(get:{ controller.heading },set:{ controller.setHeading($0) })) { ForEach(["Body","Heading 1","Heading 2"],id:\.self) { Text($0).tag($0) } }.labelsHidden().frame(width:105).accessibilityLabel("Journal paragraph style")
                    Divider().frame(height:16)
                    tool("Bold","bold",active:controller.bold) { controller.trait(.boldFontMask) }.help("Bold · ⌘B")
                    tool("Italic","italic",active:controller.italic) { controller.trait(.italicFontMask) }.help("Italic · ⌘I")
                    tool("Strikethrough","strikethrough",active:controller.strike) { controller.toggleStrike() }
                    Divider().frame(height:16)
                    tool("Bulleted list","list.bullet") { controller.list("bullet") }
                    tool("Numbered list","list.number") { controller.list("number") }
                    tool("Checklist","checklist") { controller.list("check") }
                    tool("Toggle checklist completion","checkmark.circle") { controller.check() }
                    Divider().frame(height:16)
                    tool("Link","link",active:!controller.selectedLink.isEmpty) { address = controller.selectedLink;linking = true }.disabled(!controller.hasSelection)
                        .popover(isPresented:$linking) {
                            VStack(alignment:.leading,spacing:10) {
                                Text("Link selected text").font(.headline)
                                TextField("https://… or mailto:…",text:$address).textFieldStyle(.roundedBorder).accessibilityLabel("Journal link address")
                                HStack { Button("Remove link") { controller.setLink(nil);linking = false };Spacer();Button("Apply") { if let url = JournalText.link(address) { controller.setLink(url);linking = false } }.disabled(JournalText.link(address) == nil) }
                            }.padding(16).frame(width:320)
                        }
                    tool("Clear formatting","textformat") { controller.clear() }
                    Divider().frame(height:16)
                    tool("Undo","arrow.uturn.backward") { controller.undo() }.disabled(!controller.canUndo)
                    tool("Redo","arrow.uturn.forward") { controller.redo() }.disabled(!controller.canRedo)
                }.padding(.horizontal,6).frame(height:32)
            }.frame(height:32).background(ink.opacity(0.025))
            Rectangle().fill(ink.opacity(0.08)).frame(height:1)
            NativeJournalEditor(entry:$entry,controller:controller).frame(height:210)
        }.background(paper.opacity(0.7)).clipShape(RoundedRectangle(cornerRadius:7)).overlay(RoundedRectangle(cornerRadius:7).stroke(ink.opacity(0.12)))
    }
    func tool(_ title:String,_ icon:String,active:Bool = false,action:@escaping()->Void) -> some View {
        Button(action:action) { Image(systemName:icon).font(.system(size:11,weight:.medium)).frame(width:27,height:25).foregroundStyle(active ? accent:ink.opacity(0.8)).background(active ? accent.opacity(0.12):Color.clear).clipShape(RoundedRectangle(cornerRadius:4)) }.buttonStyle(.plain).accessibilityLabel(title).accessibilityValue(active ? "On":"Off").help(title)
    }
}
