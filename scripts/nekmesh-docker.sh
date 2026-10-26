#!/usr/bin/env bash
# Run NekMesh from the current Nektar++ Docker image with the repository mounted.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec docker run --rm --user "$(id -u):$(id -g)" \
    --mount "type=bind,src=$repo_root,dst=$repo_root" \
    -w "$(pwd -P)" nektarpp/nektar:latest NekMesh "$@"
