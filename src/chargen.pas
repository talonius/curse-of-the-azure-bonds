{ The party main menu: character creation, modification and training, the portrait and icon editor, and adding, dropping
  and removing party members. }
{$O+,F+}
{$A-}
unit CharGen;

interface

uses Types, GDConsts, GDVars, C_Keys, C_Race, C_Class, C_Ifc, C_Stat, C_Status, C_Gbvm, C_Effect, C_Pic,
  C_Spell, CharHlp, ViewChar, ClassCal, Border, CbtMap, Blit, Crt, GameIo, MenuCore, TextRend, FxEngine, MapTiles,
  Magic, Portrait, SaveLoad, EclTrace;

type
  { Non-negative alignment value used by the evil-alignment test. }
  TNonNegAlign = 0..127;
  { A class or race number as an ordinal, for case labels. }
  TOrdIdx = (oi0, oi1, oi2, oi3, oi4, oi5, oi6, oi7, oi8,
             oi9, oi10, oi11, oi12, oi13, oi14, oi15, oi16);

{ Runs the party main menu: Create, Drop, Modify, Train, Human dual-class (H), View, Add, Remove, Load, Save, Begin
  adventuring and Exit, offered by whether a character is selected and whether a training hall is open. Home and End
  change the current character. Remove saves a non-NPC before removing it and drops an NPC. Any key but E or S marks the
  party unsaved, and Exit offers to save an unsaved party. J toggles free training when the second command-line
  parameter equals the shared command text. Begin needs a party whose zone-0 victory flag is clear (or demo mode); it
  restores the interface state, redraws the view frame, closes the training hall and returns. }
procedure MainMenu;

{ Adds saved characters from Curse, Pool or Hillsfar (GDVars.importMode) to the party. A pick not yet marked is loaded
  and marked '* '. It joins unless it is already in the party (same name and identity byte) or the party is full (6
  non-NPCs, 8 members), or a paladin would join an evil character, a fourth ranger would join, or an evil character
  would join a paladin. The first character into an empty party joins unchecked. A rejection removes the mark, names the
  reason (except for a duplicate or a full party) and frees the record. Ends on Exit, Escape or a full party. Note: the
  record list is never freed. }
procedure AddCharacterMenu;

