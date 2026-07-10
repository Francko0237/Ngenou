import 'package:flutter/material.dart';
import '../../core/models/matiere.dart';
import '../../core/models/notion.dart';
import '../../core/models/lecon.dart';
import '../../core/models/exercice.dart';

class MicroOrdiModuleData {
  static final Matiere matiere = Matiere(
    id: 'micro_ordi',
    nom: 'Micro-ordinateur',
    description: "Découvre l'informatique depuis ses bases jusqu'au fonctionnement interne d'un ordinateur : logiciels, matériel, architecture et codage de l'information.",
    icone: Icons.computer_outlined,
    couleur: const Color(0xFF00BCD4),
    isAvailable: true,
    sections: [
      "Introduction & Logiciels",
      "Le Matériel Informatique",
      "Architecture & Codage"
    ],
  );

  static final List<Notion> notions = [
    // --- SECTION 1 ---
    Notion(
      id: 'mo_n1',
      matiereId: 'micro_ordi',
      section: 'Introduction & Logiciels',
      titre: "Introduction à l'Informatique",
      niveau: NiveauNotion.debutant,
      description: "Les bases absolues : qu'est-ce qu'un ordinateur et comment représente-t-il l'information ?",
    ),
    Notion(
      id: 'mo_n2',
      matiereId: 'micro_ordi',
      section: 'Introduction & Logiciels',
      titre: "L'Ordinateur et ses Applications",
      niveau: NiveauNotion.debutant,
      description: "Des super-calculateurs aux smartphones, découvre le rôle des logiciels et progiciels.",
    ),
    Notion(
      id: 'mo_n3',
      matiereId: 'micro_ordi',
      section: 'Introduction & Logiciels',
      titre: "Les Fichiers et Langages Informatiques",
      niveau: NiveauNotion.debutant,
      description: "Comment les données sont stockées et comment les humains communiquent avec la machine.",
    ),
    Notion(
      id: 'mo_n4',
      matiereId: 'micro_ordi',
      section: 'Introduction & Logiciels',
      titre: "Les Périphériques",
      niveau: NiveauNotion.debutant,
      description: "Entrées et sorties : comment l'ordinateur interagit avec le monde extérieur.",
    ),

    // --- SECTION 2 ---
    Notion(
      id: 'mo_n5',
      matiereId: 'micro_ordi',
      section: 'Le Matériel Informatique',
      titre: "L'Unité Centrale et ses Composants",
      niveau: NiveauNotion.intermediaire,
      description: "Voyage au cœur de la machine : CPU, RAM, ROM et BIOS n'auront plus de secrets pour toi.",
    ),
    Notion(
      id: 'mo_n6',
      matiereId: 'micro_ordi',
      section: 'Le Matériel Informatique',
      titre: "Stockage et Carte Mère",
      niveau: NiveauNotion.intermediaire,
      description: "La colonne vertébrale de l'ordinateur et la conservation permanente de tes données.",
    ),
    Notion(
      id: 'mo_n7',
      matiereId: 'micro_ordi',
      section: 'Le Matériel Informatique',
      titre: "Les Bus et la Communication Interne",
      niveau: NiveauNotion.intermediaire,
      description: "Les autoroutes de l'information : comment les composants se parlent à la vitesse de la lumière.",
    ),

    // --- SECTION 3 ---
    Notion(
      id: 'mo_n8',
      matiereId: 'micro_ordi',
      section: 'Architecture & Codage',
      titre: "Architecture de la Mémoire",
      niveau: NiveauNotion.avance,
      description: "Comprends la structuration physique et logique de la mémoire et le calcul des signaux CS.",
    ),
    Notion(
      id: 'mo_n9',
      matiereId: 'micro_ordi',
      section: 'Architecture & Codage',
      titre: "Codage des Entiers",
      niveau: NiveauNotion.avance,
      description: "La magie du binaire : découvre comment l'ordinateur compte, additionne et gère les nombres négatifs.",
    ),
    Notion(
      id: 'mo_n10',
      matiereId: 'micro_ordi',
      section: 'Architecture & Codage',
      titre: "Codage des Nombres Réels — IEEE 754",
      niveau: NiveauNotion.avance,
      description: "La norme universelle pour représenter les nombres à virgule avec une précision fascinante.",
    ),
  ];

