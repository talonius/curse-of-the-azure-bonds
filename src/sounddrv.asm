; Interrupt-driven PC-speaker and Tandy sound playback.
CODE    SEGMENT BYTE PUBLIC 'CODE'
        ASSUME  CS:CODE, DS:CODE
        PUBLIC  InstallSoundTimer, UninstallSoundTimer
        PUBLIC  PROGRAMSPEAKERVOICES, PROGRAMTANDYVOICES, SETVOICEBYTE
        PUBLIC  TIMEOUTCTR
TICKDIV:         ; Tick divider: chain to the BIOS timer handler every 13 ticks.
        db 0Dh,00h,00h,30h
TIMEOUTCTR:      ; Forced-exit countdown, armed by service 0Fh.
        db 00h,00h
ERRMSG:          ; Encoded runtime-error message for the forced-exit handler.
        db 0D2h,0F5h,0EEh,0ADh,0F4h,0E9h,0EDh,0E5h,0A0h,0A0h,0C5h,0F2h,0F2h,0EFh,0F2h,0A0h
        db 0B2h,0B0h,0B9h,0A0h,0E1h,0F4h,0A0h,0B0h,0C2h,0C1h,0C4h,0BAh,0B0h,0B0h,0B3h,0B8h
        db 8Ah,8Dh
SEQVARS:         ; Driver state: current song, voice, voice blocks, and frequency table.
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,01h,00h
        db 00h,00h,02h,00h,03h,04h,00h,06h,08h,00h,0Ch,10h,00h,18h,20h,00h
        db 30h,40h
SEQJT:           ; Score command jump table, 0FAh to 0FFh.
        dw      offset seq_c_zero, offset seq_c_ret, offset seq_c_call, offset seq_c_clear, offset seq_c_loop
        dw      offset seq_c_set
