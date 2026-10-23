package com.drakebound.android.draft

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.CutCornerShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.IntRect
import androidx.compose.ui.layout.boundsInWindow
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.unit.round

private val destinations = listOf("Play", "Sheet", "Spells", "Gear", "Journal")
private val destinationIcons = listOf(R.drawable.ic_swords, R.drawable.ic_sheet, R.drawable.ic_spellbook, R.drawable.ic_backpack, R.drawable.ic_journal)

@Composable
fun AdventureNavigation(selected: String, reduceMotion: Boolean, onSelect: (String) -> Unit) {
    val colors = MaterialTheme.colorScheme
    Surface(color = colors.background) {
        Column(Modifier.navigationBarsPadding()) {
            HorizontalDivider(color = colors.outlineVariant.copy(alpha = .65f))
            BoxWithConstraints(Modifier.fillMaxWidth()) {
                val width = maxWidth / destinations.size
                val marker by animateDpAsState(width * destinations.indexOf(selected).coerceAtLeast(0), tween(if (reduceMotion) 0 else 180), label = "Active destination")
                Box(Modifier.offset(x = marker).width(width).padding(horizontal = 20.dp).height(2.dp).background(colors.primary))
                Row(Modifier.fillMaxWidth().selectableGroup()) {
                    destinations.forEachIndexed { index, destination ->
                        val tint by animateColorAsState(if (selected == destination) colors.primary else colors.onSurfaceVariant, tween(if (reduceMotion) 0 else 160), label = "Tab color")
                        Column(Modifier.weight(1f).heightIn(min = 62.dp).selectable(selected == destination, role = Role.Tab, onClick = { onSelect(destination) }).padding(top = 11.dp, bottom = 7.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Icon(painterResource(destinationIcons[index]), null, Modifier.size(22.dp), tint = tint)
                            Text(destination, fontSize = 11.sp, color = tint, maxLines = 1)
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun RosterEntry(hero: DraftHero, index: Int, onOpen: () -> Unit) {
    val colors = MaterialTheme.colorScheme
    Row(Modifier.fillMaxWidth().clickable(onClick = onOpen).padding(vertical = 18.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(15.dp)) {
        Box(Modifier.size(52.dp).clip(CutCornerShape(9.dp)).background(colors.primary.copy(alpha = .09f)).border(1.dp, colors.primary.copy(alpha = .5f), CutCornerShape(9.dp)), contentAlignment = Alignment.Center) {
            Text(hero.name.take(1), fontFamily = FontFamily.Serif, fontSize = 30.sp, color = colors.primary)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(hero.name, fontFamily = FontFamily.Serif, fontSize = 24.sp)
            Text("${hero.role} ${hero.level}", style = MaterialTheme.typography.bodySmall, color = colors.onSurfaceVariant)
            Text("${hero.health.current} / ${hero.health.maximum} HP", style = MaterialTheme.typography.labelSmall, color = colors.onSurfaceVariant)
        }
        Column(horizontalAlignment = Alignment.End) { Text("0${index + 1}", style = MaterialTheme.typography.labelSmall, color = colors.onSurfaceVariant); Text("›", fontSize = 24.sp, color = colors.primary) }
    }
    HorizontalDivider(color = colors.outlineVariant.copy(alpha = .55f))
}

@Composable
fun AdventureVitals(hero: DraftHero, reduceMotion: Boolean, saving: Boolean, onHp: () -> Unit, onRest: () -> Unit, onInitiative: (IntRect) -> Unit) {
    val colors = MaterialTheme.colorScheme
    val wizard = "Wizard" in hero.role
    val fraction by animateFloatAsState(hero.health.current.toFloat() / hero.health.maximum, tween(if (reduceMotion) 0 else 350), label = "Hit points")
    Column(Modifier.fillMaxWidth().padding(top = 6.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Column(Modifier.weight(1.25f)) {
                Text("HIT POINTS", style = MaterialTheme.typography.labelSmall, letterSpacing = 1.6.sp, color = colors.onSurfaceVariant)
                Text(buildAnnotatedString {
                    withStyle(SpanStyle(fontFamily = FontFamily.Serif, fontSize = 45.sp)) { append(hero.health.current.toString()) }
                    withStyle(SpanStyle(fontSize = 17.sp, color = colors.onSurfaceVariant)) { append(" / ${hero.health.maximum}") }
                })
            }
            Metric("AC", if (wizard) "15" else "18", Modifier.weight(.65f))
            Metric("INIT", if (wizard) "+3" else "+1", Modifier.weight(.7f), onInitiative)
            Metric("SPEED", "30", Modifier.weight(.7f), unit = "ft")
        }
        Box(Modifier.fillMaxWidth().height(3.dp).background(colors.outlineVariant.copy(alpha = .5f))) {
            Box(Modifier.fillMaxWidth(fraction).fillMaxHeight().background(if (fraction < .25f) colors.error else Color(0xFF9FB38A)))
        }
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text("Temporary HP · ${hero.health.temporary}", style = MaterialTheme.typography.bodySmall, modifier = Modifier.weight(1f), color = colors.onSurfaceVariant)
            TextButton(onClick = onHp, enabled = !saving, shape = RoundedCornerShape(3.dp), contentPadding = PaddingValues(horizontal = 8.dp)) { Text("Adjust HP", fontSize = 12.sp) }
            TextButton(onClick = onRest, shape = RoundedCornerShape(3.dp), contentPadding = PaddingValues(horizontal = 8.dp)) { Text("Rest", fontSize = 12.sp) }
        }
    }
}

@Composable
private fun Metric(label: String, value: String, modifier: Modifier, onClick: ((IntRect) -> Unit)? = null, unit: String? = null) {
    var bounds by remember { mutableStateOf(IntRect.Zero) }
    Column(modifier.onGloballyPositioned { val r = it.boundsInWindow(); bounds = IntRect(r.topLeft.round(), r.bottomRight.round()) }.then(if (onClick != null) Modifier.clickable { onClick(bounds) } else Modifier).heightIn(min = 64.dp).padding(bottom = 5.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(label, style = MaterialTheme.typography.labelSmall, letterSpacing = .8.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(2.dp)) { Text(value, fontSize = 25.sp); if (unit != null) Text(unit, fontSize = 11.sp, modifier = Modifier.padding(bottom = 3.dp), color = MaterialTheme.colorScheme.onSurfaceVariant) }
    }
}

@Composable
fun AdventureAttack(name: String, subtitle: String, hit: String, damage: String, onHit: (IntRect) -> Unit, onDamage: (IntRect) -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 52.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) { Text(name, fontSize = 14.sp, fontWeight = FontWeight.Medium); Text(subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
        SourceButton(hit, "$name attack", Modifier.widthIn(min = 48.dp), onClick = onHit)
        SourceButton(damage, "$name damage", Modifier.widthIn(min = 60.dp), onClick = onDamage)
    }
    HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = .5f))
}

@Composable
fun FamiliarLink(hp: Int, onOpen: () -> Unit) {
    Row(Modifier.fillMaxWidth().clickable(onClick = onOpen).heightIn(min = 58.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(Modifier.size(36.dp).border(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = .5f), CircleShape), contentAlignment = Alignment.Center) { Text("N", fontFamily = FontFamily.Serif, color = MaterialTheme.colorScheme.primary, fontSize = 19.sp) }
        Column(Modifier.weight(1f)) { Text("Nyx · Familiar", style = MaterialTheme.typography.bodyMedium); Text("Owl · $hp / 1 HP", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
        Text("Open", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.primary)
    }
}