  static final List<Lecon> lecons = [
    // NOTION 1
    Lecon(
      id: 'mo_l1_1',
      notionId: 'mo_n1',
      titre: 'Définitions fondamentales',
      contenu: '''
## 1. Informatique
L'**informatique** est la science du traitement **rationnel et automatique** de l'information à l'aide d'un ordinateur.  
Le mot "informatique" est la contraction de "**informa**tion" + "automa**tique**".  
Elle englobe la conception, la programmation, l'utilisation et la maintenance des systèmes informatiques.

## 2. Système Informatique
C'est l'ensemble des moyens logiciels ET matériels nécessaires pour satisfaire un besoin.  
> **Système informatique** = **Matériel** (hardware) + **Logiciels** (software) + **Utilisateurs** (humanware)

## 3. L'Ordinateur
C'est une machine programmable servant au traitement automatique de l'information.  
**Le savais-tu ?** Avant tout traitement, toutes les informations sont converties en binaire (suite de 0 et de 1).
Toutes les communications internes se font par des signaux électriques :
- **0** : signal éteint (absence de courant)
- **1** : signal allumé (présence de courant)

## 4. Bit et Octet
- **BIT (Binary digIT)** : La plus petite unité de mesure de l'information. Un bit ne peut valoir que 0 ou 1.
- **OCTET (BYTE)** : Un groupe de 8 bits forme un octet. C'est l'unité de base pour mesurer la capacité mémoire.

**Multiples :**
- 1 Kilo-octet (Ko) = 1 024 octets
- 1 Méga-octet (Mo) = 1 024 Ko
- 1 Giga-octet (Go) = 1 024 Mo
- 1 Téra-octet (To) = 1 024 Go
      ''',
      explicationDetaillee: "Imagine l'ordinateur comme une immense usine remplie d'ampoules. Chaque ampoule peut être allumée (1) ou éteinte (0). Une seule ampoule, c'est un BIT. Si tu regroupes 8 ampoules ensemble, ça fait un OCTET. En allumant certaines ampoules et en en éteignant d'autres dans un groupe de 8, tu peux créer 256 combinaisons de lumières différentes (assez pour représenter toutes les lettres de l'alphabet, les chiffres, etc.)."
    ),
    Lecon(
      id: 'mo_l1_2',
      notionId: 'mo_n1',
      titre: 'Représentation et numération',
      contenu: '''
## Pourquoi le binaire ?
Les circuits électroniques ne distinguent que deux états physiques : courant présent (1) ou absent (0). C'est pourquoi TOUTE information (texte, image, son) est représentée en binaire.

## Les Bases de Numération

1. **BASE 10 — DÉCIMALE (usage quotidien)** :
   Chiffres : 0 à 9. 
   Exemple : 125 = 1×10² + 2×10¹ + 5×10⁰

2. **BASE 2 — BINAIRE (usage interne)** :
   Chiffres : 0, 1.
   Exemple : 1011(2) = 1×2³ + 0×2² + 1×2¹ + 1×2⁰ = 8+0+2+1 = 11(10)

3. **BASE 16 — HEXADÉCIMALE (usage en programmation)** :
   Chiffres : 0–9 puis A=10, B=11, C=12, D=13, E=14, F=15.
   Exemple : 1F(16) = 1×16¹ + 15×16⁰ = 16 + 15 = 31(10)

## Conversions Essentielles
- **Décimal vers Binaire** : Divisions successives par 2, on lit les restes de bas en haut.
- **Binaire vers Décimal** : Somme des puissances de 2 (1, 2, 4, 8, 16, 32...).
- **Binaire vers Hexa** : On groupe les bits par 4 en partant de la droite. (ex: 1101 0110 → D6)
      ''',
      explicationDetaillee: "Convertir en binaire, c'est comme faire de la monnaie, mais tes pièces valent uniquement 1, 2, 4, 8, 16, 32... \n\nExemple pour faire 13 : \n- Est-ce que je peux utiliser la pièce de 8 ? OUI (il me reste 5).\n- Est-ce que je peux utiliser la pièce de 4 ? OUI (il me reste 1).\n- Est-ce que je peux utiliser la pièce de 2 ? NON.\n- Est-ce que je peux utiliser la pièce de 1 ? OUI.\nRésultat (8,4,2,1) : 1, 1, 0, 1. Donc 13 s'écrit 1101 en binaire !"
    ),

    // NOTION 2
    Lecon(
      id: 'mo_l2_1',
      notionId: 'mo_n2',
      titre: "Types d'ordinateurs",
      contenu: '''
## Différence Programme / Application
- **Programme** : Séquence d'instructions exécutables par un ordinateur.
- **Application** : Programme doté d'une interface utilisateur, orienté pour aider l'humain à accomplir une tâche précise.

## Évolution et Types de machines

1. **MINI-ORDINATEURS (1960–1980)**
Taille entre une armoire et un réfrigérateur. Utilisés dans les universités et labos. Remplacés aujourd'hui par les serveurs.

2. **MICRO-ORDINATEURS (depuis 1975)**
Basés sur un microprocesseur (le cerveau sur une seule puce). Ce sont les PC de bureau, laptops, tablettes, et même nos smartphones !

3. **MACRO-ORDINATEURS (Mainframes)**
Machines très puissantes et sécurisées qui traitent des millions de transactions simultanées. Utilisés par les banques ou les compagnies aériennes.

4. **SUPER-ORDINATEURS**
Les plus puissants au monde, dédiés aux calculs scientifiques (météo, ADN, simulations nucléaires).
      '''
    ),
    Lecon(
      id: 'mo_l2_2',
      notionId: 'mo_n2',
      titre: "Le logiciel et ses caractéristiques",
      contenu: '''
## Qu'est-ce qu'un logiciel ?
Un logiciel (software) est un ensemble de programmes permettant à un ordinateur d'exécuter des tâches. **Sans logiciel, le matériel est une coquille vide.**

**Caractéristiques :** Immatériel, reproductible à l'infini, modifiable et protégé par des droits (licence).

## Deux Grandes Familles

1. **LOGICIELS DE BASE (Le Système d'Exploitation)**
Le chef d'orchestre ! Il gère le matériel (CPU, RAM, écran) et sert d'intermédiaire.
*Exemples : Windows, Linux, macOS, Android.*

2. **LOGICIELS D'APPLICATION**
Ceux que tu utilises tous les jours pour des tâches précises.
*Exemples : Word, Chrome, WhatsApp.*

## Le marché
- **Propriétaires** : Code fermé, souvent payants (Windows).
- **Open Source (Libre)** : Code ouvert, gratuits, modifiables (Linux).
- **Freemium** : Gratuit avec options payantes.
- **SaaS** : Logiciel en ligne par abonnement (Netflix, Google Docs).
      '''
    ),
    Lecon(
      id: 'mo_l2_3',
      notionId: 'mo_n2',
      titre: "Les progiciels",
      contenu: '''
## Le Progiciel
Un progiciel est un logiciel "prêt à l'emploi" vendu en masse. Il n'est pas personnalisé pour un seul client.

### 1. Progiciels Horizontaux
Utilisables par **TOUS**, peu importe le métier.
*Exemples : Word, Excel, Navigateurs Web.*
- **Avantages** : Pas chers, mises à jour fréquentes, faciles à apprendre.
- **Inconvénients** : Trop généraux.

### 2. Progiciels Verticaux
Conçus **SPÉCIFIQUEMENT** pour un secteur ou métier.
*Exemples : Logiciel de pharmacie, logiciel pour hôpital.*
- **Avantages** : Parfaitement adaptés au métier.
- **Inconvénients** : Plus chers, public restreint.

### 3. Logiciels Sur Mesure (Spécifiques)
Développés uniquement pour les besoins d'un **seul** client.
- **Avantages** : Correspond à 100% au besoin.
- **Inconvénients** : Délais longs, extrêmement coûteux.
      '''
    ),

    // NOTION 3
    Lecon(
      id: 'mo_l3_1',
      notionId: 'mo_n3',
      titre: "Fichiers et Données",
      contenu: '''
## Fichiers de Programmes (Exécutables)
Ce sont les fichiers qui contiennent les **instructions** que l'ordinateur doit exécuter. Ils sont illisibles par l'humain.
*Extensions courantes :*
- `.EXE` (Windows)
- `.APK` (Android)
- `.SH` (Linux)

## Fichiers de Données
Ce sont les fichiers créés, lus ou modifiés par toi ou les programmes (le contenu).
*Extensions courantes :*
- `.DOCX` (Texte)
- `.JPG`, `.PNG` (Images)
- `.MP3` (Audio)
- `.MP4` (Vidéo)

*Règle d'or :* Un fichier de données a toujours besoin d'un fichier de programme pour être ouvert !
      '''
    ),
    Lecon(
      id: 'mo_l3_2',
      notionId: 'mo_n3',
      titre: "Les langages informatiques",
      contenu: '''
## La pyramide des langages

1. **Langage Machine (0 et 1)**
Le seul langage que l'ordinateur comprend. Ultra-rapide mais impossible à écrire pour un humain.

2. **Langage Assembleur**
Remplacement des 0 et 1 par de petits mots (ex: `MOV`). Reste très complexe et dépend de chaque processeur.

3. **Langages Évolués (Haut niveau)**
Proches de l'anglais. Ils nécessitent une traduction pour que la machine les comprenne.
- **Compilateur** : Traduit TOUT le code d'un coup avant l'exécution (C, C++).
- **Interpréteur** : Traduit le code ligne par ligne en direct (Python, JS).

4. **Les Frameworks**
Des boîtes à outils énormes qui te donnent une "ossature" pour coder plus vite. (Exemple : **Flutter** utilise le langage Dart !).
      ''',
      explicationDetaillee: "La différence entre un Compilateur et un Interpréteur ? \n\nImagine que tu as un livre en japonais et que tu ne parles que français.\n- **Le compilateur** : C'est un traducteur qui prend le livre entier, le traduit en français, et t'imprime une nouvelle version. Tu n'auras plus jamais besoin du traducteur pour lire ce livre.\n- **L'interpréteur** : C'est un ami bilingue assis à côté de toi. Il lit la première phrase en japonais, te la dit en français, puis lit la deuxième, etc. S'il s'en va, tu ne peux plus lire."
    ),

    // NOTION 4
    Lecon(
      id: 'mo_l4_1',
      notionId: 'mo_n4',
      titre: "Classification des périphériques",
      contenu: '''
## C'est quoi un périphérique ?
C'est tout appareil connecté à l'Unité Centrale pour échanger des informations avec l'ordinateur. C'est grâce à eux que la machine communique avec toi.

**1. Périphériques d'ENTRÉE (Input)**
Ils envoient de l'information VERS l'ordinateur.
*Ex: Clavier, Souris, Microphone, Webcam, Scanner.*

**2. Périphériques de SORTIE (Output)**
Ils reçoivent de l'information DEPUIS l'ordinateur pour te la montrer.
*Ex: Écran, Imprimante, Haut-parleurs.*

**3. Périphériques d'ENTRÉE / SORTIE**
Ils font les deux !
*Ex: Clé USB, Disque Dur Externe, Écran Tactile.*
      '''
    ),
    Lecon(
      id: 'mo_l4_2',
      notionId: 'mo_n4',
      titre: "L'imprimante et le scanner",
      contenu: '''
## Les types d'imprimantes

1. **Jet d'encre** : Projette des gouttelettes d'encre liquide. Peu chère à l'achat, super pour les photos, mais l'encre coûte cher à l'usage.
2. **Laser** : Utilise une poudre (toner) fixée par la chaleur. Plus chère à l'achat, mais ultra rapide et très économique pour le texte (bureaux).
3. **Matricielle** : De petites aiguilles frappent un ruban encreur. Bruyante mais indestructible, parfaite pour les reçus ou factures carbone.
4. **Imprimante 3D** : Superpose des couches de plastique pour créer un objet réel !

## Le Scanner
Il numérise tes feuilles papier en images numériques (Entrée).
Sa précision se mesure en **DPI** (Dots Per Inch = points par pouce). Plus le DPI est élevé, plus l'image sera nette et détaillée (300 DPI est la norme pour une impression propre).
      '''
    ),

    // NOTION 5
    Lecon(
      id: 'mo_l5_1',
      notionId: 'mo_n5',
      titre: "Vue d'ensemble du matériel",
      contenu: '''
## Le Matériel (Hardware)
C'est le corps de l'ordinateur, tout ce que tu peux physiquement toucher ou casser (contrairement aux logiciels).

L'**Unité Centrale (UC)** est la grosse boîte (ou le boîtier du PC portable) qui contient tous les organes vitaux :
- **Le processeur (CPU)** : Le cerveau.
- **La RAM** : La mémoire de travail immédiate.
- **Le Disque dur / SSD** : La mémoire à long terme.
- **La Carte mère** : Le système nerveux qui connecte tout le monde.
- **L'alimentation** : Le cœur qui pompe l'électricité.
      '''
    ),
    Lecon(
      id: 'mo_l5_2',
      notionId: 'mo_n5',
      titre: "Le Microprocesseur (CPU)",
      contenu: '''
## Le Cerveau de la Machine
Le CPU (Central Processing Unit) exécute les programmes à une vitesse folle (mesurée en GHz : des milliards de cycles par seconde).

**Que contient-il ?**
1. **L'UAL (Unité Arithmétique et Logique)** : La calculatrice ! Elle fait les maths (+, -, *, /) et la logique (ET, OU, comparaisons).
2. **L'UCC (Unité de Contrôle)** : Le chef d'orchestre. Il va chercher l'instruction (Fetch), la décode (Decode) et l'exécute (Execute).
3. **Les Registres** : De minuscules mémoires internes ultra-rapides. C'est là que l'UAL pose les nombres pendant qu'elle calcule.
4. **Le Cache (L1, L2, L3)** : Une mémoire d'attente très rapide intégrée au CPU. Elle évite au processeur de perdre du temps à aller chercher les infos dans la RAM.
      ''',
      explicationDetaillee: "Analogie du Cuisinier :\n- **Le CPU** c'est un cuisinier ultra-rapide (UAL) mais qui a besoin qu'on lui lise la recette étape par étape (UCC).\n- **Les Registres**, c'est la planche à découper juste sous ses mains : la place est très limitée, mais c'est immédiat.\n- **Le Cache**, c'est le petit frigo juste à côté de lui. Il y met les ingrédients dont il aura besoin dans 2 minutes.\n- **La RAM**, c'est le grand cellier de l'autre côté de la cuisine. C'est plus grand, mais ça prend plus de temps d'y aller."
    ),
    Lecon(
      id: 'mo_l5_3',
      notionId: 'mo_n5',
      titre: "La Mémoire RAM",
      contenu: '''
## La Mémoire Vive (Random Access Memory)
C'est la salle d'attente de l'ordinateur. Dès que tu ouvres une application (comme ton navigateur Web), le système copie l'application depuis le disque dur vers la RAM, car la RAM est **100x plus rapide** que le disque.

**Ses caractéristiques fondamentales :**
- **Volatile** : Si tu coupes l'électricité, la RAM s'efface TOTALEMENT. C'est pourquoi tu dois "sauvegarder" ton travail sur le disque dur.
- **Accès direct** : Le CPU peut lire la case mémoire n°1 puis la n°1000 instantanément, sans devoir lire celles entre les deux.

**Les Types :**
- **SRAM (Statique)** : Très rapide, très chère. Utilisée dans le Cache du CPU.
- **DRAM (Dynamique)** : Moins chère. Elle perd son électricité en quelques millisecondes et doit être "rafraîchie" en permanence. C'est la RAM classique (DDR4, DDR5).
      '''
    ),
    Lecon(
      id: 'mo_l5_4',
      notionId: 'mo_n5',
      titre: "La Mémoire ROM et le BIOS",
      contenu: '''
## La Mémoire Morte (ROM - Read Only Memory)
Contrairement à la RAM, la ROM n'oublie jamais rien, même quand tu débranches l'ordinateur (Non Volatile). 
Elle est généralement programmée en usine pour être lue et non modifiée.

## Le BIOS / UEFI
C'est le tout premier programme qui s'éveille quand tu appuies sur le bouton d'alimentation ! Il vit dans une puce ROM (ou Flash) sur la carte mère.
**Son rôle :**
1. Faire le POST (Power-On Self-Test) : vérifier que la RAM et le clavier fonctionnent.
2. Éveiller les composants.
3. Chercher Windows (ou Linux/Mac) sur le disque dur et lui passer le relais.

*(Note : L'UEFI est la version moderne du BIOS, offrant une interface avec la souris et un démarrage plus sécurisé).*
      '''
    ),

    // NOTION 6
    Lecon(
      id: 'mo_l6_1',
      notionId: 'mo_n6',
      titre: "Le Disque Dur et Systèmes de fichiers",
      contenu: '''
## Le Stockage
Le lieu où tes photos, jeux et l'OS dorment en sécurité.
- **HDD (Disque Dur Magnétique)** : Des disques métalliques qui tournent très vite avec une tête de lecture mécanique. Moins cher, énorme capacité, mais fragile.
- **SSD (Solid State Drive)** : Des puces mémoire Flash. Zéro pièce mécanique. Ultra-rapide, silencieux et robuste, mais un peu plus cher.

## Systèmes de Fichiers (FAT, NTFS...)
Le disque est comme un immense terrain vague. Pour y retrouver tes affaires, l'ordinateur dessine un quadrillage : c'est le système de fichiers.
- **FAT32** : Vieux format universel, mais bloque si un fichier dépasse 4 Go (impossible d'y mettre un gros film HD).
- **NTFS** : Le standard de Windows, gère la sécurité et les fichiers gigantesques.

**Les Clusters :**
Le disque est divisé en cases appelées "Secteurs" (souvent 512 octets). Le système regroupe ces secteurs en **Clusters** (ex: 4 Ko). Un cluster est la plus petite boîte qu'on peut allouer à un fichier. Même si ton texte pèse 1 octet, il occupera tout le cluster de 4 Ko !
      ''',
      explicationDetaillee: "Si tu formates ta clé USB en FAT32 et que tu essaies de copier une vidéo de 5 Go, Windows te dira 'Espace insuffisant' même si ta clé fait 64 Go ! C'est parce que l'architecture du FAT32 ne peut pas mathématiquement gérer une adresse pour un fichier de plus de 4 Go. La solution ? Reformater la clé en exFAT ou NTFS !"
    ),
    Lecon(
      id: 'mo_l6_2',
      notionId: 'mo_n6',
      titre: "La Carte Mère",
      contenu: '''
## Le système nerveux (Motherboard)
C'est le grand circuit imprimé sur lequel TOUT vient se brancher.
On y trouve :
- Le **Socket** (le nid du CPU).
- Les **Slots RAM**.
- Les **Slots PCIe** (pour brancher les cartes graphiques).
- Les **Ports SATA / NVMe** (pour les disques durs/SSD).

## Le DMA (Direct Memory Access)
Astuce incroyable des ingénieurs : Le DMA.
C'est une puce sur la carte mère qui permet à un périphérique (comme la carte réseau) d'envoyer ses données **directement** dans la RAM, sans déranger le CPU ! Le CPU peut ainsi continuer à calculer tranquillement ton jeu vidéo.
      '''
    ),
    Lecon(
      id: 'mo_l6_3',
      notionId: 'mo_n6',
      titre: "Cartes d'Extension et Alimentation",
      contenu: '''
## Les Cartes d'Extension
Elles se branchent sur les ports PCIe pour ajouter des super-pouvoirs à ton PC :
- **Carte Graphique (GPU)** : Indispensable pour la 3D, les jeux ou l'Intelligence Artificielle.
- **Carte Son, Carte Réseau Wi-Fi...**

## L'Alimentation (PSU)
La prise murale te donne du 220V Alternatif (très dangereux pour l'électronique). 
L'alimentation convertit cela en Courant Continu propre avec des tensions très faibles :
- **+12V** : Pour les gros moteurs (disques, ventilateurs) et la puissance brute (CPU, GPU).
- **+5V / +3.3V** : Pour l'électronique fine (RAM, clés USB, puces).
      '''
    ),

    // NOTION 7
    Lecon(
      id: 'mo_l7_1',
      notionId: 'mo_n7',
      titre: "Les Bus",
      contenu: '''
## Les 3 Autoroutes de l'ordinateur
Un bus est un ensemble de fils conducteurs qui transfèrent les données. Il en existe 3 types qui travaillent toujours ensemble :

1. **Le Bus d'Adresses (Unidirectionnel)**
Le CPU dit "OÙ". Il envoie sur ce bus le numéro de la case mémoire qu'il veut lire ou écrire.
*Formule vitale :* Avec **N** fils, le CPU peut adresser **2^N** cases. (Ex: 32 fils = 4 Go de RAM maximum !).

2. **Le Bus de Données (Bidirectionnel)**
Le "QUOI". C'est ici que voyage le contenu de la case mémoire. La largeur de ce bus (32 ou 64 bits) définit la quantité d'infos transportées d'un seul coup.

3. **Le Bus de Contrôle**
Le "COMMENT". Il transporte les ordres :
- **WE** (Write Enable) : "Je veux Lire" ou "Je veux Écrire"
- **CS** (Chip Select) : "Hé toi, la puce numéro 2, écoute-moi !"
- **CLK** : L'horloge qui synchronise tout le monde.
      ''',
      explicationDetaillee: "Imagine le postier (le CPU) qui doit livrer une lettre (Bus de données). \n1. Il regarde le numéro de la maison sur l'enveloppe et va dans la bonne rue (Bus d'Adresses).\n2. Il sonne à la porte pour réveiller la maison (Signal CS du Bus de Contrôle) et crie 'Je te dépose un colis !' (Signal WE).\n3. Il met la lettre dans la boîte (Bus de Données).\nSi le CPU a un bus d'adresses de 32 bits, il ne sait écrire que 4 milliards d'adresses différentes. Si tu mets 8 Go de RAM, le CPU ne saura tout simplement pas compter jusqu'aux 4 derniers Go !"
    ),

    // NOTION 8
    Lecon(
      id: 'mo_l8_1',
      notionId: 'mo_n8',
      titre: "Organisation de la mémoire",
      contenu: '''
## Anatomie d'une Puce
La mémoire est comme un immense meuble à tiroirs (Cases). Chaque tiroir a un numéro unique (l'Adresse) et contient une certaine taille de données (le Mot mémoire).

**Formule de Capacité :**
`Capacité totale = Nombre de cases × Taille du mot (en bits)`

## Assemblage de Puces
Parfois, on veut fabriquer un PC de 16 Go mais on n'a que des puces de 8 Go. On va les associer !

1. **En Parallèle (Extension du Mot)**
Si tu as deux puces qui stockent 8 bits par case, et que le CPU réclame 16 bits d'un coup, on les branche en parallèle. Le CPU lit la moitié gauche dans la puce 1, et la moitié droite dans la puce 2, en activant les deux avec le **MÊME** signal CS.

2. **En Série (Extension de Capacité)**
Si tu veux deux fois plus de cases. La puce 1 gèrera la première moitié des adresses. Quand l'adresse demandée dépasse la puce 1, on coupe son signal CS et on active le signal CS de la puce 2 !
      '''
    ),
    Lecon(
      id: 'mo_l8_2',
      notionId: 'mo_n8',
      titre: "Calcul du signal CS",
      contenu: '''
## Le rôle critique du CS (Chip Select)
Si toutes les puces mémoires répondaient au CPU en même temps, ce serait un court-circuit total sur le bus de données (embouteillage mortel).
Le décodeur d'adresse regarde les **bits de poids fort** (ceux tout à gauche de l'adresse) pour savoir dans quel "quartier" on se trouve, et envoie le courant `CS = 1` UNIQUEMENT à la puce concernée.

**Exemple :**
Si la mémoire globale fait 1 Mo (20 fils d'adresse de A0 à A19), et que Puce1 fait 512 Ko et Puce2 fait 512 Ko.
- Puce 1 couvre la moitié basse (Adresses commençant par 0...)
- Puce 2 couvre la moitié haute (Adresses commençant par 1...)
Le fil d'adresse A19 sera directement utilisé ! Si A19=0, on active Puce 1. Si A19=1, on active Puce 2.
      ''',
      explicationDetaillee: "C'est un peu comme les codes postaux. Si tu cherches le code 75001, le centre de tri regarde juste le '75' (les bits de poids fort) et sait immédiatement qu'il faut envoyer le camion vers Paris (activer le signal CS de la puce 'Paris'), sans même lire la fin de l'adresse ! C'est ce décodeur matériel ultra-rapide qui permet à l'ordinateur de trouver la bonne puce en un milliardième de seconde."
    ),

    // NOTION 9
    Lecon(
      id: 'mo_l9_1',
      notionId: 'mo_n9',
      titre: "Entiers non signés et signés",
      contenu: '''
## Comment stocker des nombres négatifs ?
En binaire, il n'y a pas de symbole "-". Comment dire à la machine que -5 n'est pas 5 ?
La magie s'appelle le **Complément à 2**.

### Les 3 étapes du Complément à 2 (Ex: Trouver -34 sur 8 bits) :
1. Écrire la valeur positive en binaire : 34 = `0010 0010`
2. **Inverser** tous les bits (Complément à 1) : `1101 1101`
3. **Ajouter 1** au résultat : `1101 1110`

C'est magique : `1101 1110` est la représentation officielle de -34 !
*Preuve : si tu fais 34 + (-34) en binaire, la retenue finale déborde et le résultat donne un 0 parfait !*

**Conséquence :** Sur 8 bits signés, le bit tout à gauche devient le bit de signe (1 = négatif). Tu peux stocker de -128 à +127 (au lieu de 0 à 255).
      '''
    ),
    Lecon(
      id: 'mo_l9_2',
      notionId: 'mo_n9',
      titre: "Opérations binaires et logiques",
      contenu: '''
## L'addition Binaire
C'est comme en décimal, 1+1 fait 2, mais 2 s'écrit `10` en binaire !
- `0 + 0 = 0`
- `0 + 1 = 1`
- `1 + 1 = 0` (et je retiens 1)
- `1 + 1 + retenue = 1` (et je retiens 1)

## Les Portes Logiques (Algèbre de Boole)
Le processeur manipule les données avec ces 4 opérations de base :
- **ET (AND)** : Renvoie 1 SEULEMENT si les deux entrées sont à 1.
- **OU (OR)** : Renvoie 1 si au MOINS UNE entrée est à 1.
- **XOR (OU Exclusif)** : Renvoie 1 si les entrées sont DIFFÉRENTES. (0 XOR 1 = 1).
- **NON (NOT)** : Inverse le bit. (NON 1 = 0).
      '''
    ),

    // NOTION 10
    Lecon(
      id: 'mo_l10_1',
      notionId: 'mo_n10',
      titre: "Virgule flottante",
      contenu: '''
## La norme IEEE 754
Comment stocker 3,14 ou -0,00045 en binaire ? Les ordinateurs utilisent la "virgule flottante" (comme la notation scientifique `3.14 x 10^2`).

**Format sur 32 bits (Simple Précision) :**
- **Bit 31 (1 bit)** : Le Signe (0 pour +, 1 pour -).
- **Bits 30-23 (8 bits)** : L'Exposant biaisé (On y ajoute toujours +127 pour éviter de gérer un exposant négatif).
- **Bits 22-0 (23 bits)** : La Mantisse (les chiffres après la virgule).

L'équation est : `± 1,Mantisse × 2^(Exposant - 127)`
C'est grâce à ça que l'ordinateur peut gérer à la fois les distances galactiques et la taille d'un atome dans la même mémoire !
      '''
    ),
    Lecon(
      id: 'mo_l10_2',
      notionId: 'mo_n10',
      titre: "Fractions binaires",
      contenu: '''
## Convertir 0,X en binaire
Pour la partie après la virgule, on ne divise pas, on MULTIPLIE par 2 !

*Exemple pour 0,625 :*
1. 0,625 × 2 = **1**,25  → Je garde `1`, reste 0,25.
2. 0,25 × 2 = **0**,50   → Je garde `0`, reste 0,5.
3. 0,50 × 2 = **1**,00   → Je garde `1`, reste 0. Terminé !
Résultat : `0,101` en binaire.

## Le problème de l'Infini
Que se passe-t-il avec `0,4` ?
0,4 × 2 = 0,8 (0)
0,8 × 2 = 1,6 (1)
0,6 × 2 = 1,2 (1)
0,2 × 2 = 0,4 (0) ... et la boucle recommence à l'infini ! `0,01100110...`
Comme la mémoire est limitée à 32 ou 64 bits, l'ordinateur doit COUPER le nombre et l'arrondir. C'est pour ça que parfois `0.1 + 0.2 = 0.30000000000000004` en programmation !
      '''
    ),
  ];

