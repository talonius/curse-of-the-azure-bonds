{ The heap-error handler, installed at startup: on a failed allocation it warns, lets the player save the game when
  heap-failure saving is on, then quits. }
{$O+,F+}
unit HeapErr;

interface

implementation

uses TextRend, SaveLoad, GameIo, GDConsts, GDVars, Crt;

{ On a failed allocation (size above 0), warns of insufficient memory and either opens the save menu until the
  recently-saved flag is set (when heap-failure saving is on) or says the program is exiting; then quits. A size-0 call
  returns at once. Note: the recently-saved flag is not cleared first, so after an earlier save the loop ends after one
  pass even when nothing is saved.
  @param(size The failed allocation size; 0 for a call that needs no action.)
  @returns(Unassigned; the routine only returns for size 0.) }
function HeapErrorHandler(size: Word): Integer;
var
  exitFlag: Byte;
begin
  if size > 0 then begin
    exitFlag := 0;
    repeat
      TextRend.DisplayAndPause(Yellow, Black, 'WARNING: Insufficient Memory');
      if GDVars.heapFailureSaveEnabled then begin
        SaveLoad.SaveGame;
        exitFlag := GDVars.recentlySaved;
      end else begin
        exitFlag := 1;
        TextRend.DisplayAndPause(Yellow, Black, 'Insufficient Memory. Exiting Program');
      end;
    until exitFlag <> 0;
    GameIo.ExitGame;
  end;
end;

begin
  HeapError := @HeapErr.HeapErrorHandler;
end.
