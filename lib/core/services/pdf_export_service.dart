import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

import '../models/matiere.dart';
import '../models/notion.dart';
import '../models/lecon.dart';
import '../models/exercice.dart';
import '../../modules/modules_registry.dart';
import '../utils/course_context_mapper.dart';

/// Service d'export PDF pour les cours et progressions
class PdfExportService {
  /// Exporte un cours complet en PDF stylé
  static Future<String?> exportCourseToPdf({
    required Matiere matiere,
    required List<Notion> notions,
    required List<Lecon> lecons,
    bool share = true,
  }) async {
    final pdf = pw.Document();
    final font = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();

    // Charger l'image du logo de Ngenou depuis les assets
    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/images/logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (e) {
      // En cas d'erreur de chargement, on affiche pas d'image
    }

    // Assainir toutes les chaînes pour éviter les caractères non supportés par la police standard PDF (ex: apostrophe typographique ’)
    final cleanMatiere = Matiere(
      id: matiere.id,
      nom: _sanitizeString(matiere.nom),
      description: _sanitizeString(matiere.description),
      icone: matiere.icone,
      couleur: matiere.couleur,
      isAvailable: matiere.isAvailable,
      sections: matiere.sections,
    );

    final cleanNotions = notions.map((n) => Notion(
      id: n.id,
      matiereId: n.matiereId,
      titre: _sanitizeString(n.titre),
      niveau: n.niveau,
      description: _sanitizeString(n.description),
      section: n.section,
      contexte: n.contexte,
    )).toList();

    final cleanLecons = lecons.map((l) => Lecon(
      id: l.id,
      notionId: l.notionId,
      titre: _sanitizeString(l.titre),
      contenu: _sanitizeString(l.contenu),
      explicationDetaillee: l.explicationDetaillee != null ? _sanitizeString(l.explicationDetaillee!) : null,
    )).toList();

    matiere = cleanMatiere;
    notions = cleanNotions;
    lecons = cleanLecons;

    // Couleurs de la marque Ngenou (Violet moderne / Bleu clair / Fond sombre)
    final brandDarkBg = PdfColor.fromHex('0F0E17'); // Fond sombre premium de l'app
    final brandPrimary = PdfColor.fromHex('6C63FF'); // Violet moderne (AppColors.primaryDark)
    final brandSecondary = PdfColor.fromHex('4A90D9'); // Bleu clair (AppColors.primaryLight)

    // 1. Première de couverture (Full-bleed sombre)
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero, // Permet le fond perdu (full-bleed)
        build: (context) {
          return pw.Container(
            width: double.infinity,
            height: double.infinity,
            color: brandDarkBg,
            padding: const pw.EdgeInsets.symmetric(horizontal: 50, vertical: 60),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // En-tête : Logo & Slogan de l'app
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    if (logoImage != null)
                      pw.Container(
                        width: 80,
                        height: 80,
                        child: pw.Image(logoImage),
                      )
                    else
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('1C1B2B'),
                          borderRadius: pw.BorderRadius.circular(8),
                          border: pw.Border.all(color: brandPrimary, width: 1.5),
                        ),
                        child: pw.Text(
                          'Ngenou',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 16,
                            color: PdfColors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    pw.Text(
                      'IA ÉDUCATION',
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 10,
                        color: PdfColors.grey400,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                pw.Spacer(flex: 2),
                // Titre et Liseré de couleur
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 5,
                      height: 120,
                      decoration: pw.BoxDecoration(
                        color: brandPrimary,
                        borderRadius: pw.BorderRadius.circular(2.5),
                      ),
                    ),
                    pw.SizedBox(width: 24),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'COURS GÉNÉRÉ PAR IA',
                            style: pw.TextStyle(
                              font: font,
                              fontSize: 12,
                              color: brandPrimary,
                              letterSpacing: 3,
                            ),
                          ),
                          pw.SizedBox(height: 12),
                          pw.Text(
                            matiere.nom.toUpperCase(),
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 32,
                              color: PdfColors.white,
                              lineSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 29),
                  child: pw.Text(
                    matiere.description,
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 12,
                      color: PdfColors.grey300,
                      lineSpacing: 1.4,
                    ),
                  ),
                ),
                pw.Spacer(flex: 3),
                // Pied de page de couverture
                pw.Divider(color: PdfColors.grey800, thickness: 1),
                pw.SizedBox(height: 15),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Document de formation personnalisé',
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 10,
                        color: PdfColors.grey500,
                      ),
                    ),
                    pw.Text(
                      'Ngenou Platform',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 10,
                        color: brandSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    // 2. Page de Sommaire (Clair pour impression)
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'SOMMAIRE',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 26,
                  color: brandPrimary,
                  letterSpacing: 1.5,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Container(
                height: 2,
                color: brandPrimary,
              ),
              pw.SizedBox(height: 24),
              ...notions.asMap().entries.map((entry) {
                final index = entry.key + 1;
                final notion = entry.value;
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 10),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        width: 32,
                        height: 32,
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('EBE9FE'),
                          shape: pw.BoxShape.circle,
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            '$index',
                            style: pw.TextStyle(
                              font: fontBold,
                              color: brandPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 16),
                      pw.Expanded(
                        child: pw.Text(
                          notion.titre,
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 13,
                            color: PdfColors.grey900,
                          ),
                        ),
                      ),
                      pw.Text(
                        '${_countLeconsForNotion(lecons, notion.id)} leçons',
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 11,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );

    // Pages de contenu par notion
    for (final notion in notions) {
      final notionLecons = lecons
          .where((l) => l.notionId == notion.id)
          .toList();

      // 3. Page d'introduction du Chapitre
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) {
            final contextColor = _getContextColor(notion.contexte);
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Bannière de chapitre élégante
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(24),
                  decoration: pw.BoxDecoration(
                    gradient: pw.LinearGradient(
                      colors: [contextColor, contextColor.withAlpha(0.7)],
                      begin: pw.Alignment.topLeft,
                      end: pw.Alignment.bottomRight,
                    ),
                    borderRadius: pw.BorderRadius.circular(16),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'CHAPITRE',
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 11,
                          color: PdfColors.grey200,
                          letterSpacing: 2.5,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        notion.titre,
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 24,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        notion.description,
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 12,
                          color: PdfColors.white,
                          lineSpacing: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 35),
                pw.Text(
                  'Liste des leçons',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 16,
                    color: brandPrimary,
                  ),
                ),
                pw.SizedBox(height: 15),
                ...notionLecons.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final lecon = entry.value;
                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 12),
                    padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Row(
                      children: [
                        pw.Container(
                          width: 4,
                          height: 16,
                          decoration: pw.BoxDecoration(
                            color: contextColor,
                            borderRadius: pw.BorderRadius.circular(2),
                          ),
                        ),
                        pw.SizedBox(width: 12),
                        pw.Text(
                          '$idx.',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 14,
                            color: contextColor,
                          ),
                        ),
                        pw.SizedBox(width: 12),
                        pw.Expanded(
                          child: pw.Text(
                            lecon.titre,
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 12,
                              color: PdfColors.grey800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            );
          },
        ),
      );

      // 4. Pages multipages détaillées de chaque leçon (Rendu Markdown complet)
      for (final lecon in notionLecons) {
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 40),
            header: (context) {
              return pw.Container(
                alignment: pw.Alignment.centerRight,
                margin: const pw.EdgeInsets.only(bottom: 15),
                child: pw.Text(
                  '${matiere.nom} - ${notion.titre}',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 8,
                    color: PdfColors.grey500,
                  ),
                ),
              );
            },
            footer: (context) {
              return pw.Container(
                alignment: pw.Alignment.centerRight,
                margin: const pw.EdgeInsets.only(top: 15),
                child: pw.Text(
                  'Page ${context.pageNumber}',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 8,
                    color: PdfColors.grey500,
                  ),
                ),
              );
            },
            build: (context) {
              return [
                pw.Text(
                  lecon.titre,
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 22,
                    color: brandPrimary,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Container(
                  height: 2,
                  color: brandPrimary.withAlpha(0.2), // 0.2 opacity
                ),
                pw.SizedBox(height: 20),
                ..._parseMarkdownToWidgets(lecon.contenu, font, fontBold),
                if (lecon.explicationDetaillee != null && lecon.explicationDetaillee!.trim().isNotEmpty) ...[
                  pw.SizedBox(height: 25),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('F3F4F6'),
                      borderRadius: pw.BorderRadius.circular(10),
                      border: pw.Border.all(color: brandPrimary.withAlpha(0.3), width: 1),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'FOCUS & ANALOGIE PÉDAGOGIQUE',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 11,
                            color: brandPrimary,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          lecon.explicationDetaillee!,
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 10,
                            color: PdfColors.grey800,
                            lineSpacing: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ];
            },
          ),
        );
      }

      // 5. Section d'exercices d'entraînement pour cette Notion / Chapitre
      final notionExercices = ModulesRegistry.getExercicesByNotion(matiere.id, notion.id);
      if (notionExercices.isNotEmpty) {
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 40),
            header: (context) {
              return pw.Container(
                alignment: pw.Alignment.centerRight,
                margin: const pw.EdgeInsets.only(bottom: 15),
                child: pw.Text(
                  '${matiere.nom} - Exercices - ${notion.titre}',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 8,
                    color: PdfColors.grey500,
                  ),
                ),
              );
            },
            footer: (context) {
              return pw.Container(
                alignment: pw.Alignment.centerRight,
                margin: const pw.EdgeInsets.only(top: 15),
                child: pw.Text(
                  'Page ${context.pageNumber}',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 8,
                    color: PdfColors.grey500,
                  ),
                ),
              );
            },
            build: (context) {
              return [
                pw.Text(
                  'EXERCICES D\'ENTRAÎNEMENT',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 18,
                    color: brandSecondary,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Container(
                  height: 2,
                  color: brandSecondary.withAlpha(0.2),
                ),
                pw.SizedBox(height: 20),
                ...notionExercices.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final ex = entry.value;
                  
                  final cleanedQuestion = _sanitizeString(ex.question);
                  final cleanedExplication = ex.explication != null ? _sanitizeString(ex.explication!) : '';

                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 20),
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Exercice $idx : ${ex.type == TypeExercice.qcm ? "QCM" : "Code / Éditeur"}',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 12,
                            color: brandPrimary,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          cleanedQuestion,
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 10.5,
                            color: PdfColors.black,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        if (ex.type == TypeExercice.qcm && ex.options.isNotEmpty) ...[
                          ...ex.options.asMap().entries.map((optEntry) {
                            final oIdx = optEntry.key;
                            final oText = _sanitizeString(optEntry.value);
                            final isCorrect = oIdx == ex.bonneReponseIndex;
                            return pw.Padding(
                              padding: const pw.EdgeInsets.only(left: 10, bottom: 4),
                              child: pw.Row(
                                children: [
                                  pw.Container(
                                    width: 10,
                                    height: 10,
                                    decoration: pw.BoxDecoration(
                                      shape: pw.BoxShape.circle,
                                      border: pw.Border.all(color: isCorrect ? PdfColors.green : PdfColors.grey400),
                                      color: isCorrect ? PdfColors.green.withAlpha(0.2) : null,
                                    ),
                                    child: pw.Center(
                                      child: isCorrect ? pw.Container(width: 5, height: 5, decoration: const pw.BoxDecoration(shape: pw.BoxShape.circle, color: PdfColors.green)) : null,
                                    ),
                                  ),
                                  pw.SizedBox(width: 8),
                                  pw.Expanded(
                                    child: pw.Text(
                                      oText,
                                      style: pw.TextStyle(
                                        font: font,
                                        fontSize: 9.5,
                                        color: isCorrect ? PdfColors.green : PdfColors.grey700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ] else if (ex.type == TypeExercice.editeur) ...[
                          if (ex.codeInitial != null && ex.codeInitial!.isNotEmpty) ...[
                            pw.Container(
                              width: double.infinity,
                              padding: const pw.EdgeInsets.all(8),
                              color: PdfColors.grey100,
                              child: pw.Text(
                                _sanitizeString(ex.codeInitial!),
                                style: pw.TextStyle(
                                  font: pw.Font.courier(),
                                  fontSize: 8.5,
                                  color: PdfColors.grey800,
                                ),
                              ),
                            ),
                          ],
                        ],
                        if (cleanedExplication.isNotEmpty) ...[
                          pw.SizedBox(height: 8),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(8),
                            decoration: pw.BoxDecoration(
                              color: PdfColor.fromHex('E8F5E9'),
                              borderRadius: pw.BorderRadius.circular(4),
                            ),
                            child: pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('Réponse & Explication : ', style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.green800)),
                                pw.Expanded(
                                  child: pw.Text(
                                    cleanedExplication,
                                    style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.green800),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ];
            },
          ),
        );
      }
    }

    // 5. Dernière de couverture (Full-bleed sombre assortie)
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) {
          return pw.Container(
            width: double.infinity,
            height: double.infinity,
            color: brandDarkBg,
            padding: const pw.EdgeInsets.all(50),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Spacer(),
                if (logoImage != null)
                  pw.Container(
                    width: 100,
                    height: 100,
                    child: pw.Image(logoImage),
                  )
                else
                  pw.Container(
                    width: 80,
                    height: 80,
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('1C1B2B'),
                      shape: pw.BoxShape.circle,
                      border: pw.Border.all(color: brandPrimary, width: 2),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'NM',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 28,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                  ),
                pw.SizedBox(height: 30),
                pw.Text(
                  'Bon apprentissage !',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 26,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  'Continuez à progresser avec l\'application Ngenou',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 13,
                    color: PdfColors.grey300,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.Spacer(),
                pw.Text(
                  'Généré le ${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 10,
                    color: PdfColors.grey500,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '© 2026 Ngenou. Tous droits réservés.',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    // Sauvegarder ou partager
    final output = await pdf.save();
    final fileName =
        'ngenou_${matiere.nom.toLowerCase().replaceAll(' ', '_')}.pdf';

    if (share) {
      // Sauvegarder temporairement et partager
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(output);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '📚 Cours "${matiere.nom}" exporté depuis Ngenou',
        subject: 'Cours: ${matiere.nom}',
      );
      return file.path;
    } else {
      String? savedPath;
      try {
        if (Platform.isAndroid) {
          // Tenter d'écrire directement dans le dossier public /storage/emulated/0/Download
          final downloadDir = Directory('/storage/emulated/0/Download');
          if (await downloadDir.exists()) {
            final file = File('${downloadDir.path}/$fileName');
            await file.writeAsBytes(output);
            savedPath = file.path;
          }
        }
        
        if (savedPath == null) {
          final downloadDir = await getDownloadsDirectory();
          if (downloadDir != null) {
            final file = File('${downloadDir.path}/$fileName');
            await file.writeAsBytes(output);
            savedPath = file.path;
          }
        }
      } catch (e) {
        // En cas d'erreur de permissions sur Android, on utilise le sélecteur natif
        try {
          savedPath = await FilePicker.saveFile(
            dialogTitle: 'Enregistrer le cours PDF',
            fileName: fileName,
            bytes: output,
          );
        } catch (_) {}
      }

      // Si l'écriture directe n'a pas fonctionné ou a été refusée, utiliser le sélecteur de fichier
      if (savedPath == null) {
        try {
          savedPath = await FilePicker.saveFile(
            dialogTitle: 'Enregistrer le cours PDF',
            fileName: fileName,
            bytes: output,
          );
        } catch (_) {}
      }

      // Dernier recours : dossier temporaire de l'application
      if (savedPath == null) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(output);
        savedPath = file.path;
      }
      return savedPath;
    }
  }

  /// Exporte la progression en image partageable
  static Future<void> shareProgressCard({
    required String matiereName,
    required double progressPercent,
    required int completedNotions,
    required int totalNotions,
    required int exercisesDone,
    required String successRate,
  }) async {
    final text =
        '''🎓 Ma progression sur Ngenou

📚 Cours: $matiereName
📊 Progression: ${progressPercent.toStringAsFixed(0)}%
✅ Chapitres complétés: $completedNotions/$totalNotions
📝 Exercices réalisés: $exercisesDone
🎯 Taux de réussite: $successRate%

Apprends, progresse, maîtrise avec Ngenou! 🚀''';

    await Share.share(text, subject: 'Ma progression - $matiereName');
  }

  static String _sanitizeString(String text) {
    String cleaned = text
        .replaceAll('’', "'")
        .replaceAll('‘', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('«', '"')
        .replaceAll('»', '"')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('œ', 'oe')
        .replaceAll('Œ', 'OE')
        .replaceAll('…', '...')
        .replaceAll('→', '->')
        .replaceAll('➔', '->')
        .replaceAll('⇒', '=>')
        .replaceAll('✓', 'v')
        .replaceAll('\u00a0', ' ')
        .replaceAll('\u202F', ' ');

    // Supprime tous les emojis et autres caractères non supportés par Helvetica
    // On conserve uniquement les caractères Latins de base, étendus et l'Euro
    cleaned = cleaned.replaceAll(RegExp(r'[^\u0000-\u024F\u20AC\n\r\t ]'), '');

    return cleaned;
  }

  /// Analyse le Markdown pour générer des widgets PDF avec gestion du gras, de l'italique et du code en ligne
  static List<pw.Widget> _parseMarkdownToWidgets(String content, pw.Font font, pw.Font fontBold) {
    final lines = content.split('\n');
    final widgets = <pw.Widget>[];

    for (var line in lines) {
      var trimmed = line.trim();
      if (trimmed.isEmpty) {
        widgets.add(pw.SizedBox(height: 8));
        continue;
      }

      // Gestion des titres (ex: ###, ##, #)
      if (trimmed.startsWith('#')) {
        final match = RegExp(r'^(#+)\s*(.*)$').firstMatch(trimmed);
        if (match != null) {
          final level = match.group(1)!.length;
          final title = _sanitizeString(match.group(2)!);
          
          double fontSize = 12;
          if (level == 1) {
            fontSize = 16;
          } else if (level == 2) fontSize = 14;
          else if (level == 3) fontSize = 12;

          widgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 12, bottom: 6),
              child: pw.Text(
                title,
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: fontSize,
                  color: PdfColor.fromHex('6C63FF'),
                ),
              ),
            ),
          );
          continue;
        }
      }

      // Gestion des listes à puces
      bool isBullet = false;
      if (trimmed.startsWith('-') || trimmed.startsWith('*') || trimmed.startsWith('•')) {
        isBullet = true;
        trimmed = trimmed.replaceFirst(RegExp(r'^[-*•]\s*'), '');
      }

      // Parseur inline : gras (**...**), italique (*...*), code en ligne (`...`) et texte normal
      final spans = <pw.TextSpan>[];
      final regex = RegExp(r'\*\*([^*]+)\*\*|\*([^*]+)\*|`([^`]+)`|([^`*]+)');
      final matches = regex.allMatches(trimmed);

      for (final match in matches) {
        if (match.group(1) != null) {
          // Gras
          spans.add(
            pw.TextSpan(
              text: _sanitizeString(match.group(1)!),
              style: pw.TextStyle(font: fontBold, fontWeight: pw.FontWeight.bold),
            ),
          );
        } else if (match.group(2) != null) {
          // Italique
          spans.add(
            pw.TextSpan(
              text: _sanitizeString(match.group(2)!),
              style: pw.TextStyle(font: pw.Font.helveticaOblique()),
            ),
          );
        } else if (match.group(3) != null) {
          // Code mono-espace
          spans.add(
            pw.TextSpan(
              text: _sanitizeString(match.group(3)!),
              style: pw.TextStyle(
                font: pw.Font.courier(),
                color: PdfColor.fromHex('C0392B'),
              ),
            ),
          );
        } else if (match.group(4) != null) {
          // Texte normal
          spans.add(
            pw.TextSpan(
              text: _sanitizeString(match.group(4)!),
            ),
          );
        }
      }

      if (isBullet) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 12, bottom: 4),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('- ', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                pw.Expanded(
                  child: pw.RichText(
                    text: pw.TextSpan(
                      children: spans,
                      style: pw.TextStyle(font: font, fontSize: 10.5, lineSpacing: 1.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.RichText(
              text: pw.TextSpan(
                children: spans,
                style: pw.TextStyle(font: font, fontSize: 10.5, lineSpacing: 1.4),
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  static int _countLeconsForNotion(List<Lecon> lecons, String notionId) {
    return lecons.where((l) => l.notionId == notionId).length;
  }

  static PdfColor _getContextColor(String? contexte) {
    final color = CourseContextMapper.getColorForContext(contexte);
    return PdfColor.fromInt(color.toARGB32());
  }
}
