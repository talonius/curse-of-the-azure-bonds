{ The character sheet and its menus: items (ready, use, trade, drop, split, join, sell, identify), spells, money, and a
  paladin's healing and curing. }
{$O+,F+}
{$A-}
unit ViewChar;

interface

uses Types, MenuCore, Portrait, Money, Border, TextRend, GDConsts, GDVars, C_Keys, C_Class,
  C_Status, C_Effect, C_Ifc, C_Gbvm, C_Stat, C_Spell, CharHlp, CbtMap, FxEngine, ClassCal, MapView, EclTrace, Magic,
  GameTime, Crt;

{ Draws the current character's sheet: name ("(NPC)" for an NPC), gender, race, age, alignment, class, the six
  abilities, money, levels (a dual-class human's earlier class too, once the current class level exceeds it),
  experience, combat statistics, weapon, armor and status. }
procedure DisplayChar;

{ Recalculates the current character and prints its AC, hit points, THAC0, damage dice, encumbrance and movement. Note:
  the movement is shown doubled when the character is slowed and halved when it is hasted. }
procedure PrintCombatStats;

{ Prints an ability of the current character on its sheet row; Strength 18 shows its exceptional part as (nn), (00) for
  100.
  @param(statIdx The ability, 0..5.)
  @param(modifying True to draw it highlighted, as while it is being modified.) }
procedure PrintStat(statIdx: ShortInt; modifying: Boolean);

{ Lists the current character's money on the sheet, jewelry and gems first. }
procedure PrintMoney;

{ Shows the current character's sheet with a menu: Items, Spells, Trade (money, outside combat; not for an active NPC),
  Drop (money), Heal (a paladin's daily laying on of hands), Cure (while it has disease cures left) and Exit; in combat
  the noncombat palette is used meanwhile.
  @param(done Set when an item use ended the character's combat turn.) }
procedure ViewCharMenu(var done: Boolean);

{ Runs the current character's item list: Ready, Use (when it is enabled, outside an anti-magic area, and in camp,
  overland, the 3D view, or combat with its item use left), Trade (outside combat), Drop, Halve (fewer than 16 items),
  Join, and in shops and temples Sell and Id (Trade and Sell not for an active NPC); V shows an item's raw fields. It
  ends when the player leaves, the character has no items, or an item use ends the turn.
  @param(done Set when an item use ended the character's combat turn.) }
procedure UseItemMenu(var done: Boolean);

{ Readies or unreadies one of the current character's items. A cursed item cannot be unreadied; readying fails with the
  hands full (said only outside combat or for a character not fighting quickly), the slot taken, or the wrong class. A
  magic item's special effect is applied or removed (ToggleItemEffect).
  @param(item The item.) }
procedure ToggleReadyItem(item: Types.PItem);

{ Uses an item of the current character: a scroll offers its spells (a magic-user or cleric reads them; a thief of level
  10 or more succeeds 75% of the time; anyone else says "oops!"), any other item casts its spell. After a cast, a scroll
  loses the spell and another item a charge (a stack loses one piece; the last charge removes the item).
  @param(item The item.)
  @param(done Set when the use ended the character's combat turn.) }
procedure UseItem(item: Types.PItem; var done: Boolean);

{ Tells whether a creature cannot take an item: it already has 16 items, or the weight (times the quantity) would go
  past its allowance plus 1500. Recalculates the creature first.
  @param(creature The creature.)
  @param(item The item.)
  @returns(True when the creature cannot take the item.) }
function CannotCarryItem(creature: Types.PCreature; item: Types.PItem): Boolean;

{ Makes the previous (Home) or next (End) party member current, wrapping around; any other key makes the first member
  current.
  @param(key The key pressed.) }
procedure SelectPrevNextChar(key: Char);

{ Values a creature's coins in gold, rounded half up; gems and jewelry are not counted.
  @param(creature The creature.)
  @returns(The value in gold.) }
function CreatureCoinValueInGold(creature: Types.PCreature): LongInt;

{ Builds a spell list for the current character (Magic.GenerateSpellList) and, when it is not empty, draws the screen
  with the list's title and runs Magic.SpellSelection. The frame is drawn when idx is below 0 or selType is 1: the
  window frame in combat, else the memorize frame for selType 2 and the title inset otherwise.
  @param(menuType The list: 0 in memory, 1 in the grimoire, 2 on a scroll, 3 on scrolls, 4 to choose, 5 to memorize, 6
    to scribe.)
  @param(selType The selection mode for Magic.SpellSelection.)
  @param(idx The highlighted entry, kept between calls.)
  @param(notEmpty Set when the list had spells.)
  @returns(The chosen spell, or 0.) }
function SpellMenu(menuType, selType: Byte; var idx: Integer; var notEmpty: Boolean): Byte;

{ Tells whether a paladin (or a dual-class character whose earlier paladin levels are active) may lay on hands now:
  outside combat, okay, and more than a day after the last time.
  @param(cr The character.)
  @returns(True when it may.) }
function CanHeal(cr: Types.PCreature): Boolean;

{ Tells whether a paladin (or a dual-class character whose earlier paladin levels are active) may cure disease now:
  outside combat, okay, with cures left (cureDiseaseUses).
  @param(cr The character.)
  @returns(True when it may.) }
function CanCure(cr: Types.PCreature): Boolean;

{ Lays on hands: the party member the player picks regains 2 hit points per paladin level of the healer (earlier paladin
  levels count while active), who cannot heal again for a day. Picking no one just redraws the sheet.
  @param(cr The paladin.) }
procedure PaladinLayOnHands(cr: Types.PCreature);

{ Cures the diseases of the party member the player picks (asking first when there are none), using one of the paladin's
  cures and starting its seven-day cure effect if it is not already running.
  @param(cr The paladin.) }
procedure PaladinCureDisease(cr: Types.PCreature);

{ Shows an item's raw fields for debugging (V in the item menu) and waits for a key.
  @param(it The item.) }
procedure ViewItemDetail(it: Types.PItem);

{ Calls the priming entries of MenuCore, Portrait, Magic, FxEngine, Money, GameTime, MapView, CharHlp, EclTrace and
  ClassCal, so the overlay manager loads them; CbtMap, which this unit also uses, is not primed. }
procedure PrimeViewChar;

implementation

procedure PrimeViewChar;
begin
  MenuCore.PrimeMenuCore;
  Portrait.PrimePortrait;
  Magic.PrimeMagic;
  FxEngine.PrimeFxEngine;
  Money.PrimeMoney;
  GameTime.PrimeGameTime;
  MapView.PrimeMapView;
  CharHlp.PrimeCharHlp;
  EclTrace.PrimeEclTrace;
  ClassCal.PrimeClassCal;
end;

procedure ItemTradeMenu(item: Types.PItem); forward;

procedure HalveItem(item: Types.PItem); forward;

procedure JoinItem(item: Types.PItem); forward;

procedure SellItem(item: Types.PItem); forward;

procedure IdentifyItem(item: Types.PItem; var newInfo: Boolean); forward;

procedure TradeTreasureMenu; forward;

procedure DropMoneyMenu; forward;

function CheckItemAvail(item: Types.PItem): Boolean; forward;

procedure ToggleItemEffect(it: Types.PItem; equipping: Boolean); forward;

procedure DisplayChar;
var
  { Unused in this version; see the other implementations of this routine. }
  statRow: Byte;
  row: Byte;
  col: Byte;
  { Unused in this version; see the other implementations of this routine. }
  statCol: Byte;
  i: ShortInt;
  j: ShortInt;
  s: String;
  multi: Boolean;
begin
  GDVars.sheetChar := GDVars.curChar;
  Border.DrawWindowFrame;
  CharHlp.DisplayCreatureName(Pointer(GDVars.sheetChar), 1, 1, False);
  if GDVars.sheetChar^.npc > $7F then
    TextRend.DisplayString(Length(GDVars.sheetChar^.name) + 3, 1, LightGreen, 0, '(NPC)');
  col := 1;
  s := GDConsts.genderNames[GDVars.sheetChar^.gender];
  TextRend.DisplayString(col, 3, White, 0, s);
  col := col + Length(s) + 1;
  s := GDConsts.raceNames[GDVars.sheetChar^.race];
  TextRend.DisplayString(col, 3, White, 0, s);
  col := col + Length(s) + 1;
  TextRend.DisplayString(col, 3, White, 0, 'Age ' + CharHlp.Uint16Str(GDVars.sheetChar^.age));
  s := GDConsts.alignmentNames[ShortInt(GDVars.sheetChar^.alignment)];
  TextRend.DisplayString(1, 4, White, 0, s);
  s := GDConsts.classNames[GDVars.sheetChar^.charClass];
  TextRend.DisplayString(1, 5, White, 0, s);
  for i := 0 to 5 do begin
    case Char(i) of
      #0: s := 'STR ';
      #1: s := 'INT ';
      #2: s := 'WIS ';
      #3: s := 'DEX ';
      #4: s := 'CON ';
      #5: s := 'CHA ';
    end;
    TextRend.DisplayString(1, i + 7, LightGreen, 0, s);
    ViewChar.PrintStat(i, False);
  end;
  ViewChar.PrintMoney;
  TextRend.DisplayString(1, 15, White, 0, 'Level');
  multi := False;
  s := '';
  for j := 0 to 7 do
    if (GDVars.sheetChar^.classLevels[j] > 0) or
        ((GDVars.sheetChar^.oldClassLevels[j] < ClassCal.CurrentDualClassLevel(Types.PCreature(GDVars.sheetChar))) and
         (GDVars.sheetChar^.oldClassLevels[j] > 0)) then begin
      if multi then
        s := s + '/';
      s := s + CharHlp.Uint8Str(GDVars.sheetChar^.classLevels[j] + GDVars.sheetChar^.oldClassLevels[j]);
      multi := True;
    end;
  TextRend.DisplayString(7, 15, White, 0, s);
  TextRend.DisplayString(17, 15, White, 0, 'Exp ' + CharHlp.Int32Str(GDVars.sheetChar^.experience));
  ViewChar.PrintCombatStats;
  row := 20;
  if GDVars.sheetChar^.equipped[0] <> nil then begin
    TextRend.DisplayString(1, row, White, 0, 'Weapon');
    CharHlp.PrintItemString(GDVars.sheetChar, Pointer(GDVars.sheetChar^.equipped[0]), 8, row, False, True);
  end;
  Inc(row);
  if GDVars.sheetChar^.equipped[2] <> nil then begin
    TextRend.DisplayString(2, row, White, 0, 'Armor');
    CharHlp.PrintItemString(GDVars.sheetChar, Pointer(GDVars.sheetChar^.equipped[2]), 8, row, False, True);
  end;
  Inc(row);
  TextRend.DisplayString(1, row, White, 0, 'Status');
  TextRend.DisplayString(8, row, LightGreen, 0, GDConsts.statusNames[ShortInt(GDVars.sheetChar^.status)]);
end;

procedure PrintMoney;
var
  row: Byte;
  m: ShortInt;
  s: Types.TStr40;
begin
  Border.ClearBox(12, 7, 26, 14);
  row := 7;
  for m := 6 downto 0 do
    if GDVars.curChar^.coins[m] > 0 then begin
      s := GDConsts.moneyNames[m];
      TextRend.DisplayString(20 - Length(s), row, LightGreen, 0, s);
      TextRend.DisplayString(21, row, LightGreen, 0, CharHlp.Uint16Str(GDVars.curChar^.coins[m]));
      Inc(row);
    end;
end;

procedure PrintCombatStats;
var
  p: Types.PCreature;
  row: Byte;
  col: Byte;
  mv: Byte;
  s: Types.TStr40;
  eff: Types.PEffect;
begin
  p := GDVars.curChar;
  CharHlp.RecalcStats(Types.PCreature(p));
  row := 17;
  TextRend.DisplayString(1, row, White, 0, 'AC    ');
  CharHlp.PrintArmorClass(Types.PCreature(p), 4, row);
  TextRend.DisplayString(1, row + 1, White, 0, 'HP    ');
  CharHlp.PrintHitPoints(Types.PCreature(p), 4, row + 1, False);
  col := 8;
  TextRend.DisplayString(col + 1, row, White, 0, 'THAC0   ');
  TextRend.DisplayString(col + 7, row, LightGreen, 0, CharHlp.Uint8Str(60 - p^.thac0Cur));
  s := CharHlp.Uint8Str(p^.curRolls[1]) + 'd' + CharHlp.Uint8Str(p^.curDice[1]);
  if p^.curMod[1] > 0 then
    s := s + '+' + CharHlp.Uint8Str(p^.curMod[1]);
  if p^.curMod[1] < 0 then
    s := s + '-' + CharHlp.Uint8Str(Abs(p^.curMod[1]));
  TextRend.DisplayString(col, row + 1, White, 0, 'Damage        ');
  TextRend.DisplayString(col + 7, row + 1, LightGreen, 0, s);
  col := 22;
  TextRend.DisplayString(col, row, White, 0, 'Encumbrance      ');
  TextRend.DisplayString(col + 12, row, LightGreen, 0, CharHlp.Uint16Str(p^.encumbrance));
  mv := p^.movementCur;
  if CharHlp.HasEffect(Types.PCreature(p), C_Effect.SLOWED, eff) then
    mv := mv * 2;
  if CharHlp.HasEffect(Types.PCreature(p), C_Effect.HASTED, eff) then
    mv := mv div 2;
  TextRend.DisplayString(col + 3, row + 1, White, 0, 'Movement   ');
  TextRend.DisplayString(col + 12, row + 1, LightGreen, 0, CharHlp.Uint8Str(mv));
end;

procedure PrintStat(statIdx: ShortInt; modifying: Boolean);
var
  s: Types.TStr40;
  col: Byte;
  hlCol: Byte;
begin
  if modifying then
    hlCol := 13
  else
    hlCol := 10;
  col := 5;
  Border.ClearBox(col, statIdx + 7, 11, statIdx + 7);
  if GDVars.curChar^.stats[statIdx].current < 10 then
    Inc(col);
  TextRend.DisplayString(col, statIdx + 7, hlCol, 0, CharHlp.Uint8Str(GDVars.curChar^.stats[statIdx].current));
  if (statIdx = C_Stat.STRENGTH) and (GDVars.curChar^.stats[C_Stat.STRENGTH].current = 18)
      and (GDVars.curChar^.exStrCur > 0) then begin
    s := CharHlp.Uint8Str(GDVars.curChar^.exStrCur);
    if GDVars.curChar^.exStrCur < 10 then
      s := '0' + s;
    if GDVars.curChar^.exStrCur = 100 then
      s := '00';
    TextRend.DisplayString(7, 7, hlCol, 0, '(' + s + ')');
  end;
end;

procedure ViewCharMenu(var done: Boolean);
var
  ch: Char;
  { Unused in this version; see the other implementations of this routine. }
  choice: Byte;
  s: Types.TStr40;
  hasMoney: Boolean;
  hasSpells: Boolean;
  ext: Boolean;
  i: Byte;
  j: ShortInt;
  idx: Integer;
begin
  if GDVars.ifcState = C_Ifc.IN_COMBAT then
    CbtMap.SetNoncombatPalette;
  ch := ' ';
  done := False;
  GDVars.tradeTarget := GDVars.curChar;
  ViewChar.DisplayChar;
  while not (ch in [C_Keys.NONE, 'E']) and not done do
  begin
    s := '';
    hasSpells := False;
    hasMoney := False;
    for i := 0 to 83 do
      if GDVars.sheetChar^.memorizedSpells[i] > 0 then
        hasSpells := True;
    for j := 0 to 6 do
      if GDVars.sheetChar^.coins[j] > 0 then
        hasMoney := True;
    if GDVars.sheetChar^.itemsAddr <> nil then
      s := s + 'Items ';
    if hasSpells then
      s := s + 'Spells ';
    if ((GDVars.sheetChar^.npc < $80) or (GDVars.sheetChar^.enabled = 0) or
        (GDVars.sheetChar^.status = C_Status.ANIMATED)) and hasMoney and
        (GDVars.ifcState <> C_Ifc.IN_COMBAT) then
      s := s + 'Trade ';
    if hasMoney then
      s := s + 'Drop ';
    if ViewChar.CanHeal(GDVars.curChar) then
      s := s + 'Heal ';
    if ViewChar.CanCure(GDVars.curChar) then
      s := s + 'Cure ';
    s := s + 'Exit';
    ch := MenuCore.MenuHorizontal('', s, LightMagenta, LightGreen, White, False, False, ext);
    idx := -1;
    case ch of
      'I': ViewChar.UseItemMenu(done);
      'S': i := ViewChar.SpellMenu(0, 0, idx, hasSpells);
      'T': ViewChar.TradeTreasureMenu;
      'D': begin
             ViewChar.DropMoneyMenu;
             ViewChar.PrintMoney;
           end;
      'H': ViewChar.PaladinLayOnHands(GDVars.curChar);
      'C': ViewChar.PaladinCureDisease(GDVars.curChar);
    end;
    if not done and (ch in ['I', 'S', 'T']) then
      ViewChar.DisplayChar;
  end;
  if GDVars.ifcState = C_Ifc.IN_COMBAT then
    CbtMap.SetCombatPalette;
  CharHlp.DisplayNoncombatInterface;
end;

{ Tells whether an item may be traded, dropped or sold: it must not be readied ("Must be unreadied"), and a scroll
  holding spells marked for scribing goes only if the player agrees to lose them.
  @param(item The item.)
  @returns(True when the item may go.) }
function CheckItemAvail(item: Types.PItem): Boolean;
begin
  CheckItemAvail := False;
  if item^.equipped <> 0 then
    CharHlp.PrintBottomLine('Must be unreadied')
  else if not Magic.ItemReadable(item) then
    CheckItemAvail := True
  else if (item^.charges > $7F) or (item^.effect > $7F) or (item^.special > $7F) then begin
    CharHlp.DisplayCreatureName(Pointer(GDVars.curChar), 1, 21, False);
    GDVars.curCol := Length(GDVars.curChar^.name) + 2;
    GDVars.curRow := 21;
    TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, 0, False, ' was going to scribe from that scroll');
    if MenuCore.YesNoMenu('is it Okay to lose it? ', LightMagenta, LightGreen, White) = 'Y' then
      CheckItemAvail := True;
  end else
    CheckItemAvail := True;
  Border.ClearBox(1, 21, 38, 22);
end;

procedure ViewItemDetail(it: Types.PItem);
begin
  Border.DrawWindowFrame;
  with it^ do begin
    TextRend.DisplayString(1, 1, LightGreen, 0, 'itemptr:      ');
    TextRend.DisplayString(1, 2, LightGreen, 0, 'namenum(1):   ');
    TextRend.DisplayString(1, 3, LightGreen, 0, 'namenum(2):   ');
    TextRend.DisplayString(1, 4, LightGreen, 0, 'namenum(3):   ');
    TextRend.DisplayString(1, 5, LightGreen, 0, 'plus:         ');
    TextRend.DisplayString(1, 6, LightGreen, 0, 'plussave:     ');
    TextRend.DisplayString(1, 7, LightGreen, 0, 'ready:        ');
    TextRend.DisplayString(1, 8, LightGreen, 0, 'identified:   ');
    TextRend.DisplayString(1, 9, LightGreen, 0, 'cursed:       ');
    TextRend.DisplayString(1, 10, LightGreen, 0, 'value:        ');
    TextRend.DisplayString(1, 11, LightGreen, 0, 'special(1):   ');
    TextRend.DisplayString(1, 12, LightGreen, 0, 'special(2):   ');
    TextRend.DisplayString(1, 13, LightGreen, 0, 'special(3):   ');
    TextRend.DisplayString(1, 14, LightGreen, 0, 'dice large:    ');
    TextRend.DisplayString(1, 15, LightGreen, 0, 'sides large:   ');
    TextRend.DisplayString(20, 1, LightGreen, 0, CharHlp.Uint8Str(itemType));
    TextRend.DisplayString(20, 2, LightGreen, 0, CharHlp.Uint8Str(nameIds[1]));
    TextRend.DisplayString(20, 3, LightGreen, 0, CharHlp.Uint8Str(nameIds[2]));
    TextRend.DisplayString(20, 4, LightGreen, 0, CharHlp.Uint8Str(nameIds[3]));
    TextRend.DisplayString(20, 5, LightGreen, 0, CharHlp.Uint8Str(Byte(plus)));
    TextRend.DisplayString(20, 6, LightGreen, 0, CharHlp.Uint8Str(Byte(saveBonus)));
    TextRend.DisplayString(20, 7, LightGreen, 0, CharHlp.Uint8Str(equipped));
    TextRend.DisplayString(20, 8, LightGreen, 0, CharHlp.Uint8Str(unidMask));
    TextRend.DisplayString(20, 9, LightGreen, 0, CharHlp.Uint8Str(cursed));
    TextRend.DisplayString(20, 10, LightGreen, 0, CharHlp.Uint16Str(value));
    TextRend.DisplayString(20, 11, LightGreen, 0, CharHlp.Uint8Str(charges));
    TextRend.DisplayString(20, 12, LightGreen, 0, CharHlp.Uint8Str(effect));
    TextRend.DisplayString(20, 13, LightGreen, 0, CharHlp.Uint8Str(special));
    TextRend.DisplayString(20, 14, LightGreen, 0, CharHlp.Uint8Str(GDVars.baseItems[itemType].dmgLgRolls));
    TextRend.DisplayString(20, 15, LightGreen, 0, CharHlp.Uint8Str(GDVars.baseItems[itemType].dmgLgDice));
  end;
  TextRend.DisplayAndPause(LightGreen, 0, 'press a key');
end;

procedure UseItemMenu(var done: Boolean);
var
  ch: Char;
  s: Types.TStr40;
  { Unused in this version; see the other implementations of this routine. }
  choice: Byte;
  needRedraw: Boolean;
  vmRedraw: Boolean;
  p: Types.PItem;
  sel: Types.PItem;
  idx: Integer;
  { Unused in this version; see the other implementations of this routine. }
  prevItem: Types.PItem;
  cr: Types.PCreature;
  itemCount: Byte;
  { Unused in this version; see the other implementations of this routine. }
  itemSlot: Byte;
begin
  cr := GDVars.curChar;
  ch := ' ';
  sel := cr^.itemsAddr;
  idx := 0;
  vmRedraw := True;
  needRedraw := True;
  while not (ch in [C_Keys.NONE, 'E']) and not done and (cr^.numberOfItems > 0) do begin
    itemCount := cr^.numberOfItems;
    if cr^.itemsAddr <> nil then begin
      s := 'Ready';
      if (cr^.enabled <> 0) and (GDVars.zone0^[C_Gbvm.ANTI_MAGIC] = 0) and
          ((GDVars.ifcState = C_Ifc.CAMPING) or (GDVars.ifcState = C_Ifc.OVERLAND) or
           (GDVars.ifcState = C_Ifc.VIEW_3D) or
           ((GDVars.ifcState = C_Ifc.IN_COMBAT) and (cr^.combatAddr^.itemUseAllowed <> 0))) then
        s := s + ' Use';
      if ((cr^.npc < $80) or (cr^.enabled = 0) or (cr^.status = C_Status.ANIMATED)) and
          (GDVars.ifcState <> C_Ifc.IN_COMBAT) then
        s := s + ' Trade';
      s := s + ' Drop';
      if cr^.numberOfItems < 16 then
        s := s + ' Halve';
      s := s + ' Join';
      if ((cr^.npc < $80) or (cr^.enabled = 0) or (cr^.status = C_Status.ANIMATED))
         and (GDVars.ifcState = C_Ifc.SHOP_TEMPLE) then
        s := s + ' Sell';
      if GDVars.ifcState = C_Ifc.SHOP_TEMPLE then
        s := s + ' Id';
      p := cr^.itemsAddr;
      while p <> nil do begin
        CharHlp.PrintItemString(cr, Pointer(p), 0, 0, True, False);
        p := p^.next;
      end;
      if needRedraw or (GDVars.invRedraw <> 0) then begin
        Border.DrawTitleInset;
        CharHlp.DisplayCreatureName(Pointer(cr), 1, 1, True);
        TextRend.DisplayString(Length(cr^.name) + 4, 1, LightGreen, 0, 'Items');
        TextRend.DisplayString(1, 3, White, 0, 'Ready Item');
        vmRedraw := True;
        needRedraw := False;
        GDVars.invRedraw := 0;
      end;
      ch := MenuCore.MenuVertical('', s, LightMagenta, LightGreen, White, 1, 5, 38, 22, cr^.itemsAddr, True, vmRedraw,
                                  idx, sel);
      if sel <> nil then
        case ch of
          'V': begin
                 ViewChar.ViewItemDetail(sel);
                 vmRedraw := True;
                 needRedraw := True;
               end;
          'R': ViewChar.ToggleReadyItem(sel);
          'U': if sel^.equipped = 0 then
               begin
                 CharHlp.PrintBottomLine('Must be Readied');
                 ch := ' ';
               end else if Magic.ItemReadable(sel) or ((sel^.effect > 0) and (sel^.special < $80)) then begin
                 ViewChar.UseItem(sel, done);
                 if GDVars.ifcState <> C_Ifc.IN_COMBAT then
                   done := False;
                 if not done then
                   needRedraw := True;
               end;
          'T': begin
                 if ViewChar.CheckItemAvail(sel) then
                   ViewChar.ItemTradeMenu(sel)
                 else
                   ch := ' ';
                 needRedraw := True;
               end;
          'D': if ViewChar.CheckItemAvail(sel) then
               begin
                 CharHlp.PrintItemString(cr, Pointer(sel), 0, 0, False, False);
                 TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, 0, True,
                                               'Your ' + sel^.name + 'will be gone forever');
                 if MenuCore.YesNoMenu('Drop It? ', LightMagenta, LightGreen, White) = 'Y' then
                 begin
                   CharHlp.RemoveItem(Types.PCreature(GDVars.curChar), Types.PItem(sel));
                   vmRedraw := True;
                 end;
                 Border.ClearBox(1, 21, 38, 22);
               end else
                 ch := ' ';
          'H': ViewChar.HalveItem(sel);
          'J': ViewChar.JoinItem(sel);
          'S': if ViewChar.CheckItemAvail(sel) then
                 ViewChar.SellItem(sel)
               else
                 ch := ' ';
          'I': ViewChar.IdentifyItem(sel, vmRedraw);
        end;
      CharHlp.RecalcStats(Types.PCreature(cr));
    end;
    if cr^.numberOfItems <> itemCount then
      vmRedraw := True;
  end;
end;

{ Applies (equipping) or removes the special effect of a magic item of the current character, by its special byte's low
  7 bits: 0 the item's effect handler through the override; 1 doubles magic-user spell slots 1..3, and on removal
  recomputes them and forgets the memorized magic-user spells over the new count; 2 and 10 Dexterity (2 also
  RecalcThiefSkills); 4 an alignment-bound item, which a wrong-alignment owner cannot ready (magic damage of effect div
  16); 5 Strength; 6 Constitution and Charisma; 8 the ability named by the effect byte; 9 removes Spiritual Hammer on
  unreadying; 11 RecalcThiefSkills; 12 Intelligence; 13 Strength and Intelligence.
  @param(it The item.)
  @param(equipping True when the item is being readied, False when it is being unreadied.) }
procedure ToggleItemEffect(it: Types.PItem; equipping: Boolean);
var
  effId: Byte;
  perClassLvl: Byte;
  damage: Byte;
  cr: Types.PCreature;
  i: ShortInt;
  newLevel: Byte;
  j: ShortInt;
  k: Byte;
  lvl: Byte;
  spellCnt: array[1..5] of Byte;
begin
  cr := GDVars.curChar;
  effId := it^.special and $7F;
  case effId of
    0: begin
         GDVars.overrideFlag := 1;
         FxEngine.CallEffectHandler(it^.special, Types.PCreature(cr), it, equipping = False);
       end;
    1: if equipping then begin
         for i := 1 to 3 do
           Inc(cr^.spellSlots[C_Spell.MAGE_LIST, i], cr^.spellSlots[C_Spell.MAGE_LIST, i]);
       end else begin
         perClassLvl := ClassCal.EarlierClassActive(Types.PCreature(cr)) * cr^.oldClassLevels[C_Class.MAGE_LEVEL]
                        + cr^.classLevels[C_Class.MAGE_LEVEL];
         newLevel := perClassLvl;
         for i := 1 to 5 do
           cr^.spellSlots[C_Spell.MAGE_LIST, i] := 0;
         cr^.spellSlots[C_Spell.MAGE_LIST, 1] := 1;
         for j := 2 to newLevel do
           for i := 1 to 5 do
             Inc(cr^.spellSlots[C_Spell.MAGE_LIST, i], GDConsts.classExperience[C_Class.MAGE].slots[j, i]);
         FillChar(spellCnt, SizeOf(spellCnt), 0);
         for k := 0 to 83 do
           if cr^.memorizedSpells[k] <> 0 then
             if GDConsts.spellProperties[cr^.memorizedSpells[k]].castClass = C_Spell.MAGE_LIST then begin
               lvl := GDConsts.spellProperties[cr^.memorizedSpells[k]].level;
               Inc(spellCnt[lvl]);
               if spellCnt[lvl] > cr^.spellSlots[C_Spell.MAGE_LIST, ShortInt(lvl)] then
                 cr^.memorizedSpells[k] := 0;
             end;
       end;
    2: begin
         FxEngine.RecalcAbility(Types.PCreature(cr), C_Stat.DEXTERITY);
         ClassCal.RecalcThiefSkills(Types.PCreature(cr));
       end;
    4: if (it^.effect and $F) <> cr^.alignment then begin
         it^.equipped := 0;
         damage := it^.effect div 16;
         GDVars.elementMask := 8;
         if GDVars.ifcState = C_Ifc.IN_COMBAT then
           CharHlp.DisplayCombatInterface;
         FxEngine.InflictNonWeaponDamage(Types.PCreature(cr), damage, 0, False);
         GDVars.invRedraw := 1;
       end;
    5: FxEngine.RecalcAbility(Types.PCreature(cr), C_Stat.STRENGTH);
    6: begin
         FxEngine.RecalcAbility(Types.PCreature(cr), C_Stat.CONSTITUTION);
         FxEngine.RecalcAbility(Types.PCreature(cr), C_Stat.CHARISMA);
       end;
    8: case it^.effect of
         C_Stat.STRENGTH: FxEngine.RecalcAbility(Types.PCreature(cr), C_Stat.STRENGTH);
         C_Stat.INTELLIGENCE: FxEngine.RecalcAbility(Types.PCreature(cr), C_Stat.INTELLIGENCE);
         C_Stat.WISDOM: FxEngine.RecalcAbility(Types.PCreature(cr), C_Stat.WISDOM);
         C_Stat.DEXTERITY: FxEngine.RecalcAbility(Types.PCreature(cr), C_Stat.DEXTERITY);
         C_Stat.CONSTITUTION: FxEngine.RecalcAbility(Types.PCreature(cr), C_Stat.CONSTITUTION);
         C_Stat.CHARISMA: FxEngine.RecalcAbility(Types.PCreature(cr), C_Stat.CHARISMA);
       end;
    9: if not equipping then
         FxEngine.RemoveEffect(Types.PCreature(cr), C_Effect.SPIRITUAL_HAMMER, nil);
    10: FxEngine.RecalcAbility(Types.PCreature(cr), C_Stat.DEXTERITY);
    11: ClassCal.RecalcThiefSkills(Types.PCreature(cr));
    12: FxEngine.RecalcAbility(Types.PCreature(cr), C_Stat.INTELLIGENCE);
    13: begin
          FxEngine.RecalcAbility(Types.PCreature(cr), C_Stat.STRENGTH);
          FxEngine.RecalcAbility(Types.PCreature(cr), C_Stat.INTELLIGENCE);
        end;
  end;
end;

procedure ToggleReadyItem(item: Types.PItem);
var
  hasSpecial: Boolean;
  err: Byte;
  slot: ShortInt;
  cr: Types.PCreature;
begin
  hasSpecial := item^.special > $7F;
  cr := GDVars.curChar;
  if item^.equipped <> 0 then begin
    if item^.cursed <> 0 then
      CharHlp.PrintBottomLine('It''s Cursed')
    else begin
      item^.equipped := 0;
      if hasSpecial then
        ViewChar.ToggleItemEffect(item, False);
    end;
  end else begin
    err := 0;
    if cr^.handsEquipped + GDVars.baseItems[item^.itemType].hands > 2 then
      err := 3;
    slot := GDVars.baseItems[item^.itemType].slot;
    case Byte(slot) of
      0..8: if cr^.equipped[slot] <> nil then
              err := 2;
      9: if cr^.equipped[10] <> nil then
              err := 2;
    end;
    if item^.itemType = 73 then
      if cr^.equipped[11] <> nil then begin
        err := 2;
        slot := 11;
      end;
    if item^.itemType = 28 then
      if cr^.equipped[12] <> nil then begin
        err := 2;
        slot := 12;
      end;
    if GDVars.baseItems[item^.itemType].classMask and cr^.classMask = 0 then
      err := 1;
    case err of
      0: begin
           item^.equipped := 1;
           if hasSpecial then
             ViewChar.ToggleItemEffect(item, True);
         end;
      1: CharHlp.PrintBottomLine('Wrong Class');
      2: begin
           CharHlp.PrintItemString(cr, Pointer(cr^.equipped[slot]), 0, 0, False, False);
           CharHlp.PrintBottomLine('already using ' + cr^.equipped[slot]^.name);
         end;
      3: if (GDVars.ifcState <> C_Ifc.IN_COMBAT) or (cr^.quickfight = 0) then
           CharHlp.PrintBottomLine('Your hands are full!');
    end;
  end;
end;

{ Gives an item of the current character to a party member the player picks, unless that member cannot carry it
  ("Overloaded").
  @param(item The item.) }
procedure ItemTradeMenu(item: Types.PItem);
var
  tgt: Types.PCreature;
begin
  tgt := GDVars.tradeTarget;
  CharHlp.DisplayNoncombatInterface;
  CharHlp.SelectChar('Trade with Whom?', True, tgt);
  if tgt <> nil then begin
    GDVars.tradeTarget := tgt;
    if ViewChar.CannotCarryItem(tgt, item) then
      CharHlp.PrintBottomLine('Overloaded')
    else begin
      CharHlp.AddItemCopy(Types.PCreature(tgt), Types.PItem(item));
      CharHlp.RemoveItem(Types.PCreature(GDVars.curChar), Types.PItem(item));
      CharHlp.RecalcStats(Types.PCreature(tgt));
    end;
  end;
end;

{ Splits a stack: a new item after it takes half the quantity, rounded down ("Can't halve that" below 2).
  @param(item The stack.) }
procedure HalveItem(item: Types.PItem);
var
  newIt: Types.PItem;
  half: Byte;
  rest: Byte;
begin
  half := item^.quantity div 2;
  if half > 0 then begin
    rest := item^.quantity - half;
    GetMem(newIt, SizeOf(newIt^));
    Move(item^, newIt^, SizeOf(newIt^));
    newIt^.quantity := half;
    newIt^.equipped := 0;
    newIt^.next := item^.next;
    item^.quantity := rest;
    item^.next := newIt;
  end else
    CharHlp.PrintBottomLine('Can''t halve that');
end;

{ Merges the current character's matching stacks (names, type, bonuses, curse and weight, under 2 charges) into a stack,
  up to 255 a stack; what does not fit stays in another stack. Note: the charge, effect and special tests compare each
  stack with itself, so those fields need not match.
  @param(item The stack merged into.) }
procedure JoinItem(item: Types.PItem);
var
  cur: Types.PItem;
  next: Types.PItem;
  dst: Types.PItem;
  qty: Byte;
begin
  dst := item;
  qty := dst^.quantity;
  cur := GDVars.curChar^.itemsAddr;
  while cur <> nil do begin
    next := cur^.next;
    if (cur <> dst) and (cur^.quantity > 0) and (cur^.nameIds[1] = dst^.nameIds[1]) and
        (cur^.nameIds[2] = dst^.nameIds[2]) and (cur^.nameIds[3] = dst^.nameIds[3]) and
        (cur^.itemType = dst^.itemType) and (cur^.plus = dst^.plus) and (cur^.saveBonus = dst^.saveBonus) and
        (cur^.cursed = dst^.cursed) and (cur^.weight = dst^.weight) and (cur^.charges = cur^.charges) and
        (cur^.charges < 2) and (cur^.effect = cur^.effect) and (cur^.special = cur^.special) then begin
      if qty + cur^.quantity <= 255 then begin
        Inc(qty, cur^.quantity);
        CharHlp.RemoveItem(Types.PCreature(GDVars.curChar), Types.PItem(cur));
      end else begin
        dst^.quantity := 255;
        cur^.quantity := cur^.quantity - (255 - qty);
        qty := cur^.quantity;
        dst := cur;
      end;
    end;
    cur := next;
  end;
  dst^.quantity := qty;
end;

procedure UseItem(item: Types.PItem; var done: Boolean);
var
  spell: Byte;
  idx: Integer;
  notEmpty: Boolean;
begin
  idx := -1;
  GDVars.usingItem := False;
  spell := 0;
  if Magic.ItemReadable(item) then begin
    GDVars.currentScroll := item;
    spell := ViewChar.SpellMenu(2, 1, idx, notEmpty);
  end else if (item^.effect > 0) and (item^.special < $80) then begin
    GDVars.usingItem := True;
    spell := item^.effect and C_Spell.ID_MASK;
  end;
  if spell = 0 then
    done := False
  else begin
    if (GDVars.ifcState = C_Ifc.IN_COMBAT) and (GDVars.curChar^.quickfight = 0) then
      CharHlp.DisplayCombatInterface;
    if GDVars.usingItem then begin
      CharHlp.PrintCreatureMessage(Types.PCreature(GDVars.curChar), 'uses an item', 10, Boolean(0));
      if GDVars.ifcState = C_Ifc.IN_COMBAT then begin
        TextRend.DisplayString(0, 23, LightGreen, 0, 'Item:');
        CharHlp.PrintItemString(GDVars.curChar, Pointer(item), 5, 23, False, True);
      end else
        CharHlp.PrintItemString(GDVars.curChar, Pointer(item), 1, 22, False, True);
      TextRend.PauseOnly;
      CharHlp.ClearMessageWindow;
    end;
    GDVars.usingItem := True;
    if Magic.ItemReadable(item) then begin
      if (ClassCal.FirstEarlierClass(Types.PCreature(GDVars.curChar)) = C_Class.MAGE_LEVEL) or
          (ClassCal.FirstCurrentClass(Types.PCreature(GDVars.curChar)) = C_Class.MAGE_LEVEL) or
          (ClassCal.FirstEarlierClass(Types.PCreature(GDVars.curChar)) = C_Class.CLERIC_LEVEL) or
          (ClassCal.FirstCurrentClass(Types.PCreature(GDVars.curChar)) = C_Class.CLERIC_LEVEL) or
          (GDVars.curChar^.classLevels[C_Class.MAGE_LEVEL] > 0) or
          (GDVars.curChar^.classLevels[C_Class.CLERIC_LEVEL] > 0) then
        Magic.CastSpell(spell, Boolean(GDVars.curChar^.quickfight), False, done)
      else if (GDVars.curChar^.classLevels[C_Class.THIEF_LEVEL] > 9) and (FxEngine.RollDice(1, 100) <= 75) then
        Magic.CastSpell(spell, Boolean(GDVars.curChar^.quickfight), False, done)
      else
        CharHlp.PrintCreatureMessage(Types.PCreature(GDVars.curChar), 'oops!', GDVars.curRow + 1, Boolean(1));
    end else
      Magic.CastSpell(spell, Boolean(GDVars.curChar^.quickfight), False, done);
    GDVars.usingItem := False;
    if GDVars.ifcState = C_Ifc.IN_COMBAT then
      if GDConsts.spellProperties[spell].combatOk <> 0 then
        done := CharHlp.EndActions(Types.PCreature(GDVars.curChar));
  end;
  if done then begin
    if Magic.ItemReadable(item) then
      Magic.RemoveSpellFromScroll(GDVars.curChar, item, spell)
    else if item^.charges > 0 then begin
      if item^.quantity > 1 then
        Dec(item^.quantity)
      else begin
        Dec(item^.charges);
        if item^.charges = 0 then
          CharHlp.RemoveItem(Types.PCreature(GDVars.curChar), Types.PItem(item));
      end;
    end;
  end;
end;

{ Offers half an item's value (for a stack, times the quantity divided by 20) and, on a deal, removes it and pays in
  platinum and gold; platinum the character cannot carry goes to the pool. Note: the test meant to price arrows and
  bolts by the whole quantity is always true, and the coins paid add no weight.
  @param(item The item.) }
procedure SellItem(item: Types.PItem);
var
  price: Word;
  plat: Word;
  gold: Word;
  takable: Word;
begin
  price := 0;
  if item^.value > 0 then
    price := item^.value div 2;
  if item^.quantity > 1 then begin
    if (item^.itemType <> 73) or (item^.itemType <> 28) then
      price := price * item^.quantity div 20
    else
      price := price * item^.quantity;
  end;
  CharHlp.PrintItemString(GDVars.sheetChar, Pointer(item), 0, 0, False, False);
  TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, 0, True,
                                'I''ll give you ' + CharHlp.Uint16Str(price) + ' gold pieces for your ' + item^.name);
  if MenuCore.YesNoMenu('Is It a Deal? ', LightMagenta, LightGreen, White) = 'Y' then
  begin
    CharHlp.PrintBottomLine('Sold!');
    CharHlp.RemoveItem(Types.PCreature(GDVars.curChar), Types.PItem(item));
    plat := price div 5;
    gold := price mod 5;
    if Money.CheckOverload(GDVars.curChar, gold + plat, takable) then begin
      CharHlp.PrintBottomLine('Overloaded.  Money will be put in pool.');
      if takable > plat then
        Inc(GDVars.curChar^.coins[4], plat)
      else begin
        Inc(GDVars.curChar^.coins[4], takable);
        Inc(GDVars.treasureMoney[4], plat - takable);
      end;
      Inc(GDVars.curChar^.coins[3], gold);
    end else begin
      Inc(GDVars.curChar^.coins[4], plat);
      Inc(GDVars.curChar^.coins[3], gold);
    end;
  end;
  Border.ClearBox(1, 21, 38, 22);
end;

{ Identifies an item fully for 200 gold, paid from the current character's coins or else the pool's; the coins left are
  changed into platinum and gold.
  @param(item The item.)
  @param(newInfo Set True when something new was learned, else left as it was.) }
procedure IdentifyItem(item: Types.PItem; var newInfo: Boolean);
var
  charGold: LongInt;
  poolGold: LongInt;
  paid: Boolean;
begin
  paid := False;
  CharHlp.PrintItemString(GDVars.sheetChar, Pointer(item), 0, 0, False, False);
  TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, 0, True,
                                'For 200 gold pieces I''ll identify your ' + item^.name);
  if MenuCore.YesNoMenu('Is It a Deal? ', LightMagenta, LightGreen, White) = 'Y' then
  begin
    charGold := ViewChar.CreatureCoinValueInGold(GDVars.curChar);
    if charGold >= 200 then begin
      paid := True;
      Dec(charGold, 200);
      Money.SetCreatureCoinsInGold(charGold);
    end else begin
      poolGold := Money.CoinValueInGold(GDVars.treasureMoney);
      if poolGold >= 200 then begin
        paid := True;
        Dec(poolGold, 200);
        Money.SetTreasureCoinsInGold(poolGold);
      end else
        CharHlp.PrintBottomLine('Not Enough Money');
    end;
  end;
  if paid then begin
    if item^.unidMask = 0 then
      TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, 0, True,
                                    'I can''t tell anything new about your ' + item^.name)
    else begin
      item^.unidMask := 0;
      CharHlp.PrintItemString(GDVars.sheetChar, Pointer(item), 0, 0, False, False);
      TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, 0, True, 'It looks like some sort of ' + item^.name);
      newInfo := True;
    end;
  end;
  if paid then
    TextRend.PauseOnly;
  Border.ClearBox(1, 21, 38, 22);
end;

{ Gives coins to party members the player picks, a coin type and amount at a time, until the character has no money left
  or the player stops. }
procedure TradeTreasureMenu;
var
  tgt: Types.PCreature;
  m: ShortInt;
  mType: ShortInt;
  k: Byte;
  gapLen: Byte;
  p: Types.PItem;
  prev: Types.PItem;
  list: Types.PItem;
  count: Word;
  idx: Integer;
  numStr: String[15];
  line: String[4];
  promptStr: String;
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
  amount: Word;
  exitOuter: Boolean;
  exitInner: Boolean;
  redraw: Boolean;
begin
  repeat
    tgt := GDVars.tradeTarget;
    CharHlp.DisplayNoncombatInterface;
    CharHlp.SelectChar('Trade to?', True, tgt);
    if tgt = nil then
      exitOuter := True
    else begin
      ViewChar.DisplayChar;
      repeat
        ViewChar.PrintMoney;
        GDVars.tradeTarget := tgt;
        p := nil;
        prev := nil;
        list := nil;
        count := 0;
        for m := 0 to 6 do
          if GDVars.curChar^.coins[m] <> 0 then begin
            Inc(count);
            if p = nil then begin
              GetMem(p, SizeOf(Types.TItemNode));
              p^.next := nil;
            end else begin
              prev := p;
              GetMem(p, SizeOf(Types.TItemNode));
              p^.next := prev;
            end;
            Str(GDVars.curChar^.coins[m], numStr);
            gapLen := 8 - Length(GDConsts.moneyNames[m]);
            line := '';
            line[0] := Chr(gapLen);
            for k := 1 to gapLen do
              line[k] := ' ';
            p^.name := line + GDConsts.moneyNames[m] + ' ' + numStr;
            p^.inUse := 0;
          end;
        list := p;
        idx := 0;
        redraw := True;
        ch := MenuCore.MenuVertical('Select type of coin ', ' Select', LightMagenta, LightGreen, White, 12, 7, 25, 13,
                                    p, True, redraw, idx, prev);
        if prev = nil then
          exitInner := True
        else begin
          promptStr := '';
          mType := Money.ParseMoneyType(prev^.name, promptStr);
          promptStr := 'How much ' + promptStr + 'will you trade? ';
          amount := Money.InputNumberMax(GDVars.curChar^.coins[mType], promptStr, 10);
          Money.TradeMoney(GDVars.curChar, tgt, amount, mType);
          exitInner := True;
          exitOuter := True;
          for m := 0 to 6 do
            if GDVars.curChar^.coins[m] > 0 then begin
              exitOuter := False;
              exitInner := False;
            end;
        end;
        if list <> nil then
          MenuCore.FreeStringList(list);
      until exitInner;
    end;
  until exitOuter;
end;

{ Drops coins, a type and amount at a time, until none are left or the player stops (in the loot screen, shops and
  temples they go to the pool). }
procedure DropMoneyMenu;
var
  m: ShortInt;
  mType: ShortInt;
  gapLen: Byte;
  k: Byte;
  count: Word;
  idx: Integer;
  p: Types.PItem;
  prev: Types.PItem;
  list: Types.PItem;
  exitFlag: Boolean;
  redraw: Boolean;
  numStr: String[15];
  line: String[4];
  promptStr: String;
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
  amount: Word;
begin
  repeat
    ViewChar.PrintMoney;
    p := nil;
    prev := nil;
    list := nil;
    count := 0;
    for m := 0 to 6 do
      if GDVars.curChar^.coins[m] <> 0 then begin
        Inc(count);
        if p = nil then begin
          GetMem(p, SizeOf(Types.TItemNode));
          p^.next := nil;
        end else begin
          prev := p;
          GetMem(p, SizeOf(Types.TItemNode));
          p^.next := prev;
        end;
        Str(GDVars.curChar^.coins[m], numStr);
        gapLen := 8 - Length(GDConsts.moneyNames[m]);
        line := '';
        line[0] := Chr(gapLen);
        for k := 1 to gapLen do
          line[k] := ' ';
        p^.name := line + GDConsts.moneyNames[m] + ' ' + numStr;
        p^.inUse := 0;
      end;
    list := p;
    idx := 0;
    redraw := True;
    ch := MenuCore.MenuVertical('Select type of coin ', ' Select', LightMagenta, LightGreen, White, 12, 7, 25, 13, p,
                                True, redraw, idx, prev);
    if prev = nil then
      exitFlag := True
    else begin
      promptStr := '';
      mType := Money.ParseMoneyType(prev^.name, promptStr);
      promptStr := 'How much ' + promptStr + 'will you drop? ';
      amount := Money.InputNumberMax(GDVars.curChar^.coins[mType], promptStr, 10);
      Money.DropMoney(GDVars.curChar, amount, mType);
      exitFlag := True;
      for m := 0 to 6 do
        if GDVars.curChar^.coins[m] > 0 then
          exitFlag := False;
    end;
    if list <> nil then
      MenuCore.FreeStringList(list);
  until exitFlag;
end;

function CannotCarryItem(creature: Types.PCreature; item: Types.PItem): Boolean;
var
  f: Boolean;
  w: Word;
begin
  CharHlp.RecalcStats(Types.PCreature(creature));
  f := False;
  if creature^.numberOfItems > 15 then
    f := True;
  w := item^.weight;
  if item^.quantity > 0 then
    w := w * item^.quantity;
  if creature^.encumbrance + w > CharHlp.WeightAllowance(Pointer(creature)) + 1500 then
    f := True;
  CannotCarryItem := f;
end;

procedure SelectPrevNextChar(key: Char);
var
  p: Types.PCreature;
begin
  p := GDVars.partyHead;
  if p <> nil then
    case key of
      C_Keys.HOME: if p = GDVars.curChar then begin
             while p^.next <> nil do
               p := p^.next;
           end else
             while (p <> nil) and (p^.next <> GDVars.curChar) do
               p := p^.next;
      C_Keys.END_KEY: if GDVars.curChar^.next <> nil then
             p := GDVars.curChar^.next;
    else
      p := GDVars.partyHead;
    end;
  GDVars.curChar := p;
end;

function CreatureCoinValueInGold(creature: Types.PCreature): LongInt;
var
  sum: LongInt;
  m: ShortInt;
begin
  sum := 0;
  for m := 0 to 4 do
    Inc(sum, GDConsts.coinValues[m] * creature^.coins[m]);
  CreatureCoinValueInGold := (sum + 100) div GDConsts.coinValues[3];
end;

function SpellMenu(menuType, selType: Byte; var idx: Integer; var notEmpty: Boolean): Byte;
var
  s: Types.TStr40;
begin
  case menuType of
    0: s := 'in Memory';
    1: s := 'in Grimoire';
    2: s := 'on Scroll';
    3: s := 'on Scrolls';
    4: s := 'to Choose';
    5: s := 'to Memorize';
    6: s := 'to Scribe';
  else
    s := '';
  end;
  notEmpty := Magic.GenerateSpellList(menuType);
  if notEmpty then begin
    if (idx < 0) or (selType = 1) then begin
      if GDVars.ifcState <> C_Ifc.IN_COMBAT then begin
        if selType = 2 then
          Border.DrawMemorizeFrame
        else
          Border.DrawTitleInset;
      end else
        Border.DrawWindowFrame;
    end;
    CharHlp.DisplayCreatureName(Pointer(GDVars.curChar), 1, 1, True);
    TextRend.DisplayString(Length(GDVars.curChar^.name) + 4, 1, LightGreen, 0, 'Spells ' + s);
    SpellMenu := Magic.SpellSelection(selType, idx);
  end else
    SpellMenu := 0;
end;

function CanHeal(cr: Types.PCreature): Boolean;
var
  eff: Types.PEffect;
begin
  CanHeal := ((cr^.charClass = C_Class.PALADIN) or
              ((cr^.oldClassLevels[C_Class.PALADIN_LEVEL] > 0) and
               Boolean(ClassCal.EarlierClassActive(Types.PCreature(cr))))) and
    (GDVars.ifcState <> C_Ifc.IN_COMBAT) and (cr^.status = C_Status.OKAY) and
    not CharHlp.HasEffect(Types.PCreature(cr), C_Effect.RECENTLY_HEALED, eff);
end;

function CanCure(cr: Types.PCreature): Boolean;
begin
  CanCure := ((cr^.charClass = C_Class.PALADIN) or
              ((cr^.oldClassLevels[C_Class.PALADIN_LEVEL] > 0) and
               Boolean(ClassCal.EarlierClassActive(Types.PCreature(cr))))) and
    (GDVars.ifcState <> C_Ifc.IN_COMBAT) and (cr^.status = C_Status.OKAY) and (cr^.cureDiseaseUses > 0);
end;

procedure PaladinLayOnHands(cr: Types.PCreature);
var
  tgt: Types.PCreature;
begin
  CharHlp.DisplayNoncombatInterface;
  tgt := GDVars.partyHead;
  CharHlp.SelectChar('Heal whom? ', True, tgt);
  if tgt = nil then
    ViewChar.DisplayChar
  else begin
    if FxEngine.RestoreHitPoints(tgt,
                                 (cr^.oldClassLevels[C_Class.PALADIN_LEVEL] * ClassCal.EarlierClassActive(cr) +
                                   cr^.classLevels[C_Class.PALADIN_LEVEL]) * 2, False) then
      CharHlp.PrintBottomLine(tgt^.name + ' feels better')
    else
      CharHlp.PrintBottomLine(tgt^.name + ' is unaffected');
    FxEngine.AddEffect(Types.PCreature(cr), C_Effect.RECENTLY_HEALED, 1440, 0, False);
    ViewChar.DisplayChar;
  end;
end;

procedure PaladinCureDisease(cr: Types.PCreature);
var
  tgt: Types.PCreature;
  found: Boolean;
  ch: Char;
  eff: Types.PEffect;
begin
  CharHlp.DisplayNoncombatInterface;
  tgt := GDVars.partyHead;
  CharHlp.SelectChar('Cure whom? ', True, tgt);
  if tgt = nil then
    ViewChar.DisplayChar
  else begin
    found := False;
    for GDVars.sharedLoopIdx := 1 to 6 do
      if CharHlp.HasEffect(Types.PCreature(tgt), GDConsts.cureEffects[GDVars.sharedLoopIdx], eff) then
        found := True;
    ch := 'Y';
    if not found then begin
      CharHlp.PrintCreatureMessage(Types.PCreature(tgt), 'is not diseased', 0, Boolean(0));
      ch := MenuCore.YesNoMenu('cure anyway: ', LightMagenta, LightGreen, White);
      CharHlp.ClearMessageWindow;
    end;
    if ch = 'Y' then
    begin
      GDVars.effectLock := 1;
      for GDVars.sharedLoopIdx := 1 to 6 do
        FxEngine.RemoveEffect(Types.PCreature(tgt), GDConsts.cureEffects[GDVars.sharedLoopIdx], nil);
      GDVars.effectLock := 0;
      if cr^.cureDiseaseUses > 0 then
        Dec(cr^.cureDiseaseUses);
      if not CharHlp.HasEffect(Types.PCreature(cr), C_Effect.RECENTLY_CURED, eff) then
        FxEngine.AddEffect(Types.PCreature(cr), C_Effect.RECENTLY_CURED, 10080, 0, True);
      CharHlp.PrintBottomLine(tgt^.name + ' is cured');
    end;
    ViewChar.DisplayChar;
  end;
end;

begin
end.
