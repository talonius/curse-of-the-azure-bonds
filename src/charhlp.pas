{ Character helpers: derived combat values from inventory and abilities, item names and lists, damage and status, the
  roster and message displays, combat sprites and bolts, target lists, and caster levels. }
{$O+,F+}
{$A-}
unit CharHlp;

interface

uses Types, GDConsts, GDVars, C_Keys, C_Status, C_Ifc, C_Race, C_Class, C_Stat, C_Pic, C_Gbvm, Crt,
  TextRend, Border, Blit, SoundDrv, CbtMap, Portrait, MenuCore, ClassCal, Pathing, MapTiles, EclTrace, MapView;

type
  { The armor-class parts RecalcStats adds up: 0 Dexterity, 1 the shield, 2 the pluses of protective items without an
    armor value, 3 the best ring plus, 4 the best armor (at least the base armor class). }
  TAcc5 = array[0..4] of ShortInt;

{ Builds an item's display name in its own name field: a Yes/No readied column when hdr is set, '*' on a magical item
  (plus, save bonus or cursed) when any party member has Detect Magic (effect 5), the quantity, then the identified name
  components, at most one of them pluralized when the quantity is above 1.
  @param(outS Unused.)
  @param(item The item to name.)
  @param(x Screen column for draw.)
  @param(y Screen row for draw.)
  @param(hdr Adds the readied column.)
  @param(draw Also prints the name at (x, y).) }
procedure PrintItemString(outS: Pointer; item: Types.PItem; x, y: Byte; hdr, draw: Boolean);

{ Draws the party roster: a Name, AC and HP heading on row 2 and one line per member from row 4 (cur in white, others
  colored by DisplayCreatureName), with AC and hit points right-aligned. The roster starts in column 1 in the main menu
  (interface state 0) and column 17 otherwise, and is not drawn in interface state 3.
  @param(cur The member to highlight, usually the current character.) }
procedure DisplayParty(cur: Types.PCreature);

{ Prints a character's current hit points: yellow below maximum, light green at maximum, light magenta when hurt is set.
  @param(cr The character.)
  @param(x Screen column.)
  @param(y Screen row.)
  @param(hurt Prints in light magenta.) }
procedure PrintHitPoints(cr: Types.PCreature; x, y: Byte; hurt: Boolean);

{ Prints a character's armor class in light green: 60 minus the stored value, with a minus sign when the value is above
  60.
  @param(cr The character.)
  @param(x Screen column.)
  @param(y Screen row.) }
procedure PrintArmorClass(cr: Types.PCreature; x, y: Byte);

{ Fills the combat side panel for a creature when the combat redraw flag is set (and clears the flag): name, hit points,
  armor class, readied weapon, and the status name of a disabled creature or '(Helpless)'.
  @param(cr The creature to show.) }
procedure CombatPrintCreatureInfo(cr: Types.PCreature);

{ Checks whether a creature has any of the four helpless status effects.
  @param(cr The creature.)
  @returns(True when it has one.) }
function IsHelpless(cr: Types.PCreature): Boolean;

{ Recomputes a character's derived values from its inventory: refills the readied-slot table (by item slot, with two
  ring slots, arrows in slot 11 and quarrels in slot 12), the item count, the hands in use and the encumbrance (item
  weights times quantity, plus coins); resets the current damage dice to the base dice; and rebuilds THAC0 and damage
  (WeaponAdjust), movement (ArmorMoveAdjust, EncumbranceAdjust) and armor class from Dexterity and readied items
  (AddItemArmorAdjust). acCur[0] gets the full AC value and acCur[1] the AC without Dexterity or shield, less 2;
  attackLevel gets the fighter level (including a dual-class fighter's earlier levels), or 1 for non-fighters and
  monsters. Note: the reduced-encumbrance branch never runs, because its flag is never set.
  @param(cr The character to update.) }
procedure RecalcStats(cr: Types.PCreature);

{ Formats a number in decimal.
  @param(value The number.)
  @returns(Its decimal digits, with a minus sign when negative.) }
function Int32Str(value: LongInt): String;

{ Formats a number in decimal.
  @param(value The number.)
  @returns(Its decimal digits.) }
function Uint16Str(value: Word): String;

{ Formats a number in decimal.
  @param(value The number.)
  @returns(Its decimal digits.) }
function Uint8Str(value: Byte): String;

{ Computes the Dexterity missile and initiative adjustment from the current Dexterity: -4 at 0..2, -3..-1 at 3..5,
  +1..+3 at 16..18, 3 at 19..20, 4 at 21..23, 5 at 24..25, else 0.
  @param(cr The creature.)
  @returns(The adjustment.) }
function DexMissileAdjust(cr: Types.PCreature): ShortInt;

{ Computes the Dexterity defensive adjustment from the current Dexterity: -4 at 1..3, -3..-1 at 4..6, +1..+4 at 15..18,
  4 at 19..20, 5 at 21..23, 6 at 24..25, else 0.
  @param(cr The creature.)
  @returns(The adjustment.) }
function DexterityArmorAdjustment(cr: Types.PCreature): ShortInt;

{ Computes the Strength to-hit bonus on TranslatedStrength's scale (-3 at 1..3 up to +7 at 30), or 0 unless useStrength
  is set.
  @param(cr The creature.)
  @returns(The to-hit bonus.) }
function StrToHitAdjust(cr: Types.PCreature): ShortInt;

{ Computes the Strength damage bonus on TranslatedStrength's scale (-2 at 1..2 up to +14 at 30), or 0 unless the
  creature's Strength bonus applies.
  @param(cr The creature.)
  @returns(The damage bonus.) }
function StrDamageAdjust(cr: Types.PCreature): ShortInt;

{ Computes the extra carrying allowance for a character's Strength on TranslatedStrength's scale, from -350 at 1..3 to
  15000 at 30, and 0 at 8..11.
  @param(cr The character.)
  @returns(The allowance, which may be negative.) }
function WeightAllowance(cr: Types.PCreature): Integer;

{ Clears the first memorized-spell byte equal to id (used when a spell being cast is lost).
  @param(cr The creature whose memorized spells are searched.)
  @param(id The spell to forget.) }
procedure RemoveSpell(cr: Types.PCreature; id: Byte);

{ Takes an item out of a creature's items and frees it; a nil item, or one not in the list, only gets an error message.
  @param(cr The creature.)
  @param(item The item.) }
procedure RemoveItem(cr: Types.PCreature; item: Types.PItem);

{ Appends a copy of an item to the end of a character's item list.
  @param(tgt The character who receives the copy.)
  @param(it The item to copy.) }
procedure AddItemCopy(tgt: Types.PCreature; it: Types.PItem);

{ Shows a message on the bottom row, waits for a key or delay (TextRend.PauseOnly), then clears the row.
  @param(msg The message.) }
procedure PrintBottomLine(msg: Types.TStr40);

{ Shows a creature's name and a message: in combat in the side panel, otherwise in the lower text window.
  @param(cr The creature to name.)
  @param(msg The message.)
  @param(row The first side-panel row, in combat.)
  @param(pause Waits and then clears the message area.) }
procedure PrintCreatureMessage(cr: Types.PCreature; msg: String; row: Byte; pause: Boolean);

