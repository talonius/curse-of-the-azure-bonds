{ The 3D dungeon view: the map planes (walls, door features, cell events), the wall sets and their symbols, and drawing
  the first-person view and the automap. }
{$O+,F+,I-}
unit View3D;

interface

{ Does nothing. }
procedure NoopThreeDViewA;

{ Records the four colors the next drawing of the 3D view paints its background in.
  @param(pal0 The sky color.)
  @param(pal1 The color of the first ground band, painted on CGA only.)
  @param(pal2 The color of the second ground band.)
  @param(pal3 The color of the lower ground.) }
procedure SetView3DColors(pal0, pal1, pal2, pal3: Byte);

{ Paints the 3D view's background in the recorded colors; CGA uses its own bands. Outside CGA, under an open sky (a cell
  event below $80 and a light cyan sky) it draws the sun by the hour when the party faces east, south or west, and the
  north sky picture when it faces north; then it draws the horizon picture. }
procedure DrawBackdrop;

{ Reads a wall from the 3D map. Off the 16x16 map it returns 0 while script 0 or 10 is loaded, and otherwise wraps
  around the edges.
  @param(col The map column.)
  @param(row The map row.)
  @param(side The side of the cell: 0, 2, 4 or 6.)
  @returns(The wall type on that side, 0 for none.) }
function GetWallType(col, row: ShortInt; side: Byte): Byte;

{ Reads the door feature of a cell side from the 3D map; off the map it behaves as GetWallType.
  @param(col The map column.)
  @param(row The map row.)
  @param(side The side of the cell: 0, 2, 4 or 6.)
  @returns(The 2-bit feature (0 solid, 1 open, 2 locked, 3 wizard-locked), 1 where the side has no wall.) }
function GetBarrierType(col, row: ShortInt; side: Byte): Byte;

{ Reads a cell's event from the 3D map; off the map it behaves as GetWallType.
  @param(tileX The map column.)
  @param(tileY The map row.)
  @returns(The cell event.) }
function GetMapEvent(tileX, tileY: ShortInt): Byte;