VOICEBLKS:       ; Voice blocks, frequency tables, and score data.
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 84h,8Eh,84h,86h,0F7h,7Eh,0D7h,77h,4Fh,71h,0C4h,6Ah,0C6h,64h,1Eh,5Fh
        db 0C7h,59h,0BDh,54h,0FCh,4Fh,7Eh,4Bh,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,0C0h,0FFh,40h,0F1h,0C0h,0E3h
        db 00h,0D7h,40h,0CBh,80h,0BFh,0C0h,0B4h,80h,0AAh,00h,0A1h,00h,98h,80h,8Fh
        db 40h,87h,6Eh,0Ch,6Eh,0Ch,6Eh,0Ch,6Eh,0Ch,76h,0Ch,6Eh,0Ch,6Eh,0Ch
        db 6Eh,0Ch,6Eh,0Bh,6Eh,0Ch,6Eh,0Ch,6Eh,0Ch,0DEh,0Bh,6Eh,0Ch,6Eh,0Ch
        db 6Eh,0Ch,06h,0Ch,6Eh,0Ch,6Eh,0Ch,6Eh,0Ch,0A6h,0Bh,6Eh,0Ch,6Eh,0Ch
        db 6Eh,0Ch,3Eh,0Ch,6Eh,0Ch,6Eh,0Ch,6Eh,0Ch,46h,0Bh,6Eh,0Ch,6Eh,0Ch
        db 6Eh,0Ch,02h,0Bh,6Eh,0Ch,6Eh,0Ch,6Eh,0Ch,1Eh,0Bh,6Eh,0Ch,6Eh,0Ch
        db 6Eh,0Ch,12h,09h,6Eh,0Ch,6Eh,0Ch,6Eh,0Ch,0BEh,0Ch,6Eh,0Ch,6Eh,0Ch
        db 6Eh,0Ch,52h,09h,6Eh,0Ch,6Eh,0Ch,6Eh,0Ch,92h,09h,6Eh,0Ch,6Eh,0Ch
        db 6Eh,0Ch,9Ah,0Ah,6Eh,0Ch,6Eh,0Ch,6Eh,0Ch,0C2h,0Ah,6Eh,0Ch,6Eh,0Ch
        db 6Eh,0Ch,12h,0Ah,6Eh,0Ch,6Eh,0Ch,6Eh,0Ch,56h,0Ah,6Eh,0Ch,6Eh,0Ch
        db 6Eh,0Ch,0D2h,09h,6Eh,0Ch,6Eh,0Ch,6Eh,0Ch,0C2h,0Dh,6Eh,0Ch,6Eh,0Ch
        db 6Eh,0Ch,0E6h,0Ch,00h,00h,00h,00h,00h,00h,02h,11h,02h,11h,02h,11h
        db 02h,11h,0Ah,11h,36h,11h,62h,11h,02h,11h,02h,11h,02h,11h,02h,11h
        db 0E6h,10h,4Eh,10h,4Ah,10h,46h,10h,02h,11h,6Ah,10h,02h,11h,0AEh,10h
        db 0C6h,10h,1Eh,10h,02h,11h,02h,11h,02h,11h,02h,11h,02h,11h,0F6h,0Fh
        db 06h,10h,0CAh,0Fh,0C6h,0Fh,02h,11h,02h,11h,02h,11h,02h,11h,02h,11h
        db 8Eh,0Fh,02h,11h,02h,11h,02h,11h,0AEh,0Fh,02h,11h,02h,11h,0DAh,0Dh
        db 0F2h,0Dh,8Eh,11h,0A6h,11h,0BEh,11h,02h,11h,02h,11h,02h,11h,12h,0Eh
        db 2Ah,0Eh,72h,0Eh,02h,11h,4Ah,0Eh,5Ah,0Eh,02h,11h,02h,11h,36h,0Fh
        db 42h,0Fh,02h,11h,02h,11h,56h,0Fh,6Eh,0Fh,02h,11h,02h,11h,0D2h,0Eh
        db 0DEh,0Eh,02h,11h,02h,11h,02h,0Fh,02h,11h,0B6h,0Eh,02h,11h,8Eh,0Eh
        db 9Eh,0Eh,9Fh,12h,02h,11h,02h,11h,02h,11h,0D6h,11h,02h,11h,02h,11h
        db 02h,11h,00h,03h,06h,09h,0Ch,0Fh,12h,15h,18h,1Bh,1Eh,21h,24h,27h
        db 2Ah,2Dh,30h,33h,36h,39h,3Bh,3Eh,41h,43h,46h,49h,4Bh,4Eh,50h,52h
        db 55h,57h,59h,5Bh,5Eh,60h,62h,64h,66h,67h,69h,6Bh,6Ch,6Eh,70h,71h
        db 72h,74h,75h,76h,77h,78h,79h,7Ah,7Bh,7Bh,7Ch,7Dh,7Dh,7Eh,7Eh,7Eh
        db 7Eh,7Eh,7Eh,7Eh,7Eh,7Eh,7Eh,7Eh,7Dh,7Dh,7Ch,7Bh,7Bh,7Ah,79h,78h
        db 77h,76h,75h,74h,72h,71h,70h,6Eh,6Ch,6Bh,69h,67h,66h,64h,62h,60h
        db 5Eh,5Bh,59h,57h,55h,52h,50h,4Eh,4Bh,49h,46h,43h,41h,3Eh,3Bh,39h
        db 36h,33h,30h,2Dh,2Ah,27h,24h,21h,1Eh,1Bh,18h,15h,12h,0Fh,0Ch,09h
        db 06h,03h,00h,0FDh,0FAh,0F7h,0F4h,0F1h,0EEh,0EBh,0E8h,0E5h,0E2h,0DFh,0DCh,0D9h
        db 0D6h,0D3h,0D0h,0CDh,0CAh,0C7h,0C5h,0C2h,0BFh,0BDh,0BAh,0B7h,0B5h,0B2h,0B0h,0AEh
        db 0ABh,0A9h,0A7h,0A5h,0A2h,0A0h,9Eh,9Ch,9Ah,99h,97h,95h,94h,92h,90h,8Fh
        db 8Eh,8Ch,8Bh,8Ah,89h,88h,87h,86h,85h,85h,84h,83h,83h,82h,82h,82h
        db 82h,82h,82h,82h,82h,82h,82h,82h,83h,83h,84h,85h,85h,86h,87h,88h
        db 89h,8Ah,8Bh,8Ch,8Eh,8Fh,90h,92h,94h,95h,97h,99h,9Ah,9Ch,9Eh,0A0h
        db 0A2h,0A5h,0A7h,0A9h,0ABh,0AEh,0B0h,0B2h,0B5h,0B7h,0BAh,0BDh,0BFh,0C2h,0C5h,0C7h
        db 0CAh,0CDh,0D0h,0D3h,0D6h,0D9h,0DCh,0DFh,0E2h,0E5h,0E8h,0EBh,0EEh,0F1h,0F4h,0F7h
        db 0FAh,0FDh,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
        db 00h,00h,78h,78h,78h,78h,78h,78h,78h,78h,78h,78h,78h,78h,78h,78h
        db 78h,78h,29h,23h,0BEh,84h,0E1h,6Ch,0D6h,0AEh,52h,90h,49h,0F1h,0F1h,0BBh
        db 0E9h,0EBh,0B3h,0A6h,0DBh,3Ch,87h,0Ch,3Eh,99h,24h,5Eh,0Dh,1Ch,06h,0B7h
        db 47h,0DEh,0B3h,12h,4Dh,0C8h,43h,0BBh,8Bh,0A6h,1Fh,03h,5Ah,7Dh,09h,38h
        db 25h,1Fh,5Dh,0D4h,0CBh,0FCh,96h,0F5h,45h,3Bh,13h,0Dh,89h,0Ah,1Ch,0DBh
        db 0AEh,32h,20h,9Ah,50h,0EEh,40h,78h,36h,0FDh,12h,49h,32h,0F6h,9Eh,7Dh
        db 49h,0DCh,0ADh,4Fh,14h,0F2h,44h,40h,66h,0D0h,6Bh,0C4h,30h,0B7h,32h,3Bh
        db 0A1h,22h,0F6h,22h,91h,9Dh,0E1h,8Bh,1Fh,0DAh,0B0h,0CAh,99h,02h,0B9h,72h
        db 9Dh,49h,2Ch,80h,7Eh,0C5h,99h,0D5h,0E9h,80h,0B2h,0EAh,0C9h,0CCh,53h,0BFh
        db 67h,0D6h,0BFh,14h,0D6h,7Eh,2Dh,0DCh,8Eh,66h,83h,0EFh,57h,49h,61h,0FFh
        db 69h,8Fh,61h,0CDh,0D1h,1Eh,9Dh,9Ch,16h,72h,72h,0E6h,1Dh,0F0h,84h,4Fh
        db 4Ah,77h,02h,0D7h,0E8h,39h,2Ch,53h,0CBh,0C9h,12h,1Eh,33h,74h,9Eh,0Ch
        db 0F4h,0D5h,0D4h,9Fh,0D4h,0A4h,59h,7Eh,35h,0CFh,32h,22h,0F4h,0CCh,0CFh,0D3h
        db 90h,2Dh,48h,0D3h,8Fh,75h,0E6h,0D9h,1Dh,2Ah,0E5h,0C0h,0F7h,2Bh,78h,81h
        db 87h,44h,0Eh,5Fh,50h,00h,0D4h,61h,8Dh,0BEh,7Bh,05h,15h,07h,3Bh,33h
        db 82h,1Fh,18h,70h,92h,0DAh,64h,54h,0CEh,0B1h,85h,3Eh,69h,15h,0F8h,46h
        db 6Ah,04h,96h,73h,0Eh,0D9h,16h,2Fh,67h,68h,0D4h,0F7h,4Ah,4Ah,0D0h,57h
        db 68h,76h,0FAh,16h,0BBh,11h,0ADh,0AEh,24h,88h,79h,0FEh,52h,0DBh,25h,43h
        db 0E5h,3Ch,0F4h,45h,0D3h,0D8h,28h,0CEh,0Bh,0F5h,0C5h,60h,59h,3Dh,97h,27h
        db 8Ah,59h,76h,2Dh,0D0h,0C2h,0C9h,0CDh,68h,0D4h,49h,6Ah,79h,25h,08h,61h
        db 40h,14h,0B1h,3Bh,6Ah,0A5h,11h,28h,0C1h,8Ch,0D6h,0A9h,0Bh,87h,97h,8Ch
        db 2Fh,0F1h,15h,1Dh,9Ah,95h,0C1h,9Bh,0E1h,0C0h,7Eh,0E9h,0A8h,9Ah,0A7h,86h
        db 0C2h,0B5h,54h,0BFh,9Ah,0E7h,0D9h,23h,0D1h,55h,90h,38h,28h,0D1h,0D9h,6Ch
        db 0A1h,66h,5Eh,4Eh,0E1h,30h,9Ch,0FEh,0D9h,71h,9Fh,0E2h,0A5h,0E2h,0Ch,9Bh
        db 0B4h,47h,65h,38h,2Ah,46h,89h,0A9h,82h,79h,7Ah,76h,78h,0C2h,63h,0B1h
        db 26h,0DFh,0DAh,29h,6Dh,3Eh,62h,0E0h,96h,12h,34h,0BFh,39h,0A6h,3Fh,89h
        db 5Eh,0F1h,6Dh,0Eh,0E3h,6Ch,28h,0A1h,1Eh,20h,1Dh,0CBh,0C2h,03h,3Fh,41h
        db 07h,84h,0Fh,14h,05h,65h,1Bh,28h,61h,0C9h,0C5h,0E7h,2Ch,8Eh,46h,36h
        db 08h,0DCh,0F3h,0A8h,8Dh,0FEh,0BEh,0F2h,0EBh,71h,0FFh,0A0h,0D0h,3Bh,75h,06h
        db 8Ch,7Eh,87h,78h,73h,4Dh,0D0h,0BEh,82h,0BEh,0DBh,0C2h,46h,41h,2Bh,8Ch
        db 0FAh,30h,7Fh,70h,0F0h,0A7h,54h,86h,32h,95h,0AAh,5Bh,68h,13h,0Bh,0E6h
        db 0FCh,0F5h,0CAh,0BEh,7Dh,9Fh,89h,8Ah,41h,1Bh,0FDh,0B8h,4Fh,68h,0F6h,72h
        db 7Bh,14h,99h,0CDh,0D3h,0Dh,0F0h,44h,3Ah,0B4h,0A6h,66h,53h,33h,0Bh,0CBh
        db 0A1h,10h,0FFh,0Ah,03h,00h,0FFh,04h,30h,75h,0FFh,1Ch,12h,07h,0FFh,24h
        db 00h,20h,0FFh,22h,10h,27h,0FFh,20h,10h,00h,0FFh,00h,1Ch,00h,0FFh,0Ah
        db 00h,00h,0FFh,00h,0Ch,00h,0FFh,0Ah,03h,00h,0FFh,04h,04h,10h,0FFh,22h
        db 98h,08h,0FFh,06h,10h,00h,0FFh,00h,2Ch,01h,0FFh,0Ah,00h,00h,0FFh,00h
        db 00h,00h,0FFh,0Ah,03h,00h,0FFh,04h,10h,27h,0FFh,1Ch,12h,07h,0FFh,24h
        db 00h,20h,0FFh,22h,28h,23h,0FFh,20h,10h,00h,0FFh,00h,19h,00h,0FFh,0Ah
        db 00h,00h,0FFh,00h,02h,00h,0FFh,0Ah,03h,00h,0FFh,04h,88h,13h,0FFh,22h
        db 0A0h,0Fh,0FFh,06h,2Ch,01h,0FFh,00h,50h,00h,0FFh,0Ah,00h,00h,0FFh,00h
        db 00h,00h,0FFh,0Ah,03h,00h,0FFh,04h,0B8h,0Bh,0FFh,1Ch,12h,07h,0FFh,24h
        db 00h,20h,0FFh,22h,4Ch,04h,0FFh,20h,10h,00h,0FFh,00h,02h,00h,0FFh,0Ah
        db 00h,00h,0FFh,00h,01h,00h,0FFh,0Ah,03h,00h,0FFh,04h,34h,08h,0FFh,22h
        db 0F4h,01h,0FFh,06h,9Ch,0FFh,0FFh,00h,1Eh,00h,0FFh,0Ah,00h,00h,0FFh,00h
        db 00h,00h,0FFh,0Ah,03h,00h,0FFh,04h,40h,1Fh,0FFh,1Ch,12h,07h,0FFh,24h
        db 00h,20h,0FFh,22h,4Ch,04h,0FFh,20h,10h,00h,0FFh,00h,02h,00h,0FFh,0Ah
        db 00h,00h,0FFh,00h,01h,00h,0FFh,0Ah,03h,00h,0FFh,04h,0D4h,17h,0FFh,22h
        db 0F4h,01h,0FFh,06h,9Ch,0FFh,0FFh,00h,50h,00h,0FFh,0Ah,00h,00h,0FFh,00h
        db 00h,00h,0FFh,0Ah,03h,00h,0FFh,1Ch,12h,07h,0FFh,24h,00h,20h,0FFh,22h
        db 0E8h,03h,0FFh,20h,10h,00h,0FFh,06h,0CEh,0FFh,0FFh,26h,04h,00h,0FFh,04h
        db 10h,27h,0FFh,00h,04h,00h,0FFh,04h,20h,4Eh,0FFh,0Ah,00h,00h,0FFh,00h
        db 04h,00h,0FFh,0Ah,03h,00h,0FFh,00h,04h,00h,0FEh,26h,2Eh,0Ah,0FFh,0Ah
        db 00h,00h,0FFh,00h,00h,00h,0FFh,0Ah,03h,00h,0FFh,1Ch,12h,07h,0FFh,24h
        db 00h,20h,0FFh,22h,0E8h,03h,0FFh,20h,10h,00h,0FFh,06h,0CEh,0FFh,0FFh,26h
        db 14h,00h,0FFh,04h,88h,13h,0FFh,00h,01h,00h,0FFh,0Ah,00h,00h,0FFh,00h
        db 01h,00h,0FFh,0Ah,03h,00h,0FFh,04h,30h,75h,0FFh,00h,01h,00h,0FEh,26h
        db 72h,0Ah,0FFh,0Ah,00h,00h,0FFh,00h,00h,00h,0FFh,0Ah,03h,00h,0FFh,04h
        db 10h,27h,0FFh,1Ch,12h,07h,0FFh,24h,00h,20h,0FFh,22h,0F4h,01h,0FFh,20h
        db 10h,00h,0FFh,06h,0CEh,0FFh,0FFh,00h,1Ch,00h,0FFh,0Ah,00h,00h,0FFh,00h
        db 00h,00h,0FFh,0Ah,03h,00h,0FFh,04h,20h,4Eh,0FFh,1Ch,12h,07h,0FFh,24h
        db 00h,20h,0FFh,22h,10h,27h,0FFh,20h,10h,00h,0FFh,00h,05h,00h,0FFh,0Ah
        db 00h,00h,0FFh,00h,01h,00h,0FFh,0Ah,03h,00h,0FFh,04h,34h,08h,0FFh,22h
        db 98h,08h,0FFh,06h,64h,00h,0FFh,00h,64h,00h,0FFh,0Ah,00h,00h,0FFh,00h
        db 00h,00h,0FFh,0Ah,03h,00h,0FFh,04h,0A0h,0Fh,0FFh,00h,05h,00h,0FFh,04h
        db 0E8h,03h,0FFh,00h,04h,00h,0FFh,0Ah,00h,00h,0FFh,00h,00h,00h,0FFh,0Ah
        db 03h,00h,0FFh,04h,0B0h,36h,0FFh,06h,0C8h,00h,0FFh,1Ch,12h,07h,0FFh,24h
        db 00h,20h,0FFh,22h,70h,17h,0FFh,20h,7Bh,00h,0FFh,00h,08h,00h,0FFh,0Ah
        db 00h,00h,0FFh,00h,00h,00h,0FFh,0Ah,03h,00h,0FFh,04h,0B4h,3Fh,0FFh,26h
        db 1Eh,00h,0FFh,06h,3Ch,0FEh,0FFh,00h,0Ch,00h,0FFh,06h,77h,02h,0FFh,00h
        db 08h,00h,0FEh,26h,52h,0Bh,0FFh,0Ah,00h,00h,0FFh,00h,00h,00h,0FFh,0Ah
        db 03h,00h,0FFh,1Ch,12h,07h,0FFh,24h,00h,20h,0FFh,22h,40h,06h,0FFh,20h
        db 9Bh,01h,0FFh,04h,0CCh,10h,0FFh,06h,0Ah,00h,0FFh,00h,1Eh,00h,0FFh,22h
        db 84h,03h,0FFh,04h,14h,05h,0FFh,06h,50h,00h,0FFh,00h,05h,00h,0FFh,0Ah
        db 00h,00h,0FFh,00h,00h,00h,0FFh,0Ah,03h,00h,0FFh,26h,05h,00h,0FFh,04h
        db 38h,18h,0FFh,06h,00h,00h,0FFh,00h,06h,00h,0FFh,28h,0Ch,00h,0FFh,06h
        db 5Eh,0FCh,0FFh,00h,01h,00h,0FFh,06h,84h,03h,0FFh,00h,01h,00h,0FEh,28h
        db 0BEh,0Bh,0FEh,26h,0B2h,0Bh,0FFh,0Ah,00h,00h,0FFh,00h,00h,00h,0FFh,0Ah
        db 03h,00h,0FFh,04h,7Bh,19h,0FFh,26h,0Ah,00h,0FFh,06h,0D3h,0FFh,0FFh,00h
        db 14h,00h,0FFh,06h,0F4h,01h,0FFh,00h,01h,00h,0FEh,26h,0EAh,0Bh,0FFh,0Ah
        db 00h,00h,0FFh,00h,00h,00h,0FFh,0Ah,03h,00h,0FFh,1Ch,12h,07h,0FFh,24h
        db 00h,20h,0FFh,22h,10h,27h,0FFh,20h,10h,00h,0FFh,04h,0E0h,2Eh,0FFh,26h
        db 2Ch,00h,0FFh,06h,0F0h,0F1h,0FFh,00h,02h,00h,0FFh,06h,88h,0Eh,0FFh,00h
        db 02h,00h,0FEh,26h,22h,0Ch,0FFh,0Ah,00h,00h,0FFh,00h,00h,00h,0FFh,0Ah
        db 03h,00h,0FFh,1Ch,12h,07h,0FFh,24h,00h,20h,0FFh,22h,28h,0Ah,0FFh,20h
        db 10h,00h,0FFh,04h,70h,17h,0FFh,06h,60h,0FFh,0FFh,00h,1Eh,00h,0FFh,06h
        db 46h,00h,0FFh,00h,23h,00h,0FFh,0Ah,00h,00h,0FFh,00h,00h,00h,0FFh,0Ah
        db 00h,00h,0FFh,00h,00h,00h,0FFh,0Ah,03h,00h,0FFh,04h,88h,13h,0FFh,1Ch
        db 0F2h,05h,0FFh,24h,00h,10h,0FFh,22h,0F4h,01h,0FFh,20h,4Eh,00h,0FFh,26h
        db 28h,00h,0FFh,06h,00h,00h,0FFh,00h,02h,00h,0FFh,06h,0ADh,0FDh,0FFh,00h
        db 01h,00h,0FFh,06h,00h,00h,0FFh,00h,02h,00h,0FFh,06h,0F4h,01h,0FFh,00h
        db 01h,00h,0FEh,26h,92h,0Ch,0FFh,0Ah,00h,00h,0FFh,00h,00h,00h,0FFh,0Ah
        db 03h,00h,0FFh,1Ch,0F2h,05h,0FFh,24h,00h,10h,0FFh,22h,0E8h,03h,0FFh,20h
        db 00h,01h,0FFh,04h,0E4h,0Ch,0FFh,06h,0ECh,0FFh,0FFh,00h,1Eh,00h,0FFh,0Ah
        db 00h,00h,0FFh,00h,00h,00h,0FCh,0EDh,0Ch,0FFh,00h,00h,00h,0FDh,30h,00h
        db 0FFh,12h,0E8h,0FFh,0FFh,16h,7Ah,0Dh,0FFh,1Ch,0F2h,05h,0FFh,24h,00h,10h
        db 0FFh,22h,28h,00h,0FFh,20h,2Ch,01h,0FDh,60h,00h,0FFh,12h,0E8h,0FFh,0FFh
        db 10h,05h,00h,0FFh,16h,62h,0Dh,0FFh,1Ch,0F2h,05h,0FFh,24h,00h,10h,0FFh
        db 22h,14h,00h,0FFh,20h,78h,00h,0FDh,00h,00h,0FFh,12h,0E8h,0FFh,0FFh,16h
        db 92h,0Dh,0FFh,1Ch,0F2h,05h,0FFh,24h,00h,10h,0FFh,22h,78h,00h,0FFh,20h
        db 0E4h,00h,0FDh,90h,00h,0FFh,12h,0E8h,0FFh,0FFh,16h,0AAh,0Dh,0FFh,1Ch,0F2h
        db 05h,0FFh,24h,00h,10h,0FFh,22h,78h,00h,0FFh,20h,0E4h,00h,0FFh,0Eh,01h
        db 00h,0FBh,03h,00h,0FFh,0FFh,00h,00h,00h,00h,00h,00h,0FFh,0FFh,00h,00h
        db 00h,00h,00h,00h,0FFh,0FFh,00h,00h,00h,00h,03h,00h,0FFh,0FFh,00h,00h
        db 10h,00h,00h,00h,0FFh,0FFh,00h,00h,00h,00h,00h,00h,1Eh,00h,00h,00h
        db 00h,00h,03h,00h,0FFh,0FFh,00h,00h,08h,00h,00h,00h,0FFh,0FFh,00h,00h
        db 00h,00h,00h,00h,1Eh,00h,00h,00h,00h,00h,03h,00h,0FFh,0FFh,00h,00h
        db 14h,00h,00h,00h,0FFh,0FFh,00h,00h,00h,00h,00h,00h,1Eh,00h,00h,00h
        db 00h,00h,0FFh,0Ah,03h,00h,0FFh,04h,0A0h,0Fh,0FFh,06h,14h,00h,0FFh,00h
        db 10h,00h,0FFh,0Ah,00h,00h,0FFh,00h,00h,00h,0FFh,04h,0B8h,0Bh,0FFh,00h
        db 1Ch,00h,0FFh,04h,80h,3Eh,0FFh,06h,0E7h,0FFh,0FFh,00h,90h,01h,0FFh,00h
        db 00h,00h,0FFh,04h,0C0h,01h,0FFh,0Ah,60h,0EAh,0FFh,00h,1Ch,00h,0FFh,0Ah
        db 50h,0C3h,0FFh,0Ch,9Ch,0FFh,0FFh,00h,90h,01h,0FFh,0Ah,00h,00h,0FFh,00h
        db 00h,00h,0FFh,04h,0B8h,0Bh,0FFh,00h,12h,00h,0FFh,04h,80h,3Eh,0FFh,06h
        db 0E7h,0FFh,0FFh,00h,64h,00h,0FFh,00h,00h,00h,0FFh,04h,0C0h,01h,0FFh,0Ah
        db 60h,0EAh,0FFh,00h,12h,00h,0FFh,0Ah,50h,0C3h,0FFh,0Ch,9Ch,0FFh,0FFh,00h
        db 64h,00h,0FFh,0Ah,00h,00h,0FFh,00h,00h,00h,0FFh,04h,28h,23h,0FFh,06h
        db 0E7h,0FFh,0FFh,00h,19h,00h,0FFh,00h,00h,00h,0FFh,04h,0C0h,01h,0FFh,0Ah
        db 0D8h,0D6h,0FFh,0Ch,9Ch,0FFh,0FFh,00h,19h,00h,0FFh,0Ah,00h,00h,0FFh,00h
        db 00h,00h,0FFh,04h,0A0h,0Fh,0FFh,0Ah,40h,9Ch,0FFh,0Ch,9Ch,0FFh,0FFh,06h
        db 9Ch,0FFh,0FFh,00h,19h,00h,0FFh,0Ah,00h,00h,0FFh,00h,00h,00h,0FFh,04h
        db 10h,27h,0FFh,06h,0E7h,0FFh,0FFh,00h,37h,00h,0FFh,00h,00h,00h,0FFh,04h
        db 0C0h,01h,0FFh,0Ah,60h,0EAh,0FFh,0Ch,9Ch,0FFh,0FFh,00h,37h,00h,0FFh,0Ah
        db 00h,00h,0FFh,00h,00h,00h,0FFh,04h,58h,1Bh,0FBh,0Ah,28h,0A0h,0FFh,0Ch
        db 9Ch,0FFh,0FFh,06h,9Ch,0FFh,0FFh,00h,37h,00h,0FFh,0Ah,00h,00h,0FFh,00h
        db 00h,00h,0FFh,04h,40h,1Fh,0FFh,00h,28h,00h,0FFh,00h,00h,00h,0FFh,04h
        db 0C0h,01h,0FFh,26h,04h,00h,0FFh,0Ah,0D8h,0D6h,0FFh,00h,05h,00h,0FFh,0Ah
        db 01h,00h,0FFh,00h,05h,00h,0FEh,26h,0E6h,0Eh,0FFh,0Ah,00h,00h,0FFh,00h
        db 00h,00h,0FFh,26h,14h,00h,0FFh,04h,70h,17h,0FFh,0Ah,50h,0C3h,0FFh,00h
        db 01h,00h,0FFh,04h,88h,13h,0FFh,0Ah,01h,00h,0FFh,00h,01h,00h,0FFh,04h
        db 30h,75h,0FFh,0Ah,50h,0C3h,0FFh,00h,01h,00h,0FEh,26h,06h,0Fh,0FFh,0Ah
        db 00h,00h,0FFh,00h,00h,00h,0FFh,04h,0A0h,0Fh,0FFh,00h,1Ch,00h,0FFh,00h
        db 00h,00h,0FFh,04h,0C0h,01h,0FFh,0Ah,50h,0C3h,0FFh,00h,1Ch,00h,0FFh,0Ah
        db 00h,00h,0FFh,00h,00h,00h,0FFh,04h,10h,27h,0FFh,00h,05h,00h,0FFh,04h
        db 0A0h,0Fh,0FFh,06h,64h,00h,0FFh,00h,64h,00h,0FFh,00h,00h,00h,0FFh,04h
        db 0C0h,01h,0FFh,0Ah,60h,0EAh,0FFh,00h,05h,00h,0FFh,0Ah,50h,0C3h,0FFh,0Ch
        db 9Ch,0FFh,0FFh,00h,64h,00h,0FFh,0Ah,00h,00h,0FFh,00h,00h,00h,0FFh,04h
        db 00h,01h,0FFh,0Ah,30h,75h,0FFh,0Ch,0E8h,03h,0FFh,00h,14h,00h,0FFh,0Ch
        db 18h,0FCh,0FFh,00h,28h,00h,0FFh,0Ah,00h,00h,0FFh,00h,00h,00h,0FFh,04h
        db 80h,01h,0FFh,0Ah,60h,0EAh,0FFh,0Ch,54h,0F2h,0FFh,00h,10h,00h,0FFh,0Ah
        db 00h,00h,0FFh,00h,00h,00h,0FFh,00h,04h,00h,0FFh,0Ah,60h,0EAh,0FFh,0Ch
        db 9Ch,0FFh,0FFh,04h,0E8h,0FDh,0FFh,26h,1Eh,00h,0FFh,06h,8Ah,0FDh,0FFh,00h
        db 0Ch,00h,0FFh,06h,76h,02h,0FFh,00h,08h,00h,0FEh,26h,0DAh,0Fh,0FFh,0Ah
        db 00h,00h,0FFh,00h,00h,00h,0FFh,04h,0D0h,07h,0FFh,06h,5Ah,00h,0FFh,00h
        db 14h,00h,0FFh,00h,00h,00h,0FFh,04h,0C0h,01h,0FFh,0Ah,60h,0EAh,0FFh,0Ch
        db 30h,0F8h,0FFh,00h,14h,00h,0FFh,0Ah,00h,00h,0FFh,00h,00h,00h,0FFh,04h
        db 0C2h,09h,0FFh,0Ah,30h,75h,0FFh,26h,0Ch,00h,0FFh,06h,0F7h,0FFh,0FFh,00h
        db 0Ch,00h,0FFh,06h,09h,00h,0FFh,00h,08h,00h,0FEh,26h,2Ah,10h,0FFh,0Ah
        db 00h,00h,0FFh,00h,00h,00h,0FFh,00h,14h,00h,0FFh,00h,14h,00h,0FFh,04h
        db 0E3h,98h,0FFh,0Ah,60h,0EAh,0FFh,0Ch,38h,0FFh,0FFh,06h,4Eh,0FFh,0FFh,00h
        db 0C8h,00h,0FFh,0Ah,00h,00h,0FFh,00h,00h,00h,0FFh,0Ah,10h,27h,0FFh,0Ch
        db 0F4h,01h,0FFh,04h,00h,0FAh,0FFh,06h,10h,0FFh,0FFh,00h,50h,00h,0FFh,0Ch
        db 00h,00h,0FFh,26h,2Ch,00h,0FFh,06h,50h,0FBh,0FFh,00h,02h,00h,0FFh,06h
        db 0D8h,04h,0FFh,00h,02h,00h,0FEh,26h,86h,10h,0FFh,0Ch,61h,0FEh,0FFh,06h
        db 3Ch,00h,0FFh,00h,78h,00h,0FFh,0Ah,00h,00h,0FFh,00h,00h,00h,0FFh,04h
        db 30h,11h,0FFh,06h,0Bh,00h,0FFh,00h,0BCh,00h,0FFh,06h,0F5h,0FFh,0FFh,00h
        db 0BCh,00h,0FFh,00h,00h,00h,0FFh,04h,0C0h,01h,0FFh,0Ah,0A8h,61h,0FFh,0Ch
        db 9Fh,00h,0FFh,00h,0BCh,00h,0FFh,0Ch,61h,0FFh,0FFh,00h,0BCh,00h,0FFh,0Ah
        db 00h,00h,0FFh,00h,00h,00h,0FFh,0Ch,60h,09h,0FFh,04h,00h,01h,0FFh,00h
        db 19h,00h,0FFh,0Ch,0A0h,0F6h,0FFh,00h,19h,00h,0FFh,0Ah,00h,00h,0FFh,00h
        db 00h,00h,0FFh,0Ah,00h,00h,0FFh,00h,00h,00h,0FFh,0Ah,60h,0EAh,0FFh,0Ch
        db 15h,0FFh,0FFh,04h,0E0h,1Fh,0FFh,26h,06h,00h,0FFh,06h,1Eh,00h,0FFh,00h
        db 10h,00h,0FFh,06h,0E2h,0FFh,0FFh,00h,10h,00h,0FEh,26h,1Ah,11h,0FFh,0Ah
        db 00h,00h,0FFh,00h,00h,00h,0FFh,0Ah,50h,0C3h,0FFh,0Ch,38h,0FFh,0FFh,04h
        db 10h,40h,0FFh,26h,0Ah,00h,0FFh,06h,42h,00h,0FFh,00h,08h,00h,0FFh,06h
        db 0BEh,0FFh,0FFh,00h,08h,00h,0FEh,26h,46h,11h,0FFh,0Ah,00h,00h,0FFh,00h
        db 00h,00h,0FFh,0Ah,0E8h,0FDh,0FFh,0Ch,0D4h,0FEh,0FFh,04h,0B0h,36h,0FFh,26h
        db 08h,00h,0FFh,06h,52h,00h,0FFh,00h,0Ch,00h,0FFh,06h,0B2h,0FFh,0FFh,00h
        db 0Ch,00h,0FEh,26h,72h,11h,0FFh,0Ah,00h,00h,0FFh,00h,00h,00h,0FFh,0Ah
        db 60h,0EAh,0FFh,0Ch,50h,0FBh,0FFh,04h,0D0h,34h,0FFh,00h,1Eh,00h,0FFh,0Ah
        db 00h,00h,0FFh,00h,00h,00h,0FFh,0Ah,60h,0EAh,0FFh,0Ch,50h,0FBh,0FFh,04h
        db 20h,80h,0FFh,00h,1Eh,00h,0FFh,0Ah,00h,00h,0FFh,00h,00h,00h,0FFh,0Ah
        db 60h,0EAh,0FFh,0Ch,50h,0FBh,0FFh,04h,70h,17h,0FFh,00h,0Ah,00h,0FFh,0Ah
        db 00h,00h,0FFh,00h,00h,00h,0FCh,0DDh,11h,0FFh,00h,00h,00h,0FDh,30h,00h
        db 0FFh,10h,0Ch,00h,0FFh,12h,0D3h,0FFh,0FFh,16h,5Fh,12h,0FFh,1Ch,0F2h,05h
        db 0FFh,24h,00h,10h,0FFh,22h,28h,00h,0FFh,20h,2Ch,01h,0FDh,60h,00h,0FFh
        db 10h,07h,00h,0FFh,12h,0D3h,0FFh,0FFh,16h,3Fh,12h,0FFh,1Ch,0F2h,05h,0FFh
        db 24h,00h,10h,0FFh,22h,16h,00h,0FFh,20h,78h,00h,0FDh,00h,00h,0FFh,10h
        db 07h,00h,0FFh,12h,0D3h,0FFh,0FFh,16h,7Fh,12h,0FFh,1Ch,0F2h,06h,0FFh,24h
        db 00h,02h,0FFh,22h,0C8h,00h,0FFh,20h,10h,00h,0FFh,0Eh,06h,00h,0FBh,50h
        db 0C3h,0FFh,0FFh,0C4h,09h,04h,00h,30h,0F8h,06h,00h,00h,00h,00h,00h,80h
        db 0BBh,0FFh,0FFh,0C0h,0E0h,06h,00h,00h,00h,0FFh,0FFh,00h,00h,00h,00h,40h
        db 9Ch,0FFh,0FFh,0C4h,09h,08h,00h,48h,0F4h,05h,00h,00h,00h,00h,00h,0C8h
        db 0AFh,0FFh,0FFh,60h,0F0h,0Bh,00h,00h,00h,0FFh,0FFh,00h,00h,00h,00h,0A8h
        db 0DEh,0FFh,0FFh,24h,0FAh,06h,00h,00h,00h,00h,00h,00h,00h,00h,00h,80h
        db 0BBh,0FFh,0FFh,0C0h,0E0h,06h,00h,00h,00h,0FFh,0FFh,00h,00h,00h,00h,0FFh
        db 04h,40h,1Fh,0FFh,0Ah,30h,75h,0FFh,06h,14h,00h,0FFh,0Ch,9Ch,0FFh,0FFh
        db 00h,10h,00h,0FFh,0Ah,00h,00h,0FFh,00h,00h,00h
