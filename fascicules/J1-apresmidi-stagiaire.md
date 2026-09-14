# J1 — Après-midi · Centralisation des logs & audit
## Fascicule stagiaire

> **Votre région de travail : celle de votre sandbox.** Relevez-la en haut à droite de la console et notez-la sur votre fiche de déploiement. Dans cette salle, chacun peut travailler dans une région différente : il n'y a pas de réponse commune à « je ne retrouve pas ma ressource ».

---

## 1. Contexte et objectif

Ce matin, votre tableau de bord était vert pendant qu'une commande client n'aboutissait pas. C'est le point de départ de cet après-midi.

Une métrique répond à « la machine va-t-elle bien ». Un log répond à « que s'est-il passé, pour quelle commande, à quelle étape ». Ce sont deux questions différentes, et la seconde est celle que pose l'exploitation à trois heures du matin.

Vous allez travailler sur une reproduction simplifiée de votre chaîne BSS : cinq services conteneurisés — CRM, IDM, provisioning, médiation, facturation — qui traitent en continu des commandes d'abonnement. Ils écrivent leurs journaux en JSON structuré, ce qui les rend interrogeables sans transformation.

Deux compétences à l'arrivée. **Retrouver une action** : qui a supprimé quoi, quand, depuis quelle adresse. **Retrouver une erreur** : combien d'erreurs 500, sur quel service, et depuis quand.

---

## 2. Services mobilisés et prérequis

| Élément | Détail |
|---|---|
| Services AWS | CloudTrail, CloudWatch Logs, Logs Insights, S3, SNS, EKS |
| Prérequis | La stack `tp-j1-am` déployée ce matin doit être en `CREATE_COMPLETE` |
| Outils | Console AWS + CloudShell (icône en bas à gauche) |
| Rubrique SNS | Celle créée ce matin, abonnement déjà confirmé |

---

## 3. Durée et coût

| | |
|---|---|
| Durée estimée | 3 h 00 |
| Coût | Moins de 0,10 € — le premier trail CloudTrail d'un compte est gratuit |

---

## 4. Énoncé

### Étape 0 — Déployer le décor (20 min)

**a. La stack de la demi-journée**

Dans **CloudShell** :

```bash
cd ~/lab && git pull          # récupère les fichiers de la demi-journée

aws cloudformation deploy \
  --template-file templates/tp-j1-pm.yaml \
  --stack-name tp-j1-pm \
  --capabilities CAPABILITY_NAMED_IAM
```

La commande rend la main quand la stack est créée. Vous pouvez suivre l'avancement en parallèle dans **CloudFormation → tp-j1-pm → Événements**.

Environ une minute. Relevez ensuite la valeur de sortie `NomBucketCentralisation`, vous en aurez besoin à l'étape 1 :

```bash
aws cloudformation describe-stacks --stack-name tp-j1-pm \
  --query 'Stacks[0].Outputs[].[OutputKey,OutputValue]' --output table
```

**b. La chaîne applicative**

Toujours dans CloudShell. **Posez d'abord vos deux constantes**, tout le reste s'en déduit :

```bash
export INIT=<vos-initiales>
export REG=${AWS_REGION:-$(aws configure get region)}
echo "$INIT dans $REG"                  # relisez cette ligne avant de continuer

cd ~/lab/manifests
aws eks update-kubeconfig --region $REG --name bss-$INIT
kubectl get nodes                       # deux noeuds en Ready
```

Les manifestes portent deux marqueurs, `REMPLACER_INITIALES` et `REMPLACER_REGION`. On les substitue **à la volée**, sans modifier les fichiers du dépôt :

```bash
sed "s/REMPLACER_INITIALES/$INIT/g; s/REMPLACER_REGION/$REG/g" bss-chaine.yaml     | kubectl apply -f -
sed "s/REMPLACER_INITIALES/$INIT/g; s/REMPLACER_REGION/$REG/g" xray-daemonset.yaml | kubectl apply -f -

kubectl get pods -n bss -w
```

> **Deux piquets à ne pas déplacer.**
> **L'ordre** : le démon X-Ray vit dans le namespace `bss`, que seul `bss-chaine.yaml` crée. Appliqué en premier, il échoue sur `namespaces "bss" not found`.
> **La région** : sans la seconde substitution, vos pods cherchent leur file SQS dans la mauvaise région et tournent en erreur sans le dire clairement.

