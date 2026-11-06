{ Creature status values (TCreature.status). }
unit C_Status;

interface

const
  OKAY = 0;
  ANIMATED = 1;
  { fled combat }
  RUNNING = 3;
  UNCONSCIOUS = 4;
  DYING = 5;
  DEAD_STATUS = 6;
  { petrified }
  STONED = 7;
  { removed from play: disintegrated / dispelled }
  GONE = 8;

implementation

end.
