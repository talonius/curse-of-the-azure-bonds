; Glyph drawing for the text renderer: one 8x8 character cell in CGA, EGA or Tandy video memory.
; Each routine is a near Pascal external taking (col, row, ink, paper, glyphIndex). RenderChar has already copied the
; glyph's eight rows to glyphBits, so glyphIndex is not read. Each routine preserves SS and DS.

CODE    SEGMENT BYTE PUBLIC 'CODE'
        ASSUME  CS:CODE, DS:DATA
        PUBLIC  CGAGLYPH, EGAGLYPH, TANDYGLYPH

DATA    SEGMENT WORD PUBLIC
        ; Each CGA color as a packed-pixel seed byte, and the eight glyph rows RenderChar staged.
        EXTRN   attrTable:BYTE
        EXTRN   glyphBits:BYTE
DATA    ENDS

; CGAGLYPH -- CGA 320x200 in four colors, used when displayMode is 0. Even scanlines live in the first bank and odd
; ones in the second; each scanline is 80 bytes, so a character row is 4 * 80 = 320 bytes per bank, and a cell is two
; bytes wide at 2 bits per pixel.
CGAGLYPH LABEL NEAR
        push    bp
        mov     bp,sp
        push    ss
        push    ds
        ; Find the cell's offset within a bank: row * 320 + col * 2.
        mov     ax,[bp+0Ah]
        mov     bx,140h
        mul     bx
        mov     bx,[bp+0Ch]
        shl     bx,1
        add     ax,bx
        mov     di,ax
        ; Look up the ink and paper colors as packed-pixel seeds.
        xor     bx,bx
        mov     bl,[bp+8]
        mov     dl,[bx+attrTable]
        mov     bl,[bp+6]
        mov     dh,[bx+attrTable]
        ; Draw the eight glyph rows as four pairs of scanlines.
        xor     bx,bx
        mov     ah,1
        mov     cx,4
@@cga_pair:
        push    cx
        ; Even scanline, in the first bank: build the cell's two bytes from the right, four pixels to a byte, merging
        ; ink where the glyph bit is set and paper where it is clear, and rotating both seeds on to the next pixel slot.
        mov     cx,0B800h
        mov     es,cx
        mov     cx,2
        inc     di
@@cga_ev_byte:
        push    cx
        mov     cx,4
        mov     al,0
@@cga_ev_pix:
        test    [bx+glyphBits],ah
        jz      @@cga_ev_paper
        or      al,dl
        jmp     short @@cga_ev_roll
        nop
@@cga_ev_paper:
        or      al,dh
@@cga_ev_roll:
        rol     dl,1
        rol     dl,1
        rol     dh,1
        rol     dh,1
        rol     ah,1
        loop    @@cga_ev_pix
        mov     es:[di],al
        dec     di
        pop     cx
        loop    @@cga_ev_byte
        ; Odd scanline: the next glyph row, built the same way in the second bank.
        inc     bx
        inc     di
        mov     ah,1
        mov     al,0
        mov     cx,0BA00h
        mov     es,cx
        mov     cx,2
        inc     di
@@cga_od_byte:
        push    cx
        mov     cx,4
        mov     al,0
@@cga_od_pix:
        test    [bx+glyphBits],ah
        jz      @@cga_od_paper
        or      al,dl
        jmp     short @@cga_od_roll
        nop
@@cga_od_paper:
        or      al,dh
@@cga_od_roll:
        rol     dl,1
        rol     dl,1
        rol     dh,1
        rol     dh,1
        rol     ah,1
        loop    @@cga_od_pix
        mov     es:[di],al
        dec     di
        pop     cx
        loop    @@cga_od_byte
        ; Move down to the next pair of scanlines.
        inc     bx
        add     di,51h
        pop     cx
        loop    @@cga_pair
        pop     ds
        pop     ss
        pop     bp
        ret     0Ah

; EGAGLYPH -- EGA 320x200 in sixteen colors, planar, used when displayMode is 1. A cell is one byte wide and a
; scanline 40 bytes. In write mode 2 the CPU byte is a color written to each pixel the bit mask allows, so a glyph row
; serves as the bit mask and no pixel packing is needed.
EGAGLYPH LABEL NEAR
        push    bp
        mov     bp,sp
        push    ss
        push    ds
        ; Point at the cell in display memory: row * 320 + col.
        mov     ax,0A000h
        mov     es,ax
        mov     ax,[bp+0Ah]
        mov     bx,140h
        mul     bx
        add     ax,[bp+0Ch]
        mov     di,ax
        ; Select write mode 2 and read mode 1, with no rotation and no colors compared.
        mov     dx,3CEh
        mov     ax,0A05h
        out     dx,ax
        mov     ah,0
        mov     al,3
        out     dx,ax
        mov     ax,7
        out     dx,ax
        ; For each glyph row, paint the ink through the row as the bit mask, then the paper through its complement. With
        ; no colors compared, a read returns $FF, so each and loads the latches and writes the color unchanged.
        xor     bx,bx
        mov     cx,8
