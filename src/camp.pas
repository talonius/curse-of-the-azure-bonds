{ Camp menus for spell preparation, resting, healing, party order and game settings. Also provides the noncombat Cast
  menu. }
{$O+,F+}
unit Camp;

interface

uses Types, Magic, ViewChar, MenuCore, TextRend, GameTime, CharHlp, Border, SaveLoad, CharGen, GameIo, FxEngine,
  Portrait, MapView, EclTrace, GDConsts, GDVars, C_Keys, C_Status, C_Effect, C_Ifc, C_Gbvm,
  C_Spell, Crt;

{ Runs the Camp menu (Save, which then offers to quit to DOS, View, Magic, Rest, Fix and Alter; extended keys change the
  current character) until Exit, Escape or an interrupted rest. On entry, saves the interface state, copies the portrait
  archive name and picture ID, clears the healing ticks, the rest clock and every pending memorize or scribe request,
  and announces 'The party makes camp...'. On exit, clears the pending requests and the cast target again, restores the
  interface state, and reloads the portrait animation from the copied archive name when it starts with PIC.
  @param(interrupted Set True when a rest is interrupted.) }
procedure CampMainMenu(var interrupted: Boolean);

{ Runs the noncombat Cast menu for the current character until no spell is picked, saying 'has no spells memorized' when
  the list is empty. Clears the remembered cast target on entry, and redraws the noncombat interface afterwards if a
  spell was cast or the spell list was not empty. }
procedure NoncombatCastMenu;

{ Calls the priming entries of EclTrace, Magic, GameTime, CharHlp, SaveLoad, MenuCore, ViewChar, MapView and FxEngine,
  so the overlay manager loads them; CharGen and Portrait, which this unit also uses, are not primed. }
procedure PrimeCamp;

implementation

