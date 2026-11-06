{ Combat-arena geometry: line walks with doubled distances, direction cones, and the sorted list of reachable targets. }
{$O+,F+}
{$A-}
{$R-}
{$S-}
unit Pathing;

interface

uses Types, GDConsts, GDVars, CbtMap;

{ Gives the sign of a number.
  @param(value The number.)
  @returns(-1, 0 or 1.) }
function SignOf(value: Integer): Integer;

{ Starts a line walk from (sx, sy) to (ex, ey): sets the current point, the deltas, the step signs, and zero error and
  distance.
  @param(req The walk, with its start and end points set.) }
procedure PathFind(var req: Types.TPathReq);

{ Takes one Bresenham step along a line walk, adding 2 to the doubled distance for a straight step and 3 for a diagonal,
  and records the step's direction.
  @param(req The walk, started by PathFind.)
  @returns(False, without moving, once the end point is reached.) }
function NextPathStep(var req: Types.TPathReq): Boolean;

{ Tells whether a target lies in the 90-degree cone that opens in a direction from the cell next to the source in that
  direction; the source and that cell count too. Direction 255 or 8 accepts any target in the arena; points outside the
  50x25 arena never pass.
  @param(x Source column.)
  @param(y Source row.)
  @param(tx Target column.)
  @param(ty Target row.)
  @param(dir The direction, 0 to 7, or 8 or 255 for any.)
  @returns(True when the target is in the cone.) }
function IsDirToward(x, y, tx, ty: ShortInt; dir: Byte): Boolean;

{ Walks the line from a source cell to a target cell through an arena. It stops where a cell's terrain blocks more than
  the source cell's clearance (unless the arena's distMode is not 0) or where the range runs out; tx and ty then become
  the stopping cell.
  @param(x Source column.)
  @param(y Source row.)
  @param(tx In: target column. Out: the stopping column when the walk stops short.)
  @param(ty In: target row. Out: the stopping row when the walk stops short.)
  @param(dist In: the range in cells. Out: the doubled distance walked.)
  @param(view The arena.)
  @returns(True when the target was reached.) }
function WalkLine(x, y: ShortInt; var tx, ty: ShortInt; var dist: Word; view: Pointer): Boolean;

