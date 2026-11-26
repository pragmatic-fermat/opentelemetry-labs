#!/usr/bin/env python3
"""Numérote les paragraphes des fichiers Markdown des labs.

Chaque paragraphe de corps reçoit un numéro discret, en indice par défaut
(``<sub>N</sub>``) ou en exposant avec ``--style sup`` (``<sup>N</sup>``), ce qui
permet de se repérer dans un texte long et de renvoyer à un paragraphe précis
(« voir § 12 »).

Le script est idempotent : il retire d'abord les numéros existants, puis
renumérote, ce qui permet de le relancer après chaque ajout ou retrait de
paragraphe.

Sont exclus de la numérotation : les titres, les listes, les tableaux, les
citations et encarts d'alerte (``>``), les blocs de code clôturés, le code
indenté, les lignes HTML et les images.

Utilisation :
    tools/number-paragraphs.py Lab_04_Ansible_Jinja2.md
    tools/number-paragraphs.py --check Lab_04_Ansible_Jinja2.md
    tools/number-paragraphs.py --style sup Lab_04_Ansible_Jinja2.md
    tools/number-paragraphs.py --anchors Lab_04_Ansible_Jinja2.md

Codes de retour :
    0  fichier déjà à jour, ou mis à jour sans --check
    1  --check : au moins un fichier doit être renuméroté
    2  erreur d'argument ou de lecture
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# Numéro déjà présent en début de ligne (exposant ou indice), avec l'espace qui le suit.
MARKER_RE = re.compile(r"^(?:<sup>\d+</sup>|<sub>\d+</sub>)[ ]?")
# Ancre déjà présente en début de ligne.
ANCHOR_RE = re.compile(r"^<a name=\"p-[0-9]+\"></a>")

# Premiers caractères qui excluent une ligne de la numérotation.
SKIP_PREFIXES = ("#", ">", "|", "<", "![")
# Puce de liste ou item numéroté : un marqueur suivi d'une espace.
LIST_ITEM_RE = re.compile(r"^([-*+]|\d+[.)])\s")
FENCE_RE = re.compile(r"^(`{3,}|~{3,})")


def is_prose_line(line: str) -> bool:
    """Vrai si la ligne peut ouvrir un paragraphe de corps."""
    if not line.strip():
        return False
    if line.startswith((" ", "\t")):
        return False
    if line.startswith(SKIP_PREFIXES):
        return False
    if LIST_ITEM_RE.match(line):
        return False
    return True


def strip_markers(line: str) -> str:
    """Retire un numéro ou une ancre déjà présents."""
    line = ANCHOR_RE.sub("", line)
    line = MARKER_RE.sub("", line)
    return line


def number_text(text: str, anchors: bool = False, style: str = "sub") -> tuple[str, int]:
    """Renumérote le texte et renvoie le résultat avec le nombre de paragraphes."""
    had_trailing_newline = text.endswith("\n")
    lines = [strip_markers(line) for line in text.splitlines()]

    out: list[str] = []
    in_fence = False
    fence_char = ""
    fence_len = 0
    count = 0

    for index, line in enumerate(lines):
        stripped = line.lstrip()
        fence = FENCE_RE.match(stripped)

        if in_fence:
            out.append(line)
            if fence and fence.group(1)[0] == fence_char and len(fence.group(1)) >= fence_len:
                in_fence = False
            continue

        if fence:
            in_fence = True
            fence_char = fence.group(1)[0]
            fence_len = len(fence.group(1))
            out.append(line)
            continue

        previous_is_blank = index == 0 or not lines[index - 1].strip()
        if previous_is_blank and is_prose_line(line):
            count += 1
            prefix = f"<{style}>{count}</{style}> "
            if anchors:
                prefix = f'<a name="p-{count}"></a>' + prefix
            out.append(prefix + line)
        else:
            out.append(line)

    result = "\n".join(out)
    if had_trailing_newline:
        result += "\n"
    return result, count


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Numérote les paragraphes d'un ou plusieurs fichiers Markdown."
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="ne modifie rien, renvoie 1 si un fichier doit être renuméroté",
    )
    parser.add_argument(
        "--style",
        choices=("sup", "sub"),
        default="sub",
        help="position du numéro : sub (indice, défaut) ou sup (exposant)",
    )
    parser.add_argument(
        "--anchors",
        action="store_true",
        help="ajoute aussi une ancre <a name=\"p-N\"></a> avant chaque numéro",
    )
    parser.add_argument("paths", nargs="+", type=Path, help="fichiers Markdown à traiter")
    args = parser.parse_args(argv)

    changed_files = 0
    total_paragraphs = 0

    for path in args.paths:
        try:
            original = path.read_text(encoding="utf-8")
        except OSError as error:
            print(f"{path}: {error}", file=sys.stderr)
            return 2

        updated, count = number_text(original, anchors=args.anchors, style=args.style)
        total_paragraphs += count

        if updated == original:
            print(f"{path}: à jour ({count} paragraphes)")
            continue

        changed_files += 1
        if args.check:
            print(f"{path}: à renuméroter ({count} paragraphes)")
        else:
            path.write_text(updated, encoding="utf-8")
            print(f"{path}: renuméroté ({count} paragraphes)")

    if args.check and changed_files:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
