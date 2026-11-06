{ Creature records (TCreature, and TCharRecord, the Pool import layout), items, combat records and effect identifiers,
  and the other record and table types the game units share. }

{$A-}

unit Types;

interface

type
  { Short strings shared by the menus, item names and file names. }
  TStr2 = String[2];
  TStr8 = String[8];
  TStr40 = String[40];
  TStr80 = String[80];

  { Money slots: copper, silver, electrum, gold, platinum, gems, jewelry. }
  TMoney = array[0..6] of LongInt;
  { Clock components, each 10, 10, 6, 24, 30 and 12 of the one before (clockLimits), then years; the rest time uses 1
    minutes, 2 tens of minutes, 3 hours and 4 days. }
  TClock = array[0..6] of Word;

  PItem = ^TItem;

  { List-node prefix shared with TItem. Nodes allocated solely for menus contain the name, label flag, and next
    pointer. }
  TItemNode = record
    name: String[40];
    inUse: Byte;
    next: PItem;
  end;
  TItem = record
    name: string[40];
    { nonzero = menu label row (not selectable); 0 for items }
    inUse: Byte;
    { next item in inventory list }
    next: PItem;
    { Base-item index into GDVars.baseItems. }
    itemType: Byte;
    { identified name components [1]=component 3, [2]=2, [3]=1 }
    nameIds: array[1..3] of Byte;
    { magical bonus }
    plus: ShortInt;
    { saving throw bonus }
    saveBonus: ShortInt;
    { 0 = unequipped, 1 = equipped }
    equipped: Byte;
    { unidentified name components bitmask }
    unidMask: Byte;
    cursed: Byte;
    { weight in coins }
    weight: Word;
    { 0 = single, non-stacking }
    quantity: Byte;
    { value in gold pieces }
    value: Word;
    case Integer of
      { properties (scroll spells / charges) }
      0: (charges: Byte;
          { effect id }
          effect: Byte;
          { special-item id }
          special: Byte);
      { scroll-spell ids }
      1: (spells: array[1..3] of Byte);
  end;

  { Active-effect list node. }
  PEffect = ^TEffect;
  TEffect = record
    { The effect, which picks its handler. }
    id: Byte;
    { Minutes left; 0 for an effect that lasts until it is removed. GameTime counts it down. }
    duration: Word;
    { A value the effect's handler reads and sets. }
    strength: Byte;
    { True to call the effect's handler again when the effect is removed. }
    onRemove: Boolean;
    next: PEffect;
  end;

  { Pool import record; SaveLoad also passes TCreature pointers as this type. }
  PCharRecord = ^TCharRecord;
  { Combat targets point to the runtime character record. }
  PCreature = ^TCreature;
  PCombatRec = ^TCombatRec;
  TCombatRec = record
    { spell being cast }
    spellCast: Byte;
    { may cast this round }
    castAllowed: Byte;
    { may use an item this round }
    itemUseAllowed: Byte;
    { Signed initiative, cleared on death or at the end of actions. }
    initiative: ShortInt;
    attackPhase: Byte;
    { sweep allowance (attack level) }
    sweepBudget: Byte;
    { movement left this round }
    movement: Byte;
    { guarding flag }
    guarding: Byte;
    madeAttack: Byte;
    { facing 0..7 }
    direction: Byte;
    { Runtime character record for the opponent or target. }
    other: PCreature;
    { damage past 0 hp (dying) }
    overkill: Byte;
    { attackers this round }
    flankCount: Byte;
    { undead-turned flag }
    turned: Byte;
    usedTurnUndead: Byte;
    { summed offset from facing, mod 8 }
    flankSpread: Byte;
    notPcNpc: Byte;
    fleeing: Byte;
    { AI approach-pattern index 1..6 }
    aiStance: Byte;
  end;

  { An ability score: its permanent value and its current (effective) value. }
  TStatPair = record permanent: Byte; current: Byte; end;

  TIcon6 = array[1..6] of Byte;

  { A party member, NPC or monster. The party and the combat roster are lists linked through next. }
  TCreature = record
    { The name shown in menus and messages; the roster tells two characters apart by it and randomId. }
    name: String[15];
    { The six ability scores, indexed by C_Stat: the permanent score and the current one, which effects and items
      change. }
    stats: array[0..5] of TStatPair;
    { The current exceptional-Strength percentage (0 when Strength is below 18), recomputed from exStrBase by the
      ability recalculation and shown on the character sheet. }
    exStrCur: Byte;
    { The rolled exceptional-Strength percentage that exStrCur is recomputed from. }
    exStrBase: Byte;
    { The memorized spells by slot: a spell id, plus C_Spell.PENDING_FLAG while it is still being memorized; 0 for an
      empty slot. }
    memorizedSpells: array[0..83] of Byte;
    { Hours of rest still needed before pending spells start to finish: Camp sets 0, 4 or 6 from the queue, and GameTime
      counts it down each hour of rest. }
    spellPrep: ShortInt;
    { The best THAC0 across the creature's classes and levels, before items and effects. }
    thac0Base: Byte;
    { A C_Race value; above C_Race.MONSTER for monsters. }
    race: ShortInt;
    { A C_Class value; values from 8 are the multi-class combinations. }
    charClass: ShortInt;
    { Age in years; GameTime adds one each year. }
    age: Word;
    { Maximum hit points; a monster's breath attacks deal this much damage. }
    hpMax: Byte;
    { Nonzero for each spell the character knows, by spell id. }
    knownSpells: array[1..100] of Byte;
    { How many weak foes the creature may sweep in a round: its fighter levels, counting an earlier fighter class while
      it is active; 1 for anything else. }
    attackLevel: Byte;
    { The icon's size class in bits 0..6; bit 7 is also tested by the combat code. }
    iconDim: Byte;
    { Saving throw targets: paralysis, petrification, wands, breath and spells. }
    saves: array[0..4] of Byte;
    { Base movement per round, copied into movementCur. }
    moveRate: Byte;
    { The highest level among the creature's current classes. }
    levelHighest: ShortInt;
    { The highest level the character had reached when it changed class (dual class); its earlier class is active again
      once the new class's level passes it. }
    levelAtChange: ShortInt;
    { Levels lost to level drain; Restoration gives one back. }
    drainedLevels: Byte;
    { Hit points the drained levels took; Restoration returns an even share of them with each level. }
    drainedHps: Byte;
    { Rank for turning undead; 0 for anything that is not undead. }
    levelUndead: ShortInt;
    { Thief skill percentages, by skill (1..8). }
    thiefSkills: array[1..8] of Byte;
    { The active effects, a list linked through TEffect.next. }
    effects: PEffect;
    { Unused. }
    afterEffects: Byte;
    { Bit 7 set for an NPC, with the morale threshold in the low bits; below $80 for a player character. }
    npc: Byte;
    { For an NPC, the number of treasure shares it takes after a battle (low 3 bits); CharGen's modify menu sets it to
      1. }
    modified: Byte;
    { Unused. }
    reserved: array[0..1] of Byte;
    { The purse: copper, silver, electrum, gold, platinum, gems and jewelry. }
    coins: array[0..6] of Word;
    { Levels in each class, indexed by the C_Class level constants (cleric, druid, fighter, paladin, ranger, mage,
      thief, monk). }
    classLevels: array[0..7] of ShortInt;
    { Levels in the classes a dual-class character has left, indexed like classLevels. }
    oldClassLevels: array[0..7] of ShortInt;
    { 0 male, 1 female. }
    gender: ShortInt;
    { The creature type that weapon and spell effects test against. }
    charType: Byte;
    { 0..8: lawful, neutral and chaotic, each good, neutral and evil. }
    alignment: Byte;
    { Base attack rate of the first attack, in half attacks per round. }
    attacks: Byte;
    { Base attack rate of the second attack, in half attacks per round. }
    attacks2: Byte;
    { Dice rolled for the damage of the first and second attack without a weapon. }
    baseRolls: array[1..2] of Byte;
    { Sides of those damage dice. }
    baseDice: array[1..2] of Byte;
    { Damage modifier of the first and second attack without a weapon. }
    baseMod: array[1..2] of ShortInt;
    { Armor class before armor and effects, stored as 60 less the armor class. }
    acBase: Byte;
    { Nonzero when Strength adjusts the creature's hit and damage rolls. }
    useStrength: Byte;
    { A random byte rolled at creation that tells apart two characters with the same name; for an NPC, the CPIC picture
      its combat icon is loaded from. }
    randomId: Byte;
    { Experience points; training compares them with the class tables. }
    experience: LongInt;
    { The classes whose items the creature may use, the sum of their C_Class item masks. }
    classMask: Byte;
    { Hit points rolled, without the Constitution bonus. }
    hpRolled: Byte;
    { Spells per day by spell list (cleric, druid, magic-user, as in TSpellRec.castClass) and spell level. }
    spellSlots: array[0..2, 1..5] of Byte;
    { Experience awarded for defeating the creature. }
    xpAward: Word;
    { Further experience awarded for each hit point the creature rolled. }
    xpBonusPerHp: Byte;
    { The portrait's head, copied from an imported character. }
    portraitHead: Byte;
    { The portrait's body, copied from an imported character. }
    portraitBody: Byte;
    { The combat icon's head picture. }
    iconHead: Byte;
    { The combat icon's body picture. }
    iconBody: Byte;
    { The icon-animation slot (0..7) the combat icon is cached in. }
    orderNumber: Byte;
    { 1 for a small combat icon, 2 for a large one. }
    iconSize: Byte;
    { The combat icon's colors for body, arm, leg, hair, shield and weapon, two color nibbles each. }
    iconColors: TIcon6;
    { Bits that spell and weapon effects test: bit 0 makes the creature subject to Dispel Evil. }
    creatureTypeFlags: Byte;
    { Items in the inventory list. }
    numberOfItems: Byte;
    { The inventory, a list linked through TItem.next. }
    itemsAddr: PItem;
    { The readied items: weapon, shield, armor, gauntlets, helm, belt, robe, cloak, boots, two rings, arrows and
      bolts. }
    equipped: array[0..12] of PItem;
    { Hands taken by the readied items. }
    handsEquipped: Byte;
    { Saving-throw bonus from items. }
    saveBonus: ShortInt;
    { Weight carried, in coins. }
    encumbrance: Word;
    { The next creature in the party or the combat roster. }
    next: PCreature;
    { The creature's combat state, valid during combat. }
    combatAddr: PCombatRec;
    { A paladin's Cure Disease uses left; when the recent-cure effect ends it is set to one use, plus one for each five
      paladin levels past the first. }
    cureDiseaseUses: Byte;
    { Flags for the scripts, which read bit 0 of the first byte; the Hillsfar import can set it. }
    scriptFlags: array[0..2] of Byte;
    { A C_Status value. }
    status: Byte;
    { Nonzero while the creature is in play; a creature that leaves the battle or the party is set to 0, and the combat
      and party code pass over it. }
    enabled: Byte;
    { The side the creature fights on: 0 with the party, 1 against it. }
    hostile: ShortInt;
    { Nonzero when the computer fights for the creature. }
    quickfight: Byte;
    { THAC0 after items and effects. }
    thac0Cur: Byte;
    { Armor class after items and effects against attacks from the front and from behind, stored like acBase. }
    acCur: array[0..1] of Byte;
    { Attacks left this round, by attack phase. }
    curAttacks: array[1..2] of Byte;
    { Damage dice rolled by each attack phase, from the readied weapon or the base dice. }
    curRolls: array[1..2] of Byte;
    { Sides of those damage dice. }
    curDice: array[1..2] of Byte;
    { Damage modifier of each attack phase, Strength included. }
    curMod: array[1..2] of ShortInt;
    { Current hit points. }
    hpCur: Byte;
    { Movement left this round. }
    movementCur: Byte;
  end;

  TCharRecord = record
    name: string[15];
    { The ability scores, indexed by C_Stat. }
    abilities: array[0..5] of Byte;
    { Exceptional Strength percentage. }
    strExc: Byte;
    { currently memorized }
    memorizedSpells: array[0..20] of Byte;
    spellPrepTime: Byte;
    { base THAC0 }
    thac0Base: Byte;
    race: ShortInt;
    { Signed class identifier; values in C_Class; 8+ = multi-class. }
    charClass: ShortInt;
    age: Word;
    { hit points maximum }
    hpMax: Byte;
    { Spellbook flags. }
    spellsKnown: array[1..56] of Byte;
    attackLevel: Byte;
    iconDimensions: Byte;
    { Saving throws: paralysis, petrification, wands, breath, spells. }
    saves: array[0..4] of Byte;
    movementBase: Byte;
    { highest single-class level }
    levelHighest: ShortInt;
    drainedLevels: Byte;
    drainedHps: Byte;
    { Undead rank for turning (0 = not undead). }
    levelUndead: ShortInt;
    thiefSkills: array[1..8] of Byte;
    { pointer to effects list }
    effectsAddr: PEffect;
    afterEffects: Byte;
    { Bit 7 set = NPC (low bits: morale); below $80 = player character. }
    npc: Byte;
    modified: Byte;
    afterModified: Byte;
    beforeCoins: Byte;
    { Copper, silver, electrum, gold, platinum, gems, jewelry. }
    coinsA: array[0..6] of Word;
    { Cleric, druid, fighter, paladin, ranger, mage, thief, monk. }
    classLevels: array[0..7] of ShortInt;
    { 0 male, 1 female. }
    gender: Byte;
    charType: Byte;
    alignment: Byte;
    { attacks per round }
    attacks: Byte;
    attacks2: Byte;
    { unarmed dice rolls }
    unarmedRollsA: array[1..2] of Byte;
    { unarmed dice sides }
    unarmedDiceA: array[1..2] of Byte;
    { unarmed dmg mods }
    unarmedModA: array[1..2] of ShortInt;
    acBase: Byte;
    { strength to-hit/damage applies }
    useStrength: Byte;
    { Random identifier used to reject duplicate party members. }
    randByte: Byte;
    experience: LongInt;
    itemLimits: Byte;
    hpRolled: Byte;
    { Bonus cleric spell slots by spell level, based on Wisdom. }
    clericSpells: array[1..3] of Byte;
    mageSpells: array[1..3] of Byte;
    xpAward: Word;
    xpBonusPerHp: Byte;
    portraitHead: Byte;
    portraitBody: Byte;
    iconHead: Byte;
    iconBody: Byte;
    { icon-animation slot index (0..7) }
    orderNumber: Byte;
    iconSize: Byte;
    { Packed color pairs for body, arm, leg, hair, shield, and weapon. }
    iconColors: TIcon6;
    numberOfItems: Byte;
    { pointer to item list }
    itemsAddr: PItem;
    { Equipped items: weapon, shield, armor, gauntlets, helm, belt, robe, cloak, boots, two rings, arrows, bolts. }
    equipped: array[0..12] of PItem;
    handsEquipped: Byte;
    { accumulated save bonus (signed) }
    saveBonus: ShortInt;
    encumbrance: Word;
    { pointer to next character }
    nextCharAddr: PCharRecord;
    { pointer to combatant }
    combatAddr: PCombatRec;
    status: 0..127;
    enabled: Byte;
    { team index }
    hostile: ShortInt;
    quickfight: Byte;
    { current THAC0 }
    thac0Cur: Byte;
    { current AC }
    acCur: Byte;
    acBehind: Byte;
    curAttacks: Byte;
    curAttacks2: Byte;
    { current dice rolls }
    curRollsA: array[1..2] of Byte;
    { current dice sides }
    curDiceA: array[1..2] of Byte;
    { current dmg mods }
    curModA: array[1..2] of ShortInt;
    { current hit points }
    hpCur: Byte;
    { Current movement. }
    movementCur: Byte;
  end;

  TBrkSet = set of ' '..'?';

  { EGA-to-CGA color map: sixteen nibbles packed into eight bytes. }
  TColorMap = array[0..7] of Byte;
  { Unsigned bytes for image data and transparency masks. }
  PBytes = ^TBytes;
  TBytes = array[0..65000] of Byte;
  PImgBuf = ^TImgBuf;
  { Image-buffer header followed by pixel data. LoadPic reads height through map from the DAX picture header. }
  TImgBuf = record
    { image height in pixels }
    height: Word;
    { image width in character cells of 8 pixels }
    width: Word;
    { horizontal placement in cells; Show3DSprite draws the sprite 2 cells further right }
    originX: Word;
    { vertical placement in cells; Show3DSprite draws the sprite 2 cells further down }
    originY: Word;
    { images in buffer }
    count: Byte;
    { EGA-to-CGA color map }
    map: TColorMap;
    { bytes in one image }
    imgSize: Word;
    { extra transparency space (default nil) }
    transp: PBytes;
    { image data (open-ended) }
    data: array[0..32000] of Byte;
  end;
  TAnimFrame = record
    { How long the frame stays up, from the file. }
    time: LongInt;
    pic: PImgBuf;
  end;
  { Animation record. }
  TAnimRec = record
    { frames loaded }
    count: Byte;
    { Frame shown, counting from 1; LoadAnimation sets it to 1 and the animation loops advance it. }
    current: Byte;
    frames: array[1..8] of TAnimFrame;
  end;

  { Terrain properties used for placement and arena generation. }
  TTerrain = record cost: Byte; clearance: Byte; blocking: Byte; tileId: Byte end;
  TIconDelta = record dx: ShortInt; dy: ShortInt end;

  { A spell's properties. }
  TSpellRec = record
    { Caster class: 0 cleric, 1 druid, 2 mage, 3 special; CharHlp.GetCasterLevel casts class 3 at level 12. }
    castClass: ShortInt;
    { The spell level, which is also the spell-slot index. }
    level: ShortInt;
    rangeBase: Byte;
    rangePerLevel: Byte;
    durBase: Byte;
    durPerLevel: Byte;
    { Low-nibble mode: 0 self, 5 weighted target selection, 8..14 radius, 15 selected target or cell; other values
      select up to four targets. }
    targetType: Byte;
    targeting: Byte;
    { What a successful save does: 0 for no save; nonzero values (1..3) offer one, and the damage and effect code read
      it as a Boolean, and pass it on as the save mode. }
    saveResult: Byte;
    saveType: Byte;
    effectId: Byte;
    { Zero restricts the spell to camp. }
    combatOk: Byte;
    { Casting delay: CastSpellCombat takes a third of it off the caster's initiative. }
    castingTime: Byte;
    aiPriority: Byte;
    { Zero skips target search; nonzero searches for an enemy. Spell 3 has separate targeting rules. }
    targetsEnemy: Byte;
    aiRadius: Byte;
  end;

  TRandomItemTemplate = record
    nameIds: array[1..3] of Word;
    weight: Word;
    value: Word;
    properties: array[1..3] of Word;
  end;
  { Low and high bytes of a word. }
  TWordBytes = record
    lo: Byte;
    hi: Byte;
  end;
  { The random item templates, which GenerateRandomItem also reads as one run of words, and of their low bytes, from a
    template's first word. }
  TRandomItemTable = record
    case Byte of
      0: (templates: array[1..7] of TRandomItemTemplate);
      1: (words: array[1..56] of Word);
      2: (wordBytes: array[1..56] of TWordBytes);
  end;

  TRuleAge = record base: Word; num: Byte; sides: Byte end;
  TBandRec = record lo: ShortInt; hi: ShortInt end;
  THitDice = record num: Byte; sides: Byte end;
  TAlignmentRow = record count: ShortInt; choices: array[1..9] of ShortInt end;
  { One class's experience table: the experience needed for each level 2..12 (-1 where the class cannot reach the
    level), and the spell slots the class gains at each of those levels, by spell level. }
  TRuleXp = record
    thresholds: array[2..12] of LongInt;
    slots: array[2..12, 1..5] of Byte;
  end;
  { The classes one race may take: how many, then the class values. }
  TRaceClassRow = record count: ShortInt; choices: array[1..13] of ShortInt; end;

  { One race's ability limits. The strength limits are indexed by gender. }
  TRaceAbilityLimit = record
    strMin: array[0..1] of Byte;
    strMax: array[0..1] of Byte;
    exStrMax: array[0..1] of Byte;
    intMin: Byte;
    intMax: Byte;
    wisMin: Byte;
    wisMax: Byte;
    dexMin: Byte;
    dexMax: Byte;
    conMin: Byte;
    conMax: Byte;
    chaMin: Byte;
    chaMax: Byte;
  end;
  PArena = ^TArena;
  TArena = record
    { reserved }
    header: array[0..1] of Byte;
    { top-left corner of the combat view }
    focusX: ShortInt;
    focusY: ShortInt;
    { draw the combat cursor when nonzero }
    cursorOn: Byte;
    { cursor icon geometry }
    focusSize: Byte;
    { bypass terrain blocking (WalkLine) when nonzero }
    distMode: Byte;
    cells: array[0..24, 0..49] of Byte;
  end;
  { An effect handler: applies (removed False) or removes (removed True) an effect on cr; effectNode is the effect node
    or the item that grants it. }
  TEffectHandler = procedure(cr: PCreature; effectNode: Pointer; removed: Boolean);

  { A stinking cloud or Cloudkill on the combat map, one node per casting. A stinking cloud uses only cells 1..4. }
  PCloudNode = ^TCloudNode;
  TCloudNode = record
    { the creature that cast it }
    caster: PCreature;
    { the next cloud of the same kind }
    next: PCloudNode;
    { the terrain under each cell, put back when the cloud clears }
    under: array[1..9] of Byte;
    { nonzero for each cell the cloud covers }
    exists: array[1..9] of Byte;
    { the origin cell; each cell lies one direction step from it }
    ulX: ShortInt;
    ulY: ShortInt;
    { the cloud's number among its caster's clouds, matched against the cast effect's strength div 16 }
    idx: Byte;
    { set when the cloud survives a resistance check; later checks skip it }
    resolved: Byte;
  end;

  TArenaLoc = record x: ShortInt; y: ShortInt; aux: Byte; size: Byte end;
  TArenaLocationHead = record x: ShortInt; y: ShortInt; aux: Byte end;
  TCombatGridStorage = record rows: array[0..23, 0..49] of Byte; finalRow: array[0..45] of Byte end;

  TCharacterMenuItem = record
    name: String[40];
    enabled: Boolean;
  end;

  TTargetRec = record
    { creature slot, doubled distance, direction toward it }
    idx: Byte;
    dist: Byte;
    dir: Byte;
  end;
  TDownedRec = record
    cr: PCreature;
    x: ShortInt;
    y: ShortInt;
    terrain: Byte;
  end;
  { Where the party stands and what it faces. GameInit clears the five fields together and SaveLoad saves and loads them
    as one block; scripts read them all through EclMenu. }
  TPartyPosition = record
    { The party's column on the 16 by 16 dungeon map; stepping off one edge wraps to the other. Explore steps it,
      scripts set it through EclMenu, and GameInit starts the party at column 7. }
    mapX: ShortInt;
    { The party's row on the dungeon map, with the same wrapping and writers as mapX; GameInit starts the party at row
      13. }
    mapY: ShortInt;
    { The direction the party faces, 0..7 clockwise from north; on the dungeon map it moves in steps of 2. Explore turns
      it, scripts set it through EclMenu, and the combat setup lays the two sides out along it. }
    facing: Byte;
    { The wall type on the facing side of the party's cell, from View3D's GetWallType; Explore, EclMenu and EclVm
      refresh it after moves and turns. }
    wallAhead: Byte;
    { The event byte of the party's cell, from View3D's GetMapEvent; Explore, EclMenu, EclVm and MapView refresh it
      after moves. With bit $80 set MapView paints the sky area in the ceiling color. }
    eventAtCell: Byte;
  end;
  { A wall-set slot: the WALLDEF block it holds and the 8x8 symbol slot its glyphs went to. }
  TWallSetCacheSlot = record
    wallDefId: Word;
    symbolSlot: Word;
  end;

  { One wall type's symbol numbers for each of its perspective forms; geoSymbolOffset gives a form's first. }
  TWallRow = array[0..155] of Byte;
  { One WALLDEF entry: the five wall types of a wall-set slot. }
  TWallEntry = array[1..5] of TWallRow;
  { The loaded wall graphics: fifteen wall types, read by wall type or as the three wall-set slots of five types each. }
  PWallGfx = ^TWallGfx;
  TWallGfx = record
    case Byte of
      0: (byType: array[1..15] of TWallRow);
      1: (bySlot: array[1..3] of TWallEntry);
  end;

  { A loaded or decompressed DAX block, read a byte at a time. }
  TByteArr = array[0..65534] of ShortInt;
  PByteArr = ^TByteArr;

  { The game font: eight rows of pixel bits per character. }
  TFontArr = array[0..255] of array[0..7] of Byte;
  PFontArr = ^TFontArr;

  { One plane of the 3D map, a byte per cell, indexed [row, col]. }
  TMapPlane = array[0..15, 0..15] of Byte;
  { The loaded 3D map: four planes of 16x16 cells. }
  PDungMap = ^TDungMap;
  TDungMap = record
    { sides 0 (N) and 2 (E): high, low nibble }
    wallP: TMapPlane;
    { sides 4 (S) and 6 (W): high, low nibble }
    wallQ: TMapPlane;
    { cell events }
    floor: TMapPlane;
    { 2-bit feature field per side: bits 7-6 side 6, 5-4 side 4, 3-2 side 2, 1-0 side 0 }
    feat: TMapPlane;
  end;

  { A portrait slot: the picture file id and its loaded image. }
  TPortSlot = record
    fileId: Byte;
    pic: PImgBuf;
  end;

  { A GOSUB return-stack entry: the script address RETURN resumes at, and the entry below it. }
  PEclRet = ^TEclRet;
  TEclRet = record
    addr: Word;
    next: PEclRet;
  end;

  { GBVM banks are indexed by script address. Bank 3 stores ECL script bytes; the other banks store words. }
  TGbvmBank0 = array[$4B00..$4EFF] of Word; PGbvmBank0 = ^TGbvmBank0;
  TGbvmBank1 = array[$7C00..$7FFF] of Word; PGbvmBank1 = ^TGbvmBank1;
  TGbvmBank2 = array[$7A00..$7BFF] of Word; PGbvmBank2 = ^TGbvmBank2;
  TGbvmBank3 = array[$8000..$9DFF] of Byte; PGbvmBank3 = ^TGbvmBank3;

  TBaseItemRec = record
    { equip slot }
    slot: Byte;
    { hands required }
    hands: Byte;
    { damage vs large: dice number }
    dmgLgRolls: Byte;
    { damage vs large: dice sides }
    dmgLgDice: Byte;
    { damage vs large: bonus }
    dmgLgMod: ShortInt;
    { ranged rate of fire x2 }
    rateOfFire: Byte;
    { AC adjustment descriptor }
    acDescr: Byte;
    { 0 slash / 1 pierce / 128 bash }
    wpnClass: Byte;
    { $00 or $80 in ITEMS; weapons may set $80. }
    weaponFlag: Byte;
    { damage vs small/medium: dice number }
    dmgSmRolls: Byte;
    { damage vs small/medium: dice sides }
    dmgSmDice: Byte;
    { damage vs small/medium: bonus }
    dmgSmMod: ShortInt;
    { ranged range (exclusive) }
    range: Byte;
    { class usability bitmask }
    classMask: Byte;
    { Weapon properties: 1 arrows, 2 Dexterity missile bonus, 4 Strength bonus, 8 ammunition weapon, 16 the item is its
      own missile, 128 quarrels. }
    props: Byte;
    { reserved; zero in ITEMS }
    entryTail: Byte;
  end;

  { One color for each slot 0..15: RemapPic's fromColors and toColors tables. }
  TColorTab = array[0..15] of Byte;
  TGlyphRow = array[0..39] of Byte;
  { The border glyph tables, GDConsts.borderGlyphs. Entries are indexed by screen column or row. The fields follow the
    tables' storage order; the bottom, right, innTop and innLeft loops read two entries past their field into the next
    table. }
  TBorderGlyphs = record
    { row 0, columns 0..39 }
    top: TGlyphRow;
    { horizontal rules, columns 0..39 }
    hrule: TGlyphRow;
    { bottom row (23, or 22 in combat), columns 0..39 }
    bottom: array[0..37] of Byte;
    { inner box top, row 2, columns 2..14 }
    innTop: array[0..12] of Byte;
    { inner box bottom, row 14, columns 2..14 }
    innBot: array[0..14] of Byte;
    { column 0, rows 0..23 }
    left: array[0..23] of Byte;
    { vertical rule, column 16, rows 0..16 }
    vrule: array[0..16] of Byte;
    { column 39, rows 0..23 }
    right: array[0..21] of Byte;
    { inner box left, column 2, rows 2..14 }
    innLeft: array[0..12] of Byte;
    { inner box right, column 14, rows 2..14 }
    innRight: array[0..14] of Byte;
    { combat column 0, rows 0..22 }
    cbLeft: array[0..22] of Byte;
    { combat column 22, rows 0..22 }
    cbMid: array[0..22] of Byte;
    { combat column 39, rows 0..22 }
    cbRight: array[0..22] of Byte;
  end;
  TColorMaps = record
    cmapIdent: TColorTab;
    cmapPink8: TColorTab;
    cmapPink0: TColorTab;
  end;
  TPortraitRemap = record tintSrc: TColorTab; tintDst: TColorTab; keySrc: TColorTab; keyDst: TColorTab end;

type
  TStar = record
    posX: Integer;
    posY: Integer;
    newX: Integer;
    newY: Integer;
    { Fixed-point position. }
    fixX: Integer;
    fixY: Integer;
    { Fixed-point velocity. }
    velX: Integer;
    velY: Integer;
    size: Byte;
    tail: array[0..5] of Byte;
  end;
  TStarRow = array[1..40] of TStar;
  TStarField = array[1..3] of TStarRow;
  PStarField = ^TStarField;
  { per-layer color seed: 1 = dim, 2..6 a color }
  TLayerMask = array[1..3] of Byte;
  { An encounter monster's display state for DisplayMonster: [0] set once its sprite is loaded, [1] once its close-up
    has been shown. }
  TMonFlags = array[0..1] of Boolean;

  { A line walk across the combat arena between two cells, in doubled-distance steps (Pathing.PathFind and
    NextPathStep). }
  TPathReq = record
    { start / end points }
    sx: Integer;
    sy: Integer;
    ex: Integer;
    ey: Integer;
    { accumulated 2x error term }
    err: Integer;
    { horizontal distance from start to end }
    adx: Integer;
    { vertical distance from start to end }
    ady: Integer;
    { current x (walked) }
    cx: Integer;
    { current y (walked) }
    cy: Integer;
    { x step sign (-1/0/1) }
    stepX: Integer;
    { y step sign (-1/0/1) }
    stepY: Integer;
    { doubled distance walked }
    dist: Byte;
    { direction of last step (0..8) }
    step: Byte;
  end;

  { A spell's handler, which casts the spell GDVars.spellId names. }
  TSpellProc = procedure;
  { A spell-target picker, called with the spell, whether the AI is casting it, and a flag it sets for the caller. }
  TCastUi = procedure(spell: Byte; aiControlled: Boolean; var sel: Boolean);
  { The spell handlers: the target picker the casting code calls, then the handler of each spell (1..100). }
  TSpellHandlers = record
    castTargets: TCastUi;
    spells: array[1..100] of TSpellProc;
  end;

  { The register block for software interrupts, laid out as Dos.Registers so storage can hold one without using Dos;
    callers pass it to Intr as a Registers. }
  TRegisters = record
    case Integer of
      0: (ax: Word;
          bx: Word;
          cx: Word;
          dx: Word;
          bp: Word;
          si: Word;
          di: Word;
          ds: Word;
          es: Word;
          flags: Word);
      1: (al: Byte;
          ah: Byte;
          bl: Byte;
          bh: Byte;
          cl: Byte;
          ch: Byte;
          dl: Byte;
          dh: Byte);
  end;

implementation

end.
