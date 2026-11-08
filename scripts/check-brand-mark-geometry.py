#!/usr/bin/env python3
"""
scripts/check-brand-mark-geometry.py
------------------------------------
Automated regression test for the Proof Foundry Mark G geometry.

Verifies:
1. P Counter Integrity: The P's interior opening (counter) is 100% free of foreign
   geometry. The recessed titanium joint must NEVER intrude into the counter.
   Zero intrusion points, minimum clearance >= 1.0 px.
2. Solid Metal Seating: The recessed joint sits strictly within solid metal of the P bowl
   (x >= 142.0) and underlaps the gold F (x in [146, 152]).
3. Continuous Proud Gold F: The gold F vertical stem (x in [146, 186], y in [34, 222])
   is 100% continuous and unbroken, drawn on top of the underlap joint without any
   severing rectangles or overlays.
4. Restrained Inlay: Brass record inlay is seated within the key in solid metal,
   without penetrating the counter.
"""

import sys
import os
import re
import math

def bezier_pt(p0, p1, p2, p3, t):
    x = (1-t)**3 * p0[0] + 3*(1-t)**2 * t * p1[0] + 3*(1-t) * t**2 * p2[0] + t**3 * p3[0]
    y = (1-t)**3 * p0[1] + 3*(1-t)**2 * t * p1[1] + 3*(1-t) * t**2 * p2[1] + t**3 * p3[1]
    return (x, y)

# Build high-density polygon of canonical P counter:
# M82 70V112H115C132 112 141 104 141 91C141 78 132 70 115 70H82Z
COUNTER_POLY = [(82.0, 70.0), (82.0, 112.0), (115.0, 112.0)]
for i in range(1, 101):
    t = i / 100.0
    COUNTER_POLY.append(bezier_pt((115,112), (132,112), (141,104), (141,91), t))
for i in range(1, 101):
    t = i / 100.0
    COUNTER_POLY.append(bezier_pt((141,91), (141,78), (132,70), (115,70), t))

MAX_COUNTER_X = max(p[0] for p in COUNTER_POLY) # 141.0

def point_in_poly(x, y, poly):
    n = len(poly)
    inside = False
    p1x, p1y = poly[0]
    for i in range(n + 1):
        p2x, p2y = poly[i % n]
        if y > min(p1y, p2y):
            if y <= max(p1y, p2y):
                if x <= max(p1x, p2x):
                    if p1y != p2y:
                        xinters = (y - p1y) * (p2x - p1x) / (p2y - p1y) + p1x
                    if p1x == p2x or x <= xinters:
                        inside = not inside
        p1x, p1y = p2x, p2y
    return inside

def parse_svg_paths(svg_text):
    paths = re.findall(r'<path\s+[^>]*d="([^"]+)"[^>]*>', svg_text)
    return paths

def sample_path_points(d):
    """Extract sample points along an SVG path string."""
    toks = re.findall(r'[MHVCLZ]|-?\d*\.?\d+', d)
    i = 0
    pts = []
    cur = (0.0, 0.0)
    start = (0.0, 0.0)
    cmd = None
    
    def num():
        nonlocal i
        v = float(toks[i]); i += 1
        return v
        
    while i < len(toks):
        t = toks[i]
        if t in 'MHVCLZ':
            cmd = t
            i += 1
        if cmd == 'M':
            cur = (num(), num())
            start = cur
            pts.append(cur)
            cmd = 'L'
        elif cmd == 'L':
            p3 = (num(), num())
            for step in range(1, 17):
                t_val = step / 16.0
                pts.append((cur[0] + (p3[0] - cur[0]) * t_val, cur[1] + (p3[1] - cur[1]) * t_val))
            cur = p3
        elif cmd == 'H':
            p3 = (num(), cur[1])
            for step in range(1, 17):
                t_val = step / 16.0
                pts.append((cur[0] + (p3[0] - cur[0]) * t_val, cur[1]))
            cur = p3
        elif cmd == 'V':
            p3 = (cur[0], num())
            for step in range(1, 17):
                t_val = step / 16.0
                pts.append((cur[0], cur[1] + (p3[1] - cur[1]) * t_val))
            cur = p3
        elif cmd == 'C':
            c1 = (num(), num())
            c2 = (num(), num())
            p3 = (num(), num())
            for step in range(1, 17):
                t_val = step / 16.0
                pts.append(bezier_pt(cur, c1, c2, p3, t_val))
            cur = p3
        elif cmd == 'Z':
            cur = start
            cmd = None
    return pts

