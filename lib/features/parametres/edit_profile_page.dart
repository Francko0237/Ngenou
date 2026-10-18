import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

enum ProfileCategory { eleve, etudiant, enseignant }

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();

  ProfileCategory _category = ProfileCategory.eleve;
  String _eleveLevel = 'secondaire'; // 'primaire' ou 'secondaire'
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentProfile() async {
    final name = await AuthService.getUsername();
    final role = await AuthService.getUserRole();
    final level = await AuthService.getSchoolLevel() ?? 'secondaire';
    final contact = await AuthService.getContactIdentifier();

    if (mounted) {
      setState(() {
        _nameController.text = name == 'Ami' ? '' : name;
        _contactController.text = contact ?? '';

        if (role == 'teacher') {
          _category = ProfileCategory.enseignant;
        } else if (level == 'superieur') {
          _category = ProfileCategory.etudiant;
        } else {
          _category = ProfileCategory.eleve;
          _eleveLevel = level == 'primaire' ? 'primaire' : 'secondaire';
        }

        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final newName = _nameController.text.trim();
      final newContact = _contactController.text.trim();

      // Sauvegarde du nom
      if (newName.isNotEmpty) {
        await AuthService.updateUsername(newName);
      }

      // Sauvegarde du contact
      if (newContact.isNotEmpty) {
        await AuthService.updateContact(newContact);
      }

      // Sauvegarde du rôle et niveau scolaire
      if (_category == ProfileCategory.enseignant) {
        await AuthService.updateUserRole('teacher');
      } else if (_category == ProfileCategory.etudiant) {
        await AuthService.updateUserRole('student');
        await AuthService.updateSchoolLevel('superieur');
      } else {
        await AuthService.updateUserRole('student');
        await AuthService.updateSchoolLevel(_eleveLevel);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil mis à jour avec succès !'),
            backgroundColor: Color(0xFF2ECC71),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121216)
          : const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Éditer mon profil',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width > 600
                        ? 32
                        : 20,
                    vertical: 20,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ─── Avatar décoratif ──────────────────────────────────
                        Center(
                          child: Stack(
                            children: [
                              Container(
                                width: 86,
                                height: 86,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      primary,
                                      primary.withValues(alpha: 0.75),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: primary.withValues(alpha: 0.3),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  _nameController.text.isNotEmpty
                                      ? _nameController.text.characters.first
                                            .toUpperCase()
                                      : 'N',
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1E1E26)
                                        : Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white24
                                          : Colors.black12,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Icon(
                                    _category == ProfileCategory.enseignant
                                        ? Icons.co_present_rounded
                                        : _category == ProfileCategory.etudiant
                                        ? Icons.school_rounded
                                        : Icons.backpack_rounded,
                                    size: 16,
                                    color: primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ─── 1. Nom d'utilisateur ──────────────────────────────
                        _fieldLabel('Nom d\'utilisateur', isDark),
                        TextFormField(
                          controller: _nameController,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Entrez votre nom ou pseudo',
                            prefixIcon: Icon(
                              Icons.person_outline_rounded,
                              color: primary,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF1E1E26)
                                : Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.black.withValues(alpha: 0.05),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Veuillez saisir votre nom';
                            }
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 20),

                        // ─── 2. Numéro de téléphone ou Email ────────────────────
                        _fieldLabel('Numéro de téléphone ou E-mail', isDark),
                        TextFormField(
                          controller: _contactController,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: '+237 6XX XX XX XX ou email@exemple.com',
                            prefixIcon: Icon(
                              Icons.contact_phone_outlined,
                              color: primary,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF1E1E26)
                                : Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.black.withValues(alpha: 0.05),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ─── 3. Choix du profil ────────────────────────────────
                        _fieldLabel('Statut & Profil', isDark),
                        const SizedBox(height: 4),
                        _profileOptionTile(
                          category: ProfileCategory.eleve,
                          title: 'Élève',
                          subtitle:
                              'Collège, Lycée ou Primaire (6e à Terminale)',
                          icon: Icons.backpack_rounded,
                          color: const Color(0xFF3498DB),
                          isDark: isDark,
                          primary: primary,
                        ),
                        const SizedBox(height: 10),
                        _profileOptionTile(
                          category: ProfileCategory.etudiant,
                          title: 'Étudiant',
                          subtitle:
                              'Études supérieures, Université ou Grandes écoles',
                          icon: Icons.school_rounded,
                          color: const Color(0xFF2ECC71),
                          isDark: isDark,
                          primary: primary,
                        ),
                        const SizedBox(height: 10),
                        _profileOptionTile(
                          category: ProfileCategory.enseignant,
                          title: 'Enseignant',
                          subtitle:
                              'Créateur de cours, professeur ou formateur',
                          icon: Icons.co_present_rounded,
                          color: const Color(0xFF9B59B6),
                          isDark: isDark,
                          primary: primary,
                        ),

                        // ─── Sous-niveau pour l'élève ──────────────────────────
                        if (_category == ProfileCategory.eleve) ...[
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 8),
                            child: Text(
                              'Niveau de l\'élève :',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _levelChip(
                                  label: 'Primaire',
                                  selected: _eleveLevel == 'primaire',
                                  onTap: () =>
                                      setState(() => _eleveLevel = 'primaire'),
                                  primary: primary,
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _levelChip(
                                  label: 'Secondaire (6e - Tle)',
                                  selected: _eleveLevel == 'secondaire',
                                  onTap: () => setState(
                                    () => _eleveLevel = 'secondaire',
                                  ),
                                  primary: primary,
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 36),

                        // ─── Bouton Enregistrer ────────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: _isSaving ? null : _saveProfile,
                            style: FilledButton.styleFrom(
                              backgroundColor: primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 2,
                            ),
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check_rounded, size: 20),
                            label: Text(
                              _isSaving
                                  ? 'Enregistrement...'
                                  : 'Enregistrer les modifications',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _fieldLabel(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white70 : Colors.black87,
        ),
      ),
    );
  }

  Widget _profileOptionTile({
    required ProfileCategory category,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    required Color primary,
  }) {
    final isSelected = _category == category;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E26) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? primary
              : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05)),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: primary.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _category = category),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF15151C),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: isSelected ? primary : Colors.grey,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _levelChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required Color primary,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? primary.withValues(alpha: isDark ? 0.25 : 0.12)
              : (isDark ? const Color(0xFF1E1E26) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? primary
                : (isDark ? Colors.white12 : Colors.black12),
            width: selected ? 1.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected
                ? (isDark ? Colors.white : primary)
                : (isDark ? Colors.white60 : Colors.black87),
          ),
        ),
      ),
    );
  }
}
