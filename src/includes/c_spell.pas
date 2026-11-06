{ Spell values: the spell lists, the pending flag and id mask of a spell byte, and the spell ids the code names. }
unit C_Spell;

interface

const
  { The spell list a spell belongs to (TSpellRec.castClass), also the first index of a character's spell slots: 0
    cleric, 1 druid (cast by rangers), 2 magic-user, 3 special spells that no class casts. }
  CLERIC_LIST = 0;
  MAGE_LIST = 2;
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
