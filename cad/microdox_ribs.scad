// microdox_ribs.scad - "Ribs" tenting stand for a Microdox half + interlocking spacers (mm).
//
// Stand (one piece per half): a plate with big soft openings (it replaces the stock 2.0 mm
// bottom plate; the keyboard screws on with its stock bottom screws), carried by three
// "wishbone" ribs, and a desk-level foot bar with two dovetail tongues on its inner face.
// A spacer drops down over the tongues: its blind dovetail sockets rest on the tongues' sloped
// tops (that slope sets the height exactly, whatever the print tolerance), and one M3x10
// button-head screw per tongue, down through the spacer's roof into a heat-set insert, pulls
// the joint tight. Couplers (double tongues) chain spacers together. The joint geometry is the
// same at every tent angle, so any spacer fits any pair of stands.
//
// Ballast keel (OPTIONAL, OFF by default; set keel = true to try it): a round metal rod (steel or brass) runs front to back
// under the keys, through a teardrop "eye" hung from each rib. It slides in from the front and
// stops against the back rib; gravity seats it in the eyes' V, so no glue. It is placed
// automatically as far inboard as screw C's access path allows, clear of the desk.
// Feet: a pad strip along each foot bar plus a pad disc at each outer foot, all in recesses of
// the same depth so the pads come out level.
//
// Parts (-D part="..."), all exported in PRINT orientation, no supports:
//   stand_left, stand_right   plate-down (keyboard face on the bed)
//   spacer                    roof-down; spacer_len = gap between the two stands' foot-bar faces
//   coupler                   flat; joins two spacers end to end (adds coupler_web mm)
//   keel_rod                  preview only: the metal rod in place (not printed)
//   assembly                  preview only (use orientation: both halves + bars + spacer)
//
// Geometry: microdox_ref.scad (v1 outline + drill-map holes; confirm on the v2 board).

include <microdox_ref.scad>

/* ---------- main knobs ---------- */
part        = "assembly";
tent_deg    = 30;       // try 20-35
outer_lift  = 8;        // plate top above desk at the outer (USB) edge
spacer_len  = 40;       // inner-face to inner-face gap between the two stands' foot bars
splay_deg   = 0;        // total splay; positive = tops of the halves lean toward each other

/* ---------- plate (replaces the stock bottom plate) ---------- */
plate_t       = 3.0;
stock_plate_t = 2.0;    // screw seat = stock plate thickness, so the stock screws fit
screw_hole_d  = 2.6;    // M2 clearance (prints ~0.2 small)
seat_d        = 6.5;    // room for the M2 head + driver under each seat
rim           = 5;      // solid border kept round the plate
boss_d        = 14;     // solid land round each screw

/* ---------- ribs ---------- */
rib_t     = 3.2;
rib_ys    = [16, 47, 78];   // between the screw lines (y 3.4 | 29-32 | 90), so every screw is reachable
band      = 5.0;            // rib member width
cap_reach = 3.0;            // foot-bar face sits this far past the plate's inner edge (spacer drops in, screws reachable)

/* ---------- joint ---------- */
joint_h      = 12;          // spacer / coupler / tongue height
bar_w        = 14;          // foot bar width (x); its inner face is at x_face()
tongue_ys    = [25, 69];    // two tongues per stand
tongue_len   = 9;           // how far a tongue sticks out of the foot bar
tongue_neck  = 9;           // width at the bar face
tongue_head  = 13;          // width at the tip (dovetail)
top_slope_min = 30;         // tongue/bar tops slope down toward the other half. One slope for every
top_slope_sum = 50;         //   tent >= 20 (tent + slope >= 50 keeps the print overhang <= 40 deg)
sock_clear   = 0.15;        // dovetail flank clearance per side; the sloped seat pushes the spacer onto the flanks
spacer_h     = joint_h + 3; // spacer roof over the tongues carries the M3 screw heads
spacer_lift  = 1.0;         // spacer underside starts this far up, so it never drags on a soft mat
end_clear    = 0.3;         // gap between a spacer end and a stand's foot-bar face
ins_x        = 5.0;         // insert / screw position along the tongue from the bar face
m3_insert_d  = 4.0;         // heat-set insert hole (check your insert's spec)
m3_insert_len = 5.7;
m3_clear_d   = 3.4;
cbore_d      = 6.4;         // M3 button-head counterbore in the spacer roof
cbore_h      = 2.5;         // (M3x10 then engages the insert fully with room to spare below)
coupler_web  = 4;           // the coupler's centre web length (adds to the chain)

