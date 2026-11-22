#!/usr/bin/env python3
"""Find elements in the accessibility tree AXe reports, for capture.sh.

    axe_ui.py has  <label>            exit 0 when an element has this label
    axe_ui.py find <label> [--lowest] print "x y", the centre of the match
    axe_ui.py list                    print every label with its frame

The tree is read from stdin (the JSON of `axe describe-ui`). `find` matches the
label exactly, then as a prefix, and takes the first match in reading order, or
the one lowest on screen with --lowest (a tab bar item shares its name with the
screen's title).
"""
import json
import sys


def walk(node):
    if isinstance(node, list):
        for item in node:
            yield from walk(item)
    elif isinstance(node, dict):
        yield node
        for key in ("children", "AXChildren"):
            yield from walk(node.get(key) or [])


def label_of(node):
    return (node.get("AXLabel") or node.get("label") or "").strip()


def frame_of(node):
    frame = node.get("frame") or node.get("AXFrame") or {}
    if not isinstance(frame, dict):
        return None
    try:
        x, y = float(frame["x"]), float(frame["y"])
        w, h = float(frame["width"]), float(frame["height"])
    except (KeyError, TypeError, ValueError):
        return None
    return (x, y, w, h) if w > 0 and h > 0 else None


def matches(nodes, label):
    wanted = label.casefold()
    exact = [n for n in nodes if label_of(n).casefold() == wanted]
    return exact or [n for n in nodes if label_of(n).casefold().startswith(wanted)]


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ("has", "find", "list"):
        sys.exit(__doc__)
    command, args = sys.argv[1], sys.argv[2:]
    try:
        nodes = [n for n in walk(json.load(sys.stdin)) if frame_of(n)]
    except json.JSONDecodeError:
        sys.exit("axe_ui: the UI description is not JSON")

    if command == "list":
        for node in nodes:
            if label_of(node):
                x, y, w, h = frame_of(node)
                kind = node.get("type") or node.get("role") or ""
                print(f"{x:6.0f} {y:6.0f} {w:5.0f} {h:5.0f}  {kind:<22} {label_of(node)}")
        return

    if not args:
        sys.exit(__doc__)
    found = matches(nodes, args[0])
    if not found:
        sys.exit(1)
    if command == "find":
        if "--lowest" in args:
            found.sort(key=lambda n: frame_of(n)[1], reverse=True)
        x, y, w, h = frame_of(found[0])
        print(f"{x + w / 2:.0f} {y + h / 2:.0f}")


if __name__ == "__main__":
    main()
