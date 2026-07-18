#!/usr/bin/env python3
"""Mechanically extract python-pptx's oxml schema knowledge into a JSON table.

Walks every module under `src/pptx/oxml/` of a python-pptx checkout, parses the
Python AST (stdlib only -- python-pptx is never imported, so lxml need not be
installed), and collects every `BaseOxmlElement` subclass carrying xmlchemy
descriptor declarations:

  - RequiredAttribute / OptionalAttribute  (python prop name, XML attr name,
    simple-type name, declared default resolved to its XML lexical form)
  - OneAndOnlyOne / ZeroOrOne / ZeroOrMore / OneOrMore  (child tag,
    cardinality, successors tuple)
  - ZeroOrOneChoice  (member child tags via Choice(...), group successors)

plus the element-tag registrations from `oxml/__init__.py`
(`register_element_cls("p:presentation", CT_Presentation)`).

Declarations are inheritance-flattened: a class entry lists the *effective*
declarations it carries at runtime (own declarations override inherited ones by
python property name), because that is what lxml sees after MetaOxmlElement
runs. Nothing here is retyped by hand -- every tag, attribute name, simple-type
name, successor list and default comes out of python-pptx's own source.

Usage:
    python3 Tools/extract-schema.py <path-to-python-pptx>/src/pptx [out.json]

Default output: Tools/tables/oxml-schema.json (next to this script).
Output is deterministic (sorted keys) so regeneration diffs cleanly; successor
lists keep their declared order because that order is the insertion semantic.
"""

from __future__ import annotations

import ast
import json
import sys
from pathlib import Path

CHILD_DESCRIPTORS = {"OneAndOnlyOne", "ZeroOrOne", "ZeroOrMore", "OneOrMore"}
ATTR_DESCRIPTORS = {"RequiredAttribute", "OptionalAttribute"}
CHOICE_GROUP = "ZeroOrOneChoice"
ALL_DESCRIPTORS = CHILD_DESCRIPTORS | ATTR_DESCRIPTORS | {CHOICE_GROUP}


def fail(msg: str) -> None:
    raise SystemExit(f"extract-schema: FATAL: {msg}")


# --------------------------------------------------------------------------- #
# successor-tuple evaluation                                                  #
# --------------------------------------------------------------------------- #


def eval_tag_tuple(node: ast.expr, env: dict, where: str) -> list[str]:
    """Evaluate a successors/tag-sequence expression to a list of tag strings.

    Handles the only shapes that occur in python-pptx source: literal tuples of
    string constants, names bound to such tuples earlier in the class body
    (`_tag_seq`), and open-ended slices of those (`_tag_seq[3:]`).
    """
    if isinstance(node, (ast.Tuple, ast.List)):
        out = []
        for elt in node.elts:
            if not (isinstance(elt, ast.Constant) and isinstance(elt.value, str)):
                fail(f"{where}: non-string element in tag tuple")
            out.append(elt.value)
        return out
    if isinstance(node, ast.Name):
        if node.id not in env:
            fail(f"{where}: unknown tag-sequence name {node.id!r}")
        return list(env[node.id])
    if isinstance(node, ast.Subscript) and isinstance(node.value, ast.Name):
        seq = eval_tag_tuple(node.value, env, where)
        sl = node.slice
        if not isinstance(sl, ast.Slice):
            fail(f"{where}: non-slice subscript of tag sequence")
        def bound(b):
            if b is None:
                return None
            if isinstance(b, ast.Constant) and isinstance(b.value, int):
                return b.value
            fail(f"{where}: non-constant slice bound")
        if sl.step is not None:
            fail(f"{where}: stepped slice of tag sequence")
        return seq[bound(sl.lower) : bound(sl.upper)]
    fail(f"{where}: unsupported successors expression {ast.dump(node)}")


# --------------------------------------------------------------------------- #
# simple-type and enum knowledge (for resolving defaults to XML strings)      #
# --------------------------------------------------------------------------- #


