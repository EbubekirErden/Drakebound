package com.drakebound.android.draft

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.IntRect
import androidx.compose.ui.layout.boundsInWindow
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.unit.round
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.core.view.WindowCompat
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            val vm: DraftViewModel = viewModel()
            SideEffect {
                WindowCompat.getInsetsController(window, window.decorView).apply {
                    isAppearanceLightStatusBars = false
                    isAppearanceLightNavigationBars = false
                }
            }
            InkTheme(vm.dark) { Drakebound(vm) }
        }
    }
}

private val InkDark = darkColorScheme(
    primary = Color(0xFFDDA37D), onPrimary = Color(0xFF2E1D13), primaryContainer = Color(0xFF493329), onPrimaryContainer = Color(0xFFFFDCC4),
    background = Color(0xFF11151A), onBackground = Color(0xFFFFF3E7), surface = Color(0xFF303942), onSurface = Color(0xFFFFF3E7),
    surfaceVariant = Color(0xFF252D35), onSurfaceVariant = Color(0xFFC5C5C7), outline = Color(0xFF566575), outlineVariant = Color(0xFF424E5A),
    secondaryContainer = Color(0xFF3E4852), onSecondaryContainer = Color(0xFFECE5DE), error = Color(0xFFFFB3BA)
)
private val InkLight = lightColorScheme(
    primary = Color(0xFF95512F), onPrimary = Color(0xFFFFF9F1), primaryContainer = Color(0xFFEED9C9), onPrimaryContainer = Color(0xFF4D2918),
    background = Color(0xFFF1E8D8), onBackground = Color(0xFF242321), surface = Color(0xFFF6EFE3), onSurface = Color(0xFF242321),
    surfaceVariant = Color(0xFFE7DDCB), onSurfaceVariant = Color(0xFF635F55), outline = Color(0xFF8B8172), outlineVariant = Color(0xFFD2C8B6),
    secondaryContainer = Color(0xFFE4D1BC), onSecondaryContainer = Color(0xFF4D2918)
)
private val JournalType = Typography(bodyMedium = androidx.compose.ui.text.TextStyle(fontSize = 13.sp, lineHeight = 19.sp), bodySmall = androidx.compose.ui.text.TextStyle(fontSize = 11.sp, lineHeight = 16.sp), labelSmall = androidx.compose.ui.text.TextStyle(fontSize = 11.sp, lineHeight = 15.sp))
@Composable fun InkTheme(dark: Boolean, content: @Composable () -> Unit) { MaterialTheme(colorScheme = if (dark) InkDark else InkLight, typography = JournalType, content = content) }

private val sections = listOf("Play", "Sheet", "Spells", "Gear", "Journal")

