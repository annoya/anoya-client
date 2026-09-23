; Inno Setup script for the Windows build.
;
; What an installer has to do here that `flutter build windows` cannot: put the
; tunnel service and the Wintun driver next to the app, register the service
; (it runs as SYSTEM — creating the adapter is the privileged act, and the app
; never has that privilege), and hand the engine's directory to the user, who
; downloads the geo databases into it while the service reads them.
;
; Build: scripts/build-tunnel-service.sh, then `flutter build windows`, then
; ISCC.exe windows\installer\Anoya.iss. Version comes from pubspec via
; /DAppVersion=<x.y.z> on the ISCC command line.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#define AppName "Anoya"
#define ServiceName "AnoyaTunnel"
#define Release "..\..\build\windows\x64\runner\Release"
#define Service "..\..\build\windows\service"

[Setup]
AppId={{BE54423E-D634-4FEE-A089-40B1E3C6AA64}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=org.anoya
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
OutputBaseFilename={#AppName}-{#AppVersion}-setup
OutputDir=..\..\build\windows\installer
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; The service needs it, and the engine directory's permissions do.
PrivilegesRequired=admin
UninstallDisplayIcon={app}\{#AppName}.exe
WizardStyle=modern

[Files]
Source: "{#Release}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs
Source: "{#Service}\tunnel-service.exe"; DestDir: "{app}\service"; Flags: ignoreversion
; Wintun is loaded from the service executable's own directory.
Source: "{#Service}\wintun.dll"; DestDir: "{app}\service"; Flags: ignoreversion

[Dirs]
; The engine's home (service.Files): the service writes the config and the
; logs here, the app writes the geo databases and reads the logs. One
; directory both may write to is the whole point of the permission.
Name: "{commonappdata}\{#AppName}\engine"; Permissions: users-modify

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppName}.exe"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppName}.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; Flags: unchecked

[Run]
; Re-register on every install: an upgrade replaced the executable, and the
; service manager keeps pointing at the path, which did not move — but a
; changed start type or description would otherwise never reach it.
Filename: "{app}\service\tunnel-service.exe"; Parameters: "-uninstall"; Flags: runhidden waituntilterminated; StatusMsg: "Stopping the tunnel service..."
Filename: "{app}\service\tunnel-service.exe"; Parameters: "-install"; Flags: runhidden waituntilterminated; StatusMsg: "Installing the tunnel service..."
Filename: "{app}\{#AppName}.exe"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{app}\service\tunnel-service.exe"; Parameters: "-uninstall"; Flags: runhidden waituntilterminated; RunOnceId: "StopService"

[Code]
// A running service holds its executable open; stop it before the files are
// replaced, or the upgrade fails on the one file that matters.
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ResultCode: Integer;
begin
  Exec(ExpandConstant('{sys}\sc.exe'), 'stop {#ServiceName}', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Sleep(1500);
  Result := '';
end;