OLDVEC8:         ; Saved BIOS timer interrupt vector, restored when playback stops.
        db 00h,00h,00h,00h

REENTRY    EQU  TICKDIV+1        ; ISR reentrancy guard
LOOPCTR    EQU  TICKDIV+2        ; voice loop counter
NOTESTRD   EQU  TICKDIV+3        ; voice-block stride (30h = SizeOf block)
CURVOICE   EQU  SEQVARS+2        ; current voice ptr
BLOCKS     EQU  SEQVARS+4        ; voice-block base
FREQTAB    EQU  SEQVARS+6        ; frequency table base
SEQRET     EQU  SEQVARS+8        ; sequencer return addr
PERVOICE   EQU  SEQVARS+0Ah      ; per-voice song numbers
VOICEBYTE  EQU  SEQVARS+0Eh      ; latched voice byte
PITTAB     EQU  VOICEBLKS+180h   ; chromatic PIT divisor table
ACTIVESPK  EQU  VOICEBLKS+198h   ; active PC-speaker voice ptr
TANDYBLKS  EQU  VOICEBLKS+19Ah   ; Tandy voice blocks
TANDYV3    EQU  VOICEBLKS+22Ah   ; Tandy voice block 3, the noise voice
TANDYFREQ  EQU  VOICEBLKS+31Ah   ; Tandy frequency table
SPKRSONGS  EQU  VOICEBLKS+332h   ; PC-speaker song pointer table
TANDYSONGS EQU  VOICEBLKS+3DAh   ; Tandy song pointer table

