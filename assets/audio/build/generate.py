"""Generate the game's sound effects from text prompts with Stable Audio Open Small (CPU).

    bash generate.sh            # every sound in SOUNDS (runs this file inside Docker)
    bash generate.sh rifle_shot mine_blast   # a subset
    bash generate.sh --list     # print the sound list
    bash generate.sh --banks    # only repack the banks from the existing wavs

Outputs assets/audio/<name>.wav (44.1 kHz stereo 16-bit, peak-normalised, trailing silence
trimmed). Edit SOUNDS to change a sound, then rerun; outputs are never hand-edited.

Sound banks: BANKS packs the clips of one speaker (the Walker, the player's boots, ...) into a
single assets/audio/banks/<bank>.wav with a short gap between clips, and writes the clip
offsets to src/shared/SoundBankData.luau (generated, do not edit). One upload per bank keeps
the game inside Roblox's monthly audio-upload cap; `SoundBanks.pick` plays a clip by seeking
to its offset. Variants are named <group>_<n> and the game picks one at random per event.

Model: stabilityai/stable-audio-open-small (0.5B params, 11 s max, Stability AI Community
License: free for commercial use under the revenue threshold on stability.ai/license). The
weights are gated: log in once with `hf auth login` on the host after accepting
the license on the model page. Runs on CPU in a few seconds per sound with 8 pingpong steps.
"""

import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.normpath(os.path.join(HERE, ".."))
MODEL = "stabilityai/stable-audio-open-small"

# name: (prompt, seconds, seed). Keep prompts literal and physical; the model does best with
# "what makes the sound" + "where" + "how it is recorded". Negative traits go in NEGATIVE.
# A fifth element overrides the negative prompt (TAIL keeps the reverb tail: blasts, beds).
TAIL = "music, melody, speech, low quality, distortion, clipping"

