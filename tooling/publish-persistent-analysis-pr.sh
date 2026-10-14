#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="/home/ubuntu/dazdownloader"
BRANCH="feature/persistent-analysis"
COMMIT_MESSAGE="feat: persist analysis session across app restarts"
PR_TITLE="feat: persist analysis session"

cd "$PROJECT_DIR"

if [[ "$(git branch --show-current)" != "$BRANCH" ]]; then
  echo "Erreur : lance d’abord tooling/start-persistent-analysis.sh" >&2
  exit 1
fi

echo "==> Mise à jour des dépendances"
/home/ubuntu/tools/flutter/bin/flutter pub get

echo "==> Analyse statique"
/home/ubuntu/tools/flutter/bin/flutter analyze --no-pub

echo "==> Tests Flutter"
/home/ubuntu/tools/flutter/bin/flutter test --no-pub

echo "==> Ajout des fichiers de la fonctionnalité"
git add -- \
  pubspec.yaml \
  pubspec.lock \
  lib/features/download/data/download_session_store.dart \
  lib/features/download/presentation/download_controller.dart \
  lib/features/home/presentation/home_page.dart \
  lib/features/shell/presentation/app_shell.dart \
  test/paste_link_test.dart \
  tooling/publish-persistent-analysis-pr.sh \
  tooling/publish-analysis.sh \
  tooling/start-analysis.sh

git diff --cached --check

if git diff --cached --quiet; then
  echo "Aucune modification à publier."
  exit 0
fi

echo "==> Commit"
git commit -m "$COMMIT_MESSAGE"

echo "==> Push de la branche"
git push --set-upstream origin "$BRANCH"

echo "==> Création ou affichage de la Pull Request"
if gh pr view "$BRANCH" --repo DazBot13-boopt/dazdownloader >/dev/null 2>&1; then
  gh pr view "$BRANCH" --repo DazBot13-boopt/dazdownloader --web
else
  gh pr create \
    --repo DazBot13-boopt/dazdownloader \
    --base main \
    --head "$BRANCH" \
    --title "$PR_TITLE" \
    --body "## Résumé

- mémorise le dernier lien d'analyse localement ;
- restaure automatiquement l'analyse au retour dans Loady ;
- rouvre la page dédiée avec le résultat ou l'état en cours ;
- ajoute les tests statiques et Flutter avant publication.

## Vérifications

- flutter analyze --no-pub
- flutter test --no-pub"
fi

echo "Terminé : la Pull Request d'analyse persistante est prête."