; Hooks the timer interrupt with the sound ISR and speeds the timer up, so the voices are stepped many times
; a second while the BIOS handler is still chained at about its usual rate.
InstallSoundTimer:
        push    ds
        push    es
        mov     ax, CODE
        mov     ds, ax
        ; Keep the BIOS handler for chaining and for UninstallSoundTimer.
        mov     ax, 3508h
        int     21h
        mov     word ptr cs:[OLDVEC8], bx
        mov     word ptr cs:[OLDVEC8+2], es
        push    ds
        mov     dx, CODE
        mov     ds, dx
        mov     dx, offset P_isr
        mov     ax, 2508h
        int     21h
        pop     ds
        ; Reprogram timer channel 0 for the faster tick rate.
        mov     al, 0B6h
        out     43h, al
        mov     ax, 13B1h
        out     40h, al
        mov     al, ah
        out     40h, al
        pop     es
        pop     ds
        retf

; Gives the timer interrupt back to the BIOS at its normal rate and silences the speaker and the Tandy voices.
UninstallSoundTimer:
        push    ds
        mov     ax, CODE
        mov     ds, ax
        push    ds
        mov     dx, word ptr cs:[OLDVEC8]
        mov     ax, word ptr cs:[OLDVEC8+2]
        mov     ds, ax
        mov     ax, 2508h
        int     21h
        pop     ds
        ; Back to the BIOS tick rate.
        mov     ax, 0FFFFh
        out     40h, al
        mov     al, ah
        out     40h, al
        ; Disconnect the speaker from timer channel 2.
        in      al, 61h
        and     al, 0FCh
        out     61h, al
        ; Set the Tandy chip's three tone voices and its noise voice to full attenuation.
        mov     al, 09Fh
        out     0C0h, al
        mov     al, 0BFh
        out     0C0h, al
        mov     al, 0DFh
        out     0C0h, al
        mov     al, 0FFh
        out     0C0h, al
        pop     ds
        retf

