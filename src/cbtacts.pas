{ Combat actions: movement, attacks, turning undead, spell casting and targeting, and the special attacks some monsters
  make. }
{$O+,F+}
{$A-}
{$R-}
{$S-}
unit CbtActs;

interface

uses Types, Crt, SoundDrv, CbtMap, FxEngine, CharHlp, Pathing, MapTiles, TextRend, Magic, ViewChar, ClassCal, GameIo,
  MenuCore, EclTrace, Border, GDConsts, GDVars, C_Keys, C_Status, C_Effect, C_Class, C_Terr, C_Gbvm,
  C_Spell;

{ Resets a creature for a new round: the combat record's casting and attack flags, its current attacks (then the
  secondary attacks, after the condition-18 effects), its sweep budget (its attack level), its initiative and its
  movement. Initiative is 1d6 plus the Dexterity missile adjustment, at least 1, less 6 when the creature's side is
  surprised, and 0 for a disabled creature or a result outside 0..20.
  @param(creature The creature starting the round.) }
procedure BeginRound(creature: Types.PCreature);

{ Computes a creature's movement in half-steps: its current movement plus, for the party, the zone's movement modifier
  (a result outside 1..96 becomes 1), doubled and then adjusted by its condition-18 effects, which run with the movement
  flag set.
  @param(creature The creature whose movement is computed.)
  @returns(The movement in half-steps.) }
function CalcCreatureMovement(creature: Types.PCreature): Byte;

{ Rolls one attack's damage into GDVars.damage: the current damage dice of the attack phase plus its modifier,
  multiplied on a backstab by (thief level - 1) div 4 + 2, where the thief level counts earlier thief levels while
  ClassCal.EarlierClassActive allows them. It then clears the damage element mask and fires attacker's condition-4 and
  defender's condition-5 effects. Note: GDVars.damage is a Byte, so the test for a negative total never passes and a
  negative total wraps.
  @param(attacker The creature dealing the damage.)
  @param(defender The creature hit; it is tested for a backstab.)
  @param(phase Attack phase, 1 or 2, whose dice and modifier are used.) }
procedure CalcWeaponDamage(attacker, defender: Types.PCreature; phase: Byte);

{ Prints the attack message and inflicts the damage. Nonzero damage stops the defender casting this round and loses a
  spell it is casting. A defender that goes down is reported as dying or killed, loses its hit-point-0 effects, runs its
  condition-13 effects and, if still disabled, goes to CbtMap.CreatureDowned.
  @param(attacker The creature attacking.)
  @param(defender The creature attacked.)
  @param(manner 1 from behind, 2 a backstab, 3 slays a helpless target; anything else is a plain attack.)
  @param(damage Hit points inflicted on a hit.)
  @param(shownDamage The damage figure printed.)
  @param(isHit True for a hit, False for a miss.) }
procedure ProcessAttackResult(attacker, defender: Types.PCreature; manner, damage, shownDamage: Byte; isHit: Boolean);

{ Moves a creature one cell in a direction. The step costs the terrain cost times 2 half-steps, times 3 on a diagonal;
  with too few left, movement drops to 0 but the step is still taken. The view follows the mover (faster in quick
  fight). The step plays the step sound, resets the creature's flanking counts and lets guarding enemies attack, and a
  mover left out of play or helpless loses the rest of its movement.
  @param(creature The creature moving.)
  @param(direction Direction of the step, 0..7 clockwise from north.) }
procedure CombatMoveCreature(creature: Types.PCreature; direction: Byte);

{ Gives each enemy adjacent to a creature before a step, but not after it, one free attack on the mover, made as from
  behind, while the mover stays up. Helpless enemies, enemies an effect forbids to attack, and enemies draining blood or
  holding with a bite are skipped. An enemy with no initiative left that has already been attacked this round needs the
  mover in the five directions in front of it. The attack uses the enemy's highest phase with attacks left, granting one
  attack when that phase has no attacks left, and the enemy's own target is kept.
  @param(creature The creature about to move.)
  @param(direction Direction of the step, 0..7 clockwise from north.) }
procedure AttacksOfOpportunity(creature: Types.PCreature; direction: Byte);

{ Tries to flee. It succeeds automatically with no enemy in the target list, and otherwise when the creature's movement
  in whole steps beats the fastest enemy's, or on 1 in 2 when they tie. Success takes the creature out of play as
  running, with 'Got Away'; failure prints 'Escape is blocked'. The creature's actions end either way.
  @param(creature The creature fleeing.)
  @returns(The result of ending its actions.) }
function AttemptFlee(creature: Types.PCreature): Boolean;

{ Sets a creature's current attacks for the round. It starts from the weapon's rate of fire (at least 2) when it has a
  ranged weapon with ammunition, else from its base attacks, both in half-attacks; applies its condition-18 effects and
  AttacksFromRate, and caps a ranged weapon by its ammunition. Once an attack has been made, the result replaces the
  current attacks when it is below the previous count (in melee, below twice it). Note: otherwise the current attacks
  keep the base attacks value, in half-attacks, rather than the previous count.
  @param(creature The creature whose attacks are recalculated.) }
procedure RecalcAttacksLeft(creature: Types.PCreature);

{ Converts half-attacks to attacks: adds 1 on odd rounds, then halves.
  @param(rate The rate in half-attacks.)
  @returns(The whole attacks for this round.) }
function AttacksFromRate(rate: Byte): Byte;

{ Sweeps level-0 enemies. When the defender is an adjacent level-0 enemy, the attacker's sweep budget exceeds its
  current attacks, and more adjacent level-0 enemies stand around it than it has current attacks, the attacker makes one
  attack on each of up to its sweep budget of them, the defender first.
  @param(att The creature attacking.)
  @param(def The enemy chosen to attack.)
  @returns(True if the attacker swept.) }
function SweepAttack(att, def: Types.PCreature): Boolean;

{ Checks whether effects let one creature attack another. True when the target is the attacker itself, False when the
  target is nil. Otherwise the target's condition-1 effects run, then, unless they vetoed, the attacker's condition-0
  effects with the target as its temporary target; an effect vetoes by setting the targeting veto flag.
  @param(attacker The creature that would attack.)
  @param(target The creature it would attack, or nil.)
  @returns(True when the attack is allowed.) }
function CanTarget(attacker, target: Types.PCreature): Boolean;

{ Turns undead. One d20 roll is compared with the turning table for up to 1d12 targets, lowest-level undead first, until
  one resists. The table row is the undead's level; the column is the cleric level for a level total of 1..8, 9 for
  9..13 and 10 otherwise, where the total counts earlier cleric levels while ClassCal.EarlierClassActive allows them. A
  positive table value turns the target and zero or a negative one destroys it; while fewer than six undead have been
  affected, a destruction by a negative value does not use up the last of the count. The creature's actions end. Note:
  the column for a total of 1..8 is the current cleric level alone, so earlier cleric levels pick the band but not the
  column.
  @param(creature The cleric turning undead.) }
procedure CombatTurnUndead(creature: Types.PCreature);

{ Finds the lowest-level unturned undead in the target list (any range); equal levels keep the earlier one, and undead
  of level 13 or more are never picked.
  @param(creature The creature turning undead.)
  @param(target Receives the undead found, or nil.)
  @returns(True if a target was found.) }
function FindTurnUndeadTarget(creature: Types.PCreature; var target: Pointer): Boolean;

{ Records an attack on a defender for flanking: the defender's count of attackers goes up, and the angle between its
  facing and the attack's direction (0..4) is added to its spread, mod 8.
  @param(attacker The attacker.)
  @param(defender The defender.) }
procedure NoteAttackDirection(attacker, defender: Types.PCreature);

