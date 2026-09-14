# J2 — Matin · Supervision sécurité
## Fascicule stagiaire

> **Votre région de travail : celle de votre sandbox.** Relevez-la en haut à droite de la console et notez-la sur votre fiche de déploiement. Dans cette salle, chacun peut travailler dans une région différente : il n'y a pas de réponse commune à « je ne retrouve pas ma ressource ».

---

## 1. Contexte et objectif

Hier, vous avez appris à voir ce qui *tombe*. Ce matin, vous allez apprendre à voir ce qui *dérive*.

Ce sont deux métiers différents. Une panne se manifeste : une alarme sonne, un client appelle. Une dérive de configuration ne se manifeste pas — un port reste ouvert après une intervention, un volume est créé sans chiffrement, un rôle applicatif accumule des droits. Rien ne casse. Tout fonctionne. Jusqu'au jour où quelqu'un s'en sert.

Votre environnement contient **quatre non-conformités plantées volontairement**. Elles ressemblent à ce qu'on trouve réellement dans un compte d'entreprise après deux ans d'exploitation. Votre travail : les faire remonter automatiquement, pas les chercher à la main.

Deux mécanismes complémentaires. **AWS Config** surveille l'état des ressources et vous dit ce qui n'est pas conforme à vos règles. **GuardDuty** surveille les comportements et vous dit ce qui est anormal. Le premier répond à « est-ce bien configuré », le second à « est-ce qu'il se passe quelque chose ».

---

## 2. Services mobilisés et prérequis

| Élément | Détail |
|---|---|
| Services AWS | AWS Config, GuardDuty, EventBridge, SNS, IAM |
| Prérequis | Stacks `tp-j1-am` et `tp-j1-pm` déployées |
| Durée | 3 h 00 |
| Coût | Environ 0,10 € — Config facture à l'élément de configuration enregistré |

---

## 3. Énoncé

### Étape 0 — Déployer le décor (10 min)

Dans **CloudShell** :

```bash
cd ~/lab && git pull          # récupère les fichiers de la demi-journée

aws cloudformation deploy \
  --template-file templates/tp-j2-am.yaml \
  --stack-name tp-j2-am \
  --capabilities CAPABILITY_NAMED_IAM
```

La commande rend la main quand la stack est créée. Vous pouvez suivre l'avancement en parallèle dans **CloudFormation → tp-j2-am → Événements**.

Relevez ensuite les deux valeurs de sortie **`RoleConfigArn`** et **`RubriqueSecuriteArn`** :

```bash
aws cloudformation describe-stacks --stack-name tp-j2-am \
  --query 'Stacks[0].Outputs[].[OutputKey,OutputValue]' --output table
```

> **Lisez la sortie `ResumeNonConformites`.** Elle liste les quatre problèmes plantés dans votre compte. Ne les corrigez pas : vous devez d'abord les *détecter*.

---

### Étape 1 — Activer l'enregistrement des configurations (30 min)

1. Console → **AWS Config** → *Commencer*.
2. **Type d'enregistrement** : *Ressources prises en charge dans cette région*, toutes.
3. **Rôle IAM** : choisir *Utiliser un rôle existant* et sélectionner `bss-config-<initiales>`.
4. **Compartiment S3 de livraison** : *Choisir un compartiment existant* → celui créé hier (`bss-journaux-…`).
5. Passer l'étape des règles pour l'instant → **Confirmer**.

Patientez. Le premier inventaire prend **5 à 10 minutes**. Pendant ce temps, passez à l'étape 2.

> **Livrable attendu :** capture de l'écran *Enregistreur de configuration* avec l'état *Activé*.

---

### Étape 2 — Activer la détection de menaces (20 min)

1. Console → **GuardDuty** → *Commencer* → **Activer GuardDuty**.
2. L'activation est immédiate. Notez ce que GuardDuty analyse **sans que vous ayez rien configuré** : journaux CloudTrail, journaux de flux VPC, requêtes DNS.
3. Générez des résultats de démonstration : *Paramètres* → **Résultats d'exemple** → *Générer des résultats d'exemple*.
4. Retournez sur **Résultats** et explorez.

> **Pourquoi des résultats d'exemple ?** Parce qu'une vraie menace ne se commande pas. Les exemples ont la structure exacte d'un vrai résultat : même sévérité, mêmes champs, même format d'événement. Ce que vous apprenez à lire ici, vous le lirez à l'identique en production.