{ Unlinks the current character from the creature list and frees it. The current character becomes the previous one, or
  the next one when it was first; with no current character the list head becomes current. A current character not in
  the list is left alone.
  @param(suppressSizeDec Keeps the party size unchanged when set; otherwise it drops by one.)
  @param(freeAnim Also frees the character's icon animation when set.) }
procedure RemoveCreature(suppressSizeDec, freeAnim: Boolean);

{ Edits the current character's combat icon: its head (0..13) and body (0..31), its colors (hair or face, by part; not
  on CGA) and its icon size (small or large), previewing in icon slot 12 beside the old icon with the combat palette.
  Keep commits a sub-edit and Exit or Escape reverts it; leaving the top menu copies the result back to the character's
  icon slot. Repeats until the player accepts the icon. }
procedure CustomizePortrait;

{ Calls the priming entry of each overlay this unit uses, so the overlay manager loads them. }
procedure PrimeCharGen;

{ Trains the current character for 1000 gp. Refuses one who is not conscious, has under 1000 gp, has no class this hall
  teaches (the low byte of the training mask) or lacks the experience. Free training, silent mode (used by
  CreateCharacterMenu) and the victory-start flag skip the gold check and the fee; free training also skips the others.
  Applies the racial level limits. Interactively, the trainable class with the highest next-level requirement is the one
  that trains, and experience is clamped to one below any level + 2 threshold already reached; silently, each trainable
  class trains. Each trained class gains a level and restores one drained level. A new magic-user level, or a ranger
  above level 8, picks one spell (silent mode grants fixed spells at magic-user levels 2..5). While the highest level is
  above the level at the class change, hit points grow by the rolled dice plus the Con bonus divided by the class count,
  at least 1. Having nothing to train sets the character menu's done flag. Note: picking the class with the highest
  requirement reads each class's requirement at the level of the last class the character has. }
procedure TrainingMenu;

{ Computes a character's Constitution hit-point bonus: the table bonus for its Con once per class below that class's Con
  cap, plus, for a single-class fighter, paladin or ranger, 1 at Con 17, 2 at 18, 3 at 19..20, 4 at 21..23 and 5 at
  24..25. A first-level ranger class doubles the total accumulated so far.
  @param(cr The character.)
  @returns(The hit-point bonus, which may be negative.) }
function ConHpBonus(cr: Types.PCreature): ShortInt;

implementation

const
  { class values (TCreature.charClass) }
  CLASS_MONK = 7;
  CLASS_CLERIC_THIEF = 12;

  { the Del key's extended scan code }
  DELETE_KEY = #83;

type
  TStartingHitDieSidesView = record t: array[0..7] of Byte; end;

var
  { startingHitDieSides by class level index 0..7: the monk's sides, class 7, are the first byte of cureEffects. }
  startingHitDieSidesView: TStartingHitDieSidesView absolute GDConsts.startingHitDieSides;

procedure PrimeCharGen;
begin
  CharHlp.PrimeCharHlp;
  ViewChar.PrimeViewChar;
  Magic.PrimeMagic;
  FxEngine.PrimeFxEngine;
  Portrait.PrimePortrait;
  MapTiles.PrimeMapTiles;
  SaveLoad.PrimeSaveLoad;
  MenuCore.PrimeMenuCore;
  CbtMap.PrimeCbtMap;
  EclTrace.PrimeEclTrace;
  ClassCal.PrimeClassCal;
end;

procedure CreateCharacterMenu; forward;

procedure DropCharacterMenu; forward;

procedure ModifyCharacterMenu; forward;

function HpMaximum(cr: Types.PCreature): Byte; forward;

function HpMinimum(cr: Types.PCreature): Byte; forward;

function RollFirstLevelHp(cr: Types.PCreature; mask: Byte): Byte; forward;

{ Frees a character's combat record, items and effects, then the record itself.
  @param(creature The character to free; set to nil.) }
procedure FreeCreature(var creature: Types.PCreature);
var
  hold: Types.PItem;
  it: Types.PItem;
  holdE: Types.PEffect;
  eff: Types.PEffect;
begin
  with creature^ do begin
    if combatAddr <> nil then
      FreeMem(combatAddr, SizeOf(combatAddr^));
    it := itemsAddr;
    while it <> nil do begin
      hold := it;
      it := it^.next;
      FreeMem(hold, SizeOf(hold^));
    end;
    eff := effects;
    while eff <> nil do begin
      holdE := eff;
      eff := eff^.next;
      FreeMem(holdE, SizeOf(holdE^));
    end;
  end;
  FreeMem(creature, SizeOf(creature^));
  creature := nil;
end;

function ClassConAdj(cls: Byte): ShortInt; forward;

procedure MainMenu;
var
  { menu-display index }
  i: Byte;
  { pressed key }
  ch: Char;
  { MenuHorizontal extended-key flag }
  ext: Boolean;
  { ViewChar.ViewCharMenu out-flag }
  ext2: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  menuEnabled: array[1..9] of Byte;
  { displayed-row counter }
  n: ShortInt;
  redraw: Boolean;
  { saved interface state (restored on Begin) }
  stateB: Byte;
  { whether the H item applied before the character changed }
  before: Boolean;
begin
  stateB := GDVars.ifcState;
  GDVars.ifcState := 0;
  redraw := True;
  GDVars.stingMode := 0;
  while True do begin
    if redraw then begin
      Border.DrawWindowFrame;
      if GDVars.curChar <> nil then begin
        CharHlp.DisplayParty(Types.PCreature(GDVars.curChar));
        GDConsts.characterVerticalMenus[1].enabled := True;
        GDConsts.characterVerticalMenus[2].enabled := True;
        if (GDVars.zone1^[C_Gbvm.TRAIN_MASK] > 0) or (GDVars.stingMode <> 0) then
          GDConsts.characterVerticalMenus[3].enabled := True;
        GDConsts.characterVerticalMenus[4].enabled := ((GDVars.zone1^[C_Gbvm.TRAIN_MASK] > 0) or
                                                       (GDVars.stingMode <> 0)) and
          Boolean(ClassCal.IsHuman(Types.PCreature(GDVars.curChar))) and
          (ClassCal.FirstEarlierClass(Types.PCreature(GDVars.curChar)) = 17);
        GDConsts.characterVerticalMenus[5].enabled := True;
        GDConsts.characterVerticalMenus[7].enabled := True;
        GDConsts.characterVerticalMenus[8].enabled := False;
        GDConsts.characterVerticalMenus[9].enabled := True;
        GDConsts.characterVerticalMenus[10].enabled := True;
      end else begin
        GDConsts.characterVerticalMenus[1].enabled := False;
        GDConsts.characterVerticalMenus[2].enabled := False;
        GDConsts.characterVerticalMenus[3].enabled := False;
        GDConsts.characterVerticalMenus[4].enabled := False;
        GDConsts.characterVerticalMenus[5].enabled := False;
        GDConsts.characterVerticalMenus[7].enabled := False;
        GDConsts.characterVerticalMenus[8].enabled := True;
        GDConsts.characterVerticalMenus[9].enabled := False;
        GDConsts.characterVerticalMenus[10].enabled := False;
      end;
      n := 0;
      for i := 0 to 11 do
        if GDConsts.characterVerticalMenus[i].enabled then begin
          TextRend.DisplayString(2, n + 12, White, 0, GDConsts.characterVerticalMenus[i].name[1]);
          TextRend.DisplayString(3, n + 12, LightGreen, 0,
                                 Copy(GDConsts.characterVerticalMenus[i].name, 2,
                                      Length(GDConsts.characterVerticalMenus[i].name) - 1));
          Inc(n);
        end;
      redraw := False;
    end;
    ch := MenuCore.MenuHorizontal('Choose a function ', GDConsts.charMenu, LightMagenta, 0, 0, True, False, ext);
    MenuCore.ClearBottomLine;
    if ext then begin
      if ch in [C_Keys.HOME, C_Keys.END_KEY] then begin
        before := Boolean(ClassCal.IsHuman(Types.PCreature(GDVars.curChar)))
                  and (ClassCal.FirstEarlierClass(Types.PCreature(GDVars.curChar)) = 17);
        ViewChar.SelectPrevNextChar(ch);
        CharHlp.DisplayParty(Types.PCreature(GDVars.curChar));
        redraw := ((Boolean(ClassCal.IsHuman(Types.PCreature(GDVars.curChar))) and
                    (ClassCal.FirstEarlierClass(Types.PCreature(GDVars.curChar)) = 17)) xor before)
                  and (GDVars.zone1^[C_Gbvm.TRAIN_MASK] > 0);
      end;
    end else begin
      if not (ch in ['E', 'S']) then
        GDVars.recentlySaved := 0;
      case ch of
        'C':
          if GDConsts.characterVerticalMenus[0].enabled then CharGen.CreateCharacterMenu;
        'D':
          if GDConsts.characterVerticalMenus[1].enabled then CharGen.DropCharacterMenu;
        'M':
          if GDConsts.characterVerticalMenus[2].enabled then CharGen.ModifyCharacterMenu;
        'T':
          if GDConsts.characterVerticalMenus[3].enabled then CharGen.TrainingMenu;
        'H':
          if GDConsts.characterVerticalMenus[4].enabled then ClassCal.ChangeClass(Types.PCreature(GDVars.curChar));
        'V':
          if GDConsts.characterVerticalMenus[5].enabled then ViewChar.ViewCharMenu(ext2);
        'A':
          if GDConsts.characterVerticalMenus[6].enabled then CharGen.AddCharacterMenu;
        'R':
          if (GDConsts.characterVerticalMenus[7].enabled) and (GDVars.curChar <> nil) then begin
            if GDVars.curChar^.npc < $80 then begin
              SaveLoad.SaveChar(Types.PCharRecord(GDVars.curChar), '');
              CharGen.RemoveCreature(False, True);
            end else
              CharGen.DropCharacterMenu;
          end;
        'L':
          if GDConsts.characterVerticalMenus[8].enabled then SaveLoad.LoadGame;
        'S':
          if (GDConsts.characterVerticalMenus[9].enabled) and (GDVars.partyHead <> nil) then SaveLoad.SaveGame;
        'B':
          if GDConsts.characterVerticalMenus[10].enabled then
            if ((GDVars.partyHead <> nil) and (GDVars.zone0^[C_Gbvm.GAME_WON] = 0)) or GDVars.demoMode then begin
              GDVars.ifcState := stateB;
              if not GDVars.loadedSavedGame and (GDVars.loadedPicId <> C_Pic.VILLAGE) then begin
                if GDVars.ifcState = C_Ifc.OVERLAND then
                  Border.DrawRowDivider
                else
                  Border.DrawViewFrame;
                CharHlp.DisplayParty(Types.PCreature(GDVars.curChar));
              end else begin
                if GDVars.zone0^[C_Gbvm.PREV_SCRIPT] = 0 then
                  Border.DrawViewFrame;
              end;
              MenuCore.ClearBottomLine;
              GDVars.zone1^[C_Gbvm.TRAIN_MASK] := 0;
              Exit;
            end;
        'E':
          if GDConsts.characterVerticalMenus[11].enabled then begin
            ch := MenuCore.YesNoMenu('Quit to DOS ', Yellow, LightGreen, White);
            if ch = 'Y' then
            begin
              if (GDVars.partyHead <> nil) and (GDVars.recentlySaved = 0) then begin
                ch := MenuCore.YesNoMenu('Game not saved.  Quit anyway? ', Yellow, LightGreen, White);
                if ch = 'N' then SaveLoad.SaveGame;
              end;
              if ch = 'Y' then GameIo.ExitGame;
            end;
          end;
        'J':
          if ParamStr(2) = GDVars.commandText then begin
            GDVars.stingMode := Ord(GDVars.stingMode = 0);
            if GDVars.stingMode <> 0 then
              CharHlp.PrintBottomLine('Free training on')
            else
              CharHlp.PrintBottomLine('Free training off');
          end;
      end;
      redraw := True;
    end;
  end;
end;

{ Creates a character: pick race (half-orcs are not offered), gender, class and alignment, each from the tables for the
  earlier picks, and set the starting age, racial effects and experience (25000, split among multiple classes). Then
  roll until the player keeps the result: each ability is the best of six 3d6 + 1 rolls, adjusted for age and clamped to
  racial and class limits; hit points and 300 platinum are set, and the character trains silently (TrainingMenu) as far
  as its experience allows. Finally name it, run CustomizePortrait, and save it if the player agrees. Aborting a pick
  menu, or not saving, frees the record but not the effects already added. Note: the racial roll adjustments test the
  race-list counter, which that loop leaves at 7, so they never apply. }
procedure CreateCharacterMenu;
var
  cr: Types.PCreature;
  savedCur: Types.PCreature;
  { pick list head (MenuCore string-list node) }
  list: Types.PItem;
  { current list member }
  m: Types.PItem;
  { menu selection }
  sel: Integer;
  { loop index: icon colors, pick-list rows, spells }
  slot: Byte;
  { roll counter 1..6 }
  j: ShortInt;
  roll: Byte;
  { menu key }
  ch: Char;
  { race list 1..7; left at 7, so the racial roll adjustments never apply }
  k: ShortInt;
  { gender loop }
  g: ShortInt;
  cls: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  statIndex: Byte;
  i: ShortInt;
  { entries in the class or alignment table }
  cnt: Byte;
  conB: Integer;
  { Unused in this version; see the other implementations of this routine. }
  hpRoll: Byte;
  clsCount: Byte;
  hpTotal: Byte;
  addExit: Boolean;
  redraw: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  haveLevelText: Byte;
  keepFlag: Boolean;
  { the class levels shown after a roll }
  line: String[40];
  { the training mask, put back after the automatic training }
  savedPanel: Byte;
begin
  GetMem(cr, SizeOf(cr^));
  FillChar(cr^, SizeOf(cr^), 0);
  with cr^ do begin
    for slot := 1 to 6 do
      iconColors[slot] := GDConsts.defaultIconColors[slot] + (GDConsts.defaultIconColors[slot] + 8) * 16;
    acBase := 50;
    thac0Base := 40;
    status := C_Status.OKAY;
    enabled := 1;
    iconDim := 1;
    { random byte that tells same-named characters apart }
    randomId := Random(256);
    orderNumber := 10;
  end;
  { race }
  MenuCore.AllocStringList(7, list);
  list^.inUse := 1;
  list^.name := 'Pick Race';
  for k := 1 to 7 do
    case TOrdIdx(k) of
      oi1..oi5: begin
              m := MenuCore.FindListMember(k, list);
              m^.name := '  ' + GDConsts.raceNames[k];
            end;
      { half-orc (6) row skipped }
      oi7: begin
              m := MenuCore.FindListMember(k - 1, list);
              m^.name := '  ' + GDConsts.raceNames[k];
            end;
    end;
  m := list;
  sel := 1;
  redraw := True;
  addExit := True;
  repeat
    ch := MenuCore.MenuVertical('', 'Select', LightMagenta, LightGreen, White, 1, 2, 38, 22, list, addExit, redraw, sel,
                                m);
    if ch = C_Keys.NONE then begin
      MenuCore.FreeStringList(list);
      FreeMem(cr, SizeOf(cr^));
      Exit;
    end;
  until ch = 'S';
  if sel = C_Race.HALF_ORC then
    { the half-orc row is never offered; row 6 is Human }
    Inc(sel);
  with cr^ do begin
    race := sel;
    case Char(race) of
      { halfling }
      #5: begin
           iconSize := 1;
           FxEngine.AddEffect(Pointer(cr), C_Effect.CONSTITUTION_SAVE_BONUS, 0, 255, False);
         end;
      { dwarf }
      #1: begin
           iconSize := 1;
           FxEngine.AddEffect(Pointer(cr), C_Effect.CONSTITUTION_SAVE_BONUS, 0, 255, False);
           FxEngine.AddEffect(Pointer(cr), C_Effect.DWARF_ATTACK_BONUS, 0, 255, False);
           FxEngine.AddEffect(Pointer(cr), C_Effect.DWARF_GIANT_DEFENSE, 0, 255, False);
         end;
      { gnome }
      #3: begin
           iconSize := 1;
           FxEngine.AddEffect(Pointer(cr), C_Effect.CONSTITUTION_SAVE_BONUS, 0, 255, False);
           FxEngine.AddEffect(Pointer(cr), C_Effect.GNOME_ATTACK_BONUS, 0, 255, False);
           FxEngine.AddEffect(Pointer(cr), C_Effect.DWARF_GIANT_DEFENSE, 0, 255, False);
           FxEngine.AddEffect(Pointer(cr), C_Effect.GNOME_BUGBEAR_DEFENSE, 0, 255, False);
         end;
      { elf }
      #2: begin
           iconSize := 2;
           FxEngine.AddEffect(Pointer(cr), C_Effect.ELF_RESISTANCE, 0, 255, False);
         end;
      { half-elf }
      #4: begin
           iconSize := 2;
           FxEngine.AddEffect(Pointer(cr), C_Effect.HALF_ELF_RESISTANCE, 0, 255, False);
         end;
    else
      { human }
      iconSize := 2;
    end;
  end;
  { gender }
  MenuCore.FreeStringList(list);
  MenuCore.AllocStringList(3, list);
  list^.inUse := 1;
  list^.name := 'Pick Gender';
  for g := 0 to 1 do begin
    m := MenuCore.FindListMember(g + 1, list);
    m^.name := '  ' + GDConsts.genderNames[g];
  end;
  m := list;
  sel := 1;
  addExit := True;
  redraw := True;
  repeat
    ch := MenuCore.MenuVertical('', 'Select', LightMagenta, LightGreen, White, 1, 2, 38, 22, list, addExit, redraw, sel,
                                m);
    if ch = C_Keys.NONE then begin
      MenuCore.FreeStringList(list);
      FreeMem(cr, SizeOf(cr^));
      Exit;
    end;
  until ch = 'S';
  cr^.gender := sel - 1;
  MenuCore.FreeStringList(list);
  { class }
  cnt := GDConsts.raceClassLimits[cr^.race].count;
  MenuCore.AllocStringList(cnt + 1, list);
  list^.inUse := 1;
  list^.name := 'Pick Class';
  for slot := 1 to cnt do begin
    m := MenuCore.FindListMember(slot, list);
    m^.name := '  ' + GDConsts.classNames[GDConsts.raceClassLimits[cr^.race].choices[slot]];
  end;
  m := list;
  sel := 1;
  addExit := True;
  redraw := True;
  repeat
    ch := MenuCore.MenuVertical('', 'Select', LightMagenta, LightGreen, White, 1, 2, 38, 22, list, addExit, redraw, sel,
                                m);
    if ch = C_Keys.NONE then begin
      MenuCore.FreeStringList(list);
      FreeMem(cr, SizeOf(cr^));
      Exit;
    end;
  until ch = 'S';
  with cr^ do begin
    experience := 25000;
    charClass := GDConsts.raceClassLimits[race].choices[sel];
    levelHighest := 1;
    case TOrdIdx(charClass) of
      { cleric, druid, fighter }
      oi0..oi2: classLevels[charClass] := 1;
      { mage, thief, monk }
      oi5..oi7: classLevels[charClass] := 1;
      { paladin }
      oi3: begin
        cr^.cureDiseaseUses := 1;
        classLevels[C_Class.PALADIN_LEVEL] := 1;
        FxEngine.AddEffect(Pointer(cr), C_Effect.PROTECTION_FROM_EVIL, 0, 255, False);
      end;
      { ranger }
      oi4: begin
        classLevels[C_Class.RANGER_LEVEL] := 1;
        FxEngine.AddEffect(Pointer(cr), C_Effect.RANGER_DAMAGE_BONUS, 0, 255, False);
      end;
      { cleric/fighter }
      oi8: begin
        classLevels[C_Class.CLERIC_LEVEL] := 1;
        classLevels[C_Class.FIGHTER_LEVEL] := 1;
        experience := 12500;
      end;
      { cleric/fighter/mage }
      oi9: begin
        classLevels[C_Class.CLERIC_LEVEL] := 1;
        classLevels[C_Class.FIGHTER_LEVEL] := 1;
        classLevels[C_Class.MAGE_LEVEL] := 1;
        experience := 8333;
      end;
      { cleric/ranger }
      oi10: begin
        classLevels[C_Class.CLERIC_LEVEL] := 1;
        classLevels[C_Class.RANGER_LEVEL] := 1;
        FxEngine.AddEffect(Pointer(cr), C_Effect.RANGER_DAMAGE_BONUS, 0, 255, False);
        experience := 12500;
      end;
      { cleric/mage }
      oi11: begin
        classLevels[C_Class.CLERIC_LEVEL] := 1;
        classLevels[C_Class.MAGE_LEVEL] := 1;
        experience := 12500;
      end;
      { cleric/thief }
      oi12: begin
        classLevels[C_Class.CLERIC_LEVEL] := 1;
        classLevels[C_Class.THIEF_LEVEL] := 1;
        experience := 12500;
      end;
      { fighter/mage }
      oi13: begin
        classLevels[C_Class.FIGHTER_LEVEL] := 1;
        classLevels[C_Class.MAGE_LEVEL] := 1;
        experience := 12500;
      end;
      { fighter/thief }
      oi14: begin
        classLevels[C_Class.FIGHTER_LEVEL] := 1;
        classLevels[C_Class.THIEF_LEVEL] := 1;
        experience := 12500;
      end;
      { fighter/mage/thief }
      oi15: begin
        classLevels[C_Class.FIGHTER_LEVEL] := 1;
        classLevels[C_Class.MAGE_LEVEL] := 1;
        classLevels[C_Class.THIEF_LEVEL] := 1;
        experience := 8333;
      end;
      { mage/thief }
      oi16: begin
        classLevels[C_Class.MAGE_LEVEL] := 1;
        classLevels[C_Class.THIEF_LEVEL] := 1;
        experience := 8333;
      end;
    end;
    if classLevels[C_Class.THIEF_LEVEL] > 0 then ClassCal.RecalcThiefSkills(Types.PCreature(cr));
    classMask := 0;
    thac0Base := 0;
    for cls := 0 to 7 do
      if classLevels[cls] > 0 then begin
        if GDConsts.classThac0[cls, classLevels[cls]] > thac0Base then
          thac0Base := GDConsts.classThac0[cls, classLevels[cls]];
        Inc(classMask, GDConsts.classItemMasks[cls]);
      end;
  end;
  ClassCal.RecalcSaves(Types.PCreature(cr));
  MenuCore.FreeStringList(list);
  { Alignment. }
  cnt := GDConsts.classAlignments[cr^.charClass].count;
  MenuCore.AllocStringList(cnt + 1, list);
  list^.inUse := 1;
  list^.name := 'Pick Alignment';
  for slot := 1 to cnt do begin
    m := MenuCore.FindListMember(slot, list);
    m^.name := '  ' + GDConsts.alignmentNames[GDConsts.classAlignments[cr^.charClass].choices[slot]];
  end;
  m := list;
  sel := 1;
  addExit := True;
  redraw := True;
  repeat
    ch := MenuCore.MenuVertical('', 'Select', LightMagenta, LightGreen, White, 1, 2, 38, 22, list, addExit, redraw, sel,
                                m);
    if ch = C_Keys.NONE then begin
      MenuCore.FreeStringList(list);
      FreeMem(cr, SizeOf(cr^));
      Exit;
    end;
  until ch = 'S';
  cr^.alignment := GDConsts.classAlignments[cr^.charClass].choices[sel];
  MenuCore.FreeStringList(list);
  { age }
  if cr^.charClass <= CharGen.CLASS_MONK then
    with GDConsts.startingAgeRolls[cr^.race, cr^.charClass] do
      cr^.age := FxEngine.RollDice(num, sides) + base
  else
    with cr^ do
      case Char(charClass) of
        { cleric/fighter }
        #8: age := GDConsts.startingAgeRolls[race, C_Class.CLERIC].base +
          GDConsts.startingAgeRolls[race, C_Class.CLERIC].sides * GDConsts.startingAgeRolls[race, C_Class.CLERIC].num;
        { cleric/fighter/mage }
        #9: age := GDConsts.startingAgeRolls[race, C_Class.CLERIC].base +
          GDConsts.startingAgeRolls[race, C_Class.CLERIC].sides * GDConsts.startingAgeRolls[race, C_Class.CLERIC].num;
        { cleric/mage }
        #11: age := GDConsts.startingAgeRolls[race, C_Class.CLERIC].base +
          GDConsts.startingAgeRolls[race, C_Class.CLERIC].sides * GDConsts.startingAgeRolls[race, C_Class.CLERIC].num;
        { cleric/thief }
        #12: age := GDConsts.startingAgeRolls[race, C_Class.CLERIC].base +
          GDConsts.startingAgeRolls[race, C_Class.CLERIC].sides * GDConsts.startingAgeRolls[race, C_Class.CLERIC].num;
        { fighter/mage }
        #13: age := GDConsts.startingAgeRolls[race, C_Class.MAGE].base +
          GDConsts.startingAgeRolls[race, C_Class.MAGE].sides * GDConsts.startingAgeRolls[race, C_Class.MAGE].num;
        { fighter/thief }
        #14: age := GDConsts.startingAgeRolls[race, C_Class.FIGHTER].base +
          GDConsts.startingAgeRolls[race, C_Class.FIGHTER].sides * GDConsts.startingAgeRolls[race, C_Class.FIGHTER].num;
        { fighter/mage/thief }
        #15: age := GDConsts.startingAgeRolls[race, C_Class.MAGE].base +
          GDConsts.startingAgeRolls[race, C_Class.MAGE].sides * GDConsts.startingAgeRolls[race, C_Class.MAGE].num;
        { mage/thief }
        #16: age := GDConsts.startingAgeRolls[race, C_Class.MAGE].base +
          GDConsts.startingAgeRolls[race, C_Class.MAGE].sides * GDConsts.startingAgeRolls[race, C_Class.MAGE].num;
        { cleric/ranger }
        #10: age := GDConsts.startingAgeRolls[race, C_Class.CLERIC].base +
          GDConsts.startingAgeRolls[race, C_Class.CLERIC].sides * GDConsts.startingAgeRolls[race, C_Class.CLERIC].num;
      end;
  { stat roll }
  savedCur := GDVars.curChar;
  GDVars.curChar := cr;
  ViewChar.DisplayChar;
  repeat
    for cls := 0 to 7 do
      if GDVars.curChar^.classLevels[cls] > 0 then GDVars.curChar^.classLevels[cls] := 1;
    cr^.exStrCur := 0;
    for i := 0 to 5 do begin
      cr^.stats[i].current := 0;
      for j := 1 to 6 do begin
        roll := FxEngine.RollDice(3, 6) + 1;
        case Char(k) of
          #1: case Char(i) of #4: Inc(roll); #5: Dec(roll) end;
          #2: case Char(i) of #3: Inc(roll); #4: Dec(roll) end;
          #5: case Char(i) of #0: Dec(roll); #3: Inc(roll) end;
          #6: case Char(i) of #0: Inc(roll); #4: Inc(roll); #5: Dec(roll, 2) end;
        end;
        if cr^.stats[i].current < roll then cr^.stats[i].current := roll;
      end;
      with cr^ do
        case Char(i) of
          { STR }
          #0: begin
               if (stats[i].current > 0) and (GDConsts.ageThresholds[race, 0] < age) then Inc(stats[i].current);
               if (stats[i].current > 0) and (GDConsts.ageThresholds[race, 1] < age) then Dec(stats[i].current);
               if (stats[i].current > 0) and (GDConsts.ageThresholds[race, 2] < age) then Dec(stats[i].current, 2);
               if (stats[i].current > 0) and (GDConsts.ageThresholds[race, 3] < age) then Dec(stats[i].current);
               if stats[i].current <
                   GDConsts.raceAbilityLimits[race].strMin[gender] then stats[i].current :=
                   GDConsts.raceAbilityLimits[race].strMin[gender];
               if stats[i].current >
                   GDConsts.raceAbilityLimits[race].strMax[gender] then stats[i].current :=
                   GDConsts.raceAbilityLimits[race].strMax[gender];
               if stats[i].current < GDConsts.classAbilityMinimums[charClass, i] then
                 stats[i].current := GDConsts.classAbilityMinimums[charClass, i];
               if stats[C_Stat.STRENGTH].current = 18 then
                 if (classLevels[C_Class.FIGHTER_LEVEL] > 0) or (classLevels[C_Class.RANGER_LEVEL] > 0) or
                     (classLevels[C_Class.PALADIN_LEVEL] > 0) then begin
                   exStrCur := Random(100) + 1;
                   if GDConsts.raceAbilityLimits[race].exStrMax[gender] < exStrCur then
                     exStrCur := GDConsts.raceAbilityLimits[race].exStrMax[gender];
                 end;
             end;
          { INT }
          #1: begin
               if GDConsts.ageThresholds[race, 1] < age then Inc(stats[i].current);
               if GDConsts.ageThresholds[race, 3] < age then Inc(stats[i].current);
               if stats[i].current <
                   GDConsts.raceAbilityLimits[race].intMin then stats[i].current :=
                   GDConsts.raceAbilityLimits[race].intMin;
               if stats[i].current >
                   GDConsts.raceAbilityLimits[race].intMax then stats[i].current :=
                   GDConsts.raceAbilityLimits[race].intMax;
               if stats[i].current < GDConsts.classAbilityMinimums[charClass, i] then
                 stats[i].current := GDConsts.classAbilityMinimums[charClass, i];
             end;
          { WIS }
          #2: begin
               if GDConsts.ageThresholds[race, 0] >= age then Dec(stats[i].current);
               if GDConsts.ageThresholds[race, 1] < age then Inc(stats[i].current);
               if GDConsts.ageThresholds[race, 2] < age then Inc(stats[i].current);
               if GDConsts.ageThresholds[race, 3] < age then Inc(stats[i].current);
               if stats[i].current <
                   GDConsts.raceAbilityLimits[race].wisMin then stats[i].current :=
                   GDConsts.raceAbilityLimits[race].wisMin;
               if stats[i].current >
                   GDConsts.raceAbilityLimits[race].wisMax then stats[i].current :=
                   GDConsts.raceAbilityLimits[race].wisMax;
               if stats[i].current < GDConsts.classAbilityMinimums[charClass, i] then
                 stats[i].current := GDConsts.classAbilityMinimums[charClass, i];
               if (stats[i].current < 13) and (charClass in [C_Class.CLERIC_FIGHTER..CharGen.CLASS_CLERIC_THIEF]) then
                 stats[i].current := 13;
             end;
          { DEX }
          #3: begin
               if GDConsts.ageThresholds[race, 2] < age then Dec(stats[i].current, 2);
               if GDConsts.ageThresholds[race, 3] < age then Dec(stats[i].current);
               if stats[i].current <
                   GDConsts.raceAbilityLimits[race].dexMin then stats[i].current :=
                   GDConsts.raceAbilityLimits[race].dexMin;
               if stats[i].current >
                   GDConsts.raceAbilityLimits[race].dexMax then stats[i].current :=
                   GDConsts.raceAbilityLimits[race].dexMax;
               if stats[i].current < GDConsts.classAbilityMinimums[charClass, i] then
                 stats[i].current := GDConsts.classAbilityMinimums[charClass, i];
             end;
          { CON }
          #4: begin
               if GDConsts.ageThresholds[race, 1] < age then Dec(stats[i].current);
               if GDConsts.ageThresholds[race, 2] < age then Dec(stats[i].current);
               if GDConsts.ageThresholds[race, 3] < age then Dec(stats[i].current);
               if stats[i].current <
                   GDConsts.raceAbilityLimits[race].conMin then stats[i].current :=
                   GDConsts.raceAbilityLimits[race].conMin;
               if stats[i].current >
                   GDConsts.raceAbilityLimits[race].conMax then stats[i].current :=
                   GDConsts.raceAbilityLimits[race].conMax;
               if stats[i].current < GDConsts.classAbilityMinimums[charClass, i] then
                 stats[i].current := GDConsts.classAbilityMinimums[charClass, i];
             end;
          { CHA }
          #5: begin
               if stats[i].current <
                   GDConsts.raceAbilityLimits[race].chaMin then stats[i].current :=
                   GDConsts.raceAbilityLimits[race].chaMin;
               if stats[i].current >
                   GDConsts.raceAbilityLimits[race].chaMax then stats[i].current :=
                   GDConsts.raceAbilityLimits[race].chaMax;
               if stats[i].current < GDConsts.classAbilityMinimums[charClass, i] then
                 stats[i].current := GDConsts.classAbilityMinimums[charClass, i];
             end;
        end;
      ViewChar.PrintStat(i, Boolean(0));
    end;
    with cr^ do begin
      hpCur := hpMax;
      attacks := 2;
      baseRolls[1] := 1;
      baseDice[1] := 2;
      useStrength := 1;
      moveRate := 12;
      hpTotal := 0;
      clsCount := 0;
      FillChar(spellSlots, SizeOf(spellSlots), 0);
      for cls := 0 to 7 do
        if classLevels[cls] > 0 then begin
          case Char(cls) of
            #0: spellSlots[C_Spell.CLERIC_LIST, 1] := 1;
            #5: spellSlots[C_Spell.MAGE_LIST, 1] := 1;
          end;
          { The hit-point sum is unused, but the dice rolls advance the random sequence. }
          Inc(hpTotal,
              FxEngine.RollDice(GDConsts.characterCreationDice[cls].num, GDConsts.characterCreationDice[cls].sides));
          case Char(cls) of
            #0: begin
                 ClassCal.RecalcClericSlots(Types.PCreature(cr), Boolean(0));
                 for slot := 1 to 100 do
                   with GDConsts.spellProperties[slot] do
                     if (castClass = C_Spell.CLERIC_LIST) and (level = 1) then knownSpells[slot] := 1;
               end;
            #5: begin
                 knownSpells[11] := 1;
                 knownSpells[18] := 1;
                 knownSpells[12] := 1;
                 knownSpells[21] := 1;
               end;
          end;
          Inc(clsCount);
        end;
      coins[4] := 300;
      hpRolled := CharGen.RollFirstLevelHp(cr, 255);
      hpMax := hpRolled;
      conB := CharGen.ConHpBonus(cr);
      if conB < 0 then begin
        if hpMax > Abs(conB) + clsCount then
          hpMax := (hpMax + conB) div clsCount
        else
          hpMax := 1;
      end else
        hpMax := (hpMax + conB) div clsCount;
      hpCur := hpMax;
      hpRolled := hpRolled div clsCount;
    end;
    savedPanel := Byte(GDVars.zone1^[C_Gbvm.TRAIN_MASK]);
    GDVars.zone1^[C_Gbvm.TRAIN_MASK] := $FF;
    GDVars.charMenuDone := 0;
    GDVars.autoTraining := True;
    repeat
      CharGen.TrainingMenu;
    until GDVars.charMenuDone <> 0;
    GDVars.zone1^[C_Gbvm.TRAIN_MASK] := savedPanel;
    GDVars.autoTraining := False;
    keepFlag := False;
    line := '';
    for cls := 0 to 7 do
      if (GDVars.curChar^.classLevels[cls] > 0) or
          ((GDVars.curChar^.oldClassLevels[cls] < ClassCal.CurrentDualClassLevel(Types.PCreature(GDVars.curChar))) and
           (GDVars.curChar^.oldClassLevels[cls] > 0)) then begin
        if keepFlag then line := line + '/';
        line := line + CharHlp.Uint8Str(GDVars.curChar^.classLevels[cls] + GDVars.curChar^.oldClassLevels[cls]);
        keepFlag := True;
      end;
    TextRend.DisplayString(7, 15, White, 0, line);
    ViewChar.PrintCombatStats;
    ViewChar.PrintMoney;
    ch := MenuCore.YesNoMenu('Reroll stats? ', LightMagenta, LightGreen, White);
  until ch = 'N';
  { name + portrait + save }
  ViewChar.DisplayChar;
  repeat
    cr^.name := TextRend.ReadString('Character name: ', LightMagenta, 0, 15);
  until cr^.name <> '';
  CharGen.CustomizePortrait;
  for i := 0 to 5 do
    cr^.stats[i].permanent := cr^.stats[i].current;
  cr^.exStrBase := cr^.exStrCur;
  ch := MenuCore.YesNoMenu('Save ' + cr^.name + '? ', LightMagenta, LightGreen, White);
  if ch = 'N' then
  begin
    FreeMem(cr, SizeOf(cr^));
    GDVars.curChar := savedCur;
  end else begin
    SaveLoad.SaveChar(Types.PCharRecord(cr), '');
    FreeMem(cr, SizeOf(cr^));
    GDVars.curChar := savedCur;
  end;
end;

{ Computes the current character's Constitution hit-point adjustment for a class: -2 at Con 3, -1 at 4..6, 0 at 7..14,
  +1 at 15, +2 at 16, and at 17..19 Con - 14 for fighters, rangers and paladins or +2 for others. Note: a Con outside
  3..19 leaves the result undefined.
  @param(cls The class level index.)
  @returns(The hit-point adjustment per level.) }
function ClassConAdj(cls: Byte): ShortInt;
var
  r: ShortInt;
begin
  case GDVars.curChar^.stats[C_Stat.CONSTITUTION].current of
    3: r := -2;
    4..6: r := -1;
    7..14: r := 0;
    15: r := 1;
    16: r := 2;
    17..19: if (cls = C_Class.FIGHTER_LEVEL) or (cls = C_Class.RANGER_LEVEL) or (cls = C_Class.PALADIN_LEVEL) then
              r := GDVars.curChar^.stats[C_Stat.CONSTITUTION].current - 14
            else
              r := 2;
  end;
  ClassConAdj := r;
end;

{ Asks twice, then deletes the current character's files and removes it from the party (RemoveCreature), with a farewell
  that depends on whether it is enabled; declining either question leaves it with a sigh of relief. Redraws the sheet
  headers afterward, even with no current character. }
procedure DropCharacterMenu;
var
  { Unused in this version; see the other implementations of this routine. }
  answer: Byte;
begin
  if GDVars.curChar <> nil then
    with GDVars.curChar^ do begin
      if (MenuCore.YesNoMenu('Drop ' + name + ' forever? ', Yellow, LightGreen, White) = 'Y') and
          (MenuCore.YesNoMenu('Are you sure? ', Yellow, LightGreen, White) = 'Y') then
      begin
        if enabled = 0 then
          CharHlp.PrintBottomLine('You dump ' + name + ' out back.')
        else
          CharHlp.PrintBottomLine(name + ' bids you farewell.');
        SaveLoad.DeleteCharacterFiles(GDVars.curChar);
        CharGen.RemoveCreature(False, True);
      end else
        CharHlp.PrintBottomLine(name + ' breathes a sigh of relief.');
    end;
  CharHlp.DisplayParty(Types.PCreature(GDVars.curChar));
end;

{ Edits the current character's abilities, hit points and name, allowed while its experience is still a starting value
  (0, 8333, 12500 or 25000) and it has not changed class. Home, End and Enter pick a row (0..5 abilities, 6 hit points,
  7 name); Left and Right lower or raise the row within racial, class and hit-point limits, or move the name cursor,
  where typing, Backspace and Del edit the name. A Constitution change pulls hit points back inside their new limits.
  Off the name row, Keep accepts and E restores everything; Escape restores everything on any row. Keep also refigures
  the stored base hit points without the Con bonus. Note: typing a capital K on the name row inserts it and also
  accepts. }
procedure ModifyCharacterMenu;
var
  savedStats: array[0..5] of Byte;
  savedStr: Byte;
  savedHp: Byte;
  savedName: String[40];
  { Unused in this version; see the other implementations of this routine. }
  nameIdx: Byte;
  cls: ShortInt;
  { stat/loop index }
  sIdx: ShortInt;
  ch: Char;
  { MenuHorizontal extended-key flag }
  ext: Boolean;
  { current field 0..7 }
  row: Byte;
  { Unused in this version; see the other implementations of this routine. }
  statRows: array[0..6] of Byte;
  { name cursor column }
  namePos: Byte;
  { inner loops + Keep class count }
  count: Byte;

  { Draws the current row (an ability, the hit points, or the name and its cursor), highlighted when active is set. }
  procedure DisplayModifyField(active: Byte);
  begin
    case row of
      0..5: ViewChar.PrintStat(row, Boolean(active));
      6: CharHlp.PrintHitPoints(Types.PCreature(GDVars.curChar), 4, 18, Boolean(active));
      7: if active <> 0 then begin
              TextRend.PrintSpaces(Length(GDVars.curChar^.name) + 1, 1, 0, 1);
              TextRend.DisplayString(1, 1, LightMagenta, 0, GDVars.curChar^.name);
              if GDVars.curChar^.name[namePos] = ' ' then
                TextRend.DisplayString(namePos, 1, White, 0, '%')
              else
                TextRend.DisplayString(namePos, 1, White, 0, GDVars.curChar^.name[namePos]);
            end else
              TextRend.DisplayString(1, 1, LightGreen, 0, GDVars.curChar^.name);
    end;
  end;

begin
  if not (((GDVars.curChar^.experience = 0) or (GDVars.curChar^.experience = 8333) or
           (GDVars.curChar^.experience = 12500) or (GDVars.curChar^.experience = 25000)) and
      (GDVars.curChar^.levelAtChange = 0)) then begin
    TextRend.PrintAndPause(GDVars.curChar^.name + ' can''t be modified.', Yellow, 0);
    Exit;
  end;

  ViewChar.DisplayChar;
  for sIdx := 0 to 5 do
    savedStats[sIdx] := GDVars.curChar^.stats[sIdx].current;
  savedStr := GDVars.curChar^.exStrCur;
  savedHp := GDVars.curChar^.hpMax;
  savedName := GDVars.curChar^.name;

  namePos := 1;
  row := 7;
  DisplayModifyField(0);
  row := 0;
  DisplayModifyField(1);

  with GDVars.curChar^ do
  repeat
    if row = 7 then begin
      repeat until KeyPressed;
      ch := GameIo.ReadGameKey;
      if ch = #0 then begin
        ch := GameIo.ReadGameKey;
        ext := True;
      end else
        ext := False;
      if ch = C_Keys.ESCAPE then ch := C_Keys.NONE;
    end else
      ch := MenuCore.MenuHorizontal('Modify: ', 'Keep Exit', LightMagenta, LightGreen, White, True, False, ext);
    DisplayModifyField(0);
    if ext then begin
      case ch of
      CharGen.DELETE_KEY:
        if (row = 7) and (Length(GDVars.curChar^.name) > 1) then begin
          if namePos = Length(GDVars.curChar^.name) then begin
            dec(GDVars.curChar^.name[0]);
            namePos := Length(GDVars.curChar^.name);
          end else begin
            for count := namePos to Length(GDVars.curChar^.name) - 1 do
              GDVars.curChar^.name[count] := GDVars.curChar^.name[count + 1];
            dec(GDVars.curChar^.name[0]);
          end;
        end;
      C_Keys.END_KEY: begin
          inc(row);
          if row > 7 then row := 0;
        end;
      C_Keys.HOME: begin
          dec(row);
          if row = 255 then row := 7;
        end;
      C_Keys.LEFT:
        if row < 6 then begin
          sIdx := row;
          dec(stats[sIdx].current);
          case Char(sIdx) of
            #0: begin
                 if exStrCur > 0 then begin
                   dec(exStrCur);
                   inc(stats[sIdx].current);
                 end else begin
                   if stats[sIdx].current < GDConsts.raceAbilityLimits[race].strMin[gender] then
                     stats[sIdx].current := GDConsts.raceAbilityLimits[race].strMin[gender];
                 end;
                 if stats[sIdx].current < GDConsts.classAbilityMinimums[charClass][C_Stat.STRENGTH] then
                   stats[sIdx].current := GDConsts.classAbilityMinimums[charClass][C_Stat.STRENGTH];
               end;
            #1: begin
                 if stats[sIdx].current < GDConsts.raceAbilityLimits[race].intMin then
                   stats[sIdx].current := GDConsts.raceAbilityLimits[race].intMin;
                 if stats[sIdx].current < GDConsts.classAbilityMinimums[charClass][C_Stat.INTELLIGENCE] then
                   stats[sIdx].current := GDConsts.classAbilityMinimums[charClass][C_Stat.INTELLIGENCE];
               end;
            #2: begin
                 if stats[sIdx].current < GDConsts.raceAbilityLimits[race].wisMin then
                   stats[sIdx].current := GDConsts.raceAbilityLimits[race].wisMin;
                 if stats[sIdx].current < GDConsts.classAbilityMinimums[charClass][C_Stat.WISDOM] then
                   stats[sIdx].current := GDConsts.classAbilityMinimums[charClass][C_Stat.WISDOM];
                 if spellSlots[C_Spell.CLERIC_LIST, 1] > 0 then spellSlots[C_Spell.CLERIC_LIST, 1] := 1;
               end;
            #3: begin
                 if stats[sIdx].current < GDConsts.raceAbilityLimits[race].dexMin then
                   stats[sIdx].current := GDConsts.raceAbilityLimits[race].dexMin;
                 if stats[sIdx].current < GDConsts.classAbilityMinimums[charClass][C_Stat.DEXTERITY] then
                   stats[sIdx].current := GDConsts.classAbilityMinimums[charClass][C_Stat.DEXTERITY];
               end;
            #4: begin
                 if stats[sIdx].current < GDConsts.raceAbilityLimits[race].conMin then
                   stats[sIdx].current := GDConsts.raceAbilityLimits[race].conMin;
                 if stats[sIdx].current < GDConsts.classAbilityMinimums[charClass][C_Stat.CONSTITUTION] then
                   stats[sIdx].current := GDConsts.classAbilityMinimums[charClass][C_Stat.CONSTITUTION];
                 if CharGen.HpMaximum(GDVars.curChar) < hpMax then
                   hpMax := CharGen.HpMaximum(GDVars.curChar);
                 hpCur := hpMax;
                 row := 6;
                 DisplayModifyField(0);
                 row := 4;
               end;
            #5: begin
                 if stats[sIdx].current < GDConsts.raceAbilityLimits[race].chaMin then
                   stats[sIdx].current := GDConsts.raceAbilityLimits[race].chaMin;
                 if stats[sIdx].current < GDConsts.classAbilityMinimums[charClass][C_Stat.CHARISMA] then
                   stats[sIdx].current := GDConsts.classAbilityMinimums[charClass][C_Stat.CHARISMA];
               end;
          end;
        end else if row = 6 then begin
          dec(hpMax);
          if CharGen.HpMinimum(GDVars.curChar) > hpMax then
            hpMax := CharGen.HpMinimum(GDVars.curChar);
          hpCur := hpMax;
        end else begin
          if namePos = 1 then
            namePos := Length(GDVars.curChar^.name)
          else
            dec(namePos);
        end;
      C_Keys.RIGHT:
        if row < 6 then begin
          sIdx := row;
          inc(stats[sIdx].current);
          case Char(sIdx) of
            #0: begin
                 if stats[sIdx].current > GDConsts.raceAbilityLimits[race].strMax[gender] then begin
                   if stats[sIdx].current > 18 then
                     if (classLevels[C_Class.FIGHTER_LEVEL] > 0) or (classLevels[C_Class.PALADIN_LEVEL] > 0) or
                         (classLevels[C_Class.RANGER_LEVEL] > 0) then
                       if GDConsts.raceAbilityLimits[race].exStrMax[gender] > exStrCur then
                         inc(exStrCur);
                   stats[sIdx].current := GDConsts.raceAbilityLimits[race].strMax[gender];
                 end;
               end;
            #1: begin
                 if stats[sIdx].current > GDConsts.raceAbilityLimits[race].intMax then
                   stats[sIdx].current := GDConsts.raceAbilityLimits[race].intMax;
               end;
            #2: begin
                 if stats[sIdx].current > GDConsts.raceAbilityLimits[race].wisMax then
                   stats[sIdx].current := GDConsts.raceAbilityLimits[race].wisMax;
                 if spellSlots[C_Spell.CLERIC_LIST, 1] > 0 then spellSlots[C_Spell.CLERIC_LIST, 1] := 1;
               end;
            #3: begin
                 if stats[sIdx].current > GDConsts.raceAbilityLimits[race].dexMax then
                   stats[sIdx].current := GDConsts.raceAbilityLimits[race].dexMax;
               end;
            #4: begin
                 if stats[sIdx].current > GDConsts.raceAbilityLimits[race].conMax then
                   stats[sIdx].current := GDConsts.raceAbilityLimits[race].conMax;
                 if CharGen.HpMinimum(GDVars.curChar) > hpMax then
                   hpMax := CharGen.HpMinimum(GDVars.curChar);
                 hpCur := hpMax;
                 row := 6;
                 DisplayModifyField(0);
                 row := 4;
               end;
            #5: begin
                 if stats[sIdx].current > GDConsts.raceAbilityLimits[race].chaMax then
                   stats[sIdx].current := GDConsts.raceAbilityLimits[race].chaMax;
               end;
          end;
        end else if row = 6 then begin
          inc(hpMax);
          if CharGen.HpMaximum(GDVars.curChar) < hpMax then
            hpMax := CharGen.HpMaximum(GDVars.curChar);
          hpCur := hpMax;
        end else begin
          if namePos = Length(GDVars.curChar^.name) then
            namePos := 1
          else
            inc(namePos);
        end;
      end;
    end else begin
      case ch of
      C_Keys.ENTER: begin
          inc(row);
          if row > 7 then row := 0;
        end;
      C_Keys.BACKSPACE:
        if (namePos > 1) and (row > 6) then begin
          for count := namePos to Length(GDVars.curChar^.name) do
            GDVars.curChar^.name[count - 1] := GDVars.curChar^.name[count];
          dec(GDVars.curChar^.name[0]);
          if namePos > Length(GDVars.curChar^.name) then
            namePos := Length(GDVars.curChar^.name);
        end;
      #32..#122:
        if row > 6 then begin
          { name insert }
          if namePos <= 15 then begin
            GDVars.curChar^.name[namePos] := ch;
            inc(namePos);
            if namePos > 15 then namePos := 15;
            if namePos > Length(GDVars.curChar^.name) then begin
              inc(GDVars.curChar^.name[0]);
              GDVars.curChar^.name[namePos] := ' ';
            end;
          end;
        end else begin
          if ch = 'E' then begin
            for sIdx := 0 to 5 do
              GDVars.curChar^.stats[sIdx].current := savedStats[sIdx];
            GDVars.curChar^.exStrCur := savedStr;
            GDVars.curChar^.hpMax := savedHp;
            GDVars.curChar^.hpCur := hpMax;
            GDVars.curChar^.name := savedName;
            CharHlp.RecalcStats(Types.PCreature(GDVars.curChar));
            Exit;
          end;
        end;
      C_Keys.NONE: begin
          for sIdx := 0 to 5 do
            GDVars.curChar^.stats[sIdx].current := savedStats[sIdx];
          GDVars.curChar^.exStrCur := savedStr;
          GDVars.curChar^.hpMax := savedHp;
          GDVars.curChar^.name := savedName;
          GDVars.curChar^.hpCur := hpMax;
          CharHlp.RecalcStats(Types.PCreature(GDVars.curChar));
          Exit;
        end;
      end;
    end;
    CharHlp.RecalcStats(Types.PCreature(GDVars.curChar));
    ViewChar.PrintCombatStats;
    DisplayModifyField(1);
  until (not ext) and (ch = 'K');

  ClassCal.RecalcClericSlots(Types.PCreature(GDVars.curChar), Boolean(1));
  GDVars.curChar^.modified := 1;
  with GDVars.curChar^ do begin
    savedHp := 0;
    count := 0;
    for cls := 0 to 7 do begin
      if classLevels[cls] > 0 then begin
        if Byte(classLevels[cls]) < GDConsts.constitutionBonusLevelCaps[cls] then begin
          if cls = C_Class.RANGER_LEVEL then
            Inc(savedHp, CharGen.ClassConAdj(cls) * (classLevels[cls] + 1))
          else
            Inc(savedHp, CharGen.ClassConAdj(cls) * classLevels[cls]);
        end else
          Inc(savedHp, CharGen.ClassConAdj(cls) * (GDConsts.constitutionBonusLevelCaps[cls] - 1));
        inc(count);
      end;
    end;
    savedHp := savedHp div count;
    hpRolled := hpMax - savedHp;
  end;
  for sIdx := 0 to 5 do
    GDVars.curChar^.stats[sIdx].permanent := GDVars.curChar^.stats[sIdx].current;
  GDVars.curChar^.exStrBase := GDVars.curChar^.exStrCur;
end;

procedure AddCharacterMenu;
var
  { character names shown in the menu }
  displayList: Types.PItem;
  { matching records, used to load }
  recordList: Types.PItem;
  { MenuVertical selected display node }
  cur: Types.PItem;
  { record fetched by index for loading }
  selRec: Types.PItem;
  { Newly allocated character candidate. }
  newChar: Types.PCreature;
  { party-scan cursor }
  scan: Types.PCreature;
  { MenuVertical selection index }
  selIdx: Integer;
  { menu key }
  ch: Char;
  { addExit is passed without initialization. }
  addExit: Boolean;
  { MenuVertical redraw flag }
  redraw: Boolean;
  { party members that are not NPCs }
  realCount: Byte;
  { count of rangers in party }
  rangerCount: Byte;
  { an evil party member is present }
  evilFlag: Byte;
  { a paladin is present }
  paladinFlag: Byte;
  { name of the paladin found (for the warning) }
  existName: String[40];
  { MenuHorizontal extended-key flag }
  ext: Boolean;
begin
  evilFlag := 0;
  paladinFlag := 0;
  rangerCount := 0;
  Border.ClearBox(1, 1, 38, 22);
  ch := MenuCore.MenuHorizontal('Add from where? ', 'Curse Pool Hillsfar Exit', LightMagenta, LightGreen, White, False,
                                False, ext);
  case ch of
    'C': GDVars.importMode := 0;
    'P': GDVars.importMode := 1;
    'H': GDVars.importMode := 2;
    'E', C_Keys.NONE: Exit;
  end;
  SaveLoad.LoadCharlist(displayList, recordList);
  if displayList = nil then Exit;
  selIdx := 0;
  cur := displayList;
  redraw := True;
  repeat
    ch := MenuCore.MenuVertical('Add a character: ', 'Add ', LightMagenta, LightGreen, White, 1, 2, 38, 22, displayList,
                                addExit, redraw, selIdx, cur);
    if (ch = C_Keys.ENTER) or (ch = 'A') then
      if cur^.name[1] <> '*' then
      begin
        MenuCore.ClearBottomLine;
        GetMem(newChar, SizeOf(newChar^));
        selRec := MenuCore.FindListMember(selIdx, recordList);
        SaveLoad.LoadChar(selRec^.name, Types.PCharRecord(newChar), False, True);
        cur^.name := '* ' + cur^.name;
        realCount := 0;
        if GDVars.partyHead = nil then begin
          GDVars.zone1^[C_Gbvm.PARTY_SIZE] := 0;
          SaveLoad.AddCharToParty(Types.PCharRecord(newChar));
          SaveLoad.LoadCharIconAnim(True);
        end else begin
          scan := GDVars.partyHead;
          rangerCount := 0;
          { A duplicate leaves scan non-nil so the candidate can be rejected below. }
          while (scan <> nil) and ((scan^.name <> newChar^.name) or (scan^.randomId <> newChar^.randomId)) do begin
            if scan^.npc < $80 then Inc(realCount);
            if scan^.classLevels[C_Class.RANGER_LEVEL] > 0 then Inc(rangerCount);
            if Byte((TNonNegAlign(scan^.alignment) + 1) mod 3) = 0 then evilFlag := 1;
            if scan^.classLevels[C_Class.PALADIN_LEVEL] > 0 then begin
              paladinFlag := 1;
              existName := scan^.name;
            end;
            scan := scan^.next;
          end;
          if (scan = nil) and
              (((newChar^.npc < $80) and (realCount < 6)) or
               ((newChar^.npc > $7F) and (GDVars.zone1^[C_Gbvm.PARTY_SIZE] < 8))) and
              (not ((newChar^.classLevels[C_Class.PALADIN_LEVEL] <> 0) and (evilFlag <> 0))) and
              (not ((newChar^.classLevels[C_Class.RANGER_LEVEL] <> 0) and (rangerCount >= 3))) and
              (not ((Byte((TNonNegAlign(newChar^.alignment) + 1) mod 3) = 0) and (paladinFlag <> 0))) then begin
            SaveLoad.AddCharToParty(Types.PCharRecord(newChar));
            SaveLoad.LoadCharIconAnim(True);
            if newChar^.npc < $80 then Inc(realCount);
          end else begin
          { Remove the selection marker, show the rejection reason, and free the candidate. }
          Delete(cur^.name, 1, 2);
          if (newChar^.classLevels[C_Class.PALADIN_LEVEL] > 0) and (evilFlag <> 0) then begin
            CharHlp.PrintBottomLine('paladins do not join with evil scum');
            TextRend.PauseOnly;
          end else if (newChar^.classLevels[C_Class.RANGER_LEVEL] > 0) and (rangerCount > 2) then
            CharHlp.PrintBottomLine('too many rangers in party')
          else if (Byte((TNonNegAlign(newChar^.alignment) + 1) mod 3) = 0) and (paladinFlag <> 0) then
            CharHlp.PrintBottomLine(existName + ' will tolerate no evil!');
          FreeMem(newChar, SizeOf(newChar^));
          end;
        end;
      end;
  until (ch = 'E') or (ch = C_Keys.NONE) or (realCount > 5) or (GDVars.zone1^[C_Gbvm.PARTY_SIZE] > 7);
  MenuCore.FreeStringList(displayList);
end;

procedure RemoveCreature(suppressSizeDec, freeAnim: Boolean);
var
  prev: Types.PCreature;
begin
  if GDVars.partyHead = nil then Exit;
  prev := GDVars.partyHead;
  if prev <> GDVars.curChar then begin
    while (prev^.next <> GDVars.curChar) and (prev^.next <> nil) do
      prev := prev^.next;
    if prev^.next <> nil then begin
      if freeAnim then
        MapTiles.FreeIconAnim(GDVars.curChar^.orderNumber);
      prev^.next := GDVars.curChar^.next;
      CharGen.FreeCreature(GDVars.curChar);
      GDVars.curChar := prev;
      if not suppressSizeDec then
        Dec(GDVars.zone1^[C_Gbvm.PARTY_SIZE]);
    end;
  end else begin
    if freeAnim then
      MapTiles.FreeIconAnim(GDVars.curChar^.orderNumber);
    GDVars.partyHead := GDVars.curChar^.next;
    prev := GDVars.curChar^.next;
    CharGen.FreeCreature(GDVars.curChar);
    GDVars.curChar := prev;
    if not suppressSizeDec then
      Dec(GDVars.zone1^[C_Gbvm.PARTY_SIZE]);
  end;
  if GDVars.curChar = nil then
    GDVars.curChar := GDVars.partyHead;
end;

procedure CustomizePortrait;
var
  { Unused in this version; see the other implementations of this routine. }
  extKey: Byte;
  { menu key }
  ch: Char;
  { MenuHorizontal extended flag }
  escFlag: Boolean;
  savedHead: Byte;
  savedBody: Byte;
  savedIcon: Byte;
  savedOrder: Byte;
  state: Byte;
  { size-name label temp }
  sizeName: String[5];
  { Unused in this version; see the other implementations of this routine. }
  colorIdx: Byte;
  { icon colors to restore on Exit }
  iconData: Types.TIcon6;
  { icon color part being edited }
  partIdx: Byte;
  { 0 = Hair, 1 = Face }
  colorMode: Byte;
  { low nibble, edited in Hair mode }
  lowColor: Byte;
  { high nibble, edited in Face mode }
  highColor: Byte;
  { state to return to }
  retState: Byte;
  { saved sub-select key }
  subKey: Char;

  { Draws the preview icon's ready and action frames at view cell (row, col) over a cleared box, and flushes. }
  procedure ShowIconFrames(row, col: Byte);
  begin
    if GDVars.displayMode = 0 then
      Blit.FillPicRect(row * 3, col * 24, 12, 24, 3, GDConsts.iconColorMap, GDVars.viewBuffer)
    else begin
      Blit.FillPicRect(row * 3, col * 24, 12, 24, 0, GDConsts.iconColorMap, GDVars.viewBuffer);
      MapTiles.DrawIconAnimSprite(row, col, 0, 0, 25);
      MapTiles.DrawIconAnimSprite(row + 3, col, 0, 1, 25);
    end;
    MapTiles.DrawIconAnimSprite(row, col, 0, 0, 12);
    MapTiles.DrawIconAnimSprite(row + 3, col, 0, 1, 12);
    Blit.FlushView;
  end;

  { Copies icon slot fromSlot's frames and masks to toSlot, then recolors toSlot to the character's colors if rebuild. }
  procedure CopyIconPics(fromSlot, toSlot, rebuild: Byte);
  var
    i: Byte;
    { Unused in this version; see the other implementations of this routine. }
    frameIdx: Byte;
    grid1: Types.TColorTab;
    grid2: Types.TColorTab;
    cnt: Word;
  begin
    cnt := GDVars.iconImages[toSlot, 0]^.imgSize;
    Move(GDVars.iconImages[fromSlot, 0]^.data, GDVars.iconImages[toSlot, 0]^.data,
         GDVars.iconImages[toSlot, 0]^.imgSize);
    Move(GDVars.iconImages[fromSlot, 1]^.data, GDVars.iconImages[toSlot, 1]^.data,
         GDVars.iconImages[toSlot, 1]^.imgSize);
    Move(GDVars.iconImages[fromSlot, 0]^.transp^, GDVars.iconImages[toSlot, 0]^.transp^, cnt);
    Move(GDVars.iconImages[fromSlot, 1]^.transp^, GDVars.iconImages[toSlot, 1]^.transp^, cnt);
    if rebuild <> 0 then
      with GDVars.curChar^ do begin
        for i := 0 to 15 do begin
          grid1[i] := i;
          grid2[i] := i;
        end;
        for i := 1 to 6 do begin
          grid2[GDConsts.defaultIconColors[i]] := iconColors[i] and $F;
          grid2[GDConsts.defaultIconColors[i] + 8] := (iconColors[i] and $F0) shr 4;
        end;
        Blit.RemapPic(grid1, grid2, 0, False, Types.PImgBuf(GDVars.iconImages[toSlot, 0]));
        Blit.RemapPic(grid1, grid2, 0, False, Types.PImgBuf(GDVars.iconImages[toSlot, 1]));
      end;
  end;

begin
  Border.DrawWindowFrame;
  CbtMap.SetCombatPalette;
  repeat
    SaveLoad.LoadCharIconAnim(False);
    with GDVars.curChar^ do begin
    state := 1;
    iconData := iconColors;
    savedOrder := orderNumber;
    orderNumber := 12;
    SaveLoad.LoadCharIconAnim(False);
    orderNumber := savedOrder;
    savedHead := iconHead;
    savedBody := iconBody;
    savedIcon := iconSize;
    CopyIconPics(orderNumber, 12, 1);
    ShowIconFrames(1, 2);
    TextRend.DisplayString(8, 6, White, 0, 'old');
    TextRend.DisplayString(3, 10, White, 0, 'ready   action');
    TextRend.DisplayString(8, 12, White, 0, 'new');
    TextRend.DisplayString(3, 16, White, 0, 'ready   action');
    repeat
      ShowIconFrames(1, 4);
      sizeName := '';
      if state = 4 then begin
        if iconSize = 2 then
          sizeName := 'Small'
        else
          sizeName := 'Large';
      end;
      ch := MenuCore.MenuHorizontal('', sizeName + GDConsts.characterHorizontalMenus[state], LightMagenta, LightGreen,
                                    White, False, False, escFlag);
      if not escFlag then
        case state of
          1: begin
               retState := 1;
               case ch of
                 'P': state := 2;
                 '1': if GDVars.displayMode = 0 then
                        TextRend.PrintAndPause('Sorry, not in CGA', Yellow, 0)
                      else begin
                        state := 3;
                        colorMode := 0;
                        Delete(GDConsts.characterHorizontalMenus[3], 13, 4);
                        Insert('Hair', GDConsts.characterHorizontalMenus[3], 13);
                      end;
                 '2': if GDVars.displayMode = 0 then
                        TextRend.PrintAndPause('Sorry, not in CGA', Yellow, 0)
                      else begin
                        state := 3;
                        colorMode := 1;
                        Delete(GDConsts.characterHorizontalMenus[3], 13, 4);
                        Insert('Face', GDConsts.characterHorizontalMenus[3], 13);
                      end;
                 'S': state := 4;
               end;
             end;
          2: begin
               retState := 2;
               if ch in [C_Keys.NONE, 'E'] then
                 state := 1
               else begin
                 subKey := ch;
                 state := 5;
               end;
             end;
          3: begin
               retState := 3;
               case ch of
                 'W': partIdx := 6;
                 'B': partIdx := 1;
                 'H': partIdx := 4;
                 'F': partIdx := 4;
                 'S': partIdx := 5;
                 'A': partIdx := 2;
                 'L': partIdx := 3;
               else
                 partIdx := 1;
               end;
               if ch in [C_Keys.NONE, 'E'] then
                 state := 1
               else
                 state := 5;
             end;
          4: begin
               case ch of
                 'L': begin iconSize := 2; SaveLoad.LoadCharIconAnim(False); end;
                 'S': begin iconSize := 1; SaveLoad.LoadCharIconAnim(False); end;
                 'K': begin savedIcon := iconSize; state := 1; ch := ' '; end;
                 'E', C_Keys.NONE: begin iconSize := savedIcon; state := 1; ch := ' '; end;
               end;
               SaveLoad.LoadCharIconAnim(False);
             end;
          5: case retState of
               2: case subKey of
                    'H':
                      begin
                        case ch of
                          'P': if iconHead > 0 then
                                 Dec(iconHead)
                               else
                                 iconHead := 13;
                          'N': if iconHead < 13 then
                                 Inc(iconHead)
                               else
                                 iconHead := 0;
                          'K': begin
                                 with GDVars.curChar^ do
                                   savedHead := iconHead;
                                 state := retState;
                                 ch := ' ';
                               end;
                          'E', C_Keys.NONE: begin
                                     iconHead := savedHead;
                                     state := retState;
                                     ch := ' ';
                                   end;
                        end;
                        SaveLoad.LoadCharIconAnim(False);
                      end;
                    'W':
                      begin
                        case ch of
                          'P': if iconBody > 0 then
                                 Dec(iconBody)
                               else
                                 iconBody := 31;
                          'N': if iconBody < 31 then
                                 Inc(iconBody)
                               else
                                 iconBody := 0;
                          'K': begin
                                 with GDVars.curChar^ do
                                   savedBody := iconBody;
                                 state := retState;
                                 ch := ' ';
                               end;
                          'E', C_Keys.NONE: begin
                                     iconBody := savedBody;
                                     state := retState;
                                     ch := ' ';
                                   end;
                        end;
                        SaveLoad.LoadCharIconAnim(False);
                      end;
                  end;
               3: begin
                    lowColor := iconColors[partIdx] and $F;
                    highColor := (iconColors[partIdx] and $F0) shr 4;
                    case ch of
                      'N': begin
                             if colorMode <> 0 then
                               highColor := (highColor + 1) mod 16
                             else
                               lowColor := (lowColor + 1) mod 16;
                             iconColors[partIdx] := (highColor shl 4) + lowColor;
                           end;
                      'P': begin
                             if colorMode <> 0 then
                               highColor := (highColor - 1) and $F
                             else
                               lowColor := (lowColor - 1) and $F;
                             iconColors[partIdx] := (highColor shl 4) + lowColor;
                           end;
                      'K': begin
                             iconData := iconColors;
                             state := retState;
                             ch := ' ';
                           end;
                      'E', C_Keys.NONE: begin
                                 iconColors := iconData;
                                 state := retState;
                                 ch := ' ';
                               end;
                    end;
                  end;
             end;
        end;
      CopyIconPics(orderNumber, 12, 1);
    until (retState = 1) and (ch in [C_Keys.NONE, 'E']);
    iconHead := savedHead;
    iconBody := savedBody;
    iconSize := savedIcon;
    iconColors := iconData;
    CopyIconPics(orderNumber, 12, 1);
    CopyIconPics(12, orderNumber, 0);
    end;
    MenuCore.ClearBottomLine;
    MapTiles.FreeIconAnim(12);
    ch := MenuCore.YesNoMenu('Is this icon ok? ', LightMagenta, LightGreen, White);
  until ch = 'Y';
  CbtMap.SetNoncombatPalette;
end;

function ConHpBonus(cr: Types.PCreature): ShortInt;
var
  bonus: ShortInt;
  cls: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  classCount: Byte;
begin
  bonus := 0;
  with cr^ do
    for cls := 0 to 7 do
      if classLevels[cls] > 0 then
        if Byte(cr^.classLevels[cls]) < GDConsts.constitutionBonusLevelCaps[cls] then begin
          Inc(bonus, GDConsts.constitutionHitPointBonus[stats[C_Stat.CONSTITUTION].current]);
          if (charClass = C_Class.FIGHTER) or (charClass = C_Class.PALADIN) or
              (charClass = C_Class.RANGER) then
            case stats[C_Stat.CONSTITUTION].current of
              17: Inc(bonus);
              18: Inc(bonus, 2);
              19, 20: Inc(bonus, 3);
              21..23: Inc(bonus, 4);
              24, 25: Inc(bonus, 5);
            end;
          if (cls = C_Class.RANGER_LEVEL) and (classLevels[cls] = 1) then
            bonus := bonus * 2;
        end;
  ConHpBonus := bonus;
end;

{ Computes the lowest legal maximum hit points: one per level in each class (plus 1 for a ranger or monk), plus the Con
  bonus, divided by the class count; 1 when a negative bonus would leave too little.
  @param(cr The character.)
  @returns(The minimum hit points.) }
function HpMinimum(cr: Types.PCreature): Byte;
var
  clsCount: Byte;
  conB: ShortInt;
  sum: Byte;
  cls: ShortInt;
begin
  with cr^ do begin
    clsCount := 0;
    sum := 0;
    for cls := 0 to 7 do
      if classLevels[cls] > 0 then begin
        Inc(sum, classLevels[cls]);
        Inc(clsCount);
        case Char(cls) of
          #4: Inc(sum);
          #7: Inc(sum);
        end;
      end;
  end;
  conB := CharGen.ConHpBonus(cr);
  if conB < 0 then begin
    if sum > Abs(conB) + clsCount then
      sum := (sum + conB) div clsCount
    else
      sum := 1;
  end else
    sum := (sum + conB) div clsCount;
  HpMinimum := sum;
end;

{ Returns the highest legal maximum hit points: below each class's Con cap, (die + ClassConAdj) per level -- cleric and
  druid d8, fighter and paladin d10, ranger d8 on level + 1, magic-user d4, thief d6, monk d4 on level + 1; at or above
  the cap a fixed amount. The total is divided by the class count. Note: a class at or above its cap replaces the
  running sum instead of adding to it, and ClassConAdj reads the current character, not cr.
  @param(cr The character.)
  @returns(The maximum hit points.) }
function HpMaximum(cr: Types.PCreature): Byte;
var
  clsCount: Byte;
  sum: Byte;
  conAdj: ShortInt;
  cls: ShortInt;
  overCap: Byte;
begin
  with cr^ do begin
    clsCount := 0;
    sum := 0;
    for cls := 0 to 7 do
      if classLevels[cls] > 0 then begin
        conAdj := CharGen.ClassConAdj(cls);
        if Byte(classLevels[cls]) < GDConsts.constitutionBonusLevelCaps[cls] then begin
          Inc(clsCount);
          case Char(cls) of
            #0: Inc(sum, (conAdj + 8) * classLevels[cls]);
            #1: Inc(sum, (conAdj + 8) * classLevels[cls]);
            #2: Inc(sum, (conAdj + 10) * classLevels[cls]);
            #3: Inc(sum, (conAdj + 10) * classLevels[cls]);
            #4: Inc(sum, (conAdj + 8) * (classLevels[cls] + 1));
            #5: Inc(sum, (conAdj + 4) * classLevels[cls]);
            #6: Inc(sum, (conAdj + 6) * classLevels[cls]);
            #7: Inc(sum, (conAdj + 4) * (classLevels[cls] + 1));
          end;
        end else begin
          Inc(clsCount);
          overCap := classLevels[cls] - GDConsts.constitutionBonusLevelCaps[cls] + 1;
          case Char(cls) of
            #0: sum := overCap * 2 + 72;
            #1: sum := 112;
            #2, #3: sum := overCap * 3 + 90;
            #4: sum := overCap * 2 + 88;
            #5: sum := overCap + 44;
            #6: sum := overCap * 2 + 60;
            #7: sum := 72;
          end;
        end;
      end;
  end;
  sum := sum div clsCount;
  HpMaximum := sum;
end;

{ Rolls hit points for each class with levels whose class bit is in mask. Below the class's Con cap it keeps the better
  of two rolls of its hit dice (one die after first level); at or above the cap it takes the fixed gain (fighter or
  paladin 3, ranger, cleric or thief 2, magic-user 1). Note: a fixed gain replaces the running sum instead of adding to
  it.
  @param(cr The character.)
  @param(mask Class bits of the classes to roll; 255 rolls each class.)
  @returns(The hit points rolled.) }
function RollFirstLevelHp(cr: Types.PCreature; mask: Byte): Byte;
var
  roll1: Byte;
  roll2: Byte;
  sum: Byte;
  diceCount: Byte;
  cls: ShortInt;
begin
  sum := 0;
  for cls := 0 to 7 do
    if cr^.classLevels[cls] > 0 then
      if GDConsts.classBits[cls] and mask > 0 then
        if Byte(cr^.classLevels[cls]) < GDConsts.constitutionBonusLevelCaps[cls] then begin
          diceCount := GDConsts.startingHitDice[cls];
          if cr^.classLevels[cls] > 1 then
            diceCount := 1;
          roll1 := FxEngine.RollDice(diceCount, startingHitDieSidesView.t[cls]);
          roll2 := FxEngine.RollDice(diceCount, startingHitDieSidesView.t[cls]);
          if roll2 > roll1 then
            roll1 := roll2;
          Inc(sum, roll1);
        end else
          case Char(cls) of
            #2, #3: sum := 3;
            #4, #0, #6: sum := 2;
            #5: sum := 1;
          end;
  RollFirstLevelHp := sum;
end;

{ Deducts an amount in gold pieces from a character's coins. Works in 1/200 of a gold piece, taking coins from copper
  upward and rounding each coin type up (capped at what is held), then refunds any overshoot from platinum downward.
  Note: if the purse cannot cover the amount, the index runs past the five coin values into whatever follows them.
  @param(gp The amount in gold pieces.)
  @param(cr The character who pays.) }
procedure TakeCoins(gp: LongInt; cr: Types.PCreature);
var
  amt: Word;
  i: ShortInt;
begin
  gp := gp * 200;
  i := 0;
  with cr^ do begin
    while gp > 0 do begin
      amt := gp div GDConsts.coinValues[i] + 1;
      if coins[i] < amt then
        amt := coins[i];
      Dec(gp, amt * GDConsts.coinValues[i]);
      Dec(coins[i], amt);
      i := Succ(i);
    end;
    if gp < 0 then begin
      gp := Abs(gp);
      i := 4;
      while gp > 0 do begin
        amt := gp div GDConsts.coinValues[i];
        Dec(gp, amt * GDConsts.coinValues[i]);
        Inc(coins[i], amt);
        i := Pred(i);
      end;
    end;
  end;
end;

procedure TrainingMenu;
var
  { at racial level limit -> skip class }
  atLimit: Boolean;
  { one below the highest level + 2 threshold reached }
  bestXp: LongInt;
  { scratch XP }
  xpTmp: LongInt;
  { trainable-now class bits }
  maskA: Byte;
  { class bits of the classes the character has }
  maskB: Byte;
  { the classes that train: maskA, limited to the hall's classes unless training is free }
  trainHere: Byte;
  { number of classes with a level }
  classCount: Byte;
  { rolled HP sum }
  hpTotal: Integer;
  { per-class HP gain }
  avgHp: Integer;
  { damage carried over: maximum minus current hit points }
  hpDelta: Byte;
  { class index }
  i: ShortInt;
  { con HP bonus }
  conBonusV: Integer;
  { display row }
  row: Byte;
  { pre-train magic-user level }
  oldMageLevel: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  oldRangerLevel: ShortInt;
  { level of the class being checked }
  curLvl: ShortInt;
  { the spell picked for the new level }
  selResult: Byte;
  { SpellMenu's highlighted entry }
  spellIdx: Integer;
  { set by SpellMenu when the list has spells }
  hasSpells: Byte;
  { Unused in this version; see the other implementations of this routine. }
  selClass: Byte;
  { classes this trainer teaches }
  trainableHere: Byte;
  { highest next-level XP among trainable classes }
  bestNextXp: LongInt;
  { the class with that requirement }
  bestClass: ShortInt;
begin
  if (GDVars.curChar^.status <> C_Status.OKAY) and (GDVars.stingMode = 0) then begin
    TextRend.PrintAndPause('we only train conscious people', Yellow, 0);
    Exit;
  end;
  if (ViewChar.CreatureCoinValueInGold(Types.PCreature(GDVars.curChar)) < 1000) and (GDVars.stingMode = 0)
     and not GDVars.autoTraining and not GDVars.victoryStart then begin
    TextRend.PrintAndPause('Training costs 1000 gp.', Yellow, 0);
    Exit;
  end;

  maskA := 0;
  maskB := 0;
  bestXp := 0;
  trainableHere := Lo(GDVars.zone1^[C_Gbvm.TRAIN_MASK]);

  with GDVars.curChar^ do begin
    bestXp := 0;
    for i := 0 to 7 do
      if classLevels[i] > 0 then begin
        Inc(maskB, GDConsts.classBits[i]);
        atLimit := False;
        curLvl := classLevels[i];
        case Char(race) of
          #1: if i = C_Class.FIGHTER_LEVEL then
               if (curLvl = 9)
                  or ((curLvl = 8) and (stats[C_Stat.STRENGTH].current = 17))
                  or ((curLvl = 7) and (stats[C_Stat.STRENGTH].current < 17)) then atLimit := True;
          #2: begin
               if i = C_Class.FIGHTER_LEVEL then
                 if (curLvl = 7)
                    or ((curLvl = 6) and (stats[C_Stat.STRENGTH].current = 17))
                    or ((curLvl = 5) and (stats[C_Stat.STRENGTH].current < 17)) then atLimit := True;
               if i = C_Class.MAGE_LEVEL then
                 if (curLvl = 11)
                    or ((curLvl = 9) and (stats[C_Stat.INTELLIGENCE].current < 17))
                    or ((curLvl = 10) and (stats[C_Stat.INTELLIGENCE].current = 17)) then atLimit := True;
             end;
          #3: if i = C_Class.FIGHTER_LEVEL then
               if (curLvl = 6)
                  or ((curLvl = 5) and (stats[C_Stat.STRENGTH].current < 18)) then atLimit := True;
          #4: if (i = C_Class.CLERIC_LEVEL) and (curLvl = 5) then atLimit := True
             else begin
               if (i = C_Class.FIGHTER_LEVEL) or (i = C_Class.RANGER_LEVEL) then
                 if (curLvl = 8)
                    or ((curLvl = 7) and (stats[C_Stat.STRENGTH].current = 17))
                    or ((curLvl = 6) and (stats[C_Stat.STRENGTH].current < 17)) then atLimit := True;
               if i = C_Class.MAGE_LEVEL then
                 if (curLvl = 8)
                    or ((curLvl = 7) and (stats[C_Stat.INTELLIGENCE].current = 17))
                    or ((curLvl = 6) and (stats[C_Stat.INTELLIGENCE].current < 17)) then atLimit := True;
             end;
          #5: if i = C_Class.FIGHTER_LEVEL then
               if (curLvl = 6)
                  or ((curLvl = 5) and (stats[C_Stat.STRENGTH].current = 17))
                  or ((curLvl = 4) and (stats[C_Stat.STRENGTH].current < 17)) then atLimit := True;
        end;
        if not atLimit then
          if (GDConsts.classExperience[i].thresholds[Succ(curLvl)] <= experience) or (GDVars.stingMode <> 0) then
            if GDConsts.classExperience[i].thresholds[Succ(curLvl)] > 0 then begin
              if GDVars.stingMode <> 0 then
                if GDConsts.classExperience[i].thresholds[Succ(curLvl)] > 0 then
                  if GDConsts.classExperience[i].thresholds[Succ(curLvl)] > experience then
                    experience := GDConsts.classExperience[i].thresholds[Succ(curLvl)];
              Inc(maskA, GDConsts.classBits[i]);
              xpTmp := GDConsts.classExperience[i].thresholds[Succ(Succ(curLvl))];
              if (xpTmp > 0) and (experience >= xpTmp) and (xpTmp > bestXp) then
                bestXp := xpTmp - 1;
            end;
      end;

    if not GDVars.autoTraining then begin
      bestNextXp := 0;
      xpTmp := 0;
      for i := 0 to 7 do
        if (GDConsts.classBits[i] and maskA) <> 0 then
          if GDConsts.classExperience[i].thresholds[Succ(curLvl)] > bestNextXp then begin
            bestNextXp := GDConsts.classExperience[i].thresholds[Succ(curLvl)];
            bestClass := i;
          end;
      if bestNextXp > 0 then begin
        maskA := GDConsts.classBits[bestClass];
        xpTmp := GDConsts.classExperience[bestClass].thresholds[Succ(Succ(curLvl))];
        if (xpTmp > 0) and (experience >= xpTmp) and (xpTmp > bestXp) then
          bestXp := xpTmp - 1;
      end;
    end;

    if (bestXp > 0) and not GDVars.autoTraining then
      experience := bestXp;

    if GDVars.stingMode = 0 then begin
      if ((maskB and trainableHere) = 0) and not GDVars.autoTraining then begin
        TextRend.PrintAndPause('We don''t train that class here', Yellow, 0);
        Exit;
      end else if (maskA and trainableHere) = 0 then begin
        GDVars.charMenuDone := 1;
        if not GDVars.autoTraining then
          TextRend.PrintAndPause('Not Enough Experience', Yellow, 0);
        Exit;
      end;
    end;

    if GDVars.stingMode = 0 then trainHere := maskA and trainableHere
    else trainHere := maskA;

    if not GDVars.autoTraining then begin
      Border.ClearBox(1, 1, 38, 22);
      row := 4;
      CharHlp.DisplayCreatureName(Types.PCreature(GDVars.curChar), 4, row, Boolean(0));
      TextRend.DisplayString(Length(name) + 4, row, LightGreen, 0, ' will become:');
      for i := 0 to 7 do
        if classLevels[i] > 0 then
          if (GDConsts.classBits[i] and trainHere) > 0 then begin
            Inc(row);
            if row = 5 then
              TextRend.DisplayString(6, row, LightGreen, 0,
                                     '    a level ' + CharHlp.Uint8Str(classLevels[i] + 1) + ' ' +
                                     GDConsts.classNames[i])
            else
              TextRend.DisplayString(6, row, LightGreen, 0,
                                     'and a level ' + CharHlp.Uint8Str(classLevels[i] + 1) + ' ' +
                                     GDConsts.classNames[i]);
          end;
      if MenuCore.YesNoMenu('Do you wish to train? ', LightMagenta, LightGreen, White) <> 'Y' then Exit;
      CharHlp.PrintBottomLine('Congratulations...');
      if (GDVars.stingMode = 0) and not GDVars.victoryStart then
        CharGen.TakeCoins(1000, GDVars.curChar);
    end;

    classCount := 0;
    oldMageLevel := classLevels[C_Class.MAGE_LEVEL];
    oldRangerLevel := classLevels[C_Class.RANGER_LEVEL];
    classMask := 0;
    for i := 0 to 7 do
      if classLevels[i] > 0 then begin
        Inc(classCount);
        if (GDConsts.classBits[i] and trainHere) > 0 then begin
          Inc(classLevels[i]);
          if drainedLevels > 0 then begin
            Dec(drainedHps, drainedHps div drainedLevels);
            Dec(drainedLevels);
          end;
        end;
      end;

    ClassCal.RecalcClassStats(Types.PCreature(GDVars.curChar));

    if not GDVars.autoTraining then
      if (classLevels[C_Class.MAGE_LEVEL] > oldMageLevel) or (classLevels[C_Class.RANGER_LEVEL] > 8) then begin
        spellIdx := -1;
        repeat
          selResult := ViewChar.SpellMenu(4, 4, spellIdx, Boolean(hasSpells));
        until (selResult > 0) or (hasSpells = 0);
        if selResult > 0 then
          knownSpells[selResult] := 1;
      end;

    if GDVars.autoTraining then
      case Char(classLevels[C_Class.MAGE_LEVEL]) of
        #2: knownSpells[15] := 1;
        #3: begin knownSpells[34] := 1; knownSpells[10] := 1; end;
        #4: knownSpells[31] := 1;
        #5: knownSpells[47] := 1;
      end;

    if levelHighest > levelAtChange then begin
      hpTotal := CharGen.RollFirstLevelHp(GDVars.curChar, trainHere);
      avgHp := hpTotal div classCount;
      if avgHp = 0 then avgHp := 1;
      Inc(hpRolled, avgHp);
      conBonusV := CharGen.ConHpBonus(GDVars.curChar);
      avgHp := (hpTotal + conBonusV) div classCount;
      if avgHp < 1 then avgHp := 1;
      hpDelta := hpMax - hpCur;
      Inc(hpMax, avgHp);
      hpCur := hpMax - hpDelta;
    end;
  end;
end;

begin
end.
