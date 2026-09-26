# DAZDOWNLOADER

Application Android (Flutter) de téléchargement de médias : on colle un lien,
l'app détecte la plateforme, propose les formats disponibles, puis enregistre
le fichier localement.

> **Statut : MVP UI.** L'interface, le routage, le thème et la validation
> d'URL sont réels et testés. Le moteur de téléchargement est encore un
> simulateur — voir [Ce qui manque](#ce-qui-manque-pour-un-usage-réel).

## Plateformes reconnues

YouTube · TikTok · Instagram · Snapchat · X · Facebook

La détection est faite par `MediaUrlParser`, qui normalise l'URL (ajoute le
schéma, retire le fragment), refuse les URL vides / malformées / non supportées
et gère les sous-domaines.

## Architecture

```
lib/
├── main.dart                     ProviderScope + DazDownloaderApp
├── app.dart                      MaterialApp.router + thème
├── core/
│   ├── routing/app_router.dart   go_router (ShellRoute + 4 routes)
│   ├── settings/                 contrôleur de mode sombre
│   └── theme/app_theme.dart      thème Material 3 clair/sombre
└── features/
    ├── home/presentation/        champ URL, collage, grille plateformes
    ├── download/
    │   ├── domain/               MediaPreview, MediaFormatOption, MediaUrlParser
    │   ├── data/                 MediaEngine (interface) + FakeMediaEngine
    │   └── presentation/        DownloadPage + DownloadController (Riverpod)
    ├── history/presentation/     état vide (persistance à venir)
    ├── settings/presentation/    mode sombre + à propos
    └── shell/presentation/       NavigationBar
```

**State management** : Riverpod 3 (`Notifier` pour le thème, `AsyncNotifier`
pour la résolution d'URL).
**Navigation** : go_router 18.
**Dépendances** : uniquement `flutter_riverpod`, `go_router`, `cupertino_icons`.

## Lancer le projet

```bash
flutter pub get
flutter run                  # appareil ou émulateur Android
flutter analyze              # doit renvoyer "No issues found!"
flutter test                 # 3 tests
```

### Build APK release

```bash
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64   # Java 25 n'a pas de JAVA_COMPILER
flutter build apk --release --split-per-abi
```

Les artefacts sont lands dans `build/app/outputs/flutter-apk/` :

| ABI | Fichier | Taille |
|---|---|---|
| arm64-v8a | `app-arm64-v8a-release.apk` | ~17 Mo |
| armeabi-v7a | `app-armeabi-v7a-release.apk` | ~15 Mo |
| x86_64 | `app-x86_64-release.apk` | ~19 Mo |

## Tests

| Fichier | Couverture |
|---|---|
| `test/media_url_parser_test.dart` | URL supportées, malformées, refusées |
| `test/widget_test.dart` | rendu de l'accueil |

## Ce qui manque pour un usage réel

1. **Moteur de téléchargement** — `FakeMediaEngine` renvoie un aperçu codé en
   dur avec un délai artificiel de 650 ms. Le bouton « Télécharger » affiche
   seulement un message.
2. **Historique** — `HistoryPage` affiche un état vide codé en dur, aucune
   persistance.
3. **Réglages** — le mode sombre n'est pas persisté ; deux `ListTile` n'ont
   aucune action.
4. **Permissions** — `INTERNET` et `WRITE_EXTERNAL_STORAGE` sont déclarés mais
   le dossier de sauvegarde n'est pas encore demandé à l'utilisateur.
5. **Signature** — le build release utilise encore les clés de debug.

## Licence

Usage privé / expérimental.
