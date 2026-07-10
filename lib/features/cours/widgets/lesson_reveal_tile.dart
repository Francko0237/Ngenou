import 'package:flutter/material.dart';

class LessonRevealTile extends StatefulWidget {
  final String title;
  final String content;
  final Color accent;
  final bool isDark;

  const LessonRevealTile({
    super.key,
    required this.title,
    required this.content,
    required this.accent,
    required this.isDark,
  });

  @override
  State<LessonRevealTile> createState() => _LessonRevealTileState();
}

class _LessonRevealTileState extends State<LessonRevealTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: widget.accent.withValues(alpha: widget.isDark ? 0.1 : 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.accent.withValues(alpha: _expanded ? 0.5 : 0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _expanded ? Icons.expand_less_rounded : Icons.touch_app_outlined,
                      color: widget.accent,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: widget.isDark ? Colors.white : Colors.black87,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.visibility : Icons.visibility_outlined,
                      color: widget.accent.withValues(alpha: 0.7),
                      size: 18,
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 12, left: 32),
                    child: Text(
                      widget.content,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.55,
                        color: widget.isDark ? Colors.grey[300] : Colors.grey[800],
                      ),
                    ),
                  ),
                  crossFadeState: _expanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 250),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
