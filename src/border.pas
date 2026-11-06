{ Screen frames drawn from 8x8 border glyphs, and clearing of character-cell rectangles in video memory. The frames
  cover columns 0..39 and rows 0..23. }
{$O+,F+}
unit Border;

interface

uses TextRend, Sym8x8, GDConsts, GDVars;

{ Clears the screen inside the outer frame (columns 1..38, rows 1..22) and draws the outer frame: row 0, columns 0 and
  39, and the bottom row, row 23. }
procedure DrawWindowFrame;

{ Draws the outer frame with DrawWindowFrame, then horizontal rules across rows 3 and 8. Intro uses it for the credits
  screen. }
procedure DrawCreditsFrame;

{ Draws the exploration layout: the outer frame, a horizontal rule across row 16, a vertical rule down column 16 from
  row 0 to row 16, and an inner box on columns and rows 2..14. }
procedure DrawViewFrame;

{ Draws the outer frame with DrawWindowFrame and a horizontal rule across row 16. }
procedure DrawRowDivider;

{ Draws the outer frame and a horizontal rule across row 16, but clears only rows 1..16 inside the frame, leaving rows
  17..22 as they were. }
procedure DrawMemorizeFrame;

{ Clears the whole screen and draws the combat layout: row 0, columns 0, 22 and 39 from row 0 to row 22, and a bottom
  row across row 22. Row 23 is left blank. }
procedure DrawCombatFrame;

{ Draws the outer frame and a horizontal rule across row 2. }
procedure DrawTitleInset;

{ Clears a rectangle of character cells, corners included, to color 0 directly in video memory. CGA clears the four
  scanlines of each cell row in both of its banks, EGA clears both display pages through TextRend.FillRectEga, and Tandy
  clears two scanlines in each of its four banks.
  @param(ulCol Left column.)
  @param(ulRow Top row.)
  @param(lrCol Right column.)
  @param(lrRow Bottom row.) }
procedure ClearBox(ulCol, ulRow, lrCol, lrRow: ShortInt);

implementation

const
  { First 8x8 symbols of the outer and inner border glyph sets; glyph table entries are offsets from these. }
  OUTER_SYMBOL_BASE = 286;
  INNER_SYMBOL_BASE = 276;

procedure DrawWindowFrame;
var
  column: Byte;
  row: Byte;
begin
  Border.ClearBox(1, 1, 38, 22);
  for column := 0 to 39 do
    Sym8x8.Put8x8Sym(column, 0, GDConsts.borderGlyphs.top[column] + Border.OUTER_SYMBOL_BASE, False, False);
  for row := 0 to 23 do begin
    Sym8x8.Put8x8Sym(0, row, GDConsts.borderGlyphs.left[row] + Border.OUTER_SYMBOL_BASE, False, False);
    Sym8x8.Put8x8Sym(39, row, GDConsts.borderGlyphs.right[row] + Border.OUTER_SYMBOL_BASE, False, False);
  end;
  for column := 0 to 39 do
    Sym8x8.Put8x8Sym(column, 23, GDConsts.borderGlyphs.bottom[column] + Border.OUTER_SYMBOL_BASE, False, False);
end;

procedure DrawCreditsFrame;
var
  i: Byte;
begin
  Border.DrawWindowFrame;
  for i := 0 to 39 do begin
    Sym8x8.Put8x8Sym(i, 3, GDConsts.borderGlyphs.hrule[i] + Border.OUTER_SYMBOL_BASE, False, False);
    Sym8x8.Put8x8Sym(i, 8, GDConsts.borderGlyphs.hrule[i] + Border.OUTER_SYMBOL_BASE, False, False);
  end;
end;

procedure DrawViewFrame;
var
  i: Byte;
  j: Byte;
begin
  Border.DrawWindowFrame;
  for i := 0 to 39 do
    Sym8x8.Put8x8Sym(i, 16, GDConsts.borderGlyphs.hrule[i] + Border.OUTER_SYMBOL_BASE, False, False);
  for j := 0 to 16 do
    Sym8x8.Put8x8Sym(16, j, GDConsts.borderGlyphs.vrule[j] + Border.OUTER_SYMBOL_BASE, False, False);
  for i := 2 to 14 do begin
    Sym8x8.Put8x8Sym(i, 2, GDConsts.borderGlyphs.innTop[i] + Border.INNER_SYMBOL_BASE, False, False);
    Sym8x8.Put8x8Sym(i, 14, GDConsts.borderGlyphs.innBot[i] + Border.INNER_SYMBOL_BASE, False, False);
  end;
  for j := 2 to 14 do begin
    Sym8x8.Put8x8Sym(2, j, GDConsts.borderGlyphs.innLeft[j] + Border.INNER_SYMBOL_BASE, False, False);
    Sym8x8.Put8x8Sym(14, j, GDConsts.borderGlyphs.innRight[j] + Border.INNER_SYMBOL_BASE, False, False);
  end;
