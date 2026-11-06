{ The EGA Sequencer and Graphics Controller ports, registers and register values. }
unit C_Ega;

interface

const
  { Sequencer index port. }
  SEQ_ADDR_PORT = $3C4;
  { Sequencer data port. }
  SEQ_DATA_PORT = $3C5;
  { Sequencer map-mask register: the planes that CPU writes reach. }
  SEQ_MAP_MASK_REG = 2;
  { Map mask enabling all four planes. }
  MAP_MASK_ALL_PLANES = $F;
  { Graphics controller index port. }
  GC_ADDR_PORT = $3CE;
  { Graphics controller data port. }
  GC_DATA_PORT = $3CF;
  { Graphics controller read-map register: the plane that CPU reads return. }
  GC_READ_MAP_REG = 4;
  { Graphics controller mode register. }
  GC_MODE_REG = 5;
  { Write mode 0: normal writes. }
  GC_WRITE_MODE_0 = 0;

implementation

end.
