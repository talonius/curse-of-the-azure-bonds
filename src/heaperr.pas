{ The heap-error handler, installed at startup: on a failed allocation the player is made to save the game, then the
  program quits. }
{$O+,F+}
unit HeapErr;

interface

{ Shows "Time to save your game" and opens the save menu until the recently-saved flag is set, then quits. It runs on
  every call, size 0 included. Note: the recently-saved flag is not cleared first, so after an earlier save the loop
  ends after one pass even when nothing is saved.
  @param(size Unused.)
  @returns(Nothing: ExitGame ends the program, so no result is assigned.) }
function HeapErrorHandler(size: Word): Integer;

{ Empty routine with no callers. }
procedure NoopHeapErr;

implementation

uses TextRend, SaveLoad, GameIo, GDConsts, GDVars, Crt;

procedure NoopHeapErr;
begin
end;

function HeapErrorHandler(size: Word): Integer;
begin
  repeat
    TextRend.DisplayAndPause(Yellow, Black, 'Time to save your game');
    SaveLoad.SaveGame;
  until GDVars.recentlySaved <> 0;
  GameIo.ExitGame;
end;

begin
  HeapError := @HeapErr.HeapErrorHandler;
end.
