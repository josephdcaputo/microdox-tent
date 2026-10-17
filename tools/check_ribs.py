#!/usr/bin/env python3
"""Build and check the Microdox "Ribs" stand + interlocking spacer system (OpenSCAD + trimesh).

Usage:
  python3 check_ribs.py --tent 20 25 30 35 [--spacer-len 40] [--splay 0] [--lift 8]
                        [--chain 40 60] [--bed 220 220]

Design constants are read from microdox_ribs.scad itself, so the checks follow any edit.
Checks per tent angle (use orientation unless noted):
  stand   one watertight body; nothing above the bottom-plate plane; every screw seat is the
          stock plate thickness (probed all round); a clear straight path along every screw
          axis for the screw head + driver (r = 2 mm), nothing in the way to infinity;
          USB plug (right-angle cable) clears the desk; bed fit
  print   every part in its print orientation: nothing starts in mid-air (layer-by-layer island
          test), and no overhang patch > 50 deg bigger than a short bridge (30 mm^2 / 8 mm across)
  joint   spacer seated on the tongues' sloped tops: zero interference at nominal, and contact
          when lowered 0.1 mm (the slope, not print tolerance, sets the height); every screw axis
          passes the spacer roof and lands on the insert-hole floor; M3x10 engagement; a straight
          tool path from above each screw (hex key / driver)
  whole   zero 3D interference between every pair of placed parts (both stands, spacer,
          keyboard placeholders), with splay applied
  chain   (--chain A B) spacer A + coupler + spacer B: zero interference, screws line up
  keel    the metal rod: clear of every screw's access path; zero interference in its eyes, and
          it rests on the eyes' V (lowering it collides) and against the back rib (pushing it
          back collides); a clear straight path to slide it in; nothing but the feet comes
          within keel_lift of the desk
  feet    every pad recess floor at the same depth, so pads come out level
  (keel checks run only when keel = true in the .scad, or with --keel / --keel-d D; --no-keel forces
   them off. The rod is an optional experiment and is off by default.)
Needs: openscad, pip install trimesh numpy shapely rtree
"""
import argparse, json, math, os, re, subprocess, tempfile, warnings
import numpy as np
import trimesh
warnings.filterwarnings("ignore", category=RuntimeWarning)

HERE = os.path.dirname(os.path.abspath(__file__))
CAD = os.path.join(HERE, "..", "cad")
SCAD = os.path.join(CAD, "microdox_ribs.scad")
REF = json.load(open(os.path.join(CAD, "microdox_ref.json")))
HOLES = REF["mount_holes"]["centers"]
USB_Y = sum(REF["cutouts"]["usb"]["y_range"]) / 2
USB_CENTER_ABOVE_PLATE, USB_HALF_H, PLUG_LEN = 8.0, 3.5, 12.0   # right-angle USB-C plug (MEASURE)
SCREW_LEN = 10.0                                                 # M3 x 10 button head at every tongue


def defaults():
    d = {}
    for m in re.finditer(r"^(\w+)\s*=\s*(-?[\d.]+|\[[^\]]*\]|true|false)\s*;", open(SCAD).read(), re.M):
        v = m.group(2)
        d[m.group(1)] = json.loads(v) if v[0] in "[tf" else float(v)
    return d


C = defaults()


def scad(out, part=None, body=None, **d):
    args = ["openscad", "--render", "-o", out]
    for k, v in d.items():
        args += ["-D", f"{k}={v}"]
    if body is None:
        args += ["-D", f'part="{part}"', SCAD]
    else:
        src = out + ".scad"
        open(src, "w").write(f"include <{SCAD}>\n{body}\n")
        args += ["-D", 'part="none"', src]
    r = subprocess.run(args, capture_output=True, text=True)
    txt = r.stdout + r.stderr
    if r.returncode or not os.path.exists(out) or os.path.getsize(out) == 0:
        if body is not None and "empty" in txt.lower():
            return None
        raise SystemExit(f"openscad failed ({part or body[:60]}):\n{txt[-800:]}")
    return trimesh.load(out)


