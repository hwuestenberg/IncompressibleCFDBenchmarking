#!/usr/bin/env bash
# Build the Taylor-Green vortex mesh and pair periodic faces.

set -euo pipefail

: "${GMSH_BIN:?Set GMSH_BIN to the path of the gmsh executable}"
: "${NEKMESH_BIN:?Set NEKMESH_BIN to the path of the NekMesh executable}"

mesh_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$mesh_dir"
GEO_FILE="${GEO_FILE:-$mesh_dir/tgv-3d.geo}"
N="${N:-64}"
MSH_FILE="${MSH_FILE:-$mesh_dir/tgv-3d.msh}"
RAW_XML="${RAW_XML:-$mesh_dir/tgv-3d-raw.xml}"
XML_FILE="${XML_FILE:-$mesh_dir/tgv-3d.xml}"

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
"$mesh_dir/../../scripts/convert_mesh_to_hdf5.sh" "$XML_FILE"

echo
echo "Done: $XML_FILE"
echo "HDF5 pair: ${XML_FILE%.xml}-hdf5.xml and ${XML_FILE%.xml}-hdf5.nekg"
echo "The runner uses mesh/tgv-3d.xml; the default case uses N=64."
echo "Sanity check, e.g.:"
echo "  grep -c '<H ID=' \"$XML_FILE\"   # expect $((N*N*N)) hexahedra"
