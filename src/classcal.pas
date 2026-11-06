{ Class-derived values: THAC0, attacks, spell slots, saving throws, thief skills and usable items, plus the human
  dual-class change. }
{$O+,F+}
{$A-}
unit ClassCal;

interface

uses Types, GDConsts, GDVars, C_Keys, C_Race, C_Class, C_Stat, C_Spell, MenuCore, EclTrace, TextRend, Crt;

{ Recomputes a character's level-derived values. The THAC0 base (thac0Base) becomes the best of its classes at their
  levels and levelHighest rises to its highest class level; a fighter or paladin above level 6 or a ranger above level 7
  gets 3 half-attacks. It then rebuilds the spell slots (RecalcSpellSlots), the saving throws (RecalcSaves) and, with
  thief levels, the thief skills (RecalcThiefSkills). The class mask (classMask) collects the item masks of the classes
  it has levels in, plus each earlier class whose level is below levelHighest; an equipped, uncursed item in an
  equipment slot that no class in the mask may use is unreadied. Once a dual-class character has passed its earlier
  class (EarlierClassActive), the earlier class levels also count for THAC0 and attacks, and earlier thief levels
  rebuild the thief skills.
  @param(cr The character to update.) }
procedure RecalcClassStats(cr: Types.PCreature);

{ Adds the Wisdom bonus cleric slots when the character has cleric levels, counting its earlier cleric levels once it
  has passed them (EarlierClassActive). Wisdom above 12 and above 13 each add a first-level slot, above 14 and above 15
  each a second-level slot, above 16 a third-level slot and above 17 a fourth-level slot, each only to a spell level
  that already has slots.
  @param(cr The character to update.)
  @param(rebuild True to rebuild the cleric slots from the cleric progression before adding the bonus.) }
procedure RecalcClericSlots(cr: Types.PCreature; rebuild: Boolean);

{ Recomputes a character's five saving throws (saves). Each starts at 20 and takes the lowest table value of its classes
  at their levels. Save 0 then adds 1 to 5, rising with Constitution from 4 to 18, for a dwarf, a halfling or a
  character with an equipped item with special $86, and 1 to 4 for Constitution 19 to 25 for anyone. Note: the
  earlier-class check reuses j after its loop has ended, so it looks only at class 7, and only when the current level of
  class 7 is above its earlier level.
  @param(cr The character to update.) }
procedure RecalcSaves(cr: Types.PCreature);

{ Recomputes a character's eight thief skills (thiefSkills) from the thief skill table at its thief level, counting its
  earlier thief levels once it has passed them (EarlierClassActive). Each skill takes the race adjustment, falling to 0
  when a race penalty exceeds it, and skills 1 to 5 also take the Dexterity adjustment. The first equipped item with
  special $82 or $8B counts: $82 raises a level below 4 to 4, or else adds 10 to each skill; $8B computes skill 1 at
  level 5 at least and skill 2 at level 7 at least, adding 5 to a skill whose level is already that high, and the 5 or 0
  chosen for skill 2 is added to skills 3 to 8 as well. Note: without a $8B item the bonus added to each skill is never
  set, so it adds whatever the local held. Note: a Dexterity below 9 is not checked against the Dexterity adjustment
  table, so it reads before the table, from the race adjustment table.
  @param(cr The character to update.) }
procedure RecalcThiefSkills(cr: Types.PCreature);

{ Lets a character change class (dual-class). Lists the classes its race allows that it qualifies for, or reports that
  it does not qualify. On a pick it resets the experience and attacks, keeps the old class's level as the earlier level,
  records levelHighest as the level at the change (levelAtChange), starts the new class at level 1 with fresh spell
  slots (a magic-user also learns four spells), clears memorized spells, recomputes its class-derived values and
  unreadies uncursed items the new class mask does not allow. Note: Escape returns without freeing the class list.
  @param(cr The character changing class.) }
procedure ChangeClass(cr: Types.PCreature);

{ Tells whether a character is human.
  @param(cr The character to check.)
  @returns(1 for a human, 0 otherwise.) }
function IsHuman(cr: Types.PCreature): Byte;

{ Finds the first class in which a human has an earlier (pre-change) level.
  @param(cr The character to check.)
  @returns(That class; 17 for a non-human or when there is none.) }