class SimpleTypes:
    """Class hierarchy + string constants of pptx/oxml/simpletypes.py."""

    def __init__(self, simpletypes_path: Path):
        tree = ast.parse(simpletypes_path.read_text())
        self.bases: dict[str, list[str]] = {}
        self.constants: dict[str, dict[str, str]] = {}
        self.defines_to_xml: set[str] = set()
        for node in tree.body:
            if not isinstance(node, ast.ClassDef):
                continue
            self.bases[node.name] = [b.id for b in node.bases if isinstance(b, ast.Name)]
            consts: dict[str, str] = {}
            for stmt in node.body:
                if (
                    isinstance(stmt, ast.Assign)
                    and len(stmt.targets) == 1
                    and isinstance(stmt.targets[0], ast.Name)
                    and isinstance(stmt.value, ast.Constant)
                    and isinstance(stmt.value.value, str)
                ):
                    consts[stmt.targets[0].id] = stmt.value.value
                if isinstance(stmt, ast.FunctionDef) and stmt.name == "convert_to_xml":
                    self.defines_to_xml.add(node.name)
            self.constants[node.name] = consts

    def to_xml_owner(self, st_name: str) -> str | None:
        """Nearest class in `st_name`'s base chain defining convert_to_xml."""
        seen = set()
        queue = [st_name]
        while queue:
            name = queue.pop(0)
            if name in seen:
                continue
            seen.add(name)
            if name in self.defines_to_xml:
                return name
            queue.extend(self.bases.get(name, []))
        return None


# Mechanical transcriptions of the convert_to_xml implementations in
# pptx/oxml/simpletypes.py, keyed by the class that defines each one. These are
# conversion *semantics* (which Rostrum needs natively anyway), not schema
# data; every tag/attr/default *value* still comes from the AST. Unknown
# combinations fail loudly rather than guess.
TO_XML_IMPLS = {
    "BaseIntType": lambda v: str(int(v)),
    "BaseFloatType": lambda v: str(float(v)),
    "BaseStringType": lambda v: str(v),
    "XsdBoolean": lambda v: {True: "1", False: "0"}[v],
    "ST_Percentage": lambda v: str(int(round(v * 100000.0))),
    "ST_Angle": lambda v: str(int(round(v * 60000)) % (360 * 60000)),
    "ST_PositiveFixedAngle": lambda v: str(int(round(v * 60000)) % (360 * 60000)),
    "ST_Coordinate": lambda v: str(int(v)),
    "ST_Coordinate32": lambda v: str(int(v)),
    "ST_HexColorRGB": lambda v: str(v).upper(),
    "ST_TextFontScalePercentOrPercentString": lambda v: str(int(v * 1000.0)),
    "ST_TextSpacingPercentOrPercentString": lambda v: str(int(round(v * 100000.0))),
}


def load_enum_xml_values(enum_dir: Path) -> dict[str, dict[str, str]]:
    """Map enum class name -> member name -> XML attribute value.

    Members of BaseXmlEnum subclasses are 3-tuples (ms_api_value, xml_value,
    docstring); module-level `ALIAS = REAL_NAME` assignments are followed.
    """
    tables: dict[str, dict[str, str]] = {}
    aliases: dict[str, str] = {}
    for path in sorted(enum_dir.glob("*.py")):
        tree = ast.parse(path.read_text())
        for node in tree.body:
            if isinstance(node, ast.ClassDef):
                members: dict[str, str] = {}
                for stmt in node.body:
                    if not (
                        isinstance(stmt, ast.Assign)
                        and len(stmt.targets) == 1
                        and isinstance(stmt.targets[0], ast.Name)
                        and isinstance(stmt.value, ast.Tuple)
                        and len(stmt.value.elts) == 3
                    ):
                        continue
                    xml = stmt.value.elts[1]
                    if isinstance(xml, ast.Constant) and isinstance(xml.value, str):
                        members[stmt.targets[0].id] = xml.value
                if members:
                    tables[node.name] = members
            elif (
                isinstance(node, ast.Assign)
                and len(node.targets) == 1
                and isinstance(node.targets[0], ast.Name)
                and isinstance(node.value, ast.Name)
            ):
                aliases[node.targets[0].id] = node.value.id
    for alias, real in aliases.items():
        if real in tables:
            tables.setdefault(alias, tables[real])
    return tables


