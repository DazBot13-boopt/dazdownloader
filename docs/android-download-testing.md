# Recette Android

Statut : **à exécuter sur appareil**. Les tests automatisés ne prouvent pas
qu'une plateforme accepte actuellement un lien.

Version visée : `1.13.0+34` ou plus récente.

## Préparation

Récupérer l'APK produit par le workflow GitHub Actions **Build Android APK**
(artefact `loady-apk-<version>`). Il est **arm64 uniquement** : il ne s'installe
pas sur un téléphone 32 bits.

Prévoir de l'espace pour les flux temporaires et le fichier final, puis choisir
de courtes vidéos publiques dont le téléchargement est autorisé. Ne pas
versionner d'URL privée, de cookie ou de lien signé.

```bash
adb devices
adb install -r loady-<version>-arm64-v8a.apk
```

Si la signature de l'ancienne APK diffère, ne pas désinstaller automatiquement :
cela effacerait les données locales. Choisir la migration avec le propriétaire.

Pour chaque essai, noter : appareil, version Android, version APK, date,
résultat.

## Matrice par plateforme

Toutes les lignes sont encore **non vérifiées sur appareil**.

| Plateforme | Aperçu réel | Vidéo enregistrée et lisible | MP3 si audio présent |
| --- | --- | --- | --- |
| YouTube / youtu.be / Shorts | À tester | À tester | À tester |
| TikTok / lien court vm.tiktok.com | À tester | À tester | À tester |
| Instagram Reel | À tester | À tester | À tester |
| Snapchat Spotlight public | À tester | À tester | À tester |
| X / publication vidéo | À tester | À tester | À tester |
| Facebook / fb.watch | À tester | À tester | À tester |
| Pinterest / pin.it (pin vidéo) | À tester | À tester | À tester |
| Threads (publication vidéo) | À tester | À tester | À tester |

À couvrir au minimum sur un Android 7–9, un Android 10–12 et un Android 13+.

## Critères d'acceptation du téléchargement

- Titre et durée cohérents, aucune résolution fictive.
- MP4 téléchargé et lisible ; WebM lisible avec un lecteur compatible
  (MP4/WebM sont des conteneurs, le lecteur doit gérer les codecs).
- Flux séparés (DASH/HLS) : fichier final avec image **et son**.
- Piste audio dans la langue originale (vidéo YouTube avec doublages).
- MP3 réellement converti, pas simplement renommé.
- Succès affiché seulement après transfert, conversion/fusion et enregistrement.
- Fichier non vide et ouvrable dans `Download/DAZDOWNLOADER` ou dans le dossier
  choisi.
- Deux téléchargements identiques ne s'écrasent pas.

## Erreurs et cycle de vie

- Annuler pendant l'analyse, le transfert et l'enregistrement : aucun faux
  succès, aucun fichier partiel.
- Couper le réseau pendant un transfert : nouvelles tentatives (3 au maximum),
  puis erreur explicite.
- Stockage plein ; permission de stockage refusée sur Android 7–9.
- Sur Android 10+ : aucune permission de stockage demandée.
- Liens privés, supprimés, profils, playlists, carrousels (TikTok `/photo/`),
  directs, format expiré : message explicite, aucun faux téléchargement.
- Quitter l'écran puis revenir : suivi de l'opération conservé.
- Mettre l'app en arrière-plan pendant un téléchargement : notification de
  progression, puis notification de fin.
- Forcer l'arrêt pendant un téléchargement : vérifier qu'aucune notification
  « Téléchargement en cours… » ne reste bloquée, et ce qui s'affiche au
  relancement.
- Rouvrir l'app après une analyse interrompue : message « L'analyse a été
  interrompue », **aucune relance automatique**.
- Rouvrir l'app après un téléchargement terminé : le résultat s'affiche une
  seule fois.
- « Redémarrer le moteur et réessayer » depuis un écran d'erreur.
- « Copier le diagnostic » : ne contient ni lien ni cookie.

## Fonctions de l'app

- Partager un lien depuis une autre app vers Loady : l'analyse s'ouvre.
- Accueil : les 3 derniers téléchargements s'affichent et s'ouvrent.
- Historique : ouvrir, supprimer un fichier, tout supprimer (avec
  confirmation).
- Réglages : choisir un dossier, télécharger dedans, le retrouver dans
  l'historique, rétablir le dossier par défaut.
- Thème Clair / Sombre / Système : choix conservé après redémarrage.
- Liens « Politique de confidentialité » et « L'équipe Loady ».
- Notification Firebase envoyée au sujet `all` : reçue app fermée.

## Démarrage du moteur (régression 1.0.0+1)

Le build release `1.0.0+1` plantait à l'analyse : R8 supprimait des classes ZIP
utilisées pour décompresser le moteur. Les règles de
`android/app/proguard-rules.pro` corrigent ce problème, et les erreurs de
chargement du moteur s'affichent désormais dans l'interface.

Test reproductible sur la JVM, avec R8 :

```bash
bash tooling/check_release_zip.sh /chemin/jdk-17 /chemin/android-sdk/build-tools/36.0.0/lib/d8.jar /chemin/commons-compress-1.12.jar
```

Il doit d'abord reproduire l'échec sans les règles, puis afficher
`ZIP runtime initialization passed after R8.` avec les règles du projet.

## En cas de fermeture de l'app

Relever modèle, version Android, version APK et action exacte. Avec un PC
autorisé pour le débogage USB :

```bash
adb logcat -d -b crash -v threadtime AndroidRuntime:E '*:S'
```

Ne partager que le bloc concernant `com.dazdownloader.dazdownloader`, en masquant
les liens privés et autres données personnelles.

Rappel : la version `1.11.1+27` (AdMob + Remote Config) se fermait au démarrage
sans trace exploitable ; en cas de réintégration d'un plugin natif, tester le
démarrage sur au moins deux téléphones avant de fusionner.

## Avant distribution

- Tester sur un appareil à pages mémoire de 16 Ko : compiler l'APK ne valide pas
  à lui seul les binaires natifs embarqués.

## Hors périmètre actuel

Téléchargements simultanés, playlists et carrousels, photos, directs en cours,
connexion aux comptes et cookies, version web fonctionnelle.
