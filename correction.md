# Plan de correction des observations Loady

> **Document terminé, conservé pour l'historique.** Les 10 points ont été
> fusionnés avec la PR #33 (20/10/2026), puis complétés par #34 (analyse non
> relancée, audio original) et #40 (thème Clair / Sombre / Système). Les
> validations sur appareil restent à faire (voir
> `docs/android-download-testing.md`). Les sujets ouverts sont suivis dans
> `dazplan.md`.

État initial établi à partir du code du dépôt, puis suivi de mise en œuvre.

## Avancement

Les points 1 à 10 ont été implémentés dans le dépôt : libellé générique,
plateformes informatives sur deux/quatre colonnes, contraste Threads adapté au
thème, derniers téléchargements dynamiques, suppression d'un ou de tous les
fichiers, retrait de la qualité par défaut, politique de confidentialité,
sélection persistante du dossier Android, mémorisation du thème et restauration
manuelle d'une analyse interrompue. Le choix d'une plateforme n'affiche plus de
SnackBar.

La politique de confidentialité ouvre
https://loady-site.vercel.app/#confidentialite. Les validations sur appareil
restent à faire. `flutter analyze` n'a pas pu démarrer dans cet environnement car
la commande `flutter` n'y est pas installée.

## 1. Libellé du champ URL

**Observation :** le texte « URL de la vidéo ou des photos TikTok » apparaît
au-dessus du champ.

**Source :** `lib/features/home/presentation/home_page.dart`, `TextField`
(`InputDecoration.labelText`). Le hint d'exemple d'URL est défini séparément.

**Plan :** supprimer le `labelText`.

## 2. Présentation des plateformes et libellés tronqués

**Observation :** les icônes/noms sont à revoir; les cartes tronquent certains
noms. Il faut décider si elles servent à ouvrir les applications ou seulement à
indiquer les services pris en charge.

**Sources :**

- `lib/features/home/presentation/home_page.dart`, `_PlatformCard` : grille,
  icônes Font Awesome, libellés et `TextOverflow.ellipsis`.
- `lib/features/download/domain/media_models.dart`, `MediaPlatform.label` :
  noms affichés.
- Le `onTap` des cartes affiche actuellement un `SnackBar` et vide le champ;
  aucun lien vers les applications n'est configuré.

**Plan :** pour l'objectif actuel de présenter les plateformes prises en
charge, faire des cartes informatives sans action trompeuse, revoir leur mise en
page pour afficher les huit noms sans troncature et harmoniser les icônes.
Si l'ouverture des apps est préférée, définir ensuite les URL/destinations par
plateforme et le comportement de repli quand l'app n'est pas installée.

## 3. Icône Threads invisible en thème sombre

**Source :** `lib/features/home/presentation/home_page.dart`, `_PlatformCard`
`_color` donne à Threads la couleur fixe `0xFF101010`, presque identique au fond
sombre de la carte (`0xFF11151D`).

**Plan :** choisir la couleur selon `Theme.of(context).brightness` (par exemple
une teinte claire en thème sombre), puis vérifier contraste et lisibilité dans
les deux thèmes.

## 4. Derniers téléchargements absents de l'accueil

**Source :** `lib/features/home/presentation/home_page.dart` affiche toujours
`const _EmptyHistoryCard()` sous « Derniers téléchargements »; ce composant ne
lit pas l'historique.

**Plan :** réutiliser la lecture native existante de l'historique pour afficher
quelques fichiers récents sur l'accueil, avec ouverture au toucher et un lien
vers l'historique complet. Afficher l'état vide seulement si la liste est vide,
et prévoir un état de chargement/erreur. Éviter de maintenir deux implémentations
divergentes de la requête native.

## 5. Suppression d'un élément ou de tout l'historique

**Sources :**

- `lib/features/history/presentation/history_page.dart` propose uniquement
  l'ouverture et l'actualisation des éléments.
- `android/app/src/main/kotlin/com/dazdownloader/dazdownloader/MediaBridge.kt`,
  `history()` interroge les éléments du dossier actuel; les méthodes natives
  `open` et `history` ne proposent pas de suppression.
- `DownloadStore.kt` publie les fichiers via MediaStore sur Android 10+ et par
  fichier/`FileProvider` sur Android 7–9.

**Plan :** ajouter une action de suppression par ligne et une action « Tout
supprimer » avec confirmation explicite. Ajouter les méthodes natives
correspondantes et retirer uniquement les fichiers gérés par Loady dans son
dossier, avec gestion des erreurs et actualisation de la liste. Confirmer le
comportement Android des fichiers et URI avant d'implémenter la suppression
groupée.

## 6. Retirer « Qualité par défaut » et ajouter la politique de confidentialité

