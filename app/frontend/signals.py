from typing import Callable, List

from PyQt6.QtCore import QObject


class Signal:
    def __init__(self):
        self.callbacks: List[Callable] = []

    def emit(self):
        for c in self.callbacks:
            c()

    def connect(self, func: Callable):
        if func not in self.callbacks:
            self.callbacks.append(func)


class Signals(QObject):
    _instance = None

    @classmethod
    def __new__(cls, *args, **kwargs):
        if cls._instance is None:
            cls._instance = super(Signals, cls).__new__(cls)
        return cls._instance

    def __init__(self):
        super(Signals, self).__init__()
        if not hasattr(self, '_initialized'):
            self._initialized = True
            self.directory_added = Signal()
            self.directory_removed = Signal()
