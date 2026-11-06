{ The 24x24 map tiles (two tile sets) and the combat icons (two frames each): loading them and drawing them into the
  view. }
{$O+,F+,I-}
unit MapTiles;

interface

uses Blit, GameIo, EclTrace, Types, GDConsts, GDVars;

{ Loads a picture and copies its first frames, 24x24 tiles, into the first tile set from a frame slot on (skipped when
  the set is not allocated). A slot above 48 quits with a range error; the slot plus the tile count is not checked.
  Note: a picture that fails to load is used through its nil pointer.
  @param(name The archive's name.)
  @param(fileId The picture's block id.)
  @param(slot The first frame slot to fill.)
  @param(nTiles The number of tiles to copy.) }
procedure Load24x24Set(name: string; fileId, slot, nTiles: Byte);

{ Draws a map tile into the view at a cell with BlitTileCell's flag; tiles 128 and up come from the second tile set, the
  others from the first.
  @param(col Column of the cell.)
  @param(row Row of the cell.)
  @param(tile The tile number.)
  @param(flag BlitTileCell's flag.) }
procedure Copy2DTile(col, row: ShortInt; tile, flag: Byte);

{ Frees both frames of a combat icon.
  @param(animIdx The icon slot.) }
procedure FreeIconAnim(animIdx: Byte);

{ Loads both frames of a combat icon, the second from block fileId + 128. CHEAD and CBODY names drop their last letter
  (a final T adds 64 to fileId); COMSPR and ICON load as named, ICON recolored through the pink-0 table; any other name
  gets the disk number appended and is recolored through the pink-8 table.
  @param(name The archive's name.)
  @param(fileId The first frame's block id.)
  @param(animIdx The icon slot.) }
procedure LoadIconAnim(name: string; fileId, animIdx: Byte);

{ Draws a frame of a combat icon into the view at the cell three times the given column and row, mirrored for facings 4
  to 7 and clipped to the view; nothing happens when that frame is not loaded.
  @param(col Column on the combat map.)
  @param(row Row on the combat map.)
  @param(facing The facing, 0 to 7.)
  @param(frame The frame, 0 or 1.)
  @param(animIdx The icon slot.) }
procedure DrawIconAnimSprite(col, row: ShortInt; facing, frame, animIdx: Byte);

{ Calls the priming entry of each overlay this unit uses, so the overlay manager loads them. }
procedure PrimeMapTiles;

implementation

var
  { The icon slots as the icon loaders index them: 26 slots, the last (the combat cursor sprite) running past iconImages
    over iconTail and arenaHead. }
  iconSlots: array[0..25, 0..1] of Types.PImgBuf absolute GDVars.iconImages;

procedure PrimeMapTiles;
begin
  EclTrace.PrimeEclTrace;
end;

procedure Load24x24Set(name: string; fileId, slot, nTiles: Byte);
var
  pic: Types.PImgBuf;
  total: Word;
  offset: Word;
begin
  if slot > 48 then begin
    Blit.RestoreVideoMode;
    WriteLn('Start range error in Load24x24Set');
    GameIo.ExitGame;
  end;
  pic := nil;
  Blit.LoadPic(name, fileId, False, 0, pic);
  total := nTiles * pic^.imgSize;
  offset := slot * pic^.imgSize;
  if GDVars.tileSet[0] <> nil then
    Move(pic^.data, GDVars.tileSet[0]^.data[offset], total);
  Blit.FreePic(pic);
  GameIo.DiscardPendingKeys;
end;

procedure Copy2DTile(col, row: ShortInt; tile, flag: Byte);
begin
  if tile > 127 then
    Blit.BlitTileCell(col, row, tile and $7F, flag, GDVars.tileSet[1], GDVars.viewBuffer)
  else
    Blit.BlitTileCell(col, row, tile, flag, GDVars.tileSet[0], GDVars.viewBuffer);
end;

procedure FreeIconAnim(animIdx: Byte);
var
  { Unused in this version; see the other implementations of this routine. }
  i: Integer;
begin
  if iconSlots[animIdx, 0] <> nil then
    Blit.FreePic(iconSlots[animIdx, 0]);
  if iconSlots[animIdx, 1] <> nil then
    Blit.FreePic(iconSlots[animIdx, 1]);
end;

procedure LoadIconAnim(name: string; fileId, animIdx: Byte);
var
  suffix: string[1];
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
begin
  if (Copy(name, 1, 5) = 'CHEAD') or (Copy(name, 1, 5) = 'CBODY') then begin
    if UpCase(name[Length(name)]) = 'T' then
      Inc(fileId, 64);
    name := Copy(name, 1, Length(name) - 1);
    suffix := '';
    Blit.LoadPic(name + suffix, fileId, True, 0, iconSlots[animIdx, 0]);
    Blit.LoadPic(name + suffix, fileId + 128, True, 0, iconSlots[animIdx, 1]);
  end else if (name = 'COMSPR') or (name = 'ICON') then begin
    suffix := '';
    Blit.LoadPic(name + suffix, fileId, True, 0, iconSlots[animIdx, 0]);
    Blit.LoadPic(name + suffix, fileId + 128, True, 0, iconSlots[animIdx, 1]);
    if name = 'ICON' then begin
      Blit.RemapPic(GDConsts.tileColorMaps.cmapIdent, GDConsts.tileColorMaps.cmapPink0, 0, False,
                    iconSlots[animIdx, 0]);
      Blit.RemapPic(GDConsts.tileColorMaps.cmapIdent, GDConsts.tileColorMaps.cmapPink0, 0, False,
                    iconSlots[animIdx, 1]);
    end;
  end else begin
    Str(GDVars.diskIndex, suffix);
    Blit.LoadPic(name + suffix, fileId, True, 0, iconSlots[animIdx, 0]);
    Blit.RemapPic(GDConsts.tileColorMaps.cmapIdent, GDConsts.tileColorMaps.cmapPink8, 0, False,
                  iconSlots[animIdx, 0]);
    Blit.LoadPic(name + suffix, fileId + 128, True, 0, iconSlots[animIdx, 1]);
    Blit.RemapPic(GDConsts.tileColorMaps.cmapIdent, GDConsts.tileColorMaps.cmapPink8, 0, False,
                  iconSlots[animIdx, 1]);
  end;
  GameIo.DiscardPendingKeys;
end;

procedure DrawIconAnimSprite(col, row: ShortInt; facing, frame, animIdx: Byte);
var
  work: Types.PImgBuf;
begin
  if iconSlots[animIdx, frame] = nil then
    Exit;
  with iconSlots[animIdx, frame]^ do begin
    Blit.AllocPic(height, width, 1, 1, work);
    if facing > 3 then
      Blit.MirrorPic(iconSlots[animIdx, frame], work)
    else begin
      Move(data, work^.data, imgSize);
      Move(transp^, work^.transp^, imgSize);
    end;
  end;
  Blit.BlitTileClipped(col * 3, row * 3, 0, 1, work, GDVars.viewBuffer);
  Blit.FreePic(work);
end;

begin
end.
