# Adaptation SecurePaste de Maccy

Source : https://github.com/p0deje/Maccy — licence MIT conservée dans LICENSE.
Fork : https://github.com/AntoineViallefont/Maccy

## État

Base Maccy importée, branche `securepaste`. Le comportement sécurisé n'est pas encore implémenté : sa définition et les raccourcis issus de la discussion précédente restent à préciser.

Comportement demandé : conserver Maccy, protéger automatiquement les copies provenant d'une liste d'applications et permettre une copie protégée manuelle avec ⇧⌘C.

Attention : ⇧⌘C ouvre actuellement l'historique de Maccy. Il faudra réaffecter ce raccourci et choisir celui de l'historique.

Une exclusion de l'historique ne protège pas le presse-papiers système des autres applications. Une solution qui utilise temporairement ce presse-papiers ne peut pas garantir son inaccessibilité pendant cet intervalle. L'exigence de protection doit être définie avant l'implémentation.

## Compiler la base (Xcode requis)

```sh
cd "/Users/macavi/Desktop/App Mac SecurePaste"
xcodebuild -project Maccy.xcodeproj -scheme Maccy -configuration Debug -derivedDataPath .build CODE_SIGNING_ALLOWED=NO build
```

Ne pas installer cette base comme une version sécurisée : elle conserve le fonctionnement original de Maccy.

## Actualiser les sources de référence

```sh
cd "/Users/macavi/Desktop/App Mac SecurePaste"
git fetch upstream
git log --oneline HEAD..upstream/master
```

Examiner les changements avant de les intégrer. Ne pas remplacer le fork par une version officielle lors des futures mises à jour.
