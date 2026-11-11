const fs = require('fs');
const html = fs.readFileSync(process.argv[2], 'utf8');
const m = html.match(/\/\/ ==CORE_START==([\s\S]*?)\/\/ ==CORE_END==/);
if (!m) throw new Error('core markers not found');
const C = new Function(m[1] + '; return {W,H,newGame,update,cost,reward,dayLen,offlineReward,progress};')();
const { newGame, update, cost, reward, dayLen, offlineReward } = C;

// 자동: 손 안 댐. 직접: 가장 덜 자란 새싹 위에 물뿌리개를 두고 잡초는 바로 누른다
function autoPolicy() { return { down: false, x: 0, y: 0 }; }
function manualPolicy(g) {
  let tgt = null;
  for (const s of g.sp) {
    if (s.bloom) continue;
    if (!tgt || s.p / s.need < tgt.p / tgt.need) tgt = s;
  }
  const o = { down: !!tgt, x: tgt ? tgt.x : 0, y: tgt ? tgt.y - 30 : 0 };
  const w = g.sp.find(s => s.weed > 0);
  if (w && g.t % 1.5 < 1 / 60) o.tapWeed = { x: w.x, y: w.y - 30 };
  return o;
}
function run(stage, up, policy, seed) {
  const g = newGame(stage, up, seed);
  let steps = 0;
  while (g.status === 'play' && steps < 60 * 400) { update(g, 1 / 60, policy(g)); steps++; }
  return { status: g.status, gain: g.gain, time: g.t, day: g.day, bloomed: g.bloomed, total: g.total };
}
const keys = ['fly', 'can', 'soil'];
function campaign(name, policy) {
  const up = { fly: 0, can: 0, soil: 0 };
  let dew = 0; const rows = [];
  const spend = () => {
    let again = true;
    while (again) {
      again = false;
      keys.sort((a, b) => up[a] - up[b]);
      for (const k of keys) { const c = cost(up[k]); if (dew >= c) { dew -= c; up[k]++; again = true; break; } }
    }
  };
  for (let s = 1; s <= 10; s++) {
    let tries = 0, r;
    do { tries++; r = run(s, up, policy, 900 + s * 17 + tries); dew += r.gain; spend(); } while (r.status !== 'won' && tries < 10);
    rows.push({ stage: s, tries, won: r.status === 'won', time: Math.round(r.time), day: r.day, lv: `${up.fly}/${up.can}/${up.soil}`, dewLeft: dew });
  }
  console.log('== ' + name); console.table(rows);
}
campaign('자동만', autoPolicy);
campaign('직접 조작', manualPolicy);
console.log('방치 보상 스테이지5 60분', offlineReward(5, 60, false), '| 500분', offlineReward(5, 500, false), '| 구독 500분', offlineReward(5, 500, true));
for (const lv of [0, 2, 3, 4, 5, 6, 8]) {
  const up = { fly: lv, can: lv, soil: lv };
  const out = [1,2,3,4,5,6,7,8,9,10].map(s => {
    const a = run(s, up, autoPolicy, 11), b = run(s, up, manualPolicy, 11);
    return `${s}:${a.status[0]}${Math.round(a.time)}/${b.status[0]}${Math.round(b.time)}`;
  });
  console.log('전체 Lv', lv, '(자동/직접) ' + out.join(' '));
}
// 스테이지 1~4 클리어 때 누적 이슬과 5 클리어에 필요한 강화량
let tot = 0; for (let s = 1; s <= 4; s++) tot += reward(s);
console.log('1~4 클리어 합계 이슬', tot, ' 강화 비용 Lv0→1/2/3/4', cost(0), cost(1), cost(2), cost(3));
const rec = [];
for (let s = 1; s <= 10; s++) { let L = 0; for (; L < 20; L++) { const up = { fly: L, can: L, soil: L }; let ok = 0; for (let k = 0; k < 8; k++) if (run(s, up, autoPolicy, 50 + k).status === 'won') ok++; if (ok === 8) break; } rec.push(L); }
console.log('자동 클리어 최소 전체 Lv(8판 모두 성공):', rec.join(','));
const recm = [];
for (let s = 1; s <= 10; s++) { let L = 0; for (; L < 20; L++) { const up = { fly: 0, can: L, soil: 0 }; let ok = 0; for (let k = 0; k < 8; k++) if (run(s, up, manualPolicy, 50 + k).status === 'won') ok++; if (ok === 8) break; } recm.push(L); }
console.log('직접 조작 시 물뿌리개 Lv:', recm.join(','));
