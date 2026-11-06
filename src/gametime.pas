{ Time and rest: the game clock and effect timeouts, and resting in camp with healing, memorizing and scribing spells,
  and interruptions. }
{$O+,F+}
{$A-}
unit GameTime;

interface

uses Types, Crt, Magic, FxEngine, CharHlp, MenuCore, TextRend, EclTrace, GDConsts, GDVars, C_Keys, C_Ifc, C_Spell,
  C_Gbvm;

{ Empty routine with no callers. }
procedure NoopGameTime;

{ Advances the game clock, kept in the script's variables, by amount units of one clock component, a unit at a time,
  carrying as it goes (ValidateClock), and runs the party's effects down by the same time (TimeOutEffects).
  @param(amount The number of units.)
  @param(tUnit The clock component counted: 1 minutes, 2 tens of minutes, 3 hours, 4 days.) }
procedure AdvanceTime(amount: Byte; tUnit: ShortInt);

{ Rests the party for the rest time, five minutes per step: the clock advances, effects run down, the party heals 1 hit
  point a day, spells are memorized and scribed, and when the script sets an interruption interval, the interruption
  chance it sets is rolled once per interval. Preparation timers start from 0 and each member's effects are checked.
  @param(interactive True to show the rest time, ask for it in the rest menu (leaving the menu skips the rest) and offer
    to stop at a key press.)
  @returns(True when the interruption roll ended the rest; False when it ran out or the player stopped or skipped it.) }
function CampRest(interactive: Boolean): Boolean;

{ Calls the priming entry of each overlay this unit uses, so the overlay manager loads them. }
procedure PrimeGameTime;

implementation

procedure NoopGameTime;
begin
end;

procedure PrimeGameTime;
begin
  EclTrace.PrimeEclTrace;
  Magic.PrimeMagic;
  FxEngine.PrimeFxEngine;
  CharHlp.PrimeCharHlp;
  MenuCore.PrimeMenuCore;
end;

{ Runs the party's effect durations down by count units of component tUnit, converted to minutes (a component-0 count is
  used as is) and taken at most 10 at a time, removing the effects that run out. effFlags marks the members with timed
  effects left: while camping the others are skipped, and nothing happens when no member is marked; otherwise each
  member is checked.
  @param(count The time to run down.)
  @param(tUnit The clock component count is in.) }
procedure TimeOutEffects(count: Byte; tUnit: ShortInt);
var
  u: ShortInt;
  i: Byte;
  step: Byte;
  total: Word;
  cur: Types.PCreature;
  done: Boolean;
  found: Boolean;
  tail: Types.PEffect;
  prev: Types.PEffect;
  e: Types.PEffect;
begin
  if GDVars.ifcState <> C_Ifc.CAMPING then
    FillChar(GDVars.effFlags, SizeOf(GDVars.effFlags), 1)
  else begin
    found := False;
    i := 1;
    repeat
      if GDVars.effFlags[i] then found := True;
      Inc(i);
    until found or (i > GDVars.zone1^[C_Gbvm.PARTY_SIZE]);
    if not found then Exit;
  end;
  total := count;
  u := tUnit;
  while u > 1 do begin
    total := GDConsts.clockLimits[Pred(u)] * total;
    u := Pred(u);
  end;
  while total > 0 do begin
    if total > 10 then step := 10 else step := total;
    i := 1;
    cur := GDVars.partyHead;
    while cur <> nil do begin
      if GDVars.effFlags[i] then begin
        GDVars.effFlags[i] := False;
        e := cur^.effects;
        tail := cur^.effects;
        prev := cur^.effects;
        if cur^.effects <> nil then
          while tail^.next <> nil do tail := tail^.next;
        done := False;
        while (e <> nil) and not done do begin
          if e = tail then done := True;
          if e^.duration = 0 then
            e := e^.next
          else if step < e^.duration then begin
            Dec(e^.duration, step);
            GDVars.effFlags[i] := True;
            e := e^.next;
          end else begin
            FxEngine.RemoveEffect(Types.PCreature(cur), e^.id, e);
            if prev = cur^.effects then
              e := cur^.effects
            else
              e := prev^.next;
          end;
          prev := cur^.effects;
          while (prev <> nil) and (prev <> e) and (prev^.next <> e) do
            prev := prev^.next;
        end;
        while e <> nil do begin
          if e^.duration > 0 then GDVars.effFlags[i] := True;
          e := e^.next;
        end;
      end;
      Inc(i);
      cur := cur^.next;
    end;
    if total > 10 then Dec(total, 10) else total := 0;
  end;
end;

{ Carries each clock component that reached its limit into the next one; when the years reach theirs, the party ages a
  year instead. Note: the years are not reset, so the party ages again on every later call.
  @param(clock The clock to carry.) }
