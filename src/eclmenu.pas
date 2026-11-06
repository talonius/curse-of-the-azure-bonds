{ ECL script support: argument decoding, GBVM memory reads and writes (with their side effects on the game), script
  strings, menus, comparisons, monster display, and the duel, robbery and damage commands. }
{$O+,F+}
unit EclMenu;

interface

uses Types, Portrait, MenuCore, MapTiles, DaxIo, TextRend, View3D, ViewChar, SaveLoad, FxEngine, CharHlp, ClassCal,
  MapView, EclTrace, GDConsts, GDVars, C_Keys, C_Status, C_Effect, C_Ifc, C_Gbvm, C_Ecl, C_Class, C_Stat, Crt;

{ Reads the value of a loaded script argument: type 0 is an immediate byte, types 1, 3 and $80 read the GBVM word at the
  argument's address, and types 2 and $81 are an immediate word. Other types leave the result undefined.
  @param(idx The argument, from 1.)
  @returns(The argument's value.) }
function GetEclVar(idx: ShortInt): Word;

{ Decodes the arguments of the current script command: each has a type byte and a low byte, and types 1..3 add a high
  byte. Type $80 is an inline packed string of that length and $81 the address of a string; both go to the next script
  string. Leaves the instruction pointer on the next command.
  @param(count The number of arguments.) }
procedure LoadEclVars(count: Byte);

{ Resets the script interpreter for a new script: its display and dump flags, wall colors, monster flags, icon animation
  slot (8), return stack and comparison flags, a few zone words (no picture, anti-magic off), and the instruction
  pointer ($8000), then reads the script's five entry addresses and turns the 3D view flag on. For a new game (not a
  loaded one) it also clears zone-0 words $4C00..$4C1F and zone-1 words $7F79..$7F82. }
procedure EclInit;

{ Loads a script block from ECL<disk>.DAX into the cleared script bank, skipping its 2-byte header, and keeps retrying
  (with disk prompts on) until the block loads.
  @param(scriptId The script's block in the file.) }
procedure LoadEclScript(scriptId: Byte);

{ Allocates a creature record and loads a monster into it.
  @param(id The monster's record number.)
  @param(creature Receives the new record.)
  @param(inv Receives its item list.)
  @param(effect Receives its effect list.) }
procedure InitCreature(id: Byte; var creature: Pointer; var inv: Pointer; var effect: Pointer);

{ Works out how far ahead a monster can appear. Outside the 3D view it is 2, also stored as the zone's monster distance;
  in it, the number of open cells (at most 2) walking from the position in the facing before a wall.
  @param(x The starting column.)
  @param(y The starting row.)
  @param(facing The direction, 0, 2, 4 or 6.)
  @returns(The distance in cells, 0..2.) }
function MaxMonsterDist(x, y, facing: Byte): Byte;

{ Shows the portrait with a head and body at (3, 3) and records them.
  @param(headId The head picture.)
  @param(bodyId The body picture.) }
procedure DisplayPortrait(headId, bodyId: Byte);

{ Shows an encounter's monster. Until its close-up is shown, it turns off the automap and loads the sprite animation in
  the 3D view the first time (redrawing the map cell on later calls), and draws the sprite at distance dist + 1. At
  distance 0 in the 3D view (unless the encounter menu is open with monster pictures off) it shows the close-up: picture
  picId, or a portrait with the zone's portrait head and body picId, skipping one already shown.
  @param(sprId The sprite animation.)
  @param(picId The close-up picture, or the portrait's body.)
  @param(dist The monster's distance, 0 when it is next to the party.)
  @param(flags The encounter's monster flags: [0] marks the sprite loaded and [1] the close-up shown.) }
procedure DisplayMonster(sprId, picId, dist: Byte; var flags: Types.TMonFlags);

{ Joins two bytes into a word.
  @param(lowByte The low byte.)
  @param(highByte The high byte.)
  @returns(The high byte times 256 plus the low byte.) }
function CombineBytesToWord(lowByte, highByte: Byte): Word;

{ Writes a GBVM word. A zone-0 write to a sky color asks for a sky redraw, and one that changes the 3D flag switches
  between the overland and 3D interface states, remembering the previous one; zone-1 writes go on to SpecialWriteZ1.
  Outside the banks, the addresses that do anything are the sound effect, two script values, and from $BF68 up the
  party's map position and facing (marking the party moved) and the wall and ceiling colors.
  @param(address The GBVM address.)
  @param(value The value written.) }
procedure WriteGbvm(address, value: Word);

{ Reads a GBVM word: zone 1 through SpecialReadZ1 first. Outside the banks it serves three script result words, the
  facing, and from $C04B the party's map position, facing (0..3), wall ahead and cell event.
  @param(address The GBVM address.)
  @returns(The word; undefined for any other address outside the banks.) }
function ReadGbvm(address: Word): Word;

{ Writes a string, zero-terminated, at a GBVM address in any bank; zone-1 address $7C00 sets the current character's
  name instead. Addresses outside the banks are ignored.
  @param(address The GBVM address.)
  @param(value The string.) }
procedure WriteGbvmString(address: Word; value: String);

{ Runs a script horizontal menu with '~' hotkeys; extended keys change the current character.
  @param(query The prompt.)
  @param(menu The menu string, with '~' before each hotkey.)
  @param(qCol The prompt's color.)
  @param(mCol The menu's color.)
  @param(hlCol The highlight color.)
  @param(enterOk True to let Enter pick the first hotkey.)
  @param(animate True to play the portrait animation while waiting.)
  @returns(The pressed hotkey's index from 0, 0 for Enter when enterOk (the same as the first hotkey), or $FF for a key
    that is not a hotkey.) }
function MenuHorizontalCharacterSelect(query: Types.TStr40; menu: String; qCol, mCol, hlCol: Byte;
                                       enterOk, animate: Boolean): Byte;

{ Prepares a script menu string's hotkeys and runs MenuCore.MenuVertical with the given list; the key it returns is
  discarded.
  @param(query The prompt.)
  @param(menu The command menu string, with '~' before each hotkey.)
  @param(qCol The labels' and prompt's color.)
  @param(mCol The choices' color.)
  @param(hlCol The highlight color.)
  @param(ulCol The window's left column.)
  @param(ulRow The window's top row.)
  @param(lrCol The window's right column.)
  @param(lrRow The window's bottom row.)
  @param(list The members listed.)
  @param(addExit True to offer Exit.)
  @param(redraw True to redraw the window first; cleared on return unless list is nil.)
  @param(idx The highlighted member, kept between calls.)
  @param(sel Receives the chosen member, or nil.) }
procedure EclVerticalMenu(query: Types.TStr40; menu: String; qCol, mCol, hlCol: Byte; ulCol, ulRow, lrCol,
                          lrRow: ShortInt; list: Types.PItem; addExit: Boolean; var redraw: Boolean;
                          var idx: Integer; var sel: Types.PItem);

{ Sets the six comparison flags from two strings: equal, not equal, less, greater, less or equal, greater or equal.
  @param(leftOperand The left side.)
  @param(rightOperand The right side.) }
procedure EclCompareStr(leftOperand, rightOperand: String);

{ Sets the six comparison flags from two numbers: equal, not equal, less, greater, less or equal, greater or equal.
  @param(leftOperand The left side.)
  @param(rightOperand The right side.) }
procedure EclCompareInt(leftOperand, rightOperand: Word);

{ Pushes the instruction pointer on the script return stack and jumps to the address in a loaded argument.
  @param(varIdx The argument holding the address.) }
procedure EclGosub(varIdx: Byte);

{ Starts a duel, recording whether it is a mirror duel: disables each party member whose name differs from the current
  character's. A mirror duel also loads the duel icon and adds 'ROLF', a hostile quick-fighting copy of the character
  with copies of its items (in reverse order).
  @param(mirror Nonzero for a mirror duel.) }
procedure CharFightsAlone(mirror: ShortInt);

{ Moves the party one cell the way it faces, wrapping on the 16x16 map, and refreshes the cell event and the wall
  ahead. }
procedure EclMoveForward;

{ Keeps a share of each of a character's coins, gems and jewelry.
  @param(fraction The share kept.)
  @param(creature The character robbed.) }
procedure RobMoney(fraction: Real; creature: Pointer);

{ Takes each of a character's items with a chance in percent. An item heavier than 255 lowers the chance by 90 and one
  heavier than 24 by 50, to no less than 0. Note: the lowered chance carries over to the items after it.
  @param(chance The chance in percent.)
  @param(creature The character robbed.) }
procedure RobItems(chance: Byte; creature: Pointer);

{ Skips the current script command, decoding as many arguments as its opcode takes. Note: VERTICAL MENU, HORIZONTAL
  MENU, ON GOTO and ON GOSUB are skipped as if they had no arguments, so the bytes of their arguments are read as the
  next commands. }
procedure SkipEclCmd;

{ Finds the party's highest and lowest movement, doubled for haste or halved for slow. Note: both start from the first
  member's unadjusted movement.
  @param(fastest Receives the highest movement.)
  @param(slowest Receives the lowest movement.) }
procedure MoveExtremes(var fastest, slowest: Byte);

{ Deals script damage to a creature with a message, then redraws the party panel; a dead creature is skipped. The
  creature dies when the damage is more than 10 above its hit points; otherwise the message gives the damage, at most
  three digits. When the message window is full it waits for a key first.
  @param(dmg The damage.)
  @param(creature The creature.) }
procedure EclInflictDamage(dmg: Word; creature: Pointer);

{ Calls the priming entries of SaveLoad, Portrait, FxEngine, MapView, ViewChar, CharHlp, EclTrace, MenuCore and
  MapTiles, so the overlay manager loads them; View3D and ClassCal, also used, are not primed. }
procedure PrimeEclMenu;

implementation

procedure ConvGbString(len, strIdx: Byte); forward;

procedure DerefGbString(strIdx: Byte; address: Word); forward;

procedure PrimeEclMenu;
begin
  SaveLoad.PrimeSaveLoad;
  Portrait.PrimePortrait;
  FxEngine.PrimeFxEngine;
  MapView.PrimeMapView;
  ViewChar.PrimeViewChar;
  CharHlp.PrimeCharHlp;
  EclTrace.PrimeEclTrace;
  MenuCore.PrimeMenuCore;
  MapTiles.PrimeMapTiles;
end;

procedure LoadEclVars(count: Byte);
var
  i: Byte;
  strIdx: Byte;
  v: Word;
  len: Word;
begin
  strIdx := 0;
  for i := 1 to count do begin
    GDVars.varTypes[i] := GDVars.scriptCode^[GDVars.eclIp + 1];
    GDVars.varLo[i] := GDVars.scriptCode^[GDVars.eclIp + 2];
    GDVars.eclIp := GDVars.eclIp + 2;
    case GDVars.varTypes[i] of
      1, 2, 3: begin
        Inc(GDVars.eclIp);
        GDVars.varHi[i] := GDVars.scriptCode^[GDVars.eclIp];
      end;
      $80: begin
        Inc(strIdx);
        len := GDVars.varLo[i];
        if len > 0 then
          EclMenu.ConvGbString(len, strIdx)
        else
          GDVars.scriptStrings[strIdx] := '';
      end;
      $81: begin
        Inc(strIdx);
        Inc(GDVars.eclIp);
        GDVars.varHi[i] := GDVars.scriptCode^[GDVars.eclIp];
        v := EclMenu.CombineBytesToWord(GDVars.varLo[i], GDVars.varHi[i]);
        EclMenu.DerefGbString(strIdx, v);
      end;
    end;
  end;
  Inc(GDVars.eclIp);
end;

function GetEclVar(idx: ShortInt): Word;
var
  { Unused in this version; see the other implementations of this routine. }
  address: Word;
  { Unused in this version; see the other implementations of this routine. }
  value: Word;
  { Unused in this version; see the other implementations of this routine. }
  kind: Word;
  lowByte: Byte;
  highByte: Byte;
begin
  lowByte := GDVars.varLo[idx];
  highByte := GDVars.varHi[idx];
  case GDVars.varTypes[idx] of
    0: GetEclVar := lowByte;
    1, 3, $80: GetEclVar := EclMenu.ReadGbvm(highByte * 256 + lowByte);
    2, $81: GetEclVar := EclMenu.CombineBytesToWord(lowByte, highByte);
  end;
end;

procedure EclInit;
var
  { Unused in this version; see the other implementations of this routine. }
  scriptId: Byte;
  i: Word;
begin
  GDVars.eclGraphics := False;
  GDVars.protShown := False;
  GDVars.dumpOnStatusClear := False;
  GDVars.dumpOnNameClear := False;
  GDVars.wallColorSel := $41;
  GDVars.ceilFloorColorSel := 9;
  GDVars.redrawViewColors := True;
  FillChar(GDVars.encounterMonsterFlags, SizeOf(GDVars.encounterMonsterFlags), 0);
  GDVars.iconAnimId := 8;
  GDVars.eclIp := $8000;
  GDVars.breathAim := False;
  GDVars.scriptReturnStack := nil;
  GDVars.prevScriptReturnStack := nil;
  FillChar(GDVars.cmpFlags, SizeOf(GDVars.cmpFlags), 0);
  GDVars.zone1^[C_Gbvm.PORTRAIT_HEAD] := 255;
  GDVars.zone1^[$7ED2] := 0;
  GDVars.zone1^[$7ED3] := 0;
  GDVars.zone0^[C_Gbvm.ANTI_MAGIC] := 0;
  EclMenu.LoadEclVars(1);
  GDVars.vmRun[1] := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  EclMenu.LoadEclVars(1);
  GDVars.vmRun[2] := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  EclMenu.LoadEclVars(1);
  GDVars.vmRun[3] := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  EclMenu.LoadEclVars(1);
  GDVars.vmRun[4] := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  EclMenu.LoadEclVars(1);
  GDVars.vmRun[5] := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  GDVars.zone0^[C_Gbvm.VIEW_3D] := 1;
  if not GDVars.loadedSavedGame then begin
    for i := 1 to 32 do
      GDVars.zone0^[i + $4BFF] := 0;
    for i := 0 to 9 do
      GDVars.zone1^[i + $7F79] := 0;
  end;
end;

procedure LoadEclScript(scriptId: Byte);
var
  { Unused in this version; see the other implementations of this routine. }
  scriptSize: Word;
  { Unused in this version; see the other implementations of this routine. }
  scriptOffset: Word;
  s: String[1];
  sizeRead: Word;
  data: Types.PByteArr;
begin
  FillChar(GDVars.scriptCode^, SizeOf(GDVars.scriptCode^), 0);
  GDVars.suppressDiskPrompt := #0;
  repeat
    MenuCore.ClearBottomLine;
    TextRend.DisplayString(0, 24, LightGreen, 0, 'Loading...Please Wait');
    Str(GDVars.diskIndex, s);
    DaxIo.LoadDax('ECL' + s, '.dax', scriptId, sizeRead, data);
  until sizeRead >= 2;
  Move(data^[2], GDVars.scriptCode^, sizeRead - 2);
  FreeMem(data, sizeRead);
  MenuCore.ClearBottomLine;
end;

procedure InitCreature(id: Byte; var creature: Pointer; var inv: Pointer; var effect: Pointer);
var
  { Unused in this version; see the other implementations of this routine. }
  item: Pointer;
begin
  creature := nil;
  GetMem(creature, SizeOf(Types.TCreature));
  SaveLoad.LoadCreatureData(id, creature);
  inv := Types.PCreature(creature)^.itemsAddr;
  effect := Types.PCreature(creature)^.effects;
end;

function MaxMonsterDist(x, y, facing: Byte): Byte;
var
  blocked: Boolean;
  dist: Byte;
begin
  dist := 0;
  blocked := False;
  MaxMonsterDist := 0;
  if GDVars.zone0^[C_Gbvm.VIEW_3D] = 0 then begin
    MaxMonsterDist := 2;
    GDVars.zone1^[C_Gbvm.MONSTER_DIST] := 2;
  end else
    while (dist < 2) and (not blocked) do begin
      if View3D.GetWallType(x, y, facing) = 0 then begin
        Inc(dist);
        MaxMonsterDist := dist;
        case facing of
          0: Dec(y);
          2: Inc(x);
          4: Inc(y);
          6: Dec(x);
        end;
      end else
        blocked := True;
    end;
end;

procedure DisplayPortrait(headId, bodyId: Byte);
begin
  GDVars.picDrawn := False;
  GDVars.portraitHeadId := headId;
  GDVars.portraitBodyId := bodyId;
  Portrait.LoadPortraitBufs(headId, bodyId);
  Portrait.DisplayPortraitBufs(3, 3, True);
end;

procedure DisplayMonster(sprId, picId, dist: Byte; var flags: Types.TMonFlags);
var
  { Unused in this version; see the other implementations of this routine. }
  headPic: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  bodyPic: Pointer;
  spriteDist: Byte;
begin
  spriteDist := dist + 1;
  if not flags[1] then begin
    if not flags[0] then begin
      if GDVars.automapOn then begin
        GDVars.automapOn := False;
        GDVars.mapRedrawPending := 1;
        MapView.DisplayMapView;
      end;
      if GDVars.zone0^[C_Gbvm.VIEW_3D] <> 0 then begin
        Portrait.LoadAnimation('SPRIT', sprId, 1, GDVars.animData);
        flags[0] := True;
        GDVars.spriteShown := True;
      end;
    end else begin
      GDVars.mapRedrawPending := 1;
      MapView.DisplayMapView;
    end;
    if GDVars.ifcState = C_Ifc.VIEW_3D then
      Portrait.Show3DSprite(spriteDist, GDVars.animData);
  end;
  if flags[1] then
    if GDVars.picIdShown = GDVars.zone1^[C_Gbvm.PORTRAIT_HEAD] then
      Exit;
  if dist <> 0 then Exit;
  if GDVars.ifcState <> C_Ifc.VIEW_3D then Exit;
  if GDVars.inEncMenu and (GDVars.monsterPics = 0) then Exit;
  GDVars.picIdShown := Byte(GDVars.zone1^[C_Gbvm.PORTRAIT_HEAD]);
  GDVars.eclGraphics := True;
  if GDVars.zone1^[C_Gbvm.PORTRAIT_HEAD] = 255 then begin
    Portrait.LoadAnimation('PIC', picId, 0, GDVars.animData);
    flags[1] := True;
    Portrait.DisplayImageBuf(3, 3, True, GDVars.animData.frames[1].pic);
  end else begin
    EclMenu.DisplayPortrait(Byte(GDVars.zone1^[C_Gbvm.PORTRAIT_HEAD]), picId);
    flags[1] := True;
    GDVars.picDrawn := False;
  end;
end;

function CombineBytesToWord(lowByte, highByte: Byte): Word;
begin
  CombineBytesToWord := highByte * 256 + lowByte;
end;

{ Turns a 6-bit game character into ASCII: codes below 32 gain 64, and higher codes stay as they are.
  @param(code The game character.)
  @returns(The ASCII character.) }
function DecodeGameCharacter(code: Byte): Char;
begin
  if code > 31 then
    DecodeGameCharacter := Chr(code)
  else
    DecodeGameCharacter := Chr(code + 64);
end;

{ Finds the GBVM bank holding an address.
  @param(address The GBVM address.)
  @returns(0 for $4B00..$4EFF, 1 for $7C00..$7FFF, 2 for $7A00..$7BFF, 3 (the script) for $8000..$9DFF, and 4 for
    anything else.) }
function GbvmZone(address: Word): Byte;
begin
  GbvmZone := 4;
  if (address >= $4B00) and (address <= $4EFF) then GbvmZone := 0;
  if (address >= $7C00) and (address <= $7FFF) then GbvmZone := 1;
  if (address >= $7A00) and (address <= $7BFF) then GbvmZone := 2;
  if (address >= $8000) and (address <= $9DFF) then GbvmZone := 3;
end;

{ Finds a creature's place in the creature list.
  @param(creature The creature.)
  @returns(Its place from 0; the list's length when it is not there.) }
function FindCurCharIdx(creature: Types.PCreature): Byte;
var
  idx: Byte;
  p: Types.PCreature;
  found: Boolean;
begin
  p := GDVars.partyHead;
  found := False;
  idx := 0;
  while (p <> nil) and (not found) do begin
    if p = creature then
      found := True
    else begin
      Inc(idx);
      p := p^.next;
    end;
  end;
  FindCurCharIdx := idx;
end;

{ Reads the zone-1 addresses that map onto the current character: Intelligence, Constitution, race, class, a saving
  throw, terrain type, thief skills, NPC byte, coins, magic-user level (counting an earlier class once passed), gender,
  alignment, a script flag bit, experience fields, status ($7D00: 1 enabled, $80 disabled, or 0 once after a
  character-not-found), side and quick fight ($7D0C), movement, party position, a Charisma value (0..60), the current
  disk and the party size.
  @param(address The zone-1 address.)
  @param(found Set False for an ordinary zone-1 word, else True.)
  @returns(The value; undefined for $7D0D and for an ordinary word.) }
function SpecialReadZ1(address: Word; var found: Boolean): Word;
var
  t: Byte;
begin
  found := True;
  address := address - $7C00;
  case address of
    $15: SpecialReadZ1 := GDVars.curChar^.stats[C_Stat.INTELLIGENCE].current;
    $18: SpecialReadZ1 := GDVars.curChar^.stats[C_Stat.CONSTITUTION].current;
    $72: SpecialReadZ1 := GDVars.curChar^.race;
    $73: SpecialReadZ1 := GDVars.curChar^.charClass;
    $9B: SpecialReadZ1 := GDVars.curChar^.saves[1];
    $A0: SpecialReadZ1 := GDVars.curChar^.levelHighest;
    $A5..$AC: begin
      t := address - $A4;
      SpecialReadZ1 := GDVars.curChar^.thiefSkills[t];
    end;
    $B8: SpecialReadZ1 := GDVars.curChar^.npc;
    $BB: SpecialReadZ1 := GDVars.curChar^.coins[0];
    $BD: SpecialReadZ1 := GDVars.curChar^.coins[1];
    $BF: SpecialReadZ1 := GDVars.curChar^.coins[2];
    $C1: SpecialReadZ1 := GDVars.curChar^.coins[3];
    $C3: SpecialReadZ1 := GDVars.curChar^.coins[4];
    $C9: SpecialReadZ1 :=
      ClassCal.EarlierClassActive(GDVars.curChar) * GDVars.curChar^.oldClassLevels[C_Class.MAGE_LEVEL] +
      GDVars.curChar^.classLevels[C_Class.MAGE_LEVEL];
    $D6: SpecialReadZ1 := GDVars.curChar^.gender;
    $D8: SpecialReadZ1 := ShortInt(GDVars.curChar^.alignment);
    $E4: SpecialReadZ1 := GDVars.curChar^.scriptFlags[0] and 1;
    $F7: SpecialReadZ1 := GDVars.curChar^.xpAward;
    $F9: SpecialReadZ1 := GDVars.curChar^.xpBonusPerHp;
    $100: begin
      if GDVars.curChar^.enabled <> 0 then
        SpecialReadZ1 := 1
      else
        SpecialReadZ1 := $80;
      if GDVars.characterNotFound = 1 then
        SpecialReadZ1 := 0;
      GDVars.characterNotFound := 0;
    end;
    $10C:
      if (GDVars.curChar^.hostile = 0) and (GDVars.curChar^.quickfight <> 0) then
        SpecialReadZ1 := $80
      else if GDVars.curChar^.hostile = 1 then
        SpecialReadZ1 := $81
      else
        SpecialReadZ1 := 0;
    $10D: ;
    $11B: SpecialReadZ1 := GDVars.curChar^.movementCur;
    $2B1: SpecialReadZ1 := EclMenu.FindCurCharIdx(GDVars.curChar);
    $2B4: SpecialReadZ1 := EclMenu.FindCurCharIdx(GDVars.curChar);
    $2CF:
      case GDVars.curChar^.stats[C_Stat.CHARISMA].current of
        3: SpecialReadZ1 := 0;
        4: SpecialReadZ1 := 5;
        5: SpecialReadZ1 := 10;
        6: SpecialReadZ1 := 15;
        7: SpecialReadZ1 := 20;
        8..12: SpecialReadZ1 := 25;
        13: SpecialReadZ1 := 30;
        14: SpecialReadZ1 := 35;
        15: SpecialReadZ1 := 40;
        16: SpecialReadZ1 := 50;
        17: SpecialReadZ1 := 55;
        18..25: SpecialReadZ1 := 60;
      end;
    $312: SpecialReadZ1 := GDVars.diskIndex;
    $33E: SpecialReadZ1 := GDVars.zone1^[C_Gbvm.PARTY_SIZE];
  else
    found := False;
  end;
end;

{ Applies the side effects of a zone-1 write to the current character: memorized spells, NPC byte (values above $B2
  lowered by $32), coins, experience fields, status ($80 and up disables, $87 also stones), side and quick fight, the
  current disk (PushState), and the three wall sets (values above $80, less bit 7). Writing 0 to $7C00 or $7D00 asks for
  a party or monster record dump.
  @param(address The zone-1 address.)
  @param(value The value written.) }
procedure SpecialWriteZ1(address, value: Word);
var
  t: Byte;
begin
  address := address - $7C00;
  case address of
    0:
      if value = 0 then GDVars.dumpOnNameClear := True;
    $20..$70: begin
      t := address - $1F;
      GDVars.curChar^.memorizedSpells[t] := value;
    end;
    $B8: begin
      if value > $B2 then Dec(value, $32);
      GDVars.curChar^.npc := value;
    end;
    $BB: GDVars.curChar^.coins[0] := value;
    $BD: GDVars.curChar^.coins[1] := value;
    $BF: GDVars.curChar^.coins[2] := value;
    $C1: GDVars.curChar^.coins[3] := value;
    $C3: GDVars.curChar^.coins[4] := value;
    $F7: GDVars.curChar^.xpAward := value;
    $F9: GDVars.curChar^.xpBonusPerHp := value;
    $100: begin
      if value >= $80 then begin
        GDVars.curChar^.enabled := 0;
        if value = $87 then GDVars.curChar^.status := C_Status.STONED;
      end;
      if value = 0 then GDVars.dumpOnStatusClear := True;
    end;
    $10C:
      case value of
        0: begin
          GDVars.curChar^.hostile := 0;
          GDVars.curChar^.quickfight := 0;
        end;
        $80: begin
          GDVars.curChar^.hostile := 0;
          GDVars.curChar^.quickfight := 1;
        end;
        $81: begin
          GDVars.curChar^.hostile := 1;
          GDVars.curChar^.quickfight := 1;
        end;
      end;
    $312: DaxIo.PushState(value);
    $322:
      if value > $80 then begin
        value := value and $7F;
        View3D.LoadWallSet(value, 1);
      end;
    $324:
      if value > $80 then begin
        value := value and $7F;
        View3D.LoadWallSet(value, 2);
      end;
    $326:
      if value > $80 then begin
        value := value and $7F;
        View3D.LoadWallSet(value, 3);
      end;
  end;
end;

procedure WriteGbvm(address, value: Word);
var
  zone: Byte;
  ok: Boolean;
begin
  zone := EclMenu.GbvmZone(address);
  case zone of
    0: begin
      { Apply the write's side effects before storing the value. }
      case address - $4B00 of
        $FD, $FE:
          GDVars.redrawSky := True;
        $E6:
          if GDVars.zone0^[C_Gbvm.VIEW_3D] <> value then begin
            GDVars.prevIfcState := GDVars.ifcState;
            if value = 0 then
              GDVars.ifcState := C_Ifc.OVERLAND
            else
              GDVars.ifcState := C_Ifc.VIEW_3D;
          end;
      end;
      GDVars.zone0^[address] := value;
    end;
    1: begin
      GDVars.zone1^[address] := value;
      EclMenu.SpecialWriteZ1(address, value);
    end;
    2:
      GDVars.zone2^[address] := value;
    3:
      GDVars.scriptCode^[address] := value;
    4:
      if address < $BF68 then
        case address of
          $FB: ;
          $FC: ;
          $B1: ;
          $3DE: GDVars.scriptSoundEffect := value;
          $B8: GDVars.scriptValueB8 := value;
          $B9: GDVars.scriptValueB9 := value;
        end else begin
        address := address - $BF68;
        case address of
          $E3: begin
            GDVars.movedParty := True;
            GDVars.partyPos.mapX := value;
          end;
          $E4: begin
            GDVars.partyPos.mapY := value;
            GDVars.movedParty := True;
          end;
          $E5: begin
            repeat
              ok := True;
              case value of
                0: GDVars.partyPos.facing := 0;
                1: GDVars.partyPos.facing := 2;
                2: GDVars.partyPos.facing := 4;
                3: GDVars.partyPos.facing := 6;
              else begin
                ok := False;
                Dec(value, 4);
              end;
              end;
            until ok = True;
            GDVars.movedParty := True;
          end;
          $F1: begin
            GDVars.wallColorSel := value;
            GDVars.redrawViewColors := True;
          end;
          $F7: begin
            GDVars.ceilFloorColorSel := value;
            GDVars.redrawViewColors := True;
          end;
          $10BA: ;
        end;
      end;
  end;
end;

function ReadGbvm(address: Word): Word;
var
  zone: Byte;
  found: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  offset: Word;
begin
  zone := EclMenu.GbvmZone(address);
  found := False;
  case zone of
    0:
      ReadGbvm := GDVars.zone0^[address];
    1: begin
      ReadGbvm := EclMenu.SpecialReadZ1(address, found);
      if not found then
        ReadGbvm := GDVars.zone1^[address];
    end;
    2:
      ReadGbvm := GDVars.zone2^[address];
    3:
      ReadGbvm := GDVars.scriptCode^[address];
    4:
      if address < $C04B then
        case address of
          $B1: ReadGbvm := GDVars.scriptResultB1;
          $FB: ReadGbvm := GDVars.scriptResultFb;
          $FC: ReadGbvm := GDVars.scriptResultFc;
          $33D: ReadGbvm := GDVars.partyPos.facing;
          $35F: ;
        end else begin
        address := address - $C04B;
        case address of
          0: ReadGbvm := GDVars.partyPos.mapX;
          1: ReadGbvm := GDVars.partyPos.mapY;
          2: ReadGbvm := GDVars.partyPos.facing div 2;
          3: ReadGbvm := GDVars.partyPos.wallAhead;
          4: ReadGbvm := GDVars.partyPos.eventAtCell;
          $E: ;
        end;
      end;
  end;
end;

procedure WriteGbvmString(address: Word; value: String);
var
  zone: Byte;
  len: Byte;
  i: Byte;
begin
  zone := EclMenu.GbvmZone(address);
  len := Length(value);
  case zone of
    0: begin
      if len > 0 then
        for i := 0 to len - 1 do
          GDVars.zone0^[address + i] := Ord(value[i + 1]);
      GDVars.zone0^[address + len] := 0;
    end;
    1:
      if address = $7C00 then
        GDVars.curChar^.name := value
      else begin
        if len > 0 then
          for i := 0 to len - 1 do
            GDVars.zone1^[address + i] := Ord(value[i + 1]);
        GDVars.zone1^[address + len] := 0;
      end;
    2: begin
      if len > 0 then
        for i := 0 to len - 1 do
          GDVars.zone2^[address + i] := Ord(value[i + 1]);
      GDVars.zone2^[address + len] := 0;
    end;
    3: begin
      if len > 0 then
        for i := 0 to len - 1 do
          GDVars.scriptCode^[address + i] := Ord(value[i + 1]);
      GDVars.scriptCode^[address + len] := 0;
    end;
  end;
end;

{ Unpacks a packed script string (four 6-bit characters per three bytes) from the script at the instruction pointer into
  a script string, skipping zero codes.
  @param(len The packed length in bytes.)
  @param(strIdx The script string filled.) }
procedure ConvGbString(len, strIdx: Byte);
var
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  outPos: Byte;
  cur: Byte;
  prev: Byte;
  charCode: Byte;
  phase: Byte;
  ch: Char;
begin
  GDVars.scriptStrings[strIdx] := '';
  i := 0;
  phase := 1;
  while i < len do begin
    if phase < 4 then begin
      Inc(GDVars.eclIp);
      prev := cur;
      cur := GDVars.scriptCode^[GDVars.eclIp];
      Inc(i);
    end;
    case phase of
      1:
        charCode := cur shr 2;
      2: begin
        charCode := prev shl 6 + cur shr 2;
        charCode := charCode shr 2;
      end;
      3: begin
        charCode := prev shl 4 + cur shr 4;
        charCode := charCode shr 2;
      end;
      4:
        charCode := cur and $3F;
    end;
    if phase < 4 then Inc(phase) else phase := 1;
    if charCode <> 0 then begin
      ch := EclMenu.DecodeGameCharacter(charCode);
      GDVars.scriptStrings[strIdx] := Concat(GDVars.scriptStrings[strIdx], ch);
    end;
  end;
  if phase = 4 then begin
    charCode := cur and $3F;
    if charCode <> 0 then begin
      ch := EclMenu.DecodeGameCharacter(charCode);
      GDVars.scriptStrings[strIdx] := Concat(GDVars.scriptStrings[strIdx], ch);
    end;
  end;
end;

{ Copies the zero-terminated string at a GBVM address into a script string. Zone-1 address $7C00 gives the current
  character's name; addresses outside the banks give an empty string.
  @param(strIdx The script string filled.)
  @param(address The GBVM address.) }
procedure DerefGbString(strIdx: Byte; address: Word);
var
  zone: Byte;
  i: Byte;
begin
  zone := EclMenu.GbvmZone(address);
  GDVars.scriptStrings[strIdx] := '';
  i := 0;
  case zone of
    0:
      while GDVars.zone0^[address + i] <> 0 do begin
        GDVars.scriptStrings[strIdx] := Concat(GDVars.scriptStrings[strIdx],
                                                 Char(GDVars.zone0^[address + i]));
        Inc(i);
      end;
    1:
      if address = $7C00 then
        GDVars.scriptStrings[strIdx] := GDVars.curChar^.name
      else
        while GDVars.zone1^[address + i] <> 0 do begin
          GDVars.scriptStrings[strIdx] := Concat(GDVars.scriptStrings[strIdx],
                                                   Char(GDVars.zone1^[address + i]));
          Inc(i);
        end;
    2:
      while GDVars.zone2^[address + i] <> 0 do begin
        GDVars.scriptStrings[strIdx] := Concat(GDVars.scriptStrings[strIdx],
                                                 Char(GDVars.zone2^[address + i]));
        Inc(i);
      end;
    3:
      while GDVars.scriptCode^[address + i] <> 0 do begin
        GDVars.scriptStrings[strIdx] := Concat(GDVars.scriptStrings[strIdx],
                                                 Char(GDVars.scriptCode^[address + i]));
        Inc(i);
      end;
  end;
end;

{ Prepares a script menu string: lowercases it, removes each '~' and uppercases the letter after it as a hotkey. Note:
  the lowercasing adds $20 to digits too, turning them into letters P..Y.
  @param(menu The menu string, prepared in place.)
  @param(opts Receives the hotkeys in order.) }
procedure MenuToOptions(var menu: String; var opts: Types.TStr40);
var
  i: Byte;
begin
  opts := '';
  for i := 1 to Length(menu) do begin
    if menu[i] in ['0'..'9', 'A'..'Z'] then
      menu[i] := Chr(Ord(menu[i]) + 32);
    if menu[i] = '~' then begin
      Delete(menu, i, 1);
      menu[i] := UpCase(menu[i]);
      opts := opts + menu[i];
    end;
  end;
end;

function MenuHorizontalCharacterSelect(query: Types.TStr40; menu: String; qCol, mCol, hlCol: Byte;
                                       enterOk, animate: Boolean): Byte;
var
  opts: Types.TStr40;
  idx: Byte;
  ch: Char;
  ext: Boolean;
begin
  EclMenu.MenuToOptions(menu, opts);
  repeat
    ch := MenuCore.MenuHorizontal(query, menu, qCol, mCol, hlCol, True, animate, ext);
    if ext then begin
      ViewChar.SelectPrevNextChar(ch);
      CharHlp.DisplayParty(GDVars.curChar);
      ch := C_Keys.NONE;
    end;
  until (ch in ['0'..'9', 'A'..'Z']) or ((ch = C_Keys.ENTER) and enterOk);
  case ch of
    C_Keys.ENTER: MenuHorizontalCharacterSelect := 0;
  else begin
    idx := 1;
    while (idx <= Length(opts)) and (opts[idx] <> ch) do
      Inc(idx);
    if idx <= Length(opts) then
      MenuHorizontalCharacterSelect := idx - 1
    else
      MenuHorizontalCharacterSelect := 255;
  end;
  end;
end;

procedure EclVerticalMenu(query: Types.TStr40; menu: String; qCol, mCol, hlCol: Byte; ulCol, ulRow, lrCol,
                          lrRow: ShortInt; list: Types.PItem; addExit: Boolean; var redraw: Boolean;
                          var idx: Integer; var sel: Types.PItem);
var
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
  opts: Types.TStr40;
begin
  EclMenu.MenuToOptions(menu, opts);
  ch := MenuCore.MenuVertical(query, menu, qCol, mCol, hlCol, ulCol, ulRow, lrCol, lrRow, list, addExit, redraw, idx,
                              sel);
end;

procedure EclCompareStr(leftOperand, rightOperand: String);
begin
  FillChar(GDVars.cmpFlags, SizeOf(GDVars.cmpFlags), 0);
  if leftOperand = rightOperand then GDVars.cmpFlags[0] := True;
  if leftOperand <> rightOperand then GDVars.cmpFlags[1] := True;
  if leftOperand < rightOperand then GDVars.cmpFlags[2] := True;
  if leftOperand > rightOperand then GDVars.cmpFlags[3] := True;
  if leftOperand <= rightOperand then GDVars.cmpFlags[4] := True;
  if leftOperand >= rightOperand then GDVars.cmpFlags[5] := True;
end;

procedure EclCompareInt(leftOperand, rightOperand: Word);
begin
  FillChar(GDVars.cmpFlags, SizeOf(GDVars.cmpFlags), 0);
  if leftOperand = rightOperand then GDVars.cmpFlags[0] := True;
  if leftOperand <> rightOperand then GDVars.cmpFlags[1] := True;
  if leftOperand < rightOperand then GDVars.cmpFlags[2] := True;
  if leftOperand > rightOperand then GDVars.cmpFlags[3] := True;
  if leftOperand <= rightOperand then GDVars.cmpFlags[4] := True;
  if leftOperand >= rightOperand then GDVars.cmpFlags[5] := True;
end;

procedure EclGosub(varIdx: Byte);
begin
  if GDVars.scriptReturnStack = nil then begin
    GetMem(GDVars.scriptReturnStack, SizeOf(GDVars.scriptReturnStack^));
    GDVars.scriptReturnStack^.next := nil;
  end else begin
    GDVars.prevScriptReturnStack := GDVars.scriptReturnStack;
    GetMem(GDVars.scriptReturnStack, SizeOf(GDVars.scriptReturnStack^));
    GDVars.scriptReturnStack^.next := GDVars.prevScriptReturnStack;
  end;
  GDVars.scriptReturnStack^.addr := GDVars.eclIp;
  GDVars.eclIp := EclMenu.CombineBytesToWord(GDVars.varLo[varIdx], GDVars.varHi[varIdx]);
end;

procedure EclMoveForward;
begin
  case GDVars.partyPos.facing of
    0: if GDVars.partyPos.mapY > 0 then Dec(GDVars.partyPos.mapY) else GDVars.partyPos.mapY := 15;
    2: if GDVars.partyPos.mapX < 15 then Inc(GDVars.partyPos.mapX) else GDVars.partyPos.mapX := 0;
    4: if GDVars.partyPos.mapY < 15 then Inc(GDVars.partyPos.mapY) else GDVars.partyPos.mapY := 0;
    6: if GDVars.partyPos.mapX > 0 then Dec(GDVars.partyPos.mapX) else GDVars.partyPos.mapX := 15;
  end;
  GDVars.partyPos.eventAtCell := View3D.GetMapEvent(GDVars.partyPos.mapX, GDVars.partyPos.mapY);
  GDVars.partyPos.wallAhead := View3D.GetWallType(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
  GDVars.movedParty := True;
end;

procedure CharFightsAlone(mirror: ShortInt);
var
  p: Types.PCreature;
  clone: Types.PCreature;
  cur: Types.PCreature;
  srcIt: Types.PItem;
  tmp: Types.PItem;
  { Unused in this version; see the other implementations of this routine. }
  srcEff: Pointer;
begin
  GDVars.duelFlag := True;
  GDVars.zone1^[C_Gbvm.MIRROR_DUEL] := mirror;
  cur := GDVars.curChar;
  p := GDVars.partyHead;
  while p <> nil do begin
    if p^.name <> cur^.name then
      p^.enabled := 0;
    p := p^.next;
  end;
  if mirror = 0 then Exit;
  MapTiles.LoadIconAnim('CPIC', 11, GDVars.iconAnimId);
  p := GDVars.partyHead;
  while p^.next <> nil do
    p := p^.next;
  GetMem(clone, SizeOf(clone^));
  clone^ := cur^;
  clone^.enabled := 1;
  clone^.next := nil;
  clone^.name := 'ROLF';
  clone^.quickfight := 1;
  clone^.hostile := 1;
  clone^.npc := $B2;
  clone^.orderNumber := GDVars.iconAnimId;
  clone^.effects := nil;
  clone^.itemsAddr := nil;
  p^.next := clone;
  p := p^.next;
  srcIt := cur^.itemsAddr;
  while srcIt <> nil do begin
    if p^.itemsAddr = nil then begin
      GetMem(p^.itemsAddr, SizeOf(Types.TItem));
      p^.itemsAddr^ := srcIt^;
      p^.itemsAddr^.next := nil;
    end else begin
      tmp := p^.itemsAddr;
      GetMem(p^.itemsAddr, SizeOf(Types.TItem));
      p^.itemsAddr^ := srcIt^;
      p^.itemsAddr^.next := Types.PItem(tmp);
    end;
    srcIt := Types.PItem(srcIt^.next);
  end;
end;

procedure RobMoney(fraction: Real; creature: Pointer);
begin
  Types.PCreature(creature)^.coins[0] := Trunc(Types.PCreature(creature)^.coins[0] * fraction);
  Types.PCreature(creature)^.coins[1] := Trunc(Types.PCreature(creature)^.coins[1] * fraction);
  Types.PCreature(creature)^.coins[2] := Trunc(Types.PCreature(creature)^.coins[2] * fraction);
  Types.PCreature(creature)^.coins[3] := Trunc(Types.PCreature(creature)^.coins[3] * fraction);
  Types.PCreature(creature)^.coins[4] := Trunc(Types.PCreature(creature)^.coins[4] * fraction);
  Types.PCreature(creature)^.coins[5] := Trunc(Types.PCreature(creature)^.coins[5] * fraction);
  Types.PCreature(creature)^.coins[6] := Trunc(Types.PCreature(creature)^.coins[6] * fraction);
end;

procedure RobItems(chance: Byte; creature: Pointer);
var
  roll: Byte;
  it: Types.PItem;
  nxt: Types.PItem;
begin
  it := Types.PCreature(creature)^.itemsAddr;
  while it <> nil do begin
    if it^.weight > 255 then begin
      if chance > 90 then
        chance := chance - 90
      else
        chance := 0;
    end else if it^.weight > 24 then begin
      if chance > 50 then
        chance := chance - 50
      else
        chance := 0;
    end;
    roll := FxEngine.RollDice(1, 100);
    nxt := Types.PItem(it^.next);
    if roll <= chance then
      CharHlp.RemoveItem(Types.PCreature(creature), Types.PItem(it));
    it := nxt;
  end;
end;

procedure SkipEclCmd;
begin
  GDVars.scriptOpcode := GDVars.scriptCode^[GDVars.eclIp];
  case GDVars.scriptOpcode of
    C_Ecl.OP_GOTO, C_Ecl.GOSUB, C_Ecl.LOAD_CHARACTER, C_Ecl.PICTURE, C_Ecl.PRINT, C_Ecl.PRINT_CLEAR,
    C_Ecl.PARTY_STRENGTH, C_Ecl.NEW_ECL, C_Ecl.CALL, C_Ecl.FIND_ITEM, C_Ecl.CLOCK, C_Ecl.ADD_NPC,
    C_Ecl.OP_PROGRAM, C_Ecl.WHO, C_Ecl.PROTECTION, C_Ecl.FIND_SPECIAL, C_Ecl.DESTROY_ITEMS:
      EclMenu.LoadEclVars(1);
    C_Ecl.COMPARE, C_Ecl.OP_RANDOM, C_Ecl.SAVE, C_Ecl.INPUT_NUMBER, C_Ecl.INPUT_STRING, $1F,
    C_Ecl.PARTY_SURPRISE:
      EclMenu.LoadEclVars(2);
    C_Ecl.ADD..C_Ecl.MULTIPLY, C_Ecl.LOAD_MONSTER, C_Ecl.SETUP_MONSTER, C_Ecl.LOAD_FILES, C_Ecl.ROB,
    C_Ecl.GET_TABLE, C_Ecl.OP_AND, C_Ecl.OP_OR, C_Ecl.SAVE_TABLE, C_Ecl.LOAD_PIECES, C_Ecl.SPELL:
      EclMenu.LoadEclVars(3);
    C_Ecl.COMPARE_AND, C_Ecl.SURPRISE:
      EclMenu.LoadEclVars(4);
    C_Ecl.DAMAGE:
      EclMenu.LoadEclVars(5);
    C_Ecl.CHECK_PARTY, C_Ecl.PARLAY:
      EclMenu.LoadEclVars(6);
    C_Ecl.TREASURE:
      EclMenu.LoadEclVars(8);
    C_Ecl.ENCOUNTER_MENU:
      EclMenu.LoadEclVars(14);
  else
    Inc(GDVars.eclIp);
  end;
end;

procedure MoveExtremes(var fastest, slowest: Byte);
var
  p: Types.PCreature;
  eff: Types.PEffect;
  m: Byte;
begin
  p := GDVars.partyHead;
  fastest := p^.movementCur;
  slowest := p^.movementCur;
  while p <> nil do begin
    m := p^.movementCur;
    if CharHlp.HasEffect(p, C_Effect.HASTED, eff) then
      m := m * 2
    else if CharHlp.HasEffect(p, C_Effect.SLOWED, eff) then
      m := m div 2;
    if m > fastest then fastest := m;
    if m < slowest then slowest := m;
    p := p^.next;
  end;
end;

procedure EclInflictDamage(dmg: Word; creature: Pointer);
var
  { Unused in this version; see the other implementations of this routine. }
  damageType: Byte;
  msg: String;
  dmgStr: String[3];
  pause: Boolean;
begin
  if Types.PCreature(creature)^.status = C_Status.DEAD_STATUS then Exit;
  pause := False;
  Str(dmg, dmgStr);
  if Types.PCreature(creature)^.hpCur + 10 < dmg then
    msg := '  ' + Types.PCreature(creature)^.name + ' dies. '
  else
    msg := '  ' + Types.PCreature(creature)^.name + ' is hit FOR ' + dmgStr + ' points of Damage.';
  if GDVars.curRow > 22 then begin
    GDVars.curRow := 17;
    pause := True;
    TextRend.DisplayAndPause(White, 0, 'press <enter>/<return> to continue');
  end else
    pause := False;
  GDVars.curCol := 38;
  TextRend.DisplayMessageWindow(1, 17, 38, 22, White, 0, pause, msg);
  CharHlp.InflictDamage(Types.PCreature(creature), dmg);
  TextRend.ClearRect(17, 1, 38, 15);
  CharHlp.DisplayParty(GDVars.curChar);
end;

begin
end.
