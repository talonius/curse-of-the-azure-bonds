{ Combat AI: movement, re-equipping, item and spell choice, morale, and the move/attack loop. }
{$O+,F+}
{$A-}
{$R-}
{$S-}
unit CombatAi;

interface

uses Types, GDConsts, GDVars, C_Keys, C_Class, C_Stat, C_Status, C_Effect, C_Gbvm, C_Spell, Crt, TextRend,
  GameIo, MenuCore, CbtMap, FxEngine, Pathing, CbtActs, Magic, ViewChar, CharHlp, View3D, EclTrace, ClassCal;

{ Runs one AI-controlled turn: checks the keyboard (Space can return the party to manual control), rerolls the approach
  pattern (kept on three turns out of four for patterns 1..4), checks morale, then tries in order an item's spell
  effect, a spell begun earlier, turning undead and a new spell, and otherwise re-equips and runs the move/attack loop
  until the creature is done.
  @param(creature The creature taking its turn.) }
procedure CombatAiControl(creature: Types.PCreature);

{ Calls the priming entry of each overlay the AI uses, so the overlay manager loads them. }
procedure PrimeCombatAi;

implementation

const
  ITEM_FIRES_AMMUNITION = 8;

procedure PrimeCombatAi;
begin
  ViewChar.PrimeViewChar;
  Pathing.PrimePathing;
  CbtMap.PrimeCbtMap;
  View3D.PrimeView3D;
  MenuCore.PrimeMenuCore;
  CharHlp.PrimeCharHlp;
  Magic.PrimeMagic;
  FxEngine.PrimeFxEngine;
  CbtActs.PrimeCbtActs;
  EclTrace.PrimeEclTrace;
  ClassCal.PrimeClassCal;
end;

function TurnUndeadAi(creature: Types.PCreature): Boolean; forward;

function SelectItemToUse(creature: Types.PCreature): Boolean; forward;

function SelectSpellToCast(creature: Types.PCreature): Boolean; forward;

function AiMoveAttack(creature: Types.PCreature): Boolean; forward;

function FinishRound(creature: Types.PCreature): Boolean; forward;

function CheckKeystroke(creature: Types.PCreature): Boolean; forward;

function CheckMorale(creature: Types.PCreature): Boolean; forward;

procedure EquipWeaponAndArmor(creature: Types.PCreature); forward;

function DecideCastSpell(creature: Types.PCreature; spell, minPri: Byte): Boolean; forward;

procedure CombatAiControl(creature: Types.PCreature);
var
  stance: Byte;
  done: Boolean;
begin
  done := CombatAi.CheckKeystroke(creature);
  MenuCore.ClearBottomLine;
  CharHlp.ClearMessageWindow;
  if creature^.enabled = 0 then
    done := CharHlp.EndActions(Pointer(creature));
  stance := creature^.combatAddr^.aiStance;
  if (stance = 0) or (stance > 4) or (FxEngine.RollDice(1, 4) = 1) then begin
    stance := FxEngine.RollDice(1, 8);
    if stance = 8 then
      stance := FxEngine.RollDice(1, 2) + 4
    else
      stance := FxEngine.RollDice(1, 4);
  end;
  creature^.combatAddr^.aiStance := stance;
  if not done then
    done := CombatAi.CheckMorale(creature);
  if (creature^.combatAddr^.fleeing <> 0) and (creature^.combatAddr^.turned = 0) then
    CharHlp.PrintCreatureMessage(Pointer(creature), 'flees in panic', 10, True);
  if done then Exit;
  if CombatAi.SelectItemToUse(creature) then
    done := CharHlp.EndActions(Pointer(creature))
  else if creature^.combatAddr^.spellCast > 0 then begin
    Magic.CastSpell(creature^.combatAddr^.spellCast, True, True, done);
    done := CharHlp.EndActions(Pointer(creature));
  end else if CombatAi.TurnUndeadAi(creature) then
    done := CharHlp.EndActions(Pointer(creature))
  else if CombatAi.SelectSpellToCast(creature) then
    done := True
  else begin
    CombatAi.EquipWeaponAndArmor(creature);
    done := CombatAi.CheckKeystroke(creature);
    while not done do
      if CbtActs.AcquireTarget(Pointer(creature), 255, 1, 0)
         and (creature^.combatAddr^.initiative > 0)
         and (creature^.enabled <> 0) then
        done := CombatAi.AiMoveAttack(creature)
      else
        done := CombatAi.FinishRound(creature);
  end;
end;

{ Turns undead when the creature is a cleric (a former cleric counts while its old cleric level is above its level at
  the class change) that has not tried this battle and a turnable undead target exists.
  @param(creature The creature.)
  @returns(True if it turned undead.) }
function TurnUndeadAi(creature: Types.PCreature): Boolean;
var
  tgt: Pointer;
