package com.drakebound.android.draft

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.layout.boundsInWindow
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.IntRect
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.round
import androidx.compose.ui.unit.sp

@Composable
fun SourceButton(text: String, label: String = text, modifier: Modifier = Modifier, enabled: Boolean = true, onClick: (IntRect) -> Unit) {
    var bounds by remember { mutableStateOf(IntRect.Zero) }
    TextButton(onClick = { onClick(bounds) }, enabled = enabled, modifier = modifier.onGloballyPositioned { bounds = it.boundsInWindow().roundToIntRect() }.heightIn(min = 48.dp), shape = RoundedCornerShape(2.dp), contentPadding = PaddingValues(horizontal = 6.dp)) {
        Text(text, fontSize = 13.sp, modifier = Modifier.semantics { contentDescription = label })
    }
}

private fun androidx.compose.ui.geometry.Rect.roundToIntRect() = IntRect(topLeft.round(), bottomRight.round())

@Composable
fun SlotTable(hero: DraftHero, saving: Boolean, onChange: (Int, Int) -> Unit) {
    val slots = listOf(hero.slots, hero.secondSlots, hero.thirdSlots)
    val limits = listOf(4, 3, 2)
    Column(Modifier.fillMaxWidth()) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text("SPELL SLOTS", Modifier.weight(1f), fontSize = 11.sp, letterSpacing = 1.2.sp, color = MaterialTheme.colorScheme.primary)
            Text("Remaining / total", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        slots.forEachIndexed { index, value ->
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
            Row(Modifier.fillMaxWidth().heightIn(min = 48.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(listOf("1st", "2nd", "3rd")[index], Modifier.width(42.dp), fontSize = 12.sp)
                Text("$value / ${limits[index]}", Modifier.width(42.dp), fontSize = 13.sp)
                Row(Modifier.weight(1f), horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                    repeat(limits[index]) { slot -> Box(Modifier.size(6.dp).rotate(45f).background(if (slot < value) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outlineVariant)) }
                }
                TextButton(enabled = value > 0 && !saving, onClick = { onChange(index + 1, -1) }, modifier = Modifier.size(48.dp).semantics { contentDescription = "Spend level ${index + 1} slot" }, contentPadding = PaddingValues(0.dp)) { Text("−", fontSize = 21.sp) }
                TextButton(enabled = value < limits[index] && !saving, onClick = { onChange(index + 1, 1) }, modifier = Modifier.size(48.dp).semantics { contentDescription = "Restore level ${index + 1} slot" }, contentPadding = PaddingValues(0.dp)) { Text("+", fontSize = 21.sp) }
            }
        }
    }
}

private data class Skill(val name: String, val ability: Int, val wizardProficient: Boolean = false, val fighterProficient: Boolean = false)
private val skills = listOf(
    Skill("Acrobatics", 1), Skill("Animal Handling", 4), Skill("Arcana", 3, true), Skill("Athletics", 0, fighterProficient = true),
    Skill("Deception", 5), Skill("History", 3, true), Skill("Insight", 4), Skill("Intimidation", 5), Skill("Investigation", 3, true),
    Skill("Medicine", 4), Skill("Nature", 3), Skill("Perception", 4, true, true), Skill("Performance", 5), Skill("Persuasion", 5),
    Skill("Religion", 3), Skill("Sleight of Hand", 1), Skill("Stealth", 1), Skill("Survival", 4)
)
private fun sign(n: Int) = if (n >= 0) "+$n" else "$n"

@Composable
fun CompactAbilities(wizard: Boolean, onRoll: (String, String, IntRect) -> Unit) {
    val labels = listOf("STR", "DEX", "CON", "INT", "WIS", "CHA")
    val scores = if (wizard) listOf(8, 16, 14, 18, 12, 10) else listOf(16, 12, 16, 10, 13, 8)
    val mods = scores.map { Math.floorDiv(it - 10, 2) }
    Row(Modifier.fillMaxWidth()) {
        scores.forEachIndexed { index, score ->
            var bounds by remember { mutableStateOf(IntRect.Zero) }
            Column(Modifier.weight(1f).onGloballyPositioned { bounds = it.boundsInWindow().roundToIntRect() }.clickable(role = Role.Button, onClickLabel = "Roll ${labels[index]}") { onRoll("1d20${sign(mods[index])}", "${labels[index]} check", bounds) }.padding(vertical = 8.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Text(labels[index], Modifier.fillMaxWidth(), textAlign = TextAlign.Center, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text("$score", Modifier.fillMaxWidth(), textAlign = TextAlign.Center, fontSize = 25.sp, fontFamily = FontFamily.Serif)
                Text(sign(mods[index]), Modifier.fillMaxWidth(), textAlign = TextAlign.Center, fontSize = 12.sp, color = MaterialTheme.colorScheme.primary)
            }
        }
    }
    HorizontalDivider()
    Text("SKILLS & SAVES", fontSize = 11.sp, letterSpacing = 1.2.sp, color = MaterialTheme.colorScheme.primary)
    skills.forEach { skill ->
        val trained = if (wizard) skill.wizardProficient else skill.fighterProficient
        val modifier = mods[skill.ability] + if (trained) if (wizard) 3 else 2 else 0
        var bounds by remember { mutableStateOf(IntRect.Zero) }
        Row(Modifier.fillMaxWidth().heightIn(min = 44.dp).onGloballyPositioned { bounds = it.boundsInWindow().roundToIntRect() }.clickable(role = Role.Button, onClickLabel = "Roll ${skill.name}") { onRoll("1d20${sign(modifier)}", skill.name, bounds) }, verticalAlignment = Alignment.CenterVertically) {
            Text(skill.name, Modifier.weight(1f), fontSize = 13.sp)
            if (trained) Text("•", Modifier.width(18.dp), color = MaterialTheme.colorScheme.primary)
            Text(labels[skill.ability], Modifier.width(38.dp), fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(sign(modifier), fontSize = 14.sp)
        }
        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = .6f))
    }
}

@Composable
fun ReferenceRow(name: String, subtitle: String, description: String, modifier: Modifier = Modifier, trailing: @Composable RowScope.() -> Unit = {}) {
    var expanded by rememberSaveable(name) { mutableStateOf(false) }
    Column(modifier.fillMaxWidth()) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(2.dp)) {
            Column(Modifier.weight(1f).clickable(role = Role.Button, onClickLabel = if (expanded) "Hide $name description" else "Read $name description") { expanded = !expanded }.heightIn(min = 52.dp).padding(vertical = 7.dp)) {
                Text(name, fontSize = 14.sp)
                Text(subtitle, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            trailing()
        }
        if (expanded) Text(description, fontSize = 13.sp, lineHeight = 19.sp, modifier = Modifier.padding(bottom = 12.dp), color = MaterialTheme.colorScheme.onSurfaceVariant)
        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = .6f))
    }
}

