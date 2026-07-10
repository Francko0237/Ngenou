import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../../core/services/ai_tutor_history_service.dart';
import '../../core/services/ai_tutor_service.dart';
import '../../core/models/deep_seek_model.dart';
import '../../core/services/quota_guard.dart';
import '../../core/providers/projets_provider.dart';
import '../../core/providers/defis_provider.dart';
import '../../core/providers/custom_courses_provider.dart';
import '../../core/utils/course_context_mapper.dart';
import '../../modules/modules_registry.dart';
import 'package:go_router/go_router.dart';
import '../cours/widgets/ai_tutor_chat_sheet.dart';
import '../../core/utils/error_formatter.dart';
import '../../core/widgets/ai_markdown_text.dart';

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
    final loaded = await AiTutorHistoryService.loadHistory('global_chat');
    if (mounted) {
      setState(() {
        _globalMessages
            .clear(); // vider avant de recharger — évite les doublons
        _globalMessages.addAll(loaded);
        _isInitLoadingGlobal = false;
      });
      // Sauter directement tout en bas à la fin du rendu initial (qui est 0.0)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _jumpToBottom();
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
    final question = text.trim();
    if (question.isEmpty || _isLoading) return;
    _input.clear();
    FocusScope.of(context).unfocus();

    final userMsg = TutorMessage(
      role: 'user',
      content: question,
      timestamp: DateTime.now(),
    );

    setState(() {
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

  // Indique si le bouton "descendre" doit être visible
  bool _showScrollDown = false;
  // Indique si le texte de saisie est long
  bool _isLongInput = false;
  // True quand l'utilisateur fait défiler manuellement — suspend l'auto-scroll
  bool _userIsScrolling = false;

  bool _isNearBottom() {
    if (!_scroll.hasClients) return true;
    return _scroll.position.pixels <= 40;
  }

  void _showAttachmentOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(
                Icons.image_rounded,
                color: Theme.of(context).primaryColor,
              ),
              title: const Text('Photo / Image'),
              subtitle: const Text('Depuis la galerie'),
              onTap: () {
                Navigator.pop(context);
                // TODO: implémenter la sélection d'image
              },
            ),
            ListTile(
              leading: Icon(
                Icons.attach_file_rounded,
                color: Theme.of(context).primaryColor,
              ),
              title: const Text('Fichier'),
              subtitle: const Text('PDF, document…'),
              onTap: () {
                Navigator.pop(context);
                // TODO: implémenter la sélection de fichier
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

  void _onScrollChanged() {
    final shouldShow = !_isNearBottom();
    if (shouldShow != _showScrollDown) {
      setState(() => _showScrollDown = shouldShow);
    }
    // Si on revient près du bas (pixels <= 45), on réactive l'auto-scroll
    if (_scroll.hasClients) {
      if (_scroll.position.pixels <= 45) {
        _userIsScrolling = false;
      }
    }
  }

  /// Scroll instantané (pendant animation typewriter) — pas de délai de transition.
  /// Ne scrolle PAS si l'utilisateur est en train de remonter pour lire.
  void _scrollToBottomFast() {
    if (!_scroll.hasClients) return;
    // Si l'utilisateur touche l'écran pour scroller (geste actif détecté par la physique de Flutter)
    if (_scroll.position.userScrollDirection != ScrollDirection.idle) {
      _userIsScrolling = true;
      return;
    }
    if (_userIsScrolling) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_userIsScrolling) {
        return; // Sécurité si l'user commence à scroller entre-temps
      }
      if (_scroll.hasClients) {
        _scroll.jumpTo(0.0);
      }
    });
  }

  /// Scroll fluide (navigation normale)
  void _scrollToBottom({bool force = false}) {
    if (!_scroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients && (force || _isNearBottom())) {
        _scroll.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        ).then((_) {
          if (force && mounted && _scroll.hasClients) {
            _scroll.jumpTo(0.0);
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    final bg = isDark ? const Color(0xFF161616) : const Color(0xFFF9FAFB);
    final inputBg = isDark ? const Color(0xFF222222) : const Color(0xFFF3F4F6);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                      ? const Color.fromARGB(255, 59, 59, 71)
                      : const Color.fromARGB(255, 98, 107, 119),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
              child: ClipOval(
                child: Transform.scale(
                  scale: 1.3,
                  child: Image.asset(
                    'assets/images/launcher_icon.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 5),
            const Text(
              'Ngenou Assistant',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isPro
              ? const Color(0xFF6C3FE8).withValues(alpha: 0.15)
              : (isDark
                    ? Colors.grey[800]!.withValues(alpha: 0.8)
                    : Colors.grey[200]!),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPro
                ? const Color(0xFF6C3FE8).withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPro ? Icons.auto_awesome : Icons.bolt_rounded,
              size: 14,
              color: isPro
                  ? const Color(0xFF6C3FE8)
                  : (isDark ? Colors.grey[300] : Colors.grey[700]),
            ),
            const SizedBox(width: 4),
            Text(
              _selectedModel.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isPro
                    ? const Color(0xFF6C3FE8)
                    : (isDark ? Colors.grey[300] : Colors.grey[700]),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.expand_more_rounded,
              size: 14,
              color: isPro
                  ? const Color(0xFF6C3FE8)
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
                          // Dès que l'utilisateur touche pour scroller : suspend l'auto-scroll
                          _userIsScrolling = true;
                        } else if (notification is ScrollEndNotification) {
                          // Le scroll s'arrête — si on est près du bas (0.0), on réactive l'auto-scroll
                          if (_scroll.position.pixels <= 45) {
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
                                color: Colors.black.withOpacity(0.15),
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
        // Champ de saisie
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
              ),
            ),
          ),
          child: Builder(
            builder: (context) {
              final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
              final minL = keyboardOpen ? 1 : 2;
              // Container principal avec bordure arrondie + hauteur max
              // Stack à l'intérieur pour superposer le bouton sur le texte
              return Container(
                constraints: BoxConstraints(
                  maxHeight: keyboardOpen ? 120 : 160,
                ),
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                    width: 1,
                  ),
                ),
                child: Stack(
                  children: [
                    // Champ texte scrollable — prend toute la place du Container
                    ClipRRect(
                      borderRadius: BorderRadius.circular(19),
                      child: ScrollConfiguration(
                        behavior: const ScrollBehavior().copyWith(
                          scrollbars: false,
                          overscroll: false,
                        ),
                        child: SingleChildScrollView(
                          reverse: true,
                          child: TextField(
                            controller: _input,
                            maxLines: null,
                            minLines: minL,
                            keyboardType: TextInputType.multiline,
                            textCapitalization: TextCapitalization.sentences,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 15,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Demande quelque chose\nà Ngenou…',
                              hintStyle: TextStyle(
                                color: isDark
                                    ? Colors.grey[500]
                                    : Colors.grey[500],
                                height: 1.5,
                              ),
                              hintMaxLines: 2,
                              border: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              // Gauche pour bouton +, droite pour bouton envoi
                              contentPadding: const EdgeInsets.fromLTRB(
                                50,
                                10,
                                52,
                                10,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Bouton + en bas à gauche
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: GestureDetector(
                        onTap: _showAttachmentOptions,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.grey[200],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            color: isDark ? Colors.grey[300] : Colors.grey[600],
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    // Bouton d'envoi / Stop
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: _isLoading ? _stop : () => _send(_input.text),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _isLoading ? Colors.red.shade400 : primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isLoading
                                ? Icons.stop_rounded
                                : Icons.send_rounded,
                            color: Colors.white,
                            size: 17,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
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
                      color: lessonColor.withOpacity(0.08),
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

  Widget _buildWelcome(bool isDark, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primary.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
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
          const SizedBox(height: 20),
          Text(
            'Bienvenue chez Ngenou 👋',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: isDark ? Colors.white : Colors.black87,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Je connais toutes les notions et matières de l\'application. Tu peux me poser des questions d\'ordre général, ou me demander d\'expliquer un cours en particulier.',
            style: TextStyle(
              fontSize: 14.5,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),
          Text(
            'Suggestions rapides',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: _suggestions
                .map((s) => _buildSuggestionChip(s, primary, isDark))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text, Color primary, bool isDark) {
    return GestureDetector(
      onTap: () => _send(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: primary.withOpacity(0.25)),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildLLMMessageRow(TutorMessage msg, bool isDark, Color primary) {
    final isUser = msg.role == 'user';
    final msgIndex = _globalMessages.indexOf(msg);

    if (isUser) {
      return GestureDetector(
        onLongPress: () =>
            _showUserMessageOptions(context, msg, msgIndex, isDark, primary),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withOpacity(0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    msg.content,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(shape: BoxShape.circle),
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
                  color: primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AiMarkdownText(
            text: msg.content,
            selectable: true,
            style: TextStyle(
              color: isDark ? Colors.grey[200] : Colors.grey[800],
              fontSize: 15,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 4),
          // Bouton copie discret
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _copyToClipboard(msg.content),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.copy_rounded,
                  size: 15,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
              ),
            ),
          ),
        ],
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

  Widget _buildTypingIndicator(bool isDark, Color primary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: ClipOval(
              child: Image.asset(
                'assets/images/launcher_icon.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ngenou',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 12),
                const SinusoidalDotIndicator(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
