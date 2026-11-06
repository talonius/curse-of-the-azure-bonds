{ Magic: the spell menus, casting, the handler of every spell (GDVars.spellHandlers.spells), and the monster-ability
  effect handlers for effect ids 83..132 that EffHndlr leaves unset. }
{$O+,F+}
{$A-}
unit Magic;

interface

uses Types, FxEngine, CbtMap, Pathing, TextRend, SoundDrv, CharHlp, ClassCal, MenuCore, EclTrace, Border, GDConsts,
  GDVars, C_Keys, C_Race, C_Status, C_Effect, C_Ifc, C_Gbvm, C_Class, C_Terr, C_Spell, C_Stat, Crt;

{ Runs the spell menu that GenerateSpellList built, then frees the list.
  @param(selType The menu: 1 Cast, 2 Memorize, 3 Scribe, or 4 Learn, which has no Exit.)
  @param(idx The highlighted line, kept between calls; below 0 forces a redraw.)
  @returns(The chosen spell, or 0 for Exit or Escape. For Scribe, GDVars.currentScroll is set to the chosen spell's
    scroll.) }
function SpellSelection(selType: Byte; var idx: Integer): Byte;

{ Builds the spell menu list for the current character, with a heading before each spell level.
  @param(menuType 0 its memorized spells it can cast, 5 those still being memorized, 1 its known spells, 4 the spells it
    may learn (a free slot of that level, not yet known), 2 the current scroll's spells, 3 all its scrolls' spells, 6
    its scrolls' spells marked for scribing.)
  @returns(True when the list is not empty.) }
function GenerateSpellList(menuType: Byte): Boolean;

{ Computes a spell's range.
  @param(spell The spell.)
  @returns(Its base plus its per-level range times the caster level (an item casts at level 6); a spell with a target
    type gets at least 1, and $FF becomes 1.) }
function CalcSpellRange(spell: Byte): Byte;

{ Picks the targets of a spell cast outside combat (GDVars.spellHandlers.castTargets there): the caster (targeting 1), a
  party member the player chooses (2; choosing none cancels), or the whole party (4); other targeting cannot be cast
  here.
  @param(spell The spell being cast.)
  @param(aiControlled Unused.)
  @param(cast Set False when the spell is not cast.) }
procedure NoncombatCastTargetMenu(spell: Byte; aiControlled: Boolean; var cast: Boolean);

{ Casts spell for the current character. Outside combat a combat-only spell can only be lost ("Lose it?"), and a
  combat-only item can only be used up without effect ("Use it?", which sets sel); effect 74 makes half the casts fail
  ("miscasts"); with announce a cast that no item makes is announced. The target picker
  (GDVars.spellHandlers.castTargets) chooses the targets; in combat the caster turns toward the target cell and a bolt
  is drawn. Then the spell is used up (unless an item casts it) and its handler runs. A cancelled pick in combat asks
  whether to abort (aiControlled skips the question), which loses the spell.
  @param(spell The spell to cast.)
  @param(aiControlled True for a computer-controlled caster; the target picker gets it too.)
  @param(announce True to announce the cast.)
  @param(sel Set by the target picker when targets were chosen, or by a Yes to "Use it?".) }
procedure CastSpell(spell: Byte; aiControlled, announce: Boolean; var sel: Boolean);

{ Tells whether an item is readable.
  @param(it The item, or nil.)
  @returns(True for a scroll: an item whose base-item slot is 11..13.) }
function ItemReadable(it: Pointer): Boolean;

{ Removes spell from scroll it: the scroll's spell-count name part drops by one, and the scroll goes when none are left
  (name id below 210).
  @param(cr The character carrying the scroll.)
  @param(it The scroll.)
  @param(spell The spell to remove; bit 7 of the scroll's entries is ignored.) }
procedure RemoveSpellFromScroll(cr, it: Pointer; spell: Byte);

{ Reports a cast: in combat "Casts a Spell" and the spell's name on row 23; outside combat creature's name, msg and the
  spell's name in the text window, then a pause.
  @param(creature The caster.)
  @param(msg Printed after the caster's name outside combat.)
  @param(spell The spell cast.) }
procedure PrintCastSpellMsg(creature: Types.PCreature; msg: Types.TStr40; spell: Byte);

{ Spells 43 and 89 (Remove Curse): lifts Bestow Curse from the target ("is un-cursed"), or else un-equips its first
  cursed item and, when that item's third spell byte is above $7F, removes that effect through the override handler and
  recalculates the target's abilities ("has an item un-cursed"). }
procedure SpellRemoveCurse;

{ Installs the spell handlers (GDVars.spellHandlers.spells, with GDVars.spellHandlers.castTargets the outside-combat
  target picker) and the monster ability handlers in the effect table, resets the effect lock, the item-use flag and the
  last target, and sets the inventory-redraw flag. }
procedure InitSpellFns;

{ Calls the priming entries of CharHlp, ClassCal, FxEngine, MenuCore and EclTrace, so the overlay manager loads them;
  CbtMap and Pathing, which this unit also uses, are not primed. }
procedure PrimeMagic;

{ Spell 1 (Bless) on the caster's side. }
procedure SpellBless;

{ Spell 2 (Curse) on the other side. }
procedure SpellCurse;

{ Spell 3 (Cure Light Wounds): heals the target 1d8. }
procedure SpellCureLightWounds;

{ Spell 4 (Cause Light Wounds): 1d8 magic damage. }
procedure SpellCauseLightWounds;

{ Spells 5, 11, 18, 22, 29 and 77: apply the spell's effect ("is affected"). }
procedure SpellDetection;

{ Spells 6, 7, 16, 17, 52, 53, 54 and 69: apply the spell's effect ("is protected"). }
procedure SpellProtection;

{ Spell 8 (Resist Cold). }
procedure SpellResistCold;

{ Spell 9 (Burning Hands): fire damage equal to the caster level. }
procedure SpellBurningHands;

{ Spell 10 (Charm Person): charms the target unless it is not a person (creature type above 1) or is large; the charm's
  strength holds the caster's team in bit 7 and the caster level. }
procedure SpellCharmPerson;

{ Spell 12 (Enlarge): Strength by caster level (18 at level 1, 18/01 to 18/100 at 2 to 6, 19 to 21 at 7 to 9, 22 at 10
  and 11, and 18 at any other level) as effect Enlarge, when that beats the target's own ("is stronger"). }
procedure SpellEnlarge;

{ Spell 13 (Reduce): removes Enlarge from the target unless it saves (type 4). }
procedure SpellReduce;

{ Spell 14 (Friends): the effect with strength 2d4, then the caster's Charisma is recalculated. }
procedure SpellFriends;

{ Spell 15 (Magic Missile): (caster level + 1) div 2 missiles of 1d4 + 1 magic damage. }
procedure SpellMagicMissile;

{ Spell 19 (Shield). }
procedure SpellShield;

{ Spell 20 (Shocking Grasp): 1d8 + caster level electrical damage. }
procedure SpellShockingGrasp;

{ Spell 21 (Sleep): 4d4 hit dice of targets fall asleep in list order, each costing 1, 2, 4, 6 or 20 by attack level (a
  level-5 monster 10); animated creatures and sleepers are skipped. }
procedure SpellSleep;

{ Spells 23, 49 and 94 (Hold): the effect on up to four targets, saved against at -2 (spell 23) or -3 for one target, -1
  for two, 0 for three or four. }
procedure SpellHold;

{ Spell 24 (Resist Fire). }
procedure SpellResistFire;

{ Spell 25 (Silence). }
procedure SpellSilence;

{ Spell 26 (Slow Poison): on a poisoned target that is not animated, raises 0 hit points to 1, applies the spell, runs
  effect 78's removal handler (revival) and re-arms the poison damage (effect 15) for 10. }
procedure SpellSlowPoison;

{ Spell 27 (Snake Charm): charms snakes (creature type 14) whose hit points fit in the caster's, in total. }
procedure SpellSnakeCharm;

{ Spell 28 (Spiritual Hammer): applies the spell and gives the target the hammer (effect 23's handler). }
procedure SpellSpiritualHammer;

{ Spells 30 and 50 (Invisibility). }
procedure SpellInvisibility;

{ Spell 31 (Knock): applies its effect ("Knock-Knock"). }
procedure SpellKnock;

{ Spell 32 (Mirror Image): 1d4 images in the strength's high nibble, the caster level in the low one. }
procedure SpellMirrorImage;

{ Spell 33 (Ray of Enfeeblement). }
procedure SpellRayOfEnfeeblement;

{ Spell 34 (Stinking Cloud): a 2x2 cloud at the target cell. A node joins the stinking-cloud list, numbered among the
  caster's clouds and tracked by effect 40 on the caster; each cell's terrain is saved (for a cell under another cloud
  or a body, the terrain beneath it) and passable cells get the cloud tile. Creatures inside take the cloud once each. }
procedure SpellStinkingCloud;

{ Spell 35 (Strength): 1d4 Strength for a magic-user, 1d6 for a cleric or thief, 1d8 for a fighter (the last match
  wins); above 18 a warrior gets exceptional Strength instead. Applied as effect 38 when it beats the target's own.
  Note: a target with none of those classes never sets the roll, so it adds whatever the local held. }
procedure SpellStrength;

{ Spells 36 and 90 (Animate Dead): up to caster-level dead creatures of type 0 on a free cell rise as zombies on the
  caster's side (quick fight, no spells, movement 6), with effect 32 holding their old team. }
procedure SpellAnimateDead;

{ Spell 37 (Cure Blindness): removes Blind ("can see"). }
procedure SpellCureBlindness;

{ Spell 38 (Cause Blindness). }
procedure SpellCauseBlindness;

{ Spell 39 (Cure Disease): RemoveDiseaseEffects. }
procedure SpellCureDisease;

{ Spell 40 (Cause Disease). }
procedure SpellCauseDisease;

{ Spells 41 and 46 (Dispel Magic): tries each timed effect (strength below 255) of the target, removing it with chance
  50% + 5 per caster level above the effect's level (strength low nibble), - 2 per level below. Then each cloud on the
  3x3 cells around the target cell is dispelled the same way against its caster, once per cloud. Note: each pass of the
  target loop dispels the first target again, so the other targets keep their effects. Note: a Cloudkill is matched
  against nine directions read on from the stinking cloud's four, so it is checked with the stinking cloud's cells and
  the first five of its own, and three of its cells are never found. }
procedure SpellDispelMagic;

{ Spell 42 (Prayer): the effect with the caster's team in bit 4 and the caster level. }
procedure SpellPrayer;

{ Spells 44 and 100 (Bestow Curse). }
procedure SpellBestowCurse;

{ Spell 45 (Blink). }
procedure SpellBlink;

{ Spells 47 and 64 (Fireball): caster-level d6 (spell 64: 3, 5 or 7 d6) fire damage; outside 3D maps the targets are
  every creature within 2 cells of the target cell. }
procedure SpellFireball;

{ Spell 48 (Haste) on the caster's side; it removes Slow instead where there is one. }
procedure SpellHaste;

{ Spell 51 (Lightning Bolt): caster-level d6 electrical damage at the target cell, carried on as a 7-cell bolt that can
  bounce. }
procedure SpellLightningBolt;

{ Spell 55 (Slow) on the other side; it removes Haste instead where there is one. }
procedure SpellSlow;

{ Spell 56 (Restoration): returns one drained level: an even share of the drained hit points, a level of the class whose
  next level costs the least experience (within the race limit), and experience up to that level's minimum. Note: when
  no class qualifies, the class index is never set, so an undefined class gains the level. }
procedure SpellRestoration;

{ Spell 57 (potion of speed): removes Slow, or else applies its effect ("is Speedy"). }
procedure SpellPotionOfSpeed;

{ Spell 58 (Cure Serious Wounds): heals the target 2d8 + 1. }
procedure SpellCureSeriousWounds;

{ Spell 59 (giant strength): effect 146 with Strength 21 for 1d4 * 10 + 40 ("is stronger" when that beats the target's
  own; the effect is added either way). }
procedure SpellGiantStrength;

{ Spell 60 (javelin of lightning): 1d6 + 20 electrical damage at the target cell, then a 3-cell bolt of 20 that does not
  bounce. }
procedure SpellJavelinOfLightning;

{ Spell 61 (wand of paralyzation). }
procedure SpellWandOfParalyzation;

{ Spell 62 (potion of healing): heals the target 2d4 + 2. }
procedure SpellPotionOfHealing;

{ Spell 63 (dust of disappearance). }
procedure SpellDustOfDisappearance;

{ Spell 65 (wand of magic missiles): 2d4 + 2 magic damage. }
procedure SpellWandOfMagicMissiles;

{ Spell 66 (Cause Serious Wounds): 2d8 + 1 magic damage. }
procedure SpellCauseSeriousWounds;

{ Spell 67 (Neutralize Poison): cures the poison of a target that is not animated (Poisoned and both Slow Poison effects
  removed with the effect lock), raising 0 hit points to 1 and setting it okay; an unpoisoned target "is unaffected". }
procedure SpellNeutralizePoison;

{ Spell 68 (poison): applies the spell, then, unless the effects of the caster's target cancel effect 64, runs effect
  64's handler (a poison bite) for the caster. }
procedure SpellPoison;

{ Spell 70 (Sticks to Snakes): a target below attack level 6 fights snakes (effect 3, strength the caster level); a
  stronger one "smashes them flat". }
procedure SpellSticksToSnakes;

{ Spell 71 (Cure Critical Wounds): heals the target 3d8 + 3. }
procedure SpellCureCriticalWounds;

{ Spell 72 (Cause Critical Wounds): 3d8 + 3 magic damage. }
procedure SpellCauseCriticalWounds;

{ Spell 73 (Dispel Evil): gives the caster effect 4 for the spell's duration and applies the spell. }
procedure SpellDispelEvil;

{ Spell 74 (Flame Strike): 6d8 fire damage. }
procedure SpellFlameStrike;

{ Spell 75 (Raise Dead): raises a dead or animated target that has raises left and is not an elf, at 1 hit point,
  removing Animate Dead and poison and recalculating its Constitution. }
procedure SpellRaiseDead;

{ Spell 76 (Slay Living): unless the target's effects cancel it, a failed save (type 4) kills the target and a made one
  costs 2d8 + 1 magic damage. }
procedure SpellSlayLiving;

{ Spell 78 (Entangle): outside 3D maps only, each target saves (type 4) or is entangled (effect 136). Note: the duration
  is computed for spell 136, past the end of the spell table. }
procedure SpellEntangle;

{ Spell 79 (Faerie Fire): ApplyEffectToTargets ("is highlighted"). }
procedure SpellFaerieFire;

{ Spell 80 (Invisibility to Animals). }
procedure SpellInvisibilityToAnimals;

{ Spell 81 (Charm Monsters): ApplyEffectToTargets, then the charm handler for each charmed target. }
procedure SpellCharmMonsters;

{ Spell 82 (Confusion): up to 2d8 targets save (type 4) or are confused (effect 35). }
procedure SpellConfusion;

{ Spell 83 (Dimension Door): moves the caster to the target cell ("teleports"). An immobile caster first frees itself
  from the adjacent creatures holding it (effects 144 and 139 whose strength is its slot). }
procedure SpellDimensionDoor;

{ Spell 84 (Fear): a 3-ray cone of 6 cells; each target saves (type 4) or runs in terror (effect 142), fleeing as a
  quick fighter with no target. }
procedure SpellFear;

{ Spell 85 (Fire Shield): asks for hot or cold flames (random for a quick fighter): hot gives the caster effects 50 and
  143, cold 54 and 143; any other answer offers to abort. }
procedure SpellFireShield;

{ Spell 86 (Fumble): a target that fails its save (type 4) becomes clumsy (effect 27), one that saves is slowed; then
  the spell's own effect applies. }
procedure SpellFumble;

{ Spell 87 (Ice Storm): 3d10 cold damage. }
procedure SpellIceStorm;

{ Spell 88 (Minor Globe of Invulnerability). }
procedure SpellMinorGlobeOfInvulnerability;

{ Spell 91 (Cloudkill): a 3x3 cloud at the target cell, built like Stinking Cloud on the Cloudkill list (tracked by
  effect 91 on the caster, cloud tile C_Terr.CLOUDKILL); a cell under another cloud of either kind keeps the terrain
  beneath it. Note: after the loop the last cell's terrain is saved and its tile set a second time. }
procedure SpellCloudkill;

{ Spell 92 (Cone of Cold): a 2-ray cone of (caster level + 1) div 2 cells, caster-level d4 + caster level cold. }
procedure SpellConeOfCold;

{ Spell 93 (Feeblemind): applies the spell with the target's spell saving throw (saves[4]) shifted by its charClass (0:
  -1, 5: +4, others +2) for the save, then runs effect 68's handler. }
procedure SpellFeeblemind;

{ Spell 95: applies its effect. }
procedure SpellImmuneBreath;

{ Spell 96: applies its effect. }
procedure SpellImmuneParalysis;

{ Spell 97: applies its effect. }
procedure SpellTurnInvisible;

{ Spell 98: a 1-ray cone of 3 cells, 6d6 damage; creatures of type 18 take it in full, the others as if saved. }
procedure SpellConeBlast;

{ Spell 99: heals the target 2d4 + 2. }
procedure SpellHealSelf;

{ Effect 83: a petrifying gaze at the target picked as for spell 65 ("gazes..."). With effect 127, an equipped item with
  name id 118 reflects it back at the gazer ("reflects it!"). Whoever it lands on saves (type 1) or is stoned.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffAimedPetrifyingGaze(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 88: breathes lightning ("Breathes!"; after the first round only half the time) from the caster toward the
  target, a 10-cell bolt of the creature's breath damage (save type 3); it breathes three times.
  @param(cr The creature that carries the effect.)
  @param(effect The effect's node on the creature.)
  @param(removed Unused.) }
procedure EffBreatheLightning(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 86: within 6 cells of its target (CalcDistance, a distance, below 7), a 30% chance to spit acid for its breath
  damage, halved on a save (type 3); otherwise "Spits Acid and Misses".
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffSpitAcidBreath(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 90: an acid breath cone (1 ray, 6 cells) for its breath damage, halved on a save (type 3), only when every
  target is on the other side; three times per battle.
  @param(cr The creature that carries the effect.)
  @param(effect The effect's node on the creature.)
  @param(removed Unused.) }
procedure EffBreatheAcid(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 128: a fire breath cone (3 rays, 9 cells) for its breath damage, halved on a save (type 3); three times per
  battle.
  @param(cr The creature that carries the effect.)
  @param(effect The effect's node on the creature.)
  @param(removed Unused.) }
procedure EffBreatheFire(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 131: a 50% chance, at an adjacent target (CalcDistance below 2), to breathe fire for 7, halved on a save (type
  3).
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffBreatheFireAdjacent(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 132: in the first four rounds, throws lightning: 16d6 at the target cell and a 10-cell bolt of a fresh 16d6.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffThrowLightning(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Effect 126: a paralyzing gaze at the target picked as for spell 36 ("gazes..."), which saves (type 1) or is paralyzed
  (effect 52) for 60.
  @param(cr The creature that carries the effect.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure EffAimedParalyzingGaze(cr: Types.PCreature; effect: Pointer; removed: Boolean);

implementation

var
  { The cloud cell directions as one run from the byte before them: entries 1..4 are the stinking cloud's cells, 5..9
    run on into Cloudkill's. }
  cloudCells: array[0..4] of Byte absolute GDConsts.cloudCenterDirection;

procedure PrimeMagic;
begin
  CharHlp.PrimeCharHlp;
  ClassCal.PrimeClassCal;
  FxEngine.PrimeFxEngine;
  MenuCore.PrimeMenuCore;
  EclTrace.PrimeEclTrace;
end;

function ClassCanCastSpell(cr: Types.PCreature; spell: Byte): Boolean; forward;

procedure AddScrollSpellLine(spell: Byte); forward;

procedure AddSpellToList(spell: Byte); forward;

procedure AddScrollSpells(forScribe: Boolean); forward;

procedure AddAllScrollSpells(forScribe: Boolean); forward;

function CalcSpellDuration(spell: Byte): Word; forward;

procedure ResolveSpell(spell, eff: Byte; onRemove: Boolean; damage, elem: Byte; msg: Types.TStr40); forward;

procedure CastOneSide(hostFlag: ShortInt; msg: Types.TStr40); forward;

procedure ApplyEffectToTargets(saveMod: ShortInt; msg: Types.TStr40); forward;

function RemoveDiseaseEffects: Boolean; forward;

procedure HasteSlowLogic(removeId: Byte; hostFlag: ShortInt; msg: Types.TStr40); forward;

procedure LightningAttackAt(x, y: ShortInt; damage: Byte; saveType: ShortInt; excludeIdx: Byte;
                            var blocked: Boolean); forward;

procedure LightningPath(boltLen, damage: Byte; saveType: ShortInt; bounce: Boolean); forward;

{ Tells whether cr's classes let it cast spell; earlier-class levels count where EarlierClassActive allows. Cleric
  spells need Wisdom above 8 and either a cleric level or more than 8 paladin levels; druid spells Wisdom above 8 and
  more than 6 ranger levels; magic-user spells Intelligence above 8 and, for a human in combat with armor (equipped[2])
  in use, more than 8 ranger levels, current or earlier with magic-user levels; special spells never.
  @param(cr The creature.)
  @param(spell The spell; bit 7 is ignored.)
  @returns(True when cr can cast spell.) }
function ClassCanCastSpell(cr: Types.PCreature; spell: Byte): Boolean;
begin
  spell := spell and C_Spell.ID_MASK;
  ClassCanCastSpell := False;
  case GDConsts.spellProperties[spell].castClass of
    C_Spell.CLERIC_LIST: ClassCanCastSpell := Boolean(cr^.stats[C_Stat.WISDOM].current > 8) and
      ((cr^.classLevels[C_Class.CLERIC_LEVEL] > 0) or
       (Boolean(ClassCal.EarlierClassActive(cr)) and (cr^.oldClassLevels[C_Class.CLERIC_LEVEL] > 0)) or
       (cr^.classLevels[C_Class.PALADIN_LEVEL] > 8) or
       ((cr^.oldClassLevels[C_Class.PALADIN_LEVEL] > 8) and Boolean(ClassCal.EarlierClassActive(cr))));
    C_Spell.DRUID_LIST: ClassCanCastSpell := Boolean(cr^.stats[C_Stat.WISDOM].current > 8) and
      ((cr^.classLevels[C_Class.RANGER_LEVEL] > 6) or
       (Boolean(ClassCal.EarlierClassActive(cr)) and (cr^.oldClassLevels[C_Class.RANGER_LEVEL] > 6)));
    C_Spell.MAGE_LIST: ClassCanCastSpell := (cr^.stats[C_Stat.INTELLIGENCE].current > 8) and
      ((cr^.race <> C_Race.HUMAN) or (cr^.equipped[2] = nil) or (GDVars.ifcState <> C_Ifc.IN_COMBAT) or
       (cr^.classLevels[C_Class.RANGER_LEVEL] > 8) or
       (Boolean(ClassCal.EarlierClassActive(cr)) and (cr^.oldClassLevels[C_Class.RANGER_LEVEL] > 8) and
        ((cr^.classLevels[C_Class.MAGE_LEVEL] > 0) or
         (Boolean(ClassCal.EarlierClassActive(cr)) and (cr^.oldClassLevels[C_Class.MAGE_LEVEL] > 0)))));
    C_Spell.SPECIAL_LIST: ClassCanCastSpell := False;
  end;
end;

function SpellSelection(selType: Byte; var idx: Integer): Byte;
var
  sel: Types.PItem;
  p: Types.PItem;
  prompt: Types.TStr40;
  title: Types.TStr40;
  { Unused in this version; see the other implementations of this routine. }
  spellLevel: Byte;
  count: Byte;
  bottomRow: Byte;
  ch: Char;
  addExit: Boolean;
  redraw: Boolean;
begin
  case selType of
    1: title := 'Cast';
    2: title := 'Memorize';
    3: title := 'Scribe';
    4: title := 'Learn';
  else
    title := '';
  end;
  if selType in [1..4] then
    prompt := 'Choose Spell: '
  else
    prompt := '';
  if selType = 2 then
    bottomRow := 15
  else
    bottomRow := 22;
  if selType = 4 then
    addExit := False
  else
    addExit := True;
  redraw := False;
  if idx < 0 then begin
    redraw := True;
    idx := 0;
  end;
  if (selType = 4) or (selType = 1) then
    redraw := True;
  sel := nil;
  repeat
    ch := MenuCore.MenuVertical(prompt, title, LightMagenta, LightGreen, White, 1, 5, 38, bottomRow, GDVars.spellList,
                                addExit, redraw, idx, sel);
  until ch in [C_Keys.NONE, C_Keys.ENTER, 'C', 'E', 'L', 'M', 'S'];
  p := GDVars.spellList;
  count := 0;
  while p <> sel do begin
    if p^.inUse = 0 then
      Inc(count);
    p := p^.next;
  end;
  if ch in [C_Keys.NONE, 'E'] then
    SpellSelection := 0
  else
    SpellSelection := GDVars.spellIds[count];
  if selType = 3 then
    GDVars.currentScroll := GDVars.scrollPtrs[count];
  MenuCore.FreeStringList(GDVars.spellList);
end;

{ Appends spell to the scroll spell list (and spellIds), with a level heading when its level differs from the last
  spell's; " *" marks bit 7.
  @param(spell The spell; bit 7 marks it with " *".) }
procedure AddScrollSpellLine(spell: Byte);
var
  p: Types.PItem;
  count: ShortInt;
  lastLevel: ShortInt;
begin
  p := GDVars.spellList;
  if GDVars.spellList = nil then begin
    GetMem(p, SizeOf(Types.TItemNode));
    GDVars.spellList := p;
    lastLevel := 0;
    count := 0;
  end else begin
    count := 1;
    while p^.next <> nil do begin
      if p^.inUse = 0 then
        Inc(count);
      p := p^.next;
    end;
    lastLevel := GDConsts.spellProperties[GDVars.spellIds[count - 1]].level;
    GetMem(p^.next, SizeOf(Types.TItemNode));
    p := p^.next;
  end;
  p^.next := nil;
  if GDConsts.spellProperties[spell and C_Spell.ID_MASK].level <> lastLevel then begin
    p^.name := GDConsts.spellLevelNames[GDConsts.spellProperties[spell and C_Spell.ID_MASK].level];
    p^.inUse := 1;
    GetMem(p^.next, SizeOf(Types.TItemNode));
    p := p^.next;
    p^.next := nil;
  end;
  if spell > C_Spell.ID_MASK then
    p^.name := ' *'
  else
    p^.name := '  ';
  p^.name := p^.name + GDConsts.spellNames[spell and C_Spell.ID_MASK];
  p^.inUse := 0;
  GDVars.spellIds[count] := spell and C_Spell.ID_MASK;
end;

{ Adds spell to the menu list (and spellIds) before the first spell of a higher level, or counts a repeat of the same
  spell as "(n)". " *" marks bit 7.
  @param(spell The spell; bit 7 marks it with " *".) }
procedure AddSpellToList(spell: Byte);
var
  carry: Byte;
  tmp: Byte;
  p: Types.PItem;
  scan: Types.PItem;
  newNode: Types.PItem;
  count: ShortInt;
  k: Byte;
  found: Boolean;
  newLevel: ShortInt;
begin
  p := GDVars.spellList;
  found := False;
  newLevel := GDConsts.spellProperties[spell and C_Spell.ID_MASK].level;
  if GDVars.spellList = nil then begin
    FillChar(GDVars.spellCounts, SizeOf(GDVars.spellCounts), 0);
    GetMem(p, SizeOf(Types.TItemNode));
    p^.next := nil;
    GDVars.spellList := p;
    count := 0;
    GDVars.spellCounts[count] := 1;
  end else begin
    count := 0;
    while (p <> nil) and not found do begin
      if p^.inUse = 0 then begin
        if not ((GDConsts.spellProperties[GDVars.spellIds[count]].level > newLevel) or
                (GDVars.spellIds[count] = (spell and C_Spell.ID_MASK))) then begin
          Inc(count);
          p := p^.next;
        end else
          found := True;
      end else begin
        p := p^.next;
        Inc(count);
      end;
    end;
    if GDVars.spellIds[count] <> (spell and C_Spell.ID_MASK) then begin
      scan := GDVars.spellList;
      if scan <> p then begin
        while scan^.next <> p do
          scan := scan^.next;
        GetMem(newNode, SizeOf(Types.TItemNode));
        newNode^.next := scan^.next;
        scan^.next := newNode;
        p := newNode;
      end else begin
        GetMem(newNode, SizeOf(Types.TItemNode));
        newNode^.next := p;
        GDVars.spellList := newNode;
        p := newNode;
      end;
      carry := 1;
      for k := count to 83 do begin
        tmp := GDVars.spellCounts[k];
        GDVars.spellCounts[k] := carry;
        carry := tmp;
      end;
    end else
      Inc(GDVars.spellCounts[count]);
  end;
  if spell > C_Spell.ID_MASK then
    p^.name := ' *'
  else
    p^.name := '  ';
  p^.name := p^.name + GDConsts.spellNames[spell and C_Spell.ID_MASK];
  p^.inUse := 0;
  if GDVars.spellCounts[count] > 1 then
    p^.name := p^.name + ' (' + CharHlp.Uint8Str(GDVars.spellCounts[count]) + ')';
  if GDVars.spellIds[count] <> (spell and C_Spell.ID_MASK) then begin
    carry := GDVars.spellIds[count];
    GDVars.spellIds[count] := spell and C_Spell.ID_MASK;
    for k := count + 1 to 83 do begin
      tmp := GDVars.spellIds[k];
      GDVars.spellIds[k] := carry;
      carry := tmp;
    end;
  end;
end;

{ Adds the current scroll's spells to the list (with forScribe only those marked for scribing), recording the scroll for
  each. The scroll is identified first when the character has Read Magic or is a cleric reading a cleric scroll (slot
  $C).
  @param(forScribe Selects the spells marked for scribing.) }
procedure AddScrollSpells(forScribe: Boolean);
var
  i: Byte;
  eff: Types.PEffect;
begin
  if CharHlp.HasEffect(GDVars.curChar, C_Effect.READ_MAGIC, eff) or
      (((GDVars.curChar^.classLevels[C_Class.CLERIC_LEVEL] > 0) or
        (GDVars.curChar^.oldClassLevels[C_Class.CLERIC_LEVEL] > GDVars.curChar^.levelAtChange)) and
       (GDVars.baseItems[GDVars.currentScroll^.itemType].slot = 12)) then
    GDVars.currentScroll^.unidMask := 0;
  if GDVars.currentScroll^.unidMask = 0 then
    for i := 1 to 3 do begin
      if (forScribe and (GDVars.currentScroll^.spells[i] > C_Spell.PENDING_FLAG)) or
          (not forScribe and (GDVars.currentScroll^.spells[i] > 0)) then begin
        Magic.AddScrollSpellLine(GDVars.currentScroll^.spells[i]);
        GDVars.scrollPtrs[GDVars.scrollCount] := GDVars.currentScroll;
        Inc(GDVars.scrollCount);
      end;
    end;
end;

{ Adds the spells of all the current character's readable scrolls (AddScrollSpells).
  @param(forScribe Passed on to AddScrollSpells.) }
procedure AddAllScrollSpells(forScribe: Boolean);
var
  i: Byte;
begin
  for i := 0 to 48 do
    GDVars.scrollPtrs[i] := nil;
  GDVars.scrollCount := 0;
  GDVars.currentScroll := GDVars.curChar^.itemsAddr;
  while GDVars.currentScroll <> nil do begin
    if Magic.ItemReadable(GDVars.currentScroll) then
      Magic.AddScrollSpells(forScribe);
    GDVars.currentScroll := GDVars.currentScroll^.next;
  end;
end;

function GenerateSpellList(menuType: Byte): Boolean;
var
  i: Byte;
  cur: Types.PItem;
  n: Types.PItem;
  prevLvl: ShortInt;
  lvl: ShortInt;
  doBuild: Boolean;
begin
  doBuild := True;
  GenerateSpellList := False;
  GDVars.spellList := nil;
  for i := 0 to 83 do
    GDVars.spellIds[i] := 0;
  case menuType of
    0: for i := 0 to 83 do
         if (GDVars.curChar^.memorizedSpells[i] > 0) and
             Magic.ClassCanCastSpell(GDVars.curChar, GDVars.curChar^.memorizedSpells[i] and C_Spell.ID_MASK) and
             (GDVars.curChar^.memorizedSpells[i] < C_Spell.PENDING_FLAG) then
           Magic.AddSpellToList(GDVars.curChar^.memorizedSpells[i]);
    5: for i := 0 to 83 do
         if (GDVars.curChar^.memorizedSpells[i] > C_Spell.ID_MASK) and
             Magic.ClassCanCastSpell(GDVars.curChar, GDVars.curChar^.memorizedSpells[i] and C_Spell.ID_MASK) then
           Magic.AddSpellToList(GDVars.curChar^.memorizedSpells[i]);
    1: for i := 1 to 100 do
         if (GDVars.curChar^.knownSpells[i] <> 0) and Magic.ClassCanCastSpell(GDVars.curChar, i) then
           Magic.AddSpellToList(i);
    2: begin Magic.AddScrollSpells(False); doBuild := False; end;
    3: begin Magic.AddAllScrollSpells(False); doBuild := False; end;
    6: begin Magic.AddAllScrollSpells(True); doBuild := False; end;
    4: for i := 1 to 100 do
         if (GDVars.curChar^.spellSlots[GDConsts.spellProperties[i].castClass,
                                        GDConsts.spellProperties[i].level] > 0) and
             Magic.ClassCanCastSpell(GDVars.curChar, i) and (GDVars.curChar^.knownSpells[i] = 0) then
           Magic.AddSpellToList(i);
  end;
  if GDVars.spellList <> nil then begin
    if doBuild then begin
      i := 0;
      lvl := GDConsts.spellProperties[GDVars.spellIds[i]].level;
      GetMem(n, SizeOf(Types.TItemNode));
      n^.next := GDVars.spellList;
      GDVars.spellList := n;
      GDVars.spellList^.name := GDConsts.spellLevelNames[GDConsts.spellProperties[GDVars.spellIds[i]].level];
      GDVars.spellList^.inUse := 1;
      cur := GDVars.spellList;
      repeat
        prevLvl := lvl;
        if GDVars.spellIds[i] <> 0 then
          lvl := GDConsts.spellProperties[GDVars.spellIds[i]].level;
        if prevLvl < lvl then begin
          GetMem(n, SizeOf(Types.TItemNode));
          n^.next := cur^.next;
          cur^.next := n;
          cur := cur^.next;
          cur^.name := GDConsts.spellLevelNames[lvl];
          cur^.inUse := 1;
        end;
        Inc(i);
        cur := cur^.next;
      until cur = nil;
    end;
    GenerateSpellList := True;
  end;
end;

function CalcSpellRange(spell: Byte): Byte;
var
  r: Byte;
begin
  if GDVars.usingItem = False then
    r :=
      GDConsts.spellProperties[spell].rangeBase +
      GDConsts.spellProperties[spell].rangePerLevel * CharHlp.GetCasterLevel(spell)
  else
    r := GDConsts.spellProperties[spell].rangePerLevel * 6 + GDConsts.spellProperties[spell].rangeBase;
  if (r = 0) and (GDConsts.spellProperties[spell].targetType <> 0) then
    r := 1;
  if r = 255 then
    r := 1;
  CalcSpellRange := r;
end;

{ Computes a spell's duration.
  @param(spell The spell.)
  @returns(1d6 * 10 for spell 40, 5d4 for 57 and 61, 1d4 * 10 + 40 for 59, 2d10 * 10 in combat or (1d10 + 10) * 10
    outside for 63, 1440 for 67, otherwise its base plus its per-level duration times the caster level.) }
function CalcSpellDuration(spell: Byte): Word;
var
  d: Word;
begin
  case spell of
    40: d := FxEngine.RollDice(1, 6) * 10;
    57, 61: d := FxEngine.RollDice(5, 4);
    59: d := FxEngine.RollDice(1, 4) * 10 + 40;
    63: if GDVars.ifcState = C_Ifc.IN_COMBAT then
                d := FxEngine.RollDice(2, 10) * 10
              else
                d := (FxEngine.RollDice(1, 10) + 10) * 10;
    67: d := 1440;
  else
    d :=
      GDConsts.spellProperties[spell].durBase +
      GDConsts.spellProperties[spell].durPerLevel * CharHlp.GetCasterLevel(spell);
  end;
  CalcSpellDuration := d;
end;

{ Applies spell to each target: a saving throw when the spell allows one, an attack roll for a touch spell (base range
  255; a miss counts as saved with no damage), the damage of type elem (reduced on a save as the spell says), and the
  spell's effect with strength eff (the caster level when 0), its duration and onRemove; msg reports the effect.
  @param(spell The spell.)
  @param(eff The effect's strength; 0 uses the caster level.)
  @param(onRemove True to run the effect's handler when it is removed.)
  @param(damage The damage to deal; 0 deals none.)
  @param(elem The damage type.)
  @param(msg Reports the effect on each target.) }
procedure ResolveSpell(spell, eff: Byte; onRemove: Boolean; damage, elem: Byte; msg: Types.TStr40);
var
  effLevel: Byte;
  i: Byte;
  tgt: Types.PCreature;
  saved: Boolean;
begin
  if damage = 0 then
    GDVars.elementMask := 0
  else
    GDVars.elementMask := elem;
  if GDVars.spellTargetCount = 0 then
    Exit;
  if eff = 0 then
    effLevel := CharHlp.GetCasterLevel(spell)
  else
    effLevel := eff;
  for i := 1 to GDVars.spellTargetCount do begin
    if GDVars.spellTargets[i] <> nil then begin
      tgt := GDVars.spellTargets[i];
      if not Boolean(GDConsts.spellProperties[spell].saveResult) then
        saved := False
      else
        saved := FxEngine.RollSavingThrow(Pointer(tgt), GDConsts.spellProperties[spell].saveType, 0);
      if GDConsts.spellProperties[GDVars.spellId].rangeBase = 255 then begin
        CharHlp.RecalcStats(tgt);
        FxEngine.TriggerEffectsWithCondition(11, Pointer(tgt));
        if not FxEngine.AttackRoll(Pointer(GDVars.curChar), Pointer(tgt), tgt^.acCur[0]) then begin
          damage := 0;
          saved := True;
        end;
      end;
      if damage > 0 then
        FxEngine.InflictNonWeaponDamage(Pointer(tgt), damage, GDConsts.spellProperties[spell].saveResult,
                                        saved);
      if GDConsts.spellProperties[spell].effectId > 0 then
        FxEngine.AddEffectWithMessage(Pointer(tgt), GDConsts.spellProperties[spell].effectId,
                                      Magic.CalcSpellDuration(spell), effLevel, onRemove,
                                      Boolean(GDConsts.spellProperties[spell].saveResult), saved, msg);
    end;
  end;
  GDVars.elementMask := 0;
end;

procedure NoncombatCastTargetMenu(spell: Byte; aiControlled: Boolean; var cast: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  target: Pointer;
begin
  if GDVars.lastSpellTarget = nil then
    GDVars.lastSpellTarget := GDVars.curChar;
  GDVars.spellTargets[1] := GDVars.curChar;
  GDVars.spellTargetCount := 1;
  cast := True;
  case GDConsts.spellProperties[spell].targeting of
    1: ;
    2: begin
         CharHlp.DisplayNoncombatInterface;
         CharHlp.SelectChar('Cast Spell on whom', True, GDVars.lastSpellTarget);
         if GDVars.lastSpellTarget = nil then begin
           GDVars.spellTargets[1] := nil;
           GDVars.spellTargetCount := 0;
           cast := False;
         end else
           GDVars.spellTargets[1] := GDVars.lastSpellTarget;
       end;
    4: begin
         GDVars.spellTargets[GDVars.spellTargetCount] := GDVars.partyHead;
         while GDVars.spellTargets[GDVars.spellTargetCount]^.next <> nil do begin
           GDVars.spellTargets[GDVars.spellTargetCount +
                               1] := GDVars.spellTargets[GDVars.spellTargetCount]^.next;
           Inc(GDVars.spellTargetCount);
         end;
       end;
  else
    cast := False;
  end;
end;

procedure CastSpell(spell: Byte; aiControlled, announce: Boolean; var sel: Boolean);
var
  ok: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  spellClass: Byte;
  x: ShortInt;
  y: ShortInt;
  k: Byte;
  { d2 roll for effect 74 }
  mr: Byte;
  p: Types.PCreature;
  { HasEffect's node, unused }
  buf: array[0..3] of Byte;
begin
  p := GDVars.curChar;
  ok := True;
  if (GDVars.ifcState <> C_Ifc.IN_COMBAT) and (GDConsts.spellProperties[spell].targeting = 0) then begin
    if GDVars.usingItem = False then begin
      TextRend.DisplayString(1, 19, LightGreen, 0, GDConsts.spellNames[spell]);
      TextRend.DisplayString(1, 20, LightGreen, 0, 'can''t be cast here...');
      if MenuCore.YesNoMenu('Lose it? ', LightMagenta, LightGreen, White) = 'Y' then
        CharHlp.RemoveSpell(p, spell);
    end else begin
      TextRend.DisplayString(1, 19, LightGreen, 0, 'That Item');
      TextRend.DisplayString(1, 20, LightGreen, 0, 'is a combat-only item...');
      if MenuCore.YesNoMenu('Use it? ', LightMagenta, LightGreen, White) = 'Y' then
        sel := True;
    end;
    announce := False;
    ok := False;
  end;
  if CharHlp.HasEffect(p, 74, Types.PEffect(buf)) then begin
    mr := FxEngine.RollDice(1, 2);
    if mr = 1 then begin
      Magic.PrintCastSpellMsg(p, 'miscasts', spell);
      announce := False;
      ok := False;
    end;
  end;
  if announce then
    if GDVars.usingItem = False then
      Magic.PrintCastSpellMsg(p, 'casts', spell);
  while ok do begin
    GDVars.spellHandlers.castTargets(spell, aiControlled, sel);
    if sel then begin
      ok := False;
      if GDVars.ifcState = C_Ifc.IN_COMBAT then begin
        CharHlp.BuildIconFacings(18);
        x := CbtMap.CombatCellX(Pointer(p));
        y := CbtMap.CombatCellY(Pointer(p));
        k := 0;
        while not Pathing.IsDirToward(x, y, GDVars.spellTargetX, GDVars.spellTargetY, k) do
          Inc(k);
        GDVars.mapVisible := True;
        CbtMap.SetCreatureFacing(Pointer(p), k, 1, 0);
        case spell of
          47: SoundDrv.SoundCommand(GDConsts.sndCmd11);
          51: SoundDrv.SoundCommand(GDConsts.sndCmd8);
        else
          SoundDrv.SoundCommand(GDConsts.sndCmd2);
        end;
        CharHlp.CombatAnimateMovingIcon(x, y, GDVars.spellTargetX, GDVars.spellTargetY, 4, 30);
        if CbtMap.CombatIconVisible(Pointer(p), 0) then begin
          CbtMap.SetCreatureFacing(Pointer(p), p^.combatAddr^.direction, 1, 1);
          CbtMap.SetCreatureFacing(Pointer(p), p^.combatAddr^.direction, 0, 0);
        end;
      end;
      FxEngine.RemoveInvisibility(Pointer(p));
      if GDVars.usingItem = False then
        CharHlp.RemoveSpell(p, spell);
      GDVars.spellId := spell;
      GDVars.spellHandlers.spells[GDVars.spellId];
      GDVars.spellId := 0;
      GDVars.multiTarget := 0;
    end else begin
      if GDVars.ifcState <> C_Ifc.IN_COMBAT then
        ok := False
      else if aiControlled or (MenuCore.YesNoMenu('Abort Spell? ', Yellow, LightGreen, White) = 'Y') then
      begin
        CharHlp.PrintBottomLine('Spell Aborted');
        if GDVars.usingItem = False then
          CharHlp.RemoveSpell(p, spell);
        ok := False;
      end;
    end;
  end;
  CharHlp.ClearMessageWindow;
  if GDVars.ifcState = C_Ifc.IN_COMBAT then
    Border.ClearBox(0, 23, 39, 23);
end;

{ Fills the spell targets with the creatures, other than the caster, on a line from (ox, oy) through (tx, ty) extended
  to reach cells and cut short by walls, and with rays 2 or 3 on one or two more lines to cells beside its end; each
  creature once.
  @param(ox The column of the cone's origin.)
  @param(oy The row of the cone's origin.)
  @param(tx The column of the aimed cell.)
  @param(ty The row of the aimed cell.)
  @param(rays The number of lines: 1, 2 or 3.)
  @param(reach The cone's length in cells.) }
procedure CollectConeTargets(ox, oy, tx, ty: ShortInt; rays, reach: Byte);
var
  side2X: ShortInt;
  side2Y: ShortInt;
  side1X: ShortInt;
  side1Y: ShortInt;
  req: Types.TPathReq;
  done: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  walkOk: Boolean;
  i: Byte;
  n: Byte;
  lastDirIdx: Byte;
  dirs: array[0..49] of Byte;
  list: array[0..30] of Byte;
  terrIdx: Byte;
  listCount: Byte;
  destIdx: Byte;
  centerDir: Byte;
  walkDist: Word;
  found: Boolean;

  { Starts the line walk req from (sx, sy) to (ex, ey). }
  procedure SetLine(sx, sy, ex, ey: ShortInt);
  begin
    req.sx := sx;
    req.sy := sy;
    req.ex := ex;
    req.ey := ey;
    Pathing.PathFind(req);
  end;

  { Keeps (cx, cy) inside the 50x25 arena. }
  procedure ClampCell(var cx, cy: ShortInt);
  begin
    if cx > 49 then cx := 49
    else if cx < 0 then cx := 0;
    if cy > 24 then cy := 24
    else if cy < 0 then cy := 0;
  end;

  { Adds each creature on the rest of req's line to list, once. }
  procedure CollectAlong;
  var
    j: Byte;
    cfound: Boolean;
  begin
    repeat
      done := not Pathing.NextPathStep(req);
      if not done then begin
        CbtMap.GetArenaContents(ShortInt(req.cx), ShortInt(req.cy), list[0], terrIdx);
        j := 1;
        cfound := False;
        if list[0] > 0 then
          repeat
            if list[j] = list[0] then
              cfound := True
            else if list[j] = 0 then begin
              list[j] := list[0];
              cfound := True;
            end else
              Inc(j);
          until cfound;
      end;
    until done;
  end;

begin
  n := 0;
  SetLine(ox, oy, tx, ty);
  repeat
    done := not Pathing.NextPathStep(req);
    if not done then begin
      dirs[n] := req.step;
      Inc(n);
    end;
  until done;

  lastDirIdx := n - 1;
  n := 0;
  reach := reach shl 1;
  i := req.dist;
  done := False;
  while (i < reach) and not done do begin
    if (tx < 49) and (tx > 0) and (ty < 24) and (ty > 0) then begin
      case dirs[n] of
        0, 2, 4, 6: Inc(i, 2);
        1, 3, 5, 7: Inc(i, 3);
      end;
      Inc(tx, GDConsts.directionDx[dirs[n]]);
      Inc(ty, GDConsts.directionDy[dirs[n]]);
      if n = lastDirIdx then n := 0 else Inc(n);
    end else
      done := True;
  end;

  ClampCell(tx, ty);
  walkOk := Pathing.WalkLine(ox, oy, tx, ty, walkDist, GDVars.combatArena);
  SetLine(ox, oy, tx, ty);

  FillChar(list[1], 30, 0);
  listCount := 1;
  repeat
    done := not Pathing.NextPathStep(req);
    if not done then begin
      CbtMap.GetArenaContents(ShortInt(req.cx), ShortInt(req.cy), list[0], terrIdx);
      if list[0] > 0 then begin
        if listCount > 1 then begin
          for GDVars.sharedLoopIdx := 1 to listCount - 1 do
            if list[GDVars.sharedLoopIdx] = list[0] then
              found := True;
        end else
          found := False;
        if not found then begin
          list[listCount] := list[0];
          Inc(listCount);
        end;
        centerDir := req.step;
      end;
    end;
  until done;

  if rays > 1 then begin
    side2X := tx + GDConsts.sideRayDX1[centerDir];
    side2Y := ty + GDConsts.sideRayDY1[centerDir];
    ClampCell(side2X, side2Y);
    side1X := tx + GDConsts.sideRayDX2[centerDir];
    side1Y := ty + GDConsts.sideRayDY2[centerDir];
    ClampCell(side1X, side1Y);
    SetLine(ox, oy, side1X, side1Y);
    CollectAlong;
    if rays > 2 then begin
      SetLine(ox, oy, side2X, side2Y);
      CollectAlong;
    end;
  end;

  listCount := 1;
  destIdx := 1;
  GDVars.spellTargetCount := 0;
  if list[1] <> 0 then
    repeat
      if GDVars.combatCreatures[list[listCount]] <> GDVars.curChar then begin
        Inc(GDVars.spellTargetCount);
        GDVars.spellTargets[destIdx] := GDVars.combatCreatures[list[listCount]];
        Inc(destIdx);
      end;
      Inc(listCount);
    until list[listCount] = 0;
end;

{ Applies the current spell's effect to each target, drawing a bolt to all but the last, with a save at saveMod. Large
  or non-person targets always save (except against spell 94), and for spells 79 and 81 the last target always saves.
  @param(saveMod The saving-throw modifier.)
  @param(msg Reports the effect on each target.) }
procedure ApplyEffectToTargets(saveMod: ShortInt; msg: Types.TStr40);
var
  tgt: Types.PCreature;
  saved: Boolean;
  i: Byte;
  saveNegates: Boolean;
begin
  for i := GDVars.spellTargetCount downto 1 do begin
    if GDVars.spellTargets[i] <> nil then begin
      tgt := GDVars.spellTargets[i];
      if i < GDVars.spellTargetCount then begin
        SoundDrv.SoundCommand(GDConsts.sndCmd2);
        CharHlp.BuildIconFacings(18);
        CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(Pointer(GDVars.curChar)),
                                        CbtMap.CombatCellY(Pointer(GDVars.curChar)), CbtMap.CombatCellX(Pointer(tgt)),
                                        CbtMap.CombatCellY(Pointer(tgt)), 4, 30);
      end;
      if ((GDVars.spellId = 79) or (GDVars.spellId = 81)) and (i = GDVars.spellTargetCount) then begin
        saved := True;
        saveNegates := True;
      end else begin
        saved := FxEngine.RollSavingThrow(Pointer(tgt), GDConsts.spellProperties[GDVars.spellId].saveType,
                                          saveMod);
        saveNegates := Boolean(GDConsts.spellProperties[GDVars.spellId].saveResult);
      end;
      if ((tgt^.charType > 1) or (tgt^.iconDim > 1)) and (GDVars.spellId <> 94) then
        saved := True;
      FxEngine.AddEffectWithMessage(Pointer(tgt), GDConsts.spellProperties[GDVars.spellId].effectId,
                                    Magic.CalcSpellDuration(GDVars.spellId),
                                    CharHlp.GetCasterLevel(GDVars.spellId), False, saveNegates, saved, msg);
    end;
  end;
end;

{ Applies the current spell to the targets on side hostFlag (for Bless in combat, not those with an enemy next to them),
  reporting msg.
  @param(hostFlag The side that keeps the spell.)
  @param(msg Reports the effect on each target.) }
procedure CastOneSide(hostFlag: ShortInt; msg: Types.TStr40);
var
  i: Byte;
begin
  GDVars.multiTarget := 1;
  for i := 1 to GDVars.spellTargetCount do begin
    if (GDVars.spellTargets[i]^.hostile <> hostFlag) or
        ((GDVars.spellId = 1) and (GDVars.ifcState = C_Ifc.IN_COMBAT) and
         (CharHlp.CountTargets(GDVars.spellTargets[i], 1) > 0)) then
      GDVars.spellTargets[i] := nil;
  end;
  Magic.ResolveSpell(GDVars.spellId, 0, False, 0, 0, msg);
end;

procedure SpellBless;
begin
  Magic.CastOneSide(GDVars.curChar^.hostile, 'is Blessed');
end;

procedure SpellCurse;
begin
  Magic.CastOneSide(ShortInt(CharHlp.NotHostile(GDVars.curChar)), 'is Cursed');
end;

procedure SpellCureLightWounds;
begin
  if GDVars.spellTargetCount = 0 then
    Exit;
  if FxEngine.RestoreHitPoints(Pointer(GDVars.spellTargets[1]), FxEngine.RollDice(1, 8), False) then
    CharHlp.AnnounceHealStatus(Types.PCreature(GDVars.spellTargets[1]));
end;

procedure SpellCauseLightWounds;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, False, FxEngine.RollDamageDice(1, 8), 8, '');
end;

procedure SpellDetection;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, False, 0, 0, 'is affected');
end;

procedure SpellProtection;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, False, 0, 0, 'is protected');
end;

procedure SpellResistCold;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, False, 0, 0, 'is cold-resistant');
end;

procedure SpellBurningHands;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, False, CharHlp.GetCasterLevel(GDVars.spellId), 9, '');
end;

procedure SpellCharmPerson;
var
  eff: Types.PEffect;
  tgt: Types.PCreature;
begin
  tgt := GDVars.spellTargets[1];
  if (tgt^.charType > 1) or (tgt^.iconDim > 1) then
    CharHlp.PrintCreatureMessage(tgt, 'is unaffected', 10, True)
  else begin
    Magic.ResolveSpell(GDVars.spellId, GDVars.curChar^.hostile * 128 + CharHlp.GetCasterLevel(GDVars.spellId), True, 0,
                        0, 'is charmed');
    if CharHlp.HasEffect(tgt, C_Effect.CHARM, eff) then
      FxEngine.CallEffectHandler(C_Effect.CHARM, Pointer(GDVars.spellTargets[1]), eff, False);
  end;
end;

procedure SpellEnlarge;
var
  enc: Byte;
  tgt: Types.PCreature;
begin
  tgt := GDVars.spellTargets[1];
  GDVars.spellAmount := 18;
  GDVars.spellCost := 0;
  case CharHlp.GetCasterLevel(GDVars.spellId) of
    1: GDVars.spellCost := 0;
    2: GDVars.spellCost := 1;
    3: GDVars.spellCost := 51;
    4: GDVars.spellCost := 76;
    5: GDVars.spellCost := 91;
    6: GDVars.spellCost := 100;
    7: GDVars.spellAmount := 19;
    8: GDVars.spellAmount := 20;
    9: GDVars.spellAmount := 21;
    10, 11: GDVars.spellAmount := 22;
  end;
  if FxEngine.AdjustForNewStrength(Pointer(tgt), GDVars.spellAmount, GDVars.spellCost, enc) then begin
    CharHlp.PrintCreatureMessage(tgt, 'is stronger', 10, True);
    FxEngine.AddEffect(Pointer(tgt), C_Effect.ENLARGE, Magic.CalcSpellDuration(GDVars.spellId), enc, True);
    FxEngine.RecalcAbility(Pointer(tgt), C_Stat.STRENGTH);
  end else
    CharHlp.PrintCreatureMessage(tgt, 'is unaffected', 10, True);
end;

procedure SpellReduce;
var
  eff: Types.PEffect;
  tgt: Types.PCreature;
begin
  tgt := GDVars.spellTargets[1];
  if tgt <> nil then
    if GDVars.spellTargetCount > 0 then
      if not FxEngine.RollSavingThrow(Pointer(tgt), 4, 0) then
        if CharHlp.HasEffect(tgt, C_Effect.ENLARGE, eff) then begin
          FxEngine.RemoveEffect(Pointer(tgt), C_Effect.ENLARGE, nil);
          FxEngine.RecalcAbility(Pointer(tgt), C_Stat.STRENGTH);
          CharHlp.PrintCreatureMessage(tgt, 'has been reduced', 10, True);
        end;
end;

procedure SpellFriends;
var
  { Unused in this version; see the other implementations of this routine. }
  oldCha: Byte;
begin
  Magic.ResolveSpell(GDVars.spellId, FxEngine.RollDice(2, 4), True, 0, 0, 'is friendly');
  FxEngine.RecalcAbility(Pointer(GDVars.curChar), C_Stat.CHARISMA);
end;

procedure SpellMagicMissile;
var
  cl: Byte;
begin
  cl := CharHlp.GetCasterLevel(GDVars.spellId) + 1;
  Magic.ResolveSpell(GDVars.spellId, 0, False, cl div 2 + FxEngine.RollDamageDice(cl div 2, 4), 8, '');
end;

procedure SpellShield;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, False, 0, 0, 'is shielded');
end;

procedure SpellShockingGrasp;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, False,
                      FxEngine.RollDamageDice(1, 8) + CharHlp.GetCasterLevel(GDVars.spellId), 12, '');
end;

procedure SpellSleep;
var
  i: Byte;
  eff: Types.PEffect;
begin
  GDVars.multiTarget := 1;
  GDVars.spellAmount := FxEngine.RollDice(4, 4);
  for i := 1 to GDVars.spellTargetCount do begin
    case GDVars.spellTargets[i]^.levelHighest of
      0..1: GDVars.spellCost := 1;
      2: GDVars.spellCost := 2;
      3: GDVars.spellCost := 4;
      4: GDVars.spellCost := 6;
      5: if GDVars.spellTargets[i]^.race = C_Race.MONSTER then
              GDVars.spellCost := 10
            else
              GDVars.spellCost := 20;
    else
      GDVars.spellCost := 20;
    end;
    if (GDVars.spellTargets[i]^.status <> C_Status.ANIMATED) and
        (not CharHlp.HasEffect(Types.PCreature(GDVars.spellTargets[i]), C_Effect.SLEEP, eff)) and
        (GDVars.spellAmount >= GDVars.spellCost) then
      Dec(GDVars.spellAmount, GDVars.spellCost)
    else
      GDVars.spellTargets[i] := nil;
  end;
  Magic.ResolveSpell(GDVars.spellId, 0, False, 0, 0, 'falls asleep');
end;

procedure SpellHold;
var
  smod: ShortInt;
begin
  case GDVars.spellTargetCount of
    1: if GDVars.spellId = 23 then
         smod := -2
       else
         smod := -3;
    2: smod := -1;
    3, 4: smod := 0;
  end;
  Magic.ApplyEffectToTargets(smod, 'is held');
end;

procedure SpellResistFire;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, False, 0, 0, 'is fire resistant');
end;

procedure SpellSilence;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, False, 0, 0, 'is silenced');
end;

procedure SpellSlowPoison;
var
  eff: Types.PEffect;
  tgt: Types.PCreature;
begin
  tgt := GDVars.spellTargets[1];
  if tgt^.status = C_Status.ANIMATED then
    GDVars.spellTargets[1] := nil
  else if CharHlp.HasEffect(tgt, C_Effect.POISONED, eff) then begin
    if tgt^.hpCur = 0 then
      tgt^.hpCur := 1;
    Magic.ResolveSpell(GDVars.spellId, 255, True, 0, 0, 'is affected');
    FxEngine.CallEffectHandler(78, Pointer(tgt), nil, True);
    FxEngine.AddEffect(Pointer(tgt), C_Effect.POISON_DAMAGE, 10, 255, True);
  end;
end;

procedure SpellSnakeCharm;
var
  p: Types.PCreature;
begin
  GDVars.spellAmount := GDVars.curChar^.hpCur;
  GDVars.spellTargetCount := 0;
  p := GDVars.partyHead;
  while p <> nil do begin
    if p^.charType = 14 then
      if GDVars.spellAmount >= p^.hpCur then begin
        GDVars.spellAmount := GDVars.spellAmount - p^.hpCur;
        Inc(GDVars.spellTargetCount);
        GDVars.spellTargets[GDVars.spellTargetCount] := p;
      end;
    p := p^.next;
  end;
  Magic.ResolveSpell(GDVars.spellId, 0, False, 0, 0, 'is charmed');
end;

procedure SpellSpiritualHammer;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, True, 0, 0, '');
  FxEngine.CallEffectHandler(C_Effect.SPIRITUAL_HAMMER, Pointer(GDVars.spellTargets[1]), nil, False);
end;

procedure SpellInvisibility;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, False, 0, 0, 'is invisible');
end;

procedure SpellKnock;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, False, 0, 0, 'Knock-Knock');
end;

procedure SpellMirrorImage;
var
  arg: Byte;
begin
  arg := FxEngine.RollDice(1, 4) shl 4;
  arg := CharHlp.GetCasterLevel(GDVars.spellId) or arg;
  Magic.ResolveSpell(GDVars.spellId, arg, False, 0, 0, 'is duplicated');
end;

procedure SpellRayOfEnfeeblement;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, False, 0, 0, 'is weakened');
end;

procedure SpellStinkingCloud;
var
  otherCloud: Types.PCloudNode;
  node: Types.PCloudNode;
  crIdx: array[1..4] of Byte;
  j: Byte;
  myClouds: Byte;
  terr: Byte;
  cl: Byte;
  k: Byte;
  dirIdx: Byte;
begin
  GDVars.multiTarget := 1;
  cl := CharHlp.GetCasterLevel(GDVars.spellId);
  myClouds := 0;
  node := GDVars.stinkHead;
  if GDVars.stinkHead = nil then begin
    GetMem(GDVars.stinkHead, SizeOf(GDVars.stinkHead^));
    node := GDVars.stinkHead;
  end else begin
    while node^.next <> nil do begin
      if node^.caster = GDVars.curChar then
        Inc(myClouds);
      node := node^.next;
    end;
    GetMem(node^.next, SizeOf(node^.next^));
    node := node^.next;
  end;
  FillChar(node^, SizeOf(node^), 0);
  FxEngine.AddEffect(Pointer(GDVars.curChar), C_Effect.CAST_STINKING_CLOUD, cl, cl + myClouds * 16, True);
  node^.caster := GDVars.curChar;
  node^.idx := myClouds;
  node^.ulX := GDVars.spellTargetX;
  node^.ulY := GDVars.spellTargetY;
  for k := 1 to 4 do begin
    dirIdx := GDConsts.stinkingCloudDirections[k];
    CbtMap.GetArenaContents(GDVars.spellTargetX + GDConsts.directionDx[dirIdx],
                            GDVars.spellTargetY + GDConsts.directionDy[dirIdx], crIdx[k], terr);
    if (terr > 0) and (GDConsts.terrainInfo[terr].cost < 255) then
      node^.exists[k] := 1
    else
      node^.exists[k] := 0;
    if terr = C_Terr.STINKING_CLOUD then begin
      otherCloud := GDVars.stinkHead;
      while otherCloud <> nil do begin
        if otherCloud <> node then
          for j := 1 to 4 do
            if (otherCloud^.exists[j] <> 0) and
                (otherCloud^.ulX + GDConsts.directionDx[GDConsts.stinkingCloudDirections[j]] = GDVars.spellTargetX +
                GDConsts.directionDx[dirIdx]) and
                (otherCloud^.ulY + GDConsts.directionDy[GDConsts.stinkingCloudDirections[j]] = GDVars.spellTargetY +
                GDConsts.directionDy[dirIdx]) then
              if otherCloud^.under[j] <> C_Terr.STINKING_CLOUD then
                terr := otherCloud^.under[j];
        otherCloud := otherCloud^.next;
      end;
    end else if terr = C_Terr.CORPSE then begin
      for j := 1 to GDVars.downedCount do
        if GDVars.downedCharacters[j].x = GDVars.spellTargetX + GDConsts.directionDx[dirIdx] then
          if GDVars.downedCharacters[j].y = GDVars.spellTargetY + GDConsts.directionDy[dirIdx] then
            terr := GDVars.downedCharacters[j].terrain;
    end;
    node^.under[k] := terr;
    if node^.exists[k] <> 0 then
      GDVars.combatArena^.cells[GDVars.spellTargetY + GDConsts.directionDy[dirIdx],
                   GDVars.spellTargetX + GDConsts.directionDx[dirIdx]] := C_Terr.STINKING_CLOUD;
  end;
  CharHlp.PrintCreatureMessage(GDVars.curChar, 'Creates a noxious cloud', 10, False);
  CbtMap.ScrollView(GDVars.spellTargetX, GDVars.spellTargetY, 255, 8);
  TextRend.PauseOnly;
  CharHlp.ClearMessageWindow;
  { Remove duplicate creature indices so a 2x2 Stinking Cloud affects each creature once. }
  for k := 2 to 4 do
    for j := 1 to 4 do
      if (crIdx[k] = crIdx[j]) and (k <> j) then
        crIdx[k] := 0;
  for k := 1 to 4 do
    if crIdx[k] > 0 then
      FxEngine.ConsiderTerrainEffects(Pointer(GDVars.combatCreatures[crIdx[k]]), 1);
end;

procedure SpellStrength;
var
  tgt: Types.PCreature;
  exStr: Byte;
  roll: Byte;
  newStr: Byte;
  { AdjustForNewStrength's encoded Strength, then the effect's strength. }
  effStr: Byte;
begin
  exStr := 0;
  tgt := GDVars.spellTargets[1];
  if (tgt^.classLevels[C_Class.MAGE_LEVEL] > 0) or (tgt^.oldClassLevels[C_Class.MAGE_LEVEL] > tgt^.levelAtChange) then
    roll := FxEngine.RollDice(1, 4);
  if (tgt^.classLevels[C_Class.CLERIC_LEVEL] > 0) or (tgt^.oldClassLevels[C_Class.CLERIC_LEVEL] > tgt^.levelAtChange) or
      (tgt^.classLevels[C_Class.THIEF_LEVEL] > 0) or
      (tgt^.oldClassLevels[C_Class.THIEF_LEVEL] > tgt^.levelAtChange) then
    roll := FxEngine.RollDice(1, 6);
  if (tgt^.classLevels[C_Class.FIGHTER_LEVEL] > 0) or
      (tgt^.oldClassLevels[C_Class.FIGHTER_LEVEL] > tgt^.levelAtChange) then
    roll := FxEngine.RollDice(1, 8);
  newStr := tgt^.stats[C_Stat.STRENGTH].current + roll;
  if newStr > 18 then begin
    if (tgt^.classLevels[C_Class.FIGHTER_LEVEL] > 0) or
        (tgt^.oldClassLevels[C_Class.FIGHTER_LEVEL] > tgt^.levelAtChange) or
        (tgt^.classLevels[C_Class.PALADIN_LEVEL] > 0) or
        (tgt^.oldClassLevels[C_Class.PALADIN_LEVEL] > tgt^.levelAtChange) or
        (tgt^.classLevels[C_Class.RANGER_LEVEL] > 0) or
        (tgt^.oldClassLevels[C_Class.RANGER_LEVEL] > tgt^.levelAtChange) then begin
      exStr := tgt^.exStrCur + (newStr - 18) * 10;
      if exStr > 100 then
        exStr := 100;
      newStr := 18;
    end else
      newStr := 18;
  end;
  if FxEngine.AdjustForNewStrength(Pointer(tgt), newStr, exStr, effStr) then begin
    effStr := roll + 100;
    FxEngine.AddEffect(Pointer(tgt), C_Effect.STRENGTH, Magic.CalcSpellDuration(GDVars.spellId), effStr, True);
    FxEngine.RecalcAbility(Pointer(tgt), C_Stat.STRENGTH);
  end;
end;

procedure SpellAnimateDead;
var
  i: Byte;
  strength: Byte;
  n: Byte;
  p: Types.PCreature;
begin
  GDVars.multiTarget := 1;
  n := CharHlp.GetCasterLevel(GDVars.spellId);
  GDVars.spellTargetCount := 0;
  p := GDVars.partyHead;
  while (p <> nil) and (n > 0) do begin
    if p^.status = C_Status.DEAD_STATUS then
      if p^.charType = 0 then
        if CbtMap.IsValidCreatureLoc(Pointer(p), CbtMap.CombatCellX(Pointer(p)), CbtMap.CombatCellY(Pointer(p)),
                                     True) then begin
          strength := p^.hostile * 16 + CharHlp.GetCasterLevel(GDVars.spellId);
          p^.hostile := GDVars.curChar^.hostile;
          p^.quickfight := 1;
          p^.levelUndead := 2;
          p^.attackLevel := 0;
          p^.moveRate := 6;
          for i := 0 to 83 do
            p^.memorizedSpells[i] := 0;
          if p^.npc > $7F then
            p^.npc := $B2
          else
            p^.npc := $B3;
          p^.charType := 4;
          if GDVars.ifcState = C_Ifc.IN_COMBAT then
            p^.combatAddr^.other := nil;
          Dec(n);
          if FxEngine.ReviveDeadCreature(Pointer(p), p^.hpMax) then begin
            FxEngine.AddEffectWithMessage(Pointer(p), C_Effect.ANIMATE_DEAD, 0, strength, True, False, False,
                                          'is animated');
            p^.status := C_Status.ANIMATED;
          end;
        end;
    p := p^.next;
  end;
end;

procedure SpellCureBlindness;
begin
  if FxEngine.RemoveEffectWithMessage(Pointer(GDVars.spellTargets[1]), C_Effect.BLIND) then
    CharHlp.PrintNameStringAnim(Types.PCreature(GDVars.spellTargets[1]), True, 'can see');
end;

procedure SpellCauseBlindness;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, False, 0, 0, 'is blind');
end;

{ Removes the target's diseases, with the effect lock set: Diseased, the Strength disease (with the hit-point disease
  and helplessness), and effect 50 (with effect 57).
  @returns(True when one was removed.) }
function RemoveDiseaseEffects: Boolean;
begin
  RemoveDiseaseEffects := False;
  GDVars.effectLock := 1;
  if FxEngine.RemoveEffectWithMessage(Pointer(GDVars.spellTargets[1]), C_Effect.DISEASED) then
    RemoveDiseaseEffects := True;
  if FxEngine.RemoveEffectWithMessage(Pointer(GDVars.spellTargets[1]), C_Effect.DISEASE_STRENGTH) then begin
    RemoveDiseaseEffects := True;
    FxEngine.RemoveEffect(Pointer(GDVars.spellTargets[1]), C_Effect.DISEASE_HIT_POINTS, nil);
    FxEngine.RemoveEffect(Pointer(GDVars.spellTargets[1]), C_Effect.HELPLESS, nil);
  end;
  if FxEngine.RemoveEffectWithMessage(Pointer(GDVars.spellTargets[1]), 50) then begin
    RemoveDiseaseEffects := True;
    FxEngine.RemoveEffect(Pointer(GDVars.spellTargets[1]), 57, nil);
  end;
  GDVars.effectLock := 0;
end;

procedure SpellCureDisease;
var
  { Unused in this version; see the other implementations of this routine. }
  cured: Boolean;
begin
  cured := Magic.RemoveDiseaseEffects;
end;

procedure SpellCauseDisease;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, True, 0, 0, 'is diseased');
end;

procedure SpellDispelMagic;
var
  i: Byte;
  cl: Byte;
  tgt: Types.PCreature;
  removed: Boolean;
  found: Boolean;
  eff: Types.PEffect;
  nxt: Types.PEffect;
  lx: ShortInt;
  ly: ShortInt;
  terr: Byte;
  sel: Byte;
  node: Types.PCloudNode;

  { Rolls whether caster cr's cloud is dispelled, by the caster level against cr's magic-user level. }
  function CloudDispelled(cr: Types.PCreature): Boolean;
  begin
    GDVars.spellCost :=
      cr^.classLevels[C_Class.MAGE_LEVEL] +
      cr^.oldClassLevels[C_Class.MAGE_LEVEL] * ClassCal.EarlierClassActive(GDVars.curChar);
    if cl > GDVars.spellCost then
      GDVars.spellAmount := (cl - GDVars.spellCost) * 5 + 50
    else if cl < GDVars.spellCost then
      GDVars.spellAmount := 50 - (GDVars.spellCost - cl) * 2
    else
      GDVars.spellAmount := 50;
    CloudDispelled := FxEngine.RollDice(1, 100) <= GDVars.spellAmount;
  end;

begin
  GDVars.multiTarget := 1;
  cl := CharHlp.GetCasterLevel(GDVars.spellId);
  for i := 1 to GDVars.spellTargetCount do begin
    removed := False;
    tgt := Types.PCreature(GDVars.spellTargets[1]);
    eff := tgt^.effects;
    while eff <> nil do begin
      nxt := eff^.next;
      if eff^.strength < 255 then begin
        GDVars.spellCost := eff^.strength and $F;
        if cl > GDVars.spellCost then
          GDVars.spellAmount := (cl - GDVars.spellCost) * 5 + 50
        else if cl < GDVars.spellCost then
          GDVars.spellAmount := 50 - (GDVars.spellCost - cl) * 2
        else
          GDVars.spellAmount := 50;
        if FxEngine.RollDice(1, 100) <= GDVars.spellAmount then begin
          FxEngine.RemoveEffect(Pointer(tgt), eff^.id, eff);
          removed := True;
        end;
      end;
      eff := nxt;
    end;
    if removed then
      CharHlp.PrintNameStringAnim(tgt, True, 'is affected');
  end;
  for GDVars.sharedLoopIdx := 0 to 8 do begin
    case GDVars.sharedLoopIdx of
      0: begin lx := GDVars.spellTargetX; ly := GDVars.spellTargetY; end;
      1: ly := GDVars.spellTargetY - 1;
      2: lx := GDVars.spellTargetX + 1;
      3: ly := GDVars.spellTargetY;
      4: ly := GDVars.spellTargetY + 1;
      5: lx := GDVars.spellTargetX;
      6: lx := GDVars.spellTargetX - 1;
      7: ly := GDVars.spellTargetY;
      8: ly := GDVars.spellTargetY - 1;
    end;
    CbtMap.GetArenaContents(lx, ly, sel, terr);
    if (terr = C_Terr.CLOUDKILL) or (terr = C_Terr.STINKING_CLOUD) then begin
      if terr = C_Terr.CLOUDKILL then begin
        node := GDVars.cloudkillHead;
        sel := 9;
      end else begin
        node := GDVars.stinkHead;
        sel := 4;
      end;
      while node <> nil do begin
        for i := 1 to sel do
          if (lx = node^.ulX + GDConsts.directionDx[cloudCells[i]]) and
              (ly = node^.ulY + GDConsts.directionDy[cloudCells[i]]) and (node^.resolved = 0) then
            if CloudDispelled(Types.PCreature(node^.caster)) then begin
              eff := Types.PCreature(node^.caster)^.effects;
              found := False;
              while (eff <> nil) and not found do begin
                if (((eff^.id = C_Effect.CAST_CLOUDKILL) and (terr = C_Terr.CLOUDKILL)) or
                    ((eff^.id = C_Effect.CAST_STINKING_CLOUD) and (terr = C_Terr.STINKING_CLOUD))) and
                        ((eff^.strength div 16) = node^.idx) then
                  found := True
                else
                  eff := eff^.next;
              end;
              if found then
                if terr = C_Terr.CLOUDKILL then
                  FxEngine.RemoveEffect(Pointer(node^.caster), C_Effect.CAST_CLOUDKILL, eff)
                else
                  FxEngine.RemoveEffect(Pointer(node^.caster), C_Effect.CAST_STINKING_CLOUD, eff);
            end else
              node^.resolved := 1;
        node := node^.next;
      end;
    end;
  end;
end;

procedure SpellPrayer;
begin
  Magic.ResolveSpell(GDVars.spellId, GDVars.curChar^.hostile * 16 + CharHlp.GetCasterLevel(GDVars.spellId), False, 0, 0,
                      'is praying');
end;

procedure SpellRemoveCurse;
var
  it: Types.PItem;
  found: Boolean;
  i: ShortInt;
begin
  if FxEngine.RemoveEffectWithMessage(Pointer(GDVars.spellTargets[1]), C_Effect.BESTOW_CURSE) then
    CharHlp.PrintNameStringAnim(Types.PCreature(GDVars.spellTargets[1]), True, 'is un-cursed')
  else begin
    found := False;
    it := GDVars.spellTargets[1]^.itemsAddr;
    while (it <> nil) and (not found) do begin
      if it^.cursed <> 0 then begin
        found := True;
        it^.equipped := 0;
        if it^.spells[3] > $7F then begin
          GDVars.overrideFlag := 1;
          FxEngine.CallEffectHandler(it^.spells[3], Pointer(GDVars.spellTargets[1]), Pointer(it), True);
          for i := 0 to 5 do
            FxEngine.RecalcAbility(Pointer(GDVars.spellTargets[1]), i);
        end;
      end;
      it := it^.next;
    end;
    if found then
      CharHlp.PrintNameStringAnim(Types.PCreature(GDVars.spellTargets[1]), True, 'has an item un-cursed');
  end;
end;

procedure SpellBestowCurse;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, False, 0, 0, 'has been cursed!');
end;

procedure SpellBlink;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, False, 0, 0, 'is blinking');
end;

procedure SpellFireball;
var
  cl: Byte;
  i: Byte;
begin
  GDVars.multiTarget := 1;
  if GDVars.spellId = 64 then
    cl := FxEngine.RollDice(1, 3) * 2 + 1
  else
    cl := CharHlp.GetCasterLevel(GDVars.spellId);
  if GDVars.zone0^[C_Gbvm.VIEW_3D] = 0 then begin
    Pathing.BuildTargetList(GDVars.spellTargetX, GDVars.spellTargetY, 2, 255, 1, GDVars.combatArena);
    for i := 1 to GDVars.targetCount do
      GDVars.spellTargets[i] := GDVars.combatCreatures[GDVars.targetList[i].idx];
    GDVars.spellTargetCount := GDVars.targetCount;
  end;
  CbtMap.ScrollView(GDVars.spellTargetX, GDVars.spellTargetY, 0, 8);
  Magic.ResolveSpell(GDVars.spellId, 0, False, FxEngine.RollDamageDice(cl, 6), 9, '');
end;

{ Applies Haste or Slow to up to caster-level targets on side hostFlag; a target with the opposite effect (removeId)
  only loses that instead.
  @param(removeId The opposite effect.)
  @param(hostFlag The side affected.)
  @param(msg Reports the effect on each target.) }
procedure HasteSlowLogic(removeId: Byte; hostFlag: ShortInt; msg: Types.TStr40);
var
  cl: Byte;
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  affected: Byte;
begin
  GDVars.multiTarget := 1;
  cl := CharHlp.GetCasterLevel(GDVars.spellId);
  for i := 1 to GDVars.spellTargetCount do begin
    if (GDVars.spellTargets[i]^.hostile = hostFlag) and (cl > 0) then begin
      Dec(cl);
      if FxEngine.RemoveEffectWithMessage(Pointer(GDVars.spellTargets[i]), removeId) then
        GDVars.spellTargets[i] := nil;
    end else
      GDVars.spellTargets[i] := nil;
  end;
  Magic.ResolveSpell(GDVars.spellId, 0, False, 0, 0, msg);
end;

procedure SpellHaste;
begin
  Magic.HasteSlowLogic(C_Effect.SLOWED, GDVars.curChar^.hostile, 'is Hasted');
end;

{ Hits the creature on cell (x, y), unless it is excludeIdx, with electrical damage halved on a save of saveType;
  blocked becomes True at an impassable cell of a 3D map unless it already was, and False otherwise.
  @param(x The cell's column.)
  @param(y The cell's row.)
  @param(damage The electrical damage.)
  @param(saveType The saving-throw type that halves it.)
  @param(excludeIdx The combat slot of a creature to skip, or 0.)
  @param(blocked In, whether the bolt was blocked before this cell; out, as described above.) }
procedure LightningAttackAt(x, y: ShortInt; damage: Byte; saveType: ShortInt; excludeIdx: Byte; var blocked: Boolean);
var
  tgt: Types.PCreature;
  crIdx: Byte;
  terr: Byte;
  { Unused in this version; see the other implementations of this routine. }
  hitDamage: Word;
begin
  CbtMap.GetArenaContents(x, y, crIdx, terr);
  if (terr > 0) and (GDConsts.terrainInfo[terr].cost = 255) and (GDVars.zone0^[C_Gbvm.VIEW_3D] = 1) and
      (not blocked) then
    blocked := True
  else
    blocked := False;
  if (crIdx > 0) and (crIdx <> excludeIdx) then begin
    tgt := GDVars.combatCreatures[crIdx];
    GDVars.elementMask := $C;
    FxEngine.InflictNonWeaponDamage(Pointer(tgt), damage, 2, FxEngine.RollSavingThrow(Pointer(tgt), saveType, 0));
    CharHlp.BuildIconFacings(19);
    GDVars.elementMask := 0;
  end;
end;

{ Carries a bolt on from the target cell, away from the caster, for boltLen cells, hitting each creature it reaches (not
  the one just hit); at a wall it turns back toward the caster, the first bounce costing 4 more cells when the caster is
  within 4 cells and bounce is set.
  @param(boltLen The bolt's length in cells.)
  @param(damage The electrical damage to each creature hit.)
  @param(saveType The saving-throw type that halves it.)
  @param(bounce True to let the first bounce cost 4 more cells.) }
procedure LightningPath(boltLen, damage: Byte; saveType: ShortInt; bounce: Boolean);
var
  req: Types.TPathReq;
  req2: Types.TPathReq;
  x0: ShortInt;
  y0: ShortInt;
  prevX: ShortInt;
  prevY: ShortInt;
  sign: ShortInt;
  blocked: Boolean;
  valid: Boolean;
  doBounce: Boolean;
  prevCr: Byte;
  crIdx: Byte;
  terr: Byte;
  budget: Byte;
  lastDist: Byte;
begin
  blocked := False;
  CharHlp.BuildIconFacings(19);
  CbtMap.GetArenaContents(GDVars.spellTargetX, GDVars.spellTargetY, prevCr, terr);
  lastDist := 0;
  sign := 1;
  x0 := CbtMap.CombatCellX(Pointer(GDVars.curChar));
  y0 := CbtMap.CombatCellY(Pointer(GDVars.curChar));
  doBounce := bounce;
  if x0 = GDVars.spellTargetX then
    if y0 = GDVars.spellTargetY then
      Exit;
  budget := boltLen * 2;
  GDVars.multiTarget := 1;
  while budget > 0 do begin
    FillChar(req, SizeOf(req), 0);
    req.sx := GDVars.spellTargetX;
    req.sy := GDVars.spellTargetY;
    req.ex := GDVars.spellTargetX + (GDVars.spellTargetX - x0) * sign * budget;
    req.ey := GDVars.spellTargetY + (GDVars.spellTargetY - y0) * sign * budget;
    Pathing.PathFind(req);
    repeat
      prevX := req.cx;
      prevY := req.cy;
      if (req.sx <> req.ex) or (req.sy <> req.ey) then begin
        repeat
          valid := Pathing.NextPathStep(req);
          CbtMap.GetArenaContents(req.cx, req.cy, crIdx, terr);
          if GDConsts.terrainInfo[terr].cost = 1 then
            blocked := False;
        until (valid = False) or ((crIdx > 0) and (crIdx <> prevCr)) or (terr = 0) or
            (GDConsts.terrainInfo[terr].cost > 1) or (req.dist >= budget);
      end;
      if terr = 0 then
        budget := 0;
      CharHlp.CombatAnimateMovingIcon(prevX, prevY, req.cx, req.cy, 4, 50);
      Magic.LightningAttackAt(req.cx, req.cy, damage, saveType, prevCr, blocked);
      prevCr := crIdx;
      if blocked then begin
        GDVars.spellTargetX := req.cx;
        GDVars.spellTargetY := req.cy;
        FillChar(req2, SizeOf(req2), 0);
        req2.sx := GDVars.spellTargetX;
        req2.sy := GDVars.spellTargetY;
        req2.ex := x0;
        req2.ey := y0;
        Pathing.PathFind(req2);
        while Pathing.NextPathStep(req2) do ;
        if doBounce then
          if req2.dist <= 8 then
            Inc(req.dist, 8);
        sign := 0 - sign;
        doBounce := False;
        prevCr := 0;
      end;
      lastDist := req.dist - lastDist;
      if lastDist < budget then
        Dec(budget, lastDist)
      else
        budget := 0;
      lastDist := req.dist;
    until blocked or (budget = 0);
  end;
  GDVars.multiTarget := 0;
end;

procedure SpellLightningBolt;
var
  dmg: Byte;
  blocked: Boolean;
begin
  dmg := FxEngine.RollDice(CharHlp.GetCasterLevel(GDVars.spellId), 6);
  Magic.LightningAttackAt(GDVars.spellTargetX, GDVars.spellTargetY, dmg, 4, 0, blocked);
  Magic.LightningPath(7, dmg, 4, True);
end;

procedure SpellSlow;
begin
  Magic.HasteSlowLogic(C_Effect.HASTED, ShortInt(CharHlp.NotHostile(GDVars.curChar)), 'is Slowed');
end;

procedure SpellRestoration;
var
  tgt: Types.PCreature;
  share: Byte;
  bestLvl: ShortInt;
  lvl: ShortInt;
  bestXp: LongInt;
  bestCls: ShortInt;
  cls: ShortInt;
begin
  tgt := GDVars.spellTargets[1];
  if tgt^.drainedLevels > 0 then begin
    share := tgt^.drainedHps div tgt^.drainedLevels;
    Inc(tgt^.hpMax, share);
    Inc(tgt^.hpCur, share);
    Inc(tgt^.hpRolled, share);
    Dec(tgt^.drainedHps, share);
    Dec(tgt^.drainedLevels);
    bestLvl := 13;
    bestXp := 10000000;
    for cls := 0 to 7 do begin
      lvl := tgt^.classLevels[cls];
      if (lvl > 0) and (lvl <= bestLvl) and (GDConsts.classExperience[cls].thresholds[Succ(lvl)] > 0) and
          (GDConsts.classExperience[cls].thresholds[Succ(lvl)] < bestXp) and
          (not CharHlp.AtLevelCap(Types.PCreature(tgt), cls)) then begin
        bestLvl := lvl;
        bestCls := cls;
        bestXp := GDConsts.classExperience[cls].thresholds[Succ(lvl)];
      end;
    end;
    Inc(tgt^.classLevels[bestCls]);
    if tgt^.experience < bestXp then
      tgt^.experience := bestXp;
    ClassCal.RecalcClassStats(Types.PCreature(tgt));
    CharHlp.PrintCreatureMessage(Types.PCreature(tgt), 'is restored', 10, True);
  end;
end;

procedure SpellPotionOfSpeed;
begin
  if not FxEngine.RemoveEffectWithMessage(Pointer(GDVars.spellTargets[1]), C_Effect.SLOWED) then
    Magic.ResolveSpell(GDVars.spellId, 0, False, 0, 0, 'is Speedy');
end;

procedure SpellCureSeriousWounds;
begin
  if GDVars.spellTargetCount = 0 then
    Exit;
  if FxEngine.RestoreHitPoints(Pointer(GDVars.spellTargets[1]), FxEngine.RollDice(2, 8) + 1, False) then
    CharHlp.AnnounceHealStatus(Types.PCreature(GDVars.spellTargets[1]));
end;

procedure SpellGiantStrength;
var
  enc: Byte;
  { Unused in this version; see the other implementations of this routine. }
  oldStrength: Byte;
begin
  if FxEngine.AdjustForNewStrength(Pointer(GDVars.spellTargets[1]), 21, 0, enc) then
    CharHlp.PrintCreatureMessage(Types.PCreature(GDVars.spellTargets[1]), 'is stronger', 10, True);
  FxEngine.AddEffect(Pointer(GDVars.spellTargets[1]), 146, FxEngine.RollDice(1, 4) * 10 + 40, enc, True);
  FxEngine.RecalcAbility(Pointer(GDVars.spellTargets[1]), C_Stat.STRENGTH);
end;

procedure SpellJavelinOfLightning;
var
  blocked: Boolean;
begin
  Magic.LightningAttackAt(GDVars.spellTargetX, GDVars.spellTargetY, FxEngine.RollDice(1, 6) + 20, 4, 0, blocked);
  Magic.LightningPath(3, 20, 4, False);
end;

procedure SpellWandOfParalyzation;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, False, 0, 0, 'is paralyzed');
end;

procedure SpellPotionOfHealing;
begin
  if FxEngine.RestoreHitPoints(Pointer(GDVars.spellTargets[1]), FxEngine.RollDice(2, 4) + 2, False) then
    CharHlp.PrintNameStringAnim(Types.PCreature(GDVars.spellTargets[1]), True, 'is Healed');
end;

procedure SpellDustOfDisappearance;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, False, 0, 0, 'is invisible');
end;

procedure SpellWandOfMagicMissiles;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, False, FxEngine.RollDamageDice(2, 4) + 2, 8, '');
end;

procedure SpellCauseSeriousWounds;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, False, FxEngine.RollDamageDice(2, 8) + 1, 8, '');
end;

procedure SpellNeutralizePoison;
var
  tgt: Types.PCreature;
  eff: Types.PEffect;
begin
  tgt := GDVars.spellTargets[1];
  if tgt^.status = C_Status.ANIMATED then
    GDVars.spellTargets[1] := nil
  else if CharHlp.HasEffect(tgt, C_Effect.POISONED, eff) then begin
    if tgt^.hpCur = 0 then
      tgt^.hpCur := 1;
    GDVars.effectLock := 1;
    FxEngine.RemoveEffect(Pointer(tgt), C_Effect.POISONED, nil);
    FxEngine.RemoveEffect(Pointer(tgt), C_Effect.SLOW_POISON_END, nil);
    FxEngine.RemoveEffect(Pointer(tgt), C_Effect.POISON_DAMAGE, nil);
    GDVars.effectLock := 0;
    CharHlp.PrintCreatureMessage(tgt, 'is unpoisoned', 10, True);
    tgt^.enabled := 1;
    tgt^.status := C_Status.OKAY;
  end else
    CharHlp.PrintCreatureMessage(tgt, 'is unaffected', 10, True);
end;

procedure SpellPoison;
var
  eff: Types.PEffect;
  tgt: Types.PCreature;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, False, 0, 8, '');
  tgt := GDVars.curChar^.combatAddr^.other;
  GDVars.effectCheck := 64;
  FxEngine.TriggerEffectsWithCondition(9, Pointer(tgt));
  if GDVars.effectCheck = 64 then
    FxEngine.CallEffectHandler(64, Pointer(GDVars.curChar), eff, False);
end;

procedure SpellSticksToSnakes;
var
  eff: Types.PEffect;
begin
  if GDVars.spellTargets[1]^.levelHighest < 6 then begin
    Magic.ResolveSpell(GDVars.spellId, CharHlp.GetCasterLevel(GDVars.spellId), False, 0, 8, '');
    if CharHlp.HasEffect(Types.PCreature(GDVars.spellTargets[1]), 3, eff) then
      FxEngine.CallEffectHandler(3, Pointer(GDVars.spellTargets[1]), eff, False);
  end else
    CharHlp.PrintCreatureMessage(Types.PCreature(GDVars.spellTargets[1]), 'smashes them flat', 10, True);
end;

procedure SpellCureCriticalWounds;
begin
  if GDVars.spellTargetCount = 0 then
    Exit;
  if FxEngine.RestoreHitPoints(Pointer(GDVars.spellTargets[1]), FxEngine.RollDice(3, 8) + 3, False) then
    CharHlp.AnnounceHealStatus(Types.PCreature(GDVars.spellTargets[1]));
end;

procedure SpellCauseCriticalWounds;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, False, FxEngine.RollDamageDice(3, 8) + 3, 8, '');
end;

procedure SpellDispelEvil;
begin
  FxEngine.AddEffectWithMessage(Pointer(GDVars.curChar), 4, Magic.CalcSpellDuration(73), 0, False, False, False, '');
  Magic.ResolveSpell(GDVars.spellId, 0, False, 0, 0, 'is affected');
end;

procedure SpellFlameStrike;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, False, FxEngine.RollDamageDice(6, 8), 9, '');
end;

procedure SpellRaiseDead;
var
  tgt: Types.PCreature;
begin
  tgt := GDVars.spellTargets[1];
  if ((tgt^.status = C_Status.DEAD_STATUS) or (tgt^.status = C_Status.ANIMATED)) and
      (tgt^.stats[C_Stat.CONSTITUTION].permanent > 0) and (tgt^.race <> C_Race.ELF) then begin
    GDVars.effectLock := 1;
    FxEngine.RemoveEffect(Pointer(tgt), C_Effect.ANIMATE_DEAD, nil);
    FxEngine.RemoveEffect(Pointer(tgt), C_Effect.POISONED, nil);
    GDVars.effectLock := 0;
    tgt^.status := C_Status.OKAY;
    tgt^.enabled := 1;
    Dec(tgt^.stats[C_Stat.CONSTITUTION].permanent);
    FxEngine.RecalcAbility(Pointer(tgt), C_Stat.CONSTITUTION);
    tgt^.hpCur := 1;
    CharHlp.PrintCreatureMessage(Types.PCreature(Pointer(tgt)), 'is raised', 10, True);
  end;
end;

procedure SpellSlayLiving;
var
  tgt: Types.PCreature;
begin
  tgt := GDVars.spellTargets[1];
  GDVars.elementMask := $40;
  GDVars.damage := 67;
  FxEngine.TriggerEffectsWithCondition(9, Pointer(tgt));
  if GDVars.damage <> 0 then begin
    if not FxEngine.RollSavingThrow(Pointer(tgt), 4, 0) then
      FxEngine.KillCreature(Pointer(tgt), C_Status.DEAD_STATUS, 'is slain')
    else begin
      GDVars.elementMask := 8;
      FxEngine.InflictNonWeaponDamage(Pointer(tgt), FxEngine.RollDamageDice(2, 8) + 1, 0, False);
    end;
  end else
    CharHlp.PrintCreatureMessage(Types.PCreature(Pointer(tgt)), 'is unaffected', 10, True);
end;

procedure SpellEntangle;
var
  tgt: Types.PCreature;
  i: Byte;
  saved: Boolean;
begin
  if GDVars.zone0^[C_Gbvm.VIEW_3D] <> 0 then
    Exit;
  for i := 1 to GDVars.spellTargetCount do
    if GDVars.spellTargets[i] <> nil then begin
      tgt := GDVars.spellTargets[i];
      saved := FxEngine.RollSavingThrow(Pointer(tgt), 4, 0);
      FxEngine.AddEffectWithMessage(Pointer(tgt), 136, Magic.CalcSpellDuration(136), 0, False, True, saved,
                                    'is entangled');
    end;
end;

procedure SpellFaerieFire;
begin
  Magic.ApplyEffectToTargets(0, 'is highlighted');
end;

procedure SpellInvisibilityToAnimals;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, False, 0, 0, 'is invisible');
end;

procedure SpellCharmMonsters;
var
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  charmCount: Integer;
  eff: Types.PEffect;
  { Unused in this version; see the other implementations of this routine. }
  charmInfo: array[0..2] of Byte;
begin
  Magic.ApplyEffectToTargets(0, 'is charmed');
  for i := 1 to GDVars.spellTargetCount do
    if CharHlp.HasEffect(Types.PCreature(GDVars.spellTargets[i]), C_Effect.CHARM, eff) then
      FxEngine.CallEffectHandler(C_Effect.CHARM, Pointer(GDVars.spellTargets[i]), eff, False);
end;

procedure SpellConfusion;
var
  i: Byte;
  saved: Boolean;
  tgt: Types.PCreature;
  { Unused in this version; see the other implementations of this routine. }
  eff: array[0..3] of Byte;
  maxTargets: Byte;
begin
  maxTargets := FxEngine.RollDice(2, 8);
  if GDVars.spellTargetCount > maxTargets then
    GDVars.spellTargetCount := maxTargets;
  for i := 1 to GDVars.spellTargetCount do
    if GDVars.spellTargets[i] <> nil then begin
      tgt := GDVars.spellTargets[i];
      saved := FxEngine.RollSavingThrow(Pointer(tgt), 4, 0);
      FxEngine.AddEffectWithMessage(Pointer(tgt), 35, Magic.CalcSpellDuration(82), 0, False, True, saved,
                                    'is confused');
    end;
end;

procedure SpellDimensionDoor;
var
  caster: Types.PCreature;
  target: Types.PCreature;
  { Unused in this version; see the other implementations of this routine. }
  locOk: Boolean;
  eff: Types.PEffect;
  i: Byte;
begin
  caster := GDVars.curChar;
  if CharHlp.HasEffect(caster, C_Effect.IMMOBILE, eff) then begin
    Pathing.BuildTargetList(CbtMap.CombatCellX(Pointer(caster)), CbtMap.CombatCellY(Pointer(caster)), 1, 255, 1,
                            GDVars.combatArena);
    for i := 1 to GDVars.targetCount do begin
      target := GDVars.combatCreatures[GDVars.targetList[i].idx];
      if CharHlp.HasEffect(target, 144, eff)
         or CharHlp.HasEffect(target, 139, eff) then
        if GDVars.combatCreatures[eff^.strength] = caster then begin
          FxEngine.RemoveEffect(Pointer(target), 144, nil);
          FxEngine.RemoveEffect(Pointer(target), 139, nil);
        end;
    end;
  end;
  CbtMap.UpdateCombatMapTile(0, 0, CbtMap.CombatSlot(Pointer(caster)));
  locOk := CbtMap.IsValidCreatureLoc(Pointer(caster), GDVars.spellTargetX, GDVars.spellTargetY, False);
  CbtMap.ScrollView(CbtMap.CombatCellX(Pointer(caster)), CbtMap.CombatCellY(Pointer(caster)), 0, 8);
  CharHlp.PrintCreatureMessage(caster, 'teleports', 10, True);
end;

procedure SpellFear;
var
  caster: Types.PCreature;
  tgt: Types.PCreature;
  i: Byte;
  saved: Boolean;
begin
  caster := GDVars.curChar;
  Magic.CollectConeTargets(CbtMap.CombatCellX(Pointer(caster)), CbtMap.CombatCellY(Pointer(caster)),
                            GDVars.spellTargetX, GDVars.spellTargetY, 3, 6);
  for i := 1 to GDVars.spellTargetCount do begin
    tgt := GDVars.spellTargets[i];
    saved := FxEngine.RollSavingThrow(Pointer(tgt), 4, 0);
    if not saved then begin
      FxEngine.AddEffectWithMessage(Pointer(tgt), 142, Magic.CalcSpellDuration(84), 0, True, True, saved,
                                    'runs in terror');
      tgt^.combatAddr^.turned := 1;
      tgt^.quickfight := 1;
      if tgt^.npc <= $7F then
        tgt^.npc := $B3;
      tgt^.combatAddr^.other := nil;
    end else
      CharHlp.PrintCreatureMessage(Types.PCreature(Pointer(tgt)), 'is unaffected', 10, True);
  end;
end;

procedure SpellFireShield;
var
  ch: Char;
  ext: Boolean;
  done: Boolean;
begin
  done := False;
  repeat
    if GDVars.curChar^.quickfight <> 0 then begin
      if FxEngine.RollDice(1, 10) > 5 then
        ch := 'H'
      else
        ch := 'C';
    end else
      ch := MenuCore.MenuHorizontal('flame type: ', 'Hot Cold', LightMagenta, LightGreen, White, False, False, ext);
    case ch of
      'H':
        begin
          FxEngine.AddEffectWithMessage(Pointer(GDVars.curChar), 50, Magic.CalcSpellDuration(85), 0, False, False,
                                        False, 'is protected');
          FxEngine.AddEffectWithMessage(Pointer(GDVars.curChar), 143, Magic.CalcSpellDuration(85), 0, False, False,
                                        False, '');
          done := True;
        end;
      'C':
        begin
          FxEngine.AddEffectWithMessage(Pointer(GDVars.curChar), 54, Magic.CalcSpellDuration(85), 0, False, False,
                                        False, '');
          FxEngine.AddEffectWithMessage(Pointer(GDVars.curChar), 143, Magic.CalcSpellDuration(85), 0, False, False,
                                        False, '');
          done := True;
        end;
    else begin
        ch := MenuCore.MenuHorizontal('Abort spell? ', 'Yes No', LightMagenta, LightGreen, White, False, False, ext);
        if ch = 'Y' then
          done := True;
      end;
    end;
  until done;
end;

procedure SpellFumble;
var
  tgt: Types.PCreature;
  eff: Types.PEffect;
begin
  tgt := GDVars.spellTargets[1];
  GDVars.elementMask := $40;
  if not FxEngine.RollSavingThrow(Pointer(tgt), 4, 0) then begin
    FxEngine.AddEffectWithMessage(Pointer(tgt), 27, Magic.CalcSpellDuration(86), 0, False, False, False,
                                  'is clumsy');
    if CharHlp.HasEffect(tgt, 27, eff) then
      FxEngine.CallEffectHandler(27, Pointer(tgt), nil, False);
  end else begin
    FxEngine.AddEffectWithMessage(Pointer(tgt), C_Effect.SLOWED, Magic.CalcSpellDuration(86), 0, False, False,
                                  False, 'is slowed');
    if CharHlp.HasEffect(tgt, C_Effect.SLOWED, eff) then
      FxEngine.CallEffectHandler(C_Effect.SLOWED, Pointer(tgt), nil, False);
  end;
  Magic.ResolveSpell(GDVars.spellId, 0, True, 0, 0, 'is clumsy');
end;

procedure SpellIceStorm;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, False, FxEngine.RollDamageDice(3, 10), 10, '');
end;

procedure SpellMinorGlobeOfInvulnerability;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, False, 0, 0, 'is protected');
end;

procedure SpellCloudkill;
var
  otherCloud: Types.PCloudNode;
  node: Types.PCloudNode;
  crIdx: array[1..9] of Byte;
  j: Byte;
  myClouds: Byte;
  terr: Byte;
  cl: Byte;
  k: Byte;
  dirIdx: Byte;
  foundUnder: Boolean;
begin
  GDVars.multiTarget := 1;
  cl := CharHlp.GetCasterLevel(GDVars.spellId);
  myClouds := 0;
  node := GDVars.cloudkillHead;
  if GDVars.cloudkillHead = nil then begin
    GetMem(GDVars.cloudkillHead, SizeOf(GDVars.cloudkillHead^));
    node := GDVars.cloudkillHead;
  end else begin
    while node^.next <> nil do begin
      if node^.caster = GDVars.curChar then
        Inc(myClouds);
      node := node^.next;
    end;
    GetMem(node^.next, SizeOf(node^.next^));
    node := node^.next;
  end;
  FillChar(node^, SizeOf(node^), 0);
  FxEngine.AddEffect(Pointer(GDVars.curChar), C_Effect.CAST_CLOUDKILL, cl, cl + myClouds * 16, True);
  node^.caster := GDVars.curChar;
  node^.idx := myClouds;
  node^.ulX := GDVars.spellTargetX;
  node^.ulY := GDVars.spellTargetY;
  for k := 1 to 9 do begin
    dirIdx := GDConsts.cloudkillDirections[k];
    CbtMap.GetArenaContents(GDVars.spellTargetX + GDConsts.directionDx[dirIdx],
                            GDVars.spellTargetY + GDConsts.directionDy[dirIdx], crIdx[k], terr);
    if (terr > 0) and (GDConsts.terrainInfo[terr].cost < 255) then
      node^.exists[k] := 1
    else
      node^.exists[k] := 0;
    case terr of
      C_Terr.STINKING_CLOUD:
        begin
          otherCloud := GDVars.stinkHead;
          foundUnder := False;
          while (otherCloud <> nil) and not foundUnder do begin
            for j := 1 to 4 do
              if (otherCloud^.exists[j] <> 0) and
                  (otherCloud^.ulX + GDConsts.directionDx[GDConsts.stinkingCloudDirections[j]] = GDVars.spellTargetX +
                  GDConsts.directionDx[dirIdx]) and
                  (otherCloud^.ulY + GDConsts.directionDy[GDConsts.stinkingCloudDirections[j]] = GDVars.spellTargetY +
                  GDConsts.directionDy[dirIdx]) and (otherCloud^.under[j] <> C_Terr.STINKING_CLOUD) and
                  (otherCloud^.under[j] <> C_Terr.CLOUDKILL) then begin
                terr := otherCloud^.under[j];
                foundUnder := True;
              end;
            otherCloud := otherCloud^.next;
          end;
        end;
      C_Terr.CLOUDKILL:
        begin
          otherCloud := GDVars.cloudkillHead;
          foundUnder := False;
          while (otherCloud <> nil) and not foundUnder do begin
            if otherCloud <> node then
              for j := 1 to 9 do
                if (otherCloud^.exists[j] <> 0) and
                    (otherCloud^.ulX + GDConsts.directionDx[GDConsts.cloudkillDirections[j]] = GDVars.spellTargetX +
                    GDConsts.directionDx[dirIdx]) and
                    (otherCloud^.ulY + GDConsts.directionDy[GDConsts.cloudkillDirections[j]] = GDVars.spellTargetY +
                    GDConsts.directionDy[dirIdx]) and (otherCloud^.under[j] <> C_Terr.STINKING_CLOUD) and
                    (otherCloud^.under[j] <> C_Terr.CLOUDKILL) then begin
                  terr := otherCloud^.under[j];
                  foundUnder := True;
                end;
            otherCloud := otherCloud^.next;
          end;
        end;
      C_Terr.CORPSE:
        begin
          for j := 1 to GDVars.downedCount do
            if GDVars.downedCharacters[j].x = GDVars.spellTargetX + GDConsts.directionDx[dirIdx] then
              if GDVars.downedCharacters[j].y = GDVars.spellTargetY + GDConsts.directionDy[dirIdx] then
                terr := GDVars.downedCharacters[j].terrain;
        end;
    end;
    node^.under[k] := terr;
    if node^.exists[k] <> 0 then
      GDVars.combatArena^.cells[GDVars.spellTargetY + GDConsts.directionDy[dirIdx],
                   GDVars.spellTargetX + GDConsts.directionDx[dirIdx]] := C_Terr.CLOUDKILL;
  end;
  node^.under[k] := terr;
  if node^.exists[k] <> 0 then
    GDVars.combatArena^.cells[GDVars.spellTargetY + GDConsts.directionDy[dirIdx],
                 GDVars.spellTargetX + GDConsts.directionDx[dirIdx]] := C_Terr.CLOUDKILL;
  CharHlp.PrintCreatureMessage(GDVars.curChar, 'Creates a poisonous cloud', 10, False);
  CbtMap.ScrollView(GDVars.spellTargetX, GDVars.spellTargetY, 255, 8);
  TextRend.PauseOnly;
  CharHlp.ClearMessageWindow;
  for k := 1 to 9 do
    if crIdx[k] > 0 then
      FxEngine.ConsiderTerrainEffects(Pointer(GDVars.combatCreatures[crIdx[k]]), 1);
end;

procedure SpellConeOfCold;
var
  p: Types.PCreature;
  reach: Byte;
  lvl: Byte;
begin
  p := GDVars.curChar;
  lvl := CharHlp.GetCasterLevel(GDVars.spellId);
  reach := (CharHlp.GetCasterLevel(GDVars.spellId) + 1) shr 1;
  if reach < 1 then
    reach := 1;
  Magic.CollectConeTargets(CbtMap.CombatCellX(Pointer(p)), CbtMap.CombatCellY(Pointer(p)), GDVars.spellTargetX,
                            GDVars.spellTargetY, 2, reach);
  Magic.ResolveSpell(GDVars.spellId, 0, False, lvl + FxEngine.RollDamageDice(lvl, 4), 10, '');
end;

procedure SpellFeeblemind;
var
  oldSpellSave: Byte;
  tgt: Types.PCreature;
  eff: Types.PEffect;
begin
  tgt := GDVars.spellTargets[1];
  oldSpellSave := tgt^.saves[4];
  case tgt^.charClass of
    0: Dec(tgt^.saves[4]);
    5: Inc(tgt^.saves[4], 4);
  else
    Inc(tgt^.saves[4], 2);
  end;
  Magic.ResolveSpell(GDVars.spellId, 0, False, 0, 0, '');
  if CharHlp.HasEffect(tgt, 68, eff) then
    FxEngine.CallEffectHandler(68, Pointer(tgt), nil, False);
  tgt^.saves[4] := oldSpellSave;
end;

procedure SpellImmuneBreath;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, False, 0, 0, '');
end;

procedure SpellImmuneParalysis;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, False, 0, 0, '');
end;

procedure SpellTurnInvisible;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, False, 0, 0, '');
end;

procedure SpellConeBlast;
var
  i: Byte;
  caster: Types.PCreature;
  tgt: Types.PCreature;
  saved: Boolean;
begin
  caster := GDVars.curChar;
  Magic.CollectConeTargets(CbtMap.CombatCellX(Pointer(caster)), CbtMap.CombatCellY(Pointer(caster)),
                            GDVars.spellTargetX, GDVars.spellTargetY, 1, 3);
  for i := 1 to GDVars.spellTargetCount do
    if GDVars.spellTargets[i] <> nil then begin
      tgt := GDVars.spellTargets[i];
      if tgt^.charType = 18 then
        saved := False
      else
        saved := True;
      FxEngine.InflictNonWeaponDamage(Pointer(tgt), FxEngine.RollDamageDice(6, 6),
                                      GDConsts.spellProperties[98].saveResult, saved);
    end;
end;

procedure SpellHealSelf;
begin
  if FxEngine.RestoreHitPoints(Pointer(GDVars.spellTargets[1]), FxEngine.RollDice(2, 4) + 2, False) then
    CharHlp.PrintNameStringAnim(Types.PCreature(GDVars.spellTargets[1]), True, 'is Healed');
end;

procedure EffAimedPetrifyingGaze(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var
  node: Types.PItem;
  reflected: Boolean;
  eff: Types.PEffect;
begin
  cr^.combatAddr^.other := nil;
  GDVars.spellHandlers.castTargets(65, True, GDVars.breathAim);
  if cr^.combatAddr^.other = nil then
    Exit;
  GDVars.combatTarget := cr^.combatAddr^.other;
  CharHlp.PrintCreatureMessage(cr, 'gazes...', 10, False);
  CharHlp.BuildIconFacings(18);
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(Pointer(cr)), CbtMap.CombatCellY(Pointer(cr)),
                                  CbtMap.CombatCellX(Pointer(GDVars.combatTarget)),
                                  CbtMap.CombatCellY(Pointer(GDVars.combatTarget)), 4, 45);
  if CharHlp.HasEffect(cr, 127, eff) then begin
    reflected := False;
    node := GDVars.combatTarget^.itemsAddr;
    while (node <> nil) and not reflected do begin
      if node^.equipped <> 0 then
        if (node^.nameIds[1] = 118) or (node^.nameIds[2] = 118) or (node^.nameIds[3] = 118) then begin
          CharHlp.PrintCreatureMessage(GDVars.combatTarget, 'reflects it!', 12, False);
          CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(Pointer(GDVars.combatTarget)),
                                          CbtMap.CombatCellY(Pointer(GDVars.combatTarget)),
                                          CbtMap.CombatCellX(Pointer(cr)), CbtMap.CombatCellY(Pointer(cr)), 4, 45);
          reflected := True;
          GDVars.combatTarget := cr;
        end;
      node := node^.next;
    end;
  end;
  if not FxEngine.RollSavingThrow(Pointer(GDVars.combatTarget), 1, 0) then
    FxEngine.KillCreature(Pointer(GDVars.combatTarget), C_Status.STONED, 'is Stoned');
end;

procedure EffBreatheLightning(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var
  blocked: Boolean;
  x: ShortInt;
  y: ShortInt;
begin
  if GDVars.roundCounter <> 0 then
    if FxEngine.RollDice(1, 100) <= 50 then
      Exit;
  GDVars.elementMask := $24;
  x := CbtMap.CombatCellX(Pointer(cr));
  y := CbtMap.CombatCellY(Pointer(cr));
  CharHlp.PrintCreatureMessage(cr, 'Breathes!', 10, True);
  GDVars.spellHandlers.castTargets(51, True, GDVars.breathAim);
  GDVars.spellTargetX := x + Pathing.SignOf(GDVars.spellTargetX - x);
  GDVars.spellTargetY := y + Pathing.SignOf(GDVars.spellTargetY - y);
  if GDVars.spellTargetX = x + 1 then
    Inc(GDVars.spellTargetX);
  if GDVars.spellTargetY = y + 1 then
    Inc(GDVars.spellTargetY);
  FxEngine.RemoveInvisibility(Pointer(cr));
  CharHlp.BuildIconFacings(19);
  CharHlp.CombatAnimateMovingIcon(x, y, GDVars.spellTargetX, GDVars.spellTargetY, 4, 50);
  Magic.LightningAttackAt(GDVars.spellTargetX, GDVars.spellTargetY, cr^.hpMax, 3, 0, blocked);
  Magic.LightningPath(10, cr^.hpMax, 3, False);
  if Types.PEffect(effect)^.strength > 253 then
    Dec(Types.PEffect(effect)^.strength)
  else
    FxEngine.RemoveEffect(Pointer(cr), 88, effect);
  blocked := CharHlp.EndActions(cr);
end;

procedure EffSpitAcidBreath(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var
  roll: Byte;
begin
  GDVars.spellHandlers.castTargets(65, True, GDVars.breathAim);
  GDVars.combatTarget := cr^.combatAddr^.other;
  roll := FxEngine.RollDice(1, 100);
  if CharHlp.CalcDistance(cr, GDVars.combatTarget) >= 7 then
    Exit;
  if GDVars.combatTarget = nil then
    Exit;
  if roll <= 30 then begin
    CharHlp.PrintCreatureMessage(cr, 'Spits Acid', 10, True);
    CharHlp.BuildIconFacings(23);
    CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(Pointer(cr)), CbtMap.CombatCellY(Pointer(cr)),
                                    CbtMap.CombatCellX(Pointer(GDVars.combatTarget)),
                                    CbtMap.CombatCellY(Pointer(GDVars.combatTarget)), 1, 30);
    FxEngine.InflictNonWeaponDamage(Pointer(GDVars.combatTarget), cr^.hpMax, 2,
                                    FxEngine.RollSavingThrow(Pointer(GDVars.combatTarget), 3, 0));
  end else
    CharHlp.PrintCreatureMessage(cr, 'Spits Acid and Misses', 10, True);
end;

procedure EffBreatheAcid(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  turnDone: Boolean;
  ox: ShortInt;
  oy: ShortInt;
  i: Byte;
  tgt: Types.PCreature;
  saved: Boolean;
begin
  GDVars.breathAim := False;
  if GDVars.roundCounter = 0 then
    Types.PEffect(effect)^.strength := 3;
  if Types.PEffect(effect)^.strength <= 0 then
    Exit;
  GDVars.elementMask := $30;
  ox := CbtMap.CombatCellX(Pointer(cr));
  oy := CbtMap.CombatCellY(Pointer(cr));
  GDVars.spellHandlers.castTargets(61, True, GDVars.breathAim);
  if GDVars.breathAim then
    Magic.CollectConeTargets(ox, oy, GDVars.spellTargetX, GDVars.spellTargetY, 1, 6);
  for i := 1 to GDVars.spellTargetCount do
    if Byte(CharHlp.NotHostile(cr)) <> Byte(GDVars.spellTargets[i]^.hostile) then
      GDVars.breathAim := False;
  if not GDVars.breathAim then
    Exit;
  if GDVars.spellTargetCount <= 0 then
    Exit;
  CharHlp.PrintCreatureMessage(cr, 'breathes acid', 10, True);
  CharHlp.BuildIconFacings(18);
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(Pointer(cr)), CbtMap.CombatCellY(Pointer(cr)),
                                  CbtMap.CombatCellX(Pointer(GDVars.spellTargets[1])),
                                  CbtMap.CombatCellY(Pointer(GDVars.spellTargets[1])), 1, 30);
  for i := 1 to GDVars.spellTargetCount do
    if GDVars.spellTargets[i] <> nil then begin
      tgt := GDVars.spellTargets[i];
      saved := FxEngine.RollSavingThrow(Pointer(tgt), 3, 0);
      FxEngine.InflictNonWeaponDamage(Pointer(tgt), cr^.hpMax, 2, saved);
    end;
  Dec(Types.PEffect(effect)^.strength);
  turnDone := CharHlp.EndActions(cr);
end;

procedure EffBreatheFire(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  turnDone: Boolean;
  bx: ShortInt;
  by: ShortInt;
  i: Byte;
  tgt: Types.PCreature;
  saved: Boolean;
begin
  if GDVars.roundCounter = 0 then
    Types.PEffect(effect)^.strength := 3;
  if Types.PEffect(effect)^.strength > 0 then begin
    GDVars.elementMask := $21;
    bx := CbtMap.CombatCellX(Pointer(cr));
    by := CbtMap.CombatCellY(Pointer(cr));
    GDVars.spellHandlers.castTargets(61, True, GDVars.breathAim);
    if not GDVars.breathAim then
      Exit;
    Magic.CollectConeTargets(bx, by, GDVars.spellTargetX, GDVars.spellTargetY, 3, 9);
    if GDVars.spellTargetCount > 0 then begin
      CharHlp.PrintCreatureMessage(Types.PCreature(Pointer(cr)), 'breathes fire', 10, True);
      CharHlp.BuildIconFacings(18);
      CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(Pointer(cr)), CbtMap.CombatCellY(Pointer(cr)),
                                      CbtMap.CombatCellX(Pointer(GDVars.spellTargets[1])),
                                      CbtMap.CombatCellY(Pointer(GDVars.spellTargets[1])), 1, 30);
      for i := 1 to GDVars.spellTargetCount do
        if GDVars.spellTargets[i] <> nil then begin
          tgt := GDVars.spellTargets[i];
          saved := FxEngine.RollSavingThrow(Pointer(tgt), 3, 0);
          FxEngine.InflictNonWeaponDamage(Pointer(tgt), cr^.hpMax, 2, saved);
        end;
      Dec(Types.PEffect(effect)^.strength);
      turnDone := CharHlp.EndActions(Types.PCreature(Pointer(cr)));
    end;
  end;
end;

procedure EffBreatheFireAdjacent(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  GDVars.spellHandlers.castTargets(65, True, GDVars.breathAim);
  GDVars.combatTarget := cr^.combatAddr^.other;
  if FxEngine.RollDice(1, 100) > 50 then
    Exit;
  if CharHlp.CalcDistance(Pointer(cr), Pointer(GDVars.combatTarget)) >= 2 then
    Exit;
  if GDVars.combatTarget = nil then
    Exit;
  GDVars.elementMask := 1;
  GDVars.breathAim := CharHlp.EndActions(Types.PCreature(Pointer(cr)));
  CharHlp.PrintCreatureMessage(Types.PCreature(Pointer(cr)), 'Breathes Fire', 10, True);
  CharHlp.BuildIconFacings(23);
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(Pointer(cr)), CbtMap.CombatCellY(Pointer(cr)),
                                  CbtMap.CombatCellX(Pointer(GDVars.combatTarget)),
                                  CbtMap.CombatCellY(Pointer(GDVars.combatTarget)), 1, 30);
  FxEngine.InflictNonWeaponDamage(Pointer(GDVars.combatTarget), 7, 2,
                                  FxEngine.RollSavingThrow(Pointer(GDVars.combatTarget), 3, 0));
end;

procedure EffThrowLightning(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var
  blocked: Boolean;
  bx: ShortInt;
  by: ShortInt;
begin
  if GDVars.roundCounter >= 4 then
    Exit;
  bx := CbtMap.CombatCellX(Pointer(cr));
  by := CbtMap.CombatCellY(Pointer(cr));
  CharHlp.PrintCreatureMessage(Types.PCreature(Pointer(cr)), 'throws lightning', 10, True);
  GDVars.spellHandlers.castTargets(51, True, GDVars.breathAim);
  FxEngine.RemoveInvisibility(Pointer(cr));
  CharHlp.BuildIconFacings(19);
  CharHlp.CombatAnimateMovingIcon(bx, by, GDVars.spellTargetX, GDVars.spellTargetY, 4, 50);
  Magic.LightningAttackAt(GDVars.spellTargetX, GDVars.spellTargetY, FxEngine.RollDamageDice(16, 6), 4, 0,
                          blocked);
  Magic.LightningPath(10, FxEngine.RollDamageDice(16, 6), 4, False);
  blocked := CharHlp.EndActions(Types.PCreature(Pointer(cr)));
end;

procedure EffAimedParalyzingGaze(cr: Types.PCreature; effect: Pointer; removed: Boolean);
begin
  cr^.combatAddr^.other := nil;
  GDVars.spellHandlers.castTargets(36, True, GDVars.breathAim);
  GDVars.combatTarget := cr^.combatAddr^.other;
  if GDVars.combatTarget = nil then
    Exit;
  CharHlp.PrintCreatureMessage(cr, 'gazes...', 10, False);
  CharHlp.BuildIconFacings(18);
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(Pointer(cr)), CbtMap.CombatCellY(Pointer(cr)),
                                  CbtMap.CombatCellX(Pointer(GDVars.combatTarget)),
                                  CbtMap.CombatCellY(Pointer(GDVars.combatTarget)), 4, 45);
  if not FxEngine.RollSavingThrow(Pointer(GDVars.combatTarget), 1, 0) then begin
    FxEngine.AddEffect(Pointer(GDVars.combatTarget), C_Effect.PARALYZED, 60, 255, False);
    CharHlp.PrintCreatureMessage(GDVars.combatTarget, 'is paralyzed', 10, False);
  end;
end;

function ItemReadable(it: Pointer): Boolean;
begin
  if (it <> nil) and (GDVars.baseItems[Types.PItem(it)^.itemType].slot > 10) and
      (GDVars.baseItems[Types.PItem(it)^.itemType].slot < 14) then
    ItemReadable := True
  else
    ItemReadable := False;
end;

procedure RemoveSpellFromScroll(cr, it: Pointer; spell: Byte);
var
  sp: Byte;
  i: Byte;
  found: Byte;
begin
  sp := spell;
  found := 0;
  for i := 1 to 3 do
    if Types.PItem(it)^.spells[i] and C_Spell.ID_MASK = sp then
      found := i;
  if found = 0 then
    Exit;
  Types.PItem(it)^.spells[found] := 0;
  Dec(Types.PItem(it)^.nameIds[2]);
  if Types.PItem(it)^.nameIds[2] < 210 then
    CharHlp.RemoveItem(Types.PCreature(cr), Types.PItem(it));
end;

procedure PrintCastSpellMsg(creature: Types.PCreature; msg: Types.TStr40; spell: Byte);
begin
  if GDVars.ifcState = C_Ifc.IN_COMBAT then begin
    CharHlp.PrintCreatureMessage(creature, 'Casts a Spell', 10, True);
    Border.ClearBox(0, 23, 39, 23);
    TextRend.DisplayString(0, 23, LightGreen, 0, 'Spell:' + GDConsts.spellNames[spell]);
  end else begin
    Border.ClearBox(1, 18, 38, 22);
    CharHlp.DisplayCreatureName(creature, 1, 19, False);
    TextRend.DisplayString(Length(creature^.name) + 2, 19, LightGreen, 0, msg);
    TextRend.DisplayString(1, 20, LightGreen, 0, GDConsts.spellNames[spell]);
    TextRend.PauseOnly;
    CharHlp.ClearMessageWindow;
  end;
end;

procedure InitSpellFns;
begin
  @GDVars.spellHandlers.castTargets := @Magic.NoncombatCastTargetMenu;
  GDVars.effectLock := 0;
  GDVars.usingItem := False;
  GDVars.lastSpellTarget := nil;
  GDVars.invRedraw := 1;
  @GDVars.spellHandlers.spells[1] := @Magic.SpellBless;
  @GDVars.spellHandlers.spells[2] := @Magic.SpellCurse;
  @GDVars.spellHandlers.spells[C_Spell.CURE_LIGHT_WOUNDS] := @Magic.SpellCureLightWounds;
  @GDVars.spellHandlers.spells[4] := @Magic.SpellCauseLightWounds;
  @GDVars.spellHandlers.spells[5] := @Magic.SpellDetection;
  @GDVars.spellHandlers.spells[6] := @Magic.SpellProtection;
  @GDVars.spellHandlers.spells[7] := @Magic.SpellProtection;
  @GDVars.spellHandlers.spells[8] := @Magic.SpellResistCold;
  @GDVars.spellHandlers.spells[9] := @Magic.SpellBurningHands;
  @GDVars.spellHandlers.spells[10] := @Magic.SpellCharmPerson;
  @GDVars.spellHandlers.spells[11] := @Magic.SpellDetection;
  @GDVars.spellHandlers.spells[12] := @Magic.SpellEnlarge;
  @GDVars.spellHandlers.spells[13] := @Magic.SpellReduce;
  @GDVars.spellHandlers.spells[14] := @Magic.SpellFriends;
  @GDVars.spellHandlers.spells[15] := @Magic.SpellMagicMissile;
  @GDVars.spellHandlers.spells[16] := @Magic.SpellProtection;
  @GDVars.spellHandlers.spells[17] := @Magic.SpellProtection;
  @GDVars.spellHandlers.spells[18] := @Magic.SpellDetection;
  @GDVars.spellHandlers.spells[19] := @Magic.SpellShield;
  @GDVars.spellHandlers.spells[20] := @Magic.SpellShockingGrasp;
  @GDVars.spellHandlers.spells[21] := @Magic.SpellSleep;
  @GDVars.spellHandlers.spells[22] := @Magic.SpellDetection;
  @GDVars.spellHandlers.spells[23] := @Magic.SpellHold;
  @GDVars.spellHandlers.spells[24] := @Magic.SpellResistFire;
  @GDVars.spellHandlers.spells[25] := @Magic.SpellSilence;
  @GDVars.spellHandlers.spells[26] := @Magic.SpellSlowPoison;
  @GDVars.spellHandlers.spells[27] := @Magic.SpellSnakeCharm;
  @GDVars.spellHandlers.spells[28] := @Magic.SpellSpiritualHammer;
  @GDVars.spellHandlers.spells[29] := @Magic.SpellDetection;
  @GDVars.spellHandlers.spells[30] := @Magic.SpellInvisibility;
  @GDVars.spellHandlers.spells[31] := @Magic.SpellKnock;
  @GDVars.spellHandlers.spells[32] := @Magic.SpellMirrorImage;
  @GDVars.spellHandlers.spells[33] := @Magic.SpellRayOfEnfeeblement;
  @GDVars.spellHandlers.spells[34] := @Magic.SpellStinkingCloud;
  @GDVars.spellHandlers.spells[35] := @Magic.SpellStrength;
  @GDVars.spellHandlers.spells[36] := @Magic.SpellAnimateDead;
  @GDVars.spellHandlers.spells[37] := @Magic.SpellCureBlindness;
  @GDVars.spellHandlers.spells[38] := @Magic.SpellCauseBlindness;
  @GDVars.spellHandlers.spells[39] := @Magic.SpellCureDisease;
  @GDVars.spellHandlers.spells[40] := @Magic.SpellCauseDisease;
  @GDVars.spellHandlers.spells[41] := @Magic.SpellDispelMagic;
  @GDVars.spellHandlers.spells[42] := @Magic.SpellPrayer;
  @GDVars.spellHandlers.spells[43] := @Magic.SpellRemoveCurse;
  @GDVars.spellHandlers.spells[44] := @Magic.SpellBestowCurse;
  @GDVars.spellHandlers.spells[45] := @Magic.SpellBlink;
  @GDVars.spellHandlers.spells[46] := @Magic.SpellDispelMagic;
  @GDVars.spellHandlers.spells[47] := @Magic.SpellFireball;
  @GDVars.spellHandlers.spells[48] := @Magic.SpellHaste;
  @GDVars.spellHandlers.spells[49] := @Magic.SpellHold;
  @GDVars.spellHandlers.spells[50] := @Magic.SpellInvisibility;
  @GDVars.spellHandlers.spells[51] := @Magic.SpellLightningBolt;
  @GDVars.spellHandlers.spells[52] := @Magic.SpellProtection;
  @GDVars.spellHandlers.spells[53] := @Magic.SpellProtection;
  @GDVars.spellHandlers.spells[54] := @Magic.SpellProtection;
  @GDVars.spellHandlers.spells[55] := @Magic.SpellSlow;
  @GDVars.spellHandlers.spells[56] := @Magic.SpellRestoration;
  @GDVars.spellHandlers.spells[57] := @Magic.SpellPotionOfSpeed;
  @GDVars.spellHandlers.spells[C_Spell.CURE_SERIOUS_WOUNDS] := @Magic.SpellCureSeriousWounds;
  @GDVars.spellHandlers.spells[59] := @Magic.SpellGiantStrength;
  @GDVars.spellHandlers.spells[60] := @Magic.SpellJavelinOfLightning;
  @GDVars.spellHandlers.spells[61] := @Magic.SpellWandOfParalyzation;
  @GDVars.spellHandlers.spells[62] := @Magic.SpellPotionOfHealing;
  @GDVars.spellHandlers.spells[63] := @Magic.SpellDustOfDisappearance;
  @GDVars.spellHandlers.spells[64] := @Magic.SpellFireball;
  @GDVars.spellHandlers.spells[65] := @Magic.SpellWandOfMagicMissiles;
  @GDVars.spellHandlers.spells[66] := @Magic.SpellCauseSeriousWounds;
  @GDVars.spellHandlers.spells[67] := @Magic.SpellNeutralizePoison;
  @GDVars.spellHandlers.spells[68] := @Magic.SpellPoison;
  @GDVars.spellHandlers.spells[69] := @Magic.SpellProtection;
  @GDVars.spellHandlers.spells[70] := @Magic.SpellSticksToSnakes;
  @GDVars.spellHandlers.spells[C_Spell.CURE_CRITICAL_WOUNDS] := @Magic.SpellCureCriticalWounds;
  @GDVars.spellHandlers.spells[72] := @Magic.SpellCauseCriticalWounds;
  @GDVars.spellHandlers.spells[73] := @Magic.SpellDispelEvil;
  @GDVars.spellHandlers.spells[74] := @Magic.SpellFlameStrike;
  @GDVars.spellHandlers.spells[75] := @Magic.SpellRaiseDead;
  @GDVars.spellHandlers.spells[76] := @Magic.SpellSlayLiving;
  @GDVars.spellHandlers.spells[77] := @Magic.SpellDetection;
  @GDVars.spellHandlers.spells[78] := @Magic.SpellEntangle;
  @GDVars.spellHandlers.spells[79] := @Magic.SpellFaerieFire;
  @GDVars.spellHandlers.spells[80] := @Magic.SpellInvisibilityToAnimals;
  @GDVars.spellHandlers.spells[81] := @Magic.SpellCharmMonsters;
  @GDVars.spellHandlers.spells[82] := @Magic.SpellConfusion;
  @GDVars.spellHandlers.spells[83] := @Magic.SpellDimensionDoor;
  @GDVars.spellHandlers.spells[84] := @Magic.SpellFear;
  @GDVars.spellHandlers.spells[85] := @Magic.SpellFireShield;
  @GDVars.spellHandlers.spells[86] := @Magic.SpellFumble;
  @GDVars.spellHandlers.spells[87] := @Magic.SpellIceStorm;
  @GDVars.spellHandlers.spells[88] := @Magic.SpellMinorGlobeOfInvulnerability;
  @GDVars.spellHandlers.spells[89] := @Magic.SpellRemoveCurse;
  @GDVars.spellHandlers.spells[90] := @Magic.SpellAnimateDead;
  @GDVars.spellHandlers.spells[91] := @Magic.SpellCloudkill;
  @GDVars.spellHandlers.spells[92] := @Magic.SpellConeOfCold;
  @GDVars.spellHandlers.spells[93] := @Magic.SpellFeeblemind;
  @GDVars.spellHandlers.spells[94] := @Magic.SpellHold;
  @GDVars.spellHandlers.spells[95] := @Magic.SpellImmuneBreath;
  @GDVars.spellHandlers.spells[96] := @Magic.SpellImmuneParalysis;
  @GDVars.spellHandlers.spells[97] := @Magic.SpellTurnInvisible;
  @GDVars.spellHandlers.spells[98] := @Magic.SpellConeBlast;
  @GDVars.spellHandlers.spells[99] := @Magic.SpellHealSelf;
  @GDVars.spellHandlers.spells[100] := @Magic.SpellBestowCurse;
  @GDVars.effectHandlers[83] := @Magic.EffAimedPetrifyingGaze;
  @GDVars.effectHandlers[86] := @Magic.EffSpitAcidBreath;
  @GDVars.effectHandlers[88] := @Magic.EffBreatheLightning;
  @GDVars.effectHandlers[90] := @Magic.EffBreatheAcid;
  @GDVars.effectHandlers[126] := @Magic.EffAimedParalyzingGaze;
  @GDVars.effectHandlers[128] := @Magic.EffBreatheFire;
  @GDVars.effectHandlers[131] := @Magic.EffBreatheFireAdjacent;
  @GDVars.effectHandlers[132] := @Magic.EffThrowLightning;
end;

begin
end.
