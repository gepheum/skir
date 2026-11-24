import abc
from typing import Generic, Optional, TypeVar

Item = TypeVar("Item")
Key = TypeVar("Key")


class KeyedItems(Generic[Item, Key], tuple[Item, ...], metaclass=abc.ABCMeta):
    """
    Immutable collection that supports efficient key-based lookups.
    Designed for scenarios where elements contain their own unique identifiers
    (keys).

    Performance characteristics:
    - First lookup: O(N) time complexity as the internal index is lazily built.
    - Subsequent lookups: O(1) time complexity using the cached index.
    """

    @abc.abstractmethod
    def find(self, key: Key) -> Optional[Item]:
        """
        Search for an item by its key.
        If multiple items share the same key, the last occurrence is returned.

        If the internal index has not been initialized, this call will trigger
        the O(N) indexing process.

        Args:
            key: The unique identifier of the item to retrieve.

        Returns:
            The Item associated with the key if found; otherwise, None.
        """
        ...

    @abc.abstractmethod
    def find_or_default(self, key: Key) -> Item:
        """
        Retrieve an item by its key or return the default value for Item.
        If multiple items share the same key, the last occurrence is returned.

        If the internal index has not been initialized, this call will trigger
        the O(N) indexing process.

        Args:
            key: The unique identifier of the item to retrieve.
        """
        ...
