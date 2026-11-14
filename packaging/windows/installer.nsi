; Tiecards installer (NSIS). Build with packaging/make-installer.sh, which passes the version in.
; Installs for the current user only (no administrator needed), like the other tie* installers.
!ifndef VERSION
  !define VERSION "0.0.0"
!endif
!define APPNAME "Tiecards"
!define EXE "tiecards.exe"
!define UNINSTKEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\Tiecards"

Name "${APPNAME} ${VERSION}"
OutFile "..\..\dist\tiecards-${VERSION}-setup.exe"
InstallDir "$LOCALAPPDATA\Programs\${APPNAME}"
InstallDirRegKey HKCU "${UNINSTKEY}" "InstallLocation"
RequestExecutionLevel user
SetCompressor /SOLID lzma
Icon "..\..\assets\icon\tiecards.ico"
UninstallIcon "..\..\assets\icon\tiecards.ico"

; the setup program's own file properties
VIProductVersion "${VERSION}.0"
VIAddVersionKey "ProductName" "${APPNAME}"
VIAddVersionKey "FileDescription" "${APPNAME} setup"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "ProductVersion" "${VERSION}"
VIAddVersionKey "LegalCopyright" "MIT licence"

Page license
Page components
Page directory
Page instfiles
UninstPage uninstConfirm
UninstPage instfiles
LicenseData "..\..\LICENSE"

Section "${APPNAME}" SecGame
  SectionIn RO
  SetOutPath "$INSTDIR"
  File "..\..\build\${EXE}"
  File "..\..\LICENSE"
  File "..\..\README.md"
  File "..\..\CHANGELOG.md"
  File "..\..\assets\cards_src\CREDITS.txt"

  CreateDirectory "$SMPROGRAMS\${APPNAME}"
  CreateShortcut "$SMPROGRAMS\${APPNAME}\${APPNAME}.lnk" "$INSTDIR\${EXE}" "" "$INSTDIR\${EXE}" 0
  CreateShortcut "$SMPROGRAMS\${APPNAME}\Uninstall ${APPNAME}.lnk" "$INSTDIR\uninstall.exe"

  WriteUninstaller "$INSTDIR\uninstall.exe"
  WriteRegStr HKCU "${UNINSTKEY}" "DisplayName" "${APPNAME}"
  WriteRegStr HKCU "${UNINSTKEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "${UNINSTKEY}" "DisplayIcon" "$INSTDIR\${EXE}"
  WriteRegStr HKCU "${UNINSTKEY}" "Publisher" "Tie Studio"
  WriteRegStr HKCU "${UNINSTKEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTKEY}" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegDWORD HKCU "${UNINSTKEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINSTKEY}" "NoRepair" 1
SectionEnd

Section "Desktop shortcut" SecDesktop
  CreateShortcut "$DESKTOP\${APPNAME}.lnk" "$INSTDIR\${EXE}" "" "$INSTDIR\${EXE}" 0
SectionEnd

Section "Uninstall"
  Delete "$INSTDIR\${EXE}"
  Delete "$INSTDIR\LICENSE"
  Delete "$INSTDIR\README.md"
  Delete "$INSTDIR\CHANGELOG.md"
  Delete "$INSTDIR\CREDITS.txt"
  Delete "$INSTDIR\uninstall.exe"
  RMDir "$INSTDIR"

  Delete "$SMPROGRAMS\${APPNAME}\${APPNAME}.lnk"
  Delete "$SMPROGRAMS\${APPNAME}\Uninstall ${APPNAME}.lnk"
  RMDir "$SMPROGRAMS\${APPNAME}"
  Delete "$DESKTOP\${APPNAME}.lnk"

  DeleteRegKey HKCU "${UNINSTKEY}"
  ; the saved game and settings (%LOCALAPPDATA%\tiecards) are left in place
SectionEnd
