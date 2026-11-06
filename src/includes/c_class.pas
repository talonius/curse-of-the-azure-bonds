{ Class values (TCreature.charClass): single classes 0..7, then multi-class combinations 8..16. }
unit C_Class;

interface

const
  CLERIC = 0;
  FIGHTER = 2;
  PALADIN = 3;
  RANGER = 4;
  MAGE = 5;
  CLERIC_FIGHTER = 8;
  CLERIC_FIGHTER_MAGE = 9;
  CLERIC_RANGER = 10;
  FIGHTER_THIEF = 14;
  FIGHTER_MAGE_THIEF = 15;
  MAGE_THIEF = 16;

  { Indices into TCreature.classLevels and oldClassLevels (one level per class). }
  CLERIC_LEVEL = 0;
  FIGHTER_LEVEL = 2;
  PALADIN_LEVEL = 3;
  RANGER_LEVEL = 4;
  MAGE_LEVEL = 5;
  THIEF_LEVEL = 6;

implementation

end.
