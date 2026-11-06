; Blitters for Blit's view buffer, linked as BLIT.OBJ. The BLITCELL* entries draw one frame of a graphic at a
; character-cell position without clipping; the BLITCLIPPED* entries clip the frame against the destination first. Each
; entry works out the geometry in its own frame and then runs the row loop, INNER1 (opaque) or INNER2 (masked), on that
; frame. The row loops record the dirty spans that FlushView copies to the screen. On entry DS is DGROUP; the loops
; borrow it to reach the pixel data and put it back before touching the span tables.

; TImgBuf fields the blitters read. The height, in scanlines, is the record's first word.
bufWidth   EQU  2                           ; width, in eight-pixel cells
bufImgSize EQU  11h                         ; imgSize: bytes in one frame
bufTransp  EQU  13h                         ; transp: the transparency mask, offset then segment
bufData    EQU  17h                         ; data: the pixel bytes

; Locals shared by the entries and both row loops.
maskOfs   EQU  -4                           ; offset of the graphic's transparency mask
maskSeg   EQU  -2                           ; segment of the graphic's transparency mask
xRec      EQU  -6                           ; left edge as FlushView's screen X: bytes on CGA and Tandy, cells on EGA
dstRow    EQU  -8                           ; destination scanline of the top edge; the row loops take it in BX
rowCnt    EQU  -10                          ; scanlines to draw; the row loops take it in CX
dstOfs    EQU  -12                          ; offset into dest's pixel data of the current row
srcOfs    EQU  -14                          ; offset into the graphic's pixel data, and its mask, of the current row
rowBytes  EQU  -16                          ; bytes drawn per scanline
dstStep   EQU  -18                          ; dest bytes to skip after a row to reach the next row's start
dstXofs   EQU  -20                          ; left edge in dest bytes, added to dstOfs at each row
srcStep   EQU  -22                          ; source bytes clipped off the right of each row; zero when unclipped
leftSkip  EQU  -24                          ; source bytes clipped off the left of each row; zero when unclipped
saveFlag  EQU  -26                          ; nonzero to save the covered bytes first; read by INNER2
savOfs    EQU  -28                          ; offset into the save-under buffer, kept in step with srcOfs

; Arguments of the BLITCELL* entries.
aDest     EQU  4                            ; dest: the buffer drawn into, normally the view buffer
aGfx      EQU  8                            ; gfx: the graphic, whose frames are imgSize bytes apart
cTile     EQU  12                           ; tileIdx: the frame drawn
cCellY    EQU  14                           ; screenY, in character rows of eight scanlines
cCellX    EQU  16                           ; screenX, in character columns

; Arguments of the BLITCLIPPED* entries, after the same dest and gfx.
kFlag     EQU  12                           ; flag: bit 0 draws masked, bit 2 saves the covered bytes when masked
kTile     EQU  14                           ; tileIdx: the frame drawn
kY        EQU  16                           ; screenY, in character rows; negative clips the top
kX        EQU  18                           ; screenX, in character columns; negative clips the left
kSave     EQU  20                           ; under: the save-under buffer INNER2 writes when saveFlag is set

; The dirty-span tables FlushView reads, one entry per view scanline.
DATA    SEGMENT WORD PUBLIC
        EXTRN   spanActive:BYTE             ; nonzero once the scanline is drawn
        EXTRN   spanScreenOfs:WORD          ; screen X of the span's first byte
        EXTRN   spanFirstOfs:WORD           ; offset into the view buffer's pixel data of the span's first byte
        EXTRN   spanLastOfs:WORD            ; offset into the view buffer's pixel data of the span's last byte
DATA    ENDS

CODE    SEGMENT BYTE PUBLIC
        ASSUME  CS:CODE, DS:DATA
        PUBLIC  BLITCELLCGA, BLITCELLCGAMASKED, BLITCLIPPEDCGA
        PUBLIC  BLITCELLEGA, BLITCELLEGAMASKED, BLITCLIPPEDEGA
        PUBLIC  BLITCELLTANDY, BLITCELLTANDYMASKED, BLITCLIPPEDTANDY

; BlitCellCga: draws a frame opaque at a cell position, unclipped. CGA takes two bytes per cell.
BLITCELLCGA LABEL NEAR
; Open the frame for the shared locals and keep the caller's SS and DS.
        push      bp
        mov       bp, sp
        sub       sp, 1ch
        sub       sp, 1ch
        push      ss
        push      ds
        cld
; Find the top scanline (the cell row times eight) and the offset of its row in dest, in cells for now.
        les       di, dword ptr [bp+aDest]
        mov       ax, word ptr [bp+cCellY]
        mov       cl, 3
        shl       ax, cl
        mov       word ptr [bp+dstRow], ax
        mov       bx, word ptr es:[di + bufWidth]
        mul       bx
        mov       word ptr [bp+dstOfs], ax
; Work out the left edge, the dest cells to skip after each row (dest width less the frame width and X), the
; screen X for FlushView, and the size and count of the frame's rows.
        mov       ax, word ptr [bp+cCellX]
        mov       word ptr [bp+dstXofs], ax
        mov       ax, word ptr es:[di + bufWidth]
        les       di, dword ptr [bp+aGfx]
        sub       ax, word ptr es:[di + bufWidth]
        sub       ax, word ptr [bp+cCellX]
        mov       word ptr [bp+dstStep], ax
        mov       ax, word ptr [bp+dstXofs]
        mov       word ptr [bp+xRec], ax
        shl       word ptr [bp+xRec], 1
        mov       ax, word ptr es:[di + bufWidth]
        shl       ax, 1
        mov       word ptr [bp+rowBytes], ax
        mov       ax, word ptr es:[di]
        mov       word ptr [bp+rowCnt], ax
; Scale the destination measures from cells to bytes.
        shl       word ptr [bp+dstXofs], 1
        shl       word ptr [bp+dstStep], 1
; Start the source at the frame drawn, then scale the dest offset to bytes too.
        mov       ax, word ptr es:[di + bufImgSize]
        xor       bx, bx
        mov       bl, byte ptr [bp+cTile]
        mul       bx
        mov       word ptr [bp+srcOfs], ax
        shl       word ptr [bp+dstOfs], 1
