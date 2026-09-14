# Fiche de déploiement — stagiaire

À garder sous la main pendant les trois jours.

---

## Vos deux constantes

Notez-les ici, vous les retaperez souvent.

| | |
|---|---|
| **Vos initiales** | `……………` (2 à 8 caractères, minuscules et chiffres) |
| **Votre région** | `……………………` (en haut à droite de la console) |

> Toutes vos ressources portent vos initiales et vivent dans **votre** région. Si vous ne retrouvez pas quelque chose, vérifiez la région avant toute autre hypothèse.

---

## Une seule fois, au début du J1

**1. Se connecter**

Portail d'accès → `SandboxAdministratorAccess` → la console s'ouvre. Relevez votre région en haut à droite et notez-la ci-dessus.

**2. Ouvrir CloudShell**

L'icône `>_` en bas à gauche de la console. Comptez trente secondes au premier démarrage.

**3. Récupérer les fichiers**

```bash
git clone https://github.com/bart120/aws-orange-sept25.git ~/lab
cd ~/lab
```

**4. Poser vos deux constantes** — à refaire à chaque ouverture de CloudShell

```bash
export INIT=<vos-initiales>
export REG=${AWS_REGION:-$(aws configure get region)}
echo "$INIT dans $REG"
```

Toutes les commandes de cette fiche s'appuient dessus. Relisez la ligne affichée : c'est votre identité de travail pour trois jours.

---

## Le geste du début de chaque demi-journée

Les fichiers arrivent **au fil de la formation**. Avant chaque déploiement, une seule commande :

```bash
cd ~/lab && git pull
```

> Les fichiers du dépôt ne sont jamais modifiés sur place — les substitutions se font à la volée, dans un tuyau. `git pull` ne peut donc pas échouer sur un conflit. Si un jour il en signale un, c'est qu'un fichier a été édité par erreur : `git checkout -- . && git pull` remet tout d'aplomb.

---

## Déployer une stack

**La même commande à chaque fois**, seul le nom change. Depuis `~/lab` dans CloudShell :

```bash
cd ~/lab && git pull

aws cloudformation deploy \
  --template-file templates/tp-j1-am.yaml \
  --stack-name tp-j1-am \
  --parameter-overrides Stagiaire=$INIT \
  --capabilities CAPABILITY_NAMED_IAM
```

La commande **attend la fin** et vous rend la main quand c'est terminé. Vous pouvez suivre l'avancement en parallèle dans la console : **CloudFormation → tp-j1-am → onglet Événements**.

> Le paramètre `Stagiaire` n'est à passer que pour `tp-j1-am`. Les autres stacks le retrouvent toutes seules.

### Le calendrier des stacks

| Quand | Commande | Durée |
|---|---|---|
| J1 · 9h00 | `tp-j1-am` avec `--parameter-overrides Stagiaire=$INIT` | **13 min** |
| J1 · avant le déjeuner | `tp-j1-pm` | 1 min |
| J2 · matin | `tp-j2-am` | 1 min |
| J2 · avant le déjeuner | `tp-j2-pm` | 1 min |
| J3 · matin | `tp-j3-am` | 3 min |
| J3 · avant le déjeuner | `tp-j3-pm` | 1 min |

Pour les cinq dernières, la commande se réduit à :

```bash
aws cloudformation deploy \
  --template-file templates/tp-j1-pm.yaml \
  --stack-name tp-j1-pm \
  --capabilities CAPABILITY_NAMED_IAM
```

### Lire les valeurs de sortie

Chaque stack publie des informations dont vous aurez besoin — noms de compartiments, ARN de rôles, ressources témoins.

```bash
aws cloudformation describe-stacks --stack-name tp-j1-pm \
  --query 'Stacks[0].Outputs[].[OutputKey,OutputValue]' --output table
```

Ou dans la console : **CloudFormation → la stack → onglet Sorties**.

---

## Déployer la chaîne applicative — J1 après-midi

Une seule fois, après `tp-j1-pm`.

```bash
cd ~/lab/manifests

# 1. Brancher kubectl sur votre cluster
aws eks update-kubeconfig --region $REG --name bss-$INIT
kubectl get nodes                      # deux noeuds en Ready

# 2. Substituer à la volée, puis appliquer — dans cet ordre
sed "s/REMPLACER_INITIALES/$INIT/g; s/REMPLACER_REGION/$REG/g" bss-chaine.yaml     | kubectl apply -f -
sed "s/REMPLACER_INITIALES/$INIT/g; s/REMPLACER_REGION/$REG/g" xray-daemonset.yaml | kubectl apply -f -

# 3. Attendre que tout démarre
kubectl get pods -n bss -w             # Ctrl+C quand tout est Running
```

> **Les deux pièges de cette séquence.**
> L'ordre : le démon X-Ray vit dans le namespace `bss` que crée le premier manifeste. Appliqué avant, il échoue sur `namespaces "bss" not found`.
> La substitution : sans elle, vos pods cherchent leur file SQS dans la mauvaise région et tournent en erreur sans le dire clairement.

Attendu : **sept pods** applicatifs en `Running` (`provisioning` en compte deux), plus un `xray-daemon` par nœud.

Au J3 matin, un troisième manifeste, sur le même modèle :

```bash
cd ~/lab && git pull && cd manifests
sed "s/REMPLACER_INITIALES/$INIT/g; s/REMPLACER_REGION/$REG/g" bss-comptes-simules.yaml | kubectl apply -f -
```

---

## Vérifier que tout va bien

**Avant chaque TP**, et dès que quelque chose vous paraît anormal :

```bash
bash ~/lab/verifier.sh $INIT
```

Le script contrôle cinq points et affiche un verdict. Annoncez votre résultat au formateur : c'est le seul moyen qu'il a de suivre la salle, puisque chacun travaille dans son propre compte.

---

## Les trois messages que vous verrez, et ce qu'ils veulent dire

| Message | Ce qui se passe | Quoi faire |
|---|---|---|
| `Unable to locate credentials` ou une erreur d'identité | Votre session SSO a expiré — cela arrive toutes les heures environ | Rouvrez le portail, recliquez sur le rôle, revenez dans CloudShell |
| *Votre session a été fermée* dans CloudShell | Fermeture sur inactivité | Cliquez sur **Reconnecter**. Vos fichiers sont conservés |
| Des pods en `0/1` pendant une minute | Les conteneurs installent leurs dépendances Python au démarrage | Patientez 60 à 90 secondes |

---

## En cas de stack en échec

Une stack en `ROLLBACK_COMPLETE` **ne peut pas être redéployée** : il faut la supprimer d'abord.

```bash
aws cloudformation delete-stack --stack-name <nom>
aws cloudformation wait stack-delete-complete --stack-name <nom>
```

Puis relancez la commande de déploiement. Pour comprendre la cause :

```bash
aws cloudformation describe-stack-events --stack-name <nom> \
  --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`].[LogicalResourceId,ResourceStatusReason]' \
  --output text | head -3
```
