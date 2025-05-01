from PyQt6.QtCore import Qt
from PyQt6.QtWidgets import (
    QHBoxLayout,
    QLabel,
    QListWidgetItem,
    QWidget,
)

from app.backend.models import Sample
from app.frontend.results.favorite_button import FavoriteButton


class ResultItem(QWidget):
    def __init__(self, sample: Sample):
        super().__init__()
        self.item = QListWidgetItem()
        self.item.setData(Qt.ItemDataRole.UserRole, sample)

        self.widget = QWidget()
        layout = QHBoxLayout(self.widget)
        layout.setContentsMargins(0, 0, 0, 0)

        label = QLabel(sample.name)
        button = FavoriteButton(sample)

        layout.addWidget(label)
        layout.addStretch()
        layout.addWidget(button)

        # self.scroll_area.itemSelectionChanged.connect(self.update_style)
        # self.update_style()

    # def update_style(self):
    #     if self.item.isSelected():
    #         self.widget.setStyleSheet("background-color: #5BA7FF; border-radius: 12px;")
    #     else:
    #         self.widget.setStyleSheet("background-color: transparent;")