; Draw the whole frame: no clipping and no save-under.
        mov       bx, word ptr [bp+dstRow]
        mov       cx, word ptr [bp+rowCnt]
        mov       byte ptr [bp+saveFlag], 0
        mov       word ptr [bp+leftSkip], 0
        mov       word ptr [bp+srcStep], 0
        call      INNER1
; Restore the caller's registers and drop the arguments.
        pop       ds
        pop       ss
        mov       sp, bp
        pop       bp
        ret       0eh

; BlitCellCgaMasked: draws a frame through its transparency mask at a cell position, unclipped. CGA takes two bytes per
; cell.
BLITCELLCGAMASKED LABEL NEAR
; Open the frame for the shared locals and keep the caller's SS and DS.
        push      bp
        mov       bp, sp
        sub       sp, 1ch
        sub       sp, 1ch
        push      ss
        push      ds
; Find the top scanline (the cell row times eight) and the offset of its row in dest, in cells for now.
        les       di, dword ptr [bp+aDest]
        mov       ax, word ptr [bp+cCellY]
        mov       cl, 3
        shl       ax, cl
        mov       word ptr [bp+dstRow], ax
        mov       bx, word ptr es:[di + bufWidth]
        mul       bx
        mov       word ptr [bp+dstOfs], ax
; Work out the left edge, the dest cells to skip after each row (dest width less the frame width and X), the
; screen X for FlushView, and the size and count of the frame's rows.
        mov       ax, word ptr [bp+cCellX]
        mov       word ptr [bp+dstXofs], ax
        mov       ax, word ptr es:[di + bufWidth]
        les       di, dword ptr [bp+aGfx]
        sub       ax, word ptr es:[di + bufWidth]
        sub       ax, word ptr [bp+cCellX]
        mov       word ptr [bp+dstStep], ax
        mov       ax, word ptr [bp+dstXofs]
        mov       word ptr [bp+xRec], ax
        shl       word ptr [bp+xRec], 1
        mov       ax, word ptr es:[di + bufWidth]
        shl       ax, 1
        mov       word ptr [bp+rowBytes], ax
        mov       ax, word ptr es:[di]
        mov       word ptr [bp+rowCnt], ax
; Keep the frame's transparency mask for INNER2.
        mov       ax, word ptr es:[di + bufTransp]
        mov       word ptr [bp+maskOfs], ax
        mov       ax, word ptr es:[di + bufTransp + 2]
        mov       word ptr [bp+maskSeg], ax
; Scale the destination measures from cells to bytes.
        shl       word ptr [bp+dstXofs], 1
        shl       word ptr [bp+dstStep], 1
; Start the source at the frame drawn, then scale the dest offset to bytes too.
        mov       ax, word ptr es:[di + bufImgSize]
        xor       bx, bx
        mov       bl, byte ptr [bp+cTile]
        mul       bx
        mov       word ptr [bp+srcOfs], ax
        shl       word ptr [bp+dstOfs], 1
; Draw the whole frame: no clipping and no save-under.
        mov       bx, word ptr [bp+dstRow]
        mov       cx, word ptr [bp+rowCnt]
        mov       byte ptr [bp+saveFlag], 0
        mov       word ptr [bp+leftSkip], 0
        mov       word ptr [bp+srcStep], 0
        call      INNER2
; Restore the caller's registers and drop the arguments.
        pop       ds
        pop       ss
        mov       sp, bp
        pop       bp
        ret       0eh

; BlitClippedCga: draws a frame at a cell position, clipped against dest, opaque or masked as the flag asks. CGA takes
; two bytes per cell.
BLITCLIPPEDCGA LABEL NEAR
; Open the frame for the shared locals and keep the caller's SS and DS.
        push      bp
        mov       bp, sp
        sub       sp, 1ch
        sub       sp, 1ch
        push      ss
        push      ds
        cld
; Reach the graphic through DS:SI and dest through ES:DI, and keep the frame's transparency mask for INNER2.
        push      ds
        lds       si, dword ptr [bp+aGfx]
        les       di, dword ptr [bp+aDest]
        mov       ax, word ptr [si + bufTransp]
        mov       word ptr [bp+maskOfs], ax
        mov       ax, word ptr [si + bufTransp + 2]
        mov       word ptr [bp+maskSeg], ax
; Clip the left edge: a negative X skips that many cells of each source row and starts at dest's first cell. X
; is compared unsigned, so -32768 counts as on dest.
        mov       ax, word ptr [bp+kX]
        cmp       ax, 8000h
        jbe       CgaNoLeftClip
        mov       word ptr [bp+leftSkip], ax
        neg       word ptr [bp+leftSkip]
        mov       word ptr [bp+dstXofs], 0
        jmp short CgaCheckRight
        nop
CgaNoLeftClip:
        mov       word ptr [bp+leftSkip], 0
        mov       word ptr [bp+dstXofs], ax
; Clip the right edge: cells past dest's width are skipped at the end of each source row; otherwise dest has a
; remainder to skip after each row.
CgaCheckRight:
        add       ax, word ptr [si + bufWidth]
        cmp       word ptr es:[di + bufWidth], ax
        jae       CgaNoRightClip
        sub       ax, word ptr es:[di + bufWidth]
        mov       word ptr [bp+srcStep], ax
        mov       word ptr [bp+dstStep], 0
        jmp short CgaCheckTop
        nop
CgaNoRightClip:
        mov       word ptr [bp+srcStep], 0
        mov       ax, word ptr es:[di + bufWidth]
        sub       ax, word ptr [bp+kX]
        sub       ax, word ptr [si + bufWidth]
        mov       word ptr [bp+dstStep], ax
