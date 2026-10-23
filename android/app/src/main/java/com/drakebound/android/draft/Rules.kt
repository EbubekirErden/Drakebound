package com.drakebound.android.draft

import kotlin.random.Random

data class Die(val sides: Int, val face: Int, val sign: Int = 1, val kept: Boolean = true)
data class DiceTerm(val sign: Int, val count: Int = 0, val sides: Int = 0, val flat: Int = 0)
data class Formula(val text: String, val terms: List<DiceTerm>) {
    val minimum get() = terms.sumOf { if (it.count == 0) it.sign * it.flat else if (it.sign > 0) it.count else -it.count * it.sides }
    val maximum get() = terms.sumOf { if (it.count == 0) it.sign * it.flat else if (it.sign > 0) it.count * it.sides else -it.count }
    val average get() = terms.sumOf { it.sign * if (it.count == 0) it.flat.toDouble() else it.count * (it.sides + 1) / 2.0 }
    val allowsAdvantage get() = terms.count { it.count > 0 } == 1 && terms.firstOrNull { it.count > 0 }?.let { it.count == 1 && it.sides == 20 && it.sign == 1 } == true
}
enum class RollMode(val label: String) { Normal("Normal"), Advantage("Advantage"), Disadvantage("Disadvantage") }
data class DiceRoll(val label: String, val formula: String, val dice: List<Die>, val modifier: Int, val mode: RollMode) {
    val total get() = dice.filter { it.kept }.sumOf { it.face * it.sign } + modifier
    val detail get() = dice.joinToString(" · ") { "${if (it.sign < 0) "−" else ""}${it.face}${if (!it.kept) " dropped" else ""}" } + if (modifier != 0) " ${if (modifier > 0) "+" else "−"} ${kotlin.math.abs(modifier)}" else ""
}
object DiceEngine {
    fun parse(input: String): Formula {
        val text = input.lowercase().filterNot(Char::isWhitespace)
        require(text.length in 1..256) { "Enter a formula, such as 2d6+3" }
        val matches = Regex("([+-]?)([0-9]*d[0-9]+|[0-9]+)").findAll(text).toList()
        require(matches.isNotEmpty() && matches.joinToString("") { it.value } == text && matches.size <= 30) { "Use dice and numbers joined by + or −" }
        require(matches.drop(1).all { it.groupValues[1].isNotEmpty() }) { "Join each term with + or −" }
        val terms = matches.map { m ->
            val sign = if (m.groupValues[1] == "-") -1 else 1
            val part = m.groupValues[2]
            if ('d' in part) {
                val pair = part.split('d')
                val count = if (pair[0].isEmpty()) 1 else pair[0].toIntOrNull() ?: 0
                val sides = pair[1].toIntOrNull() ?: 0
                require(count in 1..50 && sides in 2..1000) { "Use 1–50 dice with 2–1000 sides" }
                DiceTerm(sign, count, sides)
            } else {
                val flat = part.toIntOrNull()
                require(flat != null && flat <= 100000) { "Numbers must be at most 100,000" }
                DiceTerm(sign, flat = flat)
            }
        }
        require(terms.sumOf { it.count } <= 50) { "At most 50 dice per roll" }
        return Formula(text, terms)
    }
    fun roll(input: String, label: String, mode: RollMode = RollMode.Normal, face: (Int) -> Int = { Random.nextInt(1, it + 1) }): DiceRoll {
        val f = parse(input)
        require(mode == RollMode.Normal || f.allowsAdvantage) { "Advantage requires one positive d20" }
        val dice = mutableListOf<Die>()
        f.terms.filter { it.count > 0 }.forEach { term ->
            if (mode != RollMode.Normal) {
                val a = face(20); val b = face(20)
                val keepFirst = if (mode == RollMode.Advantage) a >= b else a <= b
                dice += Die(20, a, kept = keepFirst); dice += Die(20, b, kept = !keepFirst)
            } else repeat(term.count) { dice += Die(term.sides, face(term.sides), term.sign) }
        }
        return DiceRoll(label, f.text, dice, f.terms.filter { it.count == 0 }.sumOf { it.sign * it.flat }, mode)
    }
}

/** Bounded integer arithmetic, independent of UI; no eval or implicit dice rolls. */
object AmountCalculator {
    fun evaluate(input: String): Int {
        val s = input.filterNot(Char::isWhitespace).replace('×', '*').replace('÷', '/').replace('−', '-')
        require(s.length in 1..80) { "Enter an amount" }
        var i = 0
        fun bounded(n: Long): Long { require(n in -1000000L..1000000L) { "Amount is too large" }; return n }
        lateinit var expression: () -> Long
        fun atom(): Long {
            require(i < s.length) { "Finish the expression" }
            if (s[i] == '+' || s[i] == '-') { val negative = s[i++] == '-'; return bounded((if (negative) -1 else 1) * atom()) }
            if (s[i] == '(') { i++; val n = expression(); require(i < s.length && s[i++] == ')') { "Close the parentheses" }; return n }
            val start = i
            while (i < s.length && s[i].isDigit()) i++
            require(i > start) { "Use whole numbers and + − × ÷" }
            return bounded(s.substring(start, i).toLongOrNull() ?: error("Amount is too large"))
        }
        fun product(): Long {
            var n = atom()
            while (i < s.length && s[i] in "*/") {
                val op = s[i++]; val right = atom()
                if (op == '/') { require(right != 0L) { "Cannot divide by zero" }; require(n % right == 0L) { "Division must give a whole number" } }
                n = bounded(if (op == '*') n * right else n / right)
            }
            return n
        }
        expression = {
            var n = product()
            while (i < s.length && s[i] in "+-") { val op = s[i++]; val right = product(); n = bounded(if (op == '+') n + right else n - right) }
            n
        }
        val n = expression(); require(i == s.length) { "Check the expression" }; return n.toInt()
    }
}

data class Health(val current: Int, val maximum: Int, val temporary: Int = 0) {
    fun damage(amount: Int): Health {
        require(amount >= 0)
        val absorbed = minOf(amount, temporary)
        return copy(current = (current - (amount - absorbed)).coerceAtLeast(0), temporary = temporary - absorbed)
    }
    fun heal(amount: Int): Health { require(amount >= 0); return copy(current = (current.toLong() + amount).coerceAtMost(maximum.toLong()).toInt()) }
}
