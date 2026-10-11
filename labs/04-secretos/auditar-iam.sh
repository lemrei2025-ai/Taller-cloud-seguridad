#!/usr/bin/env bash
# Auditor mínimo de IAM: revisa las políticas gestionadas por el cliente y marca
#  - comodines totales (Action "*" sobre Resource "*")
#  - acciones IAM que permiten escalar privilegios
#  - usuarios con llaves de acceso y política de administrador
# Funciona contra Moto; con una cuenta real bastaría quitar --endpoint-url (solo lectura).
set -euo pipefail

export AWS_PAGER=""
ENDPOINT="${ENDPOINT:-http://localhost:5000}"
AWS=(aws --endpoint-url "$ENDPOINT")
PELIGROSAS='["iam:*","iam:CreateAccessKey","iam:AttachUserPolicy","iam:PutUserPolicy","iam:CreatePolicyVersion","iam:PassRole","iam:UpdateAssumeRolePolicy"]'

hallazgos=0
echo "== Políticas gestionadas por el cliente =="
for arn in $("${AWS[@]}" iam list-policies --scope Local --query 'Policies[].Arn' --output text); do
  ver=$("${AWS[@]}" iam get-policy --policy-arn "$arn" --query 'Policy.DefaultVersionId' --output text)
  doc=$("${AWS[@]}" iam get-policy-version --policy-arn "$arn" --version-id "$ver" \
        --query 'PolicyVersion.Document' --output json)
  # Algunas versiones devuelven el documento como texto (URL-encoded); se normaliza.
  if [[ "$(jq -r 'type' <<<"$doc")" == "string" ]]; then
    doc=$(jq -r '.' <<<"$doc" | python3 -c 'import sys,urllib.parse;print(urllib.parse.unquote(sys.stdin.read()))')
  fi
  # Normaliza Statement/Action/Resource a listas para poder compararlos.
  norm=$(jq '[.Statement] | flatten | map(select(.Effect=="Allow")
              | {a: ([.Action] | flatten), r: ([.Resource] | flatten)})' <<<"$doc")

  nombre="${arn##*/}"
  if jq -e 'any(.[]; (.a | index("*")) and (.r | index("*")))' <<<"$norm" >/dev/null; then
    echo "  [CRÍTICO] $nombre concede *:* (administrador total)"; hallazgos=$((hallazgos+1))
  fi
  escalada=$(jq -r --argjson p "$PELIGROSAS" '[.[].a[] | select(. as $x | $p | index($x))] | unique | join(", ")' <<<"$norm")
  if [[ -n "$escalada" ]]; then
    echo "  [ALTO]    $nombre permite escalar privilegios: $escalada"; hallazgos=$((hallazgos+1))
  fi
done

echo "== Usuarios =="
for u in $("${AWS[@]}" iam list-users --query 'Users[].UserName' --output text); do
  pols=$("${AWS[@]}" iam list-attached-user-policies --user-name "$u" --query 'AttachedPolicies[].PolicyName' --output text)
  llaves=$("${AWS[@]}" iam list-access-keys --user-name "$u" --query 'length(AccessKeyMetadata)' --output text)
  echo "  $u -> políticas: ${pols:-ninguna} | llaves de acceso: $llaves"
  if [[ "$pols" == *AdminTodo* && "$llaves" -gt 0 ]]; then
    echo "  [ALTO]    $u tiene llaves de larga duración Y es administrador"; hallazgos=$((hallazgos+1))
  fi
done

echo
echo "Total de hallazgos: $hallazgos"