Les pods installent leurs dépendances au démarrage : **60 à 90 secondes** avant qu'ils passent tous en `Running`. Quittez la surveillance avec `Ctrl+C` quand c'est le cas.

> **Livrable attendu :** la sortie de `kubectl get pods -n bss` — **sept pods** applicatifs en `Running` (`provisioning` en compte deux), plus un `xray-daemon` par noeud.

---

### Étape 1 — Activer la piste d'audit (25 min)

CloudTrail enregistre les appels d'API. Un compte AWS en journalise déjà 90 jours sans que vous n'ayez rien fait — mais sans conservation longue, sans recherche efficace et sans possibilité d'alarme.

1. Console → **CloudTrail** → *Journaux de suivi* → **Créer un journal de suivi**.
2. Nom : `audit-bss-<initiales>`.
3. Emplacement de stockage : **Utiliser un compartiment S3 existant**, et sélectionner le bucket noté à l'étape 0.
4. Chiffrement SSE-KMS : **décocher**. La gestion d'une clé n'est pas l'objet du TP.
5. *Suivant* → Type d'événement : **Événements de gestion**, Lecture **et** Écriture cochées.
6. Créer.

> **Regardez la liste des journaux de suivi.** Il y en a un autre que le vôtre, nommé `aws-mgmt-…-baseline`, que vous ne pouvez pas modifier. C'est le journal de suivi d'organisation, piloté par l'équipe qui gère le compte de gestion. Vous en héritez sans pouvoir le désactiver : c'est exactement le principe de la gouvernance centralisée, et c'est une bonne nouvelle pour un auditeur.

> **Livrable attendu :** l'ARN de votre journal de suivi, et le nom du journal de suivi d'organisation que vous ne pouvez pas modifier.

---

### Étape 2 — L'incident d'exploitation : qui a supprimé la ressource ? (35 min)

La stack a créé trois ressources témoins, dont le seul rôle est d'être supprimées.

1. **Supprimez-en une**, celle que vous voulez :
   - le groupe de sécurité `temoin-a-supprimer-<initiales>` (console EC2), ou
   - la rubrique SNS `temoin-a-supprimer-<initiales>`, ou
   - le paramètre SSM `/bss/<initiales>/temoin-a-supprimer`.

2. **Notez l'heure exacte** à la minute près.

3. Console → **CloudTrail** → *Historique des événements*.

4. Retrouvez votre suppression. Filtrez par **Nom de l'événement** : `DeleteSecurityGroup`, `DeleteTopic` ou `DeleteParameter` selon votre choix.

5. Ouvrez l'événement et répondez, en vous appuyant **uniquement** sur ce que montre l'écran :

| Question | Réponse |
|---|---|
| Quelle identité a réalisé l'action ? | |
| Quel type d'identité (racine, utilisateur IAM, rôle endossé) ? | |
| Depuis quelle adresse IP source ? | |
| Avec quel agent utilisateur ? | |
| Combien de temps s'est écoulé entre l'action et son apparition dans l'historique ? | |

> **Ce que vous devez remarquer :** l'identité n'est pas un nom d'utilisateur simple. C'est un rôle endossé via l'authentification unique, avec un nom de session. En exploitation réelle, c'est ce nom de session qui vous permet de remonter à la personne — d'où l'importance d'une convention de nommage des sessions dans votre fournisseur d'identité.

> **Livrable attendu :** le tableau ci-dessus complété, et une capture de l'enregistrement JSON de l'événement.

---

### Étape 3 — Explorer les journaux applicatifs (40 min)

Les conteneurs écrivent sur leur sortie standard. Fluent Bit, installé par le module complémentaire CloudWatch Observability, les collecte sans aucune configuration de votre part.

1. Console → **CloudWatch** → *Journaux* → **Groupes de journaux**.
2. Ouvrez `/aws/containerinsights/bss-<initiales>/application`.
3. Parcourez quelques entrées. Remarquez qu'elles sont en JSON : `service`, `statut`, `etape`, `duree_ms`.

**Puis passez à Logs Insights** — *Journaux → Informations sur les journaux*, sélectionnez ce groupe.

Requête 1 — le volume par service :

```
fields @timestamp, service, statut
| stats count() by service
| sort count() desc
```

Requête 2 — la répartition des codes de retour :

```
fields @timestamp, service, statut
| stats count() by statut, service
| sort statut desc
```

