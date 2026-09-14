# J3 — Matin · Industrialisation & centralisation
## Fascicule stagiaire

> **Votre région de travail : celle de votre sandbox.** Relevez-la en haut à droite de la console et notez-la sur votre fiche de déploiement. Dans cette salle, chacun peut travailler dans une région différente : il n'y a pas de réponse commune à « je ne retrouve pas ma ressource ».

---

## 1. Contexte et objectif

Pendant deux jours, vous avez supervisé **un** compte. Une vraie organisation en compte des dizaines : production, préproduction, développement, parfois un par équipe ou par filiale. C'est une bonne pratique de cloisonnement — et un problème de supervision.

Trois questions se posent alors, et aucune n'a de réponse dans un compte isolé. *Où va-t-on regarder quand on ne sait pas encore dans quel compte le problème se trouve ?* *Comment garde-t-on les journaux quand celui qui les produit peut les effacer ?* *Qui a le droit de voir quoi ?*

Ce matin construit la réponse : **un point de collecte unique, alimenté par tous les comptes, dont personne ne peut effacer le contenu depuis son propre compte.** C'est le socle d'un SOC cloud.

> **Une transparence nécessaire.** Le portail d'accès ne vous donne qu'un seul compte AWS. Les trois sources de journaux que vous allez centraliser représentent trois comptes, mais vivent dans le vôtre. **Tous les gestes que vous allez faire sont ceux d'une vraie centralisation** — filtres de souscription, flux de diffusion, destination commune. Seule la frontière de compte est jouée. Le paragraphe 4 explique précisément ce qui changerait en réel.

---

## 2. Services mobilisés et prérequis

| Élément | Détail |
|---|---|
| Services AWS | CloudWatch Logs, Kinesis Data Firehose, S3, IAM, CloudWatch Dashboards |
| Prérequis | Stack `tp-j1-am` déployée, chaîne BSS en cours d'exécution |
| Durée | 3 h 00 |
| Coût | Quelques centimes |

---

## 3. Énoncé

### Étape 0 — Déployer le décor (15 min)

**a. La stack**

Dans **CloudShell** :

```bash
cd ~/lab && git pull          # récupère les fichiers de la demi-journée

aws cloudformation deploy \
  --template-file templates/tp-j3-am.yaml \
  --stack-name tp-j3-am \
  --capabilities CAPABILITY_NAMED_IAM
```

La commande rend la main quand la stack est créée. Vous pouvez suivre l'avancement en parallèle dans **CloudFormation → tp-j3-am → Événements**.

Environ 3 minutes. Relevez les sorties **`NomFluxSoc`**, **`RoleSouscriptionArn`** et **`BucketSoc`** :

```bash
aws cloudformation describe-stacks --stack-name tp-j3-am \
  --query 'Stacks[0].Outputs[].[OutputKey,OutputValue]' --output table
```

**b. Le générateur de journaux**

Toujours dans CloudShell, avec les mêmes deux constantes qu'au J1 :

```bash
export INIT=<vos-initiales>
export REG=${AWS_REGION:-$(aws configure get region)}

cd ~/lab/manifests
sed "s/REMPLACER_INITIALES/$INIT/g; s/REMPLACER_REGION/$REG/g" bss-comptes-simules.yaml | kubectl apply -f -
```

Une tâche planifiée alimente les trois sources toutes les deux minutes. **Attendez un cycle** avant l'étape 1.

---

### Étape 1 — Constater la dispersion (30 min)

Console → **CloudWatch** → *Journaux* → **Groupes de journaux**. Filtrez sur `/orange/`.

Vous voyez trois groupes, un par « compte ». Ouvrez-les successivement.

| Question | Réponse |
|---|---|
| Combien d'événements dans chaque groupe sur les 10 dernières minutes ? | prod : …… / préprod : …… / dev : …… |
| Quel « compte » produit le plus d'erreurs en proportion ? | |
| Un même service apparaît-il dans plusieurs comptes ? | |

**Maintenant, la manipulation qui fait comprendre le problème.**

*Journaux → Informations sur les journaux*. Sélectionnez **les trois groupes à la fois**, puis :

```
fields @timestamp, compte, service, statut
| filter statut >= 500
| stats count() as erreurs by compte
| sort erreurs desc
```

> **Ça fonctionne.** Logs Insights sait interroger plusieurs groupes de journaux en une requête. Alors pourquoi centraliser ?
>
> Trois raisons, et vous devriez pouvoir les formuler avant de lire la suite : cette requête ne franchit pas les frontières de compte ; elle ne porte que sur la rétention du groupe d'origine ; et **le propriétaire du compte peut supprimer ses journaux**. Le troisième point est le vrai sujet d'un SOC.

> **Livrable attendu :** le résultat de la requête, et votre formulation des trois limites.

---

### Étape 2 — Brancher les sources sur le collecteur (50 min)

Un **filtre de souscription** envoie en continu les événements d'un groupe de journaux vers une destination. Vous allez en créer trois, un par « compte ».

Pour chacun des trois groupes `/orange/<initiales>/compte-*/bss` :

