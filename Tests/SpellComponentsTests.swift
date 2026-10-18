import Foundation
@main struct SpellComponentsTests {
    static func main() {
        let original = "V, S, M (a diamond worth 300 gp, consumed)"
        let parsed = SpellComponents(original)
        assert(parsed.contains("V") && parsed.contains("S") && parsed.contains("M"))
        assert(parsed.parts.count == 3)
        let noS = parsed.setting("S",enabled:false)
        assert(noS == "V, M (a diamond worth 300 gp, consumed)")
        assert(SpellComponents(noS).setting("S",enabled:true) == original)
        let material = parsed.segment("M")
        let noM = parsed.setting("M",enabled:false)
        assert(noM == "V, S")
        assert(SpellComponents(noM).setting("M",enabled:true,restored:material) == original)
        assert(SpellComponents("").setting("S",enabled:true) == "S")
        assert(SpellComponents("v, s").contains("V"))
        assert(SpellComponents("V, Special requirement").setting("V",enabled:false) == "Special requirement")
        print("Spell component preservation checks passed")
    }
}