**Choisissez un résultat de sévérité élevée** et remplissez :

| Question | Réponse |
|---|---|
| Type de résultat | |
| Sévérité (valeur numérique) | |
| Ressource concernée | |
| Acteur : adresse IP et pays | |
| Sur quelle source GuardDuty l'a-t-il vu ? | |

> **Livrable attendu :** le tableau complété, et une capture du détail du résultat.

---

### Étape 3 — Détecter les non-conformités (50 min)

Retournez sur **AWS Config**. L'inventaire doit être terminé.

*Règles* → **Ajouter une règle** → *Ajouter une règle managée par AWS*. Déployez les quatre suivantes, une par une :

| Règle | Ce qu'elle cherche |
|---|---|
| `restricted-ssh` | Groupes de sécurité autorisant le port 22 depuis n'importe où |
| `encrypted-volumes` | Volumes EBS non chiffrés |
| `s3-bucket-versioning-enabled` | Compartiments sans versionnement |
| `iam-policy-no-statements-with-admin-access` | Politiques accordant des droits trop larges |

Laissez les paramètres par défaut. Comptez **2 à 5 minutes** par règle avant le premier verdict.

**Puis relevez les résultats :**

| Règle | Conformes | Non conformes | Ressource identifiée |
|---|---|---|---|
| `restricted-ssh` | | | |
| `encrypted-volumes` | | | |
| `s3-bucket-versioning-enabled` | | | |
| `iam-policy-no-statements-with-admin-access` | | | |

> **Question pour le débrief :** l'une de ces quatre règles signale des ressources que vous n'avez pas créées, qui appartiennent au fonctionnement normal de l'environnement. Laquelle, et que faites-vous d'un tel signalement en production ?

> **Livrable attendu :** le tableau complété, et une capture du tableau de bord de conformité.

---

### Étape 4 — Router les alertes vers un humain (40 min)

Un résultat GuardDuty dans une console que personne n'ouvre ne sert à rien. Vous allez le router.

1. Console → **EventBridge** → *Règles* → **Créer une règle**.
2. Nom : `guardduty-vers-sns-<initiales>`. Bus d'événements : `default`.
3. Type : **Règle avec modèle d'événement**.
4. Source d'événement : *Services AWS* → **GuardDuty** → Type : *GuardDuty Finding*.
5. **Modifiez le modèle** pour ne router que ce qui mérite un réveil :

   ```json
   {
     "source": ["aws.guardduty"],
     "detail-type": ["GuardDuty Finding"],
     "detail": { "severity": [{ "numeric": [">=", 7] }] }
   }
   ```

6. Cible : **Rubrique SNS** → `bss-alertes-securite-<initiales>`.
7. Créer.

8. Ajoutez votre adresse e-mail comme abonnement à cette rubrique, et confirmez.
9. Regénérez des résultats d'exemple depuis GuardDuty.
10. Vérifiez la réception.

> **Le filtre de sévérité est le cœur de l'exercice.** GuardDuty produit beaucoup de résultats de sévérité faible. Router tout vers une messagerie garantit qu'au bout de trois semaines plus personne ne lit les alertes. Le seuil 7 correspond à *Élevée* — c'est un point de départ défendable, pas une vérité.

> **Livrables attendus :**
> - l'e-mail reçu, avec le type de résultat qu'il contient
> - votre réponse : combien de vos résultats d'exemple ont franchi le filtre, sur combien au total ?

---

## 4. Points à retenir

- AWS Config répond à « est-ce conforme ». GuardDuty répond à « est-ce anormal ». Les deux sont nécessaires ; aucun ne remplace l'autre.
- Une règle de conformité sans destinataire est une décoration. Le routage fait partie de la mise en place, pas d'un projet ultérieur.
- Le filtrage par sévérité n'est pas un détail de confort : c'est ce qui détermine si vos alertes seront lues dans six mois.

---

## 5. Nettoyage — fin de matinée

**Ne supprimez pas** la stack `tp-j1-am`, ni la chaîne BSS.

À faire :

1. **AWS Config** → *Paramètres* → **Arrêter l'enregistrement**. Config facture à l'élément enregistré ; laissé actif trois jours sur un compte qui bouge, il devient le deuxième poste de coût de votre lab. Vous le constaterez demain après-midi.
2. **GuardDuty** : laisser activé, il sert à l'atelier final.
3. Conserver la stack `tp-j2-am` : les non-conformités restent en place pour l'atelier du J3.
