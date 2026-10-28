# Feuille de route Loady

Mise à jour : 27/10/2026, version `1.13.0+34`.

## Déjà fait

| Sujet | PR |
|---|---|
| Analyse persistante (restauration sans relance automatique) | #7, #9, #34 |
| Téléchargements longs : service avec notification, nouvelles tentatives réseau, espace disponible, journal du dernier transfert | `d3780f6`, #33 |
| Firebase Analytics | #8 |
| Firebase Cloud Messaging (sujet `all`) | #26 |
| Build APK et AAB sur GitHub Actions, signature release | #16 à #20, #29 |
| Pinterest et Threads | #23 |
| Retours de test : historique sur l'accueil, suppression, dossier personnalisé, thème mémorisé, politique de confidentialité | #33 (détail dans `correction.md`) |
| Piste audio originale au lieu d'une piste doublée | #34 |
| Retrait des photos TikTok, vidéos uniquement | #38, #40 |
| Thème Clair / Sombre / Système | #40 |

Abandonné pour l'instant : **AdMob + Remote Config** (ajoutés en #27/#28, retirés
en #31 après un crash au démarrage de `1.11.1+27`, cause non identifiée).

## Décisions à prendre en équipe

1. **Mode de distribution**
   - A. Google Play : impose API 36, la suppression de la mise à jour de yt-dlp à
     la demande et une décision sur YouTube (risque de refus).
   - B. APK direct (site Loady + Releases GitHub) : garde la mise à jour du moteur
     et YouTube ; nécessite un mécanisme de mise à jour de l'app.
   - C. Les deux, avec deux variantes de build.
2. **Nom et `applicationId`** : à fixer avant toute publication publique ; il ne
   pourra plus changer ensuite sur Google Play.
3. **Licence** : youtubedl-android est sous GPL-3.0.
4. **Organisation** : relecture des PR, gestion de Firebase, des secrets et des
   clés de signature.
5. **Monétisation** : AdMob est probablement incompatible avec le téléchargement
   YouTube ; envisager dons ou version Premium.

## Prochaines étapes

### 1. CI
- Workflow sur chaque PR : `flutter analyze`, `flutter test`,
  `./gradlew :app:testDebugUnitTest`.
- APK `armeabi-v7a` (téléphones 32 bits) en plus d'arm64.
- Version et Release GitHub générées à partir d'un tag.

### 2. Validation sur appareil
- Remplir la matrice de `docs/android-download-testing.md` (8 plateformes,
  Android 7–9, 10–12 et 13+).

### 3. Corrections identifiées
- Notification « Téléchargement en cours… » possiblement bloquée si Android tue
  le processus : le téléchargement vit dans `MediaBridge`, mais le service
  redémarre avec `START_REDELIVER_INTENT`.
- Après un changement de dossier, l'historique n'affiche plus les fichiers de
  l'ancien dossier.
- Message de lien invalide dans `download_controller.dart` limité à 6
  plateformes.
- Textes « Downloads/DAZDOWNLOADER » / « Enregistrement dans Downloads… »
  affichés même avec un dossier personnalisé.
- Échec de suppression silencieux quand le fichier n'appartient pas à Loady.
- Messages FCM reçus app ouverte non affichés.
- Nettoyage : enum `MediaQuality` inutilisé, tutoiement/vouvoiement,
  `description` du `pubspec.yaml`.
- Lien « L'équipe Loady » : l'ancre `#equipe` doit exister sur le site.

### 4. Renommage DAZDOWNLOADER → Loady (si validé)
Par ordre de risque croissant, en PR séparées :
1. Textes, commentaires, docs, package Dart (`name:` + imports des tests).
2. Canaux `dazdownloader/...` (Dart et Kotlin dans la même PR), package Kotlin et
   `namespace`, CI web (`--base-href`), scripts `tooling/`.
3. ~~Dossier `Download/DAZDOWNLOADER`~~ : **fait**, renommé `Download/Loady`
   (app pas encore en production : les fichiers de l'ancien dossier ne sont plus
   listés dans l'historique).
4. `applicationId` : nouvelle app pour Android (pas de mise à jour des
   installations existantes) et nouvelle app Firebase, secret
   `GOOGLE_SERVICES_JSON_BASE64` à remplacer.

### 5. Publication
- Selon la décision 1. Pour Google Play : `targetSdk` 36, test fermé, Data
  Safety, politique de confidentialité alignée sur Firebase, fiche
  `playstore/listing.md` relue.

### 6. Site vitrine
- Section `#equipe`, politique de confidentialité, lien de téléchargement.

### 7. Monétisation (plus tard)
- Si AdMob est retenu : le réintégrer seul (identifiants de test, consentement
  RGPD/UMP), tester le démarrage sur au moins deux téléphones, puis Remote Config
  dans une PR distincte.
