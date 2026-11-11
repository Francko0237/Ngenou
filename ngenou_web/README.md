# Ngenou Web — Site Vitrine & Console d'Administration

Projet web officiel de l'application mobile **Ngenou**, développé en **Flutter Web** avec **Supabase** comme backend sécurisé. Il combine :
1. **Un site vitrine moderne et responsive** (`/`, `/nouveautes`, `/confidentialite`).
2. **Un espace d'administration sécurisé et masqué** (`/admin`, `/admin/login`, `/admin/releases/new`, `/admin/releases/:id/edit`).
3. **Le kit d'intégration mobile** pour la vérification automatique et manuelle des mises à jour dans l'application mobile Flutter Ngenou.

---

## 1. Stack Technique

- **Framework** : Flutter 3.38+ / Dart 3.10+ (Channel stable, null-safety intégral).
- **Style & Design** : Material 3 personnalisé, esthétique sombre premium.
  - Palette officielle : Fond `#060B1A`, Cartes `#0F1A33`, Cyan `#3CC8E8`, Or `#F0B93A`, Texte `#F3EEE2`, Muet `#9BA8C4`.
  - Typographie : **Fraunces** (titres majeurs), **Manrope** (corps et interface).
  - Dégradé officiel : Cyan (`#3CC8E8`) → Or (`#F0B93A`) réservé aux mots-clés et CTA majeurs.
- **Routage** : `go_router` avec stratégie d'URL propre (`usePathUrlStrategy` sans `#`), garde d'authentification et meta-tag `noindex` automatique sur `/admin`.
- **Gestion d'état** : `flutter_riverpod`.
- **Backend & Stockage** : Supabase (Auth, PostgreSQL avec Row Level Security, Storage Buckets `release-media` et `apks`).
- **Déploiement** : Vercel (avec règles de réécriture SPA dans `vercel.json`).

---

## 2. Arborescence du Projet

```text
ngenou_web/
├── assets/
│   ├── images/                # Logos (logo.png, logo_full.png)
│   └── screenshots/           # Captures d'écran de l'application mobile
├── lib/
│   ├── core/
│   │   ├── models/            # AppRelease, ReleaseFeature
│   │   ├── supabase/          # SupabaseConfig, ReleaseRepository, AuthRepository, Providers
│   │   ├── theme/             # AppColors, AppTheme
│   │   └── widgets/           # SiteNavbar, SiteFooter, PhoneMockup, DownloadButton, Responsive
│   ├── features/
│   │   ├── public/
│   │   │   ├── home/          # Hero, Showcase à onglets, Bento grid, CTA, FAQ
│   │   │   ├── nouveautes/    # Historique des versions et fonctionnalités publiées
│   │   │   └── confidentialite/# Politique de confidentialité & CGU (Offline-First)
│   │   └── admin/
│   │       ├── auth/          # Écran de connexion sécurisé avec protection anti-bruteforce
│   │       ├── dashboard/     # Tableau de bord : liste, recherche, tri, publication
│   │       └── release_form/  # Création/édition version, upload APK et images (<1 Mo)
│   ├── routes/                # GoRouter et gardes d'accès admin
│   └── main.dart              # Point d'entrée de l'application
├── mobile_integration/        # Code prêt à intégrer dans l'app mobile Ngenou
│   ├── update_checker_service.dart
│   ├── update_dialog.dart
│   └── parametres_update_tile.dart
├── web/
│   ├── index.html             # En-tête HTML, polices Google Fonts, script noindex /admin
│   ├── robots.txt             # Disallow: /admin
│   ├── sitemap.xml            # Sitemap public excluant /admin
│   └── favicon.png            # Favicon officiel Ngenou
├── supabase_migration.sql     # Script SQL complet de migration Supabase + RLS
├── vercel.json                # Configuration des rewrites et en-têtes HTTP pour Vercel
└── pubspec.yaml
```

---

## 3. Configuration de Supabase

### A. Exécution du script de migration SQL
Dans votre tableau de bord Supabase (**SQL Editor**) ou via la CLI Supabase, exécutez l'intégralité du fichier [`supabase_migration.sql`](file:///home/hell-francko/Documents/Projet/Ngenou/ngenou_web/supabase_migration.sql).

Ce script :
1. Crée les tables `app_releases`, `release_features` et `admin_users`.
2. Active les politiques de sécurité **RLS** :
   - Lecture publique réservée aux versions avec `is_published = true`.
   - Écriture (création, mise à jour, suppression) strictement réservée aux utilisateurs présents dans `admin_users`.
3. Configure les buckets publics de stockage `release-media` et `apks`, et réserve le droit d'upload aux administrateurs.
4. Insère un jeu de données de départ (version 1.1.0).

### B. Désactivation de l'inscription publique
Pour empêcher toute inscription non autorisée :
1. Rendez-vous dans **Authentication > Configuration > Sign Up**.
2. Décochez **« Allow new users to sign up »**.

