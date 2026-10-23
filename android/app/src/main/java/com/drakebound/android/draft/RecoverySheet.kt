package com.drakebound.android.draft

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun RestSheet(hero: DraftHero, saving: Boolean, onDismiss: () -> Unit, onComplete: () -> Unit) {
    DraftSheet(onDismiss) {
        Text("Rest & recovery", fontFamily = FontFamily.Serif, fontSize = 24.sp)
        Text("LONG REST", fontSize = 11.sp, letterSpacing = 1.4.sp, color = MaterialTheme.colorScheme.primary)
        RecoveryRow("Hit points", "${hero.health.current} → ${hero.health.maximum} / ${hero.health.maximum}")
        RecoveryRow("Temporary HP", "${hero.health.temporary} → 0")
        if (hero.role.contains("Wizard")) {
            RecoveryRow("1st-level slots", "${hero.slots} → 4")
            RecoveryRow("2nd-level slots", "${hero.secondSlots} → 3")
            RecoveryRow("3rd-level slots", "${hero.thirdSlots} → 2")
            RecoveryRow("Arcane Recovery", "${hero.recovery} → 1")
        }
        Text("This draft restores the resources above. Conditions and concentration stay as they are; hit dice are not modeled yet.", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End, verticalAlignment = Alignment.CenterVertically) {
            TextButton(onClick = onDismiss) { Text("Cancel") }
            Button(enabled = !saving, onClick = onComplete, shape = RoundedCornerShape(3.dp)) { Text("Finish rest") }
        }
    }
}

@Composable
private fun RecoveryRow(label: String, value: String) {
    Row(Modifier.fillMaxWidth().heightIn(min = 36.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(label, Modifier.weight(1f), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value, fontSize = 13.sp)
    }
    HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
}
