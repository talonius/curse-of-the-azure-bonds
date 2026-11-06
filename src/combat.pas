{ The combat loop: rounds, initiative order, and the menus for player-controlled creatures. }
{$O+,F+}
{$A-}
{$R-}
{$S-}
unit Combat;

interface

{ Runs a battle. Switches to the combat interface state and the combat cast-target menu, sets up the battle
  (CombatSt.CombatStart), then, unless a side starts empty, plays rounds until EndOfRound reports the battle over: count
  the sides, run each creature's round-start setup, clear the script's surprise flag, let the creatures act in
  initiative order, and end the round. Afterwards it cleans up and sets typingDelayOn. }
procedure CombatMain;

{ Calls the priming entry of each overlay the combat code uses, so the overlay manager loads them. }
procedure PrimeCombat;

implementation

uses Crt, Types, MenuCore, CbtMap, Pathing, FxEngine, Blit, GameIo, CharHlp, CbtActs, CombatSt, CombatAi, GameTime,
  Magic, ViewChar, MapTiles, EclTrace, Border, ClassCal, GDConsts, GDVars, C_Keys, C_Status,
  C_Ifc, C_Gbvm, C_Class;

const
  { Alt-Q and Alt-R, extended codes (the letter key's scan code) }
  ALT_Q = #16;
  ALT_R = #19;

procedure PrimeCombat;
begin
  ViewChar.PrimeViewChar;
  MenuCore.PrimeMenuCore;
  Pathing.PrimePathing;
  CbtMap.PrimeCbtMap;
  MapTiles.PrimeMapTiles;
  CharHlp.PrimeCharHlp;
  Magic.PrimeMagic;
  FxEngine.PrimeFxEngine;
  GameTime.PrimeGameTime;
  EclTrace.PrimeEclTrace;
  CombatSt.PrimeCombatSt;
  CbtActs.PrimeCbtActs;
  CombatAi.PrimeCombatAi;
  ClassCal.PrimeClassCal;
end;

procedure NextCreature(var next: Types.PCreature); forward;

procedure CreatureAction(cr: Types.PCreature); forward;

procedure ManualControl(cr: Types.PCreature); forward;

procedure CombatMenu(cr: Types.PCreature; var ch: Char); forward;

procedure EndOfRound(var done: Boolean); forward;

procedure MoveMenu(cr: Types.PCreature; firstCh: Char; var done: Boolean); forward;

procedure MeleeAttack(att, def: Types.PCreature; var done: Boolean); forward;

procedure DoneMenu(cr: Types.PCreature; var done: Boolean); forward;

procedure SpeedMenu; forward;

procedure TurnOnAuto(cr: Types.PCreature); forward;

{ Frees the stinking cloud and cloudkill lists, the arena and the combat effect sprite, restores the noncombat palette,
  and points the cast-target menu (GDVars.spellHandlers.castTargets) back at the noncombat one. }
procedure CombatDoneCleanup;
var
  p: Types.PCloudNode;
  { Unused in this version; see the other implementations of this routine. }
  nodeCount: Integer;
  { Unused in this version; see the other implementations of this routine. }
  effectScan: array[0..7] of Byte;
begin
  while GDVars.stinkHead <> nil do begin
    p := GDVars.stinkHead^.next;
    FreeMem(GDVars.stinkHead, SizeOf(GDVars.stinkHead^));
    GDVars.stinkHead := p;
  end;
  while GDVars.cloudkillHead <> nil do begin
    p := GDVars.cloudkillHead^.next;
    FreeMem(GDVars.cloudkillHead, SizeOf(GDVars.cloudkillHead^));
    GDVars.cloudkillHead := p;
  end;
  FreeMem(GDVars.combatArena, SizeOf(Types.TArena));
  GDVars.combatArena := nil;
  Blit.FreePic(GDVars.combatEffectSprite);
  CbtMap.SetNoncombatPalette;
  @GDVars.spellHandlers.castTargets := @Magic.NoncombatCastTargetMenu;
end;

procedure CombatMain;
var
  done: Boolean;
  cr: Types.PCreature;
begin
  GDVars.ifcState := C_Ifc.IN_COMBAT;
  @GDVars.spellHandlers.castTargets := @CbtActs.SelectCombatTargets;
  CombatSt.CombatStart;
  done := False;
  if (GDVars.teamCount[0] = 0) or (GDVars.teamCount[1] = 0) then
    done := True;
  while not done do begin
    CharHlp.CountTeams;
    cr := GDVars.partyHead;
    while cr <> nil do begin
      CbtActs.BeginRound(cr);
      cr := cr^.next;
    end;
    GDVars.zone1^[C_Gbvm.SURPRISE] := 0;
    Combat.NextCreature(cr);
    while cr <> nil do begin
      Combat.CreatureAction(cr);
      Combat.NextCreature(cr);
    end;
    Combat.EndOfRound(done);
  end;
  Combat.CombatDoneCleanup;
  GDVars.typingDelayOn := True;
end;

{ Picks the creature with the highest initiative to act next; ties go to the higher 1d100 roll, and a full tie to the
  later creature in the list.
  @param(next Receives the creature, or nil when no creature has initiative left.) }
procedure NextCreature(var next: Types.PCreature);
var
  best: Byte;
  bestRoll: Byte;
  roll: Byte;
  p: Types.PCreature;
begin
  best := 0;
  bestRoll := 0;
  p := GDVars.partyHead;
  while p <> nil do begin
    roll := FxEngine.RollDice(1, 100);
    if p^.combatAddr^.initiative > best then
      bestRoll := roll;
    if (p^.combatAddr^.initiative >= best) and (roll >= bestRoll) then begin
      bestRoll := roll;
      best := p^.combatAddr^.initiative;
      next := p;
    end;
    p := p^.next;
  end;
  if best = 0 then
    next := nil;
end;

{ Runs one creature's turn: resets its flanking counts and guard and fires its condition-7 effects. If it still has
  initiative (20 becomes 19), it becomes the current character, the map shows when it is friendly or a visible hostile,
  the view centers on it, its stats are recalculated and shown, and its condition-15 effects fire (and its condition-21
  effects when it is not casting). If initiative is still left, the AI (quick fight) or the player acts. Last, its cell
  is redrawn to erase the cursor.
  @param(cr The creature whose turn it is.) }
procedure CreatureAction(cr: Types.PCreature);
var
  { Unused in this version; see the other implementations of this routine. }
  initiative: Integer;
begin
  cr^.combatAddr^.flankCount := 0;
  cr^.combatAddr^.flankSpread := 0;
  cr^.combatAddr^.guarding := 0;
  FxEngine.TriggerEffectsWithCondition(7, cr);
  if cr^.combatAddr^.initiative <= 0 then
    Exit;
  if cr^.combatAddr^.initiative = 20 then
    cr^.combatAddr^.initiative := 19;
  GDVars.curChar := cr;
  GDVars.mapVisible := (cr^.hostile = 0) or CbtMap.CombatIconVisible(cr, 0);
  CbtMap.DisplayMapViewCentered(cr, 2, True);
  CharHlp.RecalcStats(cr);
  GDVars.combatRedraw := True;
  CharHlp.CombatPrintCreatureInfo(cr);
  FxEngine.TriggerEffectsWithCondition(15, cr);
  if cr^.combatAddr^.spellCast = 0 then
    FxEngine.TriggerEffectsWithCondition(21, cr);
  if cr^.combatAddr^.initiative > 0 then
    if cr^.quickfight <> 0 then
      CombatAi.CombatAiControl(cr)
    else
      Combat.ManualControl(cr);
  CbtMap.RedrawArenaCell(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr));
end;

{ Runs a player-controlled creature's turn. A disabled creature just ends its actions, and a spell begun earlier is cast
  now and ends them. Otherwise the combat menu repeats until an action ends the turn: Quick hands this creature to the
  AI, Move, View, Aim (attack), Use, Cast, Turn undead and Done do what they say, and Space takes each creature not
  flagged as an NPC off quick fight. The arrow keys and the diagonal keys move; Alt-M toggles quick magic, Alt-Q puts
  each creature on quick fight and gives this one initiative 20, and Alt-X tries the STING victory cheat.
  @param(cr The creature whose turn it is.) }
procedure ManualControl(cr: Types.PCreature);
var
  ch: Char;
  done: Boolean;
  p: Types.PCreature;
  { Unused in this version; see the other implementations of this routine. }
  aimInfo: array[1..3] of Byte;
  aimTgt: Pointer;
  spell: Byte;
begin
  if cr^.enabled <> 0 then begin
    if cr^.combatAddr^.spellCast > 0 then begin
      spell := cr^.combatAddr^.spellCast;
      cr^.combatAddr^.spellCast := 0;
      Magic.CastSpell(spell, False, True, done);
      done := CharHlp.EndActions(cr);
    end else begin
      done := False;
      while not done do begin
        Combat.CombatMenu(cr, ch);
        if not GDVars.menuExtendedKey then begin
          case ch of
            'Q': begin
                   Combat.TurnOnAuto(cr);
                   MenuCore.ClearBottomLine;
                   GameIo.DiscardPendingKeys;
                   Delay(200);
                   done := True;
                   CombatAi.CombatAiControl(cr);
                 end;
            'M': Combat.MoveMenu(cr, ' ', done);
            'V': begin
                   ViewChar.ViewCharMenu(done);
                   CbtActs.RecalcAttacksLeft(cr);
                   if done = False then
                     CharHlp.DisplayCombatInterface;
                 end;
            'A': CbtActs.CombatAimMenu(cr, 255, 1, 0, 1, done, aimTgt);
            'U': begin
                   GDVars.menuChoice := 2;
                   ViewChar.UseItemMenu(done);
                   CbtActs.RecalcAttacksLeft(cr);
                   if done = False then
                     CharHlp.DisplayCombatInterface;
                 end;
            'C': CbtActs.CastSpellCombat(0, 0, done);
            'T': begin
                   CbtActs.CombatTurnUndead(cr);
                   done := CharHlp.EndActions(cr);
                 end;
            'D': Combat.DoneMenu(cr, done);
            ' ': begin
                   p := GDVars.partyHead;
                   while p <> nil do begin
                     if p^.npc < $80 then
                       p^.quickfight := 0;
                     p := p^.next;
                   end;
                 end;
          end;
        end else begin
          case ch of
            C_Keys.UP, C_Keys.DOWN, C_Keys.RIGHT, C_Keys.LEFT, C_Keys.HOME, C_Keys.END_KEY,
                C_Keys.PAGE_DOWN, C_Keys.PAGE_UP:
              Combat.MoveMenu(cr, ch, done);
            C_Keys.ALT_M: begin
                    GDVars.quickMagic := GDVars.quickMagic = False;
                    if GDVars.quickMagic then
                      CharHlp.PrintBottomLine('Magic On')
                    else
                      CharHlp.PrintBottomLine('Magic Off');
                  end;
            Combat.ALT_Q: begin
                    cr^.combatAddr^.initiative := 20;
                    p := GDVars.partyHead;
                    while p <> nil do begin
                      Combat.TurnOnAuto(p);
                      p := p^.next;
                    end;
                    MenuCore.ClearBottomLine;
                    Delay(200);
                    done := True;
                  end;
            C_Keys.ALT_X: if CbtActs.VictoryCheat then begin
                    CbtMap.DisplayMapViewCentered(cr, 3, False);
                    done := True;
                  end else
                    CharHlp.PrintBottomLine('That doesn''t work');
          end;
        end;
        if done = False then begin
          CbtMap.DisplayMapViewCentered(cr, 2, True);
          GDVars.combatRedraw := True;
          CharHlp.CombatPrintCreatureInfo(cr);
        end;
      end;
    end;
  end else
    done := CharHlp.EndActions(cr);
end;

{ Builds the combat menu (Move while movement remains, View, Aim, Use with items, Cast with memorized spells when
  casting is allowed and the area has no anti-magic, Turn for a cleric who has not turned undead this battle, Quick,
  Done) and returns the first accepted key. Alt-R is accepted but ManualControl ignores it.
  @param(cr The creature whose turn it is.)
  @param(ch Receives the key; menuExtendedKey tells whether it is a scan code.) }
procedure CombatMenu(cr: Types.PCreature; var ch: Char);
var
  menu: String[40];
  i: Byte;
  hasSpell: Boolean;
begin
  menu := '';
  if cr^.combatAddr^.movement > 0 then
    menu := menu + 'Move ';
  menu := menu + 'View Aim ';
  if cr^.numberOfItems > 0 then
    menu := menu + 'Use ';
  hasSpell := False;
  for i := 0 to 83 do
    if cr^.memorizedSpells[i] > 0 then
      hasSpell := True;
  if hasSpell and (cr^.combatAddr^.castAllowed <> 0)
     and (GDVars.zone0^[C_Gbvm.ANTI_MAGIC] = 0) then
    menu := menu + 'Cast ';
  if ((cr^.classLevels[C_Class.CLERIC_LEVEL] > 0) or
      ((cr^.oldClassLevels[C_Class.CLERIC_LEVEL] > 0) and Boolean(ClassCal.EarlierClassActive(cr))))
     and (cr^.combatAddr^.usedTurnUndead = 0) then
    menu := menu + 'Turn ';
  menu := menu + 'Quick Done';
  repeat
    ch := MenuCore.MenuHorizontal('', menu, LightMagenta, LightGreen, White, True, False, hasSpell);
    if hasSpell then
      if not (ch in [Combat.ALT_Q, Combat.ALT_R, C_Keys.ALT_X, C_Keys.ALT_M, C_Keys.HOME,
                     C_Keys.UP, C_Keys.PAGE_UP, C_Keys.LEFT, C_Keys.RIGHT,
                     C_Keys.END_KEY, C_Keys.DOWN, C_Keys.PAGE_DOWN]) then
        ch := C_Keys.NONE;
  until ch in [Combat.ALT_Q, Combat.ALT_R, ' ', C_Keys.ALT_X, C_Keys.ALT_M, 'A', 'C', 'D', 'M', 'Q', 'T', 'U',
               'V', C_Keys.HOME, C_Keys.UP, C_Keys.PAGE_UP, C_Keys.LEFT, C_Keys.RIGHT, C_Keys.END_KEY,
               C_Keys.DOWN, C_Keys.PAGE_DOWN];
  MenuCore.ClearBottomLine;
end;

{ Ends a round: advances the clock, counts the round, refigures the hostiles' hit-point percentage, fires each
  creature's condition-19 effects and terrain effects, bleeds dying creatures (dead past overkill 9), warns when a party
  member is dying and rebuilds the view. The battle is done when a side is empty or the round limit is reached; when the
  party is left alone outside the demo, the player is asked whether to continue the battle.
  @param(done Set when the battle is over, and cleared when the player continues it; otherwise left as it was.) }
procedure EndOfRound(var done: Boolean);
var
  p: Types.PCreature;
  { Unused in this version; see the other implementations of this routine. }
  status: Byte;
  { Counts the party members walked; never read. }
  cnt: Byte;
begin
  GameTime.AdvanceTime(1, 1);
  Inc(GDVars.roundCounter);
  CbtActs.UpdateHostileHpPercent;
  p := GDVars.partyHead;
  cnt := 1;
  while p <> nil do begin
    FxEngine.TriggerEffectsWithCondition(19, p);
    FxEngine.ConsiderTerrainEffects(p, 0);
    if p^.status = C_Status.DYING then begin
      Inc(p^.combatAddr^.overkill);
      if p^.combatAddr^.overkill > 9 then
        p^.status := C_Status.DEAD_STATUS;
    end;
    Inc(cnt);
    p := p^.next;
  end;
  if CharHlp.BandageDying(False) then
    CharHlp.PrintBottomLine('Your Teammate is Dying');
  CharHlp.CountTeams;
  CbtMap.ScrollView(GDVars.combatArena^.focusX + 3, GDVars.combatArena^.focusY + 3, 255, 8);
  if (GDVars.teamCount[0] = 0) or (GDVars.teamCount[1] = 0) or (GDVars.roundCounter >= GDVars.combatTargetSlots[0]) then
    done := True;
  if (GDVars.teamCount[0] > 0) and (GDVars.teamCount[1] = 0) and not GDVars.demoMode then
    if MenuCore.YesNoMenu('Continue Battle:', LightMagenta, LightGreen, White) = 'Y' then
      done := False;
end;

{ Moves the creature with the arrow and diagonal keys, prompting with the movement left. Bumping a creature attacks it
  (MeleeAttack); stepping off the arena offers to flee; a step costing more than the movement left is refused. Each step
  allows opportunity attacks and terrain effects, and a creature left disabled or helpless ends its actions. Escape
  undoes the whole move; Enter, or movement below 2 half-steps, ends it, and movement below 2 is dropped.
  @param(cr The moving creature.)
  @param(firstCh The first key: a direction key, or a space to prompt for one.)
  @param(done Set when the creature's actions are over.) }
procedure MoveMenu(cr: Types.PCreature; firstCh: Char; var done: Boolean);
var
  savedMove: Byte;
  savedDir: Byte;
  startX: ShortInt;
  startY: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  slot: Integer;
  dir: Byte;
  crIdx: Byte;
  terrIdx: Byte;
  ch: Char;
  adjA: Byte;
  adjB: Byte;
  moveCost: Byte;
begin
  savedMove := cr^.combatAddr^.movement;
  savedDir := cr^.combatAddr^.direction;
  startX := CbtMap.CombatCellX(cr);
  startY := CbtMap.CombatCellY(cr);
  ch := firstCh;
  done := False;
  dir := 8;
  while (cr^.combatAddr^.movement > 1) and (ch <> C_Keys.NONE) and (ch <> C_Keys.ENTER) do begin
    Border.ClearBox(24, 24, 39, 24);
    if ch = ' ' then
      ch :=
        MenuCore.MenuHorizontal('Move/Attack, Move Left = ' + CharHlp.Uint8Str(cr^.combatAddr^.movement div 2) + ' ',
                                '', LightGreen, LightGreen, White, True, False, GDVars.combatMenuExtendedKey);
    case ch of
      C_Keys.NONE: begin
            cr^.combatAddr^.movement := savedMove;
            CbtMap.UpdateCombatMapTile(0, 0, CbtMap.CombatSlot(cr));
            done := CbtMap.IsValidCreatureLoc(cr, startX, startY, False) = False;
            CbtMap.ScrollView(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), 0, 8);
            cr^.combatAddr^.direction := savedDir;
            dir := 8;
          end;
      C_Keys.UP: dir := 0;
      C_Keys.PAGE_UP: dir := 1;
      C_Keys.RIGHT: dir := 2;
      C_Keys.PAGE_DOWN: dir := 3;
      C_Keys.DOWN: dir := 4;
      C_Keys.END_KEY: dir := 5;
      C_Keys.LEFT: dir := 6;
      C_Keys.HOME: dir := 7;
    else
      dir := 8;
    end;
    if dir < 8 then begin
      CbtMap.SetCreatureFacing(cr, dir, 0, 0);
      CbtMap.ProbeDirection(cr, dir, crIdx, terrIdx, adjA, adjB);
      if crIdx > 0 then
        Combat.MeleeAttack(cr, GDVars.combatCreatures[crIdx], done)
      else if terrIdx = 0 then begin
        case MenuCore.YesNoMenu('Flee:', LightMagenta, LightGreen, White) of
          'Y': done := CbtActs.AttemptFlee(cr);
          'N': done := False;
        end;
      end else begin
        if Odd(dir) then
          moveCost := GDConsts.terrainInfo[terrIdx].cost * 3
        else
          moveCost := GDConsts.terrainInfo[terrIdx].cost * 2;
        if GDConsts.terrainInfo[terrIdx].cost = 255 then
          moveCost := 255;
        if moveCost > cr^.combatAddr^.movement then
          CharHlp.PrintBottomLine('can''t go there')
        else begin
          CbtActs.AttacksOfOpportunity(cr, dir);
          if cr^.enabled = 0 then
            done := CharHlp.EndActions(cr)
          else begin
            if cr^.combatAddr^.movement > 0 then
              CbtActs.CombatMoveCreature(cr, dir);
            if cr^.enabled = 0 then
              done := CharHlp.EndActions(cr);
            FxEngine.ConsiderTerrainEffects(cr, 1);
            if CharHlp.IsHelpless(cr) then
              done := CharHlp.EndActions(cr);
          end;
        end;
      end;
    end;
    if (ch <> C_Keys.NONE) and (ch <> C_Keys.ENTER) then
      ch := ' ';
  end;
  if cr^.combatAddr^.movement < 2 then
    cr^.combatAddr^.movement := 0;
end;

{ Makes MoveMenu's bump attack: refused with a ranged weapon that is not throwable; otherwise, once CheckAttackAlly
  allows it, locks def as the target and tries a sweep before a normal attack.
  @param(att The attacker.)
  @param(def The creature bumped.)
  @param(done Set when the attack ends the attacker's actions.) }
procedure MeleeAttack(att, def: Types.PCreature; var done: Boolean);
begin
  if CharHlp.HasRangedWeapon(att) and not CharHlp.HasThrowableWeapon(att) then
    CharHlp.PrintBottomLine('Not with that weapon')
  else if CbtActs.CheckAttackAlly(att, def) then begin
    att^.combatAddr^.other := def;
    if CbtActs.SweepAttack(att, def) then
      done := True
    else begin
      CbtActs.NoteAttackDirection(att, def);
      CbtActs.MakeAttack(att, def, False, nil, done);
    end;
  end;
end;

{ Offers Guard (with a melee or throwable weapon), Delay (initiative 1, so the creature acts again later), Quit (end its
  actions), Bandage (while a party member is dying), Speed and Exit, until a choice ends the creature's actions or it
  leaves with Exit or Escape.
  @param(cr The creature whose turn it is.)
  @param(done Set when the choice ends the creature's actions.) }
procedure DoneMenu(cr: Types.PCreature; var done: Boolean);
var
  menu: String[40];
  ch: Char;
begin
  done := False;
  menu := '';
  if not CharHlp.HasRangedWeapon(cr) or CharHlp.HasThrowableWeapon(cr) then
    menu := menu + 'Guard ';
  menu := menu + 'Delay Quit ';
  if CharHlp.BandageDying(False) then
    menu := menu + 'Bandage ';
  menu := menu + 'Speed Exit';
  ch := ' ';
  while not (ch in [C_Keys.NONE, 'E']) and not done do
  begin
    ch := MenuCore.MenuHorizontal('', menu, LightMagenta, LightGreen, White, False, False,
                                  GDVars.combatMenuExtendedKey);
    case ch of
      'G': done := CharHlp.Guard(cr);
      'D': begin
             cr^.combatAddr^.initiative := 1;
             done := True;
           end;
      'Q': done := CharHlp.EndActions(cr);
      'B': begin
             done := CharHlp.BandageDying(True);
             done := CharHlp.EndActions(cr);
           end;
      'S': Combat.SpeedMenu;
    end;
  end;
end;

{ Adjusts the game delay: Slower (offered below 9) raises it, Faster (offered above 0) lowers it, and Exit or Escape
  leaves. }
procedure SpeedMenu;
var
  menu: String[40];
  query: String[40];
  ch: Char;
begin
  ch := ' ';
  while not (ch in [C_Keys.NONE, 'E']) do
  begin
    query := 'GameSpeed (' + CharHlp.Uint8Str(GDVars.gameDelay) + ') :';
    menu := ' ';
    if GDVars.gameDelay < 9 then
      menu := menu + 'Slower ';
    if GDVars.gameDelay > 0 then
      menu := menu + 'Faster ';
    menu := menu + 'Exit';
    ch := MenuCore.MenuHorizontal(query, menu, LightMagenta, LightGreen, White, False, False,
                                  GDVars.combatMenuExtendedKey);
    case ch of
      'S': Inc(GDVars.gameDelay);
      'F': Dec(GDVars.gameDelay);
    end;
  end;
end;

{ Puts a creature on quick fight and drops a locked target on its own side.
  @param(cr The creature to hand to the AI.) }
procedure TurnOnAuto(cr: Types.PCreature);
begin
  cr^.quickfight := 1;
  if (cr^.combatAddr^.other <> nil)
     and (cr^.combatAddr^.other^.hostile = cr^.hostile) then begin
    cr^.combatAddr^.other := nil;
  end;
end;

begin
end.
