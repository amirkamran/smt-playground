#!/usr/bin/python

# usage: paste align align.inv | ./symmetrize.py gd fa
# arguments are a sequence of symmetrization algorithms
# 
# Ales Tamchyna <tamchyna@ufal.mff.cuni.cz>

import sys
from collections import defaultdict

# die with a message
def die(msg):
    print >> sys.stderr, msg
    sys.exit(1)

# compare alignment points
def compare_points(x, y):
    if x[0] != y[0]:
        return x[0] - y[0]
    else:
        return x[1] - y[1]

# parse one line of Giza++-formatted word alignment
def parse_align(align_str, inv = False):
    pts = set()
    for pt in align_str.split(' '):
        x, y = [int(i) for i in pt.split('-')]
        if inv:
            x, y = y, x
        pts.add((x, y))
    return pts
# return true if new_pt has a (diagonal) neighbor in current
def has_neighbor(new_pt, current, diag):
    x, y = new_pt
    neighbors = [
        (x - 1, y),
        (x + 1, y),
        (x, y - 1),
        (x, y + 1)]
    if diag:
        neighbors.extend([
            (x - 1, y - 1),
            (x + 1, y - 1),
            (x - 1, y + 1),
            (x + 1, y + 1)])
    return any(pt in current for pt in neighbors)

# grow(-diag) algorithm
def grow(there, back, diag):
    out = there.intersection(back)
    extra = there.union(back).difference(out)
    changed = True
    while (changed):
        changed = False
        newextra = set()
        for pt in extra:
            if has_neighbor(pt, out, diag):
                changed = True
                out.add(pt)
            else:
                newextra.add(pt)
        extra = newextra
    return out

# true if new_pt is not aligned to any point in current
# on source and/or target side
def unaligned(new_pt, current, only_and):
    unaligned_src = not new_pt[0] in [pt[0] for pt in current]
    unaligned_tgt = not new_pt[1] in [pt[1] for pt in current]
    if only_and:
        return unaligned_src and unaligned_tgt
    else:
        return unaligned_src or unaligned_tgt

# final(-and) algorithm
def final(align, there, back, only_and):
    out = align.copy()
    extra = there.union(back).difference(out)
    changed = True
    while (changed):
        changed = False
        newextra = set()
        for pt in extra:
            if unaligned(pt, out, only_and):
                changed = True
                out.add(pt)
            else:
                newextra.add(pt)
        extra = newextra
    return out

## main

algorithms = []

sym_table = dict(
    i  = lambda a, t, b: t.intersection(b),
    u  = lambda a, t, b: t.union(b),
    g  = lambda a, t, b: grow(t, b, False),
    gd = lambda a, t, b: grow(t, b, True),
    f  = lambda a, t, b: final(a, t, b, False), 
    fa = lambda a, t, b: final(a, t, b, True)
)    

for arg in sys.argv[1:]:
    if not sym_table.has_key(arg): die("Unknown algorithm: " + arg)
    algorithms.append(sym_table[arg])

for line in sys.stdin:
    cols = line.rstrip().split("\t")
    there = parse_align(cols[0])
    back = parse_align(cols[1], True) # invert points

    align = set()
    for alg in algorithms:
        align = alg(align, there, back)

    try:
        # print the alignment points
        points = []
        for pt in sorted(align, compare_points):
            points.append("%d-%d" % (pt[0], pt[1]))
        print ' '.join(points)
    except IOError: # graceful handling of broken pipes (e.g. because of " | head")
        pass
