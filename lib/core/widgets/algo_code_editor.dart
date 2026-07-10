import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../algo_interpreter/syntax_highlighter.dart';

class AutoCloseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    int offset = newValue.selection.baseOffset;
    if (newValue.text.length == oldValue.text.length + 1 && offset > 0) {
      String addedChar = newValue.text[offset - 1];

      if (addedChar == '(') return _insertAndMove(newValue, ')', offset);
      if (addedChar == '[') return _insertAndMove(newValue, ']', offset);
      if (addedChar == '"') {
        if (oldValue.text.length >= offset &&
            oldValue.text[offset - 1] == '"') {
          return oldValue.copyWith(
            selection: TextSelection.collapsed(offset: offset),
          );
        }
        return _insertAndMove(newValue, '"', offset);
      }
      if (addedChar == ')') {
        if (oldValue.text.length >= offset &&
            oldValue.text[offset - 1] == ')') {
          return oldValue.copyWith(
            text: oldValue.text,
            selection: TextSelection.collapsed(offset: offset),
          );
        }
      }
      if (addedChar == ']') {
        if (oldValue.text.length >= offset &&
            oldValue.text[offset - 1] == ']') {
          return oldValue.copyWith(
            text: oldValue.text,
            selection: TextSelection.collapsed(offset: offset),
          );
        }
      }
    }
    return newValue;
  }

  TextEditingValue _insertAndMove(
    TextEditingValue value,
    String suffix,
    int offset,
  ) {
    String newText =
        value.text.substring(0, offset) + suffix + value.text.substring(offset);
    return value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

class AlgoCodeEditor extends StatefulWidget {
  final AlgoSyntaxController controller;
  final String hintText;

  const AlgoCodeEditor({
    super.key,
    required this.controller,
    this.hintText = "",
  });

  @override
  _AlgoCodeEditorState createState() => _AlgoCodeEditorState();
}

class _AlgoCodeEditorState extends State<AlgoCodeEditor> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _lineController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<String> _allSuggestions = [
    'Algorithme ',
    'Var',
    'Debut',
    'Fin',
    'Entier',
    'Reel',
    'Chaine',
    'Booleen',
    'Tableau',
    ' de ',
    'Ecrire(',
    'Lire(',
    'Si ',
    'Alors',
    'Sinon',
    'FinSi',
    'Pour ',
    ' a ',
    'Faire',
    'FinPour',
    'Tant que ',
    'FinTantQue',
    'Repeter',
    "Jusqu'a ",
    ' ← ',
    ' + ',
    ' - ',
    ' * ',
    ' / ',
  ];

  List<String> _activeSuggestions = [];
  int _lineCount = 1;
  String _currentWord = "";
  int _wordStartIdx = -1;

  @override
  void initState() {
    super.initState();
    _activeSuggestions = List.from(_allSuggestions);

    _focusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.tab) {
        if (_activeSuggestions.isNotEmpty && _currentWord.isNotEmpty) {
          _insertSuggestion(_activeSuggestions.first);
          return KeyEventResult.handled;
        }
        _insertText("   ");
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
    _updateLineNumbers();
    widget.controller.addListener(_updateLineNumbers);
    _scrollController.addListener(() {
      if (_lineController.hasClients) {
        _lineController.jumpTo(_scrollController.offset);
      }
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateLineNumbers);
    _scrollController.dispose();
    _lineController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _updateLineNumbers() {
    final count = '\n'.allMatches(widget.controller.text).length + 1;
    if (count != _lineCount) {
      setState(() => _lineCount = count);
    }
    _extractCurrentWord();
  }

  void _extractCurrentWord() {
    int cursorPos = widget.controller.selection.baseOffset;
    if (cursorPos < 0) return;

    String text = widget.controller.text;
    if (cursorPos > text.length) cursorPos = text.length;

    int start = cursorPos - 1;
    while (start >= 0 && RegExp(r'[a-zA-ZÀ-ÿ_]').hasMatch(text[start])) {
      start--;
    }
    start++;

    String word = text.substring(start, cursorPos);
    _wordStartIdx = start;

    if (word != _currentWord) {
      _currentWord = word;
      setState(() {
        if (word.length >= 2) {
          _activeSuggestions = _allSuggestions
              .where(
                (s) =>
                    s.trimLeft().toLowerCase().startsWith(word.toLowerCase()),
              )
              .toList();
          if (_activeSuggestions.isEmpty) {
            _activeSuggestions = List.from(_allSuggestions);
          }
        } else {
          _activeSuggestions = List.from(_allSuggestions);
        }
      });
    }
  }

  void _insertSuggestion(String text) {
    if (_wordStartIdx < 0 || _currentWord.isEmpty) {
      _insertText(text);
      return;
    }
    final int cursorPos = widget.controller.selection.baseOffset;
    final String currentText = widget.controller.text;
    final String newText =
        currentText.substring(0, _wordStartIdx) +
        text +
        currentText.substring(cursorPos);

    widget.controller.value = widget.controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: _wordStartIdx + text.length),
    );
    _wordStartIdx = -1;
    _currentWord = "";
  }

  void _insertText(String text) {
    final int cursorPos = widget.controller.selection.baseOffset;
    if (cursorPos < 0) {
      widget.controller.text += text;
      return;
    }
    final String currentText = widget.controller.text;
    final String newText =
        currentText.substring(0, cursorPos) +
        text +
        currentText.substring(cursorPos);
    widget.controller.value = widget.controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: cursorPos + text.length),
    );
  }

  Widget _buildSymbolButton(
    String symbol, {
    String? insertValue,
    int cursorOffset = 0,
  }) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () {
        String toInsert = insertValue ?? symbol;
        _insertText(toInsert);
        if (cursorOffset != 0) {
          final int cursorPos = widget.controller.selection.baseOffset;
          widget.controller.selection = TextSelection.collapsed(
            offset: cursorPos + cursorOffset,
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: Colors.grey.withOpacity(0.3)),
          ),
        ),
        child: Text(
          symbol,
          style: TextStyle(
            fontSize: 16,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.blueAccent[100] : Colors.blue[800],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Line numbers & Code area
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF9F9F9),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF252525)
                        : const Color(0xFFEEEEEE),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                    ),
                  ),
                  padding: const EdgeInsets.only(top: 8, right: 6, bottom: 8),
                  alignment: Alignment.topLeft,
                  child: SingleChildScrollView(
                    controller: _lineController,
                    physics: const NeverScrollableScrollPhysics(),
                    child: Text(
                      List.generate(
                        _lineCount,
                        (i) => (i + 1).toString(),
                      ).join('\n'),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        height: 1.5,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
                Expanded(
                  child: Scrollbar(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width:
                            2000, // Large fixed width to prevent word-wrap matching line numbers
                        child: TextField(
                          controller: widget.controller,
                          scrollController: _scrollController,
                          focusNode: _focusNode,
                          maxLines: null,
                          expands: true,
                          inputFormatters: [AutoCloseFormatter()],
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            height: 1.5,
                          ),
                          keyboardType: TextInputType.multiline,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            hintText: widget.hintText,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Autocomplete keywords bar
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[300],
            border: Border(
              left: BorderSide(color: Colors.grey.withOpacity(0.3)),
              right: BorderSide(color: Colors.grey.withOpacity(0.3)),
            ),
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _activeSuggestions.length,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemBuilder: (context, index) {
              bool isFirstMatch =
                  index == 0 &&
                  _currentWord.length >= 2 &&
                  _activeSuggestions.length != _allSuggestions.length;
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 2.0,
                  vertical: 4.0,
                ),
                child: ActionChip(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4.0,
                    vertical: 0.0,
                  ),
                  labelPadding: const EdgeInsets.symmetric(
                    horizontal: 4.0,
                    vertical: -4.0,
                  ),
                  label: Text(
                    _activeSuggestions[index],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isFirstMatch
                          ? FontWeight.w900
                          : FontWeight.w600,
                    ),
                  ),
                  backgroundColor: isFirstMatch
                      ? Theme.of(context).primaryColor.withOpacity(0.4)
                      : Theme.of(context).primaryColor.withOpacity(0.1),
                  side: BorderSide(
                    color: Theme.of(
                      context,
                    ).primaryColor.withOpacity(isFirstMatch ? 0.8 : 0.3),
                  ),
                  onPressed: () => _insertSuggestion(_activeSuggestions[index]),
                ),
              );
            },
          ),
        ),
        // Quick Symbols bar
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF222222) : Colors.grey[200],
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildSymbolButton(';', insertValue: ';'),
              _buildSymbolButton('()', insertValue: '()', cursorOffset: -1),
              _buildSymbolButton('[]', insertValue: '[]', cursorOffset: -1),
              _buildSymbolButton('""', insertValue: '""', cursorOffset: -1),
              _buildSymbolButton('←'),
              _buildSymbolButton('<='),
              _buildSymbolButton('>='),
              _buildSymbolButton('<'),
              _buildSymbolButton('>'),
              _buildSymbolButton('+'),
              _buildSymbolButton('-'),
              _buildSymbolButton('*'),
              _buildSymbolButton('/'),
            ],
          ),
        ),
      ],
    );
  }
}
