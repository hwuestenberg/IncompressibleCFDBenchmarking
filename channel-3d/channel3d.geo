// 3D channel mesh. Physical Surface tags identify the boundaries.
// Physical Volume identifies the fluid domain.

Lx = 6;          // Length in x-direction
Ly = 2;          // Width in y-direction
Lz = 3;          // Total height

Nx = 11;         // Number of divisions along length (x)
Nz = 7;          // Number of divisions along width (y)

// Vertical divisions for the two blocks
Ny_lower = 7;    // Number of divisions in lower block (from z=0 to 1)
Ny_upper = 7;    // Number of divisions in upper block (from z=1 to 2)
growthrate = 1.35;  // Progression factor for vertical refinement

// =====================================================
// Define Points
// =====================================================
// Bottom face (y=0)
Point(1) = {0,  0,  0, 1.0};
Point(2) = {Lx, 0,  0, 1.0};
Point(3) = {Lx, 0,  Lz, 1.0};
Point(4) = {0,  0,  Lz, 1.0};

// Top face (y=Ly)
Point(5) = {0,  Ly,  0, 1.0};
Point(6) = {Lx, Ly,  0, 1.0};
Point(7) = {Lx, Ly,  Lz, 1.0};
Point(8) = {0,  Ly,  Lz, 1.0};

// Mid-plane (z=1) -- shared by lower block (top) and upper block (bottom)
Point(9)  = {0,    Ly/2,    0, 1.0};
Point(10) = {Lx,   Ly/2,    0, 1.0};
Point(11) = {Lx,   Ly/2,   Lz, 1.0};
Point(12) = {0,    Ly/2,   Lz, 1.0};

// =====================================================
// Define Lines for Lower Block (z=0 to z=1)
// =====================================================
// Bottom face (z=0) lines of lower block
Line(1) = {1, 2};
Line(2) = {2, 3};
Line(3) = {3, 4};
Line(4) = {4, 1};

// Top face (mid-plane) lines of lower block
Line(5) = {9, 10};
Line(6) = {10, 11};
Line(7) = {11, 12};
Line(8) = {12, 9};

// Vertical edges for lower block (from bottom to mid-plane)
Line(9)  = {1, 9};
Line(10) = {2, 10};
Line(11) = {3, 11};
Line(12) = {4, 12};

// =====================================================
// Define Lines for Upper Block (z=1 to z=2)
// =====================================================
// Bottom face (mid-plane) lines for upper block (reuse points 9-12)
// Top face (z=2) lines of upper block
Line(13) = {5, 6};
Line(14) = {6, 7};
Line(15) = {7, 8};
Line(16) = {8, 5};

// Vertical edges for upper block
// To enforce refinement from the top wall, define these edges from the top towards the mid-plane.
Line(17) = {5, 9};   // from top point 5 to mid-plane point 9
Line(18) = {6, 10};  // from 6 to 10
Line(19) = {7, 11};  // from 7 to 11
Line(20) = {8, 12};  // from 8 to 12

// =====================================================
// Define Surfaces for Lower Block
// =====================================================
// Lower block bottom surface
Line Loop(21) = {1, 2, 3, 4};
Plane Surface(22) = {21};

// Lower block top surface (mid-plane)
Line Loop(23) = {5, 6, 7, 8};
Plane Surface(24) = {23};

// Side surfaces for lower block
Line Loop(25) = {1, 10, -5, -9};
Plane Surface(26) = {25};

Line Loop(27) = {2, 11, -6, -10};
Plane Surface(28) = {27};

Line Loop(29) = {3, 12, -7, -11};
Plane Surface(30) = {29};

Line Loop(31) = {4, 9, -8, -12};
Plane Surface(32) = {31};

// =====================================================
// Define Surfaces for Upper Block
// =====================================================
// Upper block bottom surface (shared mid-plane)
Line Loop(33) = {5, 6, 7, 8};
Plane Surface(34) = {33};

// Upper block top surface (z=2)
Line Loop(35) = {13, 14, 15, 16};
Plane Surface(36) = {35};

// Side surfaces for upper block
// Note: reverse the orientation of the vertical edges so that the progression is applied from the top.
Line Loop(37) = {13, -17, -5, 18};
Plane Surface(38) = {37};

Line Loop(39) = {14, -18, -6, 19};
Plane Surface(40) = {39};

Line Loop(41) = {15, -19, -7, 20};
Plane Surface(42) = {41};

Line Loop(43) = {16, -20, -8, 17};
Plane Surface(44) = {43};

// =====================================================
// Define Volume Blocks
// =====================================================
// Lower block volume
Surface Loop(45) = {22, 24, 26, 28, 30, 32};
Volume(46) = {45};

// Upper block volume
Surface Loop(47) = {34, 36, 38, 40, 42, 44};
Volume(48) = {47};

// =====================================================
// Mesh Transfinite Settings
// =====================================================
// --- Horizontal edges ---
// Bottom and top surfaces for lower block:
Transfinite Line {1, 3, 5, 7} = Nx + 1;
Transfinite Line {2, 4, 6, 8} = Nz + 1;

// Bottom and top surfaces for upper block (using same divisions):
Transfinite Line {13, 15} = Nx + 1;
Transfinite Line {14, 16} = Nz + 1;

// --- Vertical edges with progression ---
// Lower block vertical edges (from z = 0 to z = 1) : refinement starting from the bottom
Transfinite Line {9, 10, 11, 12} = Ny_lower + 1 Using Progression growthrate;

// Upper block vertical edges (defined from top to mid-plane so that the refinement occurs from the top)
Transfinite Line {17, 18, 19, 20} = Ny_upper + 1 Using Progression growthrate;

// --- Surfaces and Volumes ---
// Lower block surfaces
Transfinite Surface {22, 24, 26, 28, 30, 32};
Recombine Surface {22, 24, 26, 28, 30, 32};

// Upper block surfaces
Transfinite Surface {34, 36, 38, 40, 42, 44};
Recombine Surface {34, 36, 38, 40, 42, 44};

// Apply transfinite meshing to volumes (each block)
Transfinite Volume {46};
Recombine Volume {46};

Transfinite Volume {48};
Recombine Volume {48};

// =====================================================
// Physical Groups (Optional)
// =====================================================
// You may define physical groups for boundary conditions.
// For example, here we group the refined walls (bottom and top) and the entire fluid domain.

// Inflow
Physical Surface("Inflow") = {44,32};
// Outflow
Physical Surface("Outflow") = {40,28};

// Left
Physical Surface("Left") = {26,38};
// Right
Physical Surface("Right") = {42,30};

// Lower block: bottom wall
Physical Surface("Bottom") = {22};
// Upper block: top wall
Physical Surface("Top") = {36};
// Inlet and outlet or side walls can be grouped similarly.
// Entire fluid domain as union of both volumes
Physical Volume("Fluid") = {46, 48};