/* ---------- feet (anti-slip pads) ---------- */
foot_d     = 11;            // pod under each outer-rib foot
bump_d     = 9.0;           // outer pad recess: 8-9 mm silicone discs (or 8 mm bumpers)
strip_w    = 10;            // pad strip along each foot bar: cut 10 x 62 mm
pad_recess = 0.5;           // depth of EVERY pad recess; pads stand proud by (pad thickness - this)

/* ---------- ballast keel (round metal rod under the keys) ---------- */
keel        = false;        // true = add the rod eyes (an experiment; off by default)
keel_d      = 0;            // rod diameter; 0 = the largest standard rod that fits this tent
KEEL_SIZES  = [19.05, 15.875, 12.7];   // 3/4, 5/8, 1/2 in (auto picks the first that fits)
keel_len    = 76.2;         // rod length (3 in); it stops against the back rib, front end ~12 mm past the front rib
keel_clear  = 0.3;          // radial clearance in the eyes
keel_wall   = 2.4;          // eye wall
keel_lift   = 2.0;          // nothing but the feet comes closer to the desk plane than this
keel_sill   = 2.0;          // material under the eye's flat tip
keel_margin = 1.0;          // minimum gap between the rod and any screw's access path

/* ---------- keyboard placeholder (preview + checks) ---------- */
standoff_h = 4.0;
cap_top_above_pcb = 18;

$fn = 48;
assert(tent_deg >= 20 && tent_deg <= 35, "tent_deg must be 20..35 (outside that the ribs/joint are not print-checked)");
assert(outer_lift >= 8, "outer_lift must be >= 8 mm (USB plug and outer-foot clearance)");
assert(!keel || k_fits(keel_dia()), str("keel rod ", keel_dia(), " mm does not fit at this tent (try a smaller keel_d, or 0 = auto)"));
assert(!keel || keel_paths_clear(), "keel rod would cross a screw's access path");
if (keel) echo(str("KEEL ROD: ", keel_dia(), " mm dia x ", keel_len, " mm (steel ~", round(PI * pow(keel_dia() / 2, 2) * keel_len * 7.85e-3),
                   " g, brass ~", round(PI * pow(keel_dia() / 2, 2) * keel_len * 8.5e-3), " g)"));
function plate_in_x() = (100.092 + 1.5) * cos(tent_deg) + plate_t * sin(tent_deg);   // plate's inner extent (world x)
function x_face() = plate_in_x() + cap_reach;
function foot_x() = x_face() - bar_w / 2;                       // inner foot (world x) follows the tent angle
function top_slope() = max(top_slope_min, top_slope_sum - tent_deg);
function y_mid() = (tongue_ys[0] + tongue_ys[1]) / 2;

// Keel rod. Screw access paths (access_corridors) run down the plate normal, so in plate
// coordinates (U along the plate, H below its top) each is a band |U - hole_x| <= seat_d/2.
// The rod sits as far inboard (highest plate) as screw C's band allows, and as low as the eye's
// teardrop tip allows. Its eye is a teardrop pointing down-inward (= up when printed plate-down).
function kR(d)    = d / 2 + keel_clear;                                      // eye radius
function k_tip(d) = sqrt(2) * kR(d) - (kR(d) + 0.5);                         // half-width of the eye's flat tip
function k_U(d)   = M2_HOLES[2][0] - seat_d / 2 - kR(d) - keel_margin;
function k_zc(d)  = keel_lift + keel_sill + (kR(d) + 0.5) * cos(tent_deg) + k_tip(d) * sin(tent_deg);
function k_H(d)   = (outer_lift + k_U(d) * sin(tent_deg) - k_zc(d)) / cos(tent_deg);
function k_fits(d) = k_H(d) - kR(d) >= plate_t + 1                            // clears the plate
                  && k_U(d) - kR(d) - keel_margin >= M2_HOLES[0][0] + seat_d / 2;   // and screw A's path
