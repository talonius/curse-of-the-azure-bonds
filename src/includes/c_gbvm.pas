{ GBVM script-variable cells (word indices into the zone 0/1 banks) that the engine reads by address. }
unit C_Gbvm;

interface

const
  { zone 0: the 3D map block LOAD FILES loaded, reloaded with a saved game }
  GEO_MAP_ID = $4BC5;
  { zone 0: the game clock's hour }
  CLOCK_HOURS = $4BC9;
  { zone 0: the area's anti-magic flag }
  ANTI_MAGIC = $4BE5;
  { zone 0: nonzero while a 3D map is loaded, including town streets; zero overland }
  VIEW_3D = $4BE6;
  { zone 0: the script that ran before the last NEWECL }
  PREV_SCRIPT = $4BF2;
  { zone 0: nonzero where the area has no automap }
  NO_AUTOMAP = $4BFB;
  { zone 0: the party's overland location, an index into the map cursor tables; combat takes its low byte as the
    wilderness terrain }
  OVERLAND_LOCATION = $4CA1;
  { zone 0: set by PROGRAM when the game is won }
  GAME_WON = $4CFD;
  { zone 0: nonzero asks for the portrait animation }
  ANIM_REQUEST = $4CFF;

  { zone 1: the classes the training hall here trains, as a bitmask; 0 outside a hall }
  TRAIN_MASK = $7EA8;
  { zone 1: the distance between the party and the monsters, at most the requested one }
  MONSTER_DIST = $7EC1;
  { zone 1: added to a creature's morale check }
  MORALE_THRESHOLD = $7EC6;
  { zone 1: $FF or more blocks the party's next step; cleared when a map loads }
  MOVE_LOCK = $7EC9;
  { zone 1: search and look mode flags }
  SEARCH_FLAGS = $7ECA;
  { zone 1: the sides taken by surprise (1 the party, 2 the hostiles) }
  SURPRISE = $7ECB;
  { zone 1: set when the party's step leaves the map }
  LEAVE_MAP = $7ED5;
  { zone 1: the portrait head shown for PICTURE and close-ups; $FF for none }
  PORTRAIT_HEAD = $7EE1;
  { zone 1: nonzero for a duel against the party's mirror images; afterward dying and unconscious members recover }
  MIRROR_DUEL = $7EE6;
  { zone 1: set to 1 when the party attacks an ally }
  ATTACKED_ALLIES = $7F33;
  { zone 1: the number of party members }
  PARTY_SIZE = $7F3E;
  { zone 1: the monsters' to-hit adjustment (low byte) }
  MONSTER_THAC0_MODIFIER = $7F70;
  { zone 1: the party's to-hit adjustment (low byte) }
  PARTY_THAC0_MODIFIER = $7F71;
  { zone 1: added to the party's movement in combat }
  PARTY_MOVE_MODIFIER = $7F72;

implementation

end.
