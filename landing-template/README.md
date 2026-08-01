# Template landing page — EduFit (home-online)

Copie locale de la page téléchargée depuis :
https://html.pixelfit.agency/edufit/home-online/index.html

## Contenu

```
landing-template/
└── edufit/
    ├── common/          # CSS, JS, polices et images partagées par le template
    │   ├── css/
    │   ├── fonts/
    │   ├── images/
    │   └── js/
    └── home-online/     # La page d'accueil récupérée
        ├── index.html
        └── assets/      # CSS, JS et images spécifiques à cette page
```

La page `index.html` référence les dossiers `common/` via des chemins
relatifs (`../common/...`). Il faut donc garder cette arborescence telle
quelle (ne pas déplacer `home-online/index.html` hors de `edufit/`).

## Utilisation

Pour visualiser la page telle qu'elle a été téléchargée, ouvrir directement :

```
landing-template/edufit/home-online/index.html
```

dans un navigateur, ou servir le dossier avec un serveur statique, par ex. :

```
npx serve landing-template/edufit
```

Cette page n'est pas branchée sur l'application deer-flow — c'est
simplement le template source (HTML/CSS/JS/images/polices) à reprendre et
adapter pour la landing page de l'application externe.

Les liens de menu vers d'autres pages du template (about, contact,
cours, etc.) qui n'ont pas été téléchargées pointent toujours vers le
site d'origine (`https://html.pixelfit.agency/...`).

La police Google Fonts (`Outfit`, `SUSE`) est chargée à distance depuis
`fonts.googleapis.com` (non téléchargée localement).
