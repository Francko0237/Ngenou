# Captures d'écran pour les Mises à Jour Ngenou

Placez ici vos captures d'écran lors des mises à jour visuelles de l'application.

### 📌 Comment ça fonctionne :
1. Déposez vos images ici (formats supportés : `.png`, `.jpg`, `.jpeg`, `.webp`).
   - Exemple : `tuteur_ia.png`, `mode_sombre.png`, `nouveau_planning.png`.
2. *(Optionnel)* Vous pouvez ajouter un fichier `features.json` dans ce dossier pour personnaliser le titre et la description de chaque capture :
```json
[
  {
    "file": "tuteur_ia.png",
    "title": "Tuteur IA Intelligent",
    "body": "Posez vos questions en direct et recevez des explications détaillées."
  },
  {
    "file": "mode_sombre.png",
    "title": "Nouveau Thème Sombre OLED",
    "body": "Un confort visuel optimal pour vos sessions de révision nocturnes."
  }
]
```
3. Si vous ne mettez pas de fichier `features.json`, le script génère automatiquement les titres à partir des noms de fichiers (ex: `mode_sombre.png` ➔ `Mode Sombre`).
4. Lors de la publication avec `.\publish-release.ps1` ou `dart run tool/publish_release.dart`, les URLs GitHub / CDN (jsDelivr) sont automatiquement générées et enregistrées dans Supabase.
5. Le site web Ngenou et l'application mobile affichent immédiatement les nouveautés et les images !