SOUNDS = {
    # weapon
    "rifle_shot": ("single assault rifle gunshot, close mic, sharp crack with short tail, outdoor, dry", 1.5, 11),
    "rifle_shot_alt": ("single assault rifle gunshot, close mic, punchy crack, slightly different take, outdoor", 1.5, 12),
    "bullet_hit_flesh": ("bullet impact on a body, wet thud with a slap, close, short", 0.8, 21),
    "bullet_hit_concrete": ("bullet ricochet off concrete, sharp crack and debris, short", 0.9, 22),
    # infected
    # rat
    # pickups and progression
    # items
    # abilities
    # run flow
    # --- sound day 2026-11-07: variant sets, packed into BANKS below ---
    # player boots. "hard" = concrete/asphalt/metal floors, "soft" = dirt/grass/sand.
    "step_hard_1": ("single footstep of a heavy military boot on concrete, close, dry, very short", 0.5, 101),
    "step_hard_2": ("one boot step on a concrete floor, firm heel then sole, close, very short", 0.5, 102),
    "step_hard_3": ("single combat boot footstep on asphalt, scuff of grit, close, very short", 0.5, 103),
    "step_hard_4": ("one heavy boot footstep on pavement, close mic, very short", 0.5, 104),
    "step_soft_1": ("single boot footstep on dirt and gravel, crunch, close, very short", 0.5, 105),
    "step_soft_2": ("one boot step on dry soil with small stones, soft crunch, close, very short", 0.5, 106),
    "step_soft_3": ("single footstep on packed earth and dead grass, close, very short", 0.5, 107),
    # bullet on a body
    "bodyshot_1": ("bullet impact on a body, wet thud with a slap, close, short", 0.8, 21),
    "bodyshot_2": ("rifle round hitting flesh, heavy wet smack, close, short", 0.8, 111),
    "bodyshot_3": ("bullet punching into a torso, meaty thump with a splash, close, short", 0.8, 112),
    "headshot_1": ("bullet hitting a skull, sharp wet crack with a splat, close, short", 0.7, 113),
    "headshot_2": ("rifle round cracking bone with a wet burst, close, short", 0.7, 114),
    # the player taking a hit
    "hurt_1": ("man grunting in pain from a hit, short, close", 0.8, 91),
    "hurt_2": ("man gasping and grunting sharply in pain, short, close", 0.8, 115),
    # the Walker: a sick man, slow and wet
    "walker_idle_1": ("sick man moaning, low wet rattling breath, hoarse human voice, close", 2.0, 201),
    "walker_idle_2": ("man groaning weakly with a gurgling throat, slow hoarse exhale, close", 2.0, 202),
    "walker_idle_3": ("hoarse rasping growl with wet breath, human voice, menacing, close", 2.0, 203),
    "walker_attack_1": ("man lunging with an aggressive hoarse snarl, human voice, short", 1.0, 204),
    "walker_attack_2": ("angry guttural shout, raspy human voice, short burst", 1.0, 205),
    "walker_hurt_1": ("man grunting in pain, wet hoarse voice, short", 0.8, 206),
    "walker_hurt_2": ("pained choking gasp, hoarse man, short", 0.8, 207),
    "walker_death_1": ("man dying with a gurgling groan and collapsing to the ground, short", 1.6, 208),
    "walker_death_2": ("choked death rattle fading out, body falling onto concrete", 1.6, 209),
    # the Runner: panting, shrieking
    "runner_idle_1": ("fast panting hoarse breathing with hissing, human, close", 1.6, 211),
    "runner_idle_2": ("frantic raspy screech, high pitched human voice, close", 1.4, 212),
    "runner_idle_3": ("ragged hyperventilating breath turning into a snarl, close", 1.6, 213),
    "runner_attack_1": ("piercing raspy shriek while attacking, high human voice, short", 1.0, 214),
    "runner_attack_2": ("high screaming snarl of a person lunging, short", 1.0, 215),
    "runner_hurt_1": ("high yelp of pain, raspy human voice, short", 0.7, 216),
    "runner_death_1": ("shrieking cry cut short by a heavy fall, short", 1.4, 217),
    "runner_death_2": ("high gurgling scream fading as a body collapses", 1.6, 218),
    # the Brute: huge chest, deep
    "brute_idle_1": ("huge heavy breathing, deep chest rumble, slow, close", 2.2, 221),
    "brute_idle_2": ("deep guttural growl with wet snorts, massive creature, close", 2.2, 222),
    "brute_attack_1": ("monstrous deep roar while swinging a heavy arm, short", 1.4, 223),
    "brute_attack_2": ("deep bellowing grunt of effort, heavy swing, short", 1.2, 224),
    "brute_hurt_1": ("deep pained grunt of a huge creature, heavy, short", 0.9, 225),
    "brute_death_1": ("huge monster dying bellow, collapsing heavily onto the ground, deep thud", 2.5, 36),
    "brute_death_2": ("deep groan fading out and a heavy body thud on concrete", 2.2, 226),
    # the Hocker: liquid throat
    "hocker_idle_1": ("wet gurgling throat bubbling, sick person, close", 1.8, 231),
    "hocker_idle_2": ("phlegmy clicking gargle with hoarse breath, close", 1.8, 232),
    "hocker_idle_3": ("liquid bubbling in a throat with a hiss, close", 1.8, 233),
    "hocker_windup_1": ("long wet inhale swelling up, gurgling build-up rising in pitch", 1.3, 234),
    "hocker_spit_1": ("thick wet spit launched hard, liquid splat burst, short", 0.8, 235),
    "hocker_spit_2": ("heavy glob of liquid spat out with a wet pop, short", 0.8, 236),
    "hocker_hurt_1": ("gurgling pained yelp, wet throat, short", 0.8, 237),
    "hocker_death_1": ("wet gurgling collapse with liquid bursting out, short", 1.6, 238),
    "hocker_death_2": ("choking liquid death rattle fading, body falling", 1.6, 239),
    # Sound pass 2026-11-08 (lore developer's list; tone rules in assets/audio/README.md)
    "reload_1": ("rifle magazine released and dropped, fresh magazine slapped in, charging handle racked, close, outdoor", 2.0, 401),
    "reload_2": ("assault rifle reload, empty magazine drops, new magazine seated with a firm click, bolt released, close, outdoor", 2.0, 402),
    "dry_fire_1": ("single trigger click on an empty rifle, small dry metal click, close", 0.3, 403),
    "knockdown_1": ("soldier slammed onto asphalt, plate carrier and helmet clatter, breath knocked out, close", 1.0, 404),
    "downed_1": ("man collapsing to the ground with a pained groan, rifle and gear clattering", 1.4, 405),
    "revive_1": ("tourniquet strap ratcheted tight, velcro rip, man exhaling hard, close", 1.5, 406),
    "roll_1": ("soldier diving into a roll on concrete, body thud, webbing and magazines rattling", 0.8, 407),
    "roll_2": ("soldier sliding across gravel and concrete, gear scraping, body thud, close", 0.8, 408),
    "breach_1": ("breaching charge detonation, sharp close blast, door splinters and dust", 1.5, 409, TAIL),
    "low_health_1": ("man breathing hard and ragged through clenched teeth, muffled, close", 3.0, 410),
    "vault_1": ("soldier vaulting a concrete barrier, hands slap, gear rattles, boots land", 0.8, 411),
    "dash_1": ("short burst of sprinting, boots pounding, kit rattling, cloth rush", 0.7, 412),
    "pallet_land_1": ("heavy supply pallet dropped from height onto concrete, wood crash, metal crates rattling, straps whipping", 2.0, 421),
    "flare_burn_1": ("road flare burning, sputtering fizz and steady hiss, close", 3.0, 422),
    "callin_throw_1": ("small metal canister thrown, lands with a clank and rolls on concrete", 0.8, 423),
    "tripline_arm_1": ("mechanical spring latch snapping shut with one quiet electronic chirp, small device, close", 0.4, 424),
    "tripline_blast_1": ("anti-personnel mine detonation, sharp blast, dirt and shrapnel, outdoor, close", 1.5, 425, TAIL),
    "anvil_incoming_1": ("incoming artillery shell tearing overhead, short descending rush, outdoor", 1.0, 426),
    "anvil_blast_1": ("artillery shell impact, huge blast with debris and rolling rumble, outdoor, medium distance", 2.5, 427, TAIL),
    "pen_coil_1": ("high-voltage capacitor discharge, heavy electric crack and buzzing arc, close", 1.0, 428),
    "magpie_hover_1": ("small quadcopter hovering, steady motor whine, mid distance", 3.0, 429),
    "warden_handset_1": ("radio handset keyed open, squelch then crackling carrier hiss, garbled, small speaker, close", 1.2, 441),
    "warden_handset_2": ("police radio handset clicking on, burst of static and broken carrier noise, small speaker, close", 1.2, 442),
    "warden_impact_1": ("heavy armoured fists slammed into asphalt, concrete cracking, grit and debris, close", 1.2, 443),
    "warden_pound_1": ("massive double impact into a road, deep concrete crack and rumble, debris raining, close", 2.0, 444, TAIL),
    "warden_swing_1": ("heavy riot shield swung hard, polycarbonate whoosh then a dull body thud, close", 0.8, 445),
    "warden_step_1": ("very heavy armoured footstep on asphalt, metal plates rattling, close", 0.6, 446),
    "warden_plate_1": ("thick armour plate torn away, plastic and bone cracking, heavy clatter on road", 1.0, 447),
    "warden_roar_1": ("huge hoarse man bellowing, ragged wet throat, close", 2.0, 448),
    "warden_canister_1": ("tear gas canister popping and jetting gas, loud hiss, outdoor, close", 2.0, 449),
    "warden_death_1": ("huge armoured body collapsing onto asphalt, plates clattering, last wet breath, radio hiss cutting off", 2.5, 450),
    "radio_in_1": ("military field radio squelch break, short burst of static, small speaker, close", 0.6, 461),
    "objective_complete_1": ("two short radio squelch clicks, then clean static, small speaker", 1.0, 462),
    "card_pick_1": ("magazines pushed into a pouch, velcro flap closed, metal clack, close", 0.7, 463),
    "kia_1": ("radio carrier hiss dropping to dead air, small speaker", 1.5, 464),
    "ui_click_1": ("rubber radio keypad button press, small dry click, close", 0.2, 465),
    "lantern_rotor_1": ("military helicopter approaching overhead, heavy rotor thump and wash, outdoor", 6.0, 481, TAIL),
    "amb_city_1": ("distant city burning at night, low fire roar, faraway gunfire and collapsing debris", 6.0, 482, TAIL),
    "amb_wind_1": ("night wind through a chain-link fence, metal rattle, outdoor", 6.0, 483, TAIL),
    "amb_siren_1": ("civil defence siren wailing, slow rise and fall, distant, outdoor", 6.0, 484, TAIL),
}

