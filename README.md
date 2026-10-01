# DAZDOWNLOADER

Application Android Flutter de téléchargement local de médias publics accessibles.
Pas de compte DAZDOWNLOADER, pas de serveur utilisateur ni de synchronisation cloud.

Le simulateur a été remplacé par **yt-dlp + FFmpeg** via
[youtubedl-android 0.18.1](https://github.com/yausername/youtubedl-android/tree/0.18.1).
L'intégration est compilable et testée automatiquement ; la validation réelle sur
appareil et sur les six plateformes reste à effectuer.

## Fonctionnement

1. Coller le lien d'une vidéo YouTube, TikTok, Instagram, Snapchat, X ou Facebook.
2. Analyser ses vraies métadonnées et ses formats accessibles.
3. Sélectionner MP4, WebM ou MP3 selon ce que le média permet.
4. Télécharger ; FFmpeg assemble les flux séparés ou extrait l'audio.
5. Ouvrir le fichier enregistré dans `Downloads/DAZDOWNLOADER`.

Les résolutions ne sont pas inventées : une source 360p ne propose pas 1080p.
Les résolutions supérieures apparaissent si disponibles. La taille inconnue d'un
flux ou d'un MP3 converti n'est pas remplacée par une estimation fictive.

La progression distingue transfert, traitement et enregistrement. Un transfert
à 100 % n'est pas un succès : il faut la fin de FFmpeg, un fichier non vide avec
un en-tête cohérent, puis sa publication dans Downloads.

## Limites de cette première intégration

- Android 7/API 24 minimum. Pas de moteur de téléchargement dans le navigateur.
- Une vidéo et une opération à la fois. Le téléchargement continue en arrière-plan
  avec une notification Android tant que le système conserve le service actif ;
  une reprise après arrêt forcé du processus n'est pas garantie.
- Playlists, publications multi-médias et directs en cours refusés explicitement.
  Les replays terminés peuvent être téléchargés.
- Aucune connexion aux réseaux sociaux, aucun cookie importé, aucun contournement
  de DRM. Un lien public peut malgré tout être bloqué par la plateforme.
- Reconnaître un domaine ne garantit pas le téléchargement de tous ses contenus :
  le support dépend des extracteurs de yt-dlp et des restrictions de la plateforme.
- L'historique Android lit les fichiers enregistrés dans
  `Downloads/DAZDOWNLOADER`. Le partage Android accepte les liens texte entrants.
  Le dossier personnalisé et les préférences persistantes restent à développer.

En cas d'échec, **Mettre à jour le moteur et réessayer** télécharge explicitement
la version stable de yt-dlp depuis GitHub, puis refait l'analyse. Ce n'est ni une
mise à jour automatique de l'APK ni une garantie de résolution des restrictions.

## Architecture

- `lib/features/download/domain/media_engine.dart` : contrat du moteur.
- `lib/features/download/data/android_media_engine.dart` : commandes et progression.
- `lib/features/download/presentation/download_controller.dart` : état de l'opération.
- Dans `android/app/src/main/kotlin/com/dazdownloader/dazdownloader/` :
  `MediaBridge.kt` exécute yt-dlp/FFmpeg hors du thread UI ; `MediaCatalog.kt`
  sélectionne les vrais formats ; `DownloadStore.kt` valide et enregistre les fichiers.

Android 10+ utilise `MediaStore` avec une entrée masquée pendant l'écriture.
Android 7–9 demande l'autorisation de stockage et utilise un `FileProvider` limité
au dossier DAZDOWNLOADER. Noms nettoyés et individualisés, aucune écriture sur un
fichier existant. Les flux signés restent côté natif.

## Développement

Prérequis : Flutter compatible avec `pubspec.yaml`, SDK Android et JDK 17.

```bash
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
cd android
JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 ./gradlew :app:testDebugUnitTest
```

Depuis la racine du projet :

```bash
JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 flutter build apk --release --split-per-abi
```

APK dans `build/app/outputs/flutter-apk/`. Pour la plupart des téléphones récents :
`app-arm64-v8a-release.apk`. Les builds release utilisent encore la **clé de debug** :
ce sont des builds de test, pas des versions prêtes à publier.

Les tests Flutter utilisent un double de moteur, jamais des téléchargements réseau.
Les tests JVM vérifient formats, URL, validation minimale des fichiers et courses
annulation/publication ; ils ne testent pas MediaStore sur appareil.

La version `1.0.1+2` corrige un crash d'initialisation propre au build release :
R8 supprimait des constructeurs ZIP utilisés par réflexion pour décompresser le
moteur. Les règles requises sont conservées dans `android/app/proguard-rules.pro`.
Les erreurs de chargement du moteur sont désormais remontées dans l'interface.
Le test `tooling/check_release_zip.sh` reproduit l'échec après optimisation sans
ces règles, puis vérifie leur correction (voir la recette ci-dessous).
Cela ne remplace pas un nouvel essai sur le téléphone concerné.

Voir [la recette Android](docs/android-download-testing.md) pour la validation réelle.

## Distribution

youtubedl-android est publié sous GPL-3.0 et embarque notamment FFmpeg, Python et
QuickJS. Avant distribution publique, vérifier les obligations de licence de
l'ensemble (sources, notices, options de compilation). Cette intégration ne
choisit pas automatiquement une nouvelle licence pour le projet. Utiliser des
contenus pour lesquels le téléchargement est autorisé.
