{ Menu key values. Enter, Escape and Backspace are ASCII; the arrow, Home, End, Page Up and Page Down keys are BIOS
  extended scan codes, returned with the menu routines' extended-key flag set. }
unit C_Keys;

interface

const
  ENTER = #13;
  ESCAPE = #27;
  BACKSPACE = #8;
  UP = #72;
  DOWN = #80;
  LEFT = #75;
  RIGHT = #77;
  HOME = #71;
  END_KEY = #79;
  PAGE_UP = #73;
  PAGE_DOWN = #81;
  { Alt-letter combinations, also extended codes (the letter key's scan code). }
  ALT_X = #45;
  ALT_M = #50;
  { Menu result meaning no selection: MenuCore.MenuHorizontal returns it for Escape, and MenuVertical also for Exit or
    an empty list. }
  NONE = #0;

implementation

end.
