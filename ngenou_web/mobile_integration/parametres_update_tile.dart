import 'package:flutter/material.dart';
import 'update_checker_service.dart';

/// Widget à insérer dans la page Paramètres de l'application mobile Ngenou
class ParametresUpdateTile extends StatefulWidget {
  final String currentVersionName;
  final int currentVersionCode;

  const ParametresUpdateTile({
    super.key,
    this.currentVersionName = UpdateChecker.kCurrentVersionName,
    this.currentVersionCode = UpdateChecker.kCurrentVersionCode,
  });

  @override
  State<ParametresUpdateTile> createState() => _ParametresUpdateTileState();
}

class _ParametresUpdateTileState extends State<ParametresUpdateTile> {
  bool _isChecking = false;

  Future<void> _handleCheck() async {
    setState(() => _isChecking = true);
    try {
      await UpdateChecker.checkForUpdate(
        context,
        isManual: true,
        currentInstalledCode: widget.currentVersionCode,
      );
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1A33),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E2E52)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3CC8E8).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF3CC8E8),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Version de l\'application',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF3EEE2),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'v${widget.currentVersionName} (Build ${widget.currentVersionCode})',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9BA8C4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isChecking ? null : _handleCheck,
              icon: _isChecking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF3CC8E8),
                      ),
                    )
                  : const Icon(
                      Icons.refresh_rounded,
                      color: Color(0xFF3CC8E8),
                      size: 18,
                    ),
              label: Text(
                _isChecking ? 'Vérification en cours...' : 'Vérifier les mises à jour',
                style: const TextStyle(
                  color: Color(0xFF3CC8E8),
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF3CC8E8), width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
