package com.drakebound.android.draft

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.test.platform.app.InstrumentationRegistry
import android.graphics.Bitmap
import java.io.File
import org.junit.Rule
import org.junit.Test
import org.junit.Before
import org.junit.Assert.assertEquals

class PlayFlowTest {
    @get:Rule val compose = createAndroidComposeRule<MainActivity>()
    @Before fun requireIsolatedVerificationInstall() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        check(context.packageName == "com.drakebound.android.draft.verification") { "UI fixtures require the separate verification application ID" }
        check(context.applicationInfo.dataDir.endsWith("/com.drakebound.android.draft.verification")) { "Fixture data must be physically separate from the regular draft" }
    }
    private fun openHero() { compose.onNodeWithText("Lyra Ashford").performClick() }
    private fun inDialog(text: String) = compose.onNode(hasText(text, substring = false) and hasAnyAncestor(isDialog() or isPopup() or hasTestTag("interaction-sheet")))
    private fun screenshot(name: String) {
        compose.waitForIdle()
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        instrumentation.waitForIdleSync()
        // System IME/window transitions run outside Compose's test clock.
        Thread.sleep(600)
        instrumentation.uiAutomation.waitForIdle(300, 3000)
        val folder = File(instrumentation.targetContext.getExternalFilesDir(null) ?: instrumentation.targetContext.filesDir, "screenshots").apply { check(isDirectory || mkdirs()) }
        File(folder, "$name.png").outputStream().use { output -> instrumentation.uiAutomation.takeScreenshot().compress(Bitmap.CompressFormat.PNG, 100, output) }
    }
    private fun amount(value: String, action: String) {
        compose.onNodeWithText("Adjust HP").performClick()
        screenshot("calculator")
        compose.onNode(hasSetTextAction() and hasAnyAncestor(hasTestTag("interaction-sheet"))).performTextInput(value)
        inDialog(action).performScrollTo().performClick()
        inDialog(when (action) { "Damage" -> "Apply damage"; "Heal" -> "Apply healing"; "Set temp HP" -> "Apply temporary HP"; else -> action }).performScrollTo().performClick()
        compose.waitUntil(5000) { compose.onAllNodes(hasTestTag("interaction-sheet")).fetchSemanticsNodes().isEmpty() }
    }
    @Test fun damageUsesTemporaryHpAndCalculatorPrecedence() {
        openHero()
        compose.onNodeWithText("Rest").performClick(); screenshot("rest-sheet"); inDialog("Finish rest").performClick()
        compose.waitUntil(5000) { compose.onAllNodes(isDialog()).fetchSemanticsNodes().isEmpty() }
        amount("5", "Set temp HP")
        compose.onNodeWithText("Temporary HP · 5").assertIsDisplayed()
        amount("2+3×2", "Damage")
        compose.onNodeWithText("31 / 34").assertIsDisplayed()
        compose.onNodeWithText("Temporary HP · 0").assertIsDisplayed()
        screenshot("play")
    }
    @Test fun drawerCompanionAndJournalAreReachable() {
        openHero()
        compose.onNodeWithContentDescription("Open menu").performClick()
        compose.onNodeWithText("Nyx · Owl familiar").performClick()
        compose.onNodeWithText("Owl familiar · Tiny beast").assertIsDisplayed()
        screenshot("companion")
        compose.onNodeWithContentDescription("Back").performClick()
        compose.onNodeWithText("Journal", useUnmergedTree = true).performClick()
        compose.onNodeWithText("Edit note").performClick()
        screenshot("note-editor")
        compose.waitUntil(5000) { compose.onAllNodes(hasSetTextAction()).fetchSemanticsNodes().isNotEmpty() }
        compose.onNode(hasSetTextAction()).performTextReplacement("Android session note")
        inDialog("Save note").performClick()
        compose.waitUntil(5000) { compose.onAllNodesWithText("Android session note").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithText("Android session note").assertIsDisplayed()
        screenshot("journal")
    }
    @Test fun advantageRollShowsKeptAndDroppedDiceAndCanReroll() {
        openHero()
        compose.onNodeWithText("d20").performClick()
        compose.onNode(hasSetTextAction() and hasAnyAncestor(hasTestTag("interaction-sheet"))).performTextReplacement("1d20+7")
        compose.onNodeWithText("Adv.").performClick()
        compose.onNodeWithText("Roll dice").performScrollTo().performClick()
        compose.waitUntil(15000) { compose.onAllNodes(hasContentDescription("total", substring = true)).fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithText("1d20+7 · Advantage").assertIsDisplayed()
        screenshot("dice")
        compose.onNodeWithText("Roll again").assertIsEnabled().performClick()
        compose.waitUntil(15000) { compose.onAllNodes(hasContentDescription("total", substring = true)).fetchSemanticsNodes().isNotEmpty() }
        inDialog("Done").performClick()
    }
    @Test fun flatSheetGearAndLightAppearanceRemainUsable() {
        openHero()
        compose.onNodeWithText("Sheet", useUnmergedTree = true).performClick()
        compose.onNodeWithText("SKILLS & SAVES").assertIsDisplayed()
        screenshot("sheet")
        compose.onNodeWithText("Gear", useUnmergedTree = true).performClick()
        compose.onNodeWithText("EQUIPMENT").assertIsDisplayed()
        screenshot("gear")
        compose.onNodeWithContentDescription("Open menu").performClick()
        compose.onNodeWithText("Settings").performClick()
        compose.onAllNodes(isToggleable())[0].performClick()
        compose.onNodeWithContentDescription("Back").performClick()
        compose.onNodeWithText("Adjust HP").assertIsDisplayed()
        screenshot("play-light")
    }
    @Test fun fieldJournalSlotsDescriptionsAndInlineEquipmentWork() {
        openHero()
        compose.onNodeWithText("Rest").performClick(); inDialog("Finish rest").performClick()
        compose.waitUntil(5000) { compose.onAllNodes(isDialog()).fetchSemanticsNodes().isEmpty() }
        compose.onNodeWithContentDescription("Spend level 2 slot").performClick()
        compose.waitUntil(5000) { compose.onAllNodesWithText("2 / 3").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithText("Spells", useUnmergedTree = true).performClick()
        compose.onNodeWithText("2 / 3").assertIsDisplayed()
        compose.onNodeWithText("Fire Bolt", useUnmergedTree = true).performClick()
        compose.onNodeWithText("A bolt of fire", substring = true).assertIsDisplayed()
        screenshot("spells")
        compose.onNodeWithText("Gear", useUnmergedTree = true).performClick()
        val title = compose.onNodeWithText("Quarterstaff").fetchSemanticsNode().boundsInRoot
        val toggle = compose.onNodeWithContentDescription("Equip Quarterstaff")
        val mark = toggle.fetchSemanticsNode().boundsInRoot
        check(mark.center.y >= title.top && mark.center.y <= title.bottom + 22) { "Equipment toggle must share its item row" }
        toggle.assertIsOn().performClick()
        compose.waitUntil(5000) { compose.onAllNodes(isOn() and hasContentDescription("Equip Quarterstaff")).fetchSemanticsNodes().isEmpty() }
        toggle.assertIsOff()
        compose.onNodeWithText("Quarterstaff").performClick()
        compose.onNodeWithText("A sturdy staff", substring = true).assertIsDisplayed()
        screenshot("gear-details")
        val reloaded = DraftViewModel(InstrumentationRegistry.getInstrumentation().targetContext.applicationContext as android.app.Application)
        val savedHero = reloaded.heroes.first { it.id == "sample-lyra" }
        assertEquals(2, savedHero.secondSlots)
        assertEquals(false, savedHero.staffEquipped)
        compose.activityRule.scenario.recreate()
        compose.waitForIdle()
        compose.onNodeWithText("Gear", useUnmergedTree = true).performClick()
        compose.onNodeWithContentDescription("Equip Quarterstaff").assertIsOff()
        compose.onNodeWithText("Spells", useUnmergedTree = true).performClick()
        compose.onNodeWithText("2 / 3").assertIsDisplayed()
    }
    @Test fun attackRerollKeepsItsSourceAndFormula() {
        openHero()
        compose.onNodeWithContentDescription("Fire Bolt damage").performClick()
        compose.waitUntil(15000) { compose.onAllNodes(hasContentDescription("total", substring = true)).fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithText("2d10 · Normal").assertIsDisplayed()
        val before = compose.onNode(isPopup()).fetchSemanticsNode().positionInWindow
        compose.onNodeWithText("Roll again").performClick()
        compose.waitUntil(15000) { compose.onAllNodes(hasContentDescription("total", substring = true)).fetchSemanticsNodes().isNotEmpty() }
        val after = compose.onNode(isPopup()).fetchSemanticsNode().positionInWindow
        assertEquals(before, after)
        compose.onNodeWithText("2d10 · Normal").assertIsDisplayed()
        screenshot("anchored-roll")
        inDialog("Done").performClick()
    }
    @Test fun quickCastSpendsOneSlotAndRerollDoesNotSpendAgain() {
        openHero()
        compose.onNodeWithText("Rest").performClick(); inDialog("Finish rest").performClick()
        compose.waitUntil(5000) { compose.onAllNodes(hasTestTag("interaction-sheet")).fetchSemanticsNodes().isEmpty() }
        compose.onNodeWithText("Spells", useUnmergedTree = true).performClick()
        compose.onNodeWithText("Cast · 1st").performScrollTo().performClick()
        compose.waitUntil(15000) { compose.onAllNodes(hasContentDescription("total", substring = true)).fetchSemanticsNodes().isNotEmpty() }
        compose.onAllNodes(hasTestTag("interaction-sheet")).assertCountEquals(0)
        compose.onNodeWithText("3d4+3 · Normal").assertIsDisplayed()
        fun savedSlots() = DraftViewModel(InstrumentationRegistry.getInstrumentation().targetContext.applicationContext as android.app.Application).heroes.first { it.id == "sample-lyra" }.slots
        assertEquals(3, savedSlots())
        compose.onNodeWithText("Roll again").performClick()
        compose.waitUntil(15000) { compose.onAllNodes(hasContentDescription("total", substring = true)).fetchSemanticsNodes().isNotEmpty() }
        assertEquals(3, savedSlots())
        screenshot("quick-cast")
        inDialog("Done").performClick()
    }
    @Test fun sheetQuickAmountsCancelSafelyAndLargeDiceStayCompact() {
        openHero()
        compose.onNodeWithText("Rest").performClick(); inDialog("Finish rest").performClick()
        compose.waitUntil(5000) { compose.onAllNodes(hasTestTag("interaction-sheet")).fetchSemanticsNodes().isEmpty() }
        compose.onNodeWithText("Adjust HP").performClick()
        compose.onNodeWithText("+5").performClick(); compose.onNodeWithText("+10").performClick()
        compose.onNode(hasSetTextAction() and hasAnyAncestor(hasTestTag("interaction-sheet"))).assertTextEquals("15")
        screenshot("calculator-reworked")
        compose.onNodeWithText("Close").performClick()
        compose.waitUntil(5000) { compose.onAllNodes(hasTestTag("interaction-sheet")).fetchSemanticsNodes().isEmpty() }
        compose.onNodeWithText("34 / 34").assertIsDisplayed()
        compose.onNodeWithText("d20").performClick()
        compose.onNode(hasSetTextAction() and hasAnyAncestor(hasTestTag("interaction-sheet"))).performTextReplacement("50d1000")
        screenshot("dice-calculator")
        compose.onNodeWithText("Roll dice").performScrollTo().performClick()
        compose.waitUntil(15000) { compose.onAllNodes(hasContentDescription("total", substring = true)).fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithText("50d1000 · Normal").assertIsDisplayed()
        val popup = compose.onNode(isPopup()).fetchSemanticsNode()
        check(popup.size.height < compose.activity.resources.displayMetrics.heightPixels / 2) { "Large dice pools must not create rows of animated dice" }
        screenshot("large-dice")
        inDialog("Done").performClick()
    }
}
