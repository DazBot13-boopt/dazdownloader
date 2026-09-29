# Recette du moteur Android

Statut : **à exécuter sur appareil**. Les tests automatisés ne prouvent pas
qu'un réseau social accepte actuellement un lien.

## Préparation

Installer l'APK adaptée, prévoir de l'espace pour les flux temporaires et le fichier
final, puis choisir de courtes vidéos publiques dont le téléchargement est autorisé.
Ne pas versionner d'URL privée, de cookie ou de lien signé. Garder l'app ouverte.

```bash
adb devices
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Si la signature de l'ancienne APK diffère, ne pas désinstaller automatiquement :
cela effacerait les données locales. Choisir la migration avec le propriétaire.

## Matrice de validation réelle

Noter appareil, version Android, version APK, date et résultat.
Toutes les lignes ci-dessous sont encore non vérifiées sur appareil.

| Plateforme | Aperçu réel | Vidéo enregistrée et lisible | MP3 si audio présent |
| --- | --- | --- | --- |
| YouTube / youtu.be | À tester | À tester | À tester |
| TikTok / lien court | À tester | À tester | À tester |
| Instagram Reel | À tester | À tester | À tester |
| Snapchat Spotlight public | À tester | À tester | À tester |
| X / publication vidéo | À tester | À tester | À tester |
| Facebook / fb.watch | À tester | À tester | À tester |

## Critères d'acceptation

- Titre et durée cohérents, aucune résolution fictive.
- MP4 progressif téléchargé et lisible.
- DASH/HLS à flux séparés : fichier final avec image **et son**.
- MP3 réellement converti, pas simplement renommé.
- Succès après transfert, conversion/fusion et enregistrement, jamais à la seule
  réception d'une progression à 100 %.
- Fichier non vide et ouvrable dans `Downloads/DAZDOWNLOADER`.
- Deux téléchargements identiques ne s'écrasent pas.
- Tester un lecteur compatible avec les codecs : MP4/WebM désignent des conteneurs.

## Erreurs et cycle de vie

- Annuler pendant l'analyse, le transfert et l'enregistrement : aucun faux succès.
- Annuler au moment de la publication : si celle-ci a déjà réussi, conserver le
  succès et le fichier.
- Couper le réseau ; vérifier l'erreur et la possibilité de réessayer.
- Tester stockage plein et permission refusée sur Android 7–9.
- Sur Android 10+, aucune permission globale de stockage n'est nécessaire.
- Liens privés, supprimés, profils, playlists, carrousels, directs, format expiré :
  message explicite, aucun faux téléchargement.
- Quitter l'écran puis revenir sans fermer l'app : suivi de l'opération conservé.
- Fermer/forcer l'arrêt : aucune promesse de reprise ou d'exécution persistante.
- Tester la mise à jour explicite de yt-dlp depuis l'écran d'erreur.
- Tester les appareils à pages mémoire de 16 Ko avant distribution : compiler
  l'APK ne valide pas à lui seul les binaires natifs embarqués.

## Hors périmètre de ce premier moteur

Téléchargements multiples, playlists/carrousels, directs, authentification,
historique persistant, dossier personnalisé, notifications et service en
arrière-plan, signature de production, version web.
