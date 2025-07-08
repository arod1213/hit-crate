from typing import Optional

from PyQt6.QtCore import Qt
from PyQt6.QtWidgets import QDial, QHBoxLayout, QLabel, QSlider, QWidget

from app.frontend.store import Store, StoreState


class KnobPanel(QWidget):
    def __init__(
        self,
        subscribe_to: str,
        min_value: int,
        max_value: int,
        text_left: Optional[str],
        text_right: Optional[str],
    ):
        super().__init__()
        self.subscribe_to = subscribe_to

        layout = QHBoxLayout(self)
        self.left_label = QLabel(text_left)
        layout.addWidget(self.left_label)

        self.dial = QDial(self)
        self.dial.setTracking(False)
        self.dial.setWrapping(False)
        self.dial.setMinimum(min_value)
        self.dial.setMaximum(max_value)
        layout.addWidget(self.dial)

        self.right_label = QLabel(text_right)
        layout.addWidget(self.right_label)

        self.store = Store()
        self.store.subscribe(subscribe_to, self.set_state)
        self.dial.sliderReleased.connect(self.update_store)

        default = getattr(self.store._state, self.subscribe_to, 0)
        self.dial.setValue(default)

    def set_state(self, state: StoreState):
        # print(f"to {self.subscribe_to}")
        value = getattr(state, self.subscribe_to)
        if value is None:
            return
        self.dial.setValue(value)

    def update_store(self):
        self.store.set_state(self.subscribe_to, self.dial.value())

    def reset(
        self,
        subscribe_to: str,
        min_value: int,
        max_value: int,
        text_left: str,
        text_right: str,
    ):
        self.left_label.setText(text_left)
        self.right_label.setText(text_right)
        self.subscribe_to = subscribe_to
        self.dial.setMinimum(min_value)
        self.dial.setMaximum(max_value)
        self.dial.setValue(getattr(self.store._state, subscribe_to))
