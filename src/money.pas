{ Money: carrying weight, the treasure pool (pooling, sharing, taking and dropping money), gem and jewelry appraisal,
  and random treasure items. }
{$O+,F+}
{$A-}
unit Money;

interface

uses Types, FxEngine, CharHlp, TextRend, GameIo, MenuCore, Border, EclTrace, GDConsts, GDVars, C_Keys, C_Ifc, Crt;

{ Tells whether adding weight to a character's encumbrance would take it past its carrying capacity.
  @param(creature The character.)
  @param(weight The weight to be added.)
  @param(takable Receives the weight the character can still carry when it would be overloaded, else 0.)
  @returns(True when the weight does not fit.) }
function CheckOverload(creature: Types.PCreature; weight: Word; var takable: Word): Boolean;

{ Moves the money of each player character, including one made a quick fighter by charm (NPC value $B3), into the pool,
  taking its weight off, and marks the pool as holding money. }
procedure PoolMoney;

{ Divides the pool: each member with an NPC value below $80 gets an equal share of each money type (jewelry and gems
  first) and one coin of the remainder, as far as its carrying capacity allows, the shares being worked out over
  CountPoolers members. What is left goes to any party member with room to spare, and the rest stays in the pool, which
  is marked as holding money when anything stays. }
procedure ShareMoney;

{ Lists the money in the pool and lets the current character take an amount of the chosen type, until the pool is empty
  or the player leaves. Note: leaving the menu without choosing does not free the list it was built from. }
procedure TakeMoneyMenu;

