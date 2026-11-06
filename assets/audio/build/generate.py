"""Generate the game's sound effects from text prompts with Stable Audio Open Small (CPU).

    bash generate.sh            # every sound in SOUNDS (runs this file inside Docker)
    bash generate.sh rifle_shot mine_blast   # a subset
    bash generate.sh --list     # print the sound list

Outputs assets/audio/<name>.wav (44.1 kHz stereo 16-bit, peak-normalised, trailing silence
trimmed). Edit SOUNDS to change a sound, then rerun; outputs are never hand-edited.

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
SOUNDS = {
    # weapon
    "rifle_shot": ("single assault rifle gunshot, close mic, sharp crack with short tail, outdoor, dry", 1.5, 11),
    "rifle_shot_alt": ("single assault rifle gunshot, close mic, punchy crack, slightly different take, outdoor", 1.5, 12),
    "bullet_hit_flesh": ("bullet impact on a body, wet thud with a slap, close, short", 0.8, 21),
    "bullet_hit_concrete": ("bullet ricochet off concrete, sharp crack and debris, short", 0.9, 22),
    # infected
    "infected_groan": ("zombie groan, low guttural rasping voice, menacing, close", 2.0, 31),
    "infected_groan_alt": ("zombie moan, hoarse wet growl, mid distance", 2.0, 32),
    "infected_death": ("zombie death cry, choked gurgling scream cut short, close", 1.6, 33),
    "runner_shriek": ("fast zombie shriek, high raspy screech, aggressive, close", 1.4, 34),
    "brute_roar": ("huge monster roar, deep chest rumble, long, close, heavy", 2.5, 35),
    "brute_death": ("huge monster dying groan collapsing to the ground, deep, heavy thud at the end", 2.5, 36),
    # rat
    "rat_squeak": ("rat squeak, small animal, quick, close", 0.6, 41),
    "rat_bite": ("small animal bite and scratch, quick scrabble on skin, close", 0.7, 42),
    # pickups and progression
    "xp_pickup": ("soft digital pickup blip, short rising tone, clean, game ui", 0.5, 51),
    "level_up": ("triumphant short military radio sting, two-note brass hit with a crisp snare, clean", 1.5, 52),
    "item_pick": ("solid metallic click confirm, tactical equipment latch, short, clean", 0.6, 53),
    # items
    "crate_land": ("wooden ammo crate dropped on concrete, heavy wood thud with rattle of metal inside", 1.2, 61),
    "crate_open": ("wooden crate lid opening with metal latch and ammunition clinking", 1.2, 62),
    "mine_arm": ("electronic device arming beep, two quick high beeps, small speaker", 0.8, 63),
    "mine_blast": ("landmine explosion, sharp blast with dirt debris, outdoor, close", 2.0, 64),
    "drone_hover": ("small quadcopter drone hovering, steady motor hum, seamless loop, mid distance", 4.0, 65),
    "drone_shot": ("small energy pistol shot, quick electric zap, clean", 0.7, 66),
    "airstrike_whistle": ("falling bomb whistle descending in pitch, outdoor, ominous", 2.2, 67),
    "airstrike_blast": ("large aerial bomb explosion with long rumbling tail, outdoor, distant and heavy", 3.5, 68),
    "fire_loop": ("ground fire burning, crackling flames, seamless loop, close", 4.0, 69),
    "shock_zap": ("electric arc discharge, crackling zap, short, close", 0.8, 70),
    # abilities
    "dash": ("quick whoosh of a person sprinting past, cloth and air rush, short", 0.8, 81),
    "breach": ("heavy concussive shockwave thump with a bass drop, short, close", 1.2, 82),
    # run flow
    "player_hurt": ("man grunting in pain from a hit, short, close", 0.8, 91),
    "player_down": ("man collapsing to the ground with a pained groan, gear clatter", 1.6, 92),
    "objective_tick": ("short radio beep confirm, military comms, clean", 0.5, 93),
    "objective_complete": ("military radio confirmation sting, static burst then a clean two-tone chime", 1.5, 94),
    "extraction_horn": ("distant helicopter approaching with rotor wash, outdoor, long", 5.0, 95),
}

NEGATIVE = "music, melody, speech, reverb tail, low quality, distortion, clipping"


def load_model():
    import torch
    from stable_audio_tools import get_pretrained_model

    torch.set_num_threads(max(1, os.cpu_count() - 2))
    print(f"torch {torch.__version__}, {torch.get_num_threads()} threads", flush=True)
    model, config = get_pretrained_model(MODEL)
    model = model.to("cpu").eval()
    return model, config


def generate(model, config, name, prompt, seconds, seed):
    import math

    import soundfile
    import torch
    from einops import rearrange
    from stable_audio_tools.inference.generation import generate_diffusion_cond

    sample_rate = config["sample_rate"]
    sample_size = config["sample_size"]
    conditioning = [{"prompt": prompt, "seconds_total": seconds}]
    negative = [{"prompt": NEGATIVE, "seconds_total": seconds}]
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


def main(argv):
    if "--list" in argv:
        for name, (prompt, seconds, seed) in SOUNDS.items():
            print(f"{name:22s} {seconds:4.1f}s  {prompt}")
        return
    names = [a for a in argv if not a.startswith("--")] or list(SOUNDS)
    unknown = [n for n in names if n not in SOUNDS]
    if unknown:
        sys.exit("unknown sound(s): " + ", ".join(unknown))
    os.makedirs(OUT_DIR, exist_ok=True)
    model, config = load_model()
    for name in names:
        prompt, seconds, seed = SOUNDS[name]
        generate(model, config, name, prompt, seconds, seed)
    manifest = {n: {"prompt": SOUNDS[n][0], "seconds": SOUNDS[n][1], "seed": SOUNDS[n][2]} for n in SOUNDS}
    with open(os.path.join(HERE, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)


if __name__ == "__main__":
    main(sys.argv[1:])
