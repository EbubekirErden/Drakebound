package com.drakebound.android.draft

import android.provider.Settings
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.horizontalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.IntRect
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.window.Popup
import androidx.compose.ui.window.PopupPositionProvider
import androidx.compose.ui.window.PopupProperties
import kotlinx.coroutines.delay
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DraftSheet(onDismiss: () -> Unit, content: @Composable ColumnScope.() -> Unit) {
    val keyboard = LocalSoftwareKeyboardController.current
    DisposableEffect(Unit) { onDispose { keyboard?.hide() } }
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), properties = ModalBottomSheetProperties(isAppearanceLightStatusBars = false, isAppearanceLightNavigationBars = MaterialTheme.colorScheme.background.luminance() > .5f), shape = RoundedCornerShape(topStart = 12.dp, topEnd = 12.dp), containerColor = MaterialTheme.colorScheme.background) {
        Column(Modifier.testTag("interaction-sheet").fillMaxWidth().heightIn(max = 680.dp).verticalScroll(rememberScrollState()).padding(start = 20.dp, end = 20.dp, bottom = 20.dp), verticalArrangement = Arrangement.spacedBy(10.dp), content = content)
    }
}

@Composable
private fun SheetTitle(title: String, onDismiss: () -> Unit) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(title, Modifier.weight(1f), fontFamily = FontFamily.Serif, fontSize = 23.sp)
        TextButton(onClick = onDismiss) { Text("Close", fontSize = 12.sp) }
    }
}

@Composable
private fun ExpressionDisplay(expression: String, label: String, onChange: (String) -> Unit) {
    val focus = remember { FocusRequester() }
    val keyboard = LocalSoftwareKeyboardController.current
    Column(Modifier.fillMaxWidth().background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = .45f)).padding(horizontal = 14.dp, vertical = 9.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(label, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        BasicTextField(value = expression, onValueChange = onChange, textStyle = TextStyle(fontFamily = FontFamily.Monospace, fontSize = 30.sp, textAlign = TextAlign.End, color = MaterialTheme.colorScheme.onSurface), singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Ascii, showKeyboardOnFocus = false), modifier = Modifier.weight(1f).heightIn(min = 44.dp).focusRequester(focus), decorationBox = { inner -> Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.CenterEnd) { if (expression.isEmpty()) Text("0", fontSize = 30.sp, fontFamily = FontFamily.Monospace, color = MaterialTheme.colorScheme.onSurfaceVariant); inner() } })
        TextButton(onClick = { focus.requestFocus(); keyboard?.show() }) { Text("Type", fontSize = 11.sp) }
        }
    }
}

@Composable
fun AmountDialog(title: String, latestRoll: Int?, preview: (Int, String) -> String, actions: List<String>, saving: Boolean, onDismiss: () -> Unit, onApply: (Int, String) -> Unit) {
    var expression by rememberSaveable { mutableStateOf("") }
    var selectedAction by rememberSaveable { mutableStateOf(actions.first()) }
    val result = runCatching { AmountCalculator.evaluate(expression) }
    val value = result.getOrNull()?.takeIf { it >= 0 }
    DraftSheet(onDismiss) {
        SheetTitle(title, onDismiss)
        if (actions.size > 1) Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(5.dp)) { actions.forEach { action -> FilterChip(selected = action == selectedAction, onClick = { selectedAction = action }, label = { Text(action, fontSize = 12.sp) }) } }
        ExpressionDisplay(expression, "AMOUNT · $selectedAction") { if (it.length <= 80) expression = it }
        Text(if (value != null) "= $value · ${preview(value, selectedAction)}" else if (expression.isEmpty()) "Enter an amount, then apply" else result.exceptionOrNull()?.message ?: "Use a nonnegative amount", color = if (value == null && expression.isNotEmpty()) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            listOf(1, 5, 10, 20).forEach { n -> TextButton(onClick = { expression = ((value ?: 0).toLong() + n).coerceAtMost(1000000).toString() }) { Text("+$n", fontSize = 12.sp) } }
        }
        CalculatorGrid(listOf("7", "8", "9", "+", "4", "5", "6", "−", "1", "2", "3", "×", "0", "C", "⌫", "÷")) { key ->
            expression = when (key) { "C" -> ""; "⌫" -> expression.dropLast(1); else -> (expression + key).take(80) }
        }
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            if (latestRoll != null && latestRoll >= 0) TextButton(onClick = { expression = latestRoll.toString() }) { Text("Last roll · $latestRoll", fontSize = 12.sp) }
            Spacer(Modifier.weight(1f))
            Button(onClick = { value?.let { onApply(it, selectedAction) } }, enabled = value != null && !saving, shape = RoundedCornerShape(3.dp)) { Text(when (selectedAction) { "Damage" -> "Apply damage"; "Heal" -> "Apply healing"; "Set temp HP" -> "Apply temporary HP"; else -> selectedAction }) }
        }
    }
}

