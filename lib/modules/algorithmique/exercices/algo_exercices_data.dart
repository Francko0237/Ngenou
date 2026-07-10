import '../../../core/models/exercice.dart';

class AlgoExercicesData {
  static final List<Exercice> exercices = [
    // NOTION 1 - Intro
    Exercice(
      id: 'algo_n1_e1', notionId: 'algo_n1', type: TypeExercice.qcm,
      question: "Qu'est-ce qu'un algorithme ?",
      choixQcm: ["Un langage de programmation complet", "Une suite d'instructions précises pour résoudre un problème", "Un composant matériel du PC", "Un virus informatique"],
      reponseAttendue: "Une suite d'instructions précises pour résoudre un problème",
      explication: "L'algorithmique est un langage indépendant des langages informatiques (Python/Java), c'est un schéma de réflexion.",
    ),
    Exercice(
      id: 'algo_n1_e2', notionId: 'algo_n1', type: TypeExercice.qcm,
      question: "Quelle instruction est utilisée pour afficher un résultat ?",
      choixQcm: ["Lire", "Ecrire", "←", "Retourner"],
      reponseAttendue: "Ecrire",
      explication: "Ecrire() affiche à l'écran, tandis que Lire() écoute l'utilisateur.",
    ),
    Exercice(
      id: 'algo_n1_e3', notionId: 'algo_n1', type: TypeExercice.qcm,
      question: "Quelles sont deux propriétés fondamentales attendues d'un bon algorithme ?",
      choixQcm: ["Fini et Précis", "Lent et Aléatoire", "Infini et Dynamique", "Complexe et Magique"],
      reponseAttendue: "Fini et Précis",
      explication: "Un algorithme doit être Fini (s'arrêter un jour) et les instructions doivent être Précises (non-ambiguës).",
    ),

    // NOTION 2 - Variables
    Exercice(
      id: 'algo_n2_e1', notionId: 'algo_n2', type: TypeExercice.qcm,
      question: "Quelle est la valeur numérique finale de x ?\n\nx ← 3\nx ← x + 2",
      choixQcm: ["3", "5", "2", "6"],
      reponseAttendue: "5",
      explication: "x vaut initialement 3. Ensuite, x + 2 (soit 3 + 2 = 5) est rangé de nouveau dans x.",
    ),
    Exercice(
      id: 'algo_n2_e2', notionId: 'algo_n2', type: TypeExercice.qcm,
      question: "Quel type permet de stocker le texte 'Bonjour' ?",
      choixQcm: ["Entier", "Réel", "Chaîne", "Booléen"],
      reponseAttendue: "Chaîne",
      explication: "Une Chaîne (de caractères) sert à stocker tout bloc de texte.",
    ),
    Exercice(
      id: 'algo_n2_e3', notionId: 'algo_n2', type: TypeExercice.editeur,
      question: "Déclare une variable entière 'x', affecte-lui 10, et affiche 'x'.",
      codeInitial: "Algorithme MonAffichage\nVar\n   // compléter\nDébut\n   \nFin",
      reponseAttendue: "Non applicable (évalué visuellement ou validé lors de l'exécution)",
      explication: "Il faut :\nVar x : Entier;\nDébut\n  x ← 10\n  Ecrire(x)\nFin",
    ),

    // NOTION 3 - Conditions
    Exercice(
      id: 'algo_n3_e1', notionId: 'algo_n3', type: TypeExercice.qcm,
      question: "Que fait précisément le bloc 'Sinon' ?",
      choixQcm: ["Le chemin suivi si la condition est Fausse", "Vérifier une autre expression mathématique", "Détruire la variable existante", "Provoquer une boucle infinie"],
      reponseAttendue: "Le chemin suivi si la condition est Fausse",
      explication: "C'est l'alternative par défaut lorsque la condition initiale n'est pas remplie.",
    ),
    Exercice(
      id: 'algo_n3_e2', notionId: 'algo_n3', type: TypeExercice.editeur,
      question: "Demande un entier à l'utilisateur, et affiche 'Positif' s'il est > 0, sinon 'Negatif ou nul'.",
      codeInitial: "Algorithme VerifSigne\nVar n: Entier;\nDébut\n   Lire(n)\n   // conditions à compléter\nFin",
      reponseAttendue: "",
      explication: "Si (n > 0) Alors Ecrire('Positif') Sinon Ecrire('Negatif ou nul') FinSi",
    ),
    Exercice(
      id: 'algo_n3_e3', notionId: 'algo_n3', type: TypeExercice.qcm,
      question: "Quelle est la règle qui différencie l'opérateur ET de l'opérateur OU ?",
      choixQcm: ["ET exige que TOUTES les conditions soient vraies", "OU exige que TOUTES les conditions soient vraies", "ET suffit d'une condition vraie", "Ils fonctionnent de la même manière"],
      reponseAttendue: "ET exige que TOUTES les conditions soient vraies",
      explication: "Avec le [ET], la totalité des conditions doivent être correctes en même temps (Vrai). Avec le [OU], il suffit qu'au moins une condition le soit.",
    ),

    // NOTION 4 - Boucles
    Exercice(
      id: 'algo_n4_e1', notionId: 'algo_n4', type: TypeExercice.qcm,
      question: "Quelle boucle de base s'exécute toujours AU MOINS une fois quoi qu'il arrive ?",
      choixQcm: ["Pour ... à", "Tant que ... Faire", "Répéter ... Jusqu'à", "Aucune des trois"],
      reponseAttendue: "Répéter ... Jusqu'à",
      explication: "Puisque la condition 'Jusqu'à' se trouve à la toute fin du bloc d'instructions, tout ce qui précède aura été lu par l'ordinateur au minimum une fois.",
    ),
    Exercice(
      id: 'algo_n4_e2', notionId: 'algo_n4', type: TypeExercice.editeur,
      question: "Afficher les nombres pairs de 1 à 20 inclus.",
      codeInitial: "Algorithme Pairs\nVar i: Entier;\nDébut\n   \nFin",
      reponseAttendue: "",
      explication: "Pour i ← 1 à 20 Faire\n  Si (i MOD 2 = 0) Alors\n    Ecrire(i)\n  FinSi\nFinPour",
    ),
    Exercice(
      id: 'algo_n4_e3', notionId: 'algo_n4', type: TypeExercice.qcm,
      question: "Dans le pseudo-code de la boucle 'Pour i ← 1 à 5', est-il normal de modifier 'i' à la main avec 'i ← i + 1' dans la boucle ?",
      choixQcm: ["Oui toujours, c'est obligatoire.", "Seulement si i est impair.", "Surtout pas, la boucle gère déjà l'incrémentation automatiquement.", "C'est pareil, aucune importance."],
      reponseAttendue: "Surtout pas, la boucle gère déjà l'incrémentation automatiquement.",
      explication: "Contrairement au Tant Que, la boucle Pour incrémente ou décrémente son itérateur interne de manière transparente. Les modifier soi-même mène à des bogues.",
    ),

    // NOTION 5 - Tableaux
    Exercice(
      id: 'algo_n5_e1', notionId: 'algo_n5', type: TypeExercice.qcm,
      question: "Comment lit-t-on le contenu de la 3ème case ou élément d'un tableau T ?",
      choixQcm: ["T(3)", "T[3]", "T{3}", "T-3"],
      reponseAttendue: "T[3]",
      explication: "L'indice d'une case d'un tableau se place toujours systématiquement entre crochets dans la majorité absolue des langages algorithmiques.",
    ),
    Exercice(
      id: 'algo_n5_e2', notionId: 'algo_n5', type: TypeExercice.editeur,
      question: "Tableau de 5 élèves : Calcule et affiche la somme des notes se trouvant dans les cases du Tableau tab. (tab[1] = 10, tab[2] = 12 ... tab[5] = 15).",
      codeInitial: "Algorithme SommeTab\nVar\n   tab : Tableau[1..5] de Entier\n   somme, i: Entier\nDébut\n   tab[1]←10  tab[2]←12  tab[3]←8  tab[4]←14  tab[5]←15\n   somme ← 0\n   \nFin",
      reponseAttendue: "",
      explication: "Pour i ← 1 à 5 Faire\n somme ← somme + tab[i]\nFinPour\nEcrire(somme)",
    ),
    Exercice(
      id: 'algo_n5_e3', notionId: 'algo_n5', type: TypeExercice.qcm,
      question: "Que risque-t-il de se produire en tentant de lire T[6] d'un tableau allant seulement de 1 à 5 ?",
      choixQcm: ["Une erreur 'Index hors limites' (Plantage)", "L'ordinateur va lire le premier élément à la place", "Une nouvelle case T[6] sera créée automatiquement", "L'ordinateur lira un 0 par défaut"],
      reponseAttendue: "Une erreur 'Index hors limites' (Plantage)",
      explication: "L'ordinateur va signaler une erreur de débordement, plus connue sous le nom 'Index Hors Limites du Tableau'.",
    ),

    // NOTION 6 - Fonctions
    Exercice(
      id: 'algo_n6_e1', notionId: 'algo_n6', type: TypeExercice.qcm,
      question: "Quelle est la différence fondamentale et primordiale entre la Fonction et la Procédure ?",
      choixQcm: ["La Fonction retourne un résultat/une valeur, la procédure n'en retourne aucune.", "La Fonction ne peut pas avoir de paramètres.", "Une procédure n'utilise pas de ressources CPU.", "La procédure s'écrit obligatoirement en fin de script."],
      reponseAttendue: "La Fonction retourne un résultat/une valeur, la procédure n'en retourne aucune.",
      explication: "Une Procédure n'utilise jamais l'instruction finale 'Retourner [QuelqueChose]', elle se contente d'exécuter des requêtes à la chaîne silencieusement.",
    ),
    Exercice(
      id: 'algo_n6_e2', notionId: 'algo_n6', type: TypeExercice.editeur,
      question: "Écris une fonction addition(a, b) retournant l'addition des deux nombres.",
      codeInitial: "Fonction addition(a : Entier, b : Entier) : Entier\nDébut\n  \nFin",
      reponseAttendue: "",
      explication: "La solution attendue est tout simplement Retourner a + b;",
    ),
    Exercice(
      id: 'algo_n6_e3', notionId: 'algo_n6', type: TypeExercice.qcm,
      question: "Une variable déclarée exclusivement à l'intérieur d'une procédure ou d'une fonction est dite...",
      choixQcm: ["Locale (elle disparaît à la fin)", "Globale (elle est partagée partout)", "Ephémère", "Statique"],
      reponseAttendue: "Locale (elle disparaît à la fin)",
      explication: "Une variable locale n'appartient qu'à la fonction, son champ d'action s'achève à l'apparition de l'instruction 'Fin' de cette même fonction.",
    ),

    // NOTION 7 - Récursivité
    Exercice(
      id: 'algo_n7_e1', notionId: 'algo_n7', type: TypeExercice.qcm,
      question: "Dans le paradigme des algorithmes récursifs, qu'est-ce que le 'Cas de base' ?",
      choixQcm: ["Le démarrage du PC", "La condition évidente et terminale où la fonction arrête de s'appeler elle-même", "Le bloc principal du programme global", "Une boucle infinie autorisée"],
      reponseAttendue: "La condition évidente et terminale où la fonction arrête de s'appeler elle-même",
      explication: "C'est la solution instantanée (par ex : la factorielle de 1 ou 0 est simplement 1). C'est ce qui évite que l'ordinateur tourne en boucle à l'infini.",
    ),
    Exercice(
      id: 'algo_n7_e2', notionId: 'algo_n7', type: TypeExercice.qcm,
      question: "Si une fonction récursive ne possède aucun 'cas de base' pour s'arrêter... comment va s'achever l'application ?",
      choixQcm: ["Plantage définitif (Stack Overflow)", "Elle tournera sagement en arrière-plan", "Elle supprimera vos fichiers", "Le compilateur optimisera la boucle"],
      reponseAttendue: "Plantage définitif (Stack Overflow)",
      explication: "La pile des appels finira inévitablement débordée, et l'application informatique se figera ou provoquera systématiquement un crash sec !",
    ),
    Exercice(
      id: 'algo_n7_e3', notionId: 'algo_n7', type: TypeExercice.editeur,
      question: "A la fin d'une certaine exécution, sachant que Fonction Double(n) retourne n*2 , et que Fonction Super(n) retourne Double(Double(n)), que renverra l'appel Super(5) ?",
      codeInitial: "Algorithme Resolution\nDébut\n   Ecrire(4 * 5)\nFin",
      reponseAttendue: "",
      explication: "20",
    ),

    // NOTION 8 - Tris
    Exercice(
      id: 'algo_n8_e1', notionId: 'algo_n8', type: TypeExercice.qcm,
      question: "Quelle est malheureusement la Complexité temporelle théorique pure du Tri à Bulles dans le pire cas imaginable ?",
      choixQcm: ["O(n)", "O(n²)", "O(log n)", "O(n!)"],
      reponseAttendue: "O(n²)",
      explication: "La formule est quadratique car on imbrique deux vastes boucles de rang 'n' complètes (la boucle POUR, qui possède à l'intérieur une deuxième boucle POUR).",
    ),
    Exercice(
      id: 'algo_n8_e2', notionId: 'algo_n8', type: TypeExercice.qcm,
      question: "Lequel de ces tris est intuitivement le plus pertinent et approprié pour trier manuellement cinq cartes à jouer dans une main en moins de quelques secondes ?",
      choixQcm: ["Tri par insertion", "Tri à bulles", "Tri rapide", "Tri de shell"],
      reponseAttendue: "Tri par insertion",
      explication: "Il agit organiquement avec une liste de cartes pré-existantes : l'humain tire la 3ème par rapport à sa propre 2ème... C'est ce qu'on appelle mécaniquement le tri d'insertion.",
    ),
    Exercice(
      id: 'algo_n8_e3', notionId: 'algo_n8', type: TypeExercice.editeur,
      question: "Affiche ces nombres dans l'ordre croissant manuellement en code avec 3 variables, sans utiliser les algorithmes avancés : 30, 10, 20.",
      codeInitial: "Algorithme Ordonner\nVar a,b,c : Entier;\nDébut\n   Ecrire(10, 20, 30)\nFin",
      reponseAttendue: "",
      explication: "Cette question fait office de bac à sable basique.",
    ),

    // NOTION 9 - Recherche
    Exercice(
      id: 'algo_n9_e1', notionId: 'algo_n9', type: TypeExercice.qcm,
      question: "Le puissant modèle fondamental de Recherche Dichotomique nécessite obligatoirement que l'ensemble du tableau concerné soit originellement ___",
      choixQcm: ["Rempli de textes exclusivement", "Dédoublé", "Vide de toutes données", "Préalablement trié complétement de haut en bas"],
      reponseAttendue: "Préalablement trié complétement de haut en bas",
      explication: "C'est effectivement ce postulat de base fondamental absolu qui lui garantit mathématiquement le droit de 'considérer la moitié' tout le temps. Si un numéro 8 est mal formaté à l'adresse logique 2, on ne pourra plus se fier aux autres calculs !",
    ),
    Exercice(
      id: 'algo_n9_e2', notionId: 'algo_n9', type: TypeExercice.qcm,
      question: "Pour chercher exceptionnellement le nom 'Arthur' dans seulement soixante dossiers très désordonnés situés sur le sol... Quelle méthode devons-nous employer ?",
      choixQcm: ["La recherche séquentielle (Linéaire)", "La recherche dichotomique", "Le Tri à Bulles", "Une Intelligence Artificielle"],
      reponseAttendue: "La recherche séquentielle (Linéaire)",
      explication: "Trier les soixante pauvres fiches va s'avérer logistiquement très chronophage juste pour une seule recherche... Explorer du début à la fin (Linéaire) est plus simple exceptionnellement.",
    ),
    Exercice(
      id: 'algo_n9_e3', notionId: 'algo_n9', type: TypeExercice.editeur,
      question: "Chercher l'indice et l'afficher du nombre 5 : [1,5,7,9] en linéaire.",
      codeInitial: "Algorithme SearchBox\nVar T: Tableau[1..4] de Entier;\nDébut\n   T[1]←1 T[2]←5 T[3]←7 T[4]←9\n   // Rendre Index 2\nFin",
      reponseAttendue: "",
      explication: "Ecrire(2)",
    ),

    // NOTION 10 - Complexité
    Exercice(
      id: 'algo_n10_e1', notionId: 'algo_n10', type: TypeExercice.qcm,
      question: "Pour n = 1 000 000, l'informatique montre formellement que l'algorithme incontesté le plus apte et expressément viable sera de type purement  : ",
      choixQcm: ["O(log n) (dichotomique, etc)", "O(n) (linéaire traditionnel usuel)", "O(n²) (procédé quadratique et bulles exponentielles)", "O(1) (accès unitaire divin complet aux bases)"],
      reponseAttendue: "O(log n) (dichotomique, etc)",
      explication: "O(1) est inatteignable pour de la recherche pure exhaustive sans dictionnaire / hashmap pré-compilée sur mesures en cloud . Le seul grand concurrent mathématique qui l'emporte sur O(n) est indéniablement et objectivement la Logarithmique (O(log n)).",
    ),
    Exercice(
      id: 'algo_n10_e2', notionId: 'algo_n10', type: TypeExercice.qcm,
      question: "Dans le vocabulaire universel de l'informatique, l'évaluation du temps (ou complexité) que prendra un code est formellement notée avec la lettre :",
      choixQcm: ["La lettre O majuscule (Grand O)", "La notation Temps(n)", "Le symbole Oméga", "L'estimation de Turing"],
      reponseAttendue: "La lettre O majuscule (Grand O)",
      explication: "Cela s'appelle formellement et officiellement : La légendaire notation du Grand 'O' de complexité (Big O Notation).",
    ),
    Exercice(
      id: 'algo_n10_e3', notionId: 'algo_n10', type: TypeExercice.qcm,
      question: "Le Big-O O(1) sous-entend d'emblée un fait essentiel absolu et catégorique quant à la vitesse...",
      choixQcm: ["Que plus il y a de donnés, plus le temps de code évolue et flambe violemment .", "Que le temps d'exécution prend une base temporelle totalement fixe", "Qu'un calcul requerra obligatoirement 1 heure réelle à lui seul", "Qu'il est le plus long."],
      reponseAttendue: "Que le temps d'exécution prend une base temporelle totalement fixe",
      explication: "Même face à un tableau contenant physiquement plus de trois trilliards d'informations non formatées, accéder via la magie directe O(1) à la toute première cellule demandera éternellement des micro-secondes très minimes.",
    ),
  ];
}