; The timer ISR. A countdown armed by the game ends the program with a runtime-error message when it runs out;
; otherwise each tick steps the voices unless a step is already in progress, and every 13th tick goes on to the
; BIOS handler so the time of day keeps running.
P_isr:
        sti
        push    ax
        push    bx
        push    dx
        push    ds
        push    si
        mov     ax, CODE
        mov     ds, ax
        cmp     word ptr ds:[TIMEOUTCTR], 0
        jz      isr_tick
        dec     word ptr ds:[TIMEOUTCTR]
        jnz     isr_tick
        ; The countdown ran out: reset the video mode, decode and print the message, and terminate.
        mov     ah, 0Fh
        int     10h
        mov     ah, 0
        int     10h
        mov     bl, 7
        mov     ah, 7Fh
        mov     cx, 21h
        mov     bx, CODE
        mov     es, bx
        mov     bx, offset ERRMSG
isr_msgclr:
        mov     al, es:[bx]
        and     al, ah
        mov     es:[bx], al
        inc     bx
        loop    isr_msgclr
        mov     bl, 7
        mov     ah, 13h
        mov     al, 1
        mov     bh, 0
        mov     cx, 21h
        xor     dx, dx
        mov     bp, CODE
        mov     es, bp
        mov     bp, offset ERRMSG
        int     10h
        mov     ah, 4Ch
        mov     al, 0FFh
        int     21h