function FirstEarlierClass(cr: Types.PCreature): Byte;

{ Finds the first class in which a human has a current level.
  @param(cr The character to check.)
  @returns(That class; 17 for a non-human or when there is none.) }
function FirstCurrentClass(cr: Types.PCreature): Byte;

{ Finds a human's current level in its first class with a level.
  @param(cr The character to check.)
  @returns(That level; 0 for a non-human or a human with no level.) }
function CurrentDualClassLevel(cr: Types.PCreature): ShortInt;

{ Tells whether a dual-class character's current class level exceeds the level it had when it changed class
  (levelAtChange), which lets its earlier class's abilities count again.
  @param(cr The character to check.)
  @returns(1 when the earlier class counts again, 0 otherwise.) }
function EarlierClassActive(cr: Types.PCreature): ShortInt;

{ Calls the priming entries of EclTrace and MenuCore, so the overlay manager loads them. }
procedure PrimeClassCal;

implementation

const
  { race values (TCreature.race) }
  DWARF = 1;
  HALFLING = 5;
  { The druid spell list (TSpellRec.castClass), which rangers cast. }
  DRUID_LIST = 1;

procedure PrimeClassCal;
begin
  EclTrace.PrimeEclTrace;
  MenuCore.PrimeMenuCore;
end;

procedure RecalcSpellSlots(cr: Types.PCreature); forward;

{ Rebuilds a character's spell slots from its class levels, using an earlier class's level instead once a dual-class
  character has passed it (EarlierClassActive). A cleric gets one first-level slot plus the cleric progression for each
  level above 1, the Wisdom bonus slots (RecalcClericSlots), and knows each cleric spell of a level it has slots for,
  except spell 36. A paladin above level 8 adds its cleric slots for levels 9 up and knows each cleric spell of a level
  it has slots for. A ranger above level 7 adds its druid slots (spell levels 1 to 3) and magic-user slots (spell levels
  1 and 2) for levels 8 up and knows each druid spell. A magic-user gets one first-level slot plus its progression. Each
  equipped item with special $81 doubles the magic-user slots of spell levels 1 to 3.
  @param(cr The character to update.) }
procedure RecalcSpellSlots(cr: Types.PCreature);
var
  i: ShortInt;
  level: ShortInt;
  j: ShortInt;
  tmp: ShortInt;
  k: ShortInt;
  m: Byte;
  itm: Types.PItem;
begin
  with cr^ do begin
    FillChar(spellSlots, SizeOf(spellSlots), 0);
    for i := 0 to 7 do begin
      if (ClassCal.EarlierClassActive(cr) <> 0) and (oldClassLevels[i] <> 0) then
        level := oldClassLevels[i]
      else
        level := classLevels[i];
      if level > 0 then
        case Char(i) of
          #0: begin
               Inc(spellSlots[C_Spell.CLERIC_LIST, 1]);
               for j := 2 to level do
                 for k := 1 to 5 do
                   Inc(spellSlots[C_Spell.CLERIC_LIST, k], GDConsts.classExperience[C_Class.CLERIC].slots[j, k]);
               ClassCal.RecalcClericSlots(cr, False);
               for m := 1 to 100 do
                 with GDConsts.spellProperties[m] do
                   if (castClass = C_Spell.CLERIC_LIST) and (spellSlots[C_Spell.CLERIC_LIST, level] > 0) and
                       (m <> 36) then
                     knownSpells[m] := 1;
             end;
          #3: if level > 8 then begin
               for j := 9 to level do
                 for k := 1 to 5 do
                   Inc(spellSlots[C_Spell.CLERIC_LIST, k], GDConsts.classExperience[C_Class.PALADIN].slots[j, k]);
               for m := 1 to 100 do
                 with GDConsts.spellProperties[m] do
                   if (castClass = C_Spell.CLERIC_LIST) and (spellSlots[C_Spell.CLERIC_LIST, level] > 0) then
                     knownSpells[m] := 1;
             end;
          #4: if level > 7 then begin
               for j := 8 to level do begin
                 for k := 1 to 3 do
                   Inc(spellSlots[ClassCal.DRUID_LIST, k], GDConsts.classExperience[C_Class.RANGER].slots[j, k]);
                 for k := 4 to 5 do begin
                   tmp := k - 3;
                   Inc(spellSlots[C_Spell.MAGE_LIST, tmp], GDConsts.classExperience[C_Class.RANGER].slots[j, k]);
                 end;
               end;
               for m := 1 to 100 do
                 if GDConsts.spellProperties[m].castClass = ClassCal.DRUID_LIST then
                   knownSpells[m] := 1;
             end;
          #5: begin
               Inc(spellSlots[C_Spell.MAGE_LIST, 1]);
               for j := 2 to level do
                 for k := 1 to 5 do
                   Inc(spellSlots[C_Spell.MAGE_LIST, k], GDConsts.classExperience[C_Class.MAGE].slots[j, k]);
             end;
        end;
    end;
    itm := itemsAddr;
    while itm <> nil do begin
      if itm^.special = $81 then
        if itm^.equipped <> 0 then
          for k := 1 to 3 do
            Inc(cr^.spellSlots[C_Spell.MAGE_LIST, k], cr^.spellSlots[C_Spell.MAGE_LIST, k]);
      itm := itm^.next;
    end;
  end;