; Clip the top edge: a negative Y drops that many cell rows of source scanlines and starts at dest's top
; scanline; otherwise find the top scanline and the offset of its row in dest.
CgaCheckTop:
        mov       ax, word ptr [bp+kY]
        cmp       ax, 8000h
        jbe       CgaNoTopClip
        neg       ax
        mov       cx, 3
        shl       ax, cl
        mov       bx, word ptr [si]
        mov       word ptr [bp+rowCnt], bx
        sub       word ptr [bp+rowCnt], ax
        mov       bx, word ptr [si + bufWidth]
        mul       bx
        mov       word ptr [bp+srcOfs], ax
        mov       word ptr [bp+dstOfs], 0
        mov       word ptr [bp+dstRow], 0
        jmp short CgaCheckBounds
        nop
CgaNoTopClip:
        mov       word ptr [bp+srcOfs], 0
        mov       cx, 3
        shl       ax, cl
        mov       word ptr [bp+dstRow], ax
        mov       bx, word ptr es:[di + bufWidth]
        mul       bx
        mov       word ptr [bp+dstOfs], ax
; Clip the bottom edge to dest's height.
        mov       ax, word ptr [bp+dstRow]
        add       ax, word ptr [si]
        cmp       ax, word ptr es:[di]
        jbe       CgaFullHeight
        mov       ax, word ptr es:[di]
        sub       ax, word ptr [bp+dstRow]
        mov       word ptr [bp+rowCnt], ax
        jmp short CgaCheckBounds
        nop
CgaFullHeight:
        mov       ax, word ptr [si]
        mov       word ptr [bp+rowCnt], ax
; Give up on a frame that lies entirely off dest.
CgaCheckBounds:
        mov       ax, word ptr [si + bufWidth]
        cmp       ax, word ptr [bp+leftSkip]
        jb        CgaReject
        cmp       ax, word ptr [bp+srcStep]
        jb        CgaReject
        mov       ax, word ptr [bp+srcOfs]
        cmp       ax, word ptr [si + bufImgSize]
        ja        CgaReject
        mov       ax, word ptr [bp+dstOfs]
        cmp       ax, word ptr es:[di + bufImgSize]
        ja        CgaReject
        mov       ax, word ptr [bp+rowCnt]
        cmp       ax, word ptr [si]
        ja        CgaReject
        jmp short CgaScaleSpan
        nop
; Nothing to draw: drop the borrowed DS, restore the caller's registers and drop the arguments.
CgaReject:
        pop       ds
        pop       ds
        pop       ss
        mov       sp, bp
        pop       bp
        ret       14h
; Scale the cell measures to bytes, keep the save-under cursor in step with the source, and start the source
; at the frame drawn.
CgaScaleSpan:
        mov       ax, word ptr [bp+dstXofs]
        shl       ax, 1
        mov       word ptr [bp+dstXofs], ax
        mov       word ptr [bp+xRec], ax
        mov       ax, word ptr [si + bufWidth]
        sub       ax, word ptr [bp+leftSkip]
        sub       ax, word ptr [bp+srcStep]
        shl       ax, 1
        mov       word ptr [bp+rowBytes], ax
        shl       word ptr [bp+leftSkip], 1
        shl       word ptr [bp+srcStep], 1
        shl       word ptr [bp+dstStep], 1
        shl       word ptr [bp+srcOfs], 1
        shl       word ptr [bp+dstOfs], 1
        mov       ax, word ptr [bp+srcOfs]
        mov       word ptr [bp+savOfs], ax
        mov       ax, word ptr [si + bufImgSize]
        xor       bx, bx
        mov       bl, byte ptr [bp+kTile]
        mul       bx
        add       word ptr [bp+srcOfs], ax
; Hand the row loop its first scanline and row count, and give DS back to DGROUP for the span tables.
        mov       bx, word ptr [bp+dstRow]
        mov       cx, word ptr [bp+rowCnt]
        mov       byte ptr [bp+saveFlag], 0
        pop       ds
; Bit 0 of the flag picks masked drawing; otherwise the opaque loop draws the frame.
        test      byte ptr [bp+kFlag], 1
        jne       CgaMasked
        call      INNER1
; Restore the caller's registers and drop the arguments.
        pop       ds
        pop       ss
        mov       sp, bp
        pop       bp
        ret       14h
; Bit 2 of the flag has INNER2 save the covered bytes first.
CgaMasked:
        mov       byte ptr [bp+saveFlag], 0
        test      byte ptr [bp+kFlag], 4
        je        CgaDrawMasked
        mov       byte ptr [bp+saveFlag], 1
CgaDrawMasked:
        call      INNER2
; Restore the caller's registers and drop the arguments.
        pop       ds
        pop       ss
        mov       sp, bp
        pop       bp
        ret       14h

; BlitCellEga: draws a frame opaque at a cell position, unclipped. EGA takes four plane bytes per cell, and FlushView's
; screen X stays in cells.
BLITCELLEGA LABEL NEAR
; Open the frame for the shared locals and keep the caller's SS and DS.
        push      bp
        mov       bp, sp
        sub       sp, 1ch
        sub       sp, 1ch
        push      ss
        push      ds
        cld
; Find the top scanline (the cell row times eight) and the offset of its row in dest, in cells for now.
        les       di, dword ptr [bp+aDest]
        mov       ax, word ptr [bp+cCellY]
        mov       cl, 3
        shl       ax, cl
        mov       word ptr [bp+dstRow], ax
        mov       bx, word ptr es:[di + bufWidth]
        mul       bx
        mov       word ptr [bp+dstOfs], ax
; Work out the left edge, the dest cells to skip after each row (dest width less the frame width and X), the
; screen X for FlushView, and the size and count of the frame's rows.
        mov       ax, word ptr [bp+cCellX]
        mov       word ptr [bp+dstXofs], ax
        mov       ax, word ptr es:[di + bufWidth]
        les       di, dword ptr [bp+aGfx]
        sub       ax, word ptr es:[di + bufWidth]
        sub       ax, word ptr [bp+cCellX]
        mov       word ptr [bp+dstStep], ax
        mov       ax, word ptr [bp+dstXofs]
        mov       word ptr [bp+xRec], ax
        mov       ax, word ptr es:[di + bufWidth]
        shl       ax, 1
        shl       ax, 1
        mov       word ptr [bp+rowBytes], ax
        mov       ax, word ptr es:[di]
        mov       word ptr [bp+rowCnt], ax
