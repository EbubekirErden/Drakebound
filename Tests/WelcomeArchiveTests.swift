import Foundation

@main struct WelcomeArchiveTests {
    static func main() throws {
        let empty=Archive(heroes:[],library:starterSpells)
        try validate(empty)
        let restored=try JSONDecoder().decode(Archive.self,from:JSONEncoder().encode(empty));try validate(restored)
        assert(restored.heroes.isEmpty && restored.library == empty.library)
        let hero=Hero.sample;let legacy=Archive(heroes:[hero],library:starterSpells);try validate(legacy)
        var invalid=empty;invalid.version=999
        do { try validate(invalid);fatalError("Accepted unknown archive version") } catch { }
        do { try validate(Archive(heroes:[hero,hero],library:[]));fatalError("Accepted duplicate character IDs") } catch { }
        var malformed=hero;malformed.scores=[]
        do { try validate(Archive(heroes:[malformed],library:[]));fatalError("Accepted invalid hero") } catch { }
        print("Welcome archives: empty round trip/library preservation, legacy characters, version and character validation passed.")
    }
}
