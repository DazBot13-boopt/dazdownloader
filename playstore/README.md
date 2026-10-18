# playstore/

Tout ce qu'il faut pour déposer Loady sur le Google Play Store.
Le jour venu, ouvre `listing.md` et copie-colle section par section
dans Play Console.

## Fichiers

| Fichier | Rôle |
|---|---|
| `listing.md` | Textes FR du listing, catégorie, Data Safety, Content Rating, checklist pré-submit |
| `loady-icon-512.png` | Icône 512×512 pour la fiche Play Store (**32-bit PNG avec alpha**) |
| `loady-feature-graphic.png` | Bannière 1024×500 en haut de la fiche Play Store |
| `loady-icon.svg` | Source vectorielle de l'icône, pour re-rasteriser à n'importe quelle taille |
| `make_feature_graphic.py` | Génère `loady-feature-graphic.png` à partir de `loady-icon-512.png` (Pillow) |

## Régénérer les assets

Si tu changes le design :

```bash
# Icône PNG depuis le SVG (ImageMagick)
magick -background none -density 300 playstore/loady-icon.svg \
       -resize 512x512 playstore/loady-icon-512.png

# Feature graphic (depuis l'icône PNG)
python3 playstore/make_feature_graphic.py
```

Dépendances : `imagemagick` + `python3-pil` (`sudo apt install imagemagick python3-pil`).

## Prochaines étapes de dépôt

Voir la "Checklist avant submit" en bas de `listing.md`. En résumé :

1. Compte Play Console (25 $)
2. Générer l'upload keystore + push 4 secrets GitHub
3. Lancer le workflow `Build Release AAB (Play Store)` → télécharger le .aab
4. Créer l'app dans Play Console → copier-coller depuis `listing.md`
5. Upload des 3 assets ici + 6 screenshots pris sur le téléphone
6. Submit sur Internal testing en premier
