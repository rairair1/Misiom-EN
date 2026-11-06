; Portable launcher for the English O HUB: one .exe, no installer.
; First run unpacks O HUB (with the English app.asar) to %LOCALAPPDATA%\Misiom-EN\OHUB-<version>,
; later runs start it straight away. O HUB itself needs administrator rights (its own manifest says
; requireAdministrator) and installs Misiom's audio driver and APO effects on first launch.
; Build: makensis -DAPPDIR=<unpacked O HUB folder> -DICON=<app .ico> -DOUTFILE=<out.exe> OHUB-Portable.nsi
Unicode true
!ifndef APPDIR
  !error "pass -DAPPDIR=<folder containing O HUB.exe>"
!endif
!ifndef ICON
  !error "pass -DICON=<.ico file>"
!endif
!ifndef OUTFILE
  !define OUTFILE "OHUB-English-Portable-1.0.10.exe"
!endif
!define VERSION "1.0.10-en.1"

Name "O HUB (English, portable)"
Caption "O HUB (English) - starting"
OutFile "${OUTFILE}"
Icon "${ICON}"
RequestExecutionLevel admin
SetCompressor /SOLID lzma
SetCompressorDictSize 64
InstallDir "$LOCALAPPDATA\Misiom-EN\OHUB-${VERSION}"
ShowInstDetails nevershow
AutoCloseWindow true
BrandingText "Misiom-EN"
VIProductVersion "1.0.10.1"
VIAddVersionKey "ProductName" "O HUB (English, portable)"
VIAddVersionKey "FileDescription" "Portable English O HUB for Misiom headsets"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "LegalCopyright" "O HUB (c) Misiom Co., Ltd. English translation: Misiom-EN"
Page instfiles

Section
  SetShellVarContext current
  IfFileExists "$INSTDIR\.ready" launch
  DetailPrint "First run: unpacking O HUB, this takes about a minute..."
  RMDir /r "$INSTDIR"
  SetOutPath "$INSTDIR"
  File /r "${APPDIR}/*"
  FileOpen $0 "$INSTDIR\.ready" w
  FileWrite $0 "${VERSION}"
  FileClose $0
launch:
  DetailPrint "Starting O HUB..."
  Exec '"$INSTDIR\O HUB.exe"'
SectionEnd
