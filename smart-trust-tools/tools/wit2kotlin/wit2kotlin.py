#!/usr/bin/env python3
"""Generate the Kotlin API skeleton from the WIT contract.

Reads api/wit/*.wit and writes Kotlin Multiplatform common code to
tools/hcert-kotlin/hcert-api/src/commonMain/kotlin/who/smart/trust/ using the mapping
rules in api/README.md:

    record -> data class        variant -> sealed interface
    enum -> enum class          resource -> interface : AutoCloseable
    option<T> -> T?             result<T, E> -> HcertResult<T, E>
    list<u8> -> ByteArray       list<T> -> List<T>
    tuple<A, B> -> Pair         s32/u8/u32 -> Int, s64 -> Long
    exported interface functions -> a Kotlin interface to implement
    imported interface -> a Kotlin interface the host implements

WIT is the contract's source, not part of the Kotlin API: nothing generated
names it, apart from each file's one-line provenance header. Worlds are not
generated. A world says what a WebAssembly component exports and imports,
which is the Rust build's business; a Kotlin caller depends on the library
and calls what it needs.

Only declarations are generated: no behaviour. Implementations live in
other modules and implement these interfaces.

Usage:
    python3 tools/wit2kotlin/wit2kotlin.py           regenerate
    python3 tools/wit2kotlin/wit2kotlin.py --check   fail if the skeleton is stale

Standard library only.
"""

import argparse
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
WIT_DIR = ROOT / "api" / "wit"
OUT_DIR = ROOT / "tools" / "hcert-kotlin" / "hcert-api" / "src" / "commonMain" / "kotlin" / "who" / "smart" / "trust"
BASE_PKG = "who.smart.trust"

KOTLIN_KEYWORDS = {
    "as", "break", "class", "continue", "do", "else", "false", "for", "fun", "if", "in", "interface",
    "is", "null", "object", "package", "return", "super", "this", "throw", "true", "try", "typealias",
    "typeof", "val", "var", "when", "while",
}
PRIMITIVES = {
    "bool": "Boolean", "s8": "Int", "s16": "Int", "s32": "Int", "u8": "Int", "u16": "Int", "u32": "Int",
    "s64": "Long", "u64": "Long", "f32": "Float", "f64": "Double", "char": "Char", "string": "String",
}


class WitError(Exception):
    pass


# ---------------------------------------------------------------------------
# Lexer and parser for the WIT subset used by api/wit
# ---------------------------------------------------------------------------

TOKEN = re.compile(r"""
    (?P<doc>///[^\n]*)
  | (?P<comment>//[^\n]*)
  | (?P<ws>\s+)
  | (?P<arrow>->)
  | (?P<foreign>[a-z][a-z0-9-]*:[a-z][a-z0-9-]*/[a-z][a-z0-9-]*(?:@[0-9][0-9A-Za-z.+-]*)?)
  | (?P<id>%?[a-z][a-z0-9]*(?:-[a-z0-9]+)*)
  | (?P<ver>@[0-9][0-9A-Za-z.+-]*)
  | (?P<punct>[{}()<>,:;=.*_])
""", re.X)


def lex(text, fname):
    toks, pos, doc = [], 0, []
    while pos < len(text):
        m = TOKEN.match(text, pos)
        if not m:
            raise WitError("%s: unexpected character %r at offset %d" % (fname, text[pos], pos))
        pos = m.end()
        kind = m.lastgroup
        if kind == "doc":
            doc.append(m.group()[3:].strip())
        elif kind in ("comment", "ws"):
            continue
        else:
            toks.append((kind, m.group().lstrip("%"), doc))
            doc = []
    return toks


