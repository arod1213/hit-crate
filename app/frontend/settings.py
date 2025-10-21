from PyQt6.QtCore import QCoreApplication, QSettings

QCoreApplication.setOrganizationName("Aidan Rodriguez")
QCoreApplication.setApplicationName("Hit Crate")


def save_auto_play_setting(enabled: bool):
    settings = QSettings()
    settings.setValue("auto_play", enabled)


def load_auto_play_setting():
    settings = QSettings()
    return settings.value("auto_play", True, type=bool)


def save_dual_slider_setting(enabled: bool):
    settings = QSettings()
    settings.setValue("dual_slider", enabled)
    return


def load_dual_slider_setting():
    settings = QSettings()
    return settings.value("dual_slider", False, type=bool)