function keel_dia() = keel_d > 0 ? keel_d : let(ok = [for (d = KEEL_SIZES) if (k_fits(d)) d]) len(ok) ? ok[0] : KEEL_SIZES[len(KEEL_SIZES) - 1];
function keel_R() = kR(keel_dia());
function keel_c() = let(d = keel_dia()) [k_U(d) * cos(tent_deg) + k_H(d) * sin(tent_deg), k_zc(d)];   // world [x, z]
function keel_y1() = rib_ys[2];                    // back end: a blind cup half way into the back rib
function keel_y0() = keel_y1() - keel_len;         // front end
function keel_paths_clear() = [for (h = M2_HOLES)
    let(overlap = h[1] + seat_d / 2 + keel_margin > keel_y0() && h[1] - seat_d / 2 - keel_margin < keel_y1())
    !overlap || abs(h[0] - k_U(keel_dia())) >= seat_d / 2 + keel_R() + keel_margin - 1e-6] == [true, true, true, true, true];
function W(U, H) = [U * cos(tent_deg) + H * sin(tent_deg), outer_lift + U * sin(tent_deg) - H * cos(tent_deg)];
function to_UH(x, z) = [x * cos(tent_deg) + (z - outer_lift) * sin(tent_deg), x * sin(tent_deg) - (z - outer_lift) * cos(tent_deg)];
function bez(a, b, c, t) = (1 - t) * (1 - t) * a + 2 * (1 - t) * t * b + t * t * c;
function curve(a, c, b, n = 24) = [for (i = [0 : n]) let(p = bez(a, c, b, i / n)) W(p[0], p[1])];
module stroke(pts, w) for (i = [0 : len(pts) - 2]) hull() { translate(pts[i]) circle(d = w); translate(pts[i + 1]) circle(d = w); }

// Plate frame: origin on the outer edge at plate TOP; z = 0 is where the keyboard's bottom plate was.
module plate_frame() translate([0, 0, outer_lift]) rotate([0, -tent_deg, 0]) children();

/* ================= stand ================= */
module plate2d() difference() {
    offset(r = 1.5) pcb_outline();
    offset(r = 4) offset(delta = -4) difference() {
        offset(delta = -rim) pcb_outline();
        for (h = M2_HOLES) translate(h) circle(d = boss_d);
        translate(CTRL_ZONE[0] - [2, 2]) square(CTRL_ZONE[1] - CTRL_ZONE[0] + [4, 4]);   // battery pad stays solid
        for (y = rib_ys) translate([-5, y - rib_t / 2 - 3]) square([120, rib_t + 6]);
        for (x = [30, 62]) translate([x - 3, -5]) square([6, 110]);                       // two cross ties
    }
    for (h = M2_HOLES) translate(h) circle(d = screw_hole_d);
}
module plate() plate_frame() difference() {
    translate([0, 0, -plate_t]) linear_extrude(plate_t) plate2d();
    for (h = M2_HOLES) translate([h[0], h[1], -plate_t - 1]) cylinder(d = seat_d, h = 1 + plate_t - stock_plate_t);
}

// Rib: two curved branches meeting at the inner foot. Built in plate coordinates (U along the
// plate, H = depth below the plate top = print height); every curve stays >= 45 deg from the plate.
// Every branch is a gently bowed chord kept >= 47 deg from the plate at both ends (print-safe);
// the bow shrinks automatically when the chord itself is steep-limited.
function chord_deg(a, b) = atan2(abs(b[1] - a[1]), abs(b[0] - a[0]));
function bow_k(a, b) = min(0.06, max(0, tan(chord_deg(a, b) - 47) / 2));
function bowed(a, b, sgn) = let(d = b - a, n = [-d[1], d[0]]) (a + b) / 2 + sgn * bow_k(a, b) * n;
module rib2d() offset(r = -4) offset(delta = 4) union() {
    L = 100.1; H0 = plate_t + 2;
    f = to_UH(foot_x(), band / 2);
    leg0 = [L - 3, H0];
    br0  = [f[0] - (f[1] - H0) / tan(58), H0];
    stroke(curve([2, H0], [50, H0], [L - 2, H0]), band);                 // flange under the plate
    stroke(curve(leg0, bowed(leg0, f, -1), f), band);                    // inner leg
    stroke(curve(br0, bowed(br0, f, 1), f), band * 0.8);                 // diagonal branch
    stroke([W(1, plate_t + 1), [3, band / 2]], band);                    // outer foot
    // Keel strut: runs straight down the print (plate normal) and lands exactly on the foot bar's
    // outer-top edge, which is the bar's first printed layer; between ribs the bar is a short bridge.
    k = [x_face() - bar_w, bar_top(x_face() - bar_w)];
    kUH = to_UH(k[0], k[1]);
    stroke([W(kUH[0], H0), k], band * 0.8);
    // Keel eye: a ring round the rod, pointed toward the plate (45 deg flanks, prints without
    // support) and hung from the flange by a stem up the plate normal. The eye's hole is cut in 3D
    // after this outline is rounded. Its underside stops at keel_lift, clear of the desk.
    if (keel) {
        c = keel_c(); Ro = keel_R() + keel_wall;
        pn = [-sin(tent_deg), cos(tent_deg)];                   // plate normal (toward the plate)
        intersection() {
            hull() { translate(c) circle(r = Ro); translate(c + pn * Ro * sqrt(2)) circle(r = 0.01); }
            translate([-50, keel_lift]) square([300, 200]);
        }
        kk = to_UH(c[0], c[1]);
        stroke([W(kk[0], H0), c], band);
    }
}
module ribs() for (y = rib_ys) translate([0, y + rib_t / 2, 0]) rotate([90, 0, 0]) linear_extrude(rib_t) rib2d();

