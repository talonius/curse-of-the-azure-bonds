{ Shops: buying the shop's items with the character's or the pool's money, the money pool, and appraising gems and
  jewelry. The shop does not buy. }
{$O+,F+}
{$A-}
unit Shop;

interface

uses Types, MenuCore, ViewChar, Border, TextRend, EclMenu, CharHlp, Money, EclTrace, GDConsts, GDVars, C_Keys, C_Ifc,
  Crt, C_Gbvm;

{ Runs a shop: the money pool starts empty and the shop's goods are the treasure item list. The menu offers Buy, View,
  Pool and Appraise, plus Take and Share while the pool holds money; G and O change the current character; leaving with
  money in the pool asks first. }
procedure ShopMainMenu;

{ Gives the current character a copy of an item at the end of its items and recalculates its stats, unless it cannot
  carry it, which shows an overloaded message.
  @param(item The item to copy.)
  @param(failed Set True when the item was refused.) }
procedure GiveItemCopyToCreature(item: Types.PItem; var failed: Boolean);

{ Calls the priming entry of each overlay this unit uses, so the overlay manager loads them. }
procedure PrimeShop;

implementation

const
  { The script variable in GDVars.zone1^ holding the shop's price scale: 1, 2, 4 and 8 divide prices by 16, 8, 4 and 2;
    $20, $40 and $80 multiply them by 2, 4 and 8. }
  PRICE_SCALE = $7F6D;

procedure PrimeShop;
begin
  Money.PrimeMoney;
  ViewChar.PrimeViewChar;
  MenuCore.PrimeMenuCore;
  CharHlp.PrimeCharHlp;
  EclMenu.PrimeEclMenu;
  EclTrace.PrimeEclTrace;
end;

