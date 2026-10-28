# Prompt de Génération de Portfolio pour Ngenou (Inspiré de Rakazo.com)

Voici le prompt complet et prêt à l'emploi si tu souhaites regénérer ou adapter ce site portfolio avec une IA :

```markdown
Crée un site web portfolio et landing page SaaS ultra-moderne pour l'application mobile "Ngenou", en t'inspirant du style visuel, du minimalisme et des animations du site https://rakazo.com.

### 1. Direction Artistique & Design (Style Rakazo) :
- Palette de couleurs : Thème clair moderne, épuré et lumineux (#f8fafc, cartes blanches #ffffff), dégradés subtils violet/indigo (radial gradients rgba(99, 102, 241, 0.1) et rgba(37, 99, 235, 0.06)), bordures raffinées (#e2e8f0), ombres portées douces et typographie géométrique ultra-moderne ('Outfit' ou 'Geist' de Google Fonts).
- Navigation : Barre de navigation flottante "pill/dock" en verre dépoli blanc (backdrop-filter: blur(16px)) avec logo officiel de l'application, liens d'ancrage et bouton CTA d'action avec micro-lueur.
- Hero Section :
  * Badge pill supérieur avec pastille verte pulsante ("Version 1.1 • Prêt pour le Play Store & App Store").
  * Titre fort et percutant avec dégradé de texte : "L'apprentissage intelligent dont vous êtes le maître".
  * Sous-titre épuré mettant en avant : Tuteur IA socratique, fiches de cours, défis quotidiens, studio algorithmique, 100% offline-first avec synchronisation Supabase chiffrée.
  * Boutons de téléchargement : Google Play Store et Démo interactive.

### 2. Showcase Démo Interactif (Élément Clé Rakazo) :
- Une boîte de prévisualisation d'application mobile avec barre d'onglets commutable en JavaScript :
  1. Onglet 1 : "Tuteur IA Conversationnel" (Interface de chat décomposant une notion pas-à-pas avec quiz rapides).
  2. Onglet 2 : "Défis Quotidiens & Quiz" (Questions QCM interactives, série de jours / streak, badges).
  3. Onglet 3 : "Extensions & Ngenou Assets" (Catalogue d'outils modulaires : Interpréteur Algorithmique & Console, Atelier Visuel des Fractions, Droite Graduée).
  4. Onglet 4 : "Emploi du Temps, Alarmes & Tâches" (Planning d'étude structuré, rappels vocaux TTS et gestion des tâches).
- Mockups mobiles embellis : Intégrer les captures réelles dans des cadres smartphone stylisés avec encoches et ombres douces.

### 3. Bento Grid & Fonctionnalités :
- Carte 1 (Large) : Architecture 100% Offline-First avec base locale SQLite.
- Carte 2 : Sécurité et isolation des données avec Supabase RLS.
- Carte 3 : Questionnement socratique de l'IA (pas de triche, vrai accompagnement pédagogique).
- Carte 4 (Large) : Design soigné avec visites guidées interactives réinitialisables.

### 4. Obligations Légales & Stores :
- Page dédiée ou section complète de Politique de Confidentialité et CGU (conforme RGPD, Apple App Store Directive 5.1.1(v) et Google Play) détaillant le traitement des données de compte, les interactions IA et le bouton de suppression définitive de compte.

### 5. Format Technique :
- Fichiers séparés propres : `index.html`, `styles.css`, `script.js`, `privacy.html`.
- Vanilla HTML5 / Modern CSS / Vanilla JS sans dépendance lourde, responsive de 320px à 4K.
```

---

## Comment tester et déployer le site créé :

Le site a été directement créé dans le dossier `landing_page/` de ton projet :
- `landing_page/index.html` : La page d'accueil avec le showcase inspiré de Rakazo.
- `landing_page/privacy.html` : La page officielle des CGU & Confidentialité pour le Play Store et l'App Store.
- `landing_page/styles.css` : Le design sombre et épuré.
- `landing_page/script.js` : Les onglets interactifs et l'accordéon FAQ.

### 1. Tester en local :
Ouvre simplement le fichier `landing_page/index.html` dans ton navigateur, ou lance un serveur local :
```bash
python3 -m http.server 8080 --directory landing_page
```
Puis rends-toi sur `http://localhost:8080`.

### 2. Déployer en 1 clic :
- **Vercel** : Glisse simplement le dossier `landing_page` sur vercel.com.
- **GitHub Pages** : Active GitHub Pages sur la branche de ton choix ou le dossier `/docs`.
- **Netlify** : Glisse-dépose le dossier sur app.netlify.com/drop.
