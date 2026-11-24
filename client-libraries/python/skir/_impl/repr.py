import re
from dataclasses import dataclass
from typing import Any


@dataclass
class ReprResult:
    repr: str
    complex: bool

    @property
    def indented(self) -> str:
        if self.complex:
            return self.repr.replace("\n", "\n  ")
        else:
            return self.repr


def repr_impl(input: Any) -> ReprResult:
    if isinstance(input, list) or isinstance(input, tuple):
        if len(input) == 0:
            return ReprResult("[]", complex=False)
        elif len(input) == 1:
            only_item_repr = repr_impl(input[0])
            if only_item_repr.complex:
                return ReprResult(f"[\n  {only_item_repr.indented},\n]", complex=True)
            else:
                return ReprResult(f"[{only_item_repr.repr}]", complex=True)
        else:
            body = "".join(f"  {repr_impl(item).indented},\n" for item in input)
            return ReprResult(f"[\n{body}]", complex=True)
    elif isinstance(input, str):
        if "\n" in input:
            lines = input.split("\n")
            body = "".join(f"  {repr(line)},\n" for line in lines)
            return ReprResult(f"'\\n'.join([\n{body}])", complex=True)
        else:
            return ReprResult(repr(input), complex=False)
    else:
        r = repr(input)
        # Complex if the representation contains '[', '(' or '\n'.
        return ReprResult(r, complex=re.search(r"[\\[\\(\\\n]", r) is not None)
