import numpy as np


def get_stereo_width(audio: np.ndarray):
    left = audio[0]
    right = audio[1]

    channels = np.array(list(zip(left, right)))
    width = np.array([])
    for x, y in channels:
        total_amp = abs(x) + abs(y)
        if total_amp == 0:
            continue
        x_percent = x / total_amp
        y_percent = y / total_amp
        makeup = abs(x_percent + y_percent)
        width = np.append(arr=width, values=makeup)

    # if empty audio file
    if len(width) == 0:
        return 0

    stereo_width = np.mean(width)
    return round((1 - stereo_width) * 1000) / 10 * 2  # max value of 200