# bank: its clips, in file order. A clip may only sit in one bank. The group of a clip is its
# name without the trailing _<n>; the game picks a random clip of a group per event.
BANKS = {
    "player_steps": [f"step_hard_{i}" for i in range(1, 5)] + [f"step_soft_{i}" for i in range(1, 4)],
    "player_hits": ["bodyshot_1", "bodyshot_2", "bodyshot_3", "headshot_1", "headshot_2", "hurt_1", "hurt_2"],
    "walker": [n for n in SOUNDS if n.startswith("walker_") and n[-1].isdigit()],
    "runner": [n for n in SOUNDS if n.startswith("runner_") and n[-1].isdigit()],
    "brute": [n for n in SOUNDS if n.startswith("brute_") and n[-1].isdigit()],
    "hocker": [n for n in SOUNDS if n.startswith("hocker_") and n[-1].isdigit()],
    "player_gear": ["reload_1", "reload_2", "dry_fire_1", "knockdown_1", "downed_1", "revive_1", "roll_1",
                    "roll_2", "breach_1", "low_health_1", "vault_1", "dash_1"],
    "callins": ["pallet_land_1", "flare_burn_1", "callin_throw_1", "tripline_arm_1", "tripline_blast_1",
                "anvil_incoming_1", "anvil_blast_1", "pen_coil_1", "magpie_hover_1"],
    "warden": [n for n in SOUNDS if n.startswith("warden_") and n[-1].isdigit()],
    "ui_radio": ["radio_in_1", "objective_complete_1", "card_pick_1", "kia_1", "ui_click_1"],
    "ambience": ["lantern_rotor_1", "amb_city_1", "amb_wind_1", "amb_siren_1"],
}
BANK_GAP = 0.15  # seconds of silence between clips so a seek never bleeds into the next one
REPO_ROOT = os.environ.get("RAS_REPO") or os.path.normpath(os.path.join(HERE, "..", "..", ".."))

