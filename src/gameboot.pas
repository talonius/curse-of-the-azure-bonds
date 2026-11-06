{ Startup setup, run from the initialization block: opens the overlay file, finds the game drive, creates CURSE.CFG on
  the first run (graphics adapter, sound type, save path), then reads it to set the video mode, the overlay buffer, the
  sound type, the save path and the full-introduction flag. }
{$O+,F+,I-,R-,S-}
unit GameBoot;

interface

implementation

uses Crt, Dos, Overlay, DaxIo, Blit, TextRend, GDConsts, GDVars, C_Sound, Types;

type
  TPtrRec = record ofs: Word; seg: Word; end;

const
  OVERLAY_BUFFER_SIZE = 163840;

var
  heapTop: Types.PFreeRec absolute FreePtr;
  { The program's directory, which FSplit stores straight into cfgDir1. }
  fsDir: DirStr absolute GDVars.cfgDir1;

{ Waits for a digit key in a range and echoes it.
  @param(minDigit The lowest digit accepted.)
  @param(maxDigit The highest digit accepted.)
  @returns(The digit's value.) }
function ReadDigit(minDigit, maxDigit: Byte): Byte;
begin
  repeat
    GDVars.curKey := ReadKey;
  until (GDVars.curKey in ['0'..'9']) and ((Ord(GDVars.curKey) - Ord('0')) in [minDigit..maxDigit]);
  Write(GDVars.curKey);
  ReadDigit := Ord(GDVars.curKey) - Ord('0');
end;

begin
  CheckBreak := False;
  DaxIo.OverlayPrompt;
  OvrInit('GAME.OVR');
  FSplit(FExpand('*.exe'), fsDir, NameStr(GDVars.fsName), ExtStr(GDVars.fsExt));
  { Run from a floppy, the game disks go in the other floppy drive; otherwise they are in the program's directory. }
  if fsDir[1] < 'C' then
  begin
    if fsDir[1] = 'A' then GDVars.cfgDir2 := 'B:\'
    else GDVars.cfgDir2 := 'A:\';
  end else GDVars.cfgDir2 := fsDir;
  GDVars.driveLetter := GDVars.cfgDir2[1];

  { First run: create CURSE.CFG with the adapter (C, E or T), the sound (P, T or S), the save path and F (full
    introduction). }
  if not DaxIo.FileExists('curse.cfg') then
  begin
    Assign(GDVars.cfgFile, 'curse.cfg');
    Rewrite(GDVars.cfgFile);
    GDVars.writeProtErr := IOResult;
    if GDVars.writeProtErr <> 0 then begin
      ClrScr;
      WriteLn('Sorry, disk A can''t be write-protected.');
      WriteLn;
      WriteLn('If these are your masters, use DISKCOPY to make duplicates.');
      Halt(1);
    end;

    ClrScr;
    Write('GRAPHICS ADAPTER TYPE:  [1] CGA  [2] EGA  [3] Tandy  ');
    GDVars.digitChoice := GameBoot.ReadDigit(1, 3);
    case GDVars.digitChoice of
      1: WriteLn(GDVars.cfgFile, 'C');
      2: WriteLn(GDVars.cfgFile, 'E');
      3: WriteLn(GDVars.cfgFile, 'T');
    end;

    ClrScr;
    Write('SOUND TYPE:  [1] PC  [2] Tandy 1000  [3] Silent  ');
    GDVars.digitChoice := GameBoot.ReadDigit(1, 3);
    case GDVars.digitChoice of
      1: WriteLn(GDVars.cfgFile, 'P');
      2: WriteLn(GDVars.cfgFile, 'T');
      3: WriteLn(GDVars.cfgFile, 'S');
    end;

    ClrScr;
    GDVars.defaultPath := GDVars.cfgDir2 + 'SAVE';
    Write('PATH TO SAVE DATA (DEFAULT - ' + GDVars.defaultPath + '):  ');
    ReadLn(GDVars.savePath);
    GDVars.savePath[1] := UpCase(GDVars.savePath[1]);
    { A save path needs a drive A..P, at least 4 characters, and not the floppy the game runs from. }
    if (Length(GDVars.savePath) < 4) or (GDVars.savePath[2] <> ':')
       or ((GDVars.savePath[1] in ['A'..'B']) and (GDVars.savePath[1] = fsDir[1]))
       or not (GDVars.savePath[1] in ['A'..'P']) then
    begin
      GDVars.savePath := GDVars.defaultPath;
      WriteLn('USING DEFAULT PATH: ' + GDVars.savePath);
      Delay(2000);
    end;
    for GDVars.spIndex := 1 to Length(GDVars.savePath) do
      GDVars.savePath[GDVars.spIndex] := UpCase(GDVars.savePath[GDVars.spIndex]);
    if GDVars.savePath[Length(GDVars.savePath)] <> '\' then
      GDVars.savePath := GDVars.savePath + '\';
    WriteLn(GDVars.cfgFile, GDVars.savePath);
    WriteLn(GDVars.cfgFile, 'F');
    Close(GDVars.cfgFile);
  end;

  ClrScr;
  WriteLn('TANDY 1000 USERS - Make sure NUMLOCK is on.');
  Delay(2000);
  Assign(GDVars.cfgFile, 'curse.cfg');
  Reset(GDVars.cfgFile);
  ReadLn(GDVars.cfgFile, GDVars.curKey);
  GDVars.videoRegs.ah := $0F;
  Intr($10, Registers(GDVars.videoRegs));
  GDVars.savedVideoMode := GDVars.videoRegs.al;
  GDVars.curVideoMode := GDVars.savedVideoMode;
  case GDVars.curKey of
    'E':
      begin
        GDVars.displayMode := 1;
        Blit.SetVideoMode($0D);
        GDVars.egaShownPage := 0;
        GDVars.egaPageNumber := 0;
        TextRend.SetupEgaCurrentPage(GDVars.egaShownPage);
        TextRend.SetupEgaOtherPage(GDVars.egaPageNumber);
      end;
    'T':
      begin
        GDVars.displayMode := 2;
        { Tandy graphics use the top 16 KB of memory: the heap's free list moves 16 KB lower. }
        GDVars.savedTop := Ptr(TPtrRec(heapTop).seg - $400, TPtrRec(heapTop).ofs);
        Move(heapTop^, GDVars.savedTop^, SizeOf(GDVars.savedTop^));
        heapTop := GDVars.savedTop;
        Blit.SetVideoMode($09);
        { Keep at least 80 bytes for the heap free list. }
        FreeMin := 80;
        GDVars.tandyHeapTop := heapTop;
      end;
  else begin
      GDVars.displayMode := 0;
      Blit.SetVideoMode($04);
    end;
  end;

  { Grow the overlay buffer to 160 KB, or quit when memory is short. }
  if GameBoot.OVERLAY_BUFFER_SIZE - OvrGetBuf <= MemAvail then
    OvrSetBuf(GameBoot.OVERLAY_BUFFER_SIZE)
  else begin
    Blit.RestoreVideoMode;
    WriteLn('Not enough memory to run game.  You need ', GameBoot.OVERLAY_BUFFER_SIZE - OvrGetBuf - MemAvail,
            ' more bytes.');
    Halt;
  end;
  if OvrResult <> 0 then begin
    Blit.RestoreVideoMode;
    WriteLn('Overlay error, program abort!');
    Halt;
  end;

  ReadLn(GDVars.cfgFile, GDVars.curKey);
  case GDVars.curKey of
    'T': GDVars.soundMode := C_Sound.TANDY;
    'P': GDVars.soundMode := C_Sound.SPEAKER;
  else GDVars.soundMode := C_Sound.OFF;
  end;
  ReadLn(GDVars.cfgFile, GDVars.savedGamePath);
  ReadLn(GDVars.cfgFile, GDVars.curKey);
  if GDVars.curKey = 'F' then GDVars.fullIntro := True
  else GDVars.fullIntro := False;
  Close(GDVars.cfgFile);
end.