// Foot bar: desk-level beam joining the inner feet. Its top slopes down toward the other half
// (top_slope) so it prints without supports plate-down; its inner face carries the tongues.
function bar_top(x) = joint_h + (x_face() - x) * tan(top_slope());
module foot_bar() {
    x0 = x_face() - bar_w;
    translate([0, rib_ys[2] + rib_t / 2, 0]) rotate([90, 0, 0])
        linear_extrude(rib_ys[2] - rib_ys[0] + rib_t)
            polygon([[x0, 0], [x_face(), 0], [x_face(), joint_h], [x0, bar_top(x0)]]);
}

// Dovetail tongue footprint (neck on the bar face at x = 0, head at x = tongue_len).
module tongue2d(c = 0) offset(delta = c) polygon([[-2, -tongue_neck / 2], [0, -tongue_neck / 2],
    [tongue_len, -tongue_head / 2], [tongue_len, tongue_head / 2], [0, tongue_neck / 2], [-2, tongue_neck / 2]]);
module tongue3d(h, c = 0) linear_extrude(h) tongue2d(c);     // straight flanks, true dovetail neck
// Insert seat: a small flat spot-face below the sloped top, so the insert never stands proud of
// the seat plane the spacer rests on.
function insert_top() = joint_h - (ins_x + (m3_insert_d + 1.6) / 2) * tan(top_slope()) - 0.1;
module insert_cut() translate([ins_x, 0, 0]) {
    translate([0, 0, insert_top() - m3_insert_len - 0.3]) cylinder(d = m3_insert_d, h = 20);
    translate([0, 0, insert_top()]) cylinder(d = m3_insert_d + 1.6, h = 20);
    translate([0, 0, 1.2]) cylinder(d = m3_clear_d - 0.4, h = 20);
}
module sloped_tongue() difference() {
    tongue3d(joint_h);
    translate([0, -20, joint_h]) rotate([0, top_slope(), 0]) cube([40, 40, 20]);   // seat plane
    insert_cut();
}
module tongues() for (ty = tongue_ys) translate([x_face(), ty, 0]) sloped_tongue();

module foot_pods() for (y = [rib_ys[0], rib_ys[2]]) for (x = [7, foot_x()])
    hull() {
        translate([x, y, 0]) cylinder(d = foot_d, h = 2);
        translate([x - 3.5, y - rib_t / 2, 0]) cube([7, rib_t, 8]);
    }
// Pad recesses, all pad_recess deep: a disc at each outer foot, a strip along each foot bar.
module pad_recesses() {
    for (y = [rib_ys[0], rib_ys[2]]) translate([7, y, -1]) cylinder(d = bump_d, h = pad_recess + 1);
    hull() for (y = [rib_ys[0], rib_ys[2]]) translate([foot_x(), y, -1]) cylinder(d = strip_w, h = pad_recess + 1);
}

// Keel: the rod (use orientation) and its eye bore: a teardrop whose tip points down-inward
// (straight up when printed plate-down) with a short flat tip (a <8 mm bridge). The rod rests in
// the teardrop's V. The bore runs from in front of the front rib to half way into the back rib.
module keel_bore2d() let(R = keel_R(), w = k_tip(keel_dia()))
    translate(keel_c()) rotate(tent_deg - 180)
        hull() { circle(r = R, $fn = 64); for (s = [-1, 1]) translate([s * w, R + 0.5]) square(0.01, center = true); }
