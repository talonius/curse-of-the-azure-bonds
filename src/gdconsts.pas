{ Initialized data: the game's typed constants, in the order they sit in the data segment. A new section starts wherever
  the data needs a word boundary. Keep the order and the declared sizes: many readers run past the end of one table into
  the next, and no table grows to cover such a reader. }
unit GDConsts;

interface

uses Types;

{ Copy protection, temple services and the effects cleared after combat. }
const
  { The translation wheel's six rings of 36 characters. CopyProtection picks a ring and a position from the two runes
    and the path style it shows, and expects the character found there. }
  wheel: array[0..5] of String[36] = (
    'CWLNRTESSCEDCSHSISERRRNSHSSTSSNNHSHN',
    'LAASRDAIILIDSUGADAEEOEGRLSELIITESOIO',
    'LRUNIMMORIIGRRIUPTIIUELIMLHMIXACGRIL',
    'Z0LIOHEUVNODSGEOGXYWISIOCRARLRARRHOI',
    'AMTELRLUIYNAEOOITOUELRREREUIMADPPFAB',
    'ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890');
  { Effect IDs of the six diseases the temple's Cure Disease service removes. }
  cureDiseaseEffects: array[1..6] of Byte = (
    31, 34, 43, 44, 50, 57);
  { The temple's healing services as HealMenu lists them, with Exit last. }
  templeSpellNames: array[1..11] of Types.TStr40 = (
    'Cure Blindness',
    'Cure Disease',
    'Cure Light Wounds',
    'Cure Serious Wounds',
    'Cure Critical Wounds',
    'Heal',
    'Neutralize Poison',
    'Raise Dead',
    'Remove Curse',
    'Stone to Flesh',
    'Exit');
  { Effect IDs that end with a combat: PostCbt removes entries 1..19 from each creature in the combat list. Entry zero
    is not read. }
  postCombatRemovalEffects: array[0..19] of Byte = (
    0, 3, 11, 13, 21, 23, 27, 35, 40, 51, 52, 53, 58, 91, 136, 137,
    139, 142, 144, 31);

{ Combat placement, terrain and turning tables, and the adventure and camp menus. }
const
  { Turns that combat AI tries when a step is blocked, by approach pattern (aiStance 1..6) and attempt 1..5: each value
    is added to the wanted direction modulo 8, so 8 keeps it. A sixth attempt reads the first value of the next
    pattern. }
  combatAiDirections: array[1..6, 1..5] of Byte = ((8, 7, 6, 1, 2),
    (8, 1, 2, 7, 6),
    (7, 1, 8, 6, 2),
    (1, 7, 8, 2, 6),
    (8, 7, 6, 5, 4),
    (8, 1, 2, 3, 4));
  { Direction of the step from a team's start cell to each placement ring's base cell, by team direction (0..3) and ring
    (0..3). Ring zero is the start cell itself, so its direction is 8 (no step); CombatSt also checks for a wall that
    way. }
  combatRingDirections: array[0..3, 0..3] of Byte = (
    (8, 4, 6, 2), (8, 6, 4, 0), (8, 0, 6, 2), (8, 2, 0, 4));
  { Direction of the first quadrant filled in each placement ring, by team direction (0..3) and ring (0..3); CombatSt
    halves it to a quadrant number. }
  combatRingStarts: array[0..3, 0..3] of Byte = (
    (0, 0, 2, 6), (2, 2, 0, 4), (4, 4, 2, 6), (6, 6, 4, 0));
  { Direction (0..7) of each of the four placement quadrants. CombatSt also faces new combatants along the quadrant of
    the party's facing, turned around for hostiles. }
  combatQuadrantDirections: array[0..3] of Byte = (
    7, 2, 3, 6);
  { Column where the placement walk starts in each quadrant: the first row for ring zero, the second for the outer
    rings. }
  combatQuadrantX: array[Boolean, 0..3] of ShortInt = (
    (5, 4, 5, 6), (3, 8, 7, 2));
  { Row where the placement walk starts in each quadrant: the first row for ring zero, the second for the outer rings. }
  combatQuadrantY: array[Boolean, 0..3] of ShortInt = (
    (3, 2, 2, 3), (0, 2, 5, 3));
  { Free columns of the 11 by 6 placement grid, by team direction (0..3, with 4 for quadrant group 1) and grid row: a
    cell is free when lo <= column <= hi. A band with lo above hi frees no cell. }
  combatRowBands: array[0..4, 0..5] of Types.TBandRec = (
    ((lo: 1; hi: 0), (lo: 1; hi: 0), (lo: 1; hi: 0),
     (lo: 2; hi: 9), (lo: 3; hi: 10), (lo: 4; hi: 10)),
    ((lo: 0; hi: 2), (lo: 0; hi: 3), (lo: 1; hi: 4),
     (lo: 2; hi: 5), (lo: 3; hi: 6), (lo: 4; hi: 7)),
    ((lo: 0; hi: 6), (lo: 0; hi: 7), (lo: 1; hi: 8),
     (lo: 1; hi: 0), (lo: 1; hi: 0), (lo: 1; hi: 0)),
    ((lo: 3; hi: 6), (lo: 4; hi: 7), (lo: 5; hi: 8),
     (lo: 6; hi: 9), (lo: 7; hi: 10), (lo: 8; hi: 10)),
    ((lo: 0; hi: 6), (lo: 0; hi: 7), (lo: 1; hi: 8),
     (lo: 2; hi: 9), (lo: 3; hi: 10), (lo: 4; hi: 10)));
  { Column offsets of the four neighbors (north, east, south, west) that CombatSt's room decorator turns into feature
    tiles around a placed feature. }
  featureDx: array[1..4] of ShortInt = (0, 1, 0, -1);
  { Row offsets of the four neighbors (north, east, south, west) that go with featureDx. }
  featureDy: array[1..4] of ShortInt = (-1, 0, 1, 0);
  { Feature-class bits of each wilderness terrain character, read by TerrainClassOf; bits $10 and $20 raise the arena
    generators' fill thresholds. The terrain character is not range-checked, so higher characters read the bytes after
    this table. }
  terrainClasses: array[0..20] of Byte = (
    $00, $18, $11, $15, $01, $01, $60, $14, $08, $01, $00, $21, $71, $09, $06, $04,
    $01, $09, $09, $08, $59);
  { Not read: the bytes before the turning table. }
  turnUndeadLead: array[0..10] of ShortInt = (
    0, 17, 17, 0, 0, 1, 17, 0, 0, 32, 32);
  { D20 roll a cleric needs to turn undead, by undead level (1..10) and cleric-level bucket (the level for 1..8, 9 for
    levels 9..13 and 10 above). A positive entry turns the undead; zero or a negative entry destroys it on a roll of at
    least its magnitude; 99 cannot be rolled. CbtActs reads undead levels 11 and 12 unchecked, past the table into the
    menus that follow. }
  turnUndeadResults: array[1..10, 1..10] of ShortInt = (
    (10, 7, 4, 1, 1, 0, 0, -1, -1, -1),
    (13, 10, 7, 1, 1, 0, 0, 0, -1, -1),
    (16, 13, 10, 4, 1, 1, 0, 0, 0, -1),
    (19, 16, 13, 7, 4, 1, 1, 0, 0, -1),
    (20, 19, 16, 10, 7, 4, 1, 1, 0, 0),
    (99, 20, 19, 13, 10, 7, 4, 1, 1, 0),
    (99, 99, 20, 16, 13, 10, 7, 4, 1, 0),
    (99, 99, 99, 20, 16, 13, 10, 7, 4, 1),
    (99, 99, 99, 99, 20, 16, 13, 10, 7, 1),
    (99, 99, 99, 99, 99, 20, 16, 13, 10, 4));
  { Explore's command menu in the 3D view. }
  menu3D: String[40] = 'Area Cast View Encamp Search Look';
  { Unused: the 3D command menu without Area. }
  indoorExplorationMenu: String[40] = 'Cast View Encamp Search Look';
  { The camp menu's commands. }
  campMenu: Types.TStr40 = 'Save View Magic Rest Alter Fix Exit';
  { The camp Magic menu's commands. }
  magicMenu: Types.TStr40 = 'Cast Memorize Scribe Display Rest Exit';
  { The camp Alter menu's commands. }
  alterMenu: Types.TStr40 = 'Order Drop Speed Icon Pics Exit';

{ Party-order menu, save-file import tables and the character main menu. }
const
  { The two Party Order prompts: choosing a character, then choosing where to place it. }
  partyOrderMenus: array[0..1] of Types.TStr40 = (
    'Select Exit',
    'Place Exit');
  { Fifteen spaces that pad a character name to its column in the load and import lists, and to the width ScanSaveFiles
    compares against the party's names. }
  blankName: String[15] = '               ';
  { Offset of the character name in a save file, by import mode (0 for .guy, 1 for .cha and .sav, 2 for .hil files). }
  primaryNameOfs: array[0..2] of Byte = (
    0, 0, 4);
  { Offset of the flag byte that ScanSaveFiles checks in a save file, by import mode; a value above $7F leaves the file
    out of the list. Mode 2 files have no such byte. }
  secondaryNameOfs: array[0..2] of Word = (
    247, 132, 19);
  { File size that a character file of each import mode must have for ScanSaveFiles to list it. }
  charFileSizes: array[0..2] of Word = (
    422, 285, 188);
  { Letter that picks a combat icon file by icon size: 'S' for size 1 and 'T' for size 2, appended to CHEAD and CBODY. }
  iconFileClasses: array[0..2] of Char = (
    #0, 'S', 'T');
  { Class value for each class code (the low four bits) of an imported .hil character. Codes with no counterpart map to
    17, which reads the invalid-class name. }
  importClassMap: array[0..15] of Byte = (
    17, 6, 2, 14, 5, 16, 13, 15, 0, 12, 8, 17, 11, 17, 9, 17);
  { Hotkeys of the character main menu, passed to MenuHorizontal with no colors so the menu is not drawn; one letter per
    vertical-menu entry, then J, which toggles free training when the debug keyword is given. }
  charMenu: String[40] = 'C D M T H V A R L S B E J';
  { The character main menu's entries and whether each is offered. CharGen sets the enable flags as characters come and
    go, and draws the enabled entries' first letters as hotkeys. }
  characterVerticalMenus: array[0..11] of Types.TCharacterMenuItem = (
    (name: 'Create New Character'; enabled: True),
    (name: 'Drop Character'; enabled: False),
    (name: 'Modify Character'; enabled: False),
    (name: 'Train Character'; enabled: False),
    (name: 'Human Change Classes'; enabled: False),
    (name: 'View Character'; enabled: False),
    (name: 'Add Character to Party'; enabled: True),
    (name: 'Remove Character from Party'; enabled: False),
    (name: 'Load Saved Game'; enabled: True),
    (name: 'Save Current Game'; enabled: False),
    (name: 'BEGIN Adventuring'; enabled: False),
    (name: 'Exit to DOS'; enabled: True));

{ Icon customizer menus. }
const
  { The icon customizer's menus by state, shown after the icon size. CharGen swaps Hair or Face into the xxxx of the
    third menu as the part being edited changes. }
  characterHorizontalMenus: array[1..5] of String[40] = (
    'Parts 1st-color 2nd-color Size Exit',
    'Head Weapon Exit',
    'Weapon Body xxxx Shield Arm Leg Exit',
    ' Keep Exit',
    'Next Prev Keep Exit');

{ Character creation hit dice, cure effects, random item templates and spell-level names. }
const
  { Hit dice a class rolls for hit points at first level, by class (0..7); later levels roll one die. The better of two
    rolls counts. }
  startingHitDice: array[0..7] of Byte = (
    1, 1, 1, 1, 2, 1, 1, 2);
  { Sides of each class's hit die, by class (0..6); the monk's d4, class 7, is the first byte of cureEffects. }
  startingHitDieSides: array[0..6] of Byte = (
    8, 8, 10, 10, 8, 4, 6);
  { Entry zero is the monk's hit-die sides, the last entry of startingHitDieSides. Entries 1..6 are the disease effects
    that ViewChar's cure command removes. }
  cureEffects: array[0..6] of Byte = (
    4, 31, 34, 43, 44, 50, 57);
  { Seven item templates that GenerateRandomItem copies for some item kinds: three name IDs, weight, value and three
    spell or property values each. Money reads the name IDs and the last three values as words and uses their low
    bytes. }
  randomItemTemplates: Types.TRandomItemTable = (
    templates: (
      (nameIds: (185, 187, 64); weight: 1; value: 800;
       properties: (3, 99, 0)),
      (nameIds: (239, 167, 64); weight: 1; value: 1100;
       properties: (1, 59, 0)),
      (nameIds: (185, 167, 64); weight: 1; value: 400;
       properties: (1, 3, 0)),
      (nameIds: (173, 167, 64); weight: 1; value: 450;
       properties: (1, 48, 0)),
      (nameIds: (206, 167, 69); weight: 1; value: 11000;
       properties: (30, 15, 0)),
      (nameIds: (226, 167, 100); weight: 10; value: 15000;
       properties: (0, 38, 131)),
      (nameIds: (157, 167, 21); weight: 20; value: 3000;
       properties: (1, 51, 0))));
  { Headings of the spell lists, by spell level. }
  spellLevelNames: array[1..9] of String[40] = (
    '1st Level',
    '2nd Level',
    '3rd Level',
    '4th Level',
    '5th Level',
    '6th Level',
    '7th Level',
    '8th Level',
    '9th Level');

{ Spell rays, effect lists, screen and color tables, border glyphs, text and money tables, the name tables and CGA
  masks. }
const
  { Column offset from a ray's cell to its left-hand neighbor, by ray direction (0..7). Magic adds the side cells when a
    spell casts more than one ray. }
  sideRayDX1: array[0..7] of ShortInt = (
    -1, 0, 0, 1, 1, 0, 0, -1);
  { Row offset from a ray's cell to its left-hand neighbor, by ray direction (0..7). }
  sideRayDY1: array[0..7] of ShortInt = (
    0, -1, -1, 0, 0, 1, 1, 0);
  { Column offset from a ray's cell to its right-hand neighbor, by ray direction (0..7). }
  sideRayDX2: array[0..7] of ShortInt = (
    1, 1, 0, 0, -1, -1, 0, 0);
  { Row offset from a ray's cell to its right-hand neighbor, by ray direction (0..7). }
  sideRayDY2: array[0..7] of ShortInt = (
    0, 0, 1, 1, 0, 0, -1, -1);
  { Effect IDs that FxEngine removes when a creature's hit points reach zero (entries 1..19); entry 20 is not read. }
  deathEffects: array[1..20] of Byte = (
    7, 11, 13, 21, 23, 30, 31, 32, 51, 52, 53, 58, 59, 95, 98, 136,
    137, 139, 144, 0);
  { Effect IDs that FxEngine removes when combat AI control of a creature ends. }
  combatAiEffects: array[1..4] of Byte = (
    13, 58, 139, 144);
  { Screen column of the overland map cursor for each cursor position (0..31) a script selects. }
  cursorColumns: array[0..31] of Byte = (
    4, 12, 21, 11, 29, 20, 38, 21, 30, 31, 25, 37, 28, 29, 3, 12,
    25, 29, 29, 33, 19, 16, 9, 16, 20, 21, 25, 25, 26, 31, 37, 34);
  { Screen row of the overland map cursor for each cursor position (0..31) a script selects. }
  cursorRows: array[0..31] of Byte = (
    15, 8, 11, 4, 10, 4, 1, 2, 13, 15, 3, 5, 2, 8, 12, 13,
    10, 12, 9, 9, 8, 6, 6, 3, 2, 2, 3, 2, 3, 4, 2, 1);
  { Sky color for each sky or ceiling index of the current zone; bit 7 of the party's map cell picks the ceiling index.
    MapView does not check the indices, so a larger one reads past the table. }
  skyColors: array[0..15] of Byte = (
    0, 15, 4, 11, 13, 2, 9, 14, 0, 15, 4, 11, 13, 2, 9, 14);
  { Color maps for portraits: tint sends most colors to light red and keeps the mid-tones, for animated pictures when
    the script asks for it; key turns light magenta into black for transparent frames outside CGA. }
  portraitRemap: Types.TPortraitRemap = (
    tintSrc: (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);
    tintDst: (12, 12, 12, 12, 4, 5, 6, 7, 12, 12, 10, 12, 12, 12, 14, 12);
    keySrc: (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);
    keyDst: (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 0, 14, 15)
  );
  { First symbol of each perspective wall form within a wall's symbol list. }
  geoSymbolOffset: array[0..9] of Byte = (
    0, 2, 6, 10, 22, 38, 54, 110, 132, 154);
  { Width of each perspective wall form, in 8x8 symbol cells. }
  geoWidth: array[0..9] of Byte = (
    1, 1, 1, 3, 2, 2, 7, 2, 2, 1);
  { Height of each perspective wall form, in 8x8 symbol cells. }
  geoHeight: array[0..9] of Byte = (
    2, 4, 4, 4, 8, 8, 8, 11, 11, 2);
  { View column where each perspective wall form starts. }
  geoStartCol: array[0..9] of Integer = (
    5, 4, 6, 4, 2, 7, 2, 0, 9, 5);
  { View row where each perspective wall form starts. }
  geoStartRow: array[0..9] of Integer = (
    4, 3, 3, 3, 1, 1, 1, 0, 0, 4);
  { Color maps for tile and icon sets: the identity source list, a pink-to-pink map that leaves colors unchanged, and
    one that turns light magenta into black for ICON sets. }
  tileColorMaps: Types.TColorMaps = (
    cmapIdent: (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);
    cmapPink8: (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);
    cmapPink0: (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 0, 14, 15)
  );
  { Symbol numbers, relative to the outer border set, of the screen frame's edges and rules: top, bottom and left and
    right edges, the horizontal rule, the inner window, and the combat frame. }
  borderGlyphs: Types.TBorderGlyphs = (
    top: (0, 6, 1, 1, 1, 1, 1, 1, 6, 1, 1, 1, 1, 4, 1, 1, 1, 6, 1, 1, 1,
      1, 1, 1, 1, 8, 1, 1, 1, 1, 1, 1, 1, 4, 1, 1, 1, 6, 1, 2);
    hrule: (0, 8, 1, 1, 1, 1, 1, 1, 1, 1, 1, 6, 1, 1, 1, 8, 4, 1, 1, 1,
      6, 1, 1, 1, 1, 1, 1, 1, 1, 1, 4, 1, 6, 1, 1, 1, 1, 1, 8, 2);
    bottom: (1, 8, 6, 1, 1, 1, 1, 1, 1, 1, 1, 4, 1, 1, 1, 1, 1, 6, 8, 1,
      1, 1, 4, 1, 1, 1, 1, 1, 1, 6, 1, 1, 1, 1, 1, 1, 1, 1);
    innTop: (4, 3, 0, 6, 1, 1, 1, 1, 8, 1, 1, 4, 1);
    innBot: (1, 2, 1, 4, 1, 1, 1, 1, 1, 1, 8, 4, 1, 1, 3);
    left: (0, 2, 9, 5, 2, 2, 2, 2, 2, 2, 5, 7, 2, 2, 2, 2, 2, 9, 7, 2, 2,
      2, 7, 1);
    vrule: (0, 7, 5, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 5, 2, 9, 4);
    right: (2, 2, 9, 7, 2, 2, 2, 5, 2, 2, 2, 2, 2, 2, 2, 2, 2, 7, 2, 2,
      2, 2);
    innLeft: (5, 2, 0, 2, 7, 2, 2, 2, 2, 5, 2, 2, 2);
    innRight: (2, 1, 2, 5, 9, 2, 2, 2, 7, 5, 2, 2, 2, 2, 3);
    cbLeft: (0, 2, 9, 5, 2, 2, 2, 2, 2, 2, 5, 7, 2, 2, 2, 2, 2, 9, 7, 2,
      2, 2, 1);
    cbMid: (0, 7, 5, 2, 2, 2, 2, 2, 2, 2, 2, 2, 7, 5, 2, 2, 2, 2, 2, 2,
      5, 2, 4);
    cbRight: (2, 2, 9, 7, 2, 2, 2, 5, 2, 2, 2, 2, 2, 2, 2, 2, 2, 7, 2, 2,
      2, 2, 2)
  );
  { CGA fill byte for each of the four CGA colors: four copies of the 2-bit color, for Blit's solid runs. }
  cgaColorFill: array[0..3] of Byte = (
    $00, $55, $AA, $FF);
  { Tandy fill byte for each of the sixteen colors: two copies of the 4-bit color. }
  tandyColorFill: array[0..15] of Byte = (
    $00, $11, $22, $33, $44, $55, $66, $77, $88, $99, $AA, $BB, $CC, $DD, $EE, $FF);
  { Punctuation that TextRend keeps with the word before it when wrapping text. }
  breakChars: Types.TBrkSet = ['!', ',', '-', '.', ':', ';', '?'];
  { Characters that DaxIo removes from a name before using it as a file name. }
  invalidFileChars: array[1..10] of Char = (
    ' ', '.', '*', ',', '?', '/', '\', ':', ';', '|');
  { Worth of one coin of each kind (copper, silver, electrum, gold, platinum) in copper pieces. Money totals in gold
    divide by the gold entry, rounding at half. }
  coinValues: array[0..4] of LongInt = (
    1, 10, 100, 200, 1000);
  { Names of the classes and multi-classes, by class value (0..16). }
  classNames: array[0..16] of String[26] = (
    'Cleric',
    'Druid',
    'Fighter',
    'Paladin',
    'Ranger',
    'Magic-User',
    'Thief',
    'Monk',
    'Cleric/Fighter',
    'Cleric/Fighter/Magic-User',
    'Cleric/Ranger',
    'Cleric/Magic-User',
    'Cleric/Thief',
    'Fighter/Magic-User',
    'Fighter/Thief',
    'Fighter/Magic-User/Thief',
    'Magic-User/Thief');
  { Name shown for class value 17, which an imported character gets when its class code has no counterpart; readers
    reach it as the entry after classNames. }
  invalidClassName: String[26] = 'OK buddy, who are you?';
  { Names of the races, by race value; race 0 is a monster. }
  raceNames: array[0..7] of String[9] = (
    'Monster',
    'Dwarf',
    'Elf',
    'Gnome',
    'Half-Elf',
    'Halfling',
    'Half-Orc',
    'Human');
  { Names of the nine alignments, by alignment value. }
  alignmentNames: array[0..8] of String[16] = (
    'Lawful Good',
    'Lawful Neutral',
    'Lawful Evil',
    'Neutral Good',
    'True Neutral',
    'Neutral Evil',
    'Chaotic Good',
    'Chaotic Neutral',
    'Chaotic Evil');
  { Names of the genders, by gender value. }
  genderNames: array[0..1] of String[6] = (
    'Male',
    'Female');
  { Names of the coin kinds, then gems and jewelry, by money slot. }
  moneyNames: array[0..6] of String[10] = (
    'Copper',
    'Silver',
    'Electrum',
    'Gold',
    'Platinum',
    'Gems',
    'Jewelry');
  { Names of the creature statuses, by status value. }
  statusNames: array[0..8] of String[12] = (
    'Okay',
    'Animated',
    'tempgone',
    'Running',
    'Unconscious',
    'Dying',
    'Dead',
    'Stoned',
    'Gone');
  { Words that make up item names. An item names itself with up to three IDs into this list; empty entries are unused
    IDs. }
  itemNames: array[1..255] of String[20] = (
    'Battle Axe',
    'Hand Axe',
    'Bardiche',
    'Bec De Corbin',
    'Bill-Guisarme',
    'Bo Stick',
    'Club',
    'Dagger',
    'Dart',
    'Fauchard',
    'Fauchard-Fork',
    'Flail',
    'Military Fork',
    'Glaive',
    'Glaive-Guisarme',
    'Guisarme',
    'Guisarme-Voulge',
    'Halberd',
    'Lucern Hammer',
    'Hammer',
    'Javelin',
    'Jo Stick',
    'Mace',
    'Morning Star',
    'Partisan',
    'Military Pick',
    'Awl Pike',
    'Quarrel',
    'Ranseur',
    'Scimitar',
    'Spear',
    'Spetum',
    'Quarter Staff',
    'Bastard Sword',
    'Broad Sword',
    'Long Sword',
    'Short Sword',
    'Two-Handed Sword',
    'Trident',
    'Voulge',
    'Composite Long Bow',
    'Composite Short Bow',
    'Long Bow',
    'Short Bow',
    'Heavy Crossbow',
    'Light Crossbow',
    'Sling',
    'Mail',
    'Armor',
    'Leather',
    'Padded',
    'Studded',
    'Ring',
    'Scale',
    'Chain',
    'Splint',
    'Banded',
    'Plate',
    'Shield',
    'Woods',
    'Arrow',
    '',
    '',
    'Potion',
    'Scroll',
    'Ring',
    'Rod',
    'Stave',
    'Wand',
    'Jug',
    'Amulet',
    'Dragon Breath',
    'Bag',
    'Defoliation',
    'Ice Storm',
    'Book',
    'Boots',
    'Hornets Nest',
    'Bracers',
    'Piercing',
    'Brooch',
    'Elfin Chain',
    'Wizardry',
    'ac10',
    'Dexterity',
    'Fumbling',
    'Chime',
    'Cloak',
    'Crystal',
    'Cube',
    'Cubic',
    'The Dwarves',
    'Decanter',
    'Gloves',
    'Drums',
    'Dust',
    'Thievery',
    'Hat',
    'Flask',
    'Gauntlets',
    'Gem',
    'Girdle',
    'Helm',
    'Horn',
    'Stupidity',
    'Incense',
    'Stone',
    'Ioun Stone',
    'Javelin',
    'Jewel',
    'Ointment',
    'Pale Blue',
    'Scarlet And',
    'Manual',
    'Incandescent',
    'Deep Red',
    'Pink',
    'Mirror',
    'Necklace',
    'And Green',
    'Blue',
    'Pearl',
    'Powerlessness',
    'Vermin',
    'Pipes',
    'Hole',
    'Dragon Slayer',
    'Robe',
    'Rope',
    'Frost Brand',
    'Berserker',
    'Scarab',
    'Spade',
    'Sphere',
    'Blessed',
    'Talisman',
    'Tome',
    'Trident',
    'Grimoire',
    'Well',
    'Wings',
    'Vial',
    'Lantern',
    '',
    'Flask of Oil',
    '10 ft. Pole',
    '50 ft. Rope',
    'Iron',
    'Thf Prickly Tools',
    'Iron Rations',
    'Standard Rations',
    'Holy Symbol',
    'Holy Water vial',
    'Unholy Water vial',
    'Barding',
    'Dragon',
    'Lightning',
    'Saddle',
    'Staff',
    'Drow',
    'Wagon',
    '+1',
    '+2',
    '+3',
    '+4',
    '+5',
    'of',
    'Vulnerability',
    'Cloak',
    'Displacement',
    'Torches',
    'Oil',
    'Speed',
    'Tapestry',
    'Spine',
    'Copper',
    'Silver',
    'Electrum',
    'Gold',
    'Platinum',
    'Ointment',
    'Keoghtum''s',
    'Sheet',
    'Strength',
    'Healing',
    'Holding',
    'Extra',
    'Gaseous Form',
    'Slipperiness',
    'Jewelled',
    'Flying',
    'Treasure Finding',
    'Fear',
    'Disappearance',
    'Statuette',
    'Fungus',
    'Chain',
    'Pendant',
    'Broach',
    'Of Seeking',
    '-1',
    '-2',
    '-3',
    'Lightning Bolt',
    'Fire Resistance',
    'Magic Missiles',
    'Save',
    'Clrc Scroll',
    'MU Scroll',
    'With 1 Spell',
    'With 2 Spells',
    'With 3 Spells',
    'Prot. Scroll',
    'Jewelry',
    'Fine',
    'Huge',
    'Bone',
    'Brass',
    'Key',
    'AC 2',
    'AC 6',
    'AC 4',
    'AC 3',
    'Of Prot.',
    'Paralyzation',
    'Ogre Power',
    'Invisibility',
    'Missiles',
    'Elvenkind',
    'Rotting',
    'Covered',
    'Efreeti',
    'Bottle',
    'Missile Attractor',
    'Of Maglubiyet',
    'Secr Door & Trap Det',
    'Gd Dragon Control',
    'Feather Falling',
    'Giant Strength',
    'Restoring Level(s)',
    'Flame Tongue',
    'Fireballs',
    'Spiritual',
    'Boulder',
    'Diamond',
    'Emerald',
    'Opal',
    'Saphire',
    'Of Tyr',
    'Of Tempus',
    'Of Sune',
    'Wooden',
    '+3 vs Undead',
    'Pass',
    'Cursed');
  { Abbreviations of the eight facings, shown on the area line. }
  compassNames: array[0..7] of String[2] = (
    'N',
    'NE',
    'E',
    'SE',
    'S',
    'SW',
    'W',
    'NW');
  { Direction (0..7, or 8 for no step) of a step, by row delta + 1 and column delta + 1, read by Pathing. }
  directionByDelta: array[0..2, 0..2] of Byte = ((7, 0, 1),
    (6, 8, 2),
    (5, 4, 3));
  { Unused: EGA plane bits, highest first. }
  fontPlaneMasks: array[0..3] of Byte = (
    $08, $04, $02, $01);
  { Unused: a CGA word of each color, repeated across the eight pixels. }
  cgaFontColors: array[0..3] of Word = (
    $0000, $5555, $AAAA, $FFFF);
  { CGA color (0..3) for each of the sixteen colors. DaxIo maps text attributes through it in CGA mode, and the CGA
    glyph renderer seeds its ink and paper from it. }
  attrTable: array[0..15] of Byte = (
    0, 0, 0, 1, 2, 2, 2, 3, 0, 1, 1, 1, 2, 2, 3, 3);
  { Mask of each 2-bit CGA pixel in a word, leftmost pixel first; entries 4..7 cover the four pixels of a single byte,
    which Blit also uses to mirror a byte. }
  cgaBankMask: array[0..7] of Word = (
    $C000, $3000, $0C00, $0300, $00C0, $0030, $000C, $0003);

{ EGA and CGA drawing tables, sound commands, disk prompts, symbol sets, direction and terrain tables, and cloud
  shapes. }
const
  { Color bit carried by each EGA plane, which is also the sequencer map-mask value that selects that plane. }
  egaPlaneBit: array[0..3] of Byte = (
    $01, $02, $04, $08);
  { CGA color (0..3) at each pixel position (0..3, leftmost first) of a byte, by color then position. }
  cgaPixelPatterns: array[0..3, 0..3] of Byte = (
    ($00, $00, $00, $00),
    ($40, $10, $04, $01),
    ($80, $20, $08, $02),
    ($C0, $30, $0C, $03));
  { Map from the sixteen colors to CGA colors, two nibbles a byte, for the solid fills of View3D's sky and CharGen's
    icon backgrounds. }
  iconColorMap: Types.TColorMap = (
    $00, $11, $22, $12, $01, $21, $30, $33);
  { Sound command 255: silences both voices, removes the sound driver and marks sound inactive. Sent on quitting. }
  sndShutdown: Word = 255;
  { Sound command 0: silences both voices, before a disk load or a pause. }
  sndSilence: Word = 0;
  { Sound command 1: sets the driver's voice byte to 1 again, after a disk load or before a sound effect. }
  sndResume: Word = 1;
  { Sound command 2: the bolt sound of a spell cast at a target in combat. }
  sndCmd2: Word = 2;
  { Sound command 3: the miss sound when a combat attack is reported. }
  sndParamMiss: Word = 3;
  { Sound command 4: the hit sound when a combat attack is reported. }
  sndParamHit: Word = 4;
  { Sound command 5: a creature going down, and failing the copy protection. }
  sndCmd5: Word = 5;
  { Sound command 6: the flight of some missile types. }
  sndCmd6: Word = 6;
  { Sound command 7: a weapon hit in melee, also played when the target is already helpless. }
  sndCmd7: Word = 7;
  { Sound command 8: the bolt of spell 51, Lightning Bolt. }
  sndCmd8: Word = 8;
  { Sound command 9: a melee miss, and the flight of several missile types. }
  sndCmd9: Word = 9;
  { Sound command 10: a footstep, for party and combat moves and script sound effect 8. }
  sndFootstep: Word = 10;
  { Sound command 11: the bolt of spell 47, Fireball, and script sound effect 10. }
  sndCmd11: Word = 11;
  { Sound command 12: a missile's launch, played again for the missile types drawn by direction. }
  sndCmd12: Word = 12;
  { Sound command 13: the sound Intro plays with the fourth title picture. }
  sndIntro: Word = 13;
  { Unused: sound command 14. }
  sndCmd14: Word = 14;
  { Unused: sound command 15, which arms the driver's forced-exit countdown. }
  sndStartCountdown: Word = 15;
  { Prompts asking for the disk that holds each disk set's files (1..6), followed by the drive letter. }
  diskPrompts: array[1..6] of String[29] = (
    'Insert disk B in drive ',
    'Insert disk B in drive ',
    'Insert disk C in drive ',
    'Insert disk C in drive ',
    'Insert disk D in drive ',
    'Insert disk D in drive ');
  { First symbol number of each of the five 8x8 symbol sets; Sym8x8 subtracts it to index a set. }
  symSetBase: array[0..4] of Word = (
    1, 46, 116, 186, 256);
  { Lowest symbol number of a wall's own symbols, past the shared set; LoadWallSet shifts those symbols by the wall
    set's base. }
  wallThreshold: Word = 45;
  { Unused: the last symbol of sets 1..4. }
  symbolSetLimits: array[1..4] of Word = (115, 185, 255, 295);
  { Column step of each direction 0..7 (north first, clockwise), with 8 for no step. }
  directionDx: array[0..8] of ShortInt = (
    0, 1, 1, 1, 0, -1, -1, -1, 0);
  { Row step of each direction 0..7 (north first, clockwise), with 8 for no step. }
  directionDy: array[0..8] of ShortInt = (-1, -1, 0, 1, 1, 1, 0, -1, 0);
  { Combat terrain by terrain number: movement cost (255 impassable), clearance, blocking, and the tile drawn for it. }
  terrainInfo: array[1..65] of Types.TTerrain = (
    (cost: 255; clearance: 1; blocking: 2; tileId: 0),
    (cost: 255; clearance: 1; blocking: 2; tileId: 1),
    (cost: 255; clearance: 1; blocking: 2; tileId: 2),
    (cost: 255; clearance: 1; blocking: 2; tileId: 3),
    (cost: 1; clearance: 1; blocking: 0; tileId: 4),
    (cost: 255; clearance: 1; blocking: 2; tileId: 5),
    (cost: 255; clearance: 1; blocking: 2; tileId: 6),
    (cost: 255; clearance: 1; blocking: 2; tileId: 7),
    (cost: 1; clearance: 1; blocking: 0; tileId: 8),
    (cost: 255; clearance: 1; blocking: 2; tileId: 9),
    (cost: 1; clearance: 1; blocking: 0; tileId: 10),
    (cost: 255; clearance: 1; blocking: 2; tileId: 11),
    (cost: 1; clearance: 1; blocking: 0; tileId: 12),
    (cost: 255; clearance: 1; blocking: 2; tileId: 13),
    (cost: 1; clearance: 1; blocking: 0; tileId: 14),
    (cost: 255; clearance: 1; blocking: 2; tileId: 15),
    (cost: 1; clearance: 1; blocking: 0; tileId: 16),
    (cost: 255; clearance: 1; blocking: 2; tileId: 17),
    (cost: 255; clearance: 1; blocking: 2; tileId: 18),
    (cost: 255; clearance: 1; blocking: 2; tileId: 19),
    (cost: 255; clearance: 1; blocking: 2; tileId: 20),
    (cost: 255; clearance: 1; blocking: 2; tileId: 21),
    (cost: 1; clearance: 1; blocking: 0; tileId: 22),
    (cost: 1; clearance: 1; blocking: 0; tileId: 23),
    (cost: 255; clearance: 1; blocking: 2; tileId: 24),
    (cost: 2; clearance: 2; blocking: 0; tileId: 34),
    (cost: 1; clearance: 1; blocking: 0; tileId: 35),
    (cost: 1; clearance: 1; blocking: 0; tileId: 36),
    (cost: 1; clearance: 1; blocking: 0; tileId: 37),
    (cost: 1; clearance: 1; blocking: 0; tileId: 38),
    (cost: 1; clearance: 1; blocking: 0; tileId: 39),
    (cost: 255; clearance: 1; blocking: 2; tileId: 0),
    (cost: 255; clearance: 1; blocking: 2; tileId: 1),
    (cost: 255; clearance: 1; blocking: 2; tileId: 2),
    (cost: 255; clearance: 1; blocking: 2; tileId: 3),
    (cost: 255; clearance: 1; blocking: 2; tileId: 4),
    (cost: 1; clearance: 1; blocking: 0; tileId: 5),
    (cost: 1; clearance: 1; blocking: 0; tileId: 6),
    (cost: 1; clearance: 1; blocking: 0; tileId: 7),
    (cost: 1; clearance: 1; blocking: 0; tileId: 8),
    (cost: 1; clearance: 1; blocking: 0; tileId: 9),
    (cost: 255; clearance: 1; blocking: 2; tileId: 10),
    (cost: 255; clearance: 1; blocking: 2; tileId: 11),
    (cost: 1; clearance: 1; blocking: 0; tileId: 12),
    (cost: 1; clearance: 1; blocking: 0; tileId: 13),
    (cost: 1; clearance: 1; blocking: 0; tileId: 14),
    (cost: 1; clearance: 1; blocking: 0; tileId: 15),
    (cost: 2; clearance: 1; blocking: 0; tileId: 16),
    (cost: 2; clearance: 1; blocking: 0; tileId: 17),
    (cost: 2; clearance: 1; blocking: 0; tileId: 18),
    (cost: 2; clearance: 1; blocking: 0; tileId: 19),
    (cost: 2; clearance: 1; blocking: 0; tileId: 20),
    (cost: 2; clearance: 1; blocking: 0; tileId: 21),
    (cost: 1; clearance: 1; blocking: 0; tileId: 22),
    (cost: 1; clearance: 1; blocking: 0; tileId: 23),
    (cost: 1; clearance: 1; blocking: 0; tileId: 24),
    (cost: 1; clearance: 1; blocking: 0; tileId: 25),
    (cost: 2; clearance: 1; blocking: 0; tileId: 26),
    (cost: 2; clearance: 1; blocking: 0; tileId: 27),
    (cost: 4; clearance: 0; blocking: 0; tileId: 28),
    (cost: 4; clearance: 0; blocking: 0; tileId: 29),
    (cost: 4; clearance: 0; blocking: 0; tileId: 30),
    (cost: 4; clearance: 0; blocking: 0; tileId: 31),
    (cost: 1; clearance: 1; blocking: 0; tileId: 32),
    (cost: 1; clearance: 1; blocking: 0; tileId: 33));
  { Cell offsets of the tiles of a combat icon, by icon size (1..4) and tile (0..3); dx below zero marks an unused
    tile. }
  combatIconOffsets: array[1..4, 0..3] of Types.TIconDelta = (
    ((dx: 0; dy: 0), (dx: -1; dy: -1), (dx: -1; dy: -1), (dx: -1; dy: -1)),
    ((dx: 0; dy: 0), (dx: 0; dy: 1), (dx: -1; dy: -1), (dx: -1; dy: -1)),
    ((dx: 0; dy: 0), (dx: 1; dy: 0), (dx: -1; dy: -1), (dx: -1; dy: -1)),
    ((dx: 0; dy: 0), (dx: 1; dy: 0), (dx: 0; dy: 1), (dx: 1; dy: 1)));
  { Effect IDs that count as disabling status effects for IsHelpless. }
  statusEffects: array[1..4] of Byte = (
    51, 52, 53, 31);
  { Scan codes that MenuHorizontal returns for the digits 1..9, so that digits steer like the keypad. }
  keypadScanCodes: array[0..8] of Byte = (
    79, 80, 81, 75, 32, 77, 71, 72, 73);
  { Not read: Magic's view of the cloud cell directions starts here and reads from entry 1. }
  cloudCenterDirection: Byte = 0;
  { The stinking cloud's four cells, as directions from its upper-left cell: the cell itself (8), east, southeast and
    south. }
  stinkingCloudDirections: array[1..4] of Byte = (
    8, 2, 3, 4);
  { Cloudkill's nine cells, as directions from its center cell: the center itself (8), then the eight directions around
    it. }
  cloudkillDirections: array[1..9] of Byte = (
    8, 0, 1, 2, 3, 4, 5, 6, 7);

{ Spell names and rules, the clock limits, and the class, race and ability rule tables. }
const
  { Spell names by spell ID. Unused IDs have empty names. }
  spellNames: array[1..100] of Types.TStr40 = (
    'Bless',
    'Curse',
    'Cure Light Wounds',
    'Cause Light Wounds',
    'Detect Magic',
    'Protection From Evil',
    'Protection from Good',
    'Resist Cold',
    'Burning Hands',
    'Charm Person',
    'Detect Magic',
    'Enlarge',
    'Reduce',
    'Friends',
    'Magic Missile',
    'Protection From Evil',
    'Protection From Good',
    'Read Magic',
    'Shield',
    'Shocking Grasp',
    'Sleep',
    'Find Traps',
    'Hold Person',
    'Resist Fire',
    'Silence, 15'' Radius',
    'Slow Poison',
    'Snake Charm',
    'Spiritual Hammer',
    'Detect Invisibility',
    'Invisibility',
    'Knock',
    'Mirror Image',
    'Ray of Enfeeblement',
    'Stinking Cloud',
    'Strength',
    'Animate Dead',
    'Cure Blindness',
    'Cause Blindness',
    'Cure Disease',
    'Cause Disease',
    'Dispel Magic',
    'Prayer',
    'Remove Curse',
    'Bestow Curse',
    'Blink',
    'Dispel Magic',
    'Fireball',
    'Haste',
    'Hold Person',
    'Invisibility, 10'' Radius',
    'Lightning Bolt',
    'Protection From Evil, 10'' Radius',
    'Protection From Good, 10'' Radius',
    'Protection From Normal Missiles',
    'Slow',
    'Restoration',
    '',
    'Cure Serious Wounds',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    'Cause Serious Wounds',
    'Neutralize Poison',
    'Poison',
    'Protection Evil, 10'' Radius',
    'Sticks to Snakes',
    'Cure Critical Wounds',
    'Cause Critical Wounds',
    'Dispel Evil',
    'Flame Strike',
    'Raise Dead',
    'Slay Living',
    'Detect Magic',
    'Entangle',
    'Faerie Fire',
    'Invisibility to Animals',
    'Charm Monsters',
    'Confusion',
    'Dimension Door',
    'Fear',
    'Fire Shield',
    'Fumble',
    'Ice Storm',
    'Minor Globe Of Invulnerability',
    'Remove Curse',
    'Animate Dead',
    'Cloud Kill',
    'Cone of Cold',
    'Feeblemind',
    'Hold Monsters',
    '',
    '',
    '',
    '',
    '',
    'Bestow Curse');
  { Spell rules by spell ID: casting class and level, range, duration, targeting, saves, effect, and the combat AI's
    priority and radius. CombatAi also indexes it with unchecked preparation bits. }
  spellProperties: array[1..100] of Types.TSpellRec = (
    (castClass: 0; level: 1; rangeBase: 6; rangePerLevel: 0; durBase: 6; durPerLevel: 0; targetType: 10;
     targeting: 4; saveResult: 0; saveType: 4; effectId: 1; combatOk: 2; castingTime: 10; aiPriority: 1;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 0; level: 1; rangeBase: 6; rangePerLevel: 0; durBase: 6; durPerLevel: 0; targetType: 10;
     targeting: 0; saveResult: 0; saveType: 4; effectId: 2; combatOk: 1; castingTime: 10; aiPriority: 3;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 0; level: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 4;
     targeting: 2; saveResult: 0; saveType: 4; effectId: 0; combatOk: 2; castingTime: 5; aiPriority: 1;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 0; level: 1; rangeBase: 255; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 4;
     targeting: 0; saveResult: 0; saveType: 4; effectId: 0; combatOk: 1; castingTime: 5; aiPriority: 2;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 0; level: 1; rangeBase: 3; rangePerLevel: 0; durBase: 10; durPerLevel: 0; targetType: 0;
     targeting: 1; saveResult: 0; saveType: 4; effectId: 5; combatOk: 2; castingTime: 1; aiPriority: 0;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 0; level: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 3; targetType: 4;
     targeting: 2; saveResult: 0; saveType: 4; effectId: 8; combatOk: 2; castingTime: 4; aiPriority: 1;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 0; level: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 3; targetType: 4;
     targeting: 2; saveResult: 0; saveType: 4; effectId: 9; combatOk: 2; castingTime: 4; aiPriority: 1;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 0; level: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 10; targetType: 4;
     targeting: 2; saveResult: 0; saveType: 4; effectId: 10; combatOk: 2; castingTime: 10; aiPriority: 0;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 2; level: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 4;
     targeting: 0; saveResult: 0; saveType: 4; effectId: 0; combatOk: 1; castingTime: 1; aiPriority: 2;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 2; level: 1; rangeBase: 12; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 4;
     targeting: 0; saveResult: 1; saveType: 4; effectId: 11; combatOk: 1; castingTime: 1; aiPriority: 4;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 2; level: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 2; targetType: 0;
     targeting: 1; saveResult: 0; saveType: 4; effectId: 5; combatOk: 2; castingTime: 1; aiPriority: 0;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 2; level: 1; rangeBase: 0; rangePerLevel: 2; durBase: 0; durPerLevel: 10; targetType: 4;
     targeting: 2; saveResult: 0; saveType: 4; effectId: 12; combatOk: 2; castingTime: 1; aiPriority: 0;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 2; level: 1; rangeBase: 0; rangePerLevel: 2; durBase: 0; durPerLevel: 10; targetType: 4;
     targeting: 2; saveResult: 1; saveType: 4; effectId: 13; combatOk: 2; castingTime: 1; aiPriority: 0;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 2; level: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 1; targetType: 0;
     targeting: 1; saveResult: 0; saveType: 4; effectId: 14; combatOk: 0; castingTime: 1; aiPriority: 0;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 2; level: 1; rangeBase: 6; rangePerLevel: 4; durBase: 0; durPerLevel: 0; targetType: 4;
     targeting: 0; saveResult: 0; saveType: 4; effectId: 0; combatOk: 1; castingTime: 1; aiPriority: 4;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 2; level: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 2; targetType: 4;
     targeting: 2; saveResult: 0; saveType: 4; effectId: 8; combatOk: 2; castingTime: 1; aiPriority: 1;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 2; level: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 2; targetType: 4;
     targeting: 2; saveResult: 0; saveType: 4; effectId: 9; combatOk: 2; castingTime: 1; aiPriority: 1;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 2; level: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 2; targetType: 0;
     targeting: 1; saveResult: 0; saveType: 4; effectId: 16; combatOk: 0; castingTime: 10; aiPriority: 0;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 2; level: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 5; targetType: 0;
     targeting: 1; saveResult: 0; saveType: 4; effectId: 17; combatOk: 2; castingTime: 1; aiPriority: 2;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 2; level: 1; rangeBase: 255; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 4;
     targeting: 0; saveResult: 0; saveType: 4; effectId: 0; combatOk: 1; castingTime: 1; aiPriority: 2;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 2; level: 1; rangeBase: 3; rangePerLevel: 4; durBase: 0; durPerLevel: 5; targetType: 9;
     targeting: 0; saveResult: 0; saveType: 4; effectId: 53; combatOk: 1; castingTime: 1; aiPriority: 2;
     targetsEnemy: 1; aiRadius: 1),
    (castClass: 0; level: 2; rangeBase: 0; rangePerLevel: 0; durBase: 30; durPerLevel: 0; targetType: 0;
     targeting: 1; saveResult: 0; saveType: 4; effectId: 19; combatOk: 0; castingTime: 5; aiPriority: 0;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 0; level: 2; rangeBase: 6; rangePerLevel: 0; durBase: 4; durPerLevel: 1; targetType: 6;
     targeting: 0; saveResult: 1; saveType: 4; effectId: 52; combatOk: 1; castingTime: 5; aiPriority: 6;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 0; level: 2; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 10; targetType: 4;
     targeting: 2; saveResult: 0; saveType: 4; effectId: 20; combatOk: 2; castingTime: 5; aiPriority: 1;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 0; level: 2; rangeBase: 12; rangePerLevel: 0; durBase: 0; durPerLevel: 2; targetType: 31;
     targeting: 0; saveResult: 3; saveType: 4; effectId: 21; combatOk: 1; castingTime: 5; aiPriority: 4;
     targetsEnemy: 1; aiRadius: 1),
    (castClass: 0; level: 2; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 60; targetType: 4;
     targeting: 2; saveResult: 0; saveType: 4; effectId: 22; combatOk: 2; castingTime: 1; aiPriority: 0;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 0; level: 2; rangeBase: 3; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 240;
     targeting: 0; saveResult: 0; saveType: 4; effectId: 51; combatOk: 1; castingTime: 5; aiPriority: 0;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 0; level: 2; rangeBase: 3; rangePerLevel: 0; durBase: 0; durPerLevel: 1; targetType: 0;
     targeting: 1; saveResult: 0; saveType: 4; effectId: 23; combatOk: 2; castingTime: 5; aiPriority: 1;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 2; level: 2; rangeBase: 0; rangePerLevel: 4; durBase: 0; durPerLevel: 5; targetType: 0;
     targeting: 1; saveResult: 0; saveType: 4; effectId: 24; combatOk: 2; castingTime: 2; aiPriority: 1;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 2; level: 2; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 4;
     targeting: 2; saveResult: 0; saveType: 4; effectId: 25; combatOk: 2; castingTime: 2; aiPriority: 2;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 2; level: 2; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 0;
     targeting: 0; saveResult: 0; saveType: 4; effectId: 0; combatOk: 0; castingTime: 1; aiPriority: 0;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 2; level: 2; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 2; targetType: 0;
     targeting: 1; saveResult: 0; saveType: 4; effectId: 28; combatOk: 2; castingTime: 2; aiPriority: 3;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 2; level: 2; rangeBase: 1; rangePerLevel: 1; durBase: 0; durPerLevel: 1; targetType: 4;
     targeting: 0; saveResult: 1; saveType: 4; effectId: 29; combatOk: 1; castingTime: 2; aiPriority: 2;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 2; level: 2; rangeBase: 3; rangePerLevel: 0; durBase: 0; durPerLevel: 1; targetType: 9;
     targeting: 0; saveResult: 3; saveType: 0; effectId: 30; combatOk: 1; castingTime: 2; aiPriority: 5;
     targetsEnemy: 1; aiRadius: 1),
    (castClass: 2; level: 2; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 60; targetType: 0;
     targeting: 2; saveResult: 0; saveType: 4; effectId: 38; combatOk: 0; castingTime: 10; aiPriority: 0;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 3; level: 7; rangeBase: 4; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 8;
     targeting: 4; saveResult: 1; saveType: 4; effectId: 0; combatOk: 2; castingTime: 0; aiPriority: 2;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 0; level: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 4;
     targeting: 2; saveResult: 0; saveType: 4; effectId: 0; combatOk: 2; castingTime: 10; aiPriority: 0;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 0; level: 3; rangeBase: 255; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 4;
     targeting: 0; saveResult: 1; saveType: 4; effectId: 33; combatOk: 1; castingTime: 10; aiPriority: 3;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 0; level: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 0;
     targeting: 2; saveResult: 0; saveType: 4; effectId: 0; combatOk: 0; castingTime: 100; aiPriority: 0;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 0; level: 3; rangeBase: 255; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 4;
     targeting: 0; saveResult: 1; saveType: 4; effectId: 34; combatOk: 1; castingTime: 100; aiPriority: 4;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 0; level: 3; rangeBase: 6; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 9;
     targeting: 2; saveResult: 0; saveType: 4; effectId: 0; combatOk: 2; castingTime: 4; aiPriority: 3;
     targetsEnemy: 1; aiRadius: 1),
    (castClass: 0; level: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 1; targetType: 0;
     targeting: 4; saveResult: 0; saveType: 4; effectId: 49; combatOk: 2; castingTime: 6; aiPriority: 5;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 0; level: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 4;
     targeting: 2; saveResult: 0; saveType: 4; effectId: 0; combatOk: 2; castingTime: 6; aiPriority: 0;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 0; level: 3; rangeBase: 255; rangePerLevel: 0; durBase: 0; durPerLevel: 10; targetType: 4;
     targeting: 0; saveResult: 1; saveType: 4; effectId: 36; combatOk: 1; castingTime: 6; aiPriority: 5;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 2; level: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 1; targetType: 0;
     targeting: 0; saveResult: 0; saveType: 4; effectId: 37; combatOk: 1; castingTime: 1; aiPriority: 2;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 2; level: 3; rangeBase: 12; rangePerLevel: 0; durBase: 0; durPerLevel: 1; targetType: 9;
     targeting: 2; saveResult: 0; saveType: 4; effectId: 0; combatOk: 2; castingTime: 3; aiPriority: 2;
     targetsEnemy: 1; aiRadius: 1),
    (castClass: 2; level: 3; rangeBase: 10; rangePerLevel: 1; durBase: 0; durPerLevel: 0; targetType: 11;
     targeting: 0; saveResult: 2; saveType: 4; effectId: 0; combatOk: 1; castingTime: 3; aiPriority: 7;
     targetsEnemy: 1; aiRadius: 3),
    (castClass: 2; level: 3; rangeBase: 6; rangePerLevel: 0; durBase: 3; durPerLevel: 1; targetType: 10;
     targeting: 4; saveResult: 0; saveType: 4; effectId: 39; combatOk: 2; castingTime: 3; aiPriority: 3;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 2; level: 3; rangeBase: 12; rangePerLevel: 0; durBase: 0; durPerLevel: 2; targetType: 7;
     targeting: 0; saveResult: 1; saveType: 4; effectId: 52; combatOk: 1; castingTime: 3; aiPriority: 6;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 2; level: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 9;
     targeting: 4; saveResult: 0; saveType: 4; effectId: 25; combatOk: 2; castingTime: 3; aiPriority: 1;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 2; level: 3; rangeBase: 4; rangePerLevel: 1; durBase: 0; durPerLevel: 0; targetType: 8;
     targeting: 0; saveResult: 2; saveType: 4; effectId: 0; combatOk: 1; castingTime: 3; aiPriority: 6;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 2; level: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 2; targetType: 4;
     targeting: 2; saveResult: 0; saveType: 4; effectId: 45; combatOk: 2; castingTime: 3; aiPriority: 1;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 2; level: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 2; targetType: 4;
     targeting: 2; saveResult: 0; saveType: 4; effectId: 46; combatOk: 2; castingTime: 3; aiPriority: 2;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 2; level: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 10; targetType: 4;
     targeting: 2; saveResult: 0; saveType: 4; effectId: 41; combatOk: 2; castingTime: 3; aiPriority: 3;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 2; level: 3; rangeBase: 9; rangePerLevel: 1; durBase: 3; durPerLevel: 1; targetType: 10;
     targeting: 0; saveResult: 0; saveType: 4; effectId: 42; combatOk: 1; castingTime: 3; aiPriority: 4;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 0; level: 7; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 4;
     targeting: 2; saveResult: 0; saveType: 4; effectId: 0; combatOk: 2; castingTime: 6; aiPriority: 0;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 3; level: 6; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 0;
     targeting: 1; saveResult: 0; saveType: 4; effectId: 39; combatOk: 2; castingTime: 0; aiPriority: 3;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 0; level: 4; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 4;
     targeting: 2; saveResult: 0; saveType: 4; effectId: 0; combatOk: 2; castingTime: 7; aiPriority: 1;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 3; level: 6; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 0;
     targeting: 1; saveResult: 0; saveType: 4; effectId: 38; combatOk: 2; castingTime: 0; aiPriority: 1;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 3; level: 6; rangeBase: 4; rangePerLevel: 4; durBase: 0; durPerLevel: 0; targetType: 4;
     targeting: 0; saveResult: 2; saveType: 4; effectId: 0; combatOk: 1; castingTime: 0; aiPriority: 7;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 3; level: 6; rangeBase: 6; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 4;
     targeting: 0; saveResult: 1; saveType: 0; effectId: 52; combatOk: 1; castingTime: 0; aiPriority: 7;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 3; level: 6; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 0;
     targeting: 1; saveResult: 0; saveType: 4; effectId: 39; combatOk: 2; castingTime: 0; aiPriority: 1;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 3; level: 6; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 7;
     targeting: 4; saveResult: 0; saveType: 4; effectId: 71; combatOk: 2; castingTime: 0; aiPriority: 2;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 3; level: 6; rangeBase: 7; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 11;
     targeting: 0; saveResult: 2; saveType: 4; effectId: 0; combatOk: 1; castingTime: 0; aiPriority: 7;
     targetsEnemy: 1; aiRadius: 3),
    (castClass: 3; level: 6; rangeBase: 12; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 4;
     targeting: 0; saveResult: 0; saveType: 4; effectId: 0; combatOk: 1; castingTime: 0; aiPriority: 6;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 0; level: 4; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 4;
     targeting: 0; saveResult: 0; saveType: 4; effectId: 0; combatOk: 1; castingTime: 7; aiPriority: 5;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 0; level: 4; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 0;
     targeting: 2; saveResult: 0; saveType: 4; effectId: 0; combatOk: 0; castingTime: 7; aiPriority: 0;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 0; level: 4; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 4;
     targeting: 0; saveResult: 1; saveType: 0; effectId: 0; combatOk: 1; castingTime: 7; aiPriority: 6;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 0; level: 4; rangeBase: 3; rangePerLevel: 0; durBase: 0; durPerLevel: 10; targetType: 4;
     targeting: 2; saveResult: 0; saveType: 4; effectId: 45; combatOk: 2; castingTime: 7; aiPriority: 2;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 0; level: 4; rangeBase: 3; rangePerLevel: 0; durBase: 0; durPerLevel: 2; targetType: 4;
     targeting: 0; saveResult: 0; saveType: 4; effectId: 3; combatOk: 1; castingTime: 7; aiPriority: 4;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 0; level: 5; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 4;
     targeting: 2; saveResult: 0; saveType: 4; effectId: 0; combatOk: 2; castingTime: 8; aiPriority: 2;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 0; level: 5; rangeBase: 255; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 4;
     targeting: 0; saveResult: 1; saveType: 4; effectId: 0; combatOk: 1; castingTime: 8; aiPriority: 6;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 0; level: 5; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 1; targetType: 0;
     targeting: 0; saveResult: 0; saveType: 4; effectId: 145; combatOk: 1; castingTime: 8; aiPriority: 3;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 0; level: 5; rangeBase: 6; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 4;
     targeting: 0; saveResult: 2; saveType: 4; effectId: 0; combatOk: 1; castingTime: 8; aiPriority: 6;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 0; level: 5; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 0;
     targeting: 2; saveResult: 0; saveType: 4; effectId: 0; combatOk: 0; castingTime: 10; aiPriority: 1;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 0; level: 5; rangeBase: 3; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 4;
     targeting: 0; saveResult: 1; saveType: 4; effectId: 0; combatOk: 1; castingTime: 10; aiPriority: 7;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 1; level: 1; rangeBase: 3; rangePerLevel: 0; durBase: 12; durPerLevel: 0; targetType: 0;
     targeting: 1; saveResult: 0; saveType: 4; effectId: 5; combatOk: 2; castingTime: 3; aiPriority: 1;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 1; level: 1; rangeBase: 8; rangePerLevel: 0; durBase: 10; durPerLevel: 0; targetType: 11;
     targeting: 0; saveResult: 1; saveType: 4; effectId: 136; combatOk: 1; castingTime: 3; aiPriority: 3;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 1; level: 1; rangeBase: 8; rangePerLevel: 0; durBase: 0; durPerLevel: 4; targetType: 5;
     targeting: 0; saveResult: 1; saveType: 4; effectId: 7; combatOk: 1; castingTime: 3; aiPriority: 4;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 1; level: 1; rangeBase: 255; rangePerLevel: 0; durBase: 10; durPerLevel: 1; targetType: 4;
     targeting: 2; saveResult: 0; saveType: 4; effectId: 69; combatOk: 2; castingTime: 4; aiPriority: 1;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 2; level: 4; rangeBase: 6; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 5;
     targeting: 0; saveResult: 1; saveType: 4; effectId: 11; combatOk: 1; castingTime: 4; aiPriority: 6;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 2; level: 4; rangeBase: 12; rangePerLevel: 0; durBase: 2; durPerLevel: 1; targetType: 11;
     targeting: 0; saveResult: 1; saveType: 4; effectId: 35; combatOk: 1; castingTime: 4; aiPriority: 7;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 2; level: 4; rangeBase: 0; rangePerLevel: 3; durBase: 0; durPerLevel: 0; targetType: 8;
     targeting: 0; saveResult: 0; saveType: 4; effectId: 0; combatOk: 1; castingTime: 1; aiPriority: 0;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 2; level: 4; rangeBase: 6; rangePerLevel: 0; durBase: 0; durPerLevel: 1; targetType: 8;
     targeting: 0; saveResult: 1; saveType: 4; effectId: 142; combatOk: 1; castingTime: 4; aiPriority: 6;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 2; level: 4; rangeBase: 0; rangePerLevel: 0; durBase: 2; durPerLevel: 1; targetType: 0;
     targeting: 1; saveResult: 0; saveType: 4; effectId: 0; combatOk: 2; castingTime: 4; aiPriority: 8;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 2; level: 4; rangeBase: 0; rangePerLevel: 1; durBase: 0; durPerLevel: 1; targetType: 4;
     targeting: 0; saveResult: 1; saveType: 4; effectId: 27; combatOk: 1; castingTime: 4; aiPriority: 4;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 2; level: 4; rangeBase: 0; rangePerLevel: 1; durBase: 0; durPerLevel: 0; targetType: 10;
     targeting: 0; saveResult: 0; saveType: 4; effectId: 0; combatOk: 1; castingTime: 4; aiPriority: 7;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 2; level: 4; rangeBase: 0; rangePerLevel: 1; durBase: 0; durPerLevel: 1; targetType: 0;
     targeting: 1; saveResult: 0; saveType: 4; effectId: 63; combatOk: 2; castingTime: 4; aiPriority: 5;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 2; level: 4; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 4;
     targeting: 2; saveResult: 0; saveType: 4; effectId: 0; combatOk: 2; castingTime: 4; aiPriority: 0;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 3; level: 5; rangeBase: 1; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 240;
     targeting: 4; saveResult: 0; saveType: 4; effectId: 32; combatOk: 2; castingTime: 5; aiPriority: 0;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 2; level: 5; rangeBase: 2; rangePerLevel: 0; durBase: 0; durPerLevel: 1; targetType: 9;
     targeting: 0; saveResult: 0; saveType: 4; effectId: 0; combatOk: 2; castingTime: 5; aiPriority: 5;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 2; level: 5; rangeBase: 6; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 8;
     targeting: 0; saveResult: 2; saveType: 4; effectId: 0; combatOk: 1; castingTime: 5; aiPriority: 6;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 2; level: 5; rangeBase: 16; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 4;
     targeting: 0; saveResult: 1; saveType: 4; effectId: 68; combatOk: 1; castingTime: 5; aiPriority: 6;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 2; level: 5; rangeBase: 0; rangePerLevel: 1; durBase: 0; durPerLevel: 1; targetType: 7;
     targeting: 0; saveResult: 1; saveType: 4; effectId: 52; combatOk: 1; castingTime: 5; aiPriority: 7;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 3; level: 6; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 0;
     targeting: 1; saveResult: 0; saveType: 4; effectId: 73; combatOk: 2; castingTime: 10; aiPriority: 1;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 3; level: 6; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 0;
     targeting: 1; saveResult: 0; saveType: 4; effectId: 109; combatOk: 2; castingTime: 10; aiPriority: 1;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 3; level: 6; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 0;
     targeting: 1; saveResult: 0; saveType: 4; effectId: 25; combatOk: 2; castingTime: 0; aiPriority: 1;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 3; level: 6; rangeBase: 3; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 11;
     targeting: 0; saveResult: 1; saveType: 4; effectId: 0; combatOk: 1; castingTime: 0; aiPriority: 1;
     targetsEnemy: 1; aiRadius: 0),
    (castClass: 3; level: 6; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; targetType: 0;
     targeting: 1; saveResult: 0; saveType: 4; effectId: 0; combatOk: 2; castingTime: 0; aiPriority: 1;
     targetsEnemy: 0; aiRadius: 0),
    (castClass: 2; level: 4; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 10; targetType: 4;
     targeting: 0; saveResult: 1; saveType: 4; effectId: 0; combatOk: 1; castingTime: 4; aiPriority: 4;
     targetsEnemy: 1; aiRadius: 0));
  { Count of each game-clock unit that makes one of the next, smallest unit first; the years (256) do not roll over. }
  clockLimits: Types.TClock = (
    10, 10, 6, 24, 30, 12, 256);
  { Attack base by class (0..7) and level, read by CharGen and ClassCal; CharGen keeps the best of a character's
    classes. }
  classThac0: array[0..7, 0..12] of Byte = (
    (40, 40, 40, 40, 42, 42, 42, 44, 44, 44, 46, 46, 46),
    (40, 40, 40, 40, 42, 42, 42, 44, 44, 44, 46, 46, 46),
    (39, 40, 40, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51),
    (40, 40, 40, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51),
    (40, 40, 40, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51),
    (39, 39, 39, 39, 39, 39, 41, 41, 41, 41, 41, 43, 43),
    (40, 40, 40, 40, 40, 41, 41, 41, 41, 44, 44, 44, 44),
    (40, 40, 40, 40, 42, 42, 42, 44, 44, 44, 46, 46, 46));
  { Item-usability bit of each class (0..7), summed into a character's class mask. }
  classItemMasks: array[0..7] of Byte = (
    $02, $10, $08, $40, $40, $01, $04, $20);
  { Class bits by class value. CharGen reads the first eight against the class mask it is given. }
  classBits: array[0..16] of Byte = (
    $02, $02, $08, $10, $20, $01, $04, $04, $10, $10, $10, $20, $20, $20, $40, $40,
    $40);
  { Level at which each class (0..7) stops adding the Constitution hit-point bonus. }
  constitutionBonusLevelCaps: array[0..7] of Byte = (
    10, 15, 10, 10, 11, 12, 11, 19);
  { The icon picture colors that a character's six icon colors replace: icon color i's low nibble goes to picture color
    defaultIconColors[i] and its high nibble to that color plus 8. CharGen builds a new character's icon colors from
    them. }
  defaultIconColors: array[1..6] of Byte = (
    1, 2, 3, 4, 6, 7);
  { Base thief skill percentages by thief level (1..12) and skill (1..8), before the race and Dexterity adjustments. }
  thiefSkillBase: array[1..12, 1..8] of Byte = (
    (30, 25, 20, 15, 10, 10, 85, 0),
    (35, 29, 25, 21, 15, 10, 86, 0),
    (40, 33, 30, 27, 20, 15, 87, 0),
    (45, 37, 35, 33, 25, 15, 88, 20),
    (50, 42, 40, 40, 31, 20, 90, 25),
    (55, 47, 45, 47, 37, 20, 92, 30),
    (60, 52, 50, 55, 43, 25, 94, 35),
    (65, 57, 55, 62, 49, 25, 96, 40),
    (70, 62, 60, 70, 56, 30, 98, 45),
    (80, 67, 65, 78, 63, 30, 99, 50),
    (90, 72, 70, 86, 70, 35, 99, 60),
    (100, 77, 75, 94, 77, 35, 99, 65));
  { Thief skill adjustments by race (1..7) and skill (1..8). }
  thiefRaceAdjustments: array[1..7, 1..8] of ShortInt = (
    (0, 10, 15, 0, 0, 0, -10, -5),
    (5, -5, 0, 5, 10, 5, 0, 0),
    (0, 5, 10, 5, 5, 10, -15, 0),
    (10, 0, 0, 0, 5, 0, 0, 0),
    (5, 5, 5, 10, 15, 5, -15, -5),
    (-5, 5, 5, 0, 0, 5, 5, -10),
    (0, 0, 0, 0, 0, 0, 0, 0));
  { Thief skill adjustments by Dexterity (9..19) for the first five skills. ClassCal does not check the score, so a
    score below 9 reads the race adjustments. }
  thiefDexterityAdjustments: array[9..19, 1..5] of ShortInt = (
    (-15, -10, -10, -20, -10),
    (-19, -5, -10, -15, -5),
    (-5, 0, -5, -10, 0),
    (0, 0, 0, -5, 0),
    (0, 0, 0, 0, 0),
    (0, 0, 0, 0, 0),
    (0, 0, 0, 0, 0),
    (0, -5, 0, 0, 0),
    (5, 10, 0, 5, 5),
    (10, 15, 5, 10, 10),
    (15, 20, 10, 12, 12));
  { Ability minimums and maximums of each race (1..7), by gender for Strength, that CharGen enforces when it rolls and
    ages a character. }
  raceAbilityLimits: array[1..7] of Types.TRaceAbilityLimit = (
    (strMin: (8, 8); strMax: (18, 17); exStrMax: (99, 0);
     intMin: 3; intMax: 18; wisMin: 3; wisMax: 18;
     dexMin: 3; dexMax: 17; conMin: 12; conMax: 19; chaMin: 3; chaMax: 16),
    (strMin: (3, 3); strMax: (18, 16); exStrMax: (75, 0);
     intMin: 8; intMax: 18; wisMin: 3; wisMax: 18;
     dexMin: 7; dexMax: 19; conMin: 6; conMax: 18; chaMin: 8; chaMax: 18),
    (strMin: (6, 6); strMax: (18, 15); exStrMax: (50, 0);
     intMin: 7; intMax: 18; wisMin: 3; wisMax: 18;
     dexMin: 3; dexMax: 18; conMin: 8; conMax: 18; chaMin: 3; chaMax: 18),
    (strMin: (3, 3); strMax: (18, 17); exStrMax: (90, 0);
     intMin: 4; intMax: 18; wisMin: 3; wisMax: 18;
     dexMin: 6; dexMax: 18; conMin: 6; conMax: 18; chaMin: 3; chaMax: 18),
    (strMin: (6, 6); strMax: (17, 14); exStrMax: (0, 0);
     intMin: 6; intMax: 18; wisMin: 3; wisMax: 17;
     dexMin: 8; dexMax: 18; conMin: 10; conMax: 19; chaMin: 3; chaMax: 18),
    (strMin: (6, 6); strMax: (18, 18); exStrMax: (99, 75);
     intMin: 3; intMax: 17; wisMin: 3; wisMax: 14;
     dexMin: 3; dexMax: 17; conMin: 13; conMax: 19; chaMin: 3; chaMax: 12),
    (strMin: (3, 3); strMax: (18, 18); exStrMax: (100, 50);
     intMin: 3; intMax: 18; wisMin: 3; wisMax: 18;
     dexMin: 3; dexMax: 18; conMin: 3; conMax: 18; chaMin: 3; chaMax: 18));
  { Classes each race (1..7) may take: a count, then the class values. }
  raceClassLimits: array[1..7] of Types.TRaceClassRow = (
    (count: 3; choices: (2, 6, 14, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)),
    (count: 7; choices: (2, 5, 6, 13, 14, 15, 16, 0, 0, 0, 0, 0, 0)),
    (count: 3; choices: (2, 6, 14, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)),
    (count: 13; choices: (0, 2, 5, 6, 4, 8, 10, 9, 11, 13, 14, 15, 16)),
    (count: 3; choices: (2, 6, 14, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)),
    (count: 6; choices: (0, 2, 6, 8, 12, 14, 0, 0, 0, 0, 0, 0, 0)),
    (count: 6; choices: (0, 2, 5, 6, 3, 4, 0, 0, 0, 0, 0, 0, 0)));
  { Starting-age rolls (base, dice count and sides) by race (1..7) and class (0..6). }
  startingAgeRolls: array[1..7, 0..6] of Types.TRuleAge = (
    ((base: 250; num: 2; sides: 20),
     (base: 0; num: 0; sides: 0),
     (base: 40; num: 5; sides: 4),
     (base: 0; num: 0; sides: 0),
     (base: 0; num: 0; sides: 0),
     (base: 0; num: 0; sides: 0),
     (base: 75; num: 3; sides: 6)),
    ((base: 650; num: 10; sides: 10),
     (base: 0; num: 0; sides: 0),
     (base: 130; num: 5; sides: 6),
     (base: 0; num: 0; sides: 0),
     (base: 0; num: 0; sides: 0),
     (base: 150; num: 5; sides: 6),
     (base: 100; num: 5; sides: 6)),
    ((base: 300; num: 3; sides: 12),
     (base: 0; num: 0; sides: 0),
     (base: 60; num: 5; sides: 4),
     (base: 0; num: 0; sides: 0),
     (base: 0; num: 0; sides: 0),
     (base: 100; num: 2; sides: 12),
     (base: 80; num: 5; sides: 4)),
    ((base: 40; num: 2; sides: 4),
     (base: 0; num: 0; sides: 0),
     (base: 22; num: 3; sides: 4),
     (base: 0; num: 0; sides: 0),
     (base: 0; num: 0; sides: 0),
     (base: 30; num: 2; sides: 8),
     (base: 22; num: 3; sides: 8)),
    ((base: 0; num: 0; sides: 0),
     (base: 0; num: 0; sides: 0),
     (base: 20; num: 3; sides: 4),
     (base: 0; num: 0; sides: 0),
     (base: 0; num: 0; sides: 0),
     (base: 0; num: 0; sides: 0),
     (base: 40; num: 2; sides: 4)),
    ((base: 20; num: 1; sides: 4),
     (base: 0; num: 0; sides: 0),
     (base: 13; num: 1; sides: 4),
     (base: 0; num: 0; sides: 0),
     (base: 0; num: 0; sides: 0),
     (base: 0; num: 0; sides: 0),
     (base: 20; num: 2; sides: 4)),
    ((base: 18; num: 1; sides: 4),
     (base: 18; num: 1; sides: 4),
     (base: 15; num: 1; sides: 4),
     (base: 17; num: 1; sides: 4),
     (base: 20; num: 1; sides: 4),
     (base: 24; num: 2; sides: 4),
     (base: 18; num: 1; sides: 4)));
  { Ages at which a character of each race (1..7) passes each age category, which raise or lower its abilities. }
  ageThresholds: array[1..7, 0..4] of Word = (
    (50, 150, 250, 350, 450),
    (175, 550, 875, 1200, 1600),
    (90, 300, 450, 600, 750),
    (40, 100, 175, 250, 325),
    (33, 68, 101, 144, 199),
    (15, 30, 45, 60, 80),
    (20, 40, 60, 90, 120));
  { Minimum ability scores of each class value, which CharGen raises a rolled character to. }
  classAbilityMinimums: array[0..16, 0..5] of Byte = (
    (6, 6, 9, 0, 0, 0),
    (0, 0, 12, 0, 0, 15),
    (9, 0, 6, 6, 7, 0),
    (12, 9, 13, 0, 9, 17),
    (13, 13, 14, 0, 14, 0),
    (0, 9, 6, 6, 0, 0),
    (6, 6, 0, 9, 0, 0),
    (15, 0, 15, 15, 11, 0),
    (9, 0, 9, 0, 0, 0),
    (9, 9, 9, 0, 0, 0),
    (0, 13, 14, 0, 14, 0),
    (0, 9, 9, 0, 0, 0),
    (0, 0, 9, 9, 0, 0),
    (9, 9, 0, 0, 0, 0),
    (9, 0, 0, 9, 0, 0),
    (9, 9, 0, 9, 0, 0),
    (0, 9, 0, 9, 0, 0));
  { Alignments each class value allows: a signed count, then the alignment values. }
  classAlignments: array[0..16] of Types.TAlignmentRow = (
    (count: 9; choices: (0, 1, 2, 3, 4, 5, 6, 7, 8)),
    (count: 5; choices: (1, 3, 4, 5, 7, 0, 0, 0, 0)),
    (count: 9; choices: (0, 1, 2, 3, 4, 5, 6, 7, 8)),
    (count: 1; choices: (0, 0, 0, 0, 0, 0, 0, 0, 0)),
    (count: 3; choices: (0, 3, 6, 0, 0, 0, 0, 0, 0)),
    (count: 9; choices: (0, 1, 2, 3, 4, 5, 6, 7, 8)),
    (count: 7; choices: (1, 2, 3, 4, 5, 7, 8, 0, 0)),
    (count: 9; choices: (0, 1, 2, 3, 4, 5, 6, 7, 8)),
    (count: 9; choices: (0, 1, 2, 3, 4, 5, 6, 7, 8)),
    (count: 9; choices: (0, 1, 2, 3, 4, 5, 6, 7, 8)),
    (count: 3; choices: (0, 3, 6, 0, 0, 0, 0, 0, 0)),
    (count: 9; choices: (0, 1, 2, 3, 4, 5, 6, 7, 8)),
    (count: 9; choices: (0, 1, 2, 3, 4, 5, 6, 7, 8)),
    (count: 9; choices: (0, 1, 2, 3, 4, 5, 6, 7, 8)),
    (count: 7; choices: (1, 2, 3, 4, 5, 7, 8, 0, 0)),
    (count: 7; choices: (1, 2, 3, 4, 5, 7, 8, 0, 0)),
    (count: 7; choices: (1, 2, 3, 4, 5, 7, 8, 0, 0)));
  { Hit-point bonus per level by Constitution score (3..25). }
  constitutionHitPointBonus: array[3..25] of ShortInt = (
    -2, -1, -1, -1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2);
  { Each class's experience table (0..7): the experience needed for levels 2..12 and the spell slots gained at them.
    CharGen and Magic read the thresholds, ClassCal and ViewChar the spell slots. }
  classExperience: array[0..7] of Types.TRuleXp = (
    (thresholds: (1501, 3001, 6001, 13001, 27501, 55001, 110001, 225001, 450001, -1, -1);
     slots: ((1, 0, 0, 0, 0),
             (0, 1, 0, 0, 0),
             (1, 1, 0, 0, 0),
             (0, 1, 1, 0, 0),
             (0, 0, 1, 0, 0),
             (0, 0, 0, 1, 0),
             (0, 0, 1, 1, 0),
             (1, 1, 0, 0, 1),
             (0, 0, 0, 1, 1),
             (1, 0, 1, 0, 0),
             (1, 1, 1, 0, 0))),
    (thresholds: (-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1);
     slots: ((0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0))),
    (thresholds: (2001, 4001, 8001, 18001, 35001, 70001, 125001, 250001, 500001, 750001, 1000001);
     slots: ((0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0))),
    (thresholds: (2751, 5501, 12001, 24001, 45001, 95001, 175001, 350001, 700001, 1050001, -1);
     slots: ((0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (1, 0, 0, 0, 0),
             (1, 0, 0, 0, 0),
             (0, 1, 0, 0, 0),
             (0, 1, 0, 0, 0))),
    (thresholds: (2251, 4501, 10001, 20001, 40001, 90001, 150001, 225001, 325001, 650001, -1);
     slots: ((0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (1, 0, 0, 0, 0),
             (0, 0, 0, 1, 0),
             (1, 0, 0, 0, 0),
             (0, 0, 0, 1, 0),
             (0, 1, 0, 0, 0))),
    (thresholds: (2501, 5001, 10001, 22501, 40001, 60001, 90001, 135001, 250001, 375001, -1);
     slots: ((1, 0, 0, 0, 0),
             (0, 1, 0, 0, 0),
             (1, 1, 0, 0, 0),
             (1, 0, 1, 0, 0),
             (0, 0, 1, 0, 0),
             (0, 1, 0, 1, 0),
             (0, 0, 1, 1, 0),
             (0, 0, 0, 0, 1),
             (0, 1, 0, 0, 1),
             (0, 0, 1, 1, 1),
             (0, 0, 0, 1, 1))),
    (thresholds: (1251, 2501, 5001, 10001, 20001, 42501, 70001, 110001, 160001, 220001, 440001);
     slots: ((0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0))),
    (thresholds: (-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1);
     slots: ((0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0))));
  { Dice (count and sides) rolled for each class (0..7) while CreateCharacterMenu sets up a new character; the sum is
    not used, but the rolls advance the random sequence. }
  characterCreationDice: array[0..7] of Types.THitDice = (
    (num: 3; sides: 6), (num: 3; sides: 6), (num: 5; sides: 4), (num: 5; sides: 4), (num: 5; sides: 4),
    (num: 2; sides: 4), (num: 2; sides: 6), (num: 5; sides: 4));
  { Saving throws by class (0..7), level (1..12) and save, read by ClassCal with unchecked levels. }
  classSavingThrows: array[0..7, 1..12, 0..4] of Byte = (
    ((10, 13, 14, 16, 15),
     (10, 13, 14, 16, 15),
     (10, 13, 14, 16, 15),
     (9, 12, 13, 15, 14),
     (9, 12, 13, 15, 14),
     (9, 12, 13, 15, 14),
     (7, 10, 11, 13, 12),
     (7, 10, 11, 13, 12),
     (7, 10, 11, 13, 12),
     (6, 9, 10, 12, 11),
     (6, 9, 10, 12, 11),
     (6, 9, 10, 12, 11)),
    ((10, 13, 14, 16, 15),
     (10, 13, 14, 16, 15),
     (10, 13, 14, 16, 15),
     (9, 12, 13, 15, 14),
     (9, 12, 13, 15, 14),
     (9, 12, 13, 15, 14),
     (7, 10, 11, 13, 12),
     (7, 10, 11, 13, 12),
     (7, 10, 11, 13, 12),
     (6, 9, 10, 12, 11),
     (6, 9, 10, 12, 11),
     (6, 9, 10, 12, 11)),
    ((14, 15, 16, 17, 17),
     (14, 15, 16, 17, 17),
     (13, 14, 15, 16, 16),
     (13, 14, 15, 16, 16),
     (11, 12, 13, 13, 14),
     (11, 12, 13, 13, 14),
     (10, 11, 12, 12, 13),
     (10, 11, 12, 12, 13),
     (8, 9, 10, 9, 11),
     (8, 9, 10, 9, 11),
     (7, 8, 9, 8, 10),
     (7, 8, 9, 8, 10)),
    ((12, 13, 14, 15, 15),
     (12, 13, 14, 15, 15),
     (11, 12, 13, 14, 14),
     (11, 12, 13, 14, 14),
     (9, 9, 11, 11, 12),
     (9, 9, 11, 11, 12),
     (8, 9, 10, 10, 11),
     (9, 9, 10, 10, 11),
     (6, 7, 8, 7, 9),
     (6, 7, 8, 7, 9),
     (5, 6, 7, 6, 8),
     (5, 6, 7, 6, 8)),
    ((14, 15, 16, 17, 17),
     (14, 15, 16, 17, 17),
     (13, 14, 15, 16, 16),
     (13, 14, 15, 16, 16),
     (11, 12, 13, 13, 14),
     (11, 12, 13, 13, 14),
     (10, 11, 12, 12, 13),
     (10, 11, 12, 12, 13),
     (8, 9, 10, 9, 11),
     (8, 9, 10, 9, 11),
     (7, 8, 9, 8, 10),
     (7, 8, 9, 8, 10)),
    ((14, 13, 11, 15, 12),
     (14, 13, 11, 15, 12),
     (14, 13, 11, 15, 12),
     (14, 13, 11, 15, 12),
     (14, 13, 11, 15, 12),
     (13, 11, 9, 13, 10),
     (13, 11, 9, 13, 10),
     (13, 11, 9, 13, 10),
     (13, 11, 9, 13, 10),
     (13, 11, 9, 13, 10),
     (11, 9, 7, 11, 8),
     (11, 9, 7, 11, 8)),
    ((13, 12, 14, 16, 15),
     (13, 12, 14, 16, 15),
     (13, 12, 14, 16, 15),
     (13, 12, 14, 16, 15),
     (12, 11, 12, 15, 13),
     (12, 11, 12, 15, 13),
     (12, 11, 12, 15, 13),
     (12, 11, 12, 15, 13),
     (11, 10, 10, 14, 11),
     (11, 10, 10, 14, 11),
     (11, 10, 10, 14, 11),
     (11, 10, 10, 14, 11)),
    ((13, 12, 14, 16, 15),
     (13, 12, 14, 16, 15),
     (13, 12, 14, 16, 15),
     (13, 12, 14, 16, 15),
     (12, 11, 12, 15, 13),
     (12, 11, 12, 15, 13),
     (12, 11, 12, 15, 13),
     (12, 11, 12, 15, 13),
     (11, 10, 10, 14, 11),
     (13, 11, 9, 13, 10),
     (11, 9, 7, 11, 8),
     (11, 9, 7, 11, 8)));

implementation

end.
