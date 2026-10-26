// 3D cylinder mesh for the Re=300 redesign-validation benchmark: the 2D
// dongCylinderFine geometry (basic/meshes/2d/dongCylinderFine.geo),
// extruded natively in gmsh along the spanwise (z) direction, instead of
// via NekMesh's extrude+peralign post-processing on an already-built 2D
// mesh. Physical Volume/Surface tags below become Nektar++ composite IDs
// directly on conversion (NekMesh InputGmsh), matching the IDs already
// used in *-session.xml.

// Override from the command line with, e.g.:
//   gmsh -3 -setnumber Lz 6.0 -setnumber nLayers 48 mesh/cylinder3d.geo -o mesh/cylinder-3d.msh
If (!Exists(Lz))
    Lz = 4.0;
EndIf
If (!Exists(nLayers))
    nLayers = 40;
EndIf

// ---- 2D base geometry (verbatim from dongCylinderFine.geo) ----

// Outer box
Point(1) = {-10, -10, 0, 1.0};
Point(2) = {10, -10, 0, 1.0};
Point(3) = {40, -10, 0, 1.0};
Point(4) = {-10, 10, -0, 1.0};
Point(5) = {10, 10, -0, 1.0};
Point(6) = {40, 10, -0, 1.0};

// Cylinder
Point(7) = {-0.353553391, -0.353553391, 0, 1.0};
Point(8) = {0.353553391, -0.353553391, 0, 1.0};
Point(10) = {-0.353553391, 0.353553391, 0, 1.0};
Point(9) = {0.353553391, 0.353553391, 0, 1.0};
Point(11) = {0, 0, 0, 1.0};

// Center line
Point(12) = {-10, 0, 0, 1.0};
Point(13) = {10, 0, 0, 1.0};
Point(14) = {40, 0, 0, 1.0};
Point(15) = {-0.5, 0, 0, 1.0};
Point(16) = {0.5, 0, 0, 1.0};

// Outer box
Line(1) = {1, 2}; Transfinite Curve {1} = 19 Using Progression 1;
Line(2) = {2, 3}; Transfinite Curve {2} = 27 Using Progression 1;
Line(3) = {4, 5}; Transfinite Curve {3} = 19 Using Progression 1;
Line(4) = {5, 6}; Transfinite Curve {4} = 27 Using Progression 1;

// Diagonal lines
Line(12) = {1, 7}; Transfinite Curve {12}  = 19 Using Progression 0.9;
Line(13) = {2, 8}; Transfinite Curve {13}  = 19 Using Progression 0.9;
Line(14) = {5, 9}; Transfinite Curve {14}  = 19 Using Progression 0.9;
Line(15) = {4, 10}; Transfinite Curve {15} = 19 Using Progression 0.9;

// Center lines
Line(16) = {12, 15}; Transfinite Curve {16} = 19 Using Progression 0.9;
Line(17) = {16, 13}; Transfinite Curve {17} = 19 Using Progression 1/0.9;
Line(18) = {13, 14}; Transfinite Curve {18} = 27 Using Progression 1;

// Triangles
Line(19) = {4, 12}; Transfinite Curve {19} = 19 Using Progression 1/1.1;
Line(20) = {12, 1}; Transfinite Curve {20} = 19 Using Progression 1.1;
Line(21) = {2, 13}; Transfinite Curve {21} = 19 Using Progression 1/1.1;
Line(22) = {13, 5}; Transfinite Curve {22} = 19 Using Progression 1.1;
Line(23) = {3, 14}; Transfinite Curve {23} = 19 Using Progression 1/1.1;
Line(24) = {14, 6}; Transfinite Curve {24} = 19 Using Progression 1.1;

Circle(25) = {7, 11, 8};  Transfinite Curve {25} = 19 Using Progression 1;
Circle(26) = {8, 11, 16}; Transfinite Curve {26} = 19 Using Progression 1/1.1;
Circle(27) = {16, 11, 9}; Transfinite Curve {27} = 19 Using Progression 1.1;
Circle(28) = {9, 11, 10}; Transfinite Curve {28} = 19 Using Progression 1;
Circle(29) = {10, 11, 15};Transfinite Curve {29} = 19 Using Progression 1/1.1;
Circle(30) = {15, 11, 7}; Transfinite Curve {30} = 19 Using Progression 1.1;

