package com.drakebound.android.draft

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject

data class DraftHero(
    val id: String, val name: String, val role: String, val level: Int, val health: Health,
    val slots: Int = 3, val concentrating: Boolean = true, val recovery: Int = 1,
    val gold: Int = 42, val potions: Int = 2, val companionHp: Int = 1,
    val note: String = "The keeper saw blue lights beyond the northern ridge. Ask Mara about the sealed stairway.",
    val staffEquipped: Boolean = true, val conditions: List<String> = emptyList(),
    val secondSlots: Int = 2, val thirdSlots: Int = 2
)
fun sampleHeroes() = listOf(
    DraftHero("sample-lyra", "Lyra Ashford", "Half-elf · Wizard", 5, Health(28, 34)),
    DraftHero("sample-garrick", "Garrick Stone", "Dwarf · Fighter", 4, Health(36, 36), slots = 0, concentrating = false)
)

/** Draft-only storage in the Android app sandbox. Never accesses the Mac save directory. */
class DraftViewModel(application: Application) : AndroidViewModel(application) {
    private val prefs = application.getSharedPreferences("android-prototype-only-v1", 0)
    var heroes by mutableStateOf(sampleHeroes()); private set
    var selected by mutableStateOf<String?>(null)
    var dark by mutableStateOf(false)
    var reduceMotion by mutableStateOf(false)
    var haptics by mutableStateOf(true)
    var saving by mutableStateOf(false); private set
    var error by mutableStateOf<String?>(null)
    var history by mutableStateOf(listOf<String>()); private set
    var rolls by mutableStateOf(listOf<DiceRoll>()); private set
    val hero get() = heroes.firstOrNull { it.id == selected }
    init {
        try {
            prefs.getString("heroes", null)?.let { raw ->
                val array = JSONArray(raw)
                heroes = List(array.length()) { i ->
                    val o = array.getJSONObject(i)
                    val sample = sampleHeroes().first { it.id == o.getString("id") }
                    val health = Health(o.getInt("hp"), sample.health.maximum, o.optInt("temp"))
                    require(health.current in 0..health.maximum && health.temporary in 0..1000000)
                    sample.copy(name = o.getString("name"), health = health, slots = o.getInt("slots").also { require(it in 0..4) },
                        concentrating = o.getBoolean("concentration"), recovery = o.optInt("recovery", 1), gold = o.optInt("gold", 42),
                        potions = o.optInt("potions", 2), companionHp = o.optInt("companionHp", 1), note = o.getString("note"),
                        staffEquipped = o.optBoolean("staffEquipped", true), conditions = o.optJSONArray("conditions")?.let { a -> List(a.length()) { a.getString(it) } } ?: emptyList(),
                        secondSlots = o.optInt("secondSlots", 2).also { require(it in 0..3) }, thirdSlots = o.optInt("thirdSlots", 2).also { require(it in 0..2) })
                }
            }
        } catch (_: Exception) { error = "The draft save could not be read. Existing data was retained on disk; changes are disabled until the draft is reset." }
    }
    private fun encode(list: List<DraftHero>) = JSONArray().apply {
        list.forEach { h -> put(JSONObject().put("id", h.id).put("name", h.name).put("hp", h.health.current).put("temp", h.health.temporary)
            .put("slots", h.slots).put("secondSlots", h.secondSlots).put("thirdSlots", h.thirdSlots).put("concentration", h.concentrating).put("recovery", h.recovery).put("gold", h.gold)
            .put("potions", h.potions).put("companionHp", h.companionHp).put("note", h.note).put("staffEquipped", h.staffEquipped).put("conditions", JSONArray(h.conditions))) }
    }.toString()
    fun change(label: String, onSaved: () -> Unit = {}, update: (DraftHero) -> DraftHero) {
        val old = hero ?: return
        if (saving || error != null) return
        val updated = update(old)
        val next = heroes.map { if (it.id == old.id) updated else it }
        saving = true
        viewModelScope.launch {
            val success = withContext(Dispatchers.IO) { runCatching { prefs.edit().putString("heroes", encode(next)).commit() }.getOrDefault(false) }
            if (success) { heroes = next; history = (listOf("${old.name} · $label") + history).take(100); onSaved() }
            else error = "Saving failed. Your previous character state is unchanged."
            saving = false
        }
    }
    fun record(roll: DiceRoll) { rolls = (listOf(roll) + rolls).take(50); history = (listOf("${roll.label} · ${roll.formula} = ${roll.total}") + history).take(100) }
}
