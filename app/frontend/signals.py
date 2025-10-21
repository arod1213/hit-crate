from PyQt6.QtCore import QObject, pyqtSignal


class Signals(QObject):
    _instance = None
    directory_added = pyqtSignal()
    directory_removed = pyqtSignal()

    def __init__(self):
        super().__init__()


signals = Signals()


__all__ = ["signals"]