@Composable
fun CalculatorGrid(keys: List<String>, onPress: (String) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
        keys.chunked(4).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                row.forEach { key ->
                    TextButton(onClick = { onPress(key) }, modifier = Modifier.weight(1f).heightIn(min = 48.dp).background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = .35f)), shape = RoundedCornerShape(2.dp), contentPadding = PaddingValues(4.dp)) { Text(key, fontFamily = FontFamily.Monospace, fontSize = 21.sp, color = if (key in listOf("+", "−", "×", "÷", "C", "⌫", "±")) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface) }
                }
            }
        }
    }
}

@Composable
fun DiceCalculator(onDismiss: () -> Unit, onRoll: (String, RollMode) -> Unit) {
    var expression by rememberSaveable { mutableStateOf("1d20") }
    var mode by rememberSaveable { mutableStateOf(RollMode.Normal) }
    var customDie by rememberSaveable { mutableStateOf(false) }
    var customSides by rememberSaveable { mutableStateOf("100") }
    val parsed = runCatching { DiceEngine.parse(expression) }
    val formula = parsed.getOrNull()
    fun addDie(sides: Int) {
        val term = expression.substringAfterLast('+').substringAfterLast('-')
        expression = when { term.isNotEmpty() && term.all(Char::isDigit) -> expression + "d$sides"; expression.isEmpty() || expression.last() in "+-" -> expression + "1d$sides"; else -> "$expression+1d$sides" }.take(256)
    }
    DraftSheet(onDismiss) {
        SheetTitle("Dice calculator", onDismiss)
        ExpressionDisplay(expression, "DICE FORMULA") { if (it.length <= 256) expression = it }
        Text(formula?.let { "Range ${it.minimum}–${it.maximum} · Average ${"%.1f".format(it.average)}" } ?: parsed.exceptionOrNull()?.message.orEmpty(), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        if (formula?.allowsAdvantage == true) {
            Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                RollMode.entries.forEach { m -> FilterChip(selected = mode == m, onClick = { mode = m }, label = { Text(when (m) { RollMode.Normal -> "Normal"; RollMode.Advantage -> "Adv."; RollMode.Disadvantage -> "Disadv." }) }) }
            }
        }
        Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            listOf(4, 6, 8, 10, 12, 20, 100).forEach { sides -> TextButton(onClick = { addDie(sides) }, contentPadding = PaddingValues(7.dp)) { Text("d$sides", fontSize = 12.sp) } }
            TextButton(onClick = { customDie = !customDie }) { Text("dX", fontSize = 12.sp) }
        }
        if (customDie) Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            OutlinedTextField(customSides, { customSides = it.filter(Char::isDigit).take(4) }, label = { Text("Sides · 2–1000") }, modifier = Modifier.weight(1f), singleLine = true, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number))
            TextButton(enabled = customSides.toIntOrNull() in 2..1000, onClick = { addDie(customSides.toInt()); customDie = false }) { Text("Add die") }
        }
        CalculatorGrid(listOf("7", "8", "9", "+", "4", "5", "6", "−", "1", "2", "3", "⌫", "0", "00", "C", "±")) { key ->
            expression = when {
                key == "C" -> ""
                key == "⌫" -> expression.dropLast(1)
                key == "±" -> if (expression.startsWith("-")) expression.drop(1) else "-$expression"
                key == "+" || key == "−" -> expression.trimEnd('+', '-', '−') + if (key == "−") "-" else "+"
                key.startsWith("d") -> {
                    val term = expression.substringAfterLast('+').substringAfterLast('-')
                    when { term.isNotEmpty() && term.all(Char::isDigit) -> expression + key
                        expression.isEmpty() || expression.last() in "+-" -> expression + "1$key"
                        else -> "$expression+1$key" }
                }
                else -> {
                    val term = expression.substringAfterLast('+').substringAfterLast('-')
                    expression + (if ('d' in term) "+" else "") + key
                }
            }.take(256)
        }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
            TextButton(onClick = onDismiss) { Text("Cancel") }
            Button(onClick = { formula?.let { onRoll(it.text, if (it.allowsAdvantage) mode else RollMode.Normal) } }, enabled = formula != null) { Text("Roll dice") }
        }
    }
}