; Scale the destination measures from cells to bytes.
        shl       word ptr [bp+dstXofs], 1
        shl       word ptr [bp+dstXofs], 1
        shl       word ptr [bp+dstStep], 1
        shl       word ptr [bp+dstStep], 1
; Start the source at the frame drawn, then scale the dest offset to bytes too.
        mov       ax, word ptr es:[di + bufImgSize]
        xor       bx, bx
        mov       bl, byte ptr [bp+cTile]
        mul       bx
        mov       word ptr [bp+srcOfs], ax
        shl       word ptr [bp+dstOfs], 1
        shl       word ptr [bp+dstOfs], 1
; Draw the whole frame: no clipping and no save-under.
        mov       bx, word ptr [bp+dstRow]
        mov       cx, word ptr [bp+rowCnt]
        mov       byte ptr [bp+saveFlag], 0
        mov       word ptr [bp+leftSkip], 0
        mov       word ptr [bp+srcStep], 0
        call      INNER1
; Restore the caller's registers and drop the arguments.
        pop       ds
        pop       ss
        mov       sp, bp
        pop       bp
        ret       0eh

; BlitCellEgaMasked: draws a frame through its transparency mask at a cell position, unclipped. EGA takes four plane
; bytes per cell, and FlushView's screen X stays in cells.
BLITCELLEGAMASKED LABEL NEAR
; Open the frame for the shared locals and keep the caller's SS and DS.
        push      bp
        mov       bp, sp
        sub       sp, 1ch
        sub       sp, 1ch
        push      ss
        push      ds
        cld
; Find the top scanline (the cell row times eight) and the offset of its row in dest, in cells for now.
        les       di, dword ptr [bp+aDest]
        mov       ax, word ptr [bp+cCellY]
        mov       cl, 3
        shl       ax, cl
        mov       word ptr [bp+dstRow], ax
        mov       bx, word ptr es:[di + bufWidth]
        mul       bx
        mov       word ptr [bp+dstOfs], ax
; Work out the left edge, the dest cells to skip after each row (dest width less the frame width and X), the
; screen X for FlushView, and the size and count of the frame's rows.
        mov       ax, word ptr [bp+cCellX]
        mov       word ptr [bp+dstXofs], ax
        mov       ax, word ptr es:[di + bufWidth]
        les       di, dword ptr [bp+aGfx]
        sub       ax, word ptr es:[di + bufWidth]
        sub       ax, word ptr [bp+cCellX]
        mov       word ptr [bp+dstStep], ax
        mov       ax, word ptr [bp+dstXofs]
        mov       word ptr [bp+xRec], ax
        mov       ax, word ptr es:[di + bufWidth]
        shl       ax, 1
        shl       ax, 1
        mov       word ptr [bp+rowBytes], ax
        mov       ax, word ptr es:[di]
        mov       word ptr [bp+rowCnt], ax
; Keep the frame's transparency mask for INNER2.
        mov       ax, word ptr es:[di + bufTransp]
        mov       word ptr [bp+maskOfs], ax
        mov       ax, word ptr es:[di + bufTransp + 2]
        mov       word ptr [bp+maskSeg], ax
; Scale the destination measures from cells to bytes.
        shl       word ptr [bp+dstXofs], 1
        shl       word ptr [bp+dstXofs], 1
        shl       word ptr [bp+dstStep], 1
        shl       word ptr [bp+dstStep], 1
; Start the source at the frame drawn, then scale the dest offset to bytes too.
        mov       ax, word ptr es:[di + bufImgSize]
        xor       bx, bx
        mov       bl, byte ptr [bp+cTile]
        mul       bx
        mov       word ptr [bp+srcOfs], ax
        shl       word ptr [bp+dstOfs], 1
        shl       word ptr [bp+dstOfs], 1
; Draw the whole frame: no clipping and no save-under.
        mov       bx, word ptr [bp+dstRow]
        mov       cx, word ptr [bp+rowCnt]
        mov       byte ptr [bp+saveFlag], 0
        mov       word ptr [bp+leftSkip], 0
        mov       word ptr [bp+srcStep], 0
        call      INNER2
; Restore the caller's registers and drop the arguments.
        pop       ds
        pop       ss
        mov       sp, bp
        pop       bp
        ret       0eh

; BlitClippedEga: draws a frame at a cell position, clipped against dest, opaque or masked as the flag asks. EGA takes
; four plane bytes per cell, and FlushView's screen X stays in cells.
BLITCLIPPEDEGA LABEL NEAR
; Open the frame for the shared locals and keep the caller's SS and DS.
        push      bp
        mov       bp, sp
        sub       sp, 1ch
        sub       sp, 1ch
        push      ss
        push      ds
        cld
; Reach the graphic through DS:SI and dest through ES:DI, and keep the frame's transparency mask for INNER2.
        push      ds
        lds       si, dword ptr [bp+aGfx]
        les       di, dword ptr [bp+aDest]
        mov       ax, word ptr [si + bufTransp]
        mov       word ptr [bp+maskOfs], ax
        mov       ax, word ptr [si + bufTransp + 2]
        mov       word ptr [bp+maskSeg], ax
; Clip the left edge: a negative X skips that many cells of each source row and starts at dest's first cell. X
; is compared unsigned, so -32768 counts as on dest.
        mov       ax, word ptr [bp+kX]
        cmp       ax, 8000h
        jbe       EgaNoLeftClip
        mov       word ptr [bp+leftSkip], ax
        neg       word ptr [bp+leftSkip]
        mov       word ptr [bp+dstXofs], 0
        jmp short EgaCheckRight
        nop
EgaNoLeftClip:
        mov       word ptr [bp+leftSkip], 0
        mov       word ptr [bp+dstXofs], ax
; Clip the right edge: cells past dest's width are skipped at the end of each source row; otherwise dest has a
; remainder to skip after each row.
EgaCheckRight:
        add       ax, word ptr [si + bufWidth]
        cmp       word ptr es:[di + bufWidth], ax
        jae       EgaNoRightClip
        sub       ax, word ptr es:[di + bufWidth]
        mov       word ptr [bp+srcStep], ax
        mov       word ptr [bp+dstStep], 0
        jmp short EgaCheckTop
        nop
