{ Combat setup: builds the dungeon or wilderness arena, loads its tiles and places the creatures. }
{$O+,F+}
{$A-}
{$R-}
{$S-}
unit CombatSt;

interface

{ Prepares a battle: turns off the message typing delay and quick magic, frees the animation, portrait and big pictures,
  announces 'A battle begins...', resets the round counter, the round limit (15), the attack roll, the downed list, the
  cloud lists, the last missile item and the attacked-allies flag, builds the arena, sets up and places the creatures,
  and allocates the combat effect sprite. Then centers the view on the first creature, draws the combat screen, fires
  each creature's condition-8 and condition-22 effects, figures the hostiles' hit-point percentage and enters the combat
  interface state. }
procedure CombatStart;

{ Calls the priming entry of each overlay this unit uses, so the overlay manager loads them. }
procedure PrimeCombatSt;

implementation

uses Portrait, TextRend, Blit, MenuCore, GameIo, CbtMap, FxEngine, CbtActs, MapTiles, View3D, CharGen, CharHlp, Types,
  ViewChar, Pathing, SaveLoad, EclTrace, GDConsts, GDVars, C_Ifc, C_Terr, C_Gbvm, Crt;

const
  { GBVM script variable (a word index into GDVars.zone0^) holding the party's column on the area map. }
  MAP_X = $4BC3;
  { GBVM script variable (a word index into GDVars.zone0^) holding the party's row on the area map. }
  MAP_Y = $4BC4;

procedure PrimeCombatSt;
begin
  ViewChar.PrimeViewChar;
  Pathing.PrimePathing;
  View3D.PrimeView3D;
  CbtMap.PrimeCbtMap;
  SaveLoad.PrimeSaveLoad;
  MenuCore.PrimeMenuCore;
  CharHlp.PrimeCharHlp;
  FxEngine.PrimeFxEngine;
  CbtActs.PrimeCbtActs;
  MapTiles.PrimeMapTiles;
  CharGen.PrimeCharGen;
  EclTrace.PrimeEclTrace;
  Portrait.PrimePortrait;
end;

{ Plots a terrain at a spot of the current dungeon cell's skewed block (skewX, skewY), clipped to the arena; the arena
  cell stores terrain + 1.
  @param(col The spot's column in the block.)
  @param(row The spot's row in the block.)
  @param(terrain The terrain, one less than the value stored.) }
procedure PlotCell(col, row, terrain: Byte);
var
  x: ShortInt;
  y: ShortInt;
begin
  x := GDVars.skewX * 6 + GDVars.skewY * 5 + 21 + col;
  y := GDVars.skewY * 5 + 10 + row;
  if (x >= 0) and (x <= 49) and (y >= 0) and (y <= 24) then
    GDVars.combatArena^.cells[y, x] := terrain + 1;
end;

{ Decorates the current dungeon cell's floor. It records whether the cell is enclosed: at least one solid wall, no door,
  and no opposed pair of solid walls unless all four are solid. When the caller's map-event decoration flag is set and
  the cell is enclosed, each of its six middle spots that is open floor (terrain 22) has an even chance of becoming
  terrain 26, and each open-floor spot beside such a spot a nine in ten chance of becoming terrain 27. }
procedure DecorateCell;
var
  i: ShortInt;
  j: ShortInt;
  px: ShortInt;
  py: ShortInt;
  px2: ShortInt;
  py2: ShortInt;
  k: Byte;
begin
  GDVars.enclosed := ((GDVars.wallN = 1) or (GDVars.wallE = 1) or (GDVars.wallS = 1) or (GDVars.wallW = 1)) and
    ((GDVars.wallN <> 1) or (GDVars.wallS <> 1) or ((GDVars.wallE = 1) and (GDVars.wallW = 1))) and
    ((GDVars.wallE <> 1) or (GDVars.wallW <> 1) or ((GDVars.wallN = 1) and (GDVars.wallS = 1))) and
    ((GDVars.wallN <> 3) and (GDVars.wallE <> 3) and (GDVars.wallS <> 3) and (GDVars.wallW <> 3));
  for i := 2 to 3 do
    for j := 2 to 4 do begin
      px := GDVars.skewX * 6 + GDVars.skewY * 5 + 21 + i + j;
      py := GDVars.skewY * 5 + 10 + j;
      if (px >= 0) and (px <= 49) and (py >= 0) and (py <= 24) then
        if GDConsts.terrainInfo[GDVars.combatArena^.cells[py, px]].tileId = 22 then
          if GDVars.featureOk <> 0 then
            if GDVars.enclosed then
              if FxEngine.RollDice(1, 10) <= 5 then begin
                GDVars.combatArena^.cells[py, px] := 26;
                for k := 1 to 4 do begin
                  px2 := GDConsts.featureDx[k] + px;
                  py2 := GDConsts.featureDy[k] + py;
                  if (px2 >= 0) and (px2 <= 49) and (py2 >= 0) and (py2 <= 24) then
                    if GDConsts.terrainInfo[GDVars.combatArena^.cells[py2, px2]].tileId = 22 then
                      if FxEngine.RollDice(1, 10) <= 9 then
                        GDVars.combatArena^.cells[py2, px2] := 27;
                end;
              end;
    end;
end;

{ Classifies the edge between a dungeon cell and its neighbor in a direction, ORing the classes seen from both sides: 0
  open, 1 solid, 3 door-like (a wall with a passable barrier). A side with no barrier is solid, a side with no wall is
  open, and anything else is door-like. Off the 16x16 map, east and west sides on the party's row are open and the rest
  solid.
  @param(x The cell's column.)
  @param(y The cell's row.)
  @param(dir The direction of the neighbor, 0..7.)
  @returns(The edge's class.) }
function WallBetween(x, y: ShortInt; dir: Byte): Byte;
var
  nearKind: Byte;
  farKind: Byte;
  opp: Byte;

  { Classifies one side of an edge. }
  function GetWallKind(px, py: ShortInt; pdir: Byte): Byte;
  begin
    if (px >= 0) and (px <= 15) and (py >= 0) and (py <= 15) then begin
      if View3D.GetBarrierType(px, py, pdir) = 0 then
        GetWallKind := 1
      else if View3D.GetWallType(px, py, pdir) = 0 then
        GetWallKind := 0
      else
        GetWallKind := 3;
    end else begin
      if (py = GDVars.partyPos.mapY) and ((pdir = 2) or (pdir = 6)) then
        GetWallKind := 0
      else
        GetWallKind := 1;
    end;
  end;

begin
  opp := (dir + 4) mod 8;
  nearKind := GetWallKind(x, y, dir);
  farKind := GetWallKind(x + GDConsts.directionDx[dir], y + GDConsts.directionDy[dir], opp);
  WallBetween := nearKind or farKind;
end;

{ Builds a dungeon arena from the 13x5 map window around the party, mapping each cell to a skewed 6x5 block of the arena
  and drawing its floor, walls and corners, then decorating it. Each corner's tiles follow the cell's two walls there
  and whether the neighbors' facing edges are open. }
procedure BuildDungeonArena;
var
  cellX: ShortInt;
  cellY: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  cornerIdx: Integer;

  { Draws the current cell's floor (spots 0..5 on rows 2..4) and its west wall. }
  procedure DrawFloorWestWall;
  var
    c: Byte;
    r: Byte;
  begin
    for r := 2 to 4 do
      for c := 0 to 5 do
        CombatSt.PlotCell(c, r, 22);
    if GDVars.wallW = 1 then begin
      for r := 2 to 4 do begin
        CombatSt.PlotCell(r - 1, r, 4);
        CombatSt.PlotCell(r, r, 3);
        CombatSt.PlotCell(r + 1, r, 13);
      end;
    end else if GDVars.wallW = 3 then begin
      CombatSt.PlotCell(1, 2, 8);
      CombatSt.PlotCell(5, 4, 0);
    end;
  end;

  { Draws the current cell's north wall band (spots 3..4 on rows 0..1): wall terrain when solid, floor otherwise. }
  procedure DrawNorthWall;
  var
    { Unused in this version; see the other implementations of this routine. }
    column: Integer;
  begin
    if GDVars.wallN = 1 then begin
      CombatSt.PlotCell(3, 0, 5);
      CombatSt.PlotCell(4, 0, 5);
      CombatSt.PlotCell(3, 1, 10);
      CombatSt.PlotCell(4, 1, 10);
    end else begin
      CombatSt.PlotCell(3, 0, 22);
      CombatSt.PlotCell(4, 0, 22);
      CombatSt.PlotCell(3, 1, 22);
      CombatSt.PlotCell(4, 1, 22);
    end;
  end;

  { Fills the current cell's north-west corner (spots 1..2 on rows 0..1). }
  procedure FillCornerNorthWest;
  var
    k: Byte;
    tile1: Byte;
    tile3: Byte;
    tile2: Byte;
    tile4: Byte;
    open: Byte;
  begin
    if (CombatSt.WallBetween(cellX, cellY - 1, 6) = 0) and (CombatSt.WallBetween(cellX - 1, cellY, 0) = 0) then
      open := 1
    else
      open := 0;
    for k := 1 to 4 do
      case k of
        1: case Char(GDVars.wallN) of
             #0: case Char(GDVars.wallW) of
                  #0: tile1 := 22;
                  #3: tile1 := 13;
                  #1: if open <> 0 then tile1 := 0 else tile1 := 13;
                end;
             #3, #1: if GDVars.wallW = 0 then begin
                     if open <> 0 then tile1 := 15 else tile1 := 5;
                   end else begin
                     if open <> 0 then tile1 := 18 else tile1 := 2;
                   end;
           end;
        2: case Char(GDVars.wallN) of
             #0: tile2 := 22;
             #3: tile2 := 17;
             #1: tile2 := 5;
           end;
        3: case Char(GDVars.wallW) of
             #0: if GDVars.wallN = 0 then
                  tile3 := 22
                else if open <> 0 then
                  tile3 := 16
                else
                  tile3 := 10;
             #3: if open <> 0 then tile3 := 20 else tile3 := 7;
             #1: if open <> 0 then tile3 := 1 else tile3 := 3;
           end;
        4: case Char(GDVars.wallW) of
             #0, #3: case Char(GDVars.wallN) of
                     #0: tile4 := 22;
                     #3: tile4 := 23;
                     #1: tile4 := 10;
                   end;
             #1: case Char(GDVars.wallN) of
                  #0: tile4 := 13;
                  #3: tile4 := 21;
                  #1: tile4 := 6;
                end;
           end;
      end;
    CombatSt.PlotCell(1, 0, tile1);
    CombatSt.PlotCell(2, 0, tile2);
    CombatSt.PlotCell(1, 1, tile3);
    CombatSt.PlotCell(2, 1, tile4);
  end;

  { Fills the current cell's north-east corner (spots 5..6 on rows 0..1, reaching into the next block). }
  procedure FillCornerNorthEast;
  var
    k: Byte;
    tile1: Byte;
    tile3: Byte;
    tile2: Byte;
    tile4: Byte;
    open: Byte;
    kN: Byte;
    kE: Byte;
  begin
    kN := CombatSt.WallBetween(cellX, cellY - 1, 2);
    kE := CombatSt.WallBetween(cellX + 1, cellY, 0);
    if (kN = 0) and (kE = 0) then
      open := 1
    else
      open := 0;
    for k := 1 to 4 do
      case k of
        1: case Char(GDVars.wallN) of
             #0: if kN = 1 then tile1 := 4 else tile1 := 22;
             #3: tile1 := 15;
             #1: tile1 := 5;
           end;
        2: if GDVars.wallN = 0 then begin
             case Char(kN) of
               #0: tile2 := 22;
               #3: if (GDVars.wallE = 0) and (kE <> 0) then
                    tile2 := 24
                  else
                    tile2 := 1;
               #1: if GDVars.wallE = 0 then begin
                    if kE <> 0 then tile2 := 11 else tile2 := 7;
                  end else
                    tile2 := 3;
             end;
           end else begin
             if GDVars.wallE <> 0 then
               tile2 := 9
             else if kE <> 0 then
               tile2 := 5
             else if open <> 0 then
               tile2 := 17
             else
               tile2 := 19;
           end;
        3: case Char(GDVars.wallN) of
             #0: tile3 := 22;
             #3: tile3 := 16;
             #1: tile3 := 10;
           end;
        4: if GDVars.wallN = 0 then begin
             if kN = 0 then
               tile4 := 22
             else if GDVars.wallE <> 0 then
               tile4 := 4
             else if kE = 0 then
               tile4 := 8
             else
               tile4 := 12;
           end else begin
             if GDVars.wallE <> 0 then
               tile4 := 14
             else if kE = 0 then
               tile4 := 23
             else
               tile4 := 10;
           end;
      end;
    CombatSt.PlotCell(5, 0, tile1);
    CombatSt.PlotCell(6, 0, tile2);
    CombatSt.PlotCell(5, 1, tile3);
    CombatSt.PlotCell(6, 1, tile4);
  end;

begin
  for GDVars.skewY := -2 to 2 do
    for GDVars.skewX := -6 to 6 do begin
      cellX := GDVars.partyPos.mapX + GDVars.skewX;
      cellY := GDVars.partyPos.mapY + GDVars.skewY;
      GDVars.wallW := CombatSt.WallBetween(cellX, cellY, 6);
      GDVars.wallN := CombatSt.WallBetween(cellX, cellY, 0);
      GDVars.wallE := CombatSt.WallBetween(cellX, cellY, 2);
      GDVars.wallS := CombatSt.WallBetween(cellX, cellY, 4);
      DrawFloorWestWall;
      DrawNorthWall;
      FillCornerNorthWest;
      FillCornerNorthEast;
      GDVars.featureOk := View3D.GetMapEvent(cellX, cellY) and $40;
      CombatSt.DecorateCell;
    end;
end;

{ Reads the feature-class bits of the wilderness terrain under the party, which steer the random arena generators.
  @returns(The class bits.) }
function TerrainClassOf: Byte;
begin
  TerrainClassOf := GDConsts.terrainClasses[GDVars.terrainChar];
end;

{ Lays a river on a percentile roll: 35% for terrain class bit $20, 75% for bit $10 (which wins when both are set), and
  no river otherwise. It runs diagonally down the arena from a column near the middle, one column right per row, in
  terrains 60/61 beside 62/63, with a 1-in-20 chance per row of a ford (64 and 65). }
procedure PlaceRiver;
var
  thresh: Byte;
  { Unused in this version; see the other implementations of this routine. }
  startCol: ShortInt;
  col: ShortInt;
  row: ShortInt;

  { Plots a ford at the cell right of (row, col) and the one below it, clipped to the arena. }
  procedure PlotFord(row, col: ShortInt);
  begin
    if col < 49 then
      GDVars.combatArena^.cells[row, col + 1] := 64;
    if (row < 24) and (col < 49) then
      GDVars.combatArena^.cells[row + 1, col + 1] := 65;
  end;

begin
  thresh := 0;
  if CombatSt.TerrainClassOf and $20 <> 0 then thresh := 35;
  if CombatSt.TerrainClassOf and $10 <> 0 then thresh := 75;
  if FxEngine.RollDice(1, 100) > thresh then Exit;
  col := 34 - FxEngine.RollDice(5, 4);
  while (col + 2) mod 7 > 0 do Dec(col);
  startCol := col;
  for row := 0 to 24 do
    if col <= 49 then begin
      GDVars.combatArena^.cells[row, col] := FxEngine.RollDice(1, 2) + 59;
      if col < 49 then
        GDVars.combatArena^.cells[row, col + 1] := FxEngine.RollDice(1, 2) + 61;
      if FxEngine.RollDice(1, 20) = 1 then
        PlotFord(row, col);
      Inc(col);
    end;
end;

{ Plants trees on vertically paired grass cells (no trees for terrain class bit $80): density 10% adjusted by class bits
  2 (-5), 4 (-2), $40 (+5) and 8 (+10). A hit plants a one-cell tree (42/43) or, on a second failed roll, a two-cell
  tree (top 32..36, bottom 37..41). }
procedure PlaceTrees;
var
  { Unused in this version; see the other implementations of this routine. }
  roll: Byte;
  col: ShortInt;
  row: ShortInt;
  dens: ShortInt;
begin
  if CombatSt.TerrainClassOf and $80 <> 0 then Exit;
  dens := 10;
  if CombatSt.TerrainClassOf and $02 <> 0 then Dec(dens, 5);
  if CombatSt.TerrainClassOf and $04 <> 0 then Dec(dens, 2);
  if CombatSt.TerrainClassOf and $40 <> 0 then Inc(dens, 5);
  if CombatSt.TerrainClassOf and $08 <> 0 then Inc(dens, 10);
  if dens < 0 then dens := 1;
  for col := 0 to 49 do
    for row := 1 to 24 do
      if (GDConsts.terrainInfo[GDVars.combatArena^.cells[row, col]].tileId = 22) and
          (GDConsts.terrainInfo[GDVars.combatArena^.cells[row - 1, col]].tileId = 22) and
          (dens >= FxEngine.RollDice(1, 100)) then
        if dens >= FxEngine.RollDice(1, 100) then
          GDVars.combatArena^.cells[row, col] := FxEngine.RollDice(1, 2) + 41
        else begin
          GDVars.combatArena^.cells[row - 1, col] := FxEngine.RollDice(1, 5) + 31;
          GDVars.combatArena^.cells[row, col] := FxEngine.RollDice(1, 5) + 36;
        end;
end;

{ Scatters features over the grass cells, with weights chosen by a base of 50 adjusted by the terrain class bits; a
  total outside -30..110 scatters nothing. Each cell rolls 1d100 against five stacked weights, which pick features
  58/59, 48/49, 44..47, 55..57 and 50..53 in turn; a roll past them leaves the cell alone. }
procedure ScatterFeatures;
var
  col: ShortInt;
  row: ShortInt;
  weight: Integer;

  { Plants a feature on one cell, picked by a roll against the stacked weights. }
  procedure ScatterOneCell(col, row: ShortInt; weight1, weight2, weight3, weight4, weight5: Byte);
  var
    roll: Byte;
  begin
    roll := FxEngine.RollDice(1, 100);
    if roll <= weight1 then
      GDVars.combatArena^.cells[row, col] := FxEngine.RollDice(1, 2) + 57
    else if roll <= weight1 + weight2 then
      GDVars.combatArena^.cells[row, col] := FxEngine.RollDice(1, 2) + 47
    else if roll <= weight1 + weight2 + weight3 then
      GDVars.combatArena^.cells[row, col] := FxEngine.RollDice(1, 4) + 43
    else if roll <= weight1 + weight2 + weight3 + weight4 then
      GDVars.combatArena^.cells[row, col] := FxEngine.RollDice(1, 3) + 54
    else if roll <= weight1 + weight2 + weight3 + weight4 + weight5 then
      GDVars.combatArena^.cells[row, col] := FxEngine.RollDice(1, 4) + 49;
  end;

begin
  weight := 50;
  if CombatSt.TerrainClassOf and $10 <> 0 then Inc(weight, 10);
  if CombatSt.TerrainClassOf and $20 <> 0 then Inc(weight, 30);
  if CombatSt.TerrainClassOf and $40 <> 0 then Inc(weight, 20);
  if CombatSt.TerrainClassOf and $04 <> 0 then Dec(weight, 10);
  if CombatSt.TerrainClassOf and $02 <> 0 then Dec(weight, 20);
  if CombatSt.TerrainClassOf and $80 <> 0 then Dec(weight, 50);
  for col := 0 to 49 do
    for row := 0 to 24 do
      if GDConsts.terrainInfo[GDVars.combatArena^.cells[row, col]].tileId = 22 then
        case weight of
          -30..9: ScatterOneCell(col, row, 0, 0, 0, 30, 15);
          10..29: ScatterOneCell(col, row, 0, 1, 5, 20, 10);
          30..69: ScatterOneCell(col, row, 0, 2, 5, 10, 5);
          70..89: ScatterOneCell(col, row, 10, 2, 10, 10, 1);
          90..110: ScatterOneCell(col, row, 15, 5, 15, 10, 1);
        end;
end;

{ Fills the arena with terrain 23, reads the wilderness terrain under the party from zone 0, and runs the river, tree
  and scatter generators. The map position it reads is unused. }
procedure BuildWildernessArena;
var
  { Unused in this version; see the other implementations of this routine. }
  mapX: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  mapY: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  mapIndex: Integer;
begin
  FillChar(GDVars.combatArena^.cells, SizeOf(GDVars.combatArena^.cells), 23);
  mapX := Lo(GDVars.zone0^[CombatSt.MAP_X]);
  mapY := Lo(GDVars.zone0^[CombatSt.MAP_Y]);
  GDVars.terrainChar := Lo(GDVars.zone0^[C_Gbvm.OVERLAND_LOCATION]);
  CombatSt.PlaceRiver;
  CombatSt.PlaceTrees;
  CombatSt.ScatterFeatures;
end;

{ Loads the dungeon or wilderness combat tiles and the random-feature tiles, allocates the arena with the cursor off,
  and builds the dungeon or wilderness arena. }
procedure LoadCombatTileSet;
begin
  if GDVars.zone0^[C_Gbvm.VIEW_3D] <> 0 then
    MapTiles.Load24x24Set('DungCom', 1, 0, 25)
  else
    MapTiles.Load24x24Set('WildCom', 1, 0, 33);
  MapTiles.Load24x24Set('RandCom', 1, 34, 6);
  GetMem(GDVars.combatArena, SizeOf(Types.TArena));
  GDVars.combatArena^.cursorOn := 0;
  GDVars.combatArena^.focusSize := 1;
  GDVars.combatArena^.distMode := 0;
  if GDVars.zone0^[C_Gbvm.VIEW_3D] <> 0 then
    CombatSt.BuildDungeonArena
  else
    CombatSt.BuildWildernessArena;
end;

{ Recalculates each creature's stats and gives it a cleared combat record; creatures past the party size are marked not
  party members. The party faces the quadrant of facing and hostiles the opposite way. Friendly non-party creatures
  whose morale is 0 or above 102 get zone 1's morale threshold plus the NPC flag. }
procedure InitCreatureCombatData;
var
  p: Types.PCreature;
  count: Byte;
  m: Byte;
begin
  p := GDVars.partyHead;
  count := 0;
  while p <> nil do begin
    CharHlp.RecalcStats(Types.PCreature(p));
    Inc(count);
    GetMem(p^.combatAddr, SizeOf(Types.TCombatRec));
    FillChar(p^.combatAddr^, SizeOf(Types.TCombatRec), 0);
    if count > GDVars.zone1^[C_Gbvm.PARTY_SIZE] then
      p^.combatAddr^.notPcNpc := 1;
    p^.combatAddr^.direction := GDConsts.combatQuadrantDirections[GDVars.partyPos.facing div 2];
    if p^.hostile = 1 then
      p^.combatAddr^.direction := (p^.combatAddr^.direction + 4) mod 8;
    m := p^.npc and $7F;
    if (p^.hostile = 0) and (p^.combatAddr^.notPcNpc = 1) and ((m = 0) or (m > 102)) then
      p^.npc := GDVars.zone1^[C_Gbvm.MORALE_THRESHOLD] + $80;
    p := p^.next;
  end;
end;

{ Tells whether a quad lies off the 11x6 grid on both axes; one axis in range is enough to count as not fully off.
  @param(qx The quad's column.)
  @param(qy The quad's row.)
  @returns(True when both coordinates are outside the grid.) }
function QuadFullyOff(qx, qy: ShortInt): Boolean;
begin
  if ((qx >= 0) and (qx < 11)) or ((qy >= 0) and (qy < 6)) then
    QuadFullyOff := False
  else
    QuadFullyOff := True;
end;

{ Tries to put a creature on a quad of the current team's grid for a ring: the quad must be on the grid and free, and
  the arena cell (stored in the creature's slot before the probe) must hold no creature and passable terrain. Marks the
  quad used on success.
  @param(slot The creature's arena slot.)
  @param(qx The quad's column, 0..10.)
  @param(qy The quad's row, 0..5.)
  @param(bqx The grid's east-west offset from the party, in map cells.)
  @param(bqy The grid's north-south offset from the party, in map cells.)
  @param(ring The placement ring, 0..3.)
  @returns(1 if placed, 0 otherwise.) }
function TryPlaceAt(slot: Byte; qx, qy, bqx, bqy: ShortInt; ring: Byte): Byte;
var
  crIdx: Byte;
  terrIdx: Byte;
  adjStink: Byte;
  adjCloudkill: Byte;
begin
  if (qx < 0) or (qy < 0) or (qx > 10) or (qy > 5) or (not GDVars.quadFree[GDVars.team, ring, qy, qx]) then
    TryPlaceAt := 0
  else begin
    GDVars.arenaSlots[slot].x := qx + bqx * 6 + bqy * 5 + 22;
    GDVars.arenaSlots[slot].y := qy + bqy * 5 + 10;
    CbtMap.ProbeDirection(Types.PCreature(GDVars.combatCreatures[slot]), 8, crIdx, terrIdx, adjStink, adjCloudkill);
    if (crIdx = 0) and (terrIdx > 0) and (GDConsts.terrainInfo[terrIdx].cost < 255) then begin
      TryPlaceAt := 1;
      GDVars.quadFree[GDVars.team, ring, qy, qx] := False;
    end else
      TryPlaceAt := 0;
  end;
end;

{ Searches the current team's quad grid in zigzag legs for a place for creature slot. A leg starts at the ring's start
  quad, shifted along the quadrant's side, and alternates outward on both sides, trying each quad on the grid. A leg
  ends at a partly-off quad or after teamRows tries (first leg) or 12 (later legs); the next leg starts one step
  further, or two on the party's first diagonal leg when an exit is open. A fully-off quad moves to the next ring (up to
  3) whose direction is not walled off (always, outdoors), moving the grid one step that way.
  @param(slot The creature's arena slot.)
  @returns(False when no ring remains.) }
function FindPlacement(slot: Byte): Boolean;
var
  placed: Byte;
  firstPass: Byte;
  giveUp: Byte;
  offGrid: Byte;
  open: Byte;
  state: Byte;
  dir: Byte;
  quad: Byte;
  k: Byte;
  stepX: ShortInt;
  stepY: ShortInt;
  wallX: ShortInt;
  wallY: ShortInt;
  legShift: Byte;
  legLen: Byte;
  baseQx: ShortInt;
  baseQy: ShortInt;
  tries: Byte;
  ring: Byte;
  legX: ShortInt;
  legY: ShortInt;
  qx: ShortInt;
  qy: ShortInt;
begin
  firstPass := 1;
  giveUp := 0;
  state := 1;
  legShift := 0;
  ring := 0;
  baseQx := GDVars.placeX[GDVars.team];
  baseQy := GDVars.placeY[GDVars.team];
  repeat
    quad := GDConsts.combatRingStarts[GDVars.teamDir[GDVars.team], ring] div 2;
    case state of
      1: begin
           stepX := GDConsts.directionDx[GDConsts.combatQuadrantDirections[(quad + 2) mod 4]];
           stepY := GDConsts.directionDy[GDConsts.combatQuadrantDirections[(quad + 2) mod 4]];
           legX := GDConsts.combatQuadrantX[ring > 0, quad] + stepX * legShift;
           legY := GDConsts.combatQuadrantY[ring > 0, quad] + stepY * legShift;
           qx := legX;
           qy := legY;
           legLen := 1;
           state := 2;
           tries := 1;
         end;
      2: begin
           stepX := GDConsts.directionDx[GDConsts.combatQuadrantDirections[(quad + 1) mod 4]];
           stepY := GDConsts.directionDy[GDConsts.combatQuadrantDirections[(quad + 1) mod 4]];
           qx := legX + stepX * legLen;
           qy := legY + stepY * legLen;
           state := 3;
           Inc(tries);
         end;
      3: begin
           stepX := GDConsts.directionDx[GDConsts.combatQuadrantDirections[(quad + 3) mod 4]];
           stepY := GDConsts.directionDy[GDConsts.combatQuadrantDirections[(quad + 3) mod 4]];
           qx := legX + stepX * legLen;
           qy := legY + stepY * legLen;
           state := 2;
           Inc(legLen);
           Inc(tries);
         end;
    end;
    if (qx < 0) or (qy < 0) or (qx > 10) or (qy > 5) then
      offGrid := 1
    else
      offGrid := 0;
    if state > 1 then begin
      if ((offGrid <> 0) and (not CombatSt.QuadFullyOff(qx,
                                                        qy))) or ((firstPass <> 0) and
                                                                  (tries >= GDVars.teamRows[GDVars.team])) or
          ((firstPass = 0) and (tries > 11)) then begin
        Inc(legShift);
        if (GDVars.team = 0) and Odd(GDVars.teamDir[0]) and (ring = 0) and (legShift = 1) then begin
          wallX := GDVars.placeX[GDVars.team] + GDVars.partyPos.mapX;
          wallY := GDVars.placeY[GDVars.team] + GDVars.partyPos.mapY;
          open := 0;
          for k := 1 to 3 do begin
            dir := GDConsts.combatRingDirections[GDVars.teamDir[GDVars.team], k];
            if (GDVars.ifcState = C_Ifc.OVERLAND) or (CombatSt.WallBetween(wallX, wallY, dir) <> 1) then
              open := 1;
          end;
          if open <> 0 then Inc(legShift);
        end;
        state := 1;
        firstPass := 0;
      end;
    end;
    if (offGrid <> 0) and CombatSt.QuadFullyOff(qx, qy) then begin
      placed := 0;
      state := 0;
      while (ring < 3) and (state <> 1) do begin
        Inc(ring);
        wallX := GDVars.placeX[GDVars.team] + GDVars.partyPos.mapX;
        wallY := GDVars.placeY[GDVars.team] + GDVars.partyPos.mapY;
        dir := GDConsts.combatRingDirections[GDVars.teamDir[GDVars.team], ring];
        if (GDVars.ifcState = C_Ifc.OVERLAND) or (CombatSt.WallBetween(wallX, wallY, dir) <> 1) then begin
          baseQx := GDVars.placeX[GDVars.team] + GDConsts.directionDx[dir];
          baseQy := GDVars.placeY[GDVars.team] + GDConsts.directionDy[dir];
          legShift := 0;
          state := 1;
        end;
      end;
      if state <> 1 then giveUp := 1;
    end;
    if offGrid = 0 then
      placed := CombatSt.TryPlaceAt(slot, qx, qy, baseQx, baseQy, ring);
  until (placed <> 0) or (giveUp <> 0);
  if giveUp <> 0 then
    FindPlacement := False
  else
    FindPlacement := True;
end;

{ Places the party (at the origin) and the hostiles (zone 1's monster distance along facing, facing back), seeding each
  team's quad grids from the row bands, then registers and places each creature on the list. Disabled party members
  become bodies outside duels; non-party creatures that cannot be placed are removed, and unplaced party members keep
  their slot with no icon. The surviving list is terminated afterwards. Note: clearing slots 1..255 writes past the 71
  arena slots into gridX, gridY and the arena's creature grid, which BuildArenaArrays then clears. }
procedure PlaceAllCreatures;
var
  x: ShortInt;
  y: ShortInt;
  prev: Types.PCreature;
  p: Types.PCreature;
  slot: Byte;
  g: Byte;
  d: Byte;
  placedCnt: Byte;
  removedCnt: Byte;
begin
  CharHlp.CountTeams;
  removedCnt := 0;
  placedCnt := 0;
  for slot := 1 to 255 do
    GDVars.arenaSlots[slot].size := 0;
  CbtMap.BuildArenaArrays;
  GDVars.placeX[0] := 0;
  GDVars.placeY[0] := 0;
  GDVars.teamDir[0] := GDVars.partyPos.facing div 2;
  GDVars.placeX[1] := GDConsts.directionDx[GDVars.partyPos.facing] * GDVars.zone1^[C_Gbvm.MONSTER_DIST] +
    GDVars.placeX[0];
  GDVars.placeY[1] := GDConsts.directionDy[GDVars.partyPos.facing] * GDVars.zone1^[C_Gbvm.MONSTER_DIST] +
    GDVars.placeY[0];
  GDVars.teamDir[1] := (GDVars.partyPos.facing + 4) mod 8 div 2;
  for GDVars.team := 0 to 1 do
    GDVars.teamRows[GDVars.team] := (GDVars.teamCount[GDVars.team] + 1) div 2;
  for GDVars.team := 0 to 1 do
    for g := 0 to 3 do begin
      if g = 1 then d := 4 else d := GDVars.teamDir[GDVars.team];
      for y := 0 to 5 do
        for x := 0 to 10 do
          if (GDConsts.combatRowBands[d, y].lo > x) or (GDConsts.combatRowBands[d, y].hi < x) then
            GDVars.quadFree[GDVars.team, g, y, x] := False
          else
            GDVars.quadFree[GDVars.team, g, y, x] := True;
    end;
  slot := 1;
  GDVars.arenaCount := 1;
  prev := GDVars.partyHead;
  p := GDVars.partyHead;
  while p <> nil do begin
    GameIo.PollGameKeys;
    GDVars.combatCreatures[slot] := p;
    GDVars.team := p^.hostile;
    GDVars.arenaSlots[slot].aux := slot;
    GDVars.arenaSlots[slot].size := p^.iconDim and 7;
    if CombatSt.FindPlacement(slot) then begin
      prev := p;
      if p^.enabled = 0 then begin
        GDVars.arenaSlots[slot].size := 0;
        if not GDVars.duelFlag and (p^.combatAddr^.notPcNpc = 0) then begin
          x := GDVars.arenaSlots[slot].x;
          y := GDVars.arenaSlots[slot].y;
          Inc(GDVars.downedCount);
          GDVars.downedCharacters[GDVars.downedCount].terrain := GDVars.combatArena^.cells[y, x];
          GDVars.combatArena^.cells[y, x] := C_Terr.CORPSE;
          GDVars.downedCharacters[GDVars.downedCount].cr := Types.PCreature(p);
          GDVars.downedCharacters[GDVars.downedCount].x := x;
          GDVars.downedCharacters[GDVars.downedCount].y := y;
        end;
      end;
      CbtMap.BuildArenaArrays;
      Inc(slot);
      Inc(GDVars.arenaCount);
      Inc(placedCnt);
    end else begin
      GDVars.arenaSlots[slot].size := 0;
      if p^.combatAddr^.notPcNpc = 1 then begin
        Inc(removedCnt);
        GDVars.combatCreatures[slot] := nil;
        GDVars.curChar := p;
        CharGen.RemoveCreature(True, False);
        p := prev;
      end else begin
        prev := p;
        Inc(slot);
        Inc(GDVars.arenaCount);
      end;
    end;
    p := p^.next;
  end;
  prev^.next := nil;
end;

procedure CombatStart;
var
  { Unused in this version; see the other implementations of this routine. }
  savedFlags: array[1..10] of Byte;
  p: Types.PCreature;
begin
  GDVars.typingDelayOn := False;
  Portrait.FreeAnimation(GDVars.animData);
  Blit.FreePic(GDVars.portraits[1].pic);
  Blit.FreePic(GDVars.portraits[2].pic);
  Blit.FreePic(GDVars.bigPicImage);
  GDVars.bigPicId := 255;
  GDVars.portraits[1].fileId := 255;
  GDVars.portraits[2].fileId := 255;
  MenuCore.ClearBottomLine;
  TextRend.PauseOnly;
  TextRend.DisplayString(0, 24, LightGreen, 0, 'A battle begins...');
  GDVars.quickMagic := False;
  GDVars.roundCounter := 0;
  GDVars.combatTargetSlots[0] := 15;
  GDVars.attackRoll := 0;
  GDVars.downedCount := 0;
  GDVars.stinkHead := nil;
  GDVars.cloudkillHead := nil;
  GDVars.lastMissileItem := nil;
  FillChar(GDVars.downedCharacters, SizeOf(GDVars.downedCharacters), 0);
  GDVars.zone1^[C_Gbvm.ATTACKED_ALLIES] := 0;
  CombatSt.LoadCombatTileSet;
  GameIo.PollGameKeys;
  CombatSt.InitCreatureCombatData;
  GameIo.PollGameKeys;
  CombatSt.PlaceAllCreatures;
  GameIo.PollGameKeys;
  Blit.AllocPic(24, 3, 4, 1, GDVars.combatEffectSprite);
  GDVars.combatArena^.focusX := CbtMap.CombatCellX(Types.PCreature(GDVars.partyHead)) - 3;
  GDVars.combatArena^.focusY := CbtMap.CombatCellY(Types.PCreature(GDVars.partyHead)) - 3;
  CharHlp.DisplayCombatInterface;
  p := GDVars.partyHead;
  while p <> nil do begin
    FxEngine.TriggerEffectsWithCondition(8, Types.PCreature(p));
    FxEngine.TriggerEffectsWithCondition(22, Types.PCreature(p));
    p := p^.next;
  end;
  CbtActs.UpdateHostileHpPercent;
  GDVars.ifcState := C_Ifc.IN_COMBAT;
end;

begin
end.
