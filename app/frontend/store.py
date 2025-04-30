from collections import defaultdict
from dataclasses import dataclass, field, replace
from typing import Callable, Optional, Sequence

from app.backend.models import Sample


@dataclass
class FilterOptions:
    by_width: bool = False
    by_freq: bool = True
    spectral_centroid: int = 40


@dataclass
class StoreState:
    filters: FilterOptions = field(default_factory=FilterOptions)
    selected_sample: Optional[Sample] = None
    search_key: str = ""
    results: Sequence[Sample] | None = None
    curr_page: int = 0
    lufs_target: float = -25


class Store:
    _instance = None

    @classmethod
    def __new__(cls, *args, **kwargs):
        if cls._instance is None:
            cls._instance = super(Store, cls).__new__(cls)
            cls._instance._init_state()
        return cls._instance

    def _init_state(self):
        self._state = StoreState()
        self._subscribers = defaultdict(list)

    def set_state(self, key: str, value):
        if hasattr(self._state, key):  # Ensure the key exists in the dataclass
            setattr(self._state, key, value)  # Set the new value
            self._notify_subscribers(key)

    def update_filters(self, key: str, value):
        current_filters = self._state.filters
        if not hasattr(current_filters, key):
            raise AttributeError(f"'FilterOptions' has no attribute '{key}'")

        updated_filters = replace(current_filters, **{key: value})
        self._state.filters = updated_filters
        self._notify_subscribers("filters")

    def subscribe(self, key: str, callback: Callable[[StoreState], None]):
        self._subscribers[key].append(callback)

    def _notify_subscribers(self, key: str):
        for callback in self._subscribers[key]:
            callback(self._state)

    def __getitem__(self, key: str):
        if hasattr(self._state, key):
            return getattr(self._state, key)
        raise KeyError(f"Key '{key}' not found.")

    def __setitem__(self, key: str, value: Optional[Sample] | str):
        if hasattr(self._state, key):
            setattr(self._state, key, value)
            self._notify_subscribers(key)
