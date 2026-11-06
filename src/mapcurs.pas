{ The overland-map cursor that blinks while a horizontal menu waits for a key; its cell comes from the cursor tables,
  indexed by the overland location the script sets. }
{$O+,F+}
{$A+}
unit MapCurs;

interface

{ Empty routine with no callers. }
procedure NoopMapCursA;

{ Empty routine with no callers. }
procedure NoopMapCursB;

{ Sets the cursor's screen cell from the cursor tables, indexed by the party's overland location that the script sets. }
procedure SetCursorPosition;

{ Saves the background at the cursor's cell, then draws the cursor image there. }
procedure DrawCursor;

{ Puts back the background saved by DrawCursor, erasing the cursor. }
procedure RestoreCursorBackground;

{ Does nothing; calling it loads this overlay. }
procedure PrimeMapCurs;

{ Empty routine with no callers. }
procedure NoopMapCursC;

implementation

uses Blit, GDConsts, GDVars, C_Gbvm;

procedure NoopMapCursA;
begin
end;

procedure NoopMapCursB;
begin
end;

procedure NoopMapCursC;
begin
end;

procedure PrimeMapCurs;
begin
end;

procedure SetCursorPosition;
begin
  GDVars.cursorColumn := GDConsts.cursorColumns[GDVars.zone0^[C_Gbvm.OVERLAND_LOCATION]];
  GDVars.cursorRow := GDConsts.cursorRows[GDVars.zone0^[C_Gbvm.OVERLAND_LOCATION]];
end;

procedure DrawCursor;
begin
  Blit.GrabPic(GDVars.cursorColumn, GDVars.cursorRow, GDVars.sym8x8Buf);
  Blit.ShowPic(GDVars.cursorColumn, GDVars.cursorRow, GDVars.cursorImage);
end;

procedure RestoreCursorBackground;
begin
  Blit.ShowPic(GDVars.cursorColumn, GDVars.cursorRow, GDVars.sym8x8Buf);
end;

begin
end.
