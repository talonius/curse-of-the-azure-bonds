{ After a battle: the result and experience, removing the monsters, the NPCs' cut, the summary, and the treasure
  menus. }
{$O+,F+,A-}
unit PostCbt;

interface

{ Runs everything after a battle, or after a COMBAT command that found treasure and no monsters. It clears the combat
  result and monstersKilled; outside the demo it works out the result (DetermineCombatResults). It then enters the loot
  state, removes the monsters and frees the party's combat records. Outside the demo it also recalculates the party's
  stats and, if the party survived or fought a duel, lets the NPCs take their cut, shows the summary, runs the treasure
  menu and frees the items left (a party that fled loses them first); if the party was destroyed it says so and sets the
  combat result to $80. Last, still outside the demo, it sets typingDelayOn and clears the script's combat modifiers,
  its no-combat-items flag and its mirror-duel flag. }
procedure PostCombat;

{ Calls the priming entry of each overlay this unit uses except CharGen, so the overlay manager loads them. }
procedure PrimePostCbt;

implementation

uses Border, FxEngine, Money, CharHlp, CharGen, MenuCore, EclMenu, ViewChar, Shop, TextRend, Magic, EclTrace, MapTiles,
  Types, GDConsts, GDVars, C_Keys, C_Status, C_Ifc, C_Class, C_Stat, Crt, C_Gbvm;

const
  { GBVM script variable (a word index into GDVars.zone1^) telling the scripts how the battle ended: $80 when the party
    lost or was destroyed, $81 when it fled, 0 otherwise. }
  COMBAT_RESULT = $7EC7;
  { GBVM script variable (a word index into GDVars.zone1^) counting the hostile and non-party creatures
    PostCombatCreatureCleanup removes that were no longer enabled. }
  MONSTERS_DEFEATED = $7EC8;
  { GBVM script variable (a word index into GDVars.zone1^): 1 keeps the hostiles' items out of the treasure. PostCombat
    clears it. }
  NO_COMBAT_ITEMS = $7EE3;
  { class value (TCreature.charClass) }
  CLASS_THIEF = 6;

procedure PrimePostCbt;
begin
  ViewChar.PrimeViewChar;
  EclMenu.PrimeEclMenu;
  Money.PrimeMoney;
  MenuCore.PrimeMenuCore;
  Shop.PrimeShop;
  CharHlp.PrimeCharHlp;
  EclTrace.PrimeEclTrace;
  Magic.PrimeMagic;
  FxEngine.PrimeFxEngine;
  MapTiles.PrimeMapTiles;
end;

{ Works out the experience share of a battle. In a duel it is 100 per level of the duelist. Otherwise it collects the
  treasure of the hostile creatures that fell (not okay or running): their money goes into the pool and, unless the
  script forbids combat items, copies of their items onto the treasure list. The share is their experience plus the
  pool's value in gold (250 per gem, 2200 per piece of jewelry) and 400 per plus of the treasure items ahead of
  lastMissileItem, divided among the party members neither disabled nor animated.
  @param(share Receives the experience each character gets.) }
procedure DetermineLootExp(var share: LongInt);
var
  p: Types.PCreature;
  i: ShortInt;
  expTotal: LongInt;
  q: Types.PItem;
  it: Types.PItem;
  cnt: Byte;