def scad_echo(expr, tmp, **d):
    """Evaluate an expression with the design's own functions (so the checker never re-derives geometry)."""
    src, out = os.path.join(tmp, "echo.scad"), os.path.join(tmp, "echo.echo")
    open(src, "w").write(f"include <{SCAD}>\necho(V = {expr});\n")
    args = ["openscad", "-o", out, "-D", 'part="none"']
    for k, v in d.items():
        args += ["-D", f"{k}={v}"]
    subprocess.run(args + [src], capture_output=True, text=True)
    return json.loads(re.search(r"V = (.*)", open(out).read()).group(1))


class Report:
    def __init__(self): self.ok = True
    def __call__(self, name, passed, detail=""):
        self.ok &= bool(passed)
        print(f"  [{'PASS' if passed else 'FAIL'}] {name}" + (f": {detail}" if detail else ""))


def to_world(p, tent, lift):
    th = math.radians(tent)
    x, y, z = p
    return np.array([x * math.cos(th) - z * math.sin(th), y, lift + x * math.sin(th) + z * math.cos(th)])


def hits(mesh, o, d):
    if mesh is None:
        return np.zeros((0, 3))
    loc, _, _ = mesh.ray.intersects_location([o], [d])
    if len(loc):
        loc = loc[np.argsort((loc - o) @ np.asarray(d, float))]
    return loc


def overhang(mesh, lim=50):
    """Faces steeper than `lim` from vertical (off the bed), grouped into connected patches.
    Returns (largest patch area mm^2, largest patch span mm, total area). Small patches (< 20 mm^2,
    < 6 mm across) are short bridges a printer handles; anything bigger needs support."""
    nz, cz = mesh.face_normals[:, 2], mesh.triangles_center[:, 2]
    bad = np.where((nz < -math.sin(math.radians(lim))) & (cz > 0.2))[0]
    if not len(bad):
        return 0.0, 0.0, 0.0
    adj = mesh.face_adjacency
    keep = np.isin(adj[:, 0], bad) & np.isin(adj[:, 1], bad)
    groups = trimesh.graph.connected_components(adj[keep], nodes=bad)
    best = (0.0, 0.0)
    for g in groups:
        g = np.asarray(list(g))
        area = mesh.area_faces[g].sum()
        pts = mesh.triangles[g].reshape(-1, 3)
        span = np.ptp(pts[:, :2], axis=0).max()
        if area > best[0]:
            best = (area, span)
    return best[0], best[1], mesh.area_faces[bad].sum()


def floating_volume(mesh, lh=0.2):
    """Layer-by-layer island test: a layer region is supported only if it overlaps supported
    material in the layer below (the bed layer is supported). Returns mm^3 printed over air.
    Bridges count as supported because a bridge region touches support at its ends.
    Sampled at two layer phases; only material floating in both counts (a slice plane landing
    exactly on a flat face returns a broken outline, which is a sampling artifact)."""
    return min(_floating(mesh, lh, ph) for ph in (0.0137, 0.1037))


def _floating(mesh, lh, phase):
    from shapely.geometry import MultiPolygon, Polygon
    from shapely.ops import unary_union
    zs = np.arange(lh / 2, mesh.bounds[1][2], lh) + phase
    secs = mesh.section_multiplane(plane_origin=[0, 0, 0], plane_normal=[0, 0, 1], heights=zs)
    prev, floating = None, 0.0
    for sec in secs:
        if sec is None:
            continue
        p = unary_union(sec.polygons_full)
        comps = list(p.geoms) if isinstance(p, MultiPolygon) else [p]
        g = []
        for c in comps:
            if prev is None or (c.intersects(prev) and c.intersection(prev).area > 1e-4):
                g.append(c)
            else:
                floating += c.area * lh
        prev = unary_union(g) if g else Polygon()
    return floating


def printable(R, name, m):
    big, span, _ = overhang(m)
    fl = floating_volume(m)
    R(f"{name}: prints as exported with no supports", big < 30 and span < 8 and fl < 5,
      f"{fl:.1f} mm^3 in mid-air; largest overhang patch {big:.0f} mm^2 / {span:.1f} mm")