Requête 3 — les cinq requêtes les plus lentes :

```
fields @timestamp, service, etape, duree_ms
| filter ispresent(duree_ms)
| sort duree_ms desc
| limit 5
```

> **Question à préparer pour le débrief :** la requête 2 vous donne le nombre d'erreurs. Pourquoi ce nombre, seul, ne suffit-il pas à décider s'il faut réveiller quelqu'un ? Que faudrait-il lui ajouter ?

> **Livrable attendu :** le résultat de la requête 2, et le nom du service qui produit le plus d'erreurs.

---

### Étape 4 — Alarmer sur les journaux, pas sur les métriques (40 min)

Une erreur applicative n'existe pas comme métrique. Il faut la fabriquer : c'est le rôle d'un **filtre métrique**, qui compte les lignes de journal correspondant à un motif et publie le résultat comme métrique CloudWatch.

1. CloudWatch → *Groupes de journaux* → `/aws/containerinsights/bss-<initiales>/application`.
2. Onglet **Filtres de métriques** → **Créer un filtre de métrique**.
3. Modèle de filtre — attention à la syntaxe, les accolades et le `$` sont obligatoires :

   ```
   { $.statut = 500 }
   ```

4. **Testez le modèle** sur les données existantes avant de continuer. Si aucune ligne ne correspond, ne poursuivez pas : relisez le motif.
5. *Suivant* :
   - Nom du filtre : `erreurs-500-<initiales>`
   - Espace de noms de métrique : `BSS/<initiales>`
   - Nom de la métrique : `Erreurs500`
   - Valeur de la métrique : `1`
   - **Valeur par défaut : `0`** — ce point est capital, voir l'encadré.
6. Créer.

> **Pourquoi la valeur par défaut à 0 ?** Sans elle, la métrique ne publie rien lorsqu'il n'y a pas d'erreur. Votre alarme se retrouve alors en *Données insuffisantes* au lieu d'être en *OK*, et vous ne savez plus distinguer « tout va bien » de « la collecte est tombée ». C'est l'erreur la plus fréquente sur les alarmes fondées sur les journaux.

**Créez maintenant l'alarme :**

7. CloudWatch → *Alarmes* → **Créer une alarme** → métrique `BSS/<initiales>` → `Erreurs500`.
8. Statistique **Somme**, période **1 minute**, seuil **supérieur à 5**, **2 points de données sur 2**.
9. Action : la rubrique SNS créée ce matin.
10. Nom : `erreurs-500-bss-<initiales>`.

**Déclenchez-la :** dans CloudShell,

```bash
aws ssm put-parameter --overwrite --type String \
  --name /bss/<vos-initiales>/facturation/taux-erreur --value 60
```

Les pods relisent ce paramètre toutes les dix secondes. Le taux d'erreurs de la facturation passe à 60 %.

11. Observez l'alarme basculer, et **chronométrez** le délai jusqu'à réception du courriel.
12. Remettez le paramètre à `0` une fois l'alarme déclenchée.

> **Livrables attendus :**
> - le délai mesuré : `……… min ……… s`
> - une capture du graphique de l'alarme montrant le franchissement
> - votre réponse : ce délai est-il plus court ou plus long que celui de l'alarme CPU de ce matin ? Pourquoi ?

---

## 5. Points à retenir

- L'historique des événements CloudTrail existe sans configuration, mais ne conserve que 90 jours et ne permet ni alarme ni recherche longue durée. Un journal de suivi vers S3 répond à ces trois besoins.
- Un journal en JSON structuré est interrogeable ; un journal en texte libre demande des expressions régulières fragiles. Le coût de la structuration est payé une fois à l'écriture, pas à chaque recherche.
- Une alarme fondée sur les journaux a toujours un délai supérieur à une alarme fondée sur les métriques : il faut ajouter le temps de collecte par l'agent et de publication du filtre métrique.

---

## 6. Nettoyage — à faire en fin de journée

**Ne supprimez pas** la stack `tp-j1-am` ni la chaîne BSS : elles vivent jusqu'à la fin du J3.

À supprimer :

1. Le journal de suivi CloudTrail `audit-bss-<initiales>` — sinon il continue d'écrire dans S3 pendant trois jours.
2. Rien d'autre.

À conserver : le filtre métrique, l'alarme, la rubrique SNS et le tableau de bord. Ils servent au J3.
