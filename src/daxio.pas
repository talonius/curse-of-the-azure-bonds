{ DAX archive loading and decompression, file lookup across the two install directories with disk prompts, BIOS text
  output for prompts, and file-name cleanup. }
{$O+,F+,I-,R-,S-}
unit DaxIo;

interface

uses Types, GDConsts, GDVars, GameIo, SoundDrv, Dos;

type
  TStr20 = string[20];

{ Frees a block allocated by AllocRounded.
  @param(block The block to free.)
  @param(byteCount The size it was allocated with, before rounding up to a multiple of 8.) }
procedure FreeRounded(var block: Pointer; byteCount: Word);

{ Allocates a block rounded up to a multiple of 8 bytes.
  @param(block Receives the new block.)
  @param(byteCount The size wanted.) }
procedure AllocRounded(var block: Pointer; byteCount: Word);

{ Writes a character repeatedly at a text cell through the BIOS, translating the attribute through the CGA text color
  map in CGA mode.
  @param(col Text column.)
  @param(row Text row.)
  @param(attr Text attribute.)
  @param(count How many times to write it.)
  @param(ch The character code.) }
procedure WriteChar(col, row, attr, count, ch: Byte);

{ Writes a string one character at a time from a text cell.
  @param(col Text column of the first character.)
  @param(row Text row.)
  @param(attr Text attribute.)
  @param(source The text.) }
procedure WriteString(col, row, attr: Byte; source: string);

{ Writes a run of solid blocks from a text cell.
  @param(col Text column of the first block.)
  @param(row Text row.)
  @param(attr Text attribute.)
  @param(count How many blocks.) }
procedure WriteBlock(col, row, attr, count: Byte);

{ Shows a message on the bottom row, waits for a key, then clears the row.
  @param(attr Text attribute of the message.)
  @param(message The message.) }
procedure PromptBox(attr: Byte; message: Types.TStr40);

