{ The interface to the sound driver in SOUNDDRV.OBJ: commands for the PC speaker and Tandy voices, and installing and
  removing its timer interrupt. Sound mode 0 is the PC speaker, 1 Tandy, 2 off. }
{$F+,I-,R-,S-}
unit SoundDrv;

interface

{ Sends a command to the sound driver; with sound off only command 15 acts. 0 silences both sets of voices, 1 sets the
  voice byte to 1, 2 to 14 play song cmd - 1 on the PC speaker or the Tandy voices, 15 arms the driver's forced-exit
  countdown with 5000 ticks, and 255 silences the voices, removes the driver and marks sound inactive. Other values do
  nothing.
  @param(cmd The command.) }
procedure SoundCommand(cmd: Word);

{ Starts sound: remembers the sound mode and marks sound active, then, unless sound is off, installs the driver's timer
  interrupt and silences both sets of voices. }
procedure StartSound;

implementation

uses GDConsts, GDVars, C_Sound;

{$L SOUNDDRV.OBJ}
{ Installs the driver's timer interrupt handler and speeds up the timer. }
procedure InstallSoundTimer; external;

{ Restores the BIOS timer interrupt and its rate, and silences the speaker and the Tandy voices. }
procedure UninstallSoundTimer; external;

{ Starts a song on the PC-speaker voices; song 0 silences them.
  @param(song The song number.) }
procedure ProgramSpeakerVoices(song: Word); external;

{ Starts a song on the Tandy voices; song 0 silences them.
  @param(song The song number.) }
procedure ProgramTandyVoices(song: Word); external;

{ Sets the voice byte; while it is 0 the timer interrupt keeps the speaker and the Tandy voices quiet.
  @param(latchValue The new voice byte, in its low byte.) }
procedure SetVoiceByte(latchValue: Word); external;

{ Not code: the forced-exit countdown word that the driver's timer interrupt counts down. }
procedure TimeoutCtr; external;

procedure SoundCommand(cmd: Word);
begin
  if cmd in [0..15, 255] then
    case cmd of
      0: if GDVars.soundMode <> C_Sound.OFF then begin
             SoundDrv.ProgramTandyVoices(0);
             SoundDrv.ProgramSpeakerVoices(0);
           end;
      1: if GDVars.soundMode <> C_Sound.OFF then
             SoundDrv.SetVoiceByte(1);
      255: if GDVars.soundMode <> C_Sound.OFF then begin
             SoundDrv.ProgramTandyVoices(0);
             SoundDrv.ProgramSpeakerVoices(0);
             SoundDrv.UninstallSoundTimer;
             GDVars.soundActive := False;
           end;
      2..14: if GDVars.soundMode <> C_Sound.OFF then
               case GDVars.soundMode of
                 C_Sound.SPEAKER: SoundDrv.ProgramSpeakerVoices(cmd - 1);
                 C_Sound.TANDY: SoundDrv.ProgramTandyVoices(cmd - 1);
               end;
      15: GDVars.timeoutPtr^ := 5000;
    end;
end;

procedure StartSound;
begin
  GDVars.soundPrev := GDVars.soundMode;
  GDVars.soundActive := True;
  if GDVars.soundMode = C_Sound.OFF then Exit;
  SoundDrv.InstallSoundTimer;
  SoundDrv.ProgramSpeakerVoices(0);
  SoundDrv.ProgramTandyVoices(0);
end;

begin
  GDVars.timeoutPtr := @SoundDrv.TimeoutCtr;
  GDVars.timeoutPtr^ := 0;
end.