{ Clears the message area: the side panel's rows 10..21 in combat, otherwise rows 18..22. }
procedure ClearMessageWindow;

{ Prints a creature's name: light red when it is out of action, yellow when hostile, light cyan otherwise.
  @param(cr The creature.)
  @param(x Column to print at.)
  @param(y Row to print at.)
  @param(tail True to add 's.) }
procedure DisplayCreatureName(cr: Types.PCreature; x, y: Byte; tail: Boolean);

{ Copies one frame of an icon slot into one frame of the combat effect sprite.
  @param(slot The icon slot.)
  @param(fromFrame The icon frame to copy.)
  @param(toFrame The sprite frame to fill.)
  @param(mirrored Mirrors the frame when nonzero.) }
procedure CopyIconFacing(slot, fromFrame, toFrame, mirrored: Byte);

{ Builds the combat effect sprite's four frames from an icon slot: frame 0, frame 0 mirrored, frame 1 mirrored, frame 1.
  @param(slot The icon slot.) }
procedure BuildIconFacings(slot: Byte);

{ Flies the combat view picture from one arena cell to another along a third-cell path, cycling its frames and keeping
  it in view: the view stays put when both ends are visible, is centered between them when they lie within 6 cells of
  each other, and otherwise follows the picture and finishes at the target. With a pause of 0 the picture is drawn on
  cell edges and skipped between them. Paths of fewer than four steps are not drawn.
  @param(x1 Start column.)
  @param(y1 Start row.)
  @param(x2 Target column.)
  @param(y2 Target row.)
  @param(frames The number of picture frames to cycle.)
  @param(stepDelay Milliseconds to pause on each drawn step.) }
procedure CombatAnimateMovingIcon(x1, y1, x2, y2: Integer; frames, stepDelay: Byte);

{ Announces an effect on a creature. In combat, builds the effect picture from icon slot 22 for an effect or 23 for
  damage, scrolls to the creature, plays the matching sound, prints the message and animates the picture over it (one
  more time than the game delay for an effect, once followed by a pause for damage); elsewhere prints the message with a
  pause.
  @param(cr The creature.)
  @param(hit Set for an effect, clear for damage.)
  @param(msg The message.) }
procedure PrintNameStringAnim(cr: Types.PCreature; hit: Boolean; msg: String);

{ Finds a creature's first copy of an effect.
  @param(cr The creature.)
  @param(effId The effect to look for.)
  @param(node Receives that effect, or nil.)
  @returns(True when the creature has the effect.) }
function HasEffect(cr: Types.PCreature; effId: Byte; var node: Types.PEffect): Boolean;

{ Subtracts damage from a creature's hit points. Falling more than 9 below 0, or an animated creature reaching 0, kills
  it; 1..9 below makes it dying (in combat the deficit is kept as overkill); landing on 0 makes it unconscious. A
  creature whose status is then anything but okay or animated is disabled at 0 hit points and, in combat, removed from
  its side's count and loses its initiative.
  @param(cr The creature.)
  @param(dmg The damage.) }
procedure InflictDamage(cr: Types.PCreature; dmg: Byte);

{ Prints 'is fully healed' or 'is partially healed' for a creature, and outside combat redraws the roster.
  @param(cr The healed creature.) }
procedure AnnounceHealStatus(cr: Types.PCreature);

{ Tells whether a creature is on the party's side.
  @param(cr The creature.)
  @returns(True when its hostile flag is 0.) }
function NotHostile(cr: Types.PCreature): Boolean;

{ Recounts the enabled creatures on each side. }
procedure CountTeams;

{ Builds the target list within a range of a creature, narrows it to the creature's enemies and copies their creature
  indices into the target-slot table.
  @param(cr The creature at the center.)
  @param(range The range.)
  @returns(The number of targets kept.) }
function CountTargets(cr: Pointer; range: Byte): Byte;

{ Measures the distance in whole steps from one creature to another, read from a fresh range-255 target list (the
  previous list is saved and restored). Note: an absent target gives the last entry's distance.
  @param(cr The creature measuring.)
  @param(target The creature to find.)
  @returns(The distance.) }
function CalcDistance(cr, target: Pointer): Byte;

{ Ends a creature's actions for the round: clears its initiative, casting, guarding and movement.
  @param(cr The creature.)
  @returns(Always True.) }
function EndActions(cr: Types.PCreature): Boolean;

{ Ends a creature's actions and sets it guarding, with a 'Guarding' message.
  @param(cr The creature.)
  @returns(Always True.) }
function Guard(cr: Types.PCreature): Boolean;

{ Computes the current character's caster level for a spell. With no cleric or magic-user levels, a paladin below 9 and
  a ranger below 8, it is 6. Otherwise by the spell's class: cleric spells use the higher of the cleric level and
  paladin level - 8; druid spells ranger level - 7 (at least 0); magic-user spells the higher of the magic-user level
  and ranger level - 8; special spells give 12. Dual-class earlier levels count. While an item is being used, any spell
  but a special one is cast at level 6.
  @param(spellId The spell.)
  @returns(The caster level.) }
function GetCasterLevel(spellId: Byte): Byte;

{ Redraws the noncombat screen for the current interface state (0 main menu, 1 shop or temple, 2 camp, 3 overland map
  unless the village picture is shown, 4 3D view, 6 treasure), with the roster and status line where they apply, and
  marks the map for redraw. }
procedure DisplayNoncombatInterface;

{ Draws the status line on row 15: the party's map position (unless the area hides it), compass direction and time, '*'
  while the debug trace is on, and ' camping' or ' search' when they apply. Not drawn in interface state 3. }
procedure PrintPositionAndTime;

{ Switches to the combat palette, draws the combat frame and rebuilds the combat view. }
procedure DisplayCombatInterface;

{ Lets the player pick a party member: Home and End move through the party, Enter or S selects, and E or Escape ends the
  pick.
  @param(prompt The prompt text.)
  @param(allowExit Offers an Exit choice; Exit or Escape then sets chosen to nil.)
  @param(chosen The member highlighted at the start; receives the pick.) }
procedure SelectChar(prompt: Types.TStr40; allowExit: Boolean; var chosen: Types.PCreature);

{ Tells whether a creature's readied weapon has a range above 1.
  @param(cr The creature.)
  @returns(True for a ranged weapon.) }
function HasRangedWeapon(cr: Types.PCreature): Boolean;

{ Tells whether a creature's readied weapon is ranged and is thrown as its own missile.
  @param(cr The creature.)
  @returns(True for a thrown weapon.) }
function HasThrowableWeapon(cr: Types.PCreature): Boolean;

{ Finds the missile for a creature's readied weapon: the weapon itself when it is its own missile (props $10), or for a
  weapon needing ammunition (props $8) the arrows (props bit 0) or quarrels (props bit 7) in their slots.
  @param(cr The creature.)
  @param(it Receives the missile, or nil.)
  @returns(True when a missile was found or props is exactly $A.) }
function FindDamagingRangedWeapon(cr: Types.PCreature; var it: Pointer): Boolean;

{ Checks whether a class of a character is at its racial level limit: dwarf, elf, gnome, half-elf and halfling fighters
  (by Strength), and the half-elf cleric at 5. Note: unlike CharGen.TrainingMenu it has no dwarf level-9, elf
  magic-user, or half-elf ranger and magic-user limits.
  @param(cr The character.)
  @param(cls The class level index.)
  @returns(True at the limit.) }
function AtLevelCap(cr: Types.PCreature; cls: ShortInt): Boolean;

{ Calls the priming entry of each overlay this unit uses, so the overlay manager loads them. }
procedure PrimeCharHlp;

{ Allocates a zeroed item record and fills it from the parameters.
  @param(itemType The item type.)
  @param(name1 The first name part.)
  @param(name2 The second name part.)
  @param(name3 The third name part.)
  @param(plus The magic bonus.)
  @param(saveBonus The saving-throw bonus.)
  @param(equipped Nonzero when readied.)
  @param(unidMask Bits of the name parts still unidentified.)
  @param(cursed Nonzero when cursed.)
  @param(weight The weight.)
  @param(quantity The quantity, 0 for a single item.)
  @param(value The value.)
  @param(charges The charges.)
  @param(effect The effect.)
  @param(special The special property.)
  @returns(The new item.) }
function MakeItem(itemType, name1, name2, name3, plus, saveBonus, equipped, unidMask, cursed: Byte; weight: Word;
                  quantity: Byte; value: Word; charges, effect, special: Byte): Types.PItem;

{ Tells whether any party member (a side-0 player or non-player character) is dying. With `bandage` set, the first dying
  member found is bandaged: it becomes unconscious, its overkill is cleared and the bandaging is announced.
  @param(bandage Set to bandage the first dying member.)
  @returns(True when a member is dying.) }
function BandageDying(bandage: Boolean): Boolean;

implementation

const
  { Word index into the GBVM zone-0 variables (GDVars.zone0^) of the game clock's minutes digit. }
  CLOCK_MINUTES = $4BC7;
  { Word index into the GBVM zone-0 variables (GDVars.zone0^) of the game clock's tens-of-minutes digit. }
  CLOCK_TEN_MINUTES = $4BC8;
  { The spell list (TSpellRec.castClass) of the special spells that no class casts. }
  SPECIAL_LIST = 3;

procedure WeaponAdjust(cr: Types.PCreature); forward;

procedure ArmorMoveAdjust(cr: Types.PCreature; item: Types.PItem); forward;

procedure AddItemArmorAdjust(cr: Types.PCreature; item: Types.PItem; var acc: TAcc5; var flagZ: Byte); forward;

procedure EncumbranceAdjust(cr: Types.PCreature); forward;

function TranslatedStrength(cr: Types.PCreature): Byte; forward;

procedure PrimeCharHlp;
begin
  MapTiles.PrimeMapTiles;
  EclTrace.PrimeEclTrace;
  Portrait.PrimePortrait;
  MapView.PrimeMapView;
  MenuCore.PrimeMenuCore;
  ClassCal.PrimeClassCal;
end;

{ Sets the readied weapon's THAC0 and damage. THAC0 starts from its base, plus the Dexterity missile adjustment for a
  missile weapon and the Strength to-hit bonus for a weapon that uses Strength, which also adds the Strength damage
  bonus. The damage modifier starts from the weapon's small-target modifier. The weapon's plus and its ammunition's plus
  (the readied quarrels or arrows it fires) are added to both the damage modifier and THAC0; an elf adds 1 more to THAC0
  alone with the bows and item types 36 and 37. The damage dice are the small-target dice. Does nothing without a
  readied weapon.
  @param(cr The character.) }
procedure WeaponAdjust(cr: Types.PCreature);
var
  item: Types.PItem;
  typ: Byte;
  acc: ShortInt;
begin
  item := cr^.equipped[0];
  if item = nil then Exit;
  typ := item^.itemType;
  cr^.thac0Cur := cr^.thac0Base;
  if (GDVars.baseItems[typ].props and 2) <> 0 then
    cr^.thac0Cur := cr^.thac0Cur + CharHlp.DexMissileAdjust(cr);
  cr^.curMod[1] := GDVars.baseItems[typ].dmgSmMod;
  if (GDVars.baseItems[typ].props and 4) <> 0 then begin
    cr^.thac0Cur := cr^.thac0Cur + CharHlp.StrToHitAdjust(cr);
    cr^.curMod[1] := cr^.curMod[1] + CharHlp.StrDamageAdjust(cr);
  end;
  acc := item^.plus;
  if GDVars.baseItems[typ].props > $7F then
    if cr^.equipped[12] <> nil then
      acc := acc + cr^.equipped[12]^.plus;
  if (GDVars.baseItems[typ].props and 1) > 0 then
    if cr^.equipped[11] <> nil then
      acc := acc + cr^.equipped[11]^.plus;
  cr^.curMod[1] := cr^.curMod[1] + acc;
  if cr^.race = C_Race.ELF then
    { the four bows are item types 41..44; 45 is the heavy crossbow }
    if ((item^.itemType > 40) and (item^.itemType < 45))
       or (item^.itemType = 37)
       or (item^.itemType = 36) then
      Inc(acc);
  cr^.thac0Cur := cr^.thac0Cur + acc;
  cr^.curRolls[1] := GDVars.baseItems[typ].dmgSmRolls;
  cr^.curDice[1] := GDVars.baseItems[typ].dmgSmDice;
end;

{ For worn body armor (slot 2), sets movementCur from its weight: the base movement up to 150, 9 up to 399, 6 above;
  magic armor adds 3 when that leaves 9 or less.
  @param(cr The wearer.)
  @param(item A readied item.) }
procedure ArmorMoveAdjust(cr: Types.PCreature; item: Types.PItem);
begin
  if GDVars.baseItems[item^.itemType].slot = 2 then begin
    case item^.weight of
      0..150: cr^.movementCur := cr^.moveRate;
      151..399: cr^.movementCur := 9;
    else
      cr^.movementCur := 6;
    end;
    if item^.plus <> 0 then
      if cr^.movementCur <= 9 then
        cr^.movementCur := cr^.movementCur + 3;
  end;
end;

{ Adds one readied item's armor-class part: a shield sets the first part; an item with armor code 0 adds its plus to the
  second part (rings keep the best ring plus in the third part instead) and its save bonus to the wearer's save bonus;
  other armor keeps the best code plus its plus in the fourth part. Items without an armor code add nothing.
  @param(cr The wearer.)
  @param(item A readied item.)
  @param(acc The armor-class parts being collected.)
  @param(flagZ Set by magic body armor, which later cancels the ring bonus.) }
procedure AddItemArmorAdjust(cr: Types.PCreature; item: Types.PItem; var acc: TAcc5; var flagZ: Byte);
var
  code: Byte;
  slot: Byte;
begin
  code := GDVars.baseItems[item^.itemType].acDescr;
  if code <= $7F then Exit;
  code := code and $7F;
  slot := GDVars.baseItems[item^.itemType].slot;
  if slot = 1 then begin
    acc[1] := code + item^.plus;
    Exit;
  end;
  if code = 0 then begin
    if slot = 9 then begin
      if item^.plus > acc[3] then
        acc[3] := item^.plus;
    end else
      acc[2] := acc[2] + item^.plus;
    cr^.saveBonus := cr^.saveBonus + item^.saveBonus;
  end else begin
    if code + item^.plus > acc[4] then begin
      acc[4] := code + item^.plus;
      if item^.plus > 0 then
        if slot = 2 then
          flagZ := 1;
    end;
  end;
end;

{ Limits movementCur by encumbrance beyond the weight allowance: up to 512 over leaves it, up to 768 caps it at 9, up to
  1024 at 6, and more at 3.
  @param(cr The character.) }
procedure EncumbranceAdjust(cr: Types.PCreature);
var
  v: Integer;
  r: Byte;
begin
  v := cr^.encumbrance - CharHlp.WeightAllowance(cr);
  if v < 0 then
    v := 0;
  case v of
    0..512: r := cr^.movementCur;
    513..768: r := 9;
    769..1024: r := 6;
  else
    r := 3;
  end;
  if r < cr^.movementCur then
    cr^.movementCur := r;
end;

procedure PrintItemString(outS: Pointer; item: Types.PItem; x, y: Byte; hdr, draw: Boolean);
var
  i: Byte;
  mask: Byte;
  ec: Types.PEffect;
  detectMagic: Boolean;
  special: Boolean;
  pw: Types.PCreature;
begin
  item^.name := '';
  if hdr then begin
    if item^.equipped <> 0 then
      item^.name := ' Yes  '
    else
      item^.name := ' No   ';
  end;
  detectMagic := False;
  pw := GDVars.partyHead;
  while (pw <> nil) and (not detectMagic) do begin
    if CharHlp.HasEffect(pw, 5, ec) then
      detectMagic := True;
    pw := pw^.next;
  end;
  if detectMagic then begin
    if (item^.plus > 0) or (item^.saveBonus > 0) or (item^.cursed <> 0) then
      item^.name := item^.name + '*' + ' ';
  end;
  if item^.quantity > 0 then
    item^.name := item^.name + CharHlp.Uint8Str(item^.quantity) + ' ';
  mask := 0;
  for i := 1 to 3 do
    if (item^.nameIds[i] <> 0) and ((item^.unidMask shr (3 - i)) and 1 = 0) then
      Inc(mask, 1 shl (i - 1));
  special := False;
  for i := 3 downto 1 do
    if (mask shr (i - 1)) and 1 > 0 then begin
      item^.name := item^.name + GDConsts.itemNames[item^.nameIds[i]];
      if (item^.quantity < 2) or special then
        item^.name := item^.name + ' '
      else if ((1 shl (i - 1)) = mask)
           or ((i = 1) and (mask > 4) and (item^.itemType <> 86))
           or ((i = 2) and not Odd(mask))
           or ((i = 3) and (item^.itemType = 86))
           or
             ((item^.nameIds[3] <> 135) and ((item^.itemType = 73) or (item^.itemType = 28)) and
              (item^.nameIds[3] <> 177)) then begin
        item^.name := item^.name + 's ';
        special := True;
      end else
        item^.name := item^.name + ' ';
    end;
  if draw then
    TextRend.DisplayString(x, y, LightGreen, 0, item^.name);
end;

procedure DisplayParty(cur: Types.PCreature);
var
  head: Types.PCreature;
  col: Byte;
  row: Byte;
  c: Byte;
begin
  if GDVars.ifcState = C_Ifc.OVERLAND then
    Exit;
  if GDVars.ifcState = 0 then
    col := 1
  else
    col := 17;
  row := 2;
  TextRend.DisplayString(col, row, White, 0, 'Name');
  TextRend.DisplayString(33, row, White, 0, 'AC  HP');
  Inc(row, 2);
  head := GDVars.partyHead;
  while head <> nil do begin
    Border.ClearBox(col, row, 38, row);
    if head = cur then
      TextRend.DisplayString(col, row, White, 0, head^.name)
    else
      CharHlp.DisplayCreatureName(head, col, row, False);
    case head^.acCur[0] of
      0..50: c := 1;
      51..60: c := 2;
      61..69: c := 1;
    else
      c := 0;
    end;
    CharHlp.PrintArmorClass(head, c + 32, row);
    case head^.hpCur of
      0..9: c := 2;
      10..99: c := 1;
    else
      c := 0;
    end;
    CharHlp.PrintHitPoints(head, c + 36, row, False);
    Inc(row);
    head := head^.next;
  end;
  Border.ClearBox(col, row, 38, row);
end;

procedure PrintArmorClass(cr: Types.PCreature; x, y: Byte);
var
  outStr: String;
  { Unused in this version; see the other implementations of this routine. }
  color: Byte;
begin
  outStr := CharHlp.Uint8Str(Abs(cr^.acCur[0] - 60));
  if cr^.acCur[0] > 60 then
    outStr := '-' + outStr;
  TextRend.DisplayString(x, y, LightGreen, 0, outStr);
end;

procedure PrintHitPoints(cr: Types.PCreature; x, y: Byte; hurt: Boolean);
var
  color: Byte;
  { Unused in this version; see the other implementations of this routine. }
  valueColor: Byte;
begin
  if cr^.hpCur < cr^.hpMax then
    color := 14
  else
    color := 10;
  if hurt then
    color := 13;
  TextRend.DisplayString(x, y, color, 0, CharHlp.Uint8Str(cr^.hpCur));
end;

procedure CombatPrintCreatureInfo(cr: Types.PCreature);
var
  { Unused in this version; see the other implementations of this routine. }
  col2: Byte;
  row: Byte;
begin
  if GDVars.combatRedraw then begin
    GDVars.combatRedraw := False;
    Border.ClearBox(23, 1, 38, 21);
    row := 1;
    CharHlp.PrintCreatureMessage(cr, ' ', row, False);
    Inc(row);
    TextRend.DisplayString(23, row + 1, LightGreen, 0, 'Hitpoints');
    CharHlp.PrintHitPoints(cr, 33, row + 1, False);
    Inc(row, 2);
    TextRend.DisplayString(23, row + 1, LightGreen, 0, 'AC');
    CharHlp.PrintArmorClass(cr, 26, row + 1);
    GDVars.curRow := row + 1;
    if cr^.equipped[0] <> nil then begin
      Inc(row, 2);
      col2 := 23;
      CharHlp.PrintItemString(cr, cr^.equipped[0], 0, 0, False, False);
      TextRend.DisplayMessageWindow(23, row + 1, 38, row + 1 + 2, LightGreen, 0, True, cr^.equipped[0]^.name);
    end;
    row := GDVars.curRow + 1;
    if cr^.enabled = 0 then
      TextRend.DisplayString(23, row + 1, White, 0, GDConsts.statusNames[ShortInt(cr^.status)])
    else if CharHlp.IsHelpless(cr) then
      TextRend.DisplayString(23, row + 1, White, 0, '(Helpless)');
  end;
end;

function IsHelpless(cr: Types.PCreature): Boolean;
var
  i: Byte;
  node: Types.PEffect;
begin
  IsHelpless := False;
  for i := 1 to 4 do
    if CharHlp.HasEffect(cr, GDConsts.statusEffects[i], node) then
      IsHelpless := True;
end;

procedure RecalcStats(cr: Types.PCreature);
var
  j: Byte;
  k: ShortInt;
  item: Types.PItem;
  flagZ: Byte;
  flagY: Byte;
  acc: TAcc5;
  i: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  propertySlot: Byte;
  coinIdx: ShortInt;
  itemAc: Word;
  tblResult: Byte;
begin
  for i := 0 to 12 do
    cr^.equipped[i] := nil;
  flagY := 0;
  cr^.numberOfItems := 0;
  item := cr^.itemsAddr;
  cr^.handsEquipped := 0;
  cr^.encumbrance := 0;
  GDVars.equippedWeight := 0;
  while item <> nil do begin
    Inc(cr^.numberOfItems);
    itemAc := item^.weight;
    if item^.quantity > 0 then
      itemAc := item^.quantity * itemAc;
    Inc(cr^.encumbrance, itemAc);
    if item^.equipped <> 0 then begin
      Inc(GDVars.equippedWeight, itemAc);
      tblResult := GDVars.baseItems[item^.itemType].slot;
      case tblResult of
        0..8:
          cr^.equipped[ShortInt(tblResult)] := item;
        9:
          if cr^.equipped[9] <> nil then begin
            if cr^.equipped[10] = nil then
              cr^.equipped[10] := item;
          end else
            cr^.equipped[9] := item;
      end;
      if item^.itemType = 73 then
        cr^.equipped[11] := item;
      if item^.itemType = 28 then
        cr^.equipped[12] := item;
      cr^.handsEquipped := cr^.handsEquipped + GDVars.baseItems[item^.itemType].hands;
    end;
    item := item^.next;
  end;
  for coinIdx := 0 to 6 do
    cr^.encumbrance := cr^.coins[coinIdx] + cr^.encumbrance;
  for j := 1 to 2 do begin
    cr^.curRolls[j] := cr^.baseRolls[j];
    cr^.curDice[j] := cr^.baseDice[j];
    cr^.curMod[j] := cr^.baseMod[j];
  end;
  for k := 0 to 4 do
    acc[k] := 0;
  flagZ := 0;
  cr^.saveBonus := 0;
  cr^.acCur[0] := cr^.acBase;
  cr^.movementCur := cr^.moveRate;
  cr^.thac0Cur := cr^.thac0Base;
  acc[0] := CharHlp.DexterityArmorAdjustment(cr);
  if cr^.equipped[0] = nil then begin
    cr^.thac0Cur := cr^.thac0Cur + CharHlp.StrToHitAdjust(cr);
    cr^.curMod[1] := cr^.curMod[1] + CharHlp.StrDamageAdjust(cr);
  end;
  CharHlp.WeaponAdjust(cr);
  item := cr^.itemsAddr;
  while item <> nil do begin
    if item^.equipped <> 0 then begin
      CharHlp.ArmorMoveAdjust(cr, item);
      CharHlp.AddItemArmorAdjust(cr, item, acc, flagZ);
    end;
    item := item^.next;
  end;
  if flagZ <> 0 then
    acc[3] := 0;
  if flagY <> 0 then begin
    if cr^.encumbrance < 5000 then
      cr^.encumbrance := 0
    else
      Dec(cr^.encumbrance, 5000);
    if cr^.encumbrance < GDVars.equippedWeight then
      cr^.encumbrance := GDVars.equippedWeight;
  end;
  CharHlp.EncumbranceAdjust(cr);
  if acc[4] < cr^.acCur[0] then
    acc[4] := cr^.acCur[0];
  cr^.acCur[0] := 0;
  for k := 0 to 4 do
    cr^.acCur[0] := cr^.acCur[0] + acc[k];
  cr^.acCur[1] := acc[4] + acc[2] + acc[3] - 2;
  if ((cr^.classLevels[C_Class.FIGHTER_LEVEL] > 0) or
      ((cr^.oldClassLevels[C_Class.FIGHTER_LEVEL] > 0) and (ClassCal.EarlierClassActive(Types.PCreature(cr)) <> 0)))
     and (cr^.race > C_Race.MONSTER) then
    cr^.attackLevel := cr^.classLevels[C_Class.FIGHTER_LEVEL] +
      ClassCal.EarlierClassActive(Types.PCreature(cr)) * cr^.oldClassLevels[C_Class.FIGHTER_LEVEL]
  else
    cr^.attackLevel := 1;
end;

function Uint8Str(value: Byte): String;
var
  s: String;
begin
  Str(value, s);
  Uint8Str := s;
end;

function Uint16Str(value: Word): String;
var
  s: String;
begin
  Str(value, s);
  Uint16Str := s;
end;

function Int32Str(value: LongInt): String;
var
  s: String;
begin
  Str(value, s);
  Int32Str := s;
end;

function DexterityArmorAdjustment(cr: Types.PCreature): ShortInt;
var
  t: Byte;
begin
  t := cr^.stats[C_Stat.DEXTERITY].current;
  case t of
    1..3: DexterityArmorAdjustment := -4;
    4..6: DexterityArmorAdjustment := t - 7;
    15..18: DexterityArmorAdjustment := t - 14;
    19..20: DexterityArmorAdjustment := 4;
    21..23: DexterityArmorAdjustment := 5;
    24..25: DexterityArmorAdjustment := 6;
  else
    DexterityArmorAdjustment := 0;
  end;
end;

function DexMissileAdjust(cr: Types.PCreature): ShortInt;
var
  t: Byte;
begin
  t := cr^.stats[C_Stat.DEXTERITY].current;
  case t of
    0..2: DexMissileAdjust := -4;
    3..5: DexMissileAdjust := t - 6;
    16..18: DexMissileAdjust := t - 15;
    19..20: DexMissileAdjust := 3;
    21..23: DexMissileAdjust := 4;
    24..25: DexMissileAdjust := 5;
  else
    DexMissileAdjust := 0;
  end;
end;

{ Converts Strength to one scale: 0..17 as is; 18 by exceptional Strength (without it 18, 01-50 19, 51-75 20, 76-90 21,
  91-99 22, 00 23); 19..25 become 24..30. Note: other values leave the result undefined.
  @param(cr The creature.)
  @returns(Strength on that scale.) }
function TranslatedStrength(cr: Types.PCreature): Byte;
begin
  case cr^.stats[C_Stat.STRENGTH].current of
    0..17: TranslatedStrength := cr^.stats[C_Stat.STRENGTH].current;
    18: case cr^.exStrCur of
              0: TranslatedStrength := 18;
              1..50: TranslatedStrength := 19;
              51..75: TranslatedStrength := 20;
              76..90: TranslatedStrength := 21;
              91..99: TranslatedStrength := 22;
              100: TranslatedStrength := 23;
            end;
    19..25: TranslatedStrength := cr^.stats[C_Stat.STRENGTH].current + 5;
  end;
end;

function StrToHitAdjust(cr: Types.PCreature): ShortInt;
var
  s: Byte;
begin
  StrToHitAdjust := 0;
  s := CharHlp.TranslatedStrength(cr);
  if cr^.useStrength <> 0 then
    case s of
      1..3: StrToHitAdjust := -3;
      4..5: StrToHitAdjust := -2;
      6..7: StrToHitAdjust := -1;
      17..19: StrToHitAdjust := 1;
      20..22: StrToHitAdjust := 2;
      23..25: StrToHitAdjust := 3;
      26..27: StrToHitAdjust := 4;
      28..30: StrToHitAdjust := s - 23;
    end;
end;

function StrDamageAdjust(cr: Types.PCreature): ShortInt;
var
  s: Byte;
begin
  StrDamageAdjust := 0;
  s := CharHlp.TranslatedStrength(cr);
  if cr^.useStrength <> 0 then
    case s of
      1..2: StrDamageAdjust := -2;
      3..5: StrDamageAdjust := -1;
      16: StrDamageAdjust := 1;
      17..19: StrDamageAdjust := s - 16;
      20..29: StrDamageAdjust := s - 17;
      30: StrDamageAdjust := 14;
    end;
end;

function WeightAllowance(cr: Types.PCreature): Integer;
var
  s: Byte;
begin
  s := CharHlp.TranslatedStrength(cr);
  case s of
    1..3: WeightAllowance := -350;
    4..5: WeightAllowance := -250;
    6..7: WeightAllowance := -150;
    12..13: WeightAllowance := 100;
    14..15: WeightAllowance := 200;
    16: WeightAllowance := 350;
    17..21: WeightAllowance := (s - 17) * 250 + 500;
    22..26: WeightAllowance := (s - 22) * 1000 + 2000;
    27: WeightAllowance := 7500;
    28..30: WeightAllowance := (s - 28) * 3000 + 9000;
  else
    WeightAllowance := 0;
  end;
end;

procedure RemoveSpell(cr: Types.PCreature; id: Byte);
var
  i: Byte;
begin
  i := 0;
  while i <= 83 do begin
    if cr^.memorizedSpells[i] = id then begin
      cr^.memorizedSpells[i] := 0;
      i := 84;
    end;
    Inc(i);
  end;
end;

procedure RemoveItem(cr: Types.PCreature; item: Types.PItem);
var
  cur: Types.PItem;
begin
  if item = nil then
    TextRend.DisplayAndPause(Yellow, 0, 'Nil Item pointer...')
  else begin
    cur := cr^.itemsAddr;
    if cur = item then
      cr^.itemsAddr := item^.next
    else
      while (cur <> nil) and (cur^.next <> item) do
        cur := cur^.next;
    if cur = nil then
      TextRend.DisplayAndPause(Yellow, 0, 'Tried to Lose item & couldn''t find it!')
    else begin
      cur^.next := item^.next;
      item^.next := nil;
      Dispose(item);
    end;
  end;
end;

procedure AddItemCopy(tgt: Types.PCreature; it: Types.PItem);
var
  cur: Types.PItem;
  newItem: Types.PItem;
begin
  New(newItem);
  Move(it^, newItem^, SizeOf(newItem^));
  newItem^.next := nil;
  cur := tgt^.itemsAddr;
  if cur = nil then
    tgt^.itemsAddr := newItem
  else begin
    while cur^.next <> nil do
      cur := cur^.next;
    cur^.next := newItem;
  end;
end;

procedure PrintBottomLine(msg: Types.TStr40);
begin
  Border.ClearBox(0, 24, 39, 24);
  TextRend.DisplayString(0, 24, LightGreen, 0, msg);
  TextRend.PauseOnly;
  Border.ClearBox(0, 24, 39, 24);
end;

procedure PrintCreatureMessage(cr: Types.PCreature; msg: String; row: Byte; pause: Boolean);
var
  col: Byte;
begin
  if GDVars.ifcState = C_Ifc.IN_COMBAT then begin
    Border.ClearBox(23, row, 38, 21);
    CharHlp.DisplayCreatureName(cr, 23, row, False);
    TextRend.DisplayMessageWindow(23, row + 1, 38, 21, LightGreen, 0, True, msg);
  end else begin
    if GDVars.noBorder <> 0 then
      col := 18
    else
      col := 17;
    Border.ClearBox(1, col, 38, 22);
    CharHlp.DisplayCreatureName(cr, 1, col + 1, False);
    TextRend.DisplayMessageWindow(1, col + 2, 38, 22, LightGreen, 0, True, msg);
  end;
  if pause then begin
    TextRend.PauseOnly;
    CharHlp.ClearMessageWindow;
  end;
end;

procedure ClearMessageWindow;
begin
  if GDVars.ifcState = C_Ifc.IN_COMBAT then
    Border.ClearBox(23, 10, 38, 21)
  else
    Border.ClearBox(1, 18, 38, 22);
end;

procedure DisplayCreatureName(cr: Types.PCreature; x, y: Byte; tail: Boolean);
var
  color: Byte;
begin
  if cr^.enabled = 0 then
    color := 12
  else if cr^.hostile = 1 then
    color := 14
  else
    color := 11;
  TextRend.DisplayString(x, y, color, 0, cr^.name);
  if tail then
    TextRend.DisplayString(x + Length(cr^.name), y, color, 0, '''s');
end;

procedure CopyIconFacing(slot, fromFrame, toFrame, mirrored: Byte);
var
  pic: Types.PImgBuf;
  stride: Word;
begin
  stride := GDVars.combatEffectSprite^.imgSize;
  if mirrored <> 0 then begin
    Blit.AllocPic(24, 3, 1, 1, Types.PImgBuf(pic));
    Blit.MirrorPic(Types.PImgBuf(GDVars.iconImages[slot, fromFrame]), Types.PImgBuf(pic));
    Move(pic^.data, GDVars.combatEffectSprite^.data[toFrame * stride], stride);
    Move(pic^.transp^, GDVars.combatEffectSprite^.transp^[toFrame * stride], stride);
    Blit.FreePic(Types.PImgBuf(pic));
  end else begin
    Move(GDVars.iconImages[slot, fromFrame]^.data, GDVars.combatEffectSprite^.data[toFrame * stride], stride);
    Move(GDVars.iconImages[slot, fromFrame]^.transp^, GDVars.combatEffectSprite^.transp^[toFrame * stride], stride);
  end;
end;

procedure BuildIconFacings(slot: Byte);
begin
  CharHlp.CopyIconFacing(slot, 0, 0, 0);
  CharHlp.CopyIconFacing(slot, 0, 1, 1);
  CharHlp.CopyIconFacing(slot, 1, 2, 1);
  CharHlp.CopyIconFacing(slot, 1, 3, 0);
end;

procedure CombatAnimateMovingIcon(x1, y1, x2, y2: Integer; frames, stepDelay: Byte);
var
  { step-direction path }
  pathBuf: array[0..147] of Byte;
  { the path request }
  seed: Types.TPathReq;
  { Unused in this version; see the other implementations of this routine. }
  boltLength: array[0..1] of Byte;
  { step index }
  i: Byte;
  { last usable path index: the step count minus 2 }
  pathCount: Byte;
  frameIdx: Byte;
  { Unused in this version; see the other implementations of this routine. }
  lastFrame: Byte;
  midFlag: Byte;
  { ends a walk: the path is done or the sprite left the view }
  stop: Boolean;
  { view center column }
  cellX: Integer;
  { view center row }
  cellY: Integer;
  { Unused in this version; see the other implementations of this routine. }
  xCur: Integer;
  { Unused in this version; see the other implementations of this routine. }
  yCur: Integer;
  { sub-cell X accumulator }
  accX: Integer;
  { sub-cell Y accumulator }
  accY: Integer;
  { column distance to the target }
  deltaX: Integer;
  { row distance to the target }
  deltaY: Integer;
  stepDx: Integer;
  stepDy: Integer;
  { sprite column in the view, in third-cells }
  pxX: Integer;
  { sprite row in the view, in third-cells }
  pxY: Integer;
  { view center shift near the arena's left or right edge }
  clX: Integer;
  { view center shift near the arena's top or bottom edge }
  clY: Integer;
begin
  xCur := x1;
  yCur := y1;
  FillChar(pathBuf, SizeOf(pathBuf), 8);
  FillChar(seed, SizeOf(seed), 0);
  i := 0;
  frameIdx := 0;
  seed.sx := x1 * 3;
  seed.sy := y1 * 3;
  seed.ex := x2 * 3;
  seed.ey := y2 * 3;
  Pathing.PathFind(seed);
  repeat
    stop := Byte(Pathing.NextPathStep(seed)) = 0;
    pathBuf[i] := seed.step;
    Inc(i);
  until stop;
  pathCount := i - 2;
  if (pathCount < 2) or (i < 2) then
    Exit;
  deltaX := x2 - x1;
  deltaY := y2 - y1;
  if (Byte(CbtMap.ViewCoordsValid(x1 - GDVars.combatArena^.focusX, y1 - GDVars.combatArena^.focusY)) = 0) or
      (Byte(CbtMap.ViewCoordsValid(x2 - GDVars.combatArena^.focusX, y2 - GDVars.combatArena^.focusY)) = 0) then begin
    if (Abs(deltaX) <= 6) and (Abs(deltaY) <= 6) then begin
      midFlag := 1;
      cellX := deltaX div 2 + x1;
      cellY := deltaY div 2 + y1;
    end else begin
      midFlag := 0;
      cellX := GDVars.combatArena^.focusX + 3;
      cellY := GDVars.combatArena^.focusY + 3;
    end;
  end else begin
    midFlag := 1;
    cellX := GDVars.combatArena^.focusX + 3;
    cellY := GDVars.combatArena^.focusY + 3;
  end;
  CbtMap.ScrollView(Byte(cellX), Byte(cellY), 255, 8);
  i := 0;
  accX := 0;
  accY := 0;
  repeat
    pxX := (x1 - GDVars.combatArena^.focusX) * 3 + accX;
    pxY := (y1 - GDVars.combatArena^.focusY) * 3 + accY;
    xCur := x1;
    yCur := y1;
    stop := False;
    repeat
      stepDx := GDConsts.directionDx[pathBuf[i]];
      stepDy := GDConsts.directionDy[pathBuf[i]];
      Inc(pxX, stepDx);
      Inc(pxY, stepDy);
      if (stepDelay > 0) or (pxX mod 3 = 0) or (pxY mod 3 = 0) then begin
        Blit.BlitTileClipped(pxX, pxY, frameIdx, 5, GDVars.combatEffectSprite, GDVars.viewBuffer);
        Blit.FlushView;
        Delay(stepDelay);
        Blit.BlitTileClipped(pxX, pxY, 0, 0, GDVars.saveUnder, GDVars.viewBuffer);
        Inc(frameIdx);
        if frameIdx >= frames then
          frameIdx := 0;
      end;
      Inc(i);
      if (pxX < 0) or (pxX > 18) or (pxY < 0) or (pxY > 18) then
        stop := True;
      if (not stop) and (i < pathCount) then begin
        Inc(accX, stepDx);
        Inc(accY, stepDy);
        if Abs(accX) = 3 then begin
          Inc(x1, Pathing.SignOf(accX));
          Inc(cellX, Pathing.SignOf(accX));
          accX := 0;
        end;
        if Abs(accY) = 3 then begin
          Inc(y1, Pathing.SignOf(accY));
          Inc(cellY, Pathing.SignOf(accY));
          accY := 0;
        end;
      end;
    until (i >= pathCount) or stop;
    if i < pathCount then begin
      clX := 0;
      clY := 0;
      accY := 0;
      accX := 0;
      x1 := x2;
      y1 := y2;
      xCur := x1;
      yCur := y1;
      if x2 + 3 > 49 then
        clX := x2 - 49
      else if x2 < 3 then
        clX := 3 - x2;
      if y2 + 3 > 24 then
        clY := y2 - 24
      else if y2 < 3 then
        clY := 3 - y2;
      cellX := x2 + clX;
      cellY := y2 + clY;
      CbtMap.ScrollView(Byte(cellX), Byte(cellY), 255, 8);
      pxX := (x2 - GDVars.combatArena^.focusX) * 3;
      pxY := (y2 - GDVars.combatArena^.focusY) * 3;
      i := pathCount;
      stop := False;
      repeat
        stepDx := -GDConsts.directionDx[pathBuf[i]];
        stepDy := -GDConsts.directionDy[pathBuf[i]];
        Inc(pxX, stepDx);
        Inc(pxY, stepDy);
        if pxX > 18 then
          x1 := GDVars.combatArena^.focusX + 6
        else if pxX < 0 then
          x1 := GDVars.combatArena^.focusX;
        if pxY > 18 then
          y1 := GDVars.combatArena^.focusY + 6
        else if pxY < 0 then
          y1 := GDVars.combatArena^.focusY;
        if (pxX < 0) or (pxX > 18) or (pxY < 0) or (pxY > 18) then
          stop := True;
        if not stop then begin
          Inc(accX, stepDx);
          Inc(accY, stepDy);
          if Abs(accX) = 3 then begin
            Inc(x1, Pathing.SignOf(accX));
            Inc(cellX, Pathing.SignOf(accX));
            accX := 0;
          end;
          if Abs(accY) = 3 then begin
            Inc(y1, Pathing.SignOf(accY));
            Inc(cellY, Pathing.SignOf(accY));
            accY := 0;
          end;
          Dec(i);
        end;
      until stop;
    end else begin
      midFlag := 1;
      if Byte(CbtMap.ViewCoordsValid(x2 - GDVars.combatArena^.focusX, y2 - GDVars.combatArena^.focusY)) = 0 then
        CbtMap.ScrollView(Byte(x2), Byte(y2), 3, 8);
      pxX := (x2 - GDVars.combatArena^.focusX) * 3;
      pxY := (y2 - GDVars.combatArena^.focusY) * 3;
      Blit.BlitTileClipped(pxX, pxY, frameIdx, 5, GDVars.combatEffectSprite, GDVars.viewBuffer);
      if stepDelay > 0 then begin
        Blit.FlushView;
        Delay(stepDelay);
        Blit.BlitTileClipped(pxX, pxY, 0, 0, GDVars.saveUnder, GDVars.viewBuffer);
      end;
    end;
  until midFlag <> 0;
  Blit.FlushView;
end;

procedure PrintNameStringAnim(cr: Types.PCreature; hit: Boolean; msg: String);
var
  targetX: ShortInt;
  targetY: ShortInt;
  cell: Byte;
  j: Byte;
  i: Byte;
  frameDelay: Byte;
begin
  if GDVars.ifcState = C_Ifc.IN_COMBAT then begin
    if hit then
      cell := 22
    else
      cell := 23;
    CharHlp.BuildIconFacings(cell);
    if Byte(CbtMap.CombatIconVisible(Types.PCreature(cr), 1)) = 0 then
      CbtMap.ScrollView(CbtMap.CombatCellX(Types.PCreature(cr)), CbtMap.CombatCellY(Types.PCreature(cr)), 3, 8);
    if hit then
      SoundDrv.SoundCommand(GDConsts.sndParamHit)
    else
      SoundDrv.SoundCommand(GDConsts.sndParamMiss);
    CharHlp.PrintCreatureMessage(cr, msg, 10, False);
    if hit then
      frameDelay := GDVars.gameDelay
    else
      frameDelay := 0;
    targetX := GDVars.gridX[CbtMap.CombatSlot(Types.PCreature(cr))] * 3;
    targetY := GDVars.gridY[CbtMap.CombatSlot(Types.PCreature(cr))] * 3;
    for i := 0 to frameDelay do
      for j := 0 to 3 do begin
        Blit.BlitTileClipped(targetX, targetY, j, 5, GDVars.combatEffectSprite, GDVars.viewBuffer);
        Blit.FlushView;
        Delay(70);
        Blit.BlitTileClipped(targetX, targetY, 0, 0, GDVars.saveUnder, GDVars.viewBuffer);
      end;
    Blit.FlushView;
    if frameDelay = 0 then
      TextRend.PauseOnly;
  end else
    CharHlp.PrintCreatureMessage(cr, msg, 10, True);
end;

function HasEffect(cr: Types.PCreature; effId: Byte; var node: Types.PEffect): Boolean;
var
  found: Boolean;
begin
  found := False;
  node := cr^.effects;
  while (node <> nil) and (not found) do
    if node^.id = effId then
      found := True
    else
      node := node^.next;
  HasEffect := found;
end;

procedure InflictDamage(cr: Types.PCreature; dmg: Byte);
var
  deficit: Byte;
  excess: Byte;
begin
  deficit := 0;
  excess := 0;
  if cr^.hpCur >= dmg then
    excess := cr^.hpCur - dmg
  else
    deficit := dmg - cr^.hpCur;
  if (deficit > 9) or ((excess = 0) and (cr^.status = C_Status.ANIMATED)) then
    cr^.status := C_Status.DEAD_STATUS
  else if deficit > 0 then begin
    cr^.status := C_Status.DYING;
    if GDVars.ifcState = C_Ifc.IN_COMBAT then
      cr^.combatAddr^.overkill := deficit;
  end else if excess = 0 then
    cr^.status := C_Status.UNCONSCIOUS;
  if not (cr^.status in [C_Status.OKAY, C_Status.ANIMATED]) then begin
    cr^.enabled := 0;
    cr^.hpCur := 0;
    if GDVars.ifcState = C_Ifc.IN_COMBAT then begin
      Dec(GDVars.teamCount[cr^.hostile]);
      cr^.combatAddr^.initiative := 0;
    end;
  end else
    cr^.hpCur := excess;
end;

procedure AnnounceHealStatus(cr: Types.PCreature);
var
  s: String[40];
begin
  if cr^.hpCur = cr^.hpMax then
    s := 'is fully healed'
  else
    s := 'is partially healed';
  CharHlp.PrintCreatureMessage(cr, s, 10, True);
  if GDVars.ifcState <> C_Ifc.IN_COMBAT then
    CharHlp.DisplayParty(GDVars.curChar);
end;

function NotHostile(cr: Types.PCreature): Boolean;
begin
  if cr^.hostile = 0 then
    NotHostile := True
  else
    NotHostile := False;
end;

procedure CountTeams;
var
  pw: Types.PCreature;
begin
  GDVars.teamCount[0] := 0;
  GDVars.teamCount[1] := 0;
  pw := GDVars.partyHead;
  while pw <> nil do begin
    if pw^.enabled <> 0 then
      Inc(GDVars.teamCount[pw^.hostile]);
    pw := pw^.next;
  end;
end;

function CountTargets(cr: Pointer; range: Byte): Byte;
var
  cnt: Byte;
  keep: Byte;
  i: Byte;
begin
  Pathing.BuildTargetList(CbtMap.CombatCellX(Types.PCreature(cr)), CbtMap.CombatCellY(Types.PCreature(cr)), range, 255,
                          CbtMap.GetIconSize(Types.PCreature(cr)), Pointer(GDVars.combatArena));
  cnt := GDVars.targetCount;
  keep := 0;
  if cnt > 0 then begin
    for i := 1 to cnt do begin
      { Keep the creatures on the other side from cr. }
      if Byte(GDVars.combatCreatures[GDVars.targetList[i].idx]^.hostile) = Byte(CharHlp.NotHostile(cr)) then begin
        Inc(keep);
        Move(GDVars.targetList[i], GDVars.targetList[keep], SizeOf(Types.TTargetRec));
      end;
    end;
    cnt := keep;
    GDVars.targetCount := keep;
  end;
  CountTargets := cnt;
  for i := 1 to cnt do
    GDVars.combatTargetSlots[i] := GDVars.targetList[i].idx;
end;

function CalcDistance(cr, target: Pointer): Byte;
var
  saved: array[0..764] of Byte;
  i: Byte;
begin
  Move(GDVars.targetList[1], saved, 216);
  GDVars.combatArena^.distMode := 1;
  Pathing.BuildTargetList(CbtMap.CombatCellX(Types.PCreature(cr)), CbtMap.CombatCellY(Types.PCreature(cr)), 255, 255,
                          CbtMap.GetIconSize(Types.PCreature(cr)), Pointer(GDVars.combatArena));
  GDVars.combatArena^.distMode := 0;
  i := 1;
  while (GDVars.combatCreatures[GDVars.targetList[i].idx] <> target) and (i < GDVars.targetCount) do
    Inc(i);
  { Pathing stores doubled distances. }
  CalcDistance := GDVars.targetList[i].dist div 2;
  Move(saved, GDVars.targetList[1], 216);
end;

function EndActions(cr: Types.PCreature): Boolean;
begin
  cr^.combatAddr^.initiative := 0;
  cr^.combatAddr^.spellCast := 0;
  cr^.combatAddr^.guarding := 0;
  cr^.combatAddr^.movement := 0;
  EndActions := True;
end;

function Guard(cr: Types.PCreature): Boolean;
begin
  Guard := CharHlp.EndActions(cr);
  cr^.combatAddr^.guarding := 1;
  CharHlp.PrintBottomLine('Guarding');
end;

function GetCasterLevel(spellId: Byte): Byte;
var
  a: ShortInt;
  b: ShortInt;
begin
  if (Types.PCreature(GDVars.curChar)^.classLevels[C_Class.CLERIC_LEVEL] = 0) and
      (Types.PCreature(GDVars.curChar)^.classLevels[C_Class.MAGE_LEVEL] = 0) and
      (Types.PCreature(GDVars.curChar)^.classLevels[C_Class.PALADIN_LEVEL] < 9) and
      (Types.PCreature(GDVars.curChar)^.classLevels[C_Class.RANGER_LEVEL] < 8) then
    GetCasterLevel := 6
  else
    case Char(GDConsts.spellProperties[spellId].castClass) of
      #0: begin
           a := Types.PCreature(GDVars.curChar)^.classLevels[C_Class.CLERIC_LEVEL] +
             Types.PCreature(GDVars.curChar)^.oldClassLevels[C_Class.CLERIC_LEVEL] *
             ClassCal.EarlierClassActive(Types.PCreature(GDVars.curChar));
           b := Types.PCreature(GDVars.curChar)^.classLevels[C_Class.PALADIN_LEVEL]
                +
                  Types.PCreature(GDVars.curChar)^.oldClassLevels[C_Class.PALADIN_LEVEL] *
                    ClassCal.EarlierClassActive(Types.PCreature(GDVars.curChar)) - 8;
           if a > b then GetCasterLevel := a else GetCasterLevel := b;
         end;
      #1: begin
           a := Types.PCreature(GDVars.curChar)^.classLevels[C_Class.RANGER_LEVEL]
                +
                  Types.PCreature(GDVars.curChar)^.oldClassLevels[C_Class.RANGER_LEVEL] *
                    ClassCal.EarlierClassActive(Types.PCreature(GDVars.curChar)) - 7;
           if a > 0 then GetCasterLevel := a else GetCasterLevel := 0;
         end;
      #2: begin
           a := Types.PCreature(GDVars.curChar)^.classLevels[C_Class.MAGE_LEVEL] +
             Types.PCreature(GDVars.curChar)^.oldClassLevels[C_Class.MAGE_LEVEL] *
             ClassCal.EarlierClassActive(Types.PCreature(GDVars.curChar));
           b := Types.PCreature(GDVars.curChar)^.classLevels[C_Class.RANGER_LEVEL]
                +
                  Types.PCreature(GDVars.curChar)^.oldClassLevels[C_Class.RANGER_LEVEL] *
                    ClassCal.EarlierClassActive(Types.PCreature(GDVars.curChar)) - 8;
           if a > b then GetCasterLevel := a else GetCasterLevel := b;
         end;
      #3: GetCasterLevel := 12;
    end;
  if GDVars.usingItem and (GDConsts.spellProperties[spellId].castClass <> CharHlp.SPECIAL_LIST) then
    GetCasterLevel := 6;
end;

procedure DisplayNoncombatInterface;
begin
  GDVars.mapRedrawPending := 1;
  case Char(GDVars.ifcState) of
    #0: Border.DrawWindowFrame;
    { shop or temple }
    #1: begin
         if GDVars.shopSession then
           Border.DrawViewFrame;
         if GDVars.loadedPicId = C_Pic.VILLAGE then
           Portrait.DisplayImageBuf(3, 3, True, GDVars.animData.frames[1].pic)
         else begin
           Portrait.LoadPortraitBufs(GDVars.portraitHeadId, GDVars.portraitBodyId);
           Portrait.DisplayPortraitBufs(3, 3, True);
         end;
         CharHlp.DisplayParty(GDVars.curChar);
         CharHlp.PrintPositionAndTime;
       end;
    { camp }
    #2: begin
         Border.DrawViewFrame;
         Portrait.LoadAnimation('PIC', 29, 0, GDVars.animData);
         CharHlp.DisplayParty(GDVars.curChar);
         CharHlp.PrintPositionAndTime;
       end;
    { 3D view }
    #4: begin
         Border.DrawViewFrame;
         MapView.DisplayMapView;
         CharHlp.DisplayParty(GDVars.curChar);
         CharHlp.PrintPositionAndTime;
         GDVars.charSelectActive := 0;
       end;
    { overland }
    #3: if GDVars.loadedPicId <> C_Pic.VILLAGE then
         MapView.DisplayMapView;
    { treasure screen }
    #6: begin
         Border.DrawViewFrame;
         Portrait.LoadAnimation('PIC', 1, 0, GDVars.animData);
         CharHlp.DisplayParty(GDVars.curChar);
       end;
  end;
end;

procedure PrintPositionAndTime;
var
  mapX: Byte;
  mapY: Byte;
  hourStr: String[2];
  minuteStr: String[2];
  acc: String[40];
begin
  if GDVars.ifcState = C_Ifc.OVERLAND then
    Exit;
  acc := '';
  mapX := GDVars.partyPos.mapX;
  mapY := GDVars.partyPos.mapY;
  hourStr := CharHlp.Uint16Str(GDVars.zone0^[C_Gbvm.CLOCK_HOURS]);
  if Length(hourStr) < 2 then
    hourStr := '0' + hourStr;
  minuteStr := CharHlp.Uint16Str(GDVars.zone0^[CharHlp.CLOCK_MINUTES] + GDVars.zone0^[CharHlp.CLOCK_TEN_MINUTES] * 10);
  if Length(minuteStr) < 2 then
    minuteStr := '0' + minuteStr;
  if GDVars.zone0^[C_Gbvm.NO_AUTOMAP] = 0 then
    acc := CharHlp.Uint8Str(mapX) + ',' + CharHlp.Uint8Str(mapY) + ' ';
  acc := acc + GDConsts.compassNames[GDVars.partyPos.facing] + ' ';
  acc := acc + hourStr + ':' + minuteStr;
  if GDVars.debugTraceEnabled then
    acc := acc + '*';
  if GDVars.ifcState = C_Ifc.CAMPING then
    acc := acc + ' camping'
  else if (GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] and 1) > 0 then
    acc := acc + ' search';
  Border.ClearBox(17, 15, 38, 15);
  TextRend.DisplayString(17, 15, LightGreen, 0, acc);
end;

procedure DisplayCombatInterface;
begin
  CbtMap.SetCombatPalette;
  Border.DrawCombatFrame;
  CbtMap.ScrollView(GDVars.combatArena^.focusX + 3, GDVars.combatArena^.focusY + 3, 255, 8);
end;

procedure SelectChar(prompt: Types.TStr40; allowExit: Boolean; var chosen: Types.PCreature);
var
  key: Byte;
  valid: Byte;
  reinterpret: Byte;
  cursor: Types.PCreature;
  exitOption: String[40];
begin
  key := 32;
  exitOption := '';
  if allowExit then
    exitOption := ' Exit';
  while not (key in [Ord(C_Keys.ENTER), Ord(C_Keys.ESCAPE), Ord('E'), Ord('S')]) do begin
    CharHlp.DisplayParty(chosen);
    if (GDVars.ifcState = C_Ifc.CAMPING) or (GDVars.ifcState = C_Ifc.LOOT) then
      reinterpret := 1
    else
      reinterpret := 0;
    key := Byte(MenuCore.MenuHorizontal(prompt + ' ', 'Select' + exitOption, LightMagenta, LightGreen, White, True,
                                        Boolean(reinterpret), Boolean(valid)));
    cursor := chosen;
    if valid <> 0 then begin
      case Char(key) of
        C_Keys.END_KEY: begin
               cursor := cursor^.next;
               if cursor = nil then
                 cursor := GDVars.partyHead;
             end;
        C_Keys.HOME: begin
               cursor := GDVars.partyHead;
               if chosen <> GDVars.partyHead then
                 while cursor^.next <> chosen do
                   cursor := cursor^.next
               else
                 while cursor^.next <> nil do
                   cursor := cursor^.next;
             end;
      end;
    end else begin
      if allowExit and ((key = Ord('E')) or (key = 0)) then
        cursor := nil;
    end;
    chosen := cursor;
  end;
end;

function HasRangedWeapon(cr: Types.PCreature): Boolean;
begin
  if (cr^.equipped[0] <> nil)
     and (GDVars.baseItems[cr^.equipped[0]^.itemType].range > 1) then
    HasRangedWeapon := True
  else
    HasRangedWeapon := False;
end;

function HasThrowableWeapon(cr: Types.PCreature): Boolean;
begin
  if CharHlp.HasRangedWeapon(cr)
     and ((GDVars.baseItems[cr^.equipped[0]^.itemType].props and $14) = $14) then
    HasThrowableWeapon := True
  else
    HasThrowableWeapon := False;
end;

function FindDamagingRangedWeapon(cr: Types.PCreature; var it: Pointer): Boolean;
var
  cur: Types.PItem;
  flags: Byte;
begin
  FindDamagingRangedWeapon := False;
  cur := cr^.equipped[0];
  it := nil;
  flags := 0;
  if cur <> nil then begin
    flags := GDVars.baseItems[cur^.itemType].props;
    if (flags and $10) <> 0 then
      it := cur;
    if (flags and $8) <> 0 then begin
      if (flags and $1) <> 0 then
        it := cr^.equipped[11];
      if (flags and $80) <> 0 then
        it := cr^.equipped[12];
    end;
  end;
  if (it <> nil) or (flags = 10) then
    FindDamagingRangedWeapon := True;
end;

function AtLevelCap(cr: Types.PCreature; cls: ShortInt): Boolean;
var
  lev: ShortInt;
begin
  AtLevelCap := False;
  with cr^ do begin
    lev := classLevels[cls];
    if lev > 0 then begin
      case Char(race) of
        { dwarf }
        #1:
          if (cls = C_Class.FIGHTER_LEVEL) and
              (((lev = 8) and (stats[C_Stat.STRENGTH].current = 17)) or
               ((lev = 7) and (stats[C_Stat.STRENGTH].current < 17))) then
            AtLevelCap := True;
        { elf }
        #2:
          if (cls = C_Class.FIGHTER_LEVEL) and
              ((lev = 7) or ((lev = 6) and (stats[C_Stat.STRENGTH].current = 17)) or
               ((lev = 5) and (stats[C_Stat.STRENGTH].current < 17))) then
            AtLevelCap := True;
        { gnome }
        #3:
          if (cls = C_Class.FIGHTER_LEVEL) and ((lev = 6) or ((lev = 5) and (stats[C_Stat.STRENGTH].current < 18))) then
            AtLevelCap := True;
        { half-elf }
        #4:
          if (cls = C_Class.CLERIC_LEVEL) and (lev = 5) then
            AtLevelCap := True
          else if (cls = C_Class.FIGHTER_LEVEL) and
            ((lev = 8) or ((lev = 7) and (stats[C_Stat.STRENGTH].current = 17)) or
             ((lev = 6) and (stats[C_Stat.STRENGTH].current < 17))) then
            AtLevelCap := True;
        { halfling }
        #5:
          if (cls = C_Class.FIGHTER_LEVEL) and
              ((lev = 6) or ((lev = 5) and (stats[C_Stat.STRENGTH].current = 17)) or
               ((lev = 4) and (stats[C_Stat.STRENGTH].current < 17))) then
            AtLevelCap := True;
      end;
    end;
  end;
end;

function MakeItem(itemType, name1, name2, name3, plus, saveBonus, equipped, unidMask, cursed: Byte; weight: Word;
                  quantity: Byte; value: Word; charges, effect, special: Byte): Types.PItem;
var
  p: Types.PItem;
begin
  New(p);
  FillChar(p^, SizeOf(p^), 0);
  p^.itemType := itemType;
  p^.nameIds[1] := name1;
  p^.nameIds[2] := name2;
  p^.nameIds[3] := name3;
  p^.plus := plus;
  p^.saveBonus := saveBonus;
  p^.equipped := equipped;
  p^.unidMask := unidMask;
  p^.cursed := cursed;
  p^.weight := weight;
  p^.quantity := quantity;
  p^.value := value;
  p^.charges := charges;
  p^.effect := effect;
  p^.special := special;
  MakeItem := p;
end;

function BandageDying(bandage: Boolean): Boolean;
var
  pw: Types.PCreature;
  found: Boolean;
begin
  found := False;
  pw := GDVars.partyHead;
  while pw <> nil do begin
    if (pw^.combatAddr^.notPcNpc = 0) and (pw^.hostile = 0)
       and (pw^.status = C_Status.DYING) then begin
      found := True;
      if bandage then begin
        pw^.status := C_Status.UNCONSCIOUS;
        pw^.combatAddr^.overkill := 0;
        CharHlp.PrintCreatureMessage(pw, 'is bandaged', 10, True);
        bandage := False;
      end;
    end;
    pw := pw^.next;
  end;
  BandageDying := found;
end;

begin
end.
