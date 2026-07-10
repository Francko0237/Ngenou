import '../../../core/models/notion.dart';
import '../../../core/models/lecon.dart';

class AlgoCoursData {
  static final List<Notion> notions = [
    Notion(id: 'algo_n1', matiereId: 'algo', titre: 'Introduction à l\'Algorithmique', niveau: NiveauNotion.debutant, description: 'Les bases de l\'algorithmique et son utilité.'),
    Notion(id: 'algo_n2', matiereId: 'algo', titre: 'Variables et Types de données', niveau: NiveauNotion.debutant, description: 'Stocker et manipuler des informations.'),
    Notion(id: 'algo_n3', matiereId: 'algo', titre: 'Les Conditions', niveau: NiveauNotion.debutant, description: 'Prendre des décisions dans le code.'),
    Notion(id: 'algo_n4', matiereId: 'algo', titre: 'Les Boucles', niveau: NiveauNotion.debutant, description: 'Répéter des actions efficacement.'),
    Notion(id: 'algo_n5', matiereId: 'algo', titre: 'Les Tableaux', niveau: NiveauNotion.intermediaire, description: 'Gérer des collections de données.'),
    Notion(id: 'algo_n6', matiereId: 'algo', titre: 'Fonctions et Procédures', niveau: NiveauNotion.intermediaire, description: 'Modulariser votre code.'),
    Notion(id: 'algo_n7', matiereId: 'algo', titre: 'La Récursivité', niveau: NiveauNotion.intermediaire, description: 'Des fonctions qui s\'appellent elles-mêmes.'),
    Notion(id: 'algo_n8', matiereId: 'algo', titre: 'Algorithmes de Tri', niveau: NiveauNotion.avance, description: 'Ordonner des données de plusieurs façons.'),
    Notion(id: 'algo_n9', matiereId: 'algo', titre: 'Algorithmes de Recherche', niveau: NiveauNotion.avance, description: 'Trouver rapidement un élément.'),
    Notion(id: 'algo_n10', matiereId: 'algo', titre: 'Complexité et Optimisation', niveau: NiveauNotion.avance, description: 'Rendre vos algorithmes performants.'),
  ];

