{ Interface modes (GDVars.ifcState and its views). }
unit C_Ifc;

interface

const
  { a shop or temple: Sell and Id are offered, Use is not }
  SHOP_TEMPLE = 1;
  { camping }
  CAMPING = 2;
  { the overland map }
  OVERLAND = 3;
  { the 3D view }
  VIEW_3D = 4;
  IN_COMBAT = 5;
  { the treasure screen; dropped money goes into the pool here and in shops and temples }
  LOOT = 6;

implementation

end.
