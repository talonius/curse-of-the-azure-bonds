{ Keyboard input with its control-key commands (^S sound; with the STING parameter also ^D debug log, ^Z effect dump and
  ^C quit), and quitting the game. }
{$F+,I-,R-,S-}
unit GameIo;

interface

uses GDConsts, GDVars, Types, Crt, Dos, SoundDrv, C_Sound;

var

  { BIOS keyboard shift and toggle flags. }
  kbFlags: Byte absolute $40:$17;

{ Ends the program: restores the sound mode, stops the sound driver, restores the startup video mode (INT 10h function
  0), closes the debug log, restores the BIOS keyboard flags, and halts. }
procedure ExitGame;

{ Returns the next key: waits for one, or while the demo runs returns #0 when none is waiting. ^S turns the sound off or
  back on; with STING as the first parameter, ^D turns the debug log (DEBUG.TXT) on or off, ^Z writes the effects of
  each creature on the party list to it while the log is open, and ^C quits. Keys typed ahead are then read and the
  newest is returned, without their commands.
  @returns(The newest key, or #0 in the demo when none was waiting.) }
function ReadGameKey: Char;

{ Reads and discards the waiting keys through ReadGameKey, so their control commands still work. }
procedure DiscardPendingKeys;

{ Handles one waiting key, if any, through ReadGameKey and discards it, so control keys work while the game runs. }
procedure PollGameKeys;

implementation

const
  { Control-letter combinations (ASCII control codes). }
  CTRL_C = #3;
  CTRL_D = #4;
  CTRL_S = #19;
  CTRL_Z = #26;

procedure ExitGame;
var
  { Unused in this version; see the other implementations of this routine. }
  c: Char;
begin
  GDVars.soundMode := GDVars.soundPrev;
  SoundDrv.SoundCommand(GDConsts.sndShutdown);
  GDVars.videoRegs.AH := 0;
  GDVars.videoRegs.al := GDVars.savedVideoMode;
  Intr(16, Registers(GDVars.videoRegs));
  if GDVars.debugTraceEnabled then Close(GDVars.debugFile);
  kbFlags := GDVars.savedKbFlags;
  Halt(0);
end;

{ Writes one line per effect on a creature to the debug log: its name and the effect's id.
  @param(creature The creature.) }
procedure DumpSpells(creature: Types.PCreature);
var
  cur: Types.PEffect;
begin
  cur := creature^.effects;
  while cur <> nil do begin
    Writeln(GDVars.debugFile, 'who: ', creature^.name, '  sp#: ', cur^.id);
    cur := cur^.next;
  end;
end;

function ReadGameKey: Char;
var
  c: Char;
  cur: Types.PCreature;
begin
  if GDVars.demoMode then begin
    if KeyPressed then c := ReadKey else c := #0;
  end else
    c := ReadKey;
  { sound toggle }
  if c = GameIo.CTRL_S then begin
    if GDVars.soundMode <> C_Sound.OFF then begin
      GDVars.soundPrev := GDVars.soundMode;
      SoundDrv.SoundCommand(GDConsts.sndSilence);
      GDVars.soundMode := C_Sound.OFF;
    end else if GDVars.soundPrev in [C_Sound.SPEAKER, C_Sound.TANDY] then begin
      GDVars.soundMode := GDVars.soundPrev;
      SoundDrv.SoundCommand(GDConsts.sndResume);
    end;
  end;
  { hidden developer mode }
  if ParamStr(1) = 'STING' then begin
    case c of
      { toggle debug log }
      GameIo.CTRL_D: begin
             GDVars.debugTraceEnabled := not GDVars.debugTraceEnabled;
             if GDVars.debugTraceEnabled then begin
               Assign(GDVars.debugFile, 'debug.txt');
               Rewrite(GDVars.debugFile);
             end else
               Close(GDVars.debugFile);
           end;
      { log the party list's effects }
      GameIo.CTRL_Z: if GDVars.debugTraceEnabled then begin
             cur := GDVars.partyHead;
             while cur <> nil do begin
               GameIo.DumpSpells(cur);
               cur := cur^.next;
             end;
           end;
      { quit }
      GameIo.CTRL_C: GameIo.ExitGame;
    end;
  end;
  if c <> #0 then
    { discard type-ahead, keeping the newest key }
    while KeyPressed do c := ReadKey;
  ReadGameKey := c;
end;

procedure DiscardPendingKeys;
var
  { Unused in this version; see the other implementations of this routine. }
  c: Char;
begin
  while KeyPressed do c := GameIo.ReadGameKey;
end;

procedure PollGameKeys;
var
  { Unused in this version; see the other implementations of this routine. }
  c: Char;
begin
  if KeyPressed then c := GameIo.ReadGameKey;
end;

begin
end.