// Surfaces
Curve Loop(1) = {1, 13, -25, -12};
Plane Surface(1) = {1};
Curve Loop(2) = {13, 26, 17, -21};
Plane Surface(2) = {2};
Curve Loop(3) = {17, 22, 14, -27};
Plane Surface(3) = {3};
Curve Loop(4) = {28, -15, 3, 14};
Plane Surface(4) = {4};
Curve Loop(5) = {16, -29, -15, 19};
Plane Surface(5) = {5};
Curve Loop(6) = {12, -30, -16, 20};
Plane Surface(6) = {6};
Curve Loop(7) = {2, 23, -18, -21};
Plane Surface(7) = {7};
Curve Loop(8) = {18, 24, -4, -22};
Plane Surface(8) = {8};

Transfinite Surface {1};
Transfinite Surface {2};
Transfinite Surface {3};
Transfinite Surface {4};
Transfinite Surface {5};
Transfinite Surface {6};
Transfinite Surface {7};
Transfinite Surface {8};

Recombine Surface {1};
Recombine Surface {2};
Recombine Surface {3};
Recombine Surface {4};
Recombine Surface {5};
Recombine Surface {6};
Recombine Surface {7};
Recombine Surface {8};

// ---- Spanwise extrusion ----
// Extrude {0,0,Lz} on all 8 surfaces at once. For each input surface j
// (0-indexed), gmsh appends 6 entries to the output array in order:
//   out[6j+0] = "cap" surface at z=Lz (translated copy of surface j)
//   out[6j+1] = volume
//   out[6j+2..6j+5] = side surfaces, one per curve in that surface's
//                     Curve Loop, in the SAME ORDER as the loop.
out[] = Extrude {0, 0, Lz} {
    Surface{1, 2, 3, 4, 5, 6, 7, 8};
    Layers{nLayers};
    Recombine;
};

// ---- Physical groups (become Nektar++ composite IDs) ----
// IDs match *-session.xml's BOUNDARYREGIONS.
//
// Side-surface index derivation (curve -> physical group, per surface's
// Curve Loop above; internal curves shared between two of the 8 surfaces
// are left untagged and simply become interior faces of the volume):
//   Surface1 {1,13,-25,-12}:   out[2]=curve1  ->Bottom(4)  out[4]=curve25 ->Wall(6)
//   Surface2 {13,26,17,-21}:   out[9]=curve26 ->Wall(6)
//   Surface3 {17,22,14,-27}:   out[17]=curve27->Wall(6)
//   Surface4 {28,-15,3,14}:    out[20]=curve28->Wall(6)   out[22]=curve3  ->Top(5)
//   Surface5 {16,-29,-15,19}:  out[27]=curve29->Wall(6)   out[29]=curve19->Inflow(2)
//   Surface6 {12,-30,-16,20}:  out[33]=curve30->Wall(6)   out[35]=curve20->Inflow(2)
//   Surface7 {2,23,-18,-21}:   out[38]=curve2 ->Bottom(4) out[39]=curve23->Outflow(3)
//   Surface8 {18,24,-4,-22}:   out[45]=curve24->Outflow(3) out[46]=curve4 ->Top(5)
Physical Volume(1) = {out[1], out[7], out[13], out[19], out[25], out[31], out[37], out[43]}; // Domain/Fluid

Physical Surface(2) = {out[29], out[35]}; // Inflow
Physical Surface(3) = {out[39], out[45]}; // Outflow
Physical Surface(4) = {out[2], out[38]}; // Bottom (farfield)
Physical Surface(5) = {out[22], out[46]}; // Top (farfield)
Physical Surface(6) = {out[4], out[9], out[17], out[20], out[27], out[33]}; // Cylinder wall

Physical Surface(7) = {1, 2, 3, 4, 5, 6, 7, 8}; // Spanwise face z=0
Physical Surface(8) = {out[0], out[6], out[12], out[18], out[24], out[30], out[36], out[42]}; // Spanwise face z=Lz
