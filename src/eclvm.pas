{ The ECL script interpreter and the exploration loop: one routine per script command, the dispatcher, and the loop that
  runs a map's scripts around each move. }
{$O+,F+,I-}
unit EclVm;

interface

{ Runs exploration. Loads the area's script (the saved one, or script 1, or script $52 while the demo runs) unless
  re-entering a saved map, initializes it and runs its load entry (5). In the demo it then removes the whole party and
  returns. Otherwise, until the party is defeated or the game halts: the map menu takes a command; while search mode is
  on or Encamp is chosen, each search runs the after-move entry (2) in search mode and Encamp runs the camp (EnterCamp),
  and the menu asks again; then the before-move entry (1) runs, the party moves (Explore.ResolveMovement) with a
  footstep when it changed cells, and the after-move entry (2) runs. Script switches are followed through NewEclDone. }
procedure GameLoop;

{ Calls the priming entries of ViewChar, Portrait, MapTiles, GameTime, MenuCore, SaveLoad, FxEngine, Explore, CharHlp,
  MapView, EclMenu, Money, EclTrace, ClassCal and CopyProt, so the overlay manager loads them; the combat, shop, temple,
  camp, map-view and character-creation overlays are primed by the commands that enter them. }
procedure PrimeEclVm;

implementation

uses EclMenu, CharHlp, TextRend, MapTiles, View3D, CharGen, Types, ViewChar, Portrait, GameTime, MenuCore, SaveLoad,
  FxEngine, Explore, MapView, Money, EclTrace, ClassCal, CopyProt, SoundDrv, Crt, Border, GameIo, DaxIo, Combat,
  CombatSt, CombatAi, CbtActs, CbtMap, Pathing, PostCbt, Shop, Camp, Temple, Ending, MapCurs, GDConsts, GDVars, C_Class,
  C_Status, C_Ecl, C_Ifc, C_Pic, C_Gbvm;

const
  { Script variables the interpreter reads and writes by address: word indices into the GBVM banks, GDVars.zone0^ for
    the game's global state and GDVars.zone1^ for the current area's. }
  { Global word: the first area graphics word. While it and AREA_GRAPHICS_2 are both nonzero, LOAD PIECES loads wall-set
    slots 1 and 3 and leaves slot 2 as it is. }
  AREA_GRAPHICS_1 = $4BE7;
  { Global word: the second area graphics word, read with AREA_GRAPHICS_1. }
  AREA_GRAPHICS_2 = $4BE8;
  { Global word: the party's column before its last step; GameLoop plays a footstep when the step changed it. }
  PRE_MOVE_X = $4BF0;
  { Global word: the party's row before its last step, read with PRE_MOVE_X. }
  PRE_MOVE_Y = $4BF1;
  { Area word: the monster distance SETUP MONSTER and ENCOUNTER MENU ask for; the distance used is cut to the open cells
    ahead. }
  MONSTER_DIST_REQUEST = $7EC0;
  { Area word: 1 makes COMBAT, with no monsters loaded and no duel, enter the temple; COMBAT clears it. }
  ENTER_TEMPLE = $7EE2;
  { Area word: the remainder of the last DIVIDE. }
  DIVIDE_REMAINDER = $7F3F;
  { Area word: 1 makes COMBAT, with no monsters loaded and no duel, enter the shop; COMBAT clears it. }
  ENTER_SHOP = $7F6C;

type
  { A creature as SPELL searches it: the bytes before its memorized spells, then the spell slots and what follows
    them. }
  PSpellRec = ^TSpellRec;
  TSpellRec = record
    nameAndAbilities: array[0..$1D] of Byte;
    spells: array[0..102] of Byte;
  end;

  { Icon-set file name that LOAD MONSTER passes to MapTiles.LoadIconAnim. }
  TStr12 = String[12];

procedure CallEclScript(address: Word); forward;

procedure PrimeEclVm;
begin
  ViewChar.PrimeViewChar;
  Portrait.PrimePortrait;
  MapTiles.PrimeMapTiles;
  GameTime.PrimeGameTime;
  MenuCore.PrimeMenuCore;
  SaveLoad.PrimeSaveLoad;
  FxEngine.PrimeFxEngine;
  Explore.PrimeExplore;
  CharHlp.PrimeCharHlp;
  MapView.PrimeMapView;
  EclMenu.PrimeEclMenu;
  Money.PrimeMoney;
  EclTrace.PrimeEclTrace;
  ClassCal.PrimeClassCal;
  CopyProt.PrimeCopyProt;
end;

{ EXIT: redraws after a protection message, restores the current character if LOAD CHARACTER changed it, clears the
  monster and graphics flags, stops the interpreter, frees the GOSUB stack and resets the text cursor. }
procedure EclExit;
begin
  if GDVars.protShown then Border.DrawViewFrame;
  if GDVars.restoreChar then begin
    GDVars.curChar := GDVars.savedChar;
    GDVars.restoreChar := False;
  end;
  FillChar(GDVars.encounterMonsterFlags, SizeOf(GDVars.encounterMonsterFlags), 0);
  GDVars.eclGraphics := False;
  GDVars.protShown := False;
  GDVars.eclStop := True;
  Inc(GDVars.eclIp);
  while GDVars.scriptReturnStack <> nil do begin
    GDVars.prevScriptReturnStack := GDVars.scriptReturnStack^.next;
    FreeMem(GDVars.scriptReturnStack, SizeOf(GDVars.scriptReturnStack^));
    GDVars.scriptReturnStack := GDVars.prevScriptReturnStack;
  end;
  GDVars.curRow := 17;
  GDVars.curCol := 1;
  GDVars.boxCleared := False;
end;

{ GOTO: jumps to the address in its argument. }
procedure EclGoto;
begin
  EclMenu.LoadEclVars(1);
  GDVars.eclIp := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
end;

{ GOSUB: pushes the return address and jumps to the address in its argument. }
procedure EclGosubCmd;
begin
  EclMenu.LoadEclVars(1);
  EclMenu.EclGosub(1);
end;

{ COMPARE: sets the comparison flags from its two arguments, as strings when either is a string, else as numbers. }
procedure EclCompare;
var
  lhs: Word;
  rhs: Word;
  lhsStr: String;
  rhsStr: String;
begin
  EclMenu.LoadEclVars(2);
  if (GDVars.varTypes[1] >= $80) or (GDVars.varTypes[2] >= $80) then begin
    lhsStr := GDVars.scriptStrings[1];
    rhsStr := GDVars.scriptStrings[2];
    EclMenu.EclCompareStr(lhsStr, rhsStr);
  end else begin
    lhs := EclMenu.GetEclVar(1);
    rhs := EclMenu.GetEclVar(2);
    EclMenu.EclCompareInt(lhs, rhs);
  end;
end;

{ ADD, SUBTRACT, DIVIDE, MULTIPLY: stores v1 + v2, v2 - v1, v1 div v2 (the remainder going to zone 1) or v1 * v2 at the
  third argument's address. }
procedure EclArithmetic;
var
  address: Word;
  v: array[1..2] of Word;
  i: ShortInt;
  r: Word;
begin
  EclMenu.LoadEclVars(3);
  for i := 1 to 2 do
    v[i] := EclMenu.GetEclVar(i);
  address := EclMenu.CombineBytesToWord(GDVars.varLo[3], GDVars.varHi[3]);
  case GDVars.scriptOpcode of
    C_Ecl.ADD: r := v[1] + v[2];
    C_Ecl.SUBTRACT: r := v[2] - v[1];
    C_Ecl.DIVIDE: begin
         r := v[1] div v[2];
         GDVars.zone1^[EclVm.DIVIDE_REMAINDER] := v[1] mod v[2];
       end;
    C_Ecl.MULTIPLY: r := v[1] * v[2];
  end;
  EclMenu.WriteGbvm(address, r);
end;

{ RANDOM: stores a random number 0..n (0..254 when n is 255) at the second argument's address. }
procedure EclRandom;
var
  n: Byte;
  roll: Byte;
  address: Word;
begin
  EclMenu.LoadEclVars(2);
  n := EclMenu.GetEclVar(1);
  if n < 255 then Inc(n);
  address := EclMenu.CombineBytesToWord(GDVars.varLo[2], GDVars.varHi[2]);
  roll := Trunc(Random(n));
  EclMenu.WriteGbvm(address, roll);
end;

{ SAVE: stores the first argument, a number or a string, at the second argument's address. }
procedure EclSave;
var
  v: Word;
  address: Word;
begin
  EclMenu.LoadEclVars(2);
  address := EclMenu.CombineBytesToWord(GDVars.varLo[2], GDVars.varHi[2]);
  if GDVars.varTypes[1] < $80 then begin
    v := EclMenu.GetEclVar(1);
    EclMenu.WriteGbvm(address, v);
  end else
    EclMenu.WriteGbvmString(address, GDVars.scriptStrings[1]);
end;

{ LOAD CHARACTER: makes party member idx (low 7 bits, from 0) the current character, or sets the character-not-found
  flag; EXIT restores the previous one. With bit 7 set and both dump flags raised, the character is removed from the
  party. }
procedure EclLoadCharacter;
var
  p: Types.PCreature;
  { Unused in this version; see the other implementations of this routine. }
  savedIdx: Byte;
  idx: Byte;
  i: Byte;
  highBit: Byte;
begin
  GDVars.restoreChar := True;
  EclMenu.LoadEclVars(1);
  i := 0;
  idx := EclMenu.GetEclVar(1);
  p := GDVars.partyHead;
  highBit := idx and $80;
  idx := idx and $7F;
  if idx > 0 then
    while (i < idx) and (p <> nil) do begin
      p := p^.next;
      Inc(i);
    end;
  if p <> nil then begin
    GDVars.curChar := p;
    GDVars.characterNotFound := 0;
  end else
    GDVars.characterNotFound := 1;
  if (highBit <> 0) and GDVars.dumpOnStatusClear and GDVars.dumpOnNameClear then begin
    if GDVars.savedChar = GDVars.curChar then
      GDVars.restoreChar := False;
    CharGen.RemoveCreature(False, True);
    CharHlp.DisplayParty(GDVars.curChar);
    GDVars.dumpOnStatusClear := False;
    GDVars.dumpOnNameClear := False;
  end;
end;

{ SETUP MONSTER: records the encounter's monster and picture and its distance (the requested one, cut to the open cells
  ahead), and shows it. }
procedure EclSetupMonster;
var
  { Unused in this version; see the other implementations of this routine. }
  distance: Byte;
begin
  EclMenu.LoadEclVars(3);
  GDVars.encMonsterId := EclMenu.GetEclVar(1);
  GDVars.zone1^[EclVm.MONSTER_DIST_REQUEST] := EclMenu.GetEclVar(2);
  GDVars.encMonsterPic := EclMenu.GetEclVar(3);
  GDVars.zone1^[C_Gbvm.MONSTER_DIST] := EclMenu.MaxMonsterDist(GDVars.partyPos.mapX, GDVars.partyPos.mapY,
                                                               GDVars.partyPos.facing);
  if GDVars.zone1^[EclVm.MONSTER_DIST_REQUEST] < GDVars.zone1^[C_Gbvm.MONSTER_DIST] then
    GDVars.zone1^[C_Gbvm.MONSTER_DIST] := GDVars.zone1^[EclVm.MONSTER_DIST_REQUEST];
  EclMenu.DisplayMonster(GDVars.encMonsterId, GDVars.encMonsterPic, Byte(GDVars.zone1^[C_Gbvm.MONSTER_DIST]),
                         GDVars.encounterMonsterFlags);
end;

{ LOAD MONSTER: appends count (at least 1) copies of creature id to the creature list with icon set CPIC picId in the
  next icon slot, stopping at 63 monsters loaded. The extra copies get their own copies of the items and effects (in
  reverse order). }
procedure EclLoadMonster;
var
  id: Byte;
  count: Byte;
  picId: Byte;
  i: Byte;
  p: Types.PCreature;
  q: Types.PCreature;
  cr: Types.PCreature;
  savedCur: Types.PCreature;
  tmpl: Types.TCreature;
  nm: TStr12;
  it: Types.PItem;
  tmpIt: Types.PItem;
  invHead: Types.PItem;
  ef: Types.PEffect;
  tmpEf: Types.PEffect;
  effHead: Types.PEffect;
begin
  savedCur := GDVars.curChar;
  i := 1;
  EclMenu.LoadEclVars(3);
  if GDVars.monsterCount >= 63 then Exit;
  p := nil;
  q := nil;
  id := EclMenu.GetEclVar(1);
  EclMenu.InitCreature(id, Pointer(cr), Pointer(it), Pointer(ef));
  tmpl := cr^;
  invHead := it;
  effHead := ef;
  count := EclMenu.GetEclVar(2);
  if count <= 0 then count := 1;
  picId := EclMenu.GetEclVar(3);
  p := GDVars.partyHead;
  nm := 'CPIC';
  MapTiles.LoadIconAnim(nm, picId, GDVars.iconAnimId);
  while p^.next <> nil do
    p := p^.next;
  p^.next := cr;
  p := p^.next;
  p^.orderNumber := GDVars.iconAnimId;
  p^.next := nil;
  Inc(GDVars.monsterCount);
  Inc(i);
  while (i <= count) and (GDVars.monsterCount < 63) do begin
    GetMem(q, SizeOf(Types.TCreature));
    p^.next := q;
    p := p^.next;
    p^ := tmpl;
    p^.orderNumber := GDVars.iconAnimId;
    p^.next := nil;
    p^.effects := nil;
    p^.itemsAddr := nil;
    Inc(i);
    Inc(GDVars.monsterCount);
    while it <> nil do begin
      if p^.itemsAddr = nil then begin
        GetMem(p^.itemsAddr, SizeOf(Types.TItem));
        p^.itemsAddr^ := it^;
        p^.itemsAddr^.next := nil;
      end else begin
        tmpIt := p^.itemsAddr;
        GetMem(p^.itemsAddr, SizeOf(Types.TItem));
        p^.itemsAddr^ := it^;
        p^.itemsAddr^.next := tmpIt;
      end;
      it := it^.next;
    end;
    it := invHead;
    while ef <> nil do begin
      if p^.effects = nil then begin
        GetMem(p^.effects, SizeOf(Types.TEffect));
        p^.effects^ := ef^;
        p^.effects^.next := nil;
      end else begin
        tmpEf := p^.effects;
        GetMem(p^.effects, SizeOf(Types.TEffect));
        p^.effects^ := ef^;
        p^.effects^.next := tmpEf;
      end;
      ef := ef^.next;
    end;
    ef := effHead;
  end;
  Inc(GDVars.iconAnimId);
  GDVars.monstersLoaded := True;
  GDVars.curChar := savedCur;
end;

{ APPROACH: brings the monster one cell closer and shows it again. }
procedure EclApproach;
begin
  if GDVars.zone1^[C_Gbvm.MONSTER_DIST] > 0 then begin
    Dec(GDVars.zone1^[C_Gbvm.MONSTER_DIST]);
    EclMenu.DisplayMonster(GDVars.encMonsterId, GDVars.encMonsterPic, GDVars.zone1^[C_Gbvm.MONSTER_DIST],
                           GDVars.encounterMonsterFlags);
  end;
  Inc(GDVars.eclIp);
end;

{ PICTURE: shows picture picId (a full-screen picture from $78 up, else a PIC animation, or a portrait when a portrait
  head is set in zone 1). $FF clears it, redrawing the map cell when a picture or sprite was shown. }
procedure EclPicture;
var
  picId: Byte;
begin
  EclMenu.LoadEclVars(1);
  picId := EclMenu.GetEclVar(1);
  if picId <> 255 then begin
    GDVars.encounterMonsterFlags[1] := True;
    GDVars.eclGraphics := True;
    if GDVars.zone1^[C_Gbvm.PORTRAIT_HEAD] = 255 then begin
      GDVars.picDrawn := True;
      if picId >= 120 then begin
        Portrait.LoadBigPic(picId);
        Portrait.DisplayBigPic;
        GDVars.mapRedrawPending := 0;
      end else begin
        Portrait.LoadAnimation('PIC', picId, 0, GDVars.animData);
        Portrait.DisplayImageBuf(3, 3, True, GDVars.animData.frames[1].pic);
      end;
    end else
      EclMenu.DisplayPortrait(Byte(GDVars.zone1^[C_Gbvm.PORTRAIT_HEAD]), picId);
  end else begin
    if ((GDVars.prevIfcState <> C_Ifc.VIEW_3D) or (GDVars.ifcState = C_Ifc.VIEW_3D)) and
        (GDVars.eclGraphics or GDVars.spriteShown) then begin
      GDVars.mapRedrawPending := 1;
      MapView.DisplayMapView;
      GDVars.eclGraphics := False;
      GDVars.spriteShown := False;
      GDVars.picDrawn := True;
    end;
    GDVars.encounterMonsterFlags[0] := False;
    GDVars.encounterMonsterFlags[1] := False;
  end;
end;

{ INPUT NUMBER: reads a number from the player into the second argument's address. }
procedure EclInputNumber;
var
  q: String[1];
  v: Word;
  address: Word;
begin
  EclMenu.LoadEclVars(2);
  q := '';
  address := EclMenu.CombineBytesToWord(GDVars.varLo[2], GDVars.varHi[2]);
  v := TextRend.ReadNumber(q, LightGreen, 0);
  EclMenu.WriteGbvm(address, v);
end;

{ INPUT STRING: reads up to 40 characters into the second argument's address; an empty answer is stored as one space. }
procedure EclInputString;
var
  q: String[1];
  address: Word;
  s: String;
begin
  EclMenu.LoadEclVars(2);
  q := '';
  address := EclMenu.CombineBytesToWord(GDVars.varLo[2], GDVars.varHi[2]);
  s := TextRend.ReadString(q, LightGreen, 0, 40);
  if s = '' then s := ' ';
  EclMenu.WriteGbvmString(address, s);
end;

{ PRINT and PRINTCLEAR: prints the argument (a number in decimal) in the message window; PRINT continues where the text
  left off, PRINTCLEAR clears the window first. }
procedure EclPrint;
begin
  EclMenu.LoadEclVars(1);
  GDVars.bottomMessageCleared := False;
  GDVars.typingDelayOn := True;
  if GDVars.varTypes[1] < $80 then
    GDVars.scriptStrings[1] := CharHlp.Uint16Str(EclMenu.GetEclVar(1));
  if GDVars.scriptOpcode = C_Ecl.PRINT then
    TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, False, GDVars.scriptStrings[1])
  else begin
    GDVars.curRow := 17;
    GDVars.curCol := 1;
    TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, True, GDVars.scriptStrings[1]);
  end;
  GDVars.typingDelayOn := False;
end;

{ RETURN: pops the GOSUB stack, or ends the script (EclExit) when it is empty. }
procedure EclReturn;
begin
  Inc(GDVars.eclIp);
  if GDVars.scriptReturnStack <> nil then begin
    GDVars.eclIp := GDVars.scriptReturnStack^.addr;
    GDVars.prevScriptReturnStack := GDVars.scriptReturnStack^.next;
    FreeMem(GDVars.scriptReturnStack, SizeOf(GDVars.scriptReturnStack^));
    GDVars.scriptReturnStack := GDVars.prevScriptReturnStack;
  end else
    EclVm.EclExit;
end;

{ COMPARE AND: sets the equal flag when v1 = v2 and v3 = v4, else the not-equal flag. }
procedure EclCompareAnd;
var
  v: array[1..4] of Word;
  i: Byte;
begin
  FillChar(GDVars.cmpFlags, SizeOf(GDVars.cmpFlags), 0);
  EclMenu.LoadEclVars(4);
  for i := 1 to 4 do
    v[i] := EclMenu.GetEclVar(i);
  if (v[1] = v[2]) and (v[3] = v[4]) then
    GDVars.cmpFlags[0] := True
  else
    GDVars.cmpFlags[1] := True;
end;

{ IF =, <>, <, >, <=, >=: skips the next command unless the matching comparison flag is set. }
procedure EclIf;
begin
  Inc(GDVars.eclIp);
  case GDVars.scriptOpcode of
    C_Ecl.IF_EQ: if not GDVars.cmpFlags[0] then EclMenu.SkipEclCmd;
    C_Ecl.IF_NE: if not GDVars.cmpFlags[1] then EclMenu.SkipEclCmd;
    C_Ecl.IF_LT: if not GDVars.cmpFlags[2] then EclMenu.SkipEclCmd;
    C_Ecl.IF_GT: if not GDVars.cmpFlags[3] then EclMenu.SkipEclCmd;
    C_Ecl.IF_LE: if not GDVars.cmpFlags[4] then EclMenu.SkipEclCmd;
    C_Ecl.IF_GE: if not GDVars.cmpFlags[5] then EclMenu.SkipEclCmd;
  end;
end;

{ NEWECL: remembers the current script, loads and initializes script id, and stops the current one so the caller runs
  the new one. }
procedure EclNewEcl;
var
  newId: Byte;
begin
  EclMenu.LoadEclVars(1);
  GDVars.zone0^[C_Gbvm.PREV_SCRIPT] := GDVars.currentScriptId;
  newId := EclMenu.GetEclVar(1);
  GDVars.currentScriptId := newId;
  EclMenu.LoadEclScript(newId);
  EclMenu.EclInit;
  GDVars.eclStop := True;
  GDVars.newEclFlag := True;
  FillChar(GDVars.encounterMonsterFlags, SizeOf(GDVars.encounterMonsterFlags), 0);
end;

{ LOAD FILES and LOAD PIECES. LOAD FILES loads the 3D map (argument 1, in the 3D view) and, when argument 3 is not $FF,
  the overland picture $79 (outdoors, unless the village picture, PIC 80, is loaded). LOAD PIECES loads the wall sets
  into slots 1..3 (argument 1 = $7F loads set 0 into slot 1 alone; with both area graphics words set, slots 1 and 3 load
  and slot 2 is left as it is; otherwise $FF marks a slot unused). Once both are loaded after leaving the overland map,
  the 3D screen is redrawn. }
procedure EclLoadFiles;
var
  f: array[1..3] of Byte;
  i: Byte;
begin
  EclMenu.LoadEclVars(3);
  GDVars.filesLoaded := True;
  for i := 1 to 3 do
    f[i] := EclMenu.GetEclVar(i);
  if GDVars.scriptOpcode = C_Ecl.LOAD_FILES then begin
    GDVars.mapLoaded := True;
    if (f[1] <> 255) and (f[1] <> $7F) and (GDVars.zone0^[C_Gbvm.VIEW_3D] <> 0) then begin
      GDVars.zone0^[C_Gbvm.GEO_MAP_ID] := f[1];
      View3D.Load3DMap(f[1]);
      GDVars.zone1^[C_Gbvm.MOVE_LOCK] := 0;
    end;
    if (f[3] <> 255) and (GDVars.zone0^[C_Gbvm.VIEW_3D] = 0) and (GDVars.loadedPicId <> C_Pic.VILLAGE) then
      Portrait.LoadBigPic(C_Pic.BIGPIC_OVERLAND);
  end else begin
    GDVars.piecesLoaded := True;
    if f[1] = $7F then
      View3D.LoadWallSet(0, 1)
    else if (GDVars.zone0^[EclVm.AREA_GRAPHICS_1] <> 0) and (GDVars.zone0^[EclVm.AREA_GRAPHICS_2] <> 0) then begin
      if f[1] <> 255 then
        View3D.LoadWallSet(f[1], 1);
      if f[3] <> 255 then
        View3D.LoadWallSet(f[3], 3);
    end else
      for i := 1 to 3 do
        if f[i] <> 255 then
          View3D.LoadWallSet(f[i], i)
        else begin
          GDVars.wallDefinitions[i].wallDefId := 65535;
          GDVars.wallDefinitions[i].symbolSlot := 65535;
        end;
  end;
  if GDVars.piecesLoaded and GDVars.mapLoaded and (GDVars.prevIfcState = C_Ifc.OVERLAND) then begin
    if (GDVars.ifcState <> C_Ifc.OVERLAND) and (GDVars.charSelectActive <> 0) then begin
      Border.DrawViewFrame;
      CharHlp.DisplayParty(GDVars.curChar);
      CharHlp.PrintPositionAndTime;
    end;
    GDVars.charSelectActive := 0;
  end;
end;

{ AND and OR: stores lhs and rhs or lhs or rhs (as a byte) at the third argument's address and sets the comparison flags
  from comparing 0 with it. }
procedure EclAndOr;
var
  address: Word;
  rhs: Word;
  lhs: Word;
  r: Byte;
begin
  EclMenu.LoadEclVars(3);
  lhs := EclMenu.GetEclVar(1);
  rhs := EclMenu.GetEclVar(2);
  address := EclMenu.CombineBytesToWord(GDVars.varLo[3], GDVars.varHi[3]);
  if GDVars.scriptOpcode = C_Ecl.OP_AND then
    r := lhs and rhs
  else
    r := lhs or rhs;
  EclMenu.EclCompareInt(0, r);
  EclMenu.WriteGbvm(address, r);
end;

{ GETTABLE: copies the GBVM word at base + idx to the third argument's address. }
procedure EclGetTable;
var
  base: Word;
  dest: Word;
  sum: Word;
  v: Word;
  idx: Byte;
begin
  EclMenu.LoadEclVars(3);
  base := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  idx := EclMenu.GetEclVar(2);
  dest := EclMenu.CombineBytesToWord(GDVars.varLo[3], GDVars.varHi[3]);
  sum := idx + base;
  v := EclMenu.ReadGbvm(sum);
  EclMenu.WriteGbvm(dest, v);
end;

{ SAVE TABLE: writes v to the GBVM word at base + idx. }
procedure EclSaveTable;
var
  idx: Word;
  address: Word;
  v: Word;
  sum: Word;
begin
  EclMenu.LoadEclVars(3);
  v := EclMenu.GetEclVar(1);
  address := EclMenu.CombineBytesToWord(GDVars.varLo[2], GDVars.varHi[2]);
  idx := EclMenu.GetEclVar(3);
  sum := address + idx;
  EclMenu.WriteGbvm(sum, v);
end;

{ VERTICAL MENU: prints the message, lists count option strings, and stores the chosen option's index (from 0) at the
  first argument's address. }
procedure EclVMenu;
var
  count: Byte;
  i: Byte;
  msg: String;
  list: Types.PItem;
  head: Types.PItem;
  q: String[1];
  idx: Integer;
  redraw: Boolean;
  address: Word;
begin
  GDVars.bottomMessageCleared := False;
  redraw := True;
  q := '';
  i := 1;
  EclMenu.LoadEclVars(3);
  address := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  msg := GDVars.scriptStrings[1];
  count := EclMenu.GetEclVar(3);
  Dec(GDVars.eclIp);
  EclMenu.LoadEclVars(count);
  MenuCore.AllocStringList(count, list);
  head := list;
  GDVars.curCol := 1;
  GDVars.curRow := 17;
  TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, True, msg);
  while list <> nil do begin
    list^.name := GDVars.scriptStrings[i];
    list^.inUse := 0;
    list := list^.next;
    Inc(i);
  end;
  list := head;
  idx := 0;
  EclMenu.EclVerticalMenu(q, q, 13, 10, 15, 1, GDVars.curRow + 1, 38, 22, list, False, redraw, idx, list);
  EclMenu.WriteGbvm(address, idx);
  MenuCore.FreeStringList(list);
  TextRend.ClearRect(1, 17, 38, 22);
end;

{ HORIZONTAL MENU: offers count option strings as hotkeys and stores the chosen index at the first argument's address. A
  single option also accepts Enter, and its stock 'PRESS BUTTON OR RETURN' text is replaced. }
procedure EclHMenu;
var
  count: Byte;
  ch: Byte;
  i: Byte;
  q: String[1];
  menu: String[50];
  address: Word;
  enterOk: Boolean;
  anim: Boolean;
  hlCol: Byte;
  mCol: Byte;
begin
  q := '';
  menu := '';
  EclMenu.LoadEclVars(2);
  address := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  count := EclMenu.GetEclVar(2);
  Dec(GDVars.eclIp);
  EclMenu.LoadEclVars(count);
  menu := '';
  if count = 1 then begin
    enterOk := True;
    hlCol := 15;
    mCol := 15;
    if GDVars.scriptStrings[1] = 'PRESS BUTTON OR RETURN TO CONTINUE.' then
      GDVars.scriptStrings[1] := 'PRESS <ENTER>/<RETURN> TO CONTINUE';
  end else begin
    enterOk := False;
    hlCol := 15;
    mCol := 10;
  end;
  anim := GDVars.eclGraphics and GDVars.picDrawn;
  for i := 1 to count - 1 do
    menu := menu + '~' + GDVars.scriptStrings[i] + ' ';
  menu := menu + '~' + GDVars.scriptStrings[count];
  ch := EclMenu.MenuHorizontalCharacterSelect(q, menu, LightMagenta, mCol, hlCol, enterOk, anim);
  EclMenu.WriteGbvm(address, ch);
  TextRend.ClearRect(0, 24, 39, 24);
end;

{ CLEARMONSTERS: forgets the loaded monsters (the next icon slot is 8 again), clears the treasure money and frees the
  treasure items. }
procedure EclClearMonsters;
var
  next: Types.PItem;
  { Unused in this version; see the other implementations of this routine. }
  slotIdx: Byte;
begin
  Inc(GDVars.eclIp);
  GDVars.monsterCount := 0;
  GDVars.monstersLoaded := False;
  GDVars.iconAnimId := 8;
  FillChar(GDVars.treasureMoney, SizeOf(GDVars.treasureMoney), 0);
  while GDVars.treasureItems <> nil do begin
    next := GDVars.treasureItems^.next;
    FreeMem(GDVars.treasureItems, SizeOf(GDVars.treasureItems^));
    GDVars.treasureItems := next;
  end;
end;

{ PARTYSTRENGTH: stores the party's strength: for each member (hit points + 5 per point of stored AC above 60
  + 5 per point of stored THAC0 above 39 + 8 per magic-user level + 4 per cleric level) div 10, summed into a byte. }
procedure EclPartyStrength;
var
  hp: Byte;
  th: Byte;
  mage: Byte;
  cleric: Byte;
  ac: Byte;
  strength: Byte;
  address: Word;
  p: Types.PCreature;
begin
  EclMenu.LoadEclVars(1);
  strength := 0;
  p := GDVars.partyHead;
  while p <> nil do begin
    hp := p^.hpCur;
    ac := p^.acCur[0];
    th := p^.thac0Cur;
    mage := p^.classLevels[C_Class.MAGE_LEVEL] +
      p^.oldClassLevels[C_Class.MAGE_LEVEL] * ClassCal.EarlierClassActive(p);
    cleric := p^.classLevels[C_Class.CLERIC_LEVEL] +
        p^.oldClassLevels[C_Class.CLERIC_LEVEL] * ClassCal.EarlierClassActive(p);
    if ac > 60 then
      ac := ac - 60
    else
      ac := 0;
    if th > 39 then
      th := th - 39
    else
      th := 0;
    Inc(strength, (cleric * 4 + (hp + ac * 5 + th * 5 + mage * 8)) div 10);
    p := p^.next;
  end;
  address := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  EclMenu.WriteGbvm(address, strength);
end;

{ CHECKPARTY: by attribute key, writes the party's minimum, maximum and average of a thief skill or of movement, or (key
  0) whether any member has effect effId, to the four result addresses. Other keys write nothing. }
procedure EclCheckParty;
var
  attr: Integer;
  sum: Integer;
  effId: Byte;
  p: Types.PCreature;
  found: Byte;
  eff: Types.PEffect;
  outv: array[1..3] of Byte;
  minAddr: Word;
  maxAddr: Word;
  avgAddr: Word;
  foundAddr: Word;
  count: Byte;
  idx: Byte;

  { Writes the minimum, maximum, average and found flag to the four result addresses. }
  procedure Write4Gbvm;
  begin
    EclMenu.WriteGbvm(minAddr, outv[1]);
    EclMenu.WriteGbvm(maxAddr, outv[2]);
    EclMenu.WriteGbvm(avgAddr, outv[3]);
    EclMenu.WriteGbvm(foundAddr, ShortInt(found));
  end;

begin
  EclMenu.LoadEclVars(6);
  p := GDVars.partyHead;
  found := 0;
  if GDVars.varTypes[1] = 1 then
    attr := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1])
  else
    attr := EclMenu.GetEclVar(1);
  effId := EclMenu.GetEclVar(2);
  minAddr := EclMenu.CombineBytesToWord(GDVars.varLo[3], GDVars.varHi[3]);
  maxAddr := EclMenu.CombineBytesToWord(GDVars.varLo[4], GDVars.varHi[4]);
  avgAddr := EclMenu.CombineBytesToWord(GDVars.varLo[5], GDVars.varHi[5]);
  foundAddr := EclMenu.CombineBytesToWord(GDVars.varLo[6], GDVars.varHi[6]);
  sum := 0;
  count := 0;
  outv[1] := 255;
  outv[2] := 0;
  Dec(attr, $7FFF);
  case attr of
    -32767: begin
      while (p <> nil) and (found = 0) do begin
        found := Byte(CharHlp.HasEffect(p, effId, eff));
        p := p^.next;
      end;
      FillChar(outv, SizeOf(outv), 0);
      Write4Gbvm;
    end;
    $A5..$AC: begin
      idx := attr - $A4;
      while p <> nil do begin
        Inc(count);
        if p^.thiefSkills[idx] < outv[1] then
          outv[1] := p^.thiefSkills[idx];
        if p^.thiefSkills[idx] > outv[2] then
          outv[2] := p^.thiefSkills[idx];
        Inc(sum, p^.thiefSkills[idx]);
        p := p^.next;
      end;
      outv[3] := sum div count;
      Write4Gbvm;
    end;
    $9F: begin
      while p <> nil do begin
        Inc(count);
        if p^.movementCur < outv[1] then
          outv[1] := p^.movementCur;
        if p^.movementCur > outv[2] then
          outv[2] := p^.movementCur;
        Inc(sum, p^.movementCur);
        p := p^.next;
      end;
      outv[3] := sum div count;
      Write4Gbvm;
    end;
  end;
end;

{ PARTY SURPRISE: writes 1 to the first address when a ranger (or cleric/ranger) is in the party, else 0, and 0 to the
  second. }
procedure EclPartySurprise;
var
  p: Types.PCreature;
  partySurprise: Byte;
  monsterSurprise: Byte;
  { Unused in this version; see the other implementations of this routine. }
  hasRanger: Byte;
  partyAddr: Word;
  monsterAddr: Word;
begin
  EclMenu.LoadEclVars(2);
  p := GDVars.partyHead;
  partySurprise := 0;
  monsterSurprise := 0;
  hasRanger := 0;
  while p <> nil do begin
    if (p^.charClass = C_Class.RANGER) or (p^.charClass = C_Class.CLERIC_RANGER) then begin
      partySurprise := 1;
      hasRanger := 1;
    end;
    p := p^.next;
  end;
  partyAddr := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  monsterAddr := EclMenu.CombineBytesToWord(GDVars.varLo[2], GDVars.varHi[2]);
  EclMenu.WriteGbvm(partyAddr, partySurprise);
  EclMenu.WriteGbvm(monsterAddr, monsterSurprise);
end;

{ SURPRISE: rolls a d6 for each side against v4 + 2 - v1 and v2 + 2 - v3 and writes which side is surprised (1 or 2, 0
  when neither is) to a fixed script address. Note: the final test overrides the both-sides result 3, and the address
  lies outside the GBVM banks where WriteGbvm stores nothing, so the result is lost. }
procedure EclSurprise;
var
  rollA: Byte;
  rollB: Byte;
  i: Byte;
  result: Byte;
  v: array[1..4] of Byte;
  needA: ShortInt;
  needB: ShortInt;
begin
  EclMenu.LoadEclVars(4);
  result := 0;
  for i := 1 to 4 do
    v[i] := EclMenu.GetEclVar(i);
  needA := v[4] + 2 - v[1];
  needB := v[2] + 2 - v[3];
  rollA := FxEngine.RollDice(1, 6);
  rollB := FxEngine.RollDice(1, 6);
  if rollA <= needA then
    if rollB <= needB then
      result := 3
    else
      result := 1;
  if rollB <= needB then
    result := 2;
  EclMenu.WriteGbvm($2CB, result);
end;

{ COMBAT: with no monsters loaded (and no duel) enters the shop or temple when ENTER_SHOP or ENTER_TEMPLE is 1, else the
  treasure screen; otherwise fights the battle and then shows the treasure screen. Afterwards it reloads the view
  overlays, resets the interface state, search mode and monster flags, and redraws the screen. }
procedure EclCombat;
var
  dist: Word;
begin
  Inc(GDVars.eclIp);
  if not GDVars.monstersLoaded and not GDVars.duelFlag then begin
    if GDVars.zone1^[EclVm.ENTER_SHOP] = 1 then begin
      GDVars.zone1^[EclVm.ENTER_SHOP] := 0;
      if GDVars.soundActive then SoundDrv.SoundCommand(GDConsts.sndShutdown);
      Shop.PrimeShop;
      if not GDVars.soundActive then SoundDrv.StartSound;
      Shop.ShopMainMenu;
      if GDVars.zone0^[C_Gbvm.VIEW_3D] = 0 then begin
        if GDVars.soundActive then SoundDrv.SoundCommand(GDConsts.sndShutdown);
        MapCurs.PrimeMapCurs;
        if not GDVars.soundActive then SoundDrv.StartSound;
      end else begin
        if GDVars.soundActive then SoundDrv.SoundCommand(GDConsts.sndShutdown);
        View3D.PrimeView3D;
        if not GDVars.soundActive then SoundDrv.StartSound;
      end;
    end else if GDVars.zone1^[EclVm.ENTER_TEMPLE] = 1 then begin
      GDVars.zone1^[EclVm.ENTER_TEMPLE] := 0;
      if GDVars.soundActive then SoundDrv.SoundCommand(GDConsts.sndShutdown);
      Temple.PrimeTemple;
      if not GDVars.soundActive then SoundDrv.StartSound;
      Temple.TempleMainMenu;
      if GDVars.zone0^[C_Gbvm.VIEW_3D] = 0 then begin
        if GDVars.soundActive then SoundDrv.SoundCommand(GDConsts.sndShutdown);
        MapCurs.PrimeMapCurs;
        if not GDVars.soundActive then SoundDrv.StartSound;
      end else begin
        if GDVars.soundActive then SoundDrv.SoundCommand(GDConsts.sndShutdown);
        View3D.PrimeView3D;
        if not GDVars.soundActive then SoundDrv.StartSound;
      end;
    end else begin
      if GDVars.soundActive then SoundDrv.SoundCommand(GDConsts.sndShutdown);
      PostCbt.PrimePostCbt;
      if not GDVars.soundActive then SoundDrv.StartSound;
      PostCbt.PostCombat;
      if GDVars.zone0^[C_Gbvm.VIEW_3D] = 0 then begin
        if GDVars.soundActive then SoundDrv.SoundCommand(GDConsts.sndShutdown);
        MapCurs.PrimeMapCurs;
        if not GDVars.soundActive then SoundDrv.StartSound;
      end else begin
        if GDVars.soundActive then SoundDrv.SoundCommand(GDConsts.sndShutdown);
        View3D.PrimeView3D;
        if not GDVars.soundActive then SoundDrv.StartSound;
      end;
    end;
  end else begin
    if GDVars.soundActive then SoundDrv.SoundCommand(GDConsts.sndShutdown);
    Combat.PrimeCombat;
    CombatSt.PrimeCombatSt;
    CombatAi.PrimeCombatAi;
    CbtActs.PrimeCbtActs;
    CbtMap.PrimeCbtMap;
    Pathing.PrimePathing;
    if not GDVars.soundActive then SoundDrv.StartSound;
    dist := EclMenu.MaxMonsterDist(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
    if dist < GDVars.zone1^[C_Gbvm.MONSTER_DIST] then
      GDVars.zone1^[C_Gbvm.MONSTER_DIST] := dist;
    Combat.CombatMain;
    if GDVars.soundActive then SoundDrv.SoundCommand(GDConsts.sndShutdown);
    PostCbt.PrimePostCbt;
    PostCbt.PostCombat;
    if not GDVars.soundActive then SoundDrv.StartSound;
    if GDVars.zone0^[C_Gbvm.VIEW_3D] = 0 then begin
      if GDVars.soundActive then SoundDrv.SoundCommand(GDConsts.sndShutdown);
      MapCurs.PrimeMapCurs;
      if not GDVars.soundActive then SoundDrv.StartSound;
      Portrait.LoadBigPic(C_Pic.BIGPIC_OVERLAND);
    end else begin
      if GDVars.soundActive then SoundDrv.SoundCommand(GDConsts.sndShutdown);
      View3D.PrimeView3D;
      if not GDVars.soundActive then SoundDrv.StartSound;
    end;
    if GDVars.duelFlag then
      GDVars.duelFlag := False;
  end;
  if GDVars.zone0^[C_Gbvm.VIEW_3D] <> 0 then
    GDVars.ifcState := C_Ifc.VIEW_3D
  else
    GDVars.ifcState := C_Ifc.OVERLAND;
  GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] := GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] and 1;
  FillChar(GDVars.encounterMonsterFlags, SizeOf(GDVars.encounterMonsterFlags), 0);
  GDVars.eclGraphics := False;
  CharHlp.DisplayNoncombatInterface;
end;

{ ON GOTO and ON GOSUB: jumps to (or calls) target sel of count; nothing happens when sel is out of range. }
procedure EclOnGoto;
var
  sel: Byte;
  count: Byte;
  { Unused in this version; see the other implementations of this routine. }
  target: Byte;
  i: Byte;
  found: Byte;
begin
  found := 0;
  EclMenu.LoadEclVars(2);
  sel := EclMenu.GetEclVar(1);
  count := EclMenu.GetEclVar(2);
  Dec(GDVars.eclIp);
  EclMenu.LoadEclVars(count);
  i := 0;
  while (i < count) and (found = 0) do begin
    if sel = i then begin
      if GDVars.scriptOpcode = C_Ecl.ON_GOTO then
        GDVars.eclIp := EclMenu.CombineBytesToWord(GDVars.varLo[i + 1], GDVars.varHi[i + 1])
      else
        EclMenu.EclGosub(i + 1);
      found := 1;
    end else
      Inc(i);
  end;
end;

{ TREASURE: sets the treasure money from the first seven arguments. The eighth adds items: below $80 a block of
  ITEM<disk>.DAX (quitting if it is missing), $80 + n that many random items, whose display names are then built, and
  $FF adds nothing. Note: the random-item ranges 86..92 and 91..98 overlap, so rolls of 91 and 92 take the first. }
procedure EclTreasure;
var
  i: ShortInt;
  tId: Byte;
  j: Byte;
  { Unused in this version; see the other implementations of this routine. }
  treasureMsg: String[22];
  it: Types.TItem;
  tmp: Types.PItem;
  walk: Types.PItem;
  roll3: Byte;
  roll: Byte;
  roll2: Byte;
  itemId: Byte;
  offset: Word;
  sizeRead: Word;
  s: String[1];
  data: Types.PByteArr;
begin
  EclMenu.LoadEclVars(8);
  for i := 0 to 6 do
    GDVars.treasureMoney[i] := EclMenu.GetEclVar(Byte(i) + 1);
  tId := EclMenu.GetEclVar(8);
  if tId < $80 then begin
    Str(GDVars.diskIndex, s);
    DaxIo.LoadDax('ITEM' + s, '.dax', tId, sizeRead, data);
    if sizeRead = 0 then begin
      TextRend.DisplayAndPause(White, 0, 'Unable to find item file');
      GameIo.ExitGame;
    end;
    offset := 0;
    repeat
      Move(data^[offset], it, SizeOf(it));
      it.next := nil;
      Inc(offset, SizeOf(it));
      if GDVars.treasureItems = nil then begin
        GetMem(GDVars.treasureItems, SizeOf(Types.TItem));
        GDVars.treasureItems^ := it;
      end else begin
        tmp := GDVars.treasureItems;
        GetMem(GDVars.treasureItems, SizeOf(Types.TItem));
        GDVars.treasureItems^ := it;
        GDVars.treasureItems^.next := tmp;
      end;
    until offset >= sizeRead;
    FreeMem(data, sizeRead);
  end else begin
    if tId = 255 then Exit;
    i := tId - $80;
    for j := 1 to i do begin
      roll := FxEngine.RollDice(1, 100);
      case roll of
        1..60: begin
          roll2 := FxEngine.RollDice(1, 100);
          case roll2 of
            1..47, 50..59:
              if roll2 = 45 then
                itemId := 59
              else
                itemId := roll2;
            60..90: begin
              roll2 := FxEngine.RollDice(1, 10);
              case roll2 of
                1..4: itemId := 36;
                5..7: itemId := 35;
                8: itemId := 34;
                9: itemId := 37;
                10: itemId := 38;
              end;
            end;
            91..94: itemId := 73;
            95..97: itemId := 93;
            98..100: itemId := 77;
          else
            itemId := 59;
          end;
        end;
        61..85: itemId := 61;
        86..92: itemId := 62;
        91..98: begin
          roll3 := FxEngine.RollDice(1, 15);
          case roll3 of
            1..9: itemId := 71;
            10: itemId := 84;
            11..15: itemId := 79;
          end;
        end;
        99, 100: itemId := 59;
      end;
      Money.GenerateRandomItem(itemId, it);
      if GDVars.treasureItems = nil then begin
        GetMem(GDVars.treasureItems, SizeOf(Types.TItem));
        GDVars.treasureItems^ := it;
        GDVars.treasureItems^.next := nil;
      end else begin
        tmp := GDVars.treasureItems;
        GetMem(GDVars.treasureItems, SizeOf(Types.TItem));
        GDVars.treasureItems^ := it;
        GDVars.treasureItems^.next := tmp;
      end;
    end;
    walk := GDVars.treasureItems;
    while walk <> nil do begin
      CharHlp.PrintItemString(GDVars.curChar, walk, 0, 0, False, False);
      walk := walk^.next;
    end;
  end;
end;

{ ROB: takes the given percentage of money and robs items with the given chance, from the current character (first
  argument 0) or the whole party. }
procedure EclRob;
var
  whole: Byte;
  pct: Byte;
  chance: Byte;
  p: Types.PCreature;
  { Unused in this version; see the other implementations of this routine. }
  inv: Types.PItem;
  fraction: Real;
begin
  EclMenu.LoadEclVars(3);
  whole := EclMenu.GetEclVar(1);
  pct := EclMenu.GetEclVar(2);
  fraction := (100 - pct) / 100;
  chance := EclMenu.GetEclVar(3);
  if whole = 0 then begin
    EclMenu.RobMoney(fraction, GDVars.curChar);
    EclMenu.RobItems(chance, GDVars.curChar);
  end else begin
    p := GDVars.partyHead;
    while p <> nil do begin
      inv := p^.itemsAddr;
      EclMenu.RobMoney(fraction, p);
      EclMenu.RobItems(chance, p);
      p := p^.next;
    end;
  end;
end;

{ ENCOUNTER MENU: shows the monster at its distance with the message for that distance and offers Combat, Wait, Flee and
  Parlay (Advance while still far off in the 3D view). The script's response for the chosen option, and the party's
  slowest and fastest movement against the two flee values (arguments 13 and 14), decide the result written to the
  result address (1 fight, 2 the party flees, 0 the monsters flee, 3 parlay); waiting or advancing repeats the menu. }
procedure EclEncounter;
var
  sel: Byte;
  resp: array[0..4] of Byte;
  msgs: array[1..3] of String;
  msg: String;
  fleePar: Byte;
  fleeMon: Byte;
  i: Byte;
  hiMove: Byte;
  loMove: Byte;
  waited: Boolean;
  clearW: Boolean;
  anim: Boolean;
  menu: String[40];
  q: String[1];
  choice: Byte;
  k: Byte;
  address: Word;
begin
  GDVars.inEncMenu := True;
  GDVars.bottomMessageCleared := False;
  GDVars.typingDelayOn := True;
  EclMenu.MoveExtremes(hiMove, loMove);
  q := '';
  EclMenu.LoadEclVars(14);
  GDVars.encMonsterId := EclMenu.GetEclVar(1);
  GDVars.zone1^[EclVm.MONSTER_DIST_REQUEST] := EclMenu.GetEclVar(2);
  GDVars.encMonsterPic := EclMenu.GetEclVar(3);
  address := EclMenu.CombineBytesToWord(GDVars.varLo[4], GDVars.varHi[4]);
  for i := 0 to 4 do
    resp[i] := EclMenu.GetEclVar(i + 5);
  for i := 1 to 3 do
    msgs[i] := GDVars.scriptStrings[i];
  fleePar := EclMenu.GetEclVar(13);
  fleeMon := EclMenu.GetEclVar(14);
  GDVars.zone1^[C_Gbvm.MONSTER_DIST] := EclMenu.MaxMonsterDist(GDVars.partyPos.mapX, GDVars.partyPos.mapY,
                                                               GDVars.partyPos.facing);
  if GDVars.zone1^[EclVm.MONSTER_DIST_REQUEST] < GDVars.zone1^[C_Gbvm.MONSTER_DIST] then
    GDVars.zone1^[C_Gbvm.MONSTER_DIST] := GDVars.zone1^[EclVm.MONSTER_DIST_REQUEST];
  EclMenu.DisplayMonster(GDVars.encMonsterId, GDVars.encMonsterPic, Byte(GDVars.zone1^[C_Gbvm.MONSTER_DIST]),
                         GDVars.encounterMonsterFlags);
  repeat
    anim := GDVars.eclGraphics and GDVars.picDrawn and (GDVars.zone0^[C_Gbvm.VIEW_3D] <> 0) and
      (GDVars.loadedPicId <> C_Pic.VILLAGE);
    clearW := GDVars.zone0^[C_Gbvm.VIEW_3D] <> 0;
    waited := False;
    GDVars.curCol := 1;
    GDVars.curRow := 17;
    case GDVars.zone1^[C_Gbvm.MONSTER_DIST] of
      0: begin
        k := 1;
        repeat
          msg := msgs[k];
          Inc(k);
        until (msg <> '') or (k > 3);
      end;
      1: begin
        k := 2;
        repeat
          msg := msgs[k];
          Inc(k);
          if k > 3 then k := 1;
        until (msg <> '') or (k = 2);
      end;
      2: begin
        k := 3;
        repeat
          msg := msgs[k];
          Inc(k);
          if k > 3 then k := 1;
        until (msg <> '') or (k = 3);
      end;
    end;
    if msg = '' then
      clearW := False;
    TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, clearW, msg);
    if (GDVars.zone1^[C_Gbvm.MONSTER_DIST] = 0) or (GDVars.zone0^[C_Gbvm.VIEW_3D] = 0) then
      menu := '~COMBAT ~WAIT ~FLEE ~PARLAY'
    else
      menu := '~COMBAT ~WAIT ~FLEE ~ADVANCE';
    sel := EclMenu.MenuHorizontalCharacterSelect(q, menu, LightMagenta, LightGreen, White, False, anim);
    if ((GDVars.zone1^[C_Gbvm.MONSTER_DIST] = 0) or (GDVars.zone0^[C_Gbvm.VIEW_3D] = 0)) and (sel = 3) then
      sel := 4;
    choice := resp[sel];
    case choice of
      0:
        if sel <> 2 then
          EclMenu.WriteGbvm(address, 1)
        else begin
          if loMove >= fleePar then
            EclMenu.WriteGbvm(address, 2)
          else
            EclMenu.WriteGbvm(address, 1);
        end;
      1:
        case sel of
          0: EclMenu.WriteGbvm(address, 1);
          1: begin
            waited := True;
            TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, True, 'Both sides wait.');
          end;
          2: EclMenu.WriteGbvm(address, 2);
          3: begin
            if GDVars.zone1^[C_Gbvm.MONSTER_DIST] <> 0 then begin
              Dec(GDVars.zone1^[C_Gbvm.MONSTER_DIST]);
              EclMenu.DisplayMonster(GDVars.encMonsterId, GDVars.encMonsterPic,
                                     Byte(GDVars.zone1^[C_Gbvm.MONSTER_DIST]), GDVars.encounterMonsterFlags);
            end else
              TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, True, 'Both sides wait.');
            waited := True;
          end;
          4:
            if GDVars.zone1^[C_Gbvm.MONSTER_DIST] <= 0 then
              EclMenu.WriteGbvm(address, 3)
            else begin
              Dec(GDVars.zone1^[C_Gbvm.MONSTER_DIST]);
              EclMenu.DisplayMonster(GDVars.encMonsterId, GDVars.encMonsterPic,
                                     Byte(GDVars.zone1^[C_Gbvm.MONSTER_DIST]), GDVars.encounterMonsterFlags);
              waited := True;
            end;
        end;
      2:
        case sel of
          0:
            if fleeMon > hiMove then begin
              EclMenu.WriteGbvm(address, 0);
              GDVars.curCol := 1;
              GDVars.curRow := 17;
              TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, True, 'The monsters flee.');
            end else
              EclMenu.WriteGbvm(address, 1);
          1..4: begin
            EclMenu.WriteGbvm(address, 0);
            GDVars.curCol := 1;
            GDVars.curRow := 17;
            TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, True, 'The monsters flee.');
          end;
        end;
      3:
        case sel of
          0: EclMenu.WriteGbvm(address, 1);
          1, 3: begin
            if GDVars.zone1^[C_Gbvm.MONSTER_DIST] <> 0 then begin
              Dec(GDVars.zone1^[C_Gbvm.MONSTER_DIST]);
              EclMenu.DisplayMonster(GDVars.encMonsterId, GDVars.encMonsterPic,
                                     Byte(GDVars.zone1^[C_Gbvm.MONSTER_DIST]), GDVars.encounterMonsterFlags);
            end else
              TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, True, 'Both sides wait.');
            waited := True;
          end;
          2: EclMenu.WriteGbvm(address, 2);
          4:
            if GDVars.zone1^[C_Gbvm.MONSTER_DIST] <= 0 then
              EclMenu.WriteGbvm(address, 3)
            else begin
              Dec(GDVars.zone1^[C_Gbvm.MONSTER_DIST]);
              EclMenu.DisplayMonster(GDVars.encMonsterId, GDVars.encMonsterPic,
                                     Byte(GDVars.zone1^[C_Gbvm.MONSTER_DIST]), GDVars.encounterMonsterFlags);
              waited := True;
            end;
        end;
      4:
        case sel of
          0: EclMenu.WriteGbvm(address, 1);
          1, 3, 4:
            if GDVars.zone1^[C_Gbvm.MONSTER_DIST] <= 0 then
              EclMenu.WriteGbvm(address, 3)
            else begin
              Dec(GDVars.zone1^[C_Gbvm.MONSTER_DIST]);
              EclMenu.DisplayMonster(GDVars.encMonsterId, GDVars.encMonsterPic,
                                     Byte(GDVars.zone1^[C_Gbvm.MONSTER_DIST]), GDVars.encounterMonsterFlags);
              waited := True;
            end;
          2: EclMenu.WriteGbvm(address, 2);
        end;
    end;
  until not waited;
  MenuCore.ClearBottomLine;
  GDVars.typingDelayOn := False;
  GDVars.inEncMenu := False;