{ Erases a file if it exists.
  @param(name The file's name.) }
procedure DeleteIfPresent(name: Types.TStr80);

{ Asks for the overlay disk until GAME.OVR can be found. }
procedure OverlayPrompt;

{ Reads a drive's volume label. The FindFirst status is not checked: the name buffer is cleared first, so a failed
  search leaves it empty.
  @param(drive The drive letter.)
  @returns(The label, or an empty string when it has none.) }
function GetVolumeLabel(drive: Types.TStr2): Types.TStr40;

{ Opens a file for reading with record size 1. A name without a directory is looked up in cfgDir1; when it is not there,
  cfgDir1 and cfgDir2 are swapped for good and the other directory is tried. While the file is missing and prompting is
  allowed, it asks for the disk (promptMsg plus the drive letter, for a directory on drive A or B) or reports "Couldn't
  find <name>. Check install." and tries again.
  @param(fileName The file's name, with or without a directory.)
  @param(promptMsg The disk prompt, completed with the drive letter.)
  @param(noPrompt #0 to prompt and retry until the file is found; anything else tries once.)
  @param(openedFile Receives the opened file.)
  @returns(True if the file was found and opened.) }
function OpenWithRetry(fileName, promptMsg: Types.TStr80; noPrompt: Char; var openedFile: file): Boolean;

{ Tells whether a file exists.
  @param(name The file's name or pattern.)
  @returns(True when name is not empty and a file matches it.) }
function FileExists(name: Types.TStr80): Boolean;

{ Removes the occurrences of a substring. After a removal the scan moves on, so an occurrence directly after a removed
  one is kept.
  @param(src The text.)
  @param(del The substring to remove.)
  @returns(src without the removed occurrences.) }
function SanitizeString(src, del: string): string;

{ Makes a DOS file name: removes the ten invalid characters, keeps the first 8 characters and uppercases them.
  @param(name The raw name.)
  @returns(The file name.) }
function SanitizeFileName(name: string): Types.TStr80;

{ Decompresses DAX run-length data until the compressed length is consumed: a control byte 0 to 126 copies the next
  control + 1 bytes, -127 to -1 repeats the next byte -control times. Note: control bytes 127 and -128 are not handled
  and loop forever.
  @param(src The compressed data.)
  @param(dst Receives the decompressed data; the buffer must be large enough.)
  @param(lenCompressed Length of the compressed data.)
  @param(lenDecompressed Unused.) }
procedure DecompressDaxBuffer(var src, dst: Types.PByteArr; var lenCompressed, lenDecompressed: Word);

{ Opens a DAX archive twice through OpenWithRetry with the current disk's prompt: dirFile reads the block directory and
  dataFile the data. headerSize gets the directory length plus its length word, and dataFile is positioned past it.
  Note: if the second open fails, dataFile is left open.
  @param(fileName The archive's name, without the extension.)
  @param(ext The archive's extension.)
  @param(headerSize Receives the size of the directory with its length word.)
  @param(dataFile Receives the archive opened for the data.)
  @param(dirFile Receives the archive opened for the directory.)
  @returns(True if both opens succeeded.) }
function OpenDax(fileName, ext: TStr20; var headerSize: Word; var dataFile, dirFile: file): Boolean;

{ Closes both files of a DAX archive.
  @param(dataFile The archive opened for the data.)
  @param(dirFile The archive opened for the directory.) }
procedure CloseDax(var dataFile, dirFile: file);

{ Loads and decompresses one block of a DAX archive, with the sound silenced meanwhile. The directory entries (id,
  offset, size, compressed size) are scanned until the id matches; a compressed size above 36000 in any entry scanned
  shows 'tempsize <n>' and quits.
  @param(fileName The archive's name, without the extension.)
  @param(ext The archive's extension.)
  @param(fileId The block's id.)
  @param(sizeRead Receives the block's decompressed size, or 0 if the archive or block is missing.)
  @param(data Receives a newly allocated buffer with the block, or nil.) }
procedure LoadDax(fileName, ext: Types.TStr80; fileId: Byte; var sizeRead: Word; var data: Types.PByteArr);

{ Saves the current disk number and switches to another.
  @param(diskNumber The disk to switch to.) }
procedure PushState(diskNumber: Byte);

{ Restores the disk number saved by PushState. }
procedure PopState;

implementation

procedure FreeRounded(var block: Pointer; byteCount: Word);
begin
  FreeMem(block, (byteCount + 7) and $FFF8);
end;

procedure AllocRounded(var block: Pointer; byteCount: Word);
begin
  GetMem(block, (byteCount + 7) and $FFF8);
end;

procedure WriteChar(col, row, attr, count, ch: Byte);
begin
  GDVars.videoRegs.ah := 2;
  GDVars.videoRegs.bh := 0;
  GDVars.videoRegs.dh := row;
  GDVars.videoRegs.dl := col;
  Intr($10, Registers(GDVars.videoRegs));
  GDVars.videoRegs.ah := 9;
  GDVars.videoRegs.al := ch;
  GDVars.videoRegs.bh := 0;
  if GDVars.displayMode = 0 then
    GDVars.videoRegs.bl := GDConsts.attrTable[attr]
  else
    GDVars.videoRegs.bl := attr;
  GDVars.videoRegs.cx := count;
  Intr($10, Registers(GDVars.videoRegs));
end;

procedure WriteString(col, row, attr: Byte; source: string);
var
  n: Byte;
  i: Byte;
begin
  n := Length(source);
  for i := 1 to n do begin
    DaxIo.WriteChar(col, row, attr, 1, Ord(source[i]));
    Inc(col);
  end;
end;

procedure WriteBlock(col, row, attr, count: Byte);
begin
  DaxIo.WriteChar(col, row, attr, count, 219);
end;

procedure PromptBox(attr: Byte; message: Types.TStr40);
var
  { Unused in this version; see the other implementations of this routine. }
  key: Char;
begin
  DaxIo.WriteBlock(0, 24, 0, 40);
  DaxIo.WriteString(0, 24, attr, message);
  key := GameIo.ReadGameKey;
  DaxIo.WriteBlock(0, 24, 0, 40);
end;

procedure DeleteIfPresent(name: Types.TStr80);
begin
  if DaxIo.FileExists(name) then begin
    Assign(GDVars.scratchFile, name);
    Close(GDVars.scratchFile);
    Erase(GDVars.scratchFile);
  end;
end;

procedure OverlayPrompt;
var
  { Unused in this version; see the other implementations of this routine. }
  key: Char;
  found: Boolean;
begin
  repeat
    found := DaxIo.FileExists('game.ovr');
    if not found then begin
      Writeln('Please insert overlay disk.');
      key := GameIo.ReadGameKey;
    end;
  until found;
end;

function GetVolumeLabel(drive: Types.TStr2): Types.TStr40;
var
  sr: SearchRec;
begin
  FillChar(sr.Name, SizeOf(sr.Name), 0);
  FindFirst(drive + ':\*.*', VolumeID, sr);
  GetVolumeLabel := sr.Name;
end;

function OpenWithRetry(fileName, promptMsg: Types.TStr80; noPrompt: Char; var openedFile: file): Boolean;
var
  found: Boolean;
  oldDir: string[79];
  dir: DirStr;
  name: NameStr;
  ext: ExtStr;
begin
  FSplit(fileName, dir, name, ext);
  if dir = '' then
    dir := GDVars.cfgDir1;
  repeat
    found := DaxIo.FileExists(dir + name + ext);
    if (not found) and (dir = GDVars.cfgDir1) then begin
      oldDir := GDVars.cfgDir1;
      GDVars.cfgDir1 := GDVars.cfgDir2;
      GDVars.cfgDir2 := oldDir;
      dir := GDVars.cfgDir1;
      found := DaxIo.FileExists(dir + name + ext);
    end;
    if (not found) and (noPrompt = #0) then begin
      if dir[1] < 'C' then
        DaxIo.PromptBox(14, promptMsg + GDVars.driveLetter + ':')
      else
        DaxIo.PromptBox(14, 'Couldn''t find ' + name + ext + '. Check install.');
    end;
  until found or (noPrompt <> #0);
  if found then begin
    Assign(openedFile, dir + name + ext);
    Reset(openedFile, 1);
  end;
  OpenWithRetry := found;
end;

function FileExists(name: Types.TStr80): Boolean;
var
  sr: SearchRec;
begin
  FindFirst(name, 0, sr);
  FileExists := (DosError = 0) and (name <> '');
end;

function SanitizeString(src, del: string): string;
var
  limit: Byte;
  delLen: Byte;
  i: Byte;
begin
  delLen := Length(del);
  limit := Length(src) - delLen + 1;
  for i := 1 to limit do
    if Copy(src, i, delLen) = del then
      Delete(src, i, delLen);
  SanitizeString := src;
end;

function SanitizeFileName(name: string): Types.TStr80;
var
  i: Byte;
begin
  for i := 1 to 10 do
    name := DaxIo.SanitizeString(name, GDConsts.invalidFileChars[i]);
  name := Copy(name, 1, 8);
  for i := 1 to Length(name) do
    name[i] := UpCase(name[i]);
  SanitizeFileName := name;
end;

procedure DecompressDaxBuffer(var src, dst: Types.PByteArr; var lenCompressed, lenDecompressed: Word);
var
  srcIdx: Word;
  dstIdx: Word;
  b: ShortInt;
begin
  srcIdx := 0;
  dstIdx := 0;
  repeat
    b := src^[srcIdx];
    case b of
      0..126: begin
        Move(src^[srcIdx + 1], dst^[dstIdx], b + 1);
        Inc(srcIdx, b + 2);
        Inc(dstIdx, b + 1);
      end;
      -127..-1: begin
        b := -b;
        FillChar(dst^[dstIdx], b, src^[srcIdx + 1]);
        Inc(srcIdx, 2);
        Inc(dstIdx, b);
      end;
    end;
  until srcIdx >= lenCompressed;
end;

function OpenDax(fileName, ext: TStr20; var headerSize: Word; var dataFile, dirFile: file): Boolean;
var
  nread: Word;
  { Unused in this version; see the other implementations of this routine. }
  ioStatus: Word;
begin
  if DaxIo.OpenWithRetry(fileName + ext, GDConsts.diskPrompts[GDVars.diskIndex], GDVars.suppressDiskPrompt,
                         dataFile) then begin
    if not DaxIo.OpenWithRetry(fileName + ext, GDConsts.diskPrompts[GDVars.diskIndex], GDVars.suppressDiskPrompt,
                               dirFile) then begin
      OpenDax := False;
      Exit;
    end;
    BlockRead(dirFile, headerSize, SizeOf(headerSize), nread);
    Inc(headerSize, 2);
    Seek(dataFile, headerSize);
    OpenDax := True;
    Exit;
  end;
  OpenDax := False;
end;

procedure CloseDax(var dataFile, dirFile: file);
begin
  Close(dataFile);
  Close(dirFile);
end;

procedure LoadDax(fileName, ext: Types.TStr80; fileId: Byte; var sizeRead: Word; var data: Types.PByteArr);
var
  compSize: Word;
  offset: LongInt;
  id: Byte;
  n: Word;
  dataFile: file;
  dirFile: file;
  hdrSize: Word;
  { Unused in this version; see the other implementations of this routine. }
  soundState: Byte;
  numStr: String[6];
  { Unused in this version; see the other implementations of this routine. }
  found: Byte;
begin
  SoundDrv.SoundCommand(GDConsts.sndSilence);
  if not DaxIo.OpenDax(fileName, ext, hdrSize, dataFile, dirFile) then begin
    sizeRead := 0;
    data := nil;
    SoundDrv.SoundCommand(GDConsts.sndResume);
    Exit;
  end;
  repeat
    BlockRead(dirFile, id, SizeOf(id), n);
    BlockRead(dirFile, offset, SizeOf(offset), n);
    BlockRead(dirFile, sizeRead, SizeOf(sizeRead), n);
    BlockRead(dirFile, compSize, SizeOf(compSize), n);
    if compSize > 36000 then begin
      Str(LongInt(compSize), numStr);
      DaxIo.PromptBox(14, 'tempsize ' + numStr);
      GameIo.ExitGame;
    end;
  until (id = fileId) or (FilePos(dirFile) >= hdrSize);
  if id <> fileId then begin
    sizeRead := 0;
    data := nil;
    DaxIo.CloseDax(dataFile, dirFile);
    SoundDrv.SoundCommand(GDConsts.sndResume);
    Exit;
  end;
  DaxIo.AllocRounded(Pointer(GDVars.diskTransferBuffer), compSize);
  GetMem(data, sizeRead);
  Seek(dataFile, hdrSize + offset);
  BlockRead(dataFile, GDVars.diskTransferBuffer^, compSize, n);
  DaxIo.CloseDax(dataFile, dirFile);
  DaxIo.DecompressDaxBuffer(GDVars.diskTransferBuffer, data, compSize, sizeRead);
  DaxIo.FreeRounded(Pointer(GDVars.diskTransferBuffer), compSize);
  SoundDrv.SoundCommand(GDConsts.sndResume);
end;

procedure PushState(diskNumber: Byte);
begin
  GDVars.savedDiskIndex := GDVars.diskIndex;
  GDVars.diskIndex := diskNumber;
end;

procedure PopState;
begin
  GDVars.diskIndex := GDVars.savedDiskIndex;
end;

begin
end.
