{ Translation-wheel copy protection and the executable checksum check. }
{$O+,F+,I-}
{$A-}
unit CopyProt;

interface

{ Runs the translation-wheel copy protection: shows a random espruar rune (of 26) and dethek rune (of 22), a path style
  (of 3) and a box number (1..6), and asks for the character the wheel shows there. Three wrong answers play two sounds,
  set the game delay to 9, report 'An unseen force hurls you into the abyss!' and quit; a right answer returns at
  once. }
procedure CopyProtection;

{ Calls the trace overlay's priming entry, so the overlay manager loads it. }
procedure PrimeCopyProt;

{ Checks START.EXE against its stored checksum: the sum of every byte except the last four must equal the four-byte
  value at the end. A mismatch shows 'checksum error <sum> - <stored>'. Note: the open is checked through DosError,
  which Reset does not set, so a missing file is not caught.
  @returns(True when the sums match, or when DosError is already nonzero.) }
function VerifyChecksum: Boolean;

implementation

uses Blit, MapTiles, SoundDrv, Crt, Dos, GameIo, TextRend, Border, EclTrace, CharHlp, MenuCore,
  GDConsts, GDVars;

procedure PrimeCopyProt;
begin
  EclTrace.PrimeEclTrace;
end;

function VerifyChecksum: Boolean;
var
  { Four-byte executable checksum. }
  stored: LongInt;
  sum: LongInt;
  { Unused in this version; see the other implementations of this routine. }
  isValid: Byte;
  bytesRead: LongInt;
  i: LongInt;
  f: file;
  limit: LongInt;
  chunk: LongInt;
  buf: array[1..256] of Byte;
begin
  TextRend.DisplayString(0, 24, LightGreen, 0, 'Loading...Please Wait');
  sum := 0;
  bytesRead := 0;
  Assign(f, 'start.exe');
  Reset(f, 1);
  if DosError = 0 then begin
    limit := FileSize(f) - 4;
    while bytesRead < limit do begin
      chunk := 256;
      if bytesRead + chunk >= limit then chunk := limit - bytesRead;
      BlockRead(f, buf, chunk);
      for i := 1 to chunk do
        Inc(sum, buf[i]);
      Inc(bytesRead, chunk);
    end;
    BlockRead(f, stored, SizeOf(stored));
    VerifyChecksum := sum = stored;
    if sum <> stored then
      TextRend.DisplayAndPause(Yellow, 0, 'checksum error ' + CharHlp.Int32Str(sum) + ' - ' + CharHlp.Int32Str(stored));
  end else
    VerifyChecksum := True;
  Close(f);
  MenuCore.ClearBottomLine;
end;

procedure CopyProtection;
var
  attemptNum: Byte;
  inputChar: Char;
  answerChar: Char;
  idx: Integer;
  { Espruar rune tile shown, of 26. }
  espruarTile: Byte;
  { Dethek rune tile shown, of 22. }
  dethekTile: Byte;
  pat: String[9];
  numStr: String[1];
  { Path style shown, of 3. }
  patternSel: Byte;
  { Wheel row, shown as box number 6 - row. }
  wheelRow: Byte;
  replyStr: String[1];
begin
  MapTiles.Load24x24Set('tiles', 1, 0, 26);
  MapTiles.Load24x24Set('tiles', 2, 26, 22);
  Border.DrawWindowFrame;
  TextRend.DisplayString(3, 2, LightGreen, 0, 'Align the espruar and dethek runes');
  TextRend.DisplayString(3, 3, LightGreen, 0, 'shown below, on translation wheel');
  TextRend.DisplayString(3, 4, LightGreen, 0, 'like this:');
  attemptNum := 0;
  repeat
    espruarTile := Random(26);
    dethekTile := Random(22);
    MapTiles.Copy2DTile(17, 3, espruarTile, 0);
    MapTiles.Copy2DTile(17, 7, dethekTile + 26, 0);
    Blit.FlushView;
    patternSel := Random(3);
    case patternSel of
      0: pat := '-..-..-..';
      1: pat := '- - - - -';
      2: pat := '.........';
    end;
    wheelRow := Random(6);
    Str(6 - wheelRow, numStr);
    TextRend.DisplayString(3, 12, LightGreen, 0, 'Type the character in box number ' + numStr);
    TextRend.DisplayString(3, 13, LightGreen, 0, 'under the ');
    TextRend.DisplayString(14, 13, White, 0, pat);
    TextRend.DisplayString(25, 13, LightGreen, 0, 'path.');
    idx := espruarTile + 34 - dethekTile + patternSel * 12 + (5 - wheelRow) * 2;
    while idx < 0 do Inc(idx, 36);
    while idx > 35 do Dec(idx, 36);
    answerChar := GDConsts.wheel[wheelRow][idx + 1];
    replyStr := ' ';
    replyStr := TextRend.ReadString('type character and press return: ', LightMagenta, 0, 1);
    inputChar := replyStr[1];
    Inc(attemptNum);
    if inputChar <> answerChar then
      TextRend.PrintAndPause('Sorry, that''s incorrect.', Yellow, 0)
    else
      Exit;
  until (inputChar = answerChar) or (attemptNum > 2);
  if attemptNum < 3 then Exit;
  { Three failed answers end the game. }
  SoundDrv.SoundCommand(GDConsts.sndResume);
  SoundDrv.SoundCommand(GDConsts.sndCmd5);
  GDVars.gameDelay := 9;
  TextRend.PrintAndPause('An unseen force hurls you into the abyss!', Yellow, 0);
  Delay(1000);
  GameIo.ExitGame;
end;

begin
end.
