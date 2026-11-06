{ The program: initializes the game, shows the introduction and the Play Demo menu, asks the copy-protection question,
  then repeats party creation and exploration; after a demo run it goes back to the introduction and the menu. }
{$M 10000,65536,655360}
{$F+,O+}
program FixMain;

uses
  Overlay, Crt, Dos, Types,
  GDConsts, GDVars,
  ModeInit, SoundDrv,
  DaxIo, TextRend, Blit, GameIo, GameBoot,
  Sym8x8, Border, EclTrace, EmptyB,
  MapTiles, CbtMap, Pathing, EmptyC,
  View3D,
  Portrait, MapView, MapCurs, MenuCore, ClassCal, CharHlp,
  FxEngine, Magic, Money, GameTime, ViewChar, Ending,
  SaveLoad, CharGen, Camp, Explore, CbtActs, EffHndlr,
  GameInit, CombatSt, CombatAi, Combat, EclMenu, Shop,
  PostCbt, Temple, CopyProt, EclVm, Intro, HeapErr;

{$O HeapErr}
{$O Intro}
{$O EclVm}
{$O CopyProt}
{$O Temple}
{$O PostCbt}
{$O Shop}
{$O EclMenu}
{$O Combat}
{$O CombatAi}
{$O CombatSt}
{$O GameInit}
{$O EffHndlr}
{$O CbtActs}
{$O Explore}
{$O Camp}
{$O SaveLoad}
{$O CharGen}
{$O Ending}
{$O ViewChar}
{$O GameTime}
{$O Money}
{$O Magic}
{$O FxEngine}
{$O CharHlp}
{$O ClassCal}
{$O MenuCore}
{$O MapCurs}
{$O MapView}
{$O Portrait}
{$O View3D}
{$O Pathing}
{$O CbtMap}
{$O MapTiles}
{$O EclTrace}
{$O Sym8x8}

const
  STING_KEYWORD = 'STING';
  BANNER = 'Curse of the Azure Bonds v1.1 ';
  PLAY_DEMO = 'Play Demo';
  { Shown instead of BANNER when a demo run returns to the menu. }
  BANNER_V10 = 'Curse of the Azure Bonds v1.0 ';

begin
  SoundDrv.StartSound;
  if GDVars.soundActive then SoundDrv.SoundCommand(GDConsts.sndShutdown);
  GameInit.PrimeGameInit;
  GameInit.InitializeGame;
  if not GDVars.soundActive then SoundDrv.StartSound;
  SoundDrv.SoundCommand(GDConsts.sndSilence);
  SoundDrv.StartSound;

  { STING as the first parameter skips the introduction. }
  if ParamStr(1) <> STING_KEYWORD then Intro.Introduction;

  { Play Demo (D) is chosen by the player, or by default when the 3000-count menu timeout runs out. }
  GDVars.menuTimeout := 3000;
  GDVars.menuDefaultKey := 'D';
  GDVars.menuResult := MenuCore.MenuHorizontal(BANNER, PLAY_DEMO, LightMagenta, LightGreen, White, False, False,
                                               GDVars.titleMenuExtendedKey);
  GDVars.menuTimeout := 0;
  GDVars.menuDefaultKey := #0;
  if GDVars.menuResult = 'D' then GDVars.demoMode := True;

  { The copy-protection question is skipped in the demo or when the second parameter is ModeInit's keyword. }
  if (ParamStr(2) <> GDVars.commandText) and (not GDVars.demoMode) then
    CopyProt.CopyProtection;

  { Each pass: party creation (not in the demo), the 3D view, the area scripts, and a game reset. The demo plays from
    disk 1 at game speed 9. }
  repeat
    if GDVars.demoMode then begin
      GDVars.diskIndex := 1;
      GDVars.gameDelay := 9;
    end else
      GDVars.diskIndex := 2;

    if GDVars.soundActive then SoundDrv.SoundCommand(GDConsts.sndShutdown);
    CharGen.PrimeCharGen;
    if not GDVars.soundActive then SoundDrv.StartSound;
    if not GDVars.demoMode then CharGen.MainMenu;

    if GDVars.soundActive then SoundDrv.SoundCommand(GDConsts.sndShutdown);
    View3D.PrimeView3D;
    if not GDVars.soundActive then SoundDrv.StartSound;
    View3D.SetView3DColors(GDVars.skyCeilingColor, GDVars.ceilingBandColor, GDVars.midBandColor, GDVars.floorBandColor);

    if GDVars.soundActive then SoundDrv.SoundCommand(GDConsts.sndShutdown);
    EclVm.PrimeEclVm;
    if not GDVars.soundActive then SoundDrv.StartSound;
    EclVm.GameLoop;

    if GDVars.soundActive then SoundDrv.SoundCommand(GDConsts.sndShutdown);
    GameInit.PrimeGameInit;
    if not GDVars.soundActive then SoundDrv.StartSound;
    GameInit.ResetGameState;

    if GDVars.demoMode then begin
      Intro.Introduction;
      GameIo.DiscardPendingKeys;
      GDVars.menuTimeout := 1000;
      GDVars.menuDefaultKey := 'D';
      GDVars.menuResult := MenuCore.MenuHorizontal(BANNER_V10, PLAY_DEMO, LightMagenta, LightGreen, White, False,
                                                   False, GDVars.titleMenuExtendedKey);
      GDVars.menuTimeout := 0;
      GDVars.menuDefaultKey := #0;
      GDVars.demoMode := (GDVars.menuResult = 'D');
      if (ParamStr(2) <> GDVars.commandText) and (not GDVars.demoMode) then
        CopyProt.CopyProtection;
      SoundDrv.SoundCommand(GDConsts.sndSilence);
    end;
  until False;
end.