**Source :** `lib/features/settings/presentation/settings_page.dart` contient
une `ListTile` « Qualité par défaut » (sous-titre 1080p) sans action associée.
La page n'a pas de lien de politique de confidentialité.

**Plan :** supprimer cette option puisque la qualité se choisit à l'analyse;
ajouter dans Réglages un lien ouvrant la politique dans le navigateur. L'URL
publique de la politique reste à fournir/définir au moment de la mise en œuvre.

## 7. Choix de l'emplacement de téléchargement

**Sources :**

- `lib/features/settings/presentation/settings_page.dart` affiche « Downloads ·
  Android » dans une ligne sans action.
- `android/app/src/main/kotlin/com/dazdownloader/dazdownloader/DownloadStore.kt`
  enregistre en chemin fixe `Downloads/DAZDOWNLOADER` (MediaStore Android 10+,
  dossier public sur les versions antérieures).
- `MediaBridge.kt` et la page Historique filtrent également sur ce dossier fixe.

**Plan :** permettre le choix d'un dossier avec le sélecteur Android (Storage
Access Framework), enregistrer et restaurer l'URI autorisée, puis faire écrire
le moteur natif à cette destination. Adapter l'ouverture, l'historique, la
suppression et les permissions persistantes à cette URI. Pour Android 10+,
préférer une URI d'arbre de documents plutôt qu'un chemin fichier arbitraire;
prévoir une migration ou une valeur par défaut pour les installations existantes.

## 8. Le thème choisi n'est pas conservé

**Sources :**

- `lib/core/settings/theme_mode_controller.dart`, `build()` retourne toujours
  `ThemeMode.light`.
- `setDarkMode()` ne fait que changer l'état en mémoire.
- `lib/app.dart` applique l'état fourni à `MaterialApp.router`.

**Plan :** persister le choix clair/sombre (par exemple avec
`SharedPreferencesAsync`), le charger avant ou pendant l'initialisation du
provider, puis enregistrer chaque changement. Garder clair comme valeur initiale
si aucune préférence n'a encore été sauvegardée.

## 9. Notifications d'interface empilées au toucher des plateformes

**Source :** `lib/features/home/presentation/home_page.dart`, callback `onTap`
des cartes utilise `ScaffoldMessenger.showSnackBar`. L'implémentation par défaut
peut mettre les notifications successives en file; chaque clic en ajoute une.

**Plan :** faire remplacer l'élément visible à chaque clic en retirant ou
remplaçant le SnackBar courant avant d'afficher le nouveau. Si les cartes
deviennent purement informatives (point 2), supprimer leur action et donc cette
notification, qui n'est alors plus nécessaire.

## 10. Une ancienne analyse redémarre après fin ou retour dans l'app

**Sources :**

- `lib/features/download/presentation/download_controller.dart`, `resolve()`
  sauvegarde le lien comme `pending_analysis_url` avant l'analyse.
- `lib/features/download/data/download_session_store.dart` ne conserve que ce
  lien en attente.
- `_restoreSession()` relance `_restorePendingAnalysis()` au démarrage à froid
  si aucun transfert terminé/échoué prioritaire n'est restauré.
- `_fail()` met l'état en échec/annulé, mais ne supprime pas le lien en attente;
  le lien n'est effacé qu'après téléchargement réussi (ou restauration d'un
  succès journalisé).
- `AppShell` conserve le contrôleur d'application pendant la navigation; le
  simple retour à l'app depuis l'arrière-plan peut retrouver son état Dart,
  tandis qu'un redémarrage à froid suit le chemin de restauration décrit plus
  haut.

**Plan :** définir les états qui doivent survivre à une fermeture. Ne jamais
relancer automatiquement une analyse déjà terminée, échouée ou annulée. Effacer
le marqueur d'analyse en attente à l'issue de ces états, ou enregistrer un état
de session explicite (lien + statut + date) et restaurer l'écran correspondant
sans redémarrer le moteur. Ne reprendre automatiquement qu'une opération
identifiée comme interrompue et réellement reprenable; sinon présenter le lien
avec une action manuelle « Réanalyser ». Tester fin d'analyse, erreur,
annulation, navigation, arrière-plan et redémarrage forcé.

## Ordre proposé

1. Ajustements d'interface rapides : libellé URL, carte Threads, notifications,
   qualité par défaut et politique (après définition de son URL).
2. Historique partagé entre accueil et page dédiée, puis suppression sécurisée.
3. Persistance du thème.
4. Corriger le cycle de vie/restauration des analyses et le vérifier sur appareil.
5. Concevoir le choix du dossier et intégrer son URI à toute la chaîne native.
6. Décider si les cartes de plateformes sont informatives ou ouvrent les apps;
   finaliser les icônes et la mise en page en conséquence.
