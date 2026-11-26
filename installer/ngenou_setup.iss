; =============================================================================
; Script Inno Setup — Ngenou Installer pour Windows
; Auteur : YAMGA MOKUBE FRANCK DANIEL
; Contact : danielfranck215@gmail.com
; =============================================================================

#define AppName "Ngenou"
#define AppVersion "1.1.2"
#define AppPublisher "YAMGA MOKUBE FRANCK DANIEL"
#define AppURL "https://ngenou.vercel.app"
#define AppExeName "ngenou.exe"
#define AppBuildDir "..\build\windows\x64\runner\Release"

[Setup]
; Identifiant unique de l'application (ne pas changer après la première version)
AppId={{F3A2B1C4-9D7E-4F8A-B2C5-1E0D3A7F6B9C}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
AllowNoIcons=yes
; Contrat de licence à afficher lors de l'installation
LicenseFile=..\LICENSE.txt
; Icône de l'installateur et des raccourcis (logo officiel Ngenou)
SetupIconFile=..\windows\runner\resources\app_icon.ico
OutputDir=..\installer\output
OutputBaseFilename=NgenouSetup_{#AppVersion}_Windows_x64
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
; Nécessite Windows 10 ou supérieur (pour les API WinRT / OCR)
MinVersion=10.0
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
; Création d'un raccourci dans le menu démarrer
DisableProgramGroupPage=auto
; Infos pour Ajout/Suppression de programmes
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName}
; Ne pas nécessiter les droits admin pour une install utilisateur
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 6.1; Check: not IsAdminInstallMode

[Files]
; Exécutable principal
Source: "{#AppBuildDir}\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion

; DLLs Flutter et plugins
Source: "{#AppBuildDir}\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#AppBuildDir}\app_links_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#AppBuildDir}\audioplayers_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#AppBuildDir}\connectivity_plus_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#AppBuildDir}\file_selector_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#AppBuildDir}\flutter_timezone_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#AppBuildDir}\flutter_tts_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#AppBuildDir}\pdfium.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#AppBuildDir}\printing_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#AppBuildDir}\screen_retriever_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#AppBuildDir}\share_plus_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#AppBuildDir}\speech_to_text_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#AppBuildDir}\sqlite3.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#AppBuildDir}\url_launcher_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#AppBuildDir}\window_manager_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion

; Dossier data Flutter (assets, fonts, etc.)
Source: "{#AppBuildDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

; Fichier de licence
Source: "..\LICENSE.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: quicklaunchicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{localappdata}\{#AppName}"
Type: filesandordirs; Name: "{userappdata}\com.ngenou"

[Code]
// Vérification que Windows 10 ou supérieur est installé
function InitializeSetup(): Boolean;
var
  WinVer: TWindowsVersion;
begin
  GetWindowsVersionEx(WinVer);
  if WinVer.Major < 10 then
  begin
    MsgBox('Ngenou nécessite Windows 10 ou une version supérieure.'#13#10 +
           'Ngenou requires Windows 10 or higher.', mbError, MB_OK);
    Result := False;
  end
  else
    Result := True;
end;
