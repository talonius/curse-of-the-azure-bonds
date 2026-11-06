{ Spell values: the spell lists, the pending flag and id mask of a spell byte, and the spell ids the code names. }
unit C_Spell;

interface

const
  { The spell list a spell belongs to (TSpellRec.castClass), also the first index of a character's spell slots: cleric,
    druid (cast by rangers), magic-user, and special spells that no class casts. }
  CLERIC_LIST = 0;
  DRUID_LIST = 1;
  MAGE_LIST = 2;
  SPECIAL_LIST = 3;
  { Spell bytes hold the spell ID in bits 0..6; bit 7 marks a pending memorize or scribe request. }
  PENDING_FLAG = $80;
  ID_MASK = $7F;
  { The cure spells: the AI looks for a wounded ally before casting Cure Light Wounds, and Camp's Fix command rolls all
    three. }
  CURE_LIGHT_WOUNDS = 3;
  CURE_SERIOUS_WOUNDS = 58;
  CURE_CRITICAL_WOUNDS = 71;

implementation

end.
