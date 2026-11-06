{ Build helper: appends to an executable (START.EXE in the build) the little-endian 32-bit sum of its bytes, without
  changing the MZ header, for CopyProt.VerifyChecksum to check. A file whose size differs from what its header declares
  is refused, so a stamped file cannot be stamped twice. }
program Stamp;

{$R-}
{$S-}
{$I-}

const
  { header word: bytes used on the last page }
  MZ_LASTPAGE = 2;
  { header word: 512-byte pages, last included }
  MZ_PAGES = 4;
  { bytes per MZ page }
  MZ_PAGE_BYTES = 512;

{ Prints msg after "STAMP: " and halts with exit code 2.
  @param(msg The reason the stamp cannot be applied.) }
procedure Die(msg: string);
begin
  WriteLn('STAMP: ', msg);
  Halt(2);
end;

{ Checks that the file named on the command line is raw link output and appends the sum of its bytes. }
procedure StampFile;
var
  f: file;
  buf: array[0..1023] of Byte;
  hdr: array[0..5] of Byte;
  n: Word;
  i: Word;
  lastPage: Word;
  pages: Word;
  sum: LongInt;
  declared: LongInt;
begin
  if ParamCount <> 1 then
    Die('usage: STAMP <file.exe>');

  Assign(f, ParamStr(1));
  Reset(f, 1);
  if IOResult <> 0 then
    Die('cannot open ' + ParamStr(1));

  BlockRead(f, hdr, SizeOf(hdr), n);
  if (n <> SizeOf(hdr)) or (hdr[0] <> Ord('M')) or (hdr[1] <> Ord('Z')) then
    Die('not an MZ executable');

  lastPage := hdr[MZ_LASTPAGE] + hdr[MZ_LASTPAGE + 1] * 256;
  pages := hdr[MZ_PAGES] + hdr[MZ_PAGES + 1] * 256;
  if lastPage = 0 then
    declared := LongInt(pages) * MZ_PAGE_BYTES
  else
    declared := (LongInt(pages) - 1) * MZ_PAGE_BYTES + lastPage;

  if FileSize(f) <> declared then begin
    WriteLn('STAMP: ', ParamStr(1), ' is ', FileSize(f), ' bytes but its header declares ', declared);
    Die('refusing -- the input must be the raw link output');
  end;

  Seek(f, 0);
  sum := 0;
  repeat
    BlockRead(f, buf, SizeOf(buf), n);
    { Skip an empty read to avoid unsigned underflow in n - 1. }
    if n > 0 then
      for i := 0 to n - 1 do
        sum := sum + buf[i];
  until n = 0;

  Seek(f, FileSize(f));
  BlockWrite(f, sum, SizeOf(sum));
  Close(f);
  { Report write or close errors before announcing success. }
  if IOResult <> 0 then
    Die('write failed -- ' + ParamStr(1) + ' is NOT stamped');
  WriteLn('STAMP: appended ', sum);
end;

begin
  StampFile;
end.
