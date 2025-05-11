from PyQt6.QtCore import QCoreApplication, QSettings

QCoreApplication.setOrganizationName("Aidan Rodriguez")
QCoreApplication.setApplicationName("Hit Crate")


def save_auto_play_setting(auto_play_enabled: bool):
    settings = QSettings()
    settings.setValue("auto_play", auto_play_enabled)


def load_auto_play_setting():
    settings = QSettings()
    return settings.value("auto_play", True, type=bool)
