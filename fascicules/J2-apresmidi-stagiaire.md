# J2 — Après-midi · Performance & observabilité avancée
## Fascicule stagiaire

> **Votre région de travail : celle de votre sandbox.** Relevez-la en haut à droite de la console et notez-la sur votre fiche de déploiement. Dans cette salle, chacun peut travailler dans une région différente : il n'y a pas de réponse commune à « je ne retrouve pas ma ressource ».

---

## 1. Contexte et objectif

Une commande d'abonnement met sept secondes à aboutir. Elle aboutit — donc aucune alarme ne sonne, aucun code d'erreur n'apparaît, votre tableau de bord est vert. Et pourtant le client raccroche.

C'est le problème que cet après-midi traite. Les métriques vous disent *qu'une machine va mal*. Les logs vous disent *ce qu'un service a fait*. Ni les unes ni les autres ne vous disent **où le temps est passé** dans une chaîne qui traverse cinq services et une file d'attente.

C'est le rôle du traçage distribué. Chaque requête reçoit un identifiant qui la suit de bout en bout ; chaque service y attache un segment avec sa durée. Le résultat n'est pas un graphique de plus : c'est une carte qui montre la chaîne et désigne le maillon lent.

Votre chaîne BSS reproduit la vôtre : CRM → IDM → Provisioning → Médiation → Facturation, avec une rupture asynchrone par file d'attente entre la médiation et la facturation. Cette rupture est le point intéressant — c'est exactement ce qu'un agent applicatif classique ne franchit pas.

---

## 2. Services mobilisés et prérequis

| Élément | Détail |
|---|---|
| Services AWS | X-Ray, CloudWatch Container Insights, SQS, Systems Manager |
| Prérequis | Stack `tp-j1-am` déployée, chaîne BSS en cours d'exécution |
| Durée | 3 h 00 |
| Coût | Négligeable — X-Ray facture à la trace, quelques centimes |

---

## 3. Énoncé

### Étape 0 — Introduire le problème (10 min)

Dans **CloudShell** :

```bash
cd ~/lab && git pull          # récupère les fichiers de la demi-journée

aws cloudformation deploy \
  --template-file templates/tp-j2-pm.yaml \
  --stack-name tp-j2-pm \
  --capabilities CAPABILITY_NAMED_IAM
```

La commande rend la main quand la stack est créée. Vous pouvez suivre l'avancement en parallèle dans **CloudFormation → tp-j2-pm → Événements**.

Laissez les paramètres par défaut : latence 1800 ms, taux d'erreur 15 %.

> **Ce que fait cette stack :** elle crée quatre paramètres que les services relisent toutes les dix secondes. Aucun redéploiement, aucun redémarrage de pod. **L'effet est visible en moins d'une minute.** C'est ainsi que se construit un environnement de démonstration honnête : le problème est injecté par configuration, pas simulé.

Attendez deux minutes avant de passer à l'étape 1, le temps que les traces dégradées s'accumulent.

---

### Étape 1 — Lire la carte des services (45 min)

Console → **CloudWatch** → *X-Ray traces* → **Carte des services**. Plage : **15 dernières minutes**.

Vous devez voir apparaître un graphe. Prenez le temps de l'observer avant de répondre.

| Question | Réponse |
|---|---|
| Combien de nœuds applicatifs (`bss-…`) voyez-vous ? | |
| Quels nœuds ne sont **pas** des services applicatifs ? | |
| Quel service affiche la latence moyenne la plus élevée ? | |
| Quel service affiche le taux d'erreur le plus élevé ? | |
| Le service le plus lent est-il le même que le plus fautif ? | |

> **Regardez les nœuds qui ne portent pas de nom `bss-`.** Vous devriez trouver une file SQS et un nœud Systems Manager. Vous ne les avez pas instrumentés — ils apparaissent parce que X-Ray trace les appels aux services managés AWS automatiquement, dès lors que le SDK est en place. Notez-le : c'est le point qui distingue X-Ray d'un agent applicatif, et nous y reviendrons.

> **Livrable attendu :** une capture de la carte des services, et le tableau complété.

---

### Étape 2 — Descendre dans une trace (45 min)

1. Sur la carte, cliquez sur le nœud **`bss-mediation`** → *Afficher les traces*.
2. Triez par **durée décroissante**. Ouvrez la trace la plus longue.
3. Étudiez la chronologie des segments.

| Question | Réponse |
|---|---|
| Durée totale de la trace | |
| Durée du segment `bss-mediation` | |
| Part de la médiation dans le total (en %) | |
| Que fait la médiation pendant ce temps ? Voyez-vous un sous-segment ? | |
| Quel segment vient juste après la médiation ? | |

