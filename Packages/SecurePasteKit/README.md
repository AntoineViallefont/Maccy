# SecurePasteKit

Module Swift autonome, sans dépendance tierce. Les secrets restent dans ce module : son API publique ne fournit que configuration, état et actions sans contenu.

- `SecurePasteService` : filtre clavier actif, surveillance du compteur du presse-papiers et état observable.
- `AXSelection` : capture et insertion AX ; contrôle du focus et de la sélection ; refus des champs protégés/incompatibles.
- `EphemeralVault` : un secret chiffré AES-256-GCM, clé aléatoire éphémère, échéance monotone de 60 s, invalidation au changement de compteur.
- `SuccessPulse` : confirmation visuelle verte de 1,5 s, uniquement après insertion réussie et destruction.
- `SecureRoute` : choix des raccourcis sécurisés et maintien du fonctionnement classique hors liste.

La capture AX et l’insertion ne font aucune écriture dans le presse-papiers. Le module lit uniquement son compteur `changeCount`. Il ne contient ni accès réseau, ni écriture de fichier, ni journal du secret, ni accès à l’historique de Maccy. Une insertion réussie consomme le secret. Les erreurs détruisent aussi le secret.

Il s’agit d’une séparation de sources et de compilation, **pas d’une isolation de processus** : Maccy et le module partagent le même espace mémoire. Un processus XPC dédié constituerait une étape supplémentaire si cette isolation devient nécessaire. Ni le chiffrement avec clé dans le même processus ni cette séparation ne protègent d’une compromission complète du processus.

Swift, Foundation, AX et CryptoKit peuvent conserver des copies mémoire transitoires ; aucun effacement physique complet n’est garanti. Les contrôles de temps, de focus et de compteur réduisent les courses, sans transaction atomique entre AX et NSPasteboard. Une interruption de l’interception peut laisser passer des commandes classiques ; l’état indisponible doit être pris en compte.

Tests indépendants :

```sh
swift test --package-path Packages/SecurePasteKit
```
