import sys
import threading

from PyQt6.QtWidgets import QApplication

from app.backend.watcher import run_initial_scan
from app.frontend.main import BrowserApp


# @watchdog
def main():
    watcher_thread = threading.Thread(target=run_initial_scan, daemon=True)
    watcher_thread.start()

    app = QApplication(sys.argv)

    browser = BrowserApp()
    browser.run()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
