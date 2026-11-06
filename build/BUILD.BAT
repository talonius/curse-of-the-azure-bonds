@echo off
rem Curse of the Azure Bonds v1.3 whole-image build.
rem C: Turbo Pascal 6.0 with the 1990 RTL; D: this version tree; E: TASM.
rem F: Microsoft EXEPACK. Compiler and library hashes are pinned by the host.
rem
rem Keep PATH short; invoke the other tools by drive.
rem Compiler options come from src\TPC.CFG in the working directory:
rem   /U.              Search this source directory for units.
rem   /$F+             Far routines.
rem   /$A-             Baseline data alignment; source directives may override.
rem   /$E+ and /$N-     Emulation enabled; hardware floating point disabled.
rem   /L               Stage the linker buffer on disk.
rem   /GD and /$D+     Detailed MAP with line-number information.
rem   /$L-             Local-symbol debug information disabled.
rem   /$R- and /$S-     Range and stack checks disabled.
rem   /$V+             Strict string-parameter checking.
rem Keep slash-prefixed options and an options-only TPC.CFG.
rem Review a spacer under both alignment settings, present and absent, before
rem changing it; a passing build alone does not establish original declarations.
rem Compiler memory and option experiments are documented in goldbox-wiki,
rem climb/curse/build-configuration, with their measured version scope.
rem
rem The host creates obj and build\logs. Clean both object search locations so
rem a stale source-directory object cannot hide the newly assembled object.
rem Each tool redirects its own output. The host checks the native log and both
rem complete artifacts; this batch does not branch on every tool's ERRORLEVEL.

d:
cd \src
path c:\
if exist *.TPU del *.TPU
if exist *.OBJ del *.OBJ
if exist ..\obj\*.TPU del ..\obj\*.TPU
if exist ..\obj\*.OBJ del ..\obj\*.OBJ
if exist ..\obj\FIXMAIN.EXE del ..\obj\FIXMAIN.EXE
if exist ..\obj\FIXMAIN.OVR del ..\obj\FIXMAIN.OVR
if exist ..\obj\FIXMAIN.MAP del ..\obj\FIXMAIN.MAP
if exist ..\obj\START.EXE del ..\obj\START.EXE
if exist ..\obj\GAME.OVR del ..\obj\GAME.OVR

rem Assemble the three implementations linked by the Pascal wrappers.
e:\tasm blit,..\obj\blit > ..\build\logs\BUILD.OUT
e:\tasm sounddrv,..\obj\sounddrv >> ..\build\logs\BUILD.OUT
e:\tasm textrend,..\obj\textrend >> ..\build\logs\BUILD.OUT

rem /B rebuilds all used units, including after configuration-only changes.
rem /E selects the output directory; /O selects the linked-object directory.
tpc fixmain.pas /B /E..\obj /O..\obj >> ..\build\logs\BUILD.OUT

rem Publish the overlay under its distributed filename.
ren ..\obj\FIXMAIN.OVR GAME.OVR

rem The genuine packer produces the distributed packed executable.
f:\exepack ..\obj\FIXMAIN.EXE ..\obj\START.EXE >> ..\build\logs\BUILD.OUT