end;

{ PARLAY: offers Haughty, Sly, Nice, Meek and Abusive and stores the script's value for the chosen attitude at the sixth
  argument's address. }
procedure EclParlay;
var
  sel: Byte;
  attitudeValue: Byte;
  i: Byte;
  v: array[0..4] of Byte;
  address: Word;
  space: Char;
begin
  EclMenu.LoadEclVars(6);
  space := ' ';
  for i := 0 to 4 do
    v[i] := EclMenu.GetEclVar(i + 1);
  sel := EclMenu.MenuHorizontalCharacterSelect(space, '~HAUGHTY ~SLY ~NICE ~MEEK ~ABUSIVE', LightMagenta, LightGreen,
                                               White, False, False);
  address := EclMenu.CombineBytesToWord(GDVars.varLo[6], GDVars.varHi[6]);
  attitudeValue := v[sel];
  EclMenu.WriteGbvm(address, attitudeValue);
end;

{ FIND ITEM: sets the equal flag when any party member carries an item of the given type, else not-equal. }
procedure EclFindItem;
var
  target: Byte;
  { Unused in this version; see the other implementations of this routine. }
  itemCount: Byte;
  p: Types.PCreature;
  item: Types.PItem;
  found: Byte;
begin
  EclMenu.LoadEclVars(1);
  found := 0;
  target := EclMenu.GetEclVar(1);
  FillChar(GDVars.cmpFlags, SizeOf(GDVars.cmpFlags), 0);
  GDVars.cmpFlags[1] := True;
  p := GDVars.partyHead;
  while (p <> nil) and (found = 0) do begin
    item := p^.itemsAddr;
    while (item <> nil) and (found = 0) do begin
      if target = item^.itemType then begin
        GDVars.cmpFlags[0] := True;
        GDVars.cmpFlags[1] := False;
        found := 1;
      end;
      item := item^.next;
    end;
    p := p^.next;
  end;
end;

{ DELAY: waits the message delay (TextRend.PauseOnly); no key is read. }
procedure EclDelay;
begin
  Inc(GDVars.eclIp);
  TextRend.PauseOnly;
end;

{ DAMAGE: rolls dice d sides + bonus. With attack bit 7 the damage allows a saving throw (bits 0..4 the modifier, varOp
  bits 0..2 the save type) against the whole party (bit 6; bit 5 means no save), the current character (varOp bit 7;
  save type 0 means no save, else type - 1), or a random member; bit 4 deals it even on a save. Without bit 7, attack
  random members each take an attack roll and fresh damage. A party left with no one standing is reported killed and the
  game ends. The command ends with a press-Enter pause. }
procedure EclDamage;
var
  attack: Byte;
  dice: Byte;
  sides: Byte;
  i: Byte;
  atkLo: Byte;
  varOp: Byte;
  bonus: Byte;
  target: Byte;
  saveTy: Byte;
  j: Byte;
  dmg: Word;
  p: Types.PCreature;
  q: Types.PCreature;
  savedCur: Types.PCreature;
  { Unused in this version; see the other implementations of this routine. }
  damageType: Byte;
  areaAtk: Byte;
  saveBit: Byte;
begin
  savedCur := GDVars.curChar;
  damageType := 0;
  areaAtk := 0;
  p := GDVars.partyHead;
  EclMenu.LoadEclVars(5);
  attack := EclMenu.GetEclVar(1);
  dice := EclMenu.GetEclVar(2);
  sides := EclMenu.GetEclVar(3);
  bonus := EclMenu.GetEclVar(4);
  varOp := EclMenu.GetEclVar(5);
  dmg := FxEngine.RollDice(dice, sides) + bonus;
  saveBit := attack and $10;
  if (attack and $40) <> 0 then
    areaAtk := 1
  else
    target := FxEngine.RollDice(1, Byte(GDVars.zone1^[C_Gbvm.PARTY_SIZE]));
  if (attack and $80) <> 0 then begin
    atkLo := attack and $1F;
    saveTy := varOp and $7;
    if areaAtk <> 0 then begin
      while p <> nil do begin
        if (attack and $20) <> 0 then
          EclMenu.EclInflictDamage(dmg, p)
        else if not FxEngine.RollSavingThrow(p, saveTy, atkLo) then
          EclMenu.EclInflictDamage(dmg, p)
        else if saveBit <> 0 then
          EclMenu.EclInflictDamage(dmg, p);
        p := p^.next;
      end;
    end else if (varOp and $80) <> 0 then begin
      if (saveTy = 0) or not FxEngine.RollSavingThrow(GDVars.curChar, saveTy - 1, atkLo) then
        EclMenu.EclInflictDamage(dmg, GDVars.curChar)
      else if saveBit <> 0 then
        EclMenu.EclInflictDamage(dmg, GDVars.curChar);
    end else begin
      for i := 2 to target do
        p := p^.next;
      if not FxEngine.RollSavingThrow(p, saveTy, atkLo) then
        EclMenu.EclInflictDamage(dmg, p)
      else if saveBit <> 0 then
        EclMenu.EclInflictDamage(dmg, p);
    end;
  end else begin
    for i := 1 to attack do begin
      p := GDVars.partyHead;
      target := FxEngine.RollDice(1, Byte(GDVars.zone1^[C_Gbvm.PARTY_SIZE]));
      j := 1;
      while j < target do begin
        p := p^.next;
        Inc(j);
      end;
      if FxEngine.AttackRollNoAttacker(p, varOp) then
        EclMenu.EclInflictDamage(dmg, p);
      dmg := FxEngine.RollDice(dice, sides) + bonus;
    end;
  end;
  q := GDVars.partyHead;
  GDVars.partyDefeated := True;
  while q <> nil do begin
    if q^.enabled <> 0 then
      GDVars.partyDefeated := False;
    q := q^.next;
  end;
  if GDVars.partyDefeated then begin
    Border.DrawWindowFrame;
    GDVars.curCol := 2;
    GDVars.curRow := 2;
    TextRend.DisplayMessageWindow(1, 1, 38, 22, LightGreen, 0, True, 'The entire party is killed!');
    Delay(3000);
  end;
  GDVars.curChar := savedCur;
  TextRend.DisplayAndPause(White, 0, 'press <enter>/<return> to continue');
end;

{ SPRITE OFF: removes a shown sprite by redrawing the map cell. }
procedure EclSpriteOff;
begin
  Inc(GDVars.eclIp);
  if GDVars.spriteShown then begin
    GDVars.mapRedrawPending := 1;
    MapView.DisplayMapView;
    GDVars.spriteShown := False;
    GDVars.eclGraphics := False;
  end;
end;

{ ECL CLOCK: advances the game clock by the two arguments (GameTime.AdvanceTime). }
procedure EclClock;
var
  amount: Byte;
  tUnit: Byte;
begin
  EclMenu.LoadEclVars(2);
  amount := EclMenu.GetEclVar(1);
  tUnit := EclMenu.GetEclVar(2);
  GameTime.AdvanceTime(amount, tUnit);
end;

{ PRINT RETURN: moves the text cursor to column 1 of the next row. }
procedure EclPrintReturn;
begin
  Inc(GDVars.eclIp);
  if GDVars.printRetFlag then begin
    GDVars.curCol := 1;
    Inc(GDVars.curRow);
    GDVars.printRetFlag := False;
  end else begin
    GDVars.curCol := 1;
    Inc(GDVars.curRow);
  end;
end;

{ CLEAR BOX: redraws the exploration frame, roster, status line and the current picture. }
procedure EclClearBox;
begin
  Inc(GDVars.eclIp);
  Border.DrawViewFrame;
  CharHlp.DisplayParty(GDVars.curChar);
  CharHlp.PrintPositionAndTime;
  Portrait.DisplayImageBuf(3, 3, True, GDVars.animData.frames[1].pic);
  CharHlp.PrintPositionAndTime;
  GDVars.charSelectActive := 0;
  GDVars.boxCleared := True;
end;

{ WHO: asks the player to pick the current character, with the argument as the prompt. }
procedure EclWho;
var
  msg: String;
begin
  EclMenu.LoadEclVars(1);
  TextRend.ClearRect(1, 17, 38, 22);
  msg := GDVars.scriptStrings[1];
  CharHlp.SelectChar(msg, False, GDVars.curChar);
end;

{ ADD NPC: adds creature id to the party with morale (the argument div 2) and the NPC flag, recalculates its stats and
  redraws the roster. With 8 members already, nothing is added and the current character gets the morale and flag
  instead. }
procedure EclAddNpc;
var
  { Unused in this version; see the other implementations of this routine. }
  npc: array[1..4] of Byte;
  id: Byte;
  morale: Byte;
begin
  EclMenu.LoadEclVars(2);
  id := EclMenu.GetEclVar(1);
  SaveLoad.AddCreatureToParty(id);
  morale := EclMenu.GetEclVar(2);
  morale := morale div 2;
  morale := morale or $80;
  GDVars.curChar^.npc := morale;
  CharHlp.RecalcStats(GDVars.curChar);
  CharHlp.DisplayParty(GDVars.curChar);
end;

{ SPELL: finds the first party member with spell id memorized and writes its slot and the member's party index to the
  two addresses; when no member has it, the slot is $FF and the index the last member's. Note: the search skips slot 0
  and runs on to slot 101, past the 84 memorized-spell slots into the fields after them. }
procedure EclSpell;
var
  spellId: Byte;
  slot: Byte;
  idx: Byte;
  p: Types.PCreature;
  found: Byte;
  innerDone: Byte;
  slotAddr: Word;
  memberAddr: Word;
begin
  innerDone := 0;
  found := 0;
  EclMenu.LoadEclVars(3);
  spellId := EclMenu.GetEclVar(1);
  slotAddr := EclMenu.CombineBytesToWord(GDVars.varLo[2], GDVars.varHi[2]);
  memberAddr := EclMenu.CombineBytesToWord(GDVars.varLo[3], GDVars.varHi[3]);
  slot := 1;
  idx := 0;
  p := GDVars.partyHead;
  while (p <> nil) and (found = 0) do begin
    slot := 1;
    repeat
      if PSpellRec(p)^.spells[slot] = spellId then
        found := 1
      else if slot <= 100 then
        Inc(slot)
      else
        innerDone := 1;
    until (innerDone <> 0) or (found <> 0);
    innerDone := 0;
    p := p^.next;
    if (p <> nil) and (found = 0) then
      Inc(idx);
  end;
  if slot > 100 then
    slot := 255;
  EclMenu.WriteGbvm(slotAddr, slot);
  EclMenu.WriteGbvm(memberAddr, idx);
end;

{ CALL: runs an engine routine chosen by the argument address minus $7FFF: $AE11 refreshes the map cell and view, 1 and
  2 start a duel with or without a mirror copy, $3201 plays a sound, $401F moves the party forward, $4019 refreshes the
  wall ahead outside the 3D view, and $E804 steps the portrait animation. }
procedure EclCall;
var
  address: Word;
  magicKey: Word;
begin
  EclMenu.LoadEclVars(1);
  address := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  magicKey := address - $7FFF;
  case magicKey of
    $AE11: begin
             GDVars.partyPos.eventAtCell := View3D.GetMapEvent(GDVars.partyPos.mapX, GDVars.partyPos.mapY);
             if GDVars.filesLoaded then
               if GDVars.eclGraphics or GDVars.spriteShown or GDVars.redrawViewColors or GDVars.movedParty or
                   GDVars.redrawSky then begin
                 GDVars.mapRedrawPending := 1;
                 MapView.DisplayMapView;
                 CharHlp.PrintPositionAndTime;
                 GDVars.redrawSky := False;
                 GDVars.redrawViewColors := False;
                 GDVars.movedParty := False;
                 GDVars.eclGraphics := False;
                 GDVars.spriteShown := False;
                 GDVars.partyPos.wallAhead := View3D.GetWallType(GDVars.partyPos.mapX, GDVars.partyPos.mapY,
                                                                 GDVars.partyPos.facing);
               end;
           end;
    1: EclMenu.CharFightsAlone(1);
    2: EclMenu.CharFightsAlone(0);
    $3201: case GDVars.scriptSoundEffect of
             8: SoundDrv.SoundCommand(GDConsts.sndFootstep);
             10: SoundDrv.SoundCommand(GDConsts.sndCmd11);
           else
             SoundDrv.SoundCommand(GDConsts.sndFootstep);
           end;
    $401F: EclMenu.EclMoveForward;
    $4019: if GDVars.zone0^[C_Gbvm.VIEW_3D] = 0 then
             GDVars.partyPos.wallAhead := View3D.GetWallType(GDVars.partyPos.mapX, GDVars.partyPos.mapY,
                                                             GDVars.partyPos.facing);
    $E804: begin
             Portrait.DisplayImageBuf(3, 3, True, GDVars.animData.frames[GDVars.animData.current].pic);
             Inc(GDVars.animData.current);
             if GDVars.animData.current > GDVars.animData.count then
               GDVars.animData.current := 1;
             TextRend.PauseOnly;
           end;
  end;
end;

{ Camps: runs the before-camp entry (3) and the camp menu, then the after-interruption entry (4) if the rest was
  interrupted, redraws the map cell and clears the recently-saved mark. }
procedure EnterCamp;
var
  interrupted: Boolean;
begin
  Camp.PrimeCamp;
  interrupted := False;
  EclVm.CallEclScript(GDVars.vmRun[3]);
  Camp.CampMainMenu(interrupted);
  if interrupted then begin
    CharHlp.DisplayNoncombatInterface;
    EclVm.CallEclScript(GDVars.vmRun[4]);
  end;
  GDVars.mapRedrawPending := 1;
  MapView.DisplayMapView;
  GDVars.recentlySaved := 0;
end;

{ PROGRAM: 0 runs the party main menu; 8 plays the ending, marks the game won, heals and revives the party, lets the
  training hall train any class, runs the main menu, offers to save and quits; 9 camps and ends the script; 3 ends the
  game as a defeat. }
procedure EclProgram;
var
  prog: Byte;
  savedIp: Word;
  p: Types.PCreature;
  key: Char;
begin
  if GDVars.restoreChar then begin
    GDVars.curChar := GDVars.savedChar;
    GDVars.restoreChar := False;
  end;
  EclMenu.LoadEclVars(1);
  prog := EclMenu.GetEclVar(1);
  case prog of
    0: begin
         CharGen.PrimeCharGen;
         CharGen.MainMenu;
         if (GDVars.loadedPicId <> C_Pic.VILLAGE) and (GDVars.zone0^[C_Gbvm.VIEW_3D] = 0) then
           CharHlp.DisplayNoncombatInterface;
       end;
    8: begin
         Ending.WinGame;
         GDVars.victoryStart := True;
         GDVars.zone0^[C_Gbvm.GAME_WON] := 255;
         GDVars.zone1^[C_Gbvm.TRAIN_MASK] := $FF;
         p := GDVars.partyHead;
         while p <> nil do begin
           with p^ do begin
             hpCur := hpMax;
             status := C_Status.OKAY;
             enabled := 1;
           end;
           p := p^.next;
         end;
         CharGen.MainMenu;
         key := MenuCore.YesNoMenu('You''ve won. Save before quitting? ', LightMagenta, LightGreen, White);
         if key = 'Y' then
           SaveLoad.SaveGame;
         GameIo.ExitGame;
       end;
    9: begin
         savedIp := GDVars.eclIp;
         Camp.PrimeCamp;
         EclVm.EnterCamp;
         GDVars.eclIp := savedIp;
         EclVm.EclExit;
       end;
    3: begin
         GDVars.partyDefeated := True;
         EclVm.EclExit;
       end;
  end;
end;

{ PROTECTION: runs the copy-protection question, then the executable checksum check (a sound plays when it fails), and
  redraws the noncombat screen. }
procedure EclProtection;
var
  { Unused in this version; see the other implementations of this routine. }
  protFlags: array[0..6] of Byte;
begin
  FillChar(GDVars.encounterMonsterFlags, SizeOf(GDVars.encounterMonsterFlags), 0);
  GDVars.eclGraphics := False;
  EclMenu.LoadEclVars(1);
  CopyProt.CopyProtection;
  if not CopyProt.VerifyChecksum then SoundDrv.SoundCommand(GDConsts.sndStartCountdown);
  CharHlp.DisplayNoncombatInterface;
end;

{ DUMP: removes the current character from the party; the character that becomes current is kept as the one to
  restore. }
procedure EclDump;
var
  { Unused in this version; see the other implementations of this routine. }
  count: Byte;
begin
  Inc(GDVars.eclIp);
  CharGen.RemoveCreature(False, True);
  GDVars.savedChar := GDVars.curChar;
  CharHlp.DisplayParty(GDVars.curChar);
end;

{ FIND SPECIAL: sets the equal flag when the current character has the given effect, else not-equal. }
procedure EclFindSpecial;
var
  node: Types.PEffect;
  v: Byte;
begin
  FillChar(GDVars.cmpFlags, SizeOf(GDVars.cmpFlags), 0);
  EclMenu.LoadEclVars(1);
  v := EclMenu.GetEclVar(1);
  if CharHlp.HasEffect(GDVars.curChar, v, node) then
    GDVars.cmpFlags[0] := True
  else
    GDVars.cmpFlags[1] := True;
end;

{ DESTROY ITEMS: removes the items of the given type from each party member and recalculates the member's stats. }
procedure EclDestroyItems;
var
  target: Byte;
  p: Types.PCreature;
  item: Types.PItem;
  nextItem: Types.PItem;
begin
  EclMenu.LoadEclVars(1);
  target := EclMenu.GetEclVar(1);
  p := GDVars.partyHead;
  while p <> nil do begin
    item := p^.itemsAddr;
    while item <> nil do begin
      nextItem := item^.next;
      if target = item^.itemType then
        CharHlp.RemoveItem(p, item);
      item := nextItem;
    end;
    CharHlp.RecalcStats(p);
    p := p^.next;
  end;
end;

{ Runs the routine for the current opcode. Note: an opcode with no command does nothing and leaves the instruction
  pointer on itself, so CallEclScript fetches it again forever. }
procedure DispatchEclCommand;
begin
  case GDVars.scriptOpcode of
    C_Ecl.OP_EXIT: EclVm.EclExit;
    C_Ecl.OP_GOTO: EclVm.EclGoto;
    C_Ecl.GOSUB: EclVm.EclGosubCmd;
    C_Ecl.COMPARE: EclVm.EclCompare;
    C_Ecl.ADD, C_Ecl.SUBTRACT, C_Ecl.DIVIDE, C_Ecl.MULTIPLY: EclVm.EclArithmetic;
    C_Ecl.OP_RANDOM: EclVm.EclRandom;
    C_Ecl.SAVE: EclVm.EclSave;
    C_Ecl.LOAD_CHARACTER: EclVm.EclLoadCharacter;
    C_Ecl.LOAD_MONSTER: EclVm.EclLoadMonster;
    C_Ecl.SETUP_MONSTER: EclVm.EclSetupMonster;
    C_Ecl.APPROACH: EclVm.EclApproach;
    C_Ecl.PICTURE: EclVm.EclPicture;
    C_Ecl.INPUT_NUMBER: EclVm.EclInputNumber;
    C_Ecl.INPUT_STRING: EclVm.EclInputString;
    C_Ecl.PRINT, C_Ecl.PRINT_CLEAR: EclVm.EclPrint;
    C_Ecl.RETURN: EclVm.EclReturn;
    C_Ecl.COMPARE_AND: EclVm.EclCompareAnd;
    C_Ecl.VERTICAL_MENU: EclVm.EclVMenu;
    C_Ecl.IF_EQ, C_Ecl.IF_NE, C_Ecl.IF_LT, C_Ecl.IF_GT, C_Ecl.IF_LE, C_Ecl.IF_GE: EclVm.EclIf;
    C_Ecl.CLEAR_MONSTERS: EclVm.EclClearMonsters;
    C_Ecl.PARTY_STRENGTH: EclVm.EclPartyStrength;
    C_Ecl.CHECK_PARTY: EclVm.EclCheckParty;
    C_Ecl.NEW_ECL: EclVm.EclNewEcl;
    C_Ecl.LOAD_FILES, C_Ecl.LOAD_PIECES: EclVm.EclLoadFiles;
    C_Ecl.PARTY_SURPRISE: EclVm.EclPartySurprise;
    C_Ecl.SURPRISE: EclVm.EclSurprise;
    C_Ecl.OP_COMBAT: EclVm.EclCombat;
    C_Ecl.ON_GOTO, C_Ecl.ON_GOSUB: EclVm.EclOnGoto;
    C_Ecl.TREASURE: EclVm.EclTreasure;
    C_Ecl.ROB: EclVm.EclRob;
    C_Ecl.ENCOUNTER_MENU: EclVm.EclEncounter;
    C_Ecl.GET_TABLE: EclVm.EclGetTable;
    C_Ecl.HORIZONTAL_MENU: EclVm.EclHMenu;
    C_Ecl.PARLAY: EclVm.EclParlay;
    C_Ecl.CALL: EclVm.EclCall;
    C_Ecl.DAMAGE: EclVm.EclDamage;
    C_Ecl.OP_AND, C_Ecl.OP_OR: EclVm.EclAndOr;
    C_Ecl.SPRITE_OFF: EclVm.EclSpriteOff;
    C_Ecl.FIND_ITEM: EclVm.EclFindItem;
    C_Ecl.PRINT_RETURN: EclVm.EclPrintReturn;
    C_Ecl.CLOCK: EclVm.EclClock;
    C_Ecl.SAVE_TABLE: EclVm.EclSaveTable;
    C_Ecl.ADD_NPC: EclVm.EclAddNpc;
    C_Ecl.OP_PROGRAM: EclVm.EclProgram;
    C_Ecl.WHO: EclVm.EclWho;
    C_Ecl.OP_DELAY: EclVm.EclDelay;
    C_Ecl.SPELL: EclVm.EclSpell;
    C_Ecl.PROTECTION: EclVm.EclProtection;
    C_Ecl.CLEAR_BOX: EclVm.EclClearBox;
    C_Ecl.DUMP: EclVm.EclDump;
    C_Ecl.FIND_SPECIAL: EclVm.EclFindSpecial;
    C_Ecl.DESTROY_ITEMS: EclVm.EclDestroyItems;
  end;
end;

{ Runs the script from address until a command stops it or the game halts, writing each opcode's name to the debug file
  while tracing is on.
  @param(address GBVM address of the first command to run.) }
procedure CallEclScript(address: Word);
begin
  GDVars.eclIp := address;
  GDVars.eclStop := False;
  while not GDVars.eclStop and not GDVars.partyDefeated do begin
    GDVars.eclPrevOp := GDVars.scriptOpcode;
    GDVars.scriptOpcode := GDVars.scriptCode^[GDVars.eclIp];
    if GDVars.debugTraceEnabled then
      WriteLn(GDVars.debugFile, EclTrace.OpName(GDVars.scriptOpcode));
    EclVm.DispatchEclCommand;
  end;
  GDVars.eclStop := False;
end;

{ Follows a script switch: runs the new script's load entry (5) and then, unless it switched again, redraws the map cell
  and runs the before-move (1) and after-move (2) entries, repeating while scripts keep switching. }
procedure NewEclDone;
begin
  repeat
    Portrait.FreeAnimation(GDVars.animData);
    GDVars.savedPicArchiveName[0] := #0;
    GDVars.savedPicId := 255;
    GDVars.newEclFlag := False;
    GDVars.partyPos.eventAtCell := View3D.GetMapEvent(GDVars.partyPos.mapX, GDVars.partyPos.mapY);
    GDVars.zone1^[C_Gbvm.LEAVE_MAP] := 0;
    GDVars.savedChar := GDVars.curChar;
    EclVm.CallEclScript(GDVars.vmRun[5]);
    if not GDVars.newEclFlag then
      GDVars.zone0^[C_Gbvm.PREV_SCRIPT] := GDVars.currentScriptId;
    if not GDVars.newEclFlag then begin
      if (((GDVars.prevIfcState <> C_Ifc.VIEW_3D) or (GDVars.ifcState = C_Ifc.VIEW_3D)) and GDVars.filesLoaded) or
          ((GDVars.prevIfcState = C_Ifc.VIEW_3D) and (GDVars.ifcState = C_Ifc.VIEW_3D)) then
        MapView.DisplayMapView;
      GDVars.newEclFlag := False;
      EclVm.CallEclScript(GDVars.vmRun[1]);
      if not GDVars.newEclFlag then begin
        EclVm.CallEclScript(GDVars.vmRun[2]);
        if not GDVars.newEclFlag then begin
          GDVars.curChar := GDVars.savedChar;
          CharHlp.DisplayParty(GDVars.curChar);
        end;
      end;
    end;
  until not GDVars.newEclFlag;
  GDVars.prevIfcState := GDVars.ifcState;
end;

procedure GameLoop;
var
  cmd: Char;
begin
  GDVars.savedChar := GDVars.curChar;
  GDVars.mapRedrawPending := 1;
  GDVars.protShown := False;
  GDVars.piecesLoaded := False;
  GDVars.mapLoaded := False;
  GDVars.restoreChar := False;
  GDVars.filesLoaded := False;
  GDVars.charSelectActive := 1;
  GDVars.ifcState := C_Ifc.VIEW_3D;
  GDVars.newEclFlag := False;
  if GDVars.zone0^[C_Gbvm.PREV_SCRIPT] = 0 then begin
    GDVars.charSelectActive := 0;
    if GDVars.demoMode then
      GDVars.currentScriptId := 82
    else begin
      GDVars.currentScriptId := 1;
      CharHlp.DisplayParty(GDVars.curChar);
    end;
  end else
    GDVars.currentScriptId := Byte(GDVars.zone0^[C_Gbvm.PREV_SCRIPT]);
  if GDVars.zone0^[C_Gbvm.VIEW_3D] = 0 then
    GDVars.ifcState := C_Ifc.OVERLAND;
  if not GDVars.loadedSavedGame or (GDVars.zone0^[C_Gbvm.PREV_SCRIPT] = 0) then
    EclMenu.LoadEclScript(GDVars.currentScriptId)
  else
    GDVars.filesLoaded := True;
  EclMenu.EclInit;
  EclVm.CallEclScript(GDVars.vmRun[5]);
  if GDVars.demoMode then begin
    repeat
      CharGen.RemoveCreature(True, True);
    until GDVars.partyHead = nil;
  end else begin
    if not GDVars.newEclFlag then
      GDVars.zone0^[C_Gbvm.PREV_SCRIPT] := GDVars.currentScriptId
    else
      EclVm.NewEclDone;
    if (GDVars.ifcState <> C_Ifc.OVERLAND) and GDVars.loadedSavedGame then begin
      if GDVars.charSelectActive = 1 then
        CharHlp.DisplayNoncombatInterface;
      GDVars.mapRedrawPending := 1;
      MapView.DisplayMapView;
    end;
    GDVars.loadedSavedGame := False;
    repeat
      cmd := Explore.MapMainMenu;
      GDVars.savedChar := GDVars.curChar;
      if not GDVars.newEclFlag then
        GDVars.zone0^[C_Gbvm.PREV_SCRIPT] := GDVars.currentScriptId;
      while ((GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] > 1) or (UpCase(cmd) = 'E')) and not GDVars.partyDefeated do begin
        if UpCase(cmd) = 'E' then begin
          Camp.PrimeCamp;
          EclVm.EnterCamp;
        end else begin
          GDVars.searchBak := GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] and 1;
          GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] := 1;
          GDVars.mapRedrawPending := 1;
          MapView.DisplayMapView;
          EclVm.CallEclScript(GDVars.vmRun[2]);
          if GDVars.newEclFlag then
            EclVm.NewEclDone;
          GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] := GDVars.searchBak;
        end;
        if not GDVars.partyDefeated then begin
          cmd := Explore.MapMainMenu;
          GDVars.savedChar := GDVars.curChar;
        end;
      end;
      if not GDVars.partyDefeated then
        EclVm.CallEclScript(GDVars.vmRun[1]);
      if GDVars.newEclFlag then
        EclVm.NewEclDone
      else if not GDVars.partyDefeated then begin
        GDVars.zone0^[EclVm.PRE_MOVE_X] := GDVars.partyPos.mapX;
        GDVars.zone0^[EclVm.PRE_MOVE_Y] := GDVars.partyPos.mapY;
        Explore.ResolveMovement;
        MapView.DisplayMapView;
        if (GDVars.partyPos.mapX <> GDVars.zone0^[EclVm.PRE_MOVE_X]) or
            (GDVars.partyPos.mapY <> GDVars.zone0^[EclVm.PRE_MOVE_Y]) then
          SoundDrv.SoundCommand(GDConsts.sndFootstep);
        GDVars.eclGraphics := False;
        GDVars.picDrawn := True;
        EclVm.CallEclScript(GDVars.vmRun[2]);
        if GDVars.newEclFlag then
          EclVm.NewEclDone;
      end;
    until GDVars.partyDefeated;
    GDVars.partyDefeated := False;
  end;
end;

begin
end.
