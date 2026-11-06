{ Combat terrain values: the markers clouds and downed creatures lay on arena cells. Like any terrain value, each also
  indexes the terrain-property table. }
unit C_Terr;

interface

const
  { a Cloudkill cloud }
  CLOUDKILL = 28;
  { a Stinking Cloud }
  STINKING_CLOUD = 30;
  { a downed creature's body; its downed record keeps the terrain it covers }
  CORPSE = 31;

implementation

end.