end;

procedure RecalcClassStats(cr: Types.PCreature);
var
  i: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  spellLevel: Integer;
  level: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  spellIndex: Byte;
  m: ShortInt;
begin
  cr^.thac0Base := 0;
  for i := 0 to 7 do begin
    level := cr^.classLevels[i];
    if GDConsts.classThac0[i, level] > cr^.thac0Base then cr^.thac0Base := GDConsts.classThac0[i, level];
    if cr^.levelHighest < level then cr^.levelHighest := level;
    case Char(i) of
      #2: if level > 6 then cr^.attacks := 3;
      #4: if level > 7 then cr^.attacks := 3;
      #3: if level > 6 then cr^.attacks := 3;
    end;
  end;
  ClassCal.RecalcSpellSlots(cr);
  ClassCal.RecalcSaves(cr);
  if cr^.classLevels[C_Class.THIEF_LEVEL] > 0 then ClassCal.RecalcThiefSkills(cr);
  cr^.classMask := 0;
  for i := 0 to 7 do
    if (cr^.classLevels[i] > 0) or ((cr^.oldClassLevels[i] > 0) and (cr^.oldClassLevels[i] < cr^.levelHighest)) then
      Inc(cr^.classMask, GDConsts.classItemMasks[i]);
  for m := 0 to 12 do
    if cr^.equipped[m] <> nil then
      if (GDVars.baseItems[cr^.equipped[m]^.itemType].classMask and cr^.classMask) = 0 then
        if cr^.equipped[m]^.cursed = 0 then
          cr^.equipped[m]^.equipped := 0;
  if ClassCal.EarlierClassActive(cr) <> 0 then begin
    for i := 0 to 7 do begin
      level := cr^.oldClassLevels[i];
      case Char(i) of
        #2, #3: if level > 6 then cr^.attacks := 3;
        #4: if level > 7 then cr^.attacks := 3;
      end;
      if GDConsts.classThac0[i, level] > cr^.thac0Base then cr^.thac0Base := GDConsts.classThac0[i, level];
    end;
    if (cr^.oldClassLevels[C_Class.FIGHTER_LEVEL] > 6) or (cr^.oldClassLevels[C_Class.RANGER_LEVEL] > 7) or
        (cr^.oldClassLevels[C_Class.PALADIN_LEVEL] > 6) then
      cr^.attacks := 3;
    if cr^.oldClassLevels[C_Class.THIEF_LEVEL] > 0 then ClassCal.RecalcThiefSkills(cr);
  end;
end;

procedure RecalcClericSlots(cr: Types.PCreature; rebuild: Boolean);
var
  j: ShortInt;
  k: ShortInt;
  eff: ShortInt;
