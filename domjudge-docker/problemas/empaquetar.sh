#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/ejemplo-suma"
zip -r ../ejemplo-suma.zip . -x "*.DS_Store"
echo "Generado: problemas/ejemplo-suma.zip"
