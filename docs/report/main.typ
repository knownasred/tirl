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
appliquer une procédure donnée et de produire une sortie. Les entrées et sorties peuvent être de n'importe quel type,
qu'il s'agisse de chiffres, de chaînes de caractères, de pixels d'une image...

Le paradigme de métaprogrammation consiste à créer un programme prenant une entrée (nombre, chaîne de caractères, type,
voire même du code) et retournant du code en sortie.

Ce paradigme est présent dans de nombreux langages de programmation, car il permet de répondre à la question suivante :
_"Je veux que ma structure de données fonctionne pour n'importe quel truc"_. En Java, on vous montrera #raw(
  "List<T>",
  lang: "Java",
) pour tout #raw("T", lang: "Java"). Ces types génériques sont une forme de métaprogrammation. C'est un programme (dans
ce cas une fonction) qui prend comme paramètre le type générique et retourne une version de la structure de données
spécifique au type fourni. Cela s'appelle un type *monomorphisé*.

Par conception, ces fonctionnalités génériques sont très limitées dans de nombreux langages afin de garder une bonne
lisibilité. Dans ce cas, une autre question se pose : "Comment faire si ce que je veux faire n'est pas supporté par les
génériques ?" Cette question se pose souvent dans des cas où il est impossible de représenter le paramètre comme un
type. Par exemple, comment faire une version optimisée d'une matrice de taille $N times M$ en Java ?


Plusieurs solutions sont possibles, en fonction du langage. Dans ce rapport, nous allons nous focaliser sur un seul
langage, *Zig*, afin de comprendre son approche, très différente de celle d'autres langages.

= Présentation de Zig

Zig est un langage généraliste permettant de maintenir des programmes robustes, optimaux et réutilisables. Il a été créé
en 2016 par Andrew Kelley @noauthor_introduction_nodate et a pour objectif d'être :
- Pragmatique : le langage doit aider à faire quelque chose de mieux que tous les autres langages
- Optimal : si on écrit du code de la manière la plus naturelle, il doit permettre d'obtenir une performance équivalente
  (ou meilleure) que C.
- Safe : tant que cela ne compromet pas l'optimalité du code, le rendre le plus clair possible.
- Lisible : mettre l'accent sur la facilité de lecture plutôt que sur la facilité d'écriture.

== `comptime`, le successeur du pré-processeur ?

Pour atteindre ces objectifs, la décision a été prise de ne pas mettre en place de pré-processeur pour Zig, mais plutôt
d'utiliser un *évaluateur d'expressions constantes* @noauthor_zig_nodate, qui va exécuter du code Zig à la compilation
et stocker le résultat pour être utilisé à l'exécution.

Grâce à cette fonctionnalité, les deux exemples de code (en C et en Zig) sont équivalents :

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

Cette capacité d'exécuter du code est présente dans de nombreux langages. Même Rust est en train d'ajouter le support de
cette fonctionnalité. Cependant, Zig est un des rares langages à supporter le type `type`.

== `type`, le type de types

La pièce manquante pour la métaprogrammation est de créer un nouveau type en fonction de paramètres d'entrée. En Zig,
cela est possible grâce au type nommé `type`. Ce type est une variable comme un nombre dans le langage, il est donc
possible de l'assigner à une variable, de le fournir en paramètre à une fonction, ou, ce qui nous intéresse, de le
retourner d'une fonction.

Voici donc comment créer une liste générique en Zig :


