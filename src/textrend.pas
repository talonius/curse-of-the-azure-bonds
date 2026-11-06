{ Text on the graphics screen: the 8x8 font, characters and strings, the word-wrapped message window, prompts and input
  on the bottom row, clearing, and EGA page setup. }
{$O+,F+,I-,R-,S-}
unit TextRend;

interface

uses DaxIo, Types, Crt, Dos, GameIo, GDConsts, GDVars, C_Keys, C_Ega, C_Video;

type
  { One CGA scanline bank of video memory: 100 scanlines of 80 bytes, which ClearRect clears as 40 words a scanline. }
  TCgaBank = record
    case Byte of
      0: (bytes: array[0..99, 0..79] of Byte);
      1: (words: array[0..99, 0..39] of Word);
  end;
  { One Tandy scanline bank of video memory: 50 scanlines of 160 bytes. }
  TTandyBank = array[0..49, 0..159] of Byte;

var
  { The scanline banks of CGA (two) and Tandy (four) video memory. }
  cgaBank0: TCgaBank absolute C_Video.GFX_BANK0_SEG:0;
  cgaBank1: TCgaBank absolute C_Video.GFX_BANK1_SEG:0;
  tandyBank0: TTandyBank absolute C_Video.GFX_BANK0_SEG:0;
  tandyBank1: TTandyBank absolute C_Video.GFX_BANK1_SEG:0;
  tandyBank2: TTandyBank absolute C_Video.GFX_BANK2_SEG:0;
  tandyBank3: TTandyBank absolute C_Video.GFX_BANK3_SEG:0;

