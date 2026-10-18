#!/usr/bin/env python3
"""Rough stability numbers for the Microdox "Ribs" stand.

Usage:
  python3 stability.py [--tent 20 25 30 35] [--half-g 150] [--mu 0.8]

--half-g is one keyboard half with switches, keycaps and battery: weigh yours, it drives
every number. The stand mass comes from its mesh volume x 0.637 g/cm^3 (calibrated to
PrusaSlicer 2.7, 0.2 mm layers, 2 walls, 10% lightning: a stand at 30 deg ~ 46 cm^3 -> ~29 g).
Geometry (key positions, feet) comes from microdox_ribs.scad / microdox_ref.json, so it follows
any edit.

What it reports, per tent angle:
  lone half   the push on the worst key (straight down the key axis) that starts to rock the
              half inward onto its spacer tongues, and the push that tips it right over them
  sliding     a keypress cannot slide the board at all if mu > tan(tent) (the downward part of
              the press adds more grip than the sideways part pushes); for sideways drag from
              wrists or thumbs the board holds until drag = mu x weight
Model: rigid bodies, a keypress along the key axis at the keycap top, feet on a flat desk.
It is a comparison tool (one angle vs another, one keyboard weight vs another), not a guarantee.
"""
import argparse, json, math, os, re, subprocess, tempfile
import numpy as np
import trimesh

HERE = os.path.dirname(os.path.abspath(__file__))
CAD = os.path.join(HERE, "..", "cad")
SCAD = os.path.join(CAD, "microdox_ribs.scad")
REF = json.load(open(os.path.join(CAD, "microdox_ref.json")))
G = 9.81e-3                     # N per gram
PLA_EFF = 0.637e-3              # g per mm^3 of model volume, as printed (walls + infill)


def echo(expr, tmp, **d):
    src, out = os.path.join(tmp, "e.scad"), os.path.join(tmp, "e.echo")
    open(src, "w").write(f"include <{SCAD}>\necho(V = {expr});\n")
    args = ["openscad", "-o", out, "-D", 'part="none"'] + sum((["-D", f"{k}={v}"] for k, v in d.items()), [])
    subprocess.run(args + [src], capture_output=True, text=True)
    return json.loads(re.search(r"V = (.*)", open(out).read()).group(1))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tent", type=float, nargs="+", default=[20, 25, 30, 35])
    ap.add_argument("--half-g", type=float, default=150.0)
    ap.add_argument("--mu", type=float, default=0.8)
    a = ap.parse_args()
    keys_u = [s[0] for s in REF["switches"]["centers_xy_rotdeg"]]
    with tempfile.TemporaryDirectory() as tmp:
        print(f"keyboard half {a.half_g:.0f} g, pads mu {a.mu}\n")
        for t in a.tent:
            P = dict(tent_deg=t)
            th = math.radians(t)
            v = echo("[x_face(), foot_x(), strip_w, tongue_len, outer_lift, standoff_h, cap_top_above_pcb]", tmp, **P)
            xf, fx, sw, tl, lift, so, cap = v
            W = lambda U, H: (U * math.cos(th) + H * math.sin(th), lift + U * math.sin(th) - H * math.cos(th))
            stl = os.path.join(tmp, f"s{t}.stl")
            subprocess.run(["openscad", "--render", "-o", stl, "-D", 'part="stand_use"', "-D", f"tent_deg={t}", SCAD],
                           capture_output=True)
            m = trimesh.load(stl)
            stand_g = m.volume * PLA_EFF
            stand_x = m.center_mass[0]
            kb_x = W(np.mean(keys_u), -(so + 1.6 + 6))[0]          # keyboard CG ~ switch-body height
            print(f"=== tent {t:.0f} deg: stand {stand_g:.0f} g ===")
            masses = [(a.half_g, kb_x), (stand_g, stand_x)]
            res = []
            for axis_name, xa in (("rocks", fx + sw / 2), ("tips over", xf + tl)):
                restore = sum(g * G * (xa - x) for g, x in masses)
                worst = None
                for u in keys_u:
                    kx, kz = W(u, -(so + 1.6 + cap))
                    arm = kz * math.sin(th) - (xa - kx) * math.cos(th)
                    if arm > 0:
                        f = restore / arm
                        worst = f if worst is None else min(worst, f)
                res.append(f"{axis_name} at {worst:.1f} N" if worst else f"never {axis_name}")
            tot = a.half_g + stand_g
            print(f"  lone half {res[0]}, {res[1]}  |  pair ~{2 * tot + 12:.0f} g, slides under drag at {a.mu * (2 * tot + 12) * G:.1f} N")
            print(f"  keypress can't slide it if mu > tan(tent) = {math.tan(th):.2f}: "
                  f"{'yes' if a.mu > math.tan(th) else 'NO'} with mu {a.mu}; bare PLA (~0.3-0.5): no\n")


if __name__ == "__main__":
    main()
