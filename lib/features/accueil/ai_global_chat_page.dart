import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/ai_config.dart';
import '../../core/services/ai_tutor_history_service.dart';
import '../../core/services/ai_tutor_service.dart';
import '../../core/services/ocr_service.dart';
import '../../core/models/deep_seek_model.dart';
import '../../core/services/quota_guard.dart';
import '../../core/theme/app_colors.dart';
import '../../core/providers/projets_provider.dart';
import '../../core/providers/defis_provider.dart';
import '../../core/providers/custom_courses_provider.dart';
import '../../core/utils/course_context_mapper.dart';
import '../../modules/modules_registry.dart';
import 'package:go_router/go_router.dart';
import '../cours/widgets/ai_tutor_chat_sheet.dart';
import '../../core/utils/error_formatter.dart';
import '../../core/widgets/ai_markdown_text.dart';
import '../../core/widgets/speech_input_bar.dart';
import '../../core/widgets/tts_button.dart';
import '../../core/services/tts_service.dart';

/// Page entière dédiée à la discussion globale et l'historique avec Ngenou.
class AiGlobalChatPage extends StatefulWidget {
  const AiGlobalChatPage({super.key});

  @override
  State<AiGlobalChatPage> createState() => _AiGlobalChatPageState();
}

class _AiGlobalChatPageState extends State<AiGlobalChatPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<TutorMessage> _globalMessages = [];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _isLoading = false;
  bool _isInitLoadingGlobal = true;
  DeepSeekModel _selectedModel = DeepSeekModel.flash;

  /// True si le dernier message envoyé vient de la saisie vocale
  bool _lastInputWasVoice = false;

  /// Pièce jointe en cours de préparation / prête / en erreur
  _PendingAttachment? _pendingAttachment;

  /// Chemins locaux persistés des fichiers envoyés (timestampMs -> filePath)
  Map<String, String> _savedAttachmentPaths = {};
  static const _attachmentPathsPrefKey = 'chat_attachment_paths_v1';

  // Stocke tous les historiques chargés : key -> messages
  Map<String, List<TutorMessage>> _allHistories = {};
  bool _isLoadingHistories = true;

  static const _suggestions = [
    "Conseille-moi une méthode de révision",
    "Qu'est-ce qu'on apprend dans cette application ?",
    "Explique-moi les bases d'une notion au choix",
    "Donne-moi un quiz rapide",
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scroll.addListener(_onScrollChanged);
    _input.addListener(_onInputChanged);
    _loadGlobalChatHistory();
    _loadAllHistories();
  }

  void _jumpToBottom() {
    if (_scroll.hasClients) {
      _scroll.jumpTo(0.0);
    }
  }

  Future<void> _loadGlobalChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final rawMap = prefs.getString(_attachmentPathsPrefKey);
    if (rawMap != null && rawMap.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawMap) as Map<String, dynamic>;
        _savedAttachmentPaths =
            decoded.map((k, v) => MapEntry(k, v.toString()));
      } catch (_) {}
    }

    final loaded = await AiTutorHistoryService.loadHistory('global_chat');
    if (mounted) {
      setState(() {
        _globalMessages.clear();
        _globalMessages.addAll(loaded);
        _isInitLoadingGlobal = false;
      });
      // Deux frames pour laisser le ListView se construire avant de sauter en bas
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _jumpToBottom();
        });
      });
    }
  }

  Future<void> _loadAllHistories() async {
    setState(() => _isLoadingHistories = true);
    final histories = await AiTutorHistoryService.getAllHistories();
    // Filtrer pour ne pas mettre le chat global général dans la liste des leçons
    histories.remove('global_chat');
    if (mounted) {
      setState(() {
        _allHistories = histories;
        _isLoadingHistories = false;
      });
    }
  }

  // Variables pour stocker la réponse complète afin d'éviter les coupures à la fermeture
  String _currentFullReply = '';
  DateTime? _currentReplyTimestamp;
  Timer? _typewriterTimer;

  @override
  void dispose() {
    _tabController.dispose();
    _input.removeListener(_onInputChanged);
    _input.dispose();
    _scroll.removeListener(_onScrollChanged);
    if (_typewriterTimer != null && _typewriterTimer!.isActive) {
      _typewriterTimer!.cancel();
      // Sauvegarder immédiatement le message complet avant la destruction
      if (_globalMessages.isNotEmpty &&
          _globalMessages.last.role == 'assistant') {
        _globalMessages[_globalMessages.length - 1] = TutorMessage(
          role: 'assistant',
          content: _currentFullReply,
          timestamp: _currentReplyTimestamp ?? DateTime.now(),
        );
        AiTutorHistoryService.saveHistory('global_chat', _globalMessages);
      }
    }
    // Stopper la lecture TTS si la page est quittée
    TtsService.instance.stop();
    _scroll.dispose();
    super.dispose();
  }

  /// Prépare le contexte complet : projets, cours custom et notions de l'utilisateur.
  Future<LessonContext> _buildGlobalContext() async {
    // S'assurer que les cours custom sont bien chargés dans le registry
    final customProvider = Provider.of<CustomCoursesProvider>(
      context,
      listen: false,
    );
    if (!customProvider.isLoaded) {
      await customProvider.loadCustomCourses();
    }

    final matieres = ModulesRegistry.matieres;
    final projetsProvider = Provider.of<ProjetsProvider>(
      context,
      listen: false,
    );
    final projets = projetsProvider.projets.where((p) => !p.isSystem).toList();
    final allProjectMatiereIds = projets.expand((p) => p.matiereIds).toSet();

    final buf = StringBuffer();

    // ── 1. Projets de l'utilisateur ──────────────────────────────────────────
    if (projets.isNotEmpty) {
      buf.writeln('=== PROJETS DE L\'UTILISATEUR ===');
      for (final projet in projets) {
        buf.writeln('\nProjet : ${projet.nom}');
        if (projet.description != null && projet.description!.isNotEmpty) {
          buf.writeln('  Description : ${projet.description}');
        }
        if (projet.objectif != null && projet.objectif!.isNotEmpty) {
          buf.writeln('  Objectif : ${projet.objectif}');
        }
        if (projet.matiereIds.isEmpty) {
          buf.writeln('  (Aucun cours rattaché)');
        } else {
          buf.writeln('  Cours du projet :');
          for (final mId in projet.matiereIds) {
            final matiere = matieres.where((m) => m.id == mId).firstOrNull;
            if (matiere == null) continue;
            buf.writeln('  • ${matiere.nom}');
            final module = customProvider.modules
                .where((mod) => mod.matiere.id == mId)
                .firstOrNull;
            for (final n in ModulesRegistry.getNotions(mId)) {
              buf.writeln('      Notion : ${n.titre}');
              if (module != null) {
                final lecons = module.getLeconsByNotion(n.id);
                for (final l in lecons) {
                  buf.writeln('        Leçon : ${l.titre}');
                  final resume = l.contenu.length > 400
                      ? '${l.contenu.substring(0, 400)}…'
                      : l.contenu;
                  buf.writeln('        Contenu : $resume');
                }
              }
            }
          }
        }
      }
    }

    // ── 2. Cours hors projet (bibliothèque libre) ────────────────────────────
    final horsProjet = matieres
        .where(
          (m) =>
              ModulesRegistry.isCustomMatiere(m.id) &&
              !allProjectMatiereIds.contains(m.id),
        )
        .toList();
    if (horsProjet.isNotEmpty) {
      buf.writeln(
        '\n=== COURS CRÉÉS PAR L\'UTILISATEUR (BIBLIOTHÈQUE LIBRE) ===',
      );
      for (final m in horsProjet) {
        buf.writeln('\nCours : ${m.nom}');
        final module = customProvider.modules
            .where((mod) => mod.matiere.id == m.id)
            .firstOrNull;
        for (final n in ModulesRegistry.getNotions(m.id)) {
          buf.writeln('  Notion : ${n.titre}');
          // Inclure le contenu des leçons pour que l'IA puisse en parler
          if (module != null) {
            final lecons = module.getLeconsByNotion(n.id);
            for (final l in lecons) {
              buf.writeln('    Leçon : ${l.titre}');
              // Tronquer à 400 chars pour éviter de surcharger le contexte
              final resume = l.contenu.length > 400
                  ? '${l.contenu.substring(0, 400)}…'
                  : l.contenu;
              buf.writeln('    Contenu : $resume');
            }
          }
        }
      }
    }

    // ── 3. Cours intégrés à l'application ───────────────────────────────────
    final integres = matieres
        .where((m) => !ModulesRegistry.isCustomMatiere(m.id))
        .toList();
    if (integres.isNotEmpty) {
      buf.writeln('\n=== COURS INTÉGRÉS À L\'APPLICATION ===');
      for (final m in integres) {
        buf.writeln('\nMatière : ${m.nom}');
        for (final n in ModulesRegistry.getNotions(m.id)) {
          buf.writeln('  - ${n.titre}');
        }
      }
    }

    // ── 4. Défis quotidiens : stats pour le LLM ─────────────────────────────
    final defisProvider = Provider.of<DefisProvider>(context, listen: false);
    final defisSummary = defisProvider.statsSummary;
    buf.writeln('\n=== DÉFIS QUOTIDIENS (PERFORMANCE) ===');
    buf.writeln(defisSummary);

    return LessonContext(
      matiereNom: 'Tous les projets et cours',
      notionNom: 'Général',
      sectionTitre: 'Assistant Global Ngenou',
      sectionContenu:
          'Tu es Ngenou, un assistant pédagogique bienveillant intégré dans l\'application d\'apprentissage Ngenou.\n'
          'Tu parles à un apprenant depuis l\'écran d\'accueil.\n\n'
          'CONTEXTE DE L\'APPRENANT :\n'
          '---\n'
          '${buf.toString().trim()}\n'
          '---\n\n'
          'TON RÔLE :\n'
          '- Tu es avant tout un compagnon d\'apprentissage. Tu peux discuter librement avec l\'utilisateur.\n'
          '- Tu peux parler de n\'importe quel sujet éducatif : sciences, maths, histoire, langues, programmation, culture générale, etc.\n'
          '- Tu peux aussi apporter du soutien moral, de la motivation et de l\'encouragement quand l\'utilisateur en a besoin.\n'
          '- Si l\'utilisateur parle de ses difficultés scolaires ou personnelles liées à l\'apprentissage, écoute-le et aide-le.\n'
          '- Tu utilises les cours et projets ci-dessus comme contexte de référence, mais tu n\'es pas limité à ces seuls sujets.\n'
          '- Reste toujours dans le cadre éducatif et bienveillant — n\'aborde pas les sujets sans lien avec l\'apprentissage, le développement personnel ou les études.\n'
          '- Réponds dans la langue de l\'utilisateur. Sois chaleureux, encourageant et pédagogique.',
    );
  }

  /// Arrête la réponse en cours (typewriter + requête HTTP).
  /// Le dernier message partiel est conservé tel quel dans le chat.
  void _stop() {
    if (_typewriterTimer != null && _typewriterTimer!.isActive) {
      _typewriterTimer!.cancel();
      // Figer le message à sa position actuelle et sauvegarder
      if (_globalMessages.isNotEmpty &&
          _globalMessages.last.role == 'assistant') {
        final partial = _globalMessages.last.content;
        if (partial.isNotEmpty) {
          AiTutorHistoryService.saveHistory('global_chat', _globalMessages);
        }
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _send(String text) async {
    if (_isLoading) return;

    final att = _pendingAttachment;
    final rawQuestion = text.trim();
    if (rawQuestion.isEmpty && att == null) return;

    // Si une pièce jointe est encore en cours d'extraction en arrière-plan,
    // on attend la tâche déjà lancée sans relancer l'OCR.
    if (att != null && att.status == _AttachmentStatus.extracting) {
      setState(() => _isLoading = true);
      if (att.inFlightTask != null) {
        await att.inFlightTask;
      }
      if (!mounted) return;
    }

    final currentAtt = _pendingAttachment;
    if (currentAtt != null && currentAtt.status == _AttachmentStatus.error) {
      setState(() => _isLoading = false);
      _showAttachmentErrorSnack(
        currentAtt.errorMessage ??
            'Impossible d\'envoyer cette pièce jointe. Veuillez la retirer.',
      );
      return;
    }

    String displayContent = rawQuestion;
    String? attachmentPayload;
    TutorAttachmentPreview? attachmentPreview;

    if (currentAtt != null &&
        currentAtt.status == _AttachmentStatus.ready &&
        currentAtt.extractedText != null) {
      final effectiveQuestion = rawQuestion.isNotEmpty
          ? rawQuestion
          : 'Analyse ce document et explique-moi les points essentiels.';
      final metaParts = <String>[
        if (currentAtt.pageCount != null)
          '${currentAtt.pageCount} page${currentAtt.pageCount! > 1 ? 's' : ''}',
        if (currentAtt.kind == _AttachmentKind.text && currentAtt.lineCount > 0)
          '${currentAtt.lineCount} ligne${currentAtt.lineCount > 1 ? 's' : ''}'
        else
          '${currentAtt.wordCount} mot${currentAtt.wordCount > 1 ? 's' : ''}',
      ];
      final metaLabel = metaParts.join(' · ');
      displayContent =
          '[Pièce jointe : ${currentAtt.fileName} ($metaLabel)]\n$effectiveQuestion';
      final prepared = OcrService.prepareForPrompt(currentAtt.extractedText!);
      attachmentPayload =
          '--- DOCUMENT JOINT (${currentAtt.fileName}) ---\n'
          '$prepared\n'
          '--- FIN DU DOCUMENT JOINT ---';
      attachmentPreview = TutorAttachmentPreview(
        fileName: currentAtt.fileName,
        extensionLabel: currentAtt.extensionLabel,
        metaLabel: metaLabel,
        isImage: currentAtt.kind == _AttachmentKind.image,
        filePath: currentAtt.filePath,
        extractedText: currentAtt.extractedText,
      );
    }

    if (displayContent.trim().isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    final msgTimestamp = DateTime.now();
    String? persistedFilePath;
    if (currentAtt != null && currentAtt.status == _AttachmentStatus.ready) {
      persistedFilePath = await _persistLocalAttachmentCopy(
        currentAtt.filePath,
        currentAtt.fileName,
        msgTimestamp,
      );
      if (attachmentPreview != null && persistedFilePath != null) {
        attachmentPreview = TutorAttachmentPreview(
          fileName: attachmentPreview.fileName,
          extensionLabel: attachmentPreview.extensionLabel,
          metaLabel: attachmentPreview.metaLabel,
          isImage: attachmentPreview.isImage,
          filePath: persistedFilePath,
          extractedText: attachmentPreview.extractedText,
        );
      }
    }

    _input.clear();
    FocusScope.of(context).unfocus();

    final userMsg = TutorMessage(
      role: 'user',
      content: displayContent,
      timestamp: msgTimestamp,
      attachmentPayload: attachmentPayload,
      attachmentPreview: attachmentPreview,
    );

    setState(() {
      _pendingAttachment = null;
      _globalMessages.add(userMsg);
      _isLoading = true;
    });
    _scrollToBottom(force: true);
    await AiTutorHistoryService.saveHistory('global_chat', _globalMessages);

    try {
      final tutorResponse = await AiTutorService.ask(
        context: await _buildGlobalContext(),
        history: _globalMessages,
        model: _selectedModel,
      );
      if (mounted) {
        setState(() => _isLoading = false);
        // Fallback Pro → Flash : snackbar informatif + l'appel a quand même eu lieu
        if (tutorResponse.fallbackMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tutorResponse.fallbackMessage!),
              duration: const Duration(seconds: 4),
              backgroundColor: const Color(0xFF3498DB),
            ),
          );
        }
        await _animateResponse(tutorResponse.content);
        // Lecture auto si la saisie était vocale
        if (_lastInputWasVoice && mounted) {
          _lastInputWasVoice = false;
          final lastMsg = _globalMessages.lastWhere(
            (m) => m.role == 'assistant',
            orElse: () =>
                TutorMessage(role: '', content: '', timestamp: DateTime.now()),
          );
          if (lastMsg.content.isNotEmpty) {
            TtsService.instance.speak(
              lastMsg.content,
              msgId: lastMsg.timestamp.millisecondsSinceEpoch.toString(),
            );
          }
        }
      }
    } on QuotaExceededException catch (e) {
      // ── Quota bloqué (limite = 0) ────────────────────────────────────
      // Afficher le message DANS le chat comme réponse éphémère de l'IA.
      // Ne PAS sauvegarder en base (pas d'appel saveHistory ici).
      if (mounted) {
        setState(() {
          // Retirer le message utilisateur de la liste — on ne sauvegarde pas
          // cette interaction qui n'a jamais abouti côté API.
          if (_globalMessages.isNotEmpty &&
              _globalMessages.last.role == 'user') {
            _globalMessages.removeLast();
          }
          // Ajouter la réponse quota éphémère (non persistée)
          _globalMessages.add(
            TutorMessage(
              role: 'assistant',
              content: e.message,
              timestamp: DateTime.now(),
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom(force: true);
        // NE PAS appeler saveHistory → message éphémère
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = formatUserError(e);
        // Log temporaire pour debug — à retirer après diagnostic
        debugPrint('=== ERREUR IA BRUTE : $e ===');
        debugPrint('=== TYPE : ${e.runtimeType} ===');
        setState(() {
          _globalMessages.add(
            TutorMessage(
              role: 'assistant',
              content: '⚠️ $errorMsg',
              timestamp: DateTime.now(),
            ),
          );
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _animateResponse(String reply) async {
    final timestamp = DateTime.now();
    _currentFullReply = reply;
    _currentReplyTimestamp = timestamp;
    int charIndex = 0;
    const charsPerTick = 4;
    // Capture une référence locale à la liste pour accès après dispose()
    final messages = _globalMessages;

    setState(() {
      messages.add(
        TutorMessage(role: 'assistant', content: '', timestamp: timestamp),
      );
    });

    final completer = Completer<void>();
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 20), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        if (messages.isNotEmpty && messages.last.role == 'assistant') {
          final idx = messages.length - 1;
          messages[idx] = TutorMessage(
            role: 'assistant',
            content: reply,
            timestamp: timestamp,
          );
          AiTutorHistoryService.saveHistory('global_chat', messages);
        }
        if (!completer.isCompleted) completer.complete();
        return;
      }
      if (charIndex >= reply.length) {
        timer.cancel();
        setState(() {
          messages[messages.length - 1] = TutorMessage(
            role: 'assistant',
            content: reply,
            timestamp: timestamp,
          );
        });
        AiTutorHistoryService.saveHistory('global_chat', messages);
        if (!completer.isCompleted) completer.complete();
        return;
      }
      charIndex = (charIndex + charsPerTick).clamp(0, reply.length);
      setState(() {
        messages[messages.length - 1] = TutorMessage(
          role: 'assistant',
          content: reply.substring(0, charIndex),
          timestamp: timestamp,
        );
      });
      _scrollToBottomFast();
    });

    return completer.future;
  }

  // ── Gestion du scroll ───────────────────────────────────────────────────
  // Liste inversée : 0.0 = bas (dernier message visible)

  bool _showScrollDown = false;
  bool _isLongInput = false;
  bool _userIsScrolling = false;

  bool _isNearBottom() {
    if (!_scroll.hasClients) return true;
    return _scroll.position.pixels <= 60;
  }

  void _onScrollChanged() {
    final nearBottom = _isNearBottom();
    final shouldShow = !nearBottom;
    if (shouldShow != _showScrollDown) {
      setState(() => _showScrollDown = shouldShow);
    }
    // Réactiver l'auto-scroll dès retour au bas
    if (nearBottom) _userIsScrolling = false;
  }

  void _scrollToBottomFast() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.userScrollDirection != ScrollDirection.idle) {
      _userIsScrolling = true;
      return;
    }
    if (_userIsScrolling) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_userIsScrolling && _scroll.hasClients) {
        _scroll.jumpTo(0.0);
      }
    });
  }

  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      if (force || !_userIsScrolling) {
        if (force) _userIsScrolling = false;
        _scroll.jumpTo(0.0);
      }
    });
  }

  Future<String?> _persistLocalAttachmentCopy(
    String sourcePath,
    String fileName,
    DateTime timestamp,
  ) async {
    try {
      final src = File(sourcePath);
      if (!await src.exists()) return sourcePath;
      final supportDir = await getApplicationSupportDirectory();
      final attDir = Directory('${supportDir.path}${Platform.pathSeparator}chat_attachments');
      if (!await attDir.exists()) {
        await attDir.create(recursive: true);
      }
      final tsKey = timestamp.millisecondsSinceEpoch.toString();
      final safeName = fileName.replaceAll(RegExp(r'[^\w.\- ]'), '_');
      final destPath = '${attDir.path}${Platform.pathSeparator}${tsKey}_$safeName';
      await src.copy(destPath);

      _savedAttachmentPaths[tsKey] = destPath;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _attachmentPathsPrefKey,
        jsonEncode(_savedAttachmentPaths),
      );
      return destPath;
    } catch (_) {
      return sourcePath;
    }
  }

  void _showAttachmentErrorSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 5),
        content: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageAttachment({ImageSource? mobileSource}) async {
    try {
      File? pickedFile;
      if ((Platform.isAndroid || Platform.isIOS) && mobileSource != null) {
        final picked = await ImagePicker().pickImage(
          source: mobileSource,
          imageQuality: 88,
          maxWidth: 1800,
          maxHeight: 1800,
        );
        if (picked != null) pickedFile = File(picked.path);
      } else {
        final result = await FilePicker.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );
        if (result != null && result.files.single.path != null) {
          pickedFile = File(result.files.single.path!);
        }
      }
      if (pickedFile == null || !mounted) return;
      _startBackgroundExtraction(pickedFile, isImage: true);
    } catch (e) {
      _showAttachmentErrorSnack(
        'Impossible de sélectionner cette image : ${formatUserError(e)}',
      );
    }
  }

  Future<void> _pickDocumentAttachment() async {
    try {
      // On laisse l'utilisateur sélectionner librement puis on valide au retour
      // dans l'application (ex: limite à 5 pages pour les PDF, formats valides).
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result == null || result.files.single.path == null || !mounted) {
        return;
      }
      final file = File(result.files.single.path!);
      _startBackgroundExtraction(file, isImage: false);
    } catch (e) {
      _showAttachmentErrorSnack(
        'Impossible de sélectionner ce fichier : ${formatUserError(e)}',
      );
    }
  }

  void _startBackgroundExtraction(File file, {required bool isImage}) {
    final fileName = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : file.path;
    final lowerName = fileName.toLowerCase();
    final dotIdx = lowerName.lastIndexOf('.');
    final ext = (dotIdx >= 0 && dotIdx < lowerName.length - 1)
        ? lowerName.substring(dotIdx + 1)
        : '';

    final kind = (isImage || OcrService.imageExtensions.contains(ext))
        ? _AttachmentKind.image
        : (ext == 'pdf' ? _AttachmentKind.pdf : _AttachmentKind.text);

    final extLabel = ext.isNotEmpty
        ? ext.toUpperCase()
        : (kind == _AttachmentKind.image ? 'IMG' : 'TXT');

    final pending = _PendingAttachment(
      fileName: fileName,
      filePath: file.path,
      extensionLabel: extLabel,
      kind: kind,
      status: _AttachmentStatus.extracting,
    );

    final task = () async {
      try {
        final result = isImage
            ? OcrExtractionResult(
                text: await OcrService.extractTextFromImage(file),
              )
            : await OcrService.extractFromAnyFile(
                file,
                maxPdfPages: AiConfig.maxPdfPages,
              );

        if (!mounted || _pendingAttachment != pending) return;
        setState(() {
          pending.extractedText = result.text;
          pending.pageCount = result.pageCount;
          pending.wordCount = OcrService.countWords(result.text);
          pending.lineCount = OcrService.countLines(result.text);
          pending.wasTruncated =
              result.text.length > AiConfig.maxAttachmentChars;
          pending.status = _AttachmentStatus.ready;
        });
      } catch (e) {
        if (!mounted || _pendingAttachment != pending) return;
        final rawMsg = e.toString();
        final cleanMsg = rawMsg.startsWith('Exception: ')
            ? rawMsg.substring('Exception: '.length)
            : rawMsg;
        setState(() {
          pending.errorMessage = cleanMsg;
          pending.status = _AttachmentStatus.error;
        });
        _showAttachmentErrorSnack(cleanMsg);
      }
    }();

    pending.inFlightTask = task;
    setState(() => _pendingAttachment = pending);
  }

  void _showAttachmentOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = Platform.isAndroid || Platform.isIOS;
    final primary = Theme.of(context).primaryColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            if (isMobile) ...[
              ListTile(
                leading: Icon(Icons.photo_camera_rounded, color: primary),
                title: const Text('Prendre une photo'),
                subtitle: const Text('Photo de cours ou exercice (OCR auto)'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageAttachment(mobileSource: ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.image_rounded, color: primary),
                title: const Text('Photo depuis la galerie'),
                subtitle: const Text('Extraction du texte en arrière-plan'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageAttachment(mobileSource: ImageSource.gallery);
                },
              ),
            ] else
              ListTile(
                leading: Icon(Icons.image_rounded, color: primary),
                title: const Text('Photo / Image de cours'),
                subtitle: const Text('Extraction locale du texte en arrière-plan'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageAttachment();
                },
              ),
            ListTile(
              leading: Icon(Icons.attach_file_rounded, color: primary),
              title: const Text('Fichier (PDF, texte, code)'),
              subtitle: const Text(
                'PDF limité à ${AiConfig.maxPdfPages} pages max · .txt, .algo, .py…',
              ),
              onTap: () {
                Navigator.pop(context);
                _pickDocumentAttachment();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _onInputChanged() {
    final isLong = _input.text.length > 80;
    if (isLong != _isLongInput) {
      setState(() => _isLongInput = isLong);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    final bg = isDark ? const Color(0xFF0D121F) : const Color(0xFFF8FAFC);
    final headerBg = isDark ? const Color(0xFF131929) : Colors.white;
    final inputBg = isDark ? const Color(0xFF161D2D) : const Color(0xFFF1F5F9);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: headerBg,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: primary.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.15),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/launcher_icon.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -1,
                  right: -1,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2DD4BF),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: headerBg,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ngenou',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  'Tuteur IA • En ligne',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          _buildModelSelectorButton(isDark, primary),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: primary,
          unselectedLabelColor: isDark ? Colors.grey[500] : Colors.grey[600],
          indicatorColor: primary,
          indicatorWeight: 2.5,
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
          onTap: (index) {
            if (index == 1) {
              _loadAllHistories();
            }
          },
          tabs: const [
            Tab(text: "Discuter"),
            Tab(text: "Historiques"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Onglet 1 : Discussion globale
          _buildGlobalChatTab(isDark, primary, inputBg),
          // Onglet 2 : Historiques des leçons
          _buildHistoriesTab(isDark, primary),
        ],
      ),
    );
  }

  // ── Sélecteur de modèle (AppBar) ────────────────────────────────────────

  Widget _buildModelSelectorButton(bool isDark, Color primary) {
    final isPro = _selectedModel == DeepSeekModel.pro;
    return GestureDetector(
      onTap: () => _showModelPicker(isDark, primary),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: isPro
              ? const Color(0xFF6C3FE8).withValues(alpha: 0.16)
              : (isDark
                    ? const Color(0xFF1E2638)
                    : const Color(0xFFEDF2F7)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPro
                ? const Color(0xFF8B5CF6).withValues(alpha: 0.5)
                : (isDark ? const Color(0xFF2E3A52) : const Color(0xFFCBD5E1)),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPro ? Icons.auto_awesome_rounded : Icons.bolt_rounded,
              size: 14,
              color: isPro
                  ? const Color(0xFF8B5CF6)
                  : (isDark ? Colors.grey[300] : Colors.grey[700]),
            ),
            const SizedBox(width: 4),
            Text(
              _selectedModel.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isPro
                    ? const Color(0xFF8B5CF6)
                    : (isDark ? Colors.grey[300] : Colors.grey[700]),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.expand_more_rounded,
              size: 14,
              color: isPro
                  ? const Color(0xFF8B5CF6)
                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  void _showModelPicker(bool isDark, Color primary) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChatModelPickerSheet(
        currentModel: _selectedModel,
        isDark: isDark,
        onSelected: (m) => setState(() => _selectedModel = m),
      ),
    );
  }

  Widget _buildGlobalChatTab(bool isDark, Color primary, Color inputBg) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              _isInitLoadingGlobal
                  ? const Center(child: CircularProgressIndicator())
                  : _globalMessages.isEmpty
                  ? _buildWelcome(isDark, primary)
                  : NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification is UserScrollNotification) {
                          // L'utilisateur scrolle manuellement → suspend l'auto-scroll
                          _userIsScrolling = true;
                        } else if (notification is ScrollEndNotification) {
                          // Fin du scroll — si on est au bas, réactiver l'auto-scroll
                          if (_isNearBottom()) {
                            _userIsScrolling = false;
                          }
                        }
                        return false;
                      },
                      child: ListView.builder(
                        controller: _scroll,
                        reverse: true,
                        padding: const EdgeInsets.only(top: 8, bottom: 16),
                        itemCount:
                            _globalMessages.length + (_isLoading ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (_isLoading && i == 0) {
                            return _buildTypingIndicator(isDark, primary);
                          }
                          final msgIndex = _isLoading
                              ? _globalMessages.length - i
                              : _globalMessages.length - 1 - i;
                          return _buildLLMMessageRow(
                            _globalMessages[msgIndex],
                            isDark,
                            primary,
                          );
                        },
                      ),
                    ),
              // Bouton "descendre"
              if (_showScrollDown)
                Positioned(
                  bottom: 12,
                  right: 16,
                  child: AnimatedOpacity(
                    opacity: _showScrollDown ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Material(
                      key: const ValueKey('scroll_down_btn'),
                      color: Colors.transparent,
                      type: MaterialType.transparency,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          setState(() {
                            _userIsScrolling = false;
                            _showScrollDown = false;
                          });
                          _scrollToBottom(force: true);
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF2A2A2A)
                                : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? Colors.grey[700]!
                                  : Colors.grey[300]!,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Champ de saisie + aperçu pièce jointe
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131929) : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_pendingAttachment != null)
                _buildAttachmentBanner(isDark, primary),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Bouton pièce jointe
                  GestureDetector(
                    onTap: _isLoading ? null : _showAttachmentOptions,
                    child: Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(bottom: 4, right: 8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E2638)
                            : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF2B374E)
                              : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                        size: 22,
                      ),
                    ),
                  ),
                  // Barre de saisie avec STT
                  Expanded(
                    child: SpeechInputBar(
                      controller: _input,
                      isDark: isDark,
                      primary: primary,
                      isLoading: _isLoading,
                      onSend: _send,
                      onSendVoice: (text) {
                        _lastInputWasVoice = true;
                        _send(text);
                      },
                      onStop: _stop,
                      hintText: _pendingAttachment != null
                          ? 'Pose ta question sur ce document…'
                          : 'Demande quelque chose à Ngenou…',
                      maxLines: null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoriesTab(bool isDark, Color primary) {
    if (_isLoadingHistories) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_allHistories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 64,
                color: isDark ? Colors.grey[700] : Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                'Aucune conversation trouvée',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Commence à discuter avec Ngenou à l\'intérieur d\'une leçon pour voir l\'historique apparaître ici.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      itemCount: _allHistories.length,
      itemBuilder: (context, i) {
        final key = _allHistories.keys.elementAt(i);
        final messages = _allHistories[key]!;

        // Retrouver la matière et la notion de façon robuste
        String mId = "";
        String nId = "";
        for (final m in ModulesRegistry.matieres) {
          if (key.startsWith('${m.id}_')) {
            mId = m.id;
            nId = key.substring(m.id.length + 1);
            break;
          }
        }
        if (mId.isEmpty) {
          final idx = key.lastIndexOf('_');
          if (idx != -1) {
            mId = key.substring(0, idx);
            nId = key.substring(idx + 1);
          }
        }

        String matiereNom = "Matière";
        String notionTitre = "Leçon";
        IconData lessonIcon = Icons.class_rounded;
        Color lessonColor = primary;

        if (mId.isNotEmpty) {
          final matiere = ModulesRegistry.matieres
              .where((m) => m.id == mId)
              .firstOrNull;
          final notions = ModulesRegistry.getNotions(mId);
          final notion = notions.where((n) => n.id == nId).firstOrNull;

          if (matiere != null) {
            matiereNom = matiere.nom;
            lessonIcon = matiere.icone;
            lessonColor = matiere.couleur;
          }
          if (notion != null) {
            notionTitre = notion.titre;
            if (notion.contexte != null && notion.contexte!.isNotEmpty) {
              lessonIcon = CourseContextMapper.getIconForContext(
                notion.contexte,
              );
              lessonColor = CourseContextMapper.getColorForContext(
                notion.contexte,
              );
            }
          }
        }

        final lastMessage = messages.isNotEmpty
            ? messages.last.content
            : "Aucun message";

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              if (mId.isNotEmpty && nId.isNotEmpty) {
                context.push('/cours/$mId/$nId?openChat=true');
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: lessonColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(lessonIcon, color: lessonColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          matiereNom,
                          style: TextStyle(
                            fontSize: 11,
                            color: primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          notionTitre,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lastMessage,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _confirmDelete(key, notionTitre),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red.shade400,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(String key, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'historique ?'),
        content: Text(
          'Es-tu sûr de vouloir supprimer définitivement la discussion associée à "$title" ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await AiTutorHistoryService.deleteHistory(key);
              Navigator.pop(context);
              _loadAllHistories();
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  IconData _getSuggestionIcon(String text) {
    if (text.contains('révision') || text.contains('méthode')) {
      return Icons.lightbulb_outline_rounded;
    }
    if (text.contains('quiz')) return Icons.quiz_outlined;
    if (text.contains('notion') || text.contains('Explique')) {
      return Icons.menu_book_rounded;
    }
    return Icons.explore_outlined;
  }

  Widget _buildWelcome(bool isDark, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Avatar central avec double halo
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary.withValues(alpha: 0.08),
                ),
              ),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: primary.withValues(alpha: 0.35),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/launcher_icon.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Comment puis-je t\'aider ?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 21,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Je connais toutes les matières et notions de ton programme. Pose-moi une question ou demande-moi de t\'expliquer un cours pas à pas.',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 15,
                  color: primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Suggestions rapides',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: _suggestions
                .map((s) => _buildSuggestionChip(s, primary, isDark))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text, Color primary, bool isDark) {
    final icon = _getSuggestionIcon(text);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _send(text),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161D2D) : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isDark ? const Color(0xFF26334A) : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: primary),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[200] : const Color(0xFF1E293B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLLMMessageRow(TutorMessage msg, bool isDark, Color primary) {
    final isUser = msg.role == 'user';
    final msgIndex = _globalMessages.indexOf(msg);

    // ── MESSAGE DE L'UTILISATEUR ──────────────────────────────────────
    if (isUser) {
      final parsed = _extractAttachmentFromMessage(msg);
      final preview = parsed.preview;
      final cleanText = parsed.bodyText;

      return GestureDetector(
        onLongPress: () =>
            _showUserMessageOptions(context, msg, msgIndex, isDark, primary),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (preview != null) ...[
                      _buildSentAttachmentPreview(preview, isDark, primary),
                      const SizedBox(height: 6),
                    ],
                    if (cleanText.isNotEmpty)
                      Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.82,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primary,
                              Color.lerp(primary, const Color(0xFF0F1A33), 0.18) ??
                                  primary,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(18),
                            topRight: Radius.circular(18),
                            bottomLeft: Radius.circular(18),
                            bottomRight: Radius.circular(4),
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primary.withValues(alpha: 0.22),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              cleanText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                height: 1.45,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(msg.timestamp),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white.withValues(alpha: 0.65),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── MESSAGE DE NGENOU (CARTE PRO ET ÉLÉGANTE) ────────────────────
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161D2D) : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(
            color: isDark ? const Color(0xFF243048) : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête : Avatar Ngenou + Nom + Badge Tuteur IA + Heure
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: primary.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.18),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/launcher_icon.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Ngenou',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Tuteur IA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTime(msg.timestamp),
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AiMarkdownText(
              text: msg.content,
              selectable: true,
              style: TextStyle(
                color: isDark
                    ? const Color(0xFFE2E8F0)
                    : const Color(0xFF1E293B),
                fontSize: 14.5,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 10),
            // Barre d'actions discrète et pro
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TtsButton(
                  msgId: msg.timestamp.millisecondsSinceEpoch.toString(),
                  text: msg.content,
                  isDark: isDark,
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Copier',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      _copyToClipboard(msg.content);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Réponse copiée'),
                          duration: Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.copy_rounded,
                        size: 16,
                        color: isDark ? Colors.grey[500] : Colors.grey[400],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
  }

  void _showUserMessageOptions(
    BuildContext ctx,
    TutorMessage msg,
    int index,
    bool isDark,
    Color primary,
  ) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.edit_rounded, color: primary),
              title: const Text('Modifier et renvoyer'),
              onTap: () {
                Navigator.pop(ctx);
                _editAndResend(msg, index);
              },
            ),
            ListTile(
              leading: Icon(Icons.copy_rounded, color: primary),
              title: const Text('Copier'),
              onTap: () {
                Navigator.pop(ctx);
                _copyToClipboard(msg.content);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _editAndResend(TutorMessage msg, int index) {
    final controller = TextEditingController(text: msg.content);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier le message'),
        content: TextField(
          controller: controller,
          maxLines: null,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              final newText = controller.text.trim();
              if (newText.isEmpty) return;
              // Supprimer ce message et tout ce qui suit
              setState(() {
                _globalMessages.removeRange(index, _globalMessages.length);
              });
              _send(newText);
            },
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }

  /// Carte d'aperçu presque carrée affichée au-dessus de la barre de saisie.
  Widget _buildAttachmentBanner(bool isDark, Color primary) {
    final att = _pendingAttachment!;
    final isDesktop = MediaQuery.of(context).size.width >= 700;
    final cardWidth = isDesktop ? 144.0 : 128.0;
    final cardHeight = isDesktop ? 150.0 : 134.0;

    final cardBg = isDark ? const Color(0xFF1A2235) : const Color(0xFFF8FAFC);
    final borderColor = att.status == _AttachmentStatus.error
        ? AppColors.error.withValues(alpha: 0.7)
        : (isDark ? const Color(0xFF2B3D5C) : const Color(0xFFE2E8F0));

    String subtitleText;
    Color subtitleColor;
    switch (att.status) {
      case _AttachmentStatus.extracting:
        subtitleText = 'Extraction…';
        subtitleColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
        break;
      case _AttachmentStatus.ready:
        if (att.pageCount != null) {
          subtitleText = '${att.pageCount} p.';
        } else if (att.kind == _AttachmentKind.text && att.lineCount > 0) {
          subtitleText = '${att.lineCount} l.';
        } else {
          subtitleText = '${att.wordCount} mots';
        }
        subtitleColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
        break;
      case _AttachmentStatus.error:
        subtitleText = 'Erreur';
        subtitleColor = AppColors.error;
        break;
    }

    final hasImageFile =
        att.kind == _AttachmentKind.image && File(att.filePath).existsSync();
    final isPdf = att.kind == _AttachmentKind.pdf;

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 2),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: att.status == _AttachmentStatus.ready
                  ? () => _showAttachmentPreviewDialog(
                        TutorAttachmentPreview(
                          fileName: att.fileName,
                          extensionLabel: att.extensionLabel,
                          metaLabel: subtitleText,
                          isImage: att.kind == _AttachmentKind.image,
                          filePath: att.filePath,
                          extractedText: att.extractedText,
                        ),
                        isDark,
                        primary,
                      )
                  : null,
              child: Container(
                width: cardWidth,
                height: cardHeight,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: hasImageFile
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            File(att.filePath),
                            fit: BoxFit.cover,
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.72),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 8,
                            right: 8,
                            bottom: 8,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    att.fileName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                if (att.status == _AttachmentStatus.extracting)
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.8,
                                      color: Colors.white,
                                    ),
                                  )
                                else if (att.status == _AttachmentStatus.ready)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    size: 14,
                                    color: Color(0xFF4ADE80),
                                  )
                                else
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    size: 14,
                                    color: Color(0xFFFCA5A5),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Badge statut en haut à gauche
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isPdf
                                        ? const Color(0xFFE53935)
                                            .withValues(alpha: 0.14)
                                        : primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    att.extensionLabel,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: isPdf
                                          ? const Color(0xFFE53935)
                                          : primary,
                                    ),
                                  ),
                                ),
                                switch (att.status) {
                                  _AttachmentStatus.extracting => SizedBox(
                                      width: 13,
                                      height: 13,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.8,
                                        color: primary,
                                      ),
                                    ),
                                  _AttachmentStatus.ready => const Icon(
                                      Icons.check_circle_rounded,
                                      size: 15,
                                      color: Color(0xFF22C55E),
                                    ),
                                  _AttachmentStatus.error => const Icon(
                                      Icons.error_outline_rounded,
                                      size: 15,
                                      color: AppColors.error,
                                    ),
                                },
                              ],
                            ),
                            // Icône centrale (PDF en rouge au milieu)
                            Container(
                              width: isDesktop ? 52 : 46,
                              height: isDesktop ? 52 : 46,
                              decoration: BoxDecoration(
                                color: isPdf
                                    ? const Color(0xFFE53935)
                                        .withValues(alpha: 0.12)
                                    : primary.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                isPdf
                                    ? Icons.picture_as_pdf_rounded
                                    : Icons.description_rounded,
                                size: isDesktop ? 30 : 26,
                                color: isPdf
                                    ? const Color(0xFFE53935)
                                    : primary,
                              ),
                            ),
                            // Nom + méta en bas
                            Column(
                              children: [
                                Text(
                                  att.fileName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? const Color(0xFFF1F5F9)
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subtitleText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: subtitleColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            // Bouton circulaire × flottant en haut à droite
            Positioned(
              top: -7,
              right: -7,
              child: GestureDetector(
                onTap: () => setState(() => _pendingAttachment = null),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2B374E) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF3E4E6E)
                          : const Color(0xFFCBD5E1),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 13,
                    color: isDark ? Colors.grey[200] : const Color(0xFF475569),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Extrait l'aperçu de pièce jointe et le texte propre d'un message utilisateur.
  ({TutorAttachmentPreview? preview, String bodyText})
      _extractAttachmentFromMessage(TutorMessage msg) {
    final regex = RegExp(r'^\[Pièce jointe : (.+?) \(([^)]+)\)\]\n?');
    final match = regex.firstMatch(msg.content);
    final tsKey = msg.timestamp.millisecondsSinceEpoch.toString();
    final persistedPath = _savedAttachmentPaths[tsKey];

    if (msg.attachmentPreview != null) {
      final cleanBody = match != null
          ? msg.content.substring(match.end).trim()
          : msg.content.trim();
      final p = msg.attachmentPreview!;
      if (p.filePath == null && persistedPath != null) {
        return (
          preview: TutorAttachmentPreview(
            fileName: p.fileName,
            extensionLabel: p.extensionLabel,
            metaLabel: p.metaLabel,
            isImage: p.isImage,
            filePath: persistedPath,
            extractedText: p.extractedText,
          ),
          bodyText: cleanBody,
        );
      }
      return (preview: p, bodyText: cleanBody);
    }

    if (match != null) {
      final fileName = match.group(1) ?? 'Document';
      final metaLabel = match.group(2) ?? '';
      final dotIdx = fileName.lastIndexOf('.');
      final ext = (dotIdx >= 0 && dotIdx < fileName.length - 1)
          ? fileName.substring(dotIdx + 1).toLowerCase()
          : '';
      final isImg = OcrService.imageExtensions.contains(ext);
      final cleanBody = msg.content.substring(match.end).trim();
      return (
        preview: TutorAttachmentPreview(
          fileName: fileName,
          extensionLabel: ext.isNotEmpty ? ext.toUpperCase() : 'FILE',
          metaLabel: metaLabel,
          isImage: isImg,
          filePath: persistedPath,
        ),
        bodyText: cleanBody,
      );
    }

    return (preview: null, bodyText: msg.content);
  }

  /// Carte d'aperçu presque carrée et cliquable sur le message envoyé.
  Widget _buildSentAttachmentPreview(
    TutorAttachmentPreview preview,
    bool isDark,
    Color primary,
  ) {
    final isDesktop = MediaQuery.of(context).size.width >= 700;
    final cardWidth = isDesktop ? 148.0 : 132.0;
    final cardHeight = isDesktop ? 154.0 : 138.0;
    final hasImageFile = preview.isImage &&
        preview.filePath != null &&
        File(preview.filePath!).existsSync();
    final isPdf = preview.extensionLabel.toUpperCase() == 'PDF';

    if (hasImageFile) {
      return GestureDetector(
        onTap: () => _showAttachmentPreviewDialog(preview, isDark, primary),
        child: Container(
          width: cardWidth,
          height: cardHeight,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF2B3D5C) : const Color(0xFFCBD5E1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(File(preview.filePath!), fit: BoxFit.cover),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.78),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          preview.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.open_in_full_rounded,
                        size: 12,
                        color: Colors.white70,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final cardBg = isDark ? const Color(0xFF1A2235) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF2B3D5C) : const Color(0xFFE2E8F0);

    return GestureDetector(
      onTap: () => _showAttachmentPreviewDialog(preview, isDark, primary),
      child: Container(
        width: cardWidth,
        height: cardHeight,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isPdf
                        ? const Color(0xFFE53935).withValues(alpha: 0.14)
                        : primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    preview.extensionLabel,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: isPdf ? const Color(0xFFE53935) : primary,
                    ),
                  ),
                ),
                Icon(
                  Icons.open_in_new_rounded,
                  size: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[500],
                ),
              ],
            ),
            // Icône centrale : PDF rouge au milieu ou icône image/fichier
            Container(
              width: isDesktop ? 54 : 48,
              height: isDesktop ? 54 : 48,
              decoration: BoxDecoration(
                color: isPdf
                    ? const Color(0xFFE53935).withValues(alpha: 0.12)
                    : primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isPdf
                    ? Icons.picture_as_pdf_rounded
                    : (preview.isImage
                        ? Icons.image_rounded
                        : Icons.description_rounded),
                size: isDesktop ? 32 : 28,
                color: isPdf ? const Color(0xFFE53935) : primary,
              ),
            ),
            Column(
              children: [
                Text(
                  preview.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFFF1F5F9)
                        : const Color(0xFF0F172A),
                  ),
                ),
                if (preview.metaLabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    preview.metaLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Affiche directement le FICHIER BRUT lors d'un clic sur la pièce jointe.
  Future<void> _showAttachmentPreviewDialog(
    TutorAttachmentPreview preview,
    bool isDark,
    Color primary,
  ) async {
    final filePath = preview.filePath;
    final fileExists = filePath != null && File(filePath).existsSync();
    final isPdf = preview.extensionLabel.toUpperCase() == 'PDF';
    final isDesktop = MediaQuery.of(context).size.width >= 700;

    if (!fileExists &&
        (preview.extractedText == null || preview.extractedText!.isEmpty)) {
      _showAttachmentErrorSnack('Le fichier local n\'est plus disponible sur cet appareil.');
      return;
    }

    String? rawTextContent;
    if (fileExists && !preview.isImage && !isPdf) {
      try {
        rawTextContent = await File(filePath).readAsString();
      } catch (_) {
        rawTextContent = preview.extractedText;
      }
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF161D2D) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 64 : 14,
          vertical: 24,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktop ? 760 : double.infinity,
            maxHeight: MediaQuery.of(context).size.height * 0.86,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isPdf
                            ? const Color(0xFFE53935).withValues(alpha: 0.14)
                            : primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        preview.extensionLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isPdf ? const Color(0xFFE53935) : primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            preview.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          if (preview.metaLabel.isNotEmpty)
                            Text(
                              preview.metaLabel,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (fileExists &&
                        (Platform.isWindows ||
                            Platform.isLinux ||
                            Platform.isMacOS))
                      IconButton(
                        tooltip: 'Ouvrir dans l\'application par défaut',
                        icon: const Icon(Icons.open_in_new_rounded, size: 20),
                        onPressed: () async {
                          await launchUrl(Uri.file(filePath));
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: preview.isImage && fileExists
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 5.0,
                            child: Image.file(
                              File(filePath),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      )
                    : (isPdf && fileExists)
                        ? _PdfRawPagesViewer(
                            file: File(filePath),
                            isDark: isDark,
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: SelectableText(
                              rawTextContent ?? preview.extractedText ?? '',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12.5,
                                height: 1.5,
                                color: isDark
                                    ? const Color(0xFFE2E8F0)
                                    : const Color(0xFF1E293B),
                              ),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(bool isDark, Color primary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161D2D) : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(
            color: isDark ? const Color(0xFF243048) : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: primary.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/launcher_icon.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Ngenou prépare une réponse…',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            const SinusoidalDotIndicator(),
          ],
        ),
      ),
    );
  }
}

/// Affiche les pages brutes d'un PDF via [Printing.raster].
class _PdfRawPagesViewer extends StatefulWidget {
  final File file;
  final bool isDark;

  const _PdfRawPagesViewer({required this.file, required this.isDark});

  @override
  State<_PdfRawPagesViewer> createState() => _PdfRawPagesViewerState();
}

class _PdfRawPagesViewerState extends State<_PdfRawPagesViewer> {
  List<PdfRaster>? _pages;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPages();
  }

  Future<void> _loadPages() async {
    try {
      final bytes = await widget.file.readAsBytes();
      final list = <PdfRaster>[];
      await for (final page in Printing.raster(bytes, dpi: 150)) {
        list.add(page);
      }
      if (mounted) {
        setState(() => _pages = list);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Impossible d\'afficher ce PDF : $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            _error!,
            style: const TextStyle(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_pages == null) {
      return const Padding(
        padding: EdgeInsets.all(36),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: _pages!.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final raster = _pages![index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: widget.isDark
                      ? const Color(0xFF2B3D5C)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image(
                image: PdfRasterImage(raster),
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Page ${index + 1} / ${_pages!.length}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Enums et modèles pour la gestion des pièces jointes ─────────────────────

/// Statut d'une pièce jointe en cours de traitement.
enum _AttachmentStatus {
  /// OCR / extraction en arrière-plan — pas encore disponible.
  extracting,
  /// Texte extrait et prêt à être envoyé dans le prompt.
  ready,
  /// Erreur d'extraction — la pièce jointe ne peut pas être envoyée.
  error,
}

/// Type de pièce jointe pour choisir l'icône et le moteur d'extraction.
enum _AttachmentKind {
  /// Fichier image (JPEG, PNG, etc.) → OCR ML Kit / WinRT / Tesseract.
  image,
  /// Fichier PDF → Syncfusion + limite de pages.
  pdf,
  /// Fichier texte/code (txt, algo, py…) → lecture directe.
  text,
}

/// Pièce jointe transitoire attachée au prochain message utilisateur.
/// Elle n'est jamais sauvegardée en base de données — uniquement en mémoire.
class _PendingAttachment {
  final String fileName;
  final String filePath;
  final String extensionLabel;
  final _AttachmentKind kind;
  _AttachmentStatus status;

  /// Texte extrait (OCR ou lecture directe), null si extraction non terminée.
  String? extractedText;

  /// Nombre de pages (PDF uniquement).
  int? pageCount;

  /// Nombre de mots dans le texte extrait.
  int wordCount = 0;

  /// Nombre de lignes (fichiers texte/code).
  int lineCount = 0;

  /// Vrai si le texte a été tronqué à [AiConfig.maxAttachmentChars].
  bool wasTruncated = false;

  /// Message d'erreur lisible si [status] == [_AttachmentStatus.error].
  String? errorMessage;

  /// Future de la tâche d'extraction en cours (permet d'attendre avant d'envoyer).
  Future<void>? inFlightTask;

  _PendingAttachment({
    required this.fileName,
    required this.filePath,
    required this.extensionLabel,
    required this.kind,
    required this.status,
  });
}

// ─────────────────────────────────────────────────────────────────────────────

/// Bottom-sheet de sélection du modèle Ngenou pour le chat global.
class _ChatModelPickerSheet extends StatelessWidget {
  final DeepSeekModel currentModel;
  final bool isDark;
  final ValueChanged<DeepSeekModel> onSelected;

  const _ChatModelPickerSheet({
    required this.currentModel,
    required this.isDark,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Modèle d\'IA',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choisissez le modèle pour cette conversation',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          _modelTile(
            context,
            model: DeepSeekModel.flash,
            icon: Icons.bolt_rounded,
            iconColor: const Color(0xFF3498DB),
            bgColor: const Color(0xFF3498DB).withValues(alpha: 0.1),
          ),
          const SizedBox(height: 10),
          _modelTile(
            context,
            model: DeepSeekModel.pro,
            icon: Icons.auto_awesome,
            iconColor: const Color(0xFF6C3FE8),
            bgColor: const Color(0xFF6C3FE8).withValues(alpha: 0.1),
          ),
        ],
      ),
    );
  }

  Widget _modelTile(
    BuildContext context, {
    required DeepSeekModel model,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    final selected = currentModel == model;
    return GestureDetector(
      onTap: () {
        onSelected(model);
        Navigator.pop(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? bgColor
              : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? iconColor.withValues(alpha: 0.6)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ngenou ${model.label}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    model.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: iconColor, size: 22),
          ],
        ),
      ),
    );
  }
}
