#!/bin/bash
# ---------------------------------------------------------------------------
# Controle d'entree, a lancer AVANT tout deploiement.
#
#     bash ~/lab/controle-acces.sh
#
# Quinze secondes. Il verifie la seule chose qui, mal partie, coute une
# demi-journee : le role endosse depuis le portail d'acces.
#
# Le portail expose souvent plusieurs roles. Un role en lecture seule laisse
# passer la connexion, laisse passer CloudShell, laisse meme demarrer le
# deploiement — puis fait echouer la stack sur iam:GetRole au bout de
# plusieurs minutes, avec un message qui ne designe pas la cause.
# ---------------------------------------------------------------------------

vert()  { printf '  \033[0;32m[ OK ]\033[0m %s\n' "$1"; }
rouge() { printf '  \033[0;31m[ KO ]\033[0m %s\n' "$1"; }

printf '\n\033[1mControle d acces\033[0m\n'

IDENT=$(aws sts get-caller-identity --query 'Arn' --output text 2>&1)
if [[ "$IDENT" != arn:* ]]; then
  rouge "Pas de session AWS valide."
  echo "        Rouvrez le portail d acces et recliquez sur votre role."
  exit 1
fi

REGION="${AWS_REGION:-$(aws configure get region 2>/dev/null)}"
ROLE=$(echo "$IDENT" | cut -d/ -f2)

vert "Region      : ${REGION:-?}   <- notez-la"
vert "Utilisateur : $(echo "$IDENT" | sed 's|.*/||')"
vert "Role        : $ROLE"

if aws iam list-roles --max-items 1 >/dev/null 2>&1; then
  vert "Droits IAM  : suffisants"
else
  rouge "Droits IAM  : INSUFFISANTS"
  printf '\n\033[0;31mVous n etes pas sur le bon role. Ne deployez rien.\033[0m\n\n'
  echo "  1. Retournez au portail d acces"
  echo "  2. Cliquez sur SandboxAdministratorAccess"
  echo "  3. ROUVREZ CloudShell depuis ce nouvel onglet de console."
  echo "     Le terminal actuel garde l ancien role : Reconnecter ne suffit pas."
  echo "  4. Votre dossier ~/lab sera vide, refaites le git clone."
  echo
  exit 1
fi

ZONES=$(aws ec2 describe-availability-zones --query 'length(AvailabilityZones)' --output text 2>/dev/null)
if [ "${ZONES:-0}" -ge 3 ]; then
  vert "Zones       : $ZONES"
else
  rouge "Zones       : ${ZONES:-?} (3 requises). Signalez-le au formateur."
  exit 1
fi

printf '\n\033[0;32mVous pouvez deployer. Annoncez « vert » au formateur.\033[0m\n\n'
