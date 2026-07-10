import 'package:flutter/material.dart';

class Matiere {
  final String id;
  final String nom;
  final String description;
  final IconData _icone;
  final Color couleur;
  final bool isAvailable;
  final List<String> sections;
  final int durationMinutes;

  Matiere({
    required this.id,
    required this.nom,
    required this.description,
    required IconData icone,
    required this.couleur,
    this.isAvailable = true,
    this.sections = const [],
    this.durationMinutes = 120,
  }) : _icone = icone;

  IconData get icone => _getDynamicIcon(nom, _icone);

  static IconData _getDynamicIcon(String titre, IconData defaultIcon) {
    final t = titre.toLowerCase();
    if (t.contains('agri') || t.contains('agro') || t.contains('elevage') || t.contains('élevage') || 
        t.contains('ferme') || t.contains('plante') || t.contains('botanique') || t.contains('ecologie') || 
        t.contains('écologie') || t.contains('environnement') || t.contains('nature') || t.contains('champ') ||
        t.contains('animal') || t.contains('animaux') || t.contains('veto') || t.contains('vétérinaire') || t.contains('biologie')) {
      return Icons.eco_rounded;
    }
    if (t.contains('couture') || t.contains('mode') || t.contains('vetement') || t.contains('vêtement') || 
        t.contains('tissu') || t.contains('fil') || t.contains('aiguille') || t.contains('stylisme') || t.contains('taille')) {
      return Icons.content_cut_rounded;
    }
    if (t.contains('nourriture') || t.contains('cuisine') || t.contains('gastronomie') || t.contains('nutrition') || 
        t.contains('alimentation') || t.contains('plat') || t.contains('recette') || t.contains('chef') || 
        t.contains('cuire') || t.contains('repas')) {
      return Icons.restaurant_rounded;
    }
    if (t.contains('sport') || t.contains('fitness') || t.contains('muscu') || t.contains('danse') || 
        t.contains('football') || t.contains('basket') || t.contains('tennis') || t.contains('yoga') || 
        t.contains('entrainement') || t.contains('entraînement')) {
      return Icons.fitness_center_rounded;
    }
    if (t.contains('droit') || t.contains('loi') || t.contains('justice') || t.contains('juridique')) {
      return Icons.gavel_rounded;
    }
    if (t.contains('code') || t.contains('dev') || t.contains('algorithm') || t.contains('python') || 
        t.contains('javascript') || t.contains('c++') || t.contains('java') || t.contains('dart') || 
        t.contains('flutter') || t.contains('programmation') || t.contains('web') || t.contains('informatique') || 
        t.contains('informatiq') || t.contains('info') || t.contains('tech') || t.contains('logiciel') || t.contains('application')) {
      return Icons.code_rounded;
    }
    if (t.contains('reseau') || t.contains('réseau') || t.contains('computer') || t.contains('systeme') || t.contains('système') || 
        t.contains('ordinateur') || t.contains('linux') || t.contains('cyber') || t.contains('telecom') || t.contains('télécom')) {
      return Icons.computer_rounded;
    }
    if (t.contains('physique') || t.contains('chimie') || t.contains('science') || t.contains('espace') || 
        t.contains('astronomie') || t.contains('sante') || t.contains('santé') || t.contains('medecine') || t.contains('médecine') ||
        t.contains('hopital') || t.contains('hôpital') || t.contains('corps') || t.contains('anatomie') || t.contains('labo') || t.contains('recherche')) {
      return Icons.science_rounded;
    }
    if (t.contains('math') || t.contains('calcul') || t.contains('algebre') || t.contains('algèbre') || t.contains('geometrie') || 
        t.contains('géométrie') || t.contains('statistique') || t.contains('nombre') || t.contains('chiffre') || t.contains('compta') || t.contains('comptabilite')) {
      return Icons.calculate_rounded;
    }
    if (t.contains('histoire') || t.contains('civilisation') || t.contains('siecle') || t.contains('siècle') || t.contains('egypte') || t.contains('rome') ||
        t.contains('archeologie') || t.contains('archéologie') || t.contains('literature') || t.contains('littérature') || t.contains('livre') ||
        t.contains('ecriture') || t.contains('écriture') || t.contains('poesie') || t.contains('poésie') || t.contains('roman')) {
      return Icons.history_edu_rounded;
    }
    if (t.contains('langue') || t.contains('anglais') || t.contains('espagnol') || t.contains('francais') || t.contains('français') || 
        t.contains('traduction') || t.contains('vocabulaire') || t.contains('linguistique') || t.contains('allemand') || t.contains('italien') || t.contains('chinois')) {
      return Icons.translate_rounded;
    }
    if (t.contains('economie') || t.contains('économie') || t.contains('finance') || t.contains('argent') || t.contains('gestion') || 
        t.contains('marketing') || t.contains('comptabilite') || t.contains('vente') || t.contains('commerce') || t.contains('business') || t.contains('management') || t.contains('entreprise')) {
      return Icons.trending_up_rounded;
    }
    if (t.contains('musique') || t.contains('guitare') || t.contains('piano') || t.contains('art') || 
        t.contains('dessin') || t.contains('peinture') || t.contains('artiste') || t.contains('design') || t.contains('graphisme') || t.contains('photo') || t.contains('cinema') || t.contains('cinéma')) {
      return Icons.palette_rounded;
    }
    if (t.contains('philo') || t.contains('pensee') || t.contains('pensée') || t.contains('critique') || t.contains('esprit') || t.contains('psycho') || t.contains('sagesse') || t.contains('moral')) {
      return Icons.psychology_rounded;
    }
    if (t.contains('geo') || t.contains('géo') || t.contains('pays') || t.contains('carte') || t.contains('climat') || t.contains('terre') || t.contains('monde') || t.contains('voyage') || t.contains('tourisme') || t.contains('ocean') || t.contains('océan')) {
      return Icons.public_rounded;
    }
    return defaultIcon;
  }
}

