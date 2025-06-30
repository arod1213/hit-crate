from os import wait
from pathlib import Path

from PyQt6 import QtCore
from PyQt6.QtCore import Qt
from PyQt6.QtWidgets import QMainWindow, QMenuBar, QSplitter, QStackedWidget
from PyQt6.QtGui import QAction

from app.frontend.routes.browser.main import Browser
from app.frontend.routes.folder_tree.main import FolderTree
from app.frontend.routes.settings.main import Settings
from app.frontend.store import Store, StoreState
from app.frontend.settings import load_spam_setting, save_spam_setting


class BrowserApp(QMainWindow):
    def __init__(self):
        super().__init__()

        # Create native macOS-style menu bar
        menubar = self.menuBar()
        menubar = menubar if menubar is not None else QMenuBar(self)
        view_menu = menubar.addMenu("Options")
        if view_menu is not None:
            retrigger = QAction("Spam play", self)
            retrigger.triggered.connect(lambda: save_spam_setting(not load_spam_setting()))
            view_menu.addAction(retrigger)

            # retrigger = QAction("Auto Play", self)
            # retrigger.triggered.connect(lambda: save_auto_play_setting(not load_auto_play_setting()))
            # view_menu.addAction(retrigger)

            retrigger = QAction("Pin on top", self)
            retrigger.triggered.connect(lambda: self.set_pin(True))
            view_menu.addAction(retrigger)

        self.store = Store()
        self.store.subscribe("curr_page", self.toggle_view)

        self.splitter = QSplitter(Qt.Orientation.Horizontal)

        self.folder_tree = FolderTree()
        self.folder_tree.setVisible(False)
        self.splitter.addWidget(self.folder_tree)

        self.results = Browser()
        self.splitter.addWidget(self.results)

        self.settings_widget = Settings()

        self.stack = QStackedWidget()
        self.stack.addWidget(self.splitter)
        self.stack.addWidget(self.settings_widget)

        self.setup_ui()
        is_dark_mode = False
        self.set_stylesheet(is_dark_mode)
        self.store.subscribe("show_dirs", self.toggle_tree)

    def load_stylesheet(self, is_dark_mode: bool) -> str:
        style_path = "style_light.qss"
        if is_dark_mode:
            style_path = "style_dark.qss"
        # Resolve style.qss relative to this file
        style_path = Path(__file__).parent / style_path
        if style_path.exists():
            return style_path.read_text()
        else:
            print("Warning: style.qss not found")
            return ""

    def set_stylesheet(self, is_dark_mode: bool) -> None:
        style_sheet = self.load_stylesheet(is_dark_mode)
        self.setStyleSheet(style_sheet)

    def setup_ui(self):
        self.setWindowTitle("Hit Crate")
        self.setMinimumSize(450, 450)
        self.resize(450, 700)

        self.setCentralWidget(self.stack)

    def toggle_view(self, state: StoreState):
        if state.curr_page == 0:
            self.stack.setCurrentIndex(0)
        else:
            self.stack.setCurrentIndex(1)

    def toggle_tree(self, state: StoreState):
        value = state.show_dirs
        self.folder_tree.setVisible(value)
        if value:
            self.adjustSize()

    def run(self):
        self.show()
    
    def set_pin(self, enabled: bool):
        self.setWindowFlags(QtCore.Qt.WindowType.WindowStaysOnTopHint)
