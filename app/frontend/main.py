from pathlib import Path

from PyQt6.QtWidgets import QMainWindow, QStackedWidget

from app.frontend.browser.main import Browser
from app.frontend.settings.main import Settings
from app.frontend.store import Store, StoreState


class BrowserApp(QMainWindow):
    def __init__(self):
        super().__init__()

        self.store = Store()
        self.store.subscribe("curr_page", self.toggle_view)

        self.browser_widget = Browser()
        self.settings_widget = Settings()

        self.stack = QStackedWidget()
        self.stack.addWidget(self.browser_widget)
        self.stack.addWidget(self.settings_widget)

        self.setup_ui()
        self.setStyleSheet(self.load_stylesheet())

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

    def run(self):
        self.show()