{ Lists the shop's items with their prices in a vertical Buy menu, then rebuilds the item names. The price is the value
  scaled by the price scale (Shop.PRICE_SCALE), and a scale outside its seven values keeps the value; an item whose
  value is 0 is given the value 1.
  @param(key Receives the key pressed.)
  @param(itemToBuy Receives the chosen item.)
  @param(cursor The highlighted item, kept between calls; receives the chosen item.)
  @param(idx The highlighted item's position, kept between calls.) }
procedure ShopBuyItemSelection(var key: Char; var itemToBuy, cursor: Types.PItem; var idx: Integer);
var
  head: Types.PItem;
  p: Types.PItem;
  tmp: String[16];
  s: String[30];
  lenv: Byte;
  i: Byte;
begin
  p := GDVars.treasureItems;
  while p <> nil do begin
    s := '                              ';
    if p^.value = 0 then p^.value := 1;
    case GDVars.zone1^[Shop.PRICE_SCALE] of
      1: Str(LongInt(p^.value div 16), tmp);
      2: Str(LongInt(p^.value div 8), tmp);
      4: Str(LongInt(p^.value div 4), tmp);
      8: Str(LongInt(p^.value div 2), tmp);
      $20: Str(LongInt(p^.value * 2), tmp);
      $40: Str(LongInt(p^.value * 4), tmp);
      $80: Str(LongInt(p^.value * 8), tmp);
    else
      Str(LongInt(p^.value), tmp);
    end;
    lenv := Length(tmp);
    for i := 1 to lenv do
      s[30 - lenv + i] := tmp[i];
    lenv := Length(p^.name);
    for i := 1 to lenv do
      s[i] := p^.name[i];
    p^.name := s;
    p^.name[0] := #30;
    p := p^.next;
  end;
  head := GDVars.treasureItems;
  GDVars.menuChoice := 0;
  key := MenuCore.MenuVertical('Items: ', 'Buy', LightMagenta, LightGreen, White, 1, 1, 38, 22, head, True,
                               GDVars.buyRedraw, idx, cursor);
  itemToBuy := cursor;
  p := GDVars.treasureItems;
  while p <> nil do begin
    CharHlp.PrintItemString(nil, p, 0, 0, False, False);
    p := p^.next;
  end;
end;

procedure GiveItemCopyToCreature(item: Types.PItem; var failed: Boolean);
var
  p: Types.PItem;
  q: Types.PItem;
begin
  if ViewChar.CannotCarryItem(GDVars.curChar, item) then begin
    CharHlp.PrintBottomLine('OverLoaded');
    failed := True;
  end else begin
    failed := False;
    p := GDVars.curChar^.itemsAddr;
    if p = nil then begin
      GetMem(p, SizeOf(Types.TItem));
      p^ := item^;
      p^.next := nil;
      GDVars.curChar^.itemsAddr := p;
    end else begin
      while p^.next <> nil do
        p := p^.next;
      GetMem(q, SizeOf(Types.TItem));
      q^ := item^;
      q^.next := nil;
      p^.next := q;
    end;
    CharHlp.RecalcStats(GDVars.curChar);
  end;
end;

{ Buys items until the player leaves the Buy menu: the scaled price is paid from the current character's coins when they
  suffice, else from the pool ("Not enough Money." otherwise), the change coming back as platinum and gold. Note: unlike
  the listing, a price scale other than the seven named ones leaves the price unset. }
procedure ShopBuyMenu;
var
  itemToBuy: Types.PItem;
  c: Char;
  done: Boolean;
  price: Word;
  charGold: Word;
  pooled: LongInt;
  failed: Boolean;
  cursor: Types.PItem;
  idx: Integer;
begin
  itemToBuy := nil;
  cursor := GDVars.treasureItems;
  idx := 0;
  Border.DrawWindowFrame;
  GDVars.buyRedraw := True;
  repeat
    Shop.ShopBuyItemSelection(c, itemToBuy, cursor, idx);
    if (c <> 'B') and (c <> C_Keys.ENTER) then
      done := True
    else begin
      done := False;
      case GDVars.zone1^[Shop.PRICE_SCALE] of
        1: price := itemToBuy^.value div 16;
        2: price := itemToBuy^.value div 8;
        4: price := itemToBuy^.value div 4;
        8: price := itemToBuy^.value div 2;
        $20: price := itemToBuy^.value * 2;
        $40: price := itemToBuy^.value * 4;
        $80: price := itemToBuy^.value * 8;
      end;
      charGold := ViewChar.CreatureCoinValueInGold(GDVars.curChar);
      if price <= charGold then begin
        Shop.GiveItemCopyToCreature(itemToBuy, failed);
        if not failed then begin
          charGold := charGold - price;
          Money.SetCreatureCoinsInGold(charGold);
        end;
      end else begin
        pooled := Money.CoinValueInGold(GDVars.treasureMoney);
        if price <= pooled then begin
          Shop.GiveItemCopyToCreature(itemToBuy, failed);
          if not failed then begin
            pooled := pooled - price;
            Money.SetTreasureCoinsInGold(pooled);
          end;
        end else
          CharHlp.PrintBottomLine('Not enough Money.');
      end;
    end;
  until done;
end;

procedure ShopMainMenu;
var
  menu: String[40];
  query: String[1];
  ext: Boolean;
  done: Boolean;
  c: Char;
  hasMoney: Boolean;
  hasItems: Boolean;
  ynIdx: Byte;
  apprOk: Boolean;
  p: Types.PItem;
begin
  GDVars.ifcState := C_Ifc.SHOP_TEMPLE;
  GDVars.shopSession := GDVars.zone0^[C_Gbvm.VIEW_3D] = 0;
  CharHlp.DisplayNoncombatInterface;
  GDVars.shopSession := True;
  CharHlp.DisplayParty(GDVars.curChar);
  FillChar(GDVars.treasureMoney, SizeOf(Types.TMoney), 0);
  query[0] := #0;
  GDVars.treasureMoneyFlag := False;
  done := False;
  p := GDVars.treasureItems;
  while p <> nil do begin
    CharHlp.PrintItemString(nil, p, 0, 0, False, False);
    p := p^.next;
  end;
  repeat
    Money.DetermineTreasure(hasMoney, hasItems);
    if hasMoney then
      menu := 'Buy View Take Pool Share Appraise Exit'
    else
      menu := 'Buy View Pool Appraise Exit';
    c := MenuCore.MenuHorizontal(query, menu, LightMagenta, LightGreen, White, True, False, ext);
    case c of
      'B': Shop.ShopBuyMenu;
      'V': ViewChar.ViewCharMenu(ext);
      'T': Money.TakeMoneyMenu;
      'P': if not ext then Money.PoolMoney;
      'S': Money.ShareMoney;
      'A': Money.AppraiseMenu(apprOk);
      'E': begin
             Money.DetermineTreasure(hasMoney, hasItems);
             if hasMoney then begin
               menu := '~Yes ~No';
               TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, True,
'As you Leave the Shopkeeper says, "Excuse me but you have Left Some Money here."  ');
               TextRend.DisplayMessageWindow(1, 17, 38, 22, White, 0, False,
                                             'Do you want to go back and get your Money?');
               ynIdx := EclMenu.MenuHorizontalCharacterSelect(query, menu, LightMagenta, LightGreen, White, False,
                                                              False);
               if ynIdx = 1 then
                 done := True
               else
                 TextRend.ClearRect(1, 17, 38, 22);
             end else
               done := True;
           end;
      C_Keys.HOME: ViewChar.SelectPrevNextChar(c);
      C_Keys.END_KEY: ViewChar.SelectPrevNextChar(c);
    end;
    case c of
      'B', 'T': CharHlp.DisplayNoncombatInterface;
      'A': if apprOk then CharHlp.DisplayNoncombatInterface;
    end;
    CharHlp.DisplayParty(GDVars.curChar);
  until done;
end;

begin
end.
