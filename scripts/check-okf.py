#!/usr/bin/env python3
"""Lightweight OKF v0.1 conformance check for the harness memory bundle.

Usage: check-okf.py [bundle-root]     (default: .claude-harness/memory)

Checks (per OKF v0.1, see schemas/okf-memory.md):
  1. Every non-reserved .md file has parseable YAML frontmatter delimited by
     `---` lines, containing a non-empty `type` field.
  2. The bundle-root index.md declares okf_version "0.1" (the only frontmatter
     an index.md may carry).
  3. Non-root index.md and log.md files are reserved and must NOT carry
     frontmatter.

Everything else in the spec is soft guidance: unknown frontmatter keys,
missing optional fields, and broken links are tolerated.

Exit code: 0 if conformant, 1 otherwise (violations printed to stderr).
No third-party dependencies (frontmatter is parsed with a minimal
key/value reader, tolerant of unknown keys and value types).
"""
import os
import sys

RESERVED = {"index.md", "log.md"}


def read_frontmatter(path):
    """Return (dict-or-None, error-or-None).

    (None, None) means the file has no frontmatter block at all.
    A dict maps top-level keys to raw string values (nested/list values are
    kept as raw text or empty strings - consumers must tolerate any type).
    """
    try:
        with open(path, encoding="utf-8") as f:
            text = f.read()
    except Exception as e:  # unreadable file
        return None, "unreadable: {}".format(e)

    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None, None
    fields = {}
    closed = False
    for line in lines[1:]:
        if line.strip() == "---":
            closed = True
            break
        if not line.strip() or line.strip().startswith("#"):
            continue
        if line.startswith((" ", "\t")) or line.strip().startswith("-"):
            continue  # continuation of a nested/list value - tolerated
        if ":" not in line:
            return None, "unparseable frontmatter line: {!r}".format(line)
        key, _, value = line.partition(":")
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        fields[key.strip()] = value
    if not closed:
        return None, "frontmatter opened with --- but never closed"
    return fields, None


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else ".claude-harness/memory"
    root = os.path.abspath(root)
    if not os.path.isdir(root):
        print("check-okf: bundle root not found: {}".format(root), file=sys.stderr)
        return 1

    errors = []
    checked = 0

    # Bundle-root index.md must declare okf_version 0.1
    root_index = os.path.join(root, "index.md")
    fm, err = read_frontmatter(root_index) if os.path.isfile(root_index) else (None, None)
    if not os.path.isfile(root_index):
        errors.append("index.md: missing bundle-root index.md")
    elif err:
        errors.append("index.md: {}".format(err))
    elif not fm or fm.get("okf_version") != "0.1":
        errors.append('index.md: bundle-root must declare okf_version: "0.1"')

    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if not d.startswith(".")]
        for name in sorted(filenames):
            if not name.endswith(".md"):
                continue
            path = os.path.join(dirpath, name)
            rel = os.path.relpath(path, root)
            if name in RESERVED:
                if path == root_index:
                    continue  # validated above
                fm, err = read_frontmatter(path)
                if fm is not None or err:
                    errors.append("{}: reserved file must not carry frontmatter".format(rel))
                continue
            checked += 1
            fm, err = read_frontmatter(path)
            if err:
                errors.append("{}: {}".format(rel, err))
            elif fm is None:
                errors.append("{}: missing YAML frontmatter".format(rel))
            elif not fm.get("type", "").strip():
                errors.append("{}: frontmatter has no non-empty 'type' field".format(rel))

    if errors:
        for e in errors:
            print("check-okf: {}".format(e), file=sys.stderr)
        print(
            "check-okf: FAIL - {} violation(s) in {}".format(len(errors), root),
            file=sys.stderr,
        )
        return 1
    print("check-okf: OK - {} concept file(s) conformant in {}".format(checked, root))
    return 0


if __name__ == "__main__":
    sys.exit(main())
