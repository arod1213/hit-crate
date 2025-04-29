from PyQt6.QtCore import QSize, Qt
from PyQt6.QtGui import QIcon
from PyQt6.QtWidgets import (
    QHBoxLayout,
    QLabel,
    QPushButton,
    QVBoxLayout,
    QWidget,
)
from sqlmodel import Session

from app.backend.services import DirectoryService
from app.frontend.settings.open_dir import OpenDir
from app.backend.db import engine
from pathlib import Path

from ..store import Store


class Settings(QWidget):
    def __init__(self):
        super().__init__()

        self.store = Store()

        self.main_layout = QVBoxLayout(self)
        self.main_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)

        dir_sel = OpenDir()
        dir_sel.directory_added.connect(self.refresh_ui)

        self.main_layout.addWidget(dir_sel)
        self.setup_ui()

    def setup_ui(self):
        with Session(engine) as db_session:
            data = DirectoryService(db_session).query_directories()
            for dir in data:
                item_widget = QWidget()
                item_layout = QHBoxLayout(item_widget)

                # Folder Icon
                icon_label = QLabel()
                icon = QIcon.fromTheme("folder")  # Uses system folder icon
                icon_label.setPixmap(icon.pixmap(QSize(16, 16)))

                # Directory Path
                path_label = QLabel(text=f"{dir.path}")

                # Delete Button
                delete_button = QPushButton(text="delete")
                delete_button.setFixedSize(60, 25)
                delete_button.clicked.connect(
                    lambda _, p=dir.path: self.delete_directory(p)
                )

                # Add to layout
                item_layout.addWidget(icon_label)
                item_layout.addWidget(path_label)
                item_layout.addStretch()
                item_layout.addWidget(delete_button)

                self.main_layout.addWidget(item_widget)

    def refresh_ui(self):
        # Remove everything except the first widget (the OpenDir button)
        while self.main_layout.count() > 1:
            item = self.main_layout.takeAt(1)  # Always remove the second item (index 1)
            if item is None:
                continue
            widget = item.widget()
            if widget:
                widget.deleteLater()

        # Now re-setup the UI
        self.setup_ui()

    def create_dir(self, path: Path):
        with Session(engine) as db_session:
            DirectoryService(db_session).create(path)
        self.refresh_ui()

    def delete_directory(self, path: str):
        with Session(engine) as db_session:
            DirectoryService(db_session).delete(path)
        self.refresh_ui()

