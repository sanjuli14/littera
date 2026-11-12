#!/usr/bin/env bash
# Imprime las novedades de una versión de CHANGELOG.md (la sección
# "## [X.Y.Z] …" hasta la siguiente "## ["). Falla si no existe.
set -euo pipefail
version="${1:?uso: tool/release_notes.sh X.Y.Z}"
notes="$(awk -v v="$version" '
  $0 ~ "^## \\[" v "\\]" { found = 1; next }
  found && /^## \[/ { exit }
  found { print }
' CHANGELOG.md | sed -e '/./,$!d')"
if [ -z "${notes//[[:space:]]/}" ]; then
  echo "No hay novedades para $version en CHANGELOG.md" >&2
  exit 1
fi
printf '%s\n' "$notes"
