import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import '../../../core/services/ai_tutor_history_service.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/services/ai_tutor_service.dart';
import '../../../core/models/deep_seek_model.dart';
import '../../../core/services/quota_guard.dart';
import '../../../core/widgets/ai_markdown_text.dart';

/// Bottom sheet de chat avec Ngenou, contextuel à la leçon en cours.
class AiTutorChatSheet extends StatefulWidget {
  final LessonContext lessonContext;
  final String historyKey;

  const AiTutorChatSheet({
    super.key,
    required this.lessonContext,
    required this.historyKey,
  });

  @override
  State<AiTutorChatSheet> createState() => _AiTutorChatSheetState();
}

class _AiTutorChatSheetState extends State<AiTutorChatSheet> {
  final List<TutorMessage> _messages = [];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _isLoading = false;
  bool _isInitLoading = true;
  DeepSeekModel _selectedModel = DeepSeekModel.flash;

  /// True quand l'utilisateur scrolle manuellement — suspend l'auto-scroll
  bool _userIsScrolling = false;
  bool _showScrollDown = false;

  // Variables pour stocker la réponse complète afin d'éviter les coupures à la fermeture
  String _currentFullReply = '';
  DateTime? _currentReplyTimestamp;
  Timer? _typewriterTimer;

  static const _suggestions = [
    "Explique-moi ce concept simplement",
    "Donne-moi un exemple concret",
    "Je ne comprends pas, reformule",
    "Quelle est l'utilité pratique ?",
  ];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScrollChanged);
    _loadPersistedHistory();
  }

  void _jumpToBottom() {
    if (_scroll.hasClients) {
      _scroll.jumpTo(0.0);
    }
  }

  void _onScrollChanged() {
    final nearBottom = _isNearBottom();
    // Réactive l'auto-scroll si on revient près du bas (seuil de 45 pixels, soit <= 45 en reverse)
    if (_scroll.hasClients) {
      if (_scroll.position.pixels <= 45) {
        _userIsScrolling = false;
      }
    }
    final shouldShow = !nearBottom;
    if (shouldShow != _showScrollDown) {
      setState(() => _showScrollDown = shouldShow);
    }
  }

  Future<void> _loadPersistedHistory() async {
    final loaded = await AiTutorHistoryService.loadHistory(widget.historyKey);
    if (mounted) {
      setState(() {
        _messages
            .clear(); // Vider avant de charger pour éviter les doublons au rechargement
        _messages.addAll(loaded);
        _isInitLoading = false;
      });
      // S'assurer de sauter directement tout en bas à la fin du rendu initial (qui est 0.0)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _jumpToBottom();
      });
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScrollChanged);
    if (_typewriterTimer != null && _typewriterTimer!.isActive) {
      _typewriterTimer!.cancel();
      // Sauvegarder immédiatement le message complet avant la destruction
      if (_messages.isNotEmpty && _messages.last.role == 'assistant') {
        _messages[_messages.length - 1] = TutorMessage(
          role: 'assistant',
          content: _currentFullReply,
          timestamp: _currentReplyTimestamp ?? DateTime.now(),
        );
        AiTutorHistoryService.saveHistory(widget.historyKey, _messages);
      }
    }
    _input.dispose();
    _scroll.dispose();
    super.dispose();
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
      _messages.add(userMsg);
      _isLoading = true;
    });
    _scrollToBottom(force: true);
    await AiTutorHistoryService.saveHistory(widget.historyKey, _messages);

    try {
      final tutorResponse = await AiTutorService.ask(
        context: widget.lessonContext,
        history: _messages,
        model: _selectedModel,
      );
      if (mounted) {
        setState(() => _isLoading = false);
        // Fallback Pro → Flash : snackbar + l'appel a quand même eu lieu
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
      // Message éphémère dans le chat — aucun appel API n'a été fait.
      // On retire le message utilisateur et on affiche le message quota
      // sans sauvegarder en base.
      if (mounted) {
        setState(() {
          if (_messages.isNotEmpty && _messages.last.role == 'user') {
            _messages.removeLast();
          }
          _messages.add(
            TutorMessage(
              role: 'assistant',
              content: e.message,
              timestamp: DateTime.now(),
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom(force: true);
        // NE PAS appeler saveHistory → éphémère
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = formatUserError(e);
        // Log temporaire pour debug — à retirer après diagnostic
        debugPrint('=== ERREUR IA BRUTE : $e ===');
        debugPrint('=== TYPE : ${e.runtimeType} ===');
        setState(() {
          _messages.add(
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
    final messages = _messages; // référence locale pour accès post-dispose

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
          AiTutorHistoryService.saveHistory(widget.historyKey, messages);
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
        AiTutorHistoryService.saveHistory(widget.historyKey, messages);
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

  bool _isNearBottom() {
    if (!_scroll.hasClients) return true;
    return _scroll.position.pixels <= 40;
  }

  /// Scroll instantané (pendant animation typewriter) — suspendu si l'user scrolle
  void _scrollToBottomFast() {
    if (!_scroll.hasClients) return;
    // Si l'utilisateur touche l'écran pour scroller (geste actif détecté par la physique de Flutter)
    if (_scroll.position.userScrollDirection != ScrollDirection.idle) {
      _userIsScrolling = true;
      return;
    }
    if (_userIsScrolling) return; // l'utilisateur lit, on ne force pas
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

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // ── Handle + Header ──────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ngenou',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                  color: isDark ? Colors.white : Colors.black87,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                widget.lessonContext.sectionTitre,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: primary,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Sélecteur de modèle compact
                        _buildSheetModelSelector(isDark, primary),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.close_rounded,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Divider(
                    height: 1,
                    color: isDark ? Colors.grey[850] : Colors.grey[200],
                  ),
                ],
              ),
            ),

            // ── Zone messages (LLM-style full width layout) ──────────────────
            Expanded(
              child: _isInitLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                  ? _buildWelcome(isDark, primary)
                  : Stack(
                      children: [
                        NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification is UserScrollNotification) {
                              // L'utilisateur touche et scrolle : suspend l'auto-scroll
                              _userIsScrolling = true;
                            } else if (notification is ScrollEndNotification) {
                              if (_scroll.position.pixels <= 45) {
                                _userIsScrolling = false;
                              }
                            }
                            return false;
                          },
                          child: ListView.builder(
                            controller: _scroll,
                            reverse: true,
                            padding: EdgeInsets.zero,
                            itemCount: _messages.length + (_isLoading ? 1 : 0),
                            itemBuilder: (context, i) {
                              if (_isLoading && i == 0) {
                                return _buildTypingIndicator(isDark, primary);
                              }
                              final msgIndex = _isLoading
                                  ? _messages.length - i
                                  : _messages.length - 1 - i;
                              return _buildLLMMessageRow(
                                _messages[msgIndex],
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
                            child: Material(
                              key: const ValueKey('scroll_down_btn'),
                              color: Colors.transparent,
                              type: MaterialType.transparency,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(19),
                                onTap: () {
                                  setState(() {
                                    _userIsScrolling = false;
                                    _showScrollDown = false;
                                  });
                                  _scrollToBottom(force: true);
                                },
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF2A2A2A)
                                        : Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.grey[700]!
                                          : Colors.grey[300]!,
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
                                    color: isDark
                                        ? Colors.grey[300]
                                        : Colors.grey[700],
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),

            // ── Champ de saisie ──────────────────────────────────────────────
            Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom:
                    12 +
                    (MediaQuery.of(context).viewInsets.bottom == 0
                        ? MediaQuery.of(context).padding.bottom
                        : 0),
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _input,
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Pose ta question à Ngenou…',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.grey[500] : Colors.grey[500],
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: _isLoading ? null : _send,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _isLoading ? _stop : () => _send(_input.text),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _isLoading ? Colors.red.shade400 : primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isLoading ? Icons.stop_rounded : Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
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

  // ── Stop ────────────────────────────────────────────────────────────────

  /// Arrête la réponse en cours (typewriter + requête HTTP).
  /// Le message partiel déjà affiché est conservé dans le chat.
  void _stop() {
    if (_typewriterTimer != null && _typewriterTimer!.isActive) {
      _typewriterTimer!.cancel();
      // Sauvegarder l'état partiel
      if (_messages.isNotEmpty && _messages.last.role == 'assistant') {
        final partial = _messages.last.content;
        if (partial.isNotEmpty) {
          AiTutorHistoryService.saveHistory(widget.historyKey, _messages);
        }
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // ── Sélecteur de modèle compact dans le header ──────────────────────────

  Widget _buildSheetModelSelector(bool isDark, Color primary) {
    final isPro = _selectedModel == DeepSeekModel.pro;
    return GestureDetector(
      onTap: () => _showModelPicker(isDark, primary),
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isPro
              ? const Color(0xFF6C3FE8).withValues(alpha: 0.15)
              : (isDark
                    ? Colors.grey[800]!.withValues(alpha: 0.8)
                    : Colors.grey[200]!),
          borderRadius: BorderRadius.circular(16),
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
              size: 13,
              color: isPro
                  ? const Color(0xFF6C3FE8)
                  : (isDark ? Colors.grey[300] : Colors.grey[700]),
            ),
            const SizedBox(width: 3),
            Text(
              _selectedModel.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isPro
                    ? const Color(0xFF6C3FE8)
                    : (isDark ? Colors.grey[300] : Colors.grey[700]),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.expand_more_rounded,
              size: 13,
              color: isPro
                  ? const Color(0xFF6C3FE8)
                  : (isDark ? Colors.grey[400] : Colors.grey[500]),
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
      builder: (_) => _LessonModelPickerSheet(
        currentModel: _selectedModel,
        isDark: isDark,
        onSelected: (m) => setState(() => _selectedModel = m),
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
            'Bonjour ! Je suis Ngenou 👋',
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
            'Je suis conçu pour t\'accompagner et répondre à toutes tes questions sur cette section du cours en temps réel.',
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

  /// Bloc de message style LLM pour Ngenou, et bulle de discussion sur la droite pour l'utilisateur
  Widget _buildLLMMessageRow(TutorMessage msg, bool isDark, Color primary) {
    final isUser = msg.role == 'user';
    final msgIndex = _messages.indexOf(msg);

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

    // Message de Ngenou en style bloc LLM sans couleur de fond alternée
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
                _messages.removeRange(index, _messages.length);
              });
              _send(newText);
            },
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }

  /// Ligne d'attente d'écriture du tuteur sans couleur de fond alternée
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

/// Indicateur de trois points qui s'anime en onde sinusoïdale sur place en changeant de couleur
class SinusoidalDotIndicator extends StatefulWidget {
  const SinusoidalDotIndicator({super.key});

  @override
  State<SinusoidalDotIndicator> createState() => _SinusoidalDotIndicatorState();
}

class _SinusoidalDotIndicatorState extends State<SinusoidalDotIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final secondaryColor = Colors.purpleAccent.shade200;

    return SizedBox(
      height: 20,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              // Déphasage pour l'onde sinusoïdale (2 * pi / 3 radians de décalage entre chaque point)
              final double phase = index * (2.0 * math.pi / 3.0);
              final double t = _controller.value * 2.0 * math.pi;
              final double offset =
                  math.sin(t - phase) *
                  5.0; // hauteur de déplacement vertical de 5 pixels

              // Interpolation de couleur sinusoïdale
              final double colorFactor = (math.sin(t - phase) + 1.0) / 2.0;
              final color = Color.lerp(primary, secondaryColor, colorFactor);

              return Transform.translate(
                offset: Offset(0, offset),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color!.withOpacity(0.3),
                          blurRadius: 3,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

/// Bottom-sheet de sélection du modèle Ngenou pour le chat de leçon.
class _LessonModelPickerSheet extends StatelessWidget {
  final DeepSeekModel currentModel;
  final bool isDark;
  final ValueChanged<DeepSeekModel> onSelected;

  const _LessonModelPickerSheet({
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
            'Choisissez le modèle pour ce chat de leçon',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          _tile(
            context,
            model: DeepSeekModel.flash,
            icon: Icons.bolt_rounded,
            iconColor: const Color(0xFF3498DB),
            bgColor: const Color(0xFF3498DB).withValues(alpha: 0.1),
          ),
          const SizedBox(height: 10),
          _tile(
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

  Widget _tile(
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
