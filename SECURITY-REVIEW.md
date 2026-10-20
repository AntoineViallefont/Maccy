# Revue de sécurité — SecurePaste / Maccy

Date : 20 octobre 2026, Europe/Paris.

## Conclusion et périmètre

**Aucun indice de code malveillant n’a été identifié dans la revue ciblée effectuée. Ce résultat ne certifie pas l’absence de code malveillant ou de vulnérabilité.**

Travaux réalisés : comparaison de provenance Git, inventaire des dépendances et des phases de construction, recherche d’API sensibles dans les sources de l’application et les sources des dépendances directes retenues, lecture ciblée des chemins presse-papiers, stockage, journaux, notifications, automatisation et mise à jour, puis compilation et tests sélectionnés.

Ce travail n’est pas une lecture exhaustive ligne par ligne de toutes les dépendances, un audit binaire complet, une analyse dynamique réseau, un test d’intrusion ni une certification indépendante. Les frameworks Apple, Xcode, le compilateur et l’installation macOS ne sont pas audités. Les tests ne démontrent pas la compatibilité AX réelle dans toutes les applications.

## Provenance vérifiée

- Dépôt officiel : `https://github.com/p0deje/Maccy.git`.
- Commit de départ local : `c700182f638d9d29bfa0aec9dc560422698854c6`.
- Le `HEAD` annoncé par le dépôt officiel via Git correspondait à ce commit au moment de la vérification.
- L’état local initial ne listait ni modification ni fichier non suivi. Aucun lien symbolique ou sous-module suivi n’a été remonté par l’inventaire des modes Git.
- Le dépôt GitHub `AntoineViallefont/Maccy` a été confirmé comme fork de `p0deje/Maccy` par les métadonnées GitHub. La branche distante `securepaste` existe déjà ; elle ne doit pas être écrasée par ce travail.

Une correspondance avec le dépôt officiel établit la provenance observée ; elle ne prouve pas à elle seule l’innocuité du code officiel ou de son infrastructure.

## Chemins sensibles examinés

| Élément | Observation / traitement |
| --- | --- |
| Réseau et exécution | Aucun client réseau explicite, lancement de commande shell, chargement dynamique arbitraire ou accès au trousseau n’a été identifié par la recherche ciblée dans les sources applicatives Swift examinées. Les liens du panneau À propos sont des liens utilisateur. |
| Mise à jour Sparkle | Présente dans la base officielle ; retirée du graphe de dépendances, du démarrage et du fichier Info.plist pour empêcher le remplacement du fork par l’application officielle. |
| Construction | Aucune phase de script shell dans le projet Xcode de départ. Les manifests des dépendances directes retenues ont été inspectés ; leurs cibles applicatives ne déclarent pas de plugin de construction ni de binaire précompilé. Les macros Defaults ont une dépendance de résolution swift-syntax ; le module sécurisé n’en dépend pas. |
| Journaux Maccy | Des titres de copies figuraient dans plusieurs messages de journal. Ils ont été remplacés par des messages génériques. Le module sécurisé ne journalise aucun secret. |
| Historique et notifications | Fonctionnalités classiques conservées : l’historique normal est persistant et les notifications classiques peuvent contenir leur titre. Les secrets du module n’entrent pas dans ces circuits. Ce sont des comportements attendus de la partie classique, pas une preuve de malveillance. |
| Raccourcis et AX | Interception active et suppression de la commande sécurisée avant traitement AX différé. Pas de copie temporaire dans le presse-papiers. Vérifications de focus, sélection et échéance ; refus sur erreur. |
| Intents Maccy | Trois calculs de position pouvaient sortir des bornes et provoquer une erreur d’exécution. Gardes ajoutées avant soustraction et accès, avec test sur valeurs négatives, zéro, Int.min et Int.max. |
| Démarrage automatique | La bibliothèque LaunchAtLogin utilise ServiceManagement ; la fonction reste commandée par le réglage utilisateur. Pas d’ajout d’agent de lancement caché dans ce travail. |
| Capacité iCloud de Defaults | La bibliothèque contient un mécanisme iCloud optionnel. Aucun usage explicite de ce mécanisme n’a été identifié dans l’application par la recherche effectuée ; les secrets ne sont pas des clés Defaults. |

