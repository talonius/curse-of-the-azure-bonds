{ Temples: paid healing (cures, Heal, Raise Dead, Remove Curse, Stone to Flesh), the money pool, and appraising gems and
  jewelry. }
{$O+,F+}
{$A-}
unit Temple;

interface

{ Runs a temple. The money pool starts empty; the menu offers Heal, View, Pool and Appraise, plus Take and Share while
  the pool holds money. Home and End (or G and O) make the previous or next party member current. Exit with money left
  in the pool asks whether to go back for it. }
procedure TempleMainMenu;

{ Calls the priming entry of each overlay this unit uses, so the overlay manager loads them. }
procedure PrimeTemple;

implementation

uses MenuCore, Border, ViewChar, FxEngine, TextRend, EclMenu, Magic, CharHlp, Money, EclTrace, ClassCal,
  GDConsts, GDVars, C_Keys, Types, C_Status, C_Effect, C_Ifc, C_Class, C_Stat, Crt, C_Gbvm;

procedure PrimeTemple;
begin
  Money.PrimeMoney;
  ViewChar.PrimeViewChar;
  MenuCore.PrimeMenuCore;
  CharHlp.PrimeCharHlp;
  EclMenu.PrimeEclMenu;
  EclTrace.PrimeEclTrace;
  Magic.PrimeMagic;
  FxEngine.PrimeFxEngine;
  ClassCal.PrimeClassCal;
end;

