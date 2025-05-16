import os
from pathlib import Path
from typing import Tuple

from app.backend.db import engine
from app.backend.services import DirectoryService
from app.frontend.signals import Signals
from app.frontend.store import Store
from PyQt6.QtCore import QModelIndex, Qt
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
            QSizePolicy.Policy.Minimum, QSizePolicy.Policy.Preferred
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
        self.signals.directory_removed.connect(self.rescan)
        self.store.subscribe(
            "curr_path",
            lambda x=self.store._state: self.go_to_path(x.curr_path),
        )

    def go_to_path(self, path: Path | None):
        """Navigate to and select a specific path in the folder tree.
        Args:
            path: The Path object to navigate to and select
        """
        if path is None:
            self._close_all()
            return None

        target_path = path.absolute().resolve()
        root_index, containing_root = self._find_containing_root(path)

        if self._is_path_selected(path):
            return
        if containing_root is None or root_index is None:
            return

        if target_path == containing_root:
            self.tree_view.setCurrentIndex(root_index)
            self.tree_view.scrollTo(root_index)
            return None

        current_index = root_index
        path_parts = list(target_path.relative_to(containing_root).parts)
        self.tree_view.expand(current_index)
        for i, part in enumerate(path_parts):
            found = False
            for row in range(self.model.rowCount(current_index)):
                child_index = self.model.index(row, 0, current_index)
                child_item = self.model.itemFromIndex(child_index)
                if child_item is None:
                    continue
                child_text = child_item.text()
                if child_text == part:
                    current_index = child_index
                    found = True
                    if i < len(path_parts) - 1:
                        self.tree_view.expand(current_index)
                    break
            if not found:
                # print(f"Could not find part '{part}' in the tree")
                self.tree_view.setCurrentIndex(current_index)
                self.tree_view.scrollTo(current_index)
                return
        self.tree_view.setCurrentIndex(current_index)
        self.tree_view.scrollTo(current_index)
        return

    def _is_path_selected(self, path: Path) -> bool:
        selected_indexes = self.tree_view.selectedIndexes()
        if not selected_indexes:
            return False
        selected_item = self.model.itemFromIndex(selected_indexes[0])
        if selected_item is None:
            return False
        selected_path = selected_item.data()
        if not selected_path or not Path(selected_path).resolve() == path:
            return False
        print("Path already selected, skipping...")
        return True

    def _close_all(self):
        for row in range(self.model.rowCount()):
            index = self.model.index(row, 0)
            self.tree_view.collapse(index)
        self.tree_view.clearSelection()

    def _find_containing_root(
        self, path: Path
    ) -> Tuple[QModelIndex, Path | None]:
        target_path = path.absolute().resolve()
        root_index = None

        for row in range(self.model.rowCount()):
            index = self.model.index(row, 0)
            item = self.model.itemFromIndex(index)
            if item is None:
                continue
            item_path = item.data()
            if not isinstance(item_path, Path):
                continue
            try:
                target_path.relative_to(item_path)
                root_index = index
                return root_index, item_path
            except ValueError:
                continue
        return QModelIndex(), None

    def rescan(self):
        # Clear the current model
        self.model.clear()
        self.model.setHorizontalHeaderLabels(["Folders"])

        # Add top-level user-selected folders
        with Session(engine) as session:
            folder_paths = DirectoryService(session).query_directories()
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
        if not folder_path == self.store._state.curr_path:
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
