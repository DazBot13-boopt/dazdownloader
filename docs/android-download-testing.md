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

## Régression de fermeture à l'analyse — 1.0.1+2

Un défaut du build release `1.0.0+1` a été reproduit localement après optimisation
R8 : les constructeurs ZIP utilisés par réflexion étaient supprimés, provoquant
une `ExceptionInInitializerError` non interceptée lors du démarrage du moteur.
Le build `1.0.1+2` conserve ces classes et transforme les `LinkageError` en erreur
visible, sans intercepter les erreurs fatales de la VM comme un manque de mémoire.
La correspondance avec le crash signalé reste à confirmer sur le téléphone.

Test reproductible sur la JVM, avec R8 et la dépendance réellement utilisée :

```bash
bash tooling/check_release_zip.sh /chemin/jdk-17 /chemin/android-sdk/build-tools/36.0.0/lib/d8.jar /chemin/commons-compress-1.12.jar
```

Ce test doit d'abord reproduire l'échec sans les règles, puis afficher
`ZIP runtime initialization passed after R8.` avec les règles du projet.
Il n'exécute ni Android ni les binaires Python/FFmpeg. Après compilation, vérifier
aussi que `build/app/outputs/mapping/release/configuration.txt` contient les deux
règles de `android/app/proguard-rules.pro`.

Sur appareil, utiliser le nouvel **APK release**, pas seulement un build debug :

1. Installer `1.0.1` par-dessus l'ancienne version, sans effacer ses données.
2. Fermer puis relancer l'app ; coller une URL via le bouton ou le menu Android.
   Le champ doit se remplir sans lancer d'analyse ni fermer l'app.
3. Appuyer sur **Analyser le lien** (ou valider avec le clavier) : attendre un
   aperçu ou une erreur visible, jamais une fermeture du processus.
4. Refaire l'essai après une erreur, puis télécharger et ouvrir une courte vidéo.
5. Vérifier également le premier démarrage sur une installation vierge dans un
   appareil/profil de test distinct ; ne pas supprimer les données de l'utilisateur.

Si l'app ferme encore, relever modèle, version Android, version APK et action
exacte : collage, validation clavier ou bouton d'analyse. Avec un PC déjà autorisé
pour le débogage USB, le journal de crash se consulte avec :

```bash
adb logcat -d -b crash -v threadtime AndroidRuntime:E '*:S'
```

Ne partager que le bloc concernant `com.dazdownloader.dazdownloader`, en masquant
les liens privés et autres données personnelles. Si l'app reste ouverte avec un
message de démarrage du moteur, une capture du message suffit pour commencer.

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
