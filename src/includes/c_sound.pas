{ Sound modes (GDVars.soundMode): where SoundDrv sends its voices. }
unit C_Sound;

interface

const
  { the PC speaker, chosen by a P in the config file }
  SPEAKER = 0;
  { the Tandy voices, chosen by a T }
  TANDY = 1;
  { sound off: any other letter, or after Ctrl-S }
  OFF = 2;

implementation

end.