procedure ValidateClock(var clock: Types.TClock);
var
  i: ShortInt;
  cur: Types.PCreature;
begin
  for i := 0 to 6 do
    if clock[i] >= GDConsts.clockLimits[i] then
      if i <> 6 then begin
        Inc(clock[Succ(i)]);
        clock[i] := clock[i] - GDConsts.clockLimits[i];
      end else begin
        cur := GDVars.partyHead;
        while cur <> nil do begin
          Inc(cur^.age);
          cur := cur^.next;
        end;
      end;
end;

{ Carries the rest time and turns months into days, at most 99. }
procedure ValidateRestTime;
begin
  GameTime.ValidateClock(GDVars.restTime);
  if GDVars.restTime[5] > 0 then begin
    Inc(GDVars.restTime[4], GDConsts.clockLimits[4] * GDVars.restTime[5]);
    GDVars.restTime[5] := 0;
    if GDVars.restTime[4] > 99 then GDVars.restTime[4] := 99;
  end;
end;

procedure AdvanceTime(amount: Byte; tUnit: ShortInt);
var
  clock: Types.TClock;
  i: ShortInt;
  j: Byte;
begin
  for i := 0 to 6 do
    clock[i] := GDVars.zone0^[$4BC6 + i];
  for j := 1 to amount do begin
    Inc(clock[tUnit]);
    GameTime.ValidateClock(clock);
  end;
  for i := 0 to 6 do
    GDVars.zone0^[$4BC6 + i] := clock[i];
  GameTime.TimeOutEffects(amount, tUnit);
end;

{ Takes count units of component tUnit off the rest time, borrowing from the larger components and clearing the rest
  time when there is nothing left to borrow; nothing happens when the rest time is already 0.
  @param(count The number of units.)
  @param(tUnit The rest-time component counted: 1 minutes, 2 tens of minutes, 3 hours, 4 days.) }
procedure DecrementRestTime(count: Byte; tUnit: ShortInt);
var
  j: ShortInt;
  k: ShortInt;
begin
  if (GDVars.restTime[4] <> 0) or (GDVars.restTime[3] <> 0) or (GDVars.restTime[2] <> 0) or
      (GDVars.restTime[1] <> 0) then begin
    while count > GDVars.restTime[tUnit] do begin
      j := Succ(tUnit);
      while (GDVars.restTime[j] = 0) and (j < 5) do
        j := Succ(j);
      if j = 5 then begin
        FillChar(GDVars.restTime, SizeOf(GDVars.restTime), 0);
        count := 0;
      end else
        for k := j downto Succ(tUnit) do begin
          Dec(GDVars.restTime[k]);
          Inc(GDVars.restTime[Pred(k)], GDConsts.clockLimits[Pred(k)]);
        end;
    end;
    Dec(GDVars.restTime[tUnit], count);
    GameTime.ValidateRestTime;
  end;
end;

{ Formats a number as two digits.
  @param(value The number, 0 to 99.)
  @returns(Its first two digits, with a leading zero below 10.) }
function TwoDigitStr(value: Byte): Types.TStr40;
var
  s: Types.TStr40;
begin
  s := CharHlp.Uint8Str(value);
  if value < 10 then s := '0' + s;
  TwoDigitStr := Copy(s, 1, 2);
end;

{ Shows the rest time as days:hours:minutes on row 17, with one component highlighted.
  @param(hlUnit The component highlighted: 2 minutes, 3 hours, 4 days; 0 for none.) }
procedure DisplayRestTime(hlUnit: ShortInt);
var
  i: ShortInt;
  colors: array[0..6] of Word;
  x: Byte;
begin
  for i := 0 to 6 do
    colors[i] := 10;
  colors[hlUnit] := 15;
  TextRend.DisplayString(1, 17, LightGreen, 0, 'Rest Time:');
  x := 11;
  for i := 4 downto 3 do begin
    TextRend.DisplayString(x + 1, 17, colors[i], 0, GameTime.TwoDigitStr(GDVars.restTime[i]));
    TextRend.DisplayString(x + 1 + 2, 17, LightGreen, 0, ':');
    Inc(x, 3);
  end;
  TextRend.DisplayString(x + 1, 17, colors[2], 0, GameTime.TwoDigitStr(10 * GDVars.restTime[2] + GDVars.restTime[1]));
end;

{ Runs the rest-time menu: Days, Hours and Mins (or the left and right arrows) pick a component, Add and Subtract (or
  the up and down arrows) change it, minutes by 5.
  @returns(True for Rest or Enter, False for Exit or Escape.) }
function CampRestMenu: Boolean;
var
  ext: Boolean;
  ch: Char;
  sel: ShortInt;
