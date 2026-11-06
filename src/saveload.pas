{ Saving and loading: saved games, character files and the list of them, importing Pool and Hillsfar characters,
  monsters joining the party, and building party members' combat icons. }
{$O+,F+,I-}
{$A-}
unit SaveLoad;

interface

uses Types, GDConsts, GDVars, C_Keys, C_Ifc, C_Status, C_Race, C_Class, C_Effect, C_Stat, C_Pic, C_Spell, C_Gbvm,
  DaxIo, Dos, TextRend, GameIo, Blit, MenuCore, MapTiles, CharHlp, ClassCal, FxEngine, ViewChar, Portrait, View3D,
  Money, EclTrace;

{ Lists the characters that can be loaded in the current import mode: 0 Curse (*.guy), 1 Pool (*.cha and saved games'
  *.sav), 2 Hillsfar (*.hil). Files of the mode's size are listed, leaving out characters already in the party and those
  with a byte above $7F at the mode's second offset (modes 0 and 1). Both lists stay empty when the save directory
  cannot be reached. Note: in mode 1 the saved-game scan appends through a list tail it never set when the first scan
  found files.
  @param(nameList Receives the stored names, padded, with "from saved game X" for a .sav.)
  @param(fileList Receives the matching file names, in the same order.) }
procedure LoadCharlist(var nameList, fileList: Types.PItem);

{ Makes sure the save directory can be reached, asking for the save disk on drives A and B; in mode 0 it also refuses
  the game disk (volume CURSE) and creates a missing directory. An unexpected error on a hard disk is reported.
  @returns(True when the directory is ready.) }
function CheckSaveDir: Boolean;

{ ORs one icon's pixels into another and ANDs its transparency mask into the other's.
  @param(src The icon to add.)
  @param(dest The icon that receives it.) }
procedure MergeIcon(src, dest: Types.PImgBuf);

{ Builds the current character's combat icon in its slot (on disk 1): loads the body (CBODY) icon into the slot and the
  head (CHEAD) icon into scratch slot 11, both for its icon size, and ORs the head's two frames onto the body's.
  @param(loading Also recolors the icon with the character's six saved icon colors.) }
procedure LoadCharIconAnim(loading: Boolean);

{ Deletes a character's .guy, .swg and .fx files from the save directory.
  @param(cr The character, whose name gives the file names.) }
procedure DeleteCharacterFiles(cr: Types.PCreature);

{ Saves a character in the save directory: its 422-byte record as <name>.guy (or <fname>.sav), its items (63 bytes each)
  as .swg and its effects (9 bytes each) as .fx. With no room it offers to try another disk; choosing Ok ('Lose
  character?') goes on writing anyway; instead of overwriting a .guy file it can take a new name.
  @param(cr The character.)
  @param(fname The file name for a saved game's copy, or empty to save under the character's name.) }
procedure SaveChar(cr: Types.PCharRecord; fname: Types.TStr8);

{ Loads a character file from the save directory according to the import mode: 0 a Curse record; 1 a Pool record,
  converted; 2 a Hillsfar character, merged into an existing Curse (.guy) or Pool (.cha) character with the same name or
  else made from scratch, then sent through training. A Hillsfar merge keeps the higher ability scores, experience and
  age, takes the Hillsfar gold as platinum when that is worth more, sets the cleric, fighter, magic-user and thief
  levels to 1 or 0 from the Hillsfar class flags, and takes the hit points from the Hillsfar record. Its .swg items and
  .fx effects follow (from Pool also some .spc effects), and its stats are recalculated. Note: the Pool conversion's
  exceptional-Strength check raises Strength, not exceptional Strength, to the race's exceptional-Strength limit.
  @param(name The file name, with its extension.)
  @param(cr Receives the character.)
  @param(savedGame Unused.)
  @param(askDisk Asks for the save disk rather than the data disk while the file is missing.) }
procedure LoadChar(name: String; cr: Types.PCharRecord; savedGame, askDisk: Boolean);

{ Loads a monster from MON<disk>CHA.DAX, with its effects from MON<disk>SPC and its items from MON<disk>ITM; quits when
  the monster is missing.
  @param(id The monster number.)
  @param(cr Receives the monster.) }
procedure LoadCreatureData(id: Byte; cr: Types.PCharRecord);

{ Adds a monster to the party, unless it already has 8 members, with its combat icon from CPIC.
  @param(id The monster number, also kept as its identity byte.) }
procedure AddCreatureToParty(id: Byte);

{ Offers the saved games A..J in the save directory and loads the chosen SAVGAM<x>.DAT: the disk number, the four GBVM
  banks, the party position, the interface states, the three wall-set slots and the members' file names. The picture,
  animation and speed settings come back from zone 0, each member is loaded from its .sav file and its
  <name>.guy/.swg/.fx working files are deleted, the icons are rebuilt, the data disk is taken from its zone-1 word, and
  the 3D map and wall sets or the overland picture are reloaded. The interface state is left at 0. }
procedure LoadGame;

{ Asks which game (A..J) to save and writes SAVGAM<x>.DAT with the disk number, the GBVM banks, the party position, the
  interface states, the three wall-set slots and the members' file names CHRDAT<x><n>; then saves each member under that
  name and deletes its working files. It refuses when the disk lacks room. }
procedure SaveGame;

{ Appends a character to the creature list as the current character, gives it the first free icon slot (0..7), counts it
  in zone 1's party size, and recalculates an NPC's THAC0.
  @param(cr The character.) }
procedure AddCharToParty(cr: Types.PCharRecord);

{ Does nothing. }
procedure NoopSaveLoad;

{ Calls the priming entries of MapTiles, EclTrace, ClassCal, FxEngine and CharHlp (which prime MenuCore, Portrait and
  MapView in turn), so the overlay manager loads them; ViewChar, View3D, Money and CharGen are not primed. }
procedure PrimeSaveLoad;

implementation

uses CharGen, Crt;

const
  { Word index into the GBVM zone-0 variables (GDVars.zone0^) of the game speed saved with the game. }
  SAVED_SPEED = $4BFC;
  { Word index into the GBVM zone-0 variables (GDVars.zone0^) of the picture settings saved with the game: pictures on
    times 2, plus 1 for animation on. }
  SAVED_PICTURE_FLAGS = $4BFF;
  { Word index into the GBVM zone-1 variables (GDVars.zone1^) of the data disk saved with the game. }
  DATA_DISK = $7F12;

type

  { Null-terminated character name. }
  TCharArr = array[0..65534] of Char;

  { Hillsfar character record used by import mode 2. }
  PHillsfarRec = ^THillsfarRec;
  THillsfarRec = record
    header: array[$00..$03] of Byte;
    { C-string name }
    name4: array[0..15] of Char;
    strength: Byte;
    { exceptional Strength }
    strExc: Byte;
    { ability scores 1..5, then a byte unused here }
    otherAbilities: array[$16..$1B] of Byte;
    alignment: Byte;
    { chime charges, given as an item when merging into a Curse character }
    chimeCharges: Byte;
    age: Word;
    hpCur: Byte;
    hpMax: Byte;
    afterHpMax: Byte;
    { wand charges, given as an item when merging into a Curse character }
    wandCharges: Byte;
    beforeScriptFlag: array[$24..$25] of Byte;
    setsScriptFlag: Byte;
    beforeGold: Byte;
    gold: LongInt;
    gender: Byte;
    race: Byte;
    experience: LongInt;
    afterExperience: array[$32..$34] of Byte;
    { the Hillsfar class in the low four bits, mapped through importClassMap }
    classCode: Byte;
    afterClassCode: array[$36..$85] of Byte;
    { ring charges, given as an item when merging into a Curse character }
    ringCharges: Byte;
    { healing potions, given as one item when merging into a Curse character }
    healingPotions: Byte;
    beforeClassFlags: array[$88..$B6] of Byte;
    isCleric: Byte;
    isMage: Byte;
    isFighter: Byte;
    isThief: Byte;
    fbb: Byte;
  end;

function CStrToStr(var src): String; forward;

procedure NoopSaveLoad;
begin
end;

procedure PrimeSaveLoad;
begin
  MapTiles.PrimeMapTiles;
  EclTrace.PrimeEclTrace;
  ClassCal.PrimeClassCal;
  FxEngine.PrimeFxEngine;
  CharHlp.PrimeCharHlp;
end;

{ Converts a zero-terminated string.
  @param(src The characters.)
  @returns(The characters before the terminator.) }
function CStrToStr(var src): String;
var
  i: Byte;
  s: String;
begin
  i := 0;
  while TCharArr(src)[i] > #0 do
    Inc(i);
  Move(src, s[1], i);
  s[0] := Chr(i);
  CStrToStr := s;
end;

procedure LoadCharlist(var nameList, fileList: Types.PItem);

  { Appends the files matching pattern whose size is expectSize to names (stored names) and files (file names). }
  procedure ScanSaveFiles(pattern: Types.TStr80; name1Ofs, name2Ofs, expectSize: Word; var names, files: Types.PItem);
  var
    nameNode: Types.PItem;
    nameTail: Types.PItem;
    fileNode: Types.PItem;
    fileTail: Types.PItem;
    cr: Types.PCreature;
    sr: SearchRec;
    cnt: Word;
    f: File;
    sourceNote: String[80];
    n2len: Byte;
    buf: array[0..15] of Char;
    { Unused in this version; see the other implementations of this routine. }
    matchCount: Byte;
  begin
    nameNode := nil;
    fileNode := nil;
    FindFirst(pattern, 0, sr);
    while DosError = 0 do begin
      Assign(f, GDVars.savedGamePath + sr.Name);
      Reset(f, 1);
      if FileSize(f) = expectSize then begin
        GetMem(nameNode, SizeOf(Types.TItemNode));
        GetMem(fileNode, SizeOf(Types.TItemNode));
        FillChar(nameNode^, SizeOf(Types.TItemNode), 0);
        FillChar(fileNode^, SizeOf(Types.TItemNode), 0);
        Seek(f, name1Ofs);
        if GDVars.importMode = 2 then begin
          BlockRead(f, buf, SizeOf(buf), cnt);
          nameNode^.name := SaveLoad.CStrToStr(buf);
        end else
          BlockRead(f, nameNode^, 16, cnt);
        Seek(f, name2Ofs);
        if GDVars.importMode = 2 then
          n2len := 0
        else
          BlockRead(f, n2len, SizeOf(n2len));
        fileNode^.name := sr.Name;
        if Copy(sr.Name, 9, 4) = '.SAV' then
          sourceNote := 'from saved game ' + sr.Name[7]
        else
          sourceNote := '';
        nameNode^.name := nameNode^.name + Copy(GDConsts.blankName, 1, 15 - Length(nameNode^.name)) + sourceNote;
        cr := GDVars.partyHead;
        while (cr <> nil) and
            (Copy(nameNode^.name, 1, 15) <> cr^.name + Copy(GDConsts.blankName, 1, 15 - Length(cr^.name))) do
          cr := cr^.next;
        if (n2len > $7F) or (cr <> nil) then begin
          FreeMem(nameNode, SizeOf(Types.TItemNode));
          FreeMem(fileNode, SizeOf(Types.TItemNode));
          nameNode := nil;
          fileNode := nil;
        end;
        if nameNode <> nil then begin
          if names = nil then begin
            names := Types.PItem(nameNode);
            nameTail := Types.PItem(names);
            files := Types.PItem(fileNode);
            fileTail := Types.PItem(files);
          end else begin
            nameTail^.next := nameNode;
            nameTail := nameTail^.next;
            fileTail^.next := fileNode;
            fileTail := fileTail^.next;
          end;
        end;
      end;
      Close(f);
      FindNext(sr);
    end;
  end;

begin
  nameList := nil;
  fileList := nil;
  if SaveLoad.CheckSaveDir then
    case GDVars.importMode of
      0: ScanSaveFiles(GDVars.savedGamePath + '*.guy', GDConsts.primaryNameOfs[GDVars.importMode],
                       GDConsts.secondaryNameOfs[GDVars.importMode],
                       GDConsts.charFileSizes[GDVars.importMode], nameList, fileList);
      1: begin
           ScanSaveFiles(GDVars.savedGamePath + '*.cha', GDConsts.primaryNameOfs[GDVars.importMode],
                         GDConsts.secondaryNameOfs[GDVars.importMode],
                         GDConsts.charFileSizes[GDVars.importMode], nameList, fileList);
           ScanSaveFiles(GDVars.savedGamePath + '*.sav', GDConsts.primaryNameOfs[GDVars.importMode],
                         GDConsts.secondaryNameOfs[GDVars.importMode],
                         GDConsts.charFileSizes[1], nameList, fileList);
         end;
      2: ScanSaveFiles(GDVars.savedGamePath + '*.hil', GDConsts.primaryNameOfs[GDVars.importMode],
                       GDConsts.secondaryNameOfs[GDVars.importMode],
                       GDConsts.charFileSizes[GDVars.importMode], nameList, fileList);
    end;
end;

function CheckSaveDir: Boolean;
var
  err: Integer;
  sr: SearchRec;
  key: Char;
begin
  CheckSaveDir := False;
  case GDVars.importMode of
    0: begin
         repeat
           { Prompt until the save disk is in an accepted drive. }
           while (DaxIo.GetVolumeLabel(GDVars.savedGamePath[1]) = 'CURSE') and (GDVars.savedGamePath[1] < 'C') do
             TextRend.DisplayAndPause(Yellow, 0, 'Put save disk in ' + GDVars.savedGamePath[1] + ':');
           repeat
               FindFirst(Copy(GDVars.savedGamePath, 1, Length(GDVars.savedGamePath) - 1), Directory, sr);
               err := DosError;
               case err of
                 0: ;
                 2, 18:
                   begin
                     if UpCase(GDVars.savedGamePath[1]) < 'C' then begin
                       key := MenuCore.YesNoMenu('Is your save disk in drive ' + GDVars.savedGamePath[1] + ':? ',
                                                 LightMagenta, LightGreen, White);
                       if key <> 'Y' then
                         TextRend.DisplayAndPause(Yellow, 0, 'Put save disk in ' + GDVars.savedGamePath[1] + ':');
                     end;
                     MkDir(Copy(GDVars.savedGamePath, 1, Length(GDVars.savedGamePath) - 1));
                     err := DosError;
                   end;
               else
                 if UpCase(GDVars.savedGamePath[1]) < 'C' then
                   TextRend.DisplayAndPause(Yellow, 0, 'Put save disk in ' + GDVars.savedGamePath[1] + ':')
                 else begin
                   TextRend.DisplayAndPause(Yellow, 0, 'Unexpected error during save: ' + CharHlp.Uint8Str(err));
                   Exit;
                 end;
               end;
             until err in [0, 5];
         until err in [0, 5];
       end;
    1: begin
         repeat
           FindFirst(Copy(GDVars.savedGamePath, 1, Length(GDVars.savedGamePath) - 1), Directory, sr);
           err := DosError;
           if err <> 0 then
             if UpCase(GDVars.savedGamePath[1]) < 'C' then
               TextRend.DisplayAndPause(Yellow, 0, 'Put save disk in ' + GDVars.savedGamePath[1] + ':')
             else begin
               TextRend.DisplayAndPause(Yellow, 0, 'Unexpected error during save: ' + CharHlp.Uint8Str(err));
               Exit;
             end;
         until err = 0;
       end;
    2: begin
         repeat
           FindFirst(Copy(GDVars.savedGamePath, 1, Length(GDVars.savedGamePath) - 1), Directory, sr);
           err := DosError;
           if err <> 0 then
             if UpCase(GDVars.savedGamePath[1]) < 'C' then
               TextRend.DisplayAndPause(Yellow, 0, 'Put save disk in ' + GDVars.savedGamePath[1] + ':')
             else begin
               TextRend.DisplayAndPause(Yellow, 0, 'Unexpected error during save: ' + CharHlp.Uint8Str(err));
               Exit;
             end;
         until err = 0;
       end;
  end;
  CheckSaveDir := True;
end;

procedure MergeIcon(src, dest: Types.PImgBuf);
var
  { Unused in this version; see the other implementations of this routine. }
  count: array[0..1] of Byte;
  i: Word;
begin
  for i := 0 to src^.imgSize - 1 do begin
    dest^.data[i] := dest^.data[i] or src^.data[i];
    dest^.transp^[i] := dest^.transp^[i] and src^.transp^[i];
  end;
end;

procedure LoadCharIconAnim(loading: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  iconIds: array[0..2] of Byte;
  arr1: Types.TColorTab;
  arr2: Types.TColorTab;
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  partIdx: Byte;
begin
  DaxIo.PushState(1);
  with Types.PCreature(GDVars.curChar)^ do begin
    MapTiles.LoadIconAnim('CHEAD' + GDConsts.iconFileClasses[iconSize], iconHead, 11);
    MapTiles.LoadIconAnim('CBODY' + GDConsts.iconFileClasses[iconSize], iconBody, orderNumber);
    SaveLoad.MergeIcon(GDVars.iconImages[11, 0], GDVars.iconImages[orderNumber, 0]);
    SaveLoad.MergeIcon(GDVars.iconImages[11, 1], GDVars.iconImages[orderNumber, 1]);
    if loading then begin
      for i := 0 to 15 do begin
        arr1[i] := i;
        arr2[i] := i;
      end;
      for i := 1 to 6 do begin
        arr2[GDConsts.defaultIconColors[i]] := iconColors[i] and $0F;
        arr2[GDConsts.defaultIconColors[i] + 8] := (iconColors[i] and $F0) shr 4;
      end;
      Blit.RemapPic(Types.TColorTab(arr1), Types.TColorTab(arr2), 0, False,
                    Types.PImgBuf(GDVars.iconImages[orderNumber, 0]));
      Blit.RemapPic(Types.TColorTab(arr1), Types.TColorTab(arr2), 0, False,
                    Types.PImgBuf(GDVars.iconImages[orderNumber, 1]));
    end;
  end;
  MapTiles.FreeIconAnim(11);
  DaxIo.PopState;
  GameIo.DiscardPendingKeys;
end;

procedure DeleteCharacterFiles(cr: Types.PCreature);
var
  tmpName: String[80];
  { Unused in this version; see the other implementations of this routine. }
  fileBuf: array[0..127] of Byte;
begin
  tmpName := GDVars.savedGamePath + DaxIo.SanitizeFileName(cr^.name);
  DaxIo.DeleteIfPresent(tmpName + '.guy');
  DaxIo.DeleteIfPresent(tmpName + '.swg');
  DaxIo.DeleteIfPresent(tmpName + '.fx');
end;

procedure SaveChar(cr: Types.PCharRecord; fname: Types.TStr8);
var
  f: file;
  { target file name, without extension }
  fn: Types.TStr40;
  { '.guy'/'.sav' }
  ext: String[4];
  { retry/overwrite selector 'O'/'N' }
  flag: Char;
  { Unused in this version; see the other implementations of this routine. }
  choice: Byte;
  { item walker }
  it: Types.PItem;
  { effect walker }
  eff: Types.PEffect;
  { Unused in this version; see the other implementations of this routine. }
  nameBuf: array[0..23] of Byte;
  { error from opening the target file }
  err: Integer;
  { on-disk byte total }
  total: Word;
  { extended-key flag from MenuHorizontal }
  redraw: Boolean;
begin
  GDVars.importMode := 0;
  repeat
    if not SaveLoad.CheckSaveDir then Exit;
    total := 0;
    Inc(total, SizeOf(Types.TCreature));
    if Types.PCreature(cr)^.itemsAddr <> nil then begin
      it := Types.PCreature(cr)^.itemsAddr;
      while it <> nil do begin
        Inc(total, SizeOf(Types.TItem));
        it := it^.next;
      end;
    end;
    if Types.PCreature(cr)^.effects <> nil then begin
      eff := Types.PCreature(cr)^.effects;
      while eff <> nil do begin
        Inc(total, SizeOf(Types.TEffect));
        eff := eff^.next;
      end;
    end;
    flag := 'O';
    if total > DiskFree(Ord(UpCase(GDVars.savedGamePath[1])) - 64) then begin
      TextRend.DisplayAndPause(Yellow, 0, 'Can''t save.  No room on this disk.');
      flag := MenuCore.MenuHorizontal('Lose character? ', 'Ok  Try another disk', LightMagenta, LightGreen, White,
                                      False, False, redraw);
    end;
  until flag = 'O';
  if Length(fname) = 0 then begin
    ext := '.guy';
    fn := DaxIo.SanitizeFileName(DaxIo.SanitizeString(cr^.name, '.'));
  end else begin
    ext := '.sav';
    fn := fname;
  end;
  repeat
    Assign(f, GDVars.savedGamePath + fn + ext);
    Reset(f, 1);
    err := DosError;
    if not (err in [0, 2]) then
      if UpCase(GDVars.savedGamePath[1]) < 'C' then
        TextRend.DisplayAndPause(Yellow, 0, 'Put save disk in ' + GDVars.savedGamePath[1] + ':')
      else begin
        TextRend.DisplayAndPause(Yellow, 0, 'Unexpected error during save: ' + CharHlp.Uint8Str(err));
        Close(f);
        Exit;
      end;
  until (err = 0) or (err = 2);
  Close(f);
  flag := 'N';
  while (flag = 'N') and (Length(fname) = 0)
        and DaxIo.FileExists(GDVars.savedGamePath + fn + ext) do begin
    flag := MenuCore.YesNoMenu('Overwrite ' + fn + '? ', Yellow, LightGreen, White);
    if flag = 'N' then begin
      fn := '';
      while Length(fn) = 0 do
        fn := TextRend.ReadString('New file name: ', LightGreen, 0, 8);
    end;
  end;
  Assign(f, GDVars.savedGamePath + fn + ext);
  Rewrite(f, 1);
  BlockWrite(f, cr^, SizeOf(Types.TCreature));
  Close(f);
  DaxIo.DeleteIfPresent(GDVars.savedGamePath + fn + '.swg');
  if Types.PCreature(cr)^.itemsAddr <> nil then begin
    Assign(f, GDVars.savedGamePath + fn + '.swg');
    Rewrite(f, 1);
    it := Types.PCreature(cr)^.itemsAddr;
    while it <> nil do begin
      BlockWrite(f, it^, SizeOf(it^));
      it := it^.next;
    end;
    Close(f);
  end;
  DaxIo.DeleteIfPresent(GDVars.savedGamePath + fn + '.fx');
  if Types.PCreature(cr)^.effects <> nil then begin
    Assign(f, GDVars.savedGamePath + fn + '.fx');
    Rewrite(f, 1);
    eff := Types.PCreature(cr)^.effects;
    while eff <> nil do begin
      BlockWrite(f, eff^, SizeOf(eff^));
      eff := eff^.next;
    end;
    Close(f);
  end;
end;

procedure LoadChar(name: String; cr: Types.PCharRecord; savedGame, askDisk: Boolean);
var
  f: file;
  res: Word;
  tail: Types.PItem;
  itemBuf: Pointer;
  effTail: Types.PEffect;
  effBuf: Pointer;
  msg: String[40];
  ok: Byte;
  savedBuf: Pointer;
  hillsfarRec: PHillsfarRec;
  i: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  retry: Byte;
  curCharBak: Types.PCreature;
  baseName: String[255];
  name15: String[15];
  ext: String[4];
  { Unused in this version; see the other implementations of this routine. }
  nameLen: Byte;

  {$F+}
  { Checks the save directory for an ext file whose stored name is name15. }
  function SavedNameExists: Boolean;
  var
    sr: SearchRec;
    fname: String[15];
    f: file;
  begin
    fname := '';
    FindFirst(GDVars.savedGamePath + '*' + ext, 0, sr);
    while (DosError = 0) and (fname <> name15) do begin
      ok := Byte(DaxIo.OpenWithRetry(GDVars.savedGamePath + sr.Name, msg, #0, f));
      Seek(f, 0);
      BlockRead(f, fname, SizeOf(fname), res);
      Close(f);
      FindNext(sr);
    end;
    SavedNameExists := fname = name15;
  end;

  { Converts the Pool record in savedBuf into cr, keeping the ability scores within the race's limits. }
  procedure ConvertPoolRecord;
  var
    i: ShortInt;
    j: ShortInt;
  begin
    with Types.PCreature(cr)^ do begin
      race := Types.PCharRecord(savedBuf)^.race;
      gender := Types.PCharRecord(savedBuf)^.gender;
      name := Types.PCharRecord(savedBuf)^.name;
      for i := 0 to 5 do begin
        stats[i].permanent := Types.PCharRecord(savedBuf)^.abilities[i];
        case i of
          C_Stat.STRENGTH: begin
               if stats[i].permanent <
                   GDConsts.raceAbilityLimits[race].strMin[gender] then
                 stats[i].permanent := GDConsts.raceAbilityLimits[race].strMin[gender];
               if stats[i].permanent >
                   GDConsts.raceAbilityLimits[race].strMax[gender] then
                 stats[i].permanent := GDConsts.raceAbilityLimits[race].strMax[gender];
             end;
          C_Stat.INTELLIGENCE: begin
               if stats[i].permanent < GDConsts.raceAbilityLimits[race].intMin then
                 stats[i].permanent := GDConsts.raceAbilityLimits[race].intMin;
               if stats[i].permanent > GDConsts.raceAbilityLimits[race].intMax then
                 stats[i].permanent := GDConsts.raceAbilityLimits[race].intMax;
             end;
          C_Stat.WISDOM: begin
               if stats[i].permanent < GDConsts.raceAbilityLimits[race].wisMin then
                 stats[i].permanent := GDConsts.raceAbilityLimits[race].wisMin;
               if stats[i].permanent > GDConsts.raceAbilityLimits[race].wisMax then
                 stats[i].permanent := GDConsts.raceAbilityLimits[race].wisMax;
             end;
          C_Stat.DEXTERITY: begin
               if stats[i].permanent < GDConsts.raceAbilityLimits[race].dexMin then
                 stats[i].permanent := GDConsts.raceAbilityLimits[race].dexMin;
               if stats[i].permanent > GDConsts.raceAbilityLimits[race].dexMax then
                 stats[i].permanent := GDConsts.raceAbilityLimits[race].dexMax;
             end;
          C_Stat.CONSTITUTION: begin
               if stats[i].permanent < GDConsts.raceAbilityLimits[race].conMin then
                 stats[i].permanent := GDConsts.raceAbilityLimits[race].conMin;
               if stats[i].permanent > GDConsts.raceAbilityLimits[race].conMax then
                 stats[i].permanent := GDConsts.raceAbilityLimits[race].conMax;
             end;
          C_Stat.CHARISMA: begin
               if stats[i].permanent < GDConsts.raceAbilityLimits[race].chaMin then
                 stats[i].permanent := GDConsts.raceAbilityLimits[race].chaMin;
               if stats[i].permanent > GDConsts.raceAbilityLimits[race].chaMax then
                 stats[i].permanent := GDConsts.raceAbilityLimits[race].chaMax;
             end;
        end;
        stats[i].current := stats[i].permanent;
      end;
      exStrCur := Types.PCharRecord(savedBuf)^.strExc;
      if GDConsts.raceAbilityLimits[race].exStrMax[gender] >
          stats[C_Stat.STRENGTH].permanent then
        stats[C_Stat.STRENGTH].permanent :=
          GDConsts.raceAbilityLimits[race].exStrMax[gender];
      exStrBase := Types.PCharRecord(savedBuf)^.strExc;
      thac0Base := Types.PCharRecord(savedBuf)^.thac0Base;
      charClass := Types.PCharRecord(savedBuf)^.charClass;
      age := Types.PCharRecord(savedBuf)^.age;
      hpMax := Types.PCharRecord(savedBuf)^.hpMax;
      Move(Types.PCharRecord(savedBuf)^.spellsKnown, knownSpells, 56);
      knownSpells[36] := 0;
      attackLevel := Types.PCharRecord(savedBuf)^.attackLevel;
      iconDim := Types.PCharRecord(savedBuf)^.iconDimensions;
      Move(Types.PCharRecord(savedBuf)^.saves, saves, SizeOf(saves));
      moveRate := Types.PCharRecord(savedBuf)^.movementBase;
      levelHighest := Types.PCharRecord(savedBuf)^.levelHighest;
      levelAtChange := levelHighest;
      drainedLevels := Types.PCharRecord(savedBuf)^.drainedLevels;
      drainedHps := Types.PCharRecord(savedBuf)^.drainedHps;
      levelUndead := Types.PCharRecord(savedBuf)^.levelUndead;
      Move(Types.PCharRecord(savedBuf)^.thiefSkills, thiefSkills, SizeOf(thiefSkills));
      afterEffects := Types.PCharRecord(savedBuf)^.afterEffects;
      npc := Types.PCharRecord(savedBuf)^.npc;
      modified := Types.PCharRecord(savedBuf)^.modified;
      reserved[0] := Types.PCharRecord(savedBuf)^.afterModified;
      reserved[1] := Types.PCharRecord(savedBuf)^.beforeCoins;
      coins[4] := 300;
      Move(Types.PCharRecord(savedBuf)^.classLevels, classLevels, 8);
      charType := Types.PCharRecord(savedBuf)^.charType;
      alignment := Types.PCharRecord(savedBuf)^.alignment;
      Move(Types.PCharRecord(savedBuf)^.attacks, attacks, 2);
      Move(Types.PCharRecord(savedBuf)^.unarmedRollsA, baseRolls, SizeOf(baseRolls));
      Move(Types.PCharRecord(savedBuf)^.unarmedDiceA, baseDice, SizeOf(baseDice));
      Move(Types.PCharRecord(savedBuf)^.unarmedModA, baseMod, SizeOf(baseMod));
      acBase := Types.PCharRecord(savedBuf)^.acBase;
      useStrength := Types.PCharRecord(savedBuf)^.useStrength;
      randomId := Types.PCharRecord(savedBuf)^.randByte;
      experience := Types.PCharRecord(savedBuf)^.experience;
      classMask := Types.PCharRecord(savedBuf)^.itemLimits;
      hpRolled := Types.PCharRecord(savedBuf)^.hpRolled;
      for j := 1 to 3 do begin
        spellSlots[C_Spell.CLERIC_LIST, j] := Types.PCharRecord(savedBuf)^.clericSpells[j];
        spellSlots[C_Spell.MAGE_LIST, j] := Types.PCharRecord(savedBuf)^.mageSpells[j];
      end;
      xpAward := Types.PCharRecord(savedBuf)^.xpAward;
      xpBonusPerHp := Types.PCharRecord(savedBuf)^.xpBonusPerHp;
      portraitHead := Types.PCharRecord(savedBuf)^.portraitHead;
      portraitBody := Types.PCharRecord(savedBuf)^.portraitBody;
      iconHead := Types.PCharRecord(savedBuf)^.iconHead;
      iconBody := Types.PCharRecord(savedBuf)^.iconBody;
      iconSize := Types.PCharRecord(savedBuf)^.iconSize;
      iconColors := Types.PCharRecord(savedBuf)^.iconColors;
      numberOfItems := Types.PCharRecord(savedBuf)^.numberOfItems;
      Move(Types.PCharRecord(savedBuf)^.equipped, equipped, SizeOf(equipped));
      handsEquipped := Types.PCharRecord(savedBuf)^.handsEquipped;
      saveBonus := Types.PCharRecord(savedBuf)^.saveBonus;
      encumbrance := Types.PCharRecord(savedBuf)^.encumbrance;
      status := Types.PCharRecord(savedBuf)^.status;
      enabled := Types.PCharRecord(savedBuf)^.enabled;
      hostile := Types.PCharRecord(savedBuf)^.hostile;
      thac0Cur := Types.PCharRecord(savedBuf)^.thac0Cur;
      Move(Types.PCharRecord(savedBuf)^.acCur, acCur, SizeOf(acCur));
      Move(Types.PCharRecord(savedBuf)^.curAttacks, curAttacks, SizeOf(curAttacks));
      Move(Types.PCharRecord(savedBuf)^.curRollsA, curRolls, SizeOf(curRolls));
      Move(Types.PCharRecord(savedBuf)^.curDiceA, curDice, SizeOf(curDice));
      Move(Types.PCharRecord(savedBuf)^.curModA, curMod, SizeOf(curMod));
      hpCur := Types.PCharRecord(savedBuf)^.hpCur;
      movementCur := Types.PCharRecord(savedBuf)^.movementCur;
    end;
  end;

  { Merges hillsfarRec into cr, keeping the better values, then trains it silently with no class limit. }
  procedure MergeHillsfarRecord;
  var
    i: ShortInt;
    { Unused in this version; see the other implementations of this routine. }
    classIdx: Byte;
    j: ShortInt;
  begin
    with Types.PCreature(cr)^ do begin
      if stats[C_Stat.STRENGTH].permanent < hillsfarRec^.strength then begin
        stats[C_Stat.STRENGTH].permanent := hillsfarRec^.strength;
        stats[C_Stat.STRENGTH].current := hillsfarRec^.strength;
      end;
      if exStrCur < hillsfarRec^.strExc then begin
        exStrCur := hillsfarRec^.strExc;
        exStrBase := hillsfarRec^.strExc;
      end;
      for i := 1 to 5 do
        if stats[i].permanent < hillsfarRec^.otherAbilities[$15 + i] then begin
          stats[i].permanent := hillsfarRec^.otherAbilities[$15 + i];
          stats[i].current := stats[i].permanent;
        end;
      if experience < hillsfarRec^.experience then
        experience := hillsfarRec^.experience;
      if ViewChar.CreatureCoinValueInGold(Pointer(cr)) < hillsfarRec^.gold then begin
        for j := 0 to 4 do
          Money.DropMoney(Types.PCreature(cr), Types.PCreature(cr)^.coins[j], j);
        Money.GivePlatinum(hillsfarRec^.gold div 5);
      end;
      if Types.PCreature(cr)^.age < hillsfarRec^.age then
        Types.PCreature(cr)^.age := hillsfarRec^.age;
      classLevels[C_Class.CLERIC_LEVEL] := Byte(hillsfarRec^.isCleric > 0);
      classLevels[C_Class.MAGE_LEVEL] := Byte(hillsfarRec^.isMage > 0);
      classLevels[C_Class.FIGHTER_LEVEL] := Byte(hillsfarRec^.isFighter > 0);
      classLevels[C_Class.THIEF_LEVEL] := Byte(hillsfarRec^.isThief > 0);
      levelHighest := 1;
      if hillsfarRec^.setsScriptFlag <> 0 then
        scriptFlags[0] := 1;
      GDVars.zone1^[C_Gbvm.TRAIN_MASK] := $FF;
      GDVars.charMenuDone := 0;
      GDVars.autoTraining := True;
      repeat
        CharGen.TrainingMenu;
      until GDVars.charMenuDone <> 0;
      GDVars.autoTraining := False;
      GDVars.curChar := curCharBak;
      hpMax := hillsfarRec^.hpMax;
      hpRolled := hpMax - CharGen.ConHpBonus(Types.PCreature(cr));
      hpCur := hillsfarRec^.hpCur;
    end;
  end;

begin
  if askDisk then
    msg := 'Put save disk in ' + GDVars.savedGamePath[1] + ':'
  else
    msg := GDConsts.diskPrompts[GDVars.diskIndex];
  ok := Byte(DaxIo.OpenWithRetry(GDVars.savedGamePath + name, msg, #0, f));
  TextRend.DisplayString(0, 24, LightGreen, 0, 'Loading...Please Wait');
  FillChar(cr^, SizeOf(Types.TCreature), 0);
  case GDVars.importMode of
    0: begin
         BlockRead(f, cr^, SizeOf(Types.TCreature), res);
         Close(f);
         Types.PCreature(cr)^.itemsAddr := nil;
         Types.PCreature(cr)^.effects := nil;
         Types.PCreature(cr)^.combatAddr := nil;
         Types.PCreature(cr)^.next := nil;
       end;
    1: begin
         GetMem(savedBuf, SizeOf(Types.TCharRecord));
         BlockRead(f, savedBuf^, SizeOf(Types.TCharRecord), res);
         Close(f);
         Types.PCreature(cr)^.itemsAddr := nil;
         Types.PCreature(cr)^.effects := nil;
         Types.PCreature(cr)^.combatAddr := nil;
         Types.PCreature(cr)^.next := nil;
         ConvertPoolRecord;
         FreeMem(savedBuf, SizeOf(Types.TCharRecord));
       end;
    2: begin
         GetMem(hillsfarRec, SizeOf(hillsfarRec^));
         BlockRead(f, hillsfarRec^, SizeOf(hillsfarRec^), res);
         Close(f);
         Types.PCreature(cr)^.itemsAddr := nil;
         Types.PCreature(cr)^.effects := nil;
         Types.PCreature(cr)^.combatAddr := nil;
         Types.PCreature(cr)^.next := nil;
         name15 := SaveLoad.CStrToStr(hillsfarRec^.name4);
         ext := '.guy';
         ok := Byte(SavedNameExists);
         if ok <> 0 then begin
           baseName := name;
           Delete(baseName, Pos('.', name), 4);
           ok := Byte(DaxIo.OpenWithRetry(GDVars.savedGamePath + baseName + ext, msg, #0, f));
           BlockRead(f, cr^, SizeOf(Types.TCreature), res);
           Close(f);
           Types.PCreature(cr)^.itemsAddr := nil;
           Types.PCreature(cr)^.effects := nil;
           Types.PCreature(cr)^.combatAddr := nil;
           Types.PCreature(cr)^.next := nil;
           curCharBak := GDVars.curChar;
           GDVars.curChar := Types.PCreature(cr);
           MergeHillsfarRecord;
           if hillsfarRec^.chimeCharges > 0 then begin
             tail := Types.PItem(CharHlp.MakeItem(70, 168, 167, 87, 0, 0, 0, 0, 0, 0, 0,
                                                  hillsfarRec^.chimeCharges * 200, hillsfarRec^.chimeCharges, 31, 0));
             CharHlp.AddItemCopy(Types.PCreature(cr), Types.PItem(tail));
           end;
           if hillsfarRec^.wandCharges > 0 then begin
             tail := Types.PItem(CharHlp.MakeItem(79, 206, 167, 69, 1, 0, 0, 0, 0, 1, 0, hillsfarRec^.wandCharges * 350,
                                                  hillsfarRec^.wandCharges, 65, 0));
             CharHlp.AddItemCopy(Types.PCreature(cr), Types.PItem(tail));
           end;
           if hillsfarRec^.ringCharges > 0 then begin
             tail := Types.PItem(CharHlp.MakeItem(69, 168, 167, 66, 0, 0, 0, 0, 0, 0, 0, hillsfarRec^.ringCharges * 200,
                                                  hillsfarRec^.ringCharges, 31, 0));
             CharHlp.AddItemCopy(Types.PCreature(cr), Types.PItem(tail));
           end;
           if hillsfarRec^.healingPotions > 0 then begin
             tail := Types.PItem(CharHlp.MakeItem(70, 185, 167, 64, 0, 0, 0, 0, 0, hillsfarRec^.healingPotions * 10, 0,
                                                  hillsfarRec^.healingPotions * 400, hillsfarRec^.healingPotions, 62,
                                                  0));
             CharHlp.AddItemCopy(Types.PCreature(cr), Types.PItem(tail));
           end;
         end else begin
           name15 := SaveLoad.CStrToStr(hillsfarRec^.name4);
           ext := '.cha';
           ok := Byte(SavedNameExists);
           if ok <> 0 then begin
             GetMem(savedBuf, SizeOf(Types.TCharRecord));
             baseName := name;
             Delete(baseName, Pos('.', name), 4);
             ok := Byte(DaxIo.OpenWithRetry(GDVars.savedGamePath + baseName + ext, msg, #0, f));
             BlockRead(f, savedBuf^, SizeOf(Types.TCharRecord), res);
             Close(f);
             ConvertPoolRecord;
             FreeMem(savedBuf, SizeOf(Types.TCharRecord));
             curCharBak := GDVars.curChar;
             GDVars.curChar := Types.PCreature(cr);
             MergeHillsfarRecord;
           end else begin
             curCharBak := GDVars.curChar;
             GDVars.curChar := Types.PCreature(cr);
             with Types.PCreature(cr)^ do begin
               for GDVars.sharedLoopIdx := 1 to 6 do
                 iconColors[GDVars.sharedLoopIdx] := GDConsts.defaultIconColors[GDVars.sharedLoopIdx] +
                     ((GDConsts.defaultIconColors[GDVars.sharedLoopIdx] + 8) * 16);
               acBase := 50;
               thac0Base := 40;
               status := C_Status.OKAY;
               enabled := 1;
               portraitHead := 1;
               portraitBody := 1;
               iconDim := 1;
               randomId := Random(256);
               orderNumber := 10;
               attacks := 2;
               baseRolls[1] := 1;
               baseDice[1] := 2;
               useStrength := 1;
               moveRate := 12;
               name := SaveLoad.CStrToStr(hillsfarRec^.name4);
               stats[C_Stat.STRENGTH].permanent := hillsfarRec^.strength;
               stats[C_Stat.STRENGTH].current := hillsfarRec^.strength;
               exStrCur := hillsfarRec^.strExc;
               exStrBase := hillsfarRec^.strExc;
               for i := 1 to 5 do begin
                 stats[i].permanent := hillsfarRec^.otherAbilities[$15 + i];
                 stats[i].current := stats[i].permanent;
               end;
               race := hillsfarRec^.race + 1;
               if race = C_Race.HALF_ORC then
                 race := C_Race.HUMAN;
               case race of
                 C_Race.HALFLING: begin
                      iconSize := 1;
                      FxEngine.AddEffect(Types.PCreature(cr), C_Effect.CONSTITUTION_SAVE_BONUS, 0, 255, False);
                    end;
                 C_Race.DWARF: begin
                      iconSize := 1;
                      FxEngine.AddEffect(Types.PCreature(cr), C_Effect.CONSTITUTION_SAVE_BONUS, 0, 255, False);
                      FxEngine.AddEffect(Types.PCreature(cr), C_Effect.DWARF_ATTACK_BONUS, 0, 255, False);
                      FxEngine.AddEffect(Types.PCreature(cr), C_Effect.DWARF_GIANT_DEFENSE, 0, 255, False);
                    end;
                 C_Race.GNOME: begin
                      iconSize := 1;
                      FxEngine.AddEffect(Types.PCreature(cr), C_Effect.CONSTITUTION_SAVE_BONUS, 0, 255, False);
                      FxEngine.AddEffect(Types.PCreature(cr), C_Effect.GNOME_ATTACK_BONUS, 0, 255, False);
                      FxEngine.AddEffect(Types.PCreature(cr), C_Effect.DWARF_GIANT_DEFENSE, 0, 255, False);
                      FxEngine.AddEffect(Types.PCreature(cr), C_Effect.GNOME_BUGBEAR_DEFENSE, 0, 255, False);
                    end;
                 C_Race.ELF: begin
                      iconSize := 2;
                      FxEngine.AddEffect(Types.PCreature(cr), C_Effect.ELF_RESISTANCE, 0, 255, False);
                    end;
                 C_Race.HALF_ELF: begin
                      iconSize := 2;
                      FxEngine.AddEffect(Types.PCreature(cr), C_Effect.HALF_ELF_RESISTANCE, 0, 255, False);
                    end;
               else
                 iconSize := 2;
               end;
               charClass := GDConsts.importClassMap[hillsfarRec^.classCode and $F];
               age := hillsfarRec^.age;
               classLevels[C_Class.CLERIC_LEVEL] := Byte(hillsfarRec^.isCleric > 0);
               classLevels[C_Class.MAGE_LEVEL] := Byte(hillsfarRec^.isMage > 0);
               classLevels[C_Class.FIGHTER_LEVEL] := Byte(hillsfarRec^.isFighter > 0);
               classLevels[C_Class.THIEF_LEVEL] := Byte(hillsfarRec^.isThief > 0);
               levelHighest := 1;
               gender := hillsfarRec^.gender;
               alignment := hillsfarRec^.alignment;
               experience := hillsfarRec^.experience;
               if classLevels[C_Class.MAGE_LEVEL] > 0 then begin
                 knownSpells[11] := 1;
                 knownSpells[18] := 1;
                 knownSpells[19] := 1;
                 knownSpells[21] := 1;
               end;
               GDVars.zone1^[C_Gbvm.TRAIN_MASK] := $FF;
               GDVars.charMenuDone := 0;
               GDVars.autoTraining := True;
               repeat
                 CharGen.TrainingMenu;
               until GDVars.charMenuDone <> 0;
               GDVars.autoTraining := False;
               Money.GivePlatinum(300);
               GDVars.curChar := curCharBak;
               hpMax := hillsfarRec^.hpMax;
               hpRolled := hpMax - CharGen.ConHpBonus(Types.PCreature(cr));
               hpCur := hillsfarRec^.hpCur;
             end;
           end;
         end;
         FreeMem(hillsfarRec, SizeOf(hillsfarRec^));
       end;
  end;
  if GDVars.importMode = 0 then
    Delete(name, Pos('.', name), 4)
  else
    name := DaxIo.SanitizeFileName(cr^.name);
  if DaxIo.FileExists(GDVars.savedGamePath + name + '.swg') then begin
    GetMem(itemBuf, SizeOf(Types.TItem));
    ok := Byte(DaxIo.OpenWithRetry(GDVars.savedGamePath + name + '.swg', msg, #0, f));
    repeat
      BlockRead(f, itemBuf^, SizeOf(Types.TItem), res);
      if res = 63 then begin
        if Types.PCreature(cr)^.itemsAddr = nil then begin
          GetMem(Types.PCreature(cr)^.itemsAddr, SizeOf(Types.TItem));
          tail := Types.PCreature(cr)^.itemsAddr;
        end else begin
          GetMem(tail^.next, SizeOf(tail^.next^));
          tail := tail^.next;
        end;
        tail^ := Types.PItem(itemBuf)^;
        tail^.next := nil;
      end;
    until res <> 63;
    Close(f);
    FreeMem(itemBuf, SizeOf(Types.TItem));
  end;
  if DaxIo.FileExists(GDVars.savedGamePath + name + '.fx') then begin
    GetMem(effBuf, SizeOf(Types.TEffect));
    ok := Byte(DaxIo.OpenWithRetry(GDVars.savedGamePath + name + '.fx', msg, #0, f));
    repeat
      BlockRead(f, effBuf^, SizeOf(Types.TEffect), res);
      if res = 9 then begin
        if Types.PCreature(cr)^.effects = nil then begin
          GetMem(Types.PCreature(cr)^.effects, SizeOf(Types.TEffect));
          effTail := Types.PCreature(cr)^.effects;
        end else begin
          GetMem(effTail^.next, SizeOf(effTail^.next^));
          effTail := effTail^.next;
        end;
        effTail^ := Types.PEffect(effBuf)^;
        effTail^.next := nil;
      end;
    until res <> 9;
    Close(f);
    FreeMem(effBuf, SizeOf(Types.TEffect));
  end;
  if GDVars.importMode = 1 then
    if DaxIo.FileExists(GDVars.savedGamePath + name + '.spc') then begin
      GetMem(effBuf, SizeOf(Types.TEffect));
      ok := Byte(DaxIo.OpenWithRetry(GDVars.savedGamePath + name + '.spc', msg, #0, f));
      repeat
        BlockRead(f, effBuf^, SizeOf(Types.TEffect), res);
        if res = 9 then
          if Types.PEffect(effBuf)^.id in [18, 26, 47, 48, 97, 107, 124] then begin
            if Types.PCreature(cr)^.effects = nil then begin
              GetMem(Types.PCreature(cr)^.effects, SizeOf(Types.TEffect));
              effTail := Types.PCreature(cr)^.effects;
            end else begin
              GetMem(effTail^.next, SizeOf(effTail^.next^));
              effTail := effTail^.next;
            end;
            effTail^ := Types.PEffect(effBuf)^;
            effTail^.next := nil;
          end;
      until res <> 9;
      Close(f);
      FreeMem(effBuf, SizeOf(Types.TEffect));
    end;
  GameIo.DiscardPendingKeys;
  CharHlp.RecalcStats(Types.PCreature(cr));
  ClassCal.RecalcClassStats(Types.PCreature(cr));
end;

procedure LoadCreatureData(id: Byte; cr: Types.PCharRecord);
var
  size: Word;
  data: Types.PByteArr;
  offset: Word;
  it: Types.PItem;
  eff: Types.PEffect;
  numStr: String[1];
  { Unused in this version; see the other implementations of this routine. }
  itemIdx: array[0..1] of Byte;
begin
  Str(GDVars.diskIndex, numStr);
  DaxIo.LoadDax('MON' + numStr + 'CHA', '.dax', id, size, data);
  if size = 0 then begin
    TextRend.DisplayAndPause(White, 0, 'Unable to load monster');
    GameIo.ExitGame;
  end;
  Move(data^, cr^, SizeOf(Types.TCreature));
  with Types.PCreature(cr)^ do begin
    itemsAddr := nil;
    effects := nil;
    next := nil;
    combatAddr := nil;
  end;
  FreeMem(data, size);
  GDVars.suppressDiskPrompt := #1;

  DaxIo.LoadDax('MON' + numStr + 'SPC', '.dax', id, size, data);
  if size <> 0 then begin
    offset := 0;
    GetMem(Types.PCreature(cr)^.effects, SizeOf(Types.TEffect));
    eff := Types.PCreature(cr)^.effects;
    repeat
      Move(data^[offset], eff^, SizeOf(eff^));
      eff^.next := nil;
      Inc(offset, SizeOf(eff^));
      if offset < size then begin
        GetMem(eff^.next, SizeOf(eff^.next^));
        eff := eff^.next;
      end;
    until offset >= size;
    FreeMem(data, size);
  end;

  DaxIo.LoadDax('MON' + numStr + 'ITM', '.dax', id, size, data);
  if size <> 0 then begin
    offset := 0;
    GetMem(Types.PCreature(cr)^.itemsAddr, SizeOf(Types.TItem));
    it := Types.PCreature(cr)^.itemsAddr;
    repeat
      Move(data^[offset], it^, SizeOf(it^));
      it^.next := nil;
      Inc(offset, SizeOf(it^));
      if offset < size then begin
        GetMem(it^.next, SizeOf(it^.next^));
        it := it^.next;
      end;
    until offset >= size;
    FreeMem(data, size);
  end;

  GDVars.suppressDiskPrompt := #0;
  GameIo.DiscardPendingKeys;
end;

procedure AddCreatureToParty(id: Byte);
var
  { Unused in this version; see the other implementations of this routine. }
  node: Pointer;
  cr: Types.PCreature;
  { Unused in this version; see the other implementations of this routine. }
  slot: Byte;
begin
  if GDVars.zone1^[C_Gbvm.PARTY_SIZE] > 7 then Exit;
  GetMem(cr, SizeOf(cr^));
  SaveLoad.LoadCreatureData(id, Types.PCharRecord(cr));
  cr^.randomId := id;
  SaveLoad.AddCharToParty(Types.PCharRecord(cr));
  MapTiles.LoadIconAnim('CPIC', id, cr^.orderNumber);
end;

procedure AddCharToParty(cr: Types.PCharRecord);
var
  p: Types.PCreature;
  used: array[0..7] of Byte;
begin
  Types.PCreature(cr)^.orderNumber := 255;
  if GDVars.partyHead = nil then
    GDVars.partyHead := Types.PCreature(cr)
  else begin
    p := GDVars.partyHead;
    while p^.next <> nil do
      p := p^.next;
    p^.next := Types.PCreature(cr);
  end;
  GDVars.curChar := Types.PCreature(cr);
  FillChar(used, SizeOf(used), 0);
  p := GDVars.partyHead;
  while p <> nil do begin
    if p^.orderNumber in [0..7] then
      used[p^.orderNumber] := 1;
    p := p^.next;
  end;
  with GDVars.curChar^ do begin
    orderNumber := 0;
    while (orderNumber < 8) and (used[orderNumber] <> 0) do
      Inc(orderNumber);
  end;
  Inc(GDVars.zone1^[C_Gbvm.PARTY_SIZE]);
  if Types.PCreature(cr)^.npc > 127 then
    ClassCal.RecalcClassStats(Types.PCreature(cr));
end;

procedure LoadGame;
var
  names: array[1..8] of String[40];
  f: file;
  i: Byte;
  cr: Types.PCreature;
  sanName: String[40];
  res: Word;
  partyRead: Byte;
  { Unused in this version; see the other implementations of this routine. }
  openRes: Boolean;
  ch: Char;
  ext: Boolean;
  menu: String[20];
begin
  GDVars.importMode := 0;
  if not SaveLoad.CheckSaveDir then Exit;
  menu := '';
  for ch := 'A' to 'J' do
    if DaxIo.FileExists(GDVars.savedGamePath + 'savgam' + ch + '.dat') then
      menu := menu + ch + ' ';
  if Length(menu) = 0 then Exit;
  Delete(menu, Length(menu), 1);
  repeat
    ch := MenuCore.MenuHorizontal('Load Which Game: ', menu, LightMagenta, LightGreen, White, False, False, ext);
  until ((ch in ['A'..'J']) and DaxIo.FileExists(GDVars.savedGamePath + 'savgam' + ch + '.dat')) or (ch = C_Keys.NONE);
  if ch = C_Keys.NONE then Exit;
  openRes := DaxIo.OpenWithRetry(GDVars.savedGamePath + 'savgam' + ch + '.dat',
                                 'Put save disk in ' + GDVars.savedGamePath, #1, f);
  MenuCore.ClearBottomLine;
  TextRend.DisplayString(0, 24, LightGreen, 0, 'Loading...Please Wait');
  GDVars.loadedSavedGame := True;
  BlockRead(f, GDVars.diskIndex, SizeOf(GDVars.diskIndex), res);
  BlockRead(f, GDVars.zone0^, SizeOf(GDVars.zone0^), res);
  BlockRead(f, GDVars.zone1^, SizeOf(GDVars.zone1^), res);
  BlockRead(f, GDVars.zone2^, SizeOf(GDVars.zone2^), res);
  BlockRead(f, GDVars.scriptCode^, SizeOf(GDVars.scriptCode^), res);
  BlockRead(f, GDVars.partyPos, SizeOf(GDVars.partyPos), res);
  BlockRead(f, GDVars.prevIfcState, SizeOf(GDVars.prevIfcState), res);
  BlockRead(f, GDVars.ifcState, SizeOf(GDVars.ifcState), res);
  for i := 1 to 3 do begin
    BlockRead(f, GDVars.wallDefinitions[i].wallDefId, SizeOf(GDVars.wallDefinitions[i].wallDefId), res);
    BlockRead(f, GDVars.wallDefinitions[i].symbolSlot, SizeOf(GDVars.wallDefinitions[i].symbolSlot), res);
  end;
  BlockRead(f, partyRead, SizeOf(partyRead), res);
  BlockRead(f, names, SizeOf(names), res);
  Close(f);
  GDVars.picsOn := GDVars.zone0^[SaveLoad.SAVED_PICTURE_FLAGS] div 2;
  GDVars.animOn := GDVars.zone0^[SaveLoad.SAVED_PICTURE_FLAGS] and 1;
  GDVars.gameDelay := Lo(GDVars.zone0^[SaveLoad.SAVED_SPEED]);
  GDVars.zone1^[C_Gbvm.PARTY_SIZE] := 0;
  for i := 1 to partyRead do begin
    sanName := DaxIo.SanitizeFileName(DaxIo.SanitizeString(names[i], '.'));
    if DaxIo.FileExists(GDVars.savedGamePath + sanName + '.sav') then begin
      GetMem(cr, SizeOf(cr^));
      SaveLoad.LoadChar(sanName + '.sav', Types.PCharRecord(cr), True, True);
      SaveLoad.AddCharToParty(Types.PCharRecord(cr));
      if not SaveLoad.CheckSaveDir then Exit;
    end;
  end;
  cr := GDVars.partyHead;
  while cr <> nil do begin
    SaveLoad.DeleteCharacterFiles(cr);
    cr := cr^.next;
  end;
  GDVars.curChar := GDVars.partyHead;
  while GDVars.curChar <> nil do begin
    if GDVars.curChar^.npc < $80 then
      SaveLoad.LoadCharIconAnim(True)
    else
      MapTiles.LoadIconAnim('CPIC', GDVars.curChar^.randomId, GDVars.curChar^.orderNumber);
    GDVars.curChar := GDVars.curChar^.next;
  end;
  GDVars.curChar := GDVars.partyHead;
  { the data disk saved with the game; SaveGame writes the whole word }
  GDVars.diskIndex := Lo(GDVars.zone1^[SaveLoad.DATA_DISK]);
  if GDVars.zone0^[C_Gbvm.VIEW_3D] <> 0 then begin
    if GDVars.ifcState <> 0 then begin
      if Integer(GDVars.wallDefinitions[1].wallDefId) > 0 then View3D.Load3DMap(Lo(GDVars.zone0^[C_Gbvm.GEO_MAP_ID]));
      for i := 1 to 3 do
        if Integer(GDVars.wallDefinitions[i].wallDefId) > 0 then
          View3D.LoadWallSet(GDVars.wallDefinitions[i].wallDefId, GDVars.wallDefinitions[i].symbolSlot);
    end;
  end else
    Portrait.LoadBigPic(C_Pic.BIGPIC_OVERLAND);
  GameIo.DiscardPendingKeys;
  MenuCore.ClearBottomLine;
  GDVars.prevIfcState := GDVars.ifcState;
  GDVars.ifcState := 0;
end;

procedure SaveGame;

  { Returns the bytes the members' files need: 422 each plus 63 per item and 9 per effect. }
  function ComputePartySaveSize: Word;
  var
    cr: Types.PCreature;
    it: Types.PItem;
    eff: Types.PEffect;
    total: Word;
  begin
    total := 0;
    cr := GDVars.partyHead;
    while cr <> nil do begin
      Inc(total, SizeOf(Types.TCreature));
      if cr^.itemsAddr <> nil then begin
        it := cr^.itemsAddr;
        while it <> nil do begin
          Inc(total, SizeOf(Types.TItem));
          it := it^.next;
        end;
      end;
      if cr^.effects <> nil then begin
        eff := cr^.effects;
        while eff <> nil do begin
          Inc(total, SizeOf(Types.TEffect));
          eff := eff^.next;
        end;
      end;
      cr := cr^.next;
    end;
    ComputePartySaveSize := total;
  end;

var
  charNames: array[1..8] of Types.TStr40;
  f: file;
  i: Byte;
  cr: Types.PCreature;
  numStr: String[1];
  { Unused in this version; see the other implementations of this routine. }
  fileName: String[40];
  sel: Boolean;
  choice: Char;
  err: Integer;
  needed: Word;
begin
  repeat
    choice := MenuCore.MenuHorizontal('Save Which Game: ', 'A B C D E F G H I J', LightMagenta, LightGreen, White,
                                      False, GDVars.ifcState = C_Ifc.CAMPING, sel);
  until choice in [C_Keys.NONE, 'A'..'J'];
  if choice = C_Keys.NONE then Exit;
  GDVars.importMode := 0;
  if not SaveLoad.CheckSaveDir then Exit;
  if DaxIo.FileExists(GDVars.savedGamePath + 'savgam' + choice + '.dat') then
    needed := 0
  else
    { 12808 bytes: the disk number, the four GBVM banks, the party position and the interface states; the wall-set
      slots, member count and member names (341 bytes more) go uncounted. }
    needed := 12808;
  Inc(needed, ComputePartySaveSize);
  if needed > DiskFree(Ord(UpCase(GDVars.savedGamePath[1])) - 64) then begin
    TextRend.DisplayAndPause(Yellow, 0, 'Can''t save.  No room on this disk.');
    Exit;
  end;
  repeat
    Assign(f, GDVars.savedGamePath + 'savgam' + choice + '.dat');
    Rewrite(f, 1);
    err := DosError;
    if not (err in [0, 2, 18]) then
      if UpCase(GDVars.savedGamePath[1]) < 'C' then
        TextRend.DisplayAndPause(Yellow, 0, 'Put save disk in ' + GDVars.savedGamePath[1] + ':')
      else begin
        TextRend.DisplayAndPause(Yellow, 0, 'Unexpected error during save: ' + CharHlp.Uint8Str(err));
        Close(f);
        Exit;
      end;
  until err in [0, 2, 18];
  MenuCore.ClearBottomLine;
  TextRend.DisplayString(0, 24, LightGreen, 0, 'Saving...Please Wait');
  GDVars.zone0^[SaveLoad.SAVED_SPEED] := GDVars.gameDelay;
  GDVars.zone0^[SaveLoad.SAVED_PICTURE_FLAGS] := GDVars.picsOn * 2 + GDVars.animOn;
  GDVars.zone1^[SaveLoad.DATA_DISK] := GDVars.diskIndex;
  BlockWrite(f, GDVars.diskIndex, SizeOf(GDVars.diskIndex));
  BlockWrite(f, GDVars.zone0^, SizeOf(GDVars.zone0^));
  BlockWrite(f, GDVars.zone1^, SizeOf(GDVars.zone1^));
  BlockWrite(f, GDVars.zone2^, SizeOf(GDVars.zone2^));
  BlockWrite(f, GDVars.scriptCode^, SizeOf(GDVars.scriptCode^));
  BlockWrite(f, GDVars.partyPos, SizeOf(GDVars.partyPos));
  BlockWrite(f, GDVars.prevIfcState, SizeOf(GDVars.prevIfcState));
  BlockWrite(f, GDVars.ifcState, SizeOf(GDVars.ifcState));
  for i := 1 to 3 do begin
    BlockWrite(f, GDVars.wallDefinitions[i].wallDefId, SizeOf(GDVars.wallDefinitions[i].wallDefId));
    BlockWrite(f, GDVars.wallDefinitions[i].symbolSlot, SizeOf(GDVars.wallDefinitions[i].symbolSlot));
  end;
  i := 0;
  cr := GDVars.partyHead;
  while cr <> nil do begin
    Inc(i);
    Str(i, numStr);
    charNames[i] := 'CHRDAT' + choice + numStr;
    cr := cr^.next;
  end;
  BlockWrite(f, i, SizeOf(i));
  BlockWrite(f, charNames, SizeOf(charNames));
  Close(f);
  cr := GDVars.partyHead;
  i := 0;
  while cr <> nil do begin
    Inc(i);
    Str(i, numStr);
    SaveLoad.SaveChar(Types.PCharRecord(cr), 'CHRDAT' + choice + numStr);
    SaveLoad.DeleteCharacterFiles(cr);
    cr := cr^.next;
  end;
  GDVars.recentlySaved := 1;
  MenuCore.ClearBottomLine;
end;

begin
end.
