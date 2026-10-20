# SecurePaste — fork local de Maccy

L’application construite et son exécutable portent le nom **SecurePaste**. Le nom du module et de la cible Xcode reste `Maccy` pour limiter les modifications du socle ; ce nom technique n’est pas le nom affiché à l’utilisateur. Les crédits du logiciel d’origine sont conservés.

## Fonctionnement implémenté

- Maccy classique hors des applications de la liste ; historique conservé pour les copies ordinaires.
- Dans les applications configurées : ⌘C capture la sélection via AX et ⌘V insère via AX.
- Partout : ⇧⌘C / ⇧⌘V pour la capture et l’insertion sécurisées manuelles.
- L’historique s’ouvre désormais avec **⌃⌥⌘H** par défaut. Les combinaisons ⌘C, ⌘V, ⇧⌘C et ⇧⌘V sont réservées et refusées pour l’ouverture d’historique.
- Un secret unique, chiffré AES-256-GCM dans le module séparé `Packages/SecurePasteKit`, pendant **60 s maximum**.
- Destruction au remplacement, à une capture ou insertion échouée, après insertion réussie, au changement détecté du compteur du presse-papiers, aux notifications de veille/écran éteint/session inactive et à la fermeture.
- Aucune demande Touch ID. Icône rouge si un secret est disponible, verte pendant 1,5 s après insertion réussie et destruction, puis grise. Symbole orange si la protection est indisponible.
- Aucun repli vers le presse-papiers classique lors d’un refus de l’action sécurisée.

Le secret ne transite pas par le presse-papiers général ni par l’historique. Le module n’expose aucun contenu secret à Maccy ; seul son état est public. Il n’a aucune dépendance tierce. Il est compilé séparément **dans le même processus**, sans isolation XPC : cette séparation ne protège pas d’un processus compromis.

L’historique normal conserve son rôle et son stockage local. Son fichier est séparé de celui de Maccy officiel (`Application Support/SecurePaste/Storage.sqlite`) ; les préférences utilisent l’identifiant `fr.antoineviallefont.SecurePaste`. L’ancien historique officiel n’est ni importé ni supprimé.

## Construire et tester

Prérequis : macOS 14 ou ultérieur et Xcode complet. Validation de développement effectuée avec Xcode 27.1, sur Apple Silicon. La compatibilité réelle AX dépend de chaque application et doit être validée sur le Mac cible.

```sh
cd "/Users/macavi/Desktop/Maccy Secure"
./Scripts/test.sh
./Scripts/build.sh
open "/Users/macavi/Desktop/Maccy Secure/.build/App/Build/Products/Release/SecurePaste.app"
```

`test.sh` exécute les 10 tests du module autonome et 18 tests sélectionnés de Maccy, sans exécuter les tests de presse-papiers général de Maccy. Ce n’est pas la suite complète de Maccy ni un test interapplications AX. `build.sh` produit une version Release et la signe localement avec le runtime renforcé. Cette signature ad hoc n’est pas une signature Developer ID ni une notarisation.

## Première utilisation

1. Quitter les autres instances de Maccy pendant la validation pour éviter les conflits de raccourcis.
2. Clic droit sur l’icône → **Réglages SecurePaste…** → onglet SecurePaste.
3. Cliquer **Autoriser l’accessibilité**, puis autoriser l’application dans Réglages Système → Confidentialité et sécurité → Accessibilité. Si macOS demande aussi une autorisation de surveillance des entrées, l’examiner et l’accorder à cette seule application si nécessaire.
4. Revenir dans l’application. Vérifier **Interception active**. Ajouter les applications à protéger avec le sélecteur ; la liste est initialement vide.
5. Utiliser d’abord du texte factice sélectionné dans un champ éditable de TextEdit. Tester copie/insertion, expiration, remplacement et copie classique. Vérifier le presse-papiers et l’historique.

Une recompilation ou un déplacement de l’application peut nécessiter de renouveler l’autorisation macOS avec la signature ad hoc. Ne pas considérer une ancienne autorisation comme la preuve que la nouvelle version intercepte bien les commandes.

## Limites importantes

- Les champs protégés et les contrôles sans sélection AX compatible sont refusés. Word, les navigateurs et les éditeurs particuliers n’ont pas une compatibilité universelle garantie.
- Les menus Copier/Coller, menus contextuels, copies programmatiques et autres raccourcis ne sont pas interceptés par ce filtre clavier. Les copies classiques observées pendant qu’une application de la liste est au premier plan sont exclues de l’historique du fork, par précaution ; cette exclusion ne les protège pas sur le presse-papiers système et n’est pas sans course de focus.
- Si l’autorisation est retirée, si la saisie sécurisée est active ou si macOS désactive le filtre, des commandes classiques peuvent passer. L’icône passe à l’avertissement lorsque l’état est détecté. Aucune protection absolue ne peut être garantie pendant cette interruption. Vérifier l’état avant une copie sensible.
- La surveillance du compteur est faite toutes les 100 ms et le compteur est revérifié à l’insertion. Il subsiste des courses entre les API ; ce n’est pas une transaction atomique.
- Un secret est logiquement inutilisable après expiration ; son effacement physique intégral dans la RAM, les copies Swift/Foundation, le swap ou les applications source/destination n’est pas garanti.
- Le chiffrement avec une clé dans le même processus ne protège pas d’une compromission de ce processus ou du Mac. Aucun antivirus ni audit exhaustif n’est fourni par ce projet.
- Le sandbox App Store est retiré pour le fonctionnement AX interapplications. Le runtime renforcé est conservé dans la version Release signée. Ce choix élargit les capacités du processus ; il n’est pas présenté comme un durcissement.

## Sécurité et provenance

Voir [SECURITY-REVIEW.md](SECURITY-REVIEW.md), [security-evidence.json](docs/security-evidence.json) et [validation.json](docs/validation.json). La licence MIT de Maccy est conservée dans `LICENSE`.

Les mises à jour officielles Sparkle sont retirées : elles ne doivent pas remplacer ce fork. Les dépendances directes sont fixées à une version exacte et les révisions résolues sont versionnées.

## Mettre à jour

Après publication d’une branche du fork, récupérer uniquement cette branche de travail ; ne pas remplacer l’application par un téléchargement officiel Maccy. Pour examiner les évolutions officielles sans les intégrer automatiquement :

```sh
cd "/Users/macavi/Desktop/Maccy Secure"
git fetch upstream
git log --oneline HEAD..upstream/master
```

L’intégration des correctifs et toute mise à jour de dépendance doivent être accompagnées d’une revue, d’une mise à jour intentionnelle de `Package.resolved`, puis des tests et de la compilation ci-dessus. Ne pas lancer une mise à niveau générale non contrôlée des dépendances.
