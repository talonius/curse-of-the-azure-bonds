{ Effect IDs: TEffect.id values passed to AddEffect, RemoveEffect and HasEffect, and indices into EffHndlr's handler
  table. }
unit C_Effect;

interface

const
  { Paladin: against an evil current creature, adds 2 to the saving-throw roll and takes 2 from the attack roll. }
  PROTECTION_FROM_EVIL = 8;
  { Charm changes the creature's team and updates team counts. }
  CHARM = 11;
  { Enlarge is removed by Reduce. }
  ENLARGE = 12;
  { Poison inflicts one point of damage every 10 minutes. }
  POISON_DAMAGE = 15;
  { Read Magic identifies scroll spells. }
  READ_MAGIC = 16;
  { Gnome: adds 1 to the attack roll against a target whose creature type has flag bit 1. }
  GNOME_ATTACK_BONUS = 18;
  { When Slow Poison expires, a still-poisoned creature dies. Neutralize Poison removes the associated effects. }
  SLOW_POISON_END = 22;
  { Spiritual Hammer: the creature holds a +1 hammer while the effect lasts. }
  SPIRITUAL_HAMMER = 23;
  { Marks the invisible target. }
  INVISIBLE = 25;
  { Dwarf: adds 1 to the attack roll against a target whose creature type has flag bit 2. }
  DWARF_ATTACK_BONUS = 26;
  { Mirror Image, removed when the last image is lost. }
  MIRROR_IMAGE = 28;
  { Successful Stinking Cloud save: coughing. }
  STINKING_CLOUD_COUGH = 30;
  { Failed Stinking Cloud save: nausea. Advanced disease also causes helplessness. }
  HELPLESS = 31;
  { Animate Dead is removed by Raise Dead. }
  ANIMATE_DEAD = 32;
  { Blind: -4 to attack and saving rolls and to both AC values. }
  BLIND = 33;
  { Applies both disease effects. }
  DISEASED = 34;
  { Removed by Remove Curse. }
  BESTOW_CURSE = 36;
  { The Strength spell: recalculating Strength adds the bonus this effect carries. }
  STRENGTH = 38;
  { Haste doubles movement and ages the creature; Slow removes it. }
  HASTED = 39;
  { Tracks the caster's Stinking Cloud. }
  CAST_STINKING_CLOUD = 40;
  { Slow halves movement; Haste and potions of speed remove it. }
  SLOWED = 42;
  { Lowers Strength by 1 hourly; at Strength 3 the creature becomes helpless instead. }
  DISEASE_STRENGTH = 43;
  { Deals one point of damage every 10 minutes; at 1 hit point the creature becomes helpless instead. }
  DISEASE_HIT_POINTS = 44;
  { Dwarf and gnome: an attacker of creature type 2 or 10 with icon size 2 takes 4 from its attack roll. }
  DWARF_GIANT_DEFENSE = 47;
  { Gnome: an attacker of creature type 1 with icon size 2 takes 4 from its attack roll. }
  GNOME_BUGBEAR_DEFENSE = 48;
  { Paralyzed by a spell, a gaze or an attack; the creature stops guarding. }
  PARALYZED = 52;
  { Sleep skips creatures already carrying this effect. }
  SLEEP = 53;
  { Poisoned status, removed by Neutralize Poison. }
  POISONED = 55;
  { Prevents movement. }
  IMMOBILE = 58;
  { Carried by the caster while Cloudkill persists. }
  CAST_CLOUDKILL = 91;
  { Halfling, dwarf and gnome: adds 1..5 to the saving-throw roll against saving-throw types 2 and 4. }
  CONSTITUTION_SAVE_BONUS = 97;
  { Elf: a 90% chance to cancel Sleep and Charm. }
  ELF_RESISTANCE = 107;
  { Half-elf: a 30% chance to cancel Charm and Sleep. }
  HALF_ELF_RESISTANCE = 124;
  { Ranger: adds the ranger level to the damage against a target whose creature type has flag bit 3. }
  RANGER_DAMAGE_BONUS = 134;
  { Heal sets a 24-hour cooldown effect checked by CanHeal. }
  RECENTLY_HEALED = 140;
  { Cure sets a seven-day effect. CanCure checks cureDiseaseUses rather than this effect. }
  RECENTLY_CURED = 141;

implementation

end.