begin
  CampRestMenu := False;
  sel := 2;
  repeat
    GameTime.DisplayRestTime(sel);
    ch := MenuCore.MenuHorizontal('', 'Rest Days Hours Mins Add Subtract Exit', LightMagenta, LightGreen, White, True,
                                  False, ext);
    if ext then
      case ch of
        { Add }
        C_Keys.UP: ch := 'A';
        { Subtract }
        C_Keys.DOWN: ch := 'S';
        C_Keys.LEFT: begin
                Inc(sel);
                if sel > 4 then sel := 2;
                ch := 'X';
              end;
        C_Keys.RIGHT: begin
                Dec(sel);
                if sel < 2 then sel := 4;
                ch := 'X';
              end;
      else
        ch := 'X';
      end;
    if ch = C_Keys.ENTER then ch := 'R';
    case ch of
      'R': CampRestMenu := True;
      'D': sel := 4;
      'H': sel := 3;
      'M': sel := 2;
      'A': begin
             if sel = 2 then
               Inc(GDVars.restTime[1], 5)
             else
               Inc(GDVars.restTime[sel]);
             GameTime.ValidateRestTime;
           end;
      'S': begin
             if sel = 2 then
               GameTime.DecrementRestTime(5, 1)
             else
               GameTime.DecrementRestTime(1, sel);
             GameTime.ValidateRestTime;
           end;
    end;
  until ch in [C_Keys.NONE, 'E', 'R'];
end;

{ Counts a rest step; after 288 of them (a day) each okay, animated, unconscious or dying member regains 1 hit point (up
  to its maximum) and "The Whole Party Is Healed" shows, even if no one healed.
  @param(showTime True to show the rest time first.) }
procedure CheckRestingHeal(showTime: Boolean);
var
  healed: Boolean;
  cur: Types.PCreature;
begin
  Inc(GDVars.healTicks);
  if GDVars.healTicks >= 288 then begin
    healed := False;
    cur := GDVars.partyHead;
    while cur <> nil do begin
      if FxEngine.RestoreHitPoints(Types.PCreature(cur), 1, False) then healed := True;
      cur := cur^.next;
    end;
    if showTime then GameTime.DisplayRestTime(0);
    TextRend.DisplayString(1, 19, LightGreen, 0, 'The Whole Party Is Healed');
    if healed then CharHlp.DisplayParty(Types.PCreature(GDVars.curChar));
    TextRend.PauseOnly;
    CharHlp.ClearMessageWindow;
    GDVars.healTicks := 0;
  end;
end;

{ Looks through a member's spells still being memorized (pending flag set) and finishes the first one ("has memorized")
  when done is False.
  @param(cr The member.)
  @param(done False to finish the first pending spell, which sets it; True to look only.)
  @returns(The level of the next spell still being memorized, or 0 if none.) }
function CheckMemorizeDone(cr: Types.PCreature; var done: Boolean): Byte;
var
  lvl: Byte;
  i: Byte;
begin
  lvl := 0;
  i := 0;
  while (i <= 83) and (lvl = 0) do begin
    if cr^.memorizedSpells[i] > C_Spell.ID_MASK then
      if done then
        lvl := GDConsts.spellProperties[cr^.memorizedSpells[i] and C_Spell.ID_MASK].level
      else begin
        Dec(cr^.memorizedSpells[i], C_Spell.PENDING_FLAG);
        GameTime.DisplayRestTime(0);
        Magic.PrintCastSpellMsg(Pointer(cr), 'has memorized', cr^.memorizedSpells[i]);
        done := True;
      end;
    Inc(i);
  end;
  CheckMemorizeDone := lvl;
end;

{ Looks through the spells marked for scribing (pending flag set) on a member's readable scrolls and finishes the first
  one when done is False: it becomes known and leaves the scroll ("has scribed").
  @param(cr The member.)
  @param(done False to finish the first marked spell, which sets it; True to look only.)
  @returns(The level of the next spell still marked, or 0 if none.) }
function CheckScribeDone(cr: Types.PCreature; var done: Boolean): Byte;
var
  j: Byte;
  sp: Byte;
  lvl: Byte;
  it: Types.PItem;
  { Unused in this version; see the other implementations of this routine. }
  found: Boolean;
begin
  lvl := 0;
  found := False;
  it := cr^.itemsAddr;
  while (it <> nil) and (lvl = 0) do begin
    j := 1;
    if Magic.ItemReadable(it) then
      while (j <= 3) and (lvl = 0) do begin
        if it^.spells[j] > C_Spell.PENDING_FLAG then begin
          found := True;
          if done then
            lvl := GDConsts.spellProperties[it^.spells[j] and C_Spell.ID_MASK].level
          else begin
            sp := it^.spells[j] and C_Spell.ID_MASK;
            cr^.knownSpells[sp] := 1;
            Magic.RemoveSpellFromScroll(cr, it, sp);
            GameTime.DisplayRestTime(0);
            Magic.PrintCastSpellMsg(Pointer(cr), 'has scribed', sp);
            done := True;
          end;
        end;
        Inc(j);
      end;
    it := it^.next;
  end;
  CheckScribeDone := lvl;
