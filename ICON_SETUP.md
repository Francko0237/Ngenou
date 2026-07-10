# Configuration des Icônes et Splash Screen NovaMind

## Splash Screen Flutter

Le splash screen Flutter est déjà configuré avec :
- Fond dégradé violet/rose (667eea → 764ba2 → f093fb)
- Animation d'apparition avec rotation et scale
- Icône au centre (Icons.psychology)
- Nom de l'app avec effet d'ombre
- Indicateur de chargement stylisé

Fichier: `lib/features/splash/splash_screen.dart`

## Générer l'Icône de l'Application

### Étape 1: Générer le logo PNG
```bash
flutter run lib/tools/generate_app_icon.dart
```

Cela créera `assets/images/logo.png` avec une icône stylée NovaMind.

### Étape 2: Générer les icônes pour toutes les plateformes
```bash
flutter pub run flutter_launcher_icons:main
```

Cela générera automatiquement les icônes pour :
- Android (mipmap-hdpi, mdpi, xhdpi, xxhdpi, xxxhdpi)
- iOS (toutes les tailles requises)

### Étape 3: Rebuild l'application
```bash
flutter run
```

## Personnalisation

### Couleurs du thème
Les couleurs principales sont définies dans :
- `android/app/src/main/res/values/colors.xml` (Android natif)
- `lib/features/splash/splash_screen.dart` (Flutter splash)
- `lib/tools/generate_app_icon.dart` (Icône générée)

Couleurs NovaMind:
- Primary: #667eea (Violet bleu)
- Secondary: #764ba2 (Violet)
- Accent: #f093fb (Rose)

### Splash Screen Android Natif
Le splash screen Android utilise le même dégradé que le Flutter:
- Fichier: `android/app/src/main/res/drawable/nova_gradient.xml`
- Cercle blanc au centre en attendant le chargement Flutter

## Dépannage

Si les icônes ne s'affichent pas:
1. Vérifiez que `assets/images/logo.png` existe
2. Nettoyez le build: `flutter clean`
3. Rebuild: `flutter pub get && flutter run`

Pour iOS, assurez-vous d'ouvrir Xcode et de vérifier les Assets.xcassets.
