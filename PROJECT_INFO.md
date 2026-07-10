# NovaMind - Project Info & Architecture

Ce document centralise toutes les informations essentielles sur le projet **NovaMind**, son architecture, ses fonctionnalités et l'historique des modifications. Il est conçu pour aider tout développeur (ou IA) à comprendre rapidement le fonctionnement de l'application.

---

## 🚀 Présentation du Projet
**NovaMind** est une application d'apprentissage interactive développée en **Flutter**. L'application propose des parcours pédagogiques structurés en "Matières" (ex: Algorithmique, Micro-ordinateur). L'utilisateur lit des leçons, fait des exercices (QCM, QRO, Éditeur de code) et peut suivre sa progression globale.

### Fonctionnalités Clés
- **Apprentissage Multi-Matières** : L'application charge dynamiquement les leçons et exercices depuis un registre unifié.
- **Interpréteur Algorithmique** : Un véritable interpréteur (Lexer, Parser, Interpreter) embarqué permettant d'écrire, d'analyser et d'exécuter du pseudo-code avec affichage dans une console virtuelle.
- **Suivi de Progression** : Sauvegarde locale SQLite de l'avancement de l'utilisateur par matière et notion (Scores, nombre d'exercices réussis).
- **Routage Dynamique** : Utilisation de `go_router` pour une navigation web-friendly et des liens profonds.
- **Personnalisation** : Support du thème Clair / Sombre.

---

## 📂 Architecture des Dossiers (`lib/`)
Le projet utilise une architecture orientée "Features" (Fonctionnalités) couplée à un découpage métier.

- **`core/`** : Contient les éléments transversaux à toute l'application.
  - `database/` : Gestion de SQLite (`DatabaseHelper`).
  - `models/` : Modèles de données (`Matiere`, `Notion`, `Lecon`, `Exercice`, `Score`, `Progression`).
  - `providers/` : Gestion d'état globale (`ThemeProvider`, `ProgressionProvider`).
  - `theme/` : Couleurs et styles de l'application.
- **`features/`** : Les pages et interfaces de l'application.
  - `accueil/` : Écran d'accueil listant les matières.
  - `cours/` : Liste des notions (`CoursListPage`) et lecteur de leçons (`LeconPage`).
  - `exercice/` : Moteur de rendu des exercices (`ExercicePage`) et page de résultats (`ResultatPage`).
  - `progression/`, `parametres/`, `terminal/`, `defis/` : Autres écrans principaux.
- **`algo_interpreter/`** : Le cœur de l'interpréteur d'algorithmes (Lexer, Parser, Interpreter, Debugger, SyntaxHighlighter).
- **`modules/`** : Contient les données statiques (cours, leçons, exercices) séparées par matière.
  - `algorithmique/` : Données et cours d'Algorithmique.
  - `micro_ordi/` : Données et cours sur les Micro-ordinateurs.
  - `modules_registry.dart` : Registre central qui expose toutes les matières à l'application.

---

## 🛠️ Modèles Principaux
- **Matiere** : Une discipline (ex: "Algorithmique").
- **Notion** : Un chapitre ou concept clé dans une matière.
- **Lecon** : Le contenu théorique divisé en sections.
- **Exercice** : L'évaluation (Types: `qcm`, `qro`, `editeur`). Le modèle unifié accepte désormais les paramètres `options` et `bonneReponseIndex` pour les QCM modernes, tout en restant rétrocompatible avec `choixQcm` et `reponseAttendue`.

---

## 📝 Historique des Modifications (Changelog)

Veuillez ajouter ci-dessous chaque modification architecturale ou ajout de fonctionnalité important.

### [03 Mai 2026] - Refonte Multi-Matières & Ajout de "Micro-ordinateur"
- **Architecture** : Création de `ModulesRegistry` pour centraliser les matières. L'application ne dépend plus uniquement de l'algorithmique.
- **Routage** : Modification de `go_router` pour accepter des paramètres dynamiques `/cours/:matiereId`. Correction d'un bug de navigation (stack réinitialisé par `context.go`) en utilisant `context.pop()` depuis les pages de résultats.
- **Progression** : Mise à jour de `ProgressionProvider` et `DatabaseHelper` pour sauvegarder et charger les données en filtrant par `matiereId`.
- **Modèles** : Mise à jour du modèle `Exercice` pour unifier les QCM avec les variables `options` et `bonneReponseIndex`.
- **Contenu** : Intégration complète de la matière "Micro-ordinateur" avec toutes ses leçons et exercices.
- **UI** : Le bouton flottant "Terminal" a été rendu exclusif à la matière "Algorithmique". Correction de l'outil `AlgoSyntaxController` pour le rendu syntaxique de base.

### [Avant Mai 2026] - Fondation du Projet
- Création de l'application NovaMind.
- Implémentation du moteur d'exécution Algo.
- Interface des cours, des leçons et des exercices d'algorithmique.
- Thème sombre et clair.
