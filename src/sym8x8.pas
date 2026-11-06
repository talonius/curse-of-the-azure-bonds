{ Loads the five 8x8 symbol sets and draws their wall, map and border glyphs, using TImgBuf image buffers. }
{$O+,F+}
{$I-,A+}
unit Sym8x8;

interface

{ Empty routine with no callers. }
procedure NoopSym8x8;

{ Loads a symbol set from a picture of the current disk's 8x8D archive, with color 13 transparent. An invalid set does
  nothing; a load failure quits.
  @param(fileId The picture in the archive.)
  @param(setId Symbol-set slot, 0..4.) }
procedure Load8x8Set(fileId, setId: Byte);

{ Draws a symbol from its set (set bases from GDConsts.symSetBase); an unloaded set draws nothing, and 0 or 296 to 32767
  quits with an error. Note: a symbol of 32768 or more picks no set, so the set index is left unassigned.
  @param(col Signed column in 8-pixel cells.)
  @param(row Signed row in 8-pixel cells.)
  @param(symbol The symbol, 1 to 295 across the five sets.)
  @param(useViewBuffer Composite into the view buffer; otherwise show it through the scratch image.)
  @param(useMask Apply the transparency mask when drawing into the view buffer.) }
procedure Put8x8Sym(col, row: ShortInt; symbol: Word; useViewBuffer, useMask: Boolean);

{ Empty entry; calling it loads this overlay. }
procedure PrimeSym8x8;

implementation

uses Blit, GameIo, GDConsts, GDVars, C_Pic;

procedure NoopSym8x8;
begin
end;

procedure PrimeSym8x8;
begin
end;

procedure Load8x8Set(fileId, setId: Byte);
var
  diskText: String[1];
  fileText: String[3];
  { Unused in this version; see the other implementations of this routine. }
  frameGap: Byte;
  { Unused in this version; see the other implementations of this routine. }
  ignoredKey: Char;
begin
  if setId in [0..4] then begin
    Str(GDVars.diskIndex, diskText);
    { Never used: the error message prints fileId itself. }
    Str(fileId, fileText);
    Blit.LoadPic('8x8d' + diskText, fileId, True, C_Pic.TRANSPARENT_COLOR, GDVars.symbolSetPtrs[setId]);
    if GDVars.symbolSetPtrs[setId] = nil then begin
      Blit.RestoreVideoMode;
      WriteLn('Unable to load ', fileId, ' from 8x8D' + diskText);
      ignoredKey := GameIo.ReadGameKey;
      { The load-error path restores the video mode twice. }
      Blit.RestoreVideoMode;
      GameIo.ExitGame;
    end;
    GameIo.DiscardPendingKeys;
  end;
end;

procedure Put8x8Sym(col, row: ShortInt; symbol: Word; useViewBuffer, useMask: Boolean);
var
  setIndex: Byte;
  { Unused in this version; see the other implementations of this routine. }
  ignoredKey: Char;
begin
  case symbol of
    1..45: setIndex := 0;
    46..115: setIndex := 1;
    116..185: setIndex := 2;
    186..255: setIndex := 3;
    256..295: setIndex := 4;
    0, 296..32767: begin
      Blit.RestoreVideoMode;
      WriteLn('Bad symbol number in Put8x8Symbol.');
      ignoredKey := GameIo.ReadGameKey;
      GameIo.ExitGame;
    end;
  end;
  if GDVars.symbolSetPtrs[setIndex] <> nil then begin
    Dec(symbol, GDConsts.symSetBase[setIndex]);
    if useViewBuffer then
      Blit.BlitTileCell(col, row, symbol, Ord(useMask), GDVars.symbolSetPtrs[setIndex], GDVars.viewBuffer)
    else begin
      with GDVars.symbolSetPtrs[setIndex]^ do
        Move(data[symbol * imgSize], GDVars.sym8x8Buf^.data, imgSize);
      Blit.ShowPic(col, row, GDVars.sym8x8Buf);
    end;
  end;
end;

begin
end.
