{ The menus: the one-line horizontal menu on the bottom row (with the blinking overland cursor and the portrait
  animation while it waits), the windowed vertical menu over a string list, the yes/no prompt, and the string lists
  themselves. }
{$O+,F+}
{$A-}
unit MenuCore;

interface

uses Types, TextRend, GameIo, Crt, Portrait, Border, EclTrace, MapCurs, GDConsts, GDVars, C_Keys, C_Ifc, C_Pic, C_Gbvm;

{ Finds a member of a string list by position.
  @param(index The member's position, counting from 0.)
  @param(list The list's first member.)
  @returns(The member, or nil when the list is shorter.) }
function FindListMember(index: Integer; list: Types.PItem): Types.PItem;

{ Counts the members of a string list.
  @param(list The list's first member, or nil.)
  @returns(The number of members.) }
function ListCount(list: Types.PItem): Integer;

{ Shows query and a one-line menu on the bottom row and waits for a choice. Each option starts at a digit or capital
  letter, its hotkey, drawn in hlCol; the highlighted option (menuChoice, kept between calls) is drawn inverse. ',' and
  '.' move the highlight, wrapping; a hotkey picks its option; Enter takes the highlighted option when mCol or hlCol is
  set; Space returns ' ' and Escape #0; other keys are ignored. While it waits, the overland cursor blinks when the
  overland map picture is up in the overland interface and the village picture is not, and the portrait animation plays
  when the script's animation request or animate asks for it and frames are loaded. Once menuTimeout ticks pass with no
  new animation frame, the auto key (menuDefaultKey) is returned. The animation request is cleared on return, and
  menuExtendedKey mirrors ext.
  @param(query Text shown first, in qCol; empty for none.)
  @param(menu The options.)
  @param(qCol Color of the query.)
  @param(mCol Color of the option text.)
  @param(hlCol Color of the hotkeys and the highlight; 0 for no highlight.)
  @param(reinterpret True to return extended keys as scan codes, and the digits 1 to 9 and the backslash as keypad scan
    codes; False ignores extended keys.)
  @param(animate True to play the portrait animation.)
  @param(ext Set when the result is a scan code.)
  @returns(The chosen option's hotkey, a space, #0 for Escape, the auto key or a scan code.) }
function MenuHorizontal(query, menu: Types.TStr40; qCol, mCol, hlCol: Byte; reinterpret, animate: Boolean;
                        var ext: Boolean): Char;

{ Blanks the bottom text row. }
procedure ClearBottomLine;

{ Runs a menu over a string list in a window. Members with inUse set are labels, drawn in qCol and skipped by the
  highlight; the others are choices, drawn in mCol. A horizontal menu on the bottom row (MenuHorizontal) takes the
  command: menu's options, then Next when a later page exists, Prev when the page top is past the leading labels, and
  Exit with addExit. Home and End move the highlight up and down, wrapping within the page; Page Up and Page Down turn
  pages when Prev and Next are offered, P and N whether or not they are. The page top (verticalMenuTop) is kept between
  calls; it is pulled back to idx when it lies past it, and to 0 when it lies past the end of the list. menuChoice
  starts at 1. Note: the highlight wraps within the page without checking the end of the list, so on a short last page
  it can move past the last member.
  @param(query Text shown before the command menu.)
  @param(menu The command menu's own options.)
  @param(qCol Color of the query and the labels.)
  @param(mCol Color of the choices and the command menu.)
  @param(hlCol Color of the highlight and the hotkeys.)
  @param(ulCol Left column of the window.)
  @param(ulRow Top row of the window.)
  @param(lrCol Right column of the window.)
  @param(lrRow Bottom row of the window.)
  @param(list The list's first member; nil returns at once.)
  @param(addExit True to offer Exit.)
  @param(redraw True to redraw the window first, which a page top pulled back also forces; cleared on return unless list
    is nil.)
  @param(idx The highlighted member, counting from 0, kept between calls; set to 0 for an empty list.)
  @param(sel Receives the highlighted member when a command is chosen, or nil.)
  @returns(The command key, or #0 for Escape, Exit or an empty list.) }
function MenuVertical(query, menu: Types.TStr40; qCol, mCol, hlCol: Byte; ulCol, ulRow, lrCol, lrRow: ShortInt;
                      list: Types.PItem; addExit: Boolean; var redraw: Boolean; var idx: Integer; var sel:
                          Types.PItem): Char;

{ Asks query with a Yes/No menu, No highlighted first, until Y or N is chosen; Escape does not leave it.
  @param(query The question.)
  @param(qCol Color of the question.)
  @param(mCol Color of the options.)
  @param(hlCol Color of the hotkeys and the highlight.)
  @returns('Y' or 'N'.) }
function YesNoMenu(query: Types.TStr40; qCol, mCol, hlCol: Byte): Char;

{ Allocates a string list of empty choice members.
  @param(count The number of members; below 2 gives one.)
  @param(list Receives the first member.) }
procedure AllocStringList(count: Integer; var list: Types.PItem);

{ Frees each member of a string list; list itself is not set to nil.
  @param(list The list's first member, or nil.) }
procedure FreeStringList(var list: Types.PItem);

{ Calls the priming entries of Portrait and the trace overlay, so the overlay manager loads them; the other overlays
  this unit uses are not primed here. }
procedure PrimeMenuCore;

implementation

type
  { One horizontal-menu option: the positions of its first and last characters in the menu text. }
  TOptRange = record
    first: Byte;
    last: Byte;
  end;

procedure PrimeMenuCore;
begin
  Portrait.PrimePortrait;
  EclTrace.PrimeEclTrace;
end;

function FindListMember(index: Integer; list: Types.PItem): Types.PItem;
var
  p: Types.PItem;
  i: Integer;
begin
  i := 0;
  p := list;
  while (p <> nil) and (i <> index) do begin
    p := p^.next;
    Inc(i);
  end;
  if i = index then
    FindListMember := p
  else
    FindListMember := nil;
end;

function ListCount(list: Types.PItem): Integer;
var
  p: Types.PItem;
  n: Integer;
begin
  n := 0;
  p := list;
  while p <> nil do begin
    Inc(n);
    p := p^.next;
  end;
  ListCount := n;
end;

function MenuHorizontal(query, menu: Types.TStr40; qCol, mCol, hlCol: Byte; reinterpret, animate: Boolean;
                        var ext: Boolean): Char;
var
  frameTick: LongInt;
  cursorOnTick: LongInt;
  cursorOffTick: LongInt;
  ch: Char;
  j: Byte;
  i: Byte;
  done: Boolean;
  mLen: Byte;
  qLen: Byte;
  opt: array[1..20] of TOptRange;
  optCnt: Byte;
  enterOk: Boolean;

  { Splits menuText into options (opt, optCnt), each starting at a digit or capital letter, its hotkey. }
  procedure ParseMenu(menuText: Types.TStr40);
  var
    idx: Byte;
    i: Byte;
    len: Byte;
    { Unused in this version; see the other implementations of this routine. }
    hotkey: Byte;
  begin
    FillChar(opt, SizeOf(opt), 0);
    idx := 1;
    len := Length(menuText);
    for i := 1 to len do
      if menuText[i] in ['0'..'9', 'A'..'Z'] then
        if opt[idx].first = 0 then
          opt[idx].first := i
        else begin
          opt[idx].last := i - 2;
          Inc(idx);
          opt[idx].first := i;
        end;
    opt[idx].last := len;
    optCnt := idx;
  end;

  { Redraws the menu after the query with option cur highlighted and the hotkeys in hlCol, and blanks the rest. }
  procedure DisplayOption(cur: Byte);
  var
    i: Byte;
  begin
    if mLen > 0 then begin
      for i := 1 to mLen do
        if (opt[cur].first <= i) and (opt[cur].last >= i)
           and (hlCol <> 0) then
          TextRend.RenderChar(qLen + i - 1, 24, 0, hlCol, 1, Ord(menu[i]), 1)
        else if menu[i] in ['0'..'9', 'A'..'Z'] then
          TextRend.RenderChar(qLen + i - 1, 24, hlCol, 0, 1, Ord(menu[i]), 1)
        else
          TextRend.RenderChar(qLen + i - 1, 24, mCol, 0, 1, Ord(menu[i]), 1);
      if qLen + mLen < 39 then
        TextRend.RenderChar(qLen + mLen, 24, Black, 0, 39 - mLen - qLen + 1, 32, 1);
    end;
  end;

begin
  GDVars.menuExtendedKey := False;
  enterOk := (mCol <> 0) or (hlCol <> 0);
  ParseMenu(menu);
  if GDVars.menuChoice > optCnt then
    GDVars.menuChoice := 1;
  mLen := Length(menu);
  ch := C_Keys.NONE;
  ext := False;
  done := False;
  frameTick := TextRend.GetTicks;
  cursorOnTick := TextRend.GetTicks + 30;
  cursorOffTick := cursorOnTick + 50;
  if Length(query) <> 0 then
    TextRend.DisplayString(0, 24, qCol, 0, query);
  qLen := Length(query) + 0;
  DisplayOption(GDVars.menuChoice);
  if (GDVars.ifcState = C_Ifc.OVERLAND) and (GDVars.bigPicId = C_Pic.BIGPIC_OVERLAND) and
      (GDVars.loadedPicId <> C_Pic.VILLAGE) then begin
    MapCurs.SetCursorPosition;
    MapCurs.DrawCursor;
    MapCurs.RestoreCursorBackground;
  end;
  repeat
    if (GDVars.ifcState = C_Ifc.OVERLAND) and (GDVars.bigPicId = C_Pic.BIGPIC_OVERLAND) and
        (GDVars.loadedPicId <> C_Pic.VILLAGE) then
      if TextRend.GetTicks >= cursorOnTick then begin
        MapCurs.DrawCursor;
        cursorOnTick := cursorOffTick + 30;
      end;
    { Play idle animation when requested by the script or caller and frames are loaded. }
    if ((GDVars.zone0^[C_Gbvm.ANIM_REQUEST] <> 0) or animate) and (GDVars.animData.current > 0) then begin
      Portrait.DisplayImageBuf(3, 3, animate, GDVars.animData.frames[GDVars.animData.current].pic);
      if (TextRend.GetTicks - frameTick >= GDVars.animData.frames[GDVars.animData.current].time * 10)
         or (GDVars.zone0^[C_Gbvm.ANIM_REQUEST] <> 0) then begin
        Inc(GDVars.animData.current);
        if GDVars.animData.current > GDVars.animData.count then
          GDVars.animData.current := 1;
        frameTick := TextRend.GetTicks;
      end;
    end;
    if (GDVars.menuTimeout > 0)
       and (TextRend.GetTicks - frameTick >= GDVars.menuTimeout) then begin
      ch := GDVars.menuDefaultKey;
      done := True;
    end else if keyPressed then begin
      ch := GameIo.ReadGameKey;
      if ch = #0 then begin
        ch := GameIo.ReadGameKey;
        if reinterpret then begin
          ext := True;
          done := True;
        end;
      end else
        case ch of
          C_Keys.ESCAPE: begin
                 done := True;
                 ch := C_Keys.NONE;
               end;
          C_Keys.ENTER: if enterOk then begin
                 ch := menu[opt[GDVars.menuChoice].first];
                 if ch = #0 then
                   ch := C_Keys.ENTER;
                 done := True;
               end;
          ',': begin
                 if GDVars.menuChoice = 1 then
                   GDVars.menuChoice := optCnt
                 else
                   Dec(GDVars.menuChoice);
                 DisplayOption(GDVars.menuChoice);
               end;
          '.': begin
                 if GDVars.menuChoice = optCnt then
                   GDVars.menuChoice := 1
                 else
                   Inc(GDVars.menuChoice);
                 DisplayOption(GDVars.menuChoice);
               end;
        else begin
            ch := UpCase(ch);
            if ch in [' ', '0'..'9', 'A'..'Z'] then
              if ch = ' ' then
                done := True
              else
                for i := 1 to mLen do
                  if menu[i] = ch then begin
                    done := True;
                    j := 1;
                    while opt[j].first <> i do
                      Inc(j);
                    GDVars.menuChoice := j;
                    DisplayOption(GDVars.menuChoice);
                  end;
            if reinterpret then
              if ch in ['1'..'9', '\'] then
              begin
                if ch = '\' then
                  ch := #55
                else
                  ch := Char(GDConsts.keypadScanCodes[Ord(ch) - Ord('1')]);
                ext := True;
                done := True;
              end;
          end;
        end;
    end;
    if (GDVars.ifcState = C_Ifc.OVERLAND) and (GDVars.bigPicId = C_Pic.BIGPIC_OVERLAND) and
        (GDVars.loadedPicId <> C_Pic.VILLAGE) then
      if TextRend.GetTicks >= cursorOffTick then begin
        MapCurs.RestoreCursorBackground;
        cursorOffTick := cursorOnTick + 50;
      end;
  until done;
  GDVars.zone0^[C_Gbvm.ANIM_REQUEST] := 0;
  if (GDVars.ifcState = C_Ifc.OVERLAND) and (GDVars.bigPicId = C_Pic.BIGPIC_OVERLAND) and
      (GDVars.loadedPicId <> C_Pic.VILLAGE) then
    MapCurs.RestoreCursorBackground;
  MenuHorizontal := ch;
  GDVars.menuExtendedKey := ext;
end;

procedure ClearBottomLine;
begin
  TextRend.PrintSpaces(0, 24, Black, 40);
end;

function MenuVertical(query, menu: Types.TStr40; qCol, mCol, hlCol: Byte; ulCol, ulRow, lrCol, lrRow: ShortInt;
                      list: Types.PItem; addExit: Boolean; var redraw: Boolean; var idx: Integer; var sel:
                          Types.PItem): Char;
var
  width: Byte;
  count: Integer;
  ext: Boolean;
  rows: Integer;
  ch: Char;
  hMenu: Types.TStr40;
  hasNext: Boolean;
  hasPrev: Boolean;
  p: Types.PItem;
  headerCnt: Integer;
  total: Integer;

  { Returns the last label among the first limit members, else the first member if it is a label, else nil. }
  function LastLabelBefore(limit: Integer; head: Types.PItem): Types.PItem;
  var
    pp: Types.PItem;
    found: Types.PItem;
    i: Integer;
  begin
    i := 0;
    pp := head;
    found := nil;
    while (pp <> nil) and (i < limit) do begin
      if pp^.inUse <> 0 then
        found := pp;
      pp := pp^.next;
      Inc(i);
    end;
    if (found = nil) and (head^.inUse <> 0) then
      LastLabelBefore := head
    else
      LastLabelBefore := found;
  end;

  { Clears the window and draws one member per row from member top on, labels in qCol and choices in mCol. }
  procedure DrawPage(top: Integer);
  var
    pp: Types.PItem;
    { Unused in this version; see the other implementations of this routine. }
    q: Types.PItem;
    row: ShortInt;
  begin
    Border.ClearBox(ulCol, ulRow, lrCol, lrRow);
    pp := MenuCore.FindListMember(top, list);
    q := LastLabelBefore(top, list);
    row := ulRow;
    while (pp <> nil) and (row <= lrRow) do begin
      if pp^.inUse <> 0 then
        TextRend.DisplayString(ulCol, row, qCol, 0, pp^.name)
      else
        TextRend.DisplayString(ulCol, row, mCol, 0, pp^.name);
      if Length(pp^.name) < width then
        TextRend.RenderChar(ulCol + Length(pp^.name), row, Black, 0, width - Length(pp^.name), 32, 1);
      pp := pp^.next;
      Inc(row);
    end;
  end;

  { Returns the position of the first non-space character of itemName (its length when all spaces, 1 when empty). }
  function FirstNonBlank(itemName: Types.TStr40): Byte;
  var
    i: Byte;
    len: Byte;
  begin
    i := 1;
    len := Length(itemName);
    while (i < len) and (itemName[i] = ' ') do
      Inc(i);
    FirstNonBlank := i;
  end;

  { Returns the position of the last non-space character of itemName (1 when all spaces, 0 when empty). }
  function LastNonBlank(itemName: Types.TStr40): Byte;
  var
    n: Byte;
  begin
    n := Length(itemName);
    while (n > 1) and (itemName[n] = ' ') do
      Dec(n);
    LastNonBlank := n;
  end;

  { Redraws member memberIndex, trimmed of spaces, inverse in hlCol. }
  procedure HighlightLine(memberIndex: Integer);
  var
    pp: Types.PItem;
    a: Byte;
    b: Byte;
  begin
    pp := MenuCore.FindListMember(memberIndex, list);
    a := FirstNonBlank(pp^.name);
    b := LastNonBlank(pp^.name) - a + 1;
    { Inverse video: black on hlCol. }
    TextRend.DisplayString(ulCol + a - 1, ulRow + (memberIndex - GDVars.verticalMenuTop), 0, hlCol,
                           Copy(pp^.name, a, b));
  end;

  { Redraws member memberIndex, trimmed of spaces, in its resting color (qCol for a label, mCol otherwise). }
  procedure UnhighlightLine(memberIndex: Integer);
  var
    pp: Types.PItem;
    a: Byte;
    b: Byte;
  begin
    pp := MenuCore.FindListMember(memberIndex, list);
    a := FirstNonBlank(pp^.name);
    b := LastNonBlank(pp^.name) - a + 1;
    if pp^.inUse <> 0 then
      TextRend.DisplayString(ulCol + a - 1, ulRow + (memberIndex - GDVars.verticalMenuTop), qCol, 0,
                             Copy(pp^.name, a, b))
    else
      TextRend.DisplayString(ulCol + a - 1, ulRow + (memberIndex - GDVars.verticalMenuTop), mCol, 0,
                             Copy(pp^.name, a, b));
  end;

  { Moves the highlight off labels, wrapping within the page, for at most a page of steps. }
  procedure SkipLabels(down: Boolean);
  var
    k: Integer;
  begin
    k := 0;
    if down then begin
      while (k < rows)
            and (MenuCore.FindListMember(idx, list)^.inUse <> 0) do begin
        Inc(k);
        Inc(idx);
        if GDVars.verticalMenuTop + rows - 1 < idx then
          idx := GDVars.verticalMenuTop;
      end;
    end else
      while (k < rows)
            and (MenuCore.FindListMember(idx, list)^.inUse <> 0) do begin
        Inc(k);
        Dec(idx);
        if idx < GDVars.verticalMenuTop then
          idx := GDVars.verticalMenuTop + rows - 1;
      end;
  end;

  { Turns a page down or up, keeping the highlight on the same row, then moves it off labels and redraws the window. }
  procedure MovePage(down: Boolean);
  var
    rel: Integer;
  begin
    rel := idx - GDVars.verticalMenuTop;
    if down then begin
      Inc(GDVars.verticalMenuTop, rows);
      if count - rows < GDVars.verticalMenuTop then
        GDVars.verticalMenuTop := count - rows;
    end else begin
      Dec(GDVars.verticalMenuTop, rows);
      if GDVars.verticalMenuTop < 0 then
        GDVars.verticalMenuTop := 0;
    end;
    idx := GDVars.verticalMenuTop + rel;
    SkipLabels(down);
    DrawPage(GDVars.verticalMenuTop);
  end;

  { Moves the highlight one member down or up, wrapping within the page, then off labels. }
  procedure MoveLine(down: Boolean);
  var
    { Unused in this version; see the other implementations of this routine. }
    pp: Types.PItem;
    { Unused in this version; see the other implementations of this routine. }
    k: Integer;
    { Unused in this version; see the other implementations of this routine. }
    n: Integer;
  begin
    if down then begin
      Inc(idx);
      if GDVars.verticalMenuTop + rows - 1 < idx then
        idx := GDVars.verticalMenuTop;
    end else begin
      Dec(idx);
      if idx < GDVars.verticalMenuTop then
        idx := GDVars.verticalMenuTop + rows - 1;
    end;
    SkipLabels(down);
  end;

begin
  if list = nil then begin
    idx := 0;
    sel := nil;
    MenuVertical := C_Keys.NONE;
  end else begin
    GDVars.menuChoice := 1;
    width := lrCol - ulCol + 1;
    count := MenuCore.ListCount(list);
    rows := lrRow - ulRow + 1;
    p := list;
    headerCnt := 0;
    while (p <> nil) and (p^.inUse <> 0) do begin
      p := p^.next;
      Inc(headerCnt);
    end;
    p := list;
    total := 0;
    while p <> nil do begin
      p := p^.next;
      Inc(total);
    end;
    if GDVars.verticalMenuTop > idx then begin
      GDVars.verticalMenuTop := idx;
      redraw := True;
    end;
    if GDVars.verticalMenuTop > total then begin
      GDVars.verticalMenuTop := 0;
      redraw := True;
    end;
    Inc(idx);
    MoveLine(False);
    if redraw then
      DrawPage(GDVars.verticalMenuTop);
    redraw := False;
    repeat
      HighlightLine(idx);
      hMenu := menu;
      hasNext := False;
      hasPrev := False;
      if count - rows > GDVars.verticalMenuTop then begin
        hMenu := hMenu + ' Next';
        hasNext := True;
      end;
      if GDVars.verticalMenuTop > headerCnt then begin
        hMenu := hMenu + ' Prev';
        hasPrev := True;
      end;
      if addExit then
        hMenu := hMenu + ' Exit';
      ch := MenuCore.MenuHorizontal(query, hMenu, qCol, mCol, hlCol, True, False, ext);
      UnhighlightLine(idx);
      if ext then
        case ch of
          C_Keys.HOME: MoveLine(False);
          C_Keys.END_KEY: MoveLine(True);
          C_Keys.PAGE_UP: if hasPrev then MovePage(False);
          C_Keys.PAGE_DOWN: if hasNext then MovePage(True);
        end else
        case ch of
          'P': MovePage(False);
          'N': MovePage(True);
          C_Keys.ESCAPE, 'E', C_Keys.NONE:
            begin
              sel := nil;
              MenuVertical := C_Keys.NONE;
              Exit;
            end;
        else begin
            sel := MenuCore.FindListMember(idx, list);
            MenuVertical := ch;
            Exit;
          end;
        end;
    until False;
  end;
end;

function YesNoMenu(query: Types.TStr40; qCol, mCol, hlCol: Byte): Char;
var
  ext: Boolean;
  ch: Char;
begin
  GDVars.menuChoice := 2;
  repeat
    ch := MenuCore.MenuHorizontal(query, 'Yes No', qCol, mCol, hlCol, False, False, ext);
  until ch in ['Y', 'N'];
  YesNoMenu := ch;
end;

procedure AllocStringList(count: Integer; var list: Types.PItem);
var
  p: Types.PItem;
  i: Integer;
begin
  GetMem(list, SizeOf(Types.TItemNode));
  list^.next := nil;
  list^.inUse := 0;
  list^.name := '';
  p := list;
  for i := 2 to count do begin
    GetMem(p^.next, SizeOf(Types.TItemNode));
    p := p^.next;
    p^.next := nil;
    p^.inUse := 0;
    p^.name := '';
  end;
end;

procedure FreeStringList(var list: Types.PItem);
var
  p: Types.PItem;
  q: Types.PItem;
begin
  p := list;
  while p <> nil do begin
    q := p;
    p := p^.next;
    FreeMem(q, SizeOf(Types.TItemNode));
  end;
end;

begin
end.
