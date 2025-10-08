#!/usr/bin/env python3
# make_indirection_complexity.py
# Compute a dimensionless indirection complexity index from one or more makefiles.

import argparse, json, re, subprocess, sys
from collections import defaultdict

DEFAULT_WEIGHTS = {"var_depth": 1.0, "include_depth": 1.0, "dep_depth": 1.0, "macro_breadth": 0.25}

FUNC_NAMES = (
    "call|shell|foreach|eval|file|if|or|and|info|warning|error|origin|flavor|"
    "abspath|realpath|dir|notdir|basename|suffix|addprefix|addsuffix|join|"
    "word|wordlist|words|firstword|lastword|sort|uniq|patsubst|subst|filter|filter-out|findstring|strip"
)
FUNC_RE = re.compile(r"\$\((?:" + FUNC_NAMES + r")\b", re.MULTILINE)

TARGET_LINE_RE = re.compile(r"""^(?![#\s])
                                ([^:=#]+?)
                                \s*:\s*
                                (.+?)$
                             """, re.MULTILINE | re.VERBOSE)


def run_make_dump(makefiles=None, make_bin="make"):
    """Run make -pn, tolerate errors, fall back to -pRrq if needed."""
    cmd = [make_bin, "-pn"]
    for mf in (makefiles or []):
        cmd += ["-f", mf]

    p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if p.stdout:
        return p.stdout

    fallback = [make_bin, "-pRrq"]
    for mf in (makefiles or []):
        fallback += ["-f", mf]

    p2 = subprocess.run(fallback, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if p2.stdout:
        return p2.stdout

    raise RuntimeError(f"{make_bin} dump failed:\n{p.stderr or p2.stderr}")


def max_var_nesting(s: str) -> int:
    depth = maxd = 0
    i = 0
    while i < len(s) - 1:
        if s[i] == "$" and s[i + 1] == "(":
            depth += 1
            maxd = max(maxd, depth)
            i += 2
        elif s[i] == ")" and depth > 0:
            depth -= 1
            i += 1
        else:
            i += 1
    return maxd


 

def include_depth(make_dump: str) -> int:
    """
    Count included makefiles via MAKEFILE_LIST.
    Depth = (#unique files in MAKEFILE_LIST) - 1  (exclude the main makefile)
    """
    m = re.search(r'^MAKEFILE_LIST\s*[:+]?=\s*(.*)$', make_dump, re.M)
    if not m:
        return 0
    # Split preserving non-space paths; GNU make uses spaces between entries.
    files = m.group(1).strip().split()
    # De-dup while preserving order
    seen = []
    for f in files:
        if f not in seen:
            seen.append(f)
    return max(len(seen) - 1, 0)

def dep_graph(make_dump: str):
    graph = defaultdict(list)
    for m in TARGET_LINE_RE.finditer(make_dump):
        targets = [t.strip() for t in m.group(1).split() if t.strip()]
        rhs = m.group(2)
        prereq_part = rhs.split(";")[0]
        prereqs = [p for p in re.split(r"\s+|\|", prereq_part) if p and p != ":"]
        for t in targets:
            graph[t].extend(prereqs)
    return graph


def longest_chain(graph):
    sys.setrecursionlimit(10000)
    seen = {}

    def dfs(u, stack):
        if u in stack:
            return 0
        if u in seen:
            return seen[u]
        best = 0
        for v in graph.get(u, []):
            best = max(best, 1 + dfs(v, stack | {u}))
        seen[u] = best
        return best

    return max((dfs(n, set()) for n in graph.keys()), default=0)


def compute(weights, makefiles, make_bin):
    dump = run_make_dump(makefiles, make_bin)
    var_depth = max_var_nesting(dump)
    inc_depth = include_depth(dump)
    graph = dep_graph(dump)
    dep_depth = longest_chain(graph)
    macro_breadth = len(FUNC_RE.findall(dump))
    c_ind = (
        weights["var_depth"] * var_depth
        + weights["include_depth"] * inc_depth
        + weights["dep_depth"] * dep_depth
        + weights["macro_breadth"] * macro_breadth
    )
    return {
        "schema": "make/indirection_complexity.v1",
        "makefiles": makefiles or ["default"],
        "version": "0.3",
        "var_depth": var_depth,
        "include_depth": inc_depth,
        "dep_depth": dep_depth,
        "macro_breadth": macro_breadth,
        "weights": weights,
        "C_indirection": c_ind,
    }


def parse_weights(s):
    try:
        w = json.loads(s)
        for k in DEFAULT_WEIGHTS:
            if k not in w:
                w[k] = DEFAULT_WEIGHTS[k]
        return {k: float(w[k]) for k in DEFAULT_WEIGHTS}
    except Exception as e:
        raise argparse.ArgumentTypeError(f"invalid weights JSON: {e}")


def build_parser():
    p = argparse.ArgumentParser(
        prog="make_indirection_complexity.py",
        description="Compute a dimensionless indirection complexity index from one or more makefiles.",
        formatter_class=argparse.RawTextHelpFormatter,
    )
    p.add_argument(
        "-f",
        "--file",
        dest="makefiles",
        action="append",
        help="may be given multiple times (e.g. -f Makefile -f system/make/workflows.mk)",
    )
    p.add_argument("--make-bin", default="make", help="make binary to use (e.g., gmake on macOS)")
    p.add_argument("--weights", type=parse_weights, help="override weights JSON")
    p.add_argument("--pretty", action="store_true", help="pretty-print JSON instead of NDJSON")
    p.add_argument("--threshold", type=float, help="fail if C_indirection > THRESHOLD")
    p.add_argument("--version", action="version", version="indirection-complexity 0.3")
    return p


def main(argv=None):
    args = build_parser().parse_args(argv)
    weights = args.weights or DEFAULT_WEIGHTS
    out = compute(weights, args.makefiles, args.make_bin)
    print(json.dumps(out, indent=2 if args.pretty else None))
    if args.threshold is not None:
        sys.exit(1 if out["C_indirection"] > args.threshold else 0)


if __name__ == "__main__":
    main()
