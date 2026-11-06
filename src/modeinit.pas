{ Sets GDVars.commandText, the keyword that unlocks the developer options when it is the second command-line parameter,
  to the item-name fragment "Wooden". Given that parameter, FixMain skips the copy-protection question, Explore allows
  the automap everywhere, CharGen toggles free training, and CbtActs ends combat in victory. This unit allocates no
  storage. }
{$F+,I-,R-,S-}
unit ModeInit;

interface

uses GDConsts, GDVars;

implementation

const
  WOODEN_NAME_INDEX = 252;

begin
  GDVars.commandText := GDConsts.itemNames[ModeInit.WOODEN_NAME_INDEX];
end.
