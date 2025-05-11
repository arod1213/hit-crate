from PyQt6.QtCore import QSize, pyqtSignal
from PyQt6.QtGui import QIcon
from PyQt6.QtWidgets import QPushButton

from app.frontend.store import Store, StoreState


class ToggleView(QPushButton):
    toggle_signal = pyqtSignal()

    def __init__(self):
        super().__init__()

        self.store = Store()

        self.setFixedSize(35, 35)
        self.setIconSize(QSize(25, 25))

        self.settings_icon = QIcon("assets/settings-icon.svg")
        self.back_icon = QIcon("assets/arrow-back-icon.svg")

        self.store.subscribe("curr_page", self.set_icon)
        self.set_icon(self.store._state)

        self.clicked.connect(self.on_click)

    def on_click(self):
        if self.store._state.curr_page == 0:
            self.store.set_state("curr_page", 1)
        else:
            self.store.set_state("curr_page", 0)

    def set_icon(self, state: StoreState):
        if state.curr_page == 1:
            self.setIcon(self.back_icon)
        else:
            self.setIcon(self.settings_icon)