4. Ouvrez maintenant une trace **en erreur** : filtrez avec `service("bss-facturation") { error }`.

| Question | Réponse |
|---|---|
| À quel service l'erreur est-elle attribuée ? | |
| Le service en erreur est-il le service lent ? | |
| Quelle est la durée de cette trace par rapport à une trace saine ? | |

> **Le point à saisir :** la lenteur et l'erreur sont dans deux services différents. Une alerte sur le temps de réponse global vous aurait désigné la chaîne entière ; la trace vous désigne le maillon. C'est la différence entre « le système est lent » et « la médiation ajoute 1,8 seconde ».

> **Livrable attendu :** captures des deux traces, et les deux tableaux complétés.

---

### Étape 3 — Corréler avec les conteneurs (40 min)

Une trace dit *où* le temps est passé. Elle ne dit pas *pourquoi*. Pour cela, il faut redescendre au niveau de l'infrastructure.

1. Console → **CloudWatch** → *Insights* → **Container Insights**.
2. Sélectionnez votre cluster `bss-<initiales>`.
3. Explorez successivement : *Clusters*, *Nœuds*, *Pods*.

| Question | Réponse |
|---|---|
| Combien de pods tournent dans le namespace `bss` ? | |
| Les pods `provisioning` sont-ils sur le même nœud ? | |
| Quel pod consomme le plus de CPU ? | |
| Le pod `mediation` est-il saturé en CPU ? | |

> **Question centrale, à préparer pour le débrief :** la médiation ajoute 1,8 seconde, mais son pod n'est pas saturé. Ni CPU, ni mémoire. **Que peut-on en déduire sur la nature du problème ?** Formulez votre réponse en termes de ce que le conteneur attend.

4. Ouvrez enfin **SQS** → file `bss-facturation-<initiales>` → onglet *Surveillance*.

| Question | Réponse |
|---|---|
| Nombre approximatif de messages en attente | |
| Âge du plus ancien message | |
| Que vous dit cette métrique sur l'état de la facturation ? | |

---

### Étape 4 — Alarmer sur ce qui compte vraiment (40 min)

Vous allez créer deux alarmes, et surtout justifier pourquoi ce sont celles-là.

**Alarme 1 — le retard de la chaîne asynchrone**

1. CloudWatch → *Alarmes* → **Créer une alarme**.
2. Métrique : **SQS** → *Par file* → `bss-facturation-<initiales>` → **ApproximateAgeOfOldestMessage**.
3. Statistique **Maximum**, période **5 minutes**, seuil **supérieur à 900** (15 minutes).
4. Action : rubrique `bss-alertes-performance-<initiales>`.

**Alarme 2 — la saturation d'un pod**

5. Métrique : **ContainerInsights** → *ClusterName, Namespace, PodName* → `pod_cpu_utilization` du pod `provisioning`.
6. Seuil **supérieur à 80**, **3 points de données sur 3**, période **1 minute**.

**Puis vérifiez votre travail :**

7. Console → **Systems Manager** → *Parameter Store* → `/bss/<initiales>/provisioning/charge-cpu` → **Modifier** → valeur **`85`** → Enregistrer.
8. Attendez, observez l'alarme 2 basculer, chronométrez.
9. Remettez le paramètre à `0`.

> **Livrables attendus :**
> - les deux alarmes créées, capture à l'appui
> - le délai mesuré entre le changement de paramètre et la bascule de l'alarme 2
> - votre réponse : parmi ces deux alarmes, laquelle réveilleriez-vous quelqu'un pour, à trois heures du matin, et pourquoi ?

---

## 4. Points à retenir

- Une métrique dit qu'une machine va mal. Un log dit ce qu'un service a fait. Une trace dit où le temps est passé. Les trois sont nécessaires et aucune ne se déduit des autres.
- Le service le plus lent n'est presque jamais le service le plus fautif. Sans trace, on corrige le mauvais.
- Un pod lent sans saturation CPU attend quelque chose : un appel réseau, un verrou, une base. La corrélation trace + conteneur est ce qui permet de trancher.
- La profondeur d'une file d'attente est une métrique de service, pas d'infrastructure. C'est souvent la plus parlante d'une chaîne asynchrone.

---

## 5. Nettoyage

**Ne supprimez rien.** L'environnement de cet après-midi sert de base à l'atelier final de demain. Remettez simplement `/bss/<initiales>/provisioning/charge-cpu` à `0` si ce n'est pas déjà fait.