{ Fills the combat target list with each creature in the arena that a cell of an icon at (x, y) can reach within range
  and in the filter direction. For each creature the closest reaching pair of icon cells counts, with its doubled
  distance and a direction toward it (filter itself when below 8). The list is then sorted by distance.
  @param(x Column of the icon.)
  @param(y Row of the icon.)
  @param(range The range in cells.)
  @param(filter The direction, 0 to 7, or 255 for any.)
  @param(size The icon's size.)
  @param(view The arena.) }
procedure BuildTargetList(x, y: ShortInt; range: Word; filter: Byte; size: Byte; view: Pointer);

{ Empty entry; calling it loads this overlay. }
procedure PrimePathing;

implementation

procedure PrimePathing;
begin
end;

function SignOf(value: Integer): Integer;
begin
  if value < 0 then
    SignOf := -1
  else if value > 0 then
    SignOf := 1
  else
    SignOf := 0;
end;

{ Sorts the target list by doubled distance; on a tie a lower direction comes first, except that a diagonal (odd)
  direction never moves ahead of a straight one. }
procedure SortTargets;
var
  i: Byte;
  j: Byte;
  dirJ: Byte;
  dirI: Byte;
  tmp: Types.TTargetRec;
begin
  if GDVars.targetCount <= 1 then Exit;
  for i := 1 to GDVars.targetCount - 1 do
    for j := i + 1 to GDVars.targetCount do begin
      dirI := GDVars.targetList[i].dir;
      dirJ := GDVars.targetList[j].dir;
      if (GDVars.targetList[j].dist < GDVars.targetList[i].dist) or
          ((GDVars.targetList[j].dist = GDVars.targetList[i].dist) and (dirJ < dirI) and
           (dirJ mod 2 <= dirI mod 2)) then begin
        tmp := GDVars.targetList[i];
        GDVars.targetList[i] := GDVars.targetList[j];
        GDVars.targetList[j] := tmp;
      end;
    end;
end;

procedure PathFind(var req: Types.TPathReq);
begin
  with req do begin
    cx := sx;
    cy := sy;
    adx := Abs(ex - sx);
    ady := Abs(ey - sy);
    stepX := Pathing.SignOf(ex - sx);
    stepY := Pathing.SignOf(ey - sy);
    err := 0;
    dist := 0;
  end;
end;

function NextPathStep(var req: Types.TPathReq): Boolean;
var
  dxi: ShortInt;
  dyi: ShortInt;
begin
  NextPathStep := False;
  dxi := 1;
  dyi := 1;
  with req do begin
    if adx >= ady then
    { x-major walk }
    begin
      if cx <> ex then begin
        Inc(cx, stepX);
        dxi := stepX + 1;
        Inc(err, ady);
        Inc(err, ady);
        Inc(dist);
        Inc(dist);
        if err >= adx then begin
          Dec(err, adx);
          Dec(err, adx);
          Inc(cy, stepY);
          dyi := stepY + 1;
          Inc(dist);
        end;
        NextPathStep := True;
      end;
    end else
    { y-major walk }
    begin
      if cy <> ey then begin
        Inc(cy, stepY);
        dyi := stepY + 1;
        Inc(err, adx);
        Inc(err, adx);
        Inc(dist);
        Inc(dist);
        if err >= ady then begin
          Dec(err, ady);
          Dec(err, ady);
          Inc(cx, stepX);
          dxi := stepX + 1;
          Inc(dist);
        end;
        NextPathStep := True;
      end;
    end;
    step := GDConsts.directionByDelta[dyi, dxi];
  end;
end;

function WalkLine(x, y: ShortInt; var tx, ty: ShortInt; var dist: Word; view: Pointer): Boolean;
var
  walk: Types.TPathReq;
  meter: Types.TPathReq;
  done: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  stepped: Boolean;
  maxDist: Word;
begin
  maxDist := dist * 2 + 1;
  walk.sx := x;
  walk.sy := y;
  walk.ex := tx;
  walk.ey := ty;
  Pathing.PathFind(walk);
  meter.sx := 0;
  meter.sy := GDConsts.terrainInfo[Types.PArena(view)^.cells[y, x]].clearance;
  if walk.adx > walk.ady then
    meter.ex := walk.adx
  else
    meter.ex := walk.ady;
  meter.ey := GDConsts.terrainInfo[Types.PArena(view)^.cells[y, x]].clearance;
  Pathing.PathFind(meter);
  done := False;
  repeat
    if ((Types.PArena(view)^.distMode = 0) and
        (GDConsts.terrainInfo[Types.PArena(view)^.cells[walk.cy, walk.cx]].blocking > meter.cy)) or
          (walk.dist > maxDist) then begin
      tx := walk.cx;
      ty := walk.cy;
      dist := walk.dist;
      WalkLine := False;
      Exit;
    end;
    stepped := Pathing.NextPathStep(meter);
    done := not Pathing.NextPathStep(walk);
  until done;
  dist := walk.dist;
  WalkLine := True;
end;

function IsDirToward(x, y, tx, ty: ShortInt; dir: Byte): Boolean;
var
  nx: ShortInt;
  ny: ShortInt;
begin
  if (x < 0) or (x > 49) or (y < 0) or (y > 24) or (tx < 0) or (tx > 49) or (ty < 0) or (ty > 24) then begin
    IsDirToward := False;
    Exit;
  end;
  if dir = 255 then
    dir := 8;
  nx := x + GDConsts.directionDx[dir];
  ny := y + GDConsts.directionDy[dir];
  if ((x = tx) and (y = ty)) or ((nx = tx) and (ny = ty)) then begin
    IsDirToward := True;
    Exit;
  end;
  case dir of
    0: IsDirToward := ((tx >= nx) and (ty <= (nx - tx) + ny)) or ((tx <= nx) and (ty <= (tx - nx) + ny));
    1: IsDirToward := ((tx >= nx) and (ty <= (nx - tx) + ny)) or ((tx >= (nx + ny) - ty) and (ty <= ny));
    2: IsDirToward := ((tx >= (nx + ny) - ty) and (ty <= ny)) or ((tx >= (nx + ty) - ny) and (ty >= ny));
    3: IsDirToward := ((tx >= (nx + ty) - ny) and (ty >= ny)) or ((tx >= nx) and (ty >= (tx - nx) + ny));
    4: IsDirToward := ((tx >= nx) and (ty >= (tx - nx) + ny)) or ((tx <= nx) and (ty >= (nx - tx) + ny));
    5: IsDirToward := ((tx <= nx) and (ty >= (nx - tx) + ny)) or ((tx <= (nx + ny) - ty) and (ty >= ny));
    6: IsDirToward := ((tx <= (nx + ny) - ty) and (ty >= ny)) or ((tx <= (nx + ty) - ny) and (ty <= ny));
    7: IsDirToward := ((tx <= (nx + ty) - ny) and (ty <= ny)) or ((tx <= nx) and (ty <= (tx - nx) + ny));
    8: IsDirToward := True;
  end;
end;

procedure BuildTargetList(x, y: ShortInt; range: Word; filter: Byte; size: Byte; view: Pointer);
var
  i: Byte;
  bestDir: Byte;
  k: Byte;
  j: Byte;
  bestK: Byte;
  bestJ: Byte;
  found: Boolean;
  tx: ShortInt;
  ty: ShortInt;
  tileDx: ShortInt;
  tileDy: ShortInt;
  myX: array[0..3] of ShortInt;
  myY: array[0..3] of ShortInt;
  tgX: array[0..3] of ShortInt;
  tgY: array[0..3] of ShortInt;
  dist: Word;
  bestDist: Word;
begin
  for k := 0 to 3 do
    if CbtMap.GetIconTileDelta(size, k, tileDx, tileDy) then begin
      myX[k] := x + tileDx;
      myY[k] := y + tileDy;
    end else
      myX[k] := -1;
  GDVars.targetCount := 0;
  for i := 1 to GDVars.arenaCount do
    if GDVars.arenaSlots[i].size > 0 then begin
      found := False;
      bestDist := 255;
      for j := 0 to 3 do
        if CbtMap.GetIconTileDelta(GDVars.arenaSlots[i].size, j, tileDx, tileDy) then begin
          tgX[j] := GDVars.arenaSlots[i].x + tileDx;
          tgY[j] := GDVars.arenaSlots[i].y + tileDy;
        end else
          tgX[j] := -1;
      for j := 0 to 3 do
        if tgX[j] >= 0 then
          for k := 0 to 3 do
            if myX[k] >= 0 then
              if Pathing.IsDirToward(myX[k], myY[k], tgX[j], tgY[j], filter) then begin
                tx := tgX[j];
                ty := tgY[j];
                dist := range;
                if Pathing.WalkLine(myX[k], myY[k], tx, ty, dist, view) then begin
                  found := True;
                  if dist < bestDist then begin
                    bestDist := dist;
                    bestK := k;
                    bestJ := j;
                  end;
                end;
              end;
      if found then begin
        Inc(GDVars.targetCount);
        GDVars.targetList[GDVars.targetCount].idx := i;
        GDVars.targetList[GDVars.targetCount].dist := bestDist;
        bestDir := 0;
        if filter < 8 then
          bestDir := filter
        else
          while not Pathing.IsDirToward(myX[bestK], myY[bestK], tgX[bestJ], tgY[bestJ], bestDir) do
            Inc(bestDir);
        GDVars.targetList[GDVars.targetCount].dir := bestDir;
      end;
    end;
  Pathing.SortTargets;
end;

begin
end.
