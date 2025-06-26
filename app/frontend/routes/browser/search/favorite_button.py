from app.frontend.store import Store, StoreState
from PyQt6.QtCore import QSize
from PyQt6.QtGui import QIcon
from PyQt6.QtWidgets import QPushButton


class FavoriteButton(QPushButton):
    def __init__(self):
        super().__init__()
        self.attribute = "by_favorites"
        self.setCheckable(True)
        self.setToolTip("Filter results to only show\nyour favorite samples")

        self.store = Store()
        byFavs = self.store._state.by_favorites
        self.setChecked(byFavs)

        self.icon_pressed = "assets/heart-icon-fill.svg"
        self.icon_unpressed = "assets/heart-icon.svg"

        self.set_icon(byFavs)
        self.setIconSize(QSize(25, 25))

        self.setFixedSize(35, 35)

        self.store = Store()
        self.store.subscribe(self.attribute, self.set_state)

        self.toggled.connect(self.update_store)  # 🔁 connect signal

    def set_icon(self, value: bool):
        icon = self.icon_pressed if value else self.icon_unpressed
        self.setIcon(QIcon(icon))

    def set_state(self, state: StoreState):
        value = getattr(state, self.attribute)
        if value != self.isChecked():
            self.blockSignals(True)  # prevent triggering toggled signal during update
            self.setChecked(value)
            self.blockSignals(False)
        self.set_icon(value)

    def update_store(self, checked: bool):
        curr_val = getattr(self.store._state, self.attribute)
        if checked == curr_val:
            return
        self.store.set_state(self.attribute, checked)

        # Create a new FilterOptions with the updated value