NEGATIVE = "music, melody, speech, reverb tail, low quality, distortion, clipping"


def load_model():
    import torch
    from stable_audio_tools import get_pretrained_model

    torch.set_num_threads(max(1, os.cpu_count() - 2))
    print(f"torch {torch.__version__}, {torch.get_num_threads()} threads", flush=True)
    model, config = get_pretrained_model(MODEL)
    model = model.to("cpu").eval()
    return model, config


# Sound profiles: one master description per speaker, appended to every prompt of its
# bank so the clips sound like one character (assets/audio/README.md "Sound profiles").
# Every boss gets its own bank and profile (docs/PROGRESSION.md "Boss sound"). A bank
# without a profile here was generated before profiles existed; add one when it is next
# regenerated, and regenerate the whole bank so it stays uniform.
PROFILES = {
    "warden": "one huge man in police riot armour with a radio harness, heavy, low, close, outdoor on asphalt",
}


def profiled(name, prompt):
    for bank, clips in BANKS.items():
        if name in clips and bank in PROFILES:
            return f"{prompt}, {PROFILES[bank]}"
    return prompt


def generate(model, config, name, prompt, seconds, seed, negative_prompt=None):
    import math

    import soundfile
    import torch
    from einops import rearrange
    from stable_audio_tools.inference.generation import generate_diffusion_cond

    sample_rate = config["sample_rate"]
    sample_size = config["sample_size"]
    conditioning = [{"prompt": prompt, "seconds_total": seconds}]
    negative = [{"prompt": negative_prompt or NEGATIVE, "seconds_total": seconds}]
    t0 = time.time()
    with torch.no_grad():
        latents = generate_diffusion_cond(
            model,
            steps=8,
            cfg_scale=1.0,
            conditioning=conditioning,
            negative_conditioning=negative,
            sample_size=sample_size,
            sampler_type="pingpong",
            device="cpu",
            seed=seed,
            return_latents=True,
        )
        t1 = time.time()
        # The autoencoder decode is the slow step on CPU and its cost scales with length, so
        # decode only the latent frames that cover the requested duration (+ a little slack).
        ratio = model.pretransform.downsampling_ratio
        frames = min(latents.shape[-1], math.ceil(seconds * sample_rate / ratio) + 4)
        audio = model.pretransform.decode(latents[..., :frames])
    t2 = time.time()
    audio = rearrange(audio, "b d n -> d (b n)").to(torch.float32)
    # Keep only the requested duration, then trim trailing near-silence.
    audio = audio[:, : int(seconds * sample_rate)]
    peak = audio.abs().max().clamp(min=1e-6)
    audio = audio / peak
    envelope = audio.abs().max(dim=0).values
    above = (envelope > 0.01).nonzero()
    if len(above):
        end = min(int(above[-1]) + int(0.05 * sample_rate), audio.shape[1])
        audio = audio[:, :end]
    audio = (audio * 0.95).clamp(-1, 1)
    path = os.path.join(OUT_DIR, name + ".wav")
    soundfile.write(path, audio.T.numpy(), sample_rate, subtype="PCM_16")
    print(
        f"{name}: {audio.shape[1] / sample_rate:.2f}s  diffusion {t1 - t0:.0f}s  decode {t2 - t1:.0f}s -> {path}",
        flush=True,
    )


