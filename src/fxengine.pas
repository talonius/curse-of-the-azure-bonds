{ The effect engine: adding, removing and triggering effects, attack rolls and saving throws, dice, damage that is not a
  weapon hit, cloud cell effects, ability recalculation, and death and revival. }
{$O+,F+}
{$A-}
unit FxEngine;

interface

uses Types, CharHlp, CbtMap, Pathing, Blit, TextRend, EclTrace, ClassCal, GDConsts, GDVars,
  C_Status, C_Effect, C_Ifc, C_Stat, C_Class, C_Gbvm;

{ Prints msg for cr. Unless cr is already dead, stoned or gone, it then gives cr status, disables it at 0 hit points,
  removes its effects that end at 0 hit points, runs its condition-13 (going down) effects, marks it downed on the
  combat map when those effects leave it disabled, pauses, and redraws the status border and, outside combat, the
  current character's sheet headers.
  @param(cr Creature being killed.)
  @param(status Status to give it, such as C_Status.DEAD_STATUS.)
  @param(msg Message printed after its name.) }
procedure KillCreature(cr: Types.PCreature; status: Byte; msg: Types.TStr40);

{ Calls an effect's handler, or the override handler instead while an override is active.
  @param(effId Effect whose handler is called.)
  @param(creature Creature the effect acts on.)
  @param(effectNode Node of the effect, passed on to the handler; may be nil.)
  @param(removed True when the call is for the effect's removal.) }
procedure CallEffectHandler(effId: Byte; creature: Types.PCreature; effectNode: Pointer; removed: Boolean);

{ Unlinks an effect node from creature's effect list and frees it, calling the handler of effId first when the node's
  onRemove flag is set. Removing effect 14 recalculates Charisma; removing Enlarge, Strength or effect 146 recalculates
  Strength.
  @param(creature Creature whose effect is removed.)
  @param(effId Effect looked for when eff is nil; it also selects the handler and the ability recalculated.)
  @param(eff Node to remove, or nil for creature's first effect effId; nothing happens when there is none.) }
procedure RemoveEffect(creature: Types.PCreature; effId: Byte; eff: Pointer);

{ Runs TriggerEffect for each effect on the list of condition cond, in list order. The conditions this unit raises are 6
  damage taken, 9 an effect being applied, 10 the attacker's and 16 the defender's attack roll, 12 a saving throw, 13
  going down and 20 damage taken without a save. Condition 0 and values above 23 do nothing.
  @param(cond Condition being checked.)
  @param(creature Creature whose effects are checked.) }
procedure TriggerEffectsWithCondition(cond: Byte; creature: Types.PCreature);

{ Applies the clouds on an enabled creature's cell. In a stinking cloud, when flag is nonzero and creature is neither
  helpless nor under Animate Dead nor protected by effect 111 or 125, it rolls a saving throw (type 0): on a save it
  starts to cough for 1 minute, otherwise nausea leaves it helpless for 1d4 + 1. The cloud's caster stands in as the
  current character while the effect is added and its handler runs. In a Cloudkill cloud, a creature still enabled whose
  levelHighest is 0..4 is poisoned and killed; type 5 escapes that with a save at -4, type 6 with a save at +0, and
  other types are unaffected. Note: the cough handler is passed the node left by the last failed effect search, which is
  nil, rather than the cough effect just added.
  @param(creature Creature to check.)
  @param(flag Nonzero to let a stinking cloud act.) }
procedure ConsiderTerrainEffects(creature: Types.PCreature; flag: Byte);

{ Rolls an attack that has no attacking creature: a d20 kept in GDVars.attackRoll, where 1 always misses and 20 counts
  as 100, adjusted by the defender's condition-16 effects.
  @param(defender Creature attacked.)
  @param(sixtyMinusThac0 The attack's to-hit value, 60 minus its THAC0.)
  @returns(True when the adjusted roll is not negative and the roll plus sixtyMinusThac0 exceeds defender's acCur.) }
function AttackRollNoAttacker(defender: Types.PCreature; sixtyMinusThac0: Byte): Boolean;

{ Rolls attacker's attack on defender. Makes attacker visible, rolls a d20 into GDVars.attackRoll (1 always misses, 20
  counts as 100), runs attacker's condition-10 and defender's condition-16 effects, and adds the side's to-hit modifier:
  the low byte of script variable C_Gbvm.PARTY_THAC0_MODIFIER for an attacker on the party's side, of
  C_Gbvm.MONSTER_THAC0_MODIFIER otherwise.
  @param(attacker Creature attacking.)
  @param(defender Creature attacked.)
  @param(sixtyMinusAc Value the attack must reach, 60 minus defender's armor class.)
  @returns(True when the adjusted roll is not negative and the roll plus attacker's thac0Cur and the modifier reaches
    sixtyMinusAc.) }
function AttackRoll(attacker, defender: Types.PCreature; sixtyMinusAc: Byte): Boolean;

{ Rolls a creature's saving throw. A natural 1 fails and a natural 20 succeeds; otherwise the d20 plus the creature's
  saving throw bonus and the modifier, after the creature's condition-12 effects, must reach its save value for the
  category. The roll and the result are kept for later use, and so is the category when the roll is neither 1 nor 20.
  Note: the total is kept in a Byte, so a total below 0 wraps to a large value and succeeds.
  @param(creature Creature saving.)
  @param(saveType Saving throw category, an index into the creature's saves.)
  @param(modifier Added to the roll.)
  @returns(True when the save succeeds.) }
function RollSavingThrow(creature: Types.PCreature; saveType, modifier: ShortInt): Boolean;

{ Rolls count dice of sides faces each and adds them up.
  @param(count Number of dice; 0 rolls nothing.)
  @param(sides Faces per die.)
  @returns(The sum, kept in a Byte, so a total above 255 wraps.) }
function RollDice(count, sides: Byte): Byte;

{ Rolls count dice of sides faces each as damage dice, recording count in GDVars.damageDice.
  @param(count Number of dice.)
  @param(sides Faces per die.)
  @returns(The sum, as RollDice returns it.) }
function RollDamageDice(count, sides: Byte): Byte;

{ Adds an effect node to the end of a creature's effect list. It neither checks for a node already there nor calls the
  effect's handler.
  @param(creature The creature.)
  @param(effId The effect.)
  @param(minutes Its duration in minutes; 0 for a permanent effect.)
  @param(strength Its strength.)
  @param(onRemove True to call the effect's handler when it is removed.) }
procedure AddEffect(creature: Types.PCreature; effId: Byte; minutes: Word; strength: Byte; onRemove: Boolean);

{ Takes an enabled creature out of play: centers the map on it, prints a message after its name, disables it and sets
  its status. Its hit points drop to 0 unless it fled (running). Its icon is erased from the combat map and taken off
  the arena, and when its actions end the effects that end at 0 hit points are removed.
  @param(creature The creature.)
  @param(status Its new status.)
  @param(msg The message.) }
procedure PutOutOfPlayWithStatus(creature: Types.PCreature; status: Byte; msg: Types.TStr40);

{ Removes each invisibility node from a creature.
  @param(creature The creature.) }
procedure RemoveInvisibility(creature: Types.PCreature);

{ Removes one copy of each effect listed in GDConsts.deathEffects, the effects that end when a creature goes down. A
  creature that still has effect 77 afterwards and whose npc value is $B3 returns to the party's side.
  @param(creature Creature that went down.) }
procedure RemoveEffectsHp0(creature: Types.PCreature);

{ Removes one copy of each effect listed in GDConsts.combatAiEffects, the effects that end when combat AI control of a
  creature ends.
  @param(creature Creature released from AI control.) }
procedure RemoveAiEffects(creature: Types.PCreature);

{ Cures a creature of an effect: when it has the effect, prints that it is cured and removes the node.
  @param(creature The creature.)
  @param(effId The effect.)
  @returns(True when the creature had the effect.) }
function RemoveEffectWithMessage(creature: Types.PCreature; effId: Byte): Boolean;

{ Encodes a Strength as an effect strength: 18 with exceptional Strength excStr becomes excStr + 1 (1..101), any other
  base Strength becomes baseStr + 100.
  @param(baseStr Base Strength.)
  @param(excStr Exceptional Strength, read when baseStr is 18.)
  @returns(The encoded Strength.) }
function StrengthModifier(baseStr, excStr: Byte): Byte;

{ Decodes an effect's strength byte, bit 7 aside, into Strength: up to 101 is Strength 18 with exceptional Strength of
  the value less 1, above it Strength of the value less 100 with no exceptional Strength.
  @param(effect The Strength effect.)
  @param(baseStr Receives Strength.)
  @param(excStr Receives exceptional Strength.) }
procedure StrengthEffectToStrength(effect: Types.PEffect; var baseStr, excStr: Byte);

{ Tells whether a Strength beats a creature's permanent one: a higher base Strength, or 18 with an exceptional Strength
  above its permanent exceptional Strength.
  @param(creature Creature compared against.)
  @param(baseStr Candidate base Strength.)
  @param(excStr Candidate exceptional Strength.)
  @param(effStrength Receives the candidate's effect encoding when it is better; unchanged otherwise.)
  @returns(True when the candidate is better.) }
function AdjustForNewStrength(creature: Types.PCreature; baseStr, excStr: Byte; var effStrength: Byte): Boolean;

{ Deals damage that is not a weapon hit. creature's condition-6 effects adjust it first; then, when saved, saveReduction
  1 cancels it and 2 halves it, while without a save the condition-20 effects run. Damage left over is printed with its
  type and applied, and in combat it stops creature's casting and loses the spell it was casting. A creature this
  disables is reported as going down, dying or killed: outside combat the game pauses; in combat its 0-hit-point effects
  are removed, its condition-13 effects run and it is marked downed if it is still disabled. The status border is
  redrawn. The type comes from GDVars.elementMask: Fire, Cold, Electricity or Acid is named when it is the one type
  besides Magic, and "from Magic" is printed when Magic is the one type or no type is set.
  @param(creature Creature hurt.)
  @param(damage Damage before adjustment.)
  @param(saveReduction What a save does: 1 cancels the damage, 2 halves it, other values leave it.)
  @param(saved True when creature made its saving throw.) }
procedure InflictNonWeaponDamage(creature: Types.PCreature; damage, saveReduction: Byte; saved: Boolean);

{ Applies an effect to a creature unless its condition-9 effects block it or a save negates it; then "is Unaffected" is
  printed instead. The creature's first copy of the effect, when it has time left, is replaced. The message, when not
  empty, is printed.
  @param(creature Creature given the effect.)
  @param(effId Effect to add.)
  @param(minutes Duration.)
  @param(strength Effect strength, read by its handler.)
  @param(onRemove Set to call the effect's handler when it is removed.)
  @param(saveNegates True (1) when a successful save cancels the effect.)
  @param(saved Set when the creature made its saving throw.)
  @param(msg Message printed after its name, or empty.) }
procedure AddEffectWithMessage(creature: Types.PCreature; effId: Byte; minutes: Word; strength: Byte; onRemove,
                               saveNegates, saved: Boolean; msg: Types.TStr40);

{ Heals a creature that is okay, animated, unconscious or dying by hp hit points, capped at its maximum; with bypassRot
  set, a creature already at its maximum is left alone. A healed creature that is disabled goes from dying to
  unconscious, and an unconscious one outside combat has the handler of effect 78 called for it. Note: the sum of hpCur
  and hp is kept in a Byte, so a total above 255 wraps before the cap applies.
  @param(creature Creature healed.)
  @param(hp Hit points to restore.)
  @param(bypassRot True to leave a creature at its maximum unhealed.)
  @returns(True when it healed.) }
function RestoreHitPoints(creature: Types.PCreature; hp: Byte; bypassRot: Boolean): Boolean;

{ Stands a creature back up with the given hit points when its combat cell can hold it: its status becomes okay, it is
  enabled, the view is centered on it in combat, "stands up and grins" is printed for a hostile creature or "gets back
  up" otherwise, and the teams are recounted.
  @param(creature Creature revived.)
  @param(hp Hit points it gets back.)
  @returns(True when it revived.) }
function ReviveDeadCreature(creature: Types.PCreature; hp: Byte): Boolean;

{ Recomputes the current value of one ability of a creature from its permanent value, its equipped magic items and its
  effects. Items can raise or lower an ability or force it to 3 or 7. Strength keeps the best of the items, effect 146,
  Enlarge and the Strength effect, which adds its decoded Strength to a creature at 18/99 or less and turns each point
  above 18 into 10 exceptional points for a fighter, paladin or ranger (18 for other classes). Constitution recomputes
  the maximum hit points from the rolled hit points and the Constitution bonus of the class levels, moves the current
  hit points by the change, and keeps effect 62 on while it is 20 or more. Intelligence and Wisdom drop to 3 under
  Feeblemind unless an item forces 7 or 3, and Charisma adds the strength of effect 14.
  @param(cr Creature recalculated.)
  @param(ability Ability, a C_Stat index from STRENGTH to CHARISMA.) }
procedure RecalcAbility(cr: Types.PCreature; ability: ShortInt);

{ Calls the priming entries of CharHlp, ClassCal and the trace overlay, so the overlay manager loads those overlays. }
procedure PrimeFxEngine;

implementation

type

  TDirs = array[0..255] of Byte;

var
  { The stinking-cloud directions as FindCreatureAtCell reads them: from index 1 of a zero-based list, so the four
    entries it reads are east, southeast, south and the cell itself. }
  stinkingCloudList: TDirs absolute GDConsts.stinkingCloudDirections;

procedure PrimeFxEngine;
begin
  CharHlp.PrimeCharHlp;
  EclTrace.PrimeEclTrace;
  ClassCal.PrimeClassCal;
end;

procedure KillCreature(cr: Types.PCreature; status: Byte; msg: Types.TStr40);
begin
  CharHlp.PrintCreatureMessage(Pointer(cr), msg, 10, False);
  case Char(cr^.status) of
    { stoned, dead or gone }
    #7, #6, #8: ;
  else begin
    cr^.status := status;
    cr^.enabled := 0;
    cr^.hpCur := 0;
    FxEngine.RemoveEffectsHp0(cr);
    FxEngine.TriggerEffectsWithCondition(13, cr);
    if cr^.enabled = 0 then
      CbtMap.CreatureDowned(Pointer(cr));
    TextRend.PauseOnly;
    CharHlp.ClearMessageWindow;
    if GDVars.ifcState <> C_Ifc.IN_COMBAT then
      CharHlp.DisplayParty(GDVars.curChar);
  end;
  end;
end;

procedure CallEffectHandler(effId: Byte; creature: Types.PCreature; effectNode: Pointer; removed: Boolean);
begin
  if GDVars.overrideFlag <> 0 then
    GDVars.overrideEffectHandler(creature, effectNode, removed)
  else
    GDVars.effectHandlers[effId](creature, effectNode, removed);
end;

procedure RemoveEffect(creature: Types.PCreature; effId: Byte; eff: Pointer);
var
  prev: Types.PEffect;
  p: Types.PEffect;
begin
  p := eff;
  if p = nil then begin
    p := creature^.effects;
    while (p <> nil) and (p^.id <> effId) do
      p := p^.next;
  end;
  if p = nil then Exit;
  if p^.onRemove then
    FxEngine.CallEffectHandler(effId, creature, p, True);
  if creature^.effects = p then
    creature^.effects := Types.PEffect(p^.next)
  else begin
    prev := creature^.effects;
    while (prev <> nil) and (prev^.next <> p) do
      prev := prev^.next;
    prev^.next := p^.next;
  end;
  FreeMem(p, SizeOf(p^));
  if effId = 14 then
    FxEngine.RecalcAbility(creature, C_Stat.CHARISMA);
  if (effId = C_Effect.ENLARGE) or (effId = C_Effect.STRENGTH) or (effId = 146) then
    FxEngine.RecalcAbility(creature, C_Stat.STRENGTH);
end;

{ Fires one effect on a creature: calls its handler when the creature has the effect, or, for the aura effects Silence
  15', Protection from Evil 10', Protection from Good 10' and Prayer, when a creature carrying it has this one in range
  (6 cells for Prayer, else 1; outside combat any carrier counts). The handler gets the node found: the creature's own,
  or the carrier's for an aura. The range test builds a target list, and the caller's target list is kept around it.
  @param(creature The creature.)
  @param(effId The effect.) }
procedure TriggerEffect(creature: Types.PCreature; effId: Byte);
var
  { copy of the target list, which BuildTargetList overwrites }
  savedList: array[0..215] of Byte;
  p: Types.PCreature;
  eff: Types.PEffect;
  found: Boolean;
  i: Byte;
  range: Byte;
begin
  found := False;
  p := GDVars.partyHead;
  if CharHlp.HasEffect(Pointer(creature), effId, eff) then
    found := True
  else if effId in [21, 45, 46, 49] then begin
    Move(GDVars.targetList[1], savedList, SizeOf(savedList));
    while (p <> nil) and not found do begin
      if CharHlp.HasEffect(Pointer(p), effId, eff) then begin
        if GDVars.ifcState = C_Ifc.IN_COMBAT then begin
          if effId = 49 then range := 6 else range := 1;
          Pathing.BuildTargetList(CbtMap.CombatCellX(Pointer(p)), CbtMap.CombatCellY(Pointer(p)), range, 255,
                                  CbtMap.GetIconSize(Pointer(p)), GDVars.combatArena);
          for i := 1 to GDVars.targetCount do
            if GDVars.targetList[i].idx = CbtMap.CombatSlot(Pointer(creature)) then
              found := True;
        end else
          found := True;
      end;
      p := p^.next;
    end;
    Move(savedList, GDVars.targetList[1], SizeOf(savedList));
  end;
  if found then
    FxEngine.CallEffectHandler(effId, creature, eff, False);
end;

procedure TriggerEffectsWithCondition(cond: Byte; creature: Types.PCreature);
var
  { Unused in this version; see the other implementations of this routine. }
  eff: Pointer;
begin
  case cond of
    0: ;
    1: begin
          FxEngine.TriggerEffect(creature, 37); FxEngine.TriggerEffect(creature, C_Effect.INVISIBLE);
          FxEngine.TriggerEffect(creature, 71);
          FxEngine.TriggerEffect(creature, 69);
        end;
    2: begin
          FxEngine.TriggerEffect(creature, 79); FxEngine.TriggerEffect(creature, 80);
          FxEngine.TriggerEffect(creature, 145);
          FxEngine.TriggerEffect(creature, 57); FxEngine.TriggerEffect(creature, 96);
          FxEngine.TriggerEffect(creature, 122);
          FxEngine.TriggerEffect(creature, 123);
        end;
    3: begin
          FxEngine.TriggerEffect(creature, 64); FxEngine.TriggerEffect(creature, 65);
          FxEngine.TriggerEffect(creature, 66);
          FxEngine.TriggerEffect(creature, 67); FxEngine.TriggerEffect(creature, 70);
          FxEngine.TriggerEffect(creature, 79);
          FxEngine.TriggerEffect(creature, 87);
        end;
    4: begin
          FxEngine.TriggerEffect(creature, 29); FxEngine.TriggerEffect(creature, 6);
          FxEngine.TriggerEffect(creature, 103);
          FxEngine.TriggerEffect(creature, 75); FxEngine.TriggerEffect(creature, 76);
          FxEngine.TriggerEffect(creature, C_Effect.RANGER_DAMAGE_BONUS);
        end;
    5: begin
          FxEngine.TriggerEffect(creature, C_Effect.MIRROR_IMAGE); FxEngine.TriggerEffect(creature, 41);
          FxEngine.TriggerEffect(creature, 104);
          FxEngine.TriggerEffect(creature, 120); FxEngine.TriggerEffect(creature, 101);
          FxEngine.TriggerEffect(creature, 115);
          FxEngine.TriggerEffect(creature, 116); FxEngine.TriggerEffect(creature, 119);
          FxEngine.TriggerEffect(creature, 94);
          FxEngine.TriggerEffect(creature, 117); FxEngine.TriggerEffect(creature, 60);
          FxEngine.TriggerEffect(creature, 81);
          FxEngine.TriggerEffect(creature, 82); FxEngine.TriggerEffect(creature, 85);
          FxEngine.TriggerEffect(creature, 130);
          FxEngine.TriggerEffect(creature, 143);
        end;
    6: begin
          FxEngine.TriggerEffect(creature, 113); FxEngine.TriggerEffect(creature, 61);
          FxEngine.TriggerEffect(creature, 10);
          FxEngine.TriggerEffect(creature, 20); FxEngine.TriggerEffect(creature, 105);
          FxEngine.TriggerEffect(creature, 106);
          FxEngine.TriggerEffect(creature, 112); FxEngine.TriggerEffect(creature, 114);
          FxEngine.TriggerEffect(creature, 118);
          FxEngine.TriggerEffect(creature, 17); FxEngine.TriggerEffect(creature, 93);
          FxEngine.TriggerEffect(creature, 101);
          FxEngine.TriggerEffect(creature, C_Effect.MIRROR_IMAGE); FxEngine.TriggerEffect(creature, 110);
          FxEngine.TriggerEffect(creature, 73);
          FxEngine.TriggerEffect(creature, 82); FxEngine.TriggerEffect(creature, 84);
          FxEngine.TriggerEffect(creature, 129);
          FxEngine.TriggerEffect(creature, 133); FxEngine.TriggerEffect(creature, 135);
          FxEngine.TriggerEffect(creature, 63);
        end;
    7: begin
          FxEngine.TriggerEffect(creature, 51); FxEngine.TriggerEffect(creature, C_Effect.PARALYZED);
          FxEngine.TriggerEffect(creature, C_Effect.SLEEP);
          FxEngine.TriggerEffect(creature, C_Effect.HELPLESS); FxEngine.TriggerEffect(creature, 3);
          FxEngine.TriggerEffect(creature, 27);
          FxEngine.TriggerEffect(creature, 136);
        end;
    8: begin
          FxEngine.TriggerEffect(creature, 99); FxEngine.TriggerEffect(creature, 82);
          FxEngine.TriggerEffect(creature, 89);
          FxEngine.TriggerEffect(creature, 72); FxEngine.TriggerEffect(creature, 56);
        end;
    9: begin
          FxEngine.TriggerEffect(creature, 105); FxEngine.TriggerEffect(creature, 106);
          FxEngine.TriggerEffect(creature, C_Effect.ELF_RESISTANCE);
          FxEngine.TriggerEffect(creature, 108); FxEngine.TriggerEffect(creature, 109);
          FxEngine.TriggerEffect(creature, 110);
          FxEngine.TriggerEffect(creature, 111); FxEngine.TriggerEffect(creature, 112);
          FxEngine.TriggerEffect(creature, C_Effect.HALF_ELF_RESISTANCE);
          FxEngine.TriggerEffect(creature, 125); FxEngine.TriggerEffect(creature, 63);
          FxEngine.TriggerEffect(creature, 129);
        end;
    10: begin
          FxEngine.TriggerEffect(creature, 1); FxEngine.TriggerEffect(creature, 2);
          FxEngine.TriggerEffect(creature, C_Effect.BLIND);
          FxEngine.TriggerEffect(creature, C_Effect.BESTOW_CURSE); FxEngine.TriggerEffect(creature, 49);
          FxEngine.TriggerEffect(creature, 6);
          FxEngine.TriggerEffect(creature, C_Effect.GNOME_ATTACK_BONUS);
          FxEngine.TriggerEffect(creature, C_Effect.DWARF_ATTACK_BONUS);
          FxEngine.TriggerEffect(creature, 75);
          FxEngine.TriggerEffect(creature, 76);
        end;
    11: begin
          FxEngine.TriggerEffect(creature, C_Effect.BLIND); FxEngine.TriggerEffect(creature, 17);
          FxEngine.TriggerEffect(creature, C_Effect.PROTECTION_FROM_EVIL);
          FxEngine.TriggerEffect(creature, 9); FxEngine.TriggerEffect(creature, 45);
          FxEngine.TriggerEffect(creature, 46);
          FxEngine.TriggerEffect(creature, C_Effect.STINKING_CLOUD_COUGH); FxEngine.TriggerEffect(creature, 7);
        end;
    12: begin
          FxEngine.TriggerEffect(creature, C_Effect.PROTECTION_FROM_EVIL); FxEngine.TriggerEffect(creature, 9);
          FxEngine.TriggerEffect(creature, 10);
          FxEngine.TriggerEffect(creature, 17); FxEngine.TriggerEffect(creature, 20);
          FxEngine.TriggerEffect(creature, C_Effect.BLIND);
          FxEngine.TriggerEffect(creature, C_Effect.BESTOW_CURSE); FxEngine.TriggerEffect(creature, 45);
          FxEngine.TriggerEffect(creature, 46);
          FxEngine.TriggerEffect(creature, 49); FxEngine.TriggerEffect(creature, 61);
          FxEngine.TriggerEffect(creature, 111);
          FxEngine.TriggerEffect(creature, 125); FxEngine.TriggerEffect(creature, C_Effect.CONSTITUTION_SAVE_BONUS);
          FxEngine.TriggerEffect(creature, 50);
          FxEngine.TriggerEffect(creature, 54);
        end;
    13: begin
          FxEngine.TriggerEffect(creature, 99); FxEngine.TriggerEffect(creature, 100);
          FxEngine.TriggerEffect(creature, 75);
        end;
    14: begin
          FxEngine.TriggerEffect(creature, 83); FxEngine.TriggerEffect(creature, 88);
          FxEngine.TriggerEffect(creature, 121);
          FxEngine.TriggerEffect(creature, 86); FxEngine.TriggerEffect(creature, 87);
          FxEngine.TriggerEffect(creature, 90);
          FxEngine.TriggerEffect(creature, 126); FxEngine.TriggerEffect(creature, 128);
          FxEngine.TriggerEffect(creature, 131);
          FxEngine.TriggerEffect(creature, 132); FxEngine.TriggerEffect(creature, 139);
        end;
    15: begin
          FxEngine.TriggerEffect(creature, 21); FxEngine.TriggerEffect(creature, C_Effect.STINKING_CLOUD_COUGH);
          FxEngine.TriggerEffect(creature, C_Effect.CHARM);
          FxEngine.TriggerEffect(creature, 13); FxEngine.TriggerEffect(creature, 77);
        end;
    16: begin
          FxEngine.TriggerEffect(creature, C_Effect.INVISIBLE); FxEngine.TriggerEffect(creature, 71);
          FxEngine.TriggerEffect(creature, 37);
          FxEngine.TriggerEffect(creature, C_Effect.DWARF_GIANT_DEFENSE);
          FxEngine.TriggerEffect(creature, C_Effect.GNOME_BUGBEAR_DEFENSE);
          FxEngine.TriggerEffect(creature, 89);
          FxEngine.TriggerEffect(creature, 4);
        end;
    17: begin
          FxEngine.TriggerEffect(creature, 1); FxEngine.TriggerEffect(creature, 2);
          FxEngine.TriggerEffect(creature, C_Effect.CHARM);
        end;
    18: begin
          FxEngine.TriggerEffect(creature, C_Effect.HASTED); FxEngine.TriggerEffect(creature, C_Effect.SLOWED);
          FxEngine.TriggerEffect(creature, C_Effect.IMMOBILE);
        end;
    19: begin
          FxEngine.TriggerEffect(creature, 98); FxEngine.TriggerEffect(creature, C_Effect.SPIRITUAL_HAMMER);
          FxEngine.TriggerEffect(creature, 72);
          FxEngine.TriggerEffect(creature, 56); FxEngine.TriggerEffect(creature, C_Effect.CHARM);
        end;
    20: begin
          FxEngine.TriggerEffect(creature, 50); FxEngine.TriggerEffect(creature, 54);
        end;
    21: begin
          FxEngine.TriggerEffect(creature, 35);
        end;
    22: begin
          FxEngine.TriggerEffect(creature, 138);
        end;
    23: begin
          FxEngine.TriggerEffect(creature, 74);
        end;
  end;
end;

{ Finds the caster of the cloud covering a combat cell. Note: the direction table is read from index 1 against a table
  that starts at index 0, so with four cells per cloud the last cell checked comes from the byte after the table.
  @param(x Column of the cell.)
  @param(y Row of the cell.)
  @param(start First cloud node to check.)
  @param(count Number of cells checked per cloud.)
  @param(tbl Directions from a cloud's corner to its cells, read from index 1.)
  @returns(The caster of the first cloud, from the given node on, that has one of its checked cells live at the cell;
    the head of the creature list when there is none.) }
function FindCreatureAtCell(x, y: ShortInt; start: Types.PCloudNode; count: Byte; var tbl: TDirs): Types.PCreature;
var
  p: Types.PCloudNode;
  found: Boolean;
  i: Byte;
begin
  p := start;
  found := False;
  while (p <> nil) and not found do begin
    for i := 1 to count do
      if p^.exists[i] <> 0 then
        if (p^.ulX + GDConsts.directionDx[tbl[i]] = x) and (p^.ulY + GDConsts.directionDy[tbl[i]] = y) then
          found := True;
    if not found then
      p := p^.next;
  end;
  if found then
    FindCreatureAtCell := p^.caster
  else
    FindCreatureAtCell := GDVars.partyHead;
end;

procedure ConsiderTerrainEffects(creature: Types.PCreature; flag: Byte);
type
  TTerr = (tt0, tt1, tt2, tt3, tt4, tt5, tt6, tt7);
var
  terrIdx: Byte;
  crIdx: Byte;
  eff: Types.PEffect;
  coughEff: Types.PEffect;
  saved: Boolean;
  adjStink: Byte;
  adjCloudkill: Byte;
  savedTargets: Types.PCreature;
begin
  if creature^.enabled = 0 then Exit;
  CbtMap.ProbeDirection(Pointer(creature), 8, crIdx, terrIdx, adjStink, adjCloudkill);
  if adjStink <> 0 then
    if flag <> 0 then
      if not CharHlp.HasEffect(Pointer(creature), C_Effect.HELPLESS, eff) then
        if not CharHlp.HasEffect(Pointer(creature), C_Effect.ANIMATE_DEAD, eff) then
          if not CharHlp.HasEffect(Pointer(creature), 111, eff) then
            if not CharHlp.HasEffect(Pointer(creature), 125, eff) then begin
              saved := FxEngine.RollSavingThrow(creature, 0, 0);
              if saved then begin
                savedTargets := GDVars.curChar;
                GDVars.curChar := FxEngine.FindCreatureAtCell(CbtMap.CombatCellX(Pointer(creature)),
                                                             CbtMap.CombatCellY(Pointer(creature)), GDVars.stinkHead, 4,
                                                             stinkingCloudList);
                FxEngine.AddEffectWithMessage(creature, C_Effect.STINKING_CLOUD_COUGH, 1, 255, False, False, saved,
                                              'starts to cough');
                coughEff := nil;
                if CharHlp.HasEffect(Pointer(creature), C_Effect.STINKING_CLOUD_COUGH, coughEff) then
                  FxEngine.CallEffectHandler(C_Effect.STINKING_CLOUD_COUGH, creature, eff, False);
                GDVars.curChar := savedTargets;
              end else begin
                savedTargets := GDVars.curChar;
                GDVars.curChar := FxEngine.FindCreatureAtCell(CbtMap.CombatCellX(Pointer(creature)),
                                                             CbtMap.CombatCellY(Pointer(creature)), GDVars.stinkHead, 4,
                                                             stinkingCloudList);
                FxEngine.AddEffectWithMessage(creature, C_Effect.HELPLESS, FxEngine.RollDice(1, 4) + 1, 255, False,
                                              False, saved, 'chokes and gags from nausea');
                if CharHlp.HasEffect(Pointer(creature), C_Effect.HELPLESS, eff) then
                  FxEngine.CallEffectHandler(C_Effect.HELPLESS, creature, eff, False);
                GDVars.curChar := savedTargets;
              end;
            end;
  if adjCloudkill <> 0 then
    if creature^.enabled <> 0 then
      case TTerr(creature^.levelHighest) of
        tt0..tt4: begin
                CharHlp.PrintCreatureMessage(Pointer(creature), 'is Poisoned', 10, False);
                TextRend.PauseOnly;
                FxEngine.AddEffect(creature, C_Effect.POISONED, 0, 255, False);
                FxEngine.KillCreature(creature, C_Status.DEAD_STATUS, 'is killed');
              end;
        tt5: if not FxEngine.RollSavingThrow(creature, 0, -4) then begin
                CharHlp.PrintCreatureMessage(Pointer(creature), 'is Poisoned', 10, False);
                TextRend.PauseOnly;
                FxEngine.AddEffect(creature, C_Effect.POISONED, 0, 255, False);
                FxEngine.KillCreature(creature, C_Status.DEAD_STATUS, 'is killed');
              end;
        tt6: if not FxEngine.RollSavingThrow(creature, 0, 0) then begin
                CharHlp.PrintCreatureMessage(Pointer(creature), 'is Poisoned', 10, False);
                TextRend.PauseOnly;
                FxEngine.AddEffect(creature, C_Effect.POISONED, 0, 255, False);
                FxEngine.KillCreature(creature, C_Status.DEAD_STATUS, 'is killed');
              end;
      end;
end;

function AttackRollNoAttacker(defender: Types.PCreature; sixtyMinusThac0: Byte): Boolean;
begin
  AttackRollNoAttacker := False;
  GDVars.attackRoll := FxEngine.RollDice(1, 20);
  if GDVars.attackRoll > 1 then begin
    if GDVars.attackRoll = 20 then GDVars.attackRoll := 100;
    FxEngine.TriggerEffectsWithCondition(16, defender);
    if (GDVars.attackRoll >= 0) and (GDVars.attackRoll + sixtyMinusThac0 > defender^.acCur[0]) then
      AttackRollNoAttacker := True;
  end;
end;

function AttackRoll(attacker, defender: Types.PCreature; sixtyMinusAc: Byte): Boolean;
var
  zmod: ShortInt;
begin
  AttackRoll := False;
  FxEngine.RemoveInvisibility(attacker);
  GDVars.attackRoll := FxEngine.RollDice(1, 20);
  if GDVars.attackRoll > 1 then begin
    if GDVars.attackRoll = 20 then GDVars.attackRoll := 100;
    FxEngine.TriggerEffectsWithCondition(10, attacker);
    FxEngine.TriggerEffectsWithCondition(16, defender);
    if attacker^.hostile = 0 then
      zmod := Lo(GDVars.zone1^[C_Gbvm.PARTY_THAC0_MODIFIER])
    else
      zmod := Lo(GDVars.zone1^[C_Gbvm.MONSTER_THAC0_MODIFIER]);
    if (GDVars.attackRoll >= 0) and (GDVars.attackRoll + attacker^.thac0Cur + zmod >= sixtyMinusAc) then
      AttackRoll := True;
  end;
end;

function RollSavingThrow(creature: Types.PCreature; saveType, modifier: ShortInt): Boolean;
begin
  GDVars.saveResult := True;
  GDVars.saveRoll := FxEngine.RollDice(1, 20);
  case GDVars.saveRoll of
    1: GDVars.saveResult := False;
    20: GDVars.saveResult := True;
  else begin
    GDVars.saveRoll := GDVars.saveRoll + creature^.saveBonus + modifier;
    GDVars.saveType := saveType;
    FxEngine.TriggerEffectsWithCondition(12, creature);
    if creature^.saves[saveType] <= GDVars.saveRoll then
      GDVars.saveResult := True
    else
      GDVars.saveResult := False;
  end;
  end;
  RollSavingThrow := GDVars.saveResult;
end;

function RollDice(count, sides: Byte): Byte;
var
  i: Byte;
  total: Byte;
begin
  total := 0;
  if count > 0 then
    for i := 1 to count do
      Inc(total, Random(sides) + 1);
  RollDice := total;
end;

function RollDamageDice(count, sides: Byte): Byte;
begin
  GDVars.damageDice := count;
  RollDamageDice := FxEngine.RollDice(count, sides);
end;

procedure AddEffect(creature: Types.PCreature; effId: Byte; minutes: Word; strength: Byte; onRemove: Boolean);
var
  p: Types.PEffect;
  q: Types.PEffect;
begin
  GetMem(p, SizeOf(p^));
  if creature^.effects = nil then
    creature^.effects := p
  else begin
    q := creature^.effects;
    while q^.next <> nil do
      q := q^.next;
    q^.next := p;
  end;
  p^.next := nil;
  p^.id := effId;
  p^.duration := minutes;
  p^.onRemove := onRemove;
  p^.strength := strength;
end;

procedure PutOutOfPlayWithStatus(creature: Types.PCreature; status: Byte; msg: Types.TStr40);
var
  slot: Byte;
begin
  if creature^.enabled = 0 then Exit;
  slot := CbtMap.CombatSlot(Pointer(creature));
  CbtMap.DisplayMapViewCentered(Pointer(creature), 3, False);
  CharHlp.PrintCreatureMessage(Pointer(creature), msg, 10, True);
  creature^.enabled := 0;
  creature^.status := status;
  if creature^.status <> C_Status.RUNNING then
    creature^.hpCur := 0;
  CbtMap.UpdateCombatMapTile(0, 0, slot);
  Blit.FlushView;
  GDVars.arenaSlots[slot].size := 0;
  CbtMap.BuildArenaArrays;
  if CharHlp.EndActions(Pointer(creature)) then
    FxEngine.RemoveEffectsHp0(creature);
end;

procedure RemoveInvisibility(creature: Types.PCreature);
var
  eff: Types.PEffect;
begin
  while CharHlp.HasEffect(Pointer(creature), C_Effect.INVISIBLE, eff) do
    FxEngine.RemoveEffect(creature, C_Effect.INVISIBLE, eff);
end;

procedure RemoveEffectsHp0(creature: Types.PCreature);
var
  i: Byte;
  eff: Types.PEffect;
begin
  for i := 1 to 19 do
    FxEngine.RemoveEffect(creature, GDConsts.deathEffects[i], nil);
  if CharHlp.HasEffect(Pointer(creature), 77, eff) then
    if creature^.npc = $B3 then
      creature^.hostile := 0;
end;

procedure RemoveAiEffects(creature: Types.PCreature);
var
  i: Byte;
begin
  for i := 1 to 4 do
    FxEngine.RemoveEffect(creature, GDConsts.combatAiEffects[i], nil);
end;

function RemoveEffectWithMessage(creature: Types.PCreature; effId: Byte): Boolean;
var
  eff: Types.PEffect;
begin
  RemoveEffectWithMessage := False;
  if CharHlp.HasEffect(Pointer(creature), effId, eff) then begin
    CharHlp.PrintCreatureMessage(Pointer(creature), 'is Cured', 10, True);
    FxEngine.RemoveEffect(creature, effId, eff);
    RemoveEffectWithMessage := True;
  end;
end;

function StrengthModifier(baseStr, excStr: Byte): Byte;
begin
  StrengthModifier := baseStr + 100;
  if baseStr = 18 then
    StrengthModifier := excStr + 1;
end;

procedure StrengthEffectToStrength(effect: Types.PEffect; var baseStr, excStr: Byte);
begin
  excStr := 0;
  baseStr := effect^.strength and $7F;
  if baseStr <= 101 then begin
    excStr := baseStr - 1;
    baseStr := 18;
  end else
    baseStr := baseStr - 100;
end;

function AdjustForNewStrength(creature: Types.PCreature; baseStr, excStr: Byte; var effStrength: Byte): Boolean;
var
  { Unused in this version; see the other implementations of this routine. }
  p: Types.PEffect;
  { Unused in this version; see the other implementations of this routine. }
  found: Types.PEffect;
  { Unused in this version; see the other implementations of this routine. }
  oldBase: Byte;
  { Unused in this version; see the other implementations of this routine. }
  oldExc: Byte;
begin
  if (baseStr > creature^.stats[C_Stat.STRENGTH].permanent)
      or ((baseStr = 18) and (excStr > creature^.exStrBase)) then begin
    AdjustForNewStrength := True;
    effStrength := FxEngine.StrengthModifier(baseStr, excStr);
  end else
    AdjustForNewStrength := False;
end;

procedure RecalcAbility(cr: Types.PCreature; ability: ShortInt);
var
  statVal: Byte;
  baseStr: Byte;
  strExc: Byte;
  excStr: Byte;
  eff: Types.PEffect;
  hpSave: Byte;
  accum: Byte;
  tmp: Byte;
  i: ShortInt;
  p: Types.PItem;
  statOverride: Byte;
  enc: Byte;
  count: Byte;

  { Raises the strength being built to the candidate when higher, comparing exceptional strength only at 18. }
  procedure StrClamp;
  begin
    if (baseStr > statVal) or ((baseStr = 18) and (excStr > strExc)) then begin
      statVal := baseStr;
      strExc := excStr;
    end;
  end;

  { Adds to accum the Constitution hit-point bonus of statVal for levels of class cls, held below the class's cap. }
  procedure StatBonus(cls: ShortInt; levels: Byte);
  begin
    if GDConsts.constitutionBonusLevelCaps[cls] <= levels then
      levels := GDConsts.constitutionBonusLevelCaps[cls] - 1;
    if cls = C_Class.RANGER_LEVEL then
      if (cr^.levelAtChange = 0) or
          (Byte(cr^.oldClassLevels[C_Class.RANGER_LEVEL]) = Byte(cr^.levelAtChange)) then
        Inc(levels);
    if (cls = C_Class.FIGHTER_LEVEL) or (cls = C_Class.RANGER_LEVEL) or (cls = C_Class.PALADIN_LEVEL) then begin
      case statVal of
        15..19: Inc(accum, (statVal - 14) * levels);
        20: Inc(accum, levels * 5);
        21..23: Inc(accum, levels * 6);
        24..25: Inc(accum, levels * 7);
      end;
    end else begin
      if statVal > 15 then
        Inc(accum, levels * 2)
      else if statVal = 15 then
        Inc(accum, levels);
    end;
  end;

begin
  accum := 0;
  baseStr := 0;
  excStr := 0;
  statOverride := 255;
  p := cr^.itemsAddr;
  statVal := cr^.stats[ability].permanent;
  strExc := cr^.exStrBase;
  { Scan items and accumulate stat modifiers. }
  while p <> nil do begin
    if (p^.special > $80) and (p^.equipped <> 0) then begin
      enc := p^.special and $7F;
      case Char(ability) of
        #0: begin
             case enc of
               5: case p^.effect of
                    0: begin baseStr := 18; excStr := 100; end;
                    1: baseStr := 19;
                    2: baseStr := 20;
                    3: baseStr := 21;
                    4: baseStr := 22;
                    5: baseStr := 23;
                    6: baseStr := 24;
                  end;
               8: if (cr^.stats[C_Stat.STRENGTH].permanent < 18) and (p^.effect = C_Stat.STRENGTH) then begin
                    baseStr := cr^.stats[C_Stat.STRENGTH].permanent + 1;
                    excStr := 0;
                  end;
               13: statOverride := 3;
             end;
             StrClamp;
           end;
        #4: begin
             if enc = 6 then Inc(statVal)
             else if enc = 8 then
               if (cr^.stats[C_Stat.CONSTITUTION].permanent < 18)
                   and (p^.effect = C_Stat.CONSTITUTION) then Inc(statVal);
           end;
        #1: begin
             case enc of
               8: if (cr^.stats[C_Stat.INTELLIGENCE].permanent < 18) and
                      (p^.effect = C_Stat.INTELLIGENCE) then Inc(statVal);
               12: statOverride := 7;
               13: statOverride := 3;
             end;
           end;
        #2: if enc = 8 then
             if (p^.effect = C_Stat.WISDOM) and (cr^.stats[C_Stat.WISDOM].permanent < 18) then Inc(statVal);
        #3: begin
             case enc of
               2: case cr^.stats[C_Stat.DEXTERITY].permanent of
                    0..6: Inc(statVal, 4);
                    7..13: Inc(statVal, 2);
                  else Inc(statVal);
                  end;
               8: if (cr^.stats[C_Stat.DEXTERITY].permanent < 18)
                      and (p^.effect = C_Stat.DEXTERITY) then Inc(statVal);
               10: Dec(statVal, 2);
             end;
           end;
        #5: begin
             case enc of
               6: Dec(statVal);
               8: if (cr^.stats[C_Stat.CHARISMA].permanent < 18) and (p^.effect = C_Stat.CHARISMA) then Inc(statVal);
             end;
           end;
      end;
    end;
    p := p^.next;
  end;
  case Char(ability) of
    #0: begin
         if CharHlp.HasEffect(Pointer(cr), C_Effect.STRENGTH, eff) then begin
           FxEngine.StrengthEffectToStrength(eff, baseStr, excStr);
           if (statVal <= 18) and (strExc < 100) then begin
             baseStr := statVal + baseStr;
             if baseStr > 18 then begin
               if (cr^.classLevels[C_Class.FIGHTER_LEVEL] > 0) or
                   (cr^.oldClassLevels[C_Class.FIGHTER_LEVEL] > 0) or
                   (cr^.classLevels[C_Class.PALADIN_LEVEL] > 0) or
                       (cr^.oldClassLevels[C_Class.PALADIN_LEVEL] > 0) or
                   (cr^.classLevels[C_Class.RANGER_LEVEL] > 0) or
                       (cr^.oldClassLevels[C_Class.RANGER_LEVEL] > 0) then begin
                 excStr := cr^.exStrCur + (baseStr - 18) * 10;
                 if excStr > 100 then excStr := 100;
                 baseStr := 18;
               end else
                 baseStr := 18;
             end;
           end;
           StrClamp;
         end;
         if CharHlp.HasEffect(Pointer(cr), 146, eff) then begin
           FxEngine.StrengthEffectToStrength(eff, baseStr, excStr);
           StrClamp;
         end;
         if CharHlp.HasEffect(Pointer(cr), C_Effect.ENLARGE, eff) then begin
           FxEngine.StrengthEffectToStrength(eff, baseStr, excStr);
           StrClamp;
         end;
         if statOverride <> 255 then begin
           cr^.stats[C_Stat.STRENGTH].current := statOverride;
           cr^.exStrCur := 0;
         end else begin
           cr^.stats[C_Stat.STRENGTH].current := statVal;
           cr^.exStrCur := strExc;
         end;
       end;
    #4: begin
         count := 0;
         hpSave := cr^.hpMax;
         cr^.hpMax := cr^.hpRolled;
         for i := 0 to 7 do begin
           tmp := cr^.oldClassLevels[i];
           if tmp > 0 then StatBonus(i, tmp);
           tmp := cr^.classLevels[i];
           if tmp > 0 then Inc(count);
           if GDConsts.constitutionBonusLevelCaps[i] < tmp then tmp := GDConsts.constitutionBonusLevelCaps[i];
           if tmp > Byte(cr^.levelAtChange) then begin
             Dec(tmp, cr^.levelAtChange);
             StatBonus(i, tmp);
           end;
         end;
         accum := accum div count;
         Inc(cr^.hpMax, accum);
         if cr^.hpMax > hpSave then
           Inc(cr^.hpCur, cr^.hpMax - hpSave);
         if cr^.hpMax < hpSave then begin
           if cr^.hpCur > hpSave - cr^.hpMax then
             Dec(cr^.hpCur, hpSave - cr^.hpMax)
           else
             cr^.hpCur := 0;
         end;
         cr^.stats[C_Stat.CONSTITUTION].current := statVal;
         if cr^.stats[C_Stat.CONSTITUTION].current >= 20 then begin
           if not CharHlp.HasEffect(Pointer(cr), 62, eff) then
             FxEngine.AddEffect(cr, 62, 60, 255, True);
         end else
           FxEngine.RemoveEffect(cr, 62, nil);
       end;
    #1: begin
         if CharHlp.HasEffect(Pointer(cr), 68, eff) then
           if statOverride > 7 then statOverride := 3;
         if statOverride <> 255 then
           cr^.stats[C_Stat.INTELLIGENCE].current := statOverride
         else
           cr^.stats[C_Stat.INTELLIGENCE].current := statVal;
       end;
    #2: begin
         if CharHlp.HasEffect(Pointer(cr), 68, eff) then
           if statOverride > 7 then statOverride := 3;
         if statOverride <> 255 then
           cr^.stats[C_Stat.WISDOM].current := statOverride
         else
           cr^.stats[C_Stat.WISDOM].current := statVal;
       end;
    #3: if statOverride <> 255 then
         cr^.stats[C_Stat.DEXTERITY].current := statOverride
       else
         cr^.stats[C_Stat.DEXTERITY].current := statVal;
    #5: begin
         if CharHlp.HasEffect(Pointer(cr), 14, eff) then
           Inc(statVal, eff^.strength);
         cr^.stats[C_Stat.CHARISMA].current := statVal;
       end;
  end;
end;

procedure InflictNonWeaponDamage(creature: Types.PCreature; damage, saveReduction: Byte; saved: Boolean);
var
  s: String;
begin
  GDVars.damage := damage;
  FxEngine.TriggerEffectsWithCondition(6, creature);
  if saved then
    case Char(saveReduction) of
      #1: GDVars.damage := 0;
      #2: GDVars.damage := GDVars.damage div 2;
    end else
    FxEngine.TriggerEffectsWithCondition(20, creature);
  if GDVars.damage > 0 then begin
    if GDVars.damage <> 1 then
      s := 'takes ' + CharHlp.Uint8Str(GDVars.damage) + ' points of damage '
    else
      s := 'takes 1 point of damage ';
    case GDVars.elementMask and $F7 of
      1: s := s + 'from Fire';
      2: s := s + 'from Cold';
      4: s := s + 'from Electricity';
      16: s := s + 'from Acid';
    end;
    if (GDVars.elementMask and 8) = GDVars.elementMask then
      s := s + 'from Magic';
    CharHlp.PrintNameStringAnim(Pointer(creature), False, s);
    CharHlp.InflictDamage(Pointer(creature), GDVars.damage);
    if GDVars.ifcState = C_Ifc.IN_COMBAT then begin
      creature^.combatAddr^.castAllowed := 0;
      if creature^.combatAddr^.spellCast > 0 then begin
        CharHlp.PrintCreatureMessage(Pointer(creature), 'lost a spell', 12, True);
        CharHlp.RemoveSpell(creature, creature^.combatAddr^.spellCast);
        creature^.combatAddr^.spellCast := 0;
      end;
    end;
    if creature^.enabled = 0 then begin
      s := 'Goes Down';
      if creature^.status = C_Status.DYING then
        s := s + ', and is Dying';
      if creature^.status in [C_Status.DEAD_STATUS, C_Status.STONED, C_Status.GONE] then
        s := 'is killed';
      CharHlp.PrintCreatureMessage(Pointer(creature), s, GDVars.curRow + 1, False);
      if GDVars.ifcState <> C_Ifc.IN_COMBAT then
        TextRend.PauseOnly
      else begin
        FxEngine.RemoveEffectsHp0(creature);
        FxEngine.TriggerEffectsWithCondition(13, creature);
        if creature^.enabled = 0 then
          CbtMap.CreatureDowned(Pointer(creature))
        else
          TextRend.PauseOnly;
      end;
    end;
    CharHlp.ClearMessageWindow;
  end;
end;

procedure AddEffectWithMessage(creature: Types.PCreature; effId: Byte; minutes: Word; strength: Byte; onRemove,
                               saveNegates, saved: Boolean; msg: Types.TStr40);
var
  eff: Types.PEffect;
  { Unused in this version; see the other implementations of this routine. }
  oldEffect: Byte;
begin
  GDVars.effectCheck := effId;
  FxEngine.TriggerEffectsWithCondition(9, creature);
  if (GDVars.effectCheck = 0) or (saved and (saveNegates = True)) then
    CharHlp.PrintCreatureMessage(Pointer(creature), 'is Unaffected', 10, True)
  else begin
    if CharHlp.HasEffect(Pointer(creature), effId, eff) then
      if eff^.duration > 0 then
        FxEngine.RemoveEffect(creature, effId, eff);
    FxEngine.AddEffect(creature, effId, minutes, strength, onRemove);
    if msg[0] <> #0 then begin
      {$V-} CharHlp.PrintNameStringAnim(Pointer(creature), True, msg); {$V+}
      CharHlp.ClearMessageWindow;
    end;
  end;
end;

function RestoreHitPoints(creature: Types.PCreature; hp: Byte; bypassRot: Boolean): Boolean;
var
  { Unused in this version; see the other implementations of this routine. }
  eff: Pointer;
begin
  RestoreHitPoints := False;
  if not (creature^.status in [C_Status.OKAY, C_Status.ANIMATED, C_Status.UNCONSCIOUS,
                               C_Status.DYING]) then Exit;
  if ((creature^.hpCur < creature^.hpMax) and bypassRot) or (not bypassRot) then begin
    creature^.hpCur := creature^.hpCur + hp;
    if creature^.hpCur > creature^.hpMax then
      creature^.hpCur := creature^.hpMax;
    if creature^.enabled = 0 then begin
      if creature^.status = C_Status.DYING then creature^.status := C_Status.UNCONSCIOUS;
      if (creature^.status = C_Status.UNCONSCIOUS) and (GDVars.ifcState <> C_Ifc.IN_COMBAT) then
        FxEngine.CallEffectHandler(78, creature, nil, True);
    end;
    RestoreHitPoints := True;
  end;
end;

function ReviveDeadCreature(creature: Types.PCreature; hp: Byte): Boolean;
var
  s: Types.TStr40;
begin
  if CbtMap.IsValidCreatureLoc(Pointer(creature), CbtMap.CombatCellX(Pointer(creature)),
                               CbtMap.CombatCellY(Pointer(creature)), True) then begin
    creature^.status := C_Status.OKAY;
    creature^.enabled := 1;
    creature^.hpCur := hp;
    if GDVars.ifcState = C_Ifc.IN_COMBAT then
      CbtMap.DisplayMapViewCentered(Pointer(creature), 3, False);
    if creature^.hostile = 1 then
      s := 'stands up and grins'
    else
      s := 'gets back up';
    CharHlp.PrintCreatureMessage(Pointer(creature), s, 10, True);
    CharHlp.CountTeams;
    ReviveDeadCreature := True;
  end else
    ReviveDeadCreature := False;
end;

begin
end.