@Composable
fun Drakebound(vm: DraftViewModel) {
    var page by rememberSaveable { mutableStateOf("Home") }
    var dialog by rememberSaveable { mutableStateOf<String?>(null) }
    var info by rememberSaveable { mutableStateOf<String?>(null) }
    var result by remember { mutableStateOf<DiceRoll?>(null) }
    var sequence by remember { mutableIntStateOf(0) }
    var resultAnchor by remember { mutableStateOf<IntRect?>(null) }
    var calculatorAnchor by remember { mutableStateOf<IntRect?>(null) }
    var toolbarDiceBounds by remember { mutableStateOf(IntRect.Zero) }
    val drawer = rememberDrawerState(DrawerValue.Closed)
    val scope = rememberCoroutineScope()
    val hero = vm.hero
    fun navigate(p: String) { page = p; dialog = null; result = null; scope.launch { drawer.close() } }
    fun roll(formula: String, label: String, mode: RollMode = RollMode.Normal, anchor: IntRect? = null) {
        runCatching { DiceEngine.roll(formula, label, mode) }.onSuccess { vm.record(it); result = it; resultAnchor = anchor; sequence++; dialog = null }.onFailure { info = it.message }
    }
    fun adjustSlot(level: Int, delta: Int) { vm.change("Level $level slot adjusted") { h -> when (level) {
        1 -> h.copy(slots = (h.slots + delta).coerceIn(0, 4))
        2 -> h.copy(secondSlots = (h.secondSlots + delta).coerceIn(0, 3))
        else -> h.copy(thirdSlots = (h.thirdSlots + delta).coerceIn(0, 2))
    } } }
    BackHandler(drawer.isOpen || page != "Home") { if (drawer.isOpen) scope.launch { drawer.close() } else if (page in sections) { vm.selected = null; page = "Home" } else page = if (hero != null) "Play" else "Home" }
    ModalNavigationDrawer(drawerState = drawer, gesturesEnabled = hero != null, drawerContent = {
        ModalDrawerSheet(drawerContainerColor = MaterialTheme.colorScheme.surface, modifier = Modifier.widthIn(max = 320.dp)) {
            Column(Modifier.verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(hero?.name ?: "Drakebound", style = MaterialTheme.typography.titleLarge)
                Text(hero?.let { "${it.role} ${it.level}" } ?: "Android draft", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                DrawerLink("All characters", Icons.Default.Person) { vm.selected = null; navigate("Home") }
                HorizontalDivider(Modifier.padding(vertical = 8.dp))
                if (hero?.role?.contains("Wizard") == true) {
                    SectionLabel("COMPANIONS")
                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                        Surface(shape = RoundedCornerShape(10.dp), color = MaterialTheme.colorScheme.background) { Text("N", Modifier.padding(12.dp), color = MaterialTheme.colorScheme.primary) }
                        TextButton(onClick = { navigate("Nyx") }, modifier = Modifier.weight(1f)) { Text("Nyx · Owl familiar") }
                    }
                    TextButton(onClick = { info = "Companion creation will follow the first playable draft." }) { Text("+ Add companion") }
                    HorizontalDivider(Modifier.padding(vertical = 8.dp))
                }
                DrawerLink("Compendium", Icons.Default.Search) { navigate("Compendium") }
                DrawerLink("Activity history", Icons.Default.DateRange) { navigate("Activity") }
                HorizontalDivider(Modifier.padding(vertical = 8.dp))
                DrawerLink("Edit character", Icons.Default.Edit) { navigate("Edit character") }
                DrawerLink("Level up", Icons.Default.Add) { navigate("Level up") }
                DrawerLink("Import / export", Icons.Default.Share) { navigate("Transfer") }
                HorizontalDivider(Modifier.padding(vertical = 8.dp))
                DrawerLink("Settings", Icons.Default.Settings) { navigate("Settings") }
                Text("Sample data · Android sandbox only", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 12.dp))
            }
        }
    }) {
        Scaffold(containerColor = MaterialTheme.colorScheme.background, topBar = {
            InkTheme(true) { Surface(color = MaterialTheme.colorScheme.background) {
                Column {
                Row(Modifier.statusBarsPadding().fillMaxWidth().heightIn(min = 64.dp).padding(horizontal = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                    if (page != "Home") IconButton(onClick = { if (page in sections) scope.launch { drawer.open() } else navigate(if (hero != null) "Play" else "Home") }) {
                        Icon(if (page in sections) Icons.Default.Menu else Icons.AutoMirrored.Filled.ArrowBack, if (page in sections) "Open menu" else "Back")
                    }
                    Column(Modifier.weight(1f).padding(start = if (page == "Home") 10.dp else 0.dp)) {
                        Text(if (page in sections && hero != null) hero.name else if (page == "Home") "Drakebound" else page, fontSize = 24.sp, fontFamily = FontFamily.Serif)
                        Text(if (hero != null && page in sections) "${hero.role} ${hero.level}" else "Android draft · Field journal", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    if (hero != null) TextButton(onClick = { calculatorAnchor = toolbarDiceBounds; dialog = "dice" }, modifier = Modifier.onGloballyPositioned { val r = it.boundsInWindow(); toolbarDiceBounds = IntRect(r.topLeft.round(), r.bottomRight.round()) }) { Text("d20", fontWeight = FontWeight.Medium) }
                    IconButton(onClick = { navigate(if (page == "Home") "Settings" else "Compendium") }) { Icon(if (page == "Home") Icons.Default.Settings else Icons.Default.Search, if (page == "Home") "Settings" else "Search compendium") }
                }
                Box(Modifier.fillMaxWidth().height(3.dp).background(MaterialTheme.colorScheme.primary))
                }
            } }
        }, bottomBar = {
            if (page in sections && hero != null) InkTheme(true) { AdventureNavigation(page, vm.reduceMotion) { navigate(it) } }
        }) { padding ->
            Column(Modifier.padding(padding).fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
                if (vm.saving) LinearProgressIndicator(Modifier.fillMaxWidth())
                key(page, hero?.id) { Column(Modifier.widthIn(max = 700.dp).fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 9.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    if (vm.error != null) Surface(color = MaterialTheme.colorScheme.errorContainer, shape = RoundedCornerShape(12.dp)) { Text(vm.error!!, Modifier.padding(12.dp), color = MaterialTheme.colorScheme.onErrorContainer) }
                    if (page == "Home" || (hero == null && page != "Settings")) {
                        Text("Characters", fontFamily = FontFamily.Serif, fontSize = 32.sp)
                        SectionLabel("YOUR COMPANY", "${vm.heroes.size} characters · Offline")
                        vm.heroes.forEachIndexed { index, h -> RosterEntry(h, index) { vm.selected = h.id; navigate("Play") } }
                        Row(Modifier.padding(top = 12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Button(onClick = { info = "This first build uses two fictional characters. Guided creation is planned after the play controls." }, modifier = Modifier.weight(1f), shape = RoundedCornerShape(4.dp)) { Text("New character") }
                            OutlinedButton(onClick = { info = "Mac JSON import is not connected in this draft. Your real characters remain separate." }, modifier = Modifier.weight(1f), shape = RoundedCornerShape(4.dp)) { Text("Import") }
                        }
                        Subtle("Native Android prototype · Changes to these samples are saved only inside this app.")
                    } else if (page == "Settings") {
                        SectionLabel("APPEARANCE")
                        Panel { SettingToggle("Dark Field journal", vm.dark) { vm.dark = it }; SettingToggle("Reduce dice motion", vm.reduceMotion) { vm.reduceMotion = it } }
                        SectionLabel("DICE")
                        Panel { SettingToggle("Haptic feedback", vm.haptics) { vm.haptics = it }; Subtle("System animation settings are also respected. Dice results are generated once; the animation reveals them.") }
                        Panel { Text("About this draft", style = MaterialTheme.typography.titleMedium); Subtle("Real Android controls, random dice and isolated sample saves. Import, complete leveling, full reference content and production data storage are future work.") }
                    } else if (hero != null) {
                        val wizard = hero.role.contains("Wizard")
                        when (page) {
                            "Play" -> {
                                AdventureVitals(hero, vm.reduceMotion, vm.saving, onHp = { dialog = "hp" }, onRest = { dialog = "rest" }, onInitiative = { anchor -> roll(if (wizard) "1d20+3" else "1d20+1", "Initiative", anchor = anchor) })
                                Row(Modifier.fillMaxWidth().padding(vertical = 2.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(9.dp)) {
                                    Box(Modifier.width(2.dp).height(26.dp).background(if (hero.concentrating) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outlineVariant))
                                    Text(if (hero.concentrating) "Concentrating · Web" else "No concentration", Modifier.weight(1f), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    TextButton(onClick = { dialog = "conditions" }, shape = RoundedCornerShape(3.dp)) { Text("Conditions", fontSize = 12.sp) }
                                }
                                if (hero.conditions.isNotEmpty()) Subtle(hero.conditions.joinToString(" · "))
                                SectionLabel("READY ACTIONS", "Hit  /  Damage")
                                Column {
                                    AdventureAttack(if (wizard) "Quarterstaff" else "Greatsword", "Melee · 5 ft", if (wizard) "+2" else "+5", if (wizard) "1d6−1" else "2d6+3", { anchor -> roll(if (wizard) "1d20+2" else "1d20+5", "Weapon attack", anchor = anchor) }, { anchor -> roll(if (wizard) "1d6-1" else "2d6+3", "Weapon damage", anchor = anchor) })
                                    if (wizard) AdventureAttack("Fire Bolt", "Cantrip · 120 ft", "+7", "2d10", { anchor -> roll("1d20+7", "Fire Bolt attack", anchor = anchor) }, { anchor -> roll("2d10", "Fire Bolt damage", anchor = anchor) })
                                }
                                if (wizard) {
                                    SlotTable(hero, vm.saving, ::adjustSlot)
                                    ActionRow("Arcane Recovery", "Once per long rest", "${hero.recovery}/1", { dialog = "recovery" })
                                    FamiliarLink(hero.companionHp) { navigate("Nyx") }
                                }
                                SourceButton("Dice calculator · Custom roll", modifier = Modifier.fillMaxWidth()) { anchor -> calculatorAnchor = anchor; dialog = "dice" }
                                vm.rolls.firstOrNull()?.let { recent -> SourceButton("${recent.label} · ${recent.total}") { anchor -> resultAnchor = anchor; result = recent; sequence++ } }
                            }
                            "Sheet" -> {
                                CompactAbilities(wizard) { formula, label, anchor -> roll(formula, label, anchor = anchor) }
                                ActionRow("Wisdom save", "Saving throw", "+4", { roll("1d20+4", "Wisdom save") })
                                Panel { ActionRow("Identity", "Name and character details", "Edit", { navigate("Edit character") }); HorizontalDivider(); ActionRow("Advancement", "Review the level-up flow", "Level up", { navigate("Level up") }) }
                                Subtle("These sample statistics are fixed for layout and dice testing. Full rules parity is a later milestone.")
                            }
                            "Spells" -> if (!wizard) Panel { Text("No spellcasting", style = MaterialTheme.typography.titleMedium); Subtle("This fighter sample has no spells. Switch to Lyra to try casting.") } else {
                                Subtle("Spell save DC 15 · Attack +7")
                                SlotTable(hero, vm.saving, ::adjustSlot)
                                SectionLabel("CANTRIPS")
                                ReferenceRow("Fire Bolt", "Action · 120 ft · V, S", "A bolt of fire aimed at a creature or object. This sample rolls a spell attack and fire damage separately.") {
                                    SourceButton("+7", "Fire Bolt spell attack") { anchor -> roll("1d20+7", "Fire Bolt attack", anchor = anchor) }
                                    SourceButton("2d10", "Fire Bolt spell damage") { anchor -> roll("2d10", "Fire Bolt damage", anchor = anchor) }
                                }
                                SectionLabel("1ST LEVEL")
                                ReferenceRow("Magic Missile", "Action · 120 ft · V, S", "Three darts of magical force. Cast spends one 1st-level slot and rolls damage immediately. This draft rolls each dart separately.") {
                                    SourceButton(if (hero.slots > 0) "Cast · 1st" else "No slots", "Cast Magic Missile using one first-level slot", enabled = hero.slots > 0 && !vm.saving) { anchor ->
                                        vm.change("Magic Missile · 1st-level slot spent", onSaved = { roll("3d4+3", "Magic Missile damage", anchor = anchor) }) { h -> h.copy(slots = (h.slots - 1).coerceAtLeast(0)) }
                                    }
                                }
                                SectionLabel("2ND LEVEL")
                                ReferenceRow("Web", "Action · Concentration · V, S, M", "A mass of sticky webbing fills an area, obstructing movement and potentially restraining creatures. This draft provides a reference; the full saving-throw and condition automation is still planned.")
                                SectionLabel("3RD LEVEL")
                                ReferenceRow("Counterspell", "Reaction · 60 ft · S", "Attempt to interrupt a creature casting a spell. This entry is a sample reference; reaction casting and ability-check resolution are not connected yet.")
                            }
                            "Gear" -> {
                                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { Stat("Gold", "${hero.gold}", Modifier.weight(1f)) { dialog = "gold" }; Stat("Potions", "${hero.potions}", Modifier.weight(1f)) { dialog = "potions" } }
                                SectionLabel("EQUIPMENT")
                                val weapon = if (wizard) "Quarterstaff" else "Greatsword"
                                ReferenceRow(weapon, "${if (wizard) "Simple" else "Martial"} melee weapon", if (wizard) "A sturdy staff used as a walking aid or a close-range weapon. The sample damage roll is 1d6−1 bludgeoning." else "A large two-handed blade. The sample damage roll is 2d6+3 slashing.") { EquippedDiamond(weapon, hero.staffEquipped, vm.saving) { vm.change("Equipment toggled") { it.copy(staffEquipped = !it.staffEquipped) } } }
                                ReferenceRow("Healing Potion", "${hero.potions} remaining · 2d4+2", "Drink to restore 2d4+2 hit points up to your maximum. Confirming use consumes one potion and saves the healing and quantity together.") { TextButton(onClick = { if (hero.potions > 0) dialog = "potion" else info = "No potions remaining" }) { Text("Use", fontSize = 12.sp) } }
                                if (wizard) ReferenceRow("Spellbook", "Spellcasting equipment", "Lyra’s collected spell diagrams, copied incantations, and personal arcane notes.")
                            }
                            "Journal" -> {
                                CompactJournal(hero.note) { dialog = "note" }
                            }
                            "Nyx" -> {
                                Panel { Text("Nyx", style = MaterialTheme.typography.headlineSmall); Subtle("Owl familiar · Tiny beast") }
                                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { Stat("HP", "${hero.companionHp}/1", Modifier.weight(1f)) { dialog = "companionHp" }; Stat("AC", "11", Modifier.weight(1f)); Stat("Fly", "60 ft", Modifier.weight(1f)) }
                                Panel { ActionRow("Talons", "Melee · 5 ft", "+3", { roll("1d20+3", "Nyx · Talons") }); HorizontalDivider(); Text("Flyby", style = MaterialTheme.typography.titleSmall); Subtle("The owl does not provoke opportunity attacks when it flies out of an enemy's reach.") }
                            }
                            "Compendium" -> ReferenceScreen { title -> info = "$title · Compact reference preview. The full offline SRD library will be connected in a later milestone." }
                            "Activity" -> { SectionLabel("THIS SESSION"); if (vm.history.isEmpty()) Subtle("Roll dice or adjust a character to see activity here."); vm.history.forEach { event -> Panel { Text(event, style = MaterialTheme.typography.bodyMedium) } }; Subtle("Session history is kept in memory in this first draft.") }
                            "Edit character" -> NameEditor(hero, vm.saving, onSave = { name -> vm.change("Character renamed", onSaved = { navigate("Sheet") }) { it.copy(name = name) } }, onCancel = { navigate("Sheet") })
                            "Level up" -> { Panel { Text("${hero.role.substringAfter('·').trim()} ${hero.level} → ${hero.level + 1}", style = MaterialTheme.typography.titleLarge); Subtle("Level-up draft · Review before applying") }; Panel { ActionRow("Hit points", "Choose fixed or rolled HP", "Review", { info = "HP advancement choices will be implemented with the full level-up guide." }); HorizontalDivider(); ActionRow("Features & choices", "Class-specific selection", "Review", { info = "Feature selection is planned after the play prototype." }) }; Subtle("Level-up is a layout preview. No character levels are changed in this build."); OutlinedButton(onClick = { navigate("Sheet") }) { Text("Back to sheet") } }
                            "Transfer" -> Panel { Text("Character transfer", style = MaterialTheme.typography.titleLarge); Text("Mac JSON import/export is planned. This build only uses fictional Android samples."); Subtle("There is no connection to the Mac save folder and no cloud sync.") }
                        }
                    }
                } }
            }
        }
    }
    if (dialog == "dice") DiceCalculator(onDismiss = { dialog = null }) { formula, mode -> roll(formula, "Custom roll", mode, calculatorAnchor) }
    if (hero != null) {
        if (dialog in listOf("hp", "gold", "potions", "companionHp")) {
            val purpose = dialog
            AmountDialog(title = when (purpose) { "gold" -> "Gold calculator"; "potions" -> "Potion quantity"; "companionHp" -> "Nyx · Hit points"; else -> "Hit point calculator" }, latestRoll = vm.rolls.firstOrNull()?.total,
                preview = { n, action -> when (purpose) {
                    "gold" -> "Gold ${hero.gold} → ${if (action == "Add") hero.gold.toLong() + n else hero.gold.toLong() - n}"
                    "potions" -> "Quantity ${hero.potions} → $n"
                    "companionHp" -> "HP ${hero.companionHp} → ${if (action == "Damage") (hero.companionHp - n).coerceAtLeast(0) else (hero.companionHp.toLong() + n).coerceAtMost(1)}"
                    else -> when (action) {
                        "Damage" -> "HP ${hero.health.current} → ${hero.health.damage(n).current} · Temp ${hero.health.temporary} → ${hero.health.damage(n).temporary}"
                        "Heal" -> "HP ${hero.health.current} → ${hero.health.heal(n).current} / ${hero.health.maximum}"
                        else -> "Temporary HP ${hero.health.temporary} → $n · replaces current amount"
                    }
                } },
                actions = when (purpose) { "gold" -> listOf("Add", "Spend"); "potions" -> listOf("Set quantity"); "companionHp" -> listOf("Damage", "Heal"); else -> listOf("Damage", "Heal", "Set temp HP") }, saving = vm.saving,
                onDismiss = { dialog = null }, onApply = { n, action ->
                    if (purpose == "gold" && action == "Spend" && n > hero.gold) info = "Not enough gold"
                    else if (purpose == "gold" && action == "Add" && hero.gold.toLong() + n > 1000000) info = "Balance limit is 1,000,000 in this draft"
                    else vm.change("$action · $n", onSaved = { dialog = null }) { h -> when (purpose) {
                        "gold" -> h.copy(gold = h.gold + if (action == "Add") n else -n)
                        "potions" -> h.copy(potions = n)
                        "companionHp" -> h.copy(companionHp = if (action == "Damage") (h.companionHp - n).coerceAtLeast(0) else (h.companionHp.toLong() + n).coerceAtMost(1).toInt())
                        else -> h.copy(health = when (action) { "Damage" -> h.health.damage(n); "Heal" -> h.health.heal(n); else -> h.health.copy(temporary = n) })
                    } }
                })
        }
        if (dialog == "potion") DraftSheet(onDismiss = { dialog = null }) { Text("Healing potion", fontFamily = FontFamily.Serif, fontSize = 24.sp); Text("Restore 2d4+2 HP, capped at your maximum. Uses one of your ${hero.potions} potions.", fontSize = 13.sp); Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) { TextButton(onClick = { dialog = null }) { Text("Cancel") }; Button(enabled = hero.potions > 0 && !vm.saving, shape = RoundedCornerShape(3.dp), onClick = {
            val healing = DiceEngine.roll("2d4+2", "Healing potion")
            vm.change("Healing potion · +${healing.total} HP", onSaved = { vm.record(healing); resultAnchor = null; result = healing; sequence++; dialog = null }) { it.copy(potions = it.potions - 1, health = it.health.heal(healing.total)) }
        }) { Text("Drink potion") } } }
        if (dialog == "rest") RestSheet(hero, vm.saving, onDismiss = { dialog = null }) { vm.change("Long rest", onSaved = { dialog = null }) { it.copy(health = Health(it.health.maximum, it.health.maximum), slots = if (it.role.contains("Wizard")) 4 else 0, secondSlots = if (it.role.contains("Wizard")) 3 else 0, thirdSlots = if (it.role.contains("Wizard")) 2 else 0, recovery = 1) } }
        if (dialog == "recovery") DraftSheet(onDismiss = { dialog = null }) { Text("Arcane Recovery", fontFamily = FontFamily.Serif, fontSize = 24.sp); Text("1st-level slots: ${hero.slots} → ${minOf(4, hero.slots + 2)} · Uses ${hero.recovery}/1", fontSize = 13.sp); Subtle("This sample recovers up to two 1st-level slots. The full short-rest flow is planned."); Button(enabled = hero.recovery > 0 && hero.slots < 4 && !vm.saving, shape = RoundedCornerShape(3.dp), onClick = { vm.change("Arcane Recovery", onSaved = { dialog = null }) { it.copy(slots = minOf(4, it.slots + 2), recovery = 0) } }) { Text("Recover slots") } }
        if (dialog == "conditions") DraftSheet(onDismiss = { dialog = null }) { Text("Conditions", fontFamily = FontFamily.Serif, fontSize = 24.sp); Column { listOf("Prone", "Poisoned", "Frightened", "Restrained").forEach { c -> Row(verticalAlignment = Alignment.CenterVertically) { Checkbox(checked = c in hero.conditions, enabled = !vm.saving, onCheckedChange = { checked -> vm.change("Condition · $c") { it.copy(conditions = if (checked) it.conditions + c else it.conditions - c) } }); Text(c, fontSize = 13.sp) } }; if (hero.concentrating) TextButton(onClick = { vm.change("Concentration ended") { it.copy(concentrating = false) } }) { Text("End concentration") }; Subtle("Tracking only in this draft; conditions do not yet alter rolls.") }; TextButton(onClick = { dialog = null }, modifier = Modifier.align(Alignment.End)) { Text("Done") } }
        if (dialog == "note") NoteEditor(hero.note, vm.saving, onDismiss = { dialog = null }) { note -> vm.change("Journal saved", onSaved = { dialog = null }) { it.copy(note = note) } }
    }
    result?.let { r -> DiceResultDialog(r, sequence, vm.reduceMotion, vm.haptics, anchor = resultAnchor, onDismiss = { result = null }, onAgain = { roll(r.formula, r.label, r.mode, resultAnchor) }) }
    info?.let { text -> AlertDialog(onDismissRequest = { info = null }, title = { Text("Drakebound draft") }, text = { Text(text) }, confirmButton = { TextButton(onClick = { info = null }) { Text("OK") } }) }
}

@Composable private fun Subtle(text: String) { Text(text, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
@Composable private fun SectionLabel(text: String, detail: String = "") { Column(Modifier.fillMaxWidth().padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) { Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) { Text(text, style = MaterialTheme.typography.labelSmall, letterSpacing = 1.3.sp, color = MaterialTheme.colorScheme.primary); if (detail.isNotEmpty()) Text(detail, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }; HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = .5f)) } }
@Composable private fun Panel(content: @Composable ColumnScope.() -> Unit) { Column(Modifier.fillMaxWidth().padding(vertical = 5.dp), verticalArrangement = Arrangement.spacedBy(9.dp), content = content) }
@Composable private fun Stat(label: String, value: String, modifier: Modifier, onClick: (() -> Unit)? = null) { Column(modifier.then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier).padding(horizontal = 6.dp, vertical = 12.dp), horizontalAlignment = Alignment.CenterHorizontally) { Subtle(label); Text(value, fontSize = 23.sp, fontFamily = FontFamily.Serif) } }
@Composable private fun ActionRow(title: String, subtitle: String, action: String, onClick: () -> Unit, second: String? = null, onSecond: () -> Unit = {}) { Row(Modifier.fillMaxWidth().heightIn(min = 52.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) { Column(Modifier.weight(1f)) { Text(title, style = MaterialTheme.typography.bodyMedium); Subtle(subtitle) }; TextButton(onClick = onClick, contentPadding = PaddingValues(horizontal = 8.dp), shape = RoundedCornerShape(3.dp)) { Text(action) }; if (second != null) TextButton(onClick = onSecond, contentPadding = PaddingValues(horizontal = 8.dp), shape = RoundedCornerShape(3.dp)) { Text(second) } } }
@Composable private fun DrawerLink(label: String, icon: ImageVector, onClick: () -> Unit) { TextButton(onClick = onClick, modifier = Modifier.fillMaxWidth(), contentPadding = PaddingValues(horizontal = 8.dp, vertical = 10.dp)) { Icon(icon, null, Modifier.size(20.dp)); Spacer(Modifier.width(14.dp)); Text(label, Modifier.weight(1f), color = MaterialTheme.colorScheme.onSurface) } }
@Composable private fun SettingToggle(label: String, checked: Boolean, onChange: (Boolean) -> Unit) { Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) { Text(label, Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium); Switch(checked, onChange) } }
@Composable private fun NameEditor(hero: DraftHero, saving: Boolean, onSave: (String) -> Unit, onCancel: () -> Unit) { var name by rememberSaveable(hero.id) { mutableStateOf(hero.name) }; Panel { Text("Identity", style = MaterialTheme.typography.titleLarge); OutlinedTextField(name, { name = it.take(80) }, label = { Text("Character name") }, modifier = Modifier.fillMaxWidth()); Subtle("${hero.role} ${hero.level} · Class and feature editing are planned."); Row { TextButton(onClick = onCancel) { Text("Cancel") }; Spacer(Modifier.weight(1f)); Button(enabled = name.isNotBlank() && !saving, onClick = { onSave(name.trim()) }) { Text("Save changes") } } } }
@Composable private fun NoteEditor(initial: String, saving: Boolean, onDismiss: () -> Unit, onSave: (String) -> Unit) { var text by rememberSaveable { mutableStateOf(initial) }; DraftSheet(onDismiss) { Text("The old watchtower", style = MaterialTheme.typography.titleLarge); OutlinedTextField(text, { text = it.take(10000) }, modifier = Modifier.fillMaxWidth().heightIn(min = 160.dp, max = 300.dp), label = { Text("Session note") }); Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) { TextButton(onClick = onDismiss) { Text("Cancel") }; Button(enabled = !saving, onClick = { onSave(text) }) { Text("Save note") } } } }
@Composable private fun ReferenceScreen(onOpen: (String) -> Unit) { var query by rememberSaveable { mutableStateOf("") }; OutlinedTextField(query, { query = it }, label = { Text("Search sample references") }, singleLine = true, modifier = Modifier.fillMaxWidth()); Subtle("Small sample library · Full SRD is not bundled yet"); listOf("Web" to "Spell · 2nd level", "Magic Missile" to "Spell · 1st level", "Quarterstaff" to "Simple weapon", "Owl" to "Tiny beast").filter { it.first.contains(query, true) || it.second.contains(query, true) }.forEach { (name, category) -> Panel { ActionRow(name, category, "Open", { onOpen(name) }) } } }
