{ The introduction: the title pictures with their sound and the credits screen, or only the first title picture when the
  full-introduction flag is off. }
{$O+,F+}
unit Intro;

interface

{ Shows the first title picture for 5 seconds or until a key. With the full-introduction flag on, it goes on with title
  pictures 2 and 3 for 10 seconds, picture 4 with a sound for 10, and the credits for 10, then clears the screen. Note:
  with the flag off the first picture is left allocated. }
procedure Introduction;

{ Does nothing; nothing calls it. }
procedure NoopIntro;

implementation

uses Crt, TextRend, Blit, GameIo, SoundDrv, Border, Types, GDConsts, GDVars;

procedure NoopIntro;
begin
end;

{ Waits a number of seconds or until a key is pressed, discarding the waiting keys before and after. Note: the clock is
  the time of day, so a wait across midnight lasts until a key is pressed.
  @param(seconds How long to wait.) }
procedure DelayOrKey(seconds: Word);
var
  start: LongInt;
  deadline: LongInt;
begin
  GameIo.DiscardPendingKeys;
  start := TextRend.GetTicks;
  deadline := start + 100 * seconds;
  repeat
  until KeyPressed or (TextRend.GetTicks >= deadline);
  GameIo.DiscardPendingKeys;
end;

{ Clears the credits area and writes the credits for the novel, the scenario and the game. }
procedure Credits;
begin
  Border.DrawCreditsFrame;
  TextRend.DisplayString( 2, 1, LightGreen, Black, 'based on the tsr novel "azure bonds"');
  TextRend.DisplayString( 6, 2, LightGreen, Black, 'by:');
  TextRend.DisplayString( 9, 2, LightCyan, Black, 'kate novak');
  TextRend.DisplayString(20, 2, LightGreen, Black, 'and');
  TextRend.DisplayString(24, 2, LightCyan, Black, 'jeff grubb');
  TextRend.DisplayString(10, 4, LightGreen, Black, 'scenario created by:');
  TextRend.DisplayString(11, 5, Yellow, Black, 'tsr, inc.');
  TextRend.DisplayString(21, 5, LightGreen, Black, 'and');
  TextRend.DisplayString(25, 5, Yellow, Black, 'ssi');
  TextRend.DisplayString(14, 6, LightCyan, Black, 'jeff grubb');
  TextRend.DisplayString(11, 7, LightCyan, Black, 'george mac donald');
  TextRend.DisplayString( 1, 9, LightGreen, Black, 'game created by:');
  TextRend.DisplayString(18, 9, Yellow, Black, 'ssi special projects');
  TextRend.DisplayString( 2, 11, Yellow, Black, 'project leader:');
  TextRend.DisplayString( 2, 12, LightCyan, Black, 'george mac donald');
  TextRend.DisplayString( 2, 14, Yellow, Black, 'programming:');
  TextRend.DisplayString( 2, 15, LightCyan, Black, 'scot bayless');
  TextRend.DisplayString( 2, 16, LightCyan, Black, 'russ brown');
  TextRend.DisplayString( 2, 17, LightCyan, Black, 'michael mancuso');
  TextRend.DisplayString( 2, 19, Yellow, Black, 'development:');
  TextRend.DisplayString( 2, 20, LightCyan, Black, 'david shelley');
  TextRend.DisplayString( 2, 21, LightCyan, Black, 'michael mancuso');
  TextRend.DisplayString( 2, 22, LightCyan, Black, 'oran kangas');
  TextRend.DisplayString(22, 11, Yellow, Black, 'graphic arts:');
  TextRend.DisplayString(22, 12, LightCyan, Black, 'tom wahl');
  TextRend.DisplayString(22, 13, LightCyan, Black, 'fred butts');
  TextRend.DisplayString(22, 14, LightCyan, Black, 'susan manley');
  TextRend.DisplayString(22, 15, LightCyan, Black, 'mark johnson');
  TextRend.DisplayString(22, 16, LightCyan, Black, 'cyrus lum');
  TextRend.DisplayString(22, 18, Yellow, Black, 'playtesting:');
  TextRend.DisplayString(22, 19, LightCyan, Black, 'jim jennings');
  TextRend.DisplayString(22, 20, LightCyan, Black, 'james kucera');
  TextRend.DisplayString(22, 21, LightCyan, Black, 'rick white');
  TextRend.DisplayString(22, 22, LightCyan, Black, 'robert daly');
end;

procedure Introduction;
var
  pic: Types.PImgBuf;
begin
  pic := nil;
  Blit.LoadPic('title', 1, False, 0, pic);
  Blit.ShowPic(0, 0, pic);
  Intro.DelayOrKey(5);
  if not GDVars.fullIntro then Exit;
  Blit.LoadPic('title', 2, False, 0, pic);
  Blit.ShowPic(0, 0, pic);
  Blit.FreePic(pic);
  Blit.LoadPic('title', 3, False, 0, pic);
  Blit.ShowPic(6, 11, pic);
  Blit.FreePic(pic);
  Intro.DelayOrKey(10);
  Blit.LoadPic('title', 4, False, 0, pic);
  SoundDrv.SoundCommand(GDConsts.sndIntro);
  Blit.ShowPic(0, 11, pic);
  Blit.FreePic(pic);
  Intro.DelayOrKey(10);
  TextRend.ClearScreen;
  Intro.Credits;
  Intro.DelayOrKey(10);
  TextRend.ClearScreen;
end;

begin
end.
