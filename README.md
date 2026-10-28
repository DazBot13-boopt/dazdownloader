# Loady

Application Android (Flutter + Kotlin) qui télécharge en local les **vidéos
publiques** et leur audio. Pas de compte, pas de serveur Loady, pas de
synchronisation cloud.

Version actuelle : `1.13.0+34` (voir `pubspec.yaml`).

> Le dépôt, le package et certains identifiants techniques portent encore
> l'ancien nom **DAZDOWNLOADER** (`com.dazdownloader.dazdownloader`, dossier
> `Download/DAZDOWNLOADER`, canaux `dazdownloader/...`). Un renommage est à
> l'étude ; voir les risques dans [la feuille de route](dazplan.md).

## Fonctionnalités

- Plateformes reconnues : **YouTube, TikTok, Instagram, Snapchat, X, Facebook,
  Pinterest, Threads**. Reconnaître un domaine ne garantit pas que tous ses
  contenus sont téléchargeables : cela dépend des extracteurs yt-dlp et des
  restrictions de chaque plateforme.
- **Vidéos uniquement.** Les carrousels photo (TikTok `/photo/` notamment) sont
  refusés avec un message explicite. Playlists, publications multi-médias,
  directs en cours et contenus protégés (DRM) sont refusés ; les replays
  terminés sont acceptés.
- Formats proposés : **MP4**, **WebM** (surtout YouTube, parfois seul format
  au-delà de 1080p) et **MP3**. Seules les résolutions réellement disponibles
  sont proposées ; la taille n'est affichée que si elle est connue.
- La piste audio **originale** est conservée (pas de piste doublée).
- Lien collé, bouton « coller », ou partage Android d'un lien texte vers Loady.
- Téléchargement en arrière-plan avec notification, jusqu'à 3 tentatives en cas
  de coupure réseau, vérification de l'espace disponible.
- Accueil : 3 derniers téléchargements. Historique : ouvrir, supprimer un
  fichier ou tout supprimer (avec confirmation).
- Réglages : thème **Clair / Sombre / Système** (mémorisé), choix du dossier de
  téléchargement, version de l'app, politique de confidentialité, lien
  « L'équipe Loady ».
- Après fermeture de l'app, le dernier téléchargement terminé ou échoué est
  réaffiché une seule fois ; une analyse interrompue n'est **jamais relancée
  automatiquement** (l'utilisateur la relance s'il le souhaite).
- En cas d'échec : « Redémarrer le moteur et réessayer » (met à jour yt-dlp) et
  « Copier le diagnostic » (sans lien ni cookie).

Firebase Analytics (statistiques anonymes) et Firebase Cloud Messaging
(annonces via le sujet `all`) sont intégrés sur Android.

