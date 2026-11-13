"""Reads and writes the TOML files of the CrownOS publishing pipeline.

    toml.py json FILE   prints FILE as JSON
    toml.py write [--bare]  prints the JSON on stdin as canonical TOML,
                            with the components.toml header unless --bare

The writer covers only the schema of components.toml and the published
manifest: top-level strings, booleans and string arrays, inline tables of
strings, and arrays of tables made of those.
"""

import json
import sys
import tomllib

HEADER = (
    "# Written by scripts/toml.py: comments are not preserved and scripts/pin.sh\n"
    "# rewrites this file. Change it with pin.sh or keep edits to plain values.\n"
)
TABLE_KEY_ORDER = (
    "name", "version", "repo", "tag", "asset", "sha256", "source",
    "install", "pkgbuild", "allow_stale", "siblings",
)


def scalar(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, list):
        return "[" + ", ".join(scalar(item) for item in value) + "]"
    if isinstance(value, dict):
        pairs = ", ".join(f"{bare_key(key)} = {scalar(item)}" for key, item in sorted(value.items()))
        return "{ " + pairs + " }" if pairs else "{}"
    raise SystemExit(f"toml.py: unsupported value {value!r}")


def bare_key(key):
    if key and all(char.isalnum() or char in "-_" for char in key):
        return key
    return json.dumps(key)


def ordered_table(table):
    rank = {key: index for index, key in enumerate(TABLE_KEY_ORDER)}
    return sorted(table.items(), key=lambda item: rank.get(item[0], len(rank)))


def write(document, header):
    lines = [header]
    tables = {key: value for key, value in document.items() if is_table_array(value)}
    for key, value in document.items():
        if key not in tables:
            lines.append(f"{bare_key(key)} = {scalar(value)}\n")
    for key, entries in tables.items():
        for entry in entries:
            lines.append(f"\n[[{bare_key(key)}]]\n")
            lines.extend(f"{bare_key(name)} = {scalar(value)}\n" for name, value in ordered_table(entry))
    return "".join(lines)


def is_table_array(value):
    return isinstance(value, list) and bool(value) and all(isinstance(item, dict) for item in value)


def main(arguments):
    match arguments:
        case ["json", path]:
            with open(path, "rb") as file:
                json.dump(tomllib.load(file), sys.stdout)
            sys.stdout.write("\n")
        case ["write"]:
            sys.stdout.write(write(json.load(sys.stdin), HEADER))
        case ["write", "--bare"]:
            sys.stdout.write(write(json.load(sys.stdin), "").lstrip("\n"))
        case _:
            raise SystemExit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
