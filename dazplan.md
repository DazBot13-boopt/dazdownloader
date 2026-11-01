# Feuille de route Loady

Mise à jour : 01/11/2026, version `1.15.4+40` (tag `v1.15.4`, PR #50).

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
| Logo TikTok, lien « L'équipe Loady », historique et notifications plus clairs | #39 |
| Thème Clair / Sombre / Système | #40 |
| CI : `flutter analyze` + tests sur chaque PR et chaque push sur `main` (`tests.yml`) | #41, #45 |
| CI : Release GitHub créée à partir d'un tag, APK arm64 + `armeabi-v7a` (32 bits) | #42 |
| Mise à jour de l'app : nouvelle version proposée dans l'app (1.14.0), téléchargement direct de l'APK (1.15.2), vérification toutes les heures (1.15.3) | #43, #48, #49 |
| Dossier de téléchargement renommé `Download/Loady` | #46 |
| Corrections : notification bloquée quand Android tue Loady, messages de lien invalide avec les 8 plateformes, historique listant les deux dossiers, échecs de suppression signalés, annonces Firebase affichées app ouverte | #47 |
| Finitions : dialogues de suppression, choix du thème, notification de fin de téléchargement | #48 |
| Historique sans doublons, avertissement « déjà téléchargé » | #49 |
| Cartes des plateformes cliquables : ouvrent l'app de la plateforme | #50 |

Abandonné pour l'instant : **AdMob + Remote Config** (ajoutés en #27/#28, retirés
en #31 après un crash au démarrage de `1.11.1+27`, cause non identifiée).

## Décisions à prendre en équipe

1. **Mode de distribution** : l'objectif est la publication sur les stores
   (Google Play d'abord). L'APK du site et des Releases GitHub reste la
   solution temporaire. Pour Google Play, il faudra :
   - passer à l'API 36 ;
   - retirer la mise à jour de yt-dlp à la demande ;
   - décider quoi faire de YouTube (risque de refus) ;
   - remplacer la mise à jour intégrée à l'app (#43, #48), qui n'est pas
     autorisée sur Play.

   Prévoir sans doute deux variantes de build : Play et APK direct.
2. **Nom et `applicationId`** : aujourd'hui `com.dazdownloader.dazdownloader`.
   À fixer avant la publication, il ne pourra plus changer ensuite sur
   Google Play.
3. ~~**Licence**~~ : **décidé** le 01/11/2026, `GPL-3.0-or-later`, titulaire « Les contributeurs de Loady » (fichier `LICENSE`).
4. **Organisation** : relecture des PR, gestion de Firebase, des secrets et des
   clés de signature.
5. **Monétisation** : AdMob est probablement incompatible avec le téléchargement
   YouTube ; envisager dons ou version Premium.

## Prochaines étapes

### 1. Validation sur appareil
- Remplir la matrice de `docs/android-download-testing.md` (8 plateformes,
  Android 7–9, 10–12 et 13+). Elle est encore vide.

### 2. Nettoyage restant
- Enum `MediaQuality` inutilisé (`lib/features/download/domain/media_models.dart`).
- Tutoiement / vouvoiement : l'app vouvoie encore à plusieurs endroits
  (réglages, accueil, `download_controller.dart`) alors que le site tutoie.
- `description` du `pubspec.yaml` (« A new Flutter project. »).

### 3. Site vitrine (dépôt `loady-site`, suivi dans son `plan.md`)
- L'app renvoie vers `https://loady-site.vercel.app/#equipe`, mais cette
  section n'existe pas encore sur le site.
- L'app renvoie vers `#confidentialite`, qui n'est pour l'instant qu'un court
  encadré : la politique de confidentialité détaillée reste à écrire (elle sera
  aussi exigée par Google Play).

### 4. Renommage DAZDOWNLOADER → Loady (si validé)
Par ordre de risque croissant, en PR séparées :
1. Textes, commentaires, docs, package Dart (`name:` + imports des tests).
2. Canaux `dazdownloader/...` (Dart et Kotlin dans la même PR), package Kotlin et
   `namespace`, CI web (`--base-href`), scripts `tooling/`.
3. ~~Dossier `Download/DAZDOWNLOADER`~~ : **fait** (#46), renommé
   `Download/Loady`. L'historique liste les deux dossiers (#47).
4. `applicationId` : nouvelle app pour Android (pas de mise à jour des
   installations existantes) et nouvelle app Firebase, secret
   `GOOGLE_SERVICES_JSON_BASE64` à remplacer.

### 5. Publication sur les stores (plus tard)
- Selon la décision 1. Pour Google Play : `targetSdk` 36 (aujourd'hui 35),
  test fermé, Data Safety, politique de confidentialité alignée sur Firebase,
  fiche `playstore/listing.md` relue (checklist en bas du fichier).

### 6. Monétisation (plus tard)
- Si AdMob est retenu : le réintégrer seul (identifiants de test, consentement
  RGPD/UMP), tester le démarrage sur au moins deux téléphones, puis Remote Config
  dans une PR distincte.