{ Reports that the current character does not need the cure and asks whether to cast it anyway.
  @param(msg The report, printed after the character's name.)
  @returns('Y' or 'N'.) }
function ConfirmCureAnyway(msg: String): Char;
begin
  CharHlp.PrintCreatureMessage(GDVars.curChar, msg, 0, False);
  ConfirmCureAnyway := MenuCore.YesNoMenu('cast cure anyway: ', LightMagenta, LightGreen, White);
  CharHlp.ClearMessageWindow;
end;

{ Offers a cure for a price and, if accepted, takes the money from the current character's coins when they cover it,
  else from the pool when it does ("Not enough money." otherwise), the remainder coming back as platinum and gold, and
  reports the cure.
  @param(spell The cure's name.)
  @param(cost The price in gold pieces.)
  @returns('Y' when it was paid for, else 'N'.) }
function ConfirmCureCost(spell: String; cost: Word): Char;
var
  c: Char;
  charGold: Word;
  pooled: LongInt;
begin
  spell := spell + ' will only cost ' + CharHlp.Uint16Str(cost) + ' gold pieces.';
  TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, True, spell);
  c := MenuCore.YesNoMenu('pay for cure ', LightMagenta, LightGreen, White);
  if c = 'Y' then begin
    charGold := ViewChar.CreatureCoinValueInGold(GDVars.curChar);
    if cost <= charGold then begin
      Dec(charGold, cost);
      Money.SetCreatureCoinsInGold(charGold);
    end else begin
      pooled := Money.CoinValueInGold(GDVars.treasureMoney);
      if cost <= pooled then begin
        Dec(pooled, cost);
        Money.SetTreasureCoinsInGold(pooled);
      end else begin
        CharHlp.PrintBottomLine('Not enough money.');
        c := 'N';
      end;
    end;
  end;
  if c = 'Y' then begin
    CharHlp.ClearMessageWindow;
    CharHlp.PrintCreatureMessage(GDVars.curChar, 'is cured.', 0, True);
  end;
  ConfirmCureCost := c;
end;

{ Cure Blindness for 1000 gold: removes Blind; asks first when the character is not blind. }
procedure CureBlindness;
var
  eff: Types.PEffect;
  { Unused in this version; see the other implementations of this routine. }
  s: String;
  c: Char;
begin
  s := '';
  c := 'Y';
  if not CharHlp.HasEffect(GDVars.curChar, C_Effect.BLIND, eff) then
    c := Temple.ConfirmCureAnyway('is not blind.');
  if c = 'Y' then begin
    c := Temple.ConfirmCureCost('Cure Blindness', 1000);
    if c = 'Y' then
      FxEngine.RemoveEffect(GDVars.curChar, C_Effect.BLIND, nil);
  end;
end;

{ Cure Disease for 1000 gold: removes the six disease effects (31, 34, 43, 44, 50, 57) with the effect lock set; asks
  first when the character has none. }
procedure CureDisease;
var
  eff: Types.PEffect;
  { Unused in this version; see the other implementations of this routine. }
  s: String;
  c: Char;
  i: Byte;
  found: Boolean;
begin
  found := False;
  s := '';
  c := 'Y';
  for i := 1 to 6 do
    if CharHlp.HasEffect(GDVars.curChar, GDConsts.cureDiseaseEffects[i], eff) then
      found := True;
  if not found then
    c := Temple.ConfirmCureAnyway('is not Diseased.');
  if c = 'Y' then begin
    c := Temple.ConfirmCureCost('Cure Disease', 1000);
    if c = 'Y' then begin
      GDVars.effectLock := 1;
      for i := 1 to 6 do
        FxEngine.RemoveEffect(GDVars.curChar, GDConsts.cureDiseaseEffects[i], nil);
      GDVars.effectLock := 0;
    end;
  end;
end;

{ Heals the current character for gold, once paid.
  @param(spell 1 Cure Light Wounds (100 gold, 1d8), 2 Cure Serious Wounds (350, 2d8 + 1), 3 Cure Critical Wounds (600,
    3d8 + 3), 4 Heal (5000: up to all but 1d4 hit points, with Blind, the disease effects and effect 68 removed and
    Intelligence and Wisdom recalculated).) }
procedure CureWounds(spell: Byte);
var
  hp: Byte;
  i: Byte;
  c: Char;
  { Unused in this version; see the other implementations of this routine. }
  hpRestored: Boolean;
begin
  case spell of
    1: begin
         c := Temple.ConfirmCureCost('Cure Light Wounds', 100);
         if c = 'Y' then begin
           hp := FxEngine.RollDice(1, 8);
           hpRestored := FxEngine.RestoreHitPoints(GDVars.curChar, hp, False);
         end;
       end;
    2: begin
         c := Temple.ConfirmCureCost('Cure Serious Wounds', 350);
         if c = 'Y' then begin
           hp := FxEngine.RollDice(2, 8) + 1;
           hpRestored := FxEngine.RestoreHitPoints(GDVars.curChar, hp, False);
         end;
       end;
    3: begin
         c := Temple.ConfirmCureCost('Cure Critical Wounds', 600);
         if c = 'Y' then begin
           hp := FxEngine.RollDice(3, 8) + 3;
           hpRestored := FxEngine.RestoreHitPoints(GDVars.curChar, hp, False);
         end;
       end;
    4: begin
         c := Temple.ConfirmCureCost('Heal', 5000);
         if c = 'Y' then begin
           hp := GDVars.curChar^.hpMax - GDVars.curChar^.hpCur - FxEngine.RollDice(1, 4);
           hpRestored := FxEngine.RestoreHitPoints(GDVars.curChar, hp, False);
           FxEngine.RemoveEffect(GDVars.curChar, C_Effect.BLIND, nil);
           for i := 1 to 6 do
             FxEngine.RemoveEffect(GDVars.curChar, GDConsts.cureDiseaseEffects[i], nil);
           FxEngine.RemoveEffect(GDVars.curChar, 68, nil);
           FxEngine.RecalcAbility(GDVars.curChar, C_Stat.INTELLIGENCE);
           FxEngine.RecalcAbility(GDVars.curChar, C_Stat.WISDOM);
         end;
       end;
  end;
end;

{ Raise Dead for 5500 gold (asks first when the character is not dead, and then changes nothing): a dead or animated
  character comes back okay at 1 hit point, with Animate Dead and poison removed under the effect lock, and loses a
  point of Constitution. At Constitution 14..16, or 14 and up for a fighter, its maximum hit points then drop by its hit
  points above the rolled ones divided by its new Constitution hit-point bonus (undivided when that bonus is 0). Note: a
  third test, the fighter level against levelAtChange, adds no case to the fighter test. }
procedure RaiseDead;
var
  { Unused in this version; see the other implementations of this routine. }
  eff: Types.PEffect;
  { Unused in this version; see the other implementations of this routine. }
  s: String;
  c: Char;
  wasDead: Boolean;
  hpLoss: Byte;
  hpBonus: Byte;
  i: ShortInt;
  cr: Types.PCreature;
begin
  cr := GDVars.curChar;
  wasDead := False;
  s := '';
  c := 'Y';
  if (cr^.status = C_Status.DEAD_STATUS) or (cr^.status = C_Status.ANIMATED) then
    wasDead := True;
  if not wasDead then
    c := Temple.ConfirmCureAnyway('is not dead.');
  if c = 'Y' then begin
    c := Temple.ConfirmCureCost('Raise Dead', 5500);
    if c = 'Y' then begin
      if wasDead then begin
        GDVars.effectLock := 1;
        FxEngine.RemoveEffect(cr, C_Effect.ANIMATE_DEAD, nil);
        FxEngine.RemoveEffect(cr, C_Effect.POISONED, nil);
        GDVars.effectLock := 0;
        cr^.hpCur := 1;
        cr^.status := C_Status.OKAY;
        cr^.enabled := 1;
        if cr^.stats[C_Stat.CONSTITUTION].current > 0 then
          Dec(cr^.stats[C_Stat.CONSTITUTION].current);
        if cr^.hpMax > cr^.hpRolled then
          hpLoss := cr^.hpMax - cr^.hpRolled
        else
          hpLoss := 0;
        hpBonus := 0;
        if cr^.stats[C_Stat.CONSTITUTION].current >= 14 then begin
          for i := 0 to 7 do
            if cr^.classLevels[i] > 0 then begin
              if i = 2 then
                Inc(hpBonus, (cr^.stats[C_Stat.CONSTITUTION].current - 14) * cr^.classLevels[i])
              else if cr^.stats[C_Stat.CONSTITUTION].current > 15 then
                Inc(hpBonus, cr^.classLevels[i] * 2)
              else
                Inc(hpBonus, cr^.classLevels[i]);
            end;
          if hpBonus > 0 then
            hpLoss := hpLoss div hpBonus;
          if (cr^.stats[C_Stat.CONSTITUTION].current < 17) or (cr^.classLevels[C_Class.FIGHTER_LEVEL] > 0)
             or (cr^.classLevels[C_Class.FIGHTER_LEVEL] > cr^.levelAtChange) then
            Dec(cr^.hpMax, hpLoss);
        end;
      end;
    end;
  end;
end;

{ Neutralize Poison for 1000 gold: removes Poisoned and both Slow Poison effects under the effect lock; asks first when
  the character is not poisoned. }
procedure NeutralizePoison;
var
  eff: Types.PEffect;
  { Unused in this version; see the other implementations of this routine. }
  s: String;
  c: Char;
  found: Boolean;
begin
  found := False;
  s := '';
  c := 'Y';
  if CharHlp.HasEffect(GDVars.curChar, C_Effect.POISONED, eff) then
    found := True;
  if not found then
    c := Temple.ConfirmCureAnyway('is not poisoned.');
  if c = 'Y' then begin
    c := Temple.ConfirmCureCost('Neutralize Poison', 1000);
    if c = 'Y' then begin
      GDVars.effectLock := 1;
      FxEngine.RemoveEffect(GDVars.curChar, C_Effect.POISONED, nil);
      FxEngine.RemoveEffect(GDVars.curChar, C_Effect.SLOW_POISON_END, nil);
      FxEngine.RemoveEffect(GDVars.curChar, C_Effect.POISON_DAMAGE, nil);
      GDVars.effectLock := 0;
    end;
  end;
end;

{ Remove Curse for 3500 gold: casts the spell (Magic.SpellRemoveCurse) on the current character; asks first when it has
  neither a cursed item nor Bestow Curse. }
procedure RemoveCurse;
var
  cursed: Boolean;
  it: Types.PItem;
  eff: Types.PEffect;
  { Unused in this version; see the other implementations of this routine. }
  s: String;
  c: Char;
begin
  s := '';
  c := 'Y';
  cursed := False;
  it := GDVars.curChar^.itemsAddr;
  while (it <> nil) and (not cursed) do begin
    if it^.cursed <> 0 then
      cursed := True;
    it := it^.next;
  end;
  if not cursed then
    if not CharHlp.HasEffect(GDVars.curChar, C_Effect.BESTOW_CURSE, eff) then
      c := Temple.ConfirmCureAnyway('is not cursed.');
  if c = 'Y' then begin
    c := Temple.ConfirmCureCost('Remove Curse', 3500);
    if c = 'Y' then begin
      GDVars.spellTargets[1] := GDVars.curChar;
      Magic.SpellRemoveCurse;
    end;
  end;
end;

{ Stone to Flesh for 2000 gold: a stoned character becomes okay at 1 hit point; asks first otherwise. }
procedure StoneToFlesh;
var
  { Unused in this version; see the other implementations of this routine. }
  eff: Types.PEffect;
  { Unused in this version; see the other implementations of this routine. }
  s: String;
  c: Char;
begin
  s := '';
  c := 'Y';
  if GDVars.curChar^.status <> C_Status.STONED then
    c := Temple.ConfirmCureAnyway('is not stoned.');
  if c = 'Y' then begin
    c := Temple.ConfirmCureCost('Stone to Flesh', 2000);
    if c = 'Y' then
      if GDVars.curChar^.status = C_Status.STONED then begin
        GDVars.curChar^.status := C_Status.OKAY;
        GDVars.curChar^.enabled := 1;
        GDVars.curChar^.hpCur := 1;
      end;
  end;
end;

{ Lists the temple's ten healing services (templeSpellNames) and runs the chosen one (Heal or Enter) for the current
  character until the player leaves. }
procedure HealMenu;
var
  list: Types.PItem;
  sel: Types.PItem;
  redraw: Boolean;
  i: Byte;
  idx: Integer;
  done: Boolean;
  s: String[40];
  c: Char;
begin
  done := False;
  list := nil;
  sel := nil;
  MenuCore.AllocStringList(10, list);
  sel := list;
  i := 1;
  while list <> nil do begin
    list^.name := GDConsts.templeSpellNames[i];
    list^.inUse := 0;
    list := list^.next;
    Inc(i);
  end;
  list := sel;
  TextRend.ClearRect(0, 24, 39, 24);
  redraw := True;
  Border.DrawRowDivider;
  repeat
    s := GDVars.curChar^.name + ', how can we help you?';
    TextRend.DisplayString(1, 1, White, 0, s);
    c := MenuCore.MenuVertical('', 'Heal Exit', LightMagenta, LightGreen, White, 2, 4, 38, 15, list, False, redraw, idx,
                               sel);
    case c of
      'H', C_Keys.ENTER:
        case idx of
          0: Temple.CureBlindness;
          1: Temple.CureDisease;
          2: Temple.CureWounds(1);
          3: Temple.CureWounds(2);
          4: Temple.CureWounds(3);
          5: Temple.CureWounds(4);
          6: Temple.NeutralizePoison;
          7: Temple.RaiseDead;
          8: Temple.RemoveCurse;
          9: Temple.StoneToFlesh;
          10: done := True;
        end;
      C_Keys.NONE: done := True;
    end;
  until done;
  MenuCore.FreeStringList(list);
  CharHlp.DisplayNoncombatInterface;
  CharHlp.DisplayParty(GDVars.curChar);
end;

procedure TempleMainMenu;
var
  c: Char;
  done: Boolean;
  ext: Boolean;
  menu: String[40];
  hasMoney: Boolean;
  hasItems: Boolean;
  ynIdx: Byte;
  apprOk: Boolean;
begin
  GDVars.ifcState := C_Ifc.SHOP_TEMPLE;
  GDVars.shopSession := GDVars.zone0^[C_Gbvm.VIEW_3D] = 0;
  CharHlp.DisplayNoncombatInterface;
  GDVars.shopSession := True;
  CharHlp.DisplayParty(GDVars.curChar);
  FillChar(GDVars.treasureMoney, SizeOf(Types.TMoney), 0);
  GDVars.treasureMoneyFlag := False;
  done := False;
  repeat
    Money.DetermineTreasure(hasMoney, hasItems);
    if hasMoney then
      menu := 'Heal View Take Pool Share Appraise Exit'
    else
      menu := 'Heal View Pool Appraise Exit';
    c := MenuCore.MenuHorizontal('', menu, LightMagenta, LightGreen, White, True, False, ext);
    case c of
      'H': if not ext then Temple.HealMenu;
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
                 'As you leave a priest says, "Excuse me but you have left some money here" ');
               TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, True,
                                             'Do you want to go back and retrieve your money?');
               ynIdx := EclMenu.MenuHorizontalCharacterSelect('', menu, LightMagenta, LightGreen, White, False, False);
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
