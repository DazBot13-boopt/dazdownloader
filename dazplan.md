# Plan de développement Loady

## 1. Page d’analyse persistante — en cours

- Conserver le lien collé.
- Afficher une page dédiée à l’analyse.
- Sauvegarder l’état localement.
- Retrouver l’analyse après fermeture de l’application.
- Relancer l’analyse si elle a été interrompue.
- Conserver le résultat disponible.

Cette fonctionnalité sera la première Pull Request sur `feature/persistent-analysis`.

## 2. Téléchargements longs

- Service Android persistant.
- Reprise après coupure réseau.
- Nouvelles tentatives automatiques.
- Fichier temporaire.
- Reprise après fermeture de Loady.
- Vérification de l’espace disponible.
- Notifications : en cours, pause, reprise, terminé ou erreur.

## 3. Firebase Analytics

Mesurer anonymement les ouvertures, utilisateurs actifs, analyses lancées,
téléchargements réussis ou échoués, modèles et versions Android.

## 4. Firebase Notifications

- Messages comme « Bonne année ».
- Annonces importantes.
- Notifications programmées.
- Possibilité de désactivation par l’utilisateur.

## 5. Mises à jour automatiques

- Workflow GitHub Actions.
- Compilation automatique APK/AAB.
- Publication Google Play.
- Mise à jour automatique des utilisateurs.
- Firebase Remote Config pour activer certaines options sans republier.

## 6. Monétisation

- Intégrer AdMob en mode test.
- Garder les publicités désactivées au lancement.
- Les activer progressivement plus tard.
- Préparer Loady Premium sans publicité.

## 7. Publication Play Store

- Générer le fichier `.aab`.
- Configurer la signature release.
- Ajouter une politique de confidentialité.
- Vérifier les licences et les règles des plateformes.
- Publier d’abord en test fermé.

## 8. Badges GitHub

Créer de vraies Pull Requests testées puis fusionnées :

1. Design — déjà fusionné.
2. Analyse persistante.
3. Téléchargements longs.
4. Firebase Analytics.
5. Notifications Firebase.

Chaque PR utile fusionnée fera progresser **Pull Shark**. Une PR utile
fusionnée sans review pourra aussi valider **YOLO**.
