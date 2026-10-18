import Foundation
@main struct DiceDraftTests {
    static func main() throws {
        var d=DiceDraft(expression:"");d.digit(2);d.die(6);d.operation("+");d.digit(3)
        assert(d.expression == "2d6+3")
        assert(d.summary() == DiceFormulaSummary(resolved:"2d6+3",minimum:5,maximum:15,average:10))
        var sequence=DiceDraft(expression:"2+");sequence.die(8);assert(sequence.expression == "2+1d8")
        sequence.operation("-");sequence.digit(3);assert(sequence.expression == "2+1d8-3")
        assert(DiceDraft(expression:"1d6++3").summary() == nil)
        d.die(8);assert(d.expression == "2d6+3d8")
        d.operation("-");d.token("str")
        let hero=Hero.sample,before=Hero.sample
        assert(d.summary(hero:hero,allowTokens:true)?.resolved == "2d6+3d8+1")
        assert(d.summary(hero:hero) == nil)
        d.backspace();assert(d.expression == "2d6+3d8-");d.backspace();d.backspace();assert(d.expression == "2d6+")
        var a=DiceDraft(expression:"1d8");a.digit(4);assert(a.expression == "1d8+4");a.toggleSign();assert(a.expression == "1d8-4")
        a.operation("+");a.operation("-");assert(a.expression == "1d8-4-")
        assert(DiceDraft(expression:"2d6-1d4-3").summary() == DiceFormulaSummary(resolved:"2d6-1d4-3",minimum:-5,maximum:8,average:1.5))
        for bad in ["", "1d1","101d6","1d1001","1d6+","1d6*2","(1d6)","{missing}","100001","1d6junk"] { assert(DiceDraft(expression:bad).summary(hero:hero,allowTokens:true) == nil,bad) }
        let spell=Spell(name:"Wisdom",level:3,castingAbility:4)
        assert(DiceDraft(expression:"1d8+{spell}+{slot}").summary(hero:hero,spell:spell,slot:3,allowTokens:true)?.resolved == "1d8+1+3")
        let imported=" 2D6 + 3 ";let original=DiceDraft(expression:imported);assert(original.summary()?.resolved == "2d6+3" && original.expression == imported)
        assert(hero.scores == before.scores && hero.hp == before.hp)
        print("PASS: button composition, token context, negative modifiers, pure range/average preview, sign/delete, custom die limits, invalid input, and imported formula preservation")
    }
}
