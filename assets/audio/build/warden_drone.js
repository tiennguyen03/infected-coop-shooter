// The Warden's fight loop (no model): a low tension drone, synthesised, loop-safe.
//   node assets/audio/build/warden_drone.js [out.wav]
// Writes assets/audio/warden_drone.wav by default (git-ignored). Upload it under the group
// (assets/audio/build/upload_audio.js) and put the id in Config.Index.Warden.Music.Id and
// assets/audio/ASSET_IDS.md. Played looped by the client (BossPresence) from his arrival to
// his death, louder and a touch faster each stage.
//
// 16 s mono 16-bit at 44100 Hz. Every repeating part divides the loop exactly, so the end
// meets the start: an E/B low fifth (41.25 + 61.875 Hz) breathing on an 8 s swell, a soft
// low pulse every 0.8 s (a slow heartbeat under the fight; every 4th one heavier), a
// low-passed noise bed (cross-faded over its last second into its first), and a quiet
// beating mid tone (two sines 0.25 Hz apart) swelling every 8 s for unease. No hard edges:
// the owner turned the old ambience off because it "hurt my ears". Peak -6 dBFS.

const fs = require("fs");
const path = require("path");

const RATE = 44100;
const LENGTH = 16;
const N = RATE * LENGTH;
const PEAK_DB = -6;
const out = process.argv[2] || path.join(__dirname, "..", "warden_drone.wav");

// A seeded LCG so a rerun writes the same file.
let seed = 1914;
function rand() {
	seed = (seed * 1664525 + 1013904223) >>> 0;
	return seed / 4294967296;
}

const TAU = Math.PI * 2;
const buf = new Float64Array(N);

// The low fifth, breathing on an 8 s swell (2 cycles per loop).
for (let i = 0; i < N; i++) {
	const t = i / RATE;
	const swell = 0.75 + 0.25 * Math.sin((TAU * t) / 8);
	const drone =
		0.55 * Math.sin(TAU * 41.25 * t) +
		0.3 * Math.sin(TAU * 61.875 * t) +
		0.12 * Math.sin(TAU * 82.5 * t + 0.6);
	buf[i] += drone * swell * 0.6;
}

// The pulse: a sine thump sliding 70 -> 45 Hz, ~180 ms decay, every 0.8 s (20 per loop).
const PULSE = 0.8;
for (let k = 0; k < LENGTH / PULSE; k++) {
	const start = Math.round(k * PULSE * RATE);
	const level = k % 4 === 0 ? 0.55 : 0.32;
	let phase = 0;
	for (let j = 0; j < Math.round(0.6 * RATE); j++) {
		const t = j / RATE;
		const freq = 45 + 25 * Math.exp(-t / 0.08);
		phase += (TAU * freq) / RATE;
		const attack = Math.min(t / 0.008, 1);
		const env = attack * Math.exp(-t / 0.18);
		buf[(start + j) % N] += Math.sin(phase) * env * level;
	}
}

// The noise bed: white noise low-passed twice (~300 Hz), cross-faded over its last second.
const FADE = RATE;
const raw = new Float64Array(N + FADE);
{
	const alpha = 1 - Math.exp((-TAU * 300) / RATE);
	let a = 0;
	let b = 0;
	for (let i = 0; i < raw.length; i++) {
		a += alpha * (rand() * 2 - 1 - a);
		b += alpha * (a - b);
		raw[i] = b;
	}
}
for (let i = 0; i < N; i++) {
	let v = raw[i];
	if (i < FADE) {
		const w = i / FADE; // the tail of the run continues into the head
		v = raw[i] * w + raw[N + i] * (1 - w);
	}
	buf[i] += v * 1.6;
}

// Unease: two mid sines 0.25 Hz apart (a slow beat), swelling in and out every 8 s.
for (let i = 0; i < N; i++) {
	const t = i / RATE;
	const swell = Math.pow(Math.max(0, Math.sin((TAU * t) / 8 - Math.PI / 2)), 2);
	const tone = Math.sin(TAU * 164.75 * t) + Math.sin(TAU * 165 * t);
	buf[i] += tone * swell * 0.035;
}

// Normalise to the peak and write a 16-bit PCM WAV.
let peak = 0;
for (let i = 0; i < N; i++) peak = Math.max(peak, Math.abs(buf[i]));
const gain = Math.pow(10, PEAK_DB / 20) / peak;
const data = Buffer.alloc(N * 2);
for (let i = 0; i < N; i++) {
	const s = Math.max(-1, Math.min(1, buf[i] * gain));
	data.writeInt16LE(Math.round(s * 32767), i * 2);
}
const header = Buffer.alloc(44);
header.write("RIFF", 0);
header.writeUInt32LE(36 + data.length, 4);
header.write("WAVE", 8);
header.write("fmt ", 12);
header.writeUInt32LE(16, 16);
header.writeUInt16LE(1, 20); // PCM
header.writeUInt16LE(1, 22); // mono
header.writeUInt32LE(RATE, 24);
header.writeUInt32LE(RATE * 2, 28);
header.writeUInt16LE(2, 32);
header.writeUInt16LE(16, 34);
header.write("data", 36);
header.writeUInt32LE(data.length, 40);
fs.writeFileSync(out, Buffer.concat([header, data]));
console.log(`wrote ${out} (${LENGTH} s, peak ${PEAK_DB} dBFS)`);