module keel_rod() if (keel)
    translate([0, keel_y1(), 0]) rotate([90, 0, 0]) linear_extrude(keel_len) translate(keel_c()) circle(d = keel_dia(), $fn = 64);
module keel_bore() if (keel)
    translate([0, keel_y1(), 0]) rotate([90, 0, 0]) linear_extrude(keel_len + 10) keel_bore2d();

// A clear corridor along every screw axis, below the seat, through anything in the way
// (at steep tents the foot bar crosses screw C's path). Vertical holes when printed plate-down.
module access_corridors() plate_frame() for (h = M2_HOLES)
    translate([h[0], h[1], -stock_plate_t - 0.01]) mirror([0, 0, 1]) cylinder(d = seat_d, h = 300);

module stand_left() difference() {
    union() { plate(); ribs(); foot_bar(); tongues(); foot_pods(); }
    access_corridors();
    pad_recesses();
    keel_bore();
    // nothing may rise above the bottom-plate plane (the keyboard sits there)
    plate_frame() translate([-50, -50, 0]) cube([300, 300, 100]);
}
module stand_right() mirror([1, 0, 0]) stand_left();

// Print orientation: rotate so the plate top faces the bed.
module print_orient() translate([0, 0, 0]) rotate([0, 180 + tent_deg, 0]) translate([0, 0, -outer_lift]) children();

/* ================= spacer system ================= */
// Spacer local frame: x = 0 at the LEFT stand's foot-bar face; tongues come in from both ends.
function r_pivot() = [spacer_len, y_mid()];
module at_right_end() translate([r_pivot()[0], r_pivot()[1], 0]) rotate([0, 0, splay_deg])
                     translate([-r_pivot()[0], -r_pivot()[1], 0]) children();
function min_spacer_len() = 2 * (tongue_len + 4) + (tongue_ys[1] - tongue_ys[0] + tongue_head) / 2 * sin(abs(splay_deg));

// Spacer outline (2D): two end pads joined by a waist, with soft fillets everywhere ("bone").
function pad_w() = tongue_ys[1] - tongue_ys[0] + tongue_head + 12;
module end_pad2d(x0, dir) {
    translate([dir > 0 ? x0 + end_clear : x0 - end_clear - (tongue_len + 5), y_mid() - pad_w() / 2])
        offset(r = 4) offset(delta = -4) square([tongue_len + 5, pad_w()]);
}
module spacer2d() offset(r = -6) offset(delta = 6) union() {
    end_pad2d(0, 1);
    at_right_end() end_pad2d(spacer_len, -1);
    hull() {
        translate([tongue_len + 4, y_mid() - 15]) square([0.01, 30]);
        at_right_end() translate([spacer_len - tongue_len - 4, y_mid() - 15]) square([0.01, 30]);
    }
}
module sockets_at(x0, dir) for (ty = tongue_ys)
    translate([x0, ty, 0]) mirror([dir > 0 ? 0 : 1, 0, 0]) {
        intersection() {       // blind socket: its ceiling IS the tongue's sloped top (seat datum)
            translate([0, 0, -1]) tongue3d(joint_h + 1 + 0.01, sock_clear);   // hull, same as the tongue
            translate([0, -20, joint_h]) rotate([0, top_slope(), 0]) translate([-10, 0, -60]) cube([70, 40, 60]);
        }
        translate([ins_x, 0, -1]) cylinder(d = m3_clear_d, h = 40);                     // M3 through the roof
        translate([ins_x, 0, spacer_h - cbore_h]) cylinder(d = cbore_d, h = 10);       // button-head counterbore
    }
