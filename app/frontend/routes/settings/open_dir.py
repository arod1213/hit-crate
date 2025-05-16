from pathlib import Path

from app.backend.db import engine
from app.backend.services import DirectoryService
from app.frontend.signals import Signals
from PyQt6.QtWidgets import (
    QFileDialog,
    QPushButton,
)
from sqlmodel import Session


class OpenDir(QPushButton):

    def __init__(self):
        super().__init__()
        self.initUI()
        self.setText("Add Directory")
        self.signals = Signals()

    def initUI(self):
        self.clicked.connect(self.openFileDialog)
        self.setGeometry(150, 150, 100, 30)

    def openFileDialog(self):
        file_dialog = QFileDialog(self)
        file_dialog.setWindowTitle("Open File")
        file_dialog.setFileMode(QFileDialog.FileMode.Directory)
        file_dialog.setOption(QFileDialog.Option.ShowDirsOnly, True)
        file_dialog.setViewMode(QFileDialog.ViewMode.Detail)

        if file_dialog.exec():
            selected_files = file_dialog.selectedFiles()
            if selected_files:
                selected_path = Path(selected_files[0])
                self.create_dir(selected_path)

    def create_dir(self, path: Path):
        with Session(engine) as db_session:
            DirectoryService(db_session).create(path)
        self.signals.directory_added.emit()
