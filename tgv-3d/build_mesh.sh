#!/usr/bin/env bash
# Build the Taylor-Green vortex mesh and pair periodic faces.

set -euo pipefail

: "${GMSH_BIN:?Set GMSH_BIN to the path of the gmsh executable}"
: "${NEKMESH_BIN:?Set NEKMESH_BIN to the path of the NekMesh executable}"

GEO_FILE="${GEO_FILE:-tgv.geo}"
N="${N:-64}"
MSH_FILE="${MSH_FILE:-tgv-${N}.msh}"
RAW_XML="${RAW_XML:-tgv-${N}-raw.xml}"
XML_FILE="${XML_FILE:-tgv-${N}.xml}"

echo "Meshing $GEO_FILE -> $MSH_FILE (N=$N per direction, N^3=$((N*N*N)) elements)"
"$GMSH_BIN" -3 -setnumber N "$N" -nopopup "$GEO_FILE" -o "$MSH_FILE"

echo "Converting $MSH_FILE -> $RAW_XML"
"$NEKMESH_BIN" "$MSH_FILE" "$RAW_XML:xml:uncompress"

echo "Pairing x/y/z faces as periodic -> $XML_FILE"
"$NEKMESH_BIN" \
    -m peralign:surf1=1:surf2=6:dir=z \
    -m peralign:surf1=5:surf2=3:dir=x \
    -m peralign:surf1=2:surf2=4:dir=y \
    "$RAW_XML" "$XML_FILE:xml:uncompress"

echo
echo "Done: $XML_FILE"
echo "If N != 64, update *-session.xml's mesh filename reference (the"
echo "sessions here assume tgv-64.xml, matching the baseline's 64^3 mesh)."
echo "Sanity check, e.g.:"
echo "  grep -c '<H ID=' \"$XML_FILE\"   # expect $((N*N*N)) hexahedra"
