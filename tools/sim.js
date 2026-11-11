const fs = require('fs');
const html = fs.readFileSync(process.argv[2], 'utf8');
const m = html.match(/\/\/ ==CORE_START==([\s\S]*?)\/\/ ==CORE_END==/);
if (!m) throw new Error('core markers not found');
const C = new Function(m[1] + '; return {newGame,update,cost,reward,dayLen,decadeBonus,questReward,label,offlineReward,progress};')();
const { newGame, update, cost, reward, decadeBonus, questReward, label, offlineReward } = C;

function autoPolicy() { return { down: false, x: 0, y: 0 }; }
function manualPolicy(g) {
  let tgt = null;
  for (const s of g.sp) { if (s.bloom) continue; if (!tgt || s.p / s.need < tgt.p / tgt.need) tgt = s; }
  const o = { down: !!tgt, x: tgt ? tgt.x : 0, y: tgt ? tgt.y - 30 : 0 };
  const w = g.sp.find(s => s.weed > 0);
  if (w && g.t % 1.5 < 1 / 60) o.tapWeed = { x: w.x, y: w.y - 30 };
  return o;
}
function run(n, up, policy, seed, buff) {
  const g = newGame(n, up, seed, buff);
  let steps = 0;
  while (g.status === 'play' && steps < 60 * 300) { update(g, 1 / 60, policy(g)); steps++; }
  return { status: g.status, gain: g.gain, time: g.t, day: g.day };
}
const keys = ['fly', 'can', 'soil'];
function campaign(name, policy, maxN, report) {
  const up = { fly: 0, can: 0, soil: 0 };
  let dew = 0, total = 0, quests = 0, stuck = null; const rows = [];
  const spend = () => {
    let again = true;
    while (again) {
      again = false;
      keys.sort((a, b) => up[a] - up[b]);
      for (const k of keys) {
        const c = cost(up[k]);
        if (dew >= c) { dew -= c; up[k]++; total++; again = true; break; }
      }
      while (total >= 10 * (quests + 1)) { quests++; dew += questReward(quests, total); again = true; }
    }
  };
  let totalTries = 0;
  for (let n = 1; n <= maxN; n++) {
    let tries = 0, r;
    do { tries++; r = run(n, up, policy, 900 + n * 17 + tries); dew += r.gain; spend(); } while (r.status !== 'won' && tries < 25);
    totalTries += tries;
    if (r.status === 'won' && n % 10 === 0) { dew += decadeBonus(n); spend(); }
    if (r.status !== 'won' && !stuck) stuck = n;
    if (report.includes(n)) rows.push({ stage: label(n), tries, won: r.status === 'won', time: Math.round(r.time), day: r.day, lv: `${up.fly}/${up.can}/${up.soil}`, upgrades: total, quests });
  }
  console.log('== ' + name + ' | 막힌 스테이지:', stuck ? label(stuck) : '없음', '| 평균 시도', (totalTries / maxN).toFixed(2));
  console.table(rows);
}
const rep = [1, 5, 10, 20, 30, 50, 75, 100, 101, 150, 200, 300];
campaign('자동만', autoPolicy, 300, rep);
campaign('직접 조작', manualPolicy, 300, rep);
console.log('방치 보상 1-50 기준 60분', offlineReward(50, 60, false), '| 300분', offlineReward(50, 300, false), '| 구독 400분', offlineReward(50, 400, true));
const rec = [];
for (const n of [5, 10, 20, 50, 100, 150, 200]) {
  let L = 0; for (; L < 80; L++) { const up = { fly: L, can: L, soil: L }; let ok = 0; for (let k = 0; k < 6; k++) if (run(n, up, autoPolicy, 50 + k).status === 'won') ok++; if (ok === 6) break; }
  rec.push(label(n) + ':Lv' + L);
}
console.log('자동 클리어 최소 전체 Lv(6판 모두 성공):', rec.join('  '));
const b0 = run(30, { fly: 3, can: 3, soil: 3 }, autoPolicy, 7, false), b1 = run(30, { fly: 3, can: 3, soil: 3 }, autoPolicy, 7, true);
console.log('축복 효과(1-30, Lv3 자동): 없음', Math.round(b0.time) + 's', b0.status, '/ 있음', Math.round(b1.time) + 's', b1.status);
