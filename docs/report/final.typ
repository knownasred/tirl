#import "@preview/basic-report:0.4.0": *
#import "@preview/codly:1.3.0": *
#import "@preview/codly-languages:0.1.1": *
#show: codly-init.with()

#import "@preview/fletcher:0.5.8" as fletcher: diagram, edge, node

#import "@preview/iconify:0.5.3": icon, provide-icons
#provide-icons(json("assets/lucide.json"))
#provide-icons(json("assets/lucide-lab.json"))

#codly(languages: codly-languages + (tirl: (name: "Tirl", color: rgb("#347FC4"), icon: [])), aliases: ("tirl": "c"))

#show: it => basic-report(
  doc-category: "PLM",
  doc-title: "Rapport Final - Tirl, un format de définition de Scène en Zig avec la métaprogrammation",
  author: "Valentin Ricard
Aurélien Richard",

  affiliation: "HEIG-VD",
  datetime-fmt: "[year]-[month]-[day]",
  language: "fr",
  compact-mode: true,
  it,
)

/*
Documenter l’implémentation et l’architecture logicielle, tout en restant focalisé sur le paradigme ;
Retour d’expérience, autant sur le paradigme que sur le langage ;
Une conclusion.

Le rapport final, dans l'idéal, ne devrait pas excéder 7 pages. Le rapport intermédiaire peut y être référencé et peut être fourni en annexe. Toutefois, si le rapport intermédiaire contiendrait des erreurs ou serait incomplet, le complément doit figurer dans le rapport final.
*/

= Introduction

Les logiciels de rendu sont considérés comme nécessitant beaucoup de puissance de calcul en parallèle. Des optimisations
mineures, tel que le précalcul d'indexes, ou la génération d'une table de lookup, prennent beaucoup plus d'ampleur quand
la fonction est appelée plusieurs milliards de fois lors de l'exécution d'un programme. Tirl cherche donc à prouver que
des outils de métaprogrammation, tels que comptime, permettent de prendre en charge la complexité algorithmique qui
aurait autrement été payée à l'exécution. Ce rapport présente les mécanismes qui ont permis cette approche, et montre
comment les choix de conception de Zig l'ont rendu facile.

= Architecture

