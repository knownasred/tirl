
#import "@preview/basic-report:0.4.0": *
#import "@preview/codly:1.3.0": *

#import "@preview/codly-languages:0.1.1": *
#show: codly-init.with()

#codly(languages: codly-languages + (tirl: (name: "Tirl", color: rgb("#347FC4"), icon: [])), aliases: ("tirl": "c"))

// Documenter le paradigme ; expliquer comment le langage va y répondre ; présenter les motivations du choix ; établir le cahier des charges prévisionnel de l’implémentation

#show: it => basic-report(
  doc-category: "PLM",
  doc-title: "Rapport Intermédiaire - Tirl, un format de définition de Scène en Zig avec la métaprogrammation",
  author: "Valentin Ricard
Aurélien Richard",

  affiliation: "HEIG-VD",
  language: "fr",
  compact-mode: true,
  it,
)

= Introduction

Depuis que Turing a formalisé ce que signifie _calculer_, la programmation est l'art de traiter des entrées, leur
appliquer une procédure donnée, et de produire une sortie. Les entrées et sorties peuvent être de n'importe quel type,
qu'elles soient des chiffres, des chaines de caractères, des pixels d'une image...

Le paradigme de métaprogrammation est le fait de créer un programme prennant une entrée (nombre, chaine de caractères,
type, voir même du code), et retournant du code en sortie.

Ce paradigme est présent dans de nombreux languages de programmation, car elle premet de répondre a la question
suivante: _"Je veut que ma structure de donnée fonctionne pour n'importe quel truc"_. En Java, on vous montrera #raw(
  "List<T>",
  lang: "Java",
) pour tout #raw("T", lang: "Java"). Ces types génériques sont une forme de métaprogramming. C'est un programme (dans ce
cas une fonction), qui prend comme paramètre le type générique, et retoune une version de la structure données
spécifique au type fourni. Cela s'appelle un type *monomorphisé*.

Par design, ces fonctionnalités génériques sont très limités dans de nombreux languages, afin de garder une lisibilité.
Dans ce cas, une autre question se pose: "Comment faire si ce que je veut faire n'est pas supporté par les génériques?".
Cette question se pose souvant dans des cas ou il est impossible de représenter le paramètre comme un type. Par exemple,
comment faire une version optimisée de matrice de toute taille $N times M$ en Java?

Plusieurs solutions sont possibles, en fonction du language. Dans ce rapport, nous allons nous focaliser sur un seul
language, *Zig*, afin de comprendre son approche, très différentes d'autres languages.

Une fois le language présenté, nous pourrons aller plus en détails sur les objectifs de Tirl, et pourquoi Zig est le
language parfait pour un format de définition de scène, ainsi que son moteur de rendu.


= Présentation de Zig

Zig est un language généraliste permettant de maintenir des programmes robustes, optimaux, et réutilisables. Il a été
créé en 2016 par Andrew Kelley, et a pour objectif d'être:
- Pragmatique: Le language doit aider a faire quelque chose de mieux que tous les autres languages
- Optimal: Si on écrit du code de la manière la plus naturelle, elle doit permettre d'obtenir une performance
  équivalente (ou meilleure) que C.
- Safe: Tant que cela ne compromet pas l'optimalité du code, le rendre le plus clair possible.
- Lisible: Mettre l'accent sur la facilité de lecture plutot que la facilité d'écriture.

== `comptime`, le sucesseur du pré-processeur?

Pour atteindre ces objectifs, la décision a éré prise de ne pas mettre en place de pré-processeur pour Zig, mais plutot
d'utiliser un *évaluateur d'expression constantes*, qui va executer du code Zig a la compilation, et stocker le résultat
pour être utilisé à l'execution.

Grâce a cette fonctionnalité, les deux exemples de code (en C, et en Zig), sont équivalents:

#columns(2)[
  #set text(size: 0.95em)
  ```cxx
  #define MAX_MESSAGES 64
  struct MessageQueue {
    Message[MAX_MESSAGES] queue;
  }
  ```

  #colbreak()

  ```zig
  const max_messages = 64;
  const MessageQueue = struct {
    queue: [max_messages]Message
  }
  ```
]

Cette capacité d'executer du code est présente dans de nombreux languages. Même Rust est en train de rajouter le support
de cette fonctionnalité dans le language. Cependant, Zig est un des rares languages (autre que Terra, et Mojo) a
supporter le type `type`.

== `type`, ou le type de types

La pièce manquante pour la métaprogrammation, est le fait de pouvoir créer un nouveau type en fonction de paramètre
d'entrée. En Zig, cela est possible grace au type nommé `type`. Ce type est une variable comme un nombre dans le
language, il est donc possible de les assigner a une variable, les fournir en paramètre a une fonction, ou, ce qui nous
intéresse, le retourner d'une fonction.

Voici donc comment créer une liste générique en Zig:


#codly(
  highlighted-lines: (8,),
)
```zig
fn List(comptime T: type) type {
    return struct {
        items: []T,
        len: usize,
    };
}

var list = List(i32) {
    .items = &buffer,
    .len = 0,
};
```

