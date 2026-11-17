<div align="center">

<img src="assets/images/logo.png" alt="Ngenou Logo" width="100" />

# Ngenou

**Application mobile d'apprentissage intelligent avec tuteur IA**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.10+-0175C2?logo=dart)](https://dart.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E?logo=supabase)](https://supabase.com)
[![Version](https://img.shields.io/badge/Version-1.1.1-brightgreen)](https://ngenou.vercel.app)
[![Plateforme](https://img.shields.io/badge/Plateforme-Android-3DDC84?logo=android)](https://github.com/Francko0237/Ngenou_Web/releases)

📲 **Télécharger** : [ngenou.vercel.app](https://ngenou.vercel.app)

</div>

---

## Présentation

**Ngenou** est une application mobile Flutter conçue pour les élèves et étudiants francophones. Elle combine un tuteur IA conversationnel, des cours structurés, des défis quotidiens et un planning de révision en un seul environnement d'apprentissage — disponible entièrement hors-ligne pour les contenus installés.

> Le nom « Ngenou » signifie **intelligence** en langue Bamiléké (Cameroun).

---

## Fonctionnalités

### 🤖 Tuteur IA
- Réponses intelligentes aux questions de cours (mathématiques, physique, informatique…)
- Dictée vocale via reconnaissance vocale (Speech-to-Text)
- Synthèse audio des réponses (Text-to-Speech)
- Historique des conversations, quotas de messages gérés par utilisateur
- Mode professeur pour les enseignants (génération de cours & exercices)

### 📚 Cours & Apprentissage
- Catalogue de matières : **Algorithmique**, **Micro-ordinateur** et cours personnalisés
- Leçons structurées avec sections de contenu enrichi
- Exercices intégrés : QCM, Questions Réponses Ouvertes (QRO), Éditeur de code
- **Interpréteur algorithmique embarqué** : Lexer, Parser et Interpréteur de pseudo-code avec terminal virtuel et débogueur
- Import de cours personnalisés (formats supportés : JSON, PDF)

### 🏆 Défis Quotidiens
- Série de jours consécutifs (streak), récompenses XP et badges
- Défis algorithmiques chronométrés avec correction automatique
- QCM quotidiens sur différentes matières
- Tableau de progression et statistiques détaillées

### 🧩 Ngenou Assets (Extensions)
- Catalogue d'extensions pédagogiques légères installables à la demande
- Chaque extension ajoute des cours ou exercices supplémentaires
- Validation et import sécurisé via le service d'extensions

### 📅 Planning & Emploi du Temps
- Emploi du temps hebdomadaire personnalisable
- Rappels et alarmes de révision (notifications locales)
- Assistant IA pour la génération automatique d'un planning de révision
- Export PDF et partage du planning
- Mode Ne pas déranger automatique

### 📋 Projets & Tâches
- Gestion de projets d'étude avec tâches et sous-tâches
- Suivi de l'avancement et priorisation
- Widget d'accueil Android pour suivre les tâches sans ouvrir l'app

### 👤 Profil & Paramètres
- Authentification Supabase (email/mot de passe + Google Sign-In)
- Profil utilisateur (avatar, nom, niveau scolaire)
- Thème clair / sombre
- Mode focus anti-distraction
- Vérification automatique des mises à jour APK
- Politique de confidentialité intégrée

### 📶 Mode Hors-Ligne
- Cours, exercices et extensions installées disponibles sans connexion
- Synchronisation automatique à la reconnexion
- Base de données locale SQLite pour toute la progression

---

## Stack Technique

```
Flutter 3.x + Dart 3.10+
│
├── State Management
│   └── provider                    → Gestion d'état globale (thème, progression)
│
├── Navigation
│   └── go_router                   → Routage URL-friendly, liens profonds
│
├── Backend & Auth
│   ├── supabase_flutter            → Auth, PostgreSQL, Storage
│   ├── google_sign_in              → Connexion via compte Google
│   └── connectivity_plus           → Détection hors-ligne / en ligne
│
├── Base de données locale
│   ├── sqflite                     → SQLite (cours, progression, tâches)
│   └── shared_preferences          → Préférences légères (thème, tutoriel vu…)
│
├── IA & Traitement de données
│   ├── http                        → Appels API IA (DeepSeek)
│   ├── speech_to_text              → Reconnaissance vocale
│   ├── flutter_tts                 → Synthèse vocale
│   └── google_mlkit_text_recognition → OCR (lecture de documents)
│
├── UI & Visualisation
│   ├── google_fonts                → Typographie (Inter, Manrope…)
│   ├── fl_chart                    → Graphiques de progression
│   ├── flutter_highlight           → Coloration syntaxique du code
│   ├── flutter_svg                 → Icônes SVG
│   ├── confetti                    → Animations de célébration
│   └── flutter_animate             → Transitions et animations fluides
│
├── Fichiers & Export
│   ├── file_picker                 → Import de fichiers
│   ├── pdf / printing              → Génération et impression de PDF
│   ├── share_plus                  → Partage natif (fichiers, texte)
│   └── screenshot                  → Capture d'écran in-app
│
├── Notifications & Widgets
│   ├── flutter_local_notifications → Rappels de révision
│   ├── timezone + flutter_timezone → Gestion des fuseaux horaires
│   └── home_widget                 → Widget Android d'accueil
│
└── Utilitaires
    ├── audioplayers + audio_session → Lecture audio (sons de feedback)
    ├── path_provider               → Accès aux répertoires système
    ├── url_launcher                → Ouverture de liens externes
    ├── mailer                      → Envoi d'emails (support)
    └── app_links                   → Gestion des deep links
```

---

## Architecture du Projet

```
lib/
├── algo_interpreter/               # Interpréteur de pseudo-code complet
│   ├── lexer.dart                  # Analyse lexicale
│   ├── parser.dart                 # Analyse syntaxique (AST)
│   ├── interpreter.dart            # Exécution de l'AST
│   ├── debugger.dart               # Débogueur pas-à-pas
│   └── syntax_highlighter.dart     # Coloration syntaxique
│
├── core/
│   ├── config/                     # Configuration globale (Supabase, constantes)
│   ├── database/                   # DatabaseHelper SQLite
│   ├── models/                     # Modèles de données
│   │   ├── matiere.dart            # Matière / discipline
│   │   ├── notion.dart             # Chapitre / notion
│   │   ├── lecon.dart              # Leçon avec sections
│   │   ├── exercice.dart           # Exercice (QCM, QRO, éditeur)
│   │   ├── projet.dart             # Projet d'étude
│   │   └── score.dart / progression.dart
│   ├── providers/                  # Providers globaux
│   │   ├── theme_provider.dart     # Thème clair/sombre
│   │   ├── progression_provider.dart
│   │   └── custom_courses_provider.dart
│   ├── services/                   # Services métier
│   │   ├── ai_tutor_service.dart   # Appels API IA (DeepSeek)
│   │   ├── deep_seek_service.dart  # Client DeepSeek
│   │   ├── extensions_service.dart # Gestion des extensions Ngenou Assets
│   │   ├── update_checker_service.dart # Vérification des MAJ APK
│   │   ├── tts_service.dart        # Synthèse vocale
│   │   ├── ocr_service.dart        # Reconnaissance de texte (image)
│   │   ├── focus_mode_service.dart # Mode focus / Ne pas déranger
│   │   ├── pdf_export_service.dart # Export PDF
│   │   ├── sync_service.dart       # Synchronisation Supabase ↔ local
│   │   └── schedule_notification_service.dart # Rappels planning
│   ├── theme/                      # Couleurs et styles
│   ├── utils/                      # Fonctions utilitaires
│   └── widgets/                    # Widgets réutilisables
│
├── features/
│   ├── accueil/                    # Écran principal (3 onglets)
│   │   ├── tabs/
│   │   │   ├── cours_tab.dart      # Onglet Cours & matières
│   │   │   ├── quotidien_tab.dart  # Onglet Défis quotidiens
│   │   │   └── explorer_tab.dart   # Onglet Explorer (assets, projets)
│   │   └── widgets/
│   ├── auth/                       # Connexion / inscription / profil
│   ├── catalogue/                  # Catalogue de cours personnalisés
│   ├── cours/                      # Lecteur de leçons
│   ├── course_builder/             # Constructeur de cours personnalisés
│   ├── defis/                      # Défis quotidiens et algorithmiques
│   ├── enseignant/                 # Espace enseignant (génération de cours)
│   ├── exercice/                   # Moteur d'exercices
│   ├── extensions/                 # Ngenou Assets (extensions)
│   ├── math_tools/                 # Outils mathématiques
│   ├── parametres/                 # Paramètres, profil, confidentialité
│   ├── planning/                   # Emploi du temps et rappels
│   ├── progression/                # Statistiques et progression globale
│   ├── projets/                    # Projets et tâches
│   ├── splash/                     # Écran de démarrage
│   ├── tasks/                      # Gestion des tâches
│   └── terminal/                   # Terminal algorithmique virtuel
│
├── modules/                        # Contenu pédagogique statique
│   ├── algorithmique/              # Cours et exercices d'algorithmique
│   ├── micro_ordi/                 # Cours sur les micro-ordinateurs
│   ├── custom_course_module.dart   # Module des cours personnalisés
│   └── modules_registry.dart       # Registre central de toutes les matières
│
└── tools/                          # Outils internes de développement

assets/
├── audio/                          # Sons de feedback (succès, erreur…)
├── images/                         # Logo, icônes, launcher icon
└── icons/outline/                  # Icônes SVG (bulb, flask, code, brain…)

extensions/
└── algo_interpreter/               # Extension Algorithmique packagée

android/                            # Configuration Android
supabase/                           # Migrations et configuration Supabase
```

---

## Installation & Développement

### Prérequis

- Flutter SDK `>=3.10.0` ([installer Flutter](https://flutter.dev/docs/get-started/install))
- Android Studio ou VS Code avec les extensions Flutter/Dart
- Un appareil Android ou émulateur (Android 5.0+ / API 21+)

### 1. Cloner le dépôt

```bash
git clone https://github.com/Francko0237/Ngenou.git
cd Ngenou
flutter pub get
```

### 2. Lancer en développement

```bash
# Sur Android (appareil physique ou émulateur)
flutter run

# Sur Linux desktop (si disponible)
flutter run -d linux
```

> **Note Linux (Fedora/Nobara)** : Si `flutter run -d linux` échoue avec des erreurs CMake sur `/usr/lib/dbus-1.0/include`, créez des liens symboliques :
> ```bash
> sudo mkdir -p /usr/lib/dbus-1.0 /usr/lib/glib-2.0
> sudo ln -sfn /usr/lib64/dbus-1.0/include /usr/lib/dbus-1.0/include
> sudo ln -sfn /usr/lib64/glib-2.0/include /usr/lib/glib-2.0/include
> ```

### 3. Compiler l'APK de production

```bash
# APK universel (32-bit + 64-bit)
flutter build apk --release

# APK 32-bit uniquement (compatible avec tous les appareils)
flutter build apk --release --target-platform android-arm

# APK split par architecture
flutter build apk --release --split-per-abi
```

L'APK se trouve dans `build/app/outputs/flutter-apk/`.

---

## Configuration Supabase

### Variables d'environnement

Les clés Supabase sont configurées dans `lib/core/services/supabase_credentials.dart`. Pour utiliser votre propre backend :

1. Créer un projet sur [supabase.com](https://supabase.com)
2. Mettre à jour les clés dans `supabase_credentials.dart` :
   ```dart
   static const String supabaseUrl = 'https://votre-projet.supabase.co';
   static const String supabaseAnonKey = 'votre_cle_anon';
   ```

### Structure de la base de données

Les migrations SQL sont disponibles dans le dossier [`supabase/`](supabase/). Exécutez-les dans l'ordre depuis le **SQL Editor** de votre tableau de bord Supabase.

**Tables principales :**

| Table | Description |
|---|---|
| `profiles` | Profils utilisateurs (nom, niveau, quota IA, rôle) |
| `app_releases` | Versions publiées de l'APK (géré via ngenou_web) |
| `release_features` | Fonctionnalités de chaque version |

---

## Modèles de Données

```
Matiere (discipline)
  └── Notion (chapitre)
        ├── Lecon (cours théorique)
        │     └── [Sections de contenu]
        └── Exercice (évaluation)
              ├── QCM     → options[], bonneReponseIndex
              ├── QRO     → reponseAttendue
              └── Editeur → code à écrire / compléter
```

---

## Vérification des Mises à Jour

L'application vérifie automatiquement la disponibilité d'une nouvelle version au démarrage (1 fois par jour). Les données de version sont récupérées depuis le backend Supabase partagé avec [ngenou_web](https://github.com/Francko0237/Ngenou_Web).

```dart
// Comportement automatique dans main.dart :
UpdateChecker.checkOnStartup(context); // Vérifie 1x/jour au démarrage
```

| Type de mise à jour | Comportement |
|---|---|
| **Standard** | Boîte de dialogue avec les nouveautés, « Télécharger » ou « Plus tard » |
| **Obligatoire** (`force_update: true`) | Boîte non-fermable, seul le téléchargement est disponible |

---

## Téléchargement

La dernière version est disponible sur :

| Source | Lien |
|---|---|
| 🌐 **Site officiel** | [ngenou.vercel.app](https://ngenou.vercel.app) |
| 📦 **GitHub Releases** | [github.com/Francko0237/Ngenou_Web/releases](https://github.com/Francko0237/Ngenou_Web/releases) |

> **Version actuelle** : `1.1.1` — Compatible Android 5.0+ (API 21+), architecture 32-bit et 64-bit

---

## Projets liés

| Projet | Description | Lien |
|---|---|---|
| **Ngenou Web** | Site vitrine & console d'administration (Flutter Web) | [github.com/Francko0237/Ngenou_Web](https://github.com/Francko0237/Ngenou_Web) |

---

## Contact & Support

- 📧 **Support** : ngenou.support@gmail.com
- 🌐 **Site officiel** : [ngenou.vercel.app](https://ngenou.vercel.app)

---

<div align="center">

**Ngenou** — *L'apprentissage intelligent dont vous êtes le maître*

© 2024-2025 Ngenou. Tous droits réservés.

</div>
