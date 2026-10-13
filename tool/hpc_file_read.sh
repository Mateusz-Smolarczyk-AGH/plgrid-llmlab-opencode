#!/usr/bin/env bash
# hpc_file_read.sh
#
# Fetches a single remote file's contents over SFTP using an SSH key +
# SSH certificate (e.g. signed user certificate, as issued by an HPC site's
# CA) for authentication. Mirrors the calling convention of slurmrestd.sh:
# positional args, key/cert paths first.
#
# Usage:
#   hpc_file_read.sh <ssh-key> <ssh-certificate> <user> <host> <remote-path> [max-bytes]
#
# Prints the file contents to stdout. Exits non-zero on failure, with a
# short error message on stderr.

set -euo pipefail

if [[ $# -lt 5 ]]; then
  echo "Usage: $0 <ssh-key> <ssh-certificate> <user> <host> <remote-path> [max-bytes]" >&2
  exit 1
fi

SSH_KEY="$1"
SSH_CERT="$2"
SSH_USER="$3"
SSH_HOST="$4"
REMOTE_PATH="$5"

if [[ ! -f "$SSH_KEY" ]]; then
  echo "SSH key not found: $SSH_KEY" >&2
  exit 1
fi

CERT_OPT=()
if [[ -n "$SSH_CERT" ]]; then
  CERT_OPT=("-o" "CertificateFile=$SSH_CERT")
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

LOCAL_OUT="$WORKDIR/out"

sftp \
  -o StrictHostKeyChecking=accept-new \
  -o IdentityFile="$SSH_KEY" \
  "${CERT_OPT[@]}" \
  -o "PasswordAuthentication=no" \
  -o "BatchMode=yes" \
  "${SSH_USER}@${SSH_HOST}" >/dev/null <<EOF
get "$REMOTE_PATH" "$LOCAL_OUT"
EOF

if [[ ! -f "$LOCAL_OUT" ]]; then
  echo "Failed to fetch remote file: $REMOTE_PATH" >&2
  exit 1
fi

cat "$LOCAL_OUT"