  static final List<Exercice> exercices = [
    // --- SECTION 1 (Introduction) ---
    Exercice(
      id: 'mo_ex1',
      notionId: 'mo_n1',
      question: "L'informatique est la science du traitement _____ de l'information.",
      options: [
        "manuel et lent",
        "rationnel et automatique",
        "analogique",
        "visuel"
      ],
      bonneReponseIndex: 1,
      explication: "Définition officielle : traitement rationnel (organisé, logique) et automatique (sans intervention humaine constante).",
    ),
    Exercice(
      id: 'mo_ex2',
      notionId: 'mo_n1',
      question: "Combien de valeurs différentes peut représenter 1 octet ?",
      options: ["8", "16", "128", "256"],
      bonneReponseIndex: 3,
      explication: "1 octet = 8 bits. Chaque bit a 2 états (0 ou 1). Donc 2^8 = 256 combinaisons possibles.",
    ),
    Exercice(
      id: 'mo_ex3',
      notionId: 'mo_n2',
      question: "Quel type d'ordinateur est utilisé par les banques pour traiter des millions de transactions simultanément ?",
      options: [
        "Micro-ordinateur",
        "Mini-ordinateur",
        "Mainframe",
        "Tablette"
      ],
      bonneReponseIndex: 2,
      explication: "Les Mainframes (macro-ordinateurs) sont dédiés à la fiabilité extrême et au traitement massif de données (ex: IBM Z-Series).",
    ),
    Exercice(
      id: 'mo_ex4',
      notionId: 'mo_n2',
      question: "Un progiciel HORIZONTAL est destiné :",
      options: [
        "Uniquement aux comptables",
        "Uniquement aux médecins",
        "À tous les types d'utilisateurs et d'entreprises",
        "Uniquement aux ingénieurs"
      ],
      bonneReponseIndex: 2,
      explication: "Horizontal = usage général. Word et Excel sont utilisables dans tous les secteurs (hôpital, école, garage...).",
    ),
    Exercice(
      id: 'mo_ex5',
      notionId: 'mo_n2',
      question: "Un logiciel sur mesure est :",
      options: [
        "Vendu en grande surface",
        "Développé spécifiquement pour un seul client",
        "Libre et téléchargeable gratuitement",
        "Compatible avec toutes les plateformes"
      ],
      bonneReponseIndex: 1,
      explication: "Sur mesure = développé pour un client précis uniquement. Il est très coûteux mais parfaitement adapté au besoin.",
    ),
    Exercice(
      id: 'mo_ex6',
      notionId: 'mo_n3',
      question: "Un fichier .EXE est un fichier :",
      options: ["Texte", "Image", "Exécutable (programme)", "Audio"],
      bonneReponseIndex: 2,
      explication: ".EXE signifie EXEcutable. Il contient du code binaire directement exécutable sous Windows.",
    ),
    Exercice(
      id: 'mo_ex7',
      notionId: 'mo_n3',
      question: "Quel langage est directement compris par le processeur sans aucune traduction ?",
      options: ["Python", "Java", "Langage machine", "Assembleur"],
      bonneReponseIndex: 2,
      explication: "Le langage machine (0 et 1 purs) est le seul que le silicium comprend nativement. Tous les autres nécessitent un traducteur.",
    ),
    Exercice(
      id: 'mo_ex8',
      notionId: 'mo_n4',
      question: "Le scanner est un périphérique :",
      options: ["De sortie", "D'entrée", "D'entrée/sortie", "De stockage"],
      bonneReponseIndex: 1,
      explication: "Le scanner prend une image du monde réel et l'envoie VERS l'ordinateur. C'est donc une Entrée (Input).",
    ),
    Exercice(
      id: 'mo_ex9',
      notionId: 'mo_n2',
      question: "Un progiciel VERTICAL est :",
      options: [
        "Pour tous les secteurs d'activité",
        "Gratuit et open source",
        "Conçu spécifiquement pour un secteur métier précis",
        "Pour la gestion des fenêtres"
      ],
      bonneReponseIndex: 2,
      explication: "Vertical = spécifique à un métier (ex: logiciel de gestion hospitalière, logiciel pour garagiste).",
    ),
    Exercice(
      id: 'mo_ex10',
      notionId: 'mo_n2',
      question: "Le rôle principal du Système d'Exploitation (SE) est :",
      options: [
        "Créer des documents Word",
        "Gérer le matériel et faire l'intermédiaire avec l'utilisateur",
        "Naviguer sur Internet",
        "Stocker des fichiers sur le disque dur"
      ],
      bonneReponseIndex: 1,
      explication: "Le SE (Windows, Linux, macOS) est le chef d'orchestre : il alloue la RAM, gère le CPU et discute avec les périphériques.",
    ),

    // --- SECTION 2 (Matériel) ---
    Exercice(
      id: 'mo_ex11',
      notionId: 'mo_n5',
      question: "Le processeur (CPU) est composé principalement de :",
      options: [
        "RAM + ROM + Disque dur",
        "UAL + UCC + Registres + Cache",
        "Carte mère + Alimentation + Bus",
        "BIOS + Chipset + Slots PCIe"
      ],
      bonneReponseIndex: 1,
      explication: "UAL (calculs), UCC (contrôle), registres (mémoire interne immédiate), cache (mémoire d'attente rapide) forment le cœur du CPU.",
    ),
    Exercice(
      id: 'mo_ex12',
      notionId: 'mo_n5',
      question: "L'UAL (Unité Arithmétique et Logique) effectue :",
      options: [
        "Le stockage permanent des données",
        "Le démarrage de l'ordinateur",
        "Les calculs mathématiques et les opérations logiques",
        "La gestion des périphériques externes"
      ],
      bonneReponseIndex: 2,
      explication: "L'UAL est la 'calculatrice' interne du CPU : additions, soustractions, comparaisons, ET/OU logiques.",
    ),
    Exercice(
      id: 'mo_ex13',
      notionId: 'mo_n5',
      question: "La RAM est une mémoire :",
      options: [
        "Non volatile, stockage permanent",
        "Volatile, effacée totalement à l'extinction",
        "Lecture seule, non modifiable",
        "Externe, connectée par USB"
      ],
      bonneReponseIndex: 1,
      explication: "RAM = Random Access Memory. Elle est volatile : elle a besoin de courant pour retenir ses données. PC éteint = RAM vide.",
    ),
    Exercice(
      id: 'mo_ex14',
      notionId: 'mo_n5',
      question: "Quelle est la principale différence entre SRAM et DRAM ?",
      options: [
        "La SRAM est plus lente que la DRAM",
        "La DRAM ne nécessite pas de rafraîchissement",
        "La DRAM nécessite un rafraîchissement périodique, pas la SRAM",
        "La SRAM est utilisée comme RAM principale (8 Go)"
      ],
      bonneReponseIndex: 2,
      explication: "DRAM (Dynamic RAM) utilise des condensateurs qui fuient, il faut donc la rafraîchir en permanence. La SRAM (Static RAM) est stable et plus rapide, utilisée pour le Cache.",
    ),
    Exercice(
      id: 'mo_ex15',
      notionId: 'mo_n5',
      question: "Le BIOS est stocké dans :",
      options: ["La RAM", "Le disque dur", "Une mémoire ROM/Flash", "Le cache CPU"],
      bonneReponseIndex: 2,
      explication: "Le BIOS doit survivre à l'extinction du PC, il est donc gravé dans une puce ROM (ou Flash) sur la carte mère.",
    ),
    Exercice(
      id: 'mo_ex16',
      notionId: 'mo_n6',
      question: "Le DMA (Direct Memory Access) permet :",
      options: [
        "D'accélérer le CPU en doublant sa fréquence",
        "Aux périphériques d'accéder à la RAM sans passer par le CPU",
        "De sauvegarder automatiquement",
        "De relier deux cartes mères"
      ],
      bonneReponseIndex: 1,
      explication: "DMA = Transfert direct Périphérique ↔ RAM. Pendant ce temps, le CPU est libéré pour d'autres tâches.",
    ),
    Exercice(
      id: 'mo_ex17',
      notionId: 'mo_n6',
      question: "L'alimentation électrique (PSU) fournit aux composants :",
      options: [
        "Du courant alternatif 220V directement",
        "Du courant continu (3.3V, 5V, 12V)",
        "Un signal d'horloge au processeur",
        "Le réseau Wi-Fi"
      ],
      bonneReponseIndex: 1,
      explication: "Le PSU convertit le dangereux 220V alternatif du mur en tensions continues, faibles et stables (12V, 5V, 3.3V) pour l'électronique.",
    ),
    Exercice(
      id: 'mo_ex18',
      notionId: 'mo_n6',
      question: "SATA signifie :",
      options: [
        "Synchronized Access Terminal Array",
        "Serial Advanced Technology Attachment",
        "System Allocator Transfer Algorithm",
        "Storage And Transmission Adapter"
      ],
      bonneReponseIndex: 1,
      explication: "SATA est l'interface standard qui a remplacé le vieux PATA pour connecter les disques durs et SSD à la carte mère.",
    ),
    Exercice(
      id: 'mo_ex19',
      notionId: 'mo_n6',
      question: "La taille maximale d'un fichier UNIQUE sur une clé USB en FAT32 est :",
      options: ["2 Go", "4 Go", "8 Go", "Illimitée"],
      bonneReponseIndex: 1,
      explication: "FAT32 utilise un pointeur de 32 bits pour la taille du fichier. 2^32 octets = 4 Go maximum par fichier.",
    ),
    Exercice(
      id: 'mo_ex20',
      notionId: 'mo_n7',
      question: "Un bus d'adresse de 20 fils peut adresser au maximum :",
      options: ["512 Ko", "1 Mo", "2 Mo", "4 Mo"],
      bonneReponseIndex: 1,
      explication: "Avec N fils, on adresse 2^N cases. 2^20 = 1 048 576 octets, ce qui équivaut exactement à 1 Méga-octet (Mo).",
    ),

    // --- SECTION 3 (Architecture & Codage) ---
    Exercice(
      id: 'mo_ex21',
      notionId: 'mo_n8',
      question: "Une mémoire 16K × 32 bits a une capacité totale en octets de :",
      options: ["16 Ko", "32 Ko", "64 Kio", "128 Kio"],
      bonneReponseIndex: 2,
      explication: "16 384 cases × 32 bits = 524 288 bits. On divise par 8 pour avoir les octets : 524 288 / 8 = 65 536 octets = 64 Kio.",
    ),
    Exercice(
      id: 'mo_ex22',
      notionId: 'mo_n8',
      question: "Pour adresser 512 Ko (cases de 8 bits), combien de fils d'adresse faut-il ?",
      options: ["16 fils", "17 fils", "18 fils", "19 fils"],
      bonneReponseIndex: 3,
      explication: "512 Ko = 524 288 cases. Log₂(524 288) = 19 fils.",
    ),
    Exercice(
      id: 'mo_ex23',
      notionId: 'mo_n8',
      question: "Le signal CS (Chip Select) d'une puce sert à :",
      options: [
        "Mesurer la capacité",
        "Sélectionner/activer une puce précise parmi plusieurs sur le même bus",
        "Calculer la vitesse",
        "Synchroniser le CPU"
      ],
      bonneReponseIndex: 1,
      explication: "CS 'réveille' une puce spécifique pour qu'elle lise ou écrive sur le bus, évitant que toutes les puces ne parlent en même temps.",
    ),
    Exercice(
      id: 'mo_ex24',
      notionId: 'mo_n9',
      question: "Le complément à 2 de 4BA8(16) sur 16 bits est :",
      options: ["B457", "B458", "4B57", "B468"],
      bonneReponseIndex: 1,
      explication: "Inversion bit par bit : 4(0100) devient B(1011), B(1011) devient 4(0100), A(1010) devient 5(0101), 8(1000) devient 7(0111). Donc B457. On ajoute +1 : B458.",
    ),
    Exercice(
      id: 'mo_ex25',
      notionId: 'mo_n9',
      question: "En complément à 2 sur 8 bits, quelle est la représentation hexadécimale de -34 ?",
      options: ["CE", "DF", "DE", "EE"],
      bonneReponseIndex: 2,
      explication: "+34 en binaire = 00100010 (22h). Inversion = 11011101 (DDh). On ajoute +1 = 11011110 (DEh).",
    ),
    Exercice(
      id: 'mo_ex26',
      notionId: 'mo_n9',
      question: "111010(2) + 100110(2) en binaire donne :",
      options: ["1011000", "1100000", "1010100", "1110010"],
      bonneReponseIndex: 1,
      explication: "58 (décimal) + 38 (décimal) = 96. Et 96 s'écrit 1100000 en binaire.",
    ),
    Exercice(
      id: 'mo_ex27',
      notionId: 'mo_n9',
      question: "La porte logique '1 ET 0' vaut :",
      options: ["1", "0", "Indéfini", "2"],
      bonneReponseIndex: 1,
      explication: "La porte ET (AND) n'est vraie (1) que si TOUTES ses entrées sont vraies (1). 1 ET 0 donne donc 0.",
    ),
    Exercice(
      id: 'mo_ex28',
      notionId: 'mo_n9',
      question: "L'opération '0 XOR 1' (OU Exclusif) vaut :",
      options: ["0", "1", "2", "Indéfini"],
      bonneReponseIndex: 1,
      explication: "XOR (OU Exclusif) renvoie 1 si les bits sont strictement DIFFÉRENTS. 0 est différent de 1, donc ça donne 1.",
    ),
    Exercice(
      id: 'mo_ex29',
      notionId: 'mo_n10',
      question: "En IEEE 754 simple précision (32 bits), le biais de l'exposant est de :",
      options: ["63", "127", "128", "255"],
      bonneReponseIndex: 1,
      explication: "L'exposant occupe 8 bits. Le biais mathématique est 2^(8-1) - 1 = 127. Cela permet d'avoir des exposants négatifs sans bit de signe.",
    ),
    Exercice(
      id: 'mo_ex30',
      notionId: 'mo_n10',
      question: "La représentation binaire de la fraction décimale 0,4 est :",
      options: [
        "Un nombre fini de bits (exact)",
        "Impossible à calculer",
        "Un nombre infini périodique",
        "Toujours 0"
      ],
      bonneReponseIndex: 2,
      explication: "0,4 x 2 = 0,8 | 0,8 x 2 = 1,6 | 0,6 x 2 = 1,2 | 0,2 x 2 = 0,4... La boucle est infinie ! L'ordinateur doit donc l'arrondir.",
    ),
  ];

  static List<Lecon> getLeconsByNotion(String notionId) {
    return lecons.where((l) => l.notionId == notionId).toList();
  }

  static List<Exercice> getExercicesByNotion(String notionId) {
    return exercices.where((e) => e.notionId == notionId).toList();
  }
}
