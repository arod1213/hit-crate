from typing import Optional

from PyQt6.QtGui import QIcon
from PyQt6.QtWidgets import QPushButton


class MenuButton(QPushButton):
    def __init__(
        self,
        text: str = "",
        icon: Optional[str] = None,
    ):
        super().__init__()
        self.setCheckable(False)
        self.setChecked(False)
        if icon is not None:
            self.setIcon(QIcon(icon))
            self.setIconSize(self.sizeHint())
        else:
            self.setText(text)

        self.setFixedSize(35, 35)

    def on_press(self):
        pass
