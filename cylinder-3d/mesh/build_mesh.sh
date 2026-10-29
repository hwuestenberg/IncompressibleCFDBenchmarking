#!/usr/bin/env bash
#
# Build the 3D cylinder mesh for the Re=300 redesign-validation benchmark
# directly from cylinder-3d.geo (a standalone gmsh source: the 2D
# dongCylinderFine geometry, extruded natively in gmsh along the spanwise
# direction with Physical Volume/Surface tags already assigned -- no
# NekMesh extrude/peralign post-processing needed, and no composite-ID
# guesswork: the physical tags were verified against the mesh's own
# geometry with gmsh's Python API when cylinder-3d.geo was written (see
# comments in that file), and match *-session.xml's
# BOUNDARYREGIONS directly:
#   C[1]=domain  C[2]=inflow    C[3]=outflow  C[4]=bottom(farfield)
#   C[5]=top(farfield)  C[6]=cylinder wall
#   C[7]=spanwise face z=0      C[8]=spanwise face z=Lz
#
# Requires:
#   GMSH_BIN    path to the gmsh executable
#   NEKMESH_BIN path to the NekMesh executable (see scripts/env.sh.example)
#
# Usage:
#   ./mesh/build_mesh.sh                       # defaults: Lz=4.0, 40 layers
#   LZ=6.0 LAYERS=48 ./mesh/build_mesh.sh       # override spanwise length/layers

set -euo pipefail

: "${GMSH_BIN:?Set GMSH_BIN to the path of the gmsh executable}"
: "${NEKMESH_BIN:?Set NEKMESH_BIN to the path of the NekMesh executable}"

mesh_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$mesh_dir"
GEO_FILE="${GEO_FILE:-$mesh_dir/cylinder-3d.geo}"
MSH_FILE="${MSH_FILE:-$mesh_dir/cylinder-3d.msh}"
XML_FILE="${XML_FILE:-$mesh_dir/cylinder-3d.xml}"
LZ="${LZ:-4.0}"
LAYERS="${LAYERS:-40}"

echo "Meshing $GEO_FILE -> $MSH_FILE (Lz=$LZ, layers=$LAYERS)"
"$GMSH_BIN" -3 -setnumber Lz "$LZ" -setnumber nLayers "$LAYERS" \
    -nopopup "$GEO_FILE" -o "$MSH_FILE"

echo "Converting $MSH_FILE -> $XML_FILE"
"$NEKMESH_BIN" "$MSH_FILE" "$XML_FILE:xml:uncompress"
"$mesh_dir/../../scripts/convert_mesh_to_hdf5.sh" "$XML_FILE"

echo
echo "Done: $XML_FILE"
echo "HDF5 pair: ${XML_FILE%.xml}-hdf5.xml and ${XML_FILE%.xml}-hdf5.nekg"
echo "If LZ was overridden from the default 4.0, update the Lz PARAMETER"
echo "in session-redesign.xml / session-legacy.xml to match (it controls"
echo "the initial-condition perturbation wavelength, not the mesh)."
echo "Sanity check, e.g.:"
echo "  grep -c '<H ID=' \"$XML_FILE\"   # expect 2880 * $LAYERS hexahedra"