const
  { Message row for CharHlp.PrintCreatureMessage. }
  MESSAGE_ROW = 10;

  { CanDoSpellActivity's activity code. }
  ACTIVITY_CAST = 1;
  ACTIVITY_MEMORIZE = 2;
  ACTIVITY_SCRIBE = 3;

procedure PrimeCamp;
begin
  EclTrace.PrimeEclTrace;
  Magic.PrimeMagic;
  GameTime.PrimeGameTime;
  CharHlp.PrimeCharHlp;
  SaveLoad.PrimeSaveLoad;
  MenuCore.PrimeMenuCore;
  ViewChar.PrimeViewChar;
  MapView.PrimeMapView;
  FxEngine.PrimeFxEngine;
end;

{ Works out a character's spell preparation time: 15 minutes per level of each pending spell, plus four hours when any
  spell is pending, or six when any pending spell is level 3 or higher. Pending memorizing and pending scribing
  (readable items only) both count. Stores the base hours (0, 4 or 6) in the character's record.
  @param(creature The character.)
  @returns(The preparation time in minutes.) }
function CampSpellPrepTime(creature: Types.PCreature): Word;
var
  maxMem: Byte;
  maxScr: Byte;
  cntMem: Byte;
  cntScr: Byte;
  p: Types.PItem;
  i: Byte;
  lvl: Byte;
  base: Byte;
begin
  maxMem := 0;
  maxScr := 0;
  cntMem := 0;
  cntScr := 0;
  for i := 0 to 83 do
    if creature^.memorizedSpells[i] > C_Spell.ID_MASK then begin
      lvl := GDConsts.spellProperties[creature^.memorizedSpells[i] and C_Spell.ID_MASK].level;
      if lvl > maxMem then maxMem := lvl;
      Inc(cntMem, lvl);
    end;
  p := creature^.itemsAddr;
  while p <> nil do begin
    if Magic.ItemReadable(p) then
      for i := 1 to 3 do
        if p^.spells[i] > C_Spell.ID_MASK then begin
          lvl := GDConsts.spellProperties[p^.spells[i] and C_Spell.ID_MASK].level;
          if lvl > maxScr then maxScr := lvl;
          Inc(cntScr, lvl);
        end;
    p := p^.next;
  end;
  base := 0;
  if (cntMem > 0) or (cntScr > 0) then
    base := 4;
  if (maxMem > 2) or (maxScr > 2) then
    base := 6;
  creature^.spellPrep := base;
  CampSpellPrepTime := base * 60 + cntMem * 15 + cntScr * 15;
end;

{ Removes every pending memorize request of a character (zeroing the slot, unlike ResetScribe) and clears spellPrep.
  @param(creature The character.) }
procedure ResetMemorize(creature: Types.PCreature);
var
  i: Byte;
begin
  for i := 0 to 83 do
    if creature^.memorizedSpells[i] > C_Spell.ID_MASK then
      creature^.memorizedSpells[i] := 0;
  creature^.spellPrep := 0;
end;

{ Clears the pending flag of every scroll spell on a character's readable items.
  @param(creature The character.) }
procedure ResetScribe(creature: Types.PCreature);
var
  i: Byte;
  p: Types.PItem;
begin
  p := creature^.itemsAddr;
  while p <> nil do begin
    if Magic.ItemReadable(p) then
      for i := 1 to 3 do
        p^.spells[i] := p^.spells[i] and C_Spell.ID_MASK;
    p := p^.next;
  end;
end;

{ Clears the pending memorizing and scribing of each party member. }
procedure ResetPartySpellActivities;
var
  character: Types.PCreature;
begin
  character := GDVars.partyHead;
  while character <> nil do begin
    Camp.ResetMemorize(character);
    Camp.ResetScribe(character);
    character := character^.next;
  end;
end;

{ Counts the current character's free spell slots at a class and level: its allowance less the spells memorized or
  pending there. Note: the result is a Byte and wraps when more are memorized than allowed, as after a level drain.
  @param(spellLevel The spell level.)
  @param(spellClass The spell class.)
  @returns(The free slots.) }
function SpellSlotsRemaining(spellLevel, spellClass: ShortInt): Byte;
var
  count: Byte;
  i: Byte;
begin
  count := 0;
  for i := 0 to 83 do
    if GDVars.curChar^.memorizedSpells[i] > 0 then
      if (GDConsts.spellProperties[GDVars.curChar^.memorizedSpells[i] and C_Spell.ID_MASK].level = spellLevel) and
          (GDConsts.spellProperties[GDVars.curChar^.memorizedSpells[i] and C_Spell.ID_MASK].castClass =
           spellClass) then
        Inc(count);
  SpellSlotsRemaining := GDVars.curChar^.spellSlots[spellClass, spellLevel] - count;
end;

{ Checks whether the current character can cast, memorize or scribe. The area's anti-magic flag blocks casting; animated
  or disabled characters can do none of them. On failure, prints the character's name and the reason.
  @param(activity The activity: cast, memorize or scribe.)
  @returns(True when the character can do it.) }
function CanDoSpellActivity(activity: Byte): Boolean;
var
  message: Types.TStr40;
begin
  message := '';
  if (activity = Camp.ACTIVITY_CAST) and (GDVars.zone0^[C_Gbvm.ANTI_MAGIC] > 0) then
    message := 'cannot cast spells in this area'
  else if (GDVars.curChar^.status = C_Status.ANIMATED) or (GDVars.curChar^.enabled = 0) then begin
    message := 'is in no condition to ';
    case activity of
      Camp.ACTIVITY_CAST: message := message + 'cast any spells';
      Camp.ACTIVITY_MEMORIZE: message := message + 'memorize spells';
      Camp.ACTIVITY_SCRIBE: message := message + 'scribe any scrolls';
    end;
  end;
  if message = '' then
    CanDoSpellActivity := True
  else begin
    CanDoSpellActivity := False;
    CharHlp.PrintCreatureMessage(Types.PCreature(GDVars.curChar), message, Camp.MESSAGE_ROW, True);
  end;
end;

procedure NoncombatCastMenu;
var
  menuIndex: Integer;
  notEmpty: Boolean;
  needsRedraw: Boolean;
  castSelected: Boolean;
  spellId: Byte;
begin
  needsRedraw := False;
  menuIndex := -1;
  GDVars.lastSpellTarget := nil;
  GDVars.menuChoice := 1;
  if Camp.CanDoSpellActivity(Camp.ACTIVITY_CAST) then begin
    repeat
      spellId := ViewChar.SpellMenu(0, 1, menuIndex, notEmpty);
      if spellId <> 0 then begin
        needsRedraw := True;
        Border.ClearBox(1, 17, 38, 22);
        Magic.CastSpell(spellId, False, True, castSelected);
      end else begin
        if notEmpty then
          needsRedraw := True
        else
          CharHlp.PrintCreatureMessage(Types.PCreature(GDVars.curChar), 'has no spells memorized', Camp.MESSAGE_ROW,
                                       True);
      end;
    until spellId = 0;
  end;
  if needsRedraw then
    CharHlp.DisplayNoncombatInterface;
end;

{ Shows the current character's remaining spell slots for each class (cleric, druid, magic-user) and level 1..5. A level
  with no allowance is blank; a full level shows zero.
  @returns(True when the character has any spell allowance, even if every slot is taken.) }
function DisplaySpellSlots: Boolean;
var
  s: Types.TStr40;
  slotStr: array[1..5, 0..2] of Types.TStr2;
  canDo: array[0..2] of Byte;
  typ: ShortInt;
  lvl: ShortInt;
  col: Byte;
  row: Byte;
  any: Boolean;
begin
  any := False;
  for typ := 0 to 2 do begin
    canDo[typ] := 0;
    for lvl := 1 to 5 do begin
      slotStr[lvl, typ] := CharHlp.Uint8Str(Camp.SpellSlotsRemaining(lvl, typ));
      if GDVars.curChar^.spellSlots[typ, lvl] = 0 then
        slotStr[lvl, typ] := ' '
      else begin
        canDo[typ] := 1;
        any := True;
      end;
    end;
  end;
  if any then begin
    CharHlp.PrintCreatureMessage(Types.PCreature(GDVars.curChar), 'can memorize:', Camp.MESSAGE_ROW, False);
    row := 3;
    for typ := 0 to 2 do begin
      if canDo[typ] <> 0 then begin
        case typ of
          C_Spell.CLERIC_LIST: s := '    Cleric Spells:';
          C_Spell.DRUID_LIST: s := '     Druid Spells:';
          C_Spell.MAGE_LIST: s := 'Magic-User Spells:';
        end;
        TextRend.DisplayString(1, row + 17, LightGreen, 0, s);
        col := 19;
        for lvl := 1 to 5 do begin
          TextRend.DisplayString(col + 1, row + 17, LightGreen, 0, slotStr[lvl, typ]);
          Inc(col, 3);
        end;
        Inc(row);
      end;
    end;
  end;
  DisplaySpellSlots := any;
end;

{ Rests the party for the longest spell preparation time among its members, then clears the rest time and redraws the
  position and time.
  @param(interrupted Receives True when the rest was interrupted.) }
procedure RestForSpellPrep(var interrupted: Boolean);
var
  character: Types.PCreature;
  maxPrepMinutes: Word;
  prepMinutes: Word;
  { Unused in this version; see the other implementations of this routine. }
  hours: Word;
begin
  maxPrepMinutes := 0;
  character := GDVars.partyHead;
  while character <> nil do begin
    prepMinutes := Camp.CampSpellPrepTime(character);
    if maxPrepMinutes < prepMinutes then maxPrepMinutes := prepMinutes;
    character := character^.next;
  end;
  GDVars.restTime[3] := maxPrepMinutes div 60;
  GDVars.restTime[2] := (maxPrepMinutes - 60 * GDVars.restTime[3]) div 10;
  GDVars.restTime[1] := maxPrepMinutes mod 10;
  interrupted := GameTime.CampRest(True);
  FillChar(GDVars.restTime, SizeOf(GDVars.restTime), 0);
  CharHlp.PrintPositionAndTime;
end;

{ Sorts the current character's memorized-spell slots by spell ID, keeping each pending flag with its spell. Empty slots
  sort to the front. }
procedure SortMemorizedSpells;
var
  i: Byte;
  j: Byte;
  tmp: Byte;
begin
  for i := 0 to 82 do
    for j := i to 83 do
      if (GDVars.curChar^.memorizedSpells[i] and C_Spell.ID_MASK) >
          (GDVars.curChar^.memorizedSpells[j] and C_Spell.ID_MASK) then begin
        tmp := GDVars.curChar^.memorizedSpells[i];
        GDVars.curChar^.memorizedSpells[i] := GDVars.curChar^.memorizedSpells[j];
        GDVars.curChar^.memorizedSpells[j] := tmp;
      end;
end;

{ Runs the Memorize menu. The spells already pending are shown first: Yes keeps them and skips the choosing, No clears
  them. Then spells are chosen from the spellbook and marked pending while slots remain, and when the spellbook was
  shown the pending spells are confirmed again. Note: a full memorized-spell list is searched past its end for an empty
  slot. }
procedure CampMemorizeMenu;
var
  done: Boolean;
  notEmpty: Boolean;
  redraw: Boolean;
  spellId: Byte;
  i: Byte;
  idx: Integer;
begin
  if Camp.CanDoSpellActivity(Camp.ACTIVITY_MEMORIZE) then begin
    done := False;
    idx := -1;
    GDVars.menuChoice := 1;
    spellId := ViewChar.SpellMenu(5, 0, idx, notEmpty);
    redraw := True;
    if notEmpty then begin
      if MenuCore.YesNoMenu('Memorize These Spells? ', Yellow, LightGreen, White) = 'N' then
        Camp.ResetMemorize(GDVars.curChar)
      else
        done := True;
    end else
      redraw := False;
    idx := -1;
    while done = False do begin
      done := Camp.DisplaySpellSlots = False;
      if done then
        CharHlp.PrintCreatureMessage(Types.PCreature(GDVars.curChar), 'cannot memorize any spells', Camp.MESSAGE_ROW,
                                     True)
      else begin
        spellId := ViewChar.SpellMenu(1, 2, idx, notEmpty);
        redraw := True;
        if spellId = 0 then
          done := True
        else if Camp.SpellSlotsRemaining(GDConsts.spellProperties[spellId].level,
                                         GDConsts.spellProperties[spellId].castClass) > 0 then begin
          i := 0;
          while GDVars.curChar^.memorizedSpells[i] <> 0 do
            Inc(i);
          GDVars.curChar^.memorizedSpells[i] := spellId + C_Spell.PENDING_FLAG;
          Camp.SortMemorizedSpells;
        end;
      end;
    end;
    if idx <> -1 then begin
      idx := -1;
      spellId := ViewChar.SpellMenu(5, 0, idx, notEmpty);
      if notEmpty then
        if MenuCore.YesNoMenu('Memorize these spells? ', Yellow, LightGreen, White) = 'N' then
          Camp.ResetMemorize(GDVars.curChar);
    end;
    if redraw then
      CharHlp.DisplayNoncombatInterface;
  end;
end;

{ Runs the Scribe menu. The spells already pending are shown first: Yes keeps them and skips the choosing, No clears
  them. Then scroll spells are chosen and marked pending, refusing a spell already known or pending or beyond the
  character's slots, and when the scrolls were shown the pending spells are confirmed again. Note: the marking does not
  check that the item is readable; it marks the first unmarked spell byte equal to the spell on any item. Note: the
  spell's class and level index the slot table unchecked, so a spell an item alone provides can read past it. }
procedure CampScribeMenu;
var
  done: Boolean;
  notEmpty: Boolean;
  redraw: Boolean;
  spellId: Byte;
  { Unused in this version; see the other implementations of this routine. }
  spellClass: Byte;
  i: Byte;
  idx: Integer;
  p: Types.PItem;
  found: Boolean;
begin
  if Camp.CanDoSpellActivity(Camp.ACTIVITY_SCRIBE) then begin
    done := False;
    idx := -1;
    spellId := ViewChar.SpellMenu(6, 0, idx, notEmpty);
    redraw := True;
    if notEmpty then begin
      if MenuCore.YesNoMenu('Scribe These Spells? ', Yellow, LightGreen, White) = 'N' then
        Camp.ResetScribe(GDVars.curChar)
      else
        done := True;
    end else
      redraw := False;
    idx := -1;
    while done = False do begin
      spellId := ViewChar.SpellMenu(3, 3, idx, notEmpty);
      if spellId = 0 then begin
        done := True;
        if notEmpty = False then
          CharHlp.PrintCreatureMessage(Types.PCreature(GDVars.curChar), 'has no copyable scrolls', Camp.MESSAGE_ROW,
                                       True)
        else
          redraw := True;
      end else begin
        redraw := True;
        if GDVars.curChar^.knownSpells[spellId] <> 0 then
          CharHlp.PrintBottomLine('You already know that spell')
        else begin
          p := GDVars.curChar^.itemsAddr;
          found := False;
          while (p <> nil) and (found = False) do begin
            if Magic.ItemReadable(p) then
              for i := 1 to 3 do
                if (p^.spells[i] > C_Spell.ID_MASK) and
                    (p^.spells[i] and C_Spell.ID_MASK = spellId) then begin
                  CharHlp.PrintBottomLine('You are already scibing that spell');
                  found := True;
                end;
            p := p^.next;
          end;
          if found = False then begin
            if GDVars.curChar^.spellSlots[GDConsts.spellProperties[spellId].castClass,
                                 GDConsts.spellProperties[spellId].level] > 0 then begin
              p := GDVars.curChar^.itemsAddr;
              while (p <> nil) and (found = False) do begin
                i := 1;
                repeat
                  if p^.spells[i] = spellId then begin
                    p^.spells[i] := p^.spells[i] or C_Spell.PENDING_FLAG;
                    found := True;
                  end;
                  Inc(i);
                until (i > 3) or found;
                p := p^.next;
              end;
            end else
              CharHlp.PrintBottomLine('You can not scribe that spell.');
          end;
        end;
      end;
    end;
    if idx <> -1 then begin
      idx := -1;
      spellId := ViewChar.SpellMenu(6, 0, idx, notEmpty);
      if notEmpty then
        if MenuCore.YesNoMenu('Scribe these spells? ', Yellow, LightGreen, White) = 'N' then
          Camp.ResetScribe(GDVars.curChar);
    end;
    if redraw then
      CharHlp.DisplayNoncombatInterface;
  end;
end;

{ Lists the spell effects on each party member under the member's name. Spell effects show the name of the first spell
  (1..56) producing them, or 'Funky--<id>' when none does; other visible effects have fixed labels, and the rest are
  hidden. A member with none shows '<No Spell Effects>'. }
procedure CampDisplayMenu;
var
  effect: Types.PEffect;
  listHead: Types.PItem;
  listTail: Types.PItem;
  character: Types.PCreature;
  effectId: Byte;
  spellIndex: Byte;
  { effects listed for this character }
  effectCount: Byte;
  { Unused in this version; see the other implementations of this routine. }
  isHeading: Byte;
  effectNameFound: Boolean;
  displayEffect: Boolean;
  viewNeedsRedraw: Boolean;
  effectName: Types.TStr40;
  menuIndex: Integer;
  { Unused in this version; see the other implementations of this routine. }
  choice: Char;

  { Appends a list node with the given text; isTitle marks a character-name heading. }
  procedure AddToList(isTitle: Boolean; displayText: Types.TStr40);
  begin
    GetMem(listTail^.next, SizeOf(Types.TItemNode));
    listTail := listTail^.next;
    listTail^.next := nil;
    listTail^.name := displayText;
    listTail^.inUse := Ord(isTitle);
  end;

begin
  GetMem(listHead, SizeOf(Types.TItemNode));
  listTail := listHead;
  listTail^.inUse := 0;
  listTail^.name := ' ';
  listTail^.next := nil;
  character := GDVars.partyHead;
  while character <> nil do begin
    effectCount := 0;
    AddToList(True, character^.name);
    effect := character^.effects;
    while effect <> nil do begin
      displayEffect := True;
      effectId := effect^.id;
      case effectId of
        1, 2, 5, 8..12, 14, 16, 17, 19..25, 28, 29, 32..34,
        36..39, 41, 42, 45, 46, 49, 51..53:
          begin
            spellIndex := 1;
            effectNameFound := False;
            while (spellIndex <= 56) and (effectNameFound = False) do
              if GDConsts.spellProperties[spellIndex].effectId = effectId then begin
                effectName := GDConsts.spellNames[spellIndex];
                effectNameFound := True;
              end else
                Inc(spellIndex);
            if effectNameFound = False then
              effectName := 'Funky--' + CharHlp.Uint8Str(effectId);
          end;
        4: effectName := 'Dispel Evil';
        7: effectName := 'Faerie Fire';
        27: effectName := 'Fumbling';
        C_Effect.HELPLESS: effectName := 'Helpless';
        35: effectName := 'Confused';
        C_Effect.DISEASE_HIT_POINTS: effectName := 'Cause Disease';
        50: effectName := 'Hot Fire Shield';
        54: effectName := 'Cold Fire Shield';
        C_Effect.POISONED: effectName := 'Poisoned';
        59: effectName := 'Regenerating';
        61: effectName := 'Fire Resistance';
        63: effectName := 'Minor Globe of Invulnerability';
        68: effectName := 'enfeebled';
        69: effectName := 'invisible to animals';
        71: effectName := 'Invisible';
        72: effectName := 'Camouflaged';
        73: effectName := 'protected from dragon breath';
        77: effectName := 'berserk';
        89: effectName := 'Displaced';
      else
        displayEffect := False;
      end;
      if displayEffect then begin
        Inc(effectCount);
        AddToList(False, ' ' + effectName);
      end;
      effect := effect^.next;
    end;
    if effectCount = 0 then
      AddToList(False, ' <No Spell Effects>');
    AddToList(False, ' ');
    character := character^.next;
  end;
  viewNeedsRedraw := True;
  menuIndex := 0;
  Border.DrawWindowFrame;
  choice := MenuCore.MenuVertical('', '', LightCyan, LightGreen, White, 1, 4, 38, 22, Types.PItem(listHead), True,
                                  viewNeedsRedraw, menuIndex, Types.PItem(listTail));
  MenuCore.FreeStringList(Types.PItem(listHead));
  CharHlp.DisplayNoncombatInterface;
end;

{ Runs the Magic menu (cast, memorize, scribe, display, rest); extended keys change the current character. Ends on Exit,
  Escape or an interrupted rest.
  @param(interrupted Set True when a rest is interrupted; the menu ends at once when it is already True.) }
procedure CampMagicMenu(var interrupted: Boolean);
var
  c: Char;
  ext: Boolean;
begin
  c := ' ';
  while (interrupted = False) and (not (c in [C_Keys.NONE, 'E'])) do begin
    c := MenuCore.MenuHorizontal('', GDConsts.magicMenu, LightMagenta, LightGreen, White, True, True, ext);
    if ext then begin
      ViewChar.SelectPrevNextChar(c);
      CharHlp.DisplayParty(Types.PCreature(GDVars.curChar));
    end else
      case c of
        'C': Camp.NoncombatCastMenu;
        'M': Camp.CampMemorizeMenu;
        'S': Camp.CampScribeMenu;
        'D': Camp.CampDisplayMenu;
        'R': Camp.RestForSpellPrep(interrupted);
      end;
  end;
end;

{ Moves the current character one place earlier in the party; the first character moves to the end. }
procedure OrderMoveUp;
var
  prev: Types.PCreature;
  p: Types.PCreature;
  tmp: Types.PCreature;
begin
  p := GDVars.partyHead;
  prev := nil;
  if p = GDVars.curChar then begin
    while p^.next <> nil do
      p := p^.next;
  end else
    while p^.next <> GDVars.curChar do begin
      prev := p;
      p := p^.next;
    end;
  tmp := GDVars.curChar^.next;
  if GDVars.partyHead = GDVars.curChar then begin
    if tmp <> nil then
      GDVars.partyHead := tmp;
    p^.next := GDVars.curChar;
    GDVars.curChar^.next := nil;
  end else begin
    p^.next := tmp;
    GDVars.curChar^.next := p;
    if (p = GDVars.partyHead) or (prev = nil) then
      GDVars.partyHead := GDVars.curChar
    else
      prev^.next := GDVars.curChar;
  end;
end;

{ Moves the current character one place later in the party; the last character moves to the front. }
procedure OrderMoveDown;
var
  predecessor: Types.PCreature;
  successor: Types.PCreature;
begin
  predecessor := GDVars.partyHead;
  if predecessor <> GDVars.curChar then
    while predecessor^.next <> GDVars.curChar do
      predecessor := predecessor^.next;
  successor := GDVars.curChar^.next;
  if successor = nil then begin
    GDVars.curChar^.next := GDVars.partyHead;
    GDVars.partyHead := GDVars.curChar;
    predecessor^.next := successor;
  end else begin
    GDVars.curChar^.next := successor^.next;
    if GDVars.partyHead = GDVars.curChar then
      GDVars.partyHead := successor;
    if predecessor <> GDVars.curChar then
      predecessor^.next := successor;
    successor^.next := GDVars.curChar;
  end;
end;

{ Reorders the party in two modes. In Select mode extended keys change the current character; in Place mode Home moves
  it up and End moves it down. Enter, P and S switch modes. }
procedure PartyOrderMenu;
var
  selected: ShortInt;
  isExtendedKey: Boolean;
  choice: Char;
begin
  selected := 0;
  choice := ' ';
  while not (choice in [C_Keys.NONE, 'E']) do begin
    choice := MenuCore.MenuHorizontal('Party Order: ', GDConsts.partyOrderMenus[selected], LightMagenta, LightGreen,
                                      White, True, True, isExtendedKey);
    if isExtendedKey then begin
      if selected = 0 then begin
        ViewChar.SelectPrevNextChar(choice);
        CharHlp.DisplayParty(Types.PCreature(GDVars.curChar));
      end else begin
        case choice of
          C_Keys.HOME: Camp.OrderMoveUp;
          C_Keys.END_KEY: Camp.OrderMoveDown;
        end;
        CharHlp.DisplayParty(Types.PCreature(GDVars.curChar));
      end;
    end else
      if choice in [C_Keys.ENTER, 'P', 'S'] then begin
        selected := Ord(selected = 0);
        if selected <> 0 then
          CharHlp.PrintCreatureMessage(Types.PCreature(GDVars.curChar), 'has been selected', Camp.MESSAGE_ROW, False)
        else
          CharHlp.ClearMessageWindow;
      end;
  end;
end;

{ Drops the current character from the party after confirmation, with a farewell that depends on whether it is enabled,
  and redraws the party. For the last party member it offers to quit to DOS instead. }
procedure CampDropMenu;
begin
  if (GDVars.curChar^.next = nil) and (GDVars.curChar = GDVars.partyHead) then begin
    if MenuCore.YesNoMenu('quit TO DOS: ', Yellow, LightGreen, White) = 'Y' then begin
      CharGen.RemoveCreature(False, True);
      GameIo.ExitGame;
    end else
      Exit;
    Exit;
  end;
  CharHlp.PrintCreatureMessage(Types.PCreature(GDVars.curChar), 'will be gone', Camp.MESSAGE_ROW, False);
  if MenuCore.YesNoMenu('Drop from party? ', Yellow, LightGreen, White) = 'Y' then begin
    if GDVars.curChar^.enabled <> 0 then
      CharHlp.PrintCreatureMessage(Types.PCreature(GDVars.curChar), 'bids you farewell', Camp.MESSAGE_ROW, True)
    else
      CharHlp.PrintCreatureMessage(Types.PCreature(GDVars.curChar), 'is dumped in a ditch', Camp.MESSAGE_ROW, True);
    CharGen.RemoveCreature(False, True);
    Border.ClearBox(17, 1, 38, 11);
    CharHlp.DisplayParty(Types.PCreature(GDVars.curChar));
  end else
    CharHlp.PrintCreatureMessage(Types.PCreature(GDVars.curChar), 'Breathes A sigh of relief', Camp.MESSAGE_ROW, True);
end;

{ Adjusts the game delay, 0 (fastest) to 9 (slowest). Faster and Slower are offered only while the delay can move that
  way; the up arrow slows the game and the down arrow speeds it up. }
procedure CampSpeedMenu;
var
  choice: Char;
  isExtendedKey: Boolean;
  menuText: Types.TStr40;
begin
  repeat
    TextRend.DisplayString(1, 18, LightGreen, 0,
                           'Game Speed = ' + CharHlp.Uint8Str(GDVars.gameDelay) + ' (0=fastest 9=slowest)');
    menuText := '';
    if GDVars.gameDelay > 0 then
      menuText := menuText + ' Faster';
    if GDVars.gameDelay < 9 then
      menuText := menuText + ' Slower';
    menuText := menuText + ' Exit';
    choice := MenuCore.MenuHorizontal('Game Speed:', menuText, LightMagenta, LightGreen, White, True, True,
                                      isExtendedKey);
    if isExtendedKey then begin
      case choice of
        C_Keys.DOWN: if GDVars.gameDelay > 0 then Dec(GDVars.gameDelay);
        C_Keys.UP: if GDVars.gameDelay < 9 then Inc(GDVars.gameDelay);
      end;
    end else
      case choice of
        'F': Dec(GDVars.gameDelay);
        'S': Inc(GDVars.gameDelay);
      end;
  until choice in [C_Keys.NONE, 'E'];
  CharHlp.ClearMessageWindow;
end;

{ Runs the Alter menu: party order, drop, game speed, portrait icon, and a submenu toggling pictures and animation.
  Extended keys change the current character. }
procedure CampAlterMenu;
var
  choice: Char;
  toggleChoice: Char;
  isExtendedKey: Boolean;
  menuText: Types.TStr40;
begin
  choice := ' ';
  while not (choice in [C_Keys.NONE, 'E']) do begin
    choice := MenuCore.MenuHorizontal('Alter: ', GDConsts.alterMenu, LightMagenta, LightGreen, White, True, True,
                                      isExtendedKey);
    if isExtendedKey then begin
      ViewChar.SelectPrevNextChar(choice);
      CharHlp.DisplayParty(Types.PCreature(GDVars.curChar));
    end else
      case choice of
        'O': Camp.PartyOrderMenu;
        'D': Camp.CampDropMenu;
        'S': Camp.CampSpeedMenu;
        'I': begin
               CharGen.CustomizePortrait;
               CharHlp.DisplayNoncombatInterface;
             end;
        'P': repeat
               if GDVars.picsOn <> 0 then begin
                 menuText := 'Pics on  ';
                 if GDVars.animOn <> 0 then
                   menuText := menuText + 'Animation on  '
                 else
                   menuText := menuText + 'Animation off  ';
               end else
                 menuText := 'Pics off  ';
               menuText := menuText + 'Exit';
               toggleChoice := MenuCore.MenuHorizontal('', menuText, LightMagenta, LightGreen, White, False, True,
                                                       isExtendedKey);
               case toggleChoice of
                 'P': GDVars.picsOn := Ord(GDVars.picsOn = 0);
                 'A': GDVars.animOn := Ord(GDVars.animOn = 0);
               end;
             until toggleChoice in [C_Keys.NONE, 'E'];
      end;
  end;
end;

{ Heals the party with its cure spells. Rolls each cure spell the conscious members have memorized into a healing pool,
  rests for a time set by their cleric slots of levels 1, 4 and 5, then, unless the rest is interrupted, rolls one cure
  for each of those slots into the pool, spends the pool on the party in order and puts the rest clock back. When the
  party misses fewer hit points than the slots' combined heal time, the rest is shortened in proportion. Note: that heal
  time is never set to 0 before it is added up, and a member who is not conscious repeats the previous member's slot
  times.
  @param(interrupted Set True when the rest is interrupted.) }
procedure CampFixMenu(var interrupted: Boolean);
var
  { hit points available to heal }
  healPool: Word;
  cureLightSlots: Word;
  cureSeriousSlots: Word;
  cureCriticalSlots: Word;
  { Rest clock, restored after an uninterrupted rest. }
  savedRestTime: Types.TClock;

  { A member counts as conscious only when its status is OKAY. }
  function CanCast(character: Types.PCreature): Boolean;
  begin
    CanCast := character^.status = C_Status.OKAY;
  end;

  { Adds a roll for each cure spell memorized by a conscious member to the healing pool. }
  procedure RollMemorizedCures;
  var
    rolledHealing: Word;
    spellIndex: Byte;
    character: Types.PCreature;
  begin
    rolledHealing := 0;
    character := GDVars.partyHead;
    while character <> nil do begin
      if CanCast(character) then
        for spellIndex := 0 to 83 do
          case character^.memorizedSpells[spellIndex] of
            C_Spell.CURE_LIGHT_WOUNDS: Inc(rolledHealing, FxEngine.RollDice(1, 8));
            C_Spell.CURE_SERIOUS_WOUNDS: Inc(rolledHealing, FxEngine.RollDice(2, 8) + 1);
            C_Spell.CURE_CRITICAL_WOUNDS: Inc(rolledHealing, FxEngine.RollDice(3, 8) + 3);
          end;
      character := character^.next;
    end;
    Inc(healPool, rolledHealing);
  end;

  { Adds a cure roll for each cleric slot of levels 1, 4 and 5 counted by ComputeFixTime. }
  procedure RollCureSlots;
  var
    rolledHealing: Word;
    rollIndex: Byte;
  begin
    rolledHealing := 0;
    for rollIndex := 1 to cureLightSlots do Inc(rolledHealing, FxEngine.RollDice(1, 8));
    for rollIndex := 1 to cureSeriousSlots do Inc(rolledHealing, FxEngine.RollDice(2, 8) + 1);
    for rollIndex := 1 to cureCriticalSlots do Inc(rolledHealing, FxEngine.RollDice(3, 8) + 3);
    Inc(healPool, rolledHealing);
  end;

  { Returns the party's total missing hit points. }
  function PartyHitPointsMissing: Word;
  var
    totalDamage: Word;
    character: Types.PCreature;
  begin
    totalDamage := 0;
    character := GDVars.partyHead;
    while character <> nil do begin
      Inc(totalDamage, character^.hpMax - character^.hpCur);
      character := character^.next;
    end;
    PartyHitPointsMissing := totalDamage;
  end;

  { Counts the conscious members' cleric slots of levels 1, 4 and 5 and sets the rest clock from them. }
  procedure ComputeFixTime;
  var
    timeMin: Word;
    ch: Types.PCreature;
    maxTime: Word;
    partA: Word;
    partB: Word;
    partC: Word;
    base: Word;
    ratio: Byte;
  begin
    ch := GDVars.partyHead;
    partA := 0;
    partB := 0;
    partC := 0;
    cureLightSlots := 0;
    cureSeriousSlots := 0;
    cureCriticalSlots := 0;
    maxTime := 0;
    while ch <> nil do begin
      base := 0;
      if CanCast(ch) then begin
        Inc(cureLightSlots, ch^.spellSlots[C_Spell.CLERIC_LIST, 1]);
        partA := ch^.spellSlots[C_Spell.CLERIC_LIST, 1] * 15;
        Inc(cureSeriousSlots, ch^.spellSlots[C_Spell.CLERIC_LIST, 4]);
        partB := ch^.spellSlots[C_Spell.CLERIC_LIST, 4] * 60;
        Inc(cureCriticalSlots, ch^.spellSlots[C_Spell.CLERIC_LIST, 5]);
        partC := ch^.spellSlots[C_Spell.CLERIC_LIST, 5] * 75;
      end;
      if partA > 0 then begin
        base := 240;
        Inc(timeMin, 27);
      end;
      if partB + partC > 0 then begin
        base := 360;
        if partC > 0 then
          Inc(timeMin, 78)
        else
          Inc(timeMin, 34);
      end;
      Inc(base, partA + partB + partC);
      if maxTime < base then
        maxTime := base;
      ch := ch^.next;
    end;
    if PartyHitPointsMissing < timeMin then begin
      ratio := timeMin div PartyHitPointsMissing;
      maxTime := maxTime div ratio;
    end;
    GDVars.restTime[3] := maxTime div 60;
    GDVars.restTime[2] := (maxTime - 60 * GDVars.restTime[3]) div 10;
    GDVars.restTime[1] := maxTime mod 10;
  end;

  { Spends the healing pool on each member in party order, up to that member's missing hit points. }
  procedure HealParty;
  var
    character: Types.PCreature;
    healingNeeded: Word;
  begin
    character := GDVars.partyHead;
    while character <> nil do begin
      if character^.hpMax > character^.hpCur then begin
        healingNeeded := character^.hpMax - character^.hpCur;
        if healingNeeded > healPool then healingNeeded := healPool;
        if healingNeeded < 1 then healingNeeded := 0;
        if healingNeeded > 0 then
          if FxEngine.RestoreHitPoints(character, healingNeeded, False) then
            if healingNeeded <= healPool then
              Dec(healPool, healingNeeded);
      end;
      character := character^.next;
    end;
  end;

begin
  interrupted := False;
  healPool := 0;
  if PartyHitPointsMissing <> 0 then begin
    RollMemorizedCures;
    if PartyHitPointsMissing = 0 then begin
      CharHlp.DisplayParty(Types.PCreature(GDVars.curChar));
      CharHlp.PrintPositionAndTime;
    end else begin
      savedRestTime := GDVars.restTime;
      ComputeFixTime;
      interrupted := GameTime.CampRest(False);
      if interrupted = False then begin
        RollCureSlots;
        HealParty;
        CharHlp.DisplayParty(Types.PCreature(GDVars.curChar));
        CharHlp.PrintPositionAndTime;
        GDVars.restTime := savedRestTime;
      end;
    end;
  end;
end;

procedure CampMainMenu(var interrupted: Boolean);
var
  savedIfc: Byte;
  c: Char;
  { ViewCharMenu's out flag, unused here. }
  vflag: Boolean;
  ext: Boolean;
begin
  savedIfc := GDVars.ifcState;
  GDVars.ifcState := C_Ifc.CAMPING;
  GDVars.healTicks := 0;
  FillChar(GDVars.restTime, SizeOf(GDVars.restTime), 0);
  GDVars.savedPicArchiveName := GDVars.picArchiveName;
  GDVars.savedPicId := GDVars.loadedPicId;
  CharHlp.DisplayNoncombatInterface;
  Border.ClearBox(1, 17, 38, 22);
  TextRend.DisplayString(1, 18, LightGreen, 0, 'The party makes camp...');
  Camp.ResetPartySpellActivities;
  interrupted := False;
  c := ' ';
  while (interrupted = False) and (not (c in [C_Keys.NONE, 'E'])) do begin
    c := MenuCore.MenuHorizontal('Camp:', GDConsts.campMenu, LightMagenta, LightGreen, White, True, True, ext);
    if ext then begin
      ViewChar.SelectPrevNextChar(c);
      CharHlp.DisplayParty(Types.PCreature(GDVars.curChar));
    end else
      case c of
        'S': begin
               SaveLoad.SaveGame;
               if MenuCore.YesNoMenu('Quit TO DOS ', Yellow, LightGreen, White) = 'Y' then
                 GameIo.ExitGame;
             end;
        'V': begin
               GDVars.menuChoice := 1;
               ViewChar.ViewCharMenu(vflag);
             end;
        'M': begin
               GDVars.menuChoice := 1;
               Camp.CampMagicMenu(interrupted);
             end;
        'R': begin
               GDVars.menuChoice := 1;
               Camp.RestForSpellPrep(interrupted);
             end;
        'F': Camp.CampFixMenu(interrupted);
        'A': begin
               GDVars.menuChoice := 1;
               Camp.CampAlterMenu;
             end;
      end;
  end;
  if Copy(GDVars.savedPicArchiveName, 1, 3) = 'PIC' then
    Portrait.LoadAnimation(GDVars.savedPicArchiveName, GDVars.savedPicId, 0, GDVars.animData);
  Camp.ResetPartySpellActivities;
  GDVars.lastSpellTarget := nil;
  GDVars.ifcState := savedIfc;
  CharHlp.PrintPositionAndTime;
  CharHlp.ClearMessageWindow;
  MenuCore.ClearBottomLine;
end;

begin
end.
