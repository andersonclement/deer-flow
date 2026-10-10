# Caisso

Application mobile de gestion pour commerçants et PME au Cameroun : ventes, factures,
créances et encaissements MTN MoMo / Orange Money. Flutter, Android d'abord.

![Parcours d'inscription](docs/apercu-inscription.png)

## État actuel

- Inscription en 4 étapes : téléphone (+237), code SMS, mot de passe, infos du commerce.
- Connexion par numéro et mot de passe.
- Accueil (caisse du jour, créances) — les chiffres seront branchés sur la base des ventes.
- Interface en français et en anglais (bouton FR / EN).

Le backend n'existe pas encore : `FakeAuthRepository` simule le serveur en mémoire.
**En développement, le code SMS est toujours `123456`.**

## Lancer le projet

```bash
flutter pub get
flutter run            # sur un téléphone Android branché ou un émulateur
flutter run -d chrome  # dans le navigateur
flutter test
flutter analyze
```

## Organisation du code

```
lib/
  main.dart, app.dart          point d'entrée, routes (go_router), thème, langue
  core/                        thème, textes FR/EN, validations, format des montants
  features/
    auth/
      data/                    contrat avec le backend + implémentation factice
      application/             logique de l'inscription et de la connexion (Riverpod)
      presentation/            écrans et composants
    home/                      écran d'accueil
test/                          tests unitaires et tests d'écran
```

## Prochaines étapes

1. Base locale hors ligne (ventes, clients, créances) et accueil branché dessus.
2. Saisie d'une vente, puis saisie vocale.
3. Backend : API, envoi des SMS, mots de passe hachés côté serveur, agrégateur de paiement MTN / Orange.