end;

procedure DrawRowDivider;
var
  column: Byte;
begin
  Border.DrawWindowFrame;
  for column := 0 to 39 do
    Sym8x8.Put8x8Sym(column, 16, GDConsts.borderGlyphs.hrule[column] + Border.OUTER_SYMBOL_BASE, False, False);
end;

procedure DrawMemorizeFrame;
var
  i: Byte;
  j: Byte;
begin
  Border.ClearBox(1, 1, 38, 16);
  for i := 0 to 39 do
    Sym8x8.Put8x8Sym(i, 0, GDConsts.borderGlyphs.top[i] + Border.OUTER_SYMBOL_BASE, False, False);
  for j := 0 to 23 do begin
    Sym8x8.Put8x8Sym(0, j, GDConsts.borderGlyphs.left[j] + Border.OUTER_SYMBOL_BASE, False, False);
    Sym8x8.Put8x8Sym(39, j, GDConsts.borderGlyphs.right[j] + Border.OUTER_SYMBOL_BASE, False, False);
  end;
  for i := 0 to 39 do
    Sym8x8.Put8x8Sym(i, 23, GDConsts.borderGlyphs.bottom[i] + Border.OUTER_SYMBOL_BASE, False, False);
  for i := 0 to 39 do
    Sym8x8.Put8x8Sym(i, 16, GDConsts.borderGlyphs.hrule[i] + Border.OUTER_SYMBOL_BASE, False, False);
end;

procedure DrawCombatFrame;
var
  column: Byte;
  row: Byte;
begin
  Border.ClearBox(0, 0, 39, 23);
  for column := 0 to 39 do
    Sym8x8.Put8x8Sym(column, 0, GDConsts.borderGlyphs.top[column] + Border.OUTER_SYMBOL_BASE, False, False);
  for row := 0 to 22 do begin
    Sym8x8.Put8x8Sym(0, row, GDConsts.borderGlyphs.cbLeft[row] + Border.OUTER_SYMBOL_BASE, False, False);
    Sym8x8.Put8x8Sym(22, row, GDConsts.borderGlyphs.cbMid[row] + Border.OUTER_SYMBOL_BASE, False, False);
    Sym8x8.Put8x8Sym(39, row, GDConsts.borderGlyphs.cbRight[row] + Border.OUTER_SYMBOL_BASE, False, False);
  end;
  for column := 0 to 39 do
    Sym8x8.Put8x8Sym(column, 22, GDConsts.borderGlyphs.bottom[column] + Border.OUTER_SYMBOL_BASE, False, False);
end;

procedure DrawTitleInset;
var
  column: Byte;
begin
  Border.DrawWindowFrame;
  for column := 0 to 39 do
    Sym8x8.Put8x8Sym(column, 2, GDConsts.borderGlyphs.hrule[column] + Border.OUTER_SYMBOL_BASE, False, False);
end;

procedure ClearBox(ulCol, ulRow, lrCol, lrRow: ShortInt);
var
  top: Word;
  bot: Word;
  colOff: Word;
  rowBytes: Word;
  { Unused in this version; see the other implementations of this routine. }
  cgaColOff: Word;
  r: Word;
begin
  case GDVars.displayMode of
    0: begin
      top := ulRow * 4;
      bot := lrRow * 4 + 3;
      rowBytes := (lrCol - ulCol + 1) * 2;
      for r := top to bot do begin
        FillChar(TextRend.cgaBank0.bytes[r][Word(ulCol) * 2], rowBytes, 0);
        FillChar(TextRend.cgaBank1.bytes[r][Word(ulCol) * 2], rowBytes, 0);
      end;
    end;
    1: begin
      TextRend.FillRectEga(ulCol, ulRow, lrCol, lrRow, 0, 0);
      TextRend.FillRectEga(ulCol, ulRow, lrCol, lrRow, 1, 0);
    end;
    2: begin
      top := ulRow * 2;
      bot := lrRow * 2 + 1;
      colOff := ulCol * 4;
      rowBytes := (lrCol - ulCol + 1) * 4;
      for r := top to bot do begin
        FillChar(TextRend.tandyBank0[r][colOff], rowBytes, 0);
        FillChar(TextRend.tandyBank1[r][colOff], rowBytes, 0);
        FillChar(TextRend.tandyBank2[r][colOff], rowBytes, 0);
        FillChar(TextRend.tandyBank3[r][colOff], rowBytes, 0);
      end;
    end;
  end;
end;

begin
end.