**Pas de publicité actuellement.** AdMob et Firebase Remote Config ont été
ajoutés (PR #27) puis retirés (PR #31, 19/10/2026) car l'APK `1.11.1+27`
se fermait au démarrage ; la cause exacte n'a pas été identifiée.

## Fonctionnement

1. **Validation du lien** : côté Flutter (`media_url_parser.dart`) puis côté
   Kotlin (`MediaUrls.validate`) : HTTPS et domaine autorisé uniquement.
2. **Analyse** : yt-dlp lit les métadonnées sans télécharger
   (`--dump-single-json --skip-download`, délai max 120 s).
3. **Tri des formats** (`MediaCatalog.kt`) : piste audio originale, association
   vidéo + audio compatible (M4A pour MP4, Opus/WebM pour WebM), aucune vidéo
   muette par erreur, une option par résolution et conteneur, plus une option MP3.
   Les 8 dernières analyses restent en mémoire côté natif ; sinon l'app demande
   de réanalyser le lien.
4. **Téléchargement** : yt-dlp télécharge les flux dans le stockage privé de
   l'app ; FFmpeg fusionne vidéo et audio ou convertit en MP3.
5. **Vérification** : fichier non vide et en-tête cohérent (MP4 `ftyp`, WebM
   EBML, MP3 ID3/frame). Un transfert à 100 % n'est pas un succès en soi.
6. **Enregistrement**, en tout ou rien (rien de partiel n'est laissé) :
   - **Android 10+** : `MediaStore` dans `Download/DAZDOWNLOADER`, fichier masqué
     (`IS_PENDING`) jusqu'à la fin. Aucune autorisation demandée.
   - **Android 7 à 9** : écriture directe dans `Download/DAZDOWNLOADER` avec
     l'autorisation de stockage, ouverture via un `FileProvider`.
   - **Dossier choisi par l'utilisateur** : Storage Access Framework (droit
     persistant sur ce seul dossier).
7. **Journal** (`TransferJournal.kt`) : mémorise l'issue pour la réafficher au
   prochain lancement.

Les noms de fichiers sont nettoyés et suffixés (`titre-xxxxxxxx.mp4`) ; aucun
fichier existant n'est écrasé.

## Moteur : yt-dlp, FFmpeg, youtubedl-android

| Élément | Version | Rôle |
|---|---|---|
| [youtubedl-android](https://github.com/yausername/youtubedl-android) | `0.18.1` (`io.github.junkfood02.youtubedl-android`, coordonnées Maven officielles du projet) | Embarque Python et FFmpeg pour Android et permet d'appeler yt-dlp depuis Kotlin |
| yt-dlp figé dans l'APK | `2026.08.19` | Téléchargé par Gradle depuis les releases officielles, vérifié par SHA-256 (`build.gradle.kts`), installé au premier lancement à la place du yt-dlp 2025 fourni par la bibliothèque |
| yt-dlp mis à jour à la demande | dernière version stable | Bouton « Redémarrer le moteur » (`updateYoutubeDL(STABLE)`), sans republier l'APK |

Les règles `android/app/proguard-rules.pro` sont indispensables : sans elles,
R8 supprimait des classes ZIP utilisées pour décompresser le moteur et le build
release `1.0.0+1` plantait. `tooling/check_release_zip.sh` reproduit ce cas.

## Architecture

```
lib/
  main.dart, app.dart          initialisation Firebase, thème, routeur
  core/                        analytics, notifications FCM, thème, routes, widgets
  features/
    home/                      accueil (champ lien, plateformes, derniers fichiers)
    download/                  analyse et téléchargement
      domain/                  modèles, contrat MediaEngine, validation des liens
      data/                    AndroidMediaEngine (canal natif), session locale
      presentation/            DownloadController (état), DownloadPage
    history/                   historique, ouverture, suppression
    settings/                  réglages
    shell/                     navigation, liens partagés vers l'app
android/app/src/main/kotlin/com/dazdownloader/dazdownloader/
  MainActivity.kt              canaux Flutter, partage entrant, permissions
  MediaBridge.kt               exécute yt-dlp/FFmpeg hors du thread UI, historique, dossier
  MediaCatalog.kt              sélection des formats, validation des URL
  EngineRuntime.kt             installation/vérification/mise à jour de yt-dlp
  DownloadStore.kt, MediaBatch.kt   validation et enregistrement des fichiers
  TransferJournal.kt           état du dernier transfert
  DownloadNotificationService.kt    notification de téléchargement
  InstagramErrors.kt, NativeRuntimeGuard.kt   messages d'erreur, garde au démarrage
```

Flutter et Kotlin communiquent par les canaux `dazdownloader/media`,
`dazdownloader/media/progress`, `dazdownloader/share` et
`dazdownloader/transfer_navigation`. Les URL signées des flux ne quittent jamais
le côté natif.

## Compilation (GitHub Actions)

Les builds se font sur GitHub Actions (gratuit et sans limite de minutes pour un
dépôt public, machines standard).

| Workflow | Déclencheur | Résultat |
|---|---|---|
| `build-apk.yml` | manuel ou tag `v*` | APK release **arm64 uniquement**, signé avec la clé de debug partagée (installable par-dessus les versions de test) |
| `build-release-aab.yml` | manuel ou tag `release-v*` | AAB pour Google Play, signé avec la clé d'upload |
| `preview-web.yml` | PR vers `main` | build web de contrôle (sans déploiement) |
| `deploy-web.yml` | push sur `main` | aperçu web sur GitHub Pages (`/dazdownloader/`) |

La version web sert uniquement d'aperçu de l'interface : elle ne télécharge rien.

**Aucun workflow ne lance encore les tests** (`flutter analyze`, `flutter test`,
tests Gradle) : à lancer localement avant chaque PR.

Les APK/AAB sont des artefacts conservés 90 jours ; attacher les versions à
garder à une Release GitHub.

Secrets GitHub utilisés : `GOOGLE_SERVICES_JSON_BASE64` (config Firebase, jamais
commitée), `DEBUG_KEYSTORE_BASE64`, `UPLOAD_KEYSTORE_BASE64`,
`UPLOAD_STORE_PASSWORD`, `UPLOAD_KEY_PASSWORD`, `UPLOAD_KEY_ALIAS`.

## Développement local

Prérequis : Flutter compatible avec `pubspec.yaml` (la CI utilise Flutter
3.47.5), SDK Android et JDK 17 pour les tests natifs.

```bash
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
cd android && JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 ./gradlew :app:testDebugUnitTest
```

Compiler l'APK localement demande beaucoup de mémoire (`org.gradle.jvmargs=-Xmx8G`
dans `android/gradle.properties`) : sur une machine modeste, utiliser la CI.

```bash
flutter build apk --release --split-per-abi   # APK par architecture
flutter build appbundle --release             # AAB pour Google Play
```

Sans `android/key.properties`, le build release est signé avec la clé de debug.

Les tests Flutter utilisent un faux moteur (aucun accès réseau). Les tests JVM
couvrent formats, URL, erreurs Instagram, enregistrement atomique et démarrage du
moteur ; ils ne testent ni MediaStore ni un vrai téléchargement.
La validation sur appareil est décrite dans
[la recette Android](docs/android-download-testing.md).

## Versions

`version: X.Y.Z+N` dans `pubspec.yaml` : `X.Y.Z` est le nom affiché
(`versionName`), `N` le `versionCode`, qui doit toujours augmenter (Android
refuse une mise à jour avec un `versionCode` inférieur). La version est
actuellement montée à la main dans les PR.

## Documentation

- [Feuille de route](dazplan.md) : état, décisions en attente, prochaines étapes.
- [Recette Android](docs/android-download-testing.md) : tests sur appareil.
- [Corrections des retours de test](correction.md) : historique (terminé).
- [Fiche Play Store](playstore/listing.md) et [ressources](playstore/README.md).
- `DAZDOWNLOADER_MVP_Specification.docx` : cahier des charges initial
  (25/09/2026), conservé à titre historique ; il ne décrit plus l'app actuelle.

## Distribution et licences

youtubedl-android est publié sous **GPL-3.0** et embarque notamment Python,
FFmpeg et QuickJS. Avant toute distribution publique, vérifier les obligations
de licence (licence du projet, sources, notices). Aucune licence n'est encore
déclarée pour Loady.

Avant une publication Google Play, points bloquants connus :

- `targetSdk` est à 35 ; Google Play exige **API 36** pour les nouvelles apps et
  mises à jour depuis le 31/08/2026.
- La mise à jour de yt-dlp à la demande télécharge du code exécutable hors du
  Play Store, ce que les règles Google Play interdisent.
- Les applications permettant de télécharger depuis YouTube sont généralement
  refusées par Google Play (et par AdMob).

Utiliser Loady uniquement pour des contenus dont le téléchargement est autorisé.
