import random
from dataclasses import dataclass, field
from typing import List


@dataclass
class PlayerProfile:
    name: str
    is_cheat: bool
    reaction_time_mean_ms: float
    reaction_time_std_ms: float
    time_on_target_mean_ms: float
    time_on_target_std_ms: float
    p_hit: float
    cursor_gain: float
    cursor_noise_std: float
    # scripted: quantise inter-shot intervals to this value (ms); 0 = disabled
    scripted_interval_ms: float = 0.0
    # triggerbot: override time_on_target to near-zero
    triggerbot: bool = False
    # preaim: cursor pre-steers toward next spawn N ticks ahead
    preaim_lead_ticks: int = 0
    # aimbot: p_hit independent of cursor proximity
    aimbot: bool = False


def clean_sniper() -> PlayerProfile:
    return PlayerProfile(
        name="sniper",
        is_cheat=False,
        reaction_time_mean_ms=350.0,
        reaction_time_std_ms=80.0,
        time_on_target_mean_ms=300.0,
        time_on_target_std_ms=60.0,
        p_hit=0.75,
        cursor_gain=0.18,
        cursor_noise_std=2.0,
    )


def clean_spray() -> PlayerProfile:
    return PlayerProfile(
        name="spray_and_pray",
        is_cheat=False,
        reaction_time_mean_ms=200.0,
        reaction_time_std_ms=60.0,
        time_on_target_mean_ms=150.0,
        time_on_target_std_ms=80.0,
        p_hit=0.45,
        cursor_gain=0.12,
        cursor_noise_std=12.0,
    )


def clean_improver() -> PlayerProfile:
    return PlayerProfile(
        name="improver",
        is_cheat=False,
        reaction_time_mean_ms=280.0,
        reaction_time_std_ms=70.0,
        time_on_target_mean_ms=220.0,
        time_on_target_std_ms=70.0,
        p_hit=0.60,
        cursor_gain=0.15,
        cursor_noise_std=6.0,
    )


def clean_panicker() -> PlayerProfile:
    return PlayerProfile(
        name="panicker",
        is_cheat=False,
        reaction_time_mean_ms=320.0,
        reaction_time_std_ms=120.0,
        time_on_target_mean_ms=180.0,
        time_on_target_std_ms=100.0,
        p_hit=0.50,
        cursor_gain=0.10,
        cursor_noise_std=15.0,
    )


def aimbot() -> PlayerProfile:
    return PlayerProfile(
        name="aimbot",
        is_cheat=True,
        reaction_time_mean_ms=100.0,
        reaction_time_std_ms=20.0,
        time_on_target_mean_ms=250.0,
        time_on_target_std_ms=40.0,
        p_hit=0.97,
        cursor_gain=0.35,
        cursor_noise_std=0.5,
        aimbot=True,
    )


def scripted() -> PlayerProfile:
    return PlayerProfile(
        name="scripted",
        is_cheat=True,
        reaction_time_mean_ms=280.0,
        reaction_time_std_ms=70.0,
        time_on_target_mean_ms=220.0,
        time_on_target_std_ms=20.0,
        p_hit=0.60,
        cursor_gain=0.15,
        cursor_noise_std=6.0,
        scripted_interval_ms=800.0,
    )


def triggerbot() -> PlayerProfile:
    return PlayerProfile(
        name="triggerbot",
        is_cheat=True,
        reaction_time_mean_ms=280.0,
        reaction_time_std_ms=70.0,
        time_on_target_mean_ms=15.0,
        time_on_target_std_ms=5.0,
        p_hit=0.60,
        cursor_gain=0.15,
        cursor_noise_std=6.0,
        triggerbot=True,
    )


def preaim() -> PlayerProfile:
    return PlayerProfile(
        name="preaim",
        is_cheat=True,
        reaction_time_mean_ms=70.0,
        reaction_time_std_ms=15.0,
        time_on_target_mean_ms=80.0,
        time_on_target_std_ms=20.0,
        p_hit=0.85,
        cursor_gain=0.15,
        cursor_noise_std=5.0,
        preaim_lead_ticks=80,
    )


_CLEAN_FACTORIES = [clean_sniper, clean_spray, clean_improver, clean_panicker]
_CHEAT_FACTORIES = {
    "aimbot": aimbot,
    "scripted": scripted,
    "triggerbot": triggerbot,
    "preaim": preaim,
}


def pick_clean_profile() -> PlayerProfile:
    return random.choice(_CLEAN_FACTORIES)()


def pick_cheat_profile(allowed: List[str] = None) -> PlayerProfile:
    if allowed is None:
        allowed = list(_CHEAT_FACTORIES.keys())
    name = random.choice(allowed)
    return _CHEAT_FACTORIES[name]()
