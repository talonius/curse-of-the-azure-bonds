{ ECL script opcodes: the first byte of each instruction, which EclVm dispatches on and EclTrace names in its trace. }
unit C_Ecl;

interface

const
  { stop the VM, free the whole GOSUB stack }
  OP_EXIT = $00;
  OP_GOTO = $01;
  { push the return addr, then jump }
  GOSUB = $02;
  { int or (type >= $80) string compare -> cmpFlags }
  COMPARE = $03;
  { v1 + v2 }
  ADD = $04;
  { v2 - v1 }
  SUBTRACT = $05;
  { v1 div v2; the remainder goes to zone 1 }
  DIVIDE = $06;
  { v1 * v2 }
  MULTIPLY = $07;
  { 0..n inclusive (0..254 when n is 255) }
  OP_RANDOM = $08;
  { store an int or a string at <address> }
  SAVE = $09;
  { walk the party to the idx-th member -> curChar }
  LOAD_CHARACTER = $0A;
  { spawn <count> creatures onto the monster list }
  LOAD_MONSTER = $0B;
  { stage the monster id/pic, clamp the distance }
  SETUP_MONSTER = $0C;
  { step the monster one square closer }
  APPROACH = $0D;
  { load/show a portrait or full-screen PIC ($FF = clear) }
  PICTURE = $0E;
  { prompt for a number -> <address> }
  INPUT_NUMBER = $0F;
  { prompt for a string -> <address> }
  INPUT_STRING = $10;
  { print in the message window, continuing }
  PRINT = $11;
  { clear the message window, then print }
  PRINT_CLEAR = $12;
  { pop the GOSUB stack (empty stack -> EXIT) }
  RETURN = $13;
  { (v1=v2) and (v3=v4) -> cmpFlags }
  COMPARE_AND = $14;
  { vertical option menu -> chosen 0-based index }
  VERTICAL_MENU = $15;
  { skip the next command unless cmpFlags[0] }
  IF_EQ = $16;
  { skip the next command unless cmpFlags[1] }
  IF_NE = $17;
  { skip the next command unless cmpFlags[2] }
  IF_LT = $18;
  { skip the next command unless cmpFlags[3] }
  IF_GT = $19;
  { skip the next command unless cmpFlags[4] }
  IF_LE = $1A;
  { skip the next command unless cmpFlags[5] }
  IF_GE = $1B;
  { reset monster scratch, free the treasure list }
  CLEAR_MONSTERS = $1C;
  { sum a party "power" score -> <address> }
  PARTY_STRENGTH = $1D;
  { attribute-keyed party scan -> min/max/avg + found }
  CHECK_PARTY = $1E;
  { switch to another ECL script }
  NEW_ECL = $20;
  { load a 3D map + backdrop }
  LOAD_FILES = $21;
  { set the surprise modifiers off party classes }
  PARTY_SURPRISE = $22;
  { roll d6 twice against those modifiers; the GBVM cell the result goes to keeps nothing }
  SURPRISE = $23;
  { run combat, or enter shop/temple/post-combat }
  OP_COMBAT = $24;
  { GOTO the sel-th of <count> targets }
  ON_GOTO = $25;
  { GOSUB the sel-th of <count> targets }
  ON_GOSUB = $26;
  { stage the money slots + the next combat item list }
  TREASURE = $27;
  { take money/items from one member or the party }
  ROB = $28;
  { the ~COMBAT ~WAIT ~FLEE ~PARLAY encounter menu }
  ENCOUNTER_MENU = $29;
  { read GBVM[base + idx] -> <address> }
  GET_TABLE = $2A;
  { horizontal option bar -> chosen 0-based index }
  HORIZONTAL_MENU = $2B;
  { the ~HAUGHTY ~SLY ~NICE ~MEEK ~ABUSIVE menu }
  PARLAY = $2C;
  { the <address>-as-magic-key engine effect dispatch }
  CALL = $2D;
  { roll and apply damage per the attack bit-field }
  DAMAGE = $2E;
  { v1 and v2, as a byte; also sets cmpFlags }
  OP_AND = $2F;
  { v1 or v2, as a byte; also sets cmpFlags }
  OP_OR = $30;
  { erase the active sprite }
  SPRITE_OFF = $31;
  { party-wide item-id search -> cmpFlags }
  FIND_ITEM = $32;
  { park the cursor at column 1 of the next row }
  PRINT_RETURN = $33;
  { advance the in-game clock by (amount, time unit) }
  CLOCK = $34;
  { write v -> GBVM[base + idx] }
  SAVE_TABLE = $35;
  { add a creature to the party with a morale value }
  ADD_NPC = $36;
  { load the 3D wall/piece sets }
  LOAD_PIECES = $37;
  { run a program (0 main menu / 8 win / 9 camp / 3 halt) }
  OP_PROGRAM = $38;
  { run the character-select prompt }
  WHO = $39;
  OP_DELAY = $3A;
  { find a memorized spell across the party }
  SPELL = $3B;
  { the copy-protection prompt }
  PROTECTION = $3C;
  { redraw the frame, roster, status line and current picture }
  CLEAR_BOX = $3D;
  { remove the current creature; the new current one is kept as savedChar }
  DUMP = $3E;
  { active-effect check on curChar -> cmpFlags }
  FIND_SPECIAL = $3F;
  DESTROY_ITEMS = $40;

implementation

end.
