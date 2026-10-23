package com.drakebound.android.draft

import org.junit.Assert.*
import org.junit.Test

class RulesTest {
    @Test fun signedDiceBoundsAndModifier() {
        val f = DiceEngine.parse("2d6 - 1d4 + 3")
        assertEquals(1, f.minimum); assertEquals(14, f.maximum)
        val result = DiceEngine.roll(f.text, "test") { 1 }
        assertEquals(4, result.total); assertEquals(listOf(1, 1, -1), result.dice.map { it.sign })
    }
    @Test fun advantageKeepsExactlyOneAndAddsBonusOnce() {
        val faces = ArrayDeque(listOf(3, 17))
        val result = DiceEngine.roll("1d20+7", "Attack", RollMode.Advantage) { faces.removeFirst() }
        assertEquals(24, result.total); assertEquals(1, result.dice.count { it.kept })
        assertFalse(result.dice.first().kept)
        val tie = DiceEngine.roll("d20+2", "Save", RollMode.Disadvantage) { 12 }
        assertEquals(14, tie.total); assertEquals(1, tie.dice.count { it.kept })
    }
    @Test fun malformedAndExcessiveDiceAreRejected() {
        listOf("0d20", "1d1", "51d6", "50d6+1d4", "2d6+", "2d6garbage", "99999999999999", "1++2", "2d6d8").forEach { s ->
            assertTrue(s, runCatching { DiceEngine.parse(s) }.isFailure)
        }
    }
    @Test fun calculatorHasPrecedenceAndRejectsUnsafeInputs() {
        assertEquals(14, AmountCalculator.evaluate("2+3×4"))
        assertEquals(20, AmountCalculator.evaluate("(2+3)*4"))
        assertEquals(5, AmountCalculator.evaluate("12÷3+1"))
        listOf("1/0", "5/2", "4+", "2d6", "1000000*1000000", "1;exit()").forEach { assertTrue(it, runCatching { AmountCalculator.evaluate(it) }.isFailure) }
    }
    @Test fun damageConsumesTemporaryHpBeforeCurrentHpAndHealingCaps() {
        assertEquals(Health(27, 34, 0), Health(28, 34, 5).damage(6))
        assertEquals(Health(28, 34, 2), Health(28, 34, 5).damage(3))
        assertEquals(Health(0, 34, 0), Health(28, 34).damage(500))
        assertEquals(Health(34, 34, 5), Health(28, 34, 5).heal(100))
    }
}