  static final List<Lecon> lecons = [
    // NOTION 1
    Lecon(id: 'algo_l1_1', notionId: 'algo_n1', titre: 'Qu\'est-ce qu\'un algorithme ?', contenu: '''### Définition formelle
Un **algorithme** est une suite finie et précise d'instructions permettant de résoudre un problème ou d'obtenir un résultat.

Le mot vient du mathématicien perse **Al-Khwârizmî**. C'est la base absolue de toute l'informatique : avant même d'écrire la moindre ligne de code (manipulation d'un langage), on doit concevoir l'algorithme.

### Une analogie simple
Une **recette de cuisine** est un excellent exemple d'algorithme !
- **Les ingrédients** : Les données d'entrée (Inputs)
- **Les étapes de la recette** : Les instructions précises
- **Le plat final** : Le résultat rendu (Output)

### Les 3 propriétés fondamentales
- **Fini** : Il doit impérativement s'arrêter au bout d'un moment.
- **Clair et Non-ambigu** : Chaque étape doit être parfaitement définie (Pesez "200g de farine", et non pas "mettez de la farine").
- **Général** : Un algorithme doit pouvoir résoudre tout un groupe de problèmes similaires.

L'algorithmique permet d'apprendre à réfléchir de manière logique indépendamment de tout langage de programmation.'''),
    Lecon(id: 'algo_l1_2', notionId: 'algo_n1', titre: 'Structure d\'un algorithme', contenu: '''Un algorithme complet s'écrit souvent en trois grandes parties :

```
Algorithme MonPremierAlgo      // 1. En-tête : Nom
Var
   // 2. Déclarations : on liste les variables
Début
   // 3. Corps : Les instructions pas à pas
Fin
```

Le mot **Début** marque le point de départ de l'exécution et **Fin** marque l'arrêt.'''),
    Lecon(id: 'algo_l1_3', notionId: 'algo_n1', titre: 'Entrée / Sortie', contenu: '''Pour interagir avec l'utilisateur, on utilise deux instructions essentielles :

**Lire(variable)** : Demande à l'utilisateur de saisir une information au clavier.
**Ecrire(texte)** : Affiche un résultat à l'écran.

*Exemple pratique :*
```
Algorithme Bonjour
Var
   prenom : Chaîne ;
Début
   Ecrire("Comment t'appelles-tu ?")
   Lire(prenom)
   Ecrire("Bonjour ", prenom, " !")
Fin
```'''),

    // NOTION 2
    Lecon(id: 'algo_l2_1', notionId: 'algo_n2', titre: 'Qu\'est-ce qu\'une variable ?', contenu: '''Imaginez une **variable** comme une boîte avec une étiquette dessus. Elle permet de conserver une donnée en mémoire. 
Chaque variable a un **Type** précis, qui définit ce qu'on peut mettre dans la boîte :
- **Entier** : Un nombre sans virgule (ex: 5, -12).
- **Réel** : Un nombre à virgule (ex: 3.14).
- **Chaîne** : Du texte (ex: "Bonjour").
- **Caractère** : Une seule lettre (ex: 'A').
- **Booléen** : Vrai ou Faux.'''),
    Lecon(id: 'algo_l2_2', notionId: 'algo_n2', titre: 'L\'affectation', contenu: '''On utilise le symbole **←** pour ranger une valeur dans notre boîte (variable). Cela se lit "reçoit".

*Exemples :*
```
age ← 18     // La variable 'age' reçoit la valeur 18
prix ← 12.5  // 'prix' reçoit 12.5
```

⚠️ Attention : L'affectation se fait toujours de la **droite vers la gauche**.
`x ← x + 1` signifie qu'on prend l'ancienne valeur de x, on ajoute 1, et on range le tout dans x.'''),
    Lecon(id: 'algo_l2_3', notionId: 'algo_n2', titre: 'Les expressions', contenu: '''Une expression est un calcul combinant des valeurs et des variables à l'aide d'opérateurs.

**Opérateurs mathématiques standards :**
+ (Addition), - (Soustraction), * (Multiplication), / (Division classique).

**Opérateurs spéciaux (sur Entiers) :**
- **DIV** : Donne le quotient entier d'une division (ex: 10 DIV 3 = 3)
- **MOD** : Donne le reste de la division entière (ex: 10 MOD 3 = 1)'''),

    // NOTION 3
    Lecon(id: 'algo_l3_1', notionId: 'algo_n3', titre: 'Si ... Alors', contenu: '''Les conditions permettent de ne pas exécuter tout le code, mais seulement une partie selon une situation précise.

Imaginez au quotidien : *Si il pleut, Alors je prends un parapluie.*

*Syntaxe en algo :*
```
Si (age >= 18) Alors
   Ecrire("Vous êtes majeur.")
FinSi
```
Le bloc entre "Alors" et "FinSi" n'est exécuté que si la condition est `Vrai`.'''),
    Lecon(id: 'algo_l3_2', notionId: 'algo_n3', titre: 'Si ... Alors ... Sinon', contenu: '''Si on a une alternative (soit l'un, soit l'autre), on ajoute **Sinon**.

```
Si (nombre MOD 2 = 0) Alors
   Ecrire("Nombre pair")
Sinon
   Ecrire("Nombre impair")
FinSi
```

L'avantage est clair : l'ordinateur emprunte un seul des deux chemins. Il n'y aura jamais les deux d'affichés !'''),
    Lecon(id: 'algo_l3_3', notionId: 'algo_n3', titre: 'Conditions multiples', contenu: '''Parfois, une seule question ne suffit pas. On utilise alors les opérateurs logiques **ET** (toutes les conditions doivent être vraies), **OU** (au moins une condition vraie) et **NON** (l'inverse de la condition).

```
Si (moyenne >= 10 ET absence < 5) Alors
   Ecrire("Année validée")
FinSi
```

Dans cet exemple, l'élève rate son année si sa moyenne est inférieure à 10, **ou** s'il a dépassé 4 absences, car les DEUX critères devaient être respectés.'''),

    // NOTION 4
    Lecon(id: 'algo_l4_1', notionId: 'algo_n4', titre: 'Tant que ... Faire', contenu: '''Une boucle sert à **répéter** une ou plusieurs instructions.
La boucle `Tant que` répète l'instruction tant que la condition reste vraie.

*Exemple (Compter jusqu'à 3):*
```
i ← 1
Tant que (i <= 3) Faire
   Ecrire(i)
   i ← i + 1
FinTantQue
```

⚠️ **Attention :** Il faut toujours s'assurer que la condition deviendra fausse à un moment donné, sinon c'est la redoutée "Boucle Infinie" !'''),
    Lecon(id: 'algo_l4_2', notionId: 'algo_n4', titre: 'Pour ... à ... Faire', contenu: '''Si vous savez **exactement** combien de fois répéter le bloc, la boucle `Pour` est idéale.
Elle s'occupe de créer un "compteur" automatiquement.

*Exemple (Afficher "Bonjour" 5 fois):*
```
Pour i ← 1 à 5 Faire
   Ecrire("Bonjour")
FinPour
```
C'est souvent utilisé pour parcourir une liste précise.'''),
    Lecon(id: 'algo_l4_3', notionId: 'algo_n4', titre: 'Répéter ... Jusqu\'à', contenu: '''Contrairement au `Tant Que` qui vérifie la condition *avant* d'exécuter, la boucle `Répéter` fait l'action au moins une fois, puis vérifie la condition *après*.

*Notion clé pédagogique :* Elle s'arrête dès que la condition devient **Vraie**.

```
Répéter
   Ecrire("Tapez un code PIN valide (4 chiffres) :")
   Lire(pin)
Jusqu'à (pin >= 1000 ET pin <= 9999)
```'''),

    // NOTION 5
    Lecon(id: 'algo_l5_1', notionId: 'algo_n5', titre: 'Déclarer un tableau', contenu: '''Oubliez les variables pour ranger 100 notes d'élèves une par une ! Un **Tableau** est une grande armoire avec des "tiroirs" numérotés qui peuvent tous contenir le même type de données.

*Forme Standard :*
```
Var
   T : Tableau[1..5] de Entier ;
```
Ce tableau possède 5 tiroirs. Pour accéder au tiroir numéro 3, on écrit `T[3]`.
`T[3] ← 15` range 15 dans la troisième case du tableau T.'''),
    Lecon(id: 'algo_l5_2', notionId: 'algo_n5', titre: 'Parcourir un tableau', contenu: '''Pour lire ou afficher toutes les cases d'un tableau, associez un tableau à une boucle `Pour` !

*Calculer la somme des éléments d'un tableau T de taille 5 :*
```
somme ← 0
Pour i ← 1 à 5 Faire
   somme ← somme + T[i]
FinPour
Ecrire("La somme est : ", somme)
```'''),
    Lecon(id: 'algo_l5_3', notionId: 'algo_n5', titre: 'Rechercher le maximum', contenu: '''Comment trouver la meilleure note dans le tableau ?
L'astuce : supposer que la 1ère case est le maximum, puis comparer avec toutes les autres.

```
max ← T[1]
Pour i ← 2 à 5 Faire
   Si (T[i] > max) Alors
      max ← T[i]
   FinSi
FinPour
Ecrire("Le maximum est ", max)
```'''),

    // NOTION 6
    Lecon(id: 'algo_l6_1', notionId: 'algo_n6', titre: 'Les Sous-Programmes', contenu: '''Lorsque votre algorithme devient immense, il faut le découper en petits morceaux, réutilisables à volonté :
- **Fonction** : Un sous-programme qui agit comme une calculatrice, on lui donne des données, elle renvoie **UN SEUL RÉSULTAT**.
- **Procédure** : Un sous-programme qui fait un ensemble d'actions (ex: afficher un beau menu) mais ne renvoie aucun résultat au programme principal.'''),
    Lecon(id: 'algo_l6_2', notionId: 'algo_n6', titre: 'Syntaxe de la Fonction', contenu: '''Une fonction prend souvent des **paramètres** (variables d'entrées).

```
Fonction Carré(n : Entier) : Entier
Début
   Retourner n * n ;
Fin
```
Pour l'utiliser plus tard dans le code : `resultat ← Carré(5)`. `resultat` vaudra alors 25.'''),
    Lecon(id: 'algo_l6_3', notionId: 'algo_n6', titre: 'Portée locale et globale', contenu: '''Les variables déclarées **à l'intérieur** d'une fonction (Variables Locales) n'existent **que** pendant que la fonction tourne. Elles sont détruites à la fin.

Si le programme principal a une variable "x" et la fonction aussi, ce sont deux boîtes différentes qui portent par hasard la même étiquette. Changer la boîte `x` de la fonction ne changera pas la boîte `x` principale !'''),

    // NOTION 7
    Lecon(id: 'algo_l7_1', notionId: 'algo_n7', titre: 'Qu\'est-ce que la récursivité ?', contenu: '''Une technique fascinante : une fonction **récursive** est une fonction... qui s'appelle elle-même ! 

A l'image des poupées russes, la fonction résout un problème complexe en le transformant en un problème plus petit. 

⚠️ **Essentiel** : Elle DOIT avoir une condition d'arrêt facile à résoudre (le "Cas de base"), sinon elle s'appellera pour l'éternité et causera un plantage.'''),
    Lecon(id: 'algo_l7_2', notionId: 'algo_n7', titre: 'Exemple : La Factorielle', contenu: '''La factorielle de N, notée N!, c'est N x (N-1) x ... x 1.
Mais on peut aussi dire que N! c'est `N * Factorielle(N - 1)`.

```
Fonction Factorielle(n : Entier) : Entier
Début
   Si (n = 1 OU n = 0) Alors
      Retourner 1 ; // C'est le cas de base !
   Sinon
      Retourner n * Factorielle(n - 1) ;
   FinSi
Fin
```'''),
    Lecon(id: 'algo_l7_3', notionId: 'algo_n7', titre: 'Avantages et Inconvénients', contenu: '''**Avantage** : Le code est extrêmement élégant, très proche des mathématiques. Idéal pour explorer des arbres ou des structures complexes.

**Inconvénient** : Cela prend plus de mémoire car chaque appel (chaque poupée russe que l'on ouvre) doit être mis en pause jusqu'à ce que la petite dernière soit résolue. Pour de grands nombres, la boucle `Pour` est souvent plus performante.'''),

    // NOTION 8
    Lecon(id: 'algo_l8_1', notionId: 'algo_n8', titre: 'Le Tri à bulles', contenu: '''Mettre de l'ordre dans des données ("Trier") est capital en informatique.
Le Tri à bulles fait remonter "par bulles" les plus grandes valeurs vers la fin de la liste.
On compare chaque élément avec son voisin de droite. S'il est plus grand, on l'échange avec lui.

*Complexité* : Mauvaise sur les grandes listes (notée O(n²)).'''),
    Lecon(id: 'algo_l8_2', notionId: 'algo_n8', titre: 'Exemple de Tri à bulles', contenu: '''Voici l'algorithme complet :
```
Pour i ← 1 à taille-1 Faire
   Pour j ← 1 à taille-i Faire
      Si (T[j] > T[j+1]) Alors
         temp ← T[j]
         T[j] ← T[j+1]
         T[j+1] ← temp
      FinSi
   FinPour
FinPour
```
`temp` est une variable temporaire indispensable pour intervertir deux valeurs sans en "écraser" une.'''),
    Lecon(id: 'algo_l8_3', notionId: 'algo_n8', titre: 'Tri par Insertion', contenu: '''Le Tri par insertion imite la façon dont un joueur de cartes trie sa main. 
Il prend une carte, et la recule dans le tableau "vers la gauche" jusqu'à ce qu'elle trouve sa place légitime parmi celles déjà triées.

C'est beaucoup plus performant qu'un tri à bulles sur une liste presque triée dès le départ.'''),

    // NOTION 9
    Lecon(id: 'algo_l9_1', notionId: 'algo_n9', titre: 'Recherche Linéaire', contenu: '''C'est la recherche la plus basique. On cherche le chiffre 7 dans un tableau : on ouvre chaque case de la première à la dernière. Dès qu'on tombe dessus, on s'arrête.

*Problème* : Si on a un annuaire téléphonique de 5 millions de personnes, et que l'on cherche "Zoro", il y aura près de 5 millions de vérifications. Ce n'est pas viable.'''),
    Lecon(id: 'algo_l9_2', notionId: 'algo_n9', titre: 'Recherche Dichotomique', contenu: '''**Pré-requis absolu** : Le tableau doit obligatoirement être DÉJÀ TRIÉ.

Si le tableau est trié (ex: 1, 3, 5, 7, 9, 11), on regarde direct au milieu. C'est 5.
Si on cherche 9, on sait avec certitude que 9 est à droite de 5 ! 
On coupe donc le tableau en deux et on ignore toute la moitié gauche.
À l'étape suivante, on recoupe la moitié restante en deux. Les recherches sont ultra-rapides. C'est du "Diviser pour Régner".'''),

    // NOTION 10
    Lecon(id: 'algo_l10_1', notionId: 'algo_n10', titre: 'La Complexité (Grand O)', contenu: '''L'informatique ne regarde pas avec un chronomètre. Un PC rapide exécutera mal un algo, et inversement.
On utilise la notion de la Fonction de coût asymptotique, notée `O(x)`.

- **O(1)** : Temps constant (immédiat, peu importe la taille des données).
- **O(n)** : Temps linéaire (si on a 10 fois plus de données à chercher, on prend 10 fois plus de temps. Ex: Recherche simple).
- **O(n²)** : Temps quadratique (10 fois plus de données = 100 fois plus lent. Catastrophique à grande échelle. Ex: Tri à bulles).
- **O(log n)** : Temps logarithmique (Extrêmement optimal. Ex: Recherche dichotomique).'''),
  ];
}