#codly(
  highlighted-lines: (8,),
)
```zig
fn List(T: type) type {
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
`list`. Vu que nous avons la quasi-totalité du langage à notre disposition dans ces fonctions #footnote[Toutes les
  fonctionnalités du langage liées à l'entrée/sortie, ou spécifiques à la machine sont volontairement désactivées afin
  de garder des builds hermétiques.], il est possible de faire ce que les génériques ne nous laissaient pas faire :

```zig
fn Matrix2D(
  comptime x: i32, comptime y: i32, comptime t: type) type {
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
connue à la compilation, afin que le compilateur puisse exécuter à la compilation cette fonction retournant un type. Si
elle n'est pas connue, le compilateur lève une erreur.

== La gestion explicite de mémoire

Zig est souvent défini comme étant "un meilleur C", et cela est très probablement dû au fait que la mémoire doit être
gérée manuellement, au contraire d'autres langages dont la mémoire est gérée par le langage, tels que Rust ou Go.

Cependant, les créateurs de Zig ont pensé à améliorer un peu l'expérience, grâce aux mots-clés `defer` et `errdefer`,
qui exécutent du code une fois que l'exécution sort du scope dont il provient.

Un autre choix très apprécié vient du fait qu'il n'y a pas d'allocateur global défini en Zig : chaque fonction allouant
la mémoire prend un paramètre du type `allocator`. Cela permet, par exemple, de définir un allocateur d'arène pour
chaque requête plutôt que d'effectuer plusieurs `malloc` et `free`.

= Tirl

Tirl, notre format de définition de scène, s'inscrit donc dans ce contexte, avec son moteur de rendu. Beaucoup de
moteurs de rendu commerciaux utilisent C++ (RenderMan @noauthor_renderman_nodate, Moonray @noauthor_moonray_nodate), et
beaucoup d'exemples utilisent C @peter_shirley_ray_2025 ou C++ @pharr_physically_2023. Des implémentations dans d'autres
langages ont été tentées par le passé, mais la performance laisse à désirer, car il est nécessaire de contrôler les
allocations afin de garantir une certaine performance.

Zig répond donc à ces soucis, avec beaucoup moins de footguns #footnote[Il y aura toujours des footguns car le langage
  est d'abord optimisé pour l'optimalité (les use after free sont possibles par exemple), mais tout sera mieux que C ou
  C++ sans les smart pointers.
]. Nous avons donc choisi de l'utiliser pour tester si cela fait une différence.

== Un format de définition de scène?

Chaque moteur de rendu prenant des décisions d'architecture différentes (Moonray @noauthor_moonray_nodate et Redshift
@noauthor_redshift_nodate) ont une approche totalement différente, par exemple), chacun a son format spécifique pour le
rendu. Cependant, un standard est apparu en 2012 chez Pixar, USD. Il a depuis été rendu open source et est devenu
l'outil principal pour la définition de scène.ys

Même si l'intégration d'OpenUSD @noauthor_usd_nodate dans Zig (via une délégation Hydra @noauthor_usd_nodate-1) est un
problème intéressant, cela ne permettrait pas de mettre en avant les capacités de Zig. Nous avons donc choisi de créer
un format de définition de scène personnalisé, inspiré par USD mais plus condensé dans son format texte : Tirl.

Zig rendra cette implémentation claire et lisible, tout en restant performant, grâce à ses capacités d'exécution de code
à la compilation. En effet, il est possible d'unroll la boucle de matching de type (celle qui choisit, par exemple,
entre une `Camera` ou une `Sphere`) à la compilation grâce à `inline for`, permettant d'obtenir une performance
équivalente à un switch sans avoir à l'écrire à la main.

Voici un exemple de format de scène :
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

Cette version reste très simplifiée, et en fonction du temps disponible, d'autres fonctionnalités telles que
l'intégration de textures dans le document ou via référence seraient intéressantes.

== Mais aussi un moteur de rendu

Avoir un format de définition de scène est intéressant, mais le faire en isolation est la garantie d'obtenir un système
ne répondant pas aux besoins ou avec un impact sur la performance élevé.

L'objectif est donc de créer un moteur de rendu simplifié (via l'illumination directe ainsi que des shadow rays) mais
sans le rajout d'estimations de Monte-Carlo ou d'autres fonctionnalités trop complexes pour le temps mis à disposition.

L'objectif final est de pouvoir obtenir une image de la forme suivante (tirée du tutoriel RayTracingInOneWeekend):

#figure(
  image("assets/result-1.jpg"),
  caption: [Exemple de scène rendue par le raytracer (tirée du livre Ray Tracing in One Weekend
    @peter_shirley_ray_2025)],
)

#pagebreak()

#bibliography("zotero.bib", full: true)
