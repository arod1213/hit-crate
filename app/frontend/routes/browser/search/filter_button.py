from typing import Optional

from app.frontend.store import Store, StoreState
from PyQt6.QtGui import QIcon
from PyQt6.QtWidgets import QPushButton


class FilterButton(QPushButton):
    def __init__(
        self,
        tooltip: str,
        attribute: str,
        text: str = "",
        icon: Optional[str] = None,
        pressed: bool = False,
    ):
        super().__init__()
        self.attribute = attribute
        self.setToolTip(tooltip)
        self.setCheckable(True)
        self.setChecked(pressed)
        if icon is not None:
            self.setIcon(QIcon(icon))
            self.setIconSize(self.sizeHint())
        else:
            self.setText(text)

        self.setFixedSize(35, 35)

        self.store = Store()
        self.store.subscribe("filters", self.set_state)

        self.toggled.connect(self.update_store)  # 🔁 connect signal

    def set_state(self, state: StoreState):
        value = getattr(state.filters, self.attribute)
        if value != self.isChecked():
            self.blockSignals(True)  # prevent triggering toggled signal during update
            self.setChecked(value)
            self.blockSignals(False)

    def update_store(self, checked: bool):
        curr_val = getattr(self.store._state.filters, self.attribute)
        if checked == curr_val:
            return
        self.store.update_filters(self.attribute, checked)

        # Create a new FilterOptions with the updated value