begin
  if GDVars.duelFlag then
    share := GDVars.curChar^.levelHighest * 100
  else begin
    expTotal := 0;
    p := GDVars.partyHead;
    cnt := 0;
    while p <> nil do begin
      it := p^.itemsAddr;
      if (p^.hostile = 1) and (p^.status <> C_Status.OKAY) and (p^.status <> C_Status.RUNNING) then begin
        GDVars.monstersKilled := True;
        for i := 0 to 6 do
          Inc(GDVars.treasureMoney[i], p^.coins[i]);
        expTotal := expTotal + p^.xpAward + p^.xpBonusPerHp * p^.hpRolled;
        if GDVars.zone1^[PostCbt.NO_COMBAT_ITEMS] <> 1 then
          while it <> nil do begin
            Inc(cnt);
            if GDVars.treasureItems = nil then begin
              GetMem(GDVars.treasureItems, SizeOf(Types.TItem));
              CharHlp.PrintItemString(p, Pointer(it), 0, 0, False, False);
              GDVars.treasureItems^ := it^;
              GDVars.treasureItems^.equipped := 0;
              GDVars.treasureItems^.next := nil;
            end else begin
              q := GDVars.treasureItems;
              GetMem(GDVars.treasureItems, SizeOf(Types.TItem));
              CharHlp.PrintItemString(p, Pointer(it), 0, 0, False, False);
              GDVars.treasureItems^ := it^;
              GDVars.treasureItems^.equipped := 0;
              GDVars.treasureItems^.next := q;
            end;
            it := it^.next;
          end;
      end;
      p := p^.next;
    end;
    Inc(expTotal, GDVars.treasureMoney[0] div 200);
    Inc(expTotal, GDVars.treasureMoney[1] div 20);
    Inc(expTotal, GDVars.treasureMoney[2] div 2);
    Inc(expTotal, GDVars.treasureMoney[3]);
    Inc(expTotal, GDVars.treasureMoney[4] * 5);
    Inc(expTotal, GDVars.treasureMoney[5] * 250);
    Inc(expTotal, GDVars.treasureMoney[6] * 2200);
    q := GDVars.treasureItems;
    while (q <> nil) and (q <> GDVars.lastMissileItem) do begin
      if q^.plus > 0 then
        Inc(expTotal, q^.plus * 400);
      q := q^.next;
    end;
    share := expTotal div (GDVars.zone1^[C_Gbvm.PARTY_SIZE] - GDVars.treasureCreatureCount);
  end;
end;

{ Gives experience to each enabled creature on the creature list that is not animated: single-class characters with
  their prime requisites above 15 get 10% more, double-class characters half and triple-class ones a third.
  @param(xp The experience share.) }
procedure AwardExperience(xp: LongInt);
var
  p: Types.PCreature;
  share: LongInt;
begin
  p := GDVars.partyHead;
  while p <> nil do begin
    if (p^.enabled <> 0) and (p^.status <> C_Status.ANIMATED) then begin
      share := xp;
      case p^.charClass of
        C_Class.CLERIC: if p^.stats[C_Stat.WISDOM].current > 15 then share := xp div 10 + xp;
        C_Class.FIGHTER: if p^.stats[C_Stat.STRENGTH].current > 15 then share := xp div 10 + xp;
        C_Class.PALADIN: if (p^.stats[C_Stat.STRENGTH].current > 15) and
          (p^.stats[C_Stat.WISDOM].current > 15) then share := xp div 10 + xp;
        C_Class.RANGER:
          if (p^.stats[C_Stat.STRENGTH].current > 15) and (p^.stats[C_Stat.INTELLIGENCE].current > 15) and
              (p^.stats[C_Stat.WISDOM].current > 15) then share := xp div 10 + xp;
        C_Class.MAGE: if p^.stats[C_Stat.INTELLIGENCE].current > 15 then share := xp div 10 + xp;
        PostCbt.CLASS_THIEF: if p^.stats[C_Stat.DEXTERITY].current > 15 then share := xp div 10 + xp;
        C_Class.CLERIC_FIGHTER, C_Class.CLERIC_RANGER..C_Class.FIGHTER_THIEF,
          C_Class.MAGE_THIEF: share := xp div 2;
        C_Class.CLERIC_FIGHTER_MAGE, C_Class.FIGHTER_MAGE_THIEF: share := xp div 3;
      end;
      Inc(p^.experience, share);
    end;
    p := p^.next;
  end;
end;

{ Works out how the battle ended. The party fled when a member ran, and was defeated unless it fought a duel, or a
  mirror duel with anyone enabled, unconscious, running or dying, or a member that is neither hostile nor an NPC is
  still running, animated or okay. A member still okay or animated wins the fight, which cancels the flight. The
  post-combat effects are stripped from the party, and a win awards experience (DetermineLootExp, AwardExperience). A
  party that did not flee recovers: members that ran return, dying ones fall unconscious, unconscious ones with hit
  points stand up, and in a mirror duel the dying and the unconscious stand up with 1 hit point. A party that fled keeps
  those that ran, sets the combat result to $81 and removes the rest. A defeated party is removed. In a duel while the
  demo runs it instead awards experience once for each enabled, okay, non-hostile creature, re-enables the okay and
  animated ones and turns the dying unconscious; PostCombat never calls it during the demo, so that branch is
  unreachable. }
