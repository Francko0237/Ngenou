import 'package:flutter/material.dart';
import '../../modules/algorithmique/defis/defi_data.dart';
import 'defi_solve_page.dart';

class DefisListPage extends StatelessWidget {
  const DefisListPage({super.key});

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Mode Défis', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: DefiData.defis.length,
        itemBuilder: (context, index) {
          final defi = DefiData.defis[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: isDark ? 0 : 4,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DefiSolvePage(defi: defi))
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.emoji_events, color: Theme.of(context).primaryColor, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(defi.titre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(
                            defi.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
                          ),
                        ]
                      )
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey)
                  ]
                )
              )
            )
          );
        },
      )
    );
  }
}
