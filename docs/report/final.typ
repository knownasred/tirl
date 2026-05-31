#import "@preview/basic-report:0.4.0": *
#import "@preview/codly:1.3.0": *

#import "@preview/codly-languages:0.1.1": *
#show: codly-init.with()

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

Présentation de Tirl, des résultats, du fait qu'on a utilisé Zig, qu'on a atteint nos objectifs, et que la
meta-programmation a permis de réduire grandement la difficulté d'implémentation.

= Architecture

Diagramme:
- .scene file
- Système de combinateurs (parsers)
- Output un AST
- Interpréteur (reflect)
- Output une définition de scène
- Moteur de rendu

Pas besoin d'aller dans les détails.

= Parseurs et Combinateurs

Commencer par le challenge, sans aller trop dans les détails de ce qu'est un parseur et combinateur (peut être mettre un
lien vers crafting interpreters, pour ceux ne connaissant pas), et les containtes liées de performance.

Expliquer que dans le temps disponible, on n'a pas pu mettre en place un "streaming" parser, qui construit la scène
progressivement, sans charger le fichier ou l'AST en mémoire en tout temps.

Présetnation d'un exemple de parseur dans le code (mettre un lien), et présenter une implémentation équivalente à la
main (ou en annexe), pour montrer la difficulté.

Aussi mettre en avant la performance (saut de fonctions, inlining difficile...)

- Et montrer les éléments de Zig qui permettent d'aider (pub const T = ... permettant d'y accéder sans devoir chercher
  plus en détail, i.e. type de retour)

= Interpréteur
garder cette section plus courte

Un AST est bien, mais ne permet pas de configurer les objets rapidement, surtout dans un toy renderer. rajouter un
support de composant doit être simple, pas prendre des années (c'est le rendu qui est intéressant, pas la scène, ou le
comportement au tour, quand on souhaite avancer sur ces éléments)

reflect est donc un outil pour faire ca. On est parti d'une version manuelle (avec itération manuelle sur chacun des
types (liste les éléments 1 par un, et appelle une fonction équivalente))



On a ensuite utilisé comptime pour simplifier et rendre l'implémentation plus complète avec moins de code.

Montrer que la performance est beaucoupplus efficace (car Go et Java regarde la forme de l'objet à la compilation (donc
O(n^2) pour le parsing), vs faire une partie du travail en amont, et préparer une jumptable a la compilation avec switch
(merci comptime).

= Retour d'expérience

Parler d'a quel point Zig c'est bien, avec la vitesse de compilation, le fait que le code est fait pour être lisible, si
fait correctement, ce qui permet d'avoir un indicateur clair de si le code est lisible pour les autres ou non (a
l'instar de C par exemple, ou les bitHacks rendent la chose complexe, ou C++ avec les overload d'opérateurs). Prendre
l'exemple de Vec, et de ses fonctions postfixes, qui rendent le code plus verbeux, mais simplifient la compréhension
dans beaucoup de cas (on fait des opérations sur un objet, pas sur un blob).

Parler aussi des difficultés liées au fait que la gestion de la mémoire est manuelle, ce qui force a réfléchir sur
beaucoup de détails, a l'instar d'autres languages.

Le controle a un cout, mais il est largement rentabilisé dans Zig.

Parler de la taille du binaire, qui est grande (4.2Mb), mais pas énorme, par rapport aux équivalents en rust par
exemple.

= conclusion

Bons aprensissage, m'a permis de découvrir Zig plus en détail, et j'aimerai continuer a m'en servir dans d'autres
projets !

#pagebreak()

#bibliography("zotero.bib")