begin
  eff := cr^.classLevels[C_Class.CLERIC_LEVEL] +
    cr^.oldClassLevels[C_Class.CLERIC_LEVEL] * ClassCal.EarlierClassActive(cr);
  if eff > 0 then
    with cr^ do begin
      if rebuild then begin
        for k := 2 to 5 do spellSlots[C_Spell.CLERIC_LIST, k] := 0;
        spellSlots[C_Spell.CLERIC_LIST, 1] := 1;
        for j := 2 to eff do
          for k := 1 to 5 do
            Inc(spellSlots[C_Spell.CLERIC_LIST, k], GDConsts.classExperience[C_Class.CLERIC].slots[j, k]);
      end;
      if (stats[C_Stat.WISDOM].current > 12) and
          (spellSlots[C_Spell.CLERIC_LIST, 1] > 0) then Inc(spellSlots[C_Spell.CLERIC_LIST, 1]);
      if (stats[C_Stat.WISDOM].current > 13) and
          (spellSlots[C_Spell.CLERIC_LIST, 1] > 0) then Inc(spellSlots[C_Spell.CLERIC_LIST, 1]);
      if (stats[C_Stat.WISDOM].current > 14) and
          (spellSlots[C_Spell.CLERIC_LIST, 2] > 0) then Inc(spellSlots[C_Spell.CLERIC_LIST, 2]);
      if (stats[C_Stat.WISDOM].current > 15) and
          (spellSlots[C_Spell.CLERIC_LIST, 2] > 0) then Inc(spellSlots[C_Spell.CLERIC_LIST, 2]);
      if (stats[C_Stat.WISDOM].current > 16) and
          (spellSlots[C_Spell.CLERIC_LIST, 3] > 0) then Inc(spellSlots[C_Spell.CLERIC_LIST, 3]);
      if (stats[C_Stat.WISDOM].current > 17) and
          (spellSlots[C_Spell.CLERIC_LIST, 4] > 0) then Inc(spellSlots[C_Spell.CLERIC_LIST, 4]);
    end;
end;

procedure RecalcSaves(cr: Types.PCreature);
var
  i: ShortInt;
  j: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  level: Byte;
  specialCode: ShortInt;
  itm: Types.PItem;
  flag: ShortInt;
begin
  flag := 0;
  itm := cr^.itemsAddr;
  while (itm <> nil) and (flag = 0) do begin
    if itm^.special > $80 then
      if itm^.equipped <> 0 then begin
        specialCode := itm^.special and $7F;
        flag := Ord(specialCode = 6);
      end;
    itm := itm^.next;
  end;
  for i := 0 to 4 do begin
    cr^.saves[i] := 20;
    for j := 0 to 7 do
      if cr^.classLevels[j] > 0 then
        if cr^.saves[i] > GDConsts.classSavingThrows[j, cr^.classLevels[j], i] then
          cr^.saves[i] := GDConsts.classSavingThrows[j, cr^.classLevels[j], i];
    if cr^.classLevels[j] > cr^.oldClassLevels[j] then
      if cr^.saves[i] > GDConsts.classSavingThrows[j, cr^.oldClassLevels[j], i] then
        cr^.saves[i] := GDConsts.classSavingThrows[j, cr^.oldClassLevels[j], i];
    if i = 0 then begin
      if (cr^.race = ClassCal.DWARF) or (cr^.race = ClassCal.HALFLING) or (flag <> 0) then begin
        case cr^.stats[C_Stat.CONSTITUTION].current of
          4..6: Inc(cr^.saves[i]);
          7..10: Inc(cr^.saves[i], 2);
          11..13: Inc(cr^.saves[i], 3);
          14..17: Inc(cr^.saves[i], 4);
          18: Inc(cr^.saves[i], 5);
        end;
      end;
    end;
    if i = 0 then begin
      case cr^.stats[C_Stat.CONSTITUTION].current of
        19, 20: Inc(cr^.saves[i]);
        21, 22: Inc(cr^.saves[i], 2);
        23, 24: Inc(cr^.saves[i], 3);
        25: Inc(cr^.saves[i], 4);
      end;
    end;
  end;
end;

procedure RecalcThiefSkills(cr: Types.PCreature);
var
  i: Byte;
  tmp: Byte;
  specialCode: ShortInt;
  effLevel: ShortInt;
  savedEff: ShortInt;
  itm: Types.PItem;
  skillFloorItem: ShortInt;
  skillBonusItem: ShortInt;
