import Foundation

struct EquipmentContainer:Codable,Identifiable,Equatable {
    var id = UUID()
    var name:String
}
extension Hero {
    var inventoryContainers:[EquipmentContainer] { equipmentContainers ?? [] }
    func inventoryWeight(in container:UUID?) -> Double { items.filter { $0.containerID == container }.reduce(0) { $0+Double($1.quantity)*$1.weight } }
    @discardableResult mutating func placeItem(_ itemID:UUID,in container:UUID?) -> Bool {
        guard container == nil || inventoryContainers.contains(where:{ $0.id == container }),let i = items.firstIndex(where:{ $0.id == itemID }) else { return false }
        items[i].containerID = container; return true
    }
    mutating func removeContainer(_ id:UUID) {
        for i in items.indices where items[i].containerID == id { items[i].containerID = nil }
        equipmentContainers?.removeAll { $0.id == id }
    }
    mutating func migrateEquipmentContainers() {
        guard equipmentContainers == nil else { return }
        var shells:[String:String] = [:]
        if let sourceXML,let root = try? XMLTree.parse(sourceXML) {
            let characters = root.name == "character" ? [root]:root.nodes("character")
            if let character = characters.first(where:{ $0.value("name") == name }) ?? (characters.count == 1 ? characters.first:nil) {
                for storage in character.nodes("container") {
                    let label = storage.value("label").isEmpty ? storage.value("name"):storage.value("label")
                    if !label.isEmpty { shells[label] = storage.value("name") }
                }
            }
        }
        func legacyLocation(_ item:Item) -> String? {
            item.notes.components(separatedBy:"\n").first { $0.hasPrefix("Container: ") }.map { String($0.dropFirst(11)).trimmingCharacters(in:.whitespacesAndNewlines) }
        }
        let labels = Set(items.compactMap(legacyLocation).filter { !$0.isEmpty && $0.count <= 120 }).union(shells.keys)
        equipmentContainers = labels.sorted().map { EquipmentContainer(name:$0) }
        for i in items.indices where items[i].containerID == nil {
            if let label = legacyLocation(items[i]),items[i].name != shells[label],let storage = inventoryContainers.first(where:{ $0.name == label }) { items[i].containerID = storage.id }
        }
    }
    var readyAttacks:[Attack] { attacks.filter { attackUnavailableReason($0) == nil } }
    var stowedAttacks:[Attack] { attacks.filter { attackUnavailableReason($0) != nil } }
}
func validateInventory(_ hero:Hero) throws {
    let containers = hero.inventoryContainers
    let ids = Set(containers.map(\.id))
    guard ids.count == containers.count,containers.allSatisfy({ !$0.name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && $0.name.count <= 120 }),hero.items.allSatisfy({ $0.containerID == nil || ids.contains($0.containerID!) }) else { throw CocoaError(.fileReadCorruptFile) }
}