def build_banks():
    """Pack every complete bank into one wav and write src/shared/SoundBankData.luau."""
    import numpy
    import soundfile

    bank_dir = os.path.join(OUT_DIR, "banks")
    os.makedirs(bank_dir, exist_ok=True)
    data = {}
    for bank, clips in BANKS.items():
        paths = [os.path.join(OUT_DIR, c + ".wav") for c in clips]
        missing = [c for c, p in zip(clips, paths) if not os.path.exists(p)]
        if missing:
            print(f"bank {bank}: skipped, missing {', '.join(missing)}", flush=True)
            continue
        pieces, offsets, cursor, rate = [], {}, 0.0, 44100
        for clip, path in zip(clips, paths):
            audio, rate = soundfile.read(path, dtype="float32", always_2d=True)
            length = audio.shape[0] / rate
            offsets[clip] = (round(cursor, 3), round(length, 3))
            gap = numpy.zeros((int(BANK_GAP * rate), audio.shape[1]), dtype="float32")
            pieces += [audio, gap]
            cursor += length + BANK_GAP
        out = os.path.join(bank_dir, bank + ".wav")
        soundfile.write(out, numpy.concatenate(pieces), rate, subtype="PCM_16")
        data[bank] = offsets
        print(f"bank {bank}: {len(clips)} clips, {cursor:.1f}s -> {out}", flush=True)
    if not data:
        return
    lines = [
        "--!strict",
        "-- GENERATED by assets/audio/build/generate.py (build_banks); do not edit. Clip offsets",
        "-- (start, length in seconds) inside each packed bank wav. Asset ids live in SoundBanks.",
        "",
        "return {",
    ]
    for bank in BANKS:
        if bank not in data:
            continue
        lines.append(f"\t{bank} = {{")
        for clip, (start, length) in data[bank].items():
            lines.append(f"\t\t{clip} = {{ start = {start}, length = {length} }},")
        lines.append("\t},")
    lines += ["}", ""]
    path = os.path.join(REPO_ROOT, "src", "shared", "SoundBankData.luau")
    if os.path.isdir(os.path.dirname(path)):
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lines))
        print(f"wrote {path}", flush=True)
    else:
        print(f"no repo at {REPO_ROOT}; set RAS_REPO to write SoundBankData.luau", flush=True)


def main(argv):
    if "--banks" in argv:
        build_banks()
        return
    if "--list" in argv:
        for name, entry in SOUNDS.items():
            prompt, seconds = entry[0], entry[1]
            print(f"{name:22s} {seconds:4.1f}s  {prompt}")
        return
    names = [a for a in argv if not a.startswith("--")] or list(SOUNDS)
    unknown = [n for n in names if n not in SOUNDS]
    if unknown:
        sys.exit("unknown sound(s): " + ", ".join(unknown))
    os.makedirs(OUT_DIR, exist_ok=True)
    model, config = load_model()
    for name in names:
        entry = SOUNDS[name]
        prompt = profiled(name, entry[0])
        generate(model, config, name, prompt, entry[1], entry[2], entry[3] if len(entry) > 3 else None)
    manifest = {n: {"prompt": profiled(n, SOUNDS[n][0]), "seconds": SOUNDS[n][1], "seed": SOUNDS[n][2]} for n in SOUNDS}
    with open(os.path.join(HERE, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)
    build_banks()


if __name__ == "__main__":
    main(sys.argv[1:])
