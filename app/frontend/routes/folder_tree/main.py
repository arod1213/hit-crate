import os
from pathlib import Path

from app.backend.db import engine
from app.backend.services import DirectoryService
from app.frontend.signals import Signals
from app.frontend.store import Store
from PyQt6.QtCore import Qt
from PyQt6.QtGui import QStandardItem, QStandardItemModel
from PyQt6.QtWidgets import (
    QSizePolicy,
    QTreeView,
    QVBoxLayout,
    QWidget,
)
from sqlmodel import Session


class FolderTree(QWidget):
    def __init__(self):
        super().__init__()
        self.store = Store()
        self.signals = Signals()

        self.setMinimumWidth(200)
        self.setSizePolicy(
            QSizePolicy.Policy.Minimum,
            QSizePolicy.Policy.Preferred
        )

        self.tree_view = QTreeView(self)
        self.model = QStandardItemModel()
        self.model.setHorizontalHeaderLabels(["Folders"])
        self.tree_view.setModel(self.model)
        self.tree_view.setHeaderHidden(True)
        self.tree_view.expanded.connect(self.on_item_expanded)
        self.tree_view.setHorizontalScrollBarPolicy(
            Qt.ScrollBarPolicy.ScrollBarAlwaysOff
        )

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.addWidget(self.tree_view)
        self.rescan()
        self.setLayout(layout)
        self.signals.directory_added.connect(self.rescan)

    def rescan(self):
        print("RESACN")
        # Clear the current model
        self.model.clear()
        self.model.setHorizontalHeaderLabels(["Folders"])

        # Add top-level user-selected folders
        with Session(engine) as session:
            folder_paths = DirectoryService(session).query_directories()
            print(f"FOUND {len(folder_paths)} folders")
            for path in folder_paths:
                self.add_top_level_folder(Path(path.path))

        selection_model = self.tree_view.selectionModel()
        assert selection_model is not None
        selection_model.selectionChanged.connect(self.on_selection_changed)

    def on_selection_changed(self, selected, _):
        selected_indexes = selected.indexes()
        if not selected_indexes:
            self.store.set_state("curr_path", None)
            return

        selected_item = self.model.itemFromIndex(selected_indexes[0])
        if not selected_item:
            return None
        folder_path = selected_item.data()
        self.store.set_state("curr_path", folder_path)

    def add_top_level_folder(self, path: Path):
        if not path.is_dir():
            return
        item = QStandardItem(os.path.basename(str(path)))
        item.setData(Path(path))
        item.setEditable(False)

        # Add dummy child for expansion arrow
        item.appendRow(QStandardItem("Loading..."))
        self.model.appendRow(item)

    def on_item_expanded(self, index):
        item = self.model.itemFromIndex(index)
        if item is None:
            return
        path: Path = item.data()
        if not path or not path.is_dir():
            return

        # Remove dummy and load subfolders
        if not item.hasChildren() or not item.child(0):
            return
        item.removeRows(0, item.rowCount())
        try:
            for name in os.listdir(str(path)):
                full_path = os.path.join(str(path), name)
                if os.path.isdir(full_path):
                    child = QStandardItem(name)
                    child.setData(Path(full_path))
                    child.setEditable(False)
                    if any(
                        os.path.isdir(os.path.join(full_path, f))
                        for f in os.listdir(full_path)
                    ):
                        child.appendRow(QStandardItem("Loading..."))
                    if item is None:
                        continue
                    item.appendRow(child)
        except Exception as e:
            print("Error loading folder:", e)
