// Mô phỏng kinh tế Candy Away: node tools/sim.mjs
// Số của game đọc thẳng từ src/config.gd (giá trị mặc định, chưa tính Remote Config) và data/levels/ (số khối, HARD),
// nên sim chạy theo đúng số của bản đang có. Hành vi người chơi trong PROFILES, tỉ lệ thắng, thời gian đọc và số
// MOVES còn thừa lúc thắng là giả định, chưa có số liệu thật. Không dùng economy.simulateEconomy của Horus vì hàm đó
// mô hình hoá nâng cấp theo map và quãng đường.

import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');

// Đọc một hằng Dictionary/Array của config.gd thành object JS: bỏ comment, khoá số thành chuỗi, bỏ dấu phẩy cuối.
function gdConst(src, name) {
  const head = `const ${name} := `;
  const at = src.indexOf(head);
  if (at < 0) throw new Error(`src/config.gd: không có const ${name}`);
  let depth = 0, inStr = false, out = '';
  for (let i = at + head.length; i < src.length; i++) {
    const ch = src[i];
    if (inStr) {
      out += ch;
      if (ch === '\\') out += src[++i];
      else if (ch === '"') inStr = false;
      continue;
    }
    if (ch === '#') {
      while (i < src.length && src[i] !== '\n') i++;
      out += '\n';
      continue;
    }
    if (ch === '"') inStr = true;
    if (ch === '{' || ch === '[') depth++;
    if (ch === '}' || ch === ']') depth--;
    out += ch;
    if (depth === 0) break;
  }
  const json = out.replace(/([{,]\s*)(-?\d+)\s*:/g, '$1"$2":').replace(/,(\s*[}\]])/g, '$1');
  try {
    return JSON.parse(json);
  } catch (e) {
    throw new Error(`src/config.gd: ${name} không đọc được như JSON (${e.message})`);
  }
}

const CONFIG = readFileSync(join(ROOT, 'src/config.gd'), 'utf8');
const E = gdConst(CONFIG, '_ECON');
const LIVES = gdConst(CONFIG, '_LIVES');
const ADS = gdConst(CONFIG, '_ADS');
const UNLOCK = gdConst(CONFIG, '_UNLOCK');
const DAILY = gdConst(CONFIG, '_DAILY');
const CONTENT = gdConst(CONFIG, '_CONTENT');
const COS = gdConst(CONFIG, '_COSMETICS');
const LB = gdConst(CONFIG, '_LEADERBOARD');
const RT_COS = gdConst(CONFIG, 'ROAD_TRIP_COSMETICS');
// Món mở bằng video: mọi avatar, frame trừ món chỉ có từ Road Trip và thưởng league (design.md mục 5 "Avatar và frame").
// Món rẻ nhất mua bằng gold: chuỗi level không đủ tiền mua nó là chỉ số "kẹt gold".
const CHEAPEST = Math.min(...Object.values(E.booster_price), E.refill_coins);
const VIDEO_COSMETICS = COS.avatar_count + COS.frame_count - Object.keys(RT_COS).length - LB.cosmetics.length;

const LEVEL_DIR = join(ROOT, 'data/levels');
// Danh sách VeryHard của đường cong độ khó (src/core/difficulty_curve.gd).
const VERY_HARD = new Set(gdConst(readFileSync(join(ROOT, 'src/core/difficulty_curve.gd'), 'utf8'), 'VERY_HARD'));
const LEVELS = readdirSync(LEVEL_DIR).filter((f) => /^level_\d+\.json$/.test(f)).sort().map((f) => {
  const l = JSON.parse(readFileSync(join(LEVEL_DIR, f), 'utf8'));
  return { blocks: l.blocks.length, hard: !!l.hard, veryHard: VERY_HARD.has(l.id) };
});
// Sau level cuối game lặp lại nội dung từ CONTENT.loop_start_level.
function levelAt(l) {
  if (l <= LEVELS.length) return LEVELS[l - 1];
  const start = CONTENT.loop_start_level, span = LEVELS.length - start + 1;
  return LEVELS[start - 1 + ((l - start) % span)];
}
// MOVES dư theo bậc (design.md mục 3, Solver.slack_for): bậc theo level hiển thị `l`; level HARD từ
// very_hard_from_level tính như VeryHard.
function slack(l, lv) {
  const C = CONTENT;
  if (l <= C.slack_easy_until) return C.slack_easy;
  if (l <= C.slack_intro_until) return C.slack_intro;
  if (l <= C.slack_early_until) return C.slack_early;
  const mid = l <= C.slack_mid_until ? '_mid' : '';
  if (!lv.hard) return C[`slack_normal${mid}`];
  if (lv.veryHard || l >= C.very_hard_from_level) return C[`slack_very_hard${mid}`];
  return C[`slack_hard${mid}`];
}