{ Makes an attack. Unless it comes from behind or defender has already been attacked twice this round, defender's icon
  turns toward attacker and its facing becomes the direction of the attack; otherwise, while defender's icon is visible,
  an attack not from behind reverses defender's facing. attacker turns toward defender and takes it as its target, and
  missiles fly for weapon and for a readied weapon of type 47 or 101. If attacks remain, RollAttacks runs; weapon then
  loses the primary attacks made from its quantity, and once it is used up it is removed, an expended throwable weapon
  (other than special $89) dropping into the treasure pile. Note: the readied weapon's type is read without checking
  that there is one.
  @param(attacker The creature attacking.)
  @param(defender The creature attacked.)
  @param(fromBehind True for an attack from behind: defender keeps its facing.)
  @param(weapon The missile or thrown item, or nil for melee.)
  @param(done Set True when attacker's actions for the round are over.) }
procedure MakeAttack(attacker, defender: Types.PCreature; fromBehind: Boolean; weapon: Types.PItem; var done: Boolean);

{ Raises a defense value for range. With a ranged weapon the band is (range - 1) div 3 steps; a defender more than one
  band away adds 2 and more than two bands away 3 more. A weapon of range 3 or less has a band of 0, so any distance
  adds both. Melee adds nothing.
  @param(attacker The creature attacking.)
  @param(defender The creature attacked.)
  @param(armorClass The defense value, raised in place.) }
procedure ApplyRangePenalty(attacker, defender: Types.PCreature; var armorClass: Byte);

{ Finds a Cure Light Wounds target in the creature's own cell or the eight around it. Candidates are the wounded ally
  with the fewest hit points (the creature itself, checked last, also wins whenever below half its maximum) and the last
  downed body, not dead, stoned or gone, found on a corpse cell. The body wins unless no body was found or the ally has
  7 hit points or fewer.
  @param(creature The caster.)
  @param(tgt Receives the target, or nil.)
  @returns(True if a target was found.) }
function FindCureTarget(creature: Types.PCreature; var tgt: Types.PCreature): Boolean;

{ Builds the spell's target list from the low nibble of its target type. 0: the caster. 5: weighted picks until a second
  or later pick brings the total weight past a budget (spell $4F: caster level, weighted by icon size; others: 2d4,
  weighted by level). 15: the picked creature, or the area around a picked bare cell. 8..14: everything within (target
  type and 7) of the picked cell. Others: (target type and 3) + 1 separate picks. A repeated pick is refused; for the
  computer it uses up a pick, or one point of the weight budget. Note: the radius for a bare cell under type 15 is
  (target type and $F) shr 4, which is always 0, and when the separate picks find nothing the target cell is read
  through the entry before the first target.
  @param(spell The spell being cast.)
  @param(aiControlled 0 when the player aims; nonzero for computer-controlled targeting.)
  @param(cast Set True; set False when the pick for types 8..15 fails or the separate picks find nothing.) }
procedure SelectCombatTargets(spell, aiControlled: Byte; var cast: Boolean);

{ Picks (from the spell menu, when no spell is given) and checks a spell, rejecting those not allowed in combat. A
  casting delay (the casting time div 3) of 0 casts it at once and ends the caster's actions; otherwise the caster
  'Begins Casting': the spell is recorded as being cast and initiative drops by the delay (to at least 1), so it
  resolves on a later action. Note: after an immediate cast, the result is the True of ending the caster's actions,
  whatever the cast itself reported.
  @param(spell The spell to cast, or 0 to choose one from the menu.)
  @param(ai 0 redraws the combat screen first; passed on to the cast as its computer-controlled flag.)
  @param(cast Set True when a spell was cast or begun, False otherwise.) }
procedure CastSpellCombat(spell, ai: Byte; var cast: Boolean);

{ Confirms an attack on an ally; enemies and quick-fighting attackers pass unasked. Yes sets the attacked-allies flags,
  each okay NPC turns hostile and drops its target, and the teams are recounted.
  @param(attacker The attacker.)
  @param(defender The defender.)
  @returns(True when the attack goes ahead.) }
function CheckAttackAlly(attacker, defender: Types.PCreature): Boolean;

{ Runs target selection with cycling, the free cursor and confirmation. Targets the creature may not attack are skipped.
  N and P cycle, an arrow key or M (Manual, whose code equals RIGHT's) starts the free cursor, T confirms, C recenters,
  and E or Escape exits.
  @param(creature The creature aiming.)
  @param(range The reach in whole steps; 255 means the readied weapon's range minus 1 (1 unarmed).)
  @param(weaponMode 1 for weapon attacks, 0 for spell casting.)
  @param(groundOk Nonzero lets the free cursor pick a bare cell.)
  @param(creatureOk Nonzero lets a creature be chosen; passed on as creatureOk.)
  @param(done True when a target was chosen.)
  @param(tgt Receives the choice, a creature pointer followed by its arena cell, passed untyped.) }
procedure CombatAimMenu(creature: Types.PCreature; range, weaponMode, groundOk, creatureOk: Byte; var done: Boolean;
                        var tgt);

{ Checks for a backstab: the attacker must be a thief (or have thief levels from an earlier class that is active), with
  no weapon or one of item types 7, 8, 35..37 or 97; the defender must be small, have been attacked more than once this
  round, and face away from the attacker.
  @param(attacker The creature attacking.)
  @param(defender The creature attacked.)
  @returns(True for a backstab.) }
function IsBackstab(attacker, defender: Types.PCreature): Boolean;

{ Finds the direction from one creature to another, using eight sectors whose slope thresholds are 106/256 and 618/256;
  the same cell gives 0.
  @param(creature The creature looking.)
  @param(other The creature looked at.)
  @returns(The direction, 0..7 clockwise from north.) }
function DirTowardTarget(creature, other: Types.PCreature): Byte;

{ Flies a missile from attacker to defender. It plays the launch sound, then builds the icon for weapon's item type with
  a sound for its kind: item types 9, $15, $1C, $1F, $49 and $64 get an icon drawn for the direction of flight, and the
  others a fixed icon, some in four frames at a slower pace.
  @param(attacker The creature shooting.)
  @param(defender The creature shot at.)
  @param(weapon The missile or thrown item.) }
procedure AnimateMissile(attacker, defender: Types.PCreature; weapon: Types.PItem);

{ Sets the hostiles' hit-point percentage: the enabled hostiles' current hit points as a percentage of the hostiles'
  combined maximum hit points, disabled ones included, rounded down to a multiple of five; it is left unchanged when
  there are no hostiles. Note: the totals are Words multiplied by 20, so above 3276 hit points the percentage wraps. }
procedure UpdateHostileHpPercent;

{ Finds the fastest enabled enemy's movement in whole steps, with no range or line-of-sight check.
  @param(creature The creature whose enemies are checked.)
  @returns(The highest enemy movement, in whole steps.) }
function HighestEnemyMovement(creature: Types.PCreature): Byte;

{ Makes sure the creature's combat record holds a target. An existing lock is kept (without a range check) unless
  forceNew is set or it is now an ally, disabled or vetoed by CanTarget. Otherwise it makes up to 20 random picks among
  the enemies within range, dropping vetoed ones. If that fails a second pass repeats it, with the arena's distance mode
  set unless forceNew; there relaxed <> 0 accepts a pick without CanTarget.
  @param(creature The creature looking for a target.)
  @param(range The search range, in whole steps.)
  @param(relaxed Nonzero lets the second pass skip CanTarget.)
  @param(forceNew Nonzero drops any existing target and keeps the normal distance mode.)
  @returns(True if a target is held.) }
function AcquireTarget(creature: Types.PCreature; range, relaxed, forceNew: Byte): Boolean;

{ Effect handler for engulfing: when both primary attacks hit and the locked target is up and not already held, the
  target is engulfed. It becomes immobile and gains effect $0D with strength 2d4, and the attacker gains effect $8B
  naming the target's slot, which AttackClawRake then serves.
  @param(cr The engulfing creature.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure AttackEngulf(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Fires up to four eye rays, starting with a fresh target. Each eye fires the first unused ray whose range covers the
  target: disintegrate (distance 2 or less), stone (3), death (4), each allowing a saving throw, or a 2d8+1 wound (5);
  when no ray applies it casts the first unused of spells $54, $37 and $15. After each ray AcquireTarget checks the
  target again, keeping it while it is still a valid enemy. Note: the line-of-sight result is never tested, so rays also
  fire at targets out of sight.
  @param(cr The creature with the eyes.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure AttackEyeRays(cr: Types.PCreature; effect: Types.PCombatRec; removed: Byte);

{ Handler for effect $8B, which AttackEngulf puts on the attacker. combat is the effect record viewed as a combat
  record: its initiative byte holds the victim's slot. While the hold lasts, each trigger makes two 2d8 attacks (plus
  the current damage modifier) on the victim as from behind and ends the attacker's actions; when the victim drops, the
  hold, its immobility and effect $0D end. On removal, or when either side is down, the victim loses immobility and $0D,
  and unless already being removed the record's attackPhase byte is cleared and $8B removed.
  @param(cr The engulfing creature.)
  @param(combat The effect record, viewed as a combat record.)
  @param(secondary Nonzero when the effect is being removed.) }
procedure AttackClawRake(cr: Types.PCreature; combat: Types.PCombatRec; secondary: Byte);

{ Handler for effect $90, which AttackHug puts on the attacker; it works like AttackClawRake with one 2d8 attack, and it
  removes immobility but not $0D from the victim.
  @param(creature The hugging creature.)
  @param(effect The effect record, viewed as a combat record: its initiative byte holds the victim's slot.)
  @param(removed Nonzero when the effect is being removed.) }
procedure BiteAndHold(creature: Types.PCreature; effect: Types.PCombatRec; removed: Byte);

{ Effect handler for hugging: when the last attack roll was 18 or more, the locked target is held. It becomes immobile
  and the attacker gains effect $90 naming its slot, which BiteAndHold then serves.
  @param(cr The hugging creature.)
  @param(effect Unused.)
  @param(removed Unused.) }
procedure AttackHug(cr: Types.PCreature; effect: Pointer; removed: Boolean);

{ Debug victory: active when the second command-line parameter equals the developer keyword GDVars.commandText. Each
  hostile drops dead, each creature's actions end and the view is rebuilt.
  @returns(True when the cheat ran.) }
function VictoryCheat: Boolean;

{ Calls the priming entry of each overlay the combat actions use, so the overlay manager loads them. }
procedure PrimeCbtActs;

implementation

type

  { Acquired target: a creature pointer followed by its arena coordinates. }
  TTgtRec = record
    cr: Types.PCreature;
    cellX: Byte;
    cellY: Byte;
    cellTail: Byte;
  end;

var
  { The turning table as CbtActs reads it: undead levels 11 and 12 run past its end into the menus that follow. }
  turnUndeadTbl: array[1..12, 1..10] of ShortInt absolute GDConsts.turnUndeadResults;

procedure GuardersAttack(creature: Types.PCreature); forward;

procedure RollAttacks(att, def: Types.PCreature; fromBehind: Boolean; var done: Boolean; other: Types.PItem); forward;

function SelectSpellTarget(spellId, aiControlled, groundOk: Byte; var target: TTgtRec): Boolean; forward;

procedure BeginRound(creature: Types.PCreature);
var
  { Unused in this version; see the other implementations of this routine. }
  i: Byte;
begin
  with Types.PCreature(creature)^.combatAddr^ do begin
    spellCast := 0;
    castAllowed := 1;
    itemUseAllowed := 1;
    madeAttack := 0;
    attackPhase := 2;
    CbtActs.RecalcAttacksLeft(creature);
    GDVars.movementAttacks := Types.PCreature(creature)^.attacks2;
    GDVars.computingMove := 0;
    FxEngine.TriggerEffectsWithCondition(18, Types.PCreature(creature));
    Types.PCreature(creature)^.curAttacks[2] := CbtActs.AttacksFromRate(GDVars.movementAttacks);
    sweepBudget := Types.PCreature(creature)^.attackLevel;
    if Types.PCreature(creature)^.enabled <> 0 then begin
      initiative := FxEngine.RollDice(1, 6) + CharHlp.DexMissileAdjust(Types.PCreature(creature));
      if initiative < 1 then
        initiative := 1;
      if Byte((Types.PCreature(creature)^.hostile + 1) and Integer(GDVars.zone1^[C_Gbvm.SURPRISE])) <> 0 then
        Dec(initiative, 6);
      if (initiative < 0) or (initiative > 20) then
        initiative := 0;
    end else
      initiative := 0;
  end;
  Types.PCreature(creature)^.combatAddr^.movement := CbtActs.CalcCreatureMovement(creature);
end;

function CalcCreatureMovement(creature: Types.PCreature): Byte;
var
  movement: Byte;
begin
  movement := Types.PCreature(creature)^.movementCur;
  if Types.PCreature(creature)^.hostile = 0 then
    movement := movement + GDVars.zone1^[C_Gbvm.PARTY_MOVE_MODIFIER];
  GDVars.computingMove := 1;
  if (movement < 1) or (movement > 96) then
    movement := 1;
  GDVars.movementAttacks := movement * 2;
  FxEngine.TriggerEffectsWithCondition(18, Types.PCreature(creature));
  GDVars.computingMove := 0;
  CalcCreatureMovement := GDVars.movementAttacks;
end;

procedure CalcWeaponDamage(attacker, defender: Types.PCreature; phase: Byte);
begin
  GDVars.damage := FxEngine.RollDamageDice(attacker^.curRolls[phase], attacker^.curDice[phase])
      + attacker^.curMod[phase];
  if GDVars.damage < 0 then
    GDVars.damage := 0;
  if CbtActs.IsBackstab(attacker, defender) then
    GDVars.damage := GDVars.damage *
      ((attacker^.classLevels[C_Class.THIEF_LEVEL] +
        attacker^.oldClassLevels[C_Class.THIEF_LEVEL] * ClassCal.EarlierClassActive(attacker) - 1) div 4 + 2);
  GDVars.elementMask := 0;
  FxEngine.TriggerEffectsWithCondition(4, attacker);
  FxEngine.TriggerEffectsWithCondition(5, defender);
end;

procedure ProcessAttackResult(attacker, defender: Types.PCreature; manner, damage, shownDamage: Byte; isHit: Boolean);
var
  row: Byte;
  message: String[80];
begin
  case manner of
    2: message := '-Backstabs-';
    3: message := 'slays helpless';
  else
    message := 'Attacks';
  end;
  CharHlp.PrintCreatureMessage(attacker, message, 10, False);
  row := 12;
  CharHlp.DisplayCreatureName(defender, 23, row, False);
  Inc(row);
  if manner = 1 then
    message := '(from behind) '
  else
    message := '';
  if isHit then begin
    if manner = 3 then
      message := 'with one cruel blow'
    else begin
      message := message + 'Hitting for ' + CharHlp.Uint8Str(shownDamage);
      if shownDamage = 1 then
        message := message + ' point '
      else
        message := message + ' points ';
      message := message + 'of damage';
    end;
    CharHlp.InflictDamage(defender, damage);
  end else
    message := message + 'and Misses';
  if defender^.status <> C_Status.GONE then
    TextRend.DisplayMessageWindow(23, row, 38, row + 3, 10, 0, True, message);
  row := GDVars.curRow + 1;
  if damage > 0 then begin
    defender^.combatAddr^.castAllowed := 0;
    if defender^.combatAddr^.spellCast > 0 then begin
      TextRend.PauseOnly;
      CharHlp.PrintCreatureMessage(defender, 'lost a spell', 12, True);
      CharHlp.RemoveSpell(defender, defender^.combatAddr^.spellCast);
      defender^.combatAddr^.spellCast := 0;
    end else
      TextRend.PauseOnly;
  end else
    TextRend.PauseOnly;
  if defender^.enabled = 0 then begin
    CharHlp.PrintCreatureMessage(defender, 'goes down', row, False);
    Inc(row, 2);
    if defender^.status = C_Status.DYING then
      TextRend.DisplayString(23, row, LightGreen, 0, 'and is Dying');
    if defender^.status in [C_Status.DEAD_STATUS, C_Status.STONED, C_Status.GONE] then
      CharHlp.PrintCreatureMessage(defender, 'is killed', row, False);
    Inc(row, 2);
    FxEngine.RemoveEffectsHp0(defender);
    FxEngine.TriggerEffectsWithCondition(13, defender);
    if defender^.enabled = 0 then
      CbtMap.CreatureDowned(defender)
    else
      TextRend.PauseOnly;
  end;
  CharHlp.ClearMessageWindow;
end;

{ Lets guarding enemies strike a creature that moved next to them: each adjacent enemy that is guarding and not helpless
  spends its guard on one free attack, while the mover stays up.
  @param(creature The creature that moved.) }
procedure GuardersAttack(creature: Types.PCreature);
var
  count: Byte;
  index: Byte;
  guarder: Types.PCreature;
  done: Boolean;
begin
  count := CharHlp.CountTargets(creature, 1);
  for index := 1 to count do
    if creature^.enabled <> 0 then begin
      guarder := GDVars.combatCreatures[GDVars.combatTargetSlots[index]];
      if (guarder^.combatAddr^.guarding <> 0) and (not CharHlp.IsHelpless(guarder)) then begin
        CbtMap.ScrollView(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), 2, 8);
        guarder^.combatAddr^.guarding := 0;
        CbtActs.NoteAttackDirection(guarder, creature);
        CbtActs.MakeAttack(guarder, creature, False, nil, done);
      end;
    end;
end;

procedure CombatMoveCreature(creature: Types.PCreature; direction: Byte);
var
  moveCost: Byte;
  slot: Byte;
  nx: ShortInt;
  ny: ShortInt;
  x: ShortInt;
  y: ShortInt;
begin
  slot := CbtMap.CombatSlot(Types.PCreature(creature));
  x := GDVars.arenaSlots[slot].x;
  y := GDVars.arenaSlots[slot].y;
  nx := x + GDConsts.directionDx[direction];
  ny := y + GDConsts.directionDy[direction];
  if Odd(direction) then
    moveCost := GDConsts.terrainInfo[GDVars.combatArena^.cells[ny, nx]].cost * 3
  else
    moveCost := GDConsts.terrainInfo[GDVars.combatArena^.cells[ny, nx]].cost * 2;
  if moveCost > Types.PCreature(creature)^.combatAddr^.movement then
    Types.PCreature(creature)^.combatAddr^.movement := 0
  else
    Dec(Types.PCreature(creature)^.combatAddr^.movement, moveCost);
  moveCost := 1;
  if Types.PCreature(creature)^.quickfight <> 0 then begin
    moveCost := 3;
    if not CbtMap.ViewCoordsValid(nx - GDVars.combatArena^.focusX, ny - GDVars.combatArena^.focusY) then
      if GDVars.mapVisible then
        CbtMap.ScrollView(x, y, 2, 8);
  end;
  if GDVars.mapVisible then
    CbtMap.UpdateCombatMapTile(0, 0, slot);
  GDVars.arenaSlots[slot].x := nx;
  GDVars.arenaSlots[slot].y := ny;
  CbtMap.BuildArenaArrays;
  if GDVars.mapVisible then
    CbtMap.ScrollView(nx, ny, moveCost, 8);
  Types.PCreature(creature)^.combatAddr^.flankCount := 0;
  Types.PCreature(creature)^.combatAddr^.flankSpread := 0;
  SoundDrv.SoundCommand(GDConsts.sndFootstep);
  CbtActs.GuardersAttack(creature);
  if (Types.PCreature(creature)^.enabled = 0) or CharHlp.IsHelpless(Types.PCreature(creature)) then
    Types.PCreature(creature)^.combatAddr^.movement := 0;
end;

procedure AttacksOfOpportunity(creature: Types.PCreature; direction: Byte);
var
  candidates: array[1..12] of Byte;
  effect: Types.PEffect;
  stillAdjacent: Boolean;
  attacked: Boolean;
  slot: Byte;
  { Unused in this version; see the other implementations of this routine. }
  count: Byte;
  candidateCount: Byte;
  countAfter: Byte;
  scanPos: Byte;
  index: Byte;
  phasePos: Byte;
  phase: Byte;
  facingScan: Byte;
  attacker: Types.PCreature;
  savedTarget: Pointer;
begin
  FillChar(candidates, SizeOf(candidates), 0);
  slot := CbtMap.CombatSlot(Types.PCreature(creature));
  candidateCount := CharHlp.CountTargets(creature, 1);
  if candidateCount = 0 then
    Exit;
  for index := 1 to candidateCount do
    candidates[index] := GDVars.combatTargetSlots[index];
  Inc(GDVars.arenaSlots[slot].x, GDConsts.directionDx[direction]);
  Inc(GDVars.arenaSlots[slot].y, GDConsts.directionDy[direction]);
  countAfter := CharHlp.CountTargets(creature, 1);
  Dec(GDVars.arenaSlots[slot].x, GDConsts.directionDx[direction]);
  Dec(GDVars.arenaSlots[slot].y, GDConsts.directionDy[direction]);
  for index := 1 to candidateCount do begin
    stillAdjacent := False;
    for scanPos := 1 to countAfter do
      if GDVars.combatTargetSlots[scanPos] = candidates[index] then
        stillAdjacent := True;
    if stillAdjacent then
      candidates[index] := 0;
  end;
  for index := 1 to candidateCount do
    if candidates[index] > 0 then
      if Types.PCreature(creature)^.enabled <> 0 then begin
        GDVars.combatRedraw := True;
        GDVars.mapVisible := True;
        attacked := False;
        attacker := GDVars.combatCreatures[candidates[index]];
        if not CharHlp.IsHelpless(attacker) then
          if CbtActs.CanTarget(attacker, creature) then
            if not CharHlp.HasEffect(attacker, 75, effect) then
              if not CharHlp.HasEffect(attacker, 74, effect) then
                for facingScan := attacker^.combatAddr^.direction + 6
                    to attacker^.combatAddr^.direction + 10 do
                  if not attacked then
                    if (attacker^.combatAddr^.initiative > 0)
                       or (attacker^.combatAddr^.flankCount = 0)
                       or
                         Pathing.IsDirToward(CbtMap.CombatCellX(attacker), CbtMap.CombatCellY(attacker),
                                             CbtMap.CombatCellX(Types.PCreature(creature)),
                                             CbtMap.CombatCellY(Types.PCreature(creature)), facingScan mod 8)
                    then begin
                      phase := 1;
                      if attacker^.attacks = 0 then
                        phase := 2;
                      for phasePos := 1 to 2 do
                        if attacker^.curAttacks[phasePos] > 0 then
                          phase := phasePos;
                      if attacker^.curAttacks[phase] = 0 then
                        attacker^.curAttacks[phase] := 1;
                      attacker^.combatAddr^.attackPhase := phase;
                      savedTarget := attacker^.combatAddr^.other;
                      CbtActs.MakeAttack(attacker, creature, True, nil, GDVars.combatMenuExtendedKey);
                      attacked := True;
                      attacker^.combatAddr^.other := savedTarget;
                      if Types.PCreature(creature)^.enabled <> 0 then begin
                        GDVars.combatRedraw := True;
                        CharHlp.CombatPrintCreatureInfo(Types.PCreature(creature));
                      end;
                    end;
      end;
end;

function AttemptFlee(creature: Types.PCreature): Boolean;
var
  hasEscaped: Boolean;
  enemyMove: Byte;
  creatureMove: Byte;
begin
  hasEscaped := False;
  if CharHlp.CountTargets(creature, 255) = 0 then
    hasEscaped := True
  else begin
    creatureMove := CbtActs.CalcCreatureMovement(creature) div 2;
    enemyMove := CbtActs.HighestEnemyMovement(creature);
    if enemyMove < creatureMove then
      hasEscaped := True
    else if enemyMove = creatureMove then
      if FxEngine.RollDice(1, 2) = 1 then
        hasEscaped := True;
  end;
  if hasEscaped then
    FxEngine.PutOutOfPlayWithStatus(Types.PCreature(creature), C_Status.RUNNING, 'Got Away')
  else
    CharHlp.PrintBottomLine('Escape is blocked');
  AttemptFlee := CharHlp.EndActions(Types.PCreature(creature));
end;

procedure RecalcAttacksLeft(creature: Types.PCreature);
var
  attacks: Byte;
  previous: Byte;
  ammoLimit: Byte;
  rate: Byte;
  ranged: Boolean;
  weapon: Types.PItem;
begin
  ranged := False;
  previous := Types.PCreature(creature)^.curAttacks[1];
  Types.PCreature(creature)^.curAttacks[1] := Types.PCreature(creature)^.attacks;
  if CharHlp.HasRangedWeapon(Types.PCreature(creature))
     and CharHlp.FindDamagingRangedWeapon(Types.PCreature(creature), Pointer(weapon)) then begin
    ranged := True;
    rate := GDVars.baseItems[Types.PCreature(creature)^.equipped[0]^.itemType].rateOfFire;
    if rate < 2 then
      rate := 2;
    GDVars.movementAttacks := rate;
  end else
    GDVars.movementAttacks := Types.PCreature(creature)^.curAttacks[1];
  GDVars.computingMove := 0;
  FxEngine.TriggerEffectsWithCondition(18, Types.PCreature(creature));
  attacks := CbtActs.AttacksFromRate(GDVars.movementAttacks);
  if ranged then
    if weapon <> nil then begin
      ammoLimit := 1;
      if weapon <> nil then
        if weapon^.quantity > ammoLimit then
          ammoLimit := weapon^.quantity;
      if ammoLimit < attacks then
        if weapon^.quantity > 0 then
          attacks := ammoLimit;
    end;
  if (Types.PCreature(creature)^.combatAddr^.madeAttack = 0) or (attacks < previous)
     or ((Types.PCreature(creature)^.combatAddr^.madeAttack <> 0) and (attacks < previous * 2) and (not ranged)) then
    Types.PCreature(creature)^.curAttacks[1] := attacks;
end;

function AttacksFromRate(rate: Byte): Byte;
var
  adjusted: Byte;
begin
  adjusted := rate;
  if Odd(GDVars.roundCounter) then
    Inc(adjusted);
  AttacksFromRate := adjusted div 2;
end;

function SweepAttack(att, def: Types.PCreature): Boolean;
var
  cntBefore: Byte;
  inRange: Byte;
  i: Byte;
  defIdx: Byte;
  p: Types.PCreature;
begin
  SweepAttack := False;
  if Types.PCreature(att)^.curAttacks[1] < Types.PCreature(att)^.combatAddr^.sweepBudget then
    if Types.PCreature(def)^.levelHighest = 0 then
      if CharHlp.CalcDistance(att, def) = 1 then begin
        cntBefore := CharHlp.CountTargets(att, 1);
        inRange := 0;
        for i := 1 to cntBefore do begin
          p := GDVars.combatCreatures[GDVars.combatTargetSlots[i]];
          if p = def then
            defIdx := i;
          if p^.levelHighest = 0 then
            Inc(inRange);
        end;
        if inRange > Types.PCreature(att)^.curAttacks[1] then begin
          if inRange > Types.PCreature(att)^.combatAddr^.sweepBudget then
            inRange := Types.PCreature(att)^.combatAddr^.sweepBudget;
          CharHlp.PrintCreatureMessage(Types.PCreature(att), 'sweeps', 10, True);
          p := GDVars.combatCreatures[GDVars.combatTargetSlots[1]];
          if p <> def then begin
            GDVars.combatTargetSlots[defIdx] := GDVars.combatTargetSlots[1];
            GDVars.combatTargetSlots[1] := CbtMap.CombatSlot(Types.PCreature(def));
          end;
          for i := 1 to cntBefore do
            if inRange > 0 then
              if GDVars.combatCreatures[GDVars.combatTargetSlots[i]]^.levelHighest = 0 then begin
                p := GDVars.combatCreatures[GDVars.combatTargetSlots[i]];
                CbtActs.NoteAttackDirection(att, p);
                Types.PCreature(att)^.curAttacks[1] := 1;
                CbtActs.MakeAttack(att, p, False, nil, GDVars.combatMenuExtendedKey);
                Dec(inRange);
              end;
          SweepAttack := True;
        end;
      end;
end;

function CanTarget(attacker, target: Types.PCreature): Boolean;
var
  savedTarget: Pointer;
begin
  CanTarget := False;
  if target <> nil then
    if attacker = target then
      CanTarget := True
    else begin
      GDVars.suppressTargeting := 0;
      FxEngine.TriggerEffectsWithCondition(1, Types.PCreature(target));
      if GDVars.suppressTargeting = 0 then begin
        savedTarget := Types.PCreature(attacker)^.combatAddr^.other;
        Types.PCreature(attacker)^.combatAddr^.other := Types.PCreature(target);
        FxEngine.TriggerEffectsWithCondition(0, Types.PCreature(attacker));
        Types.PCreature(attacker)^.combatAddr^.other := savedTarget;
      end;
      CanTarget := GDVars.suppressTargeting = 0;
    end;
end;

procedure CombatTurnUndead(creature: Types.PCreature);
var
  { d20 turning roll }
  roll: Byte;
  { Undead still to affect, from 1d12. }
  affectedLeft: Byte;
  minimumLeft: Byte;
  { Signed turning threshold. }
  needed: ShortInt;
  turnedAny: Boolean;
  stop: Boolean;
  { The undead being turned. }
  target: Pointer;
  tableColumn: ShortInt;
begin
  CharHlp.PrintCreatureMessage(Types.PCreature(creature), 'turns undead...', 10, False);
  MenuCore.ClearBottomLine;
  TextRend.PauseOnly;
  turnedAny := False;
  stop := False;
  Types.PCreature(creature)^.combatAddr^.usedTurnUndead := 1;
  minimumLeft := 6;
  affectedLeft := FxEngine.RollDice(1, 12);
  roll := FxEngine.RollDice(1, 20);
  case ShortInt(Types.PCreature(creature)^.classLevels[C_Class.CLERIC_LEVEL] +
                Types.PCreature(creature)^.oldClassLevels[C_Class.CLERIC_LEVEL] *
                ClassCal.EarlierClassActive(Types.PCreature(creature))) of
    1..8: tableColumn := Types.PCreature(creature)^.classLevels[C_Class.CLERIC_LEVEL];
    9..13: tableColumn := 9;
  else
    tableColumn := 10;
  end;
  while CbtActs.FindTurnUndeadTarget(creature, target) and (affectedLeft > 0) and (not stop) do begin
    needed := turnUndeadTbl[Types.PCreature(target)^.levelUndead, tableColumn];
    if roll >= Abs(needed) then begin
      turnedAny := True;
      CbtMap.DisplayMapViewCentered(Types.PCreature(target), 3, False);
      GDVars.combatRedraw := True;
      CharHlp.CombatPrintCreatureInfo(Types.PCreature(target));
      if needed > 0 then begin
        Types.PCreature(target)^.combatAddr^.turned := 1;
        CharHlp.PrintNameStringAnim(Types.PCreature(target), True, 'is turned');
      end else begin
        CharHlp.PrintCreatureMessage(Types.PCreature(target), 'Is destroyed', 10, False);
        CbtMap.CreatureDowned(Types.PCreature(target));
        Types.PCreature(target)^.status := C_Status.GONE;
        Types.PCreature(target)^.enabled := 0;
      end;
      if minimumLeft > 0 then
        Dec(minimumLeft);
      Dec(affectedLeft);
      if (affectedLeft = 0) and (minimumLeft > 0) and (needed < 0) then
        Inc(affectedLeft);
      CharHlp.ClearMessageWindow;
    end else
      stop := True;
  end;
  if not turnedAny then
    CharHlp.PrintBottomLine('Nothing Happens...');
  CharHlp.CountTeams;
  GDVars.combatMenuExtendedKey := CharHlp.EndActions(Types.PCreature(creature));
  CharHlp.ClearMessageWindow;
end;

function FindTurnUndeadTarget(creature: Types.PCreature; var target: Pointer): Boolean;
var
  count: Byte;
  index: Byte;
  bestLevel: ShortInt;
  candidate: Types.PCreature;
begin
  bestLevel := 13;
  target := nil;
  count := CharHlp.CountTargets(creature, 255);
  FindTurnUndeadTarget := False;
  for index := 1 to count do begin
    candidate := GDVars.combatCreatures[GDVars.combatTargetSlots[index]];
    if (candidate^.combatAddr^.turned = 0) and (candidate^.levelUndead > 0)
       and (candidate^.levelUndead < bestLevel) then begin
      bestLevel := candidate^.levelUndead;
      target := candidate;
      FindTurnUndeadTarget := True;
    end;
  end;
end;

{ Resolves an attacker's remaining attacks on a defender. A helpless defender is slain with one blow (its hit points
  plus 5) and the attacks are spent. Otherwise the attacker uses its weapon's large-target dice against a large
  defender, and the defense is the rear armor class less 4 on a backstab, the rear armor class from behind (when asked,
  or when the defender was attacked more than once with the attacker at its back and a flank spread above 4), else the
  front armor class, plus range penalties. The attacks are rolled from the current attack phase down to 1 until the
  defender drops; a miss is reported when no attack hits, a used-up missile of type 100 ends the attacks, and the sweep
  budget is spent. Note: an attacker that goes down during its attacks loses the rest of that phase's attacks but still
  makes the next phase's.
  @param(att The creature attacking.)
  @param(def The creature attacked.)
  @param(fromBehind True to attack as from behind.)
  @param(done Set True when the attacker has no attacks left or is down; its actions then end.)
  @param(other The missile or thrown item, or nil.) }
procedure RollAttacks(att, def: Types.PCreature; fromBehind: Boolean; var done: Boolean; other: Types.PItem);
var
  weaponRec: Types.TBaseItemRec;
  attackMade: Boolean;
  defDown: Boolean;
  backstab: Byte;
  ac: Byte;
  k: Byte;
  phase: Byte;
  atkType: Byte;
  bsFlag: ShortInt;
begin
  backstab := Byte(fromBehind);
  done := False;
  GDVars.phaseHits[1] := 0;
  GDVars.phaseHits[2] := 0;
  GDVars.phaseAttacks[1] := 0;
  GDVars.phaseAttacks[2] := 0;
  attackMade := False;
  defDown := False;
  GDVars.damage := 0;
  att^.combatAddr^.madeAttack := 1;
  if CharHlp.IsHelpless(def) then begin
    SoundDrv.SoundCommand(GDConsts.sndCmd7);
    while att^.curAttacks[att^.combatAddr^.attackPhase] = 0 do
      Dec(att^.combatAddr^.attackPhase);
    Inc(GDVars.phaseAttacks[att^.combatAddr^.attackPhase]);
    CbtActs.ProcessAttackResult(att, def, 3, def^.hpCur + 5, 1, True);
    FxEngine.RemoveInvisibility(att);
    for k := 1 to 2 do
      att^.curAttacks[k] := 0;
    attackMade := True;
    done := True;
  end else begin
    if att^.equipped[0] <> nil then
      if (def^.iconDim > $80) or ((def^.iconDim and 7) > 1) then begin
        weaponRec := GDVars.baseItems[att^.equipped[0]^.itemType];
        att^.curRolls[1] := weaponRec.dmgLgRolls;
        att^.curDice[1] := weaponRec.dmgLgDice;
        att^.curMod[1] := att^.curMod[1] - weaponRec.dmgSmMod
            + weaponRec.dmgLgMod;
      end;
    CharHlp.RecalcStats(def);
    FxEngine.TriggerEffectsWithCondition(11, def);
    bsFlag := 0;
    if CbtActs.IsBackstab(att, def) then
      ac := def^.acCur[1] - 4
    else begin
      if def^.combatAddr^.flankCount > 1 then
        if CbtActs.DirTowardTarget(att, def) = def^.combatAddr^.direction then
          if def^.combatAddr^.flankSpread > 4 then
            backstab := 1;
      if backstab <> 0 then
        bsFlag := 1;
      ac := def^.acCur[bsFlag];
    end;
    CbtActs.ApplyRangePenalty(att, def, ac);
    atkType := 0;
    if backstab <> 0 then
      atkType := 1;
    if CbtActs.IsBackstab(att, def) then
      atkType := 2;
    phase := att^.combatAddr^.attackPhase;
    for k := phase downto 1 do
      while (att^.curAttacks[k] > 0) and (not defDown) do begin
        Dec(att^.curAttacks[k]);
        att^.combatAddr^.attackPhase := k;
        Inc(GDVars.phaseAttacks[k]);
        if FxEngine.AttackRoll(att, def, ac) or CharHlp.IsHelpless(def) then begin
          Inc(GDVars.phaseHits[k]);
          SoundDrv.SoundCommand(GDConsts.sndCmd7);
          attackMade := True;
          CbtActs.CalcWeaponDamage(att, def, k);
          CbtActs.ProcessAttackResult(att, def, atkType, GDVars.damage, GDVars.damage, True);
          if def^.enabled <> 0 then
            FxEngine.TriggerEffectsWithCondition(k + 1, att);
          if def^.enabled = 0 then
            defDown := True;
          if att^.enabled = 0 then begin
            phase := 0;
            att^.curAttacks[k] := 0;
          end;
        end;
      end;
    if (other <> nil) and (other^.quantity = 0) and (other^.itemType = 100) then
      for k := 1 to 2 do
        att^.curAttacks[k] := 0;
    if not attackMade then begin
      SoundDrv.SoundCommand(GDConsts.sndCmd9);
      CbtActs.ProcessAttackResult(att, def, atkType, 0, 0, False);
    end;
    done := True;
    for k := 1 to 2 do
      if att^.curAttacks[k] > 0 then
        done := False;
    att^.combatAddr^.sweepBudget := 0;
  end;
  if att^.enabled = 0 then
    done := True;
  if done then
    done := CharHlp.EndActions(att);
end;

procedure NoteAttackDirection(attacker, defender: Types.PCreature);
var
  angle: Byte;
  attackDirection: Byte;
begin
  Inc(defender^.combatAddr^.flankCount);
  attackDirection := CbtActs.DirTowardTarget(defender, attacker);
  angle := (attackDirection - defender^.combatAddr^.direction + 8) mod 8;
  if angle > 4 then
    angle := 8 - angle;
  defender^.combatAddr^.flankSpread := (defender^.combatAddr^.flankSpread + angle) mod 8;
end;

procedure MakeAttack(attacker, defender: Types.PCreature; fromBehind: Boolean; weapon: Types.PItem; var done: Boolean);
var
  thrownCopy: Types.PItem;
  savedCharacter: Types.PCreature;
  direction: Byte;
begin
  GDVars.mapVisible := True;
  GDVars.combatRedraw := True;
  GDVars.combatTargetSlots[0] := GDVars.roundCounter + 15;
  if (defender^.combatAddr^.flankCount < 2) and (fromBehind = False) then begin
    direction := CbtActs.DirTowardTarget(defender, attacker);
    defender^.combatAddr^.direction := (direction + 4) mod 8;
  end else if CbtMap.CombatIconVisible(defender, 0) then begin
    direction := defender^.combatAddr^.direction;
    if fromBehind = False then
      defender^.combatAddr^.direction := (direction + 4) mod 8;
  end;
  if CbtMap.CombatIconVisible(defender, 0) then
    CbtMap.SetCreatureFacing(defender, direction, 0, 0);
  direction := CbtActs.DirTowardTarget(attacker, defender);
  CharHlp.CombatPrintCreatureInfo(attacker);
  CbtMap.SetCreatureFacing(attacker, direction, 1, 0);
  attacker^.combatAddr^.other := defender;
  Delay(100);
  if weapon <> nil then
    CbtActs.AnimateMissile(attacker, defender, weapon);
  if (attacker^.equipped[0]^.itemType = 47) or (attacker^.equipped[0]^.itemType = 101) then
    CbtActs.AnimateMissile(attacker, defender, attacker^.equipped[0]);
  done := True;
  if (attacker^.curAttacks[1] > 0) or (attacker^.curAttacks[2] > 0) then begin
    savedCharacter := GDVars.curChar;
    GDVars.curChar := attacker;
    CbtActs.RollAttacks(attacker, defender, fromBehind, done, weapon);
    if weapon <> nil then begin
      if weapon^.quantity > 0 then
        Dec(weapon^.quantity, GDVars.phaseAttacks[1]);
      if weapon^.quantity = 0 then
        if CharHlp.HasThrowableWeapon(attacker) and (weapon^.special <> $89) then begin
          New(thrownCopy);
          Move(weapon^, thrownCopy^, SizeOf(thrownCopy^));
          thrownCopy^.next := GDVars.treasureItems;
          GDVars.treasureItems := thrownCopy;
          thrownCopy^.equipped := 0;
          CharHlp.RemoveItem(attacker, weapon);
          GDVars.lastMissileItem := thrownCopy;
        end else
          CharHlp.RemoveItem(attacker, weapon);
    end;
    CharHlp.RecalcStats(attacker);
    GDVars.curChar := savedCharacter;
  end;
  if done then
    done := CharHlp.EndActions(attacker);
  if CbtMap.CombatIconVisible(attacker, 0) then begin
    CbtMap.SetCreatureFacing(attacker, attacker^.combatAddr^.direction, 1, 1);
    CbtMap.SetCreatureFacing(attacker, attacker^.combatAddr^.direction, 0, 0);
  end;
end;

procedure ApplyRangePenalty(attacker, defender: Types.PCreature; var armorClass: Byte);
var
  band: ShortInt;
  distance: ShortInt;
begin
  distance := CharHlp.CalcDistance(attacker, defender);
  if CharHlp.HasRangedWeapon(attacker) then
    band := (GDVars.baseItems[attacker^.equipped[0]^.itemType].range - 1) div 3
  else
    band := distance;
  if distance - band > 0 then begin
    distance := distance - band;
    armorClass := armorClass + 2;
  end;
  if distance - band > 0 then begin
    distance := distance - band;
    armorClass := armorClass + 3;
  end;
end;

procedure PrimeCbtActs;
begin
  ViewChar.PrimeViewChar;
  Pathing.PrimePathing;
  CbtMap.PrimeCbtMap;
  MapTiles.PrimeMapTiles;
  CharHlp.PrimeCharHlp;
  Magic.PrimeMagic;
  FxEngine.PrimeFxEngine;
  MenuCore.PrimeMenuCore;
  EclTrace.PrimeEclTrace;
  ClassCal.PrimeClassCal;
end;

function FindCureTarget(creature: Types.PCreature; var tgt: Types.PCreature): Boolean;
var
  best: Types.PCreature;
  nx: ShortInt;
  ny: ShortInt;
  downIdx: Byte;
  bestHp: Byte;
  d: Byte;
  j: Byte;
  crIdx: Byte;
  terrIdx: Byte;
begin
  best := nil;
  downIdx := 0;
  bestHp := 255;
  for d := 0 to 8 do begin
    nx := CbtMap.CombatCellX(creature) + GDConsts.directionDx[d];
    ny := CbtMap.CombatCellY(creature) + GDConsts.directionDy[d];
    CbtMap.GetArenaContents(nx, ny, crIdx, terrIdx);
    if crIdx > 0 then begin
      tgt := GDVars.combatCreatures[crIdx];
      if tgt^.hostile = creature^.hostile then
        if tgt^.hpCur < tgt^.hpMax then
          if (tgt^.hpCur < bestHp)
             or ((tgt = creature) and (tgt^.hpCur < tgt^.hpMax div 2)) then begin
            best := tgt;
            bestHp := tgt^.hpCur;
          end;
    end else if terrIdx = C_Terr.CORPSE then
      for j := 1 to GDVars.downedCount do
        if GDVars.downedCharacters[j].cr <> nil then
          if not (GDVars.downedCharacters[j].cr^.status in
                  [C_Status.DEAD_STATUS, C_Status.STONED, C_Status.GONE]) then
            if GDVars.downedCharacters[j].x = nx then
              if GDVars.downedCharacters[j].y = ny then
                downIdx := j;
  end;
  if (bestHp < 8) or (downIdx = 0) then
    tgt := best
  else
    tgt := GDVars.downedCharacters[downIdx].cr;
  if tgt <> nil then
    FindCureTarget := True
  else
    FindCureTarget := False;
end;

{ Picks one spell target. For the player the aim goes through CombatAimMenu (one spell may aim at cells but not at
  creatures), which also locks the target. Otherwise a spell that does not target enemies goes to the caster, or for
  Cure Light Wounds to FindCureTarget's pick; an offensive spell takes one AcquireTarget pick, rejected when the target
  is helpless and the spell's effect is a helpless status. On success the target's cell becomes the spell's target cell;
  on failure the target is cleared.
  @param(spellId The spell being aimed.)
  @param(aiControlled 0 for the player's aim menu; nonzero for computer-controlled targeting.)
  @param(groundOk Passed to CombatAimMenu: nonzero lets the player pick a bare cell.)
  @param(target Receives the target: a creature pointer followed by its arena cell.)
  @returns(True if a target was found.) }
function SelectSpellTarget(spellId, aiControlled, groundOk: Byte; var target: TTgtRec): Boolean;
var
  found: Boolean;
  acceptable: Boolean;
  candidate: Types.PCreature;
  i: Byte;
  tries: Byte;
  creatureOk: Byte;
begin
  found := False;
  if aiControlled = 0 then begin
    creatureOk := Byte(spellId <> 83);
    CbtActs.CombatAimMenu(GDVars.curChar, Magic.CalcSpellRange(spellId), 0, groundOk, creatureOk, found, target);
    GDVars.curChar^.combatAddr^.other := target.cr;
  end else if GDConsts.spellProperties[spellId].targetsEnemy = 0 then begin
    target.cr := GDVars.curChar;
    if (spellId <> C_Spell.CURE_LIGHT_WOUNDS) or CbtActs.FindCureTarget(GDVars.curChar, target.cr) then begin
      target.cellX := CbtMap.CombatCellX(target.cr);
      target.cellY := CbtMap.CombatCellY(target.cr);
      found := True;
    end;
  end else begin
    tries := 1;
    while (tries > 0) and not found do begin
      acceptable := True;
      if CbtActs.AcquireTarget(GDVars.curChar, Magic.CalcSpellRange(spellId), 0, 1) then begin
        candidate := GDVars.curChar^.combatAddr^.other;
        if CharHlp.IsHelpless(candidate) then
          for i := 1 to 4 do
            if GDConsts.spellProperties[spellId].effectId = GDConsts.statusEffects[i] then
              acceptable := False;
        if acceptable then begin
          target.cr := GDVars.curChar^.combatAddr^.other;
          target.cellX := CbtMap.CombatCellX(target.cr);
          target.cellY := CbtMap.CombatCellY(target.cr);
          found := True;
        end;
      end;
      Dec(tries);
    end;
  end;
  if found then begin
    SelectSpellTarget := True;
    GDVars.spellTargetX := target.cellX;
    GDVars.spellTargetY := target.cellY;
  end else begin
    SelectSpellTarget := False;
    FillChar(target, SizeOf(target), 0);
  end;
end;

procedure SelectCombatTargets(spell, aiControlled: Byte; var cast: Boolean);
var
  { Separate picks still to make. }
  menuCnt: Byte;
  { Targets accepted so far. }
  found: Byte;
  { Index used to check for duplicate targets. }
  j: Byte;
  { weight budget: caster level for spell $4F, else 2d4 }
  rng: Byte;
  { weight of the targets picked so far }
  vote: Byte;
  res: TTgtRec;
  { Set when the pick is already a target. }
  dupFlag: Boolean;
  { Ends the weighted selection. }
  resFlag: Boolean;
begin
  cast := True;
  GDVars.spellTargetCount := 0;
  GDVars.multiTarget := 0;
  GDVars.spellTargetX := CbtMap.CombatCellX(GDVars.curChar);
  GDVars.spellTargetY := CbtMap.CombatCellY(GDVars.curChar);
  case GDConsts.spellProperties[spell].targetType and $0F of
    0:
      begin
        GDVars.spellTargets[1] := GDVars.curChar;
        GDVars.spellTargetCount := 1;
      end;
    5:
      begin
        vote := 0;
        found := 0;
        if spell = 79 then
          rng := CharHlp.GetCasterLevel(79)
        else
          rng := FxEngine.RollDice(2, 4);
        resFlag := False;
        repeat
          if CbtActs.SelectSpellTarget(spell, aiControlled, 0, res) then begin
            dupFlag := False;
            for j := 1 to found do
              if GDVars.spellTargets[j] = res.cr then
                dupFlag := True;
            if not dupFlag then begin
              Inc(found);
              GDVars.spellTargets[found] := res.cr;
              GDVars.spellTargetX := CbtMap.CombatCellX(res.cr);
              GDVars.spellTargetY := CbtMap.CombatCellY(res.cr);
              Inc(GDVars.spellTargetCount);
              if spell <> 79 then begin
                case GDVars.spellTargets[found]^.levelHighest of
                  0, 1: Inc(vote);
                  2: Inc(vote, 2);
                  3: Inc(vote, 4);
                else
                  Inc(vote, 8);
                end;
              end else begin
                case GDVars.spellTargets[found]^.iconDim of
                  1: Inc(vote);
                  2, 3: Inc(vote, 2);
                  4: Inc(vote, 4);
                end;
              end;
              if (found > 1) and (vote > rng) then
                resFlag := True;
            end else begin
              if aiControlled <> 0 then
                Dec(rng)
              else
                CharHlp.PrintBottomLine('Already been targeted');
            end;
            CbtMap.RedrawArenaCell(CbtMap.CombatCellX(res.cr), CbtMap.CombatCellY(res.cr));
          end else
            resFlag := True;
        until resFlag or (rng = 0);
      end;
    15:
      begin
        if CbtActs.SelectSpellTarget(spell, aiControlled, 0, res) then begin
          if GDVars.curChar^.combatAddr^.other <> nil then begin
            GDVars.spellTargets[1] := GDVars.curChar^.combatAddr^.other;
            GDVars.spellTargetCount := 1;
          end else begin
            Pathing.BuildTargetList(GDVars.spellTargetX, GDVars.spellTargetY,
                                    (GDConsts.spellProperties[spell].targetType and $F) shr 4, 255, 1,
                                    GDVars.combatArena);
            for found := 1 to GDVars.targetCount do
              GDVars.spellTargets[found] := GDVars.combatCreatures[GDVars.targetList[found].idx];
            GDVars.spellTargetCount := GDVars.targetCount;
            GDVars.multiTarget := 1;
          end;
        end else
          cast := False;
      end;
    8..14:
      begin
        if CbtActs.SelectSpellTarget(spell, aiControlled, 1, res) then begin
          Pathing.BuildTargetList(GDVars.spellTargetX, GDVars.spellTargetY,
                                  GDConsts.spellProperties[spell].targetType and $7, 255, 1, GDVars.combatArena);
          for found := 1 to GDVars.targetCount do
            GDVars.spellTargets[found] := GDVars.combatCreatures[GDVars.targetList[found].idx];
          GDVars.spellTargetCount := GDVars.targetCount;
          GDVars.multiTarget := 1;
        end else
          cast := False;
      end;
  else begin
      menuCnt := (GDConsts.spellProperties[spell].targetType and $3) + 1;
      found := 0;
      while menuCnt > 0 do begin
        if CbtActs.SelectSpellTarget(spell, aiControlled, 0, res) then begin
          dupFlag := False;
          for j := 1 to found do
            if GDVars.spellTargets[j] = res.cr then
              dupFlag := True;
          if not dupFlag then begin
            Inc(found);
            GDVars.spellTargets[found] := res.cr;
            Dec(menuCnt);
            GDVars.spellTargetX := CbtMap.CombatCellX(res.cr);
            GDVars.spellTargetY := CbtMap.CombatCellY(res.cr);
          end else begin
            if aiControlled = 0 then
              CharHlp.PrintBottomLine('Already been targeted')
            else
              Dec(menuCnt);
          end;
          CbtMap.RedrawArenaCell(CbtMap.CombatCellX(res.cr), CbtMap.CombatCellY(res.cr));
        end else
          menuCnt := 0;
      end;
      GDVars.spellTargetCount := found;
      if found = 0 then
        cast := False;
      GDVars.spellTargetX := CbtMap.CombatCellX(GDVars.spellTargets[found]);
      GDVars.spellTargetY := CbtMap.CombatCellY(GDVars.spellTargets[found]);
    end;
  end;
end;

procedure CastSpellCombat(spell, ai: Byte; var cast: Boolean);
var
  { The spell being cast, from spell or the spell menu. }
  sp: Byte;
  { Unused in this version; see the other implementations of this routine. }
  spellLevel: Byte;
  { casting delay: the spell's castingTime div 3 }
  castDelay: Byte;
  { Spell menu cursor, starting at -1. }
  idx: Integer;
  { The spell menu's has-spells flag. }
  notEmpty: Boolean;
  { The caster, the current character on entry. }
  savedCr: Types.PCreature;
begin
  savedCr := GDVars.curChar;
  notEmpty := True;
  idx := -1;
  cast := False;
  sp := spell;
  if sp = 0 then
    sp := ViewChar.SpellMenu(0, 1, idx, notEmpty);
  if sp > 0 then
    if GDConsts.spellProperties[sp].combatOk = 0 then begin
      CharHlp.PrintBottomLine('Camp Only Spell');
      sp := 0;
    end;
  if ai = 0 then begin
    CharHlp.DisplayCombatInterface;
    GDVars.mapVisible := True;
    GDVars.combatRedraw := True;
    CbtMap.DisplayMapViewCentered(savedCr, 3, True);
    CharHlp.CombatPrintCreatureInfo(savedCr);
  end;
  if sp > 0 then begin
    castDelay := GDConsts.spellProperties[sp].castingTime div 3;
    if castDelay = 0 then begin
      Magic.CastSpell(sp, Boolean(ai), True, cast);
      cast := CharHlp.EndActions(savedCr);
    end else begin
      cast := True;
      CharHlp.PrintCreatureMessage(savedCr, 'Begins Casting', 10, True);
      savedCr^.combatAddr^.spellCast := sp;
      if savedCr^.combatAddr^.initiative > castDelay then
        Dec(savedCr^.combatAddr^.initiative, castDelay)
      else
        savedCr^.combatAddr^.initiative := 1;
    end;
  end;
end;

function IsBackstab(attacker, defender: Types.PCreature): Boolean;
var
  weapon: Types.PItem;
  { Unused in this version; see the other implementations of this routine. }
  armor: Types.PItem;
  weaponType: Byte;
  canBackstab: Boolean;
begin
  canBackstab := False;
  weapon := attacker^.equipped[0];
  if weapon <> nil then
    weaponType := weapon^.itemType;
  armor := attacker^.equipped[2];
  if (attacker^.classLevels[C_Class.THIEF_LEVEL] > 0)
     or ((attacker^.oldClassLevels[C_Class.THIEF_LEVEL] > 0) and (ClassCal.EarlierClassActive(attacker) <> 0)) then
    if (weapon = nil) or (weaponType = 97) or (weaponType = 7) or (weaponType = 8)
       or ((weaponType > 34) and (weaponType < 38)) then
      canBackstab := True;
  if canBackstab and (defender^.combatAddr^.flankCount > 1)
     and ((defender^.iconDim and $7F) <= 1)
     and (CbtActs.DirTowardTarget(attacker, defender) = defender^.combatAddr^.direction) then
    IsBackstab := True
  else
    IsBackstab := False;
end;

function DirTowardTarget(creature, other: Types.PCreature): Byte;
var
  dir: Byte;
  found: Boolean;
  x1: Integer;
  y1: Integer;
  x2: Integer;
  y2: Integer;
  deltaX: Integer;
  deltaY: Integer;
begin
  x1 := CbtMap.CombatCellX(creature);
  y1 := CbtMap.CombatCellY(creature);
  x2 := CbtMap.CombatCellX(other);
  y2 := CbtMap.CombatCellY(other);
  deltaX := Abs(x2 - x1);
  deltaY := Abs(y2 - y1);
  dir := 0;
  found := False;
  while not found do begin
    case dir of
      0: found := (y2 <= y1) and ((618 * deltaX) div 256 <= deltaY);
      2: found := (x2 >= x1) and ((106 * deltaX) div 256 >= deltaY);
      4: found := (y2 >= y1) and ((618 * deltaX) div 256 <= deltaY);
      6: found := (x2 <= x1) and ((106 * deltaX) div 256 >= deltaY);
      1: found := (y2 <= y1) and (x2 >= x1)
             and ((618 * deltaX) div 256 >= deltaY) and ((106 * deltaX) div 256 <= deltaY);
      3: found := (y2 >= y1) and (x2 >= x1)
             and ((618 * deltaX) div 256 >= deltaY) and ((106 * deltaX) div 256 <= deltaY);
      5: found := (y2 >= y1) and (x2 <= x1)
             and ((618 * deltaX) div 256 >= deltaY) and ((106 * deltaX) div 256 <= deltaY);
      7: found := (y2 <= y1) and (x2 <= x1)
             and ((618 * deltaX) div 256 >= deltaY) and ((106 * deltaX) div 256 <= deltaY);
    end;
    if not found then
      Inc(dir);
  end;
  DirTowardTarget := dir;
end;

procedure AnimateMissile(attacker, defender: Types.PCreature; weapon: Types.PItem);
var
  missileCellBase: Byte;
  frames: Byte;
  direction: Byte;
  pace: Byte;
  { Unused in this version; see the other implementations of this routine. }
  imageSize: Word;
begin
  SoundDrv.SoundCommand(GDConsts.sndCmd12);
  direction := CbtActs.DirTowardTarget(attacker, defender);
  frames := 1;
  pace := 10;
  missileCellBase := 13;
  imageSize := GDVars.combatEffectSprite^.imgSize;
  case weapon^.itemType of
    9, 21, 100, 28, 31, 73:
      begin
        if Odd(direction) then begin
          if (direction = 3) or (direction = 5) then
            CharHlp.CopyIconFacing(missileCellBase + 1, 1, 0, Ord(direction = 5))
          else
            CharHlp.CopyIconFacing(missileCellBase + 1, 0, 0, Ord(direction = 7));
        end else
          CharHlp.CopyIconFacing(missileCellBase + direction mod 4, direction div 4, 0, 0);
        SoundDrv.SoundCommand(GDConsts.sndCmd12);
      end;
    2, 7, 20:
      begin
        CharHlp.BuildIconFacings(missileCellBase + 3);
        frames := 4;
        pace := 50;
        SoundDrv.SoundCommand(GDConsts.sndCmd9);
      end;
    85, 86:
      begin
        CharHlp.BuildIconFacings(missileCellBase + 4);
        frames := 4;
        pace := 50;
        SoundDrv.SoundCommand(GDConsts.sndCmd6);
      end;
    101, 47, 98:
      begin
        Inc(missileCellBase);
        CharHlp.CopyIconFacing(missileCellBase + 7, 0, 0, 0);
        CharHlp.CopyIconFacing(missileCellBase + 7, 1, 1, 0);
        frames := 2;
        pace := 10;
        SoundDrv.SoundCommand(GDConsts.sndCmd6);
      end;
  else
    CharHlp.CopyIconFacing(missileCellBase + 7, 0, 0, 0);
    CharHlp.CopyIconFacing(missileCellBase + 7, 1, 1, 0);
    frames := 2;
    pace := 20;
    SoundDrv.SoundCommand(GDConsts.sndCmd9);
  end;
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(attacker), CbtMap.CombatCellY(attacker),
                                  CbtMap.CombatCellX(defender), CbtMap.CombatCellY(defender), frames, pace);
end;

procedure UpdateHostileHpPercent;
var
  maximumTotal: Word;
  hitPointTotal: Word;
  combatant: Types.PCreature;
begin
  maximumTotal := 0;
  hitPointTotal := 0;
  combatant := GDVars.partyHead;
  while combatant <> nil do begin
    if combatant^.hostile = 1 then begin
      if combatant^.enabled <> 0 then
        hitPointTotal := hitPointTotal + combatant^.hpCur;
      maximumTotal := maximumTotal + combatant^.hpMax;
    end;
    combatant := combatant^.next;
  end;
  if maximumTotal > 0 then
    GDVars.hostileHpPct := hitPointTotal * 20 div maximumTotal * 5;
end;

function HighestEnemyMovement(creature: Types.PCreature): Byte;
var
  highest: Byte;
  movement: Byte;
  combatant: Types.PCreature;
begin
  highest := 0;
  combatant := GDVars.partyHead;
  while combatant <> nil do begin
    if (ShortInt(CharHlp.NotHostile(Types.PCreature(creature))) = combatant^.hostile) and
        (combatant^.enabled <> 0) then begin
      movement := CbtActs.CalcCreatureMovement(combatant) div 2;
      if movement > highest then
        highest := movement;
    end;
    combatant := combatant^.next;
  end;
  HighestEnemyMovement := highest;
end;

function CheckAttackAlly(attacker, defender: Types.PCreature): Boolean;
var
  combatant: Types.PCreature;
begin
  if (ShortInt(CharHlp.NotHostile(defender)) = attacker^.hostile) or (attacker^.quickfight <> 0) then
    CheckAttackAlly := True
  else if MenuCore.YesNoMenu('Attack Ally: ', LightMagenta, LightGreen, White) <> 'Y' then
    CheckAttackAlly := False
  else begin
    CheckAttackAlly := True;
    GDVars.attackedAllies := 1;
    GDVars.zone1^[C_Gbvm.ATTACKED_ALLIES] := 1;
    combatant := GDVars.partyHead;
    while combatant <> nil do begin
      if (combatant^.status = C_Status.OKAY) and (combatant^.npc > $7F) then begin
        combatant^.hostile := 1;
        combatant^.combatAddr^.other := nil;
      end;
      combatant := combatant^.next;
    end;
    CharHlp.CountTeams;
  end;
end;

{ Shows one aim-menu round on the target: centers the view on it, shows the range in weapon mode, and offers Target when
  the target is in range (spell mode: when creatures may be targeted; weapon mode: when the target is another creature
  and the attacker either has no ranged weapon, or has ammunition for it and no adjacent enemy or a throwable weapon),
  then Next, Prev, Manual, Center and Exit.
  @param(creature The creature aiming.)
  @param(target The creature under the aim.)
  @param(range The reach, in whole steps.)
  @param(weaponMode Nonzero for a weapon attack, 0 for a spell.)
  @param(groundOk Unused.)
  @param(creatureOk Nonzero when a spell may target a creature.)
  @returns(The key chosen.) }
function AimTargetMenu(creature, target: Types.PCreature; range, weaponMode, groundOk, creatureOk: Byte): Char;
var
  { The menu's option words. }
  menu: String[40];
  ext: Boolean;
  { FindDamagingRangedWeapon's missile, which this routine does not use. }
  attackItem: Pointer;
  { Distance to the target, in whole steps. }
  distance: Byte;
  { Unused in this version; see the other implementations of this routine. }
  direction: Byte;
begin
  menu := '';
  distance := CharHlp.CalcDistance(creature, target);
  direction := CbtActs.DirTowardTarget(creature, target);
  if weaponMode <> 0 then
    TextRend.DisplayString(0, 23, LightGreen, 0, 'Range = ' + CharHlp.Uint8Str(distance) + '  ');
  if distance <= range then begin
    if weaponMode = 0 then begin
      if creatureOk <> 0 then
        menu := 'Target '
      else
        menu := '';
    end else if creature <> target then begin
      if not CharHlp.HasRangedWeapon(creature) then
        menu := 'Target '
      else if CharHlp.FindDamagingRangedWeapon(creature, attackItem) then
        if (CharHlp.CountTargets(creature, 1) = 0) or CharHlp.HasThrowableWeapon(creature) then
          menu := 'Target ';
    end;
  end;
  menu := 'Next Prev Manual ' + menu + 'Center Exit';
  CbtMap.DisplayMapViewCentered(target, 3, True);
  GDVars.combatRedraw := True;
  CharHlp.CombatPrintCreatureInfo(target);
  AimTargetMenu := MenuCore.MenuHorizontal('Aim:', menu, LightMagenta, LightGreen, White, True, False, ext);
end;

{ Confirms an aim selection: weapon mode 1 makes a weapon attack, anything else selects a spell target. A weapon attack
  on an ally needs CheckAttackAlly's consent, otherwise the selection is cleared and the done flag is False. The attack
  tries a sweep first; a throwable ranged weapon used at distance 1 strikes as melee.
  @param(cur The creature aiming.)
  @param(tgt The creature chosen.)
  @param(weaponMode 1 for a weapon attack.)
  @param(done False when the attack was declined; otherwise True or the attack's result.)
  @param(sel Receives the target and its cell; cleared when declined.) }
procedure ConfirmAttackTarget(cur, tgt: Types.PCreature; weaponMode: Byte; var done: Boolean; var sel: TTgtRec);
var
  { Unused in this version; see the other implementations of this routine. }
  targetDir: Byte;
  rangedWpn: Types.PItem;
begin
  rangedWpn := nil;
  done := True;
  if (weaponMode = 1) and (not CbtActs.CheckAttackAlly(cur, tgt)) then
    done := False;
  if done then begin
    sel.cr := tgt;
    sel.cellX := CbtMap.CombatCellX(tgt);
    sel.cellY := CbtMap.CombatCellY(tgt);
    GDVars.combatArena^.cursorOn := 0;
    CbtMap.ScrollView(GDVars.combatArena^.focusX + 3, GDVars.combatArena^.focusY + 3, 3, 8);
    if weaponMode = 1 then begin
      if CbtActs.SweepAttack(cur, tgt) then
        done := CharHlp.EndActions(cur)
      else begin
        CbtActs.NoteAttackDirection(cur, tgt);
        if CharHlp.HasRangedWeapon(cur) and CharHlp.FindDamagingRangedWeapon(cur, Pointer(rangedWpn))
           and CharHlp.HasThrowableWeapon(cur) and (CharHlp.CalcDistance(cur, tgt) = 1) then
          rangedWpn := nil;
        CbtActs.MakeAttack(cur, tgt, False, rangedWpn, done);
      end;
    end;
  end else
    FillChar(sel, SizeOf(sel), 0);
end;

{ Runs the free cursor: the arrow keys move a cell cursor (kept inside the arena) from underCursor's cell, Target or
  Enter takes a valid cell (a weapon attack goes through ConfirmAttackTarget) and Center recenters. Target or Enter on
  an invalid cell, Exit and Escape leave with nothing chosen. A cell is valid when Pathing.WalkLine reaches it within
  range and its terrain is passable; a bare cell also needs groundOk, and a creature needs creatureOk and CanTarget's
  consent. In weapon mode a creature is also invalid when it is the attacker itself or a downed body, or when the
  attacker's ranged weapon has no ammunition or, unless throwable, an enemy stands adjacent.
  @param(cur The creature aiming.)
  @param(underCursor The creature whose cell the cursor starts on.)
  @param(range The reach, in whole steps.)
  @param(weaponMode 1 for a weapon attack, 0 for a spell target.)
  @param(groundOk Nonzero lets a bare cell be chosen.)
  @param(creatureOk Nonzero lets a creature be chosen.)
  @param(done True when a target was taken.)
  @param(tgt Receives the chosen creature (nil for a bare cell) and cell; cleared when nothing is chosen.) }
procedure ManualAimCursor(cur, underCursor: Types.PCreature; range, weaponMode, groundOk, creatureOk: Byte;
                          var done: Boolean; var tgt: TTgtRec);
var
  { The menu's option words. }
  menu: String[40];
  ch: Char;
  { FindDamagingRangedWeapon's missile, which this routine does not use. }
  attackItem: Pointer;
  { Cursor step direction, 0..7, or 8 to stay put. }
  dir: Byte;
  { Index into the downed creatures. }
  idx: Byte;
  { Signed target column for WalkLine. }
  savedX: ShortInt;
  { Signed target row for WalkLine. }
  savedY: ShortInt;
  cursorX: ShortInt;
  cursorY: ShortInt;
  { Creature in the cursor's cell, 0 when empty. }
  crIdx: Byte;
  { Terrain in the cursor's cell. }
  terrIdx: Byte;
  { WalkLine's distance in half-steps, then halved to whole steps. }
  rangeWork: Word;
  { Nonzero while the cell under the cursor may be chosen. }
  inRange: Byte;
begin
  FillChar(tgt, SizeOf(tgt), 0);
  cursorX := CbtMap.CombatCellX(underCursor);
  cursorY := CbtMap.CombatCellY(underCursor);
  ch := ' ';
  dir := 8;
  done := False;
  GDVars.combatArena^.cursorOn := 1;
  GDVars.combatArena^.focusSize := 1;
  while not (ch in [C_Keys.NONE, C_Keys.ENTER, 'E', 'T']) do
  begin
    CbtMap.ScrollView(cursorX, cursorY, 3, dir);
    Inc(cursorX, GDConsts.directionDx[dir]);
    Inc(cursorY, GDConsts.directionDy[dir]);
    if cursorX < 0 then cursorX := 0;
    if cursorY < 0 then cursorY := 0;
    if cursorX > 49 then cursorX := 49;
    if cursorY > 24 then cursorY := 24;
    CbtMap.GetArenaContents(cursorX, cursorY, crIdx, terrIdx);
    GameIo.DiscardPendingKeys;
    inRange := 0;
    rangeWork := 255;
    savedX := cursorX;
    savedY := cursorY;
    if Byte(Pathing.WalkLine(CbtMap.CombatCellX(cur), CbtMap.CombatCellY(cur), savedX, savedY, rangeWork,
                             GDVars.combatArena)) <> 0 then begin
      inRange := 1;
      if weaponMode <> 0 then
        TextRend.DisplayString(0, 23, LightGreen, 0, 'Range = ' + CharHlp.Uint16Str(rangeWork div 2) + '  ');
    end else if weaponMode <> 0 then
      Border.ClearBox(0, 23, 39, 23);
    rangeWork := rangeWork div 2;
    underCursor := nil;
    if inRange <> 0 then
      if crIdx > 0 then
        underCursor := GDVars.combatCreatures[crIdx]
      else if terrIdx = C_Terr.CORPSE then
        for idx := 1 to GDVars.downedCount do
          if (GDVars.downedCharacters[idx].x = cursorX) and (GDVars.downedCharacters[idx].y = cursorY) then
            underCursor := GDVars.downedCharacters[idx].cr;
    if underCursor <> nil then begin
      GDVars.combatRedraw := True;
      CharHlp.CombatPrintCreatureInfo(underCursor);
    end else
      Border.ClearBox(23, 1, 38, 21);
    if (range < rangeWork) or (GDConsts.terrainInfo[terrIdx].cost = 255) then
      inRange := 0;
    if underCursor <> nil then begin
      if (not CbtActs.CanTarget(cur, underCursor)) or (creatureOk = 0) then
        inRange := 0;
      if weaponMode = 1 then begin
        if (cur = underCursor) or ((crIdx = 0) and (terrIdx = C_Terr.CORPSE)) then
          inRange := 0
        else if CharHlp.HasRangedWeapon(cur) then
          if (not CharHlp.FindDamagingRangedWeapon(cur, attackItem))
             or ((CharHlp.CountTargets(cur, 1) > 0) and (not CharHlp.HasThrowableWeapon(cur))) then
            inRange := 0;
      end;
    end else if groundOk = 0 then
      inRange := 0;
    menu := 'Center Exit';
    if inRange <> 0 then
      menu := 'Target ' + menu;
    ch := MenuCore.MenuHorizontal('(Use Cursor keys) ', menu, LightMagenta, LightGreen, White, True, False,
                                  GDVars.combatMenuExtendedKey);
    case ch of
      C_Keys.ENTER, 'T':
        begin
          GDVars.combatArena^.cursorOn := 0;
          if inRange <> 0 then begin
            tgt.cellX := cursorX;
            tgt.cellY := cursorY;
            if underCursor <> nil then
              tgt.cr := underCursor
            else
              tgt.cr := nil;
            if weaponMode = 1 then
              CbtActs.ConfirmAttackTarget(cur, tgt.cr, weaponMode, done, tgt)
            else
              done := True;
          end;
          if (inRange = 0) or (not done) then begin
            CbtMap.RedrawArenaCell(cursorX, cursorY);
            done := False;
            FillChar(tgt, SizeOf(tgt), 0);
          end;
        end;
      C_Keys.UP: dir := 0;
      C_Keys.PAGE_UP: dir := 1;
      C_Keys.RIGHT: dir := 2;
      C_Keys.PAGE_DOWN: dir := 3;
      C_Keys.DOWN: dir := 4;
      C_Keys.END_KEY: dir := 5;
      C_Keys.LEFT: dir := 6;
      C_Keys.HOME: dir := 7;
      C_Keys.NONE, 'E':
        begin
          CbtMap.RedrawArenaCell(cursorX, cursorY);
          FillChar(tgt, SizeOf(tgt), 0);
          done := False;
        end;
      'C':
        begin
          CbtMap.ScrollView(cursorX, cursorY, 0, 8);
          dir := 8;
        end;
    else
      dir := 8;
    end;
  end;
end;

procedure CombatAimMenu(creature: Types.PCreature; range, weaponMode, groundOk, creatureOk: Byte; var done: Boolean;
                        var tgt);
var
  targets: array[1..72] of Types.TTargetRec;
  effRange: Byte;
  tgtCount: Byte;
  curIdx: Byte;
  skipStep: ShortInt;
  menuStep: ShortInt;
  curX: ShortInt;
  curY: ShortInt;
  nextX: ShortInt;
  nextY: ShortInt;
  p: Types.PCreature;
  ch: Char;

  { Copies the targets within radius 127 of cr into the local target list. }
  procedure BuildAimTargets(cr: Types.PCreature);
  var
    i: Byte;
  begin
    Pathing.BuildTargetList(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), 127, 255, CbtMap.GetIconSize(cr),
                            GDVars.combatArena);
    tgtCount := GDVars.targetCount;
    for i := 1 to tgtCount do
      targets[i] := GDVars.targetList[i];
  end;

  { Steps the target index by step, wrapping; animate flies a marker to the new target, else the old cell is redrawn. }
  function AdvanceAimTarget(step: ShortInt; animate: Boolean): Types.PCreature;
  var
    { Unused in this version; see the other implementations of this routine. }
    markerCoords: array[0..3] of Byte;
  begin
    if animate then begin
      curX := GDVars.arenaSlots[targets[curIdx].idx].x;
      curY := GDVars.arenaSlots[targets[curIdx].idx].y;
    end else
      CbtMap.RedrawArenaCell(curX, curY);
    Inc(curIdx, step);
    if curIdx = 0 then
      curIdx := tgtCount;
    if curIdx > tgtCount then
      curIdx := 1;
    AdvanceAimTarget := GDVars.combatCreatures[targets[curIdx].idx];
    nextX := GDVars.arenaSlots[targets[curIdx].idx].x;
    nextY := GDVars.arenaSlots[targets[curIdx].idx].y;
    if animate then begin
      CharHlp.CombatAnimateMovingIcon(curX, curY, nextX, nextY, 1, 0);
      curX := nextX;
      curY := nextY;
    end;
  end;

begin
  CharHlp.CopyIconFacing(25, 0, 0, Byte(False));
  FillChar(tgt, SizeOf(TTgtRec), 0);
  done := False;
  effRange := range;
  if effRange = 255 then
    if Types.PCreature(creature)^.equipped[0] <> nil then
      effRange := GDVars.baseItems[Types.PCreature(creature)^.equipped[0]^.itemType].range - 1
    else
      effRange := 1;
  if (effRange = 0) or (effRange = 255) then
    effRange := 1;
  BuildAimTargets(creature);
  curIdx := 1;
  skipStep := 0;
  p := AdvanceAimTarget(skipStep, True);
  skipStep := 1;
  ch := ' ';
  while (done = False) and (not (ch in [C_Keys.NONE, 'E'])) do
  begin
    if not CbtActs.CanTarget(creature, p) then
      p := AdvanceAimTarget(skipStep, False)
    else begin
      ch := CbtActs.AimTargetMenu(creature, p, effRange, weaponMode, groundOk, creatureOk);
      if not GDVars.menuExtendedKey then begin
        case ch of
          'N':
            begin
              skipStep := 1;
              menuStep := 1;
            end;
          'P':
            begin
              skipStep := -1;
              menuStep := -1;
            end;
          C_Keys.RIGHT, C_Keys.UP, C_Keys.DOWN, C_Keys.RIGHT, C_Keys.LEFT, C_Keys.HOME,
              C_Keys.END_KEY, C_Keys.PAGE_DOWN, C_Keys.PAGE_UP:
            begin
              CbtActs.ManualAimCursor(creature, p, effRange, weaponMode, groundOk, creatureOk, done, TTgtRec(tgt));
              CharHlp.CopyIconFacing(25, 0, 0, Byte(False));
              BuildAimTargets(creature);
              menuStep := 0;
            end;
          'T':
            begin
              CbtActs.ConfirmAttackTarget(creature, p, weaponMode, done, TTgtRec(tgt));
              CharHlp.CopyIconFacing(25, 0, 0, Byte(False));
              BuildAimTargets(creature);
              menuStep := 0;
            end;
          'C':
            begin
              CbtMap.ScrollView(CbtMap.CombatCellX(p), CbtMap.CombatCellY(p), 0, 8);
              menuStep := 0;
            end;
        end;
      end else begin
        if ch in [C_Keys.HOME, C_Keys.UP, C_Keys.PAGE_UP, C_Keys.LEFT, C_Keys.RIGHT, C_Keys.END_KEY,
                  C_Keys.DOWN, C_Keys.PAGE_DOWN] then begin
          CbtActs.ManualAimCursor(creature, p, effRange, weaponMode, groundOk, creatureOk, done, TTgtRec(tgt));
          CharHlp.CopyIconFacing(25, 0, 0, Byte(False));
          BuildAimTargets(creature);
          menuStep := 0;
        end;
      end;
      CbtMap.RedrawArenaCell(CbtMap.CombatCellX(p), CbtMap.CombatCellY(p));
      p := AdvanceAimTarget(menuStep, (done = False) and (not (ch in [C_Keys.NONE, 'E'])));
    end;
  end;
  if weaponMode <> 0 then
    Border.ClearBox(0, 23, 39, 23);
end;

function AcquireTarget(creature: Types.PCreature; range, relaxed, forceNew: Byte): Boolean;
var
  cnt: Byte;
  tries: Byte;
  pick: Byte;
  second: Boolean;
  found: Boolean;
  pass: Boolean;
  p: Types.PCreature;
begin
  pass := False;
  found := False;
  second := False;
  p := creature^.combatAddr^.other;
  if (forceNew <> 0) or
      ((p <> nil) and
       ((p^.hostile = creature^.hostile) or (p^.enabled = 0) or (not CbtActs.CanTarget(creature, p)))) then
    creature^.combatAddr^.other := nil;
  if creature^.combatAddr^.other <> nil then
    found := True;
  while (not found) and (not second) do begin
    second := pass;
    if pass and (forceNew = 0) then
      GDVars.combatArena^.distMode := 1;
    tries := 20;
    cnt := CharHlp.CountTargets(creature, range);
    while (tries > 0) and (not found) and (cnt > 0) do begin
      Dec(tries);
      pick := FxEngine.RollDice(1, cnt);
      if GDVars.combatTargetSlots[pick] > 0 then begin
        p := GDVars.combatCreatures[GDVars.combatTargetSlots[pick]];
        if ((relaxed <> 0) and (GDVars.combatArena^.distMode <> 0))
           or CbtActs.CanTarget(creature, p) then begin
          found := True;
          creature^.combatAddr^.other := p;
        end else begin
          GDVars.combatTargetSlots[pick] := 0;
          for pick := 1 to cnt do
            if GDVars.combatTargetSlots[pick] > 0 then
              found := True;
          if found then
            found := False
          else
            cnt := 0;
        end;
      end;
    end;
    if not pass then
      pass := True;
  end;
  GDVars.combatArena^.distMode := 0;
  AcquireTarget := found;
end;

procedure AttackEngulf(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  defSlot: Byte;
  eff: Types.PEffect;
  def: Types.PCreature;
begin
  def := cr^.combatAddr^.other;
  if GDVars.phaseHits[1] <> 2 then
    Exit;
  if def^.enabled = 0 then
    Exit;
  if CharHlp.HasEffect(def, C_Effect.IMMOBILE, eff) then
    Exit;
  if CharHlp.HasEffect(def, 13, eff) then
    Exit;
  def := cr^.combatAddr^.other;
  CharHlp.PrintCreatureMessage(cr, 'engulfs ' + def^.name, 12, True);
  FxEngine.AddEffect(def, C_Effect.IMMOBILE, 0, CbtMap.CombatSlot(def), False);
  FxEngine.CallEffectHandler(C_Effect.IMMOBILE, def, nil, False);
  FxEngine.AddEffect(def, 13, 0, FxEngine.RollDice(2, 4), False);
  FxEngine.AddEffect(cr, 139, 0, CbtMap.CombatSlot(def), True);
end;

procedure AttackEyeRays(cr: Types.PCreature; effect: Types.PCombatRec; removed: Byte);
var
  eyesLeft: Byte;
  distance: Word;
  usedMask: Byte;
  castDone: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  saved: Byte;
  target: Pointer;

  { Draws ray icon rayIcon and flies it from the creature to its target. }
  procedure RayBeam(rayIcon: Byte);
  begin
    CharHlp.BuildIconFacings(rayIcon + 13);
    CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr),
                                    CbtMap.CombatCellX(Types.PCreature(target)),
                                    CbtMap.CombatCellY(Types.PCreature(target)), 1, 30);
  end;

  { Locks a target through AcquireTarget; castDone stays True when there is no target or the line to it is blocked. }
  procedure LosTrace(forceNew: Byte);
  var
    { Target column; WalkLine moves it to where the line stops. }
    rayX: ShortInt;
    { Target row; WalkLine moves it to where the line stops. }
    rayY: ShortInt;
  begin
    castDone := True;
    if CbtActs.AcquireTarget(cr, 255, 0, forceNew) then begin
      rayX := CbtMap.CombatCellX(cr^.combatAddr^.other);
      rayY := CbtMap.CombatCellY(cr^.combatAddr^.other);
      if Byte(Pathing.WalkLine(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), rayX, rayY, distance,
                               GDVars.combatArena)) <> 0 then
        castDone := False;
    end;
  end;

begin
  usedMask := 0;
  eyesLeft := 4;
  castDone := False;
  cr^.combatAddr^.other := nil;
  LosTrace(1);
  repeat
    target := cr^.combatAddr^.other;
    distance := CharHlp.CalcDistance(cr, target);
    Dec(eyesLeft);
    if target <> nil then begin
      if (distance <= 2) and ((usedMask and 1) = 0) then begin
        usedMask := usedMask or 1;
        CharHlp.PrintCreatureMessage(cr, 'fires a disintegrate ray', 10, True);
        RayBeam(5);
        if not FxEngine.RollSavingThrow(Types.PCreature(target), 3, 0) then
          FxEngine.KillCreature(target, C_Status.GONE, 'is disintergrated');
        LosTrace(0);
      end else if (distance <= 3) and ((usedMask and 2) = 0) then begin
        usedMask := usedMask or 2;
        CharHlp.PrintCreatureMessage(cr, 'fires a stone to flesh ray', 10, True);
        RayBeam(10);
        if not FxEngine.RollSavingThrow(Types.PCreature(target), 1, 0) then
          FxEngine.KillCreature(target, C_Status.STONED, 'is Stoned');
        LosTrace(0);
      end else if (distance <= 4) and ((usedMask and 4) = 0) then begin
        usedMask := usedMask or 4;
        CharHlp.PrintCreatureMessage(cr, 'fires a death ray', 10, True);
        RayBeam(5);
        if not FxEngine.RollSavingThrow(Types.PCreature(target), 0, 0) then
          FxEngine.KillCreature(target, C_Status.DEAD_STATUS, 'is killed');
        LosTrace(0);
      end else if (distance <= 5) and ((usedMask and 8) = 0) then begin
        usedMask := usedMask or 8;
        CharHlp.PrintCreatureMessage(cr, 'wounds you', 10, True);
        RayBeam(5);
        FxEngine.InflictNonWeaponDamage(Types.PCreature(target), FxEngine.RollDamageDice(2, 8) + 1, 0, False);
        LosTrace(0);
      end else begin
        if (usedMask and $10) = 0 then begin
          Magic.CastSpell(84, True, True, castDone);
          usedMask := usedMask or $10;
        end else if (usedMask and $20) = 0 then begin
          Magic.CastSpell(55, True, True, castDone);
          usedMask := usedMask or $20;
        end else if (usedMask and $40) = 0 then begin
          Magic.CastSpell(21, True, True, castDone);
          usedMask := usedMask or $40;
        end;
      end;
    end;
  until (eyesLeft <= 0) or (cr^.combatAddr^.other = nil);
end;

procedure AttackClawRake(cr: Types.PCreature; combat: Types.PCombatRec; secondary: Byte);
var
  done: Boolean;
begin
  GDVars.combatTarget := GDVars.combatCreatures[Byte(combat^.initiative)];
  if (secondary <> 0) or (cr^.enabled = 0) or (GDVars.combatTarget^.enabled = 0) then begin
    FxEngine.RemoveEffect(GDVars.combatTarget, C_Effect.IMMOBILE, nil);
    FxEngine.RemoveEffect(GDVars.combatTarget, 13, nil);
    if secondary = 0 then begin
      combat^.attackPhase := 0;
      FxEngine.RemoveEffect(cr, 139, combat);
    end;
  end else begin
    cr^.curAttacks[1] := 2;
    cr^.curAttacks[2] := 0;
    cr^.curRolls[1] := 2;
    cr^.curDice[1] := 8;
    CbtActs.MakeAttack(cr, GDVars.combatTarget, True, nil, done);
    done := CharHlp.EndActions(cr);
    if GDVars.combatTarget^.enabled = 0 then begin
      FxEngine.RemoveEffect(cr, 139, nil);
      FxEngine.RemoveEffect(GDVars.combatTarget, C_Effect.IMMOBILE, nil);
      FxEngine.RemoveEffect(GDVars.combatTarget, 13, nil);
    end;
  end;
end;

procedure BiteAndHold(creature: Types.PCreature; effect: Types.PCombatRec; removed: Byte);
var
  done: Boolean;
begin
  GDVars.combatTarget := GDVars.combatCreatures[Byte(effect^.initiative)];
  if (removed <> 0) or (creature^.enabled = 0) or (GDVars.combatTarget^.enabled = 0) then begin
    FxEngine.RemoveEffect(GDVars.combatTarget, C_Effect.IMMOBILE, nil);
    if removed = 0 then begin
      effect^.attackPhase := 0;
      FxEngine.RemoveEffect(creature, 144, effect);
    end;
  end else begin
    creature^.curAttacks[1] := 1;
    creature^.curAttacks[2] := 0;
    creature^.curRolls[1] := 2;
    creature^.curDice[1] := 8;
    CbtActs.MakeAttack(creature, GDVars.combatTarget, True, nil, done);
    done := CharHlp.EndActions(creature);
    if GDVars.combatTarget^.enabled = 0 then begin
      FxEngine.RemoveEffect(creature, 144, nil);
      FxEngine.RemoveEffect(GDVars.combatTarget, C_Effect.IMMOBILE, nil);
    end;
  end;
end;

procedure AttackHug(cr: Types.PCreature; effect: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  effAndSlot: array[0..4] of Byte;
begin
  if GDVars.attackRoll < 18 then
    Exit;
  GDVars.combatTarget := cr^.combatAddr^.other;
  CharHlp.PrintCreatureMessage(cr, 'hugs ' + GDVars.combatTarget^.name, 12, True);
  FxEngine.AddEffect(GDVars.combatTarget, C_Effect.IMMOBILE, 0,
                     CbtMap.CombatSlot(GDVars.combatTarget),
                     False);
  FxEngine.CallEffectHandler(C_Effect.IMMOBILE, GDVars.combatTarget, nil, False);
  FxEngine.AddEffect(cr, 144, 0, CbtMap.CombatSlot(GDVars.combatTarget), True);
end;

function VictoryCheat: Boolean;
var
  { Unused in this version; see the other implementations of this routine. }
  done: Boolean;
  p: Types.PCreature;
begin
  VictoryCheat := False;
  if ParamStr(2) <> GDVars.commandText then
    Exit;
  VictoryCheat := True;
  CharHlp.PrintBottomLine('The Gods intervene!');
  p := GDVars.partyHead;
  while p <> nil do begin
    if p^.hostile = 1 then begin
      p^.enabled := 0;
      p^.status := C_Status.DEAD_STATUS;
      GDVars.arenaSlots[CbtMap.CombatSlot(p)].size := 0;
    end;
    done := CharHlp.EndActions(p);
    p := p^.next;
  end;
  CbtMap.ScrollView(GDVars.combatArena^.focusX + 3, GDVars.combatArena^.focusY + 3, 255, 8);
end;

begin
end.