begin
  if (creature^.combatAddr^.usedTurnUndead = 0) and
      ((creature^.classLevels[C_Class.CLERIC_LEVEL] > 0) or
       (creature^.oldClassLevels[C_Class.CLERIC_LEVEL] > creature^.levelAtChange)) and
      CbtActs.FindTurnUndeadTarget(Pointer(creature), tgt) then begin
    TurnUndeadAi := True;
    CbtActs.CombatTurnUndead(Pointer(creature));
  end else
    TurnUndeadAi := False;
end;

{ Decides whether the AI should use a spell (memorized, or an item's spell effect). Its AI priority must be at least
  minPri. Non-offensive spells other than Cure Light Wounds always qualify, as does Cure Light Wounds with a cure
  target. Everything else needs an enemy within the spell's range and, for an area spell, no candidate target whose area
  would catch an ally of the current character who fails a saving throw, rolled at once (-2 for a party caster, +8 for a
  hostile one); a spell whose save result is 1 never counts as catching one. Note: a pending spell from
  SelectSpellToCast keeps its $80 preparation bit, so its AI priority is read from past the end of the spell table.
  @param(creature The caster.)
  @param(spell The spell.)
  @param(minPri The lowest AI priority accepted.)
  @returns(True when the AI should cast the spell.) }
function DecideCastSpell(creature: Types.PCreature; spell, minPri: Byte): Boolean;
var
  tgt: Pointer;
  cnt: Byte;
  j: Byte;

  { Tells whether the spell's area around (x, y) catches an ally of the current character who fails a saving throw. }
  function AreaHitsNonEnemy(x, y: ShortInt; spell: Byte): Boolean;
  var
    i: Byte;
    filter: Byte;
  begin
    AreaHitsNonEnemy := False;
    if GDVars.curChar^.hostile = 0 then
      filter := 254
    else
      filter := 8;
    Pathing.BuildTargetList(x, y, GDConsts.spellProperties[spell].aiRadius, 255, 1, GDVars.combatArena);
    for i := 1 to GDVars.targetCount do
      if (ShortInt(CharHlp.NotHostile(Pointer(GDVars.curChar))) <>
          GDVars.combatCreatures[GDVars.targetList[i].idx]^.hostile) and
          (GDConsts.spellProperties[spell].saveResult <> 1) and
          (not FxEngine.RollSavingThrow(Pointer(GDVars.combatCreatures[GDVars.targetList[i].idx]),
                                        GDConsts.spellProperties[spell].saveType, filter)) then
        AreaHitsNonEnemy := True;
  end;

begin
  DecideCastSpell := False;
  if GDConsts.spellProperties[spell].aiPriority < minPri then Exit;
  if ((spell <> C_Spell.CURE_LIGHT_WOUNDS) and (GDConsts.spellProperties[spell].targetsEnemy = 0))
     or ((spell = C_Spell.CURE_LIGHT_WOUNDS) and CbtActs.FindCureTarget(Pointer(creature), Types.PCreature(tgt))) then
    DecideCastSpell := True
  else begin
    cnt := CharHlp.CountTargets(Pointer(creature), Magic.CalcSpellRange(spell));
    if cnt > 0 then
      if GDConsts.spellProperties[spell].aiRadius = 0 then
        DecideCastSpell := True
      else begin
        for j := 1 to cnt do
          if AreaHitsNonEnemy(GDVars.arenaSlots[GDVars.combatTargetSlots[j]].x,
                              GDVars.arenaSlots[GDVars.combatTargetSlots[j]].y, spell) then Exit;
        DecideCastSpell := True;
      end;
  end;
end;

function AiCanStep(creature: Types.PCreature; attempt, baseDir: Byte; var edge: Boolean): Boolean; forward;

procedure AiMoveStep(creature: Types.PCreature); forward;

function CalcWeaponPriority(creature: Types.PCreature; item: Types.PItem): Byte; forward;

{ Uses an item's spell effect when the AI wants one; needs item use allowed this round, enemies left and no anti-magic.
  Over 1d7 passes the minimum AI priority drops from 7, and the first readied item that is not readable, has special
  below $80 and has an effect DecideCastSpell accepts (effects above 56 map 23 lower) is used.
  @param(creature The creature.)
  @returns(True if an item was used.) }
function SelectItemToUse(creature: Types.PCreature): Boolean;
var
  lowPri: Byte;
  roll: Byte;
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  itemCount: Integer;
  { Unused in this version; see the other implementations of this routine. }
  slot: Byte;
  effect: Byte;
  { Unused in this version; see the other implementations of this routine. }
  baseItem: Pointer;
  it: Types.PItem;
  chosen: Types.PItem;
  used: Boolean;
begin
  SelectItemToUse := False;
  chosen := nil;
  lowPri := 7;
  roll := FxEngine.RollDice(1, 7);
  if (creature^.combatAddr^.itemUseAllowed <> 0)
     and (GDVars.teamCount[ShortInt(CharHlp.NotHostile(Pointer(creature)))] > 0)
     and (GDVars.zone0^[C_Gbvm.ANTI_MAGIC] = 0) then
    for i := 1 to roll do begin
      it := creature^.itemsAddr;
      while (it <> nil) and (chosen = nil) do begin
        effect := it^.effect;
        slot := GDVars.baseItems[it^.itemType].slot;
        if (not Magic.ItemReadable(it))
           and (it^.special < $80)
           and (it^.equipped <> 0)
           and (effect > 0) then begin
          if effect > 56 then effect := effect - 23;
          if CombatAi.DecideCastSpell(creature, effect, lowPri) then chosen := it;
        end;
        it := it^.next;
      end;
      Dec(lowPri);
    end;
  if chosen <> nil then begin
    ViewChar.UseItem(chosen, used);
    SelectItemToUse := True;
  end;
end;

{ Picks a spell for an NPC, or for a party member while quick magic (Alt-M) is on, when enemies remain. The list holds
  memorized entries 1..83 (pending ones included) when casting is allowed. Over 1d7 passes the minimum AI priority drops
  from 7, with three random picks per pass; the first spell DecideCastSpell accepts goes to CastSpellCombat. Note:
  pending entries keep their $80 preparation bit, which DecideCastSpell does not strip.
  @param(creature The caster.)
  @returns(CastSpellCombat's done flag, or False when no spell was cast.) }
function SelectSpellToCast(creature: Types.PCreature): Boolean;
var
  list: array[0..83] of Byte;
  { Unused in this version; see the other implementations of this routine. }
  spellTarget: array[0..3] of Byte;
  lowPri: Byte;
  roll: Byte;
  ext: Boolean;
  tries: Byte;
  inner: Byte;
  count: Byte;
  { Index into the memorized spells, then into the list. }
  k: Byte;
  spell: Byte;
  chosen: Byte;
begin
  count := 0;
  if creature^.combatAddr^.castAllowed <> 0 then
    for k := 1 to 83 do
      if creature^.memorizedSpells[k] > 0 then begin
        list[count] := creature^.memorizedSpells[k];
        Inc(count);
      end;
  chosen := 0;
  lowPri := 7;
  roll := FxEngine.RollDice(1, 7);
  tries := 1;
  if count > 0 then
    if (creature^.npc > $7F) or GDVars.quickMagic then
      if GDVars.teamCount[ShortInt(CharHlp.NotHostile(Pointer(creature)))] > 0 then
        while (tries <= roll) and (chosen = 0) do begin
          inner := 1;
          while (inner < 4) and (chosen = 0) do begin
            k := FxEngine.RollDice(1, count) - 1;
            spell := list[k];
            if CombatAi.DecideCastSpell(creature, spell, lowPri) then chosen := spell;
            Inc(inner);
          end;
          Dec(lowPri);
          Inc(tries);
        end;
  if chosen > 0 then
    CbtActs.CastSpellCombat(chosen, 1, ext)
  else
    ext := False;
  SelectSpellToCast := ext;
end;

{ Checks a step in direction baseDir plus the approach pattern's offset for attempt. Off the arena sets edge and fails;
  an occupied or impassable cell fails. The step costs 2 (orthogonal) or 3 (diagonal) times the terrain cost and must be
  less than the movement left. Next to terrain 30 the creature balks unless it has effect ANIMATE_DEAD,
  STINKING_CLOUD_COUGH, 111, 125, 129 or 63, is turned, or makes a saving throw; next to terrain 28 a creature below
  level 7 balks unless it has effect 129, 111, 133 or 125 or is turned.
  @param(creature The moving creature.)
  @param(attempt The attempt, 1..5, which picks the pattern's turn.)
  @param(baseDir The wanted direction, 0..7.)
  @param(edge Set True when the step would leave the arena, else False.)
  @returns(True when the creature can take the step.) }
function AiCanStep(creature: Types.PCreature; attempt, baseDir: Byte; var edge: Boolean): Boolean;
var
  eff: Types.PEffect;
  dirAdj: Byte;
  dir: Byte;
  crIdx: Byte;
  terrIdx: Byte;
  stepCost: Byte;
  { terrain 30 nearby (ProbeDirection) }
  terrSpec: Byte;
  { terrain 28 nearby (ProbeDirection) }
  terrHaz: Byte;
  canStep: Boolean;
begin
  edge := False;
  canStep := False;
  dirAdj := GDConsts.combatAiDirections[creature^.combatAddr^.aiStance, attempt];
  dir := (baseDir + dirAdj) mod 8;
  CbtMap.ProbeDirection(Pointer(creature), dir, crIdx, terrIdx, terrSpec, terrHaz);
  if terrIdx = 0 then
    edge := True
  else begin
    if GDConsts.terrainInfo[terrIdx].cost = 255 then begin
      AiCanStep := False;
      Exit;
    end;
    if Odd(dir) then
      stepCost := GDConsts.terrainInfo[terrIdx].cost * 3
    else
      stepCost := GDConsts.terrainInfo[terrIdx].cost * 2;
    if crIdx = 0 then
      if stepCost < creature^.combatAddr^.movement then begin
        if terrSpec <> 0 then
          if (not CharHlp.HasEffect(Pointer(creature), C_Effect.ANIMATE_DEAD, eff))
             and (not CharHlp.HasEffect(Pointer(creature), C_Effect.STINKING_CLOUD_COUGH, eff))
             and (not CharHlp.HasEffect(Pointer(creature), 111, eff))
             and (not CharHlp.HasEffect(Pointer(creature), 125, eff))
             and (not CharHlp.HasEffect(Pointer(creature), 129, eff))
             and (not CharHlp.HasEffect(Pointer(creature), 63, eff))
             and (creature^.combatAddr^.turned = 0)
             and (not FxEngine.RollSavingThrow(Pointer(creature), 0, 0)) then
            stepCost := creature^.combatAddr^.movement + 1;
        if terrHaz <> 0 then
          if (creature^.levelHighest < 7)
             and (not CharHlp.HasEffect(Pointer(creature), 129, eff))
             and (not CharHlp.HasEffect(Pointer(creature), 111, eff))
             and (not CharHlp.HasEffect(Pointer(creature), 133, eff))
             and (creature^.combatAddr^.turned = 0)
             and (not CharHlp.HasEffect(Pointer(creature), 125, eff)) then
            stepCost := creature^.combatAddr^.movement + 1;
        if creature^.combatAddr^.movement >= stepCost then canStep := True;
      end;
  end;
  AiCanStep := canStep;
end;

{ Takes one AI movement step: toward the locked target, or for a fleeing creature away from the party's facing (the
  party flees the other way), trying up to five directions from the approach pattern; a fleeing creature at the arena
  edge tries to flee. An unarmored magic-user does not advance, and a party-side NPC advances when it passes a morale
  roll against the hostiles' remaining hit points, while party characters and hostile creatures always may. A step back
  the way it came, or no usable direction, counts as stuck and rotates the pattern; stuck twice drops the target, three
  times stops moving. The step allows opportunity attacks and terrain effects.
  @param(creature The moving creature.) }
procedure AiMoveStep(creature: Types.PCreature);
var
  dir: Byte;
  adjDir: Byte;
  attempt: Byte;
  edge: Boolean;
  done: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  combat: array[0..3] of Byte;
begin
  TextRend.DisplayString(0, 24, LightGreen, 0,
                         'Move/Attack, Move Left = ' + CharHlp.Uint8Str(creature^.combatAddr^.movement div 2) + ' ');
  if CombatAi.CheckKeystroke(creature) then Exit;
  if (creature^.combatAddr^.movement div 2 > 0)
     and (creature^.combatAddr^.initiative > 0)
     and
       ((creature^.npc < $80) or
        ((creature^.npc > $7F) and (GDVars.hostileHpPct <= GDVars.combatMorale + FxEngine.RollDice(1, 100))) or
        (creature^.hostile = 1))
     and ((creature^.combatAddr^.fleeing <> 0) or (creature^.equipped[2] <> nil)
          or (creature^.charClass <> C_Class.MAGE)) then begin
    if creature^.combatAddr^.fleeing = 0 then
      dir := CbtActs.DirTowardTarget(Pointer(creature), Pointer(creature^.combatAddr^.other))
    else begin
      creature^.combatAddr^.aiStance := FxEngine.RollDice(1, 2);
      dir := GDVars.partyPos.facing - (((GDVars.partyPos.facing + 2) mod 4) div 2);
      if creature^.hostile = 0 then dir := dir + 4;
      dir := dir mod 8;
    end;
    edge := False;
    done := False;
    attempt := 1;
    while (attempt < 6) and (not done)
          and (not CombatAi.AiCanStep(creature, attempt, dir, edge)) do
      if (creature^.combatAddr^.fleeing <> 0) and edge then
        done := CbtActs.AttemptFlee(Pointer(creature))
      else
        Inc(attempt);
    if done then begin
      creature^.combatAddr^.movement := 0;
      creature^.combatAddr^.fleeing := 0;
      done := CharHlp.EndActions(Pointer(creature));
    end else begin
      adjDir := (dir + GDConsts.combatAiDirections[creature^.combatAddr^.aiStance, attempt]) mod 8;
      if (attempt = 6) or (GDVars.lastMoveDir = (adjDir + 4) mod 8) then begin
        Inc(GDVars.stuckCount);
        creature^.combatAddr^.aiStance := creature^.combatAddr^.aiStance mod 6 + 1;
        if GDVars.stuckCount > 1 then begin
          creature^.combatAddr^.other := nil;
          if GDVars.stuckCount > 2 then begin
            creature^.combatAddr^.movement := 0;
            done := True;
          end else if not CbtActs.AcquireTarget(Pointer(creature), 255, 1, 0) then
            done := CombatAi.FinishRound(creature);
        end;
      end;
      if attempt < 6 then
        GDVars.lastMoveDir := adjDir
      else
        done := True;
    end;
    if not done then begin
      GDVars.mapVisible := GDVars.inRange or CbtMap.CombatIconVisible(Pointer(creature), 0) or
                             (creature^.hostile = 0);
      CbtMap.SetCreatureFacing(Pointer(creature), adjDir, 0, 0);
      CbtActs.AttacksOfOpportunity(Pointer(creature), creature^.combatAddr^.direction);
      if creature^.enabled = 0 then
        done := CharHlp.EndActions(Pointer(creature))
      else begin
        if creature^.combatAddr^.movement > 0 then
          CbtActs.CombatMoveCreature(Pointer(creature), creature^.combatAddr^.direction);
        if creature^.enabled = 0 then done := CharHlp.EndActions(Pointer(creature));
        FxEngine.ConsiderTerrainEffects(Pointer(creature), 1);
      end;
    end;
  end else
    done := CombatAi.FinishRound(creature);
end;

{ Runs the AI's move/attack loop (the 21st pass finishes the round): fires condition-14 effects, lets a party member
  bandage a dying teammate (ending its turn), moves a fleeing creature away, then attacks the locked target if it is a
  hostile in weapon range and in sight (a locked party-side target is dropped, so hostile creatures never use theirs
  here), or a random enemy in range, or moves toward a target. A ranged weapon that cannot fire with an enemy adjacent
  makes it re-equip and stop. Attacks try a sweep first. Note: the locked target is read before it is checked for nil,
  and the pass that finishes the round for the pass limit still goes on to seek and attack a target.
  @param(creature The acting creature.)
  @returns(True when the creature can no longer act.) }
function AiMoveAttack(creature: Types.PCreature): Boolean;
var
  done: Boolean;
  canAct: Boolean;
  weaponRange: Byte;
  range: Word;
  cnt: Byte;
  pick: Byte;
  { Item returned by CharHlp.FindDamagingRangedWeapon. }
  weapon: Pointer;
  target: Types.PCreature;
  tx: ShortInt;
  ty: ShortInt;
  loopCount: Byte;
begin
  GDVars.lastMoveDir := 8;
  GDVars.stuckCount := 0;
  GDVars.aiMoveState := 0;
  loopCount := 0;
  canAct := True;
  done := False;
  FxEngine.TriggerEffectsWithCondition(14, Pointer(creature));
  if (creature^.hostile = 0) and CharHlp.BandageDying(True) then
    creature^.combatAddr^.initiative := 0;
  if creature^.combatAddr^.initiative = 0 then canAct := False;
  while (not done) and canAct do begin
    if creature^.combatAddr^.fleeing <> 0 then
      while (creature^.combatAddr^.movement > 0)
            and (creature^.combatAddr^.initiative > 0)
            and (creature^.combatAddr^.initiative < 20) do
        CombatAi.AiMoveStep(creature);
    if (creature^.combatAddr^.initiative = 0)
       or (creature^.combatAddr^.initiative = 20) then
      canAct := False
    else
      done := False;
    if (not done) and canAct then begin
      Inc(loopCount);
      if loopCount > 20 then begin
        done := True;
        canAct := CombatAi.FinishRound(creature) = False;
      end;
      GDVars.inRange := False;
      weaponRange := 1;
      if creature^.equipped[0] <> nil then
        weaponRange := GDVars.baseItems[creature^.equipped[0]^.itemType].range - 1;
      if (weaponRange = 0) or (weaponRange = 255) then weaponRange := 1;
      target := creature^.combatAddr^.other;
      if (target^.enabled = 0) or (target^.hostile = 0) then target := nil;
      if target <> nil then
        if CbtActs.CanTarget(Pointer(creature), Pointer(target)) then begin
          tx := CbtMap.CombatCellX(Pointer(target));
          ty := CbtMap.CombatCellY(Pointer(target));
          range := weaponRange;
          GDVars.combatArena^.distMode := 0;
          if Pathing.WalkLine(CbtMap.CombatCellX(Pointer(creature)), CbtMap.CombatCellY(Pointer(creature)), tx, ty,
                              range, GDVars.combatArena) then
            if range div 2 <= weaponRange then GDVars.inRange := True;
        end;
      if not GDVars.inRange then begin
        cnt := CharHlp.CountTargets(Pointer(creature), weaponRange);
        if cnt = 0 then begin
          if CbtActs.AcquireTarget(Pointer(creature), 255, 0, 0) then
            CombatAi.AiMoveStep(creature)
          else
            done := CombatAi.FinishRound(creature);
        end else begin
          pick := FxEngine.RollDice(1, cnt);
          target := GDVars.combatCreatures[GDVars.combatTargetSlots[pick]];
          if CharHlp.HasRangedWeapon(Pointer(creature)) and (not CharHlp.HasThrowableWeapon(Pointer(creature)))
             and (CharHlp.CountTargets(Pointer(creature), 1) > 0) then begin
            CombatAi.EquipWeaponAndArmor(creature);
            done := True;
          end else if (CharHlp.CalcDistance(Pointer(creature), Pointer(target)) = 1)
                  or CbtActs.CanTarget(Pointer(creature), Pointer(target)) then
            GDVars.inRange := True;
        end;
      end;
      if GDVars.inRange then
        CbtMap.ScrollView(CbtMap.CombatCellX(Pointer(creature)), CbtMap.CombatCellY(Pointer(creature)), 2,
                          CbtActs.DirTowardTarget(Pointer(creature), Pointer(target)));
      if GDVars.inRange then begin
        if CbtActs.SweepAttack(Pointer(creature), Pointer(target)) then
          done := CharHlp.EndActions(Pointer(creature))
        else begin
          CbtActs.NoteAttackDirection(Pointer(creature), Pointer(target));
          weapon := nil;
          if CharHlp.HasRangedWeapon(Pointer(creature)) then begin
            GDVars.inRange := CharHlp.FindDamagingRangedWeapon(Pointer(creature), weapon);
            if CharHlp.HasThrowableWeapon(Pointer(creature)) then
              if CharHlp.CalcDistance(Pointer(creature), Pointer(target)) = 1 then weapon := nil;
          end;
          CbtActs.MakeAttack(Pointer(creature), Pointer(target), False, weapon, done);
          if done then
            canAct := False
          else if target^.enabled = 0 then
            done := True;
        end;
      end;
    end;
  end;
  AiMoveAttack := canAct = False;
end;

{ Ends the creature's round: a helpless, ranged-armed or out-of-initiative creature just ends its actions; others guard.
  @param(creature The creature.)
  @returns(Always True.) }
function FinishRound(creature: Types.PCreature): Boolean;
begin
  CharHlp.ClearMessageWindow;
  if CharHlp.IsHelpless(Pointer(creature))
     or CharHlp.HasRangedWeapon(Pointer(creature))
     or (creature^.combatAddr^.initiative = 0) then
    FinishRound := CharHlp.EndActions(Pointer(creature))
  else
    FinishRound := CharHlp.Guard(Pointer(creature));
end;

{ Handles a key pressed during AI turns: Alt-M toggles quick magic, Space returns each non-NPC creature that is not
  animated to manual control, and Alt-X tries the STING victory cheat. Pending keys are drained afterwards.
  @param(creature The creature whose turn it is.)
  @returns(True when Space returned this creature to manual control (its initiative becomes 20).) }
function CheckKeystroke(creature: Types.PCreature): Boolean;
var
  p: Types.PCreature;
  ch: Char;
begin
  CheckKeystroke := False;
  if keyPressed then begin
    ch := GameIo.ReadGameKey;
    if ch = #0 then ch := GameIo.ReadGameKey;
    case ch of
      C_Keys.ALT_M:
        begin
          GDVars.quickMagic := GDVars.quickMagic = False;
          if GDVars.quickMagic then
            CharHlp.PrintBottomLine('Magic On')
          else
            CharHlp.PrintBottomLine('Magic Off');
        end;
      ' ':
        begin
          p := GDVars.partyHead;
          while p <> nil do begin
            if (p^.npc < $80) and (p^.status <> C_Status.ANIMATED) then
              p^.quickfight := 0;
            p := p^.next;
          end;
          if creature^.quickfight = 0 then begin
            creature^.combatAddr^.initiative := 20;
            CheckKeystroke := True;
          end;
        end;
      C_Keys.ALT_X:
        if CbtActs.VictoryCheat then begin end;
    end;
  end;
  GameIo.DiscardPendingKeys;
end;

{ Clears the creature's fleeing flag and AI effects, then checks an NPC's morale (party characters never check; a turned
  creature is forced to flee). Morale is twice the low 7 bits of its NPC byte (0 above 102), adjusted by condition-17
  effects, and it holds when it is nonzero and covers the creature's own hit-point loss in percent. Failing that, a
  hostile still holds when the hostiles' remaining hit-point percentage, adjusted the same way, is nonzero and at least
  100 less zone 1's morale threshold. On a failure the creature flees if it is at least as fast as the fastest enemy;
  otherwise one with Intelligence above 5 surrenders.
  @param(creature The creature.)
  @returns(True on surrender.) }
function CheckMorale(creature: Types.PCreature): Boolean;
var
  enemyMove: Byte;
  { Unused in this version; see the other implementations of this routine. }
  moraleSave: Byte;
begin
  CheckMorale := False;
  creature^.combatAddr^.fleeing := 0;
  FxEngine.RemoveAiEffects(Pointer(creature));
  if creature^.combatAddr^.turned <> 0 then begin
    creature^.combatAddr^.fleeing := 1;
    CharHlp.PrintCreatureMessage(Pointer(creature), 'is forced to flee', 10, True);
    Exit;
  end;
  if creature^.npc <= $7F then Exit;
  GDVars.combatMorale := (creature^.npc and $7F) * 2;
  if GDVars.combatMorale > 102 then GDVars.combatMorale := 0;
  FxEngine.TriggerEffectsWithCondition(17, Pointer(creature));
  if (GDVars.combatMorale >= 100 - creature^.hpCur * 100 div creature^.hpMax) and
      (GDVars.combatMorale <> 0) then Exit;
  moraleSave := GDVars.combatMorale;
  GDVars.combatMorale := GDVars.hostileHpPct;
  FxEngine.TriggerEffectsWithCondition(17, Pointer(creature));
  if (GDVars.combatMorale >= 100 - GDVars.zone1^[C_Gbvm.MORALE_THRESHOLD])
     and (GDVars.combatMorale <> 0)
     and (creature^.hostile <> 0) then Exit;
  enemyMove := CbtActs.HighestEnemyMovement(Pointer(creature));
  if enemyMove <= CbtActs.CalcCreatureMovement(Pointer(creature)) div 2 then begin
    creature^.combatAddr^.fleeing := 1;
    FxEngine.RemoveEffect(Pointer(creature), 74, nil);
    FxEngine.RemoveEffect(Pointer(creature), 75, nil);
  end else if creature^.stats[C_Stat.INTELLIGENCE].current > 5 then begin
    FxEngine.PutOutOfPlayWithStatus(Pointer(creature), C_Status.UNCONSCIOUS, 'Surrenders');
    CheckMorale := CharHlp.EndActions(Pointer(creature));
  end;
end;

{ Scores a weapon for EquipWeaponAndArmor: damage dice product, +8 per plus, +2 per damage bonus (item type 85 scores 8
  against an undead target), +2 per extra shot for a launcher, +3 one-handed. The score is zero when it would need more
  than 3 hands, for an aligned weapon (special $84) of another alignment, for an item with spell effect 83, and when
  cursed.
  @param(creature The creature that would wield the weapon.)
  @param(item The weapon.)
  @returns(The score.) }
function CalcWeaponPriority(creature: Types.PCreature; item: Types.PItem): Byte;
var
  pri: Byte;
  base: Types.TBaseItemRec;
begin
  base := GDVars.baseItems[item^.itemType];
  pri := base.dmgSmDice * base.dmgSmRolls;
  if item^.plus > 0 then pri := pri + item^.plus * 8;
  if base.dmgSmMod > 0 then pri := pri + base.dmgSmMod * 2;
  if (item^.itemType = 85)
     and (creature^.combatAddr^.other <> nil)
     and (creature^.combatAddr^.other^.levelUndead > 0) then
    pri := 8;
  if (base.props and CombatAi.ITEM_FIRES_AMMUNITION) > 0 then
    pri := pri + (base.rateOfFire - 1) * 2;
  if base.hands <= 1 then pri := pri + 3;
  if base.hands + creature^.handsEquipped > 3 then pri := 0;
  if item^.special = $84 then
    if (item^.effect and $F) <> creature^.alignment then pri := 0;
  if item^.effect = 83 then pri := 0;
  if item^.cursed <> 0 then pri := 0;
  CalcWeaponPriority := pri;
end;

{ Re-equips the creature: picks the best usable weapon by CalcWeaponPriority (unarmed damage sets the melee bar) and the
  best shield (plus + 1). The ranged pick wins when it beats half the melee score, has ammunition, and is thrown or no
  enemy is adjacent. Cursed items are never swapped out, and a weapon and shield needing more than two hands drop one.
  Shows the creature's panel if anything changed.
  @param(creature The creature.) }
procedure EquipWeaponAndArmor(creature: Types.PCreature);
var
  bestRanged: Types.PItem;
  bestMelee: Types.PItem;
  bestShield: Types.PItem;
  it: Types.PItem;
  ammo: Types.PItem;
  bestRangedPri: Byte;
  bestMeleePri: Byte;
  bestShieldPri: Byte;
  pri: Byte;
  itType: Byte;
  props: Byte;
  { Unused in this version; see the other implementations of this routine. }
  hands: array[$0..$0] of Byte;
  needSwap: Boolean;
  changed: Boolean;
  trueRanged: Boolean;
  hasAmmo: Boolean;
begin
  if creature^.equipped[0] <> nil then
    creature^.handsEquipped := creature^.handsEquipped
        - GDVars.baseItems[creature^.equipped[0]^.itemType].hands;
  if creature^.equipped[1] <> nil then
    creature^.handsEquipped := creature^.handsEquipped
        - GDVars.baseItems[creature^.equipped[1]^.itemType].hands;
  bestRanged := nil;
  bestMelee := nil;
  bestShield := nil;
  bestRangedPri := 1;
  bestMeleePri := creature^.baseDice[1] * creature^.baseRolls[1];
  if creature^.baseMod[1] > 0 then
    bestMeleePri := bestMeleePri + creature^.baseMod[1] * 2;
  bestShieldPri := 0;
  it := creature^.itemsAddr;
  while it <> nil do begin
    itType := it^.itemType;
    if GDVars.baseItems[itType].slot = 0 then
      if (GDVars.baseItems[itType].classMask and creature^.classMask) <> 0 then begin
        pri := CombatAi.CalcWeaponPriority(creature, it);
        if ((GDVars.baseItems[itType].props and CombatAi.ITEM_FIRES_AMMUNITION) <> 0)
           or ((GDVars.baseItems[itType].props and $10) <> 0) then
          if pri > bestRangedPri then begin
            bestRanged := it;
            bestRangedPri := pri;
          end;
        if (GDVars.baseItems[itType].props and CombatAi.ITEM_FIRES_AMMUNITION) = 0 then
          if pri > bestMeleePri then begin
            bestMelee := it;
            bestMeleePri := pri;
          end;
      end;
    if GDVars.baseItems[itType].slot = 1 then
      if (GDVars.baseItems[itType].classMask and creature^.classMask) > 0 then begin
        if it^.plus >= 0 then pri := it^.plus + 1 else pri := 0;
        if pri > bestShieldPri then begin
          bestShield := it;
          bestShieldPri := pri;
        end;
      end;
    it := it^.next;
  end;
  if (bestRanged <> nil)
     and (GDVars.baseItems[bestRanged^.itemType].range > 1)
     and ((GDVars.baseItems[bestRanged^.itemType].props and $14) = $14) then
    trueRanged := True
  else
    trueRanged := False;
  hasAmmo := False;
  ammo := nil;
  props := 0;
  if bestRanged <> nil then begin
    props := GDVars.baseItems[bestRanged^.itemType].props;
    if (props and $10) <> 0 then ammo := bestRanged;
    if (props and CombatAi.ITEM_FIRES_AMMUNITION) <> 0 then begin
      if (props and 1) <> 0 then ammo := creature^.equipped[11];
      if (props and 128) <> 0 then ammo := creature^.equipped[12];
    end;
  end;
  if (ammo <> nil) or (props = 10) then hasAmmo := True;
  if (bestRanged <> nil)
     and (bestRangedPri > bestMeleePri div 2)
     and hasAmmo
     and (trueRanged or (CharHlp.CountTargets(Pointer(creature), 1) = 0)) then
    it := bestRanged
  else
    it := bestMelee;
  changed := False;
  needSwap := True;
  if creature^.equipped[0] <> nil then
    if (creature^.equipped[0] = it) or (creature^.equipped[0]^.cursed <> 0) then
      needSwap := False;
  if needSwap then begin
    if creature^.equipped[0] <> nil then ViewChar.ToggleReadyItem(creature^.equipped[0]);
    CharHlp.RecalcStats(Pointer(creature));
    if creature^.equipped[1] <> nil then
      if creature^.equipped[1]^.cursed = 0 then
        creature^.handsEquipped := creature^.handsEquipped
            - GDVars.baseItems[creature^.equipped[1]^.itemType].hands;
    if it <> nil then ViewChar.ToggleReadyItem(it);
    changed := True;
  end;
  CharHlp.RecalcStats(Pointer(creature));
  CbtActs.RecalcAttacksLeft(Pointer(creature));
  needSwap := True;
  if creature^.equipped[1] <> nil then
    if (creature^.equipped[1] = bestShield) or (creature^.equipped[1]^.cursed <> 0) then
      needSwap := False;
  if creature^.handsEquipped > 2 then begin
    if (creature^.equipped[1] = nil) or (creature^.equipped[1]^.cursed <> 0) then begin
      ViewChar.ToggleReadyItem(it);
      changed := True;
    end else begin
      ViewChar.ToggleReadyItem(creature^.equipped[1]);
      changed := True;
    end;
  end else if (creature^.handsEquipped < 2) and needSwap then begin
    if creature^.equipped[1] <> nil then ViewChar.ToggleReadyItem(creature^.equipped[1]);
    CharHlp.RecalcStats(Pointer(creature));
    if bestShield <> nil then ViewChar.ToggleReadyItem(bestShield);
    changed := True;
  end;
  CharHlp.RecalcStats(Pointer(creature));
  if changed then CharHlp.CombatPrintCreatureInfo(Pointer(creature));
end;

begin
end.
