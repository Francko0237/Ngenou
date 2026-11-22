// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

/// Script d'automatisation pour la publication dynamique des mises à jour Ngenou
///
/// Usage :
///   dart run tool/publish_release.dart [options]
///
/// Options :
///   --title="Titre de la mise à jour"
///   --notes="Description détaillée des changements"
///   --force                  (force la mise à jour obligatoire sur mobile)
///   --dry-run                (affiche ce qui sera fait sans modifier Supabase)
///   --bump="1.2.0+2"         (met à jour pubspec.yaml et AppUpdateService avant de publier)
void main(List<String> args) async {
  print('====================================================');
  print('🚀  NGENOU - PUBLICATION DYNAMIQUE DE NOUVELLE VERSION');
  print('====================================================\n');

  final argMap = <String, String>{};
  bool isForce = false;
  bool isDryRun = false;

  for (final arg in args) {
    if (arg == '--force') {
      isForce = true;
    } else if (arg == '--dry-run') {
      isDryRun = true;
    } else if (arg.startsWith('--')) {
      final parts = arg.substring(2).split('=');
      if (parts.length >= 2) {
        argMap[parts[0]] = parts.sublist(1).join('=');
      }
    }
  }

  // 1. Détection ou mise à jour de la version
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    print('❌ Erreur : pubspec.yaml introuvable dans le répertoire courant.');
    exit(1);
  }

  var pubspecContent = pubspecFile.readAsStringSync();
  final versionRegex = RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)', multiLine: true);
  final match = versionRegex.firstMatch(pubspecContent);

  if (match == null) {
    print('❌ Erreur : Impossible de lire la version dans pubspec.yaml.');
    exit(1);
  }

  String versionName = match.group(1)!;
  int versionCode = int.parse(match.group(2)!);

  final bumpArg = argMap['bump'];
  if (bumpArg != null) {
    final bumpParts = bumpArg.split('+');
    if (bumpParts.length == 2) {
      versionName = bumpParts[0];
      versionCode = int.parse(bumpParts[1]);

      pubspecContent = pubspecContent.replaceFirst(
        versionRegex,
        'version: $versionName+$versionCode',
      );
      pubspecFile.writeAsStringSync(pubspecContent);
      print('📦 pubspec.yaml mis à jour : version $versionName+$versionCode');

      // Mettre aussi à jour AppUpdateService.dart
      final updateServiceFile = File('lib/core/services/app_update_service.dart');
      if (updateServiceFile.existsSync()) {
        var serviceContent = updateServiceFile.readAsStringSync();
        serviceContent = serviceContent.replaceFirst(
          RegExp(r"static const String currentVersionName = '[^']+';"),
          "static const String currentVersionName = '$versionName';",
        );
        serviceContent = serviceContent.replaceFirst(
          RegExp(r'static const int currentVersionCode = [0-9]+;'),
          'static const int currentVersionCode = $versionCode;',
        );
        updateServiceFile.writeAsStringSync(serviceContent);
        print('📱 AppUpdateService.dart synchronisé avec la version $versionName ($versionCode)');
      }
    }
  }

  print('📌 Version cible : v$versionName (Code: $versionCode)');

  // 2. Préparation des métadonnées
  final title = argMap['title'] ?? 'Mise à jour Ngenou v$versionName';
  final notes = argMap['notes'] ??
      'Cette mise à jour apporte des améliorations de performance, des corrections de bugs et de nouvelles fonctionnalités.';
  final apkFileName = 'ngenou-v$versionName.apk';
  final apkUrl = argMap['apk-url'] ??
      'https://github.com/Francko0237/Ngenou_Web/releases/download/v$versionName/$apkFileName';

  final apkArm64FileName = 'ngenou-v$versionName-arm64.apk';
  final apkArm64Url = argMap['apk-arm64-url'] ??
      'https://github.com/Francko0237/Ngenou_Web/releases/download/v$versionName/$apkArm64FileName';

  final apkArm32FileName = 'ngenou-v$versionName-arm32.apk';
  final apkArm32Url = argMap['apk-arm32-url'] ??
      'https://github.com/Francko0237/Ngenou_Web/releases/download/v$versionName/$apkArm32FileName';

  final windowsFileName = 'ngenou-v$versionName-windows.zip';
  final windowsUrl = argMap['windows-url'] ??
      'https://github.com/Francko0237/Ngenou_Web/releases/download/v$versionName/$windowsFileName';

  print('📝 Titre : $title');
  print('📄 Notes : $notes');
  print('🔗 URL APK Universel   : $apkUrl');
  print('🔗 URL APK 64 bits     : $apkArm64Url');
  print('🔗 URL APK 32 bits     : $apkArm32Url');
  print('🔗 URL Windows PC      : $windowsUrl');
  print('⚠️ Mise à jour requise : $isForce');

  // 3. Analyse des captures d'écran (Mise à jour visuelle)
  final screenshotsDir = Directory('assets/screenshots');
  final features = <Map<String, dynamic>>[];

  if (screenshotsDir.existsSync()) {
    // Vérifier si un fichier features.json personnalisé existe
    final customFeaturesFile = File('assets/screenshots/features.json');
    Map<String, Map<String, String>> customFeaturesMap = {};
    if (customFeaturesFile.existsSync()) {
      try {
        final decoded = jsonDecode(customFeaturesFile.readAsStringSync());
        if (decoded is List) {
          for (final item in decoded) {
            final fileName = item['file']?.toString() ?? '';
            if (fileName.isNotEmpty) {
              customFeaturesMap[fileName] = {
                'title': item['title']?.toString() ?? '',
                'body': item['body']?.toString() ?? '',
              };
            }
          }
        }
      } catch (e) {
        print('⚠️ Avertissement : Impossible de lire features.json ($e)');
      }
    }

    final imageExtensions = ['.png', '.jpg', '.jpeg', '.webp'];
    final files = screenshotsDir
        .listSync()
        .whereType<File>()
        .where((f) => imageExtensions.any((ext) => f.path.toLowerCase().endsWith(ext)))
        .toList();

    int order = 0;
    for (final file in files) {
      final fileName = file.uri.pathSegments.last;
      final cdnUrl = 'https://cdn.jsdelivr.net/gh/Francko0237/Ngenou@main/assets/screenshots/$fileName';

      String fTitle = '';
      String fBody = '';

      if (customFeaturesMap.containsKey(fileName)) {
        fTitle = customFeaturesMap[fileName]!['title'] ?? '';
        fBody = customFeaturesMap[fileName]!['body'] ?? '';
      }

      if (fTitle.isEmpty) {
        final nameWithoutExt = fileName.split('.').first.replaceAll(RegExp(r'[_-]'), ' ');
        fTitle = nameWithoutExt[0].toUpperCase() + nameWithoutExt.substring(1);
      }
      if (fBody.isEmpty) {
        fBody = 'Découvrez cette nouvelle amélioration dans la version $versionName.';
      }

      features.add({
        'title': fTitle,
        'body': fBody,
        'image_url': cdnUrl,
        'sort_order': order++,
      });

      print('   🖼️ Capture détectée : $fileName -> $fTitle');
    }
  }

  if (features.isEmpty) {
    print('ℹ️ Aucune capture d\'écran trouvée dans assets/screenshots/. Mise à jour technique.');
    features.add({
      'title': 'Améliorations et optimisations',
      'body': notes,
      'image_url': null,
      'sort_order': 0,
    });
  }

  if (isDryRun) {
    print('\n[DRY RUN] Simulation terminée sans écriture dans Supabase.');
    return;
  }

  // 4. Publication sur Supabase
  const supabaseUrl = 'https://boarzpbrrztqjfnuckxq.supabase.co';
  const serviceKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJvYXJ6cGJycnp0cWpmbnVja3hxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MjgwNjU1NiwiZXhwIjoyMDk4MzgyNTU2fQ.l5CVRQ-m_q3DwhYkmYZQ6BLCLIGUQ8O1C3rxCZ0k44E';

  print('\n🌐 Enregistrement dans Supabase...');

  final httpClient = HttpClient();
  try {
    // A. Upsert dans app_releases
    final releasePayload = {
      'version_name': versionName,
      'version_code': versionCode,
      'title': title,
      'notes': notes,
      'apk_url': apkUrl,
      'apk_url_arm64': apkArm64Url,
      'apk_url_arm32': apkArm32Url,
      'windows_url': windowsUrl,
      'force_update': isForce,
      'is_published': true,
      'published_at': DateTime.now().toUtc().toIso8601String(),
    };

    final releaseUri = Uri.parse('$supabaseUrl/rest/v1/app_releases?on_conflict=version_code');
    final req = await httpClient.postUrl(releaseUri);
    req.headers.set('apikey', serviceKey);
    req.headers.set('Authorization', 'Bearer $serviceKey');
    req.headers.set('Content-Type', 'application/json');
    req.headers.set('Prefer', 'resolution=merge-duplicates,return=representation');
    req.add(utf8.encode(jsonEncode(releasePayload)));

    final res = await req.close();
    final resBody = await res.transform(utf8.decoder).join();

    if (res.statusCode < 200 || res.statusCode >= 300) {
      print('❌ Erreur Supabase app_releases (${res.statusCode}): $resBody');
      exit(1);
    }

    final insertedReleases = jsonDecode(resBody) as List;
    final releaseId = insertedReleases.first['id'] as String;
    print('✅ Version enregistrée dans app_releases (ID: $releaseId)');

    // B. Nettoyer les anciennes features de cette release pour idempotence
    final delUri = Uri.parse('$supabaseUrl/rest/v1/release_features?release_id=eq.$releaseId');
    final delReq = await httpClient.deleteUrl(delUri);
    delReq.headers.set('apikey', serviceKey);
    delReq.headers.set('Authorization', 'Bearer $serviceKey');
    await delReq.close();

    // C. Insérer les nouvelles features
    final featuresPayload = features.map((f) {
      return {
        'release_id': releaseId,
        'title': f['title'],
        'body': f['body'],
        'image_url': f['image_url'],
        'sort_order': f['sort_order'],
      };
    }).toList();

    final featUri = Uri.parse('$supabaseUrl/rest/v1/release_features');
    final featReq = await httpClient.postUrl(featUri);
    featReq.headers.set('apikey', serviceKey);
    featReq.headers.set('Authorization', 'Bearer $serviceKey');
    featReq.headers.set('Content-Type', 'application/json');
    featReq.add(utf8.encode(jsonEncode(featuresPayload)));

    final featRes = await featReq.close();
    if (featRes.statusCode >= 200 && featRes.statusCode < 300) {
      print('✅ ${features.length} fonctionnalités / captures enregistrées dans release_features.');
    } else {
      final fBody = await featRes.transform(utf8.decoder).join();
      print('⚠️ Erreur enregistrement release_features: $fBody');
    }
  } catch (e) {
    print('❌ Erreur réseau ou Supabase : $e');
    exit(1);
  } finally {
    httpClient.close();
  }

  print('\n🎉 PUBLICATION SUPABASE RÉUSSIE !');
  print('   Le site web Ngenou_Web et les clients Ngenou (Mobile & PC Windows) sont synchronisés en direct.');
  print('\n📦 ÉTAPES GITHUB RELEASES (Francko0237/Ngenou_Web) :');
  print('   -------------------------------------------------');
  print('   📱 Pour Android (Split APKs 64 bits et 32 bits) :');
  print('      flutter build apk --split-per-abi');
  print('      gh release upload v$versionName build/app/outputs/flutter-apk/app-arm64-v8a-release.apk#$apkArm64FileName --repo Francko0237/Ngenou_Web');
  print('      gh release upload v$versionName build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk#$apkArm32FileName --repo Francko0237/Ngenou_Web');
  print('');
  print('   💻 Pour Windows PC :');
  print('      flutter build windows --release');
  print('      Compress-Archive -Path build/windows/x64/runner/Release/* -DestinationPath build/windows/x64/runner/$windowsFileName');
  print('      gh release upload v$versionName build/windows/x64/runner/$windowsFileName --repo Francko0237/Ngenou_Web');
  print('      (ou téléversez manuellement votre exécutable/setup sur GitHub Releases sous le tag v$versionName)');
  print('');
  print('   🖼️ Pour les captures d\'écran :');
  print('      git add assets/screenshots && git commit -m "feat: captures v$versionName" && git push');
  print('====================================================\n');
}
