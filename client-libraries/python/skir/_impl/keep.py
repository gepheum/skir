from dataclasses import dataclass
from typing import Final, cast, final

from skir._impl.never import Never


@final
@dataclass(frozen=True)
class Keep:
    """
    Type of the KEEP constant, which indicates that a value should not be replaced.

    Do not instantiate.
    """

    def __init__(self, never: Never):
        pass


KEEP: Final = Keep(cast(Never, None))
