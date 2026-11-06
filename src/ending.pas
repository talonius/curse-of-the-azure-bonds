{ The ending: the victory screens, their animations, and the closing fireworks. }
{$O+,F+}
unit Ending;

interface

{ Plays the ending: switches to the won-game interface state, shows the six closing screens with their animations (the
  last animation repeats (10 - gameDelay) * 2 times with the script's animation request set), a portrait, the Shadowdale
  picture and the fireworks, then restores the interface state and the noncombat screen. }
procedure WinGame;

implementation

uses MenuCore, CharHlp, Dos, Crt, Blit, TextRend, Portrait, Types, GDConsts, GDVars, C_Gbvm;

const
  { Approximation of two pi used when spawning stars. }
  TWO_PI = 6.28318;
  { the interface mode once the game has been won }
  WON_GAME_MODE = 7;

{ Writes one pixel through the video BIOS.
  @param(col The pixel column.)
  @param(row The pixel row.)
  @param(color The pixel's color.) }
procedure WritePixel(col, row: Integer; color: Byte);
begin
  GDVars.videoRegs.AH := $0C;
  GDVars.videoRegs.AL := color;
  GDVars.videoRegs.BH := 0;
  GDVars.videoRegs.CX := col;
  GDVars.videoRegs.DX := row;
  Intr($10, Registers(GDVars.videoRegs));
end;

{ Reads one pixel through the video BIOS.
  @param(col The pixel column.)
  @param(row The pixel row.)
  @returns(The pixel's color.) }
function ReadPixel(col, row: Integer): Byte;
begin
  GDVars.videoRegs.AH := $0D;
  GDVars.videoRegs.BH := 0;
  GDVars.videoRegs.CX := col;
  GDVars.videoRegs.DX := row;
  Intr($10, Registers(GDVars.videoRegs));
  ReadPixel := GDVars.videoRegs.AL;
end;

{ Flashes palette register 9 to white and back on EGA and Tandy. }
procedure SetFinalPalette;
begin
  case GDVars.displayMode of
    1: begin
         Blit.SetPaletteRegister(9, 15);
         Delay(1);
         Blit.SetPaletteRegister(9, 9);
       end;
    2: begin
         Blit.SetPaletteRegisterTandy(9, 15);
         Delay(1);
         Blit.SetPaletteRegisterTandy(9, 9);
       end;
  end;
end;

{ Sets up a burst of 3 layers of 40 stars, in 1/32-pixel fixed point. Each layer gets a random burst velocity added to
  the spark's and each star a random spread; the layer's colors per stage come from mask and the display mode. Each star
  moves to stage 2 after the first tick and gets the ticks after which it moves to stages 3 to 5, and maxDelay becomes
  the longest burst. The pixel under each star is saved. Note: the stage 5 threshold is assigned to itself; no star
  leaves stage 5, so it is never read.
  @param(px The burst's pixel column.)
  @param(py The burst's pixel row.)
  @param(baseVx The spark's horizontal velocity, in 1/32 pixel per tick.)
  @param(baseVy The spark's vertical velocity, in 1/32 pixel per tick.)
  @param(mask Each layer's color seed: 1 dim, 2 to 6 a color.) }
procedure InitStarField(px, py, baseVx, baseVy: Integer; mask: Types.TLayerMask);
var
  j: Byte;
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  stage: Byte;
  rA: Real;
  rB: Real;
  { Unused in this version; see the other implementations of this routine. }
  speed: array[0..1] of Byte;
  thr4Base: Byte;
  thr2Base: Byte;
  { Unused in this version; see the other implementations of this routine. }
  thr5Base: Byte;
  thr3Base: Byte;
  layerVx: Integer;
  layerVy: Integer;
  { Unused in this version; see the other implementations of this routine. }
  color: Byte;
begin
  GDVars.maxDelay := 0;
  FillChar(GDVars.colors, SizeOf(GDVars.colors), 1);
  for i := 1 to 3 do begin
    if GDVars.displayMode = 0 then begin
      if mask[i] > 1 then begin
        GDVars.colors[i][1] := 2;
        GDVars.colors[i][2] := 3;
        GDVars.colors[i][3] := 3;
        GDVars.colors[i][4] := 3;
        GDVars.colors[i][5] := 2;
      end;
    end else begin
      if mask[i] > 1 then
        GDVars.colors[i][1] := 15;
      GDVars.colors[i][2] := 15;
      if mask[i] > 1 then
        GDVars.colors[i][3] := mask[i] + 8;
      GDVars.colors[i][4] := mask[i];
      GDVars.colors[i][5] := 1;
    end;
    thr4Base := Random(20) + 25;
    if GDVars.maxDelay < thr4Base then
      GDVars.maxDelay := thr4Base;
    thr2Base := Random(5) + 5;
    thr3Base := thr2Base + 15;
    rA := Random * Ending.TWO_PI;
    rB := Random * Ending.TWO_PI;
    layerVx := baseVx + Trunc((Random(10) + 24) * Cos(rA) * Cos(rB));
    layerVy := baseVy + Trunc((Random(10) + 24) * Sin(rA) * Cos(rB));
    for j := 1 to 40 do begin
      with GDVars.starBuf^[i][j] do begin
        rA := Random * Ending.TWO_PI;
        rB := Random * Ending.TWO_PI;
        posX := px;
        posY := py;
        fixX := posX * 32;
        fixY := posY * 32;
        velX := layerVx + Trunc(16.0 * Cos(rA) * Cos(rB));
        velY := layerVy + Trunc(16.0 * Sin(rA) * Cos(rB));
        size := 1;
        tail[1] := 1;
        tail[2] := thr2Base + Random(7) - 4;
        tail[3] := thr3Base + Random(11) - 6;
        tail[4] := thr4Base - Random(7);
        tail[5] := tail[5];
        tail[0] := Ending.ReadPixel(posX, posY);
      end;
    end;
  end;
end;

{ Runs the burst set up by InitStarField for maxDelay + 1 ticks (AdvanceField), then restores the pixels under the
  stars.
  @param(px Unused.)
  @param(py Unused.)
  @param(baseVx Unused.)
  @param(baseVy Unused.)
  @param(mask Unused.) }
procedure RunStarField(px, py, baseVx, baseVy: Integer; mask: Types.TLayerMask);
var
  star: Byte;
  layer: Byte;
  tick: Byte;
  { Unused in this version; see the other implementations of this routine. }
  setupState: array[0..21] of Byte;

  { Advances each star one tick and redraws the stars on rows 9 to 64; flashes the palette while star 1 is in stage 2. }
  procedure AdvanceField(curTick: Byte; buf: Types.PStarField);
  var
    tickMod6: Byte;
    star: Byte;
    layer: Byte;
  begin
    tickMod6 := tick mod 6;
    for layer := 1 to 3 do
      for star := 1 to 40 do
        with buf^[layer][star] do begin
          Inc(fixX, velX);
          Inc(fixY, velY);
          newX := fixX div 32;
          newY := fixY div 32;
          if tickMod6 = 0 then
            Inc(velY);
          if velX > 0 then
            Dec(velX)
          else if velX < 0 then
            Inc(velX);
          if tail[size] < curTick then
            if size < 5 then
              Inc(size);
        end;
    for star := 1 to 40 do
      for layer := 1 to 3 do
        with buf^[layer][star] do
          if (posY > 8) and (posY < 65) then
            Ending.WritePixel(posX, posY, tail[0]);
    for star := 1 to 40 do
      for layer := 1 to 3 do
        with buf^[layer][star] do begin
          posX := newX;
          posY := newY;
          if (posY > 8) and (posY < 65) then
            tail[0] := Ending.ReadPixel(posX, posY);
        end;
    for star := 1 to 40 do
      for layer := 1 to 3 do
        with buf^[layer][star] do
          if (posY > 8) and (posY < 65) then
            Ending.WritePixel(posX, posY, GDVars.colors[layer][size]);
    if buf^[1][1].size = 2 then
      Ending.SetFinalPalette;
  end;

begin
  for tick := 1 to GDVars.maxDelay + 1 do
    AdvanceField(tick, GDVars.starBuf);
  for star := 1 to 40 do
    for layer := 1 to 3 do
      with GDVars.starBuf^[layer][star] do
        if (posY > 8) and (posY < 65) then
          Ending.WritePixel(posX, posY, tail[0]);
end;

{ Moves a rising spark under gravity, 15 ms per step, then one step more. Drawing flashes the palette first and draws
  the spark in a random bright color on rows 9 to 64, restoring what was under it.
  @param(px The spark's pixel column, updated.)
  @param(py The spark's pixel row, updated.)
  @param(vx Its horizontal velocity in 1/32 pixel per step, updated.)
  @param(vy Its vertical velocity in 1/32 pixel per step, rising by 1 each step.)
  @param(steps The number of 15 ms steps.)
  @param(drawFlag Nonzero to draw the spark.) }
procedure StepSpark(var px, py, vx, vy: Integer; steps: Word; drawFlag: Byte);
var
  newpx: Integer;
  newpy: Integer;
  xf: Integer;
  yf: Integer;
  k: Word;
  saved: Byte;
begin
  if drawFlag <> 0 then
    Ending.SetFinalPalette;
  xf := px * 32;
  yf := py * 32;
  if drawFlag <> 0 then
    if (py > 8) and (py < 65) then
      saved := Ending.ReadPixel(px, py);
  for k := 1 to steps do begin
    xf := xf + vx;
    yf := yf + vy + 1;
    newpx := xf div 32;
    newpy := yf div 32;
    Inc(vy);
    if drawFlag <> 0 then
      if (py > 8) and (py < 65) then begin
        Ending.WritePixel(px, py, saved);
        saved := Ending.ReadPixel(newpx, newpy);
        Ending.WritePixel(newpx, newpy, Random(7) + 8);
      end;
    Delay(15);
    px := newpx;
    py := newpy;
  end;
  if drawFlag <> 0 then
    if (py > 8) and (py < 65) then
      Ending.WritePixel(px, py, saved);
  xf := xf + vx;
  yf := yf + vy + 1;
  newpx := xf div 32;
  newpy := yf div 32;
  Inc(vy);
  px := newpx;
  py := newpy;
end;

{ Shows fireworks until a key is pressed: at random moments a spark rises from (65, 65), first undrawn to find where it
  bursts, then drawn, and bursts into 1 or 2 colored layers (the rest dim). A key press is noticed when a burst ends. }
procedure VictoryAnim;
begin
  GetMem(GDVars.starBuf, SizeOf(GDVars.starBuf^));
  GDVars.animDone := 0;
  repeat
    if GDVars.animDone = 0 then begin
      if Random(10000) < 1 then begin
        FillChar(GDVars.sizes, SizeOf(GDVars.sizes), 1);
        GDVars.burstCount := Random(2) + 1;
        for GDVars.fillIdx := 1 to GDVars.burstCount do
          GDVars.sizes[GDVars.fillIdx] := Random(5) + 2;
        GDVars.px := 65;
        GDVars.py := 65;
        GDVars.vx := Random(20) + 35;
        GDVars.vy := -(Random(5) + 50);
        GDVars.saveVx := GDVars.vx;
        GDVars.saveVy := GDVars.vy;
        Ending.StepSpark(GDVars.px, GDVars.py, GDVars.vx, GDVars.vy, 60, 0);
        Ending.InitStarField(GDVars.px, GDVars.py, GDVars.vx, GDVars.vy, GDVars.sizes);
        GDVars.vx := GDVars.saveVx;
        GDVars.vy := GDVars.saveVy;
        GDVars.px := 65;
        GDVars.py := 65;
        Ending.StepSpark(GDVars.px, GDVars.py, GDVars.vx, GDVars.vy, 60, 1);
        Ending.RunStarField(GDVars.px, GDVars.py, GDVars.vx, GDVars.vy, GDVars.sizes);
        if KeyPressed then
          GDVars.animDone := Ord(ReadKey);
      end;
    end;
  until GDVars.animDone <> 0;
  FreeMem(GDVars.starBuf, SizeOf(GDVars.starBuf^));
end;

{ Plays a PIC animation, timing each frame by its delay times (gameDelay + 3), then frees it.
  @param(col The left column.)
  @param(row The top row.)
  @param(picId The animation's block in PIC.)
  @param(nCycles How many times to play it.) }
procedure PlayFinalAnim(col, row: Integer; picId, nCycles: Byte);
var
  a: Types.TAnimRec;
  tickNow: LongInt;
  tickLast: LongInt;
  cycles: Byte;
begin
  cycles := 0;
  tickLast := TextRend.GetTicks;
  FillChar(a, SizeOf(a), 0);
  Portrait.LoadAnimation('PIC', picId, 2, a);
  Blit.BlitTileClipped(col - 1, row - 1, 0, 0, a.frames[1].pic, GDVars.viewBuffer);
  Blit.FlushView;
  repeat
    Portrait.DisplayImageBuf(col, row, True, a.frames[a.current].pic);
    tickNow := TextRend.GetTicks;
    if tickNow - tickLast > a.frames[a.current].time * (GDVars.gameDelay + 3) then begin
      Inc(a.current);
      if a.current > a.count then begin
        a.current := 1;
        Inc(cycles);
      end;
      tickLast := tickNow;
    end;
  until cycles = nCycles;
  Portrait.FreeAnimation(a);
end;

procedure WinGame;
begin
  GDVars.prevIfcState := GDVars.ifcState;
  GDVars.ifcState := Ending.WON_GAME_MODE;

  { Screen 1: Tyranthraxus' spirit leaves the slain storm giant }
  TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, True, 'Tyranthraxus'' spirit coalesces over the slain ');
  TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, False,
                                'storm giant. ''You have defeated me. Were it not for ');
  TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, False,
                                'the Amulet of Lythander, I could possess you and rob ');
  TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, False,
                                'you of your victory. Still I can escape through the pool.');
  TextRend.DisplayAndPause(LightMagenta, 0, 'Press any key to continue.');

  { Screen 2: the gauntlet shatters the pool }
  TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, True,
                                'As you reach for the Pool of Radiance, he cries ');
  TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, False,
                                'out, ''Keep the Gauntlet of Moander away from there, you ');
  TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, False,
                                'will unleash dangerous energies. Stay back!'' As the ');
  TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, False,
                                'gauntlet contacts the pool, it contracts and shatters it.');
  Ending.PlayFinalAnim(3, 3, 74, 1);
  TextRend.DisplayAndPause(LightMagenta, 0, 'Press any key to continue.');
  MenuCore.ClearBottomLine;

  { Screen 3: Tyranthraxus slain }
  TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, True,
                                '''I am trapped without escape, you have succeeded ');
  TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, False,
                                'where armies have not. Gloat while you may, Tyranthraxus ');
  TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, False,
                                'is slain this day.'' Before your eyes he crumbles into ');
  TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, False, 'nothingness.');
  Ending.PlayFinalAnim(3, 3, 75, 1);
  TextRend.DisplayAndPause(LightMagenta, 0, 'Press any key to continue.');
  MenuCore.ClearBottomLine;

  { Screen 4: the last bond fades }
  TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, True, 'You are certain he is destroyed because your ');
  TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, False,
                                'final bond fades away. The Curse of the Azure Bonds ');
  TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, False,
                                'has finally been lifted from you! You are free at ');
  TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, False, 'last!');
  GDVars.zone0^[C_Gbvm.ANIM_REQUEST] := 1;
  Ending.PlayFinalAnim(3, 3, 77, (10 - GDVars.gameDelay) * 2);
  GDVars.zone0^[C_Gbvm.ANIM_REQUEST] := 0;
  Portrait.LoadPortraitBufs(65, 65);
  Portrait.DisplayPortraitBufs(3, 3, True);

  { Screen 5: the Knights of Myth Drannor }
  TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, True, 'The Knights of Myth Drannor rush in, ''');
  TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, False,
                                'Congratulations, you have destroyed the Flamed One. ');
  TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, False,
                                'With the power of Elminster, let us take you from ');
  TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, False, 'this  foul place, to a fine feast.''');
  TextRend.DisplayAndPause(LightMagenta, 0, 'Press any key to continue.');
  MenuCore.ClearBottomLine;
  Portrait.LoadBigPic(122);
  Portrait.DisplayBigPic;

  { Screen 6: the Shadowdale feast }
  TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, True,
                                'You are teleported to Shadowdale, where festivities ');
  TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, False,
                                'have already begun. A huge cheer goes up at your arrival. ');
  TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, False,
                                'Gharri and Nacacia, arm in arm, yell congratulations ');
  TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, False, 'from the nearby stands. ''You have won!''');

  Ending.VictoryAnim;
  GDVars.ifcState := GDVars.prevIfcState;
  CharHlp.DisplayNoncombatInterface;
end;

begin
end.
