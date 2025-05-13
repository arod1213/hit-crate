from pathlib import Path

from PyQt6.QtWidgets import QHBoxLayout, QMainWindow, QStackedWidget, QWidget

from app.frontend.routes.browser.main import Browser
from app.frontend.routes.folder_tree.main import FolderTree
from app.frontend.routes.settings.main import Settings
from app.frontend.store import Store, StoreState


class BrowserApp(QMainWindow):
    def __init__(self):
        super().__init__()

        self.store = Store()
        self.store.subscribe("curr_page", self.toggle_view)

        self.browser_widget = QWidget()
        self.browser_layout = QHBoxLayout(self.browser_widget)

        self.folder_tree = FolderTree()
        self.folder_tree.setVisible(False)
        self.browser_layout.addWidget(self.folder_tree, stretch=0)

        self.results = Browser()
        self.browser_layout.addWidget(self.results, stretch=1)

        self.settings_widget = Settings()

        self.stack = QStackedWidget()
        self.stack.addWidget(self.browser_widget)
        self.stack.addWidget(self.settings_widget)

        self.setup_ui()
        self.setStyleSheet(self.load_stylesheet())
        self.store.subscribe("show_dirs", self.toggle_tree)

    def load_stylesheet(self) -> str:
        # Resolve style.qss relative to this file
        style_path = Path(__file__).parent / "style.qss"
        if style_path.exists():
            return style_path.read_text()
        else:
            print("Warning: style.qss not found")
            return ""

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
