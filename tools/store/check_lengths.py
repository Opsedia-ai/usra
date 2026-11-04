"""Checks the store texts in docs/store against each field's limit.

    python3 tools/store/check_lengths.py         # report, exit 1 if over a limit
    python3 tools/store/check_lengths.py --fix   # also rewrite the (n/limit) counts

A field is a heading like `### Short description (69/80)` followed by a ```text
block. Keywords are counted in UTF-8 bytes, everything else in characters.
"""
import pathlib
import re
import sys

DOCS = pathlib.Path(__file__).resolve().parents[2] / "docs" / "store"
FIELD = re.compile(
    r"^(### [^\n]*\()(\d+)/(\d+)( bytes)?\)\n+```text\n(.*?)\n```",
    re.M | re.S,
)
COUNTED = re.compile(r"^### [^\n]*\(\d+/\d+( bytes)?\)$", re.M)


def main():
    fix = "--fix" in sys.argv
    over = 0
    for path in sorted(DOCS.glob("*.md")):
        text = path.read_text(encoding="utf-8")

        def check(m):
            nonlocal over
            head, _, limit, unit, body = m.groups()
            n = len(body.encode("utf-8")) if unit else len(body)
            name = head[4:-2]
            if n > int(limit):
                over += 1
                print(f"{path.name}: {name}: {n}/{limit} over the limit")
            else:
                print(f"{path.name}: {name}: {n}/{limit}")
            return m.group(0).replace(f"({m.group(2)}/", f"({n}/", 1)

        new = FIELD.sub(check, text)
        # A counted heading without a text block right after it is never checked.
        unchecked = len(COUNTED.findall(text)) - len(FIELD.findall(text))
        if unchecked:
            over += 1
            print(f"{path.name}: {unchecked} counted heading(s) without a ```text block")
        if fix and new != text:
            path.write_text(new, encoding="utf-8")
    sys.exit(1 if over else 0)


if __name__ == "__main__":
    main()