def interference(pairs, P, tmp, tag):
    worst = []
    for a, b in pairs:
        m = scad(os.path.join(tmp, f"i_{tag}_{a[:6]}_{b[:6]}.stl".replace(" ", "")), body=f"intersection() {{ {a} {b} }}", **P)
        v = abs(m.volume) if m is not None else 0.0
        if v > 0.5:
            worst.append(f"[{a}] x [{b}] {v:.0f} mm^3")
    return worst


def check_angle(tent, a, tmp):
    print(f"\n=== tent {tent} | lift {a.lift} | spacer {a.spacer_len} | splay {a.splay} ===")
    R = Report()
    th = math.radians(tent)
    n_up = np.array([-math.sin(th), 0, math.cos(th)]); down = -n_up
    P = dict(tent_deg=tent, outer_lift=a.lift, spacer_len=a.spacer_len, splay_deg=a.splay)
    keel_on = (bool(C.get("keel")) or a.keel or a.keel_d > 0) and not a.no_keel
    P["keel"] = "true" if keel_on else "false"
    if keel_on and a.keel_d:
        P["keel_d"] = a.keel_d
    f = lambda n: os.path.join(tmp, f"{n}_{tent}.stl")
    st = scad(f("stand_use"), "stand_use", **P)
    R("stand: one watertight body", st.is_watertight and len(st.split(only_watertight=False)) == 1)
    above = ((st.vertices - to_world((0, 0, 0), tent, a.lift)) @ n_up).max()
    R("nothing above the bottom-plate plane", above < 1e-3, f"max {above:.4f} mm")

    seat_bad, path_bad = [], []
    for i, (hx, hy) in enumerate(HOLES):
        lbl = "ABCDE"[i]
        r = (C["screw_hole_d"] / 2 + C["seat_d"] / 2) / 2
        for ang in np.linspace(0, 2 * math.pi, 8, endpoint=False):
            top = to_world((hx + r * math.cos(ang), hy + r * math.sin(ang), 5), tent, a.lift)
            h = hits(st, top, down)
            t = ((h[1] - h[0]) @ down) if len(h) >= 2 else -1
            if abs(t - C["stock_plate_t"]) > 0.05:
                seat_bad.append(f"{lbl}:{t:.2f}")
        start = to_world((hx, hy, -C["stock_plate_t"] - 0.05), tent, a.lift)
        u = np.cross(down, [0, 1, 0]); u /= np.linalg.norm(u); v = np.array([0, 1.0, 0])
        for rr, ang in [(0, 0)] + [(2.0, t) for t in np.linspace(0, 2 * math.pi, 12, endpoint=False)]:
            if len(hits(st, start + rr * (math.cos(ang) * u + math.sin(ang) * v), down)):
                path_bad.append(lbl); break
    R(f"screw seats = stock {C['stock_plate_t']} mm all round", not seat_bad, ", ".join(seat_bad) or "5 holes x 8 probes")
    R("every screw: open straight path for head + driver (r 2 mm) to infinity", not path_bad,
      f"blocked: {sorted(set(path_bad))}" if path_bad else "A-E clear, nothing but air below each seat")

    pts = [to_world((x, USB_Y, z), tent, a.lift) for x in (-PLUG_LEN, 0)
           for z in (USB_CENTER_ABOVE_PLATE - USB_HALF_H, USB_CENTER_ABOVE_PLATE + USB_HALF_H)]
    zmin = min(q[2] for q in pts)
    R("USB plug (right-angle cable) clears the desk", zmin >= 2, f"lowest point {zmin:.1f} mm")

    sp = scad(f("stand_print"), "stand_left", **P)
    printable(R, "stand (plate-down)", sp)
    ext = sp.extents
    R(f"stand fits {a.bed[0]:.0f}x{a.bed[1]:.0f} bed",
      all(e <= b for e, b in zip(sorted(ext[:2]), sorted(a.bed))), f"{ext.round(0).tolist()} mm")

    # joint: the spacer's height is set by the tongues' sloped tops, not by print tolerance
    lowered = scad(os.path.join(tmp, f"low_{tent}.stl"),
                   body="intersection() { stand_left(); translate([0, 0, -0.1]) spacer_placed(); }", **P)
    lv = abs(lowered.volume) if lowered is not None else 0.0
    R("spacer seats on the tongues' sloped tops (lowering it 0.1 mm collides)", lv > 0.5, f"{lv:.1f} mm^3 overlap when lowered")
    ths = math.radians(a.splay)
    xf = scad_echo("x_face()", tmp, **P)
    piv = np.array([xf + a.spacer_len, (C["tongue_ys"][0] + C["tongue_ys"][1]) / 2])
    rot = np.array([[math.cos(ths), -math.sin(ths)], [math.sin(ths), math.cos(ths)]])
    spc = scad(f("spacer_placed"), "spacer_placed", **P)
    srp = scad(f("stand_right_placed"), "stand_right_placed", **P)
    kl = scad(f("kbl"), "keyboard_left", **P)
    kr = scad(f("kbr"), "keyboard_right", **P)
    spacer_h = scad_echo("spacer_h", tmp, **P)
    bad, tool = [], []
    for ty in C["tongue_ys"]:
        for side, xy, stand_mesh in (("L", np.array([xf + C["ins_x"], ty]), st),
                                     ("R", piv + rot @ (np.array([xf + a.spacer_len - C["ins_x"], ty]) - piv), srp)):
            o = np.array([xy[0], xy[1], 60.0])
            if len(hits(spc, o, [0, 0, -1])):
                bad.append(f"{side}{ty}: spacer roof hole blocked")
            h = hits(stand_mesh, o, [0, 0, -1])
            if not len(h) or abs(h[0][2] - 1.2) > 0.05:
                bad.append(f"{side}{ty}: lands at {h[0][2] if len(h) else None}")
            for rr, ang in [(0, 0)] + [(3.0, t) for t in np.linspace(0, 2 * math.pi, 8, endpoint=False)]:
                up = np.array([xy[0] + rr * math.cos(ang), xy[1] + rr * math.sin(ang), spacer_h + 0.1])
                if any(len(hits(m, up, [0, 0, 1])) for m in (st, srp, kl, kr)):
                    tool.append(f"{side}{ty}"); break
    R("screws line up: spacer roof -> insert -> hole floor (4 joints)", not bad, "; ".join(bad) or "4/4")
    R("straight tool path from above to every joint screw (r 3 mm)", not tool, f"blocked: {tool}" if tool else "4/4 clear")
    ins_top = scad_echo("insert_top()", tmp, **P)
    tip = spacer_h - C["cbore_h"] - SCREW_LEN
    engaged = ins_top - max(tip, ins_top - C["m3_insert_len"])
    R(f"M3x{SCREW_LEN:.0f} screw: >= 4.5 mm in the insert, tip clear of the hole floor", tip > 1.2 + 0.3 and engaged >= 4.5,
      f"{engaged:.1f} mm in insert, tip {tip - 1.2:.1f} mm above floor")

    # ---- feet: every pad recess floor at the same depth
    xf_bar = xf - C["bar_w"] / 2
    probes = [(7, C["rib_ys"][0]), (7, C["rib_ys"][2])] + [(xf_bar, y) for y in (C["rib_ys"][0], C["rib_ys"][1], C["rib_ys"][2])]
    floors = []
    for (px, py) in probes:
        h = hits(st, np.array([px, py, -5.0]), [0, 0, 1])
        floors.append(h[0][2] if len(h) else None)
    ok_f = all(z is not None and abs(z - C["pad_recess"]) < 0.02 for z in floors)
    R(f"pad recesses all {C['pad_recess']} mm deep (2 outer discs + foot-bar strip)", ok_f,
      ", ".join("none" if z is None else f"{z:.2f}" for z in floors))

    # ---- keel rod
    if keel_on:
        kd = scad_echo("keel_dia()", tmp, **P)
        kc = scad_echo("keel_c()", tmp, **P)
        y0, y1 = scad_echo("keel_y0()", tmp, **P), scad_echo("keel_y1()", tmp, **P)
        klift = C["keel_lift"]
        vol = math.pi * (kd / 2) ** 2 * C["keel_len"]
        print(f"  [info] keel rod {kd:.3f} mm ({kd / 25.4:.3f} in) x {C['keel_len']} mm: steel {vol * 7.85e-3:.0f} g, brass {vol * 8.5e-3:.0f} g")
        rod = "keel_rod();"
        v_corr = interference([(rod, "access_corridors();")], P, tmp, f"kc{tent}")
        R("rod clear of every screw's access path (full seat_d corridors)", not v_corr, "; ".join(v_corr) or "A-E clear")
        v_fit = interference([(rod, "stand_left();")], P, tmp, f"kf{tent}")
        drop = C["keel_clear"] + 0.3
        low = scad(os.path.join(tmp, f"klow_{tent}.stl"), body=f"intersection() {{ stand_left(); translate([0, 0, -{drop}]) keel_rod(); }}", **P)
        back = scad(os.path.join(tmp, f"kback_{tent}.stl"), body="intersection() { stand_left(); translate([0, 0.2, 0]) keel_rod(); }", **P)
        lv = abs(low.volume) if low is not None else 0.0
        bv = abs(back.volume) if back is not None else 0.0
        R("rod sits free in its eyes, rests on their V (lowered collides), stops on the back rib",
          not v_fit and lv > 0.5 and bv > 0.5, f"nominal {'clear' if not v_fit else v_fit}; lowered {drop:.1f} mm: {lv:.1f} mm^3; pushed back 0.2 mm: {bv:.1f} mm^3")
        sweep = (f"translate([0, keel_y1(), 0]) rotate([90, 0, 0]) linear_extrude(keel_len + 80) "
                 f"translate(keel_c()) circle(d = keel_dia(), $fn = 64);")
        v_sw = interference([(sweep, "stand_left();")], P, tmp, f"ks{tent}")
        R("rod slides straight in from the front (clear path through all three eyes)", not v_sw, "; ".join(v_sw) or "clear")
        low_pts = st.vertices[st.vertices[:, 2] < klift - 0.01]
        stray = low_pts[(low_pts[:, 0] > 14) & (low_pts[:, 0] < xf - C["bar_w"] - 1)]
        R(f"nothing but the feet within {klift} mm of the desk plane", len(stray) == 0,
          f"{len(stray)} stray vertices" if len(stray) else f"rod underside {kc[1] - kd / 2:.1f} mm, eyes >= {klift} mm")

    pairs = [("stand_left();", "spacer_placed();"), ("right_side_placement() stand_left();", "spacer_placed();"),
             ("stand_left();", "right_side_placement() stand_left();"),
             ("keyboard_placeholder();", "right_side_placement() keyboard_placeholder();"),
             ("keyboard_placeholder();", "right_side_placement() stand_left();"),
             ("right_side_placement() keyboard_placeholder();", "stand_left();"),
             ("keyboard_placeholder();", "stand_left();"),
             ("right_side_placement() keyboard_placeholder();", "right_side_placement() stand_left();"),
             ("keyboard_placeholder();", "spacer_placed();"),
             ("right_side_placement() keyboard_placeholder();", "spacer_placed();")]
    if keel_on:
        pairs += [("keel_rod();", "keyboard_placeholder();"), ("keel_rod();", "spacer_placed();"),
                  ("right_side_placement() keel_rod();", "right_side_placement() stand_left();"),
                  ("right_side_placement() keel_rod();", "right_side_placement() keyboard_placeholder();")]
    worst = interference(pairs, P, tmp, f"t{tent}")
    R("no parts intersect in 3D (2 stands, spacer, 2 keyboards" + (", 2 rods" if keel_on else "") + ")", not worst, "; ".join(worst) or f"{len(pairs)} pairs")
    return R.ok


