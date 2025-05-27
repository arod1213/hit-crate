from typing import List, Callable


def tokenize(text: str) -> List[str]:
    text_lower = text.lower()

    matcher_map: dict[Callable[[], List[str]], List[str]] = {
        match_kick: ['ki', 'kick', 'bass drum'],
        match_snare: ['snr', 'snare'],
        match_rim: ['rim'],
        match_clap: ['clap', 'clp'],
        match_hat_closed: ['chh', 'hhc', 'hat cl', 'closed h'],
        match_hat_open: ['ohh', 'hho', 'hat op', 'open h'],
        match_hat: ['hh', 'hat'],
        match_tom: ['floor', 'mid', 'tom', 'tm'],
        match_shaker: ['shk', 'shaker'],
        match_tamb: ['tamb', 'tmb'],
        match_perc: ['perc'],
        match_cym: ['cym', 'cymbal'],
        match_fx: ['fx', 'lazer', 'sweep', 'zap', 'trans', 'impact'],
        match_vox: ['vox', 'vocal']
    }

    for matcher_func, triggers in matcher_map.items():
        if any(text_lower.startswith(t) or t in text_lower for t in triggers):
            return matcher_func()

    return []


def match_kick() -> List[str]:
    return ['kik', 'kick', 'bass drum', 'bd']


def match_snare() -> List[str]:
    return ['snr', 'snare', 'snare drum', 'sd']


def match_rim() -> List[str]:
    return ['rim', 'side stick']


def match_clap() -> List[str]:
    return ['clp', 'clap', 'snap']


def match_hat_closed() -> List[str]:
    return ['chh', 'hat cl', 'hhc', 'hat']


def match_hat_open() -> List[str]:
    return ['ohh', 'hat open', 'hho']


def match_hat() -> List[str]:
    hat_c = match_hat_closed()
    hat_o = match_hat_open()
    return [*hat_c, *hat_o]


def match_tom() -> List[str]:
    return ['tom', 'floor']


def match_cym() -> List[str]:
    return ['ride', 'crsh', 'crash', 'cymbal', 'cym', 'splash', 'china']


def match_shaker() -> List[str]:
    return ['shk', 'shaker']


def match_tamb() -> List[str]:
    return ['tamb', 'tmb']


def match_perc() -> List[str]:
    shaker_match = match_shaker()
    tamb_match = match_tamb()
    return ['cow', 'vibra', 'cabas', 'conga', 'bongo', *shaker_match, *tamb_match]


def match_fx() -> List[str]:
    return ['fx', 'lazer', 'sweep', 'zap', 'trans', 'impact', 'riser', 'downshifter']


def match_vox() -> List[str]:
    return ['vox', 'vocal', 'chant', 'shout', 'yell']
