#!/usr/bin/env bash
#
# Build the 2D cylinder mesh from a gmsh geometry file.
# Gmsh meshes the .geo into a .msh file,
# then NekMesh converts that into the Nektar++ session-mesh .xml.
#
# Requires:
#   GMSH_BIN    path to the gmsh executable
#   NEKMESH_BIN path to the NekMesh executable (see scripts/env.sh.example)
#
# Usage:
#   ./build_mesh_2d.sh
#
# The gmsh Physical Surface/Curve tags in the .geo become Nektar++
# composite IDs directly on conversion, and already match what
# session-legacy.xml / session-redesign.xml expect:
#   C[1]=domain  C[2]=inflow  C[3]=outflow  C[4]=bottom(farfield)
#   C[5]=top(farfield)  C[6]=cylinder wall
# -- no manual ID lookup/edit needed after running this.

set -euo pipefail

: "${GMSH_BIN:?Set GMSH_BIN to the path of the gmsh executable}"
: "${NEKMESH_BIN:?Set NEKMESH_BIN to the path of the NekMesh executable}"

: "${SOURCE_GEO:?Set SOURCE_GEO to the path of the .geo file}"
MSH_FILE="${MSH_FILE:-cylinder-2d.msh}"
XML_FILE="${XML_FILE:-cylinder-2d.xml}"

[ -f "$SOURCE_GEO" ] || {
    echo "Source geometry not found: $SOURCE_GEO" >&2
    echo "(override with SOURCE_GEO=... if it has moved)" >&2
    exit 1
}

echo "Meshing $SOURCE_GEO -> $MSH_FILE"
"$GMSH_BIN" -2 "$SOURCE_GEO" -o "$MSH_FILE"

echo "Converting $MSH_FILE -> $XML_FILE"
"$NEKMESH_BIN" "$MSH_FILE" "$XML_FILE:xml:uncompress"

echo
echo "Done: $XML_FILE"
echo "Sanity check element/composite counts, e.g.:"
echo "  grep -c '<Q ID=' \"$XML_FILE\"   # expect 2880 quads"
