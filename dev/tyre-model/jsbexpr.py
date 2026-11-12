"""Compile Python-style arithmetic into JSBSim <function> XML.

The tyre model is a few dozen equations per wheel. Written directly as nested
JSBSim XML they are unreadable, so generate.py keeps them as one-line
expressions and this module turns each one into an <fcs_function>.

Supported: + - * /, unary minus, numbers, names (resolved to properties by the
caller) and the functions listed in CALLS.
"""
import ast

BINOPS = {ast.Add: "sum", ast.Sub: "difference", ast.Mult: "product", ast.Div: "quotient"}

# expression name -> JSBSim element
CALLS = {
    "abs": "abs", "sin": "sin", "cos": "cos", "atan": "atan", "sqrt": "sqrt",
    "pow": "pow", "min": "min", "max": "max", "ifthen": "ifthen", "lt": "lt",
}

INDENT = "\t"


class ExprError(ValueError):
    pass


def _number(value):
    return repr(float(value))


def _xml(node, resolve, depth):
    pad = INDENT * depth
    if isinstance(node, ast.Constant):
        if isinstance(node.value, bool) or not isinstance(node.value, (int, float)):
            raise ExprError("unsupported constant %r" % (node.value,))
        return "%s<v>%s</v>\n" % (pad, _number(node.value))
    if isinstance(node, ast.Name):
        return "%s<p>%s</p>\n" % (pad, resolve(node.id))
    if isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.USub):
        if isinstance(node.operand, ast.Constant):
            return "%s<v>%s</v>\n" % (pad, _number(-node.operand.value))
        inner = _xml(node.operand, resolve, depth + 1)
        return "%s<product>\n%s%s<v>-1.0</v>\n%s%s</product>\n" % (pad, pad, INDENT, inner, pad)
    if isinstance(node, ast.BinOp) and type(node.op) in BINOPS:
        tag = BINOPS[type(node.op)]
        if tag in ("sum", "product"):
            # a + b + c becomes one <sum> with three children
            parts = []

            def collect(n):
                if isinstance(n, ast.BinOp) and BINOPS.get(type(n.op)) == tag:
                    collect(n.left)
                    collect(n.right)
                else:
                    parts.append(n)

            collect(node)
        else:
            parts = [node.left, node.right]
        body = "".join(_xml(p, resolve, depth + 1) for p in parts)
        return "%s<%s>\n%s%s</%s>\n" % (pad, tag, body, pad, tag)
    if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and not node.keywords:
        if node.func.id not in CALLS:
            raise ExprError("unknown function %r" % node.func.id)
        tag = CALLS[node.func.id]
        body = "".join(_xml(a, resolve, depth + 1) for a in node.args)
        return "%s<%s>\n%s%s</%s>\n" % (pad, tag, body, pad, tag)
    raise ExprError("unsupported syntax: %s" % ast.dump(node))


def names(expr):
    """Every bare name an expression refers to, functions excluded."""
    tree = ast.parse(expr.strip(), mode="eval")
    called = {n.func.id for n in ast.walk(tree) if isinstance(n, ast.Call) and isinstance(n.func, ast.Name)}
    return {n.id for n in ast.walk(tree) if isinstance(n, ast.Name)} - called


def fcs_function(prop, expr, resolve, outputs=(), depth=2):
    """One <fcs_function> that evaluates expr into the property `prop`.

    `resolve` maps a name used in expr to a JSBSim property path. `outputs` are
    extra properties that receive the same value.
    """
    pad = INDENT * depth
    try:
        body = _xml(ast.parse(expr.strip(), mode="eval").body, resolve, depth + 2)
    except (ExprError, SyntaxError, KeyError) as exc:
        raise ExprError("%s = %s: %s" % (prop, expr, exc)) from exc
    out = ["%s<!-- %s = %s -->\n" % (pad, prop.rsplit("/", 1)[-1], " ".join(expr.split()))]
    out.append('%s<fcs_function name="%s">\n' % (pad, prop))
    out.append("%s%s<function>\n%s%s%s</function>\n" % (pad, INDENT, body, pad, INDENT))
    for target in outputs:
        out.append("%s%s<output>%s</output>\n" % (pad, INDENT, target))
    out.append("%s</fcs_function>\n" % pad)
    return "".join(out)