{ Gives platinum to the current character; what it cannot carry goes into the pool ("Overloaded. Money will be put in
  Pool.").
  @param(pp The platinum given.) }
procedure GivePlatinum(pp: Word);

{ Reads the money type named by the first non-space letter of a menu entry: G followed by E is gems, G otherwise gold,
  then P, E, S, C and J for platinum, electrum, silver, copper and jewelry.
  @param(entry The menu entry.)
  @param(typeName Receives the type's name and a trailing space.)
  @returns(The money type; undefined for other letters.) }
function ParseMoneyType(entry: String; var typeName: String): ShortInt;

{ Shows a question on the bottom row and reads a number of at most max: digits are echoed in white, a number above max
  becomes max, and backspace takes off the last digit. Enter or Escape ends the input.
  @param(max The largest number accepted.)
  @param(query The question shown.)
  @param(color The question's color.)
  @returns(The number, or 0 on Escape.) }
function InputNumberMax(max: Word; query: Types.TStr40; color: Byte): Word;

{ Moves money from one character to another, unless that would overload the receiver ("Overloaded").
  @param(giver The character giving the money.)
  @param(rcv The character receiving it.)
  @param(qty The amount.)
  @param(mType The money type.) }
procedure TradeMoney(var giver, rcv: Types.PCreature; qty: Word; mType: ShortInt);

{ Takes money from a character; in the loot screen and in shops and temples it goes into the pool, elsewhere it is lost.
  @param(creature The character.)
  @param(qty The amount.)
  @param(mType The money type.) }
procedure DropMoney(creature: Types.PCreature; qty: Word; mType: ShortInt);

{ Tells what treasure is left.
  @param(coins Set True when any pool slot is not 0, else False.)
  @param(items Set True when the treasure item list is not empty, else False.) }
procedure DetermineTreasure(var coins, items: Boolean);

{ Replaces the current character's coins with an amount of gold, paid as gp div 5 platinum and gp mod 5 gold. Gems and
  jewelry are kept, and the encumbrance is left as it was.
  @param(gp The amount in gold.) }
procedure SetCreatureCoinsInGold(gp: Word);

{ Replaces the pool's coins with an amount of gold, as gp div 5 platinum and gp mod 5 gold. Gems and jewelry are kept.
  @param(gp The amount in gold.) }
procedure SetTreasureCoinsInGold(gp: Word);

{ Values the coins of a money record in gold, rounded half up; gems and jewelry are not counted.
  @param(coins The money record.)
  @returns(The value in gold.) }
function CoinValueInGold(coins: Types.TMoney): LongInt;

{ Fills an item record with a random item of a kind. Weapons and armor (1..59, 73, 77, 93) get a +1 or +2 bonus (kind 77
  twice that plus 2) with their name, weight and value; kinds 61 and 62 get 1..3 random magic-user (61) or clerical (62)
  spells of levels 1..5, worth 300 gp a level; kinds 63, 67, 71, 78, 79, 84, 92, and one in five of kind 21, copy a
  template from the random-item table.
  @param(kind The item kind.)
  @param(item Receives the item.) }
procedure GenerateRandomItem(kind: Byte; var item: Types.TItem);

{ Appraises the current character's gems and jewelry one at a time: each gets a random value and is sold for its full
  value, paid as value div 5 platinum, or, when the character has room and fewer than 16 items, kept as an item. Note: a
  kept gem or jewel is linked to the end of the item list without counting it or adding its weight, and it is lost when
  the character carries no items.
  @param(ok Set False when there is nothing to appraise, else True.) }
procedure AppraiseMenu(var ok: Boolean);

{ Calls the priming entry of each overlay this unit uses, so the overlay manager loads them. }
procedure PrimeMoney;

implementation

type
  { The low and high words of a LongInt. }
  TLongWords = record
    lo: Word;
    hi: Word;
  end;

var
  { The pool's money slots, each read as its low and high words. }
  treasureMoneyLo: array[0..6] of TLongWords absolute GDVars.treasureMoney;

procedure PrimeMoney;
begin
  MenuCore.PrimeMenuCore;
  CharHlp.PrimeCharHlp;
  FxEngine.PrimeFxEngine;
  EclTrace.PrimeEclTrace;
end;

{ Works out how much weight a character can carry before it is overloaded: its Strength weight allowance plus 1500.
  @param(creature The character.)
  @returns(The carrying capacity.) }
function CarryingCapacity(creature: Types.PCreature): Word;
begin
  CarryingCapacity := CharHlp.WeightAllowance(creature) + 1500;
end;

{ Takes weight off a character's encumbrance.
  @param(creature The character.)
  @param(weight The weight removed.) }
procedure RemoveWeight(creature: Types.PCreature; weight: Word);
begin
  creature^.encumbrance := creature^.encumbrance - weight;
end;

{ Adds weight to a character's encumbrance.
  @param(creature The character.)
  @param(weight The weight added.) }
procedure AddWeight(creature: Types.PCreature; weight: Word);
begin
  creature^.encumbrance := creature^.encumbrance + weight;
end;

function CheckOverload(creature: Types.PCreature; weight: Word; var takable: Word): Boolean;
begin
  if creature^.encumbrance + weight > Money.CarryingCapacity(creature) then begin
    CheckOverload := True;
    takable := Money.CarryingCapacity(creature) - creature^.encumbrance;
  end else begin
    CheckOverload := False;
    takable := 0;
  end;
end;

function CoinValueInGold(coins: Types.TMoney): LongInt;
var
  total: LongInt;
  i: ShortInt;
begin
  total := 0;
  for i := 0 to 4 do
    Inc(total, GDConsts.coinValues[i] * coins[i]);
  CoinValueInGold := (total + 100) div GDConsts.coinValues[3];
end;

procedure SetCreatureCoinsInGold(gp: Word);
var
  i: ShortInt;
begin
  for i := 0 to 4 do
    GDVars.curChar^.coins[i] := 0;
  GDVars.curChar^.coins[4] := gp div 5;
  GDVars.curChar^.coins[3] := gp mod 5;
end;

procedure SetTreasureCoinsInGold(gp: Word);
var
  i: ShortInt;
begin
  for i := 0 to 4 do
    GDVars.treasureMoney[i] := 0;
  GDVars.treasureMoney[4] := gp div 5;
  GDVars.treasureMoney[3] := gp mod 5;
end;

procedure GivePlatinum(pp: Word);
var
  takable: Word;
begin
  if Money.CheckOverload(GDVars.curChar, pp, takable) then begin
    CharHlp.PrintBottomLine('Overloaded.  Money will be put in Pool.');
    Inc(GDVars.curChar^.coins[4], takable);
    Money.AddWeight(GDVars.curChar, takable);
    GDVars.treasureMoney[4] := pp + GDVars.treasureMoney[4] - takable;
  end else begin
    Inc(GDVars.curChar^.coins[4], pp);
    Money.AddWeight(GDVars.curChar, pp);
  end;
end;

function InputNumberMax(max: Word; query: Types.TStr40; color: Byte): Word;
var
  col: Byte;
  { Unused in this version; see the other implementations of this routine. }
  maxLen: Byte;
  qLen: Byte;
  maxStr: String[5];
  s: String[6];
  ch: Char;
  v: LongInt;
  code: Integer;
  n: Word;
begin
  TextRend.PrintSpaces(0, 24, 0, 40);
  TextRend.DisplayString(0, 24, color, 0, query);
  qLen := Length(query);
  col := qLen;
  Str(max, maxStr);
  s := '';
  repeat
    ch := GameIo.ReadGameKey;
    case ch of
      '0'..'9': begin
          s := Concat(s, ch);
          Val(s, v, code);
          if max >= v then
            Inc(col)
          else begin
            s := maxStr;
            col := qLen + Length(maxStr);
          end;
          TextRend.DisplayString(qLen, 24, White, 0, s);
        end;
      C_Keys.BACKSPACE: if Length(s) > 0 then begin
          s := Copy(s, 1, Length(s) - 1);
          TextRend.PrintSpaces(col, 24, 0, 1);
          Dec(col);
        end;
    end;
  until (ch = C_Keys.ENTER) or (ch = C_Keys.ESCAPE);
  TextRend.PrintSpaces(0, 24, 0, 40);
  if ch = C_Keys.ESCAPE then
    n := 0
  else
    Val(s, n, code);
  InputNumberMax := n;
end;

procedure TradeMoney(var giver, rcv: Types.PCreature; qty: Word; mType: ShortInt);
begin
  if rcv^.encumbrance + qty <= Money.CarryingCapacity(rcv) then begin
    giver^.coins[mType] := giver^.coins[mType] - qty;
    Money.RemoveWeight(giver, qty);
    rcv^.coins[mType] := rcv^.coins[mType] + qty;
    Money.AddWeight(rcv, qty);
  end else
    CharHlp.PrintBottomLine('Overloaded');
end;

procedure PoolMoney;
var
  p: Types.PCreature;
  i: ShortInt;
  mt: ShortInt;
begin
  p := GDVars.partyHead;
  GDVars.treasureMoneyFlag := True;
  while p <> nil do begin
    if (p^.npc = 0) or (p^.npc = $B3) then begin
      for i := 0 to 6 do begin
        mt := i;
        GDVars.treasureMoney[mt] := p^.coins[mt] + GDVars.treasureMoney[mt];
        Money.RemoveWeight(p, p^.coins[mt]);
      end;
      FillChar(p^.coins, SizeOf(p^.coins), 0);
    end;
    p := p^.next;
  end;
end;

{ Counts the player characters, including those made quick fighters by charm (NPC value $B3).
  @returns(The number of characters that pool money.) }
function CountPoolers: Byte;
var
  p: Types.PCreature;
  n: Byte;
begin
  p := GDVars.partyHead;
  n := 0;
  while p <> nil do begin
    if (p^.npc = 0) or (p^.npc = $B3) then
      Inc(n);
    p := p^.next;
  end;
  CountPoolers := n;
end;

procedure ShareMoney;
var
  p: Types.PCreature;
  { Unused in this version; see the other implementations of this routine. }
  receiver: Types.PCreature;
  cnt: Byte;
  { Unused in this version; see the other implementations of this routine. }
  done: Boolean;
  takable: Word;
  share: array[0..6] of Word;
  rem: array[0..6] of Word;
  i: ShortInt;
begin
  p := GDVars.partyHead;
  done := False;
  cnt := Money.CountPoolers;
  FillChar(share, SizeOf(share), 0);
  FillChar(rem, SizeOf(rem), 0);
  for i := 0 to 6 do
    if GDVars.treasureMoney[i] > 0 then begin
      share[i] := GDVars.treasureMoney[i] div cnt;
      rem[i] := GDVars.treasureMoney[i] mod cnt;
    end else begin
      share[i] := 0;
      rem[i] := 0;
    end;
  while p <> nil do begin
    if p^.npc < $80 then
      for i := 6 downto 0 do
        if not Money.CheckOverload(p, share[i], takable) then begin
          p^.coins[i] := share[i] + p^.coins[i];
          Money.AddWeight(p, share[i]);
          if rem[i] > 0 then
            if not Money.CheckOverload(p, 1, takable) then begin
              p^.coins[i] := p^.coins[i] + 1;
              Money.AddWeight(p, 1);
              Dec(rem[i]);
            end;
        end else begin
          p^.coins[i] := p^.coins[i] + takable;
          rem[i] := rem[i] + share[i] - takable;
          Money.AddWeight(p, takable);
        end;
    p := p^.next;
  end;
  for i := 6 downto 0 do
    if rem[i] > 0 then begin
      p := GDVars.partyHead;
      while p <> nil do begin
        takable := Money.CarryingCapacity(p) - p^.encumbrance;
        if takable > 0 then
          if rem[i] > takable then begin
            p^.coins[i] := p^.coins[i] + takable;
            Money.AddWeight(p, takable);
            rem[i] := rem[i] - takable;
          end else begin
            p^.coins[i] := p^.coins[i] + rem[i];
            Money.AddWeight(p, rem[i]);
            rem[i] := 0;
          end;
        p := p^.next;
      end;
    end;
  GDVars.treasureMoneyFlag := False;
  for i := 0 to 6 do begin
    GDVars.treasureMoney[i] := rem[i];
    if GDVars.treasureMoney[i] <> 0 then
      GDVars.treasureMoneyFlag := True;
  end;
end;

procedure DropMoney(creature: Types.PCreature; qty: Word; mType: ShortInt);
begin
  creature^.coins[mType] := creature^.coins[mType] - qty;
  Money.RemoveWeight(creature, qty);
  if (GDVars.ifcState = C_Ifc.LOOT) or (GDVars.ifcState = C_Ifc.SHOP_TEMPLE) then
    GDVars.treasureMoney[mType] := GDVars.treasureMoney[mType] + qty;
end;

{ Moves money from the pool to a character, at most what the pool holds (its low word); an amount that would overload
  the character is refused whole ("Overloaded"). Note: the overload test uses the amount asked for, before it is cut
  down to what the pool holds.
  @param(creature The character.)
  @param(qty The amount asked for.)
  @param(mType The money type.) }
procedure TakeMoney(creature: Types.PCreature; qty: Word; mType: ShortInt);
var
  takable: Word;
begin
  if Money.CheckOverload(creature, qty, takable) then
    CharHlp.PrintBottomLine('Overloaded')
  else begin
    if qty > GDVars.treasureMoney[mType] then
      qty := treasureMoneyLo[mType].lo;
    GDVars.treasureMoney[mType] := GDVars.treasureMoney[mType] - qty;
    creature^.coins[mType] := creature^.coins[mType] + qty;
    Money.AddWeight(creature, qty);
  end;
end;

function ParseMoneyType(entry: String; var typeName: String): ShortInt;
var
  i: Byte;
begin
  i := 1;
  while entry[i] = ' ' do
    Inc(i);
  case entry[i] of
    'G': if UpCase(entry[i + 1]) = 'E' then begin
           ParseMoneyType := 5;
           typeName := 'Gems ';
         end else begin
           typeName := 'Gold ';
           ParseMoneyType := 3;
         end;
    'P': begin
           typeName := 'Platinum ';
           ParseMoneyType := 4;
         end;
    'E': begin
           typeName := 'electrum ';
           ParseMoneyType := 2;
         end;
    'S': begin
           typeName := 'silver ';
           ParseMoneyType := 1;
         end;
    'C': begin
           typeName := 'Copper ';
           ParseMoneyType := 0;
         end;
    'J': begin
           typeName := 'Jewelry ';
           ParseMoneyType := 6;
         end;
  end;
end;

procedure TakeMoneyMenu;
var
  i: ShortInt;
  mType: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  weight: Word;
  p: Types.PItem;
  sel: Types.PItem;
  save: Types.PItem;
  cnt: Word;
  idx: Integer;
  numStr: String;
  n: Word;
  exitF: Boolean;
  redraw: Boolean;
  ch: Char;
begin
  Border.DrawWindowFrame;
  idx := 0;
  repeat
    redraw := True;
    p := nil;
    sel := nil;
    for i := 6 downto 0 do
      if GDVars.treasureMoney[i] > 0 then begin
        Inc(cnt);
        if p = nil then begin
          GetMem(p, SizeOf(Types.TItemNode));
          p^.next := nil;
        end else begin
          sel := p;
          GetMem(p, SizeOf(Types.TItemNode));
          p^.next := sel;
        end;
        Str(GDVars.treasureMoney[i], numStr);
        p^.name := GDConsts.moneyNames[i] + ' ' + numStr;
        p^.inUse := 0;
      end;
    sel := p;
    save := p;
    ch := MenuCore.MenuVertical('Select type of coin ', 'Select', LightMagenta, LightGreen, White, 2, 2, 15, 8, p, True,
                                redraw, idx, sel);
    if (sel = nil) or (ch = C_Keys.NONE) then
      exitF := True
    else begin
      exitF := False;
      mType := Money.ParseMoneyType(sel^.name, numStr);
      numStr := 'How much ' + numStr + 'will you take? ';
      n := Money.InputNumberMax(treasureMoneyLo[mType].lo, numStr, 10);
      Money.TakeMoney(GDVars.curChar, n, mType);
      MenuCore.FreeStringList(save);
      GDVars.treasureMoneyFlag := False;
      exitF := True;
      for i := 0 to 6 do
        if GDVars.treasureMoney[i] > 0 then begin
          GDVars.treasureMoneyFlag := True;
          exitF := False;
        end;
    end;
  until exitF;
end;

procedure DetermineTreasure(var coins, items: Boolean);
var
  i: ShortInt;
begin
  coins := False;
  items := False;
  for i := 0 to 6 do
    if GDVars.treasureMoney[i] <> 0 then
      coins := True;
  if GDVars.treasureItems <> nil then
    items := True;
end;

{ Rolls a random weapon or armor bonus.
  @returns(1 on a d20 roll of 1..14, 2 on 15..20.) }
function RandomBonus: ShortInt;
var
  r: Byte;
begin
  r := FxEngine.RollDice(1, 20);
  case r of
    1..14: RandomBonus := 1;
    15..20: RandomBonus := 2;
  end;
end;

procedure GenerateRandomItem(kind: Byte; var item: Types.TItem);
var
  roll: Byte;
  spellCount: Byte;
  j: Byte;
  templateIdx: Byte;
  spell: Byte;
begin
  FillChar(item, SizeOf(item), 0);
  templateIdx := 0;
  with item do begin
    FillChar(spells, SizeOf(spells), 0);
    next := nil;
    equipped := 0;
    unidMask := 6;
    cursed := 0;
    itemType := kind;
    FillChar(nameIds, SizeOf(nameIds), 0);
    case itemType of
      1..59, 73, 77, 93: begin
          plus := Money.RandomBonus;
          case itemType of
            21: begin
                   roll := FxEngine.RollDice(1, 5);
                   if roll = 5 then
                     templateIdx := 49;
                   nameIds[3] := 21;
                   nameIds[2] := plus + 161;
                 end;
            28: begin
                   nameIds[3] := 28;
                   nameIds[2] := plus + 161;
                 end;
            50, 51: begin
                   nameIds[3] := itemType;
                   nameIds[2] := 49;
                   nameIds[1] := plus + 161;
                   unidMask := 4;
                 end;
            52: begin
                   nameIds[3] := itemType;
                   nameIds[2] := 50;
                   nameIds[1] := plus + 161;
                   unidMask := 4;
                 end;
            53..58: begin
                   nameIds[3] := itemType;
                   nameIds[2] := 48;
                   nameIds[1] := plus + 161;
                   unidMask := 4;
                 end;
            73: begin
                   nameIds[3] := 61;
                   nameIds[2] := plus + 161;
                 end;
            77: begin
                   nameIds[3] := 79;
                   nameIds[2] := 167;
                   plus := plus * 2 + 2;
                   case plus of
                     4: nameIds[1] := 221;
                     6: nameIds[1] := 222;
                   end;
                 end;
            93: begin
                   nameIds[3] := 66;
                   nameIds[2] := 224;
                   nameIds[1] := plus + 161;
                 end;
            else begin
                   nameIds[3] := itemType;
                   nameIds[2] := plus + 161;
                 end;
          end;
          saveBonus := 0;
          quantity := 0;
          case itemType of
            1, 13, 14, 35:
              weight := 75;
            2, 20, 29, 31, 32, 33, 39, 42, 44, 46, 59:
              weight := 50;
            3, 24, 40:
              weight := 125;
            4, 15, 23, 34, 43, 45, 51:
              weight := 100;
            5, 12, 17, 19, 50:
              weight := 150;
            6: weight := 15;
            7: weight := 30;
            8, 77:
              weight := 10;
            9: begin
                 weight := 25;
                 quantity := 5;
               end;
            10, 26, 36:
              weight := 60;
            11, 16, 25, 27, 41, 47:
              weight := 80;
            18: weight := 175;
            21: weight := 20;
            22, 30:
              weight := 40;
            37: weight := 35;
            38, 53:
              weight := 250;
            52: weight := 200;
            54, 56:
              weight := 400;
            55: weight := 300;
            57: weight := 350;
            58: weight := 450;
            47, 93:
              weight := 1;
            else begin
                   weight := 40;
                   quantity := 10;
                 end;
          end;
          case itemType of
            59: value := Word(plus) * 2500;
            73, 28: value := Word(plus) * 150;
            53, 54: value := Word(plus) * 3000;
            55, 56: value := Word(plus) * 3500;
            57: value := Word(plus) * 4000;
            58: value := Word(plus) * 5000;
            77: value := Word(plus) * 3000;
            else value := Word(plus) * 2000;
          end;
        end;
      61, 62: begin
          spellCount := FxEngine.RollDice(1, 3);
          if itemType = 61 then
            nameIds[3] := 209
          else
            nameIds[3] := 208;
          nameIds[2] := spellCount + 209;
          nameIds[1] := 0;
          plus := 1;
          weight := 25;
          quantity := 0;
          value := 0;
          for j := 1 to spellCount do begin
            roll := FxEngine.RollDice(1, 5);
            if itemType = 61 then
              { magic-user spells of level roll }
              case roll of
                1: spell := FxEngine.RollDice(1, 13) + 8;
                2: spell := FxEngine.RollDice(1, 7) + 28;
                3: spell := FxEngine.RollDice(1, 11) + 44;
                4: spell := FxEngine.RollDice(1, 9) + 80;
                5: spell := FxEngine.RollDice(1, 4) + 90;
              end else
              { clerical spells of level roll }
              case roll of
                1: spell := FxEngine.RollDice(1, 8);
                2: spell := FxEngine.RollDice(1, 7) + 21;
                3: spell := FxEngine.RollDice(1, 8) + 36;
                4: spell := FxEngine.RollDice(1, 5) + 65;
                5: spell := FxEngine.RollDice(1, 6) + 70;
              end;
            spells[j] := spell;
            value := Word(roll) * 300 + value;
          end;
        end;
      63, 67: templateIdx := 41;
      78, 79: templateIdx := 33;
      84, 92: templateIdx := 9;
      71: begin
             roll := FxEngine.RollDice(1, 8);
             case roll of
               1..5: templateIdx := 17;
               6..8: templateIdx := 1;
             end;
           end;
    end;
    if templateIdx <> 0 then begin
      for j := 0 to 2 do
        nameIds[j + 1] := GDConsts.randomItemTemplates.wordBytes[templateIdx + j].lo;
      plus := 1;
      saveBonus := 1;
      weight := GDConsts.randomItemTemplates.words[templateIdx + 3];
      quantity := 0;
      value := GDConsts.randomItemTemplates.words[templateIdx + 4];
      for j := 1 to 3 do
        spells[j] := GDConsts.randomItemTemplates.wordBytes[templateIdx + 4 + j].lo;
    end;
  end;
end;

procedure AppraiseMenu(var ok: Boolean);
var
  gemStr: String[40];
  jwlStr: String[40];
  ch: Char;
  menu: String[40];
  actionStr: String[40];
  r: Byte;
  gemValue: Word;
  takable: Word;
  p: Types.PItem;
  gem: Types.PItem;
  exitF: Boolean;
  ext: Boolean;
  mustSell: Boolean;
begin
  ok := True;
  if (GDVars.curChar^.coins[5] = 0) and (GDVars.curChar^.coins[6] = 0) then begin
    CharHlp.PrintBottomLine('No Gems or Jewelry');
    ok := False;
  end else
    repeat
      if (GDVars.curChar^.coins[5] = 0) and (GDVars.curChar^.coins[6] = 0) then
        exitF := True
      else begin
        exitF := False;
        Str(GDVars.curChar^.coins[5], gemStr);
        Str(GDVars.curChar^.coins[6], jwlStr);
        case GDVars.curChar^.coins[5] of
          0: gemStr := '';
          1: gemStr := gemStr + ' Gem';
          else gemStr := gemStr + ' Gems';
        end;
        case GDVars.curChar^.coins[6] of
          0: jwlStr := '';
          1: jwlStr := jwlStr + ' piece of Jewelry';
          else jwlStr := jwlStr + ' pieces of Jewelry';
        end;
        TextRend.ClearRect(1, 1, 38, 22);
        CharHlp.DisplayCreatureName(GDVars.curChar, 1, 1, False);
        TextRend.DisplayString(1, 7, White, 0, 'You have a fine collection of:');
        TextRend.DisplayString(1, 9, White, 0, gemStr);
        TextRend.DisplayString(1, 10, White, 0, jwlStr);
        menu := '';
        if GDVars.curChar^.coins[5] <> 0 then
          menu := '  Gems';
        if GDVars.curChar^.coins[6] <> 0 then
          menu := menu + '  Jewelry';
        menu := menu + ' Exit';
        ch := MenuCore.MenuHorizontal('Appraise : ', menu, LightMagenta, LightGreen, White, True, False, ext);
        case ch of
          'G': if GDVars.curChar^.coins[5] <> 0 then begin
              Dec(GDVars.curChar^.coins[5]);
              r := FxEngine.RollDice(1, 100);
              case r of
                1..25: gemValue := 10;
                26..50: gemValue := 50;
                51..70: gemValue := 100;
                71..90: gemValue := 500;
                91..99: gemValue := 1000;
                100: gemValue := 5000;
              end;
              Str(gemValue, gemStr);
              gemStr := 'The Gem is Valued at ' + gemStr + ' gp.';
              TextRend.DisplayString(1, 12, White, 0, gemStr);
              if Money.CheckOverload(GDVars.curChar, 1, takable)
                 or (GDVars.curChar^.numberOfItems >= 16) then begin
                actionStr := 'Sell';
                mustSell := True;
              end else begin
                actionStr := 'Sell Keep';
                mustSell := False;
              end;
              ch := MenuCore.MenuHorizontal('You can : ', actionStr, LightMagenta, LightGreen, White, True, False, ext);
              if (ch = 'K') and (not mustSell) then begin
                GetMem(gem, SizeOf(gem^));
                FillChar(gem^, SizeOf(gem^), 0);
                gem^.next := nil;
                gem^.equipped := 0;
                gem^.nameIds[3] := 101;
                gem^.nameIds[2] := 0;
                gem^.nameIds[1] := 0;
                gem^.itemType := 70;
                gem^.value := gemValue;
                gem^.weight := 1;
                gem^.unidMask := 0;
                p := GDVars.curChar^.itemsAddr;
                if p = nil then
                  p := gem
                else begin
                  while p^.next <> nil do
                    p := p^.next;
                  p^.next := gem;
                end;
              end else begin
                gemValue := gemValue div 5;
                Money.GivePlatinum(gemValue);
              end;
            end;
          'J': if GDVars.curChar^.coins[6] <> 0 then begin
              Dec(GDVars.curChar^.coins[6]);
              r := FxEngine.RollDice(1, 100);
              case r of
                1..10: gemValue := Trunc(Random(900)) + 100;
                11..20: gemValue := Trunc(Random(1000)) + 200;
                21..40: gemValue := Trunc(Random(1500)) + 300;
                41..50: gemValue := Trunc(Random(2500)) + 500;
                51..70: gemValue := Trunc(Random(5000)) + 1000;
                71..90: gemValue := Trunc(Random(6000)) + 2000;
                91..100: gemValue := Trunc(Random(10000)) + 2000;
              end;
              Str(gemValue, jwlStr);
              gemStr := 'The Jewel is Valued at ' + jwlStr + ' gp.';
              TextRend.DisplayString(1, 12, White, 0, gemStr);
              if Money.CheckOverload(GDVars.curChar, 1, takable)
                 or (GDVars.curChar^.numberOfItems >= 16) then begin
                actionStr := 'Sell';
                mustSell := True;
              end else begin
                actionStr := 'Sell Keep';
                mustSell := False;
              end;
              ch := MenuCore.MenuHorizontal('You can : ', actionStr, LightMagenta, LightGreen, White, True, False, ext);
              if (ch = 'K') and (not mustSell) then begin
                GetMem(gem, SizeOf(gem^));
                FillChar(gem^, SizeOf(gem^), 0);
                gem^.next := nil;
                gem^.equipped := 0;
                gem^.nameIds[3] := 214;
                gem^.nameIds[2] := 0;
                gem^.nameIds[1] := 0;
                gem^.itemType := 70;
                gem^.value := gemValue;
                gem^.weight := 1;
                gem^.unidMask := 0;
                p := GDVars.curChar^.itemsAddr;
                if p = nil then
                  p := gem
                else begin
                  while p^.next <> nil do
                    p := p^.next;
                  p^.next := gem;
                end;
              end else begin
                gemValue := gemValue div 5;
                Money.GivePlatinum(gemValue);
              end;
            end;
          'E', C_Keys.NONE:
            exitF := True;
        end;
        CharHlp.RecalcStats(GDVars.curChar);
      end;
    until exitF;
end;

begin
end.
