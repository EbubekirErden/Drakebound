import AppKit
import PDFKit

@main struct CharacterPDFTests {
    static func main() throws {
        var hero = Hero.sample
        if CommandLine.arguments.count > 1 {
            let archive = try JSONDecoder().decode(Archive.self,from:Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1])))
            hero = archive.heroes.first { $0.name == "Shennie Dia" } ?? archive.heroes[0]
        }
        let before = hero
        let data = try CharacterPDF.data(for:hero)
        guard let document = PDFDocument(data:data) else { fatalError("Invalid PDF") }
        let text = document.string ?? ""
        assert(document.pageCount == 2 && text.contains(hero.name) && text.contains("SAVING THROWS") && text.contains("Skills".uppercased()))
        for spell in hero.spells { assert(text.contains(spell.name),"Missing spell: "+spell.name) }
        for item in hero.items { assert(text.contains(item.name),"Missing item: "+item.name) }
        assert(document.page(at:1)!.string!.contains("SPELLBOOK"))
        assert(hero == before)
        try FileManager.default.createDirectory(atPath:"output/pdf",withIntermediateDirectories:true)
        try data.write(to:URL(fileURLWithPath:"output/pdf/character-sheet.pdf"))
        var full = CharacterPDFOptions(); full.spellDescriptions = true; full.featureDescriptions = true; full.equipmentDescriptions = true
        let detailed = PDFDocument(data:try CharacterPDF.data(for:hero,options:full))!
        assert(detailed.pageCount > document.pageCount)
        try detailed.dataRepresentation()!.write(to:URL(fileURLWithPath:"build/pdf-full-reference-test.pdf"))
        var letter = CharacterPDFOptions(); letter.letter = true
        let letterPDF = PDFDocument(data:try CharacterPDF.data(for:hero,options:letter))!
        assert(letterPDF.pageCount == 2)
        for item in hero.items { assert(letterPDF.string!.contains(item.name),"Letter missing item: "+item.name) }
        for spell in hero.spells { assert(letterPDF.page(at:1)!.string!.contains(spell.name),"Spell missing from page two") }
        var packed=hero; packed.items=(0..<50).map { Item(name:"Inventory entry \($0)") }; packed.items.append(Item(name:"LastInventoryEntry"))
        var inventoryOptions=CharacterPDFOptions(); inventoryOptions.equipmentDescriptions=true
        let inventoryReference=PDFDocument(data:try CharacterPDF.data(for:packed,options:inventoryOptions))!
        assert(inventoryReference.string!.contains("LastInventoryEntry"))
        var crowded=hero; crowded.spells = (0..<200).map { Spell(name:"Test spell \($0)",level:$0%10) }
        let overflow=PDFDocument(data:try CharacterPDF.data(for:crowded))!
        assert(overflow.pageCount == 2 && overflow.string!.contains("additional spells"))
        if hero.name == "Shennie Dia" { assert(letterPDF.page(at:0)!.string!.contains("Staff"),"Overview attack spilled from Letter page") }
        var long = hero; long.journalEntries = [JournalEntry(title:"Long note",description:String(repeating:"Long-form text with Unicode: Şennie, déjà vu, dragon. ",count:1500)+"EndOfLongNoteToken")]
        var options = CharacterPDFOptions(); options.journal = true; options.letter = true
        let stress = PDFDocument(data:try CharacterPDF.data(for:long,options:options))!
        assert(stress.string!.contains("EndOfLongNoteToken"))
        assert(stress.pageCount > document.pageCount)
        try stress.dataRepresentation()!.write(to:URL(fileURLWithPath:"build/pdf-pagination-test.pdf"))
        for i in 0..<document.pageCount {
            let page = document.page(at:i)!
            let image = page.thumbnail(of:NSSize(width:900,height:1250),for:.mediaBox)
            let bitmap = NSBitmapImageRep(data:image.tiffRepresentation!)!
            try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:"build/pdf-page-\(i+1).png"))
        }
        let thumbSize = NSSize(width:300,height:424)
        let contact = NSImage(size:NSSize(width:900,height:CGFloat((document.pageCount+2)/3)*450))
        contact.lockFocus(); NSColor.lightGray.setFill(); NSBezierPath(rect:NSRect(origin:.zero,size:contact.size)).fill()
        for i in 0..<document.pageCount {
            let thumb = document.page(at:i)!.thumbnail(of:thumbSize,for:.mediaBox)
            let x=CGFloat(i%3)*300; let y=contact.size.height-CGFloat(i/3+1)*450+20
            thumb.draw(in:NSRect(x:x,y:y,width:300,height:424))
        }
        contact.unlockFocus()
        let bitmap = NSBitmapImageRep(data:contact.tiffRepresentation!)!
        try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:"build/pdf-contact-sheet.png"))
        print("PASS: PDF \(document.pageCount) pages; all spells/items, immutable export, A4/Letter, Unicode, and long-note pagination (\(stress.pageCount) pages)")
    }
}
