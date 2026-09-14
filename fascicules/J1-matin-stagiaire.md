# J1 — Matin · Fondamentaux de la supervision & monitoring cloud
## Fascicule stagiaire

> **Votre région de travail : celle de votre sandbox.** Relevez-la en haut à droite de la console et notez-la sur votre fiche de déploiement. Dans cette salle, chacun peut travailler dans une région différente : il n'y a pas de réponse commune à « je ne retrouve pas ma ressource ». Vérifiez-la **avant chaque manipulation** — une ressource créée ailleurs sera invisible dans vos écrans.

---

## 0. Avant tout : lancer la construction de votre environnement

Cette manipulation se fait **une fois pour les trois jours**, et elle dure treize minutes. Lancez-la maintenant : elle travaille en arrière-plan pendant l'apport théorique.

Ouvrez **CloudShell** (icône `>_` en bas à gauche de la console), puis :

```bash
git clone https://github.com/bart120/aws-orange-sept25.git ~/lab
cd ~/lab

INIT=<vos-initiales>            # tapez-les comme vous voulez
export INIT=${INIT,,}           # forcees en minuscules : S3 n'accepte que ca
export REG=${AWS_REGION:-$(aws configure get region)}
echo "$INIT dans $REG"          # relisez cette ligne

bash controle-acces.sh          # quinze secondes, ne sautez pas cette ligne

aws cloudformation deploy \
  --template-file templates/tp-j1-am.yaml \
  --stack-name tp-j1-am \
  --parameter-overrides Stagiaire=$INIT \
  --capabilities CAPABILITY_NAMED_IAM
```

> **Si `controle-acces.sh` affiche un rouge, ne déployez pas.** Le portail propose plusieurs rôles et un rôle en lecture seule laisse tout passer jusqu'à faire échouer la stack au bout de plusieurs minutes, sur un message qui ne dit pas la cause. Le script vous indique quoi faire.

Laissez tourner. Le détail des commandes, le calendrier des trois jours et les messages d'erreur courants sont dans **`FICHE-DEPLOIEMENT.md`**, à garder ouvert.

Le TP du matin, lui, se fait **entièrement dans la console** et ne dépend pas de cette stack. Vous pouvez enchaîner sans attendre.

---

## 1. Contexte et objectif

Votre chaîne BSS traite des commandes d'abonnement de bout en bout : CRM, provisioning, médiation, facturation. Quand une commande n'aboutit pas, la première question n'est jamais « quel code d'erreur ? » mais « **est-ce que quelque chose a changé, et depuis quand ?** ».

Répondre à cette question suppose trois choses en place **avant** l'incident :

- une mesure continue de l'état des ressources (les **métriques**),
- un seuil au-delà duquel on considère que l'état est anormal (l'**alarme**),
- un canal qui prévient quelqu'un (la **notification**).

C'est précisément ce que vous allez construire ce matin, sur un nœud isolé représentant un collecteur de médiation. L'objectif n'est pas de savoir cliquer dans CloudWatch : c'est de comprendre **pourquoi** un seuil à 70 % pendant 5 minutes n'a pas le même sens qu'un seuil à 90 % pendant 1 minute, et ce que chacun coûte en réveils nocturnes inutiles.

À la fin de la matinée, vous saurez répondre à : *sur quelle métrique, à quel seuil, pendant combien de temps, et qui je préviens ?*

---

## 2. Services mobilisés et prérequis

| Élément | Détail |
|---|---|
| Services AWS | EC2, CloudWatch (métriques, alarmes, tableaux de bord), SNS, VPC |
| Rôle d'accès | `SandboxAdministratorAccess` via le portail d'accès AWS |
| Région | celle de votre sandbox — **la même pendant les trois jours** |
| Accès à l'instance | EC2 Instance Connect, dans le navigateur — **aucune clé SSH à gérer** |
| Adresse e-mail | La vôtre, professionnelle. Vous recevrez une demande de confirmation AWS à valider. |