class Parser:
    def __init__(self, toks, fname):
        self.t, self.i, self.fname = toks, 0, fname

    def peek(self, k=0):
        return self.t[self.i + k] if self.i + k < len(self.t) else (None, None, [])

    def next(self):
        tok = self.peek()
        self.i += 1
        return tok

    def expect(self, value):
        kind, val, doc = self.next()
        if val != value:
            raise WitError("%s: expected %r, got %r" % (self.fname, value, val))
        return doc

    def ident(self):
        kind, val, doc = self.next()
        if kind != "id":
            raise WitError("%s: expected identifier, got %r" % (self.fname, val))
        return val, doc

    def type(self):
        kind, val, _ = self.next()
        if val == "_":
            return ("unit",)
        if kind != "id":
            raise WitError("%s: expected type, got %r" % (self.fname, val))
        if self.peek()[1] == "<":
            self.next()
            args = [self.type()]
            while self.peek()[1] == ",":
                self.next()
                args.append(self.type())
            self.expect(">")
            return (val, *args)
        return (val,)

    def params(self):
        self.expect("(")
        out = []
        while self.peek()[1] != ")":
            name, _ = self.ident()
            self.expect(":")
            out.append((name, self.type()))
            if self.peek()[1] == ",":
                self.next()
        self.expect(")")
        return out

    def func_tail(self):
        params = self.params()
        ret = None
        if self.peek()[0] == "arrow":
            self.next()
            ret = self.type()
        self.expect(";")
        return params, ret

    def file(self):
        items = []
        while self.peek()[0] is not None:
            kind, val, doc = self.peek()
            if val == "package":
                while self.next()[1] != ";":
                    pass
            elif val == "interface":
                items.append(self.interface())
            elif val == "world":
                items.append(self.world())
            else:
                raise WitError("%s: unexpected %r at top level" % (self.fname, val))
        return items

    def interface(self):
        doc = self.expect("interface")
        name, _ = self.ident()
        self.expect("{")
        iface = {"kind": "interface", "name": name, "doc": doc, "uses": [], "types": [], "funcs": [], "file": self.fname}
        while self.peek()[1] != "}":
            kind, val, idoc = self.peek()
            if val == "use":
                self.next()
                src, _ = self.ident()
                self.expect(".")
                self.expect("{")
                names = []
                while self.peek()[1] != "}":
                    n, _ = self.ident()
                    names.append(n)
                    if self.peek()[1] == ",":
                        self.next()
                self.expect("}")
                self.expect(";")
                iface["uses"].append((src, names))
            elif val == "type":
                self.next()
                n, _ = self.ident()
                self.expect("=")
                t = self.type()
                self.expect(";")
                iface["types"].append({"kind": "alias", "name": n, "doc": idoc, "type": t})
            elif val in ("record", "enum", "variant", "flags"):
                iface["types"].append(self.compound(val, idoc))
            elif val == "resource":
                iface["types"].append(self.resource(idoc))
            elif kind == "id":
                n, _ = self.ident()
                self.expect(":")
                self.expect("func")
                params, ret = self.func_tail()
                iface["funcs"].append({"name": n, "doc": idoc, "params": params, "ret": ret})
            else:
                raise WitError("%s: unexpected %r in interface %s" % (self.fname, val, name))
        self.expect("}")
        return iface

    def compound(self, kind, doc):
        self.next()
        name, _ = self.ident()
        self.expect("{")
        members = []
        while self.peek()[1] != "}":
            mname, mdoc = self.ident()
            if kind == "record":
                self.expect(":")
                members.append({"name": mname, "doc": mdoc, "type": self.type()})
            elif kind == "variant" and self.peek()[1] == "(":
                self.next()
                t = self.type()
                self.expect(")")
                members.append({"name": mname, "doc": mdoc, "type": t})
            else:
                members.append({"name": mname, "doc": mdoc, "type": None})
            if self.peek()[1] == ",":
                self.next()
        self.expect("}")
        return {"kind": kind, "name": name, "doc": doc, "members": members}

    def resource(self, doc):
        self.next()
        name, _ = self.ident()
        res = {"kind": "resource", "name": name, "doc": doc, "ctor": None, "methods": [], "statics": []}
        if self.peek()[1] == ";":
            self.next()
            return res
        self.expect("{")
        while self.peek()[1] != "}":
            kind, val, mdoc = self.peek()
            if val == "constructor":
                self.next()
                params = self.params()
                self.expect(";")
                res["ctor"] = {"doc": mdoc, "params": params}
            else:
                n, _ = self.ident()
                self.expect(":")
                static = False
                if self.peek()[1] == "static":
                    self.next()
                    static = True
                self.expect("func")
                params, ret = self.func_tail()
                (res["statics"] if static else res["methods"]).append(
                    {"name": n, "doc": mdoc, "params": params, "ret": ret})
        self.expect("}")
        return res

    def world(self):
        doc = self.expect("world")
        name, _ = self.ident()
        self.expect("{")
        w = {"kind": "world", "name": name, "doc": doc, "imports": [], "exports": [], "includes": []}
        while self.peek()[1] != "}":
            kw, _ = self.ident()
            if self.peek()[0] == "foreign":
                # Another package's interface (wasi:random/random@0.2.6): the
                # component's host supplies it, and the JVM and Node have their
                # own, so Kotlin generates nothing for it.
                self.next()
                self.expect(";")
                continue
            target, _ = self.ident()
            self.expect(";")
            {"import": w["imports"], "export": w["exports"], "include": w["includes"]}[kw].append(target)
        self.expect("}")
        return w