EgaNoRightClip:
        mov       word ptr [bp+srcStep], 0
        mov       ax, word ptr es:[di + bufWidth]
        sub       ax, word ptr [bp+kX]
        sub       ax, word ptr [si + bufWidth]
        mov       word ptr [bp+dstStep], ax
; Clip the top edge: a negative Y drops that many cell rows of source scanlines and starts at dest's top
; scanline; otherwise find the top scanline and the offset of its row in dest.
EgaCheckTop:
        mov       ax, word ptr [bp+kY]
        cmp       ax, 8000h
        jbe       EgaNoTopClip
        neg       ax
        mov       cx, 3
        shl       ax, cl
        mov       bx, word ptr [si]
        mov       word ptr [bp+rowCnt], bx
        sub       word ptr [bp+rowCnt], ax
        mov       bx, word ptr [si + bufWidth]
        mul       bx
        mov       word ptr [bp+srcOfs], ax
        mov       word ptr [bp+dstOfs], 0
        mov       word ptr [bp+dstRow], 0
        jmp short EgaCheckBounds
        nop
EgaNoTopClip:
        mov       word ptr [bp+srcOfs], 0
        mov       cx, 3
        shl       ax, cl
        mov       word ptr [bp+dstRow], ax
        mov       bx, word ptr es:[di + bufWidth]
        mul       bx
        mov       word ptr [bp+dstOfs], ax
; Clip the bottom edge to dest's height.
        mov       ax, word ptr [bp+dstRow]
        add       ax, word ptr [si]
        cmp       ax, word ptr es:[di]
        jbe       EgaFullHeight
        mov       ax, word ptr es:[di]
        sub       ax, word ptr [bp+dstRow]
        mov       word ptr [bp+rowCnt], ax
        jmp short EgaCheckBounds
        nop
EgaFullHeight:
        mov       ax, word ptr [si]
        mov       word ptr [bp+rowCnt], ax
; Give up on a frame that lies entirely off dest.
EgaCheckBounds:
        mov       ax, word ptr [si + bufWidth]
        cmp       ax, word ptr [bp+leftSkip]
        jb        EgaReject
        cmp       ax, word ptr [bp+srcStep]
        jb        EgaReject
        mov       ax, word ptr [bp+srcOfs]
        cmp       ax, word ptr [si + bufImgSize]
        ja        EgaReject
        mov       ax, word ptr [bp+dstOfs]
        cmp       ax, word ptr es:[di + bufImgSize]
        ja        EgaReject
        mov       ax, word ptr [bp+rowCnt]
        cmp       ax, word ptr [si]
        ja        EgaReject
        jmp short EgaScaleSpan
        nop
; Nothing to draw: drop the borrowed DS, restore the caller's registers and drop the arguments.
EgaReject:
        pop       ds
        pop       ds
        pop       ss
        mov       sp, bp
        pop       bp
        ret       14h
; Scale the cell measures to bytes, keep the save-under cursor in step with the source, and start the source
; at the frame drawn.
EgaScaleSpan:
        mov       ax, word ptr [bp+dstXofs]
        mov       word ptr [bp+xRec], ax
        mov       ax, word ptr [bp+dstXofs]
        shl       ax, 1
        shl       ax, 1
        mov       word ptr [bp+dstXofs], ax
        mov       ax, word ptr [si + bufWidth]
        sub       ax, word ptr [bp+leftSkip]
        sub       ax, word ptr [bp+srcStep]
        shl       ax, 1
        shl       ax, 1
        mov       word ptr [bp+rowBytes], ax
        shl       word ptr [bp+leftSkip], 1
        shl       word ptr [bp+leftSkip], 1
        shl       word ptr [bp+srcStep], 1
        shl       word ptr [bp+srcStep], 1
        shl       word ptr [bp+dstStep], 1
        shl       word ptr [bp+dstStep], 1
        shl       word ptr [bp+srcOfs], 1
        shl       word ptr [bp+srcOfs], 1
        shl       word ptr [bp+dstOfs], 1
        shl       word ptr [bp+dstOfs], 1
        mov       ax, word ptr [bp+srcOfs]
        mov       word ptr [bp+savOfs], ax
        mov       ax, word ptr [si + bufImgSize]
        xor       bx, bx
        mov       bl, byte ptr [bp+kTile]
        mul       bx
        add       word ptr [bp+srcOfs], ax
; Hand the row loop its first scanline and row count, and give DS back to DGROUP for the span tables.
        mov       bx, word ptr [bp+dstRow]
        mov       cx, word ptr [bp+rowCnt]
        mov       byte ptr [bp+saveFlag], 0
        pop       ds
; Bit 0 of the flag picks masked drawing; otherwise the opaque loop draws the frame.
        test      byte ptr [bp+kFlag], 1
        jne       EgaMasked
        call      INNER1
; Restore the caller's registers and drop the arguments.
        pop       ds
        pop       ss
        mov       sp, bp
        pop       bp
        ret       14h
; Bit 2 of the flag has INNER2 save the covered bytes first.
EgaMasked:
        mov       byte ptr [bp+saveFlag], 0
        test      byte ptr [bp+kFlag], 4
        je        EgaDrawMasked
        mov       byte ptr [bp+saveFlag], 1
EgaDrawMasked:
        call      INNER2
; Restore the caller's registers and drop the arguments.
        pop       ds
        pop       ss
        mov       sp, bp
        pop       bp
        ret       14h

; BlitCellTandy: draws a frame opaque at a cell position, unclipped. Tandy takes four bytes per cell.
BLITCELLTANDY LABEL NEAR
; Open the frame for the shared locals and keep the caller's SS and DS.
        push      bp
        mov       bp, sp
        sub       sp, 1ch
        sub       sp, 1ch
        push      ss
        push      ds
        cld
; Find the top scanline (the cell row times eight) and the offset of its row in dest, in cells for now.
        les       di, dword ptr [bp+aDest]
        mov       ax, word ptr [bp+cCellY]
        mov       cl, 3
        shl       ax, cl
        mov       word ptr [bp+dstRow], ax
        mov       bx, word ptr es:[di + bufWidth]
        mul       bx
        mov       word ptr [bp+dstOfs], ax