def resolve_default(
    node: ast.expr,
    simple_type: str,
    simpletypes: SimpleTypes,
    enums: dict[str, dict[str, str]],
    where: str,
) -> str | None:
    """Resolve a declared `default=` expression to its XML lexical string.

    Returns None for an explicit `default=None` (i.e. no default).
    """
    def convert(value):
        owner = simpletypes.to_xml_owner(simple_type)
        if owner is None and simple_type in enums:
            fail(f"{where}: plain value default for enum simple-type {simple_type}")
        impl = TO_XML_IMPLS.get(owner or "")
        if impl is None:
            fail(f"{where}: no convert_to_xml rule for {simple_type} (owner {owner})")
        return impl(value)

    if isinstance(node, ast.Constant):
        if node.value is None:
            return None
        return convert(node.value)
    if (
        isinstance(node, ast.Call)
        and isinstance(node.func, ast.Name)
        and node.func.id in ("Emu", "Centipoints", "Pt")
        and len(node.args) == 1
        and isinstance(node.args[0], ast.Constant)
    ):
        # Length subclasses are int subclasses; Emu(91440) is the int 91440.
        if node.func.id != "Emu":
            fail(f"{where}: unhandled length constructor {node.func.id}")
        return convert(node.args[0].value)
    if isinstance(node, ast.Attribute) and isinstance(node.value, ast.Name):
        owner, member = node.value.id, node.attr
        if owner in enums:
            if member not in enums[owner]:
                fail(f"{where}: {owner}.{member} has no XML value")
            return enums[owner][member]
        consts = simpletypes.constants.get(owner, {})
        if member in consts:
            return consts[member]
        fail(f"{where}: unresolvable default {owner}.{member}")
    fail(f"{where}: unsupported default expression {ast.dump(node)}")


# --------------------------------------------------------------------------- #
# oxml class extraction                                                       #
# --------------------------------------------------------------------------- #


def parse_descriptor(call: ast.Call, env: dict, where: str) -> dict | None:
    """Return a declaration dict for one descriptor constructor call."""
    name = call.func.id  # type: ignore[union-attr]
    args = call.args
    kwargs = {kw.arg: kw.value for kw in call.keywords if kw.arg}

    def const_str(node, what):
        if isinstance(node, ast.Constant) and isinstance(node.value, str):
            return node.value
        fail(f"{where}: expected string constant for {what}")

    if name in ATTR_DESCRIPTORS:
        decl = {
            "kind": "attribute",
            "required": name == "RequiredAttribute",
            "xml_name": const_str(args[0], "attr name"),
        }
        st = args[1] if len(args) > 1 else kwargs.get("simple_type")
        if not isinstance(st, ast.Name):
            fail(f"{where}: simple_type is not a plain name")
        decl["simple_type"] = st.id
        default = args[2] if len(args) > 2 else kwargs.get("default")
        if name == "RequiredAttribute" and default is not None:
            fail(f"{where}: RequiredAttribute with a default")
        decl["default_node"] = default  # resolved later (needs enum tables)
        return decl

    if name in CHILD_DESCRIPTORS:
        tag = const_str(args[0], "child tag")
        if name == "OneAndOnlyOne":
            if len(args) > 1 or kwargs:
                fail(f"{where}: OneAndOnlyOne takes only a tag")
            successors: list[str] = []
        else:
            succ_node = args[1] if len(args) > 1 else kwargs.get("successors")
            successors = [] if succ_node is None else eval_tag_tuple(succ_node, env, where)
        return {"kind": "child", "cardinality": name, "tag": tag, "successors": successors}

    if name == CHOICE_GROUP:
        choices_node = args[0] if args else kwargs.get("choices")
        if not isinstance(choices_node, (ast.Tuple, ast.List)):
            fail(f"{where}: ZeroOrOneChoice choices is not a tuple")
        choices = []
        for elt in choices_node.elts:
            if not (
                isinstance(elt, ast.Call)
                and isinstance(elt.func, ast.Name)
                and elt.func.id == "Choice"
                and len(elt.args) == 1
                and not elt.keywords
            ):
                fail(f"{where}: unsupported Choice member {ast.dump(elt)}")
            choices.append(const_str(elt.args[0], "choice tag"))
        succ_node = args[1] if len(args) > 1 else kwargs.get("successors")
        successors = [] if succ_node is None else eval_tag_tuple(succ_node, env, where)
        return {
            "kind": "choiceGroup",
            "cardinality": "ZeroOrOneChoice",
            "choices": choices,
            "successors": successors,
        }

    return None


