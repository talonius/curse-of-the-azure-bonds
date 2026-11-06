{ Game setup: InitializeGame allocates and fills everything the game needs at startup, and ResetGameState returns the
  globals to their defaults after a game. }
{$O+,F+,I-}
unit GameInit;

interface

{ Sets the game up once at startup: saves the keyboard flags and turns Num Lock on, seeds Random, allocates the GBVM
  banks, the font, wall graphics, 3D map and picture buffers, clears the span tables, builds the CGA, EGA and Tandy row
  tables, clears the GBVM banks and the picture and icon tables, puts the party at (7, 13) facing 0, and sets the other
  globals to their defaults. Then it loads the font, the symbol sets, the combat icons, the sky pictures (not on CGA)
  and the base item table from ITEMS, and installs the spell and effect handlers. }
procedure InitializeGame;

{ Returns the game to its starting state after a game: clears the span tables and the GBVM banks, puts the party at (7,
  13) facing 2, and resets most of the globals InitializeGame gives defaults, leaving the picture and animation
  switches, the demo flag and the sky pictures alone. }
procedure ResetGameState;

{ Calls the priming entry of each overlay this unit uses, so the overlay manager loads them. }
procedure PrimeGameInit;

implementation

uses Types, Blit, TextRend, DaxIo, Sym8x8, MapTiles, MenuCore, EffHndlr, Magic, Explore, Portrait, EclTrace, GDConsts,
  GDVars, C_Ifc, C_Gbvm, C_Pic, C_Video, Crt, GameIo;

var
  { BIOS keyboard flags for the shift and toggle keys held down. }
  kbFlags2: Byte absolute $0040:$0018;

procedure PrimeGameInit;
begin
  Explore.PrimeExplore;
  Magic.PrimeMagic;
  Sym8x8.PrimeSym8x8;
  MapTiles.PrimeMapTiles;
  Portrait.PrimePortrait;
  EffHndlr.PrimeEffHndlr;
  MenuCore.PrimeMenuCore;
  EclTrace.PrimeEclTrace;
end;