@Composable
fun EquippedDiamond(name: String, checked: Boolean, saving: Boolean, onToggle: () -> Unit) {
    // A 12dp mark inside a 48dp target; both stay in the item's horizontal row.
    androidx.compose.material3.IconToggleButton(checked, { onToggle() }, enabled = !saving, modifier = Modifier.size(48.dp).semantics { contentDescription = "Equip $name" }) {
        Box(Modifier.size(12.dp).rotate(45f).border(1.dp, MaterialTheme.colorScheme.primary).background(if (checked) MaterialTheme.colorScheme.primary else androidx.compose.ui.graphics.Color.Transparent))
    }
}

@Composable
fun CompactJournal(note: String, onEdit: () -> Unit) {
    var expanded by rememberSaveable { mutableStateOf(false) }
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text("SESSION NOTES", Modifier.weight(1f), fontSize = 11.sp, letterSpacing = 1.sp, color = MaterialTheme.colorScheme.primary)
        TextButton(onClick = onEdit) { Text("Edit note", fontSize = 12.sp) }
    }
    HorizontalDivider()
    Row(Modifier.fillMaxWidth().clickable(role = Role.Button, onClickLabel = "Expand session note") { expanded = !expanded }.padding(vertical = 10.dp), verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Text("08", fontFamily = FontFamily.Serif, fontSize = 24.sp, color = MaterialTheme.colorScheme.primary)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text("The old watchtower", fontSize = 15.sp, fontFamily = FontFamily.Serif)
            Text(note, fontSize = 12.sp, lineHeight = 17.sp, maxLines = if (expanded) Int.MAX_VALUE else 2, overflow = TextOverflow.Ellipsis, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text("Session 8 · Saved on this device", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
    HorizontalDivider()
}
