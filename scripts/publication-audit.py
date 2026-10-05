#!/usr/bin/env python3
"""Redacted publication checks over Git-selected files and document contents.

This is a focused hygiene check, not a substitute for a credential scanner.
It never emits matching text. Ignored files and the macOS Keychain are outside
its scope. Run Gitleaks separately for provider rules and reachable history.
"""

from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
import io
import json
from pathlib import Path
import re
import shutil
import subprocess
import zipfile


# Escape the word list so the scanner's own source does not trigger itself.
PROFANITY = re.compile(
    r"\b(?:\u0066uck(?:ing|er|ers|ed|s)?|mother\u0066uck(?:er|ers|ing)?|"
    r"bull\u0073hit|\u0073hit(?:ty|ting|s)?|\u0061sshole(?:s)?|"
    r"\u0062itch(?:es|ing)?|\u0063unt(?:s)?|(?:god)?\u0064amn(?:ed)?|"
    r"\u0062astard(?:s)?|\u0070iss(?:ed|ing)?|\u0064ick(?:s|head(?:s)?)?|"
    r"\u0077tf|\u0073tfu)\b",
    re.IGNORECASE,
)
RULES = {
    "profanity": PROFANITY,
    "private_key_material": re.compile(
        r"-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----"
    ),
    "provider_credential_candidate": re.compile(
        r"\b(?:sk-(?:proj-|svcacct-)?[A-Za-z0-9_-]{24,}|"
        r"gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|"
        r"xox[baprs]-[A-Za-z0-9-]{20,}|AKIA[A-Z0-9]{16})\b"
    ),
    # Google browser/site keys require contextual review, not automatic rotation.
    "google_key_candidate_review_context": re.compile(r"\bAIza[0-9A-Za-z_-]{35}\b"),
    "personal_home_path": re.compile(
        r"(?:/Users/|/home/|[A-Za-z]:\\Users\\)(?!<|\$|\{|USER\b|user\b|"
        r"runner\b|username\b|example\b)[A-Za-z0-9_.-]+"
    ),
}
ARCHIVE_TEXT_SUFFIXES = {".xml", ".rels", ".txt", ".json", ".md", ".svg", ".csv", ".html"}
MAX_ARCHIVE_DEPTH = 3


def git(root: Path, *args: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(root), *args])


def audit(root: Path, include_untracked: bool) -> dict:
    command = ["ls-files", "-z", "--cached"]
    if include_untracked:
        command.extend(["--others", "--exclude-standard"])
    paths = sorted(set(p.decode("utf-8") for p in git(root, *command).split(b"\0") if p))
    counts: Counter = Counter()
    findings = []
    limitations = []
    pdf_tools = {name: shutil.which(name) for name in ("pdfinfo", "pdftotext")}

    def inspect_text(name: str, content: str, kind: str) -> None:
        counts[kind] += 1
        for category, pattern in RULES.items():
            for match in pattern.finditer(content):
                findings.append({
                    "category": category,
                    "path": name,
                    "line": content.count("\n", 0, match.start()) + 1,
                })

    def inspect_archive(name: str, data: bytes, depth: int = 1) -> None:
        counts["archives"] += 1
        try:
            with zipfile.ZipFile(io.BytesIO(data)) as archive:
                for member in archive.infolist():
                    if member.is_dir():
                        continue
                    suffix = Path(member.filename).suffix.lower()
                    if suffix not in ARCHIVE_TEXT_SUFFIXES | {".zip", ".pptx", ".potx", ".docx", ".xlsx"}:
                        continue
                    member_name = f"{name}!{member.filename}"
                    if member.file_size > 32 * 1024 * 1024:
                        limitations.append({"path": member_name, "reason": "archive member exceeds 32 MiB"})
                        continue
                    member_data = archive.read(member)
                    if suffix in ARCHIVE_TEXT_SUFFIXES:
                        try:
                            decoded = member_data.decode("utf-8-sig")
                        except UnicodeDecodeError:
                            limitations.append({"path": member_name, "reason": "archive text is not UTF-8"})
                        else:
                            inspect_text(member_name, decoded, "archive_text_members")
                    elif depth < MAX_ARCHIVE_DEPTH:
                        inspect_archive(member_name, member_data, depth + 1)
                    else:
                        limitations.append({"path": member_name, "reason": "nested archive depth limit"})
        except (zipfile.BadZipFile, RuntimeError, OSError):
            limitations.append({"path": name, "reason": "archive could not be read"})

    for name in paths:
        path = root / name
        if path.is_symlink():
            limitations.append({"path": name, "reason": "symlink not followed"})
            continue
        if not path.is_file():
            counts["deleted_or_nonregular_paths"] += 1
            continue
        counts["files"] += 1
        data = path.read_bytes()
        if zipfile.is_zipfile(io.BytesIO(data)):
            inspect_archive(name, data)
        elif path.suffix.lower() == ".pdf":
            counts["pdfs"] += 1
            for tool_name, tool_path in pdf_tools.items():
                if not tool_path:
                    limitations.append({"path": name, "reason": f"{tool_name} unavailable"})
                    continue
                args = [tool_path, str(path)] if tool_name == "pdfinfo" else [tool_path, "-enc", "UTF-8", str(path), "-"]
                result = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, check=False)
                if result.returncode:
                    limitations.append({"path": name, "reason": f"{tool_name} failed"})
                else:
                    inspect_text(f"{name}!{tool_name}", result.stdout.decode("utf-8", "replace"), "pdf_extractions")
        else:
            try:
                content = data.decode("utf-8-sig")
            except UnicodeDecodeError:
                counts["other_binary_files"] += 1
                continue
            if "\0" in content:
                counts["other_binary_files"] += 1
                continue
            inspect_text(name, content, "text_files")

    return {
        "schema_version": 1,
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "base_commit": git(root, "rev-parse", "HEAD").decode().strip(),
        "scope": "Git tracked working-tree files" + (" and nonignored untracked files" if include_untracked else ""),
        "counts": dict(sorted(counts.items())),
        "finding_counts": dict(sorted(Counter(f["category"] for f in findings).items())),
        "findings": findings,
        "limitations": limitations,
        "boundaries": [
            "Findings are candidates requiring contextual review; matching text is never emitted.",
            "Ignored files, Keychain entries and Git history are not read.",
            "Binary image, audio, video and font content is not inspected.",
            "PDF metadata and extracted text are inspected; pixels are not OCRed.",
            "No scan establishes the absence of all possible secrets or offensive language.",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--include-untracked", action="store_true", help="include nonignored files prepared for the release")
    parser.add_argument("--output", type=Path, help="write the same redacted JSON report to this path")
    args = parser.parse_args()
    report = audit(args.repo.resolve(), args.include_untracked)
    encoded = json.dumps(report, indent=2, ensure_ascii=False) + "\n"
    if args.output:
        args.output.write_text(encoded)
    print(encoded, end="")
    return 1 if report["findings"] or report["limitations"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
