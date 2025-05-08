from typing import Optional

from PyQt6.QtCore import QSize
from PyQt6.QtGui import QIcon
from PyQt6.QtWidgets import QPushButton


class MenuButton(QPushButton):
    def __init__(
        self,
        text: str = "",
        icon: Optional[str] = None,
        size: Optional[QSize] = None
    ):
        super().__init__()
        self.setCheckable(False)
        self.setChecked(False)
        if icon is not None:
            self.setIcon(QIcon(icon))
            if size is None:
                self.setIconSize(self.sizeHint())
            else:
                self.setIconSize(size)
        else:
            self.setText(text)

        self.setFixedSize(35, 35)

    def on_press(self):
        pass
