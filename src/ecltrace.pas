{ ECL opcode mnemonics for the interpreter's debug trace, and an empty overlay-priming entry. }
{$O+,F+}
unit EclTrace;

interface

{ Empty routine with no callers. }
procedure NoopEclTrace;

{ Empty entry; calling it loads this overlay. }
procedure PrimeEclTrace;

{ Returns the mnemonic of the current script opcode (scriptOpcode) for the interpreter's debug trace file. Note: the
  subtract opcode's mnemonic is spelled SUBTRAT.
  @param(op Unused.)
  @returns(The mnemonic; unsupported opcodes leave the result unassigned.) }
function OpName(op: Byte): String;

implementation

uses GDConsts, GDVars, C_Ecl;

procedure NoopEclTrace;
begin
end;

procedure PrimeEclTrace;
begin
end;

function OpName(op: Byte): String;
begin
  case GDVars.scriptOpcode of
    C_Ecl.OP_EXIT: OpName := 'EXIT';
    C_Ecl.OP_GOTO: OpName := 'GOTO';
    C_Ecl.GOSUB: OpName := 'GOSUB';
    C_Ecl.COMPARE: OpName := 'COMPARE';
    C_Ecl.ADD: OpName := 'ADD';
    C_Ecl.SUBTRACT: OpName := 'SUBTRAT';
    C_Ecl.DIVIDE: OpName := 'DIVIDE';
    C_Ecl.MULTIPLY: OpName := 'MULTIPLY';
    C_Ecl.OP_RANDOM: OpName := 'RANDOM';
    C_Ecl.SAVE: OpName := 'SAVE';
    C_Ecl.LOAD_CHARACTER: OpName := 'LOAD CHARACTER';
    C_Ecl.LOAD_MONSTER: OpName := 'LOAD MONSTER';
    C_Ecl.SETUP_MONSTER: OpName := 'SETUP MONSTER';
    C_Ecl.APPROACH: OpName := 'APPROACH';
    C_Ecl.PICTURE: OpName := 'PICTURE';
    C_Ecl.INPUT_NUMBER: OpName := 'INPUT NUMBER';
    C_Ecl.INPUT_STRING: OpName := 'INPUT STRING';
    C_Ecl.PRINT: OpName := 'PRINT';
    C_Ecl.PRINT_CLEAR: OpName := 'PRINTCLEAR';
    C_Ecl.RETURN: OpName := 'RETURN';
    C_Ecl.COMPARE_AND: OpName := 'COMPARE AND';
    C_Ecl.VERTICAL_MENU: OpName := 'VERTICAL MENU';
    C_Ecl.IF_EQ: OpName := 'IF = ';
    C_Ecl.IF_NE: OpName := 'IF <>';
    C_Ecl.IF_LT: OpName := 'IF <';
    C_Ecl.IF_GT: OpName := 'IF >';
    C_Ecl.IF_LE: OpName := 'IF <=';
    C_Ecl.IF_GE: OpName := 'IF >=';
    C_Ecl.CLEAR_MONSTERS: OpName := 'CLEARMONSTERS';
    C_Ecl.PARTY_STRENGTH: OpName := 'PARTYSTRENGTH';
    C_Ecl.CHECK_PARTY: OpName := 'CHECKPARTY';
    C_Ecl.NEW_ECL: OpName := 'NEWECL';
    C_Ecl.LOAD_FILES: OpName := 'LOAD FILES';
    C_Ecl.LOAD_PIECES: OpName := 'LOAD PIECES';
    C_Ecl.PARTY_SURPRISE: OpName := 'PARTY SURPRISE';
    C_Ecl.SURPRISE: OpName := 'SURPRISE';
    C_Ecl.OP_COMBAT: OpName := 'COMBAT';
    C_Ecl.ON_GOTO: OpName := 'ON GOTO';
    C_Ecl.ON_GOSUB: OpName := 'ON GOSUB';
    C_Ecl.TREASURE: OpName := 'TREASURE';
    C_Ecl.ROB: OpName := 'ROB';
    C_Ecl.ENCOUNTER_MENU: OpName := 'ENCOUNTER MENU';
    C_Ecl.GET_TABLE: OpName := 'GETTABLE';
    C_Ecl.HORIZONTAL_MENU: OpName := 'HORIZONTAL MENU';
    C_Ecl.PARLAY: OpName := 'PARLAY';
    C_Ecl.CALL: OpName := 'CALL';
    C_Ecl.DAMAGE: OpName := 'DAMAGE';
    C_Ecl.OP_AND: OpName := 'AND';
    C_Ecl.OP_OR: OpName := 'OR';
    C_Ecl.SPRITE_OFF: OpName := 'SPRITE OFF';
    C_Ecl.FIND_ITEM: OpName := 'FIND ITEM';
    C_Ecl.PRINT_RETURN: OpName := 'PRINT RETURN';
    C_Ecl.CLOCK: OpName := 'ECL CLOCK';
    C_Ecl.SAVE_TABLE: OpName := 'SAVE TABLE';
    C_Ecl.ADD_NPC: OpName := 'ADD NPC';
    C_Ecl.OP_PROGRAM: OpName := 'PROGRAM';
    C_Ecl.WHO: OpName := 'WHO';
    C_Ecl.OP_DELAY: OpName := 'DELAY';
    C_Ecl.SPELL: OpName := 'SPELL';
    C_Ecl.PROTECTION: OpName := 'PROTECTION';
    C_Ecl.CLEAR_BOX: OpName := 'CLEAR BOX';
    C_Ecl.DUMP: OpName := 'DUMP';
    C_Ecl.FIND_SPECIAL: OpName := 'FIND SPECIAL';
    C_Ecl.DESTROY_ITEMS: OpName := 'DESTROY ITEMS';
  end;
end;

begin
end.