procedure DetermineCombatResults;
var
  p: Types.PCreature;
  { Set at the first creature that is not a party member, ending the removal loop. }
  reachedMonsters: Boolean;
  { Index into the post-combat removal-effect table. }
  fxIdx: Byte;
  { someone is still alive (enabled, unconscious, running or dying) }
  anyAlive: Boolean;
begin
  GDVars.treasureCreatureCount := 0;
  GDVars.partyDefeated := True;
  GDVars.partyFled := False;
  p := GDVars.partyHead;
  while (p <> nil) and (p^.combatAddr^.notPcNpc <> 1) do begin
    if p^.status = C_Status.RUNNING then
      GDVars.partyFled := True;
    p := p^.next;
  end;
  p := GDVars.partyHead;
  anyAlive := False;
  while (p <> nil) and (not anyAlive) do begin
    if (p^.enabled <> 0) or (p^.status = C_Status.UNCONSCIOUS) or (p^.status = C_Status.RUNNING) or
        (p^.status = C_Status.DYING) then
      anyAlive := True;
    p := p^.next;
  end;
  if GDVars.duelFlag or ((GDVars.zone1^[C_Gbvm.MIRROR_DUEL] <> 0) and anyAlive) then
    GDVars.partyDefeated := False;
  GDVars.combatWon := 0;
  p := GDVars.partyHead;
  if (not GDVars.duelFlag) or (not GDVars.demoMode) then begin
    while (p <> nil) and (p^.combatAddr^.notPcNpc <> 1) do begin
      if ((p^.status = C_Status.RUNNING) or (p^.status = C_Status.ANIMATED) or
          (p^.status = C_Status.OKAY)) and
          (p^.hostile = 0) and (p^.npc < $80) then
        GDVars.partyDefeated := False;
      if (p^.status = C_Status.ANIMATED) or (p^.status = C_Status.OKAY) then begin
        GDVars.combatWon := 1;
        GDVars.partyFled := False;
      end;
      if (p^.enabled = 0) or (p^.status = C_Status.ANIMATED) then
        Inc(GDVars.treasureCreatureCount);
      for fxIdx := 1 to 19 do
        FxEngine.RemoveEffect(p, GDConsts.postCombatRemovalEffects[fxIdx], nil);
      p := p^.next;
    end;
    if GDVars.combatWon <> 0 then begin
      PostCbt.DetermineLootExp(GDVars.experienceShare);
      PostCbt.AwardExperience(GDVars.experienceShare);
    end;
    p := GDVars.partyHead;
    if not GDVars.partyDefeated then begin
      while (p <> nil) and (p^.combatAddr^.notPcNpc <> 1) do begin
        if not GDVars.partyFled then begin
          case p^.status of
            C_Status.RUNNING: begin
                 p^.status := C_Status.OKAY;
                 p^.enabled := 1;
               end;
            C_Status.DYING: if GDVars.zone1^[C_Gbvm.MIRROR_DUEL] <> 0 then begin
                 p^.status := C_Status.OKAY;
                 p^.enabled := 1;
                 p^.hpCur := 1;
               end else
                 p^.status := C_Status.UNCONSCIOUS;
            C_Status.UNCONSCIOUS: if p^.hpCur > 0 then begin
                 p^.status := C_Status.OKAY;
                 p^.enabled := 1;
               end else if GDVars.zone1^[C_Gbvm.MIRROR_DUEL] <> 0 then begin
                 p^.status := C_Status.OKAY;
                 p^.enabled := 1;
                 p^.hpCur := 1;
               end;
          end;
          p := p^.next;
        end else begin
          GDVars.zone1^[PostCbt.COMBAT_RESULT] := $81;
          if p^.status = C_Status.RUNNING then begin
            p^.status := C_Status.OKAY;
            p^.enabled := 1;
            p := p^.next;
          end else begin
            GDVars.curChar := p;
            p := p^.next;
            CharGen.RemoveCreature(False, True);
          end;
        end;
      end;
    end else begin
      p := GDVars.partyHead;
      reachedMonsters := False;
      while (p <> nil) and (not reachedMonsters) do begin
        if p^.combatAddr^.notPcNpc <> 1 then begin
          GDVars.curChar := p;
          CharGen.RemoveCreature(False, True);
        end else
          reachedMonsters := True;
        p := p^.next;
      end;
      GDVars.zone1^[C_Gbvm.PARTY_SIZE] := 0;
    end;
  end else begin
    p := GDVars.partyHead;
    while p <> nil do begin
      if (p^.enabled = 1) and (p^.status = C_Status.OKAY) and (p^.hostile <> 1) then begin
        GDVars.combatWon := 1;
        PostCbt.DetermineLootExp(GDVars.experienceShare);
        PostCbt.AwardExperience(GDVars.experienceShare);
      end;
      p := p^.next;
    end;
    p := GDVars.partyHead;
    while p <> nil do begin
      if (p^.status = C_Status.OKAY) or (p^.status = C_Status.ANIMATED) then
        p^.enabled := 1;
      if p^.status = C_Status.DYING then
        p^.status := C_Status.UNCONSCIOUS;
      p := p^.next;
    end;
  end;