# ---------------------------------------------------------------------------
# Kotlin generation
# ---------------------------------------------------------------------------

def pascal(name):
    return "".join(p[:1].upper() + p[1:] for p in name.split("-"))


def camel(name):
    p = pascal(name)
    return p[:1].lower() + p[1:]


def ident(name):
    n = camel(name)
    return "`%s`" % n if n in KOTLIN_KEYWORDS else n


def const(name):
    return name.replace("-", "_").upper()


def pkg(iface):
    return "%s.%s" % (BASE_PKG, iface.replace("-", ""))


def kdoc(lines, indent=""):
    lines = [l for l in lines]
    if not lines:
        return ""
    if len(lines) == 1:
        return "%s/** %s */\n" % (indent, lines[0])
    return indent + "/**\n" + "".join("%s * %s\n" % (indent, l) if l else "%s *\n" % indent for l in lines) + indent + " */\n"


class Gen:
    def __init__(self, ifaces, worlds):
        self.ifaces = {i["name"]: i for i in ifaces}
        self.worlds = worlds
        # type name -> (owning interface, declaration)
        self.owner = {}
        for i in ifaces:
            for t in i["types"]:
                self.owner[(i["name"], t["name"])] = t
        imported, exported = set(), set()
        for w in worlds:
            imported.update(w["imports"])
            exported.update(w["exports"])
        self.host_provided = imported - exported

    def resolve(self, iface, name):
        """Interface that declares `name` as seen from `iface` (own types or `use`d ones)."""
        if (iface["name"], name) in self.owner:
            return iface["name"]
        for src, names in iface["uses"]:
            if name in names:
                return self.resolve(self.ifaces[src], name)
        raise WitError("interface %s: unknown type %s" % (iface["name"], name))

    def kt(self, iface, t, imports):
        head = t[0]
        if head == "unit":
            return "Unit"
        if head in PRIMITIVES:
            return PRIMITIVES[head]
        if head == "list":
            if t[1] == ("u8",):
                return "ByteArray"
            return "List<%s>" % self.kt(iface, t[1], imports)
        if head == "option":
            return "%s?" % self.kt(iface, t[1], imports)
        if head == "result":
            ok = self.kt(iface, t[1], imports) if len(t) > 1 else "Unit"
            err = self.kt(iface, t[2], imports) if len(t) > 2 else "Unit"
            imports.add("%s.HcertResult" % BASE_PKG)
            return "HcertResult<%s, %s>" % (ok, err)
        if head == "tuple":
            parts = [self.kt(iface, x, imports) for x in t[1:]]
            if len(parts) == 2:
                return "Pair<%s>" % ", ".join(parts)
            if len(parts) == 3:
                return "Triple<%s>" % ", ".join(parts)
            raise WitError("tuple of %d elements has no Kotlin mapping" % len(parts))
        if head in ("borrow", "own"):
            return self.kt(iface, t[1], imports)
        owner = self.resolve(iface, head)
        if owner != iface["name"]:
            imports.add("%s.%s" % (pkg(owner), pascal(head)))
        return pascal(head)

    def params(self, iface, params, imports):
        return ", ".join("%s: %s" % (ident(n), self.kt(iface, t, imports)) for n, t in params)

    def ret(self, iface, ret, imports):
        return "" if ret is None else ": %s" % self.kt(iface, ret, imports)

    def type_decl(self, iface, t, imports):
        name = pascal(t["name"])
        out = kdoc(t["doc"])
        if t["kind"] == "alias":
            return out + "typealias %s = %s\n" % (name, self.kt(iface, t["type"], imports))
        if t["kind"] == "enum":
            cases = []
            for m in t["members"]:
                cases.append(kdoc(m["doc"], "    ") + "    %s" % const(m["name"]))
            return out + "enum class %s {\n%s,\n}\n" % (name, ",\n".join(cases))
        if t["kind"] == "flags":
            cases = [kdoc(m["doc"], "    ") + "    %s" % const(m["name"]) for m in t["members"]]
            return out + "enum class %s {\n%s,\n}\n\ntypealias %sSet = Set<%s>\n" % (name, ",\n".join(cases), name, name)
        if t["kind"] == "record":
            fields = []
            for m in t["members"]:
                ty = self.kt(iface, m["type"], imports)
                default = " = null" if ty.endswith("?") else ""
                fields.append(kdoc(m["doc"], "    ") + "    val %s: %s%s," % (ident(m["name"]), ty, default))
            return out + "data class %s(\n%s\n)\n" % (name, "\n".join(fields))
        if t["kind"] == "variant":
            cases = []
            cnames = {pascal(m["name"]) for m in t["members"]}
            for m in t["members"]:
                cname = pascal(m["name"])
                d = kdoc(m["doc"], "    ")
                if m["type"] is None:
                    cases.append(d + "    data object %s : %s" % (cname, name))
                else:
                    ty = self.kt(iface, m["type"], imports)
                    # Inside the sealed interface a case name shadows a type of the
                    # same name (case dvc-min carrying record dvc-min), so qualify it.
                    def qualify(match):
                        simple = match.group(0)
                        if simple not in cnames:
                            return simple
                        imported = [i for i in imports if i.endswith("." + simple)]
                        return imported[0] if imported else "%s.%s" % (pkg(iface), simple)
                    ty = re.sub(r"\b[A-Z][A-Za-z0-9]*\b", qualify, ty)
                    cases.append(d + "    data class %s(val value: %s) : %s" % (cname, ty, name))
            return out + "sealed interface %s {\n%s\n}\n" % (name, "\n\n".join(cases))
        if t["kind"] == "resource":
            methods = []
            for f in t["methods"]:
                methods.append(kdoc(f["doc"], "    ") + "    fun %s(%s)%s" % (
                    ident(f["name"]), self.params(iface, f["params"], imports), self.ret(iface, f["ret"], imports)))
            body = "\n\n".join(methods)
            return out + "interface %s : AutoCloseable {\n%s\n}\n" % (name, body)
        raise WitError("unsupported type kind %s" % t["kind"])

    def service(self, iface, imports):
        """Kotlin interface holding the WIT interface's functions and resource constructors."""
        members = []
        for f in iface["funcs"]:
            members.append(kdoc(f["doc"], "    ") + "    fun %s(%s)%s" % (
                ident(f["name"]), self.params(iface, f["params"], imports), self.ret(iface, f["ret"], imports)))
        for t in iface["types"]:
            if t["kind"] != "resource":
                continue
            if t["ctor"] is not None:
                doc = t["ctor"]["doc"] or ["Creates a new [%s]." % pascal(t["name"])]
                members.append(kdoc(doc, "    ") + "    fun new%s(%s): %s" % (
                    pascal(t["name"]), self.params(iface, t["ctor"]["params"], imports), pascal(t["name"])))
            for f in t["statics"]:
                members.append(kdoc(f["doc"], "    ") + "    fun %s%s(%s)%s" % (
                    camel(t["name"]), pascal(f["name"]), self.params(iface, f["params"], imports),
                    self.ret(iface, f["ret"], imports)))
        if not members:
            return ""
        role = ("Implemented by the host application and passed to the library."
                if iface["name"] in self.host_provided else
                "Implemented by the library.")
        doc = list(iface["doc"]) + ([""] if iface["doc"] else []) + [role]
        return kdoc(doc) + "interface %s {\n%s\n}\n" % (pascal(iface["name"]), "\n\n".join(members))

    def interface_file(self, iface):
        imports = set()
        decls = [self.type_decl(iface, t, imports) for t in iface["types"]]
        svc = self.service(iface, imports)
        if svc:
            decls.append(svc)
        header = ("// GENERATED by tools/wit2kotlin/wit2kotlin.py from api/wit/%s (interface %s). Do not edit.\n"
                  "package %s\n\n") % (iface["file"], iface["name"], pkg(iface["name"]))
        imps = "".join("import %s\n" % i for i in sorted(imports) if not i.startswith(pkg(iface["name"]) + "."))
        return header + (imps + "\n" if imps else "") + "\n".join(decls)

    def has_service(self, name):
        i = self.ifaces[name]
        return bool(i["funcs"]) or any(t["kind"] == "resource" and (t["ctor"] or t["statics"]) for t in i["types"])


