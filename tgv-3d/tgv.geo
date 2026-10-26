// Triply periodic Taylor-Green vortex mesh. N sets elements per direction.

If (!Exists(N))
    N = 64;
EndIf

Point(1) = {0, 0, 0, 1};
Point(2) = {2*Pi, 0, 0, 1};
Point(3) = {2*Pi, 2*Pi, 0, 1};
Point(4) = {0, 2*Pi, 0, 1};

Line(1) = {1, 2};
Line(2) = {2, 3};
Line(3) = {3, 4};
Line(4) = {4, 1};

Line Loop(1) = {1, 2, 3, 4};
Plane Surface(1) = {1};

// Structured mesh: N+1 points per edge -> N elements per direction.
Transfinite Curve(1) = N + 1;
Transfinite Curve(2) = N + 1;
Transfinite Curve(3) = N + 1;
Transfinite Curve(4) = N + 1;
Transfinite Surface(1) = {1, 2, 3, 4};
Recombine Surface{1};

// Extend to 3D.
surfaceVector[] = Extrude {0, 0, 2*Pi} {
    Surface{1};
    Layers{N};
    Recombine;
};

// Same physical-surface ordering/naming as the case-tree precedent
// (2pihex-99.geo) -- composite IDs become, in order of first appearance:
// 1=front(z=2*Pi) 2=bottom(y=0) 3=right(x=2*Pi) 4=top(y=2*Pi)
// 5=left(x=0) 6=back(z=0), Physical Volume 7=fluid. This exactly matches
// the peralign pairing build_mesh.sh uses (surf1=1:surf2=6:dir=z,
// surf1=5:surf2=3:dir=x, surf1=2:surf2=4:dir=y) and *-session.xml's
// BOUNDARYREGIONS.
Physical Surface("front")  = surfaceVector[0];
Physical Surface("bottom") = surfaceVector[2];
Physical Surface("right")  = surfaceVector[3];
Physical Surface("top")    = surfaceVector[4];
Physical Surface("left")   = surfaceVector[5];
Physical Surface("back")   = {1};
Physical Volume("internal") = surfaceVector[1];
