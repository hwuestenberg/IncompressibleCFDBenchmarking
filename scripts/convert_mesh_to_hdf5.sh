#!/usr/bin/env bash
# Convert a Nektar++ XML mesh to its HDF5 .nekg plus companion .xml.
# Usage: convert_mesh_to_hdf5.sh INPUT.xml [OUTPUT_STEM]
set -euo pipefail

: "${NEKMESH_BIN:?Set NEKMESH_BIN to NekMesh or scripts/nekmesh-docker.sh}"
[[ $# -ge 1 && $# -le 2 ]] || { echo "Usage: $0 INPUT.xml [OUTPUT_STEM]" >&2; exit 2; }
input="$1"
[[ -f "$input" ]] || { echo "Missing XML mesh: $input" >&2; exit 1; }
input="$(realpath "$input")"
stem="${2:-${input%.xml}-hdf5}"
[[ "$stem" != *.xml && "$stem" != *.nekg ]] || { echo "OUTPUT_STEM must have no extension" >&2; exit 2; }
[[ "$stem" = /* ]] || stem="$(pwd -P)/$stem"
[[ "$stem.xml" != "$input" ]] || { echo "Output would overwrite input: $input" >&2; exit 2; }
mkdir -p "$(dirname "$stem")"

echo "Converting $input -> $stem.nekg (+ $stem.xml)"
(
    cd "$(dirname "$stem")"
    "$NEKMESH_BIN" "$input" "$(basename "$stem").nekg"
)
[[ -s "$stem.nekg" && -s "$stem.xml" ]] || {
    echo "NekMesh did not produce both $stem.nekg and $stem.xml" >&2
    exit 1
}
# NekMesh may embed an absolute path when given an absolute input. Keep the
# companion portable so the two files can be staged together on compute nodes.
python3 - "$stem.xml" "$(basename "$stem").nekg" <<'PY'
import sys
import xml.etree.ElementTree as ET

path, filename = sys.argv[1:]
tree = ET.parse(path)
geometry = tree.getroot().find("GEOMETRY")
if geometry is None or not geometry.get("HDF5FILE"):
    raise SystemExit(f"Missing HDF5FILE in {path}")
geometry.set("HDF5FILE", filename)
tree.write(path, encoding="utf-8", xml_declaration=True)
PY
