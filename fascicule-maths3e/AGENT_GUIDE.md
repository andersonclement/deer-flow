# Guide — RÉDIGER un chapitre du fascicule Maths 3ème / BEPC (OnBuch)

Tu **rédiges depuis zéro** UN chapitre du fascicule de mathématiques classe de 3ème
(BEPC, Cameroun, programme MINESEC/APC), pour l'application éducative **OnBuch**.
Objectif : qualité « **grand livre de référence** » que les élèves adorent — cours
clair et bien illustré, méthodes, et **beaucoup** d'exercices, au niveau collège
(pas Terminale — reste simple, concret, progressif).

## Fichiers fournis dans cette archive

- `preamble.tex` — préambule LaTeX complet (NE PAS modifier, ne pas recopier dans
  ta réponse) : définit tous les environnements/macros utilisés ci-dessous.
- `PLAN.md` — le programme détaillé des **16 chapitres** du fascicule. Chaque
  chapitre a sa propre section « Cours / Méthodes / Exercices » : c'est ton cahier
  des charges pour le contenu de CHAQUE fichier.
- `ch_<nom>.tex` — un fichier « stub » par chapitre (une seule ligne
  `\chapter{Titre}`), à remplir intégralement.
- `ref_ch_derivation.tex`, `ref_ch_barycentre.tex` — deux chapitres déjà rédigés
  (fascicule Terminale C, niveau différent) donnés **uniquement comme référence de
  style/mise en forme** (comment utiliser les environnements et macros ci-dessous
  en pratique) — n'en recopie pas le contenu mathématique, seulement le style.
- `fonts/`, `icons/`, `logo.png` — assets graphiques du gabarit (pas besoin d'y
  toucher).

## Cible quantitative (par chapitre)
- **Cours** : clair, progressif, beaucoup d'exemples numériques simples. Plusieurs `\section`.
- **Figures** : **3 à 5** figures TikZ/pgfplots, sobres, couleurs OnBuch (géométrie
  simple : triangles, cercles, solides — pas de graphiques de fonctions complexes).
- **Méthodes** : **5 à 8** `\methode{}`, chacune avec un `\begin{exemple}` résolu.
- **Exercices d'application CORRIGÉS** : **12 à 18**, classés par `\rubrique{}`.
- **Exercices d'entraînement NON corrigés** : **18 à 28**, classés par `\rubrique{}`,
  énoncés seulement (pas de corrigé — c'est voulu).
- **Sujets type BEPC** : **2 à 3**, complets et **corrigés** en détail.
- Une fiche de révision via `\begin{synthese}...\end{synthese}`.

## Structure IMPOSÉE du chapitre (dans cet ordre)
1. `\chapter{Titre exact}` (celui du fichier stub) + court paragraphe d'intro `\textit{...}`.
2. **Le cours** : plusieurs `\section{...}`, avec :
   - `\begin{definition}[Nom]...\end{definition}` (orange)
   - `\begin{propriete}[Nom]...\end{propriete}` (vert) — niveau 3ème : énonce et
     illustre, pas de démonstration savante.
   - `\begin{remarque}...\end{remarque}`, `\begin{exemple}...\end{exemple}` (souvent)
   - `\begin{aretenir}...\end{aretenir}` (2-3 fois)
   - **3 à 5 figures** : `\begin{illus}` + `tikzpicture` + `\fig{Figure — légende.}` + `\end{illus}`.
3. `\section{L'essentiel à retenir}` → `\begin{synthese}...\end{synthese}`.
4. `\section{Méthodes \& savoir-faire}` → **5 à 8** `\methode{Titre}` + `\begin{exemple}` résolu.
5. `\section{Exercices d'application}` → classés par `\rubrique{Thème}` (3-5
   rubriques), `\exo{}\diff{n}` (n=1/2/3 → ★/★★/★★★), **12 à 18** exercices.
6. `\section{Exercices d'entraînement}` → GROS banc NON corrigé, `\rubrique{}`,
   **18 à 28** exercices, AUCUN corrigé.
7. `\section{Sujets type BEPC}` → **2 à 3** sujets, chacun via `\sujetbac[contexte court]`.
8. `\section{Corrigés}` → `\corrige{de l'exercice n}` / `\corrige{du sujet n}`
   pour les sections 5 et 7 UNIQUEMENT (pas la 6).

## Commandes & environnements disponibles (déjà définis dans preamble.tex)
- Boîtes : `definition[Nom]`, `theoreme[Nom]`, `propriete[Nom]`, `remarque`,
  `exemple`, `aretenir`, `synthese`, `illus`.
- Macros : `\methode{}`, `\rubrique{}`, `\exo{}`, `\diff{1|2|3}`, `\corrige{}`,
  `\sujetbac[..]` (garde ce nom même si le texte affiché dit « BEPC »), `\fig{}`.
- Maths : `\R \N \Z \Q` (pas de `\C` au collège), `\dd`, `\Card`.
- Listes : `\begin{enumerate}[label=\alph*)]` ou `[label=\arabic*)]`.
- Couleurs figures : `onbo, onbo2, onbgreen, onbink, onbblue, onbmuted, onbline, onbsoft`.
- tikz libs chargées : `arrows.meta, positioning, calc, decorations.pathreplacing,
  angles, quotes`. pgfplots `compat=1.18`. ⚠️ `intersections` et `fillbetween` NE
  SONT PAS chargées — pour remplir sous une courbe : `\addplot[...] {...} \closedcycle;`.

## Règles ABSOLUES
- **Mathématiquement EXACT** : vérifie toi-même tous les calculs des exemples/corrigés.
- **Programme 3ème/BEPC Cameroun, niveau collège** — ne déborde pas sur du contenu
  de Seconde/Première. Contexte camerounais bienvenu (villes, francs CFA) quand naturel.
- LaTeX **pur et compilable**, AUCUN package en plus de `preamble.tex`.
- N'écris NI `\documentclass` NI `\begin{document}` : uniquement le contenu, à
  partir de `\chapter{...}`.
- Les corrigés (section 8) doivent correspondre EXACTEMENT à la numérotation des
  `\exo` de la section 5 (même ordre).

## Vérification avant de rendre
- **Si tu as accès à l'exécution de code** (ex. interpréteur Python/shell) : essaie
  d'installer/utiliser `tectonic` (ou `pdflatex`/`xelatex` si `tectonic`
  indisponible) pour compiler ton chapitre avec `preamble.tex` et corriger toute
  erreur avant de rendre — voir la procédure détaillée en bas de
  `AGENT_GUIDE.md` d'origine (fichier séparé, non requis ici si tu ne peux pas
  exécuter de code).
- **Si tu n'as PAS d'exécution de code** : relis très attentivement ta syntaxe
  LaTeX (accolades équilibrées, environnements bien fermés dans l'ordre, pas de
  `$` orphelin, pas de caractères spéciaux non échappés comme `%`, `&`, `_`, `#`
  hors contexte mathématique) en te calquant strictement sur la syntaxe des
  fichiers `ref_ch_*.tex` fournis.

## Format de livraison
Réponds avec **le contenu complet du fichier `.tex`** pour le chapitre demandé (le
LaTeX final, prêt à coller dans le fichier stub correspondant — commence directement
par `\chapter{...}`), suivi d'un court récap (nb d'exercices d'application /
d'entraînement / sujets BEPC, nb de figures, nb de méthodes).

Travaille **un chapitre à la fois**, dans l'ordre du `PLAN.md` (ou l'ordre qu'on te
donne), et livre chaque chapitre terminé avant de passer au suivant.