end;

{ Shows the outcome (the party fled and lost the treasure, lost the fight in a duel or mirror duel, won, or found
  treasure without a fight) and the experience each character, or the duelist, receives, then waits for Enter. A lost
  fight sets the combat result to $80.
  @param(xp The experience share; a fled or lost fight shows 0.) }
procedure PostCombatSummary(xp: LongInt);
var
  numStr: String[10];
  msg: String;
  { Unused in this version; see the other implementations of this routine. }
  c: Char;
  { always empty }
  query: String[1];
  ext: Boolean;
  p: Types.PItem;
  q: Types.PItem;
begin
  query[0] := #0;
  Border.DrawWindowFrame;
  if GDVars.monstersKilled or GDVars.duelFlag then begin
    if GDVars.partyFled then begin
      TextRend.DisplayString(1, 3, LightGreen, 0, 'The party has fled.');
      xp := 0;
      p := GDVars.treasureItems;
      while p <> nil do begin
        q := p^.next;
        FreeMem(p, SizeOf(Types.TItem));
        p := q;
      end;
      FillChar(GDVars.treasureMoney, SizeOf(GDVars.treasureMoney), 0);
    end else if (GDVars.duelFlag and (GDVars.combatWon = 0)) or
      ((GDVars.combatWon = 0) and (GDVars.zone1^[C_Gbvm.MIRROR_DUEL] <> 0)) then begin
      GDVars.zone1^[PostCbt.COMBAT_RESULT] := $80;
      TextRend.DisplayString(1, 3, LightGreen, 0, 'You have lost the fight.');
      xp := 0;
    end else begin
      if GDVars.duelFlag then
        TextRend.DisplayString(1, 3, LightGreen, 0, 'You have won the duel.')
      else
        TextRend.DisplayString(1, 3, LightGreen, 0, 'The party has won.');
    end;
  end else
    TextRend.DisplayString(1, 3, LightGreen, 0, 'The party has found Treasure!');
  Str(xp, numStr);
  if GDVars.duelFlag then
    msg := 'The duelist receives ' + numStr
  else
    msg := 'Each character receives ' + numStr;
  TextRend.DisplayString(1, 5, LightGreen, 0, msg);
  TextRend.DisplayString(1, 7, LightGreen, 0, 'experience points.');
  c := MenuCore.MenuHorizontal(query, 'press <enter>/<return> to continue', White, White, White, True, False, ext);
end;