begin
  with cr^ do begin
    skillFloorItem := 0;
    skillBonusItem := 0;
    itm := itemsAddr;
    while (itm <> nil) and (skillFloorItem = 0) and (skillBonusItem = 0) do begin
      if itm^.special > $80 then
        if itm^.equipped <> 0 then begin
          specialCode := itm^.special and $7F;
          skillFloorItem := Ord(specialCode = 11);
          skillBonusItem := Ord(specialCode = 2);
        end;
      itm := itm^.next;
    end;
    effLevel := cr^.classLevels[C_Class.THIEF_LEVEL] +
      cr^.oldClassLevels[C_Class.THIEF_LEVEL] * ClassCal.EarlierClassActive(cr);
    if (effLevel < 4) and (skillBonusItem <> 0) then begin
      effLevel := 4;
      skillBonusItem := 0;
    end;
    savedEff := effLevel;
    for i := 1 to 8 do begin
      if skillFloorItem <> 0 then
        case i of
          1: if effLevel < 5 then begin effLevel := 5; tmp := 0; end
             else tmp := 5;
          2: if effLevel < 7 then begin effLevel := 7; tmp := 0; end
             else tmp := 5;
        end;
      if (GDConsts.thiefRaceAdjustments[race, i] < 0) and
          (GDConsts.thiefSkillBase[effLevel, i] < Abs(GDConsts.thiefRaceAdjustments[race, i]) + tmp) then
        thiefSkills[i] := 0
      else begin
        thiefSkills[i] := GDConsts.thiefSkillBase[effLevel, i] + GDConsts.thiefRaceAdjustments[race, i] + tmp;
        if i < 6 then
          thiefSkills[i] := thiefSkills[i] + GDConsts.thiefDexterityAdjustments[stats[C_Stat.DEXTERITY].current, i];
      end;
      if skillBonusItem <> 0 then
        Inc(thiefSkills[i], 10);
      effLevel := savedEff;
    end;
  end;
end;

procedure ChangeClass(cr: Types.PCreature);
var
  menuKey: Char;
  classIdx: ShortInt;
  classBase: Byte;
  listHead: Types.PItem;
  cur: Types.PItem;
  count: Integer;
  selE: Boolean;
  selF: Boolean;
  itm: Types.PItem;

  { True when the character may change to newClass: another class, prime requisites high enough, alignment allowed. }
  function QualifiesForClass(newClass: ShortInt): Boolean;
  var
    qual: Boolean;
    j: ShortInt;
    k: Byte;
  begin
    qual := Byte(GDConsts.raceClassLimits[cr^.race].choices[GDVars.sharedLoopIdx]) <> ClassCal.FirstCurrentClass(cr);
    j := 0;
    while (j <= 5) and
        not ((GDConsts.classAbilityMinimums[ShortInt(ClassCal.FirstCurrentClass(cr)), j] >= 9)
            and (cr^.stats[j].permanent <= 14)) do
      Inc(j);
    qual := qual and (j > 5);
    j := 0;
    while (j <= 5) and not ((GDConsts.classAbilityMinimums[newClass, j] >= 9) and (cr^.stats[j].permanent <= 16)) do
      Inc(j);
    qual := qual and (j > 5);
    k := 1;
    while (Byte(GDConsts.classAlignments[newClass].count) >= k) and
        (Byte(GDConsts.classAlignments[newClass].choices[k]) <> cr^.alignment) do
      Inc(k);
    qual := qual and (Byte(GDConsts.classAlignments[newClass].count) >= k);
    QualifiesForClass := qual;
  end;