end;

{ Counts each member's preparation timer down a step. A member whose timer has run out and who has no base preparation
  time left finishes its next scribing, or else memorizing, and its timer is set to 3 steps (15 minutes) per level of
  the one after. }
procedure AdvanceSpellPrep;
var
  i: Byte;
  lvl: Byte;
  cur: Types.PCreature;
  done: Boolean;
begin
  i := 1;
  cur := GDVars.partyHead;
  while cur <> nil do begin
    if GDVars.prepTimers[i] > 0 then
      Dec(GDVars.prepTimers[i]);
    if (GDVars.prepTimers[i] = 0) and (cur^.spellPrep = 0) then begin
      done := False;
      lvl := GameTime.CheckScribeDone(cur, done);
      if lvl = 0 then lvl := GameTime.CheckMemorizeDone(cur, done);
      GDVars.prepTimers[i] := lvl * 3;
    end;
    cur := cur^.next;
    Inc(i);
  end;
end;

{ Counts a rest step and every 12 steps (an hour) counts each member's base preparation time (spellPrep, in hours) down;
  when it runs out, the member's timer is set from the first pending scribing or memorizing, which is not finished yet.
  @param(tick The step count, kept by CampRest and reset every 12 steps.) }
procedure AdvanceSpellPrepBase(var tick: Byte);
var
  i: Byte;
  lvl: Byte;
  cur: Types.PCreature;
  done: Boolean;
begin
  Inc(tick);
  if tick >= 12 then begin
    tick := 0;
    i := 1;
    cur := GDVars.partyHead;
    while cur <> nil do begin
      if cur^.spellPrep > 0 then begin
        Dec(cur^.spellPrep);
        if cur^.spellPrep = 0 then begin
          done := True;
          lvl := GameTime.CheckScribeDone(cur, done);
          if lvl = 0 then lvl := GameTime.CheckMemorizeDone(cur, done);
          GDVars.prepTimers[i] := lvl * 3;
        end;
      end;
      cur := cur^.next;
      Inc(i);
    end;
  end;
end;

function CampRest(interactive: Boolean): Boolean;
var
  cur: Types.PCreature;
  { Unused in this version; see the other implementations of this routine. }
  member: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  memberCount: Byte;
  i: Byte;
  tick: Byte;
  cnt: Byte;
  stop: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  interrupted: Boolean;
begin
  CampRest := False;
  interrupted := False;
  i := 1;
  cur := GDVars.partyHead;
  while cur <> nil do begin
    GDVars.prepTimers[i] := 0;
    Inc(i);
    cur := cur^.next;
  end;
  FillChar(GDVars.effFlags, SizeOf(GDVars.effFlags), 1);
  tick := 0;
  cnt := 0;
  if interactive then begin
    TextRend.ClearRect(1, 17, 38, 22);
    GameTime.DisplayRestTime(0);
  end;
  GDVars.noBorder := 1;
  if interactive then
    stop := not GameTime.CampRestMenu
  else
    stop := False;
  while (not stop) and
      ((GDVars.restTime[4] > 0) or (GDVars.restTime[3] > 0) or (GDVars.restTime[2] > 0) or
       (GDVars.restTime[1] > 0)) do begin
    if interactive and KeyPressed then begin
      GameTime.DisplayRestTime(0);
      if MenuCore.YesNoMenu('Stop Resting? ', LightMagenta, LightGreen, White) = 'Y' then
        stop := True
      else
        MenuCore.ClearBottomLine;
    end;
    if not stop then begin
      GameTime.DecrementRestTime(5, 1);
      Inc(cnt);
      if interactive and (cnt >= 5) then begin
        GameTime.DisplayRestTime(0);
        cnt := 0;
      end;
      GameTime.AdvanceTime(5, 1);
      GameTime.CheckRestingHeal(interactive);
      GameTime.AdvanceSpellPrep;
      GameTime.AdvanceSpellPrepBase(tick);
      if GDVars.zone1^[$7ED2] > 0 then begin
        Inc(GDVars.restTicks);
        if GDVars.restTicks >= GDVars.zone1^[$7ED2] then begin
          GDVars.restTicks := 0;
          if FxEngine.RollDice(1, 100) <= GDVars.zone1^[$7ED3] then begin
            CharHlp.ClearMessageWindow;
            GameTime.DisplayRestTime(0);
            TextRend.DisplayString(1, 19, White, 0, 'Your repose is suddenly interrupted!');
            stop := True;
            CampRest := True;
            TextRend.PauseOnly;
          end;
        end;
      end;
    end;
  end;
  TextRend.ClearRect(1, 17, 38, 22);
  GDVars.noBorder := 0;
end;

begin
end.