def check_chain(a, tmp):
    A, B = a.chain
    print(f"\n=== chain: spacer {A} + coupler + spacer {B} (tent 30) ===")
    R = Report()
    xf = scad_echo("x_face()", tmp, tent_deg=30)
    web = C["coupler_web"]
    # each spacer is exported separately (OpenSCAD can't rebind spacer_len per call), then placed
    mA = scad(os.path.join(tmp, "cA.stl"), "spacer_placed", spacer_len=A)
    mB = scad(os.path.join(tmp, "cB.stl"), "spacer_placed", spacer_len=B)
    mC = scad(os.path.join(tmp, "cC.stl"), "coupler")
    mA.apply_translation([-xf, 0, 0]); mB.apply_translation([-xf, 0, 0])      # back to spacer frame
    mA.apply_translation([xf, 0, 0])
    mC.apply_translation([xf + A + web / 2, 0, 0])
    mB.apply_translation([xf + A + web, 0, 0])
    inter = []
    for n1, m1, n2, m2 in (("spacer A", mA, "coupler", mC), ("coupler", mC, "spacer B", mB), ("spacer A", mA, "spacer B", mB)):
        mfile1, mfile2 = os.path.join(tmp, "x1.stl"), os.path.join(tmp, "x2.stl")
        m1.export(mfile1); m2.export(mfile2)
        m = scad(os.path.join(tmp, "xi.stl"), body=f'intersection() {{ import("{mfile1}"); import("{mfile2}"); }}')
        v = abs(m.volume) if m is not None else 0
        if v > 0.5: inter.append(f"{n1}/{n2} {v:.0f} mm^3")
    R("spacer + coupler + spacer: no interference", not inter, "; ".join(inter) or "3 pairs")
    bad = 0
    for ty in C["tongue_ys"]:
        for x in (xf + A + web / 2 - web / 2 - C["ins_x"], xf + A + web / 2 + web / 2 + C["ins_x"]):
            o = np.array([x, ty, 40.0])
            hA, hB = hits(mA, o, [0, 0, -1]), hits(mB, o, [0, 0, -1])
            hc = hits(mC, o, [0, 0, -1])
            if len(hA) or len(hB) or not len(hc) or abs(hc[0][2] - 1.2) > 0.05:
                bad += 1
    R("coupler screws line up: spacer roof -> coupler insert -> hole floor (4)", bad == 0, f"{bad} misaligned")
    print(f"  [info] chain length (stand face to stand face) = {A} + {web:.0f} + {B} = {A + web + B:.0f} mm")
    return R.ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tent", type=float, nargs="+", default=[20, 25, 30, 35])
    ap.add_argument("--lift", type=float, default=C["outer_lift"])
    ap.add_argument("--spacer-len", type=float, default=C["spacer_len"])
    ap.add_argument("--splay", type=float, default=C["splay_deg"])
    ap.add_argument("--chain", type=float, nargs=2, default=None)
    ap.add_argument("--bed", type=float, nargs=2, default=[220, 220])
    ap.add_argument("--no-keel", action="store_true", help="check the stand without the metal rod / eyes")
    ap.add_argument("--keel-d", type=float, default=0, help="check with the rod eyes on, forcing this rod diameter")
    ap.add_argument("--keel", action="store_true", help="check with the rod eyes on (keel = true), auto-sized rod")
    a = ap.parse_args()
    with tempfile.TemporaryDirectory() as tmp:
        print("=== small parts (print orientation) ===")
        R = Report()
        for name, P in (("spacer", dict(spacer_len=a.spacer_len, splay_deg=a.splay)), ("coupler", {})):
            m = scad(os.path.join(tmp, f"{name}.stl"), name, **P)
            R(f"{name}: one watertight body, flat on the bed", m.is_watertight and len(m.split(only_watertight=False)) == 1
              and abs(m.bounds[0][2]) < 1e-6, f"{m.extents.round(1).tolist()} mm")
            printable(R, name, m)
        ok = R.ok
        for t in a.tent:
            ok &= check_angle(t, a, tmp)
        if a.chain:
            ok &= check_chain(a, tmp)
    print("\nOVERALL:", "PASS" if ok else "FAIL")
    raise SystemExit(0 if ok else 1)


if __name__ == "__main__":
    main()
