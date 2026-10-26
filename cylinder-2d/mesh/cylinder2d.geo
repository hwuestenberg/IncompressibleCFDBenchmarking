// Cylinder 2D, Re=100: transfinite quadrilateral mesh.
// Physical IDs match session-legacy.xml and session-redesign.xml.

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

Physical Surface(1) = {1, 2, 3, 4, 5, 6, 7, 8}; // Fluid
Physical Curve(2) = {19, 20}; // Inflow
Physical Curve(3) = {23, 24}; // Outflow
Physical Curve(4) = {1, 2}; // Bottom
Physical Curve(5) = {3, 4}; // Top
Physical Curve(6) = {25, 26, 27, 28, 29, 30}; // Cylinder
