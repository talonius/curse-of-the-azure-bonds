{ Global variables: the game's variables in storage order, grouped in sections by subsystem. A new section starts
  wherever the data needs a word boundary. }
unit GDVars;

interface

uses Types;

{ Title menu answer and the script interpreter's run state: stop and switch requests, what LOAD FILES and LOAD PIECES
  have loaded, the monster count and the character to restore. }
var
  { The title menu's answer: D plays the demo, anything else starts a game. The menu returns D by itself when its
    countdown runs out. }
  menuResult: Char;
  { Receives the title menu's extended-key flag; never read. }
  titleMenuExtendedKey: Boolean;
  { Set by EXIT and NEWECL to end the running script; CallEclScript clears it before and after its command loop. }
  eclStop: Boolean;
  { Set by NEWECL when a script has loaded a different area script. The game loop and NewEclDone check it after each
    entry point runs, so the new script's load, step and after-step entries run before play continues. }
  newEclFlag: Boolean;
  { Set by LOAD CHARACTER: EXIT and PROGRAM then put back the current character saved in savedChar. Cleared when the
    loaded character is the one saved, or when the game loop starts. }
  restoreChar: Boolean;
  { Set once LOAD FILES or LOAD PIECES has run in this area (or when a saved game resumes); the map cell is redrawn
    after a script switch, and on the script call that refreshes the view, only when it is set. Cleared when the game
    loop starts. }
  filesLoaded: Boolean;
  { Set when LOAD PIECES has loaded the wall sets. With mapLoaded, after leaving the overland map, it lets EclLoadFiles
    redraw the 3D screen once both are in. Cleared when the game loop starts. }
  piecesLoaded: Boolean;
  { Set when LOAD FILES has loaded the 3D map. With piecesLoaded, after leaving the overland map, it lets EclLoadFiles
    redraw the 3D screen once both are in. Cleared when the game loop starts. }
  mapLoaded: Boolean;
  { Number of monsters LOAD MONSTER has added to the party list for the coming fight; it stops adding at 63.
    CLEARMONSTERS resets it. }
  monsterCount: Byte;
  { The current character as it was before a script step, LOAD CHARACTER or a script switch; the scripts' EXIT and
    PROGRAM commands and NewEclDone restore curChar from it. }
  savedChar: Types.PCreature;

{ Combat aftermath flags, and the shop's item list redraw flag. }
var
  { Set after a fight that had monsters in it: by DetermineLootExp for each downed hostile and by
    PostCombatCreatureCleanup for each monster or hostile it removes. PostCombatSummary shows the results and treasure
    only when it is set or the fight was a duel. }
  monstersKilled: Boolean;
  { Set by DetermineCombatResults when a party member is running and none is still standing. The fled members keep their
    status, the treasure is thrown away and the summary says the party has fled. }
  partyFled: Boolean;
  { Tells the Buy menu's item list to redraw its window; ShopBuyMenu sets it when it opens and the list clears it after
    drawing. }
  buyRedraw: Boolean;

{ Combat AI movement state for the creature taking its turn. }
var
  { Direction of the last step the AI took this turn, 0..7, or 8 before the first. A step straight back the way it came
    counts as stuck. }
  lastMoveDir: Byte;
  { Steps this turn on which the AI found no way forward or had to double back. The second makes it drop its target and
    look for another; the third ends its movement. }
  stuckCount: Byte;
  { Cleared at the start of each AI turn; never read. }
  aiMoveState: Byte;

{ Arena building: the creature placement grids for each team and the walls of the dungeon cell being drawn. }
var
  { Free placement quads per team (0 = party, 1 = hostiles), ring 0..3, quad row and quad column: True while a creature
    can still be put there. PlaceAllCreatures fills each ring from the facing's row bands; TryPlaceAt clears a quad when
    it places a creature on it. }
  quadFree: array[0..1, 0..3, 0..5, 0..10] of Boolean;
  { Each team's grid origin across, in dungeon cells from the party: 0 for the party, the monster distance along the
    party's facing for the hostiles. }
  placeX: array[0..1] of ShortInt;
  { Each team's grid origin down, in dungeon cells from the party: 0 for the party, the monster distance along the
    party's facing for the hostiles. }
  placeY: array[0..1] of ShortInt;
  { Length of each team's first placement leg: half the team's size, rounded up. }
  teamRows: array[0..1] of ShortInt;
  { The quadrant each team faces, 0..3: the party's facing halved for the party, the opposite facing for the hostiles.
    It picks the ring start and ring directions in FindPlacement. }
  teamDir: array[0..1] of ShortInt;
  { Column of the dungeon cell being drawn into the arena, -6..6 from the party; also the loop index of
    BuildDungeonArena's cell walk. }
  skewX: ShortInt;
  { Row of the dungeon cell being drawn into the arena, -2..2 from the party; also the loop index of BuildDungeonArena's
    cell walk. }
  skewY: ShortInt;
  { Wall class on the north side of the dungeon cell being drawn: 0 open, 1 solid, 3 a door or other passable wall. }
  wallN: Byte;
  { Wall class on the west side of the dungeon cell being drawn: 0 open, 1 solid, 3 a door or other passable wall. }
  wallW: Byte;
  { Wall class on the east side of the dungeon cell being drawn: 0 open, 1 solid, 3 a door or other passable wall. }
  wallE: Byte;
  { Wall class on the south side of the dungeon cell being drawn: 0 open, 1 solid, 3 a door or other passable wall. }
  wallS: Byte;
  { The team being placed, 0 for the party and 1 for the hostiles; the loop index of PlaceAllCreatures's per-team setup
    and then each creature's hostile flag. }
  team: ShortInt;

{ Arena terrain: the wilderness terrain under the party and the decoration flags of the dungeon cell being drawn. }
var
  { Wilderness terrain code under the party, copied from zone 0 by BuildWildernessArena; TerrainClassOf looks up its
    feature-class bits, which steer the river, tree and scatter generators. }
  terrainChar: Byte;
  { Feature bit of the dungeon cell being drawn, from its map cell: nonzero lets DecorateCell scatter terrain in it. }
  featureOk: Byte;
  { True when the dungeon cell being drawn has a solid wall, no door-like wall, and no pair of opposite solid walls
    unless all four sides are solid, which leaves out corridors and dead ends; DecorateCell decorates such cells. }
  enclosed: Boolean;

{ Startup scratch and the item table file, the ending's fireworks, the character sheet's creatures, the rest timers'
  effect flags and the spell and scroll menus. }
var
  { Reserved, never read: the bytes that open this run, before initLoopIdx. }
  initLoopIdxLead: array[0..3] of Byte;
  { Loop index of InitializeGame's scanline-table and portrait setup loops, the combat-sprite loads and ResetGameState's
    saved-position reset. }
  initLoopIdx: Byte;
  { Reserved, never read: the bytes after initLoopIdx, before itemsOk. }
  initLoopIdxTail: array[0..2] of Byte;
  { Result of opening ITEMS in InitializeGame; set but never read. }
  itemsOk: Boolean;
  { Reserved, never read: the bytes after itemsOk, before itemsFile. }
  itemsOkTail: array[0..42] of Byte;
  { The ITEMS file, open while InitializeGame reads the base item table into baseItems. }
  itemsFile: file;
  { Reserved, never read: the bytes after itemsFile, before starBuf. }
  starBufLead: array[0..1] of Byte;
  { The fireworks star field, three layers of 40 stars, allocated on the heap for the length of VictoryAnim. }
  starBuf: Types.PStarField;
  { Ticks the longest layer of the current firework burst lasts; RunStarField advances the field this many ticks plus
    one. }
  maxDelay: Byte;
  { Fireworks pixel color per layer and per star stage, set by InitStarField from the layer's color seed and the display
    mode. }
  colors: array[1..3, 1..5] of Byte;
  { Key code that stops the fireworks; VictoryAnim loops while it is 0. }
  animDone: Byte;
  { Color seed of each fireworks layer for the next burst: 1 is dim, 2..6 a color. VictoryAnim colors the first one or
    two layers. }
  sizes: Types.TLayerMask;
  { Loop index of VictoryAnim's layer-color loop. }
  fillIdx: Byte;
  { Fireworks spark column in pixels; it rises from 65 and is where the burst starts. }
  px: Integer;
  { Fireworks spark row in pixels; it rises from 65 and is where the burst starts. }
  py: Integer;
  { Fireworks spark velocity across, in 1/32 pixel per step. }
  vx: Integer;
  { Fireworks spark velocity down, in 1/32 pixel per step; negative while rising, it grows by 1 each step. }
  vy: Integer;
  { The spark's starting velocity across, kept so the drawn launch repeats the undrawn one that found the burst point. }
  saveVx: Integer;
  { The spark's starting velocity down, kept so the drawn launch repeats the undrawn one that found the burst point. }
  saveVy: Integer;
  { Number of colored layers in the next fireworks burst, 1 or 2; the rest stay dim. }
  burstCount: Byte;
  { The character on the character sheet; DisplayChar sets it from curChar, and the sheet's menus and item lines read
    it. }
  sheetChar: Types.PCreature;
  { The party member chosen last on the character sheet's trade prompts, offered first the next time; ViewCharMenu
    starts it at the current character. }
  tradeTarget: Types.PCreature;
  { One flag per party member in list order: set while that member has timed effects left to run down. TimeOutEffects in
    camp skips unflagged members and does nothing when none is flagged; CampRest and each call outside camp mark them
    all. }
  effFlags: array[1..72] of Boolean;
  { The spell menu's string list: spell names with level headings, built by GenerateSpellList and freed by
    SpellSelection. }
  spellList: Types.PItem;
  { How many copies of each listed spell the character holds, in menu order without headings; more than one shows as a
    count after the name. }
  spellCounts: array[0..83] of Byte;
  { Spell id of each menu entry, in menu order without headings; SpellSelection returns the chosen one. }
  spellIds: array[0..83] of Byte;
  { The scroll each scroll-spell menu entry came from; choosing a scroll spell makes it currentScroll. }
  scrollPtrs: array[0..48] of Types.PItem;
  { Number of scroll-spell entries recorded in scrollPtrs. }
  scrollCount: Byte;
  { Spell scratch: the new Strength for Enlarge, the Hit Dice budget left for Sleep, the hit points left for Snake
    Charm, the percent chance to dispel for Dispel Magic. }
  spellAmount: Byte;
  { Spell scratch: the exceptional Strength for Enlarge, the Hit Dice cost of the next Sleep target, the caster level of
    the effect or cloud Dispel Magic tries. }
  spellCost: Byte;

{ Equipment weight, and the first-run setup that writes and reads the configuration file. }
var
  { Total weight of the equipped items, summed by RecalcStats. It is the floor for the encumbrance in a branch of
    RecalcStats that never runs. }
  equippedWeight: Word;
  { The new top of the heap's free list in Tandy mode, 16 KB lower, so the heap stays clear of the Tandy screen memory;
    the free-list record is moved there. }
  savedTop: Types.PFreeRec;
  { Last key or configuration letter read at startup: ReadDigit's key, then the adapter, sound and full-introduction
    letters read back from CURSE.CFG. }
  curKey: Char;
  { The number picked on a first-run setup question, 1..3, for the graphics adapter and then the sound. }
  digitChoice: Byte;
  { CURSE.CFG: written on the first run (adapter, sound, save path, introduction), then read at every start. }
  cfgFile: Text;
  { Reserved, never read: the bytes after cfgFile, before writeProtErr. }
  cfgFileTail: array[0..127] of Byte;
  { IOResult of creating CURSE.CFG; nonzero means the disk is write-protected and the game stops. }
  writeProtErr: Byte;
  { Loop index of the first-run setup's upper-casing of savePath. }
  spIndex: Byte;
  { The save path typed on the first run; the default replaces it when it has no valid drive, and it ends in a backslash
    when written to CURSE.CFG. }
  savePath: String[80];
  { The program's file name from splitting its path; never read. }
  fsName: String[8];
  { The program's extension from splitting its path; never read. }
  fsExt: String[4];
  { The default save path offered on the first run: the game disk directory plus SAVE. }
  defaultPath: String[79];

{ Where the game's files are found, and the drive named when a disk must be inserted. }
var
  { Directory searched first for game files: the program's own directory at startup. OpenWithRetry swaps it with cfgDir2
    when a file is found only there. }
  cfgDir1: string[79];
  { Directory searched second for game files: the other floppy drive when the game runs from A or B, otherwise the
    program's directory. }
  cfgDir2: string[79];
  { Drive letter named in insert-disk prompts, the first letter of cfgDir2 at startup. }
  driveLetter: Char;

{ Session settings and script state: the GBVM banks, the script entry points, the interface mode and the player's
  display options; then video: the BIOS register block and the active display mode and pages. }
var
  { Points at the sound driver's forced-exit countdown, which its timer interrupt counts down. Sound command 15 arms it
    with 5000 ticks; when the count runs out the driver resets the video, prints its message and ends the program.
    SoundDrv's initialization aims it at the counter and clears the count. }
  timeoutPtr: ^Word;
  { Set when the fourth line of the configuration file is F. Introduction shows only the first title picture when it is
    clear and the rest of the title sequence when it is set. }
  fullIntro: Boolean;
  { The GBVM bank holding the game's global script state: the 3D-view flag, the clock, the anti-magic word, the stored
    game speed and picture options, and the other values scripts share across areas. Allocated at startup, cleared by
    game setup and reset, and saved with the game. }
  zone0: Types.PGbvmBank0;
  { The GBVM bank holding the current area's state: the rest-interruption interval and chance, the picture being shown,
    the search flags, the party size and the other per-area values scripts read and write. Saved with the game. }
  zone1: Types.PGbvmBank1;
  { A GBVM bank that scripts read and write through the general GBVM access. Allocated at startup, cleared by game setup
    and reset, and saved with the game. }
  zone2: Types.PGbvmBank2;
  { The GBVM bank holding the area's loaded ECL script, indexed by script address. LoadEclScript copies the script from
    its archive block into it, the interpreter fetches opcodes and operands from it at eclIp, and it is saved with the
    game. }
  scriptCode: Types.PGbvmBank3;
  { Game speed, 0 fastest to 9 slowest, changed from the camp speed menu and the combat speed prompt; 4 by default and
    saved with the game. It scales the per-character message delay, the pause after messages and the combat and ending
    animation timing. The demo and a failed copy-protection answer set it to 9. }
  gameDelay: Byte;
  { Script entry addresses set by the area's setup script: 1 runs before each step, 2 after a step and while searching,
    3 before camping, 4 when a rest is interrupted, 5 when the area loads. }
  vmRun: array[1..5] of Word;
  { The script instruction pointer: the address in scriptCode of the next byte the interpreter reads. Game setup, reset
    and each newly loaded script start it at the beginning of the script bank; GOTO, GOSUB and RETURN reload it. }
  eclIp: Word;
  { Reserved, never read. Sits between the script instruction pointer and the interface mode. }
  eclIpTail: array[0..3] of Byte;
  { What the main screen is showing, which decides how menus, redraws and messages behave: 0 the character screens, 1 a
    shop or temple, 2 camping, 3 the overland map, 4 the 3D view, 5 combat, 6 the treasure screen, 7 the ending. Game
    setup and reset start it at 4. Saved with the game. }
  ifcState: Byte;
  { The interface mode before the most recent switch: set when a script toggles between the 3D view and the overland map
    and at the end of each step. The step loop compares it with ifcState to decide whether the view needs redrawing and
    whether the area's map is entered fresh. Saved with the game. }
  prevIfcState: Byte;
  { Set while the demo plays: ReadGameKey polls the keyboard instead of waiting, prompts that wait for Enter or Escape
    return at once, and the game loop runs the demo script and then removes the party. }
  demoMode: Boolean;
  { Reserved, never read. Sits between the demo flag and the picture option. }
  demoModeTail: Byte;
  { The camp menu's Pics option, nonzero for on; 1 by default and saved with the game. }
  picsOn: Byte;
  { The camp menu's Animation option, nonzero for on; 1 by default and saved with the game. When it is off, pictures
    load only their first frame and the loading message is not shown. }
  animOn: Byte;
  { Nothing sets it, so it stays zero. DisplayMonster skips the close-up picture while the encounter menu is up when it
    is zero. }
  monsterPics: Byte;
  { The developer debug log switch, toggled by Ctrl-D in developer mode. While it is set, the interpreter writes each
    opcode's name to the debug file, Ctrl-Z logs every creature's effects, and the status line shows an asterisk. }
  debugTraceEnabled: Boolean;
  { Set when a saved game is loaded; game setup and reset clear it, and the game loop clears it once the restored area
    is on screen. While it is set, the game loop keeps the script that came with the save instead of loading it again,
    script setup keeps the saved script flags, and the view is redrawn in place. }
  loadedSavedGame: Boolean;
  { Rest steps since the last interruption roll. Each rest step counts it up; when it reaches the area's interruption
    interval it starts again from zero and the interruption chance is rolled. }
  restTicks: Word;
  { Head picture of the portrait shown in the view window, kept so the portrait can be redrawn when a shop or temple
    screen is restored. }
  portraitHeadId: Byte;
  { Body picture of the portrait shown in the view window, kept with portraitHeadId for redrawing it. }
  portraitBodyId: Byte;
  { Set once the whole party is dead or a PROGRAM command halts the game. It stops the interpreter and the step loop and
    suppresses the map redraw; the step loop clears it when it gives up control. }
  partyDefeated: Boolean;
  { Set while a new or imported character is trained silently up to its starting levels: TrainingMenu then picks the
    training itself and skips its prompts and messages. }
  autoTraining: Boolean;
  { Turns on the per-character typing delay in message windows, game speed times three milliseconds per character. On by
    default; combat turns it off when it starts and back on when it ends, and some script commands set it while they
    print and clear it afterwards. }
  typingDelayOn: Boolean;
  { Register block for the BIOS video calls: setting the mode, selecting the EGA page, the palette, the cursor and
    character output in text-style messages, and single pixels in the ending. }
  videoRegs: Types.TRegisters;
  { Video segment of the EGA page on display, recorded when SetupEgaCurrentPage selects it. }
  egaCurPage: Word;
  { Video segment of the EGA page that drawing goes to; FillRectEga fills rectangles there. }
  egaOtherPage: Word;
  { Number of the EGA page that drawing goes to; FillRectEga points egaOtherPage at another page while it fills and then
    back at this one. }
  egaPageNumber: Byte;
  { Number of the EGA page on display, 0 from startup. }
  egaShownPage: Byte;
  { BIOS video mode to return to: the mode before the last SetVideoMode call, or the DOS mode found at startup.
    RestoreVideoMode and ExitGame return to it. }
  savedVideoMode: Byte;
  { BIOS video mode most recently set by SetVideoMode, or the DOS mode found at startup. }
  curVideoMode: Byte;
  { The graphics adapter chosen in the configuration file: 0 CGA, 1 EGA, 2 Tandy. The drawing routines pick their CGA,
    EGA or Tandy path from it. }
  displayMode: Byte;

{ The off-screen view: its image and save-under buffers, the dirty-span tables that FlushView copies by, the scanline
  address tables of each display mode, and the graphics setup flag. }
var
  { The off-screen image of the view window, used in every display mode: the 3D view, the combat arena, pictures and
    icons are drawn into it, and FlushView copies its changed rows to the screen. }
  viewBuffer: Types.PImgBuf;
  { Scratch image that BlitTileClipped fills with the pixels a masked sprite covers, so an animation can put the
    background back after each frame. }
  saveUnder: Types.PImgBuf;
  { Reserved, never read. Sits between the save-under image pointer and the dirty-span tables. }
  saveUnderTail: array[0..15] of Byte;
  { Nonzero for each scanline of the 3D view that a blitter drew into since the last FlushView, which copies the marked
    scanlines to the screen and clears the marks. One slot per view scanline, 21 character rows of 8. }
  spanActive: array[0..167] of Byte;
  { For each view scanline, the byte offset into the screen scanline where its dirty span begins; a blit that lowers
    spanFirstOfs sets it too, and FlushView adds it to the scanline's video address. }
  spanScreenOfs: array[0..167] of Word;
  { For each view scanline, the lowest offset into the view buffer's pixel data written since the last flush. FlushView
    copies from here and resets it to $FFFF, so the next write always lowers it. }
  spanFirstOfs: array[0..167] of Word;
  { For each view scanline, the highest offset into the view buffer's pixel data written since the last flush. FlushView
    copies through here and resets it to 0, so the next write always raises it. }
  spanLastOfs: array[0..167] of Word;
  { Reserved, never read: follows the dirty-span tables and precedes the scanline address tables. }
  spanTail: array[0..671] of Byte;
  { Video segment of each CGA scanline, built at startup for the two interleaved banks. }
  cgaRowSeg: array[0..199] of Word;
  { Offset of each scanline within the EGA video segment, built at startup. }
  fbRowOfs: array[0..199] of Word;
  { Video segment of each Tandy scanline, built at startup for the four interleaved banks. }
  tandyRowSeg: array[0..199] of Word;
  { Set by game setup and reset; never read. }
  graphicsInitFlag: Boolean;

{ Sound: the device chosen, the mode to come back to, and whether the driver is installed. }
var
  { The sound device chosen in the configuration file, as a C_Sound value: speaker, Tandy, or off. Ctrl-S switches it
    off and back; while it is off the sound commands do nothing. }
  soundMode: Byte;
  { The sound mode to come back to: StartSound records it, Ctrl-S keeps the mode it turns off, and ExitGame restores it
    before shutting the driver down. }
  soundPrev: Byte;
  { Set while the sound driver is installed. StartSound sets it and the shutdown command clears it; code that loads
    overlays shuts the driver down around the load and restarts it if it was running. }
  soundActive: Boolean;

{ Disk state, the base item table, the current character and party list, the text font and cursor, the symbol, tile and
  icon images, and the combat arena: its slots, creature grid, bodies and target list. }
var
  { Number of the game disk the current data comes from: it picks the archive names and the insert-disk prompt.
    PushState switches it for a load and PopState restores it. Saved with the game. }
  diskIndex: Byte;
  { The disk number PushState saves for PopState to restore. }
  savedDiskIndex: Byte;
  { Where saved games and characters go, read from the configuration file: a drive and directory ending in a backslash.
    Drives below C get insert-the-save-disk prompts. }
  savedGamePath: String;
  { #1 while a saved game's monster records are loaded, #0 otherwise: OpenWithRetry then returns a missing file instead
    of asking for a disk. Reset clears it. }
  suppressDiskPrompt: Char;
  { Set when SaveGame finishes; cleared when a rest ends and when the party menu runs anything other than save or exit.
    Quitting with it clear asks whether to quit without saving, and the out-of-memory handler repeats the save menu
    until it is set. EffColdVulnerable reads it where its fire counterpart reads the save result. }
  recentlySaved: Byte;
  { Holds a DAX block's compressed data while LoadDax reads and decompresses it; freed when the block is done. }
  diskTransferBuffer: Types.PByteArr;
  { Base properties of each item type, indexed by item type: equip slot, hands, damage dice, rate of fire, range, class
    mask and flags. Startup reads it from ITEMS, which fills the first 128 entries; the last entry stays zero. }
  baseItems: array[0..128] of Types.TBaseItemRec;
  { The selected creature: the character menus act on it, and in combat it is the creature taking its turn or the
    attacker whose effects are being checked. }
  curChar: Types.PCreature;
  { Head of the party's character list, linked through each record's next pointer; nil when there is no party. }
  partyHead: Types.PCreature;
  { The copy of a thrown weapon put into the treasure list when its last unit is thrown; combat start clears it. }
  lastMissileItem: Types.PItem;
  { File variable DeleteIfPresent uses to erase a file. }
  scratchFile: file;
  { Number of bytes startup read from ITEMS; nothing checks it. }
  itemsRead: Word;
  { The 8x8 font, eight bytes per glyph, loaded from the font archive by LoadGameFont; RenderChar copies each glyph from
    it. Allocated at startup. }
  gameFont: Types.PFontArr;
  { The eight pixel rows of the character being drawn, one bit per pixel. RenderChar copies them out of gameFont before
    each call into the assembly glyph renderers, which test them row by row. }
  glyphBits: array[0..7] of Byte;
  { Text cursor column, in character cells: where the next message-window character goes. }
  curCol: Byte;
  { Text cursor row, in character cells: where the next message-window character goes. }
  curRow: Byte;
  { Reserved, never read. Sits between the text cursor and the symbol-set pointers. }
  curRowTail: array[0..19] of Byte;
  { The five 8x8 symbol sets that Load8x8Set fills. Put8x8Sym picks the set from the symbol number: 1..45 set 0, 46..115
    set 1, 116..185 set 2, 186..255 set 3, 256..295 set 4. GameInit loads sets 0 and 4; the 3D view loads sets 1 to 3
    with the current wall sets. A set left nil draws nothing. }
  symbolSetPtrs: array[0..4] of Types.PImgBuf;
  { One 8x8 cell image. Put8x8Sym copies a symbol into it to draw straight to the screen, and the overland map cursor
    grabs the screen cell under the cursor into it so RestoreCursorBackground can put it back. }
  sym8x8Buf: Types.PImgBuf;
  { The 24x24 tile sets Copy2DTile draws from. Set 0 is allocated at startup with room for 48 tiles and filled by
    Load24x24Set; tile numbers above 127 draw from set 1, which nothing loads, so it stays nil. }
  tileSet: array[0..1] of Types.PImgBuf;
  { Combat icons, a ready frame and an action frame each, by icon slot: slots 0..10 are combatants by order number
    (party members, then script-loaded monsters from slot 8), slot 11 holds a character's head while LoadCharIconAnim
    merges it onto the body, slot 12 is the icon editor's working copy, and slots 13..24 hold the combat sprites.
    MapTiles and GameInit treat the run as 26 slots; the last, the combat cursor sprite, lies over iconTail and
    arenaHead. }
  iconImages: array[0..24, 0..1] of Types.PImgBuf;
  { Most of icon slot 25's frame pointers (the combat cursor sprite), which MapTiles loads through its 26-slot view of
    iconImages; the slot's last three bytes are arenaHead. GameInit clears it with the icon slots. }
  iconTail: array[0..4] of Byte;
  { Arena slot 0's cell coordinates and auxiliary byte. Slot 0 never holds a creature, and these bytes also end icon
    slot 25's frame pointers (see iconImages); arenaCount, which follows, takes the place of its size byte. }
  arenaHead: Types.TArenaLocationHead;
  { One more than the number of arena slots in use: CombatSt sets it to 1 and counts up for each slot it fills, and the
    arena loops run from 1 to it. It also reads as arena slot 0's size. }
  arenaCount: Byte;
  { Arena slots 1..71, one per combatant by combat slot: its arena cell, its slot number and its icon size (0 when it is
    off the map). }
  arenaSlots: array[1..71] of Types.TArenaLoc;
  { Slot 72's cell and auxiliary byte, past the slots the code fills; its size byte would be the first entry of gridX. }
  arenaSlotsTail: Types.TArenaLocationHead;
  { Each arena slot's column relative to the combat view's upper-left cell, by combat slot; CalcGridDeltas sets it from
    the arena slot and the view corner. Negative or above 6 means the creature is off the view. }
  gridX: array[0..71] of ShortInt;
  { Each arena slot's row relative to the combat view's upper-left cell, by combat slot; CalcGridDeltas sets it from the
    arena slot and the view corner. Negative or above 6 means the creature is off the view. }
  gridY: array[0..71] of ShortInt;
  { Reserved, never read. It lies between gridY and the arena's creature grid. }
  combatGridLeadingCell: Byte;
  { The combat slot occupying each arena cell, 0 for an empty cell, by row and column; BuildArenaArrays clears it and
    stamps each placed creature's footprint. CbtMap reads it as 25 rows of 50 cells, so the last four cells of the
    bottom row share storage with slot 0 of combatCreatures, which never holds a creature. }
  combatGridCells: Types.TCombatGridStorage;
  { The creature in each combat slot; slot 0 stays empty. CombatSt fills the slots from 1 in party-list order as it
    places creatures. }
  combatCreatures: array[0..72] of Types.PCreature;
  { Bodies of party-side creatures that went down in combat, entries 1..downedCount: the creature (cleared when it moves
    again), its arena cell and the terrain its corpse covers, which comes back when the creature gets up and moves.
    Healers and the aim cursor search it to find a body by cell. }
  downedCharacters: array[1..8] of Types.TDownedRec;
  { Number of entries in downedCharacters; CombatStart clears it and each body recorded adds one. }
  downedCount: Byte;
  { Heap block holding the current combat's arena: the terrain of each cell, the combat view's upper-left cell and the
    cursor state. CombatSt allocates it when a battle begins. }
  combatArena: Types.PArena;
  { Number of entries BuildTargetList left in targetList. Area target selection trims it to the creatures it keeps, and
    spell casting copies it to spellTargetCount. }
  targetCount: Byte;
  { Creatures BuildTargetList found from a position within range, entries 1..targetCount sorted nearest first: combat
    slot, doubled distance and the direction toward it. }
  targetList: array[1..72] of Types.TTargetRec;

{ The treasure pool, the team counts, and the values that the effect triggers adjust while an attack, a save or a spell
  resolves. }
var
  { The treasure pool's money by money type: copper, silver, electrum, gold and platinum coins, then gems and jewelry.
    Combat spoils and pooled or dropped money land here; ShareMoney divides it and TakeMoney hands it out. }
  treasureMoney: Types.TMoney;
  { Head of the treasure item list: the loot after combat, including thrown weapons that ran out, and in a shop the
    stock offered for sale. }
  treasureItems: Types.PItem;
  { Creatures still able to fight on each side, by team: 0 the party's side, 1 the hostile side. CountTeams recounts it
    and a creature that goes down takes one off; combat ends when either side reaches 0. }
  teamCount: array[0..1] of Byte;
  { The saving throw in progress: a d20 plus the creature's save bonus and the modifier. RollSavingThrow sets it, the
    save-trigger effect handlers raise or lower it (100 forces a success), and the save succeeds when it reaches the
    creature's save value. A natural 1 or 20 decides the save without the handlers. }
  saveRoll: Byte;
  { The effect being applied while AddEffectWithMessage runs the effect-check triggers; a handler that grants immunity
    clears it, and the effect is not applied when it comes back 0. }
  effectCheck: Byte;
  { Hit points of damage being dealt by the current attack, spell or effect. The damage triggers adjust it before it is
    applied (halved, doubled or cleared by resistances and immunities). }
  damage: Byte;
  { Kind of the damage or effect being dealt, as bits: 1 fire, 2 cold, 4 electricity, 8 magic, 16 acid, 32 breath
    weapon, 64 debilitating magic. Damage messages name it, and resistance and immunity handlers test it; 0 means a
    plain weapon attack. }
  elementMask: Byte;
  { Movement or attack rate being computed, which the rate triggers adjust: haste doubles it, slow halves it and an
    immobile creature's movement drops to 0. CalcCreatureMovement returns it as the movement; the attack routines turn
    it into attacks with AttacksFromRate. }
  movementAttacks: Byte;
  { The spell whose handler is running, 0 between casts; set by the cast routines around the call. }
  spellId: Byte;
  { Dice count of the last RollDamageDice roll. Fire-immunity handlers take 2 points off per die but leave at least 1
    per die. }
  damageDice: Byte;

{ Effect-trigger switches, the attack roll and hits, morale, the combat target and the saving throw in progress. }
var
  { Set while CalcCreatureMovement runs the rate triggers, so EffImmobile zeroes the movement rate but not the attack
    rate. }
  computingMove: Byte;
  { Set by a defender's effect (invisibility, blink, dust of disappearance) to make the attacker unable to target it;
    CanTarget clears it, runs the triggers and reads the result. }
  suppressTargeting: Byte;
  { Set while code removes effects deliberately (cures, the end of slow poison) so removal handlers neither renew the
    effect nor kill an animated creature. }
  effectLock: Byte;
  { Set while the current spell affects several targets; mirror images do not absorb such a spell. }
  multiTarget: Byte;
  { Set when the inventory screen must redraw its title and headings, such as after an item's alignment curse strikes;
    the inventory loop clears it. }
  invRedraw: Byte;
  { The attack roll in progress: a d20, with 20 read as 100. The attack triggers raise or lower it, and any negative
    value means a miss. AttackHug needs 18 or more. }
  attackRoll: ShortInt;
  { Hits landed in the current attack by attack phase, counted by MakeAttack. AttackEngulf acts when the first phase's
    count is 2 and otherwise does nothing, and a defender that avoids an attack takes one first-phase hit back. }
  phaseHits: array[1..2] of Byte;
  { The morale value CheckMorale tests, as a percentage: first from the creature's morale rating, then from the hostile
    side's remaining hit points. Morale triggers adjust it (100 means never flee). }
  combatMorale: Byte;
  { Creature that the claw-rake, bite-and-hold and hug attacks act on, and the opponent the effect handlers look at
    while they run. }
  combatTarget: Types.PCreature;
  { Saving-throw category of the roll in progress: 0 paralysis, poison and death magic; 1 petrification and polymorph; 2
    rod, staff and wand; 3 breath weapon; 4 spell. RollSavingThrow sets it for the save-trigger handlers. }
  saveType: Byte;
  { Outcome of the last saving throw, True when it was made; RollSavingThrow returns it. }
  saveResult: Boolean;

{ The effect handler table; the 3D view's wall sets, map, colors and pictures and the party's position; the picture
  window's animation, portraits and big picture. }
var
  { Effect handlers by effect ID. EffHndlr.InitEffectHandlers fills it at startup and Magic.InitSpellFns replaces the
    monster gaze, breath and spit entries; FxEngine.CallEffectHandler dispatches through it. The initializer's entry 147
    is overrideEffectHandler. }
  effectHandlers: array[1..146] of Types.TEffectHandler;
  { Handler that FxEngine.CallEffectHandler calls in place of the table while overrideFlag is set. InitEffectHandlers
    stores EffGrantItemEffect here as entry 147; it adds or removes the effect an item grants and clears overrideFlag. }
  overrideEffectHandler: Types.TEffectHandler;
  { Reserved, never read; sits between the override handler and wallGfx. }
  overrideEffectHandlerTail: array[0..11] of Byte;
  { Heap buffer of the loaded wall sets for the 3D view, as rows of 8x8 symbol IDs. GameInit allocates it,
    View3D.LoadWallSet copies each WALLDEF block in and shifts its symbol IDs to the slot's symbol set, and the view
    drawing reads it. }
  wallGfx: Types.PWallGfx;
  { Heap buffer for the current 16x16 map from the GEO file: the two wall planes (a nibble per side), the cell-event
    plane and the two-bit side features. GameInit allocates it, View3D.Load3DMap fills it, the 3D view and automap read
    it, and Explore edits the features when a door is opened. }
  map3d: Types.PDungMap;
  { Color of the upper band of the 3D view: the area's ceiling color when the party's cell has its indoor bit, its sky
    color otherwise. Light cyan marks open daytime sky, where the sun and north sky pictures are drawn. }
  skyCeilingColor: Byte;
  { Color of the one-line band at the horizon of the 3D view, drawn in CGA only; MapView.DisplayMapView picks it from
    the area's ceiling and floor selection. }
  ceilingBandColor: Byte;
  { Color of the two-line band just below the horizon of the 3D view; in CGA MapView.DisplayMapView picks it from the
    area's ceiling and floor selection. }
  midBandColor: Byte;
  { Color of the floor band that fills the lower part of the 3D view: picked from the area's wall selection in CGA, dark
    gray in the other display modes. }
  floorBandColor: Byte;
  { Set while the 3D view shows the overhead map instead of the corridor; A in the exploration menu toggles it where the
    area allows a map. Areas without map information, the start of a script picture and a game reset turn it off. }
  automapOn: Boolean;
  { The party's place on the map and the direction it faces, with the wall ahead and the event of its cell. }
  partyPos: Types.TPartyPosition;
  { Wall-set slots 1 to 3: the WALLDEF block each slot holds and the 8x8 symbol slot its glyphs went to, 65535 in both
    when the slot is empty. View3D.LoadWallSet records them, EclVm.EclLoadFiles empties a slot the area leaves unused,
    and SaveLoad saves them and reloads the named wall sets after a load. }
  wallDefinitions: array[1..3] of Types.TWallSetCacheSlot;
  { Sky picture drawn at the top of the 3D view when the party faces north under open daytime sky; loaded from the sky
    file by GameInit outside CGA. }
  northSkyImage: Types.PImgBuf;
  { Sun picture drawn in the 3D view's sky by the hour of day when the party faces east, south or west under open
    daytime sky; loaded by GameInit outside CGA. }
  sunImage: Types.PImgBuf;
  { Horizon picture drawn across the 3D view's background outside CGA; loaded by GameInit. }
  horizonImage: Types.PImgBuf;
  { The animation in the picture window: up to eight frames from a PIC, FINAL or SPRIT block, the number loaded, and the
    current frame, which MenuHorizontal and the script VM cycle from 1 to the count. Portrait.LoadAnimation fills it and
    Portrait.FreeAnimation releases the frames and forgets the block. }
  animData: Types.TAnimRec;
  { The character portrait: entry 1 the head, entry 2 the body. Portrait.LoadPortraitBufs loads each part and skips the
    reload when the same file block is asked for again; both are freed when combat starts or the party moves on. }
  portraits: array[1..2] of Types.TPortSlot;
  { Archive name of the block in animData, such as PIC or SPRIT; empty when no animation is loaded.
    Portrait.LoadAnimation skips the load when the name and block both match. }
  picArchiveName: String[8];
  { picArchiveName as it was when the party made camp, so the camp menu can reload a PIC animation when it closes; the
    script VM clears it on a script switch. }
  savedPicArchiveName: String[8];
  { Block number of the animation in animData, 255 when none. The village picture also disables the big picture redraw
    and the overland cursor blink. }
  loadedPicId: Byte;
  { loadedPicId as it was when the party made camp, reloaded with savedPicArchiveName when the camp menu closes; 255
    when there is nothing to restore. }
  savedPicId: Byte;
  { The loaded BIGPIC picture that Portrait.DisplayBigPic draws over the picture area; freed when combat starts. }
  bigPicImage: Types.PImgBuf;
  { BIGPIC block in bigPicImage, 255 when none; Portrait.LoadBigPic skips a reload of the same block. The overland map's
    cursor blinks only while the overland big picture is shown. }
  bigPicId: Byte;

{ Menu state that MenuVertical and MenuHorizontal keep between calls, and the horizontal menu's timeout. }
var
  { Index of the first list entry on the vertical menu's page, counting from 0. MenuVertical keeps it between calls and
    pages it by whole screens, keeping it from going below 0. }
  verticalMenuTop: Integer;
  { Option highlighted in the horizontal menu, counting from 1. MenuHorizontal keeps it between calls, so a menu opens
    where the last one left off; callers preset it to pick the default, and it falls back to 1 when it is past the new
    menu's options. }
  menuChoice: Byte;
  { Set by MenuHorizontal when the key that closed the menu is a movement key: an extended key, or a digit read as a
    keypad direction where the menu allows it. The combat command and aiming menus act on the returned letter only when
    it is clear. }
  menuExtendedKey: Boolean;
  { Time in hundredths of a second after which MenuHorizontal answers itself with menuDefaultKey; 0 means wait for the
    player. The main program sets it around the title menu so the demo starts on its own. }
  menuTimeout: LongInt;
  { Key that MenuHorizontal returns when menuTimeout runs out; the title menu uses D for Play Demo. }
  menuDefaultKey: Char;

{ Spell casting: the scroll being read, the spell handlers, the targets and aim point, and the clouds on the combat map;
  then the treasure pile's coin flag. }
var
  { The scroll being read. Collecting the current character's scroll spells steps it through the inventory, Scribe sets
    it to the chosen spell's scroll, and using a readable item points it at that item. }
  currentScroll: Types.PItem;
  { Spell handlers by spell number, 1 to 100, installed by Magic.InitSpellFns. castTargets holds the target picker the
    casting code calls: Magic.NoncombatCastTargetMenu outside combat, CbtActs.SelectCombatTargets while combat lasts. }
  spellHandlers: Types.TSpellHandlers;
  { Number of creatures in spellTargets for the spell being cast; 0 when the target picker found none or was
    cancelled. }
  spellTargetCount: Byte;
  { Creatures the current spell affects, entries 1 to spellTargetCount. The target pickers fill it, from the player's
    choice or the area list Pathing.BuildTargetList builds, and each spell handler walks it. }
  spellTargets: array[1..72] of Types.PCreature;
  { Character last picked as the target of a spell cast outside combat, offered as the default the next time; the caster
    stands in when it is empty. }
  lastSpellTarget: Types.PCreature;
  { Combat-map column the current spell is aimed at: the chosen creature's or cell's position. Bolts are animated toward
    it and clouds are placed around it. }
  spellTargetX: ShortInt;
  { Combat-map row the current spell is aimed at, paired with spellTargetX. }
  spellTargetY: ShortInt;
  { Head of the list of stinking clouds on the combat map: one heap node per casting, holding its caster, the cells it
    covers and the terrain under each. Magic adds a node per casting, EffHndlr.EffClearStinkingCloud unlinks it when the
    effect ends, CombatStart empties the list, and Combat.CombatDoneCleanup frees what is left. }
  stinkHead: Types.PCloudNode;
  { Head of the list of cloudkills on the combat map, with the same node layout as the stinking cloud list. Magic adds a
    node per casting, EffHndlr.EffClearCloudkill unlinks it when the effect ends, CombatStart empties the list, and
    Combat.CombatDoneCleanup frees what is left. }
  cloudkillHead: Types.PCloudNode;
  { True while the spell being cast comes from an item's own power rather than a memorized spell: it casts at level 6,
    isn't announced as cast, and doesn't use up a memorized spell. ViewChar.UseItem sets it; Magic.InitSpellFns clears
    it. }
  usingItem: Boolean;
  { True while the treasure pile holds coins. Money.PoolMoney sets it and sharing or taking money works it out again;
    shops and temples clear it with the pile. No routine tests it. }
  treasureMoneyFlag: Boolean;

{ Camp rest: the time left, the spell preparation and healing timers, and the message placement while resting. }
var
  { Rest time left, as a clock: minutes, tens of minutes, hours and days in entries 1 to 4, with months in entry 5
    folded into days and capped at 99. The camp menu sets it to the longest spell preparation, the player adjusts it,
    and resting counts it down. }
  restTime: Types.TClock;
  { Per party member, in party order: rest steps of five minutes until that member's current scribing or memorizing
    finishes, three steps per spell level. Resting counts them down and moves each member on to the next pending
    spell. }
  prepTimers: array[1..8] of Byte;
  { Rest steps since the party last healed. At 288, a day of rest, each member regains a hit point and the count starts
    over; making camp resets it. }
  healTicks: Word;
  { Set while GameTime.CampRest runs, so messages printed during the rest start a row lower and leave the rest-time line
    in place. }
  noBorder: Byte;

{ Picture area redraw. }
var
  { Set when the picture area has been drawn over; outside the 3D view MapView.DisplayMapView then redraws the big
    picture, and it clears the flag after every call. A village picture clears it too. }
  mapRedrawPending: Byte;

{ Magic item effects. }
var
  { Set just before FxEngine.CallEffectHandler is asked to apply or remove a magic item's own effect, when an item is
    equipped or taken off or a curse is lifted; the call then goes to overrideEffectHandler, which clears the flag. }
  overrideFlag: Byte;

{ Character import. }
var
  { Which character format the add-character menu reads: 0 this game's own, 1 and 2 the two imported formats it offers.
    It picks the file pattern, name positions and record size the loader uses and how the record is converted; the
    add-character menu sets it, and loading or saving resets it to 0. }
  importMode: ShortInt;

{ Character training switches, and the ways past a locked door. }
var
  { Ends the automatic training loops that bring a new or imported character up to its levels: CharGen.TrainingMenu sets
    it when there is nothing left to train. }
  charMenuDone: Byte;
  { Free-training switch, toggled by J in the main menu when the second command-line parameter is the developer keyword.
    While on, training ignores experience, cost, the character's status and which classes the hall teaches. }
  stingMode: Byte;
  { Which ways past the locked door ahead are still offered: entry 0 bash, 1 pick, 2 knock. Each step and each game
    reset turns all three on; a bash without a member strong enough, or any pick attempt, turns its entry off. }
  lockOptions: array[0..2] of Boolean;

{ Combat round state: the ally attack flag, the round counter and target slots, the attack counts, the hostiles' hit
  points, quick magic, the effect sprite, and the range, redraw and visibility flags. }
var
  { Set when the player confirms an attack on an ally; the script-visible flag in GBVM zone 1 is set alongside it and is
    the one scripts test. No routine reads this copy. }
  attackedAllies: Byte;
  { Combat rounds completed, counting from 0 at CombatStart. Combat ends when it reaches the round limit in
    combatTargetSlots, and several monster abilities check it to act only on the first round or from the fourth on. }
  roundCounter: Byte;
  { Candidate target slots into combatCreatures from entry 1, used by the attack and guard code. Entry 0 is the round
    limit: CombatStart sets it to 15 and each attack moves it to 15 rounds past the current one, so combat ends after 15
    rounds without an attack. }
  combatTargetSlots: array[0..71] of Byte;
  { Attacks made in the current attack by attack phase. RollAttacks clears and counts phases 1 and 2, and MakeAttack
    takes the first phase's count from a thrown weapon's quantity. Phase 0 counts only when the automatic hit on a
    helpless defender finds no attacks left in either phase, and RollAttacks never clears it. }
  phaseAttacks: array[0..2] of Byte;
  { Enabled hostiles' current hit points as a percentage of their total maximum, rounded down to a multiple of five.
    CbtActs.UpdateHostileHpPercent sets it and the monsters' morale checks compare against it. }
  hostileHpPct: Byte;
  { Spell switch for automatic fighting, toggled by Alt-M in the combat menu or during a quick fight: while on, party
    members fighting on their own may cast spells as monsters do. CombatStart turns it off. }
  quickMagic: Boolean;
  { Scratch flag that combat code hands to calls whose output it doesn't use: the extended-key flag of its menus,
    MakeAttack's done result, and the result of EndActions. No routine reads it back. }
  combatMenuExtendedKey: Boolean;
  { Reserved, never read; sits between combatMenuExtendedKey and combatEffectSprite. }
  combatMenuExtendedKeyTail: array[0..3] of Byte;
  { Four-frame sprite buffer for missiles and spell effects in combat. CombatStart allocates it, CharHlp.CopyIconFacing
    copies frames from the combat tile set into it, mirrored where needed, the missile and bolt animations draw it over
    the arena, and Combat.CombatDoneCleanup frees it. }
  combatEffectSprite: Types.PImgBuf;
  { Set during a monster's combat turn when its target is within weapon reach (or an area target can be hit), so it
    attacks instead of moving; a ranged attack replaces it with whether ammunition was found. AiMoveStep also reads it
    to keep a monster's movement shown on the map. }
  inRange: Boolean;
  { Asks CombatPrintCreatureInfo to redraw the creature panel on the right of the combat screen; set when a turn starts
    or a creature changes, cleared by the redraw. }
  combatRedraw: Boolean;
  { Set while combat movement and attacks are drawn on the arena map: set when the acting creature is a party member or
    on screen, so hidden monsters move without scrolling the view. }
  mapVisible: Boolean;

{ The script VM: the CGA view color selectors, the GBVM values, the GOSUB stack and compare flags, the command being
  decoded and its arguments, the encounter display, the character removal switches and the shop session flag. }
var
  { Wall color selector that scripts set through GBVM address $C059; the CGA 3D view maps it to its third color. Game
    start sets $DB, a new script $41. }
  wallColorSel: Byte;
  { Ceiling and floor color selector that scripts set through GBVM address $C05F; the CGA 3D view maps it to its first
    two colors. Game start sets $E8, a new script 9. }
  ceilFloorColorSel: Byte;
  { Value scripts read at GBVM address $FB. Writes to that address are ignored and nothing else sets it, so scripts read
    zero. }
  scriptResultFb: Word;
  { Value scripts read at GBVM address $FC. Writes to that address are ignored and nothing else sets it, so scripts read
    zero. }
  scriptResultFc: Word;
  { Value scripts read at GBVM address $B1. Writes to that address are ignored and nothing else sets it, so scripts read
    zero. }
  scriptResultB1: Word;
  { Top of the script GOSUB return stack, a heap-allocated linked list of return addresses; nil when empty. RETURN pops
    it, EXIT frees it, and EclInit empties it. }
  scriptReturnStack: Types.PEclRet;
  { Working pointer for pushing and popping the GOSUB return stack: the node below the top while a push or pop links the
    list. }
  prevScriptReturnStack: Types.PEclRet;
  { Result of the last script COMPARE or test: equal, not equal, less, greater, less or equal, greater or equal. The IF
    commands skip their next command when their flag is clear. }
  cmpFlags: array[0..5] of Boolean;
  { Opcode of the script command run before the current one, saved each step of CallEclScript; never read. }
  eclPrevOp: Byte;
  { Opcode of the script command being run, fetched each step of CallEclScript. Commands shared by several opcodes test
    it to tell them apart, and the debug trace prints its name. }
  scriptOpcode: Byte;
  { Reserved, never read; sits between scriptOpcode and encMonsterId. }
  scriptOpcodeTail: Byte;
  { Sprite animation of the current encounter's monster, from SETUP MONSTER and its variants; passed to DisplayMonster
    whenever the monster is redrawn at a new distance. }
  encMonsterId: Byte;
  { Close-up picture of the current encounter's monster, from SETUP MONSTER and its variants; DisplayMonster shows it
    when the monster reaches the party. }
  encMonsterPic: Byte;
  { Combat icon slot for the next monster group a script loads: starts at 8, after the party's slots, at each new script
    and encounter reset, and advances once per LOAD MONSTER and duel mirror copy. }
  iconAnimId: Byte;
  { Reserved, never read or written by name; lies between iconAnimId and the script argument tables. }
  iconAnimTail: array[0..129] of Byte;
  { Kind of each argument of the script command being decoded, from 1: 0 an immediate byte, 2 an immediate word, 1 or 3
    a GBVM address to read, $80 an inline string, $81 a string at a GBVM address. LoadEclVars fills it and GetEclVar
    interprets it. }
  varTypes: array[1..64] of Byte;
  { High byte of each argument of the script command being decoded, from 1; LoadEclVars fills it for word, address and
    string-address arguments. }
  varHi: array[1..64] of Byte;
  { Low byte of each argument of the script command being decoded, from 1; for an inline string it is the string's
    length. }
  varLo: array[1..64] of Byte;
  { Set by the target picker when a breath or gaze attack has an aim; a cone breath also clears it when the cone would
    catch a friend of the breather, which cancels the attack. }
  breathAim: Boolean;
  { Loop counter that several routines keep here instead of in a local: the color-remap and run-fill loops of picture
    drawing, freeing an animation's frames, the cure-effect loops, the race and class qualification loop, pruning
    duplicate targets along a spell's center ray, the 3x3 cell scan of a spell's area, and setting up a loaded
    character's combat colors. }
  sharedLoopIdx: ShortInt;
  { Decoded string arguments of the script command being run, numbered in the order the arguments appear; LoadEclVars
    fills one per string argument, converting inline strings and fetching those stored at GBVM addresses. }
  scriptStrings: array[1..20] of String;
  { Encounter display state that DisplayMonster keeps: the first byte is set once the monster's sprite is loaded, the
    second once its close-up has been shown. PICTURE sets the second and clearing the picture resets both. }
  encounterMonsterFlags: Types.TMonFlags;
  { Reserved, never read; sits between encounterMonsterFlags and scriptSoundEffect. }
  encounterMonsterFlagsTail: array[0..1] of Byte;
  { Sound that scripts choose by writing GBVM address $3DE; the script call that plays it gives the alternate effect for
    10 and the footstep for anything else. }
  scriptSoundEffect: Word;
  { Value scripts write at GBVM address $B8; kept but never read back. }
  scriptValueB8: Word;
  { Value scripts write at GBVM address $B9; kept but never read back. }
  scriptValueB9: Word;
  { Set when a script writes 0 to the current character's status word in zone 1; with dumpOnNameClear also set, a LOAD
    CHARACTER with bit 7 removes that character. EclInit and the removal clear it. }
  dumpOnStatusClear: Boolean;
  { Set when a script writes 0 to the start of the current character's name in zone 1; with dumpOnStatusClear also set,
    a LOAD CHARACTER with bit 7 removes that character. EclInit and the removal clear it. }
  dumpOnNameClear: Boolean;
  { Inside a shop or temple, makes a redraw of the noncombat screen draw the view frame. Entering sets it when the shop
    is outside the 3D view, draws the screen, then sets it for later redraws. }
  shopSession: Boolean;

{ Duels and the post-combat tally. }
var
  { Set when a script starts a duel, where the current character fights alone, optionally against a mirror copy. It
    changes the post-combat outcome and messages and keeps disabled party members off the arena as bodies; the combat
    command clears it afterwards. }
  duelFlag: Boolean;
  { Party members that get no share of the combat experience (disabled or animated); the post-combat tally counts them
    and divides the experience among the rest. }
  treasureCreatureCount: Byte;
  { Experience each party member earns from the last combat, worked out from the monsters, coins and magic items; the
    post-combat summary shows it. }
  experienceShare: LongInt;
  { Set by the post-combat tally when a party member is still standing (okay or animated); a fight without it was
    lost. }
  combatWon: Byte;

{ The current area script and the script display flags; then startup and debug state: the heap top, the debug log, the
  overland map cursor and the developer keyword. }
var
  { Script block of the current area, loaded from the ECL file: 1 for a new game, 82 for the demo, otherwise the area a
    script switched to. In areas 0 and 10 the 3D map does not wrap at its edges. }
  currentScriptId: Byte;
  { The party's search mode, saved while the after-step script entry runs with searching forced on, and restored
    afterwards. }
  searchBak: Byte;
  { Set by CLEAR BOX and cleared by EXIT and game start; never read. }
  boxCleared: Boolean;
  { Tested by PRINT RETURN, but nothing ever sets it, so both branches move the text cursor to the next row. }
  printRetFlag: Boolean;
  { Set while a script picture or encounter close-up is on screen; when it is set, clearing the picture or the next map
    refresh redraws the map cell, and script menus animate the picture. }
  eclGraphics: Boolean;
  { Set when the picture on screen is a plain picture rather than a portrait; together with eclGraphics it lets script
    menus animate it. }
  picDrawn: Boolean;
  { Makes EXIT redraw the view frame when set; nothing sets it, so it stays clear. }
  protShown: Boolean;
  { Set when an encounter's sprite is drawn in the 3D view; SPRITE OFF, clearing the picture and the map refresh redraw
    the cell to remove it. }
  spriteShown: Boolean;
  { Set once the main exploration menu has cleared the message area under the view; script printing, script menus and
    the encounter menu clear it so the next main menu wipes their text. }
  bottomMessageCleared: Boolean;
  { Asks for the 3D view to be redrawn with fresh wall and ceiling colors: set by a new script and when scripts change
    wallColorSel or ceilFloorColorSel, cleared by the map refresh. }
  redrawViewColors: Boolean;
  { Set when a script moves or turns the party; the next map refresh redraws the cell and clears it. }
  movedParty: Boolean;
  { Set once LOAD MONSTER has added monsters to the creature list; the COMBAT command starts a fight only when it is set
    or a duel is on. }
  monstersLoaded: Boolean;
  { Set when a script changes the sky colors in zone 0; the next map refresh redraws the cell and clears it. }
  redrawSky: Boolean;
  { Set while the encounter menu is up; with monster pictures turned off, DisplayMonster then skips the close-up. }
  inEncMenu: Boolean;
  { Portrait head of the encounter close-up last shown, from zone-1 word $7EE1; DisplayMonster skips showing the same
    close-up again. }
  picIdShown: Byte;
  { Set when LOAD CHARACTER names a party slot past the end of the party; the next script read of the current
    character's status returns 0 and clears it. }
  characterNotFound: Byte;
  { Set when a new area script takes over, so the exploration frame, roster and view still need drawing; whichever path
    draws them clears it. }
  charSelectActive: Byte;
  { Set after the game is won: training is then free and needs no gold. Game start and loading clear it. }
  victoryStart: Boolean;
  { The heap top recorded at boot in Tandy mode, after it is moved down below the Tandy video memory; never read. }
  tandyHeapTop: Types.PFreeRec;
  { Reserved, never read; sits between tandyHeapTop and debugFile. }
  tandyHeapTopTail: array[0..1] of Byte;
  { The developer debug log, debug.txt, opened and closed with Ctrl-D in developer mode; the script trace and the effect
    dump write to it, and quitting closes it while logging is on. }
  debugFile: Text;
  { Cleared at game start and when a game is loaded; nothing else uses it. }
  initFlag1: Boolean;
  { Cleared at game start and when a game is loaded; nothing else uses it. }
  initFlag2: Boolean;
  { Screen X of the overland map cursor, looked up from the cursor position the area keeps in zone 0. }
  cursorColumn: Integer;
  { Screen Y of the overland map cursor, looked up from the cursor position the area keeps in zone 0. }
  cursorRow: Integer;
  { The overland map cursor, a solid block one cell wide allocated at startup. Drawing it first saves the background
    under it in sym8x8Buf. }
  cursorImage: Types.PImgBuf;
  { Developer keyword, set at startup from the item name Wooden. Given as the second command-line parameter it skips the
    copy-protection question, allows the automap everywhere, lets the character menu toggle free training, and lets the
    combat cheat end a fight in victory. }
  commandText: String[20];

{ Keyboard state to restore on quitting. }
var
  { BIOS keyboard flags as they were at startup, before Num Lock is forced on; quitting restores them. }
  savedKbFlags: Byte;

implementation

end.
