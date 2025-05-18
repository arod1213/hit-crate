from PyQt6.QtCore import QCoreApplication, QSettings

QCoreApplication.setOrganizationName("Aidan Rodriguez")
QCoreApplication.setApplicationName("Hit Crate")


# general
# def save_dark_mode(is_dark: bool):
#     settings = QSettings()
#     settings.setValue("dark_mode", is_dark)
#
#
# def load_dark_mode_setting():
#     settings = QSettings()
#     return settings.value("dark_mode", True, type=bool)


# audio
def save_auto_play_setting(auto_play_enabled: bool):
    settings = QSettings()
    settings.setValue("auto_play", auto_play_enabled)


def load_auto_play_setting():
    settings = QSettings()
    return settings.value("auto_play", True, type=bool)


# def save_normalize_settings(is_normalize: bool):
#     settings = QSettings()
#     settings.setValue("normalize_playback", is_normalize)
#
#
# def load_normalize_setting():
#     settings = QSettings()
#     return settings.value("normalize_playback", True, type=bool)
