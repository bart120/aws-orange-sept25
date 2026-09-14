# J3 — Après-midi · FinOps & atelier final
## Fascicule stagiaire

> **Votre région de travail : celle de votre sandbox.** Relevez-la en haut à droite de la console et notez-la sur votre fiche de déploiement. Dans cette salle, chacun peut travailler dans une région différente : il n'y a pas de réponse commune à « je ne retrouve pas ma ressource ».

---

## 1. Contexte et objectif

Deux jours et demi que votre environnement tourne. Cluster, journaux, traces, conformité, centralisation. Tout cela a un prix, et **vous allez le regarder pour de vrai** — pas sur un jeu de données de démonstration, mais sur votre propre consommation, accumulée depuis le premier matin.

C'est le dernier angle de la supervision, et le plus souvent négligé. Une dérive de coût est un signal comme un autre : elle a une cause, elle se détecte, elle s'alarme. La différence est qu'on la découvre en général un mois trop tard, sur une facture.

La demi-journée se termine par une **mise en situation complète** : votre chaîne BSS va tomber en panne de cinq manières simultanées, et vous devrez faire le diagnostic avec ce que vous avez construit en trois jours.

---

## 2. Services mobilisés et prérequis

| Élément | Détail |
|---|---|
| Services AWS | Cost Explorer, AWS Budgets, et tout ce qui a été vu depuis le J1 |
| Prérequis | Toutes les stacks déployées, chaîne BSS en cours d'exécution |
| Durée | 3 h 00 |

---

## 3. Partie 1 — FinOps (1 h 15)

### Étape 0 — Déployer la stack de l'atelier (5 min)

Dans **CloudShell** :

```bash
cd ~/lab && git pull          # récupère les fichiers de la demi-journée

aws cloudformation deploy \
  --template-file templates/tp-j3-pm.yaml \
  --stack-name tp-j3-pm \
  --capabilities CAPABILITY_NAMED_IAM
```

La commande rend la main quand la stack est créée. Vous pouvez suivre l'avancement en parallèle dans **CloudFormation → tp-j3-pm → Événements**.


Notez la sortie **`RubriqueIncidentArn`**.

---

### Étape 1 — Lire sa propre facture (35 min)

Console → **Cost Explorer** → *Explorateur de coûts*.

Réglages : granularité **Journalière**, plage **7 derniers jours**, groupement **Service**.

| Question | Réponse |
|---|---|
| Coût total depuis le début de la formation | |
| Service le plus coûteux | |
| Deuxième service | |
| La courbe est-elle plate, croissante, ou en marches ? | |
| À quel moment la consommation a-t-elle démarré ? | |

**Puis regroupez par *Type d'utilisation*** et cherchez les postes que vous n'auriez pas devinés.

| Question | Réponse |
|---|---|
| Un poste vous surprend-il ? Lequel ? | |
| Voyez-vous une ligne liée aux journaux ? | |
| Voyez-vous une ligne liée à la surveillance de configuration ? | |

> **Le poste qui surprend presque toujours** n'est pas le cluster. C'est ce qui l'accompagne : l'ingestion des journaux, les métriques personnalisées, ou un enregistrement de configuration laissé actif. Ce sont des services facturés à l'usage, qu'on active en trois clics et qu'on oublie.
>
> Rappelez-vous du nœud Systems Manager repéré hier sur la carte des services : cinq services qui relisent leurs paramètres toutes les dix secondes, sans que personne ne l'ait demandé explicitement. **Chaque appel est facturé.** Ce n'est pas une dérive grave ici ; à l'échelle de centaines de pods, c'en est une.

> **Livrable attendu :** capture de la vue journalière groupée par service, et les deux tableaux complétés.

---

### Étape 2 — Poser un garde-fou (35 min)

1. Console → **Billing and Cost Management** → *Budgets* → **Créer un budget**.
2. Type : **Budget de coût**, personnalisé.
3. Période **Mensuelle**, montant **20 USD**.
4. Alertes — créez-en **deux**, et c'est le point de l'exercice :
   - à **80 % du montant réel**
   - à **100 % du montant prévisionnel**
5. Destinataire : votre adresse e-mail.

> **Pourquoi deux seuils de natures différentes ?** Le seuil *réel* vous prévient quand l'argent est déjà dépensé — c'est un constat. Le seuil *prévisionnel* vous prévient quand la tendance mène au dépassement, souvent plusieurs jours avant. C'est la différence exacte entre une alarme sur `CPUUtilization` et une alarme sur la pente de la courbe. Le second vous laisse le temps d'agir.

