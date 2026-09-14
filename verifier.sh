#!/bin/bash
# ---------------------------------------------------------------------------
# Verification de l'environnement de formation.
#
# A lancer dans CloudShell, a tout moment :
#     bash ~/lab/verifier.sh
#
# Chaque stagiaire le lance lui-meme et annonce son resultat au formateur :
# c'est le seul moyen de suivre l'avancement d'une salle ou chaque personne
# travaille dans son propre compte AWS.
# ---------------------------------------------------------------------------

INITIALES="${1:-}"

vert()  { printf '  \033[0;32m[ OK ]\033[0m %s\n' "$1"; }
rouge() { printf '  \033[0;31m[ KO ]\033[0m %s\n' "$1"; PROBLEMES=$((PROBLEMES+1)); }
gris()  { printf '  [ -- ] %s\n' "$1"; }
titre() { printf '\n\033[1m%s\033[0m\n' "$1"; }

PROBLEMES=0

if [ -z "$INITIALES" ]; then
  echo "Usage : bash verifier.sh <vos-initiales>"
  echo "Exemple : bash verifier.sh vl"
  exit 1
fi

# Meme contrainte que le parametre Stagiaire du socle : les initiales
# suffixent des noms de compartiments S3, qui n'acceptent que ca.
if ! printf '%s' "$INITIALES" | grep -Eq '^[a-z0-9]{2,8}$'; then
  printf '\n  \033[0;31m[ KO ]\033[0m Initiales invalides : \"%s\"\n' "$INITIALES"
  echo "        Attendu : 2 a 8 caracteres, minuscules et chiffres uniquement."
  echo "        Corrigez avec :  export INIT=\${INIT,,}"
  echo
  exit 1
fi

titre "1. Compte et region"

# La region n'est pas imposee : chaque stagiaire peut travailler dans la
# sienne. On l'affiche pour qu'il l'annonce, et on verifie qu'elle convient.
REGION="${AWS_REGION:-$(aws configure get region 2>/dev/null)}"
if [ -z "$REGION" ]; then
  rouge "Region indeterminee. Rouvrez CloudShell depuis la console."
  exit 1
fi
vert "Region : $REGION   <- notez-la, toutes vos ressources y vivent"

ZONES=$(aws ec2 describe-availability-zones --query 'length(AvailabilityZones)' --output text 2>/dev/null)
if [ "${ZONES:-0}" -ge 3 ]; then
  vert "Zones de disponibilite : $ZONES"
else
  rouge "Zones de disponibilite : ${ZONES:-?} (3 requises par le socle)"
  echo "        Signalez-le au formateur : cette region ne convient pas."
fi

IDENT=$(aws sts get-caller-identity --query 'Arn' --output text 2>&1)
if [[ "$IDENT" == arn:* ]]; then
  vert "Identite : $(echo "$IDENT" | sed 's|.*/||')"
else
  rouge "Session expiree. Reconnectez-vous au portail d'acces."
  exit 1
fi

# Le portail expose souvent plusieurs roles. Un role en lecture seule laisse
# passer sts et ec2, puis fait echouer la stack sur iam:GetRole apres plusieurs
# minutes. On le detecte ici, avant tout deploiement.
ROLE=$(echo "$IDENT" | cut -d/ -f2)
vert "Role endosse : $ROLE"

if aws iam list-roles --max-items 1 >/dev/null 2>&1; then
  vert "Droits IAM : suffisants pour creer les roles des stacks"
else
  rouge "Droits IAM insuffisants avec le role $ROLE."
  echo "        Vous n'etes pas sur le bon role. Retournez au portail d'acces,"
  echo "        cliquez sur SandboxAdministratorAccess, puis ROUVREZ CloudShell"
  echo "        depuis ce nouvel onglet — le terminal actuel garde l'ancien role."
  echo "        Votre dossier ~/lab sera a recloner."
  exit 1
fi

titre "2. Stack socle (tp-j1-am)"

