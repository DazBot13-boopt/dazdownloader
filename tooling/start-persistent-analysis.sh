#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="/home/ubuntu/dazdownloader"
BRANCH="feature/persistent-analysis"

cd "$PROJECT_DIR"

echo "==> Synchronisation de main avec le design fusionné"
git switch main
git pull --ff-only origin main

if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  echo "==> La branche $BRANCH existe déjà"
  git switch "$BRANCH"
else
  echo "==> Création de $BRANCH"
  git switch -c "$BRANCH"
fi

echo
echo "Branche active : $(git branch --show-current)"
echo "Dernier commit : $(git log -1 --oneline)"
echo
git status --short
echo
echo "Prêt pour développer la page d’analyse persistante."