{ Draws the view from a map cell: the automap when it is on, otherwise the 3D view, first the background and sky
  (DrawBackdrop), then the walls from two cells ahead back to the viewer's cell, nearer over farther.
  @param(tileX The viewer's map column.)
  @param(tileY The viewer's map row.)
  @param(facing The direction faced: 0, 2, 4 or 6.) }
procedure Display3DMapView(tileX, tileY, facing: Byte);

{ Loads a wall-definition block of WALLDEF<disk>.DAX into a wall slot, and into the following slots when the block holds
  several entries. Their symbol numbers are moved to each slot's symbol set and the matching 8x8 symbol sets are loaded
  (picture blockId * 10 + n for entry n of a multi-entry block). A slot outside 1 to 3 does nothing; a missing block, or
  one that does not fit in slots 1 to 3, reports it, waits for a key and quits.
  @param(blockId The block to load.)
  @param(wallset The first slot it fills, 1 to 3.) }
procedure LoadWallSet(blockId, wallset: Byte);

{ Loads a 3D map block of GEO<disk>.DAX (1026 bytes: a 2-byte header and the four 16x16 planes) and records its id for
  the script; a missing or wrong-sized block reports it, waits for a key and quits.
  @param(blockId The block to load.) }
procedure Load3DMap(blockId: Byte);

{ Does nothing. }
procedure NoopThreeDViewB;

{ Calls the priming entry of each overlay this unit uses, so the overlay manager loads them. }
procedure PrimeView3D;

implementation

uses Blit, Sym8x8, DaxIo, GameIo, EclTrace, Types, GDConsts, GDVars, Crt, C_Gbvm;

procedure NoopThreeDViewA;
begin
end;

procedure NoopThreeDViewB;
begin
end;

procedure PrimeView3D;
begin
  Sym8x8.PrimeSym8x8;
  EclTrace.PrimeEclTrace;
end;

{ Draws the automap: the 11x11 cells around the viewer, kept on the 16x16 map, each as the symbol for its walls ($104
  plus one bit per side), and the viewer's arrow ($100 plus facing div 2) on its cell.
  @param(col The viewer's map column.)
  @param(row The viewer's map row.)
  @param(facing The direction faced: 0, 2, 4 or 6.) }
procedure DrawAutoMap(col, row: ShortInt; facing: Byte);
var
  cRem: ShortInt;
  rRem: ShortInt;
  ri: ShortInt;
  ci: ShortInt;
  cClamp: ShortInt;
  rClamp: ShortInt;
  rr: ShortInt;
  cc: ShortInt;
  mask: Integer;
  { Unused in this version; see the other implementations of this routine. }
  symbolText: array[1..256] of Byte;
begin
  cClamp := col - 5;
  if cClamp < 0 then cClamp := 0;
  if cClamp > 5 then cClamp := 5;
  cRem := col - cClamp;
  rClamp := row - 5;
  if rClamp < 0 then rClamp := 0;
  if rClamp > 5 then rClamp := 5;
  rRem := row - rClamp;
  for ci := 0 to 10 do begin
    cc := ci + rClamp;
    for ri := 0 to 10 do begin
      rr := ri + cClamp;
      mask := $104;
      if View3D.GetWallType(rr, cc, 0) > 0 then Inc(mask);
      if View3D.GetWallType(rr, cc, 2) > 0 then Inc(mask, 2);
      if View3D.GetWallType(rr, cc, 4) > 0 then Inc(mask, 4);
      if View3D.GetWallType(rr, cc, 6) > 0 then Inc(mask, 8);
      Sym8x8.Put8x8Sym(ri + 3 - 1, ci + 3 - 1, mask, True, False);
    end;
  end;
  Sym8x8.Put8x8Sym(cRem + 3 - 1, rRem + 3 - 1, (facing div 2) + 256, True, False);
  Blit.FlushView;
end;

procedure SetView3DColors(pal0, pal1, pal2, pal3: Byte);
begin
  GDVars.skyCeilingColor := pal0;
  GDVars.ceilingBandColor := pal1;
  GDVars.midBandColor := pal2;
  GDVars.floorBandColor := pal3;
end;

procedure DrawBackdrop;
var
  hour: Word;
  bx0: Byte;
  by0: Byte;
  bx1: Byte;
  { Unused in this version; see the other implementations of this routine. }
  by1: Byte;
begin
  if GDVars.displayMode = 0 then begin
    Blit.FillPicRect(2, 16, 11, 43, GDVars.skyCeilingColor, GDConsts.iconColorMap, GDVars.viewBuffer);
    Blit.FillPicRect(2, 59, 11, 1, GDVars.ceilingBandColor, GDConsts.iconColorMap, GDVars.viewBuffer);
    Blit.FillPicRect(2, 60, 11, 2, GDVars.midBandColor, GDConsts.iconColorMap, GDVars.viewBuffer);
    Blit.FillPicRect(2, 62, 11, 42, GDVars.floorBandColor, GDConsts.iconColorMap, GDVars.viewBuffer);
  end else begin
    Blit.FillPicRect(2, 16, 11, 44, GDVars.skyCeilingColor, GDConsts.iconColorMap, GDVars.viewBuffer);
    Blit.FillPicRect(2, 60, 11, 2, GDVars.midBandColor, GDConsts.iconColorMap, GDVars.viewBuffer);
    Blit.FillPicRect(2, 62, 11, 42, GDVars.floorBandColor, GDConsts.iconColorMap, GDVars.viewBuffer);
    if View3D.GetMapEvent(GDVars.partyPos.mapX, GDVars.partyPos.mapY) < $80 then
      { an open sky }
      if GDVars.skyCeilingColor = LightCyan then begin
        bx0 := 2; by0 := 2; bx1 := 12; by1 := 12;
        hour := GDVars.zone0^[C_Gbvm.CLOCK_HOURS];
        case hour of
          1..5:
            case GDVars.partyPos.facing of
              2: Blit.BlitTileClipped(bx1 - 3, by0 + 5 - hour, 0, 1, GDVars.sunImage, GDVars.viewBuffer);
              4: if hour > 2 then
                   Blit.BlitTileClipped(bx0 + hour - 3, by0 + 5 - hour, 0, 1, GDVars.sunImage, GDVars.viewBuffer);
            end;
          13..18:
            case GDVars.partyPos.facing of
              6: Blit.BlitTileClipped(bx0, by0 + hour - 13, 0, 1, GDVars.sunImage, GDVars.viewBuffer);
              4: if hour < 16 then
                   Blit.BlitTileClipped(bx0 + hour - 8, by0 + hour - 13, 0, 1, GDVars.sunImage, GDVars.viewBuffer);
            end;
        end;
        if GDVars.partyPos.facing = 0 then
          Blit.BlitTileClipped(bx0, by0, 0, 1, GDVars.northSkyImage, GDVars.viewBuffer);
      end;
    Blit.BlitTileClipped(2, 7, 0, 1, GDVars.horizonImage, GDVars.viewBuffer);
  end;
end;

{ Draws a wall in one perspective form, geoWidth by geoHeight symbols, clipped to the 11x11 view; symbol 0 is left
  transparent.
  @param(startCol The view column of its top left symbol.)
  @param(startRow The view row of its top left symbol.)
  @param(wallType The wall type, an index into the loaded wall graphics.)
  @param(wallform The perspective form.) }
procedure DrawWallSlice(startCol, startRow: ShortInt; wallType, wallform: Byte);
var
  colEnd: Integer;
  rowEnd: Integer;
  col: Integer;
  row: Integer;
  startIdx: Byte;
begin
  startIdx := GDConsts.geoSymbolOffset[wallform];
  colEnd := GDConsts.geoWidth[wallform] + startCol - 1;
  rowEnd := GDConsts.geoHeight[wallform] + startRow - 1;
  for row := startRow to rowEnd do
    for col := startCol to colEnd do begin
      if (row >= 0) and (row <= 10) and (col >= 0) and (col <= 10) then
        if GDVars.wallGfx^.byType[wallType][startIdx] > 0 then
          Sym8x8.Put8x8Sym(col + 3 - 1, row + 3 - 1, GDVars.wallGfx^.byType[wallType][startIdx], True, True);
      Inc(startIdx);
    end;
end;

{ Tells whether a cell is on the 16x16 map.
  @param(col The map column.)
  @param(row The map row.)
  @returns(True when the cell is on the map.) }
function Valid3DCoords(col, row: ShortInt): Boolean;
begin
  if (col > 15) or (col < 0) or (row > 15) or (row < 0) then
    Valid3DCoords := False
  else
    Valid3DCoords := True;
end;

function GetBarrierType(col, row: ShortInt; side: Byte): Byte;
var
  feat: Byte;
begin
  if (not View3D.Valid3DCoords(col, row))
     and ((GDVars.currentScriptId = 0) or (GDVars.currentScriptId = 10)) then begin
    GetBarrierType := 0;
    Exit;
  end;
  if col > 15 then col := 0 else if col < 0 then col := 15;
  if row > 15 then row := 0 else if row < 0 then row := 15;
  feat := 1;
  if View3D.GetWallType(col, row, side) > 0 then
    case side of
      6: feat := (GDVars.map3d^.feat[row, col] and $C0) shr 6;
      4: feat := (GDVars.map3d^.feat[row, col] and $30) shr 4;
      2: feat := (GDVars.map3d^.feat[row, col] and $0C) shr 2;
      0: feat := GDVars.map3d^.feat[row, col] and $03;
    end;
  GetBarrierType := feat;
end;

function GetWallType(col, row: ShortInt; side: Byte): Byte;
begin
  if (not View3D.Valid3DCoords(col, row))
     and ((GDVars.currentScriptId = 0) or (GDVars.currentScriptId = 10)) then begin
    GetWallType := 0;
    Exit;
  end;
  if col > 15 then col := 0 else if col < 0 then col := 15;
  if row > 15 then row := 0 else if row < 0 then row := 15;
  case side of
    0: GetWallType := (GDVars.map3d^.wallP[row, col] and $F0) shr 4;
    2: GetWallType := GDVars.map3d^.wallP[row, col] and $0F;
    4: GetWallType := (GDVars.map3d^.wallQ[row, col] and $F0) shr 4;
    6: GetWallType := GDVars.map3d^.wallQ[row, col] and $0F;
  end;
end;

function GetMapEvent(tileX, tileY: ShortInt): Byte;
begin
  if (not View3D.Valid3DCoords(tileX, tileY))
     and ((GDVars.currentScriptId = 0) or (GDVars.currentScriptId = 10)) then begin
    GetMapEvent := 0;
    Exit;
  end;
  if tileX > 15 then tileX := 0 else if tileX < 0 then tileX := 15;
  if tileY > 15 then tileY := 0;
  if tileY < 0 then tileY := 15;
  GetMapEvent := GDVars.map3d^.floor[tileY, tileX];
end;

procedure Display3DMapView(tileX, tileY, facing: Byte);
var
  leftDir: Byte;
  rightDir: Byte;
  backDir: Byte;
  cx: Integer;
  cy: Integer;
  fdx: Integer;
  fdy: Integer;
  dx: Integer;
  dy: Integer;
  lat: Byte;
  accum: Integer;
  depth: Byte;
  cw: Byte;
  cwC: Byte;
  { Unused in this version; see the other implementations of this routine. }
  slack: Byte;
  prev: Byte;

begin
  if GDVars.automapOn then begin
    View3D.DrawAutoMap(tileX, tileY, facing);
    Exit;
  end;
  View3D.DrawBackdrop;
  leftDir := (facing + 6) mod 8;
  backDir := (facing + 4) mod 8;
  rightDir := (facing + 2) mod 8;
  cx := ShortInt(tileX);
  cy := ShortInt(tileY);
  fdx := GDConsts.directionDx[facing];
  fdy := GDConsts.directionDy[facing];
  depth := 2;
  Inc(cx, depth * fdx);
  Inc(cy, depth * fdy);
  repeat
    case depth of
    2:
    begin
      { Two cells ahead, from the center leftward: the walls facing the viewer and their form-9 edges. }
      dx := cx; dy := cy; lat := 0; accum := 0; prev := 0;
      while lat < 4 do begin
        cw := View3D.GetWallType(Byte(dx), Byte(dy), facing);
        if not View3D.Valid3DCoords(ShortInt(Byte(dx)), ShortInt(Byte(dy))) then
          if View3D.GetWallType(Byte(dx), Byte(dy), rightDir) = 0 then prev := 0;
        if cw <> 0 then begin
          if prev > 0 then View3D.DrawWallSlice(GDConsts.geoStartCol[9] + accum + 1, GDConsts.geoStartRow[9], prev, 9);
          prev := cw;
          View3D.DrawWallSlice(GDConsts.geoStartCol[0] + accum, GDConsts.geoStartRow[0], cw, 0);
        end else begin
          if prev > 0 then
            if View3D.GetWallType(Byte(dx - GDConsts.directionDx[leftDir]), Byte(dy - GDConsts.directionDy[leftDir]),
                                  leftDir) <> 0 then
              View3D.DrawWallSlice(GDConsts.geoStartCol[9] + accum + 1, GDConsts.geoStartRow[9], prev, 9);
          prev := 0;
        end;
        Inc(lat); Dec(accum, 2);
        dx := dx + GDConsts.directionDx[leftDir]; dy := dy + GDConsts.directionDy[leftDir];
      end;
      { The same, from the center rightward. }
      dx := cx; dy := cy; lat := 0; accum := 0; prev := 0;
      while lat < 4 do begin
        cw := View3D.GetWallType(Byte(dx), Byte(dy), facing);
        if not View3D.Valid3DCoords(ShortInt(Byte(dx)), ShortInt(Byte(dy))) then
          if View3D.GetWallType(Byte(dx), Byte(dy), leftDir) = 0 then prev := 0;
        if cw <> 0 then begin
          if prev > 0 then View3D.DrawWallSlice(GDConsts.geoStartCol[9] + accum - 1, GDConsts.geoStartRow[9], prev, 9);
          prev := cw;
          View3D.DrawWallSlice(GDConsts.geoStartCol[0] + accum, GDConsts.geoStartRow[0], cw, 0);
        end else begin
          if prev > 0 then
            if View3D.GetWallType(Byte(dx - GDConsts.directionDx[rightDir]), Byte(dy - GDConsts.directionDy[rightDir]),
                                  rightDir) <> 0 then
              View3D.DrawWallSlice(GDConsts.geoStartCol[9] + accum - 1, GDConsts.geoStartRow[9], prev, 9);
          prev := 0;
        end;
        Inc(lat); Inc(accum, 2);
        dx := dx + GDConsts.directionDx[rightDir]; dy := dy + GDConsts.directionDy[rightDir];
      end;
      { The left-hand side walls of those cells, from the center leftward. }
      dx := cx; dy := cy; lat := 0; accum := 0;
      while lat < 3 do begin
        cwC := View3D.GetWallType(Byte(dx), Byte(dy), leftDir);
        if cwC <> 0 then
          if lat = 0 then View3D.DrawWallSlice(GDConsts.geoStartCol[1] + accum, GDConsts.geoStartRow[1], cwC, 1)
          else View3D.DrawWallSlice(GDConsts.geoStartCol[1] + accum - 1, GDConsts.geoStartRow[1], cwC, 1);
        Inc(lat); Dec(accum, 2);
        dx := dx + GDConsts.directionDx[leftDir]; dy := dy + GDConsts.directionDy[leftDir];
      end;
      { The right-hand side walls, from the center rightward. }
      dx := cx; dy := cy; lat := 0; accum := 0;
      while lat < 3 do begin
        cwC := View3D.GetWallType(Byte(dx), Byte(dy), rightDir);
        if cwC <> 0 then
          if lat = 0 then View3D.DrawWallSlice(GDConsts.geoStartCol[2] + accum, GDConsts.geoStartRow[2], cwC, 2)
          else View3D.DrawWallSlice(GDConsts.geoStartCol[2] + accum + 1, GDConsts.geoStartRow[2], cwC, 2);
        Inc(lat); Inc(accum, 2);
        dx := dx + GDConsts.directionDx[rightDir]; dy := dy + GDConsts.directionDy[rightDir];
      end;
    end;
    1:
    begin
      dx := cx + GDConsts.directionDx[leftDir]; dx := dx + GDConsts.directionDx[leftDir]; dy := cy +
        GDConsts.directionDy[leftDir]; dy := dy + GDConsts.directionDy[leftDir]; lat := 0; accum := -6;
      while lat < 3 do begin
        cw := View3D.GetWallType(Byte(dx), Byte(dy), facing);
        if cw <> 0 then View3D.DrawWallSlice(GDConsts.geoStartCol[3] + accum, GDConsts.geoStartRow[3], cw, 3);
        cwC := View3D.GetWallType(Byte(dx), Byte(dy), leftDir);
        if cwC <> 0 then View3D.DrawWallSlice(GDConsts.geoStartCol[4] + accum, GDConsts.geoStartRow[4], cwC, 4);
        Inc(lat); Inc(accum, 3);
        dx := dx + GDConsts.directionDx[rightDir]; dy := dy + GDConsts.directionDy[rightDir];
      end;
      dx := cx + GDConsts.directionDx[rightDir]; dx := dx + GDConsts.directionDx[rightDir]; dy := cy +
        GDConsts.directionDy[rightDir]; dy := dy + GDConsts.directionDy[rightDir]; lat := 0; accum := 6;
      while lat < 3 do begin
        cw := View3D.GetWallType(Byte(dx), Byte(dy), facing);
        if cw <> 0 then View3D.DrawWallSlice(GDConsts.geoStartCol[3] + accum, GDConsts.geoStartRow[3], cw, 3);
        cwC := View3D.GetWallType(Byte(dx), Byte(dy), rightDir);
        if cwC <> 0 then View3D.DrawWallSlice(GDConsts.geoStartCol[5] + accum, GDConsts.geoStartRow[5], cwC, 5);
        Inc(lat); Dec(accum, 3);
        dx := dx + GDConsts.directionDx[leftDir]; dy := dy + GDConsts.directionDy[leftDir];
      end;
    end;
    0:
    begin
      dx := cx + GDConsts.directionDx[leftDir]; dy := cy + GDConsts.directionDy[leftDir]; lat := 0; accum := -7;
      while lat < 2 do begin
        cw := View3D.GetWallType(Byte(dx), Byte(dy), facing);
        if cw <> 0 then View3D.DrawWallSlice(GDConsts.geoStartCol[6] + accum, GDConsts.geoStartRow[6], cw, 6);
        cwC := View3D.GetWallType(Byte(dx), Byte(dy), leftDir);
        if cwC <> 0 then View3D.DrawWallSlice(GDConsts.geoStartCol[7] + accum, GDConsts.geoStartRow[7], cwC, 7);
        Inc(lat); Inc(accum, 7);
        dx := dx + GDConsts.directionDx[rightDir]; dy := dy + GDConsts.directionDy[rightDir];
      end;
      dx := cx + GDConsts.directionDx[rightDir]; dy := cy + GDConsts.directionDy[rightDir]; lat := 0; accum := 7;
      while lat < 2 do begin
        cw := View3D.GetWallType(Byte(dx), Byte(dy), facing);
        if cw <> 0 then View3D.DrawWallSlice(GDConsts.geoStartCol[6] + accum, GDConsts.geoStartRow[6], cw, 6);
        cwC := View3D.GetWallType(Byte(dx), Byte(dy), rightDir);
        if cwC <> 0 then View3D.DrawWallSlice(GDConsts.geoStartCol[8] + accum, GDConsts.geoStartRow[8], cwC, 8);
        Inc(lat); Dec(accum, 7);
        dx := dx + GDConsts.directionDx[leftDir]; dy := dy + GDConsts.directionDy[leftDir];
      end;
    end;
    end;
    cx := cx + GDConsts.directionDx[backDir]; cy := cy + GDConsts.directionDy[backDir];
    Dec(depth);
  { The counter wraps after depth 0. }
  until depth = 255;
  Blit.FlushView;
end;

procedure LoadWallSet(blockId, wallset: Byte);
var
  n: Word;
  data: Types.PByteArr;
  offset: Word;
  delta: Integer;
  rr: Byte;
  entryIdx: Word;
  cc: Word;
  numEntries: Byte;
  ns: string[1];
  { Unused in this version; see the other implementations of this routine. }
  bk: Byte;
begin
  if (wallset < 1) or (wallset > 3) then Exit;
  Str(GDVars.diskIndex, ns);
  DaxIo.LoadDax('WALLDEF' + ns, '.dax', blockId, n, data);
  if (n = 0) or ((n div SizeOf(Types.TWallEntry)) + wallset > 4) then begin
    Blit.RestoreVideoMode;
    WriteLn('Unable to load ', blockId, ' from WALLDEF' + ns + '.');
    bk := Byte(GameIo.ReadGameKey);
    Blit.RestoreVideoMode;
    GameIo.ExitGame;
  end;
  delta := Integer(GDConsts.symSetBase[wallset]) - Integer(GDConsts.symSetBase[1]);
  offset := 0;
  entryIdx := 1;
  repeat
    Move(data^[offset], GDVars.wallGfx^.bySlot[wallset + entryIdx - 1], SizeOf(Types.TWallEntry));
    Inc(offset, SizeOf(Types.TWallEntry));
    Inc(entryIdx);
  until offset >= n;
  FreeMem(data, n);
  numEntries := entryIdx - 1;
  for entryIdx := 1 to numEntries do begin
    if (wallset + entryIdx - 1) in [1..3] then begin
      GDVars.wallDefinitions[wallset + entryIdx - 1].wallDefId := 65535;
      GDVars.wallDefinitions[wallset + entryIdx - 1].symbolSlot := 65535;
      for rr := 1 to 5 do
        for cc := 0 to 155 do
          if GDVars.wallGfx^.bySlot[wallset + entryIdx - 1][rr][cc] >= GDConsts.wallThreshold then
            Inc(GDVars.wallGfx^.bySlot[wallset + entryIdx - 1][rr][cc], delta);
      if numEntries > 1 then
        Sym8x8.Load8x8Set(blockId * 10 + entryIdx, wallset + entryIdx - 1)
      else
        Sym8x8.Load8x8Set(blockId, wallset + entryIdx - 1);
    end;
  end;
  GDVars.wallDefinitions[wallset].wallDefId := blockId;
  GDVars.wallDefinitions[wallset].symbolSlot := wallset;
end;

procedure Load3DMap(blockId: Byte);
var
  n: Word;
  data: Types.PByteArr;
  offset: Word;
  ns: string[1];
  { Unused in this version; see the other implementations of this routine. }
  bk: Byte;
begin
  Str(GDVars.diskIndex, ns);
  DaxIo.LoadDax('GEO' + ns, '.dax', blockId, n, data);
  if (n = 0) or (n <> 1026) then begin
    Blit.RestoreVideoMode;
    WriteLn('Unable to load geo in Load3DMap.');
    bk := Byte(GameIo.ReadGameKey);
    Blit.RestoreVideoMode;
    GameIo.ExitGame;
  end;
  offset := 2;
  Move(data^[offset], GDVars.map3d^.wallP, SizeOf(Types.TMapPlane)); Inc(offset, SizeOf(Types.TMapPlane));
  Move(data^[offset], GDVars.map3d^.wallQ, SizeOf(Types.TMapPlane)); Inc(offset, SizeOf(Types.TMapPlane));
  Move(data^[offset], GDVars.map3d^.floor, SizeOf(Types.TMapPlane)); Inc(offset, SizeOf(Types.TMapPlane));
  Move(data^[offset], GDVars.map3d^.feat, SizeOf(Types.TMapPlane));
  FreeMem(data, n);
  GDVars.zone0^[C_Gbvm.GEO_MAP_ID] := blockId;
end;

begin
end.