#align(center, diagram(
  node-stroke: 0.8pt,
  node-corner-radius: 3pt,
  spacing: (3em, 1.2em),

  // States: on the sides, with a light blue fill
  let state-fill = rgb("#e8f0fe"),

  // Processes: in the center, with a light orange fill
  let process-fill = rgb("#fef3e8"),

  // Scene file (left)
  node((0, 0), width: 14em, fill: state-fill, [
    #[
      #set text(size: 0.4em)
      #codly(
        header: none,
        display-name: false,
        display-icon: false,
        zebra-fill: none,
        number-format: none,
        stroke: none,
        default-color: white,
      )
      #set raw(theme: "./assets/Monokai.tmTheme")
      #show raw: it => block(
        fill: rgb("#1d2433"),
        inset: 8pt,
        radius: 5pt,
        text(fill: rgb("#a2aabc"), it),
      )
      ```js
      Camera "Camera" {
          lookFrom: Vec3(0, 0, 0),
          lookAt: Vec3(0, 0, -1),
          vup: Vec3(0, 1, 0),
          vfov: 90,
          aspectRatio: 1.77,
          imageWidth: 400,
          samplesPerPixel: 100,
          maxDepth: 50,
          defocusAngle: 4,
          focusDistance: 1,
      }
      ```
    ]
    #v(-1em)
    Définition de scène (.scene)
  ]),

  // Parser (center)
  edge((0, 0), (1, 1), "-|>"),
  node((1, 1), fill: process-fill, shape: circle, [#icon("lucide-lab:reel-thread") \ Combinateurs / \ Parseurs]),

  // AST (right)
  edge((1, 1), (2, 2), "-|>"),
  node((2, 2), fill: state-fill, shape: rect, [#icon("lucide:list-tree") \ Abstract Syntax \ Tree (AST)]),

  // Interpreter (center)
  edge((2, 2), (1, 3), "-|>"),
  node((1, 3), fill: process-fill, shape: circle, [#icon("lucide:notebook-pen") \ Interpréteur]),

  // Scene format (left)
  edge((1, 3), (0, 4), "-|>"),
  node((0, 4), fill: state-fill, shape: rect, [#icon("lucide:earth") \ Représentation de \ scène]),

  // Renderer (center)
  edge((0, 4), (1, 5), "-|>"),
  node((1, 5), fill: process-fill, shape: circle, [#icon("lucide:aperture") \ Moteur de \ rendu]),

  // Final image (right)
  edge((1, 5), (2, 6), "-|>"),
  node((2, 6), fill: state-fill, shape: rect, [
    #image("./assets/output.png", width: 7em)
    Image finale
  ]),
))

Afin de rendre ce projet modulaire, et d'aider à travailler en équipe plus efficacement, le projet est sectionné en
plusieurs parties communiquant via des schémas de données distincts.

Cela a aussi pour avantage de segmenter clairement les parties du code utilisant majoritairement de la métaprogrammation
(combinateurs de parseurs, interpréteur), du moteur de rendu, qui utilise de la programmation impérative plus
traditionnelle.

Tout d'abord, la définition de scène (.scene) est lue et convertie en AST via les combinateurs de parseurs, qui peut
être ensuite fourni à l'interpréteur, afin d'être converti en représentation de scène, qui peut enfin être consommée par
le moteur de rendu pour obtenir une image détaillée, qui est sauvegardée sur disque.

#codly-reset()
#codly(languages: codly-languages + (tirl: (name: "Tirl", color: rgb("#347FC4"), icon: [])), aliases: ("tirl": "c"))
#show: codly-init.with()

= Parseurs et Combinateurs

Comme expliqué dans le rapport intermédiaire, utiliser un format de définition de scène permet de rendre plus d'une
scène sans nécessiter de compiler de nouveau le logiciel en entier. Il est donc important d'avoir un parseur permettant
de lire à l'exécution un format de fichier décrivant une scène. Dans le cadre du cours de PLM, nous avons choisi de
développer notre propre standard (textuel) de scène.

Même si l'écriture du parseur à la main aurait été possible, il est souvent plus simple de le dériver de la grammaire.
La génération de code de parseurs pour la syntaxe d'un langage ou format est assez commune, avec la mise en place de Lex
et Yacc dans la période 1970-1975. Cependant, ces outils sont externes aux toolchains de langages, et nécessitent de
travailler avec un autre langage de programmation ou une autre structure de programme. Nous avons donc conçu notre
propre librairie de combinateurs intégrés au langage Zig. Un autre avantage est que là où Lex et Yacc émettent du source
à compiler séparément, `comptime` effectue cette spécialisation directement dans le compilateur, par monomorphisation.
Cela permet de n'avoir qu'un seul outil (le compilateur) pour obtenir le même résultat.

Afin d'expliquer les nuances, prenons la grammaire nécessaire pour lire un symbole:
```ebnf
alpha ::= "A".."Z"
alphanumeric ::= alpha | "0".."9"
symbol ::= alpha {alphanumeric}
```
Voici ensuite comment cette grammaire est implémentée dans Tirl:

```zig
pub const combinator = combinators.lexme(
    combinators.recognize(
        combinators.seq(.{
            combinators.satisfy(std.ascii.isAlphabetic),
            combinators.takeWhile(std.ascii.isAlphanumeric),
        }),
    ),
).map(@This().toStruct).label("an identifier (e.g. foo, foo123)");
```
Cette implémentation, écrite dans le même langage que le reste de l'application, permet d'effectuer une conversion entre
la correspondance, et l'objet même de l'AST. De plus, elle est similaire en compréhension à la grammaire décrite
précédemment.

Puisque le paramètre est `const`, la totalité du combinateur est évaluée à la compilation via comptime. Cela inclut
aussi les fonctions, connues à la compilation (`*const fn`), ce qui permet au compilateur d'inline ces fonctions,
évitant des redirections à l'exécution (via VTables en C++, ou aux interfaces en Go ou Java).

= Interpréteur

Une fois que nous avons obtenu l'AST au travers du parseur, il est ensuite nécessaire de le convertir dans des
structures de données qui peuvent ensuite être utilisées par le moteur de rendu. Même si ce projet n'en fait pas
l'utilisation, à cause du temps limité, il serait possible d'intégrer à cette étape les éléments de la scène dans une
structure d'accélération telle qu'une Bounding Volume Hierarchy (BVH).

Afin de faciliter les cycles d'itération, et de mettre en avant une autre fonctionnalité proposée par l'implémentation
de la métaprogrammation en Zig: l'introspection, nous avons implémenté l'interpréteur grâce à `comptime`.

Cette architecture permet de rajouter des éléments et composants au moteur de rendu très rapidement. Pour tester ces
capacités, nous avons rajouté le support des quadrilatères (`Quad`) dans notre format de scène.

Pour le rajouter, il faut d'abord implémenter la structure dans le module `hittable`:
```zig
// Note: Dans Zig, un module / fichier n'est qu'une structure implicite
const Quad = struct {
  q: Point3,
  u: Vec3,
  v: Vec3,
  material: *const Material,

  pub fn hit(...) ?HitRecord {
    ...
  }
}
```

Puis, ajouter la nouvelle variante dans l'union taggée (`union(enum)`) `Hittable`, pour pouvoir être inclus dans la
liste des instances `HittableList`.

Enfin, rajouter une monomorphisation pour l'objet dans l'interpréteur:
```zig
const block_handlers = .{
    // ...
    handler("Quad", Quad, .hittable),
};
```
Cette ligne suffit, car elle appellera la fonction `reflect.parseBlock`, qui itère sur tous les attributs de la
structure (via `inline for`), et génère un parseur optimisé à partir de ces informations. Cela permet des optimisations
telles que la génération de lookup structures, ou un inlining agressif des parseurs de valeur (`Vec3`). Ces
optimisations seraient impossibles à obtenir dans un langage comme Java, dont les paramètres de la structure ne sont
accessibles qu'à l'exécution, forçant l'utilisation d'offsets dynamiques, et aux sauts via VTable.

= Retour d'expérience

L'implémentation d'un moteur de rendu en Zig a été une expérience particulièrement enrichissante. Bien que
l'implémentation (et ce rapport) se concentre principalement sur la fonctionnalité `comptime` du langage, ce n'est pas
nécessairement le seul avantage que Zig apporte à l'expérience de développement.

Un autre gain souvent sous-estimé est le fait que la configuration de la compilation (dépendances, optimisations,
linkers) soit aussi décrite en Zig (même le fichier .zon est un fichier zig valide!).

Un autre intérêt qui paraissait être un inconvénient avant de commencer l'implémentation: l'absence volontaire du
support de surcharge d'opérateurs. Cela force un code plus verbeux, mais permet de comprendre tellement plus rapidement
la structure et les opérations effectuées par le logiciel. Prenons l'exemple de code suivant (en C++, ayant une
implémentation de Vec3 telle qu'elle a été décrite dans le livre Ray Tracing In One Weekend):
```cpp
vec3 a, b, c; // initialization...
auto value = dot(a,b) * c + a * 4;
```
Pour un lecteur expérimenté, cette ligne est assez explicite, mais elle ne réponds pas forcément aux questions
suivantes: Est-ce que value est un Vec3? Un scalaire (double)? Des multiplications scalaires ou de vecteurs sont
effectuées?

Alors que le code équivalent en zig:

```zig
const value = c.mul_s(Vec3.dot(a,b))
  .add(a.mul_s(4));
```
Montre explicitement que les additions sont vectorielles (sinon l'opérateur + aurait été utilisé), et que les
multiplications se font avec des nombres scalaires. Fournir un vecteur à l'opération de multiplication scalaire crée une
erreur. Cela est aussi obligatoire car Zig ne supporte pas la surcharge de fonctions.

Cependant, ces avantages facilitant la lecture de code ne sont parfois pas des plus simples. Par exemple, il est
difficile de forcer une fonction à être exécutée à la compilation uniquement. Cela a causé des soucis si le parseur
était mis dans une fonction, générant une erreur à l'exécution.

Aussi, car Zig interprète le code à la compilation, il est impossible d'attacher un débuggeur lors de la compilation, ce
qui force l'utilisation de `@compileLog` pour trouver l'origine d'une erreur.

Toutes ces petites décisions rendent plus difficile l'écriture de code Zig, mais rendent sa lecture tellement plus
facile que cela change de la structure habituelle d'un projet.

= Conclusion

Nous avons donc pu voir tout au long de ce rapport comment Zig permet, via ces outils de métaprogrammation, la mise en
place d'abstractions claires et haute performance, sans sacrifier l'expressivité du langage, et sa compréhension.

Pouvoir mettre en application ces principes, découverts pendant le rendu intermédiaire, dans un projet pratique à
échelle moyenne (Tirl), nous a permis de voir les avantages et l'absence de limites ou contraintes majeures de
l'implémentation de la métaprogrammation en Zig. La combinaison de performance, lisibilité et contrôle que laisse le
langage en fait un candidat parfait pour les projets sur lesquels le contrôle sur la façon dont le code est exécuté est
une nécessité importante.

Tirl n'est cependant pas fini. Si le projet venait à continuer, il serait appréciable de rajouter le support des BVH,
afin d'augmenter la performance. Aussi, rajouter le support pour plus de fonctionnalités et éléments, tel que
l'instancing d'objet afin de réduire la taille des fichiers .scene, serait utile pour découvrir plus de détails
d'implémentation de logiciels utilisés en production.