// Giả định.
const AD_SEC = 30, READ = 2.5, READ_HARD = 3.5, OVERHEAD = 5, SAVE_RATE = 0.8, BOOST = 0.15;
const DAYS = 28, SESSIONS_PER_DAY = 2, SESSION_SEC = 600, SEEDS = 500;

// buy[n]: xác suất mua lần cứu thứ n + 1 bằng gold khi đủ tiền (lần sau dùng phần tử cuối).
const PROFILES = {
  noads: { label: 'Không xem quảng cáo', x2: 0, video: 0, calClaim: 0.8, calAd: 0, shop: 0, buy: [0.3, 0.2, 0.1, 0.05], freeBoost: 0, refillVideo: 0, cosmetic: 0.25 },
  some: { label: 'Thỉnh thoảng xem', x2: 0.5, video: 0.6, calClaim: 0.8, calAd: 0.5, shop: 2, buy: [0.2, 0.15, 0.05, 0.05], freeBoost: 0.25, refillVideo: 0.6, cosmetic: 0.25 },
  ads: { label: 'Xem nhiều', x2: 0.9, video: 0.9, calClaim: 0.9, calAd: 0.9, shop: 5, buy: [0.1, 0.1, 0.05, 0.05], freeBoost: 0.5, refillVideo: 0.9, cosmetic: 0.25 },
};