RUNTIME = '''// GENERATED by tools/wit2kotlin/wit2kotlin.py. Do not edit.
package who.smart.trust

/**
 * The outcome of a call that can fail in an expected way: the value, or an
 * error saying which step failed and why.
 *
 * Expected failures are values, not exceptions [STT-VER-008], so the JVM and
 * Android API returns this instead of throwing. Kotlin's own `Result` cannot
 * carry a typed error, hence this type. The Kotlin/JS facade may throw, to keep
 * one TypeScript surface [STT-GEN-011].
 */
sealed interface HcertResult<out T, out E> {
    data class Ok<out T>(val value: T) : HcertResult<T, Nothing>

    data class Err<out E>(val error: E) : HcertResult<Nothing, E>
}

inline fun <T, E, R> HcertResult<T, E>.fold(onOk: (T) -> R, onErr: (E) -> R): R = when (this) {
    is HcertResult.Ok -> onOk(value)
    is HcertResult.Err -> onErr(error)
}

fun <T, E> HcertResult<T, E>.getOrNull(): T? = (this as? HcertResult.Ok)?.value
'''


def generate():
    ifaces, worlds = [], []
    for path in sorted(WIT_DIR.glob("*.wit")):
        for item in Parser(lex(path.read_text(), path.name), path.name).file():
            (worlds if item["kind"] == "world" else ifaces).append(item)
    g = Gen(ifaces, worlds)
    files = {"HcertResult.kt": RUNTIME}
    for i in ifaces:
        files["%s/%s.kt" % (i["name"].replace("-", ""), pascal(i["name"]))] = g.interface_file(i)
    return files


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    try:
        files = generate()
    except WitError as e:
        print("wit2kotlin: %s" % e, file=sys.stderr)
        return 1
    if args.check:
        existing = {p.relative_to(OUT_DIR).as_posix() for p in OUT_DIR.rglob("*.kt")} if OUT_DIR.exists() else set()
        stale = [n for n, c in files.items() if not (OUT_DIR / n).exists() or (OUT_DIR / n).read_text() != c]
        extra = sorted(existing - set(files))
        if stale or extra:
            print("stale Kotlin skeleton: %s (run tools/wit2kotlin/wit2kotlin.py)" % ", ".join(stale + extra), file=sys.stderr)
            return 1
        print("Kotlin skeleton is up to date")
        return 0
    if OUT_DIR.exists():
        for p in OUT_DIR.rglob("*.kt"):
            p.unlink()
    for name, content in files.items():
        path = OUT_DIR / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
    print("wrote %d Kotlin files to %s" % (len(files), OUT_DIR.relative_to(ROOT)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
