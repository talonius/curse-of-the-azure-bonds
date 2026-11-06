{ Pictures in the view: portrait heads and bodies, the full-screen big picture, PIC animations and 3D sprites. }
{$O+,F+,I-}
unit Portrait;

interface

uses Types, Blit, DaxIo, GDConsts, GDVars, TextRend, GameIo, Border, EclTrace, Crt, C_Gbvm;

{ Draws a picture at a cell; nothing for nil. With anim, or while the script's animation request is set (the picture
  then recolored first through the portrait tint table), it is blitted into the view one cell up and left of the given
  cell and flushed; otherwise it is shown directly.
  @param(col Column of the cell.)
  @param(row Row of the cell.)
  @param(anim True to draw through the view, as an animation frame.)
  @param(pic The picture, or nil.) }
procedure DisplayImageBuf(col, row: Integer; anim: Boolean; pic: Types.PImgBuf);

{ Draws a portrait head at a cell.
  @param(col Column of the cell.)
  @param(row Row of the cell.)
  @param(pic The head picture.) }
procedure DisplayPortraitHead(col, row: Byte; pic: Types.PImgBuf);

{ Draws a portrait body 5 rows below a cell, under its head.
  @param(col Column of the head's cell.)
  @param(row Row of the head's cell.)
  @param(pic The body picture.) }
procedure DisplayPortraitBody(col, row: Byte; pic: Types.PImgBuf);

{ Loads an animation from <name><disk>.DAX, unless it is the one already loaded or picId is 255. PIC and FINAL
  animations store each later frame XORed with the first, and while the animation flag is off only their first frame is
  loaded. Frames stop loading when free memory drops below 3900 bytes; outside CGA, transparent frames are recolored
  through the portrait key table. While the animation flag is on, "Loading...Please Wait" shows meanwhile; a missing
  block reports "PIC not found". Note: the name and id are recorded as loaded before the block is read, so after "PIC
  not found" the same request is skipped.
  @param(name The archive's base name.)
  @param(picId The animation's block id, or 255 for none.)
  @param(transp Bit 0 set for transparent frames.)
  @param(anim Receives the frames; its old frames are freed first.) }
procedure LoadAnimation(name: Types.TStr8; picId, transp: Byte; var anim: Types.TAnimRec);

{ Frees an animation's frames, clears it, and forgets the name and id of the loaded animation.
  @param(anim The animation.) }
procedure FreeAnimation(var anim: Types.TAnimRec);

{ Draws the loaded portrait head at a cell and, optionally, the body below it.
  @param(col Column of the cell.)
  @param(row Row of the cell.)
  @param(both True to draw the body too.) }
procedure DisplayPortraitBufs(col, row: Byte; both: Boolean);

{ Loads a portrait head from HEAD<disk>.DAX and a body from BODY<disk>.DAX, skipping 255 and those already loaded. Note:
  a missing body also reports "head not found".
  @param(headId The head's block id, or 255 to keep the current head.)
  @param(bodyId The body's block id, or 255 to keep the current body.) }
procedure LoadPortraitBufs(headId, bodyId: Byte);

{ Draws a frame of a 3D sprite animation into the view at its origin moved 2 cells right and down and flushes it;
  nothing happens when that frame is not loaded. A distance outside 1 to 3 restores the video mode, prints "Illegal
  range in Show3DSprite." and quits.
  @param(dist The distance, 1 to 3, which is the frame drawn.)
  @param(anim The sprite animation.) }
procedure Show3DSprite(dist: Byte; anim: Types.TAnimRec);

{ Frees the picture-window animation (GDVars.animData), then loads a full-screen picture from BIGPIC<disk>.DAX unless it
  is already loaded.
  @param(id The picture's block id.) }
procedure LoadBigPic(id: Byte);

{ Draws the full-screen picture frame and shows the loaded big picture in it. }
procedure DisplayBigPic;

{ Calls the priming entry of the overlay this unit uses, so the overlay manager loads it. }
procedure PrimePortrait;

implementation

procedure PrimePortrait;
begin
  EclTrace.PrimeEclTrace;
end;

procedure DisplayImageBuf(col, row: Integer; anim: Boolean; pic: Types.PImgBuf);
begin
  if pic <> nil then
    if (GDVars.zone0^[C_Gbvm.ANIM_REQUEST] > 0) or anim then begin
      if GDVars.zone0^[C_Gbvm.ANIM_REQUEST] > 0 then
        Blit.RemapPic(GDConsts.portraitRemap.tintSrc, GDConsts.portraitRemap.tintDst, 0, True, pic);
      Blit.BlitTileClipped(col - 1, row - 1, 0, 0, pic, GDVars.viewBuffer);
      Blit.FlushView;
    end else
      Blit.ShowPic(col, row, pic);
end;

procedure DisplayPortraitHead(col, row: Byte; pic: Types.PImgBuf);
begin
  Portrait.DisplayImageBuf(col, row, False, pic);
end;

procedure DisplayPortraitBody(col, row: Byte; pic: Types.PImgBuf);
begin
  Portrait.DisplayImageBuf(col, row + 5, False, pic);
end;

procedure LoadAnimation(name: Types.TStr8; picId, transp: Byte; var anim: Types.TAnimRec);
var
  sz: Word;
  buf: Types.PByteArr;
  offset: Word;
  f: Byte;
  h: Word;
  w: Word;
  diskCh: String[1];
  xorBuf: Types.PByteArr;
  j: Word;
  planeSz: Word;
  isPic: Boolean;
  gotXor: Boolean;
  loaded: Byte;
begin
  if ((name = GDVars.picArchiveName) and (picId = GDVars.loadedPicId)) or (picId = 255) then Exit;
  if GDVars.animOn <> 0 then begin
    TextRend.PrintSpaces(0, 24, 0, 40);
    TextRend.DisplayString(0, 24, LightGreen, 0, 'Loading...Please Wait');
  end;
  Portrait.FreeAnimation(anim);
  GDVars.picArchiveName := name;
  GDVars.loadedPicId := picId;
  isPic := (name = 'PIC') or (name = 'FINAL');
  Str(LongInt(GDVars.diskIndex), diskCh);
  DaxIo.LoadDax(name + diskCh, '.dax', picId, sz, buf);
  if sz = 0 then begin
    TextRend.DisplayAndPause(Yellow, 0, 'PIC not found');
    Exit;
  end;
  offset := 0;
  gotXor := False;
  with anim do begin
    count := buf^[offset];
    Inc(offset);
    current := 1;
    loaded := 0;
    if (GDVars.animOn = 0) and isPic then count := 1;
    for f := 1 to count do begin
      Move(buf^[offset], frames[f].time, SizeOf(frames[f].time));
      Inc(offset, 4);
      Move(buf^[offset], h, SizeOf(h));
      Inc(offset, 2);
      Move(buf^[offset], w, SizeOf(w));
      Inc(offset, 2);
      if MaxAvail >= 3900 then begin
        Inc(loaded);
        Blit.AllocPic(h, w, 1, transp, frames[f].pic);
        with frames[f].pic^ do begin
          Move(buf^[offset], originX, SizeOf(originX));
          Inc(offset, 2);
          Move(buf^[offset], originY, SizeOf(originY));
          Inc(offset, 3);
          Move(buf^[offset], map, SizeOf(map));
          Inc(offset, 8);
        end;
        if GDVars.displayMode = 0 then
          planeSz := frames[f].pic^.imgSize * 2 - 1
        else
          planeSz := frames[f].pic^.imgSize - 1;
        if isPic then
          if f = 1 then begin
            GetMem(xorBuf, planeSz + 1);
            Move(buf^[offset], xorBuf^, planeSz + 1);
            gotXor := True;
          end else
            for j := offset to offset + planeSz do
              buf^[j] := buf^[j] xor xorBuf^[j - offset];
        Blit.ExpandPicFrames(buf, offset, Boolean(transp), 0, frames[f].pic);
        if (transp and 1 > 0) and (GDVars.displayMode <> 0) then
          Blit.RemapPic(GDConsts.portraitRemap.keySrc, GDConsts.portraitRemap.keyDst, 0, False, frames[f].pic);
        Inc(offset, planeSz + 1);
      end else
        count := 1;
    end;
    count := loaded;
  end;
  if isPic and gotXor then FreeMem(xorBuf, planeSz + 1);
  FreeMem(buf, sz);
  GameIo.DiscardPendingKeys;
  if GDVars.animOn <> 0 then TextRend.PrintSpaces(0, 24, 0, 40);
end;

procedure FreeAnimation(var anim: Types.TAnimRec);
begin
  with anim do
    for GDVars.sharedLoopIdx := 1 to count do
      Blit.FreePic(frames[GDVars.sharedLoopIdx].pic);
  FillChar(anim, SizeOf(anim), 0);
  GDVars.picArchiveName[0] := #0;
  GDVars.loadedPicId := 255;
end;

procedure LoadPortraitBufs(headId, bodyId: Byte);
var
  diskCh: String[1];
begin
  Str(LongInt(GDVars.diskIndex), diskCh);
  if headId <> 255 then
    if (GDVars.portraits[1].fileId = 255) or (GDVars.portraits[1].fileId <> headId) then begin
      Blit.LoadPic('HEAD' + diskCh, headId, False, 0, GDVars.portraits[1].pic);
      if GDVars.portraits[1].pic = nil then
        TextRend.DisplayAndPause(Yellow, 0, 'head not found');
      GDVars.portraits[1].fileId := headId;
    end;
  if bodyId <> 255 then
    if (GDVars.portraits[2].fileId = 255) or (GDVars.portraits[2].fileId <> bodyId) then begin
      Blit.LoadPic('BODY' + diskCh, bodyId, False, 0, GDVars.portraits[2].pic);
      if GDVars.portraits[2].pic = nil then
        TextRend.DisplayAndPause(Yellow, 0, 'head not found');
      GDVars.portraits[2].fileId := bodyId;
    end;
  GameIo.DiscardPendingKeys;
end;

procedure DisplayPortraitBufs(col, row: Byte; both: Boolean);
begin
  if both then begin
    Portrait.DisplayPortraitHead(col, row, GDVars.portraits[1].pic);
    Portrait.DisplayPortraitBody(col, row, GDVars.portraits[2].pic);
  end else
    Portrait.DisplayImageBuf(col, row, False, GDVars.portraits[1].pic);
end;

procedure Show3DSprite(dist: Byte; anim: Types.TAnimRec);
begin
  if (dist < 1) or (dist > 3) then begin
    Blit.RestoreVideoMode;
    WriteLn('Illegal range in Show3DSprite.');
    GameIo.ExitGame;
  end;
  if anim.frames[dist].pic <> nil then
    with anim.frames[dist].pic^ do
      Blit.BlitTileClipped(originX + 3 - 1, originY + 3 - 1, 0, 1, anim.frames[dist].pic, GDVars.viewBuffer)
  else
    Exit;
  Blit.FlushView;
end;

procedure LoadBigPic(id: Byte);
var
  diskCh: String[1];
begin
  Portrait.FreeAnimation(GDVars.animData);
  if GDVars.bigPicId = id then Exit;
  Str(LongInt(GDVars.diskIndex), diskCh);
  Blit.LoadPic('bigpic' + diskCh, id, False, 0, GDVars.bigPicImage);
  GDVars.bigPicId := id;
end;

procedure DisplayBigPic;
begin
  Border.DrawRowDivider;
  Blit.ShowPic(1, 1, GDVars.bigPicImage);
end;

begin
end.