function mulberry(a) {
  return () => {
    a |= 0; a = a + 0x6D2B79F5 | 0;
    let t = Math.imul(a ^ a >>> 15, 1 | a);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}

function winRate(l, hard) {
  if (hard) return 0.5;
  if (l <= 19) return 0.95 - (l - 1) * (0.95 - 0.72) / 18;
  return 0.7;
}

function play(p, seed) {
  const rnd = mulberry(seed);
  const s = {
    gold: E.start_coins, level: 1, lives: LIVES.max, inv: { hint: 0, move: 0, smash: 0 }, cal: 0, owned: 0,
    t: 0, runs: 0, wins: 0, lastInterRun: -99, lastInterT: -999, lastRvT: -999, sessionStart: 0, firstSession: true,
    attempts: 0, losses: 0, rv: 0, inter: 0, waits: 0,
    rShown: 0, rInv: 0, rVideo: 0, rGold: 0, rShort: 0,
    earn: { win: 0, x2: 0, cal: 0, shop: 0 }, spend: { rescue: 0, refill: 0 },
    dry: 0, maxDry: 0, canRescue: 0, gifts: {},
  };
  const out = { days: {}, chap: {}, l20: null };
  const rv = () => { s.rv++; s.t += AD_SEC; s.lastRvT = s.t; };

  // Quà hướng dẫn: 1 booster vào kho khi tới level mở booster đó.
  function gifts() {
    for (const k of ['hint', 'move', 'smash']) {
      if (s.level >= UNLOCK[k] && !s.gifts[k]) { s.gifts[k] = true; s.inv[k]++; }
    }
  }
  function grantCal() {
    const r = DAILY[s.cal % DAILY.length];
    s.gold += r.coins; s.earn.cal += r.coins;
    for (const [k, n] of Object.entries(r.items)) s.inv[k] += n;
    s.cal++;
  }
  // Interstitial result_exit (design.md mục 6): rời thẻ thắng đã bỏ qua x2; L1–10 không có thẻ, tính như bỏ qua x2.
  function maybeInter(x2Taken) {
    if (x2Taken || s.runs < ADS.inter_from_run || s.runs - s.lastInterRun < ADS.inter_every) return;
    if (s.t - s.lastInterT < ADS.inter_cooldown || s.t - s.sessionStart < ADS.session_warmup) return;
    if (s.t - s.lastRvT < ADS.rewarded_grace) return;
    if (s.firstSession && s.level <= ADS.first_session_block_until_level) return;
    s.inter++; s.t += AD_SEC; s.lastInterRun = s.runs; s.lastInterT = s.t;
  }
  // Hết MOVES (design.md mục 3): mỗi lần một popup +rescue_moves, giá theo rescue_prices, video được
  // rescue_video_max lần đầu, +3 Move trong kho dùng miễn phí và vẫn tính một lần.
  function rescue() {
    for (let n = 0; n < E.rescue_prices.length; n++) {
      s.rShown++; s.t += 3;
      const price = E.rescue_prices[n];
      if (s.inv.move > 0) { s.inv.move--; s.rInv++; }
      else if (n < E.rescue_video_max && rnd() < p.video) { rv(); s.rVideo++; }
      else if (s.gold >= price && rnd() < p.buy[Math.min(n, p.buy.length - 1)]) {
        s.gold -= price; s.spend.rescue += price; s.rGold++;
      } else {
        if (s.gold < price) s.rShort++;
        return false;
      }
      if (rnd() < SAVE_RATE) return true;
    }
    return false;
  }
  function attempt() {
    const l = s.level, lv = levelAt(l);
    gifts();
    s.attempts++; s.runs++;
    s.t += lv.blocks * (lv.hard ? READ_HARD : READ) + OVERHEAD;
    let rate = winRate(l, lv.hard);
    if (lv.hard && l >= UNLOCK.hint) {
      if (s.inv.hint > 0) { s.inv.hint--; rate += BOOST; }
      else if (rnd() < p.freeBoost) { rv(); rate += BOOST; }
      if (l >= UNLOCK.smash && s.inv.smash > 0) { s.inv.smash--; rate += BOOST; }
    }
    let rescued = false, won = rnd() < rate;
    if (!won) { won = rescue(); rescued = won; }
    if (!won) {
      s.losses++;
      if (l >= LIVES.from_level) s.lives--;
      return;
    }
    s.wins++;
    // MOVES còn thừa: thắng không cứu thì chạm sai 0..dư lần; thắng sau khi cứu thì còn 0..rescue_moves - 1.
    const left = rescued ? Math.floor(rnd() * E.rescue_moves) : Math.floor(rnd() * (slack(l, lv) + 1));
    const reward = E.win_coins + left * E.win_move_coins;
    s.gold += reward; s.earn.win += reward;
    // Thẻ thắng từ win_card_from_level (thẻ đầu x2 miễn phí); dưới mốc gold vào ví, không có x2 (design.md mục 4).
    const freeX2 = l === E.win_card_from_level;
    const x2 = l >= E.win_card_from_level && (freeX2 || rnd() < p.x2);
    if (x2) {
      if (!freeX2) rv();
      s.gold += reward; s.earn.x2 += reward;
    }
    maybeInter(x2);
    if (s.gold < CHEAPEST) { s.dry++; s.maxDry = Math.max(s.maxDry, s.dry); } else s.dry = 0;
    if (!s.canRescue && s.gold >= E.rescue_prices[0]) s.canRescue = l;
    s.level++;
    if ([5, 10, 15, 20].includes(l)) out.chap[l] = { min: s.t / 60, gold: s.gold };
    if (l === 20) {
      out.l20 = { min: s.t / 60, attempts: s.attempts, losses: s.losses, rGold: s.rGold, rVideo: s.rVideo, rInv: s.rInv, rv: s.rv, gold: s.gold, waits: s.waits, maxDry: s.maxDry };
    }
  }
  function refill() {
    if (rnd() < p.refillVideo) { rv(); s.lives = 1; return true; }
    if (s.gold >= E.refill_coins && rnd() < 0.5) {
      s.gold -= E.refill_coins; s.spend.refill += E.refill_coins; s.lives = E.refill_lives;
      return true;
    }
    s.waits++;
    return false;
  }
  function daily(state) {
    if (s.level >= UNLOCK.daily_gift && !state.claimed && rnd() < p.calClaim) {
      grantCal(); state.claimed = true;
      if (rnd() < p.calAd) { rv(); grantCal(); }
    }
    if (s.level >= UNLOCK.shop) {
      for (; state.shop < Math.min(p.shop, E.shop_video_max); state.shop++) {
        rv(); s.gold += E.shop_video_coins; s.earn.shop += E.shop_video_coins;
      }
    }
    return state;
  }
  // Avatar, frame chỉ mở bằng video (cosmetic_unlock), không tiêu gold.
  function cosmetic() {
    if (s.owned >= VIDEO_COSMETICS || rnd() >= p.cosmetic) return;
    if (rnd() < p.video) { rv(); s.owned++; }
  }

  for (let day = 1; day <= DAYS; day++) {
    let state = { claimed: false, shop: 0 };
    cosmetic();
    for (let ss = 0; ss < SESSIONS_PER_DAY; ss++) {
      s.sessionStart = s.t; s.lives = LIVES.max;
      const end = s.t + SESSION_SEC;
      while (s.t < end) {
        if (s.level >= LIVES.from_level && s.lives <= 0 && !refill()) break;
        attempt();
        state = daily(state);
      }
      s.firstSession = false;
    }
    if ([1, 7, 14, 28].includes(day)) {
      out.days[day] = {
        level: s.level, gold: s.gold, ...s.earn, sRescue: s.spend.rescue, sRefill: s.spend.refill, owned: s.owned,
        rv: s.rv, inter: s.inter, rShown: s.rShown, rInv: s.rInv, rVideo: s.rVideo, rGold: s.rGold, rShort: s.rShort,
        waits: s.waits, calCells: s.cal, wins: s.wins,
      };
    }
  }
  out.canRescue = s.canRescue;
  return out;
}

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
const R1 = n0(E.rescue_prices[0]);

console.log(`Số từ src/config.gd (mặc định, chưa Remote Config), ${LEVELS.length} level trong data/levels/, ${SEEDS} lần chạy mỗi nhóm.\n`);

console.log('### L1–20\n');
console.log(table(['Người chơi', 'Thời gian', 'Số lần chơi', 'Thua', 'Cứu lượt gold / video / kho', 'Rewarded', 'Gold còn', 'Hết mạng phải chờ', `Chuỗi level dài nhất dưới ${n0(CHEAPEST)} gold`],
  ids.map((id) => {
    const r = runs[id], m = (k) => mean(r, (x) => x.l20?.[k]);
    return [L(id), `${n1(m('min'))} phút`, n0(m('attempts')), n0(m('losses')), `${n1(m('rGold'))} / ${n1(m('rVideo'))} / ${n1(m('rInv'))}`, n0(m('rv')), n0(m('gold')), n1(m('waits')), n1(m('maxDry'))];
  })));

console.log('\n### Theo chặng\n');
console.log(table(['Chặng', ...ids.map(L)], [5, 10, 15, 20].map((c) => [`Hết L${c}`, ...ids.map((id) => {
  const m = (k) => mean(runs[id], (x) => x.chap[c]?.[k]);
  return `${n1(m('min'))} phút, ${n0(m('gold'))} gold`;
})])));

console.log(`\n### ${DAYS} ngày, ${SESSIONS_PER_DAY * SESSION_SEC / 60} phút mỗi ngày\n`);
for (const id of ids) {
  console.log(`**${L(id)}**\n`);
  console.log(table(['Hết ngày', 'Level', 'Gold còn', 'Thắng + x2', 'Lịch quà', 'Video shop', 'Tiêu cứu lượt', 'Refill', 'Avatar/frame', 'Rewarded', 'Interstitial', 'Ô lịch'],
    [1, 7, 14, 28].map((d) => {
      const m = (k) => mean(runs[id], (x) => x.days[d][k]);
      return [d, n0(m('level')), n0(m('gold')), n0(m('win') + m('x2')), n0(m('cal')), n0(m('shop')), n0(m('sRescue')), n0(m('sRefill')), n1(m('owned')), n0(m('rv')), n0(m('inter')), n0(m('calCells'))];
    })));
  console.log('');
}

console.log(`### Popup hết MOVES trong ${DAYS} ngày\n`);
console.log(table(['Người chơi', 'Lần hiện', 'Dùng từ kho', 'Video', 'Mua bằng gold', 'Thiếu gold', `Level đầu đủ ${R1} gold`, 'Rewarded mỗi ngày', 'Interstitial mỗi ngày'],
  ids.map((id) => {
    const m = (k) => mean(runs[id], (x) => x.days[DAYS][k]);
    return [L(id), n0(m('rShown')), n0(m('rInv')), n0(m('rVideo')), n0(m('rGold')), n0(m('rShort')), n0(mean(runs[id], (x) => x.canRescue || null)), n1(m('rv') / DAYS), n1(m('inter') / DAYS)];
  })));

// Gold trung bình mỗi lần thắng (chưa x2) của người không xem quảng cáo, gồm phần MOVES thừa.
const perWin = mean(runs.noads, (x) => x.days[DAYS].win / x.days[DAYS].wins);
const items = [
  ['Gợi ý', E.booster_price.hint], ['Refill', E.refill_coins], ['+3 Move (booster)', E.booster_price.move],
  ['Cứu lượt lần 1', E.rescue_prices[0]], ['Phá khối', E.booster_price.smash],
];
console.log(`\n### Giá từng món (thắng trung bình ${n0(perWin)} gold, chưa x2)\n`);
console.log(table(['Món', 'Giá', 'Số level thắng để đủ tiền', 'Số video trong shop'],
  items.map(([name, price]) => [name, n0(price), n1(price / perWin), n1(price / E.shop_video_coins)])));
