{ The display memory: the EGA framebuffer and the CGA and Tandy display banks. }
unit C_Video;

interface

const
  { Visible EGA page. }
  EGA_VIDEO_SEG = $A000;
  { CGA and Tandy interleave scanlines across video-memory banks. CGA uses two banks; Tandy uses four. }
  GFX_BANK0_SEG = $B800;
  GFX_BANK1_SEG = $BA00;
  GFX_BANK2_SEG = $BC00;
  GFX_BANK3_SEG = $BE00;

implementation

end.
