# Loady — Play Store Listing (FR)

Tout ce qu'il faut taper dans Play Console → Store listing. Les champs
sont dans l'ordre que Google te présente.

---

## 1. Store listing

### Titre (max 30 caractères)
```
Loady · Télécharger vidéos
```
(27/30 — reste 3 chars de marge)

### Description courte (max 80 caractères)
```
Télécharge vidéos et photos YouTube, TikTok, Insta, X, FB — en local, sans compte.
```
(80/80 pile)

### Description longue (max 4000 caractères)
```
Loady, c'est le téléchargeur de médias simple, rapide et 100 % local.

Colle un lien, choisis la qualité, télécharge. Tout se passe sur ton téléphone — rien n'est copié sur un serveur, rien ne demande de compte.

━━━━━━━━━━━━━━━━━━━━
PLATEFORMES PRISES EN CHARGE
━━━━━━━━━━━━━━━━━━━━
• YouTube — vidéos, Shorts
• TikTok — vidéos et photos (y compris les liens courts vm.tiktok.com)
• Instagram — Reels, posts
• Snapchat — Spotlight
• X (Twitter) — vidéos
• Facebook — vidéos
• Pinterest — pins vidéo et image
• Threads — vidéos et images

━━━━━━━━━━━━━━━━━━━━
POURQUOI LOADY
━━━━━━━━━━━━━━━━━━━━
✓ 100 % local — les fichiers restent sur ton téléphone, ne passent par aucun serveur
✓ Sans compte, sans inscription
✓ Détection automatique de la plateforme depuis le lien collé
✓ Choix de la qualité avant téléchargement
✓ Historique des téléchargements accessible, effaçable à tout moment
✓ Interface claire, en français, pensée pour aller vite
✓ Mode sombre natif
✓ Léger (<30 Mo) et optimisé arm64

━━━━━━━━━━━━━━━━━━━━
COMMENT ÇA MARCHE
━━━━━━━━━━━━━━━━━━━━
1. Copie l'URL depuis l'app source (YouTube, TikTok…)
2. Ouvre Loady — colle le lien, l'app détecte la plateforme
3. Choisis la qualité
4. Télécharge — le fichier atterrit dans ta galerie

━━━━━━━━━━━━━━━━━━━━
RESPECT DE LA VIE PRIVÉE
━━━━━━━━━━━━━━━━━━━━
Loady ne lit pas tes contacts, ne connaît pas ton numéro, ne te demande ni email ni mot de passe. Les seules données techniques envoyées sont des statistiques d'usage anonymes (via Firebase Analytics) pour corriger les bugs. Détails complets dans notre politique de confidentialité : https://togbedji-daziano.vercel.app/loady-privacy

━━━━━━━━━━━━━━━━━━━━
UTILISATION RESPONSABLE
━━━━━━━━━━━━━━━━━━━━
Loady télécharge uniquement du contenu accessible publiquement. Respecte les droits d'auteur et les conditions d'utilisation de chaque plateforme — Loady est pour un usage personnel.

━━━━━━━━━━━━━━━━━━━━
CONTACT
━━━━━━━━━━━━━━━━━━━━
Un bug, une suggestion ? Écris-nous : daziano13@gmail.com
Site : https://togbedji-daziano.vercel.app
```
(~1980 caractères — large marge pour en rajouter si tu veux)

---

## 2. Graphics

| Asset | Spec | Fichier prêt |
|---|---|---|
| App icon | 512×512 PNG 32-bit | `scratchpad/loady-icon-512.png` |
| Feature graphic | 1024×500 PNG/JPEG, <1 Mo | `scratchpad/loady-feature-graphic.png` |
| Phone screenshots | min 2, max 8, 16:9 ou 9:16 portrait, min 320px côté court | à prendre sur ton tel |