; Work out the left edge, the dest cells to skip after each row (dest width less the frame width and X), the
; screen X for FlushView, and the size and count of the frame's rows.
        mov       ax, word ptr [bp+cCellX]
        mov       word ptr [bp+dstXofs], ax
        mov       ax, word ptr es:[di + bufWidth]
        les       di, dword ptr [bp+aGfx]
        sub       ax, word ptr es:[di + bufWidth]
        sub       ax, word ptr [bp+cCellX]
        mov       word ptr [bp+dstStep], ax
        mov       ax, word ptr [bp+dstXofs]
        mov       word ptr [bp+xRec], ax
        shl       word ptr [bp+xRec], 1
        shl       word ptr [bp+xRec], 1
        mov       ax, word ptr es:[di + bufWidth]
        shl       ax, 1
        shl       ax, 1
        mov       word ptr [bp+rowBytes], ax
        mov       ax, word ptr es:[di]
        mov       word ptr [bp+rowCnt], ax
; Scale the destination measures from cells to bytes.
        shl       word ptr [bp+dstXofs], 1
        shl       word ptr [bp+dstXofs], 1
        shl       word ptr [bp+dstStep], 1
        shl       word ptr [bp+dstStep], 1
; Start the source at the frame drawn, then scale the dest offset to bytes too.
        mov       ax, word ptr es:[di + bufImgSize]
        xor       bx, bx
        mov       bl, byte ptr [bp+cTile]
        mul       bx
        mov       word ptr [bp+srcOfs], ax
        shl       word ptr [bp+dstOfs], 1
        shl       word ptr [bp+dstOfs], 1
; Draw the whole frame: no clipping and no save-under.
        mov       bx, word ptr [bp+dstRow]
        mov       cx, word ptr [bp+rowCnt]
        mov       byte ptr [bp+saveFlag], 0
        mov       word ptr [bp+leftSkip], 0
        mov       word ptr [bp+srcStep], 0
        call      INNER1
; Restore the caller's registers and drop the arguments.
        pop       ds
        pop       ss
        mov       sp, bp
        pop       bp
        ret       0eh

; BlitCellTandyMasked: draws a frame through its transparency mask at a cell position, unclipped. Tandy takes four
; bytes per cell.
BLITCELLTANDYMASKED LABEL NEAR
; Open the frame for the shared locals and keep the caller's SS and DS.
        push      bp
        mov       bp, sp
        sub       sp, 1ch
        sub       sp, 1ch
        push      ss
        push      ds
; Find the top scanline (the cell row times eight) and the offset of its row in dest, in cells for now.
        les       di, dword ptr [bp+aDest]
        mov       ax, word ptr [bp+cCellY]
        mov       cl, 3
        shl       ax, cl
        mov       word ptr [bp+dstRow], ax
        mov       bx, word ptr es:[di + bufWidth]
        mul       bx
        mov       word ptr [bp+dstOfs], ax
; Work out the left edge, the dest cells to skip after each row (dest width less the frame width and X), the
; screen X for FlushView, and the size and count of the frame's rows.
        mov       ax, word ptr [bp+cCellX]
        mov       word ptr [bp+dstXofs], ax
        mov       ax, word ptr es:[di + bufWidth]
        les       di, dword ptr [bp+aGfx]
        sub       ax, word ptr es:[di + bufWidth]
        sub       ax, word ptr [bp+cCellX]
        mov       word ptr [bp+dstStep], ax
        mov       ax, word ptr [bp+dstXofs]
        mov       word ptr [bp+xRec], ax
        shl       word ptr [bp+xRec], 1
        shl       word ptr [bp+xRec], 1
        mov       ax, word ptr es:[di + bufWidth]
        shl       ax, 1
        shl       ax, 1
        mov       word ptr [bp+rowBytes], ax
        mov       ax, word ptr es:[di]
        mov       word ptr [bp+rowCnt], ax
; Keep the frame's transparency mask for INNER2.
        mov       ax, word ptr es:[di + bufTransp]
        mov       word ptr [bp+maskOfs], ax
        mov       ax, word ptr es:[di + bufTransp + 2]
        mov       word ptr [bp+maskSeg], ax
; Scale the destination measures from cells to bytes.
        shl       word ptr [bp+dstXofs], 1
        shl       word ptr [bp+dstXofs], 1
        shl       word ptr [bp+dstStep], 1
        shl       word ptr [bp+dstStep], 1
; Start the source at the frame drawn, then scale the dest offset to bytes too.
        mov       ax, word ptr es:[di + bufImgSize]
        xor       bx, bx
        mov       bl, byte ptr [bp+cTile]
        mul       bx
        mov       word ptr [bp+srcOfs], ax
        shl       word ptr [bp+dstOfs], 1
        shl       word ptr [bp+dstOfs], 1
; Draw the whole frame: no clipping and no save-under.
        mov       bx, word ptr [bp+dstRow]
        mov       cx, word ptr [bp+rowCnt]
        mov       byte ptr [bp+saveFlag], 0
        mov       word ptr [bp+leftSkip], 0
        mov       word ptr [bp+srcStep], 0
        call      INNER2
; Restore the caller's registers and drop the arguments.
        pop       ds
        pop       ss
        mov       sp, bp
        pop       bp
        ret       0eh

; BlitClippedTandy: draws a frame at a cell position, clipped against dest, opaque or masked as the flag asks. Tandy
; takes four bytes per cell.
BLITCLIPPEDTANDY LABEL NEAR
; Open the frame for the shared locals and keep the caller's SS and DS.
        push      bp
        mov       bp, sp
        sub       sp, 1ch
        sub       sp, 1ch
        push      ss
        push      ds
        cld
; Reach the graphic through DS:SI and dest through ES:DI, and keep the frame's transparency mask for INNER2.
        push      ds
        lds       si, dword ptr [bp+aGfx]
        les       di, dword ptr [bp+aDest]
        mov       ax, word ptr [si + bufTransp]
        mov       word ptr [bp+maskOfs], ax
        mov       ax, word ptr [si + bufTransp + 2]
        mov       word ptr [bp+maskSeg], ax