isr_tick:
        cmp     byte ptr ds:[REENTRY], 0
        jnz     isr_div
        mov     byte ptr ds:[REENTRY], 1
        call    tick_spkr
        call    tick_tandy
        mov     byte ptr ds:[REENTRY], 0
isr_div:
        dec     byte ptr ds:[TICKDIV]
        jnz     isr_eoi
        mov     byte ptr ds:[TICKDIV], 0Dh
        pop     si
        pop     ds
        pop     dx
        pop     bx
        pop     ax
        jmp     dword ptr cs:[OLDVEC8]
        ; Not chaining this tick: acknowledge the interrupt ourselves.
isr_eoi:
        mov     al, 20h
        out     20h, al
        pop     si
        pop     ds
        pop     dx
        pop     bx
        pop     ax
        iret

; Steps the PC-speaker voices, then sounds the first voice still playing with a nonzero volume through timer
; channel 2, or turns the speaker off when no song is playing or the voice byte is clear.
tick_spkr:
        mov     bx, word ptr ds:[SEQVARS]
        cmp     bx, 0
        jz      spkr_set
        mov     word ptr ds:[ACTIVESPK], 0
        mov     byte ptr ds:[LOOPCTR], 4
        mov     si, offset PITTAB
        mov     word ptr ds:[FREQTAB], si
        mov     si, offset VOICEBLKS
        mov     word ptr ds:[BLOCKS], si
