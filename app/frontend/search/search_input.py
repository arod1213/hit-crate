from PyQt6.QtCore import Qt
from PyQt6.QtWidgets import (
    QLineEdit,
    QVBoxLayout,
    QWidget,
)

from app.frontend.store import Store


class SearchInput(QWidget):
    def __init__(self):
        super().__init__()
        self.store = Store()

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)

        # text input
        self.search_input = QLineEdit()
        self.search_input.setPlaceholderText("Search samples...")
        self.search_input.textChanged.connect(self.search)
        layout.addWidget(self.search_input)

        self.setLayout(layout)

    # handles search input
    def keyPressEvent(self, a0):
        if a0 is None:
            return
        key = a0.key()
        if key in {Qt.Key.Key_Enter, Qt.Key.Key_Return}:
            self.search_input.clearFocus()
        super().keyPressEvent(a0)

    def search(self, text):
        self.store.set_state("search_key", text)
