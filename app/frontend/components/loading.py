from PyQt6.QtWidgets import QLabel, QProgressBar, QVBoxLayout, QWidget

from app.frontend.components.spinner import Spinner


class LoadingIndicator(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 30, 0, 0)

        # self.progress_bar = QProgressBar(self)
        # self.progress_bar.setRange(0, 0)
        # self.progress_bar = Spinner()
        # self.progress_bar.setVisible(False)

        # Create the loading label
        self.loading_label = QLabel("Loading, please wait...", self)
        self.loading_label.setVisible(False)

        # layout.addWidget(self.progress_bar)
        layout.addWidget(self.loading_label)

        self.setLayout(layout)

    def toggle_loading(self, show: bool = True):
        # self.progress_bar.setVisible(show)
        self.loading_label.setVisible(show)
