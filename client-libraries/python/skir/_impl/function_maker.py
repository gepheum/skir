import itertools
from dataclasses import dataclass
from typing import Any, Callable, Iterable, Optional, Sequence, Union


def make_function(
    name: str,
    params: Sequence[Union[str, "Param"]],
    body: Sequence[Union[str, "Line"]],
) -> Callable:
    params = [Param(p, default=None) if isinstance(p, str) else p for p in params]

    def make_locals() -> _Locals:
        # First, collect all the (key, value) pairs.
        # There may be both key duplicates and value duplicates. They will be resolved
        # later.
        all_pieces: list[Union[str, _Local]] = []
        for param in params:
            if param._default is not None:
                all_pieces.extend(param._default._pieces)
        for line in body:
            if isinstance(line, LineSpan):
                all_pieces.extend(line._pieces)
        all_locals = (p for p in all_pieces if isinstance(p, _Local))

        locals: dict[str, Any] = {}
        reversed: dict[int, str] = {}
        prefix_to_count: dict[str, int] = {}
        for local in all_locals:
            name = local.name
            value = local.value
            if id(value) in reversed:
                # We already have this value, either under the same name or under a
                # different name. Either way, we can reuse the name we already have.
                continue
            if name.endswith("?"):
                # Replace the "?" suffix with a number obtained from a sequence so there
                # is no name conflict.
                prefix = name[0:-1]
                count = prefix_to_count.get(prefix, 0)
                prefix_to_count[prefix] = count + 1
                name = prefix + str(count)
            if name in locals:
                raise ValueError(f"Duplicate local: name={name}; value={value}")
            locals[name] = value
            reversed[id(value)] = name

        return _Locals(locals, reversed)

    locals = make_locals()

    def line_to_code(ln: Union[str, Line]) -> str:
        if isinstance(ln, str):
            return ln
        return ln._to_code(locals)

    body_str = "\n    ".join(line_to_code(ln) for ln in body) if body else "pass"
    text = f"""
def __create_function__({', '.join(locals.locals.keys())}):
  def {name}({', '.join(p._to_code(locals) for p in params)}):
    {body_str}
  return {name}
"""
    ns = {}
    exec(text, None, ns)
    return ns["__create_function__"](**locals.locals)


@dataclass(frozen=True)
class LineSpan:
    "An immutable span within a line of Python code."

    _pieces: tuple[Union[str, "_Local"], ...]

    @staticmethod
    def join(*spans: Union[str, "LineSpan"], separator: str = "") -> "LineSpan":
        def get_pieces(
            span: Union[str, "LineSpan"],
        ) -> tuple[Union[str, "_Local"], ...]:
            if isinstance(span, LineSpan):
                return span._pieces
            return ((span),)

        # Remove empty strings.
        spans = tuple(s for s in spans if s)
        if len(spans) == 0:
            return _EMPTY_LINE_SPAN
        elif len(spans) == 1:
            only_span = spans[0]
            if isinstance(only_span, LineSpan):
                return only_span
            return LineSpan((only_span,))
        if separator:
            pieces = itertools.chain(
                get_pieces(spans[0]),
                *itertools.chain(
                    itertools.chain((separator,), get_pieces(s)) for s in spans[1:]
                ),
            )
        else:
            pieces = itertools.chain(*(get_pieces(s) for s in spans))
        return LineSpan(tuple(pieces))

    @staticmethod
    def local(name: str, value: Any):
        return LineSpan((_Local(name, value),))

    def _to_code(self, locals: "_Locals") -> str:
        ret = ""
        for piece in self._pieces:
            if isinstance(piece, _Local):
                # Look up the resolved name for the value.
                # It migth be different from `piece.name` in some edge cases.
                ret += locals.reversed[id(piece.value)]
            else:
                ret += piece
        return ret


_EMPTY_LINE_SPAN = LineSpan(())


LineSpanLike = Union[str, LineSpan]


# A type alias to use when the line span is a Python expression.
Expr = LineSpan
ExprLike = LineSpanLike


# A type alias to use when the line span is the whole line.
Line = LineSpan


# An immutable sequence of lines.
BodySpan = tuple[Union[str, Line], ...]


# A type alias to use when the lines constitute the whole body of a function.
Body = BodySpan


class BodyBuilder:
    """Arnold Schwarzenegger."""

    _lines: list[LineSpan]

    def __init__(self):
        self._lines = []

    def append_ln(self, *spans: Union[str, LineSpan]):
        self._lines.append(Line.join(*spans))

    def extend(self, other: Iterable[Union[str, Line]], indent: str = ""):
        self._lines.extend(Line.join(indent, ln) for ln in other)
        return self

    def build(self) -> Body:
        return tuple(self._lines)


@dataclass(frozen=True)
class Param:
    name: str
    default: Optional[ExprLike] = None

    def _to_code(self, locals: "_Locals") -> str:
        if self._default is None:
            return self.name
        return f"{self.name}={self._default._to_code(locals)}"

    @property
    def _default(self) -> Optional[Expr]:
        if self.default is None:
            return None
        else:
            return Expr.join(self.default)


Params = list[Union[str, Param]]


@dataclass(frozen=True)
class _Local:
    name: str
    value: Any


@dataclass(frozen=True)
class _Locals:
    locals: dict[str, Any]
    reversed: dict[Any, str]
