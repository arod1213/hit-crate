from dataclasses import dataclass

from app.frontend.components.slider import Slider
from app.frontend.store import Store, StoreState
from PyQt6.QtCore import QSize
from PyQt6.QtGui import QIcon
from PyQt6.QtWidgets import QHBoxLayout, QPushButton, QWidget


@dataclass
class SubscriptableValue:
    text_left: str
    text_right: str
    min: int
    max: int
    default_value: int


class SortSlider(QWidget):
    def __init__(
        self,
        subscribe_to: str,
    ):
        super().__init__()

        self.subscriptable_values = {
            'spectral_centroid': SubscriptableValue(
                text_left='dark',
                text_right='bright',
                min=40,
                max=8000,
                default_value=40
            ),
            'stereo_width': SubscriptableValue(
                text_left='mono',
                text_right='wide',
                min=0,
                max=200,
                default_value=0
            )
        }
        self.sub = self.subscriptable_values[subscribe_to]
        if self.sub is None:
            raise ValueError("Invalid subscribe value", subscribe_to)

        self.store = Store()
        self.subscribe_to = subscribe_to
        self.default_value = self.sub.default_value

        layout = QHBoxLayout(self)

        power_icon = QIcon("assets/power-icon.svg")
        self.power_button = QPushButton(text="", icon=power_icon)
        self.power_button.setStyleSheet(
            """
            QPushButton {
                background-color: #e4e6eb;
                border-radius: 10px;
                border: 0px solid #FFFFFF;
            }
            QPushButton:checked {
                background-color: #5BA7FF;  /* Tailwind-ish blue */
            }
        """
        )
        self.power_button.setCheckable(True)
        self.power_button.setChecked(
            getattr(self.store._state, subscribe_to) is not None
        )
        self.power_button.setIconSize(QSize(16, 16))
        self.power_button.setFixedSize(22, 22)
        self.power_button.clicked.connect(self.toggle_power)
        self.store.subscribe(self.subscribe_to, self.update_power)

        layout.addWidget(self.power_button)

        self.slider = Slider(
            subscribe_to=subscribe_to,
            min_value=self.sub.min,
            max_value=self.sub.max,
            text_left=self.sub.text_left,
            text_right=self.sub.text_right,
        )
        layout.addWidget(self.slider)

        toggle_button = QIcon("assets/switch-icon.svg")
        self.toggle_button = QPushButton(text="", icon=toggle_button)
        self.toggle_button.setCheckable(False)
        self.toggle_button.setIconSize(QSize(16, 16))
        self.toggle_button.setFixedSize(22, 22)
        self.toggle_button.setStyleSheet(
            """
            QPushButton {
                background-color: #e4e6eb;
                border-radius: 10px;
                border: 0px solid #000000;
            }
        """
        )
        self.toggle_button.clicked.connect(self.rotate_sub)
        layout.addWidget(self.toggle_button)

    # switch subscriptable item
    def rotate_sub(self, _):
        keys = list(self.subscriptable_values.keys())
        current_index = keys.index(self.subscribe_to)
        new_index = current_index + 1
        if new_index > len(keys) - 1:
            new_index = 0
        new_key = keys[new_index]
        new_sub = self.subscriptable_values.get(new_key)
        if new_sub is None:
            return

        # reset previous value
        self.store.set_state(self.subscribe_to, None)

        self.subscribe_to = new_key
        self.slider.subscribe_to = new_key
        self.sub = new_sub
        self.default_value = new_sub.default_value
        self.store.set_state(new_key, new_sub.default_value)
        self.slider.reset(
            subscribe_to=new_key,
            min_value=new_sub.min,
            max_value=new_sub.max,
            text_left=new_sub.text_left,
            text_right=new_sub.text_right,
        )
        self.power_button.setChecked(True)
        pass

    # update to store state
    def update_power(self, state: StoreState):
        value = getattr(state, self.subscribe_to)
        if value is None:
            self.power_button.setChecked(False)
        else:
            self.power_button.setChecked(True)

    # trigger toggle on click
    def toggle_power(self, power_on: bool) -> None:
        store_value = None if not power_on else self.default_value
        self.store.set_state(self.subscribe_to, store_value)