**Point d'attention préalable :** votre compte sandbox peut ne pas disposer de VPC par défaut. L'étape 0 le vérifie et le crée si besoin. Ne sautez pas cette étape, sinon le lancement de l'instance échouera sans message explicite.

---

## 3. Durée et coût

| | |
|---|---|
| Durée estimée | 2 h 15 (hors pause) |
| Coût des ressources créées | **Moins de 0,05 €** si le nettoyage de la section 6 est effectué |
| Poste principal | Instance `t3.micro` — facturée à la seconde |
| Alarmes CloudWatch | 10 alarmes gratuites par compte et par mois |
| SNS | 1 000 notifications e-mail gratuites par mois |

---

## 4. Énoncé

### Étape 0 — Vérifier le réseau (10 min)

1. Console → service **VPC** → **Vos VPC**.
2. Si la liste est vide : menu **Actions** → **Créer un VPC par défaut** → confirmer.
3. Vérifier ensuite dans **Sous-réseaux** qu'il existe au moins deux sous-réseaux, dans deux zones de disponibilité différentes.

> **Livrable attendu :** l'identifiant de votre VPC (format `vpc-xxxxxxxx`) et le nombre de sous-réseaux.
>
> VPC : `…………………………` Sous-réseaux : `………`

---

### Étape 1 — Déployer le nœud à superviser (25 min)

1. Console → **EC2** → **Instances** → **Lancer une instance**.
2. Nom : `mediation-<vos-initiales>`.
3. Image : **Amazon Linux 2023**, architecture 64 bits (x86).
4. Type : **t3.micro**.
5. Paire de clés : **Continuer sans paire de clés**.
6. Paramètres réseau → **Modifier** :
   - VPC : celui de l'étape 0,
   - Attribuer automatiquement une IP publique : **Activer**,
   - Groupe de sécurité : créer `sg-mediation-<initiales>`, **sans aucune règle entrante**.
7. **Détails avancés** → dérouler jusqu'à **Surveillance détaillée CloudWatch** → **Activer**.
8. Lancer.

> **Pourquoi désactiver toute règle entrante ?** Parce que vous n'en avez pas besoin : EC2 Instance Connect passe par l'API AWS, pas par le port 22. Ouvrir SSH au monde sur une instance de lab est exactement le genre de dérive que le TP de conformité du J2 détectera.

> **Pourquoi la surveillance détaillée ?** Sans elle, les métriques remontent toutes les 5 minutes. Une alarme sur 5 minutes réagira donc au mieux au bout de 10. Avec la surveillance détaillée, la granularité passe à 1 minute. Notez ce que cela change sur le délai de détection : c'est une vraie décision d'exploitation, pas une case à cocher.

> **Livrable attendu :** l'ID de l'instance et sa zone de disponibilité.
>
> Instance : `…………………………` AZ : `………………`

---

### Étape 2 — Créer le canal de notification (20 min)

1. Console → **Amazon SNS** → **Rubriques** → **Créer une rubrique**.
2. Type : **Standard**. Nom : `alertes-mediation-<initiales>`.
3. Créer, puis dans l'onglet **Abonnements** → **Créer un abonnement** :
   - Protocole : **E-mail**,
   - Point de terminaison : votre adresse professionnelle.
4. **Relevez vos e-mails** et cliquez sur *Confirm subscription*.
5. Revenez sur la console et vérifiez que le statut de l'abonnement est passé de *En attente de confirmation* à **Confirmé**.

> **Ne passez pas à l'étape 3 tant que le statut n'est pas « Confirmé ».** Une alarme reliée à un abonnement non confirmé se déclenchera normalement, changera d'état, et n'enverra strictement rien. C'est la panne silencieuse la plus fréquente en production.

> **Livrable attendu :** capture d'écran de l'abonnement au statut *Confirmé*.

---

### Étape 3 — Créer l'alarme CPU (30 min)