def extract_classes(oxml_dir: Path) -> dict[str, dict]:
    """name -> {module, bases, decls: {prop_name: decl}} for every class."""
    classes: dict[str, dict] = {}
    for path in sorted(oxml_dir.rglob("*.py")):
        if "__pycache__" in path.parts:
            continue
        rel_module = ".".join(path.relative_to(oxml_dir).with_suffix("").parts)
        tree = ast.parse(path.read_text())
        module_env: dict[str, list[str]] = {}
        for node in tree.body:
            if not isinstance(node, ast.ClassDef):
                continue
            if node.name in classes:
                fail(f"duplicate class name {node.name} in {rel_module}")
            env = dict(module_env)
            decls: dict[str, dict] = {}
            for stmt in node.body:
                where = f"{rel_module}:{stmt.lineno} {node.name}"
                if isinstance(stmt, ast.Assign) and len(stmt.targets) == 1:
                    target, value = stmt.targets[0], stmt.value
                elif isinstance(stmt, ast.AnnAssign) and stmt.value is not None:
                    target, value = stmt.target, stmt.value
                else:
                    continue
                if not isinstance(target, ast.Name):
                    continue
                if isinstance(value, (ast.Tuple, ast.List)) and all(
                    isinstance(e, ast.Constant) and isinstance(e.value, str)
                    for e in value.elts
                ):
                    env[target.id] = [e.value for e in value.elts]  # type: ignore[misc]
                    continue
                if not isinstance(value, ast.Call):
                    continue
                func = value.func
                if isinstance(func, ast.Attribute) and func.attr in ALL_DESCRIPTORS:
                    fail(f"{where}: qualified descriptor call not supported")
                if not (isinstance(func, ast.Name) and func.id in ALL_DESCRIPTORS):
                    continue
                decl = parse_descriptor(value, env, where)
                if decl is not None:
                    decl["where"] = where
                    decls[target.id] = decl
            classes[node.name] = {
                "module": rel_module,
                "bases": [b.id for b in node.bases if isinstance(b, ast.Name)],
                "decls": decls,
            }
    return classes


def effective_decls(name: str, classes: dict[str, dict]) -> dict[str, dict]:
    """Inheritance-flattened declarations: own decls override base decls."""
    merged: dict[str, dict] = {}
    for base in classes[name]["bases"]:
        if base in classes:
            merged.update(effective_decls(base, classes))
    merged.update(classes[name]["decls"])
    return merged


def extract_registrations(init_path: Path, classes: dict[str, dict]) -> dict[str, str]:
    tags: dict[str, str] = {}
    tree = ast.parse(init_path.read_text())
    for node in ast.walk(tree):
        if not (
            isinstance(node, ast.Call)
            and isinstance(node.func, ast.Name)
            and node.func.id == "register_element_cls"
        ):
            continue
        if len(node.args) != 2:
            fail(f"__init__.py:{node.lineno}: register_element_cls arg count")
        tag_node, cls_node = node.args
        if not (isinstance(tag_node, ast.Constant) and isinstance(tag_node.value, str)):
            fail(f"__init__.py:{node.lineno}: non-constant tag")
        if not isinstance(cls_node, ast.Name):
            fail(f"__init__.py:{node.lineno}: non-name class")
        tag, cls = tag_node.value, cls_node.id
        if cls not in classes:
            fail(f"__init__.py:{node.lineno}: unknown class {cls} for tag {tag}")
        if tag in tags and tags[tag] != cls:
            fail(f"tag {tag} registered for both {tags[tag]} and {cls}")
        tags[tag] = cls
    return tags