On voit bien en ligne 8 que le type retourné par la fonction `List` est utilisé pour créer une nouvelle instance dans
`list`. Vu que nous avons la quasi-totalité du language a notre disposition dans ces fonctions #footnote[Toutes les
  fonctionnalité du languages lié a l'entrée/sortie, ou spécifique a la machine sont volontairement désactivés afin de
  garder des builds hermétiques.], il est possible de faire ce que les génériques ne nous laissaient pas faire:

```zig
fn Matrix2D(x: i32, y: i32, t: type) type {
  return struct {
    inner: [y][x]t,
  };
}

// On peut avoir 2 types de matrices en parallèle,
// bonne chance pour le faire en C

const mat1: ?Matrix2D(4,3,i32) = null;
const mat2: ?Matrix2D(5,2,f64) = null;

```

Dans cet exemple, le mot clé `comptime` est important. Il permet d'indiquer au compilateur que cette valeur *doit* être
connue à la compilation, afin que le compilateur puisse executer à la compilation cette fonction retournant un type. Si
elle n'est pas connue, le compilateur lève une erreur.

== La gestion explicite de mémoire

Zig est souvent défini comme étant "un meilleur C", et cela est très probablement dû au fait que la mémoire doit être
gérée manuellement, a l'instar d'autres languages dont la mémoire est gérée par le language, tel que Rust ou Go.

Cependant, les créateurs de Zig ont pensé a améliorer un peu l'expérience, grâce aux mots clés `defer` et `errdefer`,
qui executent du code une fois que l'execution sort du scope dont il provient.

Un autre choix très apprécié vient du fait qu'il n'y a pas d'allocateur global défini en Zig, chaque fonction allouant
la mémoire prend un paramètre du type `allocator`. Cela permet par exemple de définir un allocateur d'arrène pour chaque
requête, plutot que d'effectuer plusieurs `malloc` et `free`.

= Tirl

C'est donc dans ce contexte que s'inscrit Tirl, notre format de définition de scène, ainsi que son moteur de rendu.
Beaucoup de moteurs de rendu commercials utilisent C++ (#link("https://renderman.pixar.com")[Renderman], #link(
  "https://openmoonray.org/",
)[Moonray]), et beaucoup d'exemples utilisent C (#link(
  "https://raytracing.github.io/books/RayTracingInOneWeekend.html",
)[Raytracing in a Weekend]), ou C++ (#link("https://www.pbrt.org/")[PBRT]). Des implémentations en d'aures languages ont
été tentées par le passé, mais la performance laisse a désirer, car il est nécessaire de contrôler les allocations afin
de garantir une certaine performance.

Zig répondant donc a ces soucis, avec beaucoup moins de footguns #footnote[Il y aura toujours des footguns car le
  language est d'abord optimisé pour l'optimalité (les use after free sont possibles par exemple), mais tout sera mieux
  que C ou C++ sans les smart pointers.
], il est donc intéressant d'évaluer les avantages d'utiliser des languages plus modernes par rapport a ces languages
plus établis.

== Un format de définition de scène?

Chaquemoteur de rendu prenant des décision d'architecture différente (Moonray et #link(
  "https://www.maxon.net/en/redshift",
)[Redshift] ont une approche totalement différente par exemple), chacun a son format spécifique pour le rendu.
Cependant, un standard est apparu en 2012 chez Pixar, USD. Il a depuis été rendu opensource, et est devenu l'outil
principal pour la définition de scène.

Même si l'intégration d'OpenUSD dans Zig (via une délégation Hydra) est un problème intéressant, cela ne permettrait pas
de mettre en avant les capacités de Zig. Nous avons donc choisi de créer un format de définition de scène personnalisé,
inspiré par USD, mais étant plus condensé dans son format texte: Tirl.

Zig rendra cette implémentation claire et lisible, tout en restant performant, grâce a ces capacités d'execution de code
a la compilation. En effet, il est possible d'unroll la boucle de matching de type (Choisie entre une `Camera` ou une
`Sphere`) a la compilation grâce a `inline for`, permettant d'obtenir une performance équivalente a un switch, sans
avoir a l'écrire a la main.

Voici un exemple de format de scène:
```tirl
Camera {
  Position: (1.0,2,4.2)
  LookingAt: (4.2,5,50)
}

Sphere {
    Position: (1,3,4)
    Scale: (4,1,1)
    Material: Simple {
        Color: #11ff11
        Reflectance: 0.85
    }
}
```

Cette version reste très simplifiée, et en fonction du temps disponnible, d'autres fonctionnalités tel que l'intégration
de textures dans le document ou via référence serait intéressant.

== Mais aussi un moteur de rendu

Avoir un format de définition de scène est intéressant, mais le faire en isolation est la garantie d'obtenir un système
ne répondant pas aux besoins, ou avec un impact sur la performance élevé.

L'objectif est donc de créer un moteur de rendu simplifié (via l'illumination directe, ainsi que des shadow rays), mais
sans le rajout d'estimations de monte-carlo, ou autres fonctionnalités trop complexe pour le temps mis a disposition.

L'objectif final est de pouvoir obtenir une image de la forme suivante (tirée du tutoriel RayTracingInOneWeekend):

#figure(
  image("assets/result-1.jpg"),
  caption: "Exemple de scène rendue par le raytracer (tirée du livre Ray Tracing in one Weekend)",
)

#pagebreak()

#bibliography("zotero.bib", full: true)
