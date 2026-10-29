#!/usr/bin/env bash
# Build the 3D channel mesh and pair periodic faces.

set -euo pipefail

: "${GMSH_BIN:?Set GMSH_BIN to the path of the gmsh executable}"
: "${NEKMESH_BIN:?Set NEKMESH_BIN to the path of the NekMesh executable}"

mesh_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$mesh_dir"
GEO_FILE="${GEO_FILE:-$mesh_dir/channel-3d.geo}"
MSH_FILE="${MSH_FILE:-$mesh_dir/channel-3d.msh}"
RAW_XML="${RAW_XML:-$mesh_dir/channel-3d-raw.xml}"
XML_FILE="${XML_FILE:-$mesh_dir/channel-3d.xml}"

echo "Meshing $GEO_FILE -> $MSH_FILE"
"$GMSH_BIN" -3 -nopopup "$GEO_FILE" -o "$MSH_FILE"

echo "Converting $MSH_FILE -> $RAW_XML"
"$NEKMESH_BIN" "$MSH_FILE" "$RAW_XML:xml:uncompress"

echo "Pairing streamwise (x) and spanwise (z) faces as periodic -> $XML_FILE"
"$NEKMESH_BIN" \
    -m peralign:surf1=1:surf2=2:dir=x \
    -m peralign:surf1=3:surf2=4:dir=z \
    "$RAW_XML" "$XML_FILE:xml:uncompress"
"$mesh_dir/../../scripts/convert_mesh_to_hdf5.sh" "$XML_FILE"

echo
echo "Done: $XML_FILE"
echo "HDF5 pair: ${XML_FILE%.xml}-hdf5.xml and ${XML_FILE%.xml}-hdf5.nekg"
echo "Sanity check, e.g.:"
echo "  grep -c '<H ID=' \"$XML_FILE\"   # expect 1078 hexahedra"
