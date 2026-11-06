{ The combat map: a 7x7 view of the 50x25 arena, creature icons and their arena cells, scrolling, the aim cursor and
  downed-creature tracking. }
{$O+,F+}
{$A-}
{$R-}
{$S-}
unit CbtMap;

interface

uses Blit, Types, GDConsts, GDVars, C_Ifc, C_Terr, MapTiles, SoundDrv, Crt, TextRend, EclTrace;

{ Empty routine with no callers. }
procedure NoopCbtMap;

{ Finds where one tile of a creature icon lies relative to the icon's upper-left cell.
  @param(size The icon size; 0 for no icon.)
  @param(idx The tile, 0 to 3.)
  @param(dx Receives the tile's column offset; left as it was for size 0.)
  @param(dy Receives the tile's row offset; left as it was for size 0.)
  @returns(True when the icon uses the tile; False for size 0 or an unused tile, whose column offset is negative.) }
function GetIconTileDelta(size, idx: Byte; var dx, dy: ShortInt): Boolean;

{ Recomputes each arena creature's view coordinates from its arena cell and the view's upper-left cell. }
procedure CalcGridDeltas;

{ Exchanges palette registers 0 and 8 (black and dark gray) for combat on EGA and Tandy. }
procedure SetCombatPalette;

{ Restores palette registers 0 and 8 after combat on EGA and Tandy. Note: on Tandy, register 0 is restored through the
  EGA palette call rather than the Tandy one. }
procedure SetNoncombatPalette;

{ Repaints the terrain under the cursor's footprint at an arena cell, draws the cursor there when it is on, then redraws
  the creature standing on the cell if it is visible.
  @param(x Arena column of the cell.)
  @param(y Arena row of the cell.) }
procedure DrawCursorCell(x, y: ShortInt);

{ Redraws one arena cell: repaints its terrain (the whole icon footprint when a creature stands there, through
  UpdateCombatMapTile), then the creature's sprite if it is visible.
  @param(x Arena column of the cell.)
  @param(y Arena row of the cell.) }
procedure RedrawArenaCell(x, y: ShortInt);

{ Rebuilds the arena's creature-index grid and each creature's view coordinates. }
procedure BuildArenaArrays;

{ Looks up what lies on an arena cell.
  @param(x Arena column of the cell.)
  @param(y Arena row of the cell.)
  @param(crIdx Receives the combat slot of the creature standing there; 0 for none or outside the arena.)
  @param(terrIdx Receives the cell's terrain; 0 outside the arena.) }
procedure GetArenaContents(x, y: ShortInt; var crIdx, terrIdx: Byte);

{ Repaints the terrain under each visible tile of a creature's icon, erasing its sprite, or under the single view cell
  when no creature is there.
  @param(x View column of the cell; the creature's own view column replaces it.)
  @param(y View row of the cell; the creature's own view row replaces it.)
  @param(crIdx The creature's combat slot, or 0 to look up the creature standing on the cell.) }
procedure UpdateCombatMapTile(x, y: ShortInt; crIdx: Byte);

{ Tells whether a view cell lies inside the 7x7 view.
  @param(x View column.)
  @param(y View row.)
  @returns(True when both coordinates lie inside the view.) }
function ViewCoordsValid(x, y: ShortInt): Boolean;

{ Tests whether a creature's icon is visible in the view.
  @param(creature The creature.)
  @param(whole Nonzero to require each tile of the icon in view, 0 to require one.)
  @returns(True when the icon is visible; False when the creature has no icon.) }
function CombatIconVisible(creature: Types.PCreature; whole: Byte): Boolean;

{ Targets the arena cell one step in dir from a cell and redraws the whole view if needed (BuildViewBuffer), redrawing
  each visible icon of an enabled creature after a full redraw. Then redraws the cell, draws the cursor at the target
  (kept inside the arena) and flushes the view.
  @param(x Arena column of the cell.)
  @param(y Arena row of the cell.)
  @param(delta How far the target may lie from the view center before the view moves; 255 forces a full redraw.)
  @param(dir Direction of the target, 0 to 7; 8 for the cell itself.) }
procedure ScrollView(x, y: ShortInt; delta, dir: Byte);

{ Turns a creature. While the combat map shows, it scrolls the creature into view unless it is wholly visible, and
  repaints its terrain when the facing crosses between 0 to 3 and 4 to 7 (the mirrored sprites) or frame or eraseOnly is
  nonzero. It stores the new facing and, unless eraseOnly, draws its sprite and flushes when it is visible and the map
  shows.
  @param(creature The creature.)
  @param(dir The new facing, 0 to 7.)
  @param(frame The animation frame to draw.)
  @param(eraseOnly Nonzero to erase the sprite without drawing it again.) }
procedure SetCreatureFacing(creature: Types.PCreature; dir, frame, eraseOnly: Byte);

{ Finds a creature's arena column.
  @param(creature The creature.)
  @returns(The column of its icon's upper-left cell.) }
function CombatCellX(creature: Types.PCreature): ShortInt;

{ Finds a creature's arena row.
  @param(creature The creature.)
  @returns(The row of its icon's upper-left cell.) }
function CombatCellY(creature: Types.PCreature): ShortInt;

{ Finds a creature's icon size in the arena.
  @param(creature The creature.)
  @returns(The icon size; 0 when it has no icon.) }
function GetIconSize(creature: Types.PCreature): Byte;

{ Finds a creature in the combat creature table.
  @param(creature The creature.)
  @returns(Its index in the table, or 0 when it is not there.) }
function CombatSlot(creature: Types.PCreature): Byte;

{ Probes the cells one step in dir from each of the creature's icon tiles.
  @param(creature The creature.)
  @param(dir The direction, 0 to 7; 8 probes the creature's own cells.)
  @param(crIdx Receives an adjacent creature's combat slot (0 for none); the creature itself is ignored and the last one
    found wins.)
  @param(terrIdx Receives the dominant terrain: 0 (off the arena) beats everything, otherwise the highest cost wins (the
    later tile on a tie), starting from terrain 23 at cost 1. Stinking Cloud and Cloudkill do not compete.)
  @param(adjStink Receives 1 when a probed cell holds a stinking cloud, else 0.)
  @param(adjCloudkill Receives 1 when a probed cell holds a cloudkill, else 0.) }
procedure ProbeDirection(creature: Types.PCreature; dir: Byte; var crIdx, terrIdx, adjStink, adjCloudkill: Byte);

{ Handles a creature going down. Outside combat it plays the downed sound and pauses. In combat it scrolls the creature
  wholly into view, flashes the skull sprite over it, records a body for the party side (notPcNpc = 0) and marks its
  cell as a corpse (unless the cell holds a stinking cloud), removes the icon, refreshes the view's center cell
  (ScrollView), and clears the creature's initiative, movement, casting and guarding. Note: the check for an already
  recorded body tests downedCharacters[frame] with frame not yet set, so it finds one only when that entry happens to
  hold the creature.
  @param(creature The creature that went down.) }
procedure CreatureDowned(creature: Types.PCreature);

{ Places a creature on an arena cell if it fits. Outside combat it does nothing. In combat it places the creature at the
  cell (icon size from the low 7 bits of iconDim), probes its own cells and rejects the place, zeroing the icon size, on
  any creature, terrain 0 or cost 255. On success with moving set and notPcNpc = 0, it clears the creature's body
  entries and, unless another body lies on the cell, writes into it the terrain its last body covered, or the probed
  terrain when it has no body entry or the body covered a corpse cell. The creature grid is then refilled.
  @param(creature The creature.)
  @param(x Arena column of the cell.)
  @param(y Arena row of the cell.)
  @param(moving True when the creature moves there, so its bodies are cleared.)
  @returns(True outside combat or when the creature fits.) }
function IsValidCreatureLoc(creature: Types.PCreature; x, y: Byte; moving: Boolean): Boolean;

{ Scrolls the view to the creature (ScrollView with dir 8) when the combat map shows, drawing the cursor over its icon
  footprint when cursor is set; afterwards the cursor is off with size 1.
  @param(creature The creature.)
  @param(delta How far it may lie from the view center before the view moves; 255 forces a full redraw.)
  @param(cursor True to draw the cursor.) }
procedure DisplayMapViewCentered(creature: Types.PCreature; delta: Byte; cursor: Boolean);

{ Calls the priming entry of each overlay this unit uses, so the overlay manager loads them. }
procedure PrimeCbtMap;

implementation

var
  { The creature grid as the 25 full rows of 50 cells the arena has; the bottom row runs past combatGridCells into
    combatCreatures' slot 0, which never holds a creature. }
  creatureGrid: array[0..24, 0..49] of Byte absolute GDVars.combatGridCells;

procedure NoopCbtMap;
begin
end;

procedure PrimeCbtMap;
begin
  MapTiles.PrimeMapTiles;
  EclTrace.PrimeEclTrace;
end;

function GetIconTileDelta(size, idx: Byte; var dx, dy: ShortInt): Boolean;
begin
  GetIconTileDelta := False;
  if size = 0 then Exit;
  dx := GDConsts.combatIconOffsets[size, idx].dx;
  dy := GDConsts.combatIconOffsets[size, idx].dy;
  if dx >= 0 then
    GetIconTileDelta := True;
end;

procedure CalcGridDeltas;
var
  i: Byte;
begin
  for i := 1 to GDVars.arenaCount do begin
    GDVars.gridX[i] := GDVars.arenaSlots[i].x - GDVars.combatArena^.focusX;
    GDVars.gridY[i] := GDVars.arenaSlots[i].y - GDVars.combatArena^.focusY;
  end;
end;

procedure SetCombatPalette;
begin
  case Char(GDVars.displayMode) of
    #1: begin Blit.SetPaletteRegister(0, 8); Blit.SetPaletteRegister(8, 0); end;
    #2: begin Blit.SetPaletteRegisterTandy(0, 8); Blit.SetPaletteRegisterTandy(8, 0); end;
  end;
end;

procedure SetNoncombatPalette;
begin
  case Char(GDVars.displayMode) of
    #1: begin Blit.SetPaletteRegister(0, 0); Blit.SetPaletteRegister(8, 8); end;
    #2: begin Blit.SetPaletteRegister(0, 0); Blit.SetPaletteRegisterTandy(8, 8); end;
  end;
end;

procedure DrawCursorCell(x, y: ShortInt);
var
  relX: ShortInt;
  relY: ShortInt;
  tdx: ShortInt;
  tdy: ShortInt;
  i: Byte;
  c: Byte;
  t: Byte;
begin
  relX := x - GDVars.combatArena^.focusX;
  relY := y - GDVars.combatArena^.focusY;
  for i := 0 to 3 do begin
    if CbtMap.GetIconTileDelta(GDVars.combatArena^.focusSize, i, tdx, tdy) then
      if CbtMap.ViewCoordsValid(relX + tdx, relY + tdy) then begin
        MapTiles.Copy2DTile((relX + tdx) * 3, (relY + tdy) * 3,
                            GDConsts.terrainInfo[GDVars.combatArena^.cells[y + tdy, x + tdx]].tileId, 0);
        if GDVars.combatArena^.cursorOn <> 0 then
          MapTiles.DrawIconAnimSprite(relX + tdx, relY + tdy, 0, 0, 25);
      end;
  end;
  CbtMap.GetArenaContents(x, y, c, t);
  if c > 0 then
    if CbtMap.CombatIconVisible(GDVars.combatCreatures[c], 0) then
      MapTiles.DrawIconAnimSprite(GDVars.gridX[c], GDVars.gridY[c], GDVars.combatCreatures[c]^.combatAddr^.direction, 0,
                                  GDVars.combatCreatures[c]^.orderNumber);
end;

procedure RedrawArenaCell(x, y: ShortInt);
var
  relX: ShortInt;
  relY: ShortInt;
  c: Byte;
  t: Byte;
begin
  relX := x - GDVars.combatArena^.focusX;
  relY := y - GDVars.combatArena^.focusY;
  CbtMap.UpdateCombatMapTile(relX, relY, 0);
  CbtMap.GetArenaContents(x, y, c, t);
  if c > 0 then
    if CbtMap.CombatIconVisible(GDVars.combatCreatures[c], 0) then
      MapTiles.DrawIconAnimSprite(GDVars.gridX[c], GDVars.gridY[c], GDVars.combatCreatures[c]^.combatAddr^.direction, 0,
                                  GDVars.combatCreatures[c]^.orderNumber);
end;

procedure BuildArenaArrays;
var
  i: Byte;
  j: Byte;
  tdx: ShortInt;
  tdy: ShortInt;
begin
  FillChar(creatureGrid, SizeOf(creatureGrid), 0);
  for i := 1 to GDVars.arenaCount do begin
    if GDVars.arenaSlots[i].size > 0 then begin
      for j := 0 to 3 do
        if CbtMap.GetIconTileDelta(GDVars.arenaSlots[i].size, j, tdx, tdy) then
          creatureGrid[GDVars.arenaSlots[i].y + tdy, GDVars.arenaSlots[i].x + tdx] := i;
      GDVars.gridX[i] := GDVars.arenaSlots[i].x - GDVars.combatArena^.focusX;
      GDVars.gridY[i] := GDVars.arenaSlots[i].y - GDVars.combatArena^.focusY;
    end;
  end;
end;

procedure GetArenaContents(x, y: ShortInt; var crIdx, terrIdx: Byte);
begin
  if (x >= 0) and (x <= 49) and (y >= 0) and (y <= 24) then begin
    terrIdx := GDVars.combatArena^.cells[y, x];
    crIdx := creatureGrid[y, x];
  end else begin
    crIdx := 0;
    terrIdx := 0;
  end;
end;

procedure UpdateCombatMapTile(x, y: ShortInt; crIdx: Byte);
var
  absX: ShortInt;
  absY: ShortInt;
  tdx: ShortInt;
  tdy: ShortInt;
  i: Byte;
  t: Byte;
  size: Byte;
begin
  if crIdx = 0 then begin
    absX := x + GDVars.combatArena^.focusX;
    absY := y + GDVars.combatArena^.focusY;
    CbtMap.GetArenaContents(absX, absY, crIdx, t);
  end;
  if crIdx > 0 then begin
    x := GDVars.gridX[crIdx];
    y := GDVars.gridY[crIdx];
    absX := x + GDVars.combatArena^.focusX;
    absY := y + GDVars.combatArena^.focusY;
    size := GDVars.arenaSlots[crIdx].size;
    for i := 0 to 3 do
      if CbtMap.GetIconTileDelta(size, i, tdx, tdy) then
        if CbtMap.ViewCoordsValid(x + tdx, y + tdy) then
          MapTiles.Copy2DTile((x + tdx) * 3, (y + tdy) * 3,
                              GDConsts.terrainInfo[GDVars.combatArena^.cells[absY + tdy, absX + tdx]].tileId, 0);
  end else if CbtMap.ViewCoordsValid(x, y) then
    MapTiles.Copy2DTile(x * 3, y * 3, GDConsts.terrainInfo[GDVars.combatArena^.cells[absY, absX]].tileId, 0);
end;

function ViewCoordsValid(x, y: ShortInt): Boolean;
begin
  if (x < 0) or (x > 6) or (y < 0) or (y > 6) then
    ViewCoordsValid := False
  else
    ViewCoordsValid := True;
end;

function CombatIconVisible(creature: Types.PCreature; whole: Byte): Boolean;
var
  i: Byte;
  slot: Byte;
  tdx: ShortInt;
  tdy: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  visibleTiles: Integer;
begin
  CombatIconVisible := True;
  slot := CbtMap.CombatSlot(creature);
  if GDVars.arenaSlots[slot].size = 0 then
    CombatIconVisible := False
  else
    for i := 0 to 3 do begin
      if CbtMap.GetIconTileDelta(GDVars.arenaSlots[slot].size, i, tdx, tdy) then
        if not CbtMap.ViewCoordsValid(GDVars.gridX[slot] + tdx, GDVars.gridY[slot] + tdy) then begin
          CombatIconVisible := False;
          if whole <> 0 then Exit;
        end else begin
          CombatIconVisible := True;
          if whole = 0 then Exit;
        end;
    end;
end;

{ Redraws the whole view when a cell falls outside its center band; delta 255 forces a full redraw. Moves the center
  toward the cell, keeping the 7x7 view inside the arena, then repaints each tile into the buffer.
  @param(x Arena column of the cell.)
  @param(y Arena row of the cell.)
  @param(delta Cells either side of the view center that the band spans; 255 forces a full redraw.)
  @returns(True when the view was redrawn.) }
function BuildViewBuffer(x, y: ShortInt; delta: Byte): Boolean;
var
  d: Byte;
  pixX: ShortInt;
  pixY: ShortInt;
  i: Byte;
  j: Byte;
  cX: ShortInt;
  cY: ShortInt;
  minX: ShortInt;
  maxX: ShortInt;
  minY: ShortInt;
  maxY: ShortInt;
begin
  BuildViewBuffer := False;
  cX := GDVars.combatArena^.focusX + 3;
  cY := GDVars.combatArena^.focusY + 3;
  d := delta;
  if delta = 255 then
    d := 0;
  minX := cX - d;
  maxX := cX + d;
  minY := cY - d;
  maxY := cY + d;
  if (delta <> 255) and (x >= minX) and (x <= maxX)
     and (y >= minY) and (y <= maxY) then Exit;
  if x < minX then
    while (x < cX) and (cX > 3) do Dec(cX)
  else if x > maxX then
    while (x > cX) and (cX < 46) do Inc(cX);
  if y < minY then
    while (y < cY) and (cY > 3) do Dec(cY)
  else if y > maxY then
    while (y > cY) and (cY < 21) do Inc(cY);
  GDVars.combatArena^.focusX := cX - 3;
  GDVars.combatArena^.focusY := cY - 3;
  pixY := 0;
  cY := GDVars.combatArena^.focusY;
  for j := 0 to 6 do begin
    pixX := 0;
    cX := GDVars.combatArena^.focusX;
    for i := 0 to 6 do begin
      MapTiles.Copy2DTile(pixX, pixY, GDConsts.terrainInfo[GDVars.combatArena^.cells[cY, cX]].tileId, 0);
      Inc(pixX, 3);
      Inc(cX);
    end;
    Inc(pixY, 3);
    Inc(cY);
  end;
  CbtMap.CalcGridDeltas;
  BuildViewBuffer := True;
end;

procedure ScrollView(x, y: ShortInt; delta, dir: Byte);
var
  p: Types.PCreature;
  i: Byte;
  tx: ShortInt;
  ty: ShortInt;
begin
  tx := x + GDConsts.directionDx[dir];
  ty := y + GDConsts.directionDy[dir];
  if CbtMap.BuildViewBuffer(tx, ty, delta) then begin
    for i := 1 to GDVars.arenaCount do begin
      p := GDVars.combatCreatures[i];
      if (p^.enabled <> 0) and (GDVars.arenaSlots[i].size > 0) then
        if CbtMap.CombatIconVisible(p, 0) then
          MapTiles.DrawIconAnimSprite(GDVars.gridX[i], GDVars.gridY[i], p^.combatAddr^.direction, 0, p^.orderNumber);
    end;
  end;
  CbtMap.RedrawArenaCell(x, y);
  if not CbtMap.ViewCoordsValid(tx - GDVars.combatArena^.focusX, ty - GDVars.combatArena^.focusY) then begin
    if tx > 49 then tx := 49;
    if tx < 0 then tx := 0;
    if ty > 24 then ty := 24;
    if ty < 0 then ty := 0;
  end;
  CbtMap.DrawCursorCell(tx, ty);
  Blit.FlushView;
end;

procedure SetCreatureFacing(creature: Types.PCreature; dir, frame, eraseOnly: Byte);
var
  slot: Byte;
begin
  slot := CbtMap.CombatSlot(creature);
  if (not CbtMap.CombatIconVisible(creature, 1)) and GDVars.mapVisible then
    CbtMap.ScrollView(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), 3, 8);
  if (creature^.combatAddr^.direction div 4 <> dir div 4)
     or (frame <> 0) or (eraseOnly <> 0) then
    if GDVars.mapVisible then
      CbtMap.UpdateCombatMapTile(0, 0, slot);
  creature^.combatAddr^.direction := dir;
  if eraseOnly = 0 then
    if CbtMap.CombatIconVisible(creature, 0) and GDVars.mapVisible then begin
      MapTiles.DrawIconAnimSprite(GDVars.gridX[slot], GDVars.gridY[slot], dir, frame, creature^.orderNumber);
      Blit.FlushView;
    end;
end;

function CombatCellX(creature: Types.PCreature): ShortInt;
begin
  CombatCellX := GDVars.arenaSlots[CbtMap.CombatSlot(creature)].x;
end;

function CombatCellY(creature: Types.PCreature): ShortInt;
begin
  CombatCellY := GDVars.arenaSlots[CbtMap.CombatSlot(creature)].y;
end;

function GetIconSize(creature: Types.PCreature): Byte;
begin
  GetIconSize := GDVars.arenaSlots[CbtMap.CombatSlot(creature)].size;
end;

function CombatSlot(creature: Types.PCreature): Byte;
var
  found: Boolean;
  i: Byte;
begin
  found := False;
  CombatSlot := 0;
  i := 0;
  repeat
    Inc(i);
    if GDVars.combatCreatures[i] = creature then
      found := True;
  until found or (i = GDVars.arenaCount);
  if found then
    CombatSlot := i;
end;

procedure ProbeDirection(creature: Types.PCreature; dir: Byte; var crIdx, terrIdx, adjStink, adjCloudkill: Byte);
var
  i: Byte;
  slot: Byte;
  c: Byte;
  t: Byte;
  best: Byte;
  nx: ShortInt;
  ny: ShortInt;
  x: ShortInt;
  y: ShortInt;
  tdx: ShortInt;
  tdy: ShortInt;
begin
  crIdx := 0;
  terrIdx := 23;
  best := 1;
  adjStink := 0;
  adjCloudkill := 0;
  slot := CbtMap.CombatSlot(creature);
  x := GDVars.arenaSlots[slot].x;
  y := GDVars.arenaSlots[slot].y;
  for i := 0 to 3 do begin
    if CbtMap.GetIconTileDelta(GDVars.arenaSlots[slot].size, i, tdx, tdy) then begin
      nx := x + tdx + GDConsts.directionDx[dir];
      ny := y + tdy + GDConsts.directionDy[dir];
      CbtMap.GetArenaContents(nx, ny, c, t);
      if c = slot then
        c := 0;
      if c > 0 then
        crIdx := c;
      if (t = 0) or (terrIdx = 0) then
        terrIdx := 0
      else
        case t of
          C_Terr.STINKING_CLOUD: adjStink := 1;
          C_Terr.CLOUDKILL: adjCloudkill := 1;
        else
          if GDConsts.terrainInfo[t].cost >= best then begin
            best := GDConsts.terrainInfo[t].cost;
            terrIdx := t;
          end;
        end;
    end;
  end;
end;

procedure CreatureDowned(creature: Types.PCreature);
var
  slot: Byte;
  m: Byte;
  frame: Byte;
  tdx: ShortInt;
  tdy: ShortInt;
  cellX: ShortInt;
  cellY: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  bodyCell: array[1..3] of Byte;
begin
  if GDVars.ifcState <> C_Ifc.IN_COMBAT then begin
    SoundDrv.SoundCommand(GDConsts.sndCmd5);
    TextRend.PauseOnly;
  end else begin
    m := 1;
    { frame is uninitialized here. }
    while (m < 9) and (GDVars.downedCharacters[frame].cr <> creature) do
      Inc(m);
    if m < 9 then Exit;
    slot := CbtMap.CombatSlot(creature);
    cellX := CbtMap.CombatCellX(creature);
    cellY := CbtMap.CombatCellY(creature);
    if not CbtMap.CombatIconVisible(creature, 1) then
      CbtMap.ScrollView(cellX, cellY, 3, 8);
    CbtMap.UpdateCombatMapTile(0, 0, slot);
    SoundDrv.SoundCommand(GDConsts.sndCmd5);
    for frame := 0 to 8 do begin
      for m := 0 to 3 do
        if CbtMap.GetIconTileDelta(GDVars.arenaSlots[slot].size, m, tdx, tdy) then
          if CbtMap.ViewCoordsValid(GDVars.gridX[slot] + tdx, GDVars.gridY[slot] + tdy) then
            Blit.BlitTileClipped((GDVars.gridX[slot] + tdx) * 3, (GDVars.gridY[slot] + tdy) * 3, 0, 5,
                                 GDVars.iconImages[24][frame mod 2], GDVars.viewBuffer);
      Blit.FlushView;
      Delay(10);
    end;
    if creature^.combatAddr^.notPcNpc = 0 then begin
      Inc(GDVars.downedCount);
      GDVars.downedCharacters[GDVars.downedCount].terrain := GDVars.combatArena^.cells[cellY, cellX];
      if GDVars.combatArena^.cells[cellY, cellX] <> C_Terr.STINKING_CLOUD then
        GDVars.combatArena^.cells[cellY, cellX] := C_Terr.CORPSE;
      GDVars.downedCharacters[GDVars.downedCount].cr := creature;
      GDVars.downedCharacters[GDVars.downedCount].x := cellX;
      GDVars.downedCharacters[GDVars.downedCount].y := cellY;
    end;
    TextRend.PauseOnly;
    CbtMap.UpdateCombatMapTile(0, 0, slot);
    GDVars.arenaSlots[CbtMap.CombatSlot(creature)].size := 0;
    CbtMap.BuildArenaArrays;
    CbtMap.ScrollView(GDVars.combatArena^.focusX + 3, GDVars.combatArena^.focusY + 3, 3, 8);
    creature^.combatAddr^.initiative := 0;
    creature^.combatAddr^.movement := 0;
    creature^.combatAddr^.spellCast := 0;
    creature^.combatAddr^.guarding := 0;
  end;
end;

function IsValidCreatureLoc(creature: Types.PCreature; x, y: Byte; moving: Boolean): Boolean;
var
  slot: Byte;
  i: Byte;
  c: Byte;
  t: Byte;
  found: Boolean;
  adjStink: Byte;
  adjCloudkill: Byte;
begin
  if GDVars.ifcState = C_Ifc.IN_COMBAT then begin
    IsValidCreatureLoc := False;
    slot := CbtMap.CombatSlot(creature);
    GDVars.arenaSlots[slot].size := creature^.iconDim and $7F;
    GDVars.arenaSlots[slot].x := x;
    GDVars.arenaSlots[slot].y := y;
    CbtMap.ProbeDirection(creature, 8, c, t, adjStink, adjCloudkill);
    if (c <> 0) or (t = 0) or (GDConsts.terrainInfo[t].cost = 255) then
      GDVars.arenaSlots[slot].size := 0
    else begin
      IsValidCreatureLoc := True;
      if moving then
        if creature^.combatAddr^.notPcNpc = 0 then begin
          for i := 1 to GDVars.downedCount do
            if GDVars.downedCharacters[i].cr = creature then begin
              if GDVars.downedCharacters[i].terrain <> C_Terr.CORPSE then
                t := GDVars.downedCharacters[i].terrain;
              FillChar(GDVars.downedCharacters[i], SizeOf(GDVars.downedCharacters[i]), 0);
            end;
          found := False;
          for i := 1 to GDVars.downedCount do
            if (GDVars.downedCharacters[i].cr <> nil) and (GDVars.downedCharacters[i].x = x)
               and (GDVars.downedCharacters[i].y = y) then
              found := True;
          if not found then
            GDVars.combatArena^.cells[y, x] := t;
        end;
      CbtMap.BuildArenaArrays;
    end;
  end else
    IsValidCreatureLoc := True;
end;

procedure DisplayMapViewCentered(creature: Types.PCreature; delta: Byte; cursor: Boolean);
begin
  GDVars.combatArena^.cursorOn := Ord(cursor);
  GDVars.combatArena^.focusSize := GDVars.arenaSlots[CbtMap.CombatSlot(creature)].size;
  if GDVars.mapVisible then
    CbtMap.ScrollView(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), delta, 8);
  GDVars.combatArena^.cursorOn := 0;
  GDVars.combatArena^.focusSize := 1;
end;

begin
end.
