const fs = require('fs');
const html = fs.readFileSync(process.argv[2], 'utf8');
const m = html.match(/\/\/ ==CORE_START==([\s\S]*?)\/\/ ==CORE_END==/);
if (!m) throw new Error('core markers not found');
const core = new Function(m[1] + '; return {W,H,PY,DEF,newGame,update,stats,cost,reward,stageDef,baseHp,DOGS,offlineReward};')();
const { W, PY, newGame, update, cost, reward, stats, DOGS, offlineReward } = core;
let DOG = 'beagle';

function smartInput(g) {
  // manual: stand under the lowest enemy, step out of warned zones and incoming shots
  let tx = W / 2, best = -1e9;
  for (const e of g.en) if (e.y > best) { best = e.y; tx = e.x; }
  const bad = [];
  for (const z of g.zones) if (z.age < z.warn + z.act) bad.push([z.x - z.w / 2 - 22, z.x + z.w / 2 + 22]);
  for (const s of g.shots) if (s.y > PY - 130 && s.y < PY + 10) bad.push([s.x - 22, s.x + 22]);
  const inBad = x => bad.some(([a, b]) => x > a && x < b);
  if (inBad(tx) || inBad(g.px)) {
    let bx = null, bd = 1e9;
    for (let x = 20; x <= W - 20; x += 4) {
      if (inBad(x)) continue;
      const d = Math.abs(x - g.px) * 1 + Math.abs(x - tx) * 0.3;
      if (d < bd) { bd = d; bx = x; }
    }
    if (bx !== null) tx = bx;
  }
  return { down: true, x: tx, ult: g.gauge >= 100 };
}
function autoInput(g) { return { down: false, x: g.px, ult: g.gauge >= 100 }; }

function run(stage, up, policy, seed) {
  const g = newGame(stage, up, seed, DOG);
  let steps = 0;
  while (g.status === 'play' && steps < 60 * 150) { update(g, 1 / 60, policy(g)); steps++; }
  return { status: g.status, coins: g.coins, time: g.t, hp: g.hp, maxHp: g.maxHp, kills: g.kills };
}

function campaign(policyName, policy) {
  const up = { atk: 0, spd: 0, hp: 0 };
  let coins = 0, rows = [];
  const keys = ['atk', 'spd', 'hp'];
  const spend = () => {
    let bought = true;
    while (bought) {
      bought = false;
      // buy the lowest-level stat first
      keys.sort((a, b) => up[a] - up[b]);
      for (const k of keys) {
        const c = cost(up[k]);
        if (coins >= c) { coins -= c; up[k]++; bought = true; break; }
      }
    }
  };
  for (let s = 1; s <= 10; s++) {
    let tries = 0, res;
    do {
      tries++;
      res = run(s, up, policy, 5000 + s * 31 + tries);
      coins += res.status === 'won' ? res.coins : Math.floor(res.coins * 0.5);
      spend();
    } while (res.status !== 'won' && tries < 12);
    rows.push({ stage: s, tries, won: res.status === 'won', time: +res.time.toFixed(1), hpLeft: Math.round(res.hp), lv: `${up.atk}/${up.spd}/${up.hp}`, coinsLeft: coins });
  }
  console.log('== ' + policyName);
  console.table(rows);
}

for (const d of Object.keys(DOGS)) {
  DOG = d;
  console.log('######## ' + DOGS[d].name);
  campaign('auto only', autoInput);
  campaign('smart manual', smartInput);
}
DOG = 'beagle';
console.log('offline: stage5 60min', offlineReward(5, 60, false), '| 600min', offlineReward(5, 600, false), '| club 600min', offlineReward(5, 600, true));

// boss check at fixed levels
for (const lv of [0, 2, 4, 6]) {
  const up = { atk: lv, spd: lv, hp: lv };
  const out = [5, 10].map(s => {
    const a = run(s, up, autoInput, 11), b = run(s, up, smartInput, 11);
    return `s${s} auto:${a.status}(${a.time.toFixed(0)}s) smart:${b.status}(${b.time.toFixed(0)}s,hp ${Math.round(b.hp)})`;
  });
  console.log('all-stat level', lv, out.join(' | '));
}
