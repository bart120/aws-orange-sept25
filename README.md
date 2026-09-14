# Formation — Supervision, Observabilité & Gouvernance sur AWS

Dépôt de travaux pratiques. Tout se passe dans **CloudShell**, depuis la console AWS de votre sandbox.

---

## Au tout début du J1

```bash
git clone https://github.com/bart120/aws-orange-sept25.git ~/lab
cd ~/lab
```

Puis lisez **[FICHE-DEPLOIEMENT.md](FICHE-DEPLOIEMENT.md)** : elle tient sur une page et contient tout ce dont vous aurez besoin pendant trois jours.

## Au début de chaque demi-journée

```bash
cd ~/lab && git pull
```

Les fichiers arrivent au fil de la formation. Sans cette commande, le fichier de la demi-journée n'est pas encore chez vous.

---

## Contenu

| | |
|---|---|
| `FICHE-DEPLOIEMENT.md` | Votre aide-mémoire : commandes, calendrier, messages d'erreur courants |
| `fascicules/` | Un fascicule par demi-journée |
| `templates/` | Les modèles CloudFormation qui construisent votre environnement |
| `manifests/` | Les manifestes Kubernetes de la chaîne applicative (à partir du J1 après-midi) |
| `verifier.sh` | Diagnostic de votre environnement — `bash ~/lab/verifier.sh $INIT` |

---

## Deux règles

**Ne modifiez pas les fichiers de ce dépôt.** Les substitutions se font à la volée, au moment d'appliquer. C'est ce qui garantit que `git pull` fonctionnera toute la semaine.

**Ne poussez rien.** Le dépôt est en lecture seule pour vous, même si votre outil ne vous l'interdit pas explicitement.
