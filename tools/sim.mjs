// Mô phỏng kinh tế Tap Block Out: node tools/sim.mjs
// Không dùng economy.simulateEconomy của Horus vì hàm đó mô hình hoá nâng cấp theo map và quãng đường.
// Hành vi người chơi trong PROFILES và tỉ lệ thắng là giả định, chưa có số liệu thật.

const ECON = {
  startGold: 1000, win: 40, livesMax: 10, refillGold: 900, refillLives: 5,
  shopVideo: 200, shopVideoMax: 5, aPrice: 1900, bPrice: [900, 1900, 2900, 3900], bVideoMax: 2,
  cosmeticPrice: [50, 75, 100], cosmeticCount: 24,
};
const CAL = [
  [50], [100], [0, 'hint'], [200], [0, 'move'], [300], [500, 'smash'],
  [100], [150], [0, 'hint'], [250], [0, 'move'], [350], [600, 'smash'],
  [150], [200], [0, 'hint'], [300], [0, 'move'], [400], [700, 'smash'],
  [200], [250], [0, 'hint'], [350], [0, 'move'], [500], [1000, 'smash', 'hint', 'move'],
];
const BLOCKS = [2, 3, 4, 5, 7, 8, 10, 10, 12, 13, 15, 16, 16, 18, 20, 22, 22, 24, 26, 28];
const HARD20 = new Set([8, 12, 16, 20]);
const AD_SEC = 30, READ = 2.5, READ_HARD = 3.5, OVERHEAD = 5, SAVE_RATE = 0.8, BOOST = 0.15;
const DAYS = 28, SESSIONS_PER_DAY = 2, SESSION_SEC = 600, SEEDS = 500;

const PROFILES = {
  noads: { label: 'Không xem quảng cáo', x2: 0, video: 0, calClaim: 0.8, calAd: 0, shop: 0, wA: 0.3, wB: [0.5, 0.2, 0.1, 0.05], freeBoost: 0, refillVideo: 0, cosmetic: 0.25 },
  some: { label: 'Thỉnh thoảng xem', x2: 0.5, video: 0.6, calClaim: 0.8, calAd: 0.5, shop: 2, wA: 0.2, wB: [0.3, 0.15, 0.05, 0.05], freeBoost: 0.25, refillVideo: 0.6, cosmetic: 0.25 },
  ads: { label: 'Xem nhiều', x2: 0.9, video: 0.9, calClaim: 0.9, calAd: 0.9, shop: 5, wA: 0.1, wB: [0.2, 0.1, 0.05, 0.05], freeBoost: 0.5, refillVideo: 0.9, cosmetic: 0.25 },
};