{ Resets the EGA graphics controller (registers 0 to 5 to 0, color don't-care $0F, bit mask $FF) and enables writes to
  the four planes. }
procedure ResetEgaGc;

{ Shows an EGA page (video BIOS function 5) and points egaCurPage at its segment.
  @param(page The page to show.) }
procedure SetupEgaCurrentPage(page: Byte);

{ Points egaOtherPage at the segment of an EGA page.
  @param(page The page.) }
procedure SetupEgaOtherPage(page: Byte);

{ Fills a character-cell rectangle of an EGA page with one color in write mode 2, then restores write mode 0 and points
  egaOtherPage back at the current page (egaPageNumber).
  @param(ulCol Left column.)
  @param(ulRow Top row.)
  @param(lrCol Right column.)
  @param(lrRow Bottom row.)
  @param(page The EGA page to fill.)
  @param(color The fill color.) }
procedure FillRectEga(ulCol, ulRow, lrCol, lrRow: ShortInt; page, color: Byte);

{ Loads the 8x8 game font (block 201 of 8X8D1.DAX) into the font buffer; nothing happens when it is missing. }
procedure LoadGameFont;

{ Draws a run of one character rightward from a cell, with the display mode's glyph routine. Nothing is drawn when the
  first cell is off the 40x25 screen or there is no font; the run itself is not clipped.
  @param(col The first cell's column.)
  @param(row The cell row.)
  @param(fg The character's color.)
  @param(bg The background color.)
  @param(count How many times to draw it.)
  @param(ch The character, or a font index when isAscii is 0.)
  @param(isAscii Nonzero to upper-case ch and take it mod 64 as the font index.) }
procedure RenderChar(col, row, fg, bg, count, ch, isAscii: Byte);

{ Blanks a run of cells; nothing happens when the first cell is off the screen.
  @param(col The first cell's column.)
  @param(row The cell row.)
  @param(color The color to blank to.)
  @param(count The number of cells.) }
procedure PrintSpaces(col, row, color, count: Byte);

{ Writes a string from a cell, one character per cell; characters off the screen are not drawn.
  @param(col The first character's column.)
  @param(row The row.)
  @param(fg The text color.)
  @param(bg The background color.)
  @param(source The text.) }
procedure DisplayString(col, row, fg, bg: Byte; source: string);

{ Writes a string word-wrapped into a window, from the text cursor (curCol, curRow) when it is inside the window, else,
  or after clearing with clearFirst, from the top left. Punctuation (breakChars) stays with the word before it.
  Characters appear one by one with the typing delay while typingDelayOn is on. When the window fills with text left
  over, it waits for a key and goes on in the cleared window. The text cursor is left after the text. Note: the check
  meant to keep a word whose trailing space alone overruns the right edge can never hold, so such a word wraps as well.
  @param(ulCol Left column of the window.)
  @param(ulRow Top row of the window.)
  @param(lrCol Right column of the window.)
  @param(lrRow Bottom row of the window.)
  @param(fg The text color.)
  @param(bg The background color.)
  @param(clearFirst True to clear the window and start at its top left.)
  @param(source The text.) }
procedure DisplayMessageWindow(ulCol, ulRow, lrCol, lrRow, fg, bg: Byte; clearFirst: Boolean; source: string);

{ Shows a prompt on the bottom row and reads text, echoed in white: a space through z is added while there is room and
  backspace deletes, until Enter or Escape, or after the first key while the demo runs. The row is cleared afterwards.
  @param(query The prompt.)
  @param(fg The prompt's color.)
  @param(bg The prompt's background color.)
  @param(maxLen The most characters accepted.)
  @returns(The text typed, upper-cased; Escape returns it too.) }
function ReadString(query: Types.TStr40; fg, bg, maxLen: Byte): Types.TStr40;

{ Reads numbers of up to six characters (ReadString) until one parses within 0 to 65536. Note: 65536 is accepted and
  becomes 0.
  @param(query The prompt.)
  @param(fg The prompt's color.)
  @param(bg The prompt's background color.)
  @returns(The number.) }
function ReadNumber(query: Types.TStr40; fg, bg: Byte): Word;

{ Shows a message on the bottom row and waits for a key; the message stays.
  @param(fg The text color.)
  @param(bg The background color.)
  @param(msg The message.) }
procedure DisplayAndPause(fg, bg: Byte; msg: Types.TStr40);

{ Reads the time of day.
  @returns(The time since midnight in hundredths of a second.) }
function GetTicks: LongInt;

{ Clears the whole screen (both EGA pages). }
procedure ClearScreen;

{ Shows a message on the bottom row for gameDelay * 100 milliseconds (PauseOnly), then clears the row.
  @param(msg The message.)
  @param(fg The text color.)
  @param(bg The background color.) }
procedure PrintAndPause(msg: Types.TStr40; fg, bg: Byte);

{ Waits gameDelay * 100 milliseconds. }
procedure PauseOnly;

{ Clears a character-cell rectangle to black, on both EGA pages.
  @param(ulCol Left column.)
  @param(ulRow Top row.)
  @param(lrCol Right column.)
  @param(lrRow Bottom row.) }
procedure ClearRect(ulCol, ulRow, lrCol, lrRow: ShortInt);

implementation

const
  { Write mode 2: the low four bits of each CPU byte color the eight pixels it covers (bit n fills plane n). }
  GC_WRITE_MODE_2 = 2;

{$L TEXTREND.OBJ}
{$F-}
{ Draws one character cell on CGA from the glyph rows RenderChar staged in glyphBits.
  @param(col The cell column.)
  @param(row The cell row.)
  @param(ink The color of the glyph's set pixels.)
  @param(paper The color of its clear pixels.)
  @param(glyphIndex Unused.) }
procedure CgaGlyph(col, row: Word; ink, paper, glyphIndex: Byte); external;

{ Draws one character cell on EGA from the glyph rows RenderChar staged in glyphBits.
  @param(col The cell column.)
  @param(row The cell row.)
  @param(ink The color of the glyph's set pixels.)
  @param(paper The color of its clear pixels.)
  @param(glyphIndex Unused.) }
procedure EgaGlyph(col, row: Word; ink, paper, glyphIndex: Byte); external;

{ Draws one character cell on Tandy from the glyph rows RenderChar staged in glyphBits.
  @param(col The cell column.)
  @param(row The cell row.)
  @param(ink The color of the glyph's set pixels.)
  @param(paper The color of its clear pixels.)
  @param(glyphIndex Unused.) }
procedure TandyGlyph(col, row: Word; ink, paper, glyphIndex: Byte); external;
{$F+}

procedure ResetEgaGc;
begin
  Port[C_Ega.GC_ADDR_PORT] := 0; Port[C_Ega.GC_DATA_PORT] := 0;
  Port[C_Ega.GC_ADDR_PORT] := 1; Port[C_Ega.GC_DATA_PORT] := 0;
  Port[C_Ega.GC_ADDR_PORT] := 2; Port[C_Ega.GC_DATA_PORT] := 0;
  Port[C_Ega.GC_ADDR_PORT] := 3; Port[C_Ega.GC_DATA_PORT] := 0;
  Port[C_Ega.GC_ADDR_PORT] := C_Ega.GC_READ_MAP_REG; Port[C_Ega.GC_DATA_PORT] := 0;
  Port[C_Ega.GC_ADDR_PORT] := C_Ega.GC_MODE_REG; Port[C_Ega.GC_DATA_PORT] := C_Ega.GC_WRITE_MODE_0;
  Port[C_Ega.GC_ADDR_PORT] := 7; Port[C_Ega.GC_DATA_PORT] := $0F;
  Port[C_Ega.GC_ADDR_PORT] := 8; Port[C_Ega.GC_DATA_PORT] := $FF;
  Port[C_Ega.SEQ_ADDR_PORT] := C_Ega.SEQ_MAP_MASK_REG; Port[C_Ega.SEQ_DATA_PORT] := C_Ega.MAP_MASK_ALL_PLANES;
end;

procedure SetupEgaCurrentPage(page: Byte);
begin
  GDVars.videoRegs.ah := 5;
  GDVars.videoRegs.al := page;
  Intr($10, Registers(GDVars.videoRegs));
  GDVars.egaCurPage := C_Video.EGA_VIDEO_SEG + (Word(page) shl 9);
end;

procedure SetupEgaOtherPage(page: Byte);
begin
  GDVars.egaOtherPage := C_Video.EGA_VIDEO_SEG + (Word(page) shl 9);
end;

procedure FillRectEga(ulCol, ulRow, lrCol, lrRow: ShortInt; page, color: Byte);
var
  savedPage: Byte;
  dstOff: Word;
  rowCount: Word;
  i: Word;
begin
  savedPage := GDVars.egaPageNumber;
  dstOff := Word(ulRow) * 40 * 8 + ulCol;
  rowCount := (lrRow - ulRow + 1) * 8 - 1;
  TextRend.SetupEgaOtherPage(page);
  TextRend.ResetEgaGc;
  Port[C_Ega.GC_ADDR_PORT] := C_Ega.GC_MODE_REG;
  Port[C_Ega.GC_DATA_PORT] := TextRend.GC_WRITE_MODE_2;
  for i := 0 to rowCount do begin
    FillChar(Mem[GDVars.egaOtherPage:dstOff], lrCol - ulCol + 1, color);
    Inc(dstOff, 40);
  end;
  Port[C_Ega.GC_ADDR_PORT] := C_Ega.GC_MODE_REG;
  Port[C_Ega.GC_DATA_PORT] := C_Ega.GC_WRITE_MODE_0;
  GDVars.egaPageNumber := savedPage;
  TextRend.SetupEgaOtherPage(GDVars.egaPageNumber);
end;

procedure LoadGameFont;
var
  size: Word;
  p: Types.PByteArr;
begin
  DaxIo.LoadDax('8X8d1', '.dax', 201, size, p);
  if size = 0 then Exit;
  Move(p^, GDVars.gameFont^, size);
  FreeMem(p, size);
end;

procedure RenderChar(col, row, fg, bg, count, ch, isAscii: Byte);
var
  i: Byte;
  charIdx: Byte;
  { Unused in this version; see the other implementations of this routine. }
  dstOff: Word;
  { Unused in this version; see the other implementations of this routine. }
  cnt: Word;
  { Unused in this version; see the other implementations of this routine. }
  colBase: Word;
  { Unused in this version; see the other implementations of this routine. }
  cgaWord: Word;
  { Unused in this version; see the other implementations of this routine. }
  tandyPx: Byte;
  { Unused in this version; see the other implementations of this routine. }
  k: Byte;
  { Unused in this version; see the other implementations of this routine. }
  mask: Byte;
  { Unused in this version; see the other implementations of this routine. }
  bank: Byte;
  { Unused in this version; see the other implementations of this routine. }
  outerRow: Byte;
  { Unused in this version; see the other implementations of this routine. }
  plane: Byte;
begin
  if (col > 39) or (row > 24) or (GDVars.gameFont = nil) then Exit;
  if isAscii <> 0 then
    charIdx := Ord(UpCase(Chr(ch))) mod 64
  else
    charIdx := ch;
  Move(GDVars.gameFont^[charIdx], GDVars.glyphBits, SizeOf(GDVars.glyphBits));
  case Char(GDVars.displayMode) of
    #0: begin
      for i := 1 to count do begin
        TextRend.CgaGlyph(col, row, fg, bg, charIdx);
        Inc(col);
      end;
    end;
    #1: begin
      for i := 1 to count do begin
        TextRend.EgaGlyph(col, row, fg, bg, charIdx);
        Inc(col);
      end;
    end;
    #2: begin
      for i := 1 to count do begin
        TextRend.TandyGlyph(col, row, fg, bg, charIdx);
        Inc(col);
      end;
    end;
  end;
end;

procedure PrintSpaces(col, row, color, count: Byte);
begin
  if (col < 0) or (col > 39) or (row < 0) or (row > 24) then Exit;
  TextRend.RenderChar(col, row, color, color, count, 32, 1);
end;

procedure DisplayString(col, row, fg, bg: Byte; source: string);
var
  n: Byte;
  i: Byte;
begin
  if (col > 39) or (row > 39) then Exit;
  n := Length(source);
  for i := 1 to n do begin
    TextRend.RenderChar(col, row, fg, bg, 1, Ord(source[i]), 1);
    Inc(col);
  end;
end;

procedure DisplayMessageWindow(ulCol, ulRow, lrCol, lrRow, fg, bg: Byte; clearFirst: Boolean; source: string);
var
  len: Byte;
  { Unused in this version; see the other implementations of this routine. }
  width: Byte;
  idx: Byte;
  lineEnd: Byte;
  { Unused in this version; see the other implementations of this routine. }
  lineStart: Byte;

  { Prints the characters from idx to lineEnd at the text cursor, with the typing delay while typingDelayOn is on. }
  procedure PrintCharInWindow;
  begin
    while idx <= lineEnd do begin
      TextRend.RenderChar(GDVars.curCol, GDVars.curRow, fg, bg, 1, Ord(source[idx]), 1);
      if GDVars.typingDelayOn then Delay(GDVars.gameDelay * 3);
      Inc(idx);
      Inc(GDVars.curCol);
    end;
  end;

  { Skips the spaces from idx. }
  procedure FindNewIndex;
  begin
    while (idx < len) and (source[idx] = ' ') do Inc(idx);
  end;

begin
  if (ulCol > 39) or (ulRow > 24) or (lrCol > 39) or (lrRow > 39) then Exit;
  if (GDVars.curCol < ulCol) or (GDVars.curCol > lrCol) or (GDVars.curRow < ulRow) or
      (GDVars.curRow > lrRow) then begin
    GDVars.curCol := ulCol;
    GDVars.curRow := ulRow;
  end;
  if clearFirst then begin
    TextRend.ClearRect(ulCol, ulRow, lrCol, lrRow);
    GDVars.curCol := ulCol;
    GDVars.curRow := ulRow;
  end;
  idx := 1;
  len := Length(source);
  if len = 0 then Exit;
  width := lrCol - ulCol + 1;
  repeat
    lineEnd := idx;
    while (lineEnd < len) and (source[lineEnd] in GDConsts.breakChars) do
      Inc(lineEnd);
    while (lineEnd < len) and not (source[lineEnd] in GDConsts.breakChars) and (source[lineEnd] <> ' ') do
      Inc(lineEnd);
    if source[lineEnd] <> ' ' then
      while (lineEnd + 1 < len) and (source[lineEnd + 1] in GDConsts.breakChars) do
        Inc(lineEnd);
    if lineEnd - idx + GDVars.curCol > lrCol then begin
      if (lineEnd - idx + GDVars.curCol = lrCol) and (source[lineEnd] = ' ') then begin
        Dec(lineEnd);
        PrintCharInWindow;
      end;
      GDVars.curCol := ulCol;
      Inc(GDVars.curRow);
      FindNewIndex;
      if (GDVars.curRow > lrRow) and (idx < len) then begin
        GDVars.curCol := ulCol;
        GDVars.curRow := ulRow;
        TextRend.DisplayAndPause(LightMagenta, 0, 'Press any key to continue');
        GameIo.DiscardPendingKeys;
        TextRend.ClearRect(ulCol, ulRow, lrCol, lrRow);
        PrintCharInWindow;
      end;
    end else
      PrintCharInWindow;
  until idx > len;
  if GDVars.curCol > lrCol then begin
    GDVars.curCol := ulCol;
    Inc(GDVars.curRow);
  end;
end;

function ReadString(query: Types.TStr40; fg, bg, maxLen: Byte): Types.TStr40;
var
  col: Byte;
  entry: string;
  key: Char;
begin
  TextRend.PrintSpaces(0, 24, 0, 40);
  TextRend.DisplayString(0, 24, fg, bg, query);
  col := Length(query);
  entry := '';
  repeat
    key := GameIo.ReadGameKey;
    case key of
      ' '..'z':
        if Length(entry) < maxLen then begin
          entry := entry + key;
          Inc(col);
          TextRend.DisplayString(col, 24, White, 0, key);
        end;
      C_Keys.BACKSPACE:
        if Length(entry) > 0 then begin
          entry := Copy(entry, 1, Length(entry) - 1);
          TextRend.PrintSpaces(col, 24, 0, 1);
          Dec(col);
        end;
    end;
  until (key = C_Keys.ENTER) or (key = C_Keys.ESCAPE) or GDVars.demoMode;
  TextRend.PrintSpaces(0, 24, 0, 40);
  for col := 1 to Length(entry) do
    entry[col] := UpCase(entry[col]);
  ReadString := entry;
end;

function ReadNumber(query: Types.TStr40; fg, bg: Byte): Word;
var
  num: LongInt;
  entry: Types.TStr40;
  code: Integer;
begin
  repeat
    entry := TextRend.ReadString(query, fg, bg, 6);
    Val(entry, num, code);
    if code = 0 then
      if (num > 65536) or (num < 0) then code := 1;
  until code = 0;
  ReadNumber := num;
end;

procedure DisplayAndPause(fg, bg: Byte; msg: Types.TStr40);
var
  { Unused in this version; see the other implementations of this routine. }
  key: Char;
begin
  TextRend.PrintSpaces(0, 24, 0, 40);
  TextRend.DisplayString(0, 24, fg, bg, msg);
  key := GameIo.ReadGameKey;
end;

function GetTicks: LongInt;
var
  h: Word;
  m: Word;
  s: Word;
  hundredths: Word;
begin
  GetTime(h, m, s, hundredths);
  GetTicks := LongInt(h) * 360000 + LongInt(m) * 6000 + LongInt(s) * 100 + hundredths;
end;

procedure ClearScreen;
begin
  case Char(GDVars.displayMode) of
    #0: begin
      FillChar(cgaBank1, SizeOf(cgaBank1), 0);
      FillChar(cgaBank0, SizeOf(cgaBank0), 0);
    end;
    #1: begin
      TextRend.FillRectEga(0, 0, 39, 24, 0, 0);
      TextRend.FillRectEga(0, 0, 39, 24, 1, 0);
    end;
    #2: begin
      FillChar(tandyBank0, SizeOf(tandyBank0), 0);
      FillChar(tandyBank1, SizeOf(tandyBank1), 0);
      FillChar(tandyBank2, SizeOf(tandyBank2), 0);
      FillChar(tandyBank3, SizeOf(tandyBank3), 0);
    end;
  end;
end;

procedure PrintAndPause(msg: Types.TStr40; fg, bg: Byte);
begin
  TextRend.PrintSpaces(0, 24, 0, 40);
  TextRend.DisplayString(0, 24, fg, bg, msg);
  TextRend.PauseOnly;
  TextRend.PrintSpaces(0, 24, 0, 40);
end;

procedure PauseOnly;
begin
  Delay(GDVars.gameDelay * 100);
end;

procedure ClearRect(ulCol, ulRow, lrCol, lrRow: ShortInt);
var
  firstRow: Word;
  lastRow: Word;
  firstByteColumn: Word;
  byteCount: Word;
  row: Word;
begin
  case Char(GDVars.displayMode) of
    #0: begin
      firstRow := ulRow * 4;
      lastRow := lrRow * 4 + 3;
      byteCount := (lrCol - ulCol + 1) * 2;
      for row := firstRow to lastRow do begin
        FillChar(cgaBank0.words[row][ulCol], byteCount, 0);
        FillChar(cgaBank1.words[row][ulCol], byteCount, 0);
      end;
    end;
    #1: begin
      TextRend.FillRectEga(ulCol, ulRow, lrCol, lrRow, 0, 0);
      TextRend.FillRectEga(ulCol, ulRow, lrCol, lrRow, 1, 0);
    end;
    #2: begin
      firstRow := ulRow * 2;
      lastRow := lrRow * 2 + 1;
      firstByteColumn := ulCol * 4;
      byteCount := (lrCol - ulCol + 1) * 4;
      for row := firstRow to lastRow do begin
        FillChar(tandyBank0[row][firstByteColumn], byteCount, 0);
        FillChar(tandyBank1[row][firstByteColumn], byteCount, 0);
        FillChar(tandyBank2[row][firstByteColumn], byteCount, 0);
        FillChar(tandyBank3[row][firstByteColumn], byteCount, 0);
      end;
    end;
  end;
end;

begin
end.
