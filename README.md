# SecurePaste

Application macOS basée sur Maccy, avec historique classique et un mode de copie sécurisé distinct.

- **⌘C / ⌘V** sécurisés dans les applications configurées.
- **⇧⌘C / ⇧⌘V** pour les actions sécurisées manuelles ailleurs.
- Capture et insertion via Accessibilité, sans transport du secret par le presse-papiers système.
- Un secret en mémoire, 60 secondes maximum, détruit après une insertion réussie ou une nouvelle copie.
- Cadenas gris : aucun secret ; rouge : secret prêt ; vert pendant 1,5 s : insertion réussie et secret détruit ; orange : protection indisponible.
- Aucun Touch ID. L’historique classique reste persistant ; le module sécurisé reste séparé de cet historique.

## Construire

Prérequis : macOS 14 ou ultérieur et Xcode complet.

```sh
git clone --branch securepaste-native https://github.com/AntoineViallefont/Maccy.git SecurePaste
cd SecurePaste
./Scripts/build.sh
open .build/App/Build/Products/Release/SecurePaste.app
```

Les dépendances sont fixées et résolues par Xcode. La compilation produit une application signée localement, sans notarisation. Autoriser ensuite SecurePaste dans Réglages Système → Confidentialité et sécurité → Accessibilité.

## Tester

```sh
./Scripts/test.sh
```

Les essais automatisés ne remplacent pas la validation AX dans chaque application. Aucun fonctionnement universel ni effacement physique complet de la mémoire n’est garanti. Si l’interception est indisponible, les raccourcis classiques peuvent rester actifs ; vérifier l’état avant toute copie sensible.

## Documentation

- [Utilisation, installation locale et maintenance](SECUREPASTE.md)
- [Revue de sécurité et limites](SECURITY-REVIEW.md)
- [Résultats de validation](docs/validation.json)
- [Inventaire de provenance](docs/security-evidence.json)

## Licence

Fork de [Maccy](https://github.com/p0deje/Maccy), sous [licence MIT](LICENSE). Copyright du projet d’origine conservé. Les remerciements personnels, médias promotionnels, anciennes icônes et composants inutilisés de la distribution Maccy ont été retirés.
