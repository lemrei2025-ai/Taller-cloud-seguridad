#!/usr/bin/env bash
# Puebla la "cuenta AWS" emulada (Moto) con usuarios y políticas, algunas peligrosas.
# Así el Lab 4 tiene algo realista que auditar. Requiere el laboratorio en marcha.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AWS_ACCESS_KEY_ID=testing AWS_SECRET_ACCESS_KEY=testing AWS_DEFAULT_REGION=us-east-1 AWS_PAGER=""
AWS=(aws --endpoint-url http://localhost:5000)
CUENTA="123456789012"   # cuenta por defecto de Moto

crear_politica() {  # nombre archivo
  "${AWS[@]}" iam create-policy --policy-name "$1" \
    --policy-document "file://$DIR/politicas/$2" >/dev/null 2>&1 || true
}

echo "[*] Creando políticas..."
crear_politica AdminTodo          admin-todo.json
crear_politica DevGestionaIAM     dev-gestiona-iam.json
crear_politica LecturaFacturacion lectura-facturacion.json

echo "[*] Creando usuarios y asignando políticas..."
for u in carla-admin diego-dev elena-finanzas bot-ci; do
  "${AWS[@]}" iam create-user --user-name "$u" >/dev/null 2>&1 || true
done
"${AWS[@]}" iam attach-user-policy --user-name carla-admin    --policy-arn "arn:aws:iam::$CUENTA:policy/AdminTodo"
"${AWS[@]}" iam attach-user-policy --user-name diego-dev      --policy-arn "arn:aws:iam::$CUENTA:policy/DevGestionaIAM"
"${AWS[@]}" iam attach-user-policy --user-name elena-finanzas --policy-arn "arn:aws:iam::$CUENTA:policy/LecturaFacturacion"
"${AWS[@]}" iam attach-user-policy --user-name bot-ci         --policy-arn "arn:aws:iam::$CUENTA:policy/AdminTodo"
"${AWS[@]}" iam create-access-key --user-name bot-ci >/dev/null

echo "[*] Guardando un secreto en Secrets Manager (la forma correcta)..."
"${AWS[@]}" secretsmanager create-secret --name prod/app/base-datos \
  --secret-string '{"usuario":"app","clave":"N0-En-El-Codigo!"}' >/dev/null 2>&1 || true

echo "[+] Cuenta AWS emulada poblada. Explorar con: awsm iam list-users"
