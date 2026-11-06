{ Redrawing the exploration view: the 3D view's colors and automap cursor, or the overland picture. }
{$O+,F+}
{$A-}
unit MapView;

interface

uses EclTrace, Portrait, View3D, MapTiles, GDConsts, GDVars, C_Pic, C_Gbvm;

{ Redraws the view unless the party is defeated. In the 3D view it reads the cell event at the party's position, picks
  the sky color by the script's ceiling index (an event of 128 or more) or sky index, and on CGA, when the wide picture
  region is set, turns the ceiling, floor and wall selections into wall colors and draws the 3D cell; in the other modes
  it sets floorBandColor to 8 and draws no cell. The automap is turned off when the script says there is no map, and the
  automap cursor is drawn. On the overland map it redraws the big picture when a map redraw is pending. The pending flag
  is cleared after a redraw, and on entry when the village picture is loaded. }
procedure DisplayMapView;

{ Calls the priming entries of MapTiles, Portrait and the trace overlay (not View3D), so the overlay manager loads those
  overlays. }
procedure PrimeMapView;

implementation

const
  { Script variable in GDVars.zone0^ holding the 3D view's sky color, an index into GDConsts.skyColors. }
  SKY_INDEX = $4BFD;
  { Script variable in GDVars.zone0^ holding the 3D view's sky color under a ceiling, used when the cell event at the
    party's position is above $7F; an index into GDConsts.skyColors. }
  CEILING_INDEX = $4BFE;

procedure PrimeMapView;
begin
  MapTiles.PrimeMapTiles;
  EclTrace.PrimeEclTrace;
  Portrait.PrimePortrait;
end;

procedure DisplayMapView;
var
  { Unused in this version; see the other implementations of this routine. }
  wildX: Integer;
  { Unused in this version; see the other implementations of this routine. }
  wildY: Integer;

  { CGA color 1 for a ceiling and floor selection. }
  function HorizonUpperColorOf(selector: Byte): Byte;
  begin
    case selector of
      $08: HorizonUpperColorOf := 0;
      $41: HorizonUpperColorOf := 0;
      $E8: HorizonUpperColorOf := 15;
    else HorizonUpperColorOf := 15;
    end;
  end;

  { CGA color 2 for a ceiling and floor selection. }
  function HorizonLowerColorOf(selector: Byte): Byte;
  begin
    case selector of
      $08: HorizonLowerColorOf := 8;
      $41: HorizonLowerColorOf := 7;
      $E8: HorizonLowerColorOf := 7;
    else HorizonLowerColorOf := 7;
    end;
  end;

  { CGA color 3 for a wall selection. }
  function FloorColorOf(selector: Byte): Byte;
  begin
    case selector of
      $0B: FloorColorOf := 8;
      $09: FloorColorOf := 6;
      $DB: FloorColorOf := 6;
      $06: FloorColorOf := 1;
    else FloorColorOf := 6;
    end;
  end;

begin
  if GDVars.loadedPicId = C_Pic.VILLAGE then GDVars.mapRedrawPending := 0;
  if GDVars.partyDefeated then Exit;
  if GDVars.zone0^[C_Gbvm.VIEW_3D] <> 0 then begin
    GDVars.partyPos.eventAtCell := View3D.GetMapEvent(GDVars.partyPos.mapX, GDVars.partyPos.mapY);
    if GDVars.partyPos.eventAtCell > $7F then
      GDVars.skyCeilingColor := GDConsts.skyColors[GDVars.zone0^[MapView.CEILING_INDEX]]
    else
      GDVars.skyCeilingColor := GDConsts.skyColors[GDVars.zone0^[MapView.SKY_INDEX]];
    if GDVars.displayMode = 0 then begin
      if GDVars.redrawViewColors then begin
        GDVars.ceilingBandColor := HorizonUpperColorOf(GDVars.ceilFloorColorSel);
        GDVars.midBandColor := HorizonLowerColorOf(GDVars.ceilFloorColorSel);
        GDVars.floorBandColor := FloorColorOf(GDVars.wallColorSel);
        View3D.SetView3DColors(GDVars.skyCeilingColor, GDVars.ceilingBandColor, GDVars.midBandColor,
                               GDVars.floorBandColor);
      end;
    end else
      GDVars.floorBandColor := $08;
    if GDVars.zone0^[C_Gbvm.NO_AUTOMAP] <> 0 then GDVars.automapOn := False;
    View3D.Display3DMapView(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
  end else begin
    if GDVars.mapRedrawPending <> 0 then Portrait.DisplayBigPic;
  end;
  GDVars.mapRedrawPending := 0;
end;

begin
end.
