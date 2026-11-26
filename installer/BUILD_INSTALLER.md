# Ngenou — Création de l'installateur Windows

## Prérequis

1. **Flutter build** doit être compilé en mode Release :
   ```powershell
   cd D:\Projets\Flutter\Ngenou
   flutter build windows --release
   ```
   Les fichiers seront dans : `build\windows\x64\runner\Release\`

2. **Inno Setup 6** doit être installé :  
   👉 Télécharger : https://jrsoftware.org/isdl.php

## Compiler l'installateur

### Option A — Interface graphique
1. Ouvrir Inno Setup Compiler
2. Fichier → Ouvrir → `D:\Projets\Flutter\Ngenou\installer\ngenou_setup.iss`
3. Build → Compile (ou F9)
4. L'installateur sera généré dans `installer\output\NgenouSetup_1.1.2_Windows_x64.exe`

### Option B — Ligne de commande
```powershell
# Depuis le dossier du projet
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\ngenou_setup.iss
```

## Structure générée

```
installer/
├── ngenou_setup.iss       ← Script Inno Setup
├── output/
│   └── NgenouSetup_1.1.2_Windows_x64.exe   ← Installateur final
└── BUILD_INSTALLER.md     ← Ce fichier
```

## Mettre à jour la version

Dans `ngenou_setup.iss`, modifier la ligne :
```iss
#define AppVersion "1.1.2"
```

## Uploader sur Ngenou

Une fois l'installateur `.exe` généré :
1. Aller sur https://ngenou.vercel.app/admin
2. Section "Téléchargements → Windows"
3. Uploader le fichier `.exe`
4. Enregistrer

## Notes importantes

- L'installateur cible **Windows 10 x64 minimum** (requis pour l'OCR WinRT)
- Le contrat de licence `LICENSE.txt` est affiché pendant l'installation
- L'app s'installe dans `%AppData%\Local\Programs\Ngenou` (sans droits admin)
- Un raccourci bureau optionnel est proposé à l'installation