ETAT=$(aws cloudformation describe-stacks --stack-name tp-j1-am \
        --query 'Stacks[0].StackStatus' --output text 2>/dev/null)
case "$ETAT" in
  CREATE_COMPLETE|UPDATE_COMPLETE) vert "Socle : $ETAT" ;;
  *IN_PROGRESS)  gris "Socle en cours de creation ($ETAT) — patientez, comptez 13 minutes au total." ;;
  *ROLLBACK*)    rouge "Socle en echec ($ETAT). Supprimez la stack et redeployez."
                 aws cloudformation describe-stack-events --stack-name tp-j1-am \
                   --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`].[LogicalResourceId,ResourceStatusReason]' \
                   --output text 2>/dev/null | head -2 | sed 's/^/        /' ;;
  *)             rouge "Socle absent. Deployez tp-j1-am.yaml depuis la console CloudFormation." ; exit 1 ;;
esac

titre "3. Cluster et acces kubectl"

CLUSTER="bss-$INITIALES"
ETAT_CL=$(aws eks describe-cluster --name "$CLUSTER" --query 'cluster.status' --output text 2>/dev/null)
if [ "$ETAT_CL" = "ACTIVE" ]; then
  vert "Cluster $CLUSTER : ACTIVE"
  aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER" >/dev/null 2>&1
  NOEUDS=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready ")
  if [ "$NOEUDS" -ge 2 ]; then
    vert "Noeuds prets : $NOEUDS"
  else
    rouge "Noeuds prets : $NOEUDS (attendu : 2). Patientez deux minutes et relancez."
  fi
else
  gris "Cluster $CLUSTER : ${ETAT_CL:-absent} — normal tant que le socle n'est pas termine."
fi

titre "4. Chaine BSS"

if kubectl get namespace bss >/dev/null 2>&1; then
  TOTAL=$(kubectl get pods -n bss --no-headers 2>/dev/null | wc -l)
  PRETS=$(kubectl get pods -n bss --no-headers 2>/dev/null | grep -c "Running")
  if [ "$TOTAL" -gt 0 ] && [ "$PRETS" -eq "$TOTAL" ]; then
    vert "Pods : $PRETS/$TOTAL en cours d'execution"
    DERNIER=$(kubectl logs -n bss deploy/generateur-commandes --tail=1 2>/dev/null)
    if echo "$DERNIER" | grep -q '"statut": 200'; then
      vert "La chaine traite des commandes"
    elif [ -n "$DERNIER" ]; then
      rouge "Le generateur tourne mais la chaine ne repond pas encore. Attendez 60 secondes."
    fi
  elif [ "$TOTAL" -gt 0 ]; then
    gris "Pods : $PRETS/$TOTAL prets — l'installation des dependances prend 60 a 90 secondes."
    kubectl get pods -n bss --no-headers 2>/dev/null | grep -v Running | awk '{print "        "$1" : "$3}'
  fi
else
  gris "Chaine BSS non deployee — normal avant le J1 apres-midi."
fi

titre "5. Stacks des demi-journees"

for S in tp-j1-pm tp-j2-am tp-j2-pm tp-j3-am tp-j3-pm; do
  E=$(aws cloudformation describe-stacks --stack-name "$S" --query 'Stacks[0].StackStatus' --output text 2>/dev/null)
  case "$E" in
    CREATE_COMPLETE|UPDATE_COMPLETE) vert "$S : $E" ;;
    "")            gris "$S : non deployee" ;;
    *ROLLBACK*)    rouge "$S : $E — a supprimer avant de redeployer" ;;
    *)             gris "$S : $E" ;;
  esac
done

printf '\n'
if [ "$PROBLEMES" -eq 0 ]; then
  printf '\033[0;32mEnvironnement conforme. Annoncez « %s : vert ».\033[0m\n\n' "$INITIALES"
else
  printf '\033[0;31m%s point(s) a corriger. Annoncez « %s : %s rouge(s) ».\033[0m\n\n' \
    "$PROBLEMES" "$INITIALES" "$PROBLEMES"
fi
