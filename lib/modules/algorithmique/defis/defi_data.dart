import '../../../core/models/defi.dart';

class DefiData {
  static final List<Defi> defis = [
    Defi(
      id: 'defi_n1',
      matiereId: 'algo',
      titre: "Le Rituel de Politesse",
      description: "Écrivez un algorithme nommé Bonjour qui demande à l'utilisateur de saisir son nom à l'aide de Lire() et qui affiche \"Bonjour [nom]\" à l'aide de Ecrire().\nExemple : si le nom saisi est \"Alice\", l'algorithme doit afficher \"Bonjour Alice\".",
      codeInitial: '''Algorithme Bonjour;
Var
   nom : Chaine;
Debut
   
Fin''',
      tests: [
        DefiTest(inputs: ["Alice"], expectedOutput: "Bonjour Alice"),
        DefiTest(inputs: ["Bob"], expectedOutput: "Bonjour Bob"),
      ],
    ),
    Defi(
      id: 'defi_n2',
      matiereId: 'algo',
      titre: 'Le Plus Grand',
      description: "Écrivez un algorithme nommé Maximum qui demande à l'utilisateur de saisir deux nombres entiers au clavier (à l'aide de deux appels à Lire()). Affichez uniquement le plus grand des deux nombres à l'aide de Ecrire().",
      codeInitial: '''Algorithme Maximum;
Var
   a, b : Entier;
Debut
   
Fin''',
      tests: [
        DefiTest(inputs: ["10", "20"], expectedOutput: "20"),
        DefiTest(inputs: ["50", "5"], expectedOutput: "50"),
        DefiTest(inputs: ["-5", "-2"], expectedOutput: "-2"),
      ],
    ),
    Defi(
      id: 'defi_n3',
      matiereId: 'algo',
      titre: "Somme d'un tableau",
      description: "Le tableau T de 3 entiers est déjà déclaré et pré-rempli avec les valeurs 5, 10 et 15. Écrivez la suite de l'algorithme pour calculer et afficher uniquement la somme de ces 3 entiers à l'aide de Ecrire().",
      codeInitial: '''Algorithme SommeTab;
Var
   T : Tableau[1..3] de Entier;
   i, somme : Entier;
Debut
   T[1] ← 5; T[2] ← 10; T[3] ← 15;
   somme ← 0;
   
Fin''',
      tests: [
        DefiTest(inputs: [], expectedOutput: "30"),
      ],
    )
  ];
}