{ Lists the treasure items, with their names refreshed, in a vertical menu with Take and Exit.
  @param(key Receives the command key, or #0 for Escape or Exit.)
  @param(itemToTake Receives the chosen item, or nil.)
  @param(cursor Receives the chosen item, or nil.)
  @param(idx The highlighted item's position, kept between calls.) }
procedure LootTakeItemSelection(var key: Char; var itemToTake: Types.PItem; var cursor: Types.PItem;
                                var idx: Integer);
var
  head: Types.PItem;
  { Unused in this version; see the other implementations of this routine. }
  tmp: String[16];
  { Unused in this version; see the other implementations of this routine. }
  lenv: Byte;
  { Unused in this version; see the other implementations of this routine. }
  i: Byte;
  redraw: Boolean;
  p: Types.PItem;
begin
  redraw := True;
  Border.DrawWindowFrame;
  p := GDVars.treasureItems;
  while p <> nil do begin
    CharHlp.PrintItemString(nil, Pointer(p), 0, 0, False, False);
    p := p^.next;
  end;
  head := GDVars.treasureItems;
  key := MenuCore.MenuVertical('Items: ', 'Take', LightMagenta, LightGreen, White, 1, 1, 38, 22, head, True, redraw,
                               idx, cursor);
  itemToTake := cursor;
end;

{ Lets the current character take treasure items one at a time until it leaves or the list is empty; a taken item is
  copied to the character and freed from the list. }
procedure LootTakeItemMenu;
var
  itemToTake: Types.PItem;
  p: Types.PItem;
  c: Char;
  done: Boolean;
  cursor: Types.PItem;
  idx: Integer;
  failed: Boolean;
begin
  itemToTake := nil;
  cursor := GDVars.treasureItems;
  idx := 0;
  repeat
    PostCbt.LootTakeItemSelection(c, itemToTake, cursor, idx);
    if (c <> 'T') and (c <> C_Keys.ENTER) then
      done := True
    else begin
      done := False;
      Shop.GiveItemCopyToCreature(itemToTake, failed);
      if not failed then begin
        p := GDVars.treasureItems;
        if p = itemToTake then
          GDVars.treasureItems := itemToTake^.next
        else begin
          while p^.next <> itemToTake do
            p := p^.next;
          p^.next := itemToTake^.next;
        end;
        itemToTake^.next := nil;
        if itemToTake <> nil then
          FreeMem(itemToTake, SizeOf(Types.TItem));
        if GDVars.treasureItems = nil then
          done := True;
      end;
    end;
  until done;
  CharHlp.DisplayNoncombatInterface;
end;

{ Takes treasure: with both money and items, a Money/Items/Exit menu runs until one kind runs out, and Home and End
  change the current character; otherwise it goes straight to the money or the item menu.
  @param(hasMoney True when the pool holds money; kept current while the Money/Items menu runs.)
  @param(hasItems True when treasure items are left; kept current while the Money/Items menu runs.) }
procedure LootTakeMenu(var hasMoney, hasItems: Boolean);
var
  c: Char;
  done: Boolean;
  ext: Boolean;
begin
  done := False;
  if hasMoney then begin
    if hasItems then begin
      repeat
        c := MenuCore.MenuHorizontal('Take: ', 'Money Items Exit', LightMagenta, LightGreen, White, True, True, ext);
        case c of
          'M': begin
                 Money.TakeMoneyMenu;
                 CharHlp.DisplayNoncombatInterface;
               end;
          'I': PostCbt.LootTakeItemMenu;
          'E', C_Keys.NONE: done := True;
          C_Keys.HOME: ViewChar.SelectPrevNextChar(c);
          C_Keys.END_KEY: ViewChar.SelectPrevNextChar(c);
        end;
        CharHlp.DisplayParty(Types.PCreature(GDVars.curChar));
        Money.DetermineTreasure(hasMoney, hasItems);
        if not hasMoney or not hasItems then
          done := True;
      until done;
    end else begin
      Money.TakeMoneyMenu;
      CharHlp.DisplayNoncombatInterface;
    end;
  end else
    PostCbt.LootTakeItemMenu;
end;

{ Runs the treasure menu after a battle: View and Pool, Take while treasure is left, Share with money, and Detect when
  there are items and the current character is enabled and has a detection spell (5, 11 or 77) memorized. Leaving with
  treasure left asks whether to go back for it; Home and End change the current character. }
procedure LootMenu;
var
  hasMoney: Boolean;
  hasItems: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  canDetect: Byte;
  menu: String;
  c: Char;
  done: Boolean;
  ext: Boolean;
  { always empty }
  query: String[1];
  ynIdx: Byte;
  i: Byte;
  detectSpell: Byte;
  hasDetect: Byte;
  tail: String[13];
begin
  query[0] := #0;
  done := False;
  CharHlp.DisplayNoncombatInterface;
  hasMoney := False;
  repeat
    Money.DetermineTreasure(hasMoney, hasItems);
    menu := 'View Pool Exit';
    i := 0;
    tail := ' Exit';
    hasDetect := 0;
    if hasItems then
      while (i <= 83) and (hasDetect = 0) do begin
        if ((GDVars.curChar^.memorizedSpells[i] = 5) or (GDVars.curChar^.memorizedSpells[i] = 11) or
            (GDVars.curChar^.memorizedSpells[i] = 77)) and (GDVars.curChar^.enabled <> 0) then begin
          hasDetect := 1;
          detectSpell := GDVars.curChar^.memorizedSpells[i];
        end;
        Inc(i);
      end;
    if hasDetect <> 0 then
      tail := ' Detect Exit';
    if hasMoney then
      menu := 'View Take Pool Share' + tail
    else if hasItems then
      menu := 'View Take Pool' + tail;
    c := MenuCore.MenuHorizontal(query, menu, LightMagenta, LightGreen, White, True, True, ext);
    case c of
      'V': ViewChar.ViewCharMenu(ext);
      'T': PostCbt.LootTakeMenu(hasMoney, hasItems);
      'P': if not ext then Money.PoolMoney;
      'S': Money.ShareMoney;
      'D': Magic.CastSpell(detectSpell, False, False, ext);
      'E', C_Keys.NONE: begin
                 Money.DetermineTreasure(hasMoney, hasItems);
                 if hasMoney or hasItems then begin
                   menu := '~Yes ~No';
                   TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, True, 'There is still treasure left.  ');
                   TextRend.DisplayMessageWindow(1, 17, 38, 22, White, 0, False,
                                                 'Do you want to go back and claim your treasure?');
                   ynIdx := EclMenu.MenuHorizontalCharacterSelect(query, menu, LightMagenta, LightGreen, White, False,
                                                                  False);
                   if ynIdx = 1 then
                     done := True
                   else
                     TextRend.ClearRect(1, 17, 38, 22);
                 end else
                   done := True;
               end;
      C_Keys.HOME: begin
             ViewChar.SelectPrevNextChar(c);
             CharHlp.DisplayParty(Types.PCreature(GDVars.curChar));
           end;
      C_Keys.END_KEY: begin
             ViewChar.SelectPrevNextChar(c);
             CharHlp.DisplayParty(Types.PCreature(GDVars.curChar));
           end;
    end;
  until done;
end;

{ Removes the hostile and non-party creatures from the creature list, setting monstersKilled when it finds any and
  counting those not enabled in the script's monsters-defeated count, frees the party members' combat records and makes
  the first creature on the list current. }
procedure PostCombatCreatureCleanup;
var
  p: Types.PCreature;
  next: Types.PCreature;
begin
  GDVars.zone1^[PostCbt.MONSTERS_DEFEATED] := 0;
  p := GDVars.partyHead;
  while p <> nil do begin
    if (p^.combatAddr^.notPcNpc = 1) or (p^.hostile = 1) then begin
      GDVars.monstersKilled := True;
      if p^.enabled <> 1 then
        Inc(GDVars.zone1^[PostCbt.MONSTERS_DEFEATED]);
      next := p^.next;
      GDVars.curChar := p;
      CharGen.RemoveCreature(p^.combatAddr^.notPcNpc = 1, True);
      p := next;
    end else begin
      if p^.combatAddr <> nil then begin
        FreeMem(p^.combatAddr, SizeOf(p^.combatAddr^));
        p^.combatAddr := nil;
      end;
      p := p^.next;
    end;
  end;
  GDVars.curChar := GDVars.partyHead;
end;

{ NPCs in the party that are okay take their cut of each money type: an NPC counts as (modified and 7) shares, everyone
  else as one, and the NPCs' shares leave the pool. When any money was taken, each such NPC with modified above 0 is
  then shown taking and hiding its share. Note: each share is truncated to a byte before the NPCs' part leaves the
  pool. }
procedure NpcTreasureShare;
var
  p: Types.PCreature;
  npcShares: Byte;
  total: Byte;
  { a LongInt share truncated to a byte }
  cut: Byte;
  row: Byte;
  i: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  msg: String[8];
  took: Boolean;
  ext: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  c: Char;
begin
  took := False;
  p := GDVars.partyHead;
  npcShares := 0;
  total := 0;
  while p <> nil do begin
    if (p^.npc > $7F) and (p^.status = C_Status.OKAY) then begin
      Inc(npcShares, p^.modified and 7);
      Inc(total, p^.modified and 7);
    end else
      Inc(total);
    p := p^.next;
  end;
  if npcShares > 0 then
    for i := 0 to 6 do
      if GDVars.treasureMoney[i] > 0 then begin
        cut := GDVars.treasureMoney[i] div total;
        Dec(GDVars.treasureMoney[i], npcShares * cut);
        took := True;
      end;
  if took then begin
    Border.DrawWindowFrame;
    p := GDVars.partyHead;
    row := 0;
    while p <> nil do begin
      if (p^.npc > $7F) and (p^.status = C_Status.OKAY) and (p^.modified > 0) then begin
        if p^.gender = 0 then
          TextRend.DisplayMessageWindow(5, row + 5, 34, 22, LightGreen, 0, True,
                                        p^.name + ' takes and hides ' + 'his' + ' share.')
        else
          TextRend.DisplayMessageWindow(5, row + 5, 34, 22, LightGreen, 0, True,
                                        p^.name + ' takes and hides ' + 'her' + ' share.');
        Inc(row, 2);
      end;
      p := p^.next;
    end;
    c := MenuCore.MenuHorizontal('', 'press <enter>/<return> to continue', White, White, White, True, False, ext);
  end;
end;

procedure PostCombat;
var
  p: Types.PItem;
  q: Types.PItem;
  cp: Types.PCreature;
begin
  GDVars.zone1^[PostCbt.COMBAT_RESULT] := 0;
  GDVars.monstersKilled := False;
  if not GDVars.demoMode then
    PostCbt.DetermineCombatResults;
  GDVars.ifcState := C_Ifc.LOOT;
  PostCbt.PostCombatCreatureCleanup;
  if not GDVars.demoMode then begin
    cp := GDVars.partyHead;
    while cp <> nil do begin
      CharHlp.RecalcStats(cp);
      cp := cp^.next;
    end;
    if (not GDVars.partyDefeated) or GDVars.duelFlag then begin
      if GDVars.partyFled then begin
        p := GDVars.treasureItems;
        while p <> nil do begin
          q := p;
          p := p^.next;
          FreeMem(q, SizeOf(Types.TItem));
        end;
        GDVars.treasureItems := nil;
      end;
      if not GDVars.demoMode then begin
        PostCbt.NpcTreasureShare;
        PostCbt.PostCombatSummary(GDVars.experienceShare);
        PostCbt.LootMenu;
      end;
      p := GDVars.treasureItems;
      while p <> nil do begin
        q := p;
        p := p^.next;
        FreeMem(q, SizeOf(Types.TItem));
      end;
      GDVars.treasureItems := nil;
    end else begin
      GDVars.zone1^[PostCbt.COMBAT_RESULT] := $80;
      Border.DrawWindowFrame;
      GDVars.curCol := 2;
      GDVars.curRow := 6;
      TextRend.DisplayMessageWindow(2, 5, 37, 22, LightGreen, 0, True,
                                    'The monsters rejoice for the party has been destroyed');
      TextRend.DisplayAndPause(LightMagenta, 0, 'Press any key to continue');
    end;
    GDVars.typingDelayOn := True;
    GDVars.zone1^[C_Gbvm.MONSTER_THAC0_MODIFIER] := 0;
    GDVars.zone1^[C_Gbvm.PARTY_THAC0_MODIFIER] := 0;
    GDVars.zone1^[C_Gbvm.PARTY_MOVE_MODIFIER] := 0;
    GDVars.zone1^[PostCbt.NO_COMBAT_ITEMS] := 0;
    GDVars.zone1^[C_Gbvm.MIRROR_DUEL] := 0;
  end;
end;

begin
end.
