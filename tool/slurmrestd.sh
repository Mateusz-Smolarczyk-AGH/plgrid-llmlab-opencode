#!/bin/bash
KEY="$1"
CERT="$2"
USER="$3"
HOST="$4"
REQUEST="$5"

CERT_OPT=()
if [[ -n "$CERT" ]]; then
  CERT_OPT=("-o" "CertificateFile=$CERT")
fi

printf "${REQUEST}\r\n\r\n" | ssh \
  -i "$KEY" \
  "${CERT_OPT[@]}" \
  -o "StrictHostKeyChecking=accept-new" \
  -o "PasswordAuthentication=no" \
  -o "BatchMode=yes" \
  "$USER@$HOST" "slurmrestd"