begin
  classBase := Byte(GDConsts.raceClassLimits[cr^.race].count);
  GetMem(listHead, SizeOf(Types.TItemNode));
  cur := listHead;
  cur^.next := nil;
  cur^.inUse := 1;
  cur^.name := 'Pick New Class';
  count := 1;
  for GDVars.sharedLoopIdx := 1 to classBase do begin
    classIdx := Byte(GDConsts.raceClassLimits[cr^.race].choices[GDVars.sharedLoopIdx]);
    if QualifiesForClass(classIdx) then begin
      GetMem(cur^.next, SizeOf(Types.TItemNode));
      cur := cur^.next;
      cur^.next := nil;
      cur^.inUse := 0;
      cur^.name := GDConsts.classNames[classIdx];
      Inc(count);
    end;
  end;
  if count = 1 then begin
    TextRend.PrintAndPause(cr^.name + ' doesn''t qualify.', Red, White);
    MenuCore.FreeStringList(listHead);
  end else begin
    cur := listHead;
    count := 1;
    selE := True;
    selF := True;
    repeat
      menuKey := MenuCore.MenuVertical('', 'Select', LightMagenta, LightGreen, White, 1, 2, 38, 22, listHead, selE,
                                       selF, count, cur);
      if menuKey = C_Keys.NONE then Exit;
    until menuKey = 'S';
    cr^.experience := 0;
    cr^.attacks := 2;
    classIdx := 0;
    while (classIdx <= 7) and (GDConsts.classNames[classIdx] <> cur^.name) do
      Inc(classIdx);
    MenuCore.FreeStringList(listHead);
    cr^.oldClassLevels[ShortInt(ClassCal.FirstCurrentClass(cr))] := ClassCal.CurrentDualClassLevel(cr);
    cr^.levelAtChange := cr^.levelHighest;
    cr^.levelHighest := 1;
    cr^.classLevels[ShortInt(ClassCal.FirstCurrentClass(cr))] := 0;
    cr^.classLevels[classIdx] := 1;
    FillChar(cr^.spellSlots, SizeOf(cr^.spellSlots), 0);
    case Char(classIdx) of
      #0: cr^.spellSlots[C_Spell.CLERIC_LIST, 1] := 1;
      #5: begin
           cr^.spellSlots[C_Spell.MAGE_LIST, 1] := 1;
           cr^.knownSpells[11] := 1;
           cr^.knownSpells[18] := 1;
           cr^.knownSpells[12] := 1;
           cr^.knownSpells[21] := 1;
         end;
    end;
    cr^.charClass := classIdx;
    TextRend.PrintAndPause(cr^.name + ' is now a 1st level ' + GDConsts.classNames[classIdx] + '.', LightGreen, 0);
    FillChar(cr^.memorizedSpells, SizeOf(cr^.memorizedSpells), 0);
    ClassCal.RecalcClassStats(cr);
    ClassCal.RecalcClericSlots(cr, True);
    ClassCal.RecalcSaves(cr);
    ClassCal.RecalcThiefSkills(cr);
    itm := cr^.itemsAddr;
    while itm <> nil do begin
      if (GDVars.baseItems[itm^.itemType].classMask and cr^.classMask) = 0 then
        if itm^.cursed = 0 then
          itm^.equipped := 0;
      itm := itm^.next;
    end;
  end;
end;

function FirstEarlierClass(cr: Types.PCreature): Byte;
var
  i: ShortInt;
begin
  if cr^.race <> C_Race.HUMAN then
    FirstEarlierClass := 17
  else begin
    i := 0;
    while (i < 7) and (cr^.oldClassLevels[i] = 0) do
      Inc(i);
    if cr^.oldClassLevels[i] > 0 then
      FirstEarlierClass := i
    else
      FirstEarlierClass := 17;
  end;
end;

function FirstCurrentClass(cr: Types.PCreature): Byte;
var
  i: ShortInt;
begin
  if cr^.race <> C_Race.HUMAN then
    FirstCurrentClass := 17
  else begin
    i := 0;
    while (i < 7) and (cr^.classLevels[i] = 0) do
      Inc(i);
    if cr^.classLevels[i] > 0 then
      FirstCurrentClass := i
    else
      FirstCurrentClass := 17;
  end;
end;

function CurrentDualClassLevel(cr: Types.PCreature): ShortInt;
var
  i: ShortInt;
begin
  if cr^.race <> C_Race.HUMAN then
    CurrentDualClassLevel := 0
  else begin
    i := 0;
    while (i < 7) and (cr^.classLevels[i] = 0) do
      Inc(i);
    CurrentDualClassLevel := cr^.classLevels[i];
  end;
end;

function IsHuman(cr: Types.PCreature): Byte;
begin
  IsHuman := Ord(cr^.race = C_Race.HUMAN);
end;

function EarlierClassActive(cr: Types.PCreature): ShortInt;
begin
  EarlierClassActive := Ord(ClassCal.CurrentDualClassLevel(cr) > cr^.levelAtChange);
end;

begin
end.
