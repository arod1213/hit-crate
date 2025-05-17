from PyQt6.QtCore import QObject, pyqtSignal


# class Signal:
#     def __init__(self):
#         self.callbacks: List[Callable] = []
#
#     def emit(self):
#         for c in self.callbacks:
#             c()
#
#     def connect(self, func: Callable):
#         if func not in self.callbacks:
#             self.callbacks.append(func)


class Signals(QObject):
    _instance = None
    directory_added = pyqtSignal()
    directory_removed = pyqtSignal()

    def __init__(self):
        super().__init__()


signals = Signals()


__all__ = ['signals']