module spacer_use() {
    assert(spacer_len >= min_spacer_len(), str("spacer_len must be >= ", min_spacer_len(), " mm at this splay"));
    difference() {
        translate([0, 0, spacer_lift]) linear_extrude(spacer_h - spacer_lift) spacer2d();
        sockets_at(0, 1);
        at_right_end() sockets_at(spacer_len, -1);
        if (spacer_len > 2 * tongue_len + 34)     // long spacers get a window
            hull() for (x = [tongue_len + 16, spacer_len - tongue_len - 16]) translate([x, y_mid(), -1]) cylinder(d = 14, h = spacer_h + 2);
    }
}
// Coupler: two pairs of tongues back to back on a web; chains spacer + spacer.
module coupler_use() {
    difference() {
        union() {
            translate([-coupler_web / 2, y_mid() - (tongue_ys[1] - tongue_ys[0] + tongue_head + 4) / 2, 0])
                cube([coupler_web, tongue_ys[1] - tongue_ys[0] + tongue_head + 4, joint_h]);
            for (ty = tongue_ys) for (s = [-1, 1]) translate([s * coupler_web / 2, ty, 0]) mirror([s > 0 ? 0 : 1, 0, 0]) sloped_tongue();
        }
    }
}
/* ================= test prints (print these first) ================= */
// Fit plate: just the stand's plate (same outline, holes, 2.0 mm screw seats, battery pad), keyboard
// face on the bed exactly like the stand. Screw your board onto it with the stock screws to prove
// the v2 hole pattern, outline, screw length and battery/switch clearance before a 4 h print.
// (A rotation, not a mirror: a mirrored plate would be the RIGHT half's. This is the LEFT half's,
// exactly as it prints on the stand.)
module fit_plate() rotate([0, 180, 0]) difference() {
    translate([0, 0, -plate_t]) linear_extrude(plate_t) plate2d();
    for (h = M2_HOLES) translate([h[0], h[1], -plate_t - 1]) cylinder(d = seat_d, h = 1 + plate_t - stock_plate_t);
}
// Joint test: one tongue on a short block of foot bar (desk face on the bed), and one spacer end
// with its socket (roof on the bed, like the real spacer). Checks the dovetail fit, the heat-set
// insert and the M3x10 clamp.
jt_half = 12;       // half-length of the test pieces along y
module joint_test_tongue() {
    translate([-10, -jt_half, 0]) cube([10, 2 * jt_half, joint_h]);
    sloped_tongue();
}
module jt_socket_use() intersection() {           // socket piece in use position over the tongue
    translate([0, -tongue_ys[0], 0]) spacer_use();
    translate([-1, -jt_half, -1]) cube([tongue_len + 8, 2 * jt_half, spacer_h + 2]);
}
module joint_test_socket() translate([0, 0, spacer_h]) mirror([0, 0, 1]) jt_socket_use();   // roof on the bed

/* ================= assembly (use orientation) ================= */
module keyboard_placeholder() plate_frame() {
    color([0.22, 0.24, 0.27]) translate([0, 0, standoff_h]) linear_extrude(1.6) pcb_outline();
    color([0.93, 0.92, 0.88]) translate([0, 0, standoff_h + 1.6 + 6]) linear_extrude(cap_top_above_pcb - 6)
        keycap_keepout_2d(extra = -0.5);
}
module right_side_placement() translate([x_face(), 0, 0]) at_right_end()
    translate([spacer_len + x_face(), 0, 0]) mirror([1, 0, 0]) children();
module spacer_placed() translate([x_face(), 0, 0]) spacer_use();

if (part == "stand_left")  print_orient() stand_left();
if (part == "stand_right") mirror([1, 0, 0]) print_orient() stand_left();   // mirror image prints the same way
if (part == "spacer")      translate([0, 0, spacer_h]) mirror([0, 0, 1]) spacer_use();   // roof on the bed
if (part == "coupler")     coupler_use();
if (part == "fit_plate")         fit_plate();
if (part == "joint_test_tongue") joint_test_tongue();
if (part == "joint_test_socket") joint_test_socket();
if (part == "joint_test_fit")    { joint_test_tongue(); color([0.98, 0.72, 0.40]) jt_socket_use(); }   // preview
// use-orientation helpers for checks / renders
if (part == "stand_use")          stand_left();
if (part == "stand_right_placed") right_side_placement() stand_left();
if (part == "spacer_placed")      spacer_placed();
if (part == "keyboard_left")      keyboard_placeholder();
if (part == "keel_rod")           keel_rod();
if (part == "keyboard_right")     right_side_placement() keyboard_placeholder();
if (part == "assembly") {
    color([0.95, 0.47, 0.32]) stand_left();
    keyboard_placeholder();
    color([0.95, 0.47, 0.32]) right_side_placement() stand_left();
    right_side_placement() keyboard_placeholder();
    color([0.80, 0.63, 0.30]) { keel_rod(); right_side_placement() keel_rod(); }
    color([0.98, 0.72, 0.40]) spacer_placed();
}