function mulberry(a) {
  return () => {
    a |= 0; a = a + 0x6D2B79F5 | 0;
    let t = Math.imul(a ^ a >>> 15, 1 | a);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}

const isHard = (l) => l <= 20 ? HARD20.has(l) : l % 4 === 0;
const blocks = (l) => l <= 20 ? BLOCKS[l - 1] : 24 + (l % 7);
function winRate(l) {
  if (isHard(l)) return 0.5;
  if (l <= 19) return 0.95 - (l - 1) * (0.95 - 0.72) / 18;
  return 0.7;
}

function play(p, seed) {
  const rnd = mulberry(seed);
  const s = {
    gold: ECON.startGold, level: 1, lives: ECON.livesMax, inv: { hint: 0, move: 0, smash: 0 }, cal: 0, owned: 0,
    t: 0, runs: 0, lastInterRun: -99, lastInterT: -999, lastRvT: -999, sessionStart: 0, firstSession: true,
    attempts: 0, losses: 0, rv: 0, inter: 0, aShown: 0, aSold: 0, aFromInv: 0, aShort: 0, bGold: 0, bVideo: 0, waits: 0,
    earn: { win: 0, x2: 0, cal: 0, shop: 0 }, spend: { a: 0, b: 0, refill: 0, cosmetic: 0 },
    dry: 0, maxDry: 0, canA: 0, gift4: false, gift6: false, gift9: false,
  };
  const out = { days: {}, chap: {}, l20: null };
  const rv = () => { s.rv++; s.t += AD_SEC; s.lastRvT = s.t; };

  function gifts() {
    if (s.level >= 4 && !s.gift4) { s.gift4 = true; s.inv.hint++; }
    if (s.level >= 6 && !s.gift6) { s.gift6 = true; s.inv.move++; }
    if (s.level >= 9 && !s.gift9) { s.gift9 = true; s.inv.smash++; }
  }
  function grantCal() {
    const r = CAL[s.cal % CAL.length];
    s.gold += r[0]; s.earn.cal += r[0];
    for (const k of r.slice(1)) s.inv[k]++;
    s.cal++;
  }
  function maybeInter(x2Offered, x2Taken) {
    const sinceStart = s.t - s.sessionStart;
    if (!x2Offered || x2Taken || s.runs < 4 || s.runs - s.lastInterRun < 2 || s.t - s.lastInterT < 120) return;
    if (sinceStart < 90 || s.t - s.lastRvT < 45 || (s.firstSession && s.level <= 10)) return;
    s.inter++; s.t += AD_SEC; s.lastInterRun = s.runs; s.lastInterT = s.t;
  }
  function rescue() {
    s.aShown++; s.t += 3;
    let used = false;
    if (s.inv.move > 0) { s.inv.move--; s.aFromInv++; used = true; }
    else if (s.gold >= ECON.aPrice && rnd() < p.wA) {
      s.gold -= ECON.aPrice; s.spend.a += ECON.aPrice; s.aSold++; used = true;
    } else if (s.gold < ECON.aPrice) s.aShort++;
    if (used && rnd() < SAVE_RATE) return true;
    for (let n = 0; n < ECON.bPrice.length; n++) {
      s.t += 3;
      const price = ECON.bPrice[n];
      if (n < ECON.bVideoMax && rnd() < p.video) { rv(); s.bVideo++; }
      else if (s.inv.move > 0) s.inv.move--;
      else if (s.gold >= price && rnd() < p.wB[n]) { s.gold -= price; s.spend.b += price; s.bGold++; }
      else return false;
      if (rnd() < SAVE_RATE) return true;
    }
    return false;
  }
  function attempt() {
    const l = s.level, hard = isHard(l);
    gifts();
    s.attempts++; s.runs++;
    s.t += blocks(l) * (hard ? READ_HARD : READ) + OVERHEAD;
    let rate = winRate(l);
    if (hard && l >= 4) {
      if (s.inv.hint > 0) { s.inv.hint--; rate += BOOST; }
      else if (rnd() < p.freeBoost) { rv(); rate += BOOST; }
      if (l >= 9 && s.inv.smash > 0) { s.inv.smash--; rate += BOOST; }
    }
    const won = rnd() < rate || rescue();
    if (!won) {
      s.losses++;
      if (l >= 10) s.lives--;
      return;
    }
    s.gold += ECON.win; s.earn.win += ECON.win;
    const firstFree = l === 1;
    const x2 = firstFree || rnd() < p.x2;
    if (x2) {
      if (!firstFree) rv();
      s.gold += ECON.win; s.earn.x2 += ECON.win;
    }
    maybeInter(!firstFree, x2);
    if (s.gold < ECON.bPrice[0]) { s.dry++; s.maxDry = Math.max(s.maxDry, s.dry); } else s.dry = 0;
    if (!s.canA && s.gold >= ECON.aPrice) s.canA = l;
    s.level++;
    if (s.level - 1 === 5 || s.level - 1 === 10 || s.level - 1 === 15 || s.level - 1 === 20) {
      out.chap[s.level - 1] = { min: s.t / 60, gold: s.gold };
    }
    if (s.level - 1 === 20) {
      out.l20 = { min: s.t / 60, attempts: s.attempts, losses: s.losses, aSold: s.aSold, bGold: s.bGold, bVideo: s.bVideo, rv: s.rv, gold: s.gold, waits: s.waits, maxDry: s.maxDry };
    }
  }
  function refill() {
    if (rnd() < p.refillVideo) { rv(); s.lives = 1; return true; }
    if (s.gold >= ECON.refillGold && rnd() < 0.5) {
      s.gold -= ECON.refillGold; s.spend.refill += ECON.refillGold; s.lives = ECON.refillLives;
      return true;
    }
    s.waits++;
    return false;
  }
  function daily(state) {
    if (s.level <= 3) return state;
    if (!state.claimed && rnd() < p.calClaim) {
      grantCal(); state.claimed = true;
      if (rnd() < p.calAd) { rv(); grantCal(); }
    }
    if (s.level >= 5) {
      for (; state.shop < p.shop; state.shop++) {
        rv(); s.gold += ECON.shopVideo; s.earn.shop += ECON.shopVideo;
      }
    }
    return state;
  }
  function cosmetic() {
    if (s.owned >= ECON.cosmeticCount || rnd() >= p.cosmetic) return;
    if (p.refillVideo > 0 && rnd() < p.video) { rv(); s.owned++; return; }
    const price = ECON.cosmeticPrice[s.owned % ECON.cosmeticPrice.length];
    if (s.gold >= price + ECON.aPrice) { s.gold -= price; s.spend.cosmetic += price; s.owned++; }
  }

  for (let day = 1; day <= DAYS; day++) {
    let state = { claimed: false, shop: 0 };
    cosmetic();
    for (let ss = 0; ss < SESSIONS_PER_DAY; ss++) {
      s.sessionStart = s.t; s.lives = ECON.livesMax;
      const end = s.t + SESSION_SEC;
      while (s.t < end) {
        if (s.level >= 10 && s.lives <= 0 && !refill()) break;
        attempt();
        state = daily(state);
      }
      s.firstSession = false;
    }
    if ([1, 7, 14, 28].includes(day)) {
      out.days[day] = { level: s.level, gold: s.gold, ...s.earn, ...spendKeys(s.spend), rv: s.rv, inter: s.inter, aShown: s.aShown, aSold: s.aSold, aFromInv: s.aFromInv, aShort: s.aShort, bGold: s.bGold, bVideo: s.bVideo, waits: s.waits, calCells: s.cal };
    }
  }
  out.canA = s.canA;
  return out;
}
function spendKeys(sp) { return { sA: sp.a, sB: sp.b, sRefill: sp.refill, sCosmetic: sp.cosmetic }; }

function mean(list, pick) {
  const vals = list.map(pick).filter((v) => v !== null && v !== undefined);
  return vals.length ? vals.reduce((a, b) => a + b, 0) / vals.length : 0;
}
const n0 = (v) => Math.round(v).toLocaleString('vi-VN');
const n1 = (v) => v.toFixed(1).replace('.', ',');
const row = (cells) => `| ${cells.join(' | ')} |`;
const table = (head, rows) => [row(head), row(head.map(() => '---')), ...rows.map(row)].join('\n');

const runs = {};
for (const [id, p] of Object.entries(PROFILES)) {
  runs[id] = Array.from({ length: SEEDS }, (_, i) => play(p, i * 7919 + 13));
}
const ids = Object.keys(PROFILES), L = (id) => PROFILES[id].label;

console.log(`### L1–20 (trung bình ${SEEDS} lần chạy)\n`);
console.log(table(['Người chơi', 'Thời gian', 'Số lần chơi', 'Thua', 'A bán', 'B gold / video', 'Rewarded', 'Gold còn', 'Hết mạng phải chờ', 'Chuỗi level dài nhất dưới 900 gold'],
  ids.map((id) => {
    const r = runs[id], m = (k) => mean(r, (x) => x.l20?.[k]);
    return [L(id), `${n1(m('min'))} phút`, n0(m('attempts')), n0(m('losses')), n1(m('aSold')), `${n1(m('bGold'))} / ${n1(m('bVideo'))}`, n0(m('rv')), n0(m('gold')), n1(m('waits')), n1(m('maxDry'))];
  })));

console.log('\n### Theo chặng\n');
console.log(table(['Chặng', ...ids.map(L)], [5, 10, 15, 20].map((c) => [`Hết L${c}`, ...ids.map((id) => {
  const m = (k) => mean(runs[id], (x) => x.chap[c]?.[k]);
  return `${n1(m('min'))} phút, ${n0(m('gold'))} gold`;
})])));

console.log('\n### 28 ngày, 20 phút mỗi ngày\n');
for (const id of ids) {
  console.log(`**${L(id)}**\n`);
  console.log(table(['Hết ngày', 'Level', 'Gold còn', 'Thắng + x2', 'Lịch quà', 'Video shop', 'A', 'B', 'Refill', 'Avatar', 'Rewarded', 'Interstitial', 'Ô lịch'],
    [1, 7, 14, 28].map((d) => {
      const m = (k) => mean(runs[id], (x) => x.days[d][k]);
      return [d, n0(m('level')), n0(m('gold')), n0(m('win') + m('x2')), n0(m('cal')), n0(m('shop')), n0(m('sA')), n0(m('sB')), n0(m('sRefill')), n0(m('sCosmetic')), n0(m('rv')), n0(m('inter')), n0(m('calCells'))];
    })));
  console.log('');
}

console.log('### Popup A trong 28 ngày\n');
console.log(table(['Người chơi', 'Lần hiện', 'Dùng từ kho', 'Mua bằng gold', 'Thiếu gold', 'Level đầu đủ 1.900 gold', 'Rewarded mỗi ngày', 'Interstitial mỗi ngày'],
  ids.map((id) => {
    const m = (k) => mean(runs[id], (x) => x.days[28][k]);
    return [L(id), n0(m('aShown')), n0(m('aFromInv')), n0(m('aSold')), n0(m('aShort')), n0(mean(runs[id], (x) => x.canA || null)), n1(m('rv') / DAYS), n1(m('inter') / DAYS)];
  })));