; Clip the left edge: a negative X skips that many cells of each source row and starts at dest's first cell. X
; is compared unsigned, so -32768 counts as on dest.
        mov       ax, word ptr [bp+kX]
        cmp       ax, 8000h
        jbe       TandyNoLeftClip
        mov       word ptr [bp+leftSkip], ax
        neg       word ptr [bp+leftSkip]
        mov       word ptr [bp+dstXofs], 0
        jmp short TandyCheckRight
        nop
TandyNoLeftClip:
        mov       word ptr [bp+leftSkip], 0
        mov       word ptr [bp+dstXofs], ax
; Clip the right edge: cells past dest's width are skipped at the end of each source row; otherwise dest has a
; remainder to skip after each row.
TandyCheckRight:
        add       ax, word ptr [si + bufWidth]
        cmp       word ptr es:[di + bufWidth], ax
        jae       TandyNoRightClip
        sub       ax, word ptr es:[di + bufWidth]
        mov       word ptr [bp+srcStep], ax
        mov       word ptr [bp+dstStep], 0
        jmp short TandyCheckTop
        nop
TandyNoRightClip:
        mov       word ptr [bp+srcStep], 0
        mov       ax, word ptr es:[di + bufWidth]
        sub       ax, word ptr [bp+kX]
        sub       ax, word ptr [si + bufWidth]
        mov       word ptr [bp+dstStep], ax
; Clip the top edge: a negative Y drops that many cell rows of source scanlines and starts at dest's top
; scanline; otherwise find the top scanline and the offset of its row in dest.
TandyCheckTop:
        mov       ax, word ptr [bp+kY]
        cmp       ax, 8000h
        jbe       TandyNoTopClip
        neg       ax
        mov       cx, 3
        shl       ax, cl
        mov       bx, word ptr [si]
        mov       word ptr [bp+rowCnt], bx
        sub       word ptr [bp+rowCnt], ax
        mov       bx, word ptr [si + bufWidth]
        mul       bx
        mov       word ptr [bp+srcOfs], ax
        mov       word ptr [bp+dstOfs], 0
        mov       word ptr [bp+dstRow], 0
        jmp short TandyCheckBounds
        nop
TandyNoTopClip:
        mov       word ptr [bp+srcOfs], 0
        mov       cx, 3
        shl       ax, cl
        mov       word ptr [bp+dstRow], ax
        mov       bx, word ptr es:[di + bufWidth]
        mul       bx
        mov       word ptr [bp+dstOfs], ax
; Clip the bottom edge to dest's height.
        mov       ax, word ptr [bp+dstRow]
        add       ax, word ptr [si]
        cmp       ax, word ptr es:[di]
        jbe       TandyFullHeight
        mov       ax, word ptr es:[di]
        sub       ax, word ptr [bp+dstRow]
        mov       word ptr [bp+rowCnt], ax
        jmp short TandyCheckBounds
        nop
TandyFullHeight:
        mov       ax, word ptr [si]
        mov       word ptr [bp+rowCnt], ax
; Give up on a frame that lies entirely off dest.
TandyCheckBounds:
        mov       ax, word ptr [si + bufWidth]
        cmp       ax, word ptr [bp+leftSkip]
        jb        TandyReject
        cmp       ax, word ptr [bp+srcStep]
        jb        TandyReject
        mov       ax, word ptr [bp+srcOfs]
        cmp       ax, word ptr [si + bufImgSize]
        ja        TandyReject
        mov       ax, word ptr [bp+dstOfs]
        cmp       ax, word ptr es:[di + bufImgSize]
        ja        TandyReject
        mov       ax, word ptr [bp+rowCnt]
        cmp       ax, word ptr [si]
        ja        TandyReject
        jmp short TandyScaleSpan
        nop
; Nothing to draw: drop the borrowed DS, restore the caller's registers and drop the arguments.
TandyReject:
        pop       ds
        pop       ds
        pop       ss
        mov       sp, bp
        pop       bp
        ret       14h
; Scale the cell measures to bytes, keep the save-under cursor in step with the source, and start the source
; at the frame drawn.
TandyScaleSpan:
        mov       ax, word ptr [bp+dstXofs]
        shl       ax, 1
        shl       ax, 1
        mov       word ptr [bp+dstXofs], ax
        mov       word ptr [bp+xRec], ax
        mov       ax, word ptr [si + bufWidth]
        sub       ax, word ptr [bp+leftSkip]
        sub       ax, word ptr [bp+srcStep]
        shl       ax, 1
        shl       ax, 1
        mov       word ptr [bp+rowBytes], ax
        shl       word ptr [bp+leftSkip], 1
        shl       word ptr [bp+leftSkip], 1
        shl       word ptr [bp+srcStep], 1
        shl       word ptr [bp+srcStep], 1
        shl       word ptr [bp+dstStep], 1
        shl       word ptr [bp+dstStep], 1
        shl       word ptr [bp+srcOfs], 1
        shl       word ptr [bp+srcOfs], 1
        shl       word ptr [bp+dstOfs], 1
        shl       word ptr [bp+dstOfs], 1
        mov       ax, word ptr [bp+srcOfs]
        mov       word ptr [bp+savOfs], ax
        mov       ax, word ptr [si + bufImgSize]
        xor       bx, bx
        mov       bl, byte ptr [bp+kTile]
        mul       bx
        add       word ptr [bp+srcOfs], ax
; Hand the row loop its first scanline and row count, and give DS back to DGROUP for the span tables.
        mov       bx, word ptr [bp+dstRow]
        mov       cx, word ptr [bp+rowCnt]
        mov       byte ptr [bp+saveFlag], 0
        pop       ds
; Bit 0 of the flag picks masked drawing; otherwise the opaque loop draws the frame.
        test      byte ptr [bp+kFlag], 1
        jne       TandyMasked
        call      INNER1
; Restore the caller's registers and drop the arguments.
        pop       ds
        pop       ss
        mov       sp, bp
        pop       bp
        ret       14h