### Captures à prendre sur ton tel (dans l'ordre pour le story-telling)
1. **Home** — hero "Ton contenu. Ton appareil. Tes règles." + champ URL
2. **Grille des 8 plateformes** (scroll bas du home)
3. **Résultat d'analyse** — après avoir collé un lien YouTube, l'écran qui liste les qualités
4. **Téléchargement en cours** — barre de progression
5. **Historique** — avec quelques items
6. **Settings** — pour montrer "Contacter les dev"

Astuce : prend-les en mode sombre, c'est l'identité visuelle de l'app.

---

## 3. Categorization

- **App or game** : App
- **Category** : Video Players & Editors (pas "Music & Audio", Google tolère mieux les téléchargeurs ici)
- **Tags** : Video, Downloader, Media

---

## 4. Contact details

- **Website** : https://togbedji-daziano.vercel.app
- **Email** : daziano13@gmail.com
- **Phone** : (laisser vide)
- **Privacy policy** : https://togbedji-daziano.vercel.app/loady-privacy ← ← ← DOIT ÊTRE ICI

---

## 5. Data safety (le formulaire chiant mais obligatoire)

### Section "Does your app collect or share any of the required user data types?"
→ **Yes**

### Data types to declare

Pour chaque entrée : collected = Yes, shared = No (sauf AdMob qui partage), processed ephemerally = No, user can request deletion = Yes (via mail).

| Data type | Collected | Shared | Purpose |
|---|---|---|---|
| **App interactions** (events analytics) | Yes | No | Analytics |
| **Crash logs** | Yes | No | Analytics, App functionality |
| **Diagnostics** (perf) | Yes | No | Analytics |
| **Device or other IDs** (Advertising ID, FCM token) | Yes | **Yes** (shared with Google AdMob) | Advertising, App functionality |
| **Approximate location** (dérivée de l'IP par Firebase) | Yes | No | Analytics |

### Security practices
- Data encrypted in transit : **Yes** (HTTPS pour toutes les requêtes Firebase + AdMob)
- Users can request data deletion : **Yes** (via email `daziano13@gmail.com`)
- Committed to Play Families Policy : **No** (pas destinée aux enfants)

---

## 6. Content rating

Google te fera remplir un questionnaire IARC. Réponses pour Loady :
- Violence : **No**
- Sexual content : **No**
- Profanity : **No**
- Controlled substances : **No**
- User-generated content : **No** (on ne poste rien, on télécharge)
- User interaction with other users : **No**
- Shares user location : **No**
- Allows digital purchases : **No**
→ Rating final attendu : **PEGI 3 / ESRB Everyone / IARC 3+**

---

## 7. Target audience and content

- **Target age** : 13+ (parce qu'on envoie des pubs AdMob qui lisent l'Advertising ID, donc on ne peut pas cibler <13)
- **Appeal to children** : No

---

## 8. News app, COVID-19 app, Government app, Financial features
Tous **No**.

---

## 9. Ads
- **Does your app contain ads?** → **Yes**
  (Loady affiche une bannière AdMob quand le kill-switch Remote Config `ads_enabled` est vrai. Même si c'est à `false` au lancement, Google exige qu'on déclare le code publicitaire présent.)

---

## 10. App access
- **All functionality available without special access** → **Yes** (pas de login)

---

## Checklist avant submit

- [ ] Icon 512×512 uploadé
- [ ] Feature graphic 1024×500 uploadé
- [ ] Au moins 2 screenshots phone uploadés
- [ ] Titre + short desc + long desc remplis
- [ ] Privacy policy URL = https://togbedji-daziano.vercel.app/loady-privacy
- [ ] Email contact = daziano13@gmail.com
- [ ] Data safety validé (bouton "Submit" dans la section)
- [ ] Content rating validé
- [ ] Target audience validé
- [ ] Ads declaration = Yes
- [ ] AAB uploadé dans Internal testing (lance d'abord `Build Release AAB` workflow)
- [ ] Testeurs internes ajoutés (au moins ton propre mail Google)
- [ ] Review Google (quelques heures à quelques jours pour Internal testing)