# --------------------------------------------------------------------------- #
# main                                                                        #
# --------------------------------------------------------------------------- #


def main(argv: list[str]) -> None:
    if len(argv) < 2:
        fail("usage: extract-schema.py <python-pptx>/src/pptx [out.json]")
    pptx_dir = Path(argv[1]).resolve()
    oxml_dir = pptx_dir / "oxml"
    enum_dir = pptx_dir / "enum"
    if not oxml_dir.is_dir():
        fail(f"{oxml_dir} is not a directory (pass .../src/pptx)")
    out_path = (
        Path(argv[2]).resolve()
        if len(argv) > 2
        else Path(__file__).resolve().parent / "tables" / "oxml-schema.json"
    )

    simpletypes = SimpleTypes(oxml_dir / "simpletypes.py")
    enums = load_enum_xml_values(enum_dir)
    classes = extract_classes(oxml_dir)
    tags = extract_registrations(oxml_dir / "__init__.py", classes)

    # Assemble JSON: per-class effective declarations, plus the tag map.
    out_classes: dict[str, dict] = {}
    for name in sorted(classes):
        info = classes[name]
        decls = effective_decls(name, classes)
        if not decls and name not in tags.values():
            continue  # helper/base class with nothing declared and no tag
        attributes: dict[str, dict] = {}
        children: dict[str, dict] = {}
        choice_groups: dict[str, dict] = {}
        for prop in sorted(decls):
            d = decls[prop]
            where = d["where"]
            if d["kind"] == "attribute":
                entry = {
                    "property": prop,
                    "required": d["required"],
                    "simple_type": d["simple_type"],
                }
                if d["default_node"] is not None:
                    default = resolve_default(
                        d["default_node"], d["simple_type"], simpletypes, enums, where
                    )
                    if default is not None:
                        entry["default"] = default
                if d["xml_name"] in attributes:
                    fail(f"{where}: duplicate xml attribute {d['xml_name']}")
                attributes[d["xml_name"]] = entry
            elif d["kind"] == "child":
                if d["tag"] in children:
                    fail(f"{where}: duplicate child tag {d['tag']}")
                children[d["tag"]] = {
                    "property": prop,
                    "cardinality": d["cardinality"],
                    "successors": d["successors"],
                }
            else:
                choice_groups[prop] = {
                    "cardinality": "ZeroOrOneChoice",
                    "choices": d["choices"],
                    "successors": d["successors"],
                }
        out_classes[name] = {
            "module": f"pptx.oxml.{info['module']}",
            "bases": info["bases"],
            "attributes": attributes,
            "children": children,
            "choiceGroups": choice_groups,
        }

    known_tags = set(tags)
    for c in out_classes.values():
        known_tags.update(c["children"])
        for child in c["children"].values():
            known_tags.update(child["successors"])
        for grp in c["choiceGroups"].values():
            known_tags.update(grp["choices"])
            known_tags.update(grp["successors"])

    doc = {
        "meta": {
            "extractor": "Tools/extract-schema.py",
            "source": "python-pptx src/pptx/oxml xmlchemy descriptor declarations",
            "note": (
                "Mechanically extracted; do not edit. Class declarations are "
                "inheritance-flattened (effective at runtime). Successor lists "
                "preserve declared order; all mappings are sorted by key."
            ),
            "counts": {
                "classes": len(out_classes),
                "registered_tags": len(tags),
                "known_tags": len(known_tags),
            },
        },
        "classes": out_classes,
        "tags": dict(sorted(tags.items())),
    }
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(doc, indent=2, sort_keys=True) + "\n")
    print(
        f"extract-schema: {len(out_classes)} classes, {len(tags)} registered tags, "
        f"{len(known_tags)} known tags -> {out_path}"
    )


if __name__ == "__main__":
    main(sys.argv)
