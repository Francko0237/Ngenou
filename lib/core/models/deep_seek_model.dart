/// Modèles Ngenou disponibles dans l'application.
enum DeepSeekModel {
  /// deepseek-chat — rapide, économique (V3).
  flash,

  /// deepseek-reasoner — plus puissant, plus explicatif (R1).
  pro;

  /// Identifiant API exact à envoyer dans le champ "model".
  String get apiId {
    switch (this) {
      case DeepSeekModel.flash:
        return 'deepseek-chat';
      case DeepSeekModel.pro:
        return 'deepseek-reasoner';
    }
  }

  /// Label court affiché dans l'UI.
  String get label {
    switch (this) {
      case DeepSeekModel.flash:
        return 'Flash';
      case DeepSeekModel.pro:
        return 'Pro';
    }
  }

  /// Description affichée dans les tooltips / sous-titres.
  String get description {
    switch (this) {
      case DeepSeekModel.flash:
        return 'Rapide & économique';
      case DeepSeekModel.pro:
        return 'Plus puissant & explicatif';
    }
  }

  /// Prompt système supplémentaire injecté quand Pro est sélectionné.
  /// Retourne null pour Flash (pas de surcharge).
  String? get proSystemPromptSuffix {
    if (this == DeepSeekModel.flash) return null;
    return '''
INSTRUCTIONS QUALITÉ RENFORCÉE (MODE PRO — PRIORITÉ ABSOLUE) :
Tu opères en mode haute qualité. Tes réponses doivent respecter les exigences suivantes SANS EXCEPTION :

1. CLARTÉ MAXIMALE : Explique chaque concept de manière progressive, du plus simple au plus complexe. Ne suppose jamais que l'apprenant connaît déjà le sujet. Définis chaque terme technique à sa première apparition.

2. EXHAUSTIVITÉ : Ne raccourcis aucune explication. Chaque section doit être complète et autonome. Si un concept nécessite 10 phrases pour être bien compris, écris 10 phrases. Ne coupe jamais court.

3. EXEMPLES CONCRETS OBLIGATOIRES : Pour chaque concept abstrait, fournis au minimum 2 exemples concrets tirés de la vie quotidienne ou de cas réels. Les exemples doivent être variés et progressifs (simple puis plus complexe).

4. PÉDAGOGIE STEP-BY-STEP : Décompose chaque processus en étapes numérotées claires. Chaque étape doit expliquer POURQUOI elle est nécessaire, pas seulement QUOI faire.

5. CODE COMMENTÉ LIGNE PAR LIGNE : Tout extrait de code doit avoir CHAQUE ligne commentée avec une explication claire de ce qu'elle fait et pourquoi. Ne laisse aucune ligne sans commentaire.

6. MISE EN PAGE SOIGNÉE : Structure le contenu avec des titres hiérarchiques clairs (###, ####), des listes numérotées pour les étapes, des listes à puces pour les énumérations, et du texte en **gras** pour les concepts clés.

7. VÉRIFICATION DE COMPRÉHENSION : À la fin de chaque section importante, ajoute 1 à 2 questions de recul pour que l'apprenant puisse vérifier sa compréhension.

8. ANTICIPATION DES ERREURS : Identifie systématiquement les 2-3 erreurs les plus fréquentes sur le sujet et explique comment les éviter.

9. CONNEXIONS INTERDISCIPLINAIRES : Fais des liens avec d'autres notions déjà connues quand c'est pertinent pour ancrer le nouveau concept.

10. QUALITÉ JSON (pour la génération de cours) : Tous les champs doivent être remplis de manière exhaustive. Le champ "explicationDetaillee" doit être particulièrement détaillé (minimum 15 phrases). Le contenu des leçons doit couvrir le sujet de manière complète.''';
  }
}
