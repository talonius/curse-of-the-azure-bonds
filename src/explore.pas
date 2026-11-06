{ Party movement in the 3D view: the exploration menu, turning and stepping, leaving the map, and locked doors (bash,
  pick, knock). }
{$O+,F+}
unit Explore;

interface

{ Takes the step the exploration menu asked for, in the 3D view and unless zone 1 locks movement (the lock is then
  cleared). An open side is walked through. A locked door (feature 2) offers Bash, Pick (with a thief in the party) and
  Knock (with the spell memorized), each while the door's options (lockOptions) still allow it, and is walked through on
  success; a wizard-locked door (feature 3) offers the same, but choosing Pick just takes it off the menu. With nothing
  to offer it calls ChangeBarrierImpassable, which does nothing. Afterwards the portrait animation and both portraits
  are freed. Note: Knock lets the party through without unlocking the door. }
procedure ResolveMovement;

{ Clears zone 1's movement lock, then runs the exploration menu in the 3D view until a command ends it: Area toggles the
  automap (where the map allows it, or with the developer keyword), Cast (for a character in good health) and View open
  their menus, Encamp leaves, Search toggles search mode, and Look searches once and points the script at its after-move
  entry (2). Up arrow checks the step ahead (MoveForward) and leaves; down arrow turns around, left and right arrows
  turn; other extended keys change the current character. On the overland map it shows no menu. Then the text window is
  cleared unless it already is. Note: on the overland map the result is never set.
  @returns(The key that ended the menu: E for Encamp, L for Look, the up arrow's scan code for a step.) }
function MapMainMenu: Char;

{ Calls the priming entries of FxEngine, CharHlp, ViewChar, MapView, SaveLoad, MapTiles, Portrait, GameTime, MenuCore,
  ClassCal and the trace overlay, so the overlay manager loads them; the other overlays this unit uses are not primed
  here. }
procedure PrimeExplore;

implementation

uses FxEngine, ClassCal, CharHlp, Types, MenuCore, Portrait, TextRend, GameTime, SoundDrv, Crt, Blit, ViewChar, Camp,
  View3D, MapView, SaveLoad, MapTiles, EclTrace, Border, GDConsts, GDVars,
  C_Keys, C_Status, C_Stat, C_Gbvm;

procedure PrimeExplore;
begin
  FxEngine.PrimeFxEngine;
  CharHlp.PrimeCharHlp;
  ViewChar.PrimeViewChar;
  MapView.PrimeMapView;
  SaveLoad.PrimeSaveLoad;
  MapTiles.PrimeMapTiles;
  Portrait.PrimePortrait;
  GameTime.PrimeGameTime;
  EclTrace.PrimeEclTrace;
  MenuCore.PrimeMenuCore;
  ClassCal.PrimeClassCal;
end;

{ Meant to make a cell side impassable by clearing its door feature. Note: it exits first, so it does nothing.
  @param(x The map column.)
  @param(y The map row.)
  @param(facing The side: 0, 2, 4 or 6.) }
procedure ChangeBarrierImpassable(x, y, facing: ShortInt);
begin
  Exit;
  case Byte(facing) of
    6: GDVars.map3d^.feat[y, x] := GDVars.map3d^.feat[y, x] and $3F;
    4: GDVars.map3d^.feat[y, x] := GDVars.map3d^.feat[y, x] and $CF;
    2: GDVars.map3d^.feat[y, x] := GDVars.map3d^.feat[y, x] and $F3;
    0: GDVars.map3d^.feat[y, x] := GDVars.map3d^.feat[y, x] and $FC;
  end;
end;

{ Sets the door feature of a cell side to 1, open; cells off the 16x16 map are ignored.
  @param(x The map column.)
  @param(y The map row.)
  @param(facing The side: 0, 2, 4 or 6.) }
procedure ChangeBarrierPassable(x, y, facing: ShortInt);
begin
  if (x < 0) or (x > 15) or (y < 0) or (y > 15) then Exit;
  case Byte(facing) of
    6: GDVars.map3d^.feat[y, x] := GDVars.map3d^.feat[y, x] and $3F or $40;
    4: GDVars.map3d^.feat[y, x] := GDVars.map3d^.feat[y, x] and $CF or $10;
    2: GDVars.map3d^.feat[y, x] := GDVars.map3d^.feat[y, x] and $F3 or $4;
    0: GDVars.map3d^.feat[y, x] := GDVars.map3d^.feat[y, x] and $FC or $1;
  end;
end;

{ Tells whether a party member has levels in a class; levels in an earlier class count while ClassCal.EarlierClassActive
  allows.
  @param(idx The class.)
  @returns(True when a member has levels in it.) }
function PartyHasClass(idx: ShortInt): Boolean;
var
  p: Types.PCreature;
  found: Boolean;
begin
  found := False;
  p := GDVars.partyHead;
  while (p <> nil) and (not found) do begin
    if (p^.classLevels[idx] > 0) or
        ((p^.oldClassLevels[idx] > 0) and (ClassCal.EarlierClassActive(p) <> 0)) then
      found := True;
    p := p^.next;
  end;
  PartyHasClass := found;
end;

{ Each party member in turn tries to bash the door ahead until one succeeds, the chance set by Strength and exceptional
  Strength. A wizard-locked door (feature 3) needs 18/91 or more, and a weaker member's try removes Bash from the door's
  menu (stronger members after it still try); an ordinary locked door can be bashed from Strength 3. On success the wall
  opens from both sides.
  @returns(True when the door opened.) }
function BashDoor: Boolean;
var
  p: Types.PCreature;
  success: Boolean;
begin
  success := False;
  p := GDVars.partyHead;
  while (p <> nil) and (not success) do begin
    with p^ do begin
      if View3D.GetBarrierType(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing) = 3 then begin
        case stats[C_Stat.STRENGTH].current of
          18: case exStrCur of
                 91..99: if FxEngine.RollDice(1, 6) = 1 then success := True;
                 100: if FxEngine.RollDice(1, 6) <= 2 then success := True;
               else
                 GDVars.lockOptions[0] := False;
               end;
          19, 20: if FxEngine.RollDice(1, 6) <= 3 then success := True;
          21, 22: if FxEngine.RollDice(1, 6) <= 4 then success := True;
          23: if FxEngine.RollDice(1, 6) <= 5 then success := True;
          24: if FxEngine.RollDice(1, 8) <= 7 then success := True;
          25: success := True;
        else
          GDVars.lockOptions[0] := False;
        end;
      end else
        case stats[C_Stat.STRENGTH].current of
          3..7: if FxEngine.RollDice(1, 6) = 1 then success := True;
          8..15: if FxEngine.RollDice(1, 6) <= 2 then success := True;
          16..17: if FxEngine.RollDice(1, 6) <= 3 then success := True;
          18: case exStrCur of
                 0..50: if FxEngine.RollDice(1, 6) <= 3 then success := True;
                 51..99: if FxEngine.RollDice(1, 6) <= 4 then success := True;
                 100: if FxEngine.RollDice(1, 6) <= 5 then success := True;
               end;
          19, 20: if FxEngine.RollDice(1, 8) <= 7 then success := True;
          21: if FxEngine.RollDice(1, 10) <= 9 then success := True;
          22, 23: if FxEngine.RollDice(1, 12) <= 11 then success := True;
          24: if FxEngine.RollDice(1, 20) <= 19 then success := True;
          25: success := True;
        end;
    end;
    p := p^.next;
  end;
  if success then begin
    Explore.ChangeBarrierPassable(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
    Explore.ChangeBarrierPassable(GDVars.partyPos.mapX + GDConsts.directionDx[GDVars.partyPos.facing],
                                  GDVars.partyPos.mapY + GDConsts.directionDy[GDVars.partyPos.facing],
                                  (GDVars.partyPos.facing + 4) mod 8);
  end;
  BashDoor := success;
end;

{ Each party member in good health tries the lock-picking thief skill (a d100) until one succeeds; Pick is then removed
  from the door's menu either way. On success the wall opens from both sides.
  @returns(True when the lock was picked.) }
function PickLock: Boolean;
var
  p: Types.PCreature;
  success: Boolean;
begin
  success := False;
  p := GDVars.partyHead;
  while (p <> nil) and (not success) do begin
    with p^ do
      if (FxEngine.RollDice(1, 100) <= thiefSkills[2]) and (status = C_Status.OKAY) then
        success := True;
    p := p^.next;
  end;
  GDVars.lockOptions[1] := False;
  if success then begin
    Explore.ChangeBarrierPassable(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
    Explore.ChangeBarrierPassable(GDVars.partyPos.mapX + GDConsts.directionDx[GDVars.partyPos.facing],
                                  GDVars.partyPos.mapY + GDConsts.directionDy[GDVars.partyPos.facing],
                                  (GDVars.partyPos.facing + 4) mod 8);
  end;
  PickLock := success;
end;

{ Finds a spell among a creature's memorized spells.
  @param(spellId The spell.)
  @param(creature The creature.)
  @returns(The slot, 0 to 83, or 255 when it is not memorized.) }
function FindMemorizedSpell(spellId: Byte; creature: Types.PCreature): Byte;
var
  i: Byte;
begin
  i := 0;
  while (i <= 83) and (creature^.memorizedSpells[i] <> spellId) do
    Inc(i);
  if i <= 83 then
    FindMemorizedSpell := i
  else
    FindMemorizedSpell := 255;
end;

{ Finds the first party member with a spell memorized.
  @param(spellId The spell.)
  @returns(That member, or nil.) }
function FindCharWithSpell(spellId: Byte): Types.PCreature;
var
  p: Types.PCreature;
begin
  p := GDVars.partyHead;
  while (p <> nil) and (Explore.FindMemorizedSpell(spellId, p) = 255) do
    p := p^.next;
  FindCharWithSpell := p;
end;

{ Has the first party member with Knock (spell 31) memorized cast it, using the spell up; the wall itself is not
  changed.
  @returns(True when someone could cast it.) }
function PartyCastsKnock: Boolean;
var
  p: Types.PCreature;
begin
  p := Explore.FindCharWithSpell(31);
  if p <> nil then begin
    p^.memorizedSpells[Explore.FindMemorizedSpell(31, p)] := 0;
    PartyCastsKnock := True;
  end else
    PartyCastsKnock := False;
end;

{ Checks the step the party faces: clears zone 1's leave-map word, then sets it when that side is not solid (feature
  other than 0, locked doors included) and the step would leave the 16x16 map; the party stays on its edge cell. The
  step itself comes later, in ResolveMovement. }
procedure MoveForward;
var
  nx: Integer;
  ny: Integer;
  f: Integer;
begin
  nx := GDVars.partyPos.mapX;
  ny := GDVars.partyPos.mapY;
  f := GDVars.partyPos.facing;
  GDVars.zone1^[C_Gbvm.LEAVE_MAP] := 0;
  if View3D.GetBarrierType(nx, ny, f) <> 0 then begin
    Inc(nx, GDConsts.directionDx[f]);
    Inc(ny, GDConsts.directionDy[f]);
    if nx > 15 then begin
      GDVars.partyPos.mapX := 15;
      GDVars.zone1^[C_Gbvm.LEAVE_MAP] := 1;
    end;
    if nx < 0 then begin
      GDVars.partyPos.mapX := 0;
      GDVars.zone1^[C_Gbvm.LEAVE_MAP] := 1;
    end;
    if ny > 15 then begin
      GDVars.partyPos.mapY := 15;
      GDVars.zone1^[C_Gbvm.LEAVE_MAP] := 1;
    end;
    if ny < 0 then begin
      GDVars.partyPos.mapY := 0;
      GDVars.zone1^[C_Gbvm.LEAVE_MAP] := 1;
    end;
  end;
end;

{ Steps the party one cell the way it faces with a footstep sound, wrapping around the 16x16 map, refreshes the wall
  ahead and the cell event, resets the door options, and advances the clock (AdvanceTime(1, 1), or (1, 2) while
  searching). }
procedure MovePartyForward3D;
begin
  SoundDrv.SoundCommand(GDConsts.sndFootstep);
  Delay(50);
  Inc(GDVars.partyPos.mapX, GDConsts.directionDx[GDVars.partyPos.facing]);
  Inc(GDVars.partyPos.mapY, GDConsts.directionDy[GDVars.partyPos.facing]);
  if GDVars.partyPos.mapX < 0 then GDVars.partyPos.mapX := 15;
  if GDVars.partyPos.mapX > 15 then GDVars.partyPos.mapX := 0;
  if GDVars.partyPos.mapY < 0 then GDVars.partyPos.mapY := 15;
  if GDVars.partyPos.mapY > 15 then GDVars.partyPos.mapY := 0;
  GDVars.partyPos.wallAhead := View3D.GetWallType(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
  FillChar(GDVars.lockOptions, SizeOf(GDVars.lockOptions), 1);
  GDVars.partyPos.eventAtCell := View3D.GetMapEvent(GDVars.partyPos.mapX, GDVars.partyPos.mapY);
  if GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] and 1 > 0 then
    GameTime.AdvanceTime(1, 2)
  else
    GameTime.AdvanceTime(1, 1);
end;

function MapMainMenu: Char;
var
  done: Boolean;
  c: Char;
  ext: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  s: String[40];
  vflag: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  oldZone: Pointer;
begin
  GDVars.zone1^[C_Gbvm.MOVE_LOCK] := 0;
  case Char(GDVars.ifcState) of
  { 3D view }
  #4: begin
    done := False;
    repeat
      c := MenuCore.MenuHorizontal('', GDConsts.menu3D, LightMagenta, LightGreen, White, True, False, ext);
      if not ext then begin
        case c of
          'A': if (GDVars.zone0^[C_Gbvm.NO_AUTOMAP] = 0) or (ParamStr(2) = GDVars.commandText) then begin
                 GDVars.automapOn := GDVars.automapOn = False;
                 View3D.Display3DMapView(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
               end else
                 TextRend.PrintAndPause('Not Here', Yellow, 0);
          'C': if GDVars.curChar^.status = C_Status.OKAY then begin
                 GDVars.menuChoice := 1;
                 Camp.NoncombatCastMenu;
               end;
          'V': begin
                 GDVars.menuChoice := 1;
                 ViewChar.ViewCharMenu(vflag);
               end;
          'E': begin
                 done := True;
                 GDVars.menuChoice := 1;
               end;
          'S': GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] := GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] xor 1;
          'L': begin
                 GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] := GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] or 2;
                 GameTime.AdvanceTime(1, 2);
                 GDVars.eclIp := GDVars.vmRun[2];
                 done := True;
               end;
        end;
      end else begin
        case c of
          C_Keys.UP: begin
                 Explore.MoveForward;
                 done := True;
               end;
          C_Keys.DOWN: begin
                 GDVars.partyPos.facing := (GDVars.partyPos.facing + 4) mod 8;
                 GDVars.partyPos.wallAhead := View3D.GetWallType(GDVars.partyPos.mapX, GDVars.partyPos.mapY,
                                                                 GDVars.partyPos.facing);
                 View3D.Display3DMapView(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
               end;
          C_Keys.LEFT: begin
                 GDVars.partyPos.facing := (GDVars.partyPos.facing + 6) mod 8;
                 SoundDrv.SoundCommand(GDConsts.sndFootstep);
                 GDVars.partyPos.wallAhead := View3D.GetWallType(GDVars.partyPos.mapX, GDVars.partyPos.mapY,
                                                                 GDVars.partyPos.facing);
                 View3D.Display3DMapView(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
               end;
          C_Keys.RIGHT: begin
                 GDVars.partyPos.facing := (GDVars.partyPos.facing + 2) mod 8;
                 SoundDrv.SoundCommand(GDConsts.sndFootstep);
                 GDVars.partyPos.wallAhead := View3D.GetWallType(GDVars.partyPos.mapX, GDVars.partyPos.mapY,
                                                                 GDVars.partyPos.facing);
                 View3D.Display3DMapView(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
               end;
        else begin
          ViewChar.SelectPrevNextChar(c);
          CharHlp.DisplayParty(GDVars.curChar);
        end;
        end;
      end;
      CharHlp.PrintPositionAndTime;
    until done;
    end;
  { overland }
  #3: ;
  end;
  if not GDVars.bottomMessageCleared then begin
    Border.ClearBox(1, 17, 38, 22);
    GDVars.bottomMessageCleared := True;
  end;
  MapMainMenu := c;
end;

procedure ResolveMovement;
var
  moved: Boolean;
  isExtended: Boolean;
  menuStr: String[40];
  lockedKey: Char;
begin
  moved := False;
  case Char(GDVars.ifcState) of
  { 3D view }
  #4:
    if GDVars.zone1^[C_Gbvm.MOVE_LOCK] < 255 then begin
      GDVars.mapRedrawPending := 1;
      case View3D.GetBarrierType(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing) of
        1: moved := True;
        2: begin
             menuStr[0] := #0;
             if GDVars.lockOptions[0] then
               menuStr := 'Bash';
             if GDVars.lockOptions[1] and Explore.PartyHasClass(6) then
               menuStr := menuStr + ' Pick';
             if GDVars.lockOptions[2] and (Explore.FindCharWithSpell(31) <> nil) then
               menuStr := menuStr + ' Knock';
             menuStr := menuStr + ' Exit';
             if menuStr = ' Exit' then
               Explore.ChangeBarrierImpassable(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing)
             else begin
               lockedKey := MenuCore.MenuHorizontal('Locked. ', menuStr, LightMagenta, LightGreen, White, False, False,
                                                    isExtended);
               case lockedKey of
                 'B': moved := Explore.BashDoor;
                 'P': moved := Explore.PickLock;
                 'K': moved := Explore.PartyCastsKnock;
               end;
             end;
           end;
        3: begin
             menuStr[0] := #0;
             if GDVars.lockOptions[0] then
               menuStr := 'Bash';
             if GDVars.lockOptions[1] and Explore.PartyHasClass(6) then
               menuStr := menuStr + ' Pick';
             if GDVars.lockOptions[2] and (Explore.FindCharWithSpell(31) <> nil) then
               menuStr := menuStr + ' Knock';
             menuStr := menuStr + ' Exit';
             if menuStr = ' Exit' then
               Explore.ChangeBarrierImpassable(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing)
             else begin
               lockedKey := MenuCore.MenuHorizontal('Locked. ', menuStr, LightMagenta, LightGreen, White, False, False,
                                                    isExtended);
               case lockedKey of
                 'B': moved := Explore.BashDoor;
                 'P': GDVars.lockOptions[1] := False;
                 'K': moved := Explore.PartyCastsKnock;
               end;
             end;
           end;
      end;
      if moved then
        Explore.MovePartyForward3D;
      CharHlp.PrintPositionAndTime;
    end else
      GDVars.zone1^[C_Gbvm.MOVE_LOCK] := 0;
  end;
  Portrait.FreeAnimation(GDVars.animData);
  Blit.FreePic(GDVars.portraits[1].pic);
  Blit.FreePic(GDVars.portraits[2].pic);
  GDVars.portraits[1].fileId := 255;
  GDVars.portraits[2].fileId := 255;
end;

{ Does nothing. }
procedure NoopExplore;
begin
end;

begin
end.