spkr_loop:
        cmp     word ptr [si], 0
        jz      spkr_next
        call    voice_step
        cmp     word ptr ds:[ACTIVESPK], 0
        jnz     spkr_next
        cmp     word ptr [si+0Ah], 0
        jz      spkr_next
        cmp     word ptr [si], 0
        jz      spkr_next
        mov     word ptr ds:[ACTIVESPK], si
spkr_next:
        add     si, 30h
        dec     byte ptr ds:[LOOPCTR]
        jnz     spkr_loop
        mov     bl, byte ptr ds:[VOICEBYTE]
        cmp     bl, 0
        jz      spkr_set
        mov     bx, word ptr ds:[ACTIVESPK]
        cmp     bx, 0
        jz      spkr_set
        mov     si, bx
        mov     ax, [si+8]
        out     42h, al
        mov     al, ah
        out     42h, al
        mov     bx, [si+0Ah]
        and     bl, 3
spkr_set:
        in      al, 61h
        and     al, 0FCh
        or      al, bl
        out     61h, al
        ret

; Steps the Tandy voices, then writes each voice's frequency and attenuation to the sound chip, or silences the
; chip when no song is playing or the voice byte is clear.
tick_tandy:
        mov     bx, word ptr ds:[SEQVARS]
        cmp     bx, 0
        jz      tandy_off
        mov     byte ptr ds:[LOOPCTR], 4
        mov     si, offset TANDYFREQ
        mov     word ptr ds:[FREQTAB], si
        mov     si, offset TANDYBLKS
        mov     word ptr ds:[BLOCKS], si
tandy_loop1:
        cmp     word ptr [si], 0
        jz      tandy_skip1
        call    voice_step
tandy_skip1:
        add     si, 30h
        dec     byte ptr ds:[LOOPCTR]
        jnz     tandy_loop1
        mov     al, byte ptr ds:[VOICEBYTE]
        cmp     al, 0
        jz      tandy_off
        mov     byte ptr ds:[LOOPCTR], 4
        mov     si, offset TANDYBLKS
        mov     dl, 80h
tandy_loop2:
        mov     ax, [si+8]
        shr     ax, 1
        shr     ax, 1
        shr     al, 1
        shr     al, 1
        shr     al, 1
        shr     al, 1
        xor     al, dl
        out     0C0h, al
        cmp     dl, 0E0h
        jz      tandy_noatt
        mov     al, ah
        out     0C0h, al
tandy_noatt:
        mov     ax, 0FFFFh
        sub     ax, [si+0Ah]
        shr     ah, 1
        shr     ah, 1
        shr     ah, 1
        shr     ah, 1
        mov     al, ah
        xor     al, dl
        add     al, 10h
        out     0C0h, al
        add     dl, 20h
        add     si, 30h
        dec     byte ptr ds:[LOOPCTR]
        jnz     tandy_loop2
        ret
tandy_off:
        mov     al, 09Fh
        out     0C0h, al
        mov     al, 0BFh
        out     0C0h, al
        mov     al, 0DFh
        out     0C0h, al
        mov     al, 0FFh
        out     0C0h, al
        ret

; Advances one voice by a tick: applies its volume and pitch slides and vibrato, counts down its note and its
; release, runs the sequencer when the note ends, and walks its envelope table when a stage ends.
voice_step:
        push    cx
        push    di
        mov     ax, [si+0Ch]
        add     [si+0Ah], ax
        mov     ax, [si+6]
        add     [si+4], ax
        sub     dx, dx
        mov     ax, [si+1Eh]
        add     ax, [si+20h]
        jz      vs_nofreq
        cmp     ax, [si+24h]
        jc      vs_store
        sub     ax, [si+24h]
vs_store:
        mov     [si+1Eh], ax
        mov     cl, 4
        sar     ax, cl
        add     ax, [si+1Ch]
        mov     di, ax
        mov     ah, [di]
        mov     al, 0
        imul    word ptr [si+22h]
vs_nofreq:
        add     dx, [si+4]
        mov     [si+8], dx
        cmp     word ptr [si+14h], 0
        jz      vs_dur
        dec     word ptr [si+14h]
        jnz     vs_dur
        mov     word ptr [si+18h], 10h
        mov     word ptr [si+1Ah], 1
vs_dur:
        dec     word ptr [si]
        jnz     vs_rel
        call    seq_proc
vs_rel:
        cmp     word ptr [si+1Ah], 0
        jz      vs_done
        dec     word ptr [si+1Ah]
        jnz     vs_done
vs_relloop:
        mov     bx, [si+16h]
        add     bx, [si+18h]
        cmp     word ptr [bx+2], 0FFFFh
        jnz     vs_relset
        mov     ax, [bx]
        mov     [si+0Ah], ax
        cmp     ax, 0
        jnz     vs_relskip
        mov     [si+0Ch], ax
vs_relskip:
        add     word ptr [si+18h], 4
        jmp     vs_relloop
vs_relset:
        mov     ax, [bx]
        mov     [si+0Ch], ax
        mov     ax, [bx+2]
        mov     [si+1Ah], ax
        add     word ptr [si+18h], 4
vs_done:
        pop     di
        pop     cx
        ret

; Reads the voice's score until it reaches a note: commands 0FAh and up (zero, return, call, clear, loop, set)
; adjust the voice or the read position, and a note sets the duration and pitch of the voice it names.
seq_proc:
        mov     di, [si+2]
        cmp     di, 0
        jnz     seq_go
        ret
seq_go:
        mov     word ptr ds:[CURVOICE], si