@@ega_row:
        mov     ah,[bx+glyphBits]
        mov     al,8
        out     dx,ax
        mov     al,[bp+8]
        and     es:[di],al
        not     ah
        mov     al,8
        out     dx,ax
        mov     al,[bp+6]
        and     es:[di],al
        add     di,28h
        inc     bx
        loop    @@ega_row
        ; Restore the graphics controller defaults: write mode 0, every pixel writable, no rotation, every plane
        ; compared.
        mov     ax,5
        out     dx,ax
        mov     ax,0FF08h
        out     dx,ax
        mov     ax,3
        out     dx,ax
        mov     ax,0F07h
        out     dx,ax
        pop     ds
        pop     ss
        pop     bp
        ret     0Ah

; TANDYGLYPH -- Tandy 320x200 in sixteen colors at 4 bits per pixel, used when displayMode is 2. Scanlines interleave
; across four banks (the bank is the scanline mod 4); each scanline is 160 bytes, so a character row is 2 * 160 = 320
; bytes per bank, and a cell is four bytes wide.
TANDYGLYPH LABEL NEAR
        push    bp
        mov     bp,sp
        push    ss
        push    ds
        ; Find the cell's offset within a bank: row * 320 + col * 4.
        mov     ax,[bp+0Ah]
        mov     bx,140h
        mul     bx
        mov     bx,[bp+0Ch]
        shl     bx,1
        shl     bx,1
        add     ax,bx
        mov     di,ax
        ; Take the paper and ink colors as raw 4-bit values.
        mov     dl,[bp+6]
        mov     dh,[bp+8]
        xor     bx,bx
        mov     ah,1
        mov     cx,2
        ; Draw the eight glyph rows as two passes over the four banks. In each bank, build the cell's four bytes from
        ; the right, two pixels to a byte, merging ink where the glyph bit is set and paper where it is clear, and
        ; swapping both colors' nibbles for the next pixel.
@@t_quad:
        push    cx
        mov     cx,0B800h
        mov     es,cx
        mov     cx,4
        add     di,3
@@t_b0_byte:
        push    cx
        mov     cx,2
        mov     al,0
@@t_b0_pix:
        test    [bx+glyphBits],ah
        jz      @@t_b0_paper
        or      al,dh
        jmp     short @@t_b0_roll
        nop
@@t_b0_paper:
        or      al,dl
@@t_b0_roll:
        push    cx
        mov     cx,4
        rol     dl,cl
        mov     cx,4
        rol     dh,cl
        rol     ah,1
        pop     cx
        loop    @@t_b0_pix
        mov     es:[di],al
        dec     di
        pop     cx
        loop    @@t_b0_byte
        ; Back to the cell's right edge for the next glyph row, in the next bank.
        add     di,4
        inc     bx
        mov     cx,0BA00h
        mov     es,cx
        mov     cx,4
@@t_b1_byte:
        push    cx
        mov     cx,2
        mov     al,0
@@t_b1_pix:
        test    [bx+glyphBits],ah
        jz      @@t_b1_paper
        or      al,dh
        jmp     short @@t_b1_roll
        nop
@@t_b1_paper:
        or      al,dl
@@t_b1_roll:
        push    cx
        mov     cx,4
        rol     dl,cl
        mov     cx,4
        rol     dh,cl
        rol     ah,1
        pop     cx
        loop    @@t_b1_pix
        mov     es:[di],al
        dec     di
        pop     cx
        loop    @@t_b1_byte
        add     di,4
        inc     bx
        mov     cx,0BC00h
        mov     es,cx
        mov     cx,4
@@t_b2_byte:
        push    cx
        mov     cx,2
        mov     al,0
@@t_b2_pix:
        test    [bx+glyphBits],ah
        jz      @@t_b2_paper
        or      al,dh
        jmp     short @@t_b2_roll
        nop
@@t_b2_paper:
        or      al,dl
@@t_b2_roll:
        push    cx
        mov     cx,4
        rol     dl,cl
        mov     cx,4
        rol     dh,cl
        rol     ah,1
        pop     cx
        loop    @@t_b2_pix
        mov     es:[di],al
        dec     di
        pop     cx
        loop    @@t_b2_byte
        add     di,4
        inc     bx
        mov     cx,0BE00h
        mov     es,cx
        mov     cx,4
@@t_b3_byte:
        push    cx
        mov     cx,2
        mov     al,0
@@t_b3_pix:
        test    [bx+glyphBits],ah
        jz      @@t_b3_paper
        or      al,dh
        jmp     short @@t_b3_roll
        nop
@@t_b3_paper:
        or      al,dl
@@t_b3_roll:
        push    cx
        mov     cx,4
        rol     dl,cl
        mov     cx,4
        rol     dh,cl
        rol     ah,1
        pop     cx
        loop    @@t_b3_pix
        mov     es:[di],al
        dec     di
        pop     cx
        loop    @@t_b3_byte
        ; Move down to the next group of four scanlines; the jump back is near because the body is beyond LOOP's reach.
        inc     bx
        add     di,0A1h
        pop     cx
        dec     cx
        jz      @@t_done
        jmp     @@t_quad
@@t_done:
        pop     ds
        pop     ss
        pop     bp
        ret     0Ah

CODE    ENDS
        END
