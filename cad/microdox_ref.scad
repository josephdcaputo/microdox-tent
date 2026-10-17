// microdox_ref.scad - Microdox LEFT-half reference geometry (mm). Use with include<>.
// Generated from microdox_ref.json. Frame: top view, origin = PCB outline bbox corner,
// +x = inner (thumb / TRRS) edge. No DXF import needed: avoids OpenSCAD's 5-sided
// circle import that makes M2 holes too small.
// GEOMETRY IS FROM v1 FILES. The target board is Microdox v2 (wireless build, no TRRS cable).
// v1 outline/holes are a hypothesis for v2 until the paper template / fit slice confirms them.
// Values tagged MEASURE are inferred; check on the real board.

/* ---------- FDM + stack parameters (override after include) ---------- */
pcb_clear    = 0.5;   // per side, PCB/plate to wall
wall_t       = 2.5;
floor_t      = 1.5;   // MEASURE: >= 2.5 if you recess screw heads or feet
pcb_bottom_z = 4.4;   // MEASURE: floor + standoff; must clear hotswap sockets/solder tails
pcb_t        = 1.6;   // MEASURE
plate_rise   = 5.0;   // PCB top -> switch plate top. MX = 5.0; Choc is different: MEASURE
plate_t      = 1.5;
m2_clear_d   = 2.4;   // printed M2 clearance hole (2.2 prints undersize)
m2_insert_d  = 3.2;   // heat-set insert hole: use the insert maker's spec
boss_d       = 6.0;
hole_fn      = 48;

/* ---------- build options (wireless v2) ---------- */
trrs_jack_installed = true;  // set false only if the jack is NOT soldered on (it sticks out past the PCB edge)
encoders_installed  = false; // v2 optional EC11: position/height unknown -> MEASURE before enabling
// Battery + power-switch mods: user-measured envelope per half, in this frame. [x, y, w, d, h_below_pcb]
// Leave empty until measured; anything listed here is kept clear by the modelling agent.
MODS_ENVELOPES = [];
function pcb_top_z()  = pcb_bottom_z + pcb_t;
function wall_top_z() = pcb_top_z() + plate_rise;

/* ---------- 2D data ---------- */
PCB_OUTLINE = [[0.000, 85.049], [0.005, 7.381], [0.029, 7.143], [0.097, 6.921], [0.206, 6.716], [0.355, 6.535], [0.536, 6.386], [0.741, 6.277], [0.964, 6.209], [1.187, 6.187], [40.089, 6.191], [90.372, 0.023], [90.795, 0.000], [91.271, 0.054], [91.725, 0.185], [92.150, 0.387], [92.536, 0.655], [92.875, 0.985], [93.159, 1.371], [93.377, 1.806], [100.092, 14.065], [100.092, 20.065], [96.150, 39.211], [96.150, 87.435], [96.126, 87.670], [96.056, 87.893], [95.947, 88.096], [95.801, 88.272], [95.625, 88.417], [95.423, 88.527], [95.199, 88.596], [94.952, 88.622], [88.504, 88.622], [82.130, 93.384], [20.053, 93.384], [19.805, 93.359], [19.582, 93.289], [19.380, 93.180], [19.204, 93.034], [19.058, 92.858], [18.948, 92.656], [18.879, 92.432], [18.852, 92.183], [18.855, 87.430], [18.832, 87.199], [18.764, 86.974], [18.653, 86.767], [18.504, 86.586], [18.325, 86.439], [18.120, 86.330], [17.897, 86.262], [17.664, 86.239], [1.200, 86.242], [0.951, 86.215], [0.727, 86.146], [0.525, 86.036], [0.349, 85.890], [0.203, 85.714], [0.094, 85.512], [0.024, 85.289]];
M2_HOLES    = [[14.204, 29.079], [21.595, 90.598], [57.656, 31.729], [81.354, 89.928], [85.844, 3.378]];
SWITCHES    = [[48.023, 83.872, 0.0], [9.924, 76.728, 0.0], [28.973, 81.491, 0.0], [67.072, 81.491, -0.0], [86.121, 79.109, 0.0], [9.924, 57.679, 0.0], [28.973, 62.441, 0.0], [48.023, 64.822, 0.0], [67.072, 62.441, 0.0], [86.121, 60.060, 0.0], [9.924, 38.630, 0.0], [28.973, 43.392, 0.0], [48.023, 45.773, 0.0], [67.072, 43.392, -0.0], [86.121, 41.011, 0.0], [47.172, 19.167, 0.0], [68.493, 16.513, -15.0], [89.733, 13.082, -28.5]];  // x, y, rot_deg
USB_Y       = [11.5, 24.75];   // outer-edge slot (x = 0 side). Centre uncertain 16.4..18.1: MEASURE
TRRS_Y      = [24.85, 31.7];   // inner-edge slot. Jack centreline y = 28.3
INNER_PIVOT = [98.396, 28.3];  // PCB inner edge at y = 28.3 (TRRS centreline); placement pivot
CTRL_ZONE   = [[0, 6.19], [38.4, 27.02]];   // controller + OLED footprint
KEYCAP      = 18.0;