@Composable
fun DiceResultDialog(roll: DiceRoll, sequence: Int, reducedMotion: Boolean, haptics: Boolean, anchor: IntRect? = null, onDismiss: () -> Unit, onAgain: () -> Unit) {
    val context = LocalContext.current
    val haptic = LocalHapticFeedback.current
    val systemReduced = Settings.Global.getFloat(context.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
    var settled by remember(sequence) { mutableStateOf(false) }
    var animatedTotal by remember(sequence) { mutableIntStateOf(roll.total) }
    val limits = remember(roll.formula) { DiceEngine.parse(roll.formula) }
    val rotation = remember(sequence) { Animatable(0f) }
    LaunchedEffect(sequence) {
        if (!reducedMotion && !systemReduced && roll.dice.isNotEmpty()) {
            repeat(12) { tick ->
                animatedTotal = Random.nextInt(limits.minimum, limits.maximum + 1)
                rotation.snapTo((12 - tick) * 17f)
                delay(52)
            }
        }
        animatedTotal = roll.total; settled = true
        if (haptics) haptic.performHapticFeedback(HapticFeedbackType.LongPress)
        if (!reducedMotion && !systemReduced) rotation.animateTo(0f, spring(dampingRatio = .55f, stiffness = 380f))
    }
    RollSurface(anchor, onDismiss) {
        Text(roll.label, style = MaterialTheme.typography.titleMedium, fontFamily = FontFamily.Serif)
        Text("${roll.formula} · ${roll.mode.label}", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Row(Modifier.fillMaxWidth().clearAndSetSemantics { contentDescription = if (settled) "${roll.label}, ${roll.formula}, total ${roll.total}, ${roll.detail}" else "Rolling dice" }, horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.CenterVertically) {
            val shown = if (settled) roll.total else animatedTotal
            Box(Modifier.size(128.dp).graphicsLayer { rotationZ = rotation.value; rotationX = rotation.value / 3; cameraDistance = 12 * density }, contentAlignment = Alignment.Center) {
                val fill = MaterialTheme.colorScheme.primaryContainer; val stroke = MaterialTheme.colorScheme.primary
                Canvas(Modifier.fillMaxSize()) {
                    val path = Path(); val radius = size.minDimension / 2 - 3
                    repeat(6) { j -> val angle = j * PI / 3 - PI / 2; val x = size.width / 2 + cos(angle).toFloat() * radius; val y = size.height / 2 + sin(angle).toFloat() * radius; if (j == 0) path.moveTo(x, y) else path.lineTo(x, y) }; path.close()
                    drawPath(path, fill); drawPath(path, stroke, style = Stroke(1.5.dp.toPx()))
                }
                Text("$shown", fontSize = if (shown.toString().length > 4) 25.sp else 39.sp, fontFamily = FontFamily.Serif, color = MaterialTheme.colorScheme.onPrimaryContainer)
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(7.dp)) {
                Text(if (settled) "TOTAL" else "ROLLING", fontSize = 11.sp, letterSpacing = 1.sp, color = MaterialTheme.colorScheme.primary)
                Text(if (!settled) "…" else if (roll.mode != RollMode.Normal) roll.dice.joinToString("\n") { "${if (it.kept) "Kept" else "Dropped"} ${it.face}" } else roll.detail.ifEmpty { "Flat value" }, fontSize = 12.sp, lineHeight = 17.sp, maxLines = 3, overflow = TextOverflow.Ellipsis)
                Text(if (roll.dice.size > 1) "${roll.dice.size} dice · one total" else roll.dice.firstOrNull()?.let { "d${it.sides}" } ?: "Modifier only", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
            TextButton(onClick = onDismiss) { Text("Done") }
            Button(onClick = onAgain, enabled = settled, shape = RoundedCornerShape(3.dp)) { Text("Roll again") }
        }
    }
}

/** Keep the original source rectangle across rerolls, including the same formula and mode. */
private class SourcePosition(private val source: IntRect, private val gap: Int) : PopupPositionProvider {
    override fun calculatePosition(anchorBounds: IntRect, windowSize: IntSize, layoutDirection: LayoutDirection, popupContentSize: IntSize): IntOffset {
        val x = (source.center.x - popupContentSize.width / 2).coerceIn(gap, (windowSize.width - popupContentSize.width - gap).coerceAtLeast(gap))
        val below = source.bottom + gap
        val above = source.top - popupContentSize.height - gap
        val y = if (below + popupContentSize.height <= windowSize.height - gap) below else above
        return IntOffset(x, y.coerceIn(gap, (windowSize.height - popupContentSize.height - gap).coerceAtLeast(gap)))
    }
}

@Composable
private fun RollSurface(anchor: IntRect?, onDismiss: () -> Unit, content: @Composable ColumnScope.() -> Unit) {
    if (anchor == null) { DraftSheet(onDismiss, content); return }
    val windowSize = LocalWindowInfo.current.containerSize
    val density = LocalDensity.current
    val gap = with(density) { 8.dp.roundToPx() }
    val availableWidth = with(density) { windowSize.width.toDp() }
    val availableHeight = with(density) { windowSize.height.toDp() }
    val position = remember(anchor, gap) { SourcePosition(anchor, gap) }
    Popup(popupPositionProvider = position, onDismissRequest = onDismiss, properties = PopupProperties(focusable = true)) {
        Surface(shape = RoundedCornerShape(4.dp), shadowElevation = 12.dp, color = MaterialTheme.colorScheme.surface, border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)) {
            Column(Modifier.width(minOf(320.dp, availableWidth - 24.dp).coerceAtLeast(200.dp)).heightIn(max = (availableHeight - 64.dp).coerceAtLeast(160.dp)).verticalScroll(rememberScrollState()).padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp), content = content)
        }
    }
}
