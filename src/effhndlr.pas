{ The effect handlers and their shared helpers. InitEffectHandlers installs the handlers in the effect handler table;
  each is called with the creature carrying the effect when the effect is checked during an attack, save or damage roll,
  when it repeats, and when it is removed. }
{$O+,F+,R-,S-,I-,V-,B-,A-}
unit EffHndlr;

interface

uses Types, FxEngine, ViewChar, CbtMap, Pathing, CharHlp, CbtActs, ClassCal, EclTrace, TextRend, GDConsts, GDVars,
  C_Status, C_Effect, C_Ifc, C_Class, C_Race, C_Terr, C_Stat;

{ Installs the handler of each effect id in the effect handler table. Five ids use CbtActs attack routines; ids 86, 88,
  90, 128, 131 and 132 get no handler. EffGrantItemEffect becomes the override handler. }
procedure InitEffectHandlers;

{ Calls the priming entries of CharHlp, ClassCal, EclTrace and FxEngine, so the overlay manager loads those overlays. }
procedure PrimeEffHndlr;

{ Cancels the pending effect and the damage when effId is 0 or effId is the effect being applied.
  @param(effId The effect to cancel, or 0 for whichever effect is pending.) }
procedure NullifyAttack(effId: Byte);

{ Adds effect effId again (with the given strength and duration, its handler called on removal) unless the effect lock
  is set, so the effect repeats.
  @param(cr The creature that carries the effect.)
  @param(effId The effect to add.)
  @param(strength The new effect's strength.)
  @param(minutes The new effect's duration.)
  @returns(True when the effect was added.) }
function AddEffectIfNoLock(cr: Types.PCreature; effId, strength: Byte; minutes: Word): Boolean;

{ Effects 27, 31 and 51..53: the creature's actions end for the round (CharHlp.EndActions).
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffHelpless(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Adds 1 to the saving-throw roll and to the attack roll.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure AddRollBonus(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 1 (Bless): adds 5 to morale and 1 to the attack roll.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffBless(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 2 (Curse): takes 5 from morale (not below 0) and 1 from the attack roll.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffCurse(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 3 (Sticks to Snakes): counts the strength down by curAttacks[1] + curAttacks[2], removing the effect when it
  runs out, and reports the creature fighting snakes, which ends its actions for the round.
  @param(cr The creature that carries the effect.)
  @param(effect The effect's node on the creature.)
  @param(removed Unused.) }
procedure EffSticksToSnakes(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 4 (Dispel Evil): takes 7 from the attack roll when the current creature has creature-type flag bit 0
  (creatureTypeFlags).
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffDispelEvil(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 6: makes the damage fire and magic, and against a target of creature type 10, 9 or 12, or 4, adds 1, 2 or 3 to
  the attack roll and the damage.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffFlameTongue(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 7 (Faerie Fire): raises the creature's AC and acCur[1] by 2; values from 58 up become 60 ($3C), including any
  above 60. Note: a higher stored AC is a better armor class, so the outlined creature becomes harder to hit, not
  easier.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffFaerieFire(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effects 8 and 45 (Protection from Evil): against an evil current creature (alignment 2, 5 or 8), adds 2 to the
  saving-throw roll and takes 2 from the attack roll.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffProtEvil(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effects 9 and 46 (Protection from Good): against a good current creature (alignment 0, 3 or 6), adds 2 to the
  saving-throw roll and takes 2 from the attack roll.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffProtGood(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 10 (Resist Cold): halves cold damage and adds 3 to the saving-throw roll against it.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffResistCold(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 11 (Charm): the first time (strength bit 5 marks it), saves the creature's team in strength bit 6, moves it to
  the team in bit 7, makes it a quick fighter (NPC value $B3 unless the value is above $7F), drops its target and
  recounts the teams; each call except a removal sets morale to 100. On removal the saved team returns and the NPC value
  $B3 is cleared.
  @param(cr The creature that carries the effect.)
  @param(effect The effect's node on the creature.)
  @param(removed True when the effect is being removed.) }
procedure EffCharm(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effects 12 (Enlarge) and 38 (Strength): nothing to do.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffStrengthBonus(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 13: each call counts the strength down by 1, and a call that finds it already 0 kills the creature
  ("Suffocates").
  @param(cr The creature that carries the effect.)
  @param(effect The effect's node on the creature.)
  @param(removed Unused.) }
procedure EffEngulfed(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 14: nothing to do.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffFriends(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 15 (poison damage): repeats itself with duration 10 and, while the creature has more than 1 hit point, deals 1
  point of untyped damage, redrawing the roster outside combat.
  @param(cr The creature that carries the effect.)
  @param(effect The effect's node on the creature.)
  @param(removed Unused.) }
procedure EffSlowPoisonHit(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 16 (Read Magic): nothing to do.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffReadMagic(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 17 (Shield): raises the creature's AC to at least 57 ($39), adds 1 to the saving-throw roll, and negates the
  damage of spell $F.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffShield(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 18: adds 1 to the attack roll when the creature's target has creature-type flag bit 1.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffGnomeHitBonus(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 20 (Resist Fire): except on removal, halves fire damage and adds 3 to the saving-throw roll against it.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffResistFire(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 21 (Silence): the creature can neither use an item nor cast this round ("is silenced", printed while it still
  could).
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffSilence(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 22 (Slow Poison ends): a creature still poisoned dies; then the poison damage effect (15) is removed with the
  effect lock set, so it does not repeat.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffSlowPoisonEnd(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 23 (Spiritual Hammer): gives the creature a +1 hammer (item type $14, name id $F3, "Gains an item") when it has
  none and carries fewer than 16 items, and removes the hammer when the effect is removed. Stats are recalculated either
  way. Note: the readying is applied to the temporary record before it is disposed, so the hammer added to the inventory
  is not readied.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffSpiritualHammer(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 25 (Invisible): unless the current creature has See Invisible, the attack is forbidden and the attack roll
  loses 4 (not on removal).
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffInvisible(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 26: adds 1 to the attack roll when the creature's target has creature-type flag bit 2.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffDwarfHitBonus(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Empty routine with no callers. }
procedure NoopEffHndlrA;

{ Effect 28 (Mirror Image): a spell aimed at this creature alone (not at several targets) strikes an image with chance 1
  - 1/(strength div 16 + 1): the spell is cancelled ("lost an image") and the strength drops by 1; the effect ends when
  the strength reaches 0.
  @param(cr The creature that carries the effect.)
  @param(effect The effect's node on the creature.)
  @param(removed Unused.) }
procedure EffMirrorImage(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 29: takes a quarter off the damage.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffEnfeeble(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 30 (Stinking Cloud, saved): the creature can neither use an item nor cast ("is coughing", printed while it
  still could), and, after its stats are recalculated, acCur[1] drops by 2, or becomes 50 when it is 52 or less, and the
  AC takes that value, shown when it is the current creature.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffCoughing(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 32 (Animate Dead): when it ends, the creature collapses dead (unless the effect lock is set) and its record is
  reset: team from strength div 16, quick fight, its undead rank cleared, its fighter attack level from its fighter
  levels, movement 12, the charmed NPC value and the creature type cleared. Clears the effect's on-removal flag first.
  @param(cr The creature that carries the effect.)
  @param(effect The effect's node on the creature.)
  @param(removed Unused.) }
procedure EffAnimateDead(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 33 (Blind): takes 4 from the attack roll and the saving-throw roll, and lowers both AC values by 4.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffBlind(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 34 (Diseased): runs both disease handlers (43 and 44).
  @param(cr The creature that carries the effect.)
  @param(effect Passed on to both handlers.)
  @param(removed Passed on to both handlers.) }
procedure EffDiseased(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 35 (Confusion): a d100 decides the round: 1..10 the creature runs away (the confusion ends; it is turned, made
  a quick fighter with NPC value $B3 unless the value is above $7F, drops its target and gets effect $8E for 10), 11..60
  it is confused and its actions end, 61..80 it goes berserk (effect $89), 81..100 it is enraged. A successful saving
  throw (type 4, -2) then ends the confusion.
  @param(cr The creature that carries the effect.)
  @param(effect Passed on to EffHelpless.)
  @param(removed Unused.) }
procedure EffConfusion(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 36 (Bestow Curse): takes 4 from the attack roll and the saving-throw roll.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffBestowCurse(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 37: while the creature's initiative is 0, the attack is forbidden and misses.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffBlinking(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 39 (Haste): doubles movement and, the first time (strength bit 4 marks it), ages the creature a year.
  @param(cr The creature that carries the effect.)
  @param(effect The effect's node on the creature.)
  @param(removed Unused.) }
procedure EffHasted(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 40 (the caster's Stinking Cloud): finds the creature's cloud number strength div 16 in the stinking-cloud list.
  If found, restores its four cells (the downed-body tile $1F where a body lies, else the saved tile), unlinks and frees
  it, and draws the cloud tile $1E on the cells of the remaining clouds.
  @param(cr The creature that carries the effect.)
  @param(effect The effect's node on the creature.)
  @param(removed Unused.) }
procedure EffClearStinkingCloud(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Lets defender avoid an attack by the current creature with chance percent, when that creature has a readied weapon and
  CharHlp.CalcDistance from it to defender is above 1: "Avoids it", no damage, the attack misses and the primary hit
  count drops by 1.
  @param(defender The creature attacked.)
  @param(chance The chance to avoid the attack, in percent.) }
procedure AvoidMissile(defender: Types.PCreature; chance: Byte);

{ Finds the item attacker attacks with.
  @param(attacker The attacking creature.)
  @returns(The item CharHlp.FindDamagingRangedWeapon finds, else attacker's readied weapon; nil when no weapon is
    readied.) }
function FindDamagingWeapon(attacker: Types.PCreature): Pointer;

{ Effect 41: attacks by the current creature with a nonmagical weapon are avoided (AvoidMissile at 100%).
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffProtNormalMissiles(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 42 (Slow): halves movement.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffSlow(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 43 (disease, ability loss): repeats itself with duration 60 and lowers the creature's Strength by 1 ("is
  weakened"); once Strength is down to 3 the creature becomes helpless instead.
  @param(cr The creature that carries the effect.)
  @param(effect The effect's node on the creature.)
  @param(removed Unused.) }
procedure EffDiseaseStrength(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 44 (disease, hit points): repeats itself with duration 10 and deals 1 point of untyped damage; once the
  creature is down to 1 hit point it becomes helpless instead.
  @param(cr The creature that carries the effect.)
  @param(effect The effect's node on the creature.)
  @param(removed Unused.) }
procedure EffDiseaseHitPoints(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 47: takes 4 from the attack roll when the current creature is of creature type 2 or $A with icon size 2.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffDwarfGiantDefense(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 48: takes 4 from the attack roll when the current creature is of creature type 1 with icon size 2.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffGnomeBugDefense(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 49 (Prayer): a creature on the team in strength bit 4 gains 1 on the saving-throw roll and the attack roll; any
  other loses 1 on both.
  @param(cr The creature that carries the effect.)
  @param(effect The effect's node on the creature.)
  @param(removed Passed on to AddRollBonus.) }
procedure EffPrayer(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 50: adds 2 to the saving-throw roll against cold, and doubles fire damage when the saving throw failed.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffFireVulnerable(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 54: adds 2 to the saving-throw roll against fire, and doubles cold damage while recentlySaved is 0. Note: the
  cold test reads recentlySaved, the flag set when the game is saved, where EffFireVulnerable reads the saving-throw
  result, so the doubling ignores the creature's save and stops while the game counts as just saved.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffColdVulnerable(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 55 (Poisoned): nothing to do.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffPoisoned(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 56: makes the creature invisible (effect 25, duration 1, strength 12).
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffRenewInvisibility(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 58 (Immobile): the creature cannot move, and its movement is 0 while movement is being calculated.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffImmobile(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 59: adds effect 98 ($62) with duration 0 and strength $FF.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffTrollRegen(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 60: damage from the current creature is negated without a magic weapon and halved with a +1 or +2 one.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffWeaponResistance(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 61: against fire, takes 2 off the damage per damage die (keeping at least 1 per die) and adds 4 to the
  saving-throw roll, and cancels the effect and damage unless the fire is also magic. Note: the damage is a Byte, so
  damage below 2 when a die is taken off wraps to a large value that the per-die floor does not catch.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffNormalFireImmunity(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 62: repeats itself with duration 60 and restores 1 hit point, announcing it.
  @param(cr The creature that carries the effect.)
  @param(effect The effect's node on the creature.)
  @param(removed Unused.) }
procedure EffConRegeneration(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 63 (Minor Globe of Invulnerability): cancels spells below level 4.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffMinorGlobe(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ The creature's target saves against poison (type 0) with modifier saveModifier, or is poisoned and killed.
  @param(cr The attacking creature.)
  @param(saveModifier The saving-throw modifier, read as a signed value.) }
procedure PoisonTarget(cr: Types.PCreature; saveModifier: Byte);

{ The creature's target saves (type 0), or is paralyzed (effect 52, strength 12) for duration.
  @param(cr The attacking creature.)
  @param(duration How long the paralysis lasts.)
  @param(saveModifier Unused.) }
procedure ParalyzeTarget(cr: Types.PCreature; duration: Word; saveModifier: Byte);

{ Effect 64: poison attack, saved against at +0.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffPoisonAttack(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 65: poison attack, saved against at +4.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffWeakPoisonAttack(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 66: poison attack, saved against at +2.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffMildPoisonAttack(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 67: paralyzing attack lasting 2d8.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffParalyzingHit(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 68: sets Intelligence and Wisdom to 7 ("is stupid"); in combat the creature can no longer cast and loses the
  spell it was casting.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffFeeblemind(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 69: against a current creature of type $13, takes 4 from the attack roll, and forbids the attack unless that
  creature has See Invisible.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffInvisibleToAnimals(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 70: poison attack, saved against at -2.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffStrongPoisonAttack(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 71: the attack is forbidden and the attack roll loses 4.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffDustOfDisappearance(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 72: a 95% chance to turn invisible (effect 25, duration 1, strength 12).
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffCamouflage(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 73: cancels the effect and the damage of attacks with damage-type bit $20 ("is unaffected").
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffImmuneBreath(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 74: nothing to do.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffSpellFailure(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 75: against a target of creature type 3, the damage becomes 1d12 * 3 + 4 + CharHlp.StrDamageAdjust and the
  attack roll gains 2.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffDragonSlayer(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 76: adds 3 to the attack roll and the damage against a target of creature type 8.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffBaneWeapon(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 77 (berserk): makes the creature a quick fighter with NPC value $B3 ($B2 for an NPC above $7F other than $B3).
  In combat it also targets the first other creature in its target list, joins the opposing team, stops casting and
  "goes berzerk". On removal $B3 is cleared and it returns to team 0.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffBerserk(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 78: revives the dead creature at its current hit points, or repeats itself with duration 1.
  @param(cr The creature that carries the effect.)
  @param(effect The effect's node on the creature.)
  @param(removed Unused.) }
procedure EffDelayedRevival(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 79: deals 2d10 fire and magic damage to the creature's target.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffFireTouch(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 80: deals 1d4 acid damage to the creature's target.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffAcidTouch(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 81: halves the damage.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffHalfDamage(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 82: against fire or cold, a saving throw (type 4) negates the damage when the current spell allows a save, and
  otherwise the damage is halved.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffFireColdResistance(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 83: a stoning gaze at the creature's target ("gazes..."). When the gazer has effect 127 ($7F), an equipped item
  of the target with any name id $76 reflects it back at the gazer ("reflects it!"). Whoever it lands on saves (type 1)
  or is stoned.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffPetrifyingGaze(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 84: absorbs electricity: the effect and damage are cancelled and the creature gains 8 hit points, with no
  limit. Note: a d8 is rolled and its result discarded.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffAbsorbElectricity(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 85: weapons of weapon class 1 deal 1 damage.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffResistPiercing(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 89: in round 0 with an attack roll of 0, the strength is cut to its low four bits (clearing bit 4); otherwise
  the first attack (bit 4 not yet set) misses and sets it.
  @param(cr Unused.)
  @param(effect The effect's node on the creature.)
  @param(removed Unused.) }
procedure EffDisplaced(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 91 (the caster's Cloudkill): finds the creature's cloud number strength div 16 in the Cloudkill list. If found,
  restores its nine cells (the downed-body tile $1F where a body lies, else the saved tile), unlinks and frees it, and
  draws the cloud tile $1C on the cells of the remaining clouds.
  @param(cr The creature that carries the effect.)
  @param(effect The effect's node on the creature.)
  @param(removed Unused.) }
procedure EffClearCloudkill(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 93: halves fire damage.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffHalfFire(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 94: halves damage from weapons whose weapon class has bit 0 or bit 7 set.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffHalfPierceBash(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 95: clears the effect's on-removal flag and kills the creature ("Falls dead") if it is still enabled.
  @param(cr The creature that carries the effect.)
  @param(effect The effect's node on the creature.)
  @param(removed Unused.) }
procedure EffFightOn(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 97: against saving-throw types 2 and 4, adds 1..5 to the saving-throw roll by Constitution (4..6 +1, 7..10 +2,
  11..13 +3, 14..17 +4, 18..20 +5). Note: for any other Constitution the bonus is never set, so an undefined amount is
  added.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffConSpellSave(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 98: restores 3 hit points, up to the maximum.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffRegenerate(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 99: revives a dying creature with less than 6 overkill at 6 - overkill hit points, or an unconscious one at 6;
  once revived it gets effect 95 for 1d4 + 1 and loses this effect (its on-removal flag cleared first).
  @param(cr The creature that carries the effect.)
  @param(effect The effect's node on the creature.)
  @param(removed Unused.) }
procedure EffCanFightOn(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 100: damage that is neither fire nor acid adds effect 102 for 3d6, so the creature can revive.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffTrollBurn(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 101: adds effect 59 for 3 unless the creature already has effect 98 or 59.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffTrollHeal(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 102: revives the dead creature at full hit points, or repeats itself with duration 1.
  @param(cr The creature that carries the effect.)
  @param(effect The effect's node on the creature.)
  @param(removed Unused.) }
procedure EffTrollReturn(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 103: adds 1d6 damage against a target without effects 20, 54 and 61.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffFireDamageBonus(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 104: a 60% chance to avoid the current creature's weapon attacks (AvoidMissile).
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffDodgeMissiles(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Magic resistance: when a spell effect or magic damage is pending, a d100 at or below baseChance + 5 * (11 - the
  current spell's caster level) cancels it. Note: the threshold is a Byte, so when a high caster level takes it below 0
  it wraps to a large value and the resistance becomes certain.
  @param(baseChance The resistance in percent against a level-11 caster.) }
procedure MagicResistance(baseChance: Byte);

{ Effect 105: magic resistance with base 50.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffStrongMagicResistance(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 106: magic resistance with base 15.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffWeakMagicResistance(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 107: a 90% chance to cancel Sleep (53) and Charm (11).
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffElfResistance(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 108: cancels Charm and Sleep.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffImmuneSleepCharm(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 109: cancels paralysis (effect 52).
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffImmuneParalysis(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 110: cancels the effect and the damage of cold attacks.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffImmuneCold(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 111: cancels Poisoned (55) and paralysis (52), and saving throws of type 0 succeed.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffImmuneParalysisPoison(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 112: cancels the effect and the damage of fire attacks.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffImmuneFire(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 113: takes 1 off fire damage per damage die, keeping at least 1 per die. Note: the damage is a Byte, so fire
  damage of 0 wraps to a large value that the per-die floor does not catch.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffFireDamageReduction(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 114: halves electrical damage.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffHalfElectricity(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 115: halves damage from weapons of weapon class 0 or with class bit 0 set.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffHalfSlashPierce(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 116: halves damage from magic weapons.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffHalfMagicWeapon(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 117: when the current creature's readied weapon is item type $55, the damage becomes 1d6 + 1.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffHolyWater(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 118: halves cold damage.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffHalfCold(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 119: without a magic weapon, damage from a current creature of race above 0 or terrain type below 4 is negated.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffNeedMagicWeapon(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 120: a 50% chance to avoid attacks with a readied weapon of item type $57 or $58 (AvoidMissile).
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffDodgeBoulders(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 121: a 25% chance, when CharHlp.CalcDistance to the target is below 4, to spit acid ("Spits Acid"): 8d4 damage
  of the pending damage type, halved on a save (type 3). The spitting ends the creature's actions, and the creature then
  loses this effect and effect 80.
  @param(cr The creature that carries the effect.)
  @param(effect The effect's node on the creature.)
  @param(removed Unused.) }
procedure EffSpitAcid(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 122: the creature's target saves (type 0) or is paralyzed (effect 52, strength $FF).
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffParalyzingTouch(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 123: deals 2d8 cold and magic damage to the creature's target.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffColdTouch(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 124: a 30% chance to cancel Charm and Sleep.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffHalfElfResistance(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 125: cancels Charm, Sleep, paralysis and Poisoned, and saving throws of type 0 succeed.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffImmuneCharmSleepParalysisPoison(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 126: a paralyzing gaze at the creature's target ("gazes..."), which saves (type 1) or is paralyzed (effect 52,
  strength $FF).
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffParalyzingGaze(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 129: cancels any pending spell effect or magic damage.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffImmuneMagic(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 130: an attack with item type $1C named $87 removes the creature outright (status 8, gone), removes its effects
  that end at 0 hit points, triggers its condition-13 effects and marks it downed if it is still disabled. Note: the
  item's type is read before the item is checked for nil.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffBanishByWeapon(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ The override handler, called while GDVars.overrideFlag is set: the effect an item grants is added permanently, with
  its handler run outside combat, or removed on removal. Clears the override flag first.
  @param(cr The creature that carries the effect.)
  @param(effect The item that grants the effect.)
  @param(removed True when the effect is being removed.) }
procedure EffGrantItemEffect(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 133: cancels effects 142, 29 and 68 ($8E, $1D, $44) and attacks with damage-type bit $40.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffImmuneDebilitation(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 134: adds the creature's ranger level (classLevels[4]) to the damage when its target has creature-type flag bit
  3.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffRangerDamageBonus(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 135: cancels the effect and the damage of electrical attacks.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffImmuneElectricity(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 136: the creature cannot move.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffEntangle(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 137: makes the creature a quick fighter with NPC value $B3 ($B2 for an NPC above $7F other than $B3), targeting
  the first other creature in its target list and joining the opposing team. On removal $B3 is cleared and its team
  comes back from the strength.
  @param(cr The creature that carries the effect.)
  @param(effect The effect's node on the creature.)
  @param(removed True when the effect is being removed.) }
procedure EffConfusedBerserk(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 138: makes the creature invisible (effect 25, duration and strength $FF).
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffLastingInvisibility(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 141: on removal, sets the disease count to (paladin level - 1) div 5 + 1.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffRecentCure(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 142: on removal, clears the charmed NPC value $B3 (and quick fight with it) and the turned flag.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffFear(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 143: a current creature that hits from CharHlp.CalcDistance below 2 "gets zapped" for double the damage as
  magic damage.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffZapAttacker(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 145: a target with creature-type flag bit 0 that fails a saving throw (type 4) is dispelled (status gone), and
  the current creature loses effects 4 and 145; otherwise the target "resists dispel evil".
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffDispelEvilTouch(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Empty routine with no callers. }
procedure NoopEffHndlrB;

{ Effects 5, 19, 24, 92, 127, 140 and 146: nothing to do.
  @param(cr Unused.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffNone(cr: Types.PCreature; effect: Pointer; removed: Boolean);

implementation

const
  { The viewer needs this effect to see invisible targets. }
  SEE_INVISIBLE = 24;

type
  { Non-negative 16-bit value for unsigned division. }
  TNN16 = 0..32767;

procedure PrimeEffHndlr;
begin
  CharHlp.PrimeCharHlp;
  ClassCal.PrimeClassCal;
  EclTrace.PrimeEclTrace;
  FxEngine.PrimeFxEngine;
end;

procedure NullifyAttack(effId: Byte);
begin
  if (effId = 0) or (GDVars.effectCheck = effId) then
  begin GDVars.damage := 0; GDVars.effectCheck := 0; end;
end;

function AddEffectIfNoLock(cr: Types.PCreature; effId, strength: Byte; minutes: Word): Boolean;
begin
  if GDVars.effectLock <> 0 then AddEffectIfNoLock := False
  else begin
    AddEffectIfNoLock := True;
    FxEngine.AddEffect(cr, effId, minutes, strength, True);
  end;
end;

procedure EffHelpless(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if Byte(CharHlp.EndActions(cr)) <> 0 then;
end;

procedure AddRollBonus(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  Inc(GDVars.saveRoll);
  Inc(GDVars.attackRoll);
end;

procedure EffBless(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin Inc(GDVars.combatMorale, 5); Inc(GDVars.attackRoll); end;

procedure EffCurse(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if GDVars.combatMorale < 5 then GDVars.combatMorale := 0 else Dec(GDVars.combatMorale, 5);
  Dec(GDVars.attackRoll);
end;

procedure EffSticksToSnakes(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var
  attacks: Byte;
  { Unused in this version; see the other implementations of this routine. }
  ended: Boolean;
begin
  attacks := cr^.curAttacks[1] + cr^.curAttacks[2];
  if Types.PEffect(effect)^.strength > attacks then
    Dec(Types.PEffect(effect)^.strength, attacks)
  else
    FxEngine.RemoveEffect(cr, 3, nil);
  CharHlp.PrintNameStringAnim(cr, True, 'is fighting with snakes');
  CharHlp.ClearMessageWindow;
  ended := CharHlp.EndActions(cr);
end;

procedure EffDispelEvil(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if (GDVars.curChar^.creatureTypeFlags and 1) <> 0 then Dec(GDVars.attackRoll, 7);
end;

procedure EffFlameTongue(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var bonus: Byte;
begin
  GDVars.combatTarget := cr^.combatAddr^.other;
  case GDVars.combatTarget^.charType of
    10: bonus := 1;
    9, 12: bonus := 2;
    4: bonus := 3;
  else
    bonus := 0;
  end;
  Inc(GDVars.attackRoll, bonus);
  Inc(GDVars.damage, bonus);
  GDVars.elementMask := 9;
end;

procedure EffFaerieFire(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if cr^.acCur[0] < 58 then Inc(cr^.acCur[0], 2) else cr^.acCur[0] := 60;
  if cr^.acCur[1] < 58 then Inc(cr^.acCur[1], 2) else cr^.acCur[1] := 60;
end;

procedure EffProtEvil(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if (GDVars.curChar^.alignment = 2) or (GDVars.curChar^.alignment = 5) or (GDVars.curChar^.alignment = 8) then
  begin Inc(GDVars.saveRoll, 2); Dec(GDVars.attackRoll, 2); end;
end;

procedure EffProtGood(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if (GDVars.curChar^.alignment = 0) or (GDVars.curChar^.alignment = 3) or (GDVars.curChar^.alignment = 6) then
  begin Inc(GDVars.saveRoll, 2); Dec(GDVars.attackRoll, 2); end;
end;

procedure EffResistCold(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if (GDVars.elementMask and 2) <> 0 then
  begin GDVars.damage := GDVars.damage div 2; Inc(GDVars.saveRoll, 3); end;
end;

procedure EffCharm(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if removed then begin
    cr^.hostile := (Types.PEffect(effect)^.strength and $40) div $40;
    if cr^.npc = $B3 then cr^.npc := 0;
  end else begin
    if (Types.PEffect(effect)^.strength and $20) = 0 then begin
      Types.PEffect(effect)^.strength := Types.PEffect(effect)^.strength + $20 + cr^.hostile * $40;
      cr^.hostile := Types.PEffect(effect)^.strength div $80;
      cr^.quickfight := 1;
      if cr^.npc <= $7F then cr^.npc := $B3;
      cr^.combatAddr^.other := nil;
      CharHlp.CountTeams;
    end;
    GDVars.combatMorale := 100;
  end;
end;

procedure EffStrengthBonus(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin end;

procedure EffEngulfed(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if Types.PEffect(effect)^.strength = 0 then
    FxEngine.KillCreature(cr, C_Status.DEAD_STATUS, 'Suffocates')
  else
    Dec(Types.PEffect(effect)^.strength);
end;

procedure EffFriends(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin end;

procedure EffSlowPoisonHit(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if EffHndlr.AddEffectIfNoLock(cr, C_Effect.POISON_DAMAGE, Types.PEffect(effect)^.strength, 10) then
    if cr^.hpCur > 1 then begin
      GDVars.elementMask := 0;
      FxEngine.InflictNonWeaponDamage(cr, 1, 0, False);
      if GDVars.ifcState <> C_Ifc.IN_COMBAT then CharHlp.DisplayParty(GDVars.curChar);
    end;
end;

procedure EffReadMagic(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin end;

procedure EffShield(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if cr^.acCur[0] < 57 then cr^.acCur[0] := 57;
  Inc(GDVars.saveRoll);
  if GDVars.spellId = 15 then GDVars.damage := 0;
end;

procedure EffGnomeHitBonus(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  foeIndex: Integer;
begin
  GDVars.combatTarget := cr^.combatAddr^.other;
  if (GDVars.combatTarget^.creatureTypeFlags and 2) <> 0 then Inc(GDVars.attackRoll);
end;

procedure EffResistFire(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if (not removed) and ((GDVars.elementMask and 1) <> 0) then
  begin GDVars.damage := GDVars.damage div 2; Inc(GDVars.saveRoll, 3); end;
end;

procedure EffSilence(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if cr^.combatAddr^.itemUseAllowed <> 0 then
    CharHlp.PrintCreatureMessage(cr, 'is silenced', 10, True);
  cr^.combatAddr^.itemUseAllowed := 0;
  cr^.combatAddr^.castAllowed := 0;
end;

procedure EffSlowPoisonEnd(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var existing: Pointer;
begin
  if CharHlp.HasEffect(cr, C_Effect.POISONED, Types.PEffect(existing)) then
    FxEngine.KillCreature(cr, C_Status.DEAD_STATUS, 'dies from poison');
  GDVars.effectLock := 1;
  FxEngine.RemoveEffect(cr, C_Effect.POISON_DAMAGE, nil);
  GDVars.effectLock := 0;
end;

procedure EffSpiritualHammer(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var
  item: Types.PItem;
  found: Byte;
begin
  item := cr^.itemsAddr;
  found := 0;
  while (item <> nil) and (found = 0) do
    if (item^.itemType = 20) and (item^.nameIds[3] = 243) then
      found := 1
    else
      item := item^.next;
  if removed and (item <> nil) then
    CharHlp.RemoveItem(cr, item);
  if (not removed) and (found = 0) and (cr^.numberOfItems < 16) then begin
    New(item);
    FillChar(item^, SizeOf(item^), 0);
    item^.itemType := 20;
    item^.nameIds[2] := 20;
    item^.nameIds[3] := 243;
    item^.plus := 1;
    item^.effect := 23;
    item^.special := $A0;
    CharHlp.AddItemCopy(cr, item);
    ViewChar.ToggleReadyItem(item);
    Dispose(item);
    CharHlp.PrintCreatureMessage(cr, 'Gains an item', 10, True);
  end;
  CharHlp.RecalcStats(cr);
end;

procedure EffInvisible(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var existing: Pointer;
begin
  if not removed then
    if not CharHlp.HasEffect(GDVars.curChar, EffHndlr.SEE_INVISIBLE, Types.PEffect(existing)) then begin
      GDVars.suppressTargeting := 1;
      Dec(GDVars.attackRoll, 4);
    end;
end;

procedure EffDwarfHitBonus(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  foeIndex: Integer;
begin
  GDVars.combatTarget := cr^.combatAddr^.other;
  if (GDVars.combatTarget^.creatureTypeFlags and 4) <> 0 then Inc(GDVars.attackRoll);
end;

procedure EffMirrorImage(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if (FxEngine.RollDice(1, (Types.PEffect(effect)^.strength div 16) + 1) > 1) and (GDVars.spellId > 0) and
      (GDVars.multiTarget = 0) then begin
    EffHndlr.NullifyAttack(0);
    CharHlp.PrintCreatureMessage(cr, 'lost an image', 10, True);
    Dec(Types.PEffect(effect)^.strength);
    if Types.PEffect(effect)^.strength = 0 then FxEngine.RemoveEffect(cr, C_Effect.MIRROR_IMAGE, nil);
  end;
end;

procedure EffEnfeeble(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  GDVars.damage := GDVars.damage - GDVars.damage div 4;
end;

procedure EffCoughing(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if cr^.combatAddr^.itemUseAllowed <> 0 then
    CharHlp.PrintCreatureMessage(cr, 'is coughing', 10, True);
  cr^.combatAddr^.itemUseAllowed := 0;
  cr^.combatAddr^.castAllowed := 0;
  CharHlp.RecalcStats(cr);
  if cr^.acCur[1] > 52 then Dec(cr^.acCur[1], 2)
  else cr^.acCur[1] := 50;
  cr^.acCur[0] := cr^.acCur[1];
  if cr = GDVars.curChar then
    CharHlp.CombatPrintCreatureInfo(cr);
end;

procedure EffAnimateDead(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  Types.PEffect(effect)^.onRemove := False;
  if GDVars.effectLock = 0 then
    FxEngine.KillCreature(cr, C_Status.DEAD_STATUS, 'collapses');
  cr^.hostile := Types.PEffect(effect)^.strength div 16;
  cr^.quickfight := 1;
  cr^.levelUndead := 0;
  cr^.attackLevel := ClassCal.EarlierClassActive(cr) * cr^.oldClassLevels[C_Class.FIGHTER_LEVEL] +
      cr^.classLevels[C_Class.FIGHTER_LEVEL];
  cr^.moveRate := 12;
  if cr^.npc = $B3 then cr^.npc := 0;
  cr^.charType := 0;
end;

procedure EffBlind(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  Dec(GDVars.attackRoll, 4);
  Dec(cr^.acCur[0], 4);
  Dec(cr^.acCur[1], 4);
  Dec(GDVars.saveRoll, 4);
end;

procedure EffDiseased(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  FxEngine.CallEffectHandler(C_Effect.DISEASE_STRENGTH, cr, effect, removed);
  FxEngine.CallEffectHandler(C_Effect.DISEASE_HIT_POINTS, cr, effect, removed);
end;

procedure EffConfusion(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var
  roll: Byte;
  saved: Boolean;
begin
  roll := FxEngine.RollDice(1, 100);
  case roll of
    1..10:
      begin
        FxEngine.RemoveEffect(cr, 35, nil);
        cr^.combatAddr^.turned := 1;
        cr^.quickfight := 1;
        if cr^.npc <= $7F then cr^.npc := $B3;
        cr^.combatAddr^.other := nil;
        FxEngine.AddEffectWithMessage(cr, 142, 10, 0, True, True, False, 'runs away');
      end;
    11..60:
      begin
        CharHlp.PrintNameStringAnim(cr, True, 'is confused');
        CharHlp.ClearMessageWindow;
        EffHndlr.EffHelpless(cr, effect, False);
      end;
    61..80:
      begin
        FxEngine.AddEffectWithMessage(cr, 137, 1, cr^.hostile, True, True, False, 'goes berserk');
        FxEngine.CallEffectHandler(137, cr, nil, False);
      end;
    81..100:
      begin
        CharHlp.PrintNameStringAnim(cr, True, 'is enraged');
        CharHlp.ClearMessageWindow;
      end;
  end;
  saved := FxEngine.RollSavingThrow(cr, 4, -2);
  if saved then
    FxEngine.RemoveEffect(cr, 35, nil);
end;

procedure EffBestowCurse(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin Dec(GDVars.attackRoll, 4); Dec(GDVars.saveRoll, 4); end;

procedure EffBlinking(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if cr^.combatAddr^.initiative = 0 then
  begin GDVars.suppressTargeting := 1; GDVars.attackRoll := -1; end;
end;

procedure EffHasted(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if (Types.PEffect(effect)^.strength and $10) = 0 then begin
    Types.PEffect(effect)^.strength := Types.PEffect(effect)^.strength + 16;
    CharHlp.PrintCreatureMessage(cr, 'ages', 10, True);
    Inc(cr^.age);
  end;
  GDVars.movementAttacks := GDVars.movementAttacks shl 1;
end;

procedure EffClearStinkingCloud(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var
  prev: Types.PCloudNode;
  node: Types.PCloudNode;
  found: Boolean;
  k: Byte;
  i: Byte;
  col: Byte;
  row: Byte;
begin
  k := Types.PEffect(effect)^.strength div 16;
  found := False;
  node := GDVars.stinkHead;
  while (node <> nil) and not found do
    if (node^.caster = cr) and (node^.idx = k) then
      found := True
    else
      node := node^.next;
  if not found then Exit;
  CharHlp.PrintBottomLine('The air clears a little...');
  for i := 1 to 4 do
    if node^.exists[i] <> 0 then begin
      col := node^.ulX + GDConsts.directionDx[GDConsts.stinkingCloudDirections[i]];
      row := node^.ulY + GDConsts.directionDy[GDConsts.stinkingCloudDirections[i]];
      found := False;
      for k := 1 to GDVars.downedCount do
        if (GDVars.downedCharacters[k].cr <> nil) and (GDVars.downedCharacters[k].x = col)
           and (GDVars.downedCharacters[k].y = row) then
          found := True;
      if found then
        GDVars.combatArena^.cells[row, col] := C_Terr.CORPSE
      else
        GDVars.combatArena^.cells[row, col] := node^.under[i];
    end;
  prev := GDVars.stinkHead;
  if prev = node then
    GDVars.stinkHead := prev^.next
  else
    while prev^.next <> node do
      prev := prev^.next;
  prev^.next := node^.next;
  FreeMem(node, SizeOf(node^));
  prev := GDVars.stinkHead;
  while prev <> nil do begin
    for i := 1 to 4 do
      if prev^.exists[i] <> 0 then
        GDVars.combatArena^.cells[prev^.ulY + GDConsts.directionDy[GDConsts.stinkingCloudDirections[i]],
                                  prev^.ulX +
                                  GDConsts.directionDx[GDConsts.stinkingCloudDirections[i]]] := C_Terr.STINKING_CLOUD;
    prev := prev^.next;
  end;
end;

procedure AvoidMissile(defender: Types.PCreature; chance: Byte);
begin
  if GDVars.curChar^.equipped[0] <> nil then
    if CharHlp.CalcDistance(GDVars.curChar, defender) > 1 then
      if FxEngine.RollDice(1, 100) <= chance then begin
        CharHlp.PrintCreatureMessage(defender, 'Avoids it', 10, True);
        GDVars.damage := 0;
        GDVars.attackRoll := -1;
        Dec(GDVars.phaseHits[1]);
      end;
end;

function FindDamagingWeapon(attacker: Types.PCreature): Pointer;
var item: Pointer; resolved: Byte;
begin
  item := nil;
  if attacker^.equipped[0] <> nil then begin
    resolved := Byte(CharHlp.FindDamagingRangedWeapon(attacker, item));
    if (resolved = 0) or (item = nil) then item := attacker^.equipped[0];
  end;
  FindDamagingWeapon := item;
end;

procedure EffProtNormalMissiles(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if EffHndlr.FindDamagingWeapon(GDVars.curChar) <> nil then
    if Types.PItem(EffHndlr.FindDamagingWeapon(GDVars.curChar))^.plus = 0 then
      EffHndlr.AvoidMissile(cr, 100);
end;

procedure EffSlow(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  GDVars.movementAttacks := GDVars.movementAttacks div 2;
end;

procedure EffDiseaseStrength(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var existing: Pointer;
begin
  if EffHndlr.AddEffectIfNoLock(cr, C_Effect.DISEASE_STRENGTH, Types.PEffect(effect)^.strength, 60) then begin
    if cr^.stats[C_Stat.STRENGTH].current > 3 then begin
      CharHlp.PrintCreatureMessage(cr, 'is weakened', 10, True);
      Dec(cr^.stats[C_Stat.STRENGTH].current);
    end else
      if not CharHlp.HasEffect(cr, C_Effect.HELPLESS, Types.PEffect(existing)) then
        FxEngine.AddEffect(cr, C_Effect.HELPLESS, 0, 255, False);
  end;
end;

procedure EffDiseaseHitPoints(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var existing: Pointer;
begin
  if EffHndlr.AddEffectIfNoLock(cr, C_Effect.DISEASE_HIT_POINTS, Types.PEffect(effect)^.strength, 10) then begin
    if cr^.hpCur > 1 then begin
      GDVars.elementMask := 0;
      FxEngine.InflictNonWeaponDamage(cr, 1, 0, False);
      if GDVars.ifcState <> C_Ifc.IN_COMBAT then CharHlp.DisplayParty(GDVars.curChar);
    end else
      if not CharHlp.HasEffect(cr, C_Effect.HELPLESS, Types.PEffect(existing)) then
        FxEngine.AddEffect(cr, C_Effect.HELPLESS, 0, 255, False);
  end;
end;

procedure EffDwarfGiantDefense(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  foeIndex: Integer;
begin
  GDVars.combatTarget := cr^.combatAddr^.other;
  if (GDVars.curChar^.charType = 2) or (GDVars.curChar^.charType = 10) then
    if (GDVars.curChar^.iconDim and $7F) = 2 then Dec(GDVars.attackRoll, 4);
end;

procedure EffGnomeBugDefense(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if GDVars.curChar^.charType = 1 then
    if (GDVars.curChar^.iconDim and $7F) = 2 then Dec(GDVars.attackRoll, 4);
end;

procedure EffPrayer(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var team: Byte;
begin
  team := (Types.PEffect(effect)^.strength and $10) div 16;
  if Byte(cr^.hostile) = team then EffHndlr.AddRollBonus(cr, effect, removed)
  else begin Dec(GDVars.attackRoll); Dec(GDVars.saveRoll); end;
end;

procedure EffFireVulnerable(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if (GDVars.elementMask and 2) <> 0 then Inc(GDVars.saveRoll, 2)
  else if (GDVars.elementMask and 1) <> 0 then
    if not GDVars.saveResult then GDVars.damage := GDVars.damage shl 1;
end;

procedure EffColdVulnerable(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if (GDVars.elementMask and 1) <> 0 then Inc(GDVars.saveRoll, 2)
  else if (GDVars.elementMask and 2) <> 0 then
    if GDVars.recentlySaved = 0 then GDVars.damage := GDVars.damage shl 1;
end;

procedure EffPoisoned(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin end;

procedure EffRenewInvisibility(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  FxEngine.AddEffect(cr, C_Effect.INVISIBLE, 1, 12, False);
end;

procedure EffImmobile(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  cr^.combatAddr^.movement := 0;
  if GDVars.computingMove <> 0 then GDVars.movementAttacks := 0;
end;

procedure EffTrollRegen(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  FxEngine.AddEffect(cr, 98, 0, 255, False);
end;

procedure EffWeaponResistance(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var item: Types.PItem;
begin
  item := Types.PItem(EffHndlr.FindDamagingWeapon(GDVars.curChar));
  if (item = nil) or (item^.plus = 0) then GDVars.damage := 0
  else if (item <> nil) and (item^.plus < 3) then GDVars.damage := GDVars.damage div 2;
end;

procedure EffNormalFireImmunity(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var i: Byte;
begin
  if (GDVars.elementMask and 1) <> 0 then begin
    for i := 1 to GDVars.damageDice do begin
      Dec(GDVars.damage, 2);
      if GDVars.damage < GDVars.damageDice then GDVars.damage := GDVars.damageDice;
    end;
    Inc(GDVars.saveRoll, 4);
    if (GDVars.elementMask and 8) = 0 then EffHndlr.NullifyAttack(0);
  end;
end;

procedure EffConRegeneration(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if EffHndlr.AddEffectIfNoLock(cr, 62, Types.PEffect(effect)^.strength, 60) then
    if FxEngine.RestoreHitPoints(cr, 1, True) then
      CharHlp.AnnounceHealStatus(cr);
end;

procedure EffMinorGlobe(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if (GDVars.spellId > 0) and (GDConsts.spellProperties[GDVars.spellId].level < 4) then EffHndlr.NullifyAttack(0);
end;

procedure PoisonTarget(cr: Types.PCreature; saveModifier: Byte);
begin
  GDVars.combatTarget := cr^.combatAddr^.other;
  if not FxEngine.RollSavingThrow(GDVars.combatTarget, 0, ShortInt(saveModifier)) then begin
    CharHlp.PrintCreatureMessage(GDVars.combatTarget, 'is Poisoned', 10, False);
    TextRend.PauseOnly;
    FxEngine.AddEffect(GDVars.combatTarget, C_Effect.POISONED, 0, 255, False);
    FxEngine.KillCreature(GDVars.combatTarget, C_Status.DEAD_STATUS, 'is killed');
  end;
end;

procedure ParalyzeTarget(cr: Types.PCreature; duration: Word; saveModifier: Byte);
begin
  GDVars.combatTarget := cr^.combatAddr^.other;
  if not FxEngine.RollSavingThrow(GDVars.combatTarget, 0, 0) then begin
    CharHlp.PrintNameStringAnim(GDVars.combatTarget, True, 'is Paralyzed');
    FxEngine.AddEffect(GDVars.combatTarget, C_Effect.PARALYZED, duration, 12, False);
  end;
end;

procedure EffPoisonAttack(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  EffHndlr.PoisonTarget(cr, 0);
end;

procedure EffWeakPoisonAttack(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  EffHndlr.PoisonTarget(cr, 4);
end;

procedure EffMildPoisonAttack(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  EffHndlr.PoisonTarget(cr, 2);
end;

procedure EffParalyzingHit(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  EffHndlr.ParalyzeTarget(cr, FxEngine.RollDice(2, 8), 0);
end;

procedure EffFeeblemind(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  cr^.stats[C_Stat.INTELLIGENCE].current := 7;
  cr^.stats[C_Stat.WISDOM].current := 7;
  CharHlp.PrintCreatureMessage(cr, 'is stupid', 10, True);
  if GDVars.ifcState = C_Ifc.IN_COMBAT then begin
    cr^.combatAddr^.castAllowed := 0;
    if cr^.combatAddr^.spellCast > 0 then begin
      CharHlp.PrintCreatureMessage(cr, 'lost a spell', 12, True);
      CharHlp.RemoveSpell(cr, cr^.combatAddr^.spellCast);
      cr^.combatAddr^.spellCast := 0;
    end;
  end;
end;

procedure EffInvisibleToAnimals(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var existing: Pointer;
begin
  if GDVars.curChar^.charType = 19 then begin
    if not CharHlp.HasEffect(GDVars.curChar, EffHndlr.SEE_INVISIBLE,
                             Types.PEffect(existing)) then GDVars.suppressTargeting := 1;
    Dec(GDVars.attackRoll, 4);
  end;
end;

procedure EffStrongPoisonAttack(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  EffHndlr.PoisonTarget(cr, 254);
end;

procedure EffDustOfDisappearance(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin GDVars.suppressTargeting := 1; Dec(GDVars.attackRoll, 4); end;

procedure EffCamouflage(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if FxEngine.RollDice(1, 100) <= 95 then FxEngine.AddEffect(cr, C_Effect.INVISIBLE, 1, 12, False);
end;

procedure EffImmuneBreath(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if (GDVars.elementMask and $20) > 0 then begin
    EffHndlr.NullifyAttack(0);
    CharHlp.PrintCreatureMessage(cr, 'is unaffected', 10, True);
  end;
end;

procedure EffSpellFailure(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  foeIndex: Integer;
begin end;

procedure EffDragonSlayer(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  GDVars.combatTarget := cr^.combatAddr^.other;
  if GDVars.combatTarget^.charType = 3 then begin
    GDVars.damage := FxEngine.RollDice(1, 12) * 3 + 4 + CharHlp.StrDamageAdjust(cr);
    Inc(GDVars.attackRoll, 2);
  end;
end;

procedure EffBaneWeapon(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  GDVars.combatTarget := cr^.combatAddr^.other;
  if GDVars.combatTarget^.charType = 8 then
  begin Inc(GDVars.attackRoll, 3); Inc(GDVars.damage, 3); end;
end;

procedure EffBerserk(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if not removed then begin
    cr^.quickfight := 1;
    if (cr^.npc <= $7F) or (cr^.npc = $B3) then cr^.npc := $B3
    else cr^.npc := $B2;
    if GDVars.ifcState = C_Ifc.IN_COMBAT then begin
      cr^.combatAddr^.other := nil;
      Pathing.BuildTargetList(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), 255, 255, CbtMap.GetIconSize(cr),
                              GDVars.combatArena);
      cr^.combatAddr^.other := GDVars.combatCreatures[GDVars.targetList[2].idx];
      cr^.combatAddr^.castAllowed := 0;
      cr^.hostile := cr^.combatAddr^.other^.hostile xor 1;
      CharHlp.PrintCreatureMessage(cr, 'goes berzerk', 10, True);
    end;
  end else begin
    if cr^.npc = $B3 then cr^.npc := 0;
    cr^.hostile := 0;
  end;
end;

procedure EffDelayedRevival(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  repeated: Boolean;
begin
  if not FxEngine.ReviveDeadCreature(cr, cr^.hpCur) then
    repeated := EffHndlr.AddEffectIfNoLock(cr, 78, Types.PEffect(effect)^.strength, 1);
end;

procedure EffFireTouch(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  GDVars.elementMask := 9;
  FxEngine.InflictNonWeaponDamage(cr^.combatAddr^.other, FxEngine.RollDamageDice(2, 10), 0, False);
end;

procedure EffAcidTouch(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  GDVars.elementMask := $10;
  FxEngine.InflictNonWeaponDamage(cr^.combatAddr^.other, FxEngine.RollDamageDice(1, 4), 0, False);
end;

procedure EffHalfDamage(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin GDVars.damage := GDVars.damage div 2; end;

procedure EffFireColdResistance(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if ((GDVars.elementMask and 1) <> 0) or ((GDVars.elementMask and 2) <> 0) then
    if FxEngine.RollSavingThrow(cr, 4, 0) and (GDConsts.spellProperties[GDVars.spellId].saveResult <> 0) then
      GDVars.damage := 0
    else
      GDVars.damage := GDVars.damage div 2;
end;

procedure EffPetrifyingGaze(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var
  item: Types.PItem;
  reflected: Boolean;
  existing: Types.PEffect;
begin
  GDVars.combatTarget := cr^.combatAddr^.other;
  CharHlp.PrintCreatureMessage(cr, 'gazes...', 10, False);
  CharHlp.BuildIconFacings(18);
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr),
                                  CbtMap.CombatCellX(GDVars.combatTarget), CbtMap.CombatCellY(GDVars.combatTarget), 4,
                                  45);
  if CharHlp.HasEffect(cr, 127, existing) then begin
    reflected := False;
    item := GDVars.combatTarget^.itemsAddr;
    while (item <> nil) and (not reflected) do begin
      if item^.equipped <> 0 then
        if (item^.nameIds[1] = 118) or (item^.nameIds[2] = 118) or (item^.nameIds[3] = 118) then begin
          CharHlp.PrintCreatureMessage(GDVars.combatTarget, 'reflects it!', 12, False);
          CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(GDVars.combatTarget),
                                          CbtMap.CombatCellY(GDVars.combatTarget), CbtMap.CombatCellX(cr),
                                          CbtMap.CombatCellY(cr), 4, 45);
          reflected := True;
          GDVars.combatTarget := cr;
        end;
      item := item^.next;
    end;
  end;
  if not FxEngine.RollSavingThrow(GDVars.combatTarget, 1, 0) then
    FxEngine.KillCreature(GDVars.combatTarget, C_Status.STONED, 'is Stoned');
end;

procedure EffAbsorbElectricity(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  roll: Byte;
begin
  if (GDVars.elementMask and 4) <> 0 then begin
    EffHndlr.NullifyAttack(0);
    roll := FxEngine.RollDice(1, 8);
    Inc(cr^.hpCur, 8);
  end;
end;

procedure EffResistPiercing(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var item: Types.PItem;
begin
  item := Types.PItem(EffHndlr.FindDamagingWeapon(GDVars.curChar));
  if item <> nil then
    if GDVars.baseItems[item^.itemType].wpnClass = 1 then GDVars.damage := 1;
end;

procedure EffDisplaced(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if (GDVars.roundCounter = 0) and (GDVars.attackRoll = 0) then
    Types.PEffect(effect)^.strength := Types.PEffect(effect)^.strength and $F
  else if (Types.PEffect(effect)^.strength and $10) = 0 then begin
    GDVars.attackRoll := -1;
    Types.PEffect(effect)^.strength := Types.PEffect(effect)^.strength or $10;
  end;
end;

procedure EffClearCloudkill(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var
  prev: Types.PCloudNode;
  node: Types.PCloudNode;
  found: Boolean;
  j: Byte;
  i: Byte;
  cellX: Byte;
  cellY: Byte;
begin
  j := Types.PEffect(effect)^.strength div 16;
  found := False;
  node := GDVars.cloudkillHead;
  while (node <> nil) and not found do
    if (node^.caster = cr) and (node^.idx = j) then
      found := True
    else
      node := node^.next;
  if not found then Exit;
  CharHlp.PrintBottomLine('The air clears a little...');
  for i := 1 to 9 do
    if node^.exists[i] <> 0 then begin
      cellX := node^.ulX + GDConsts.directionDx[GDConsts.cloudkillDirections[i]];
      cellY := node^.ulY + GDConsts.directionDy[GDConsts.cloudkillDirections[i]];
      found := False;
      for j := 1 to GDVars.downedCount do
        if (GDVars.downedCharacters[j].cr <> nil) and (GDVars.downedCharacters[j].x = cellX) and
            (GDVars.downedCharacters[j].y = cellY) then
          found := True;
      if found then
        GDVars.combatArena^.cells[cellY, cellX] := C_Terr.CORPSE
      else
        GDVars.combatArena^.cells[cellY, cellX] := node^.under[i];
    end;
  prev := GDVars.cloudkillHead;
  if prev = node then
    GDVars.cloudkillHead := prev^.next
  else
    while prev^.next <> node do
      prev := prev^.next;
  prev^.next := node^.next;
  Dispose(node);
  prev := GDVars.cloudkillHead;
  while prev <> nil do begin
    for i := 1 to 9 do
      if prev^.exists[i] <> 0 then
        GDVars.combatArena^.cells[prev^.ulY + GDConsts.directionDy[GDConsts.cloudkillDirections[i]],
                                 prev^.ulX + GDConsts.directionDx[GDConsts.cloudkillDirections[i]]] := C_Terr.CLOUDKILL;
    prev := prev^.next;
  end;
end;

procedure EffHalfFire(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if (GDVars.elementMask and 1) <> 0 then GDVars.damage := GDVars.damage div 2;
end;

procedure EffHalfPierceBash(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var item: Types.PItem;
begin
  item := Types.PItem(EffHndlr.FindDamagingWeapon(GDVars.curChar));
  if item <> nil then
    if (GDVars.baseItems[item^.itemType].wpnClass and $81) <> 0 then GDVars.damage := GDVars.damage div 2;
end;

procedure EffFightOn(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  Types.PEffect(effect)^.onRemove := False;
  if cr^.enabled <> 0 then
    FxEngine.KillCreature(cr, C_Status.DEAD_STATUS, 'Falls dead');
end;

procedure EffConSpellSave(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var bonus: Byte;
begin
  if (GDVars.saveType = 4) or (GDVars.saveType = 2) then begin
    case cr^.stats[C_Stat.CONSTITUTION].current of
      4..6: bonus := 1;
      7..10: bonus := 2;
      11..13: bonus := 3;
      14..17: bonus := 4;
      18..20: bonus := 5;
    end;
    GDVars.saveRoll := GDVars.saveRoll + bonus;
  end;
end;

procedure EffRegenerate(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  Inc(cr^.hpCur, 3);
  if cr^.hpCur > cr^.hpMax then cr^.hpCur := cr^.hpMax;
end;

procedure EffCanFightOn(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var hp: Byte;
begin
  hp := 0;
  if (cr^.status = C_Status.DYING) and (cr^.combatAddr^.overkill < 6) then
    hp := 6 - cr^.combatAddr^.overkill;
  if cr^.status = C_Status.UNCONSCIOUS then hp := 6;
  if (hp > 0) and FxEngine.ReviveDeadCreature(cr, hp) then begin
    FxEngine.AddEffect(cr, 95, FxEngine.RollDice(1, 4) + 1, 255, True);
    Types.PEffect(effect)^.onRemove := False;
    FxEngine.RemoveEffect(cr, 99, effect);
  end;
end;

procedure EffTrollBurn(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if ((GDVars.elementMask and 1) = 0) and ((GDVars.elementMask and $10) = 0) then
    FxEngine.AddEffect(cr, 102, FxEngine.RollDice(3, 6), 255, True);
end;

procedure EffTrollHeal(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var existing: Pointer;
begin
  if (not CharHlp.HasEffect(cr, 98, Types.PEffect(existing)))
     and (not CharHlp.HasEffect(cr, 59, Types.PEffect(existing))) then
    FxEngine.AddEffect(cr, 59, 3, 255, True);
end;

procedure EffTrollReturn(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  repeated: Boolean;
begin
  if not FxEngine.ReviveDeadCreature(cr, cr^.hpMax) then
    repeated := EffHndlr.AddEffectIfNoLock(cr, 102, Types.PEffect(effect)^.strength, 1);
end;

procedure EffFireDamageBonus(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var existing: Pointer;
begin
  GDVars.combatTarget := cr^.combatAddr^.other;
  if (not CharHlp.HasEffect(GDVars.combatTarget, 20, Types.PEffect(existing)))
     and (not CharHlp.HasEffect(GDVars.combatTarget, 54, Types.PEffect(existing)))
     and (not CharHlp.HasEffect(GDVars.combatTarget, 61, Types.PEffect(existing))) then
    Inc(GDVars.damage, FxEngine.RollDice(1, 6));
end;

procedure EffDodgeMissiles(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  EffHndlr.AvoidMissile(cr, 60);
end;

procedure MagicResistance(baseChance: Byte);
var
  casterLevel: Byte;
  threshold: Byte;
begin
  casterLevel := CharHlp.GetCasterLevel(GDVars.spellId);
  threshold := baseChance + (11 - casterLevel) * 5;
  if (GDVars.effectCheck = 0) and ((GDVars.elementMask and 8) = 0) then
  else
    if FxEngine.RollDice(1, 100) <= threshold then EffHndlr.NullifyAttack(0);
end;

procedure EffStrongMagicResistance(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  EffHndlr.MagicResistance(50);
end;

procedure EffWeakMagicResistance(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  EffHndlr.MagicResistance(15);
end;

procedure EffElfResistance(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if FxEngine.RollDice(1, 100) <= 90 then begin
    EffHndlr.NullifyAttack(C_Effect.SLEEP);
    EffHndlr.NullifyAttack(C_Effect.CHARM);
  end;
end;

procedure EffImmuneSleepCharm(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  EffHndlr.NullifyAttack(C_Effect.CHARM);
  EffHndlr.NullifyAttack(C_Effect.SLEEP);
end;

procedure EffImmuneParalysis(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  EffHndlr.NullifyAttack(C_Effect.PARALYZED);
end;

procedure EffImmuneCold(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if (GDVars.elementMask and 2) <> 0 then EffHndlr.NullifyAttack(0);
end;

procedure EffImmuneParalysisPoison(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  EffHndlr.NullifyAttack(C_Effect.POISONED);
  EffHndlr.NullifyAttack(C_Effect.PARALYZED);
  if GDVars.saveType = 0 then GDVars.saveRoll := 100;
end;

procedure EffImmuneFire(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if (GDVars.elementMask and 1) <> 0 then EffHndlr.NullifyAttack(0);
end;

procedure EffFireDamageReduction(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var i: Byte;
begin
  if (GDVars.elementMask and 1) <> 0 then
    for i := 1 to GDVars.damageDice do begin
      Dec(GDVars.damage);
      if GDVars.damage < GDVars.damageDice then GDVars.damage := GDVars.damageDice;
    end;
end;

procedure EffHalfElectricity(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if (GDVars.elementMask and 4) <> 0 then GDVars.damage := GDVars.damage div 2;
end;

procedure EffHalfSlashPierce(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var item: Types.PItem;
begin
  item := Types.PItem(EffHndlr.FindDamagingWeapon(GDVars.curChar));
  if item <> nil then
    if (GDVars.baseItems[item^.itemType].wpnClass = 0) or
        ((GDVars.baseItems[item^.itemType].wpnClass and 1) <> 0) then
      GDVars.damage := GDVars.damage div 2;
end;

procedure EffHalfMagicWeapon(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var item: Types.PItem;
begin
  item := Types.PItem(EffHndlr.FindDamagingWeapon(GDVars.curChar));
  if item <> nil then
    if item^.plus > 0 then GDVars.damage := GDVars.damage div 2;
end;

procedure EffHolyWater(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var weapon: Types.PItem;
begin
  weapon := GDVars.curChar^.equipped[0];
  if weapon <> nil then
    if weapon^.itemType = 85 then
      GDVars.damage := FxEngine.RollDamageDice(1, 6) + 1;
end;

procedure EffHalfCold(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if (GDVars.elementMask and 2) <> 0 then GDVars.damage := GDVars.damage div 2;
end;

procedure EffNeedMagicWeapon(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var item: Types.PItem;
begin
  item := Types.PItem(EffHndlr.FindDamagingWeapon(GDVars.curChar));
  if (item = nil) or (item^.plus = 0) then
    if (GDVars.curChar^.race > C_Race.MONSTER) or (GDVars.curChar^.levelHighest < 4) then GDVars.damage := 0;
end;

procedure EffDodgeBoulders(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var weapon: Types.PItem;
begin
  weapon := GDVars.curChar^.equipped[0];
  if weapon <> nil then
    if (weapon^.itemType = 87) or (weapon^.itemType = 88) then
      EffHndlr.AvoidMissile(cr, 50);
end;

procedure EffSpitAcid(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  ended: Boolean;
begin
  GDVars.combatTarget := cr^.combatAddr^.other;
  if (FxEngine.RollDice(1, 100) <= 25) and (CharHlp.CalcDistance(cr, GDVars.combatTarget) < 4) then begin
    ended := CharHlp.EndActions(cr);
    CharHlp.PrintCreatureMessage(cr, 'Spits Acid', 10, True);
    CharHlp.BuildIconFacings(23);
    CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr),
                                    CbtMap.CombatCellX(GDVars.combatTarget),
                                    CbtMap.CombatCellY(GDVars.combatTarget), 1, 30);
    FxEngine.InflictNonWeaponDamage(GDVars.combatTarget, FxEngine.RollDamageDice(8, 4), 2,
                                    FxEngine.RollSavingThrow(GDVars.combatTarget, 3, 0));
    FxEngine.RemoveEffect(cr, 121, effect);
    FxEngine.RemoveEffect(cr, 80, nil);
  end;
end;

procedure EffParalyzingTouch(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var saved: Boolean;
begin
  GDVars.combatTarget := cr^.combatAddr^.other;
  saved := FxEngine.RollSavingThrow(GDVars.combatTarget, 0, 0);
  if not saved then begin
    FxEngine.AddEffect(GDVars.combatTarget, C_Effect.PARALYZED, 0, 255, False);
    CharHlp.PrintCreatureMessage(GDVars.combatTarget, 'is paralyzed', 10, True);
  end;
end;

procedure EffColdTouch(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  GDVars.elementMask := $A;
  FxEngine.InflictNonWeaponDamage(cr^.combatAddr^.other, FxEngine.RollDamageDice(2, 8), 0, False);
end;

procedure EffHalfElfResistance(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if FxEngine.RollDice(1, 100) <= 30 then begin
    EffHndlr.NullifyAttack(C_Effect.CHARM);
    EffHndlr.NullifyAttack(C_Effect.SLEEP);
  end;
end;

procedure EffImmuneCharmSleepParalysisPoison(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  EffHndlr.NullifyAttack(C_Effect.CHARM);
  EffHndlr.NullifyAttack(C_Effect.SLEEP);
  EffHndlr.NullifyAttack(C_Effect.PARALYZED);
  EffHndlr.NullifyAttack(C_Effect.POISONED);
  if GDVars.saveType = 0 then GDVars.saveRoll := 100;
end;

procedure EffParalyzingGaze(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  GDVars.combatTarget := cr^.combatAddr^.other;
  CharHlp.PrintCreatureMessage(cr, 'gazes...', 10, False);
  CharHlp.BuildIconFacings(18);
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr),
                                  CbtMap.CombatCellX(GDVars.combatTarget), CbtMap.CombatCellY(GDVars.combatTarget), 4,
                                  45);
  if not FxEngine.RollSavingThrow(GDVars.combatTarget, 1, 0) then begin
    FxEngine.AddEffect(GDVars.combatTarget, C_Effect.PARALYZED, 0, 255, False);
    CharHlp.PrintCreatureMessage(GDVars.combatTarget, 'is paralyzed', 10, False);
  end;
end;

procedure EffImmuneMagic(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if (GDVars.effectCheck = 0) and ((GDVars.elementMask and 8) = 0) then
  else EffHndlr.NullifyAttack(0);
end;

procedure EffBanishByWeapon(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var item: Pointer;
begin
  item := nil;
  if Byte(CharHlp.FindDamagingRangedWeapon(GDVars.curChar, item)) <> 0 then
    if Types.PItem(item)^.itemType = 28 then
      if item <> nil then
        if Types.PItem(item)^.nameIds[3] = 135 then begin
          cr^.status := C_Status.GONE;
          cr^.enabled := 0;
          cr^.hpCur := 0;
          FxEngine.RemoveEffectsHp0(cr);
          FxEngine.TriggerEffectsWithCondition(13, cr);
          if cr^.enabled = 0 then CbtMap.CreatureDowned(cr);
        end;
end;

procedure EffGrantItemEffect(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var item: Types.PItem;
begin
  GDVars.overrideFlag := 0;
  item := Types.PItem(effect);
  if removed then
    FxEngine.RemoveEffect(cr, item^.effect, nil)
  else begin
    FxEngine.AddEffect(cr, item^.effect, 0, 255, True);
    if GDVars.ifcState <> C_Ifc.IN_COMBAT then
      FxEngine.CallEffectHandler(item^.effect, cr, nil, False);
  end;
end;

procedure EffImmuneDebilitation(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  EffHndlr.NullifyAttack(142);
  EffHndlr.NullifyAttack(29);
  EffHndlr.NullifyAttack(68);
  if (GDVars.elementMask and $40) <> 0 then EffHndlr.NullifyAttack(0);
end;

procedure EffRangerDamageBonus(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  GDVars.combatTarget := cr^.combatAddr^.other;
  if (GDVars.combatTarget^.creatureTypeFlags and 8) <>
      0 then Inc(GDVars.damage, cr^.classLevels[C_Class.RANGER_LEVEL]);
end;

procedure EffImmuneElectricity(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if (GDVars.elementMask and 4) <> 0 then EffHndlr.NullifyAttack(0);
end;

procedure EffEntangle(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  cr^.combatAddr^.movement := 0;
end;

procedure EffConfusedBerserk(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if not removed then begin
    cr^.quickfight := 1;
    if (cr^.npc <= $7F) or (cr^.npc = $B3) then cr^.npc := $B3
    else cr^.npc := $B2;
    cr^.combatAddr^.other := nil;
    Pathing.BuildTargetList(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), 255, 255, CbtMap.GetIconSize(cr),
                            GDVars.combatArena);
    cr^.combatAddr^.other := GDVars.combatCreatures[GDVars.targetList[2].idx];
    cr^.hostile := cr^.combatAddr^.other^.hostile xor 1;
  end else begin
    if cr^.npc = $B3 then cr^.npc := 0;
    cr^.hostile := Types.PEffect(effect)^.strength;
  end;
end;

procedure EffLastingInvisibility(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  FxEngine.AddEffect(cr, C_Effect.INVISIBLE, 255, 255, False);
end;

procedure EffRecentCure(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  { The dividend is non-negative, so divide it as an unsigned value. }
  if removed then
    cr^.cureDiseaseUses :=
      TNN16(ClassCal.EarlierClassActive(cr) * cr^.oldClassLevels[C_Class.PALADIN_LEVEL] +
      cr^.classLevels[C_Class.PALADIN_LEVEL] - 1) div 5 + 1;
end;

procedure EffFear(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  if removed then begin
    if cr^.npc = $B3 then
    begin cr^.npc := 0; cr^.quickfight := 0; end;
    cr^.combatAddr^.turned := 0;
  end;
end;

procedure EffZapAttacker(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var
  savedDamage: Byte;
  savedElemMask: Byte;
begin
  if CharHlp.CalcDistance(GDVars.curChar, cr) < 2 then begin
    savedDamage := GDVars.damage;
    GDVars.damage := GDVars.damage shl 1;
    savedElemMask := GDVars.elementMask;
    GDVars.elementMask := 8;
    CharHlp.PrintCreatureMessage(GDVars.curChar, 'gets zapped', 10, True);
    FxEngine.InflictNonWeaponDamage(GDVars.curChar, GDVars.damage, 0, False);
    GDVars.damage := savedDamage;
    GDVars.elementMask := savedElemMask;
  end;
end;

procedure EffDispelEvilTouch(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  GDVars.combatTarget := cr^.combatAddr^.other;
  if ((GDVars.combatTarget^.creatureTypeFlags and 1) <> 0) and
      (not FxEngine.RollSavingThrow(GDVars.combatTarget, 4, 0)) then begin
    FxEngine.KillCreature(GDVars.combatTarget, C_Status.GONE, 'is dispelled');
    FxEngine.RemoveEffect(GDVars.curChar, 4, nil);
    FxEngine.RemoveEffect(GDVars.curChar, 145, nil);
  end else
    CharHlp.PrintCreatureMessage(GDVars.combatTarget, 'resists dispel evil', 10, True);
end;

procedure EffNone(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin end;

procedure NoopEffHndlrA;
begin
end;

procedure NoopEffHndlrB;
begin
end;

procedure InitEffectHandlers;
begin
  GDVars.effectHandlers[1] := EffHndlr.EffBless;
  GDVars.effectHandlers[2] := EffHndlr.EffCurse;
  GDVars.effectHandlers[3] := EffHndlr.EffSticksToSnakes;
  GDVars.effectHandlers[4] := EffHndlr.EffDispelEvil;
  GDVars.effectHandlers[5] := EffHndlr.EffNone;
  GDVars.effectHandlers[6] := EffHndlr.EffFlameTongue;
  GDVars.effectHandlers[7] := EffHndlr.EffFaerieFire;
  GDVars.effectHandlers[C_Effect.PROTECTION_FROM_EVIL] := EffHndlr.EffProtEvil;
  GDVars.effectHandlers[9] := EffHndlr.EffProtGood;
  GDVars.effectHandlers[10] := EffHndlr.EffResistCold;
  GDVars.effectHandlers[C_Effect.CHARM] := EffHndlr.EffCharm;
  GDVars.effectHandlers[C_Effect.ENLARGE] := EffHndlr.EffStrengthBonus;
  GDVars.effectHandlers[13] := EffHndlr.EffEngulfed;
  GDVars.effectHandlers[14] := EffHndlr.EffFriends;
  GDVars.effectHandlers[C_Effect.POISON_DAMAGE] := EffHndlr.EffSlowPoisonHit;
  GDVars.effectHandlers[C_Effect.READ_MAGIC] := EffHndlr.EffReadMagic;
  GDVars.effectHandlers[17] := EffHndlr.EffShield;
  GDVars.effectHandlers[C_Effect.GNOME_ATTACK_BONUS] := EffHndlr.EffGnomeHitBonus;
  GDVars.effectHandlers[19] := EffHndlr.EffNone;
  GDVars.effectHandlers[20] := EffHndlr.EffResistFire;
  GDVars.effectHandlers[21] := EffHndlr.EffSilence;
  GDVars.effectHandlers[C_Effect.SLOW_POISON_END] := EffHndlr.EffSlowPoisonEnd;
  GDVars.effectHandlers[C_Effect.SPIRITUAL_HAMMER] := EffHndlr.EffSpiritualHammer;
  GDVars.effectHandlers[EffHndlr.SEE_INVISIBLE] := EffHndlr.EffNone;
  GDVars.effectHandlers[C_Effect.INVISIBLE] := EffHndlr.EffInvisible;
  GDVars.effectHandlers[C_Effect.DWARF_ATTACK_BONUS] := EffHndlr.EffDwarfHitBonus;
  GDVars.effectHandlers[27] := EffHndlr.EffHelpless;
  GDVars.effectHandlers[C_Effect.MIRROR_IMAGE] := EffHndlr.EffMirrorImage;
  GDVars.effectHandlers[29] := EffHndlr.EffEnfeeble;
  GDVars.effectHandlers[C_Effect.STINKING_CLOUD_COUGH] := EffHndlr.EffCoughing;
  GDVars.effectHandlers[C_Effect.HELPLESS] := EffHndlr.EffHelpless;
  GDVars.effectHandlers[C_Effect.ANIMATE_DEAD] := EffHndlr.EffAnimateDead;
  GDVars.effectHandlers[C_Effect.BLIND] := EffHndlr.EffBlind;
  GDVars.effectHandlers[C_Effect.DISEASED] := EffHndlr.EffDiseased;
  GDVars.effectHandlers[35] := EffHndlr.EffConfusion;
  GDVars.effectHandlers[C_Effect.BESTOW_CURSE] := EffHndlr.EffBestowCurse;
  GDVars.effectHandlers[37] := EffHndlr.EffBlinking;
  GDVars.effectHandlers[C_Effect.STRENGTH] := EffHndlr.EffStrengthBonus;
  GDVars.effectHandlers[C_Effect.HASTED] := EffHndlr.EffHasted;
  GDVars.effectHandlers[C_Effect.CAST_STINKING_CLOUD] := EffHndlr.EffClearStinkingCloud;
  GDVars.effectHandlers[41] := EffHndlr.EffProtNormalMissiles;
  GDVars.effectHandlers[C_Effect.SLOWED] := EffHndlr.EffSlow;
  GDVars.effectHandlers[C_Effect.DISEASE_STRENGTH] := EffHndlr.EffDiseaseStrength;
  GDVars.effectHandlers[C_Effect.DISEASE_HIT_POINTS] := EffHndlr.EffDiseaseHitPoints;
  GDVars.effectHandlers[45] := EffHndlr.EffProtEvil;
  GDVars.effectHandlers[46] := EffHndlr.EffProtGood;
  GDVars.effectHandlers[C_Effect.DWARF_GIANT_DEFENSE] := EffHndlr.EffDwarfGiantDefense;
  GDVars.effectHandlers[C_Effect.GNOME_BUGBEAR_DEFENSE] := EffHndlr.EffGnomeBugDefense;
  GDVars.effectHandlers[49] := EffHndlr.EffPrayer;
  GDVars.effectHandlers[50] := EffHndlr.EffFireVulnerable;
  GDVars.effectHandlers[51] := EffHndlr.EffHelpless;
  GDVars.effectHandlers[C_Effect.PARALYZED] := EffHndlr.EffHelpless;
  GDVars.effectHandlers[C_Effect.SLEEP] := EffHndlr.EffHelpless;
  GDVars.effectHandlers[54] := EffHndlr.EffColdVulnerable;
  GDVars.effectHandlers[C_Effect.POISONED] := EffHndlr.EffPoisoned;
  GDVars.effectHandlers[56] := EffHndlr.EffRenewInvisibility;
  @GDVars.effectHandlers[57] := @CbtActs.AttackEngulf;
  GDVars.effectHandlers[C_Effect.IMMOBILE] := EffHndlr.EffImmobile;
  GDVars.effectHandlers[59] := EffHndlr.EffTrollRegen;
  GDVars.effectHandlers[60] := EffHndlr.EffWeaponResistance;
  GDVars.effectHandlers[61] := EffHndlr.EffNormalFireImmunity;
  GDVars.effectHandlers[62] := EffHndlr.EffConRegeneration;
  GDVars.effectHandlers[63] := EffHndlr.EffMinorGlobe;
  GDVars.effectHandlers[64] := EffHndlr.EffPoisonAttack;
  GDVars.effectHandlers[65] := EffHndlr.EffWeakPoisonAttack;
  GDVars.effectHandlers[66] := EffHndlr.EffMildPoisonAttack;
  GDVars.effectHandlers[67] := EffHndlr.EffParalyzingHit;
  GDVars.effectHandlers[68] := EffHndlr.EffFeeblemind;
  GDVars.effectHandlers[69] := EffHndlr.EffInvisibleToAnimals;
  GDVars.effectHandlers[70] := EffHndlr.EffStrongPoisonAttack;
  GDVars.effectHandlers[71] := EffHndlr.EffDustOfDisappearance;
  GDVars.effectHandlers[72] := EffHndlr.EffCamouflage;
  GDVars.effectHandlers[73] := EffHndlr.EffImmuneBreath;
  GDVars.effectHandlers[74] := EffHndlr.EffSpellFailure;
  GDVars.effectHandlers[75] := EffHndlr.EffDragonSlayer;
  GDVars.effectHandlers[76] := EffHndlr.EffBaneWeapon;
  GDVars.effectHandlers[77] := EffHndlr.EffBerserk;
  GDVars.effectHandlers[78] := EffHndlr.EffDelayedRevival;
  GDVars.effectHandlers[79] := EffHndlr.EffFireTouch;
  GDVars.effectHandlers[80] := EffHndlr.EffAcidTouch;
  GDVars.effectHandlers[81] := EffHndlr.EffHalfDamage;
  GDVars.effectHandlers[82] := EffHndlr.EffFireColdResistance;
  GDVars.effectHandlers[83] := EffHndlr.EffPetrifyingGaze;
  GDVars.effectHandlers[84] := EffHndlr.EffAbsorbElectricity;
  GDVars.effectHandlers[85] := EffHndlr.EffResistPiercing;
  @GDVars.effectHandlers[87] := @CbtActs.AttackEyeRays;
  GDVars.effectHandlers[89] := EffHndlr.EffDisplaced;
  GDVars.effectHandlers[C_Effect.CAST_CLOUDKILL] := EffHndlr.EffClearCloudkill;
  GDVars.effectHandlers[92] := EffHndlr.EffNone;
  GDVars.effectHandlers[93] := EffHndlr.EffHalfFire;
  GDVars.effectHandlers[94] := EffHndlr.EffHalfPierceBash;
  GDVars.effectHandlers[95] := EffHndlr.EffFightOn;
  @GDVars.effectHandlers[96] := @CbtActs.AttackHug;
  GDVars.effectHandlers[C_Effect.CONSTITUTION_SAVE_BONUS] := EffHndlr.EffConSpellSave;
  GDVars.effectHandlers[98] := EffHndlr.EffRegenerate;
  GDVars.effectHandlers[99] := EffHndlr.EffCanFightOn;
  GDVars.effectHandlers[100] := EffHndlr.EffTrollBurn;
  GDVars.effectHandlers[101] := EffHndlr.EffTrollHeal;
  GDVars.effectHandlers[102] := EffHndlr.EffTrollReturn;
  GDVars.effectHandlers[103] := EffHndlr.EffFireDamageBonus;
  GDVars.effectHandlers[104] := EffHndlr.EffDodgeMissiles;
  GDVars.effectHandlers[105] := EffHndlr.EffStrongMagicResistance;
  GDVars.effectHandlers[106] := EffHndlr.EffWeakMagicResistance;
  GDVars.effectHandlers[C_Effect.ELF_RESISTANCE] := EffHndlr.EffElfResistance;
  GDVars.effectHandlers[108] := EffHndlr.EffImmuneSleepCharm;
  GDVars.effectHandlers[109] := EffHndlr.EffImmuneParalysis;
  GDVars.effectHandlers[110] := EffHndlr.EffImmuneCold;
  GDVars.effectHandlers[111] := EffHndlr.EffImmuneParalysisPoison;
  GDVars.effectHandlers[112] := EffHndlr.EffImmuneFire;
  GDVars.effectHandlers[113] := EffHndlr.EffFireDamageReduction;
  GDVars.effectHandlers[114] := EffHndlr.EffHalfElectricity;
  GDVars.effectHandlers[115] := EffHndlr.EffHalfSlashPierce;
  GDVars.effectHandlers[116] := EffHndlr.EffHalfMagicWeapon;
  GDVars.effectHandlers[117] := EffHndlr.EffHolyWater;
  GDVars.effectHandlers[118] := EffHndlr.EffHalfCold;
  GDVars.effectHandlers[119] := EffHndlr.EffNeedMagicWeapon;
  GDVars.effectHandlers[120] := EffHndlr.EffDodgeBoulders;
  GDVars.effectHandlers[121] := EffHndlr.EffSpitAcid;
  GDVars.effectHandlers[122] := EffHndlr.EffParalyzingTouch;
  GDVars.effectHandlers[123] := EffHndlr.EffColdTouch;
  GDVars.effectHandlers[C_Effect.HALF_ELF_RESISTANCE] := EffHndlr.EffHalfElfResistance;
  GDVars.effectHandlers[125] := EffHndlr.EffImmuneCharmSleepParalysisPoison;
  GDVars.effectHandlers[126] := EffHndlr.EffParalyzingGaze;
  GDVars.effectHandlers[127] := EffHndlr.EffNone;
  GDVars.effectHandlers[129] := EffHndlr.EffImmuneMagic;
  GDVars.effectHandlers[130] := EffHndlr.EffBanishByWeapon;
  GDVars.effectHandlers[133] := EffHndlr.EffImmuneDebilitation;
  GDVars.effectHandlers[C_Effect.RANGER_DAMAGE_BONUS] := EffHndlr.EffRangerDamageBonus;
  GDVars.effectHandlers[135] := EffHndlr.EffImmuneElectricity;
  GDVars.effectHandlers[136] := EffHndlr.EffEntangle;
  GDVars.effectHandlers[137] := EffHndlr.EffConfusedBerserk;
  GDVars.effectHandlers[138] := EffHndlr.EffLastingInvisibility;
  @GDVars.effectHandlers[139] := @CbtActs.AttackClawRake;
  GDVars.effectHandlers[C_Effect.RECENTLY_HEALED] := EffHndlr.EffNone;
  GDVars.effectHandlers[C_Effect.RECENTLY_CURED] := EffHndlr.EffRecentCure;
  GDVars.effectHandlers[142] := EffHndlr.EffFear;
  GDVars.effectHandlers[143] := EffHndlr.EffZapAttacker;
  @GDVars.effectHandlers[144] := @CbtActs.BiteAndHold;
  GDVars.effectHandlers[145] := EffHndlr.EffDispelEvilTouch;
  GDVars.effectHandlers[146] := EffHndlr.EffNone;
  GDVars.overrideEffectHandler := EffHndlr.EffGrantItemEffect;
end;

begin
end.