1. Ouvrir le groupe → onglet **Filtres d'abonnement** → *Créer* → **Créer un filtre d'abonnement Kinesis Firehose**.
2. Flux de diffusion : `bss-soc-<initiales>`.
3. Autorisation : **Rôle existant** → `bss-logs-vers-firehose-<initiales>`.
4. Format : *Autre*. Modèle de filtre : **laisser vide** pour tout envoyer.
5. Nom : `vers-soc-production`, `vers-soc-preproduction`, `vers-soc-developpement`.
6. Créer.

> **Le rôle est fourni, et ce n'est pas un cadeau anodin.** Sa politique de confiance autorise `logs.<votre-région>.amazonaws.com` — pas `logs.amazonaws.com`. Ce détail régional fait perdre un quart d'heure à tout le monde la première fois.

**Vérifiez la collecte :**

7. Attendez **2 minutes** — Firehose met en tampon 60 secondes ou 5 Mo.
8. Console → **S3** → compartiment `bss-soc-central-<initiales>` → dossier `journaux-centralises/`.
9. Descendez dans l'arborescence année / mois / jour / heure et ouvrez un objet.

| Question | Réponse |
|---|---|
| Combien d'objets sont arrivés ? | |
| Les trois comptes sont-ils présents dans le même objet ? | |
| Dans quel format le contenu est-il stocké ? | |

> **Livrable attendu :** capture de l'arborescence S3, et un extrait du contenu d'un objet.

---

### Étape 3 — Construire la vue globale (50 min)

Un collecteur qu'on n'interroge pas ne sert à rien. Il vous faut une vue d'ensemble.

1. CloudWatch → *Tableaux de bord* → **Créer** → `soc-global-<initiales>`.
2. Ajoutez **quatre widgets** :

| Widget | Type | Contenu |
|---|---|---|
| Erreurs par compte | *Requête de journaux*, barres | Requête ci-dessous, sur les trois groupes |
| Volume par service | *Requête de journaux*, camembert | `stats count() by service` |
| Santé du cluster | *Métriques ligne* | `node_cpu_utilization` de votre cluster |
| Retard de facturation | *Métriques ligne* | `ApproximateAgeOfOldestMessage` de la file SQS |

Requête du premier widget :

```
fields @timestamp, compte, statut
| filter statut >= 500
| stats count() as erreurs by bin(5m), compte
```

3. Réglez la plage sur **3 heures** et sauvegardez.

> **Pourquoi mélanger journaux et métriques sur le même tableau ?** Parce qu'une astreinte n'a pas le temps d'ouvrir quatre consoles. La valeur d'une vue SOC n'est pas l'exhaustivité, c'est de permettre de **décider en trente secondes** s'il faut escalader. Le jour de l'atelier de cet après-midi, c'est ce tableau que vous ouvrirez en premier.

> **Livrable attendu :** capture du tableau de bord complet.

---

### Étape 4 — La gouvernance des accès (25 min)

Pas de manipulation ici. Un raisonnement, à mener en groupe.

Votre collecteur contient désormais les journaux des trois comptes. Vous devez décider **qui peut y accéder**. Répondez pour chacun :

| Population | Lecture des journaux centralisés ? | Sur quel périmètre ? | Justification |
|---|---|---|---|
| Équipe SOC | | | |
| Équipe d'exploitation BSS | | | |
| Développeur d'une équipe produit | | | |
| Auditeur externe | | | |
| Le compte de production lui-même | | | |

> **La dernière ligne est un piège.** Un compte doit-il pouvoir lire, et surtout **modifier ou supprimer**, les journaux qu'il a lui-même produits une fois centralisés ? Pensez à ce qu'un attaquant ayant compromis ce compte chercherait à faire en premier.

---

## 4. Ce qui changerait en multi-comptes réel

Trois différences seulement, et aucune ne remet en cause ce que vous venez de faire.

| Élément | Dans ce lab | En réel |
|---|---|---|
| Emplacement des sources | Trois groupes dans un compte | Un groupe par compte membre |
| Emplacement du flux | Le même compte | Un **compte SOC dédié** |
| Autorisation | Un rôle local | Une **destination CloudWatch Logs** dans le compte SOC, avec une politique de ressource autorisant les comptes membres |

Le geste du stagiaire — créer un filtre de souscription pointant vers une destination — est **rigoureusement identique**. Seul l'ARN de destination change de compte.

Le vrai sujet du multi-comptes n'est d'ailleurs pas technique : c'est **qui possède le compte SOC**, qui y a accès, et qui peut effacer. Un compte membre qui peut supprimer ses journaux centralisés annule tout l'intérêt de la centralisation.

---

## 5. Points à retenir

- Centraliser ne sert pas à « tout voir au même endroit ». Cela sert à ce que **celui qui produit les journaux ne puisse pas les effacer**.
- Un filtre de souscription est un flux continu, pas une copie ponctuelle. Il se met en place une fois et fonctionne ensuite sans intervention.
- Une vue SOC se juge à une seule chose : permet-elle de décider en trente secondes s'il faut escalader ?

---

## 6. Nettoyage

**Ne supprimez rien.** Le tableau de bord et les alarmes servent à l'atelier de cet après-midi.