seq_loop:
        mov     bl, [di]
        inc     di
        cmp     bl, 0FAh
        jnc     seq_cmd
        jmp     seq_note
seq_cmd:
        sub     bh, bh
        sub     bl, 0FAh
        add     bl, bl
        jmp     word ptr [bx+SEQJT]
seq_c_loop:
        mov     bl, [di]
        inc     di
        mov     bh, 0
        mov     ax, [di]
        add     di, 2
        cmp     word ptr [bx+si], 0
        jz      seq_c_loop_set
        dec     word ptr [bx+si]
        jz      seq_loop
seq_c_loop_set:
        mov     di, ax
        jmp     seq_loop
seq_c_clear:
        mov     si, [di]
        add     di, 2
        add     si, word ptr ds:[BLOCKS]
seq_c_zero:
        sub     bx, bx
        mov     [si+4], bx
        mov     [si+6], bx
        mov     [si+8], bx
        mov     [si+0Ah], bx
        mov     [si+0Ch], bx
        mov     [si+10h], bx
        mov     [si+12h], bx
        mov     [si+16h], bx
        mov     [si+18h], bx
        mov     [si+1Ah], bx
        mov     [si+1Ch], bx
        mov     [si+1Eh], bx
        mov     [si+20h], bx
        mov     [si+22h], bx
        mov     [si+24h], bx
        jmp     seq_loop
seq_c_set:
        mov     bl, [di]
        inc     di
        mov     bh, 0
        mov     ax, [di]
        inc     di
        inc     di
        mov     [bx+si], ax
        cmp     bl, 0
        jnz     seq_loop
seq_end:
        mov     si, word ptr ds:[CURVOICE]
        cmp     word ptr [si], 0
        jnz     seq_e_set
        mov     bl, 4
        sub     bl, byte ptr ds:[LOOPCTR]
        sub     bh, bh
        mov     byte ptr [bx+PERVOICE], 0
        mov     di, 0
seq_e_set:
        mov     [si+2], di
        ret
seq_c_ret:
        mov     di, word ptr ds:[SEQRET]
        jmp     seq_loop
seq_c_call:
        mov     ax, [di]
        add     di, 2
        mov     word ptr ds:[SEQRET], di
        mov     di, ax
        jmp     seq_loop
seq_note_b:
        mov     bl, [di]
        inc     di
seq_note:
        push    di
        mov     al, bl
        mov     cl, 5
        shr     al, cl
        mov     cl, al
        mul     byte ptr ds:[NOTESTRD]
        add     ax, word ptr ds:[BLOCKS]
        mov     di, ax
        pop     bx
        push    bx
        mov     ax, [si+0Eh]
        cmp     al, 1
        ja      sn_mul
        xor     ah, ah
        mov     al, [bx+1]
        jmp     short sn_store
sn_mul:
        mul     byte ptr [bx+1]
sn_store:
        mov     [si], ax
        mov     al, [bx]
        and     ax, 7Fh
        cmp     ax, 7Fh
        jz      sn_tail
        cmp     cl, 0
        ja      sn_tail
        mov     cx, [si]
        mov     [di], cx
        mov     [di+14h], cx
        add     ax, [di+12h]
        mov     word ptr [di+18h], 0
        mov     word ptr [di+1Ah], 1
        mov     cx, 0FFh
sn_oct:
        inc     cl
        sub     ax, 0Ch
        jnc     sn_oct
        add     ax, 0Ch
        mov     bx, ax
        add     bx, bx
        ; Note: the test for the Tandy noise voice branches to the next instruction either way.
        cmp     di, offset TANDYV3
        jnz     sn_notspec
sn_notspec:
        add     bx, word ptr ds:[FREQTAB]
        mov     ax, [bx]
        shr     ax, cl
        mov     [di+4], ax
        mov     [di+8], ax
sn_tail:
        pop     di
        mov     al, [di]
        inc     di
        inc     di
        and     al, 80h
        jnz     sn_more
        jmp     seq_note_b
sn_more:
        jmp     seq_end

; Starts song number song on the PC-speaker voices for SoundDrv.SoundCommand: each voice the song uses is cleared and
; pointed at its score. The ISR is held off while the voices change.
PROGRAMSPEAKERVOICES:
        push    bp
        mov     bp, sp
        push    ax
        push    bx
        push    di
        push    si
        push    ds
        mov     si, CODE
        mov     ds, si
        mov     si, [bp+6]
        mov     word ptr ds:[SEQVARS], si
        add     si, si
        add     si, si
        add     si, si
        mov     byte ptr ds:[REENTRY], 1
        mov     byte ptr ds:[LOOPCTR], 4
        mov     di, offset VOICEBLKS
vwa_loop:
        mov     ax, word ptr [si+SPKRSONGS]
        cmp     ax, 0
        jz      vwa_next
        mov     bx, 2Eh
vwa_clr:
        mov     word ptr [bx+di], 0
        sub     bx, 2
        jge     vwa_clr
        mov     [di+2], ax
        mov     bl, 4
        sub     bl, byte ptr ds:[LOOPCTR]
        sub     bh, bh
        mov     ax, word ptr ds:[SEQVARS]
        mov     byte ptr [bx+PERVOICE], al
        mov     word ptr [di], 1
vwa_next:
        add     di, 30h
        add     si, 2
        dec     byte ptr ds:[LOOPCTR]
        jnz     vwa_loop
        mov     byte ptr ds:[REENTRY], 0
        pop     ds
        pop     si
        pop     di
        pop     bx
        pop     ax
        pop     bp
        retf    2

; Starts song number song on the Tandy voices, the same way.
PROGRAMTANDYVOICES:
        push    bp
        mov     bp, sp
        push    ax
        push    bx
        push    di
        push    si
        push    ds
        mov     si, CODE
        mov     ds, si
        mov     si, [bp+6]
        mov     word ptr ds:[SEQVARS], si
        add     si, si
        add     si, si
        add     si, si
        mov     byte ptr ds:[REENTRY], 1
        mov     byte ptr ds:[LOOPCTR], 4
        mov     di, offset TANDYBLKS
vwb_loop:
        mov     ax, word ptr [si+TANDYSONGS]
        cmp     ax, 0
        jz      vwb_next
        mov     bx, 2Eh
vwb_clr:
        mov     word ptr [bx+di], 0
        sub     bx, 2
        jge     vwb_clr
        mov     [di+2], ax
        mov     bl, 4
        sub     bl, byte ptr ds:[LOOPCTR]
        sub     bh, bh
        mov     ax, word ptr ds:[SEQVARS]
        mov     byte ptr [bx+PERVOICE], al
        mov     word ptr [di], 1
vwb_next:
        add     di, 30h
        add     si, 2
        dec     byte ptr ds:[LOOPCTR]
        jnz     vwb_loop
        mov     byte ptr ds:[REENTRY], 0
        pop     ds
        pop     si
        pop     di
        pop     bx
        pop     ax
        pop     bp
        retf    2

; Sets the voice byte, which lets the ISR drive the speaker and the Tandy chip when nonzero.
SETVOICEBYTE:
        push    bp
        mov     bp, sp
        push    ax
        push    ds
        mov     ax, CODE
        mov     ds, ax
        mov     ax, [bp+6]
        mov     byte ptr ds:[VOICEBYTE], al
        pop     ds
        pop     ax
        pop     bp
        retf    2

CODE    ENDS
        END