L’inspection de références aux API sensibles est une méthode de repérage, pas une preuve d’absence d’obfuscation ou d’un autre chemin d’exécution.

## Module sécurisé distinct

Le package `Packages/SecurePasteKit` n’a aucune dépendance tierce et aucune dépendance sur Maccy. Son API publique fournit uniquement une configuration et un état observable, ainsi que des commandes sans paramètre secret. Le coffre et l’adaptateur AX sont internes au module.

Le secret est chiffré AES-256-GCM avec une nouvelle clé aléatoire et un nonce généré par CryptoKit pour chaque capture. La clé et le secret chiffré restent en mémoire. Ils sont rendus inaccessibles par l’API lors de l’invalidation ; l’écrasement de toutes les copies physiques n’est pas attesté.

Le module utilise `NSPasteboard.general.changeCount` pour l’invalidation ; il ne lit pas les données du presse-papiers et n’y écrit pas le secret. Aucun accès fichier, accès réseau, historique, journal ou Touch ID n’est ajouté au module.

**Séparation de module, pas de processus :** le package est lié dans l’exécutable de Maccy. Une compromission de cet exécutable peut contourner la logique ou accéder à sa mémoire. L’isolation via un processus XPC serait une amélioration distincte à concevoir et auditer.

## Dépendances et éléments de preuve

Les URL, versions et révisions retenues figurent dans `Maccy.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` et dans `docs/security-evidence.json`. Les dépendances directes sont demandées à une version exacte ; les scripts utilisent uniquement les versions du fichier résolu. Toute actualisation doit être intentionnelle et réexaminée.

Les empreintes des sources et les informations de version sont des éléments de traçabilité, pas un label d’innocuité. Aucune conclusion d’absence de CVE n’est formulée.

## Validation effectuée et reste à vérifier

- Compilation Debug complète réussie.
- 10 tests du module sécurisé réussis, dont deux sur la confirmation verte de 1,5 s et son annulation.
- 18 tests Maccy sélectionnés réussis, dont le test des bornes des Intents. La suite complète Maccy et les tests UI/AX interapplications ne sont pas couverts par ce résultat.
- Compilation Release réussie, signature ad hoc avec runtime renforcé vérifiée par `codesign --verify --deep --strict`. Les droits embarqués sont vides : pas de droit de débogage injecté. Les bibliothèques dynamiques listées par `otool -L` sont des bibliothèques système Apple ; Sparkle n’est plus lié.
- Application Release lancée ; onglet SecurePaste inspecté dans l’interface en thème sombre. L’absence d’autorisation Accessibilité est correctement signalée. Sur la version précédant le renommage, Antoine a confirmé au clavier physique la capture manuelle, l’icône rouge et l’insertion à usage unique dans TextEdit. Le contenu inséré a été observé via l’interface ; le témoin classique est resté disponible. Le collage sécurisé a aussi été rapporté dans TextEdit temporairement ajouté à la liste. La couleur verte finale reste à vérifier visuellement.
- Aucun contenu de l’archive `SecurePaste-source.zip` n’a été examiné : elle n’a pas été retrouvée dans les emplacements recherchés. Ce nouveau fork ne prouve rien sur cet ancien prototype.

Contrôle ciblé en lecture seule de la base locale après les essais : zéro titre et zéro contenu comportant le texte factice sécurisé. Ce contrôle ne prouve pas l’absence de trace dans tout le système.

Restent à valider : les applications autres que TextEdit, les deux thèmes de la barre des menus, le signal vert de la version finale, les scénarios réels de retrait de permission, interruption du filtre et expiration. Les simulations clavier de l’outil de contrôle n’ont pas reproduit de manière fiable les raccourcis physiques ; elles ne sont pas utilisées comme preuve de bon fonctionnement du filtre.

Le sandbox App Store de la base est retiré pour les accès AX interapplications. Le runtime renforcé est conservé dans la version Release locale. La signature ad hoc n’est pas une notarisation ou une signature Developer ID. Les permissions macOS doivent être accordées explicitement à l’application construite.