1. Console → **CloudWatch** → **Alarmes** → **Créer une alarme**.
2. **Sélectionner une métrique** → EC2 → *Par instance* → votre instance → **CPUUtilization**.
3. Statistique : **Moyenne**. Période : **1 minute**.
4. Condition : **Statique**, **Supérieur à**, seuil **70**.
5. Configuration supplémentaire :
   - Points de données pour l'alarme : **2 sur 2**,
   - Traitement des données manquantes : **Considérer comme correct**.
6. Action : état **En alarme** → rubrique SNS de l'étape 2.
7. Nom : `cpu-haute-mediation-<initiales>`. Créer.

**Puis déclenchez-la réellement :**

8. EC2 → votre instance → **Se connecter** → onglet **EC2 Instance Connect** → **Se connecter**.
9. Dans le terminal, lancez une charge sur tous les cœurs :

   ```
   for i in $(nproc --all | xargs seq); do yes > /dev/null & done
   ```

10. Observez l'alarme passer de *OK* à *Insuffisance de données* puis à *En alarme*. **Chronométrez** le délai entre le lancement de la charge et la réception de l'e-mail.
11. Arrêtez la charge : `pkill yes`

> **Livrables attendus :**
> - le délai mesuré entre le début de la charge et l'e-mail : `……… min ……… s`
> - une capture du graphique de l'alarme montrant le franchissement du seuil.

> **Question à préparer pour le débrief :** vous avez choisi *2 points sur 2*. Qu'auriez-vous détecté de plus, et de moins, avec *1 sur 1* ? Avec *5 sur 5* ? Formulez votre réponse en termes de faux positifs et de temps de détection, pas en termes de préférence.

---

### Étape 4 — Construire le tableau de bord (30 min)

1. CloudWatch → **Tableaux de bord** → **Créer un tableau de bord** → `supervision-mediation-<initiales>`.
2. Ajoutez quatre widgets, un par signal :

| Signal | Métrique | Type de widget |
|---|---|---|
| Saturation | `CPUUtilization` | Ligne |
| Saturation disque | `EBSReadOps` + `EBSWriteOps` | Ligne empilée |
| Trafic | `NetworkIn` + `NetworkOut` | Ligne |
| État | Votre alarme CPU | Statut d'alarme |

3. Réglez la plage temporelle sur **3 heures** et sauvegardez.

> **Pourquoi ces quatre-là ?** Ce sont les *golden signals* vus en cours, adaptés à ce que l'hyperviseur AWS peut voir d'une instance. Remarquez ce qui **manque** : la latence applicative et le taux d'erreur. Aucune métrique EC2 native ne vous les donnera — il faudra les logs et l'instrumentation applicative, objets du J1 après-midi et du J2. Gardez cette limite en tête, c'est le cœur de la distinction monitoring / observabilité.

> **Livrable attendu :** capture du tableau de bord complet, les quatre widgets visibles.

---

## 5. Points à retenir

- Une métrique sans seuil ne sert à rien ; un seuil sans destinataire non plus.
- Le délai de détection est la somme de la granularité, du nombre de points de données requis et du temps de propagation. Il se calcule, il ne se devine pas.
- CloudWatch voit l'infrastructure depuis l'extérieur de la machine. Tout ce qui se passe *à l'intérieur* d'un processus lui est invisible par défaut.

---

## 6. Nettoyage — à faire avant la pause déjeuner

Dans cet ordre :

1. **CloudWatch → Alarmes** : supprimer `cpu-haute-mediation-<initiales>`.
2. **CloudWatch → Tableaux de bord** : conserver le vôtre, il servira au J3.
3. **EC2 → Instances** : sélectionner votre instance → *État de l'instance* → **Résilier**.
4. **EC2 → Groupes de sécurité** : supprimer `sg-mediation-<initiales>` une fois l'instance résiliée.
5. **SNS** : conserver la rubrique et l'abonnement, ils resserviront cet après-midi.

> Une instance oubliée coûte environ 0,25 € par jour. Ce n'est rien, jusqu'au moment où vingt stagiaires l'oublient pendant trois semaines. Le J3 après-midi sera consacré exactement à cette question.
