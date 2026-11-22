"""Measure the body shell that mass.py spreads over the exterior of Models/followme.ac.

    python3 dev/tyre-model/fit_body_shell.py

Prints the area-weighted centroid and second moments per kg of the body
meshes and fails if they differ from BODY_SHELL_CENTROID and
BODY_SHELL_INERTIA_PER_KG in mass.py. Requires NumPy.
"""
import sys
from pathlib import Path

import numpy as np

import mass

MODEL = Path(__file__).resolve().parents[2] / "Models" / "followme.ac"

# Top-level objects that are not body panels: wheels, brakes, axles, lamps and
# their light cones, switches, plates, wipers, mirrors and small trim.
NOT_BODY = ("Cone", "Tyre", "kaqian", "zhou", "light", "indicater", "reverse", "plate", "sign",
            "switch", "charge", "group", "wiper", "mirror", "bose", "dooo", "cylinder")


def read_ac3d(path):
    """[(path, vertices, triangles)] in model axes.

    AC3D is y up; FlightGear maps (x, y, z) to (x, -z, y), which gives the
    structural frame: x aft, y right, z up.
    """
    lines = path.read_text(encoding="latin-1").split("\n")
    out = []

    def parse(i, parent_loc, parent_rot, parent_path):
        assert lines[i].startswith("OBJECT"), lines[i]
        i += 1
        name, loc, rot = "", np.zeros(3), np.eye(3)
        verts, tris = np.zeros((0, 3)), []
        while True:
            tok = lines[i].split()
            key = tok[0] if tok else ""
            if key == "name":
                name = lines[i].strip()[5:].strip().strip('"')
                i += 1
            elif key == "data":
                need, i = int(tok[1]), i + 1
                while need > 0:
                    need -= len(lines[i]) + 1
                    i += 1
            elif key == "rot":
                rot = np.array([float(v) for v in tok[1:10]]).reshape(3, 3)
                i += 1
            elif key == "loc":
                loc = np.array([float(v) for v in tok[1:4]])
                i += 1
            elif key == "numvert":
                n = int(tok[1])
                verts = np.array([[float(v) for v in lines[i + 1 + k].split()[:3]] for k in range(n)]).reshape(-1, 3)
                i += 1 + n
            elif key == "numsurf":
                i += 1
                for _ in range(int(tok[1])):
                    flags = int(lines[i].split()[1], 16)
                    while not lines[i].startswith("refs"):
                        i += 1
                    k = int(lines[i].split()[1])
                    refs = [int(lines[i + 1 + j].split()[0]) for j in range(k)]
                    i += 1 + k
                    if flags & 0xF == 0:              # a polygon, not a line
                        tris.extend((refs[0], refs[j], refs[j + 1]) for j in range(1, k - 1))
            elif key == "kids":
                world_rot = parent_rot @ rot
                world_loc = parent_rot @ loc + parent_loc
                here = parent_path + "/" + name
                if len(verts) and tris:
                    w = verts @ world_rot.T + world_loc
                    out.append((here, np.column_stack([w[:, 0], -w[:, 2], w[:, 1]]), np.array(tris)))
                i += 1
                for _ in range(int(tok[1])):
                    i = parse(i, world_loc, world_rot, here)
                return i
            else:
                i += 1                               # texture, texrep, crease, url, ...

    start = next(i for i, line in enumerate(lines) if line.startswith("OBJECT"))
    parse(start, np.zeros(3), np.eye(3), "")
    return out


def measure(objects):
    """Area-weighted centroid and second moments per kg of the body meshes."""
    centres, areas = [], []
    for path, verts, tris in objects:
        top = path.split("/")[2] if path.count("/") >= 2 else path
        if any(word in top for word in NOT_BODY):
            continue
        p = verts[tris]
        a = 0.5 * np.linalg.norm(np.cross(p[:, 1] - p[:, 0], p[:, 2] - p[:, 0]), axis=1)
        centres.append(p.mean(axis=1)[a > 0])
        areas.append(a[a > 0])
    c, a = np.vstack(centres), np.concatenate(areas)
    w = a / a.sum()
    centroid = w @ c
    r = c - centroid
    inertia = np.eye(3) * (w @ (r * r).sum(axis=1)) - (r * w[:, None]).T @ r
    return a.sum(), centroid, inertia


def main():
    area, centroid, inertia = measure(read_ac3d(MODEL))
    print("body mesh area %.1f m2" % area)
    print("BODY_SHELL_CENTROID = (%.4f, %.4f, %.4f)" % tuple(centroid))
    print("BODY_SHELL_INERTIA_PER_KG = (")
    for row in inertia:
        print("    (%.4f, %.4f, %.4f)," % tuple(row))
    print(")")
    ok = (np.allclose(centroid, mass.BODY_SHELL_CENTROID, atol=1e-3)
          and np.allclose(inertia, mass.BODY_SHELL_INERTIA_PER_KG, atol=1e-3))
    print("mass.py matches" if ok else "mass.py is out of date")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