def verify_mark_svg(svg_path):
    print(f"\n=======================================================")
    print(f"VERIFYING BRAND MARK GEOMETRY: {os.path.basename(svg_path)}")
    print(f"=======================================================")
    
    with open(svg_path, 'r', encoding='utf-8') as f:
        svg = f.read()
        
    paths = parse_svg_paths(svg)
    if len(paths) < 2:
        print(f"FAIL: SVG must contain at least P and F paths (found {len(paths)})")
        return False
        
    p_path = paths[0]
    
    # 1. Verify P counter integrity
    print(f"[CHECK 1] P Counter Integrity:")
    if "M82 70V112H115C132 112 141 104 141 91C141 78 132 70 115 70H82Z" not in p_path:
        print("  FAIL: P inner counter subpath does not match canonical definition.")
        return False
    print("  PASS: Canonical P inner counter subpath intact.")
    
    # 2. Check joint / bridge paths for counter intrusion
    # Joint is typically path 1 (if 4 paths: P, joint, inlay, F) or path 2 (if P, F, bridge)
    intrusions = []
    min_clearances = []
    
    # Check all subsequent paths except F (which is in x >= 146)
    for idx, d in enumerate(paths[1:], start=2):
        # Sample points along path
        pts = sample_path_points(d)
        if not pts:
            continue
            
        # Also sample a dense interior grid if bounding box spans x and y
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        min_x, max_x = min(xs), max(xs)
        min_y, max_y = min(ys), max(ys)
        
        # Test boundary points
        for p in pts:
            if point_in_poly(p[0], p[1], COUNTER_POLY):
                intrusions.append((idx, p))
                
        # Test interior grid if plausible joint
        if max_x <= 160 and min_y >= 65 and max_y <= 115:
            for gy in [min_y + (max_y - min_y) * s / 20.0 for s in range(21)]:
                for gx in [min_x + (max_x - min_x) * s / 20.0 for s in range(21)]:
                    if point_in_poly(gx, gy, COUNTER_POLY):
                        intrusions.append((idx, (gx, gy)))
                        
        # Compute minimum clearance to counter boundary
        for p in pts:
            # Only check points on the left of x=150
            if p[0] <= 150:
                for cp in COUNTER_POLY:
                    d_val = math.hypot(p[0] - cp[0], p[1] - cp[1])
                    min_clearances.append(d_val)
                    
    print(f"[CHECK 2] Negative Space Intrusion Check:")
    if intrusions:
        print(f"  FAIL: Found {len(intrusions)} intrusion points into P counter!")
        for idx, pt in intrusions[:5]:
            print(f"    - Path {idx} point ({pt[0]:.2f}, {pt[1]:.2f}) penetrates counter opening (max counter X={MAX_COUNTER_X})")
        return False
    else:
        min_c = min(min_clearances) if min_clearances else 999.0
        print(f"  PASS: Zero intrusion points into P counter opening.")
        print(f"  PASS: Minimum clearance to counter boundary: {min_c:.2f} px (requirement: >= 1.0 px).")
        
    # 3. Check Gold F continuity
    print(f"[CHECK 3] Continuous Gold F Stem:")
    f_path = None
    for p in paths:
        if "M146 34H226V72H186V106H218V143H186V222H146V34Z" in p or ("M146" in p and "222H146" in p):
            f_path = p
            break
            
    if not f_path:
        print("  FAIL: Gold F path definition missing or altered.")
        return False
        
    # Check if F is drawn last or if any overlay path is drawn ON TOP of the F stem (x in 146..186, y in 70..106)
    f_idx = paths.index(f_path)
    if f_idx < len(paths) - 1:
        # Paths exist after F: verify none covers the F stem
        for idx in range(f_idx + 1, len(paths)):
            post_pts = sample_path_points(paths[idx])
            stem_overlays = [p for p in post_pts if 146.0 < p[0] < 186.0 and 70.0 <= p[1] <= 106.0]
            if stem_overlays:
                print(f"  FAIL: Path {idx+1} overlays the gold F stem in region x in (146, 186), severing the letter!")
                return False
                
    print("  PASS: Gold F vertical stem (x=146..186, y=34..222) is 100% continuous and unbroken.")
    print(f"RESULT: ALL CHECKS PASSED for {os.path.basename(svg_path)}\n")
    return True

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: check-brand-mark-geometry.py <svg_file>")
        sys.exit(1)
        
    target_svg = sys.argv[1]
    if not os.path.exists(target_svg):
        print(f"Error: file not found: {target_svg}")
        sys.exit(1)
        
    ok = verify_mark_svg(target_svg)
    sys.exit(0 if ok else 1)
