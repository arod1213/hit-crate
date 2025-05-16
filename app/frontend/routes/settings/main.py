import threading
from pathlib import Path

from app.backend.db import engine
from app.backend.services import DirectoryService
from app.frontend.components import ToggleView
from app.frontend.signals import Signals
from app.frontend.store import Store
from PyQt6.QtCore import QSize, Qt
from PyQt6.QtGui import QIcon
from PyQt6.QtWidgets import (
    QHBoxLayout,
    QLabel,
    QVBoxLayout,
    QWidget,
)
from sqlmodel import Session

from .audio_settings import AudioSettings
from .menu_button import MenuButton
from .open_dir import OpenDir


def update_dir(dir: str):
    with Session(engine) as session:
        DirectoryService(session).rescan(Path(dir))


def rescan(dir: str):
    t = threading.Thread(target=lambda x=dir: update_dir(x), daemon=True)
    t.start()


class Settings(QWidget):
    def __init__(self):
        super().__init__()

        self.store = Store()
        self.signals = Signals()

        self.main_layout = QVBoxLayout(self)
        self.main_layout.setAlignment(Qt.AlignmentFlag.AlignTop)

        back = ToggleView()
        self.main_layout.addWidget(back)

        self.setup_ui()

    def setup_ui(self):
        audio_settings = AudioSettings()
        self.main_layout.addWidget(audio_settings)
        self.signals.directory_added.connect(self.refresh_ui)
        dir_sel = OpenDir()
        self.main_layout.addWidget(dir_sel)

        with Session(engine) as db_session:
            data = DirectoryService(db_session).query_directories()
            for dir in data:
                item_widget = QWidget()
                item_layout = QHBoxLayout(item_widget)

                # Folder Icon
                icon_label = QLabel()
                icon = QIcon("assets/folder-icon")
                icon_label.setPixmap(icon.pixmap(QSize(16, 16)))

                # Directory Path
                path_label = QLabel(text=f"{dir.path}")

                rescan_button = MenuButton(
                    text="rescan",
                    icon="assets/refresh-icon.svg",
                    size=QSize(19, 19),
                )
                rescan_button.clicked.connect(lambda _, p=dir.path: rescan(p))
                # Delete Button
                delete_button = MenuButton(
                    text="delete", icon="assets/close-icon.svg"
                )
                delete_button.clicked.connect(
                    lambda _, p=dir.path: self.delete_directory(p)
                )

                # Add to layout
                item_layout.addWidget(icon_label)
                item_layout.addWidget(path_label)
                item_layout.addStretch()
                item_layout.addWidget(rescan_button)
                item_layout.addWidget(delete_button)

                self.main_layout.addWidget(item_widget)

    def refresh_ui(self):
        # Remove everything except the first widget (the OpenDir button)
        while self.main_layout.count() > 1:
            item = self.main_layout.takeAt(
                1
            )  # Always remove the second item (index 1)
            if item is None:
                continue
            widget = item.widget()
            if widget:
                widget.deleteLater()

        # Now re-setup the UI
        self.setup_ui()

    def delete_directory(self, path: str):
        with Session(engine) as db_session:
            DirectoryService(db_session).delete(path)
        self.refresh_ui()
        self.signals.directory_removed.emit()