module pcb_outline()  { polygon(PCB_OUTLINE); }
module pcb_pocket()   { offset(delta = pcb_clear) pcb_outline(); }
module tray_outline() { offset(r = pcb_clear + wall_t) pcb_outline(); }
module mount_holes_2d(d = m2_clear_d) {
    for (h = M2_HOLES) translate(h) circle(d = d, $fn = hole_fn);
}
// Nothing taller than the switch-plate top may enter this footprint (keycaps travel here).
module keycap_keepout_2d(extra = 0.5) {
    for (s = SWITCHES) translate([s[0], s[1]]) rotate(s[2]) square(KEYCAP + 2*extra, center = true);
}
module ctrl_zone_2d() { translate(CTRL_ZONE[0]) square(CTRL_ZONE[1] - CTRL_ZONE[0]); }

// Wall slots as 3D cutters, tops open. USB (needed on BOTH halves for charging) is cut down
// to the PCB bottom because v2 mounts both controllers face down. Use trrs_slot_cut() only
// when trrs_jack_installed. Slot positions are v1: MEASURE on v2.
module usb_slot_cut(floor_z = pcb_bottom_z) {
    translate([-(pcb_clear + wall_t) - 1, USB_Y[0], floor_z])
        cube([pcb_clear + wall_t + 2, USB_Y[1] - USB_Y[0], 50]);
}
module trrs_slot_cut(floor_z = pcb_top_z() - 0.5) {
    translate([INNER_PIVOT[0] - 3, TRRS_Y[0], floor_z]) cube([12, TRRS_Y[1] - TRRS_Y[0], 50]);
}

/* ---------- Unibody placement ----------
   Left half: rotate by -splay/2 about INNER_PIVOT, then move the pivot to (-edge_gap/2, 0).
   Right half: mirror([1,0,0]) of the left. Inner edges face each other across x = 0,
   USB ports stay on the outer ends. Positive splay = tops lean inward.
   edge_gap = distance between the two PCB inner edges at y = 28.3.
   Check any (splay, edge_gap) with check_layout.py before modelling the bridge.        */
module place_half(side, splay_deg, edge_gap) {
    module L() translate([-edge_gap/2, 0, 0]) rotate(-splay_deg/2)
               translate([-INNER_PIVOT[0], -INNER_PIVOT[1], 0]) children();
    if (side == "left") L() children(); else mirror([1, 0, 0]) L() children();
}

/* ---------- demo: openscad -D demo=true -o demo.png microdox_ref.scad ---------- */
demo = false;
if (demo) for (s = ["left", "right"]) place_half(s, 15, 40) {
    color("tan") linear_extrude(1) difference() { tray_outline(); mount_holes_2d(); }
    color("steelblue") translate([0, 0, 1]) linear_extrude(0.5) pcb_outline();
    color("red", 0.4) translate([0, 0, 1.5]) linear_extrude(0.2) keycap_keepout_2d();
}