procedure InitializeGame;
begin
  { Save the BIOS keyboard flags, then turn Num Lock on (bit 5; the same bit of the second flags byte is Num Lock held
    down). }
  GDVars.savedKbFlags := GameIo.kbFlags;
  GameIo.kbFlags := GameIo.kbFlags or $20;
  kbFlags2 := kbFlags2 or $20;
  Randomize;

  GetMem(GDVars.zone0, SizeOf(GDVars.zone0^));
  GetMem(GDVars.zone1, SizeOf(GDVars.zone1^));
  GetMem(GDVars.zone2, SizeOf(GDVars.zone2^));
  GetMem(GDVars.scriptCode, SizeOf(GDVars.scriptCode^));
  GetMem(GDVars.gameFont, 1416);
  GetMem(GDVars.wallGfx, SizeOf(Types.TWallGfx));
  GetMem(GDVars.map3d, 1024);

  Blit.AllocPic(8, 1, 1, 0, GDVars.sym8x8Buf);
  Blit.AllocPic(8, 1, 1, 0, GDVars.cursorImage);
  FillChar(GDVars.cursorImage^.data, GDVars.cursorImage^.imgSize, $FF);
  Blit.AllocPic(168, 21, 1, 0, GDVars.viewBuffer);
  Blit.AllocPic(24, 3, 1, 0, GDVars.saveUnder);

  FillChar(GDVars.spanActive, SizeOf(GDVars.spanActive), 0);
  FillChar(GDVars.spanScreenOfs, SizeOf(GDVars.spanScreenOfs), 0);
  FillChar(GDVars.spanFirstOfs, SizeOf(GDVars.spanFirstOfs), $FF);
  FillChar(GDVars.spanLastOfs, SizeOf(GDVars.spanLastOfs), 0);

  for GDVars.initLoopIdx := 0 to 199 do begin
    if Odd(GDVars.initLoopIdx) then
      GDVars.cgaRowSeg[GDVars.initLoopIdx] := (GDVars.initLoopIdx div 2) * 5 + C_Video.GFX_BANK1_SEG
    else
      GDVars.cgaRowSeg[GDVars.initLoopIdx] := (GDVars.initLoopIdx div 2) * 5 + C_Video.GFX_BANK0_SEG;
    GDVars.fbRowOfs[GDVars.initLoopIdx] := GDVars.initLoopIdx * 40;
    case GDVars.initLoopIdx mod 4 of
      0: GDVars.tandyRowSeg[GDVars.initLoopIdx] := (GDVars.initLoopIdx div 4) * 10 + C_Video.GFX_BANK0_SEG;
      1: GDVars.tandyRowSeg[GDVars.initLoopIdx] := (GDVars.initLoopIdx div 4) * 10 + C_Video.GFX_BANK1_SEG;
      2: GDVars.tandyRowSeg[GDVars.initLoopIdx] := (GDVars.initLoopIdx div 4) * 10 + C_Video.GFX_BANK2_SEG;
      3: GDVars.tandyRowSeg[GDVars.initLoopIdx] := (GDVars.initLoopIdx div 4) * 10 + C_Video.GFX_BANK3_SEG;
    end;
  end;

  FillChar(GDVars.symbolSetPtrs, SizeOf(GDVars.symbolSetPtrs), 0);
  FillChar(GDVars.tileSet, SizeOf(GDVars.tileSet), 0);
  Blit.AllocPic(24, 3, 48, 0, GDVars.tileSet[0]);

  FillChar(GDVars.zone0^, SizeOf(GDVars.zone0^), 0);
  GDVars.zone0^[C_Gbvm.VIEW_3D] := 1;
  GDVars.zone0^[C_Gbvm.PREV_SCRIPT] := 0;
  FillChar(GDVars.zone1^, SizeOf(GDVars.zone1^), 0);
  FillChar(GDVars.zone2^, SizeOf(GDVars.zone2^), 0);
  FillChar(GDVars.scriptCode^, SizeOf(GDVars.scriptCode^), 0);
  FillChar(GDVars.iconImages, SizeOf(GDVars.iconImages) + SizeOf(GDVars.iconTail) + SizeOf(GDVars.arenaHead), 0);

  for GDVars.initLoopIdx := 1 to 2 do begin
    GDVars.portraits[GDVars.initLoopIdx].fileId := 255;
    GDVars.portraits[GDVars.initLoopIdx].pic := nil;
  end;
  FillChar(GDVars.animData, SizeOf(GDVars.animData), 0);
  GDVars.bigPicImage := nil;
  GDVars.treasureItems := nil;

  FillChar(GDVars.partyPos, SizeOf(GDVars.partyPos), 0);
  GDVars.partyPos.mapX := 7;
  GDVars.partyPos.mapY := 13;
  GDVars.partyPos.facing := 0;
  FillChar(GDVars.lockOptions, SizeOf(GDVars.lockOptions), 1);
  GDVars.wallDefinitions[1].wallDefId := 0;
  GDVars.wallDefinitions[1].symbolSlot := 1;
  for GDVars.initLoopIdx := 2 to 3 do begin
    GDVars.wallDefinitions[GDVars.initLoopIdx].wallDefId := 65535;
    GDVars.wallDefinitions[GDVars.initLoopIdx].symbolSlot := 65535;
  end;

  { The other globals get their defaults; ResetGameState repeats most of these. }
  GDVars.animOn := 1;
  GDVars.picsOn := 1;
  GDVars.debugTraceEnabled := False;
  GDVars.typingDelayOn := True;
  GDVars.loadedSavedGame := False;
  GDVars.restTicks := 0;
  GDVars.partyHead := nil;
  GDVars.curChar := nil;
  GDVars.eclIp := $8000;
  GDVars.gameDelay := 4;
  GDVars.demoMode := False;
  GDVars.diskIndex := 1;
  GDVars.savedDiskIndex := 1;
  GDVars.automapOn := False;
  LastMode := 1;
  GDVars.zone1^[C_Gbvm.PARTY_SIZE] := 0;
  GDVars.verticalMenuTop := 1;
  GDVars.duelFlag := False;
  GDVars.noBorder := 0;
  GDVars.searchBak := 0;
  GDVars.boxCleared := False;
  GDVars.printRetFlag := False;
  GDVars.eclGraphics := False;
  GDVars.partyDefeated := False;
  GDVars.graphicsInitFlag := True;
  GDVars.spriteShown := False;
  GDVars.suppressDiskPrompt := #0;
  GDVars.picArchiveName[0] := #0;
  GDVars.savedPicArchiveName[0] := #0;
  GDVars.loadedPicId := 255;
  GDVars.savedPicId := 255;
  GDVars.recentlySaved := 0;
  GDVars.ceilFloorColorSel := $E8;
  GDVars.wallColorSel := $DB;
  GDVars.inEncMenu := False;
  GDVars.mapVisible := True;
  GDVars.bigPicId := 255;
  GDVars.initFlag1 := False;
  GDVars.initFlag2 := False;
  GDVars.autoTraining := False;
  GDVars.menuChoice := 1;
  GDVars.ifcState := C_Ifc.VIEW_3D;
  GDVars.prevIfcState := 0;
  GDVars.soundActive := True;
  GDVars.overrideFlag := 0;
  GDVars.northSkyImage := nil;
  GDVars.sunImage := nil;
  GDVars.horizonImage := nil;
  GDVars.victoryStart := False;

  TextRend.LoadGameFont;
  MenuCore.ClearBottomLine;
  TextRend.DisplayString(0, 24, LightGreen, 0, 'Loading...Please Wait');
  Sym8x8.Load8x8Set(202, 4);
  Sym8x8.Load8x8Set(203, 0);
  for GDVars.initLoopIdx := 0 to 11 do
    MapTiles.LoadIconAnim('COMSPR', GDVars.initLoopIdx, GDVars.initLoopIdx + 13);
  MapTiles.LoadIconAnim('COMSPR', 25, 25);
  if GDVars.displayMode <> 0 then begin
    Blit.LoadPic('sky', 250, True, C_Pic.TRANSPARENT_COLOR, GDVars.northSkyImage);
    Blit.LoadPic('sky', 251, True, C_Pic.TRANSPARENT_COLOR, GDVars.sunImage);
    Blit.LoadPic('sky', 252, True, C_Pic.TRANSPARENT_COLOR, GDVars.horizonImage);
  end;
  GDVars.itemsOk := DaxIo.OpenWithRetry('ITEMS', GDConsts.diskPrompts[GDVars.diskIndex], #0, GDVars.itemsFile);
  Reset(GDVars.itemsFile, 1);
  Seek(GDVars.itemsFile, 2);
  BlockRead(GDVars.itemsFile, GDVars.baseItems, SizeOf(GDVars.baseItems), GDVars.itemsRead);
  Close(GDVars.itemsFile);
  Magic.InitSpellFns;
  EffHndlr.InitEffectHandlers;
end;

procedure ResetGameState;
begin

  FillChar(GDVars.spanActive, SizeOf(GDVars.spanActive), 0);
  FillChar(GDVars.spanScreenOfs, SizeOf(GDVars.spanScreenOfs), 0);
  FillChar(GDVars.spanFirstOfs, SizeOf(GDVars.spanFirstOfs), $FF);
  FillChar(GDVars.spanLastOfs, SizeOf(GDVars.spanLastOfs), 0);

  FillChar(GDVars.zone0^, SizeOf(GDVars.zone0^), 0);
  GDVars.zone0^[C_Gbvm.VIEW_3D] := 1;
  GDVars.zone0^[C_Gbvm.PREV_SCRIPT] := 0;
  FillChar(GDVars.zone1^, SizeOf(GDVars.zone1^), 0);
  FillChar(GDVars.zone2^, SizeOf(GDVars.zone2^), 0);
  FillChar(GDVars.scriptCode^, SizeOf(GDVars.scriptCode^), 0);

  FillChar(GDVars.partyPos, SizeOf(GDVars.partyPos), 0);
  GDVars.partyPos.mapX := 7;
  GDVars.partyPos.mapY := 13;
  GDVars.partyPos.facing := 2;
  FillChar(GDVars.lockOptions, SizeOf(GDVars.lockOptions), 1);
  GDVars.wallDefinitions[1].wallDefId := 0;
  GDVars.wallDefinitions[1].symbolSlot := 1;
  for GDVars.initLoopIdx := 2 to 3 do begin
    GDVars.wallDefinitions[GDVars.initLoopIdx].wallDefId := 65535;
    GDVars.wallDefinitions[GDVars.initLoopIdx].symbolSlot := 65535;
  end;

  GDVars.debugTraceEnabled := False;
  GDVars.typingDelayOn := True;
  GDVars.loadedSavedGame := False;
  GDVars.restTicks := 0;
  GDVars.partyHead := nil;
  GDVars.curChar := nil;
  GDVars.eclIp := $8000;
  GDVars.gameDelay := 4;
  GDVars.diskIndex := 1;
  GDVars.savedDiskIndex := 1;
  GDVars.automapOn := False;
  LastMode := 1;
  GDVars.zone1^[C_Gbvm.PARTY_SIZE] := 0;
  GDVars.verticalMenuTop := 1;
  GDVars.duelFlag := False;
  GDVars.noBorder := 0;
  GDVars.searchBak := 0;
  GDVars.boxCleared := False;
  GDVars.printRetFlag := False;
  GDVars.eclGraphics := False;
  GDVars.partyDefeated := False;
  GDVars.graphicsInitFlag := True;
  GDVars.spriteShown := False;
  GDVars.suppressDiskPrompt := #0;
  GDVars.picArchiveName[0] := #0;
  GDVars.savedPicArchiveName[0] := #0;
  GDVars.loadedPicId := 255;
  GDVars.savedPicId := 255;
  GDVars.recentlySaved := 0;
  GDVars.ceilFloorColorSel := $E8;
  GDVars.wallColorSel := $DB;
  GDVars.inEncMenu := False;
  GDVars.mapVisible := True;
  GDVars.bigPicId := 255;
  GDVars.initFlag1 := False;
  GDVars.initFlag2 := False;
  GDVars.autoTraining := False;
  MenuCore.ClearBottomLine;
  GDVars.menuChoice := 1;
  GDVars.ifcState := C_Ifc.VIEW_3D;
  GDVars.prevIfcState := 0;
  GDVars.soundActive := True;
  GDVars.overrideFlag := 0;
  GDVars.victoryStart := False;
end;

begin
end.