### C. Création du premier administrateur
1. Dans Supabase, rendez-vous dans **Authentication > Users** et cliquez sur **« Add user »** (ou invitez votre adresse email administrateur, ex. `admin@ngenou.top`).
2. Récupérez l'identifiant unique (UUID) de l'utilisateur créé.
3. Dans le **SQL Editor**, insérez cet UUID dans la table `admin_users` :
   ```sql
   INSERT INTO public.admin_users (user_id)
   VALUES ('VOTRE_UUID_UTILISATEUR_ICI');
   ```

---

## 4. Lancement Local & Compilation

### Dépendances
```bash
cd ngenou_web
flutter pub get
```

### Lancement en développement local
Pour lancer le site avec vos clés Supabase :
```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://votre-projet.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=votre_cle_anon_publique
```

> **Note de sécurité** : Ne renseignez **JAMAIS** la clé `service_role` dans le client web. Seule la clé `anon` (publique) doit être injectée.

### Compilation pour la production (Release)
La commande suivante active les optimisations de chargement, le tree-shaking des icônes (réduction de 99% du poids des polices) :
```bash
flutter build web --release \
  --dart-define=SUPABASE_URL=https://votre-projet.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=votre_cle_anon_publique
```
Les fichiers générés se trouvent dans le dossier `build/web/`.

---

## 5. Déploiement sur Vercel & Domaine ngenou.top

Le fichier [`vercel.json`](file:///home/hell-francko/Documents/Projet/Ngenou/ngenou_web/vercel.json) est déjà configuré à la racine pour rediriger toutes les routes vers `index.html` (support du Single Page Application), interdire l'indexation des URL d'administration avec l'en-tête `X-Robots-Tag: noindex, nofollow`, et mettre en cache les assets statiques.

### Déploiement via Vercel CLI ou GitHub
1. Connectez le dépôt à votre compte [Vercel](https://vercel.com).
2. Dans les paramètres de build du projet Vercel (**Build and Output Settings**) :
   - **Framework Preset** : `Other`
   - **Build Command** :
     ```bash
     flutter/bin/flutter build web --release --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
     ```
   - **Output Directory** : `build/web`
3. Dans **Settings > Environment Variables**, ajoutez :
   - `SUPABASE_URL` = `https://votre-projet.supabase.co`
   - `SUPABASE_ANON_KEY` = `votre_cle_anon_publique`
4. *(Alternative simple)* : Vous pouvez compiler localement (`flutter build web --release ...`) et déployer le dossier `build/web` directement avec `vercel --prod build/web`.

### Configuration du domaine `ngenou.top`
1. Dans votre projet Vercel, accédez à **Settings > Domains**.
2. Ajoutez le domaine `ngenou.top` ainsi que `www.ngenou.top`.
3. Chez votre registrar DNS (ex. Cloudflare, Namecheap, OVH), ajoutez les enregistrements indiqués par Vercel :
   - Enregistrement **A** : `@` → `76.76.21.21`
   - Enregistrement **CNAME** : `www` → `cname.vercel-dns.com`

---

## 6. Intégration dans l'Application Mobile Ngenou

Les fichiers prêts à l'emploi sont situés dans le dossier [`mobile_integration/`](file:///home/hell-francko/Documents/Projet/Ngenou/ngenou_web/mobile_integration/) :

### A. Vérification silencieuse au lancement (1 fois par jour)
Dans votre `main.dart` ou `app.dart` mobile (après l'initialisation de Supabase et l'affichage de la première page) :
```dart
import 'package:ngenou/mobile_integration/update_checker_service.dart';

@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    UpdateChecker.checkOnStartup(context);
  });
}
```

### B. Bouton de vérification dans les Paramètres
Dans votre `parametres_page.dart` mobile, insérez le widget :
```dart
import 'package:ngenou/mobile_integration/parametres_update_tile.dart';

// À insérer dans votre ListView de paramètres :
const ParametresUpdateTile(
  currentVersionName: '1.1.0',
  currentVersionCode: 11,
),
```

### C. Comportement des mises à jour
- **Mise à jour standard** : L'utilisateur voit la liste des nouveautés et peut choisir « Télécharger » (ouvre le site `https://ngenou.top/nouveautes`) ou « Plus tard ».
- **Mise à jour obligatoire (`force_update = true`)** : La boîte de dialogue est non-fermable (le bouton retour et l'arrière-plan sont désactivés) ; seul le bouton « Télécharger » est disponible.

---

## 7. Sécurité & Bonnes Pratiques

- **Masquage d'URL** : La route `/admin` ne figure dans aucun lien public, ni dans le `sitemap.xml`, ni dans `robots.txt`.
- **Protection par rôle (RLS)** : Même si un internaute découvre l'URL `/admin`, les requêtes vers Supabase sont rejetées au niveau du moteur PostgreSQL grâce aux politiques Row Level Security basées sur la table `admin_users`.
- **Anti-Brute Force** : L'écran de connexion administrateur verrouille automatiquement le formulaire après 5 tentatives infructueuses.
- **Règles de contenu public** : Aucune mention de nom de technologie backend ou d'infrastructure (Supabase) n'apparaît sur les pages publiques. Le support est centralisé sur `ngenou.support@gmail.com`.