| Question | Réponse |
|---|---|
| Votre consommation actuelle par rapport au budget | |
| La prévision de fin de mois dépasse-t-elle 20 USD ? | |
| Sur quel seuil seriez-vous alerté en premier ? | |

> **Livrable attendu :** capture du budget créé avec ses deux alertes.

---

### Étape 3 — Trois décisions d'optimisation (10 min)

Sans rien manipuler, répondez :

| Question | Votre réponse |
|---|---|
| Quelle est la première chose à supprimer en fin de formation, et pourquoi ? | |
| Quelle rétention de journaux choisiriez-vous pour un environnement de développement ? Et pour un audit de sécurité ? | |
| L'enregistrement de configuration doit-il rester actif en permanence ? Sur quelles ressources ? | |

---

## 4. Partie 2 — Atelier final (1 h 45)

### La situation

Il est 3 h 10 du matin. Vous êtes d'astreinte. Le centre d'appels signale que **des commandes d'abonnement n'aboutissent plus**. Le responsable de la facturation signale de son côté que **le traitement a plusieurs heures de retard**.

Vous n'avez aucune autre information. Vous avez trois jours d'outillage.

**Votre formateur vient de déclencher l'incident.** Attendez une minute que la chaîne bascule.

---

### Ce qu'on attend de vous

**Ne cherchez pas au hasard.** Établissez d'abord un ordre d'investigation, puis suivez-le. Consignez vos réponses au fur et à mesure : le débrief portera autant sur votre méthode que sur vos conclusions.

#### a. Constat (20 min)

| Question | Réponse | Où l'avez-vous vu ? |
|---|---|---|
| Depuis quand la situation est-elle anormale ? | | |
| Combien de symptômes distincts identifiez-vous ? | | |
| Tous les services sont-ils touchés ? | | |

#### b. Investigation (45 min)

Pour chaque symptôme, la cause et l'écran qui l'a révélée.

| # | Symptôme constaté | Service concerné | Écran qui l'a révélé |
|---|---|---|---|
| 1 | | | |
| 2 | | | |
| 3 | | | |
| 4 | | | |
| 5 | | | |

> **Indice méthodologique, si vous bloquez après vingt minutes :** vous avez construit quatre familles d'outils en trois jours. Métriques et Container Insights. Journaux et Logs Insights. Traces et carte des services. Audit, conformité et coûts. Un symptôme se cache dans chacune.

#### c. Cause racine et périmètre (20 min)

| Question | Réponse |
|---|---|
| Y a-t-il **une** cause unique, ou plusieurs causes indépendantes ? | |
| Le symptôme de sécurité est-il lié aux symptômes de performance ? | |
| Qu'est-ce qui justifie de réveiller quelqu'un, et qu'est-ce qui peut attendre 8 h ? | |

#### d. Plan d'action (20 min)

Rédigez, en une page :

1. **Trois actions immédiates**, dans l'ordre, pour rétablir le service.
2. **Trois alarmes** que vous auriez voulu avoir avant cette nuit. Pour chacune : métrique, seuil, durée, destinataire — et surtout **pourquoi celle-là et pas une autre**.
3. **Une mesure de fond** pour que cela ne se reproduise pas.

> **Sur les trois alarmes.** C'est la partie évaluée. Une alarme trop sensible est pire que pas d'alarme : elle sera ignorée dans un mois. Justifiez chaque seuil.

---

## 5. Débrief collectif (20 min)

Chaque groupe présente son plan d'action. La question de clôture de la formation :

> **Parmi les alarmes que vous venez de proposer, lesquelles auriez-vous réellement voulu recevoir à trois heures du matin ?**

---

## 6. Nettoyage de fin de formation

Dans cet **ordre inverse du déploiement** :

1. Vider les compartiments S3 — CloudFormation refuse de supprimer un compartiment non vide.
2. Supprimer `tp-j3-pm`, puis `tp-j3-am`, `tp-j2-pm`, `tp-j2-am`, `tp-j1-pm`.
3. `kubectl delete namespace bss`
4. Supprimer `tp-j1-am` **en dernier** : elle porte le cluster dont tout le reste dépend.
5. Désactiver GuardDuty et arrêter l'enregistreur AWS Config.

> Vérifiez dans Cost Explorer le lendemain que la courbe est bien retombée à zéro. C'est le dernier réflexe FinOps, et le plus souvent oublié.