; Bit 2 of the flag has INNER2 save the covered bytes first.
TandyMasked:
        mov       byte ptr [bp+saveFlag], 0
        test      byte ptr [bp+kFlag], 4
        je        TandyDrawMasked
        mov       byte ptr [bp+saveFlag], 1
TandyDrawMasked:
        call      INNER2
; Restore the caller's registers and drop the arguments.
        pop       ds
        pop       ss
        mov       sp, bp
        pop       bp
        ret       14h

; Opaque row loop. Each pass draws one destination scanline straight over the background and widens that scanline's
; dirty span. It runs on the calling entry's frame, with BX holding the first scanline and CX the row count.
; Note: it applies neither leftSkip nor srcStep, so a clipped opaque frame cut at the left or right edge is drawn with
; its rows out of step.
INNER1 LABEL NEAR
; Mark the scanline dirty and index its entries in the word span tables.
        mov       byte ptr [bx+spanActive], 1
        shl       bx, 1
; Move to the row's first byte; a row that starts at or before the recorded span becomes the span's start, with
; its screen X.
        mov       ax, word ptr [bp+dstXofs]
        add       word ptr [bp+dstOfs], ax
        mov       ax, word ptr [bp+dstOfs]
        cmp       ax, word ptr [bx+spanFirstOfs]
        ja        OpaqueCopyRow
        mov       word ptr [bx+spanFirstOfs], ax
        mov       ax, word ptr [bp+xRec]
        mov       word ptr [bx+spanScreenOfs], ax
; Copy the row over the background, past the TImgBuf header of both buffers.
OpaqueCopyRow:
        push      ds
        lds       si, dword ptr [bp+aGfx]
        les       di, dword ptr [bp+aDest]
        add       si, bufData
        add       si, word ptr [bp+srcOfs]
        add       di, bufData
        add       di, word ptr [bp+dstOfs]
        push      cx
        mov       cx, word ptr [bp+rowBytes]
        rep movsb
        pop       cx
        pop       ds
; Move both cursors past the row, and let its last byte extend the span's end.
        mov       ax, word ptr [bp+rowBytes]
        add       word ptr [bp+srcOfs], ax
        add       word ptr [bp+dstOfs], ax
        mov       ax, word ptr [bp+dstOfs]
        dec       ax
        cmp       ax, word ptr [bx+spanLastOfs]
        jb        OpaqueNextRow
        mov       word ptr [bx+spanLastOfs], ax
; Skip the rest of the dest row and go on to the next scanline.
OpaqueNextRow:
        mov       ax, word ptr [bp+dstStep]
        add       word ptr [bp+dstOfs], ax
        shr       bx, 1
        inc       bx
        loop      INNER1
        ret

; Masked row loop. Same bookkeeping as INNER1, but each byte goes through the transparency mask: the background byte is
; ANDed with the mask and the frame's byte ORed in, so a 1 bit keeps the background pixel and a 0 bit lets the frame's
; pixel through. With saveFlag set it first copies each covered byte into the save-under buffer, so the background can
; be put back later.
INNER2 LABEL NEAR
; Mark the scanline dirty, index its entries in the word span tables, and skip the source bytes clipped off the
; left.
        mov       byte ptr [bx+spanActive], 1
        shl       bx, 1
        mov       ax, word ptr [bp+leftSkip]
        add       word ptr [bp+srcOfs], ax
; Move to the row's first byte; a row that starts before the recorded span becomes the span's start, with its
; screen X.
        mov       ax, word ptr [bp+dstXofs]
        add       word ptr [bp+dstOfs], ax
        mov       ax, word ptr [bp+dstOfs]
        cmp       ax, word ptr [bx+spanFirstOfs]
        jae       MaskedCopyRow
        mov       word ptr [bx+spanFirstOfs], ax
        mov       ax, word ptr [bp+xRec]
        mov       word ptr [bx+spanScreenOfs], ax
; Walk the row a byte at a time, keeping the row count while CX counts the bytes.
MaskedCopyRow:
        push      ds
        les       di, dword ptr [bp+aDest]
        add       di, word ptr [bp+dstOfs]
        push      cx
        mov       cx, word ptr [bp+rowBytes]
; With save-under on, keep the background byte about to be covered.
MaskedCopyByte:
        cmp       byte ptr [bp+saveFlag], 0
        je        MaskedComposite
        lds       si, dword ptr [bp+kSave]
        add       si, word ptr [bp+savOfs]
        mov       al, byte ptr es:[di + bufData]
        mov       byte ptr [si + bufData], al
; Keep the background where the mask is set, OR the frame's pixels in, and advance the source, save-under and
; dest cursors.
MaskedComposite:
        lds       si, dword ptr [bp+maskOfs]
        add       si, word ptr [bp+srcOfs]
        mov       ah, byte ptr [si]
        lds       si, dword ptr [bp+aGfx]
        add       si, word ptr [bp+srcOfs]
        mov       al, byte ptr [si + bufData]
        and       byte ptr es:[di + bufData], ah
        or        byte ptr es:[di + bufData], al
        inc       word ptr [bp+srcOfs]
        inc       word ptr [bp+savOfs]
        inc       word ptr [bp+dstOfs]
        inc       di
        loop      MaskedCopyByte
; Let the row's last byte extend the span's end.
        pop       cx
        pop       ds
        mov       ax, word ptr [bp+dstOfs]
        dec       ax
        cmp       ax, word ptr [bx+spanLastOfs]
        jbe       MaskedNextRow
        mov       word ptr [bx+spanLastOfs], ax
; Skip the rest of the dest row and the source bytes clipped off the right, then go on to the next scanline; the
; loop body is too long for LOOP.
MaskedNextRow:
        mov       ax, word ptr [bp+dstStep]
        add       word ptr [bp+dstOfs], ax
        mov       ax, word ptr [bp+srcStep]
        add       word ptr [bp+srcOfs], ax
        add       word ptr [bp+savOfs], ax
        shr       bx, 1
        inc       bx
        dec       cx
        je        MaskedDone
        jmp       INNER2
MaskedDone:
        ret

CODE    ENDS
        END
