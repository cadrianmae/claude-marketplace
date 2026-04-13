const http = require('http');
const fs = require('fs');
const { execSync } = require('child_process');
const path = require('path');

const PORT = 8321;

const server = http.createServer((req, res) => {
  if (req.method === 'GET' && (req.url === '/' || req.url === '/index.html')) {
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(fs.readFileSync(path.join(__dirname, 'index.html')));
    return;
  }

  if (req.method === 'POST' && req.url === '/play') {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
      try {
        const p = JSON.parse(body);
        const mode = p.mode || 'sequence';

        const script = generatePythonScript(p, mode);
        const tmpScript = path.join(require('os').tmpdir(), 'click-designer-play.py');
        fs.writeFileSync(tmpScript, script);
        execSync(`python3 ${tmpScript}`, { timeout: 10000 });

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ ok: true }));
      } catch (e) {
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: e.message }));
      }
    });
    return;
  }

  res.writeHead(404);
  res.end('Not found');
});

function generatePythonScript(p, mode) {
  return `
import struct, wave, math, random, subprocess, tempfile, os

sr = 44100

def make_click(params):
    dur = params['click_dur']
    lo_freq = params['lo_freq'] + random.randint(-150, 150)
    hi_freq = params['hi_freq'] + random.randint(-250, 250)
    sh_freq = params['shimmer_freq'] + random.randint(-200, 200)
    imp_amp = params['impulse_amp']
    attack_time = params['attack_time']

    samples = []
    if imp_amp > 0:
        samples += [0, imp_amp, -int(imp_amp*0.4), int(imp_amp*0.1), 0]

    # Smoothed noise
    n = int(sr * dur) + 20
    raw = [random.gauss(0, 1) for _ in range(n)]
    for _p in range(params['smooth_passes']):
        smoothed = []
        for j in range(len(raw)):
            start = max(0, j - 4)
            end = min(len(raw), j + 4)
            smoothed.append(sum(raw[start:end]) / (end - start))
        raw = smoothed

    for i in range(int(sr * dur)):
        t = i / sr
        attack = min(1.0, t / attack_time) if attack_time > 0 else 1.0
        lo_decay = math.exp(-t * params['lo_decay'])
        hi_decay = math.exp(-t * params['hi_decay'])
        sh_decay = math.exp(-t * params['shimmer_decay'])
        fr_decay = math.exp(-t * params['friction_decay'])

        lo = params['lo_amp'] * attack * lo_decay * math.sin(2 * math.pi * lo_freq * t)
        hi = params['hi_amp'] * attack * hi_decay * math.sin(2 * math.pi * hi_freq * t)
        sh = params['shimmer_amp'] * attack * sh_decay * math.sin(2 * math.pi * sh_freq * t)
        friction = params['friction_amt'] * attack * fr_decay * raw[i] if i < len(raw) else 0

        samples.append(int(lo + hi + sh + friction))
    return samples

params = {
    'lo_freq': ${p.lo_freq},
    'hi_freq': ${p.hi_freq},
    'shimmer_freq': ${p.shimmer_freq},
    'lo_amp': ${p.lo_amp},
    'hi_amp': ${p.hi_amp},
    'shimmer_amp': ${p.shimmer_amp},
    'lo_decay': ${p.lo_decay},
    'hi_decay': ${p.hi_decay},
    'shimmer_decay': ${p.shimmer_decay},
    'attack_time': ${p.attack_time},
    'click_dur': ${p.click_dur},
    'friction_amt': ${p.friction_amt},
    'friction_decay': ${p.friction_decay},
    'smooth_passes': ${p.smooth_passes},
    'impulse_amp': ${p.impulse_amp},
}

mode = '${mode}'
max_dur = ${p.max_dur}
start_rate = ${p.start_rate}

tmpf = tempfile.NamedTemporaryFile(suffix='.wav', delete=False)
tmpf.close()

w = wave.open(tmpf.name, 'w')
w.setnchannels(1)
w.setsampwidth(2)
w.setframerate(sr)

if mode == 'single':
    samples = make_click(params)
    samples += [0] * int(sr * 0.1)
    w.writeframes(struct.pack(f'<{len(samples)}h', *samples))
else:
    all_samples = []
    t = 0
    base_gap = (1.0 / start_rate) - params['click_dur']
    if base_gap < 0.001:
        base_gap = 0.001
    while t < max_dur:
        click_samples = make_click(params)
        all_samples.extend(click_samples)
        ratio = t / max_dur
        gap = base_gap * (1 + ratio * ratio * 4)
        gap_samples = int(sr * gap)
        all_samples.extend([0] * gap_samples)
        t += params['click_dur'] + gap
    w.writeframes(struct.pack(f'<{len(all_samples)}h', *all_samples))

w.close()

# Apply reverb via sox if enabled
reverb_on = ${p.reverb_on || 0}
reverb_file = tmpf.name.replace('.wav', '_reverb.wav')
if reverb_on:
    try:
        subprocess.run(['sox', tmpf.name, reverb_file, 'reverb',
            str(${p.reverb_verb || 40}), str(${p.reverb_hf || 50}), str(${p.reverb_room || 80})],
            check=True, capture_output=True)
        os.unlink(tmpf.name)
        tmpf_name = reverb_file
    except Exception:
        tmpf_name = tmpf.name
else:
    tmpf_name = tmpf.name

subprocess.run(['paplay', tmpf_name], check=True)
os.unlink(tmpf_name)
`;
}

server.listen(PORT, () => {
  console.log(JSON.stringify({ url: `http://localhost:${PORT}`, port: PORT }));
});
