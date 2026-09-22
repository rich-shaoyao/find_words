/*
 * 暗棋规则引擎单元测试 —— 用 macOS 自带 JavaScriptCore 运行：
 *   cd docs/dark-chess && /System/Library/Frameworks/JavaScriptCore.framework/Versions/A/Helpers/jsc engine.test.js
 */
if (typeof console === 'undefined') { var console = { log: print }; }
load('engine.js');
var E = DarkChess;
var RED = E.RED, BLACK = E.BLACK;

var pass = 0, fail = 0, failures = [];
function ok(cond, msg) {
  if (cond) { pass++; }
  else { fail++; failures.push(msg); console.log('  ✗ ' + msg); }
}
function eq(a, b, msg) { ok(a === b, msg + ' (期望 ' + JSON.stringify(b) + '，实际 ' + JSON.stringify(a) + ')'); }
function section(t) { console.log('\n▶ ' + t); }

function emptyState() {
  var board = [];
  for (var r = 0; r < 10; r++) { board.push([]); for (var c = 0; c < 9; c++) board[r].push(null); }
  return { board: board, turn: 'r', first: null, quiet: 0, captured: { r: [], b: [] }, last: null, over: false, winner: null, reason: null };
}
function put(st, r, c, s, t, up) { st.board[r][c] = { s: s, t: t, up: up === false ? 0 : 1 }; }
function has(list, r, c) {
  for (var i = 0; i < list.length; i++) if (list[i].r === r && list[i].c === c) return true;
  return false;
}
// 固定种子的可复现随机（LCG）
function seeded(seed) {
  var s = seed;
  return function () { s = (s * 1103515245 + 12345) % 2147483648; return s / 2147483648; };
}

/* ============ 1. 布阵 ============ */
section('布阵：标准格局 + 将帅明牌 + 30 枚混装暗棋');
(function () {
  var N = 500;
  var badTotal = 0, badDark = 0, badSpots = 0, badKind = 0, mixed = 0;
  var ALL = E.HOME.r.concat(E.HOME.b);
  for (var i = 0; i < N; i++) {
    var st = E.newGame(seeded(i * 7919 + 13));
    var total = 0, dark = 0, occ = {}, kinds = { r: {}, b: {} }, redInBlackHalf = 0;
    for (var r = 0; r < 10; r++) for (var c = 0; c < 9; c++) {
      var p = st.board[r][c];
      if (!p) continue;
      total++; occ[r + ',' + c] = 1;
      if (!p.up) {
        dark++;
        kinds[p.s][p.t] = (kinds[p.s][p.t] || 0) + 1;
        if (p.s === RED && r <= 4) redInBlackHalf++;   // 红子落在黑方半场 = 混装证据
      }
    }
    if (total !== 32) badTotal++;
    if (dark !== 30) badDark++;
    if (redInBlackHalf > 0) mixed++;
    // 32 个标准点位必须枚枚落子、且不越位
    var spotOK = Object.keys(occ).length === 32;
    for (var k = 0; k < ALL.length && spotOK; k++)
      if (!occ[ALL[k][0] + ',' + ALL[k][1]]) spotOK = false;
    if (!spotOK) badSpots++;
    // 暗棋构成：每方 2 仕 + 2 相 + 2 车 + 2 马 + 2 炮 + 5 兵（将/帅不在暗棋里）
    [RED, BLACK].forEach(function (s) {
      var kk = kinds[s];
      if (!(kk.K === undefined && kk.A === 2 && kk.E === 2 && kk.R === 2 && kk.H === 2 && kk.C === 2 && kk.P === 5)) badKind++;
    });
  }
  eq(badTotal, 0, '每局恰好 32 枚棋子');
  eq(badSpots, 0, '棋子恰好铺满中国象棋标准格局的 32 个点位（无空点、无越位）');
  eq(badDark, 0, '其中 30 枚扣着');
  eq(badKind, 0, '暗棋构成正确：红黑各 2 仕 + 2 相 + 2 车 + 2 马 + 2 炮 + 5 兵');
  ok(mixed > N * 0.99, '暗棋是红黑混装：红方半场几乎总会出现黑子（' + mixed + '/' + N + ' 局）');

  // 将帅固定、明牌
  var badK = 0;
  for (i = 0; i < N; i++) {
    var s2 = E.newGame(seeded(i * 104729 + 7));
    var kr = s2.board[9][4], kb = s2.board[0][4];
    if (!(kr && kr.s === RED && kr.t === 'K' && kr.up === 1)) badK++;
    if (!(kb && kb.s === BLACK && kb.t === 'K' && kb.up === 1)) badK++;
    if (s2.board[9][3].up || s2.board[9][5].up) badK++;      // 底线其它点必须是暗棋
    if (s2.board[0][3].up || s2.board[0][5].up) badK++;
  }
  eq(badK, 0, '红帅固定 (9,4) / 黑将固定 (0,4)，正面朝上，全场仅此两枚明棋');

  // 常量自检
  eq(E.HOME.r.length, 16, '红方标准点位 16 个');
  eq(E.HOME.b.length, 16, '黑方标准点位 16 个');
  eq(E.openSpots().length, 30, '去掉将帅两点后剩 30 个暗棋点位');
  eq(E.darkPool().length, 30, '暗棋共 30 枚（红黑各 15）');
  (function () {
    var overlap = 0;
    E.HOME.r.forEach(function (a) {
      E.HOME.b.forEach(function (b) { if (a[0] === b[0] && a[1] === b[1]) overlap++; });
    });
    eq(overlap, 0, '红黑双方的标准点位互不重叠');
    ok(Math.min.apply(null, E.HOME.r.map(function (p) { return p[0]; })) >= 5, '红方点位全在红方半场（行 >= 5）');
    ok(Math.max.apply(null, E.HOME.b.map(function (p) { return p[0]; })) <= 4, '黑方点位全在黑方半场（行 <= 4）');
  })();
})();

/* ============ 1b. 位置固定、内容与归属全部洗牌 ============ */
section('位置固定、内容与归属全部洗牌');
(function () {
  var perms = {}, redInRedHalf = { min: 99, max: -1 }, n = 300;
  for (var i = 0; i < n; i++) {
    var st = E.newGame(seeded(i * 104729 + 7));
    var sig = [];
    for (var k = 0; k < E.HOME.r.length; k++)
      sig.push(st.board[E.HOME.r[k][0]][E.HOME.r[k][1]].s + st.board[E.HOME.r[k][0]][E.HOME.r[k][1]].t);
    perms[sig.join('')] = 1;
    // 红方半场 15 个暗棋点里，属于红方的棋子数分布
    var cnt = 0;
    for (var r = 5; r < 10; r++) for (var c = 0; c < 9; c++) {
      var p = st.board[r][c];
      if (p && p.s === RED && p.t !== 'K') cnt++;
    }
    if (cnt < redInRedHalf.min) redInRedHalf.min = cnt;
    if (cnt > redInRedHalf.max) redInRedHalf.max = cnt;
  }
  ok(Object.keys(perms).length > n - 3,
     '红方 16 个点位上的棋子排列每局都不同（' + n + ' 局出现 ' + Object.keys(perms).length + ' 种）');
  ok(redInRedHalf.min < 15 && redInRedHalf.max > 5,
     '红方半场里的红子数量每局都在变（实测区间 ' + redInRedHalf.min + '–' + redInRedHalf.max + ' 枚）');
  var bad = 0;
  for (i = 0; i < n; i++) {
    var g = E.newGame(seeded(i * 31 + 5));
    if (g.board[9][4].r !== undefined && g.board[9][4].t === 'K' && g.board[9][4].s !== RED) bad++;
    if (g.board[0][4].t === 'K' && g.board[0][4].s !== BLACK) bad++;
  }
  eq(bad, 0, '将帅永远固定在自己那一侧的底线正中');
})();

/* ============ 2. 翻子权限 ============ */
section('规则 1：只能翻己方半场的暗棋');
(function () {
  var st = E.newGame(seeded(12345));
  var fr = E.flippable(st, RED), fb = E.flippable(st, BLACK);
  eq(fr.length, 15, '红方开局可翻 15 枚（红方半场恰好 15 个暗棋点位）');
  eq(fb.length, 15, '黑方开局可翻 15 枚');
  ok(fr.every(function (p) { return p.r >= 5; }), '红方只能翻红方半场（行 5..9）的暗棋');
  ok(fb.every(function (p) { return p.r <= 4; }), '黑方只能翻黑方半场（行 0..4）的暗棋');
  eq(fr.length + fb.length, 30, '两方可翻点合起来 = 全部 30 枚暗棋');

  var st2 = emptyState();
  put(st2, 9, 4, RED, 'K', true);
  put(st2, 0, 4, BLACK, 'K', true);
  put(st2, 6, 2, BLACK, 'R', false);      // 红方半场里的暗子（其实是黑方的）
  put(st2, 2, 2, RED, 'R', false);        // 黑方半场里的暗子（其实是红方的）
  var f2 = E.flippable(st2, RED);
  eq(f2.length, 1, '红方在这个局面只有 1 枚可翻');
  ok(has(f2, 6, 2), '红方能翻自己半场里的暗子 —— 哪怕它翻开后是黑方的');
  ok(!has(f2, 2, 2), '红方严禁翻对方半场里的暗子 —— 哪怕它其实是红方的');
})();

/* ============ 3. 暗棋按「所在点位的标准棋子」走 ============ */
section('规则 3：暗棋按它所在点位的标准棋子走，与真实身份无关');
(function () {
  // (9,0) 是底线车位 —— 哪怕它真实身份是兵，也按「车」走
  var st = emptyState();
  put(st, 9, 0, RED, 'P', false);
  var m = E.legalMoves(st, 9, 0);
  ok(has(m, 0, 0) && has(m, 9, 8), '车位上的暗子按「车」走 —— 哪怕它真实身份只是个兵');

  // 走法只看「位置」：同一个车位的暗子换遍各种真实身份，落点必须完全一致
  (function () {
    var base = null;
    ['K', 'A', 'H', 'E', 'R', 'C', 'P'].forEach(function (t) {
      var s2 = emptyState();
      put(s2, 9, 0, RED, t, false);
      var mv = E.legalMoves(s2, 9, 0).map(function (x) { return x.r + ',' + x.c; }).sort().join('|');
      if (base === null) base = mv;
      else eq(mv, base, '车位 (9,0) 的暗子真实身份换成 ' + t + '，落点仍与「车」完全一致');
    });
    eq(base.split('|').length, 17,
      '空旷棋盘上 (9,0) 的暗车有 17 个落点（整条底线 8 + 整条竖线 9）—— 是「走一次完整走法」，不是「挪一格」');
  })();

  // (9,1) 是底线马位
  st = emptyState();
  put(st, 9, 1, RED, 'R', false);          // 真实身份是车
  m = E.legalMoves(st, 9, 1);
  ok(has(m, 7, 0) && has(m, 7, 2), '马位上的暗子只能走日 —— 哪怕它真实身份是车');
  ok(!has(m, 9, 8), '它不能像车那样横冲到底');

  // (9,2) 是底线象位
  st = emptyState();
  put(st, 9, 2, RED, 'R', false);
  m = E.legalMoves(st, 9, 2);
  ok(has(m, 7, 0) && has(m, 7, 4), '象位上的暗子走田');
  put(st, 8, 3, RED, 'P', true);           // 塞象眼
  m = E.legalMoves(st, 9, 2);
  ok(!has(m, 7, 4), '象眼上的子照样塞象眼');

  // (9,3) 是底线士位
  st = emptyState();
  put(st, 9, 3, RED, 'C', false);
  m = E.legalMoves(st, 9, 3);
  eq(m.length, 2, '士位上的暗子斜走一步（底边只剩 2 个落点）');
  ok(has(m, 8, 2) && has(m, 8, 4), '两个斜向落点');

  // (7,1) 是炮位
  st = emptyState();
  put(st, 7, 1, RED, 'P', false);          // 真实身份是兵，但落在炮位
  put(st, 5, 1, RED, 'R', true);           // 炮架
  put(st, 3, 1, BLACK, 'R', true);         // 目标
  m = E.legalMoves(st, 7, 1);
  ok(has(m, 3, 1), '炮位上的暗子按「炮」走 —— 能隔子打中目标');
  ok(!has(m, 5, 1), '炮不能吃掉作为炮架的那枚子');

  // (6,0) / (3,2) 是兵/卒位
  st = emptyState();
  put(st, 6, 0, RED, 'R', false);          // 真实身份是车，但落在兵位
  m = E.legalMoves(st, 6, 0);
  eq(m.length, 1, '兵位上的暗子只能向前一步 —— 哪怕它真实身份是车');
  ok(has(m, 5, 0), '红方半场的兵位朝上走');

  st = emptyState();
  put(st, 3, 2, BLACK, 'R', false);        // 黑方卒位上的暗子（真实是车）
  m = E.legalMoves(st, 3, 2);
  eq(m.length, 1, '黑方卒位上的暗子同样只能向前一步');
  ok(has(m, 4, 2), '黑方半场的卒位朝下走');

  // 翻开之后，改按它真实的身份走（规则 6）
  st = emptyState();
  put(st, 9, 0, RED, 'P', true);           // 明兵站在底线车位上
  m = E.legalMoves(st, 9, 0);
  eq(m.length, 1, '翻开后按真实身份走 —— 明兵在底线只能向前一步，不能横走');
  ok(has(m, 8, 0), '向前 = 行号减小');

  st = emptyState();
  put(st, 9, 1, RED, 'R', true);           // 明车站在马位上
  m = E.legalMoves(st, 9, 1);
  ok(has(m, 9, 8), '明棋按自己的真实身份走 —— 车可以横冲到底');

  // HOME_TYPE 自检
  eq(E.homeType(9, 0), 'R', '(9,0) 是车位');
  eq(E.homeType(9, 1), 'H', '(9,1) 是马位');
  eq(E.homeType(9, 2), 'E', '(9,2) 是象位');
  eq(E.homeType(9, 3), 'A', '(9,3) 是士位');
  eq(E.homeType(9, 4), 'K', '(9,4) 是帅位');
  eq(E.homeType(7, 1), 'C', '(7,1) 是炮位');
  eq(E.homeType(6, 0), 'P', '(6,0) 是兵位');
  eq(E.homeType(0, 8), 'R', '(0,8) 是黑方车位');
  eq(E.homeType(2, 7), 'C', '(2,7) 是黑方炮位');
  eq(E.homeType(3, 8), 'P', '(3,8) 是黑方卒位');
  eq(E.homeType(5, 4), null, '(5,4) 不是标准点位，没有「标准棋子」');
  eq(E.homeType(4, 4), null, '(4,4) 不是标准点位，没有「标准棋子」');

  // 30 个暗棋点位的类型构成 = 暗棋池的构成（这是个漂亮的巧合，值得钉住）
  (function () {
    var got = {};
    E.openSpots().forEach(function (p) { var t = E.homeType(p[0], p[1]); got[t] = (got[t] || 0) + 1; });
    var want = { R: 4, H: 4, E: 4, A: 4, C: 4, P: 10 };
    eq(got.K, undefined, '30 个暗棋点位里不含将/帅位（那两点固定是明牌）');
    ['R', 'H', 'E', 'A', 'C', 'P'].forEach(function (t) {
      eq(got[t], want[t], '30 个暗棋点位里有 ' + want[t] + ' 个' + E.NAME[t][RED] + '位');
    });
  })();
})();

/* ============ 4. 走完必须翻开 ============ */
section('规则 4：暗棋走完必须立即翻开');
(function () {
  var st = emptyState();
  st.turn = RED;
  put(st, 9, 4, RED, 'K', true);
  put(st, 0, 4, BLACK, 'K', true);
  put(st, 5, 3, RED, 'R', false);
  var next = E.apply(st, { kind: 'move', from: [5, 3], to: [5, 0] });
  eq(next.board[5][0].up, 1, '暗棋走完后自动翻开');
  eq(next.board[5][0].s, RED, '翻开后归属不变');
  eq(next.last.revealed, true, '该步被标记为「走完翻开」');
  eq(next.quiet, 0, '有棋子翻面 = 有进展，和棋计时归零');
  eq(st.board[5][3].up, 0, 'apply 不修改原状态');

  var st2 = emptyState();
  st2.turn = RED;
  put(st2, 9, 4, RED, 'K', true);
  put(st2, 0, 4, BLACK, 'K', true);
  put(st2, 5, 3, RED, 'R', true);
  var nx2 = E.apply(st2, { kind: 'move', from: [5, 3], to: [5, 0] });
  eq(nx2.last.revealed, false, '明棋走完没有发生翻面');
  eq(nx2.quiet, 1, '纯移动不算进展');
})();

/* ============ 5. 吃子规则 ============ */
section('规则 5：吃子范围（敌我一律用公开信息判定）');
(function () {
  // —— 暗棋吃明棋：只能吃「移动方对手」的明棋（明棋的归属本来就是公开的）
  var st = emptyState();
  put(st, 5, 4, RED, 'R', false);          // 红方「暗车」
  put(st, 1, 4, BLACK, 'P', true);         // 移动方（红）之对手的明棋
  var m = E.legalMoves(st, 5, 4);
  ok(has(m, 1, 4), '暗棋可以吃到对手的明棋');

  st = emptyState();
  put(st, 5, 4, RED, 'R', false);
  put(st, 5, 6, RED, 'P', true);           // 己方明棋
  ok(!has(E.legalMoves(st, 5, 4), 5, 6), '暗棋不能吃己方明棋');

  // —— 暗棋吃暗棋：只能吃「位于对方半场」的暗棋
  //    判定依据是点位的标准归属（那一格本该站着对方的子），绝不会去偷看暗棋的真实归属
  st = emptyState();
  put(st, 5, 4, RED, 'R', false);          // 红方半场 (5,4)
  put(st, 3, 4, BLACK, 'P', false);        // 黑方半场 (3,4) —— 点位归属是对方
  var m2 = E.legalMoves(st, 5, 4);
  ok(has(m2, 3, 4), '暗棋可以吃「对方半场」的暗棋');
  ok(!has(m2, 2, 4), '吃掉它之后不能再越过');

  st = emptyState();
  put(st, 5, 4, RED, 'R', false);
  put(st, 5, 6, BLACK, 'P', false);        // 真实归属是黑，但站在红方半场
  ok(!has(E.legalMoves(st, 5, 4), 5, 6),
     '暗棋不能吃己方半场的暗棋 —— 哪怕它真实归属是对方（敌人藏在自家半场，只能先翻出来）');

  // —— 明棋：照旧（归属公开）
  st = emptyState();
  put(st, 5, 4, RED, 'R', true);           // 明车（红方半场）
  put(st, 5, 6, RED, 'P', false);          // 自家阵地里的暗棋（真实归属也是自己）
  put(st, 5, 0, RED, 'P', true);           // 己方明棋
  var m4 = E.legalMoves(st, 5, 4);
  ok(!has(m4, 5, 6), '明棋不能吃自家阵地（己方半场）里的暗棋');
  ok(!has(m4, 5, 0), '明棋不能吃己方明棋');

  st = emptyState();
  put(st, 5, 4, RED, 'R', true);
  put(st, 5, 6, BLACK, 'P', false);        // 真实归属是对方，但站在红方半场
  ok(!has(E.legalMoves(st, 5, 4), 5, 6),
     '明棋也不能吃自家阵地里的暗棋 —— 哪怕它真实归属是对方（只能先翻出来）');

  // 明棋推进到对方半场后，那边**所有**暗棋都能吃 —— 真实归属是自己的就叫「自残」
  st = emptyState();
  put(st, 5, 4, RED, 'R', true);           // 明车
  put(st, 3, 4, RED, 'P', false);          // 自家子埋在黑方半场
  ok(has(E.legalMoves(st, 5, 4), 3, 4), '明棋可以吃对方半场里的暗棋（真实归属是自己 → 自残）');
  st = emptyState();
  put(st, 5, 4, RED, 'R', true);
  put(st, 3, 4, BLACK, 'P', false);        // 敌子也在黑方半场
  ok(has(E.legalMoves(st, 5, 4), 3, 4), '明棋可以吃对方半场里的暗棋（真实归属是对方）');

  // canLand 的各条分支（第 3 个参数 = 谁在走）
  var darkR = { s: RED, t: 'R', up: 0 }, litR = { s: RED, t: 'R', up: 1 };
  var darkB = { s: BLACK, t: 'P', up: 0 }, litB = { s: BLACK, t: 'P', up: 1 };
  eq(E.canLand(darkR, null, RED), true, '暗棋可入空格');
  eq(E.canLand(darkR, litB, RED), true, '暗棋可吃对手的明棋');
  eq(E.canLand(darkR, litR, RED), false, '暗棋不可吃己方明棋');
  eq(E.canLand(darkR, darkB, RED, 3, 4), true, '暗棋可吃对方半场的暗棋');
  eq(E.canLand(darkR, darkB, RED, 5, 6), false, '暗棋不可吃己方半场的暗棋（哪怕真实归属是对方）');
  eq(E.canLand(litR, darkB, RED), true, '明棋可吃对方暗棋');
  eq(E.canLand(litR, darkR, RED, 3, 4), true, '明棋可吃对方半场的暗棋（真实归属是自己 = 自残）');
  eq(E.canLand(litR, darkR, RED, 5, 6), false, '明棋不可吃自家阵地里的暗棋');
  eq(E.canLand(litR, litB, RED), true, '明棋可吃对方明棋');
  eq(E.canLand(litR, litR, RED), false, '明棋不可吃己方明棋');
})();

/* ============ 6. 车 ============ */
section('车');
(function () {
  var st = emptyState();
  put(st, 9, 0, RED, 'R', true);
  put(st, 7, 0, BLACK, 'P', false);        // 拦路的暗子
  var m = E.legalMoves(st, 9, 0);
  ok(has(m, 8, 0), '车可前进一格');
  ok(!has(m, 7, 0), '明车不能吃自家阵地（己方半场）里的暗棋 —— 但它照样挡路');
  ok(!has(m, 6, 0), '被这枚暗子挡住，不能越过');
  ok(has(m, 9, 8), '车可平移到最右');

  st = emptyState();
  put(st, 9, 0, RED, 'R', true);
  put(st, 7, 0, BLACK, 'P', true);
  m = E.legalMoves(st, 9, 0);
  ok(has(m, 7, 0), '车可吃敌方明子');
  ok(!has(m, 6, 0), '吃子后不能再深入');

  st = emptyState();
  put(st, 9, 0, RED, 'R', true);
  put(st, 8, 0, RED, 'P', true);           // 己方明子
  m = E.legalMoves(st, 9, 0);
  ok(!has(m, 8, 0) && !has(m, 7, 0), '车不能吃己方明子，也无法越过');
})();

/* ============ 7. 马 ============ */
section('马');
(function () {
  var st = emptyState();
  put(st, 9, 4, RED, 'H', true);           // 底边中路：向上 2 + 左右 2，共 4 个落点
  var m = E.legalMoves(st, 9, 4);
  eq(m.length, 4, '空盘马有 4 个落点');
  ok(has(m, 7, 3) && has(m, 7, 5) && has(m, 8, 2) && has(m, 8, 6), '马走日字形');

  put(st, 8, 4, RED, 'P', false);          // 蹩住上方的马腿（暗子也算蹩）
  m = E.legalMoves(st, 9, 4);
  eq(m.length, 2, '马腿被暗子蹩住则受该方向限制');
  ok(!has(m, 7, 3) && !has(m, 7, 5), '被蹩方向的两个落点都不可走');
  ok(has(m, 8, 2) && has(m, 8, 6), '其余方向不受影响');

  st = emptyState();
  put(st, 9, 4, RED, 'H', true);
  put(st, 7, 3, RED, 'P', true);           // 落点为己方明子
  put(st, 7, 5, BLACK, 'P', true);         // 落点为敌方明子
  put(st, 8, 2, BLACK, 'P', false);        // 落点为暗子（在红方半场）
  m = E.legalMoves(st, 9, 4);
  ok(!has(m, 7, 3), '马不能落到己方明子格');
  ok(has(m, 7, 5), '马可吃敌方明子');
  ok(!has(m, 8, 2), '明马不能吃自家阵地里的暗棋');

  // 马过河之后，黑方半场里的暗棋都能吃（真实归属是自己的 = 自残）
  st = emptyState();
  put(st, 2, 4, RED, 'H', true);           // 明马已过河
  put(st, 3, 2, BLACK, 'P', false);        // 黑方半场
  put(st, 1, 2, RED, 'P', false);          // 黑方半场，真实归属是自己
  m = E.legalMoves(st, 2, 4);
  ok(has(m, 3, 2), '明马可以吃对方半场里的暗棋');
  ok(has(m, 1, 2), '明马可以吃对方半场里真实归属是自己的暗棋（自残）');
})();

/* ============ 8. 相/象 ============ */
section('规则 8：士象可过河（相/象）');
(function () {
  var st = emptyState();
  put(st, 9, 4, RED, 'E', true);
  var m = E.legalMoves(st, 9, 4);
  ok(has(m, 7, 2) && has(m, 7, 6), '相走田字');
  put(st, 8, 3, BLACK, 'P', false);
  m = E.legalMoves(st, 9, 4);
  ok(!has(m, 7, 2), '象眼被暗子塞住则不能走');
  ok(has(m, 7, 6), '另一侧田字不受影响');

  st = emptyState();
  put(st, 5, 4, RED, 'E', true);
  ok(has(E.legalMoves(st, 5, 4), 3, 2), '相可过河到黑方半场');
  st = emptyState();
  put(st, 1, 4, BLACK, 'E', true);
  ok(has(E.legalMoves(st, 1, 4), 3, 2), '黑象可过河到红方半场');
})();

/* ============ 9. 仕/士 ============ */
section('规则 8：士象可过河（仕/士）');
(function () {
  var st = emptyState();
  put(st, 5, 3, RED, 'A', true);
  var m = E.legalMoves(st, 5, 3);
  eq(m.length, 4, '仕斜走一步有 4 个落点');
  ok(has(m, 4, 2) && has(m, 4, 4), '仕可过河');
  st = emptyState();
  put(st, 0, 0, BLACK, 'A', true);
  var m2 = E.legalMoves(st, 0, 0);
  eq(m2.length, 1, '角落的士只有 1 个落点');
  ok(has(m2, 1, 1), '士走出角落');
})();

/* ============ 10. 帅/将 ============ */
section('规则 7：帅/将不出九宫');
(function () {
  var st = emptyState();
  put(st, 9, 4, RED, 'K', true);
  var m = E.legalMoves(st, 9, 4);
  eq(m.length, 3, '帅在底线中路只有 3 个落点');
  ok(has(m, 8, 4) && has(m, 9, 3) && has(m, 9, 5), '帅可在九宫内直线一步');
  ok(!has(m, 9, 2) && !has(m, 9, 6), '帅不能出九宫');

  st = emptyState();
  put(st, 7, 3, RED, 'K', true);
  m = E.legalMoves(st, 7, 3);
  ok(has(m, 8, 3) && has(m, 7, 4), '帅可沿九宫边移动');
  ok(!has(m, 6, 3), '帅不能前进到九宫之外');
  ok(!has(m, 7, 2), '帅不能横出九宫');

  st = emptyState();
  put(st, 0, 4, BLACK, 'K', true);
  eq(E.legalMoves(st, 0, 4).length, 3, '将在黑方九宫内同样只有直线一步');
})();

/* ============ 11. 兵/卒 ============ */
section('规则 9：兵/卒永不后退');
(function () {
  var st = emptyState();
  put(st, 6, 4, RED, 'P', true);           // 未过河
  var m = E.legalMoves(st, 6, 4);
  eq(m.length, 1, '未过河的兵只能向前一步');
  ok(has(m, 5, 4), '红兵向前 = 行号减小');

  st = emptyState();
  put(st, 5, 4, RED, 'P', true);
  var m2 = E.legalMoves(st, 5, 4);
  eq(m2.length, 1, '红兵在行 5 时仍未过河');
  ok(!has(m2, 5, 3) && !has(m2, 5, 5), '未过河的兵不能横走');

  st = emptyState();
  put(st, 4, 4, RED, 'P', true);           // 已过河
  var m3 = E.legalMoves(st, 4, 4);
  eq(m3.length, 3, '过河后的兵可前进或左右平移');
  ok(has(m3, 3, 4) && has(m3, 4, 3) && has(m3, 4, 5), '过河兵的三个方向');
  ok(!has(m3, 5, 4), '兵永远不能后退');

  st = emptyState();
  put(st, 5, 4, BLACK, 'P', true);
  var m4 = E.legalMoves(st, 5, 4);
  ok(has(m4, 6, 4) && has(m4, 5, 3) && has(m4, 5, 5), '黑卒过河后同理');
  st = emptyState();
  put(st, 4, 4, BLACK, 'P', true);
  var m5 = E.legalMoves(st, 4, 4);
  eq(m5.length, 1, '未过河的黑卒只能向前');
  ok(has(m5, 5, 4) && !has(m5, 3, 4), '黑卒向前 = 行号增大，且不能后退');
})();

/* ============ 12. 炮 ============ */
section('炮');
(function () {
  var st = emptyState();
  put(st, 9, 0, RED, 'C', true);
  var m = E.legalMoves(st, 9, 0);
  ok(has(m, 0, 0), '无阻挡时炮平移如车');
  ok(has(m, 9, 8), '炮可横向平移到底');

  st = emptyState();
  put(st, 9, 0, RED, 'C', true);
  put(st, 7, 0, RED, 'P', true);           // 炮架：明子
  put(st, 5, 0, BLACK, 'R', true);         // 目标：敌方明子
  m = E.legalMoves(st, 9, 0);
  ok(has(m, 5, 0), '炮可隔一个明子炮架吃敌方明子');
  ok(!has(m, 7, 0), '炮不能吃掉作为炮架的棋子');
  ok(has(m, 8, 0), '炮架之前的空格仍可平移');
  ok(!has(m, 6, 0), '炮不能落在炮架与目标之间');

  st = emptyState();
  put(st, 9, 0, RED, 'C', true);
  put(st, 7, 0, RED, 'P', true);
  put(st, 5, 0, BLACK, 'R', false);        // 目标是自家阵地里的暗棋
  ok(!has(E.legalMoves(st, 9, 0), 5, 0), '明炮不能吃自家阵地（己方半场）里的暗棋');

  st = emptyState();
  put(st, 6, 0, RED, 'C', true);           // 明炮推进到兵线
  put(st, 4, 0, RED, 'P', true);           // 炮架在黑方半场
  put(st, 2, 0, BLACK, 'R', false);        // 目标 (2,0) 在黑方半场
  ok(has(E.legalMoves(st, 6, 0), 2, 0), '明炮可以隔子吃对方半场里的暗棋');

  st = emptyState();
  put(st, 9, 0, RED, 'C', true);
  put(st, 7, 0, RED, 'P', true);
  put(st, 6, 0, RED, 'P', true);
  ok(!has(E.legalMoves(st, 9, 0), 6, 0), '炮不能吃己方明子');

  // 暗子可以当炮架（暗子是棋盘上的实体）
  st = emptyState();
  put(st, 9, 0, RED, 'C', true);
  put(st, 7, 0, RED, 'P', false);          // 挡在身前的暗子 —— 可以当架
  put(st, 5, 0, BLACK, 'R', true);         // 目标
  m = E.legalMoves(st, 9, 0);
  ok(has(m, 5, 0), '暗子可以当炮架，炮能隔着它打中目标');
  ok(has(m, 8, 0), '炮架之前的空格仍可平移');
  ok(!has(m, 7, 0), '炮不能吃掉作为炮架的棋子');

  // 炮可以打将/帅
  st = emptyState();
  put(st, 9, 0, RED, 'C', true);
  put(st, 7, 0, RED, 'P', true);           // 明子炮架
  put(st, 5, 0, BLACK, 'K', true);         // 对方的将
  ok(has(E.legalMoves(st, 9, 0), 5, 0), '炮可以打对方的将/帅');

  st = emptyState();
  put(st, 9, 0, RED, 'C', true);
  put(st, 7, 0, RED, 'P', false);          // 暗子炮架
  put(st, 5, 0, BLACK, 'K', true);
  ok(has(E.legalMoves(st, 9, 0), 5, 0), '隔着暗子炮架也能打死对方的将');

  // 炮位上的暗子按「炮」走（见规则 3 段）；这里测它翻成明子后仍按炮走
  st = emptyState();
  put(st, 7, 1, RED, 'C', true);
  put(st, 5, 1, RED, 'P', true);
  put(st, 3, 1, BLACK, 'R', true);
  m = E.legalMoves(st, 7, 1);
  ok(has(m, 3, 1), '明炮可以隔炮架吃对方明棋');
  ok(!has(m, 5, 1), '明炮不能吃掉作为炮架的那枚明棋');
})();

/* ============ 12b. 暗棋的半场限制 + 炮的开局风险 ============ */
section('暗棋的半场限制，与「炮架放开」带来的开局风险');
(function () {
  // 1) 暗棋只能在自己半场移动（这一条保留，否则贴脸斩首无法阻止）
  var st = emptyState();
  st.turn = RED;
  put(st, 9, 4, RED, 'K', true);
  put(st, 0, 4, BLACK, 'K', true);
  put(st, 0, 3, RED, 'R', false);          // 红车被洗到黑将左边（贴脸）
  ok(!E.canPick(st, 0, 3, RED), '红方不能操作落在黑方半场的己方暗棋');
  eq(E.allActions(st, RED).filter(function (a) {
    return a.kind === 'move' && a.from[0] === 0 && a.from[1] === 3;
  }).length, 0, '贴脸的红暗车一步也走不出去 → 开局贴脸斩首被堵死（此时红方只有帅能动）');
  put(st, 0, 3, RED, 'R', true);           // 翻开之后
  ok(E.canPick(st, 0, 3, RED), '翻成明棋后就可以全盘行动了');

  // 2) 炮的开局杀招确实存在 —— 这是「炮架明暗皆可 + 炮可打将」的直接后果，不是 bug
  var st2 = emptyState();
  st2.turn = RED;
  put(st2, 9, 4, RED, 'K', true);
  put(st2, 0, 4, BLACK, 'K', true);
  put(st2, 6, 4, RED, 'C', true);          // 红炮落在红方兵位 (6,4)
  put(st2, 3, 4, BLACK, 'P', false);       // (3,4) 是黑方卒位，开局必定有子（哪怕是暗子）
  ok(has(E.legalMoves(st2, 6, 4), 0, 4),
     '红炮在 (6,4) 且 (3,4) 是暗子 → 第一手就能打死 (0,4) 的黑将（这就是已知的开局风险）');

  // 3) 守门线：把这个已知代价量化，防止以后改规则时悄悄恶化
  var N = 2000, firstKill = 0;
  for (var i = 0; i < N; i++) {
    var g = E.newGame(seeded(i * 7919 + 3));
    var acts = E.allActions(g, g.turn), kill = false;
    for (var k = 0; k < acts.length; k++) {
      if (acts[k].kind !== 'move') continue;
      var t = g.board[acts[k].to[0]][acts[k].to[1]];
      if (t && t.t === 'K') { kill = true; break; }
    }
    if (kill) firstKill++;
  }
  ok(firstKill / N < 0.10,
     '先手第一手斩首率在已知区间内（实测 ' + (firstKill * 100 / N).toFixed(1) + '%，守门线 10%）');
})();

/* ============ 13. 暗棋只能「移动后」翻开 ============ */
section('暗棋必须移动后才可翻开（无原地翻开）');
(function () {
  var st = emptyState();
  st.turn = RED;
  put(st, 9, 4, RED, 'K', true);
  put(st, 0, 4, BLACK, 'K', true);
  put(st, 6, 2, BLACK, 'R', false);        // 红方半场里的暗子（真实归属是黑方）
  var acts = E.allActions(st, RED);

  // 1) 不再存在任何「原地翻开」动作
  eq(acts.filter(function (a) { return a.kind === 'flip'; }).length, 0, '「原地翻开」动作已彻底取消');
  ok(acts.every(function (a) { return a.kind === 'move'; }), '红方的合法行动全部是「走一步」');

  // 2) 那枚暗子只能靠走动来揭开：(6,2) 是兵位 → 只能向前一步到 (5,2)
  var step = acts.filter(function (a) { return a.from[0] === 6 && a.from[1] === 2; });
  eq(step.length, 1, '兵位上的暗子只有「向前一步」这一种走法');
  eq(step[0].to[0] + ',' + step[0].to[1], '5,2', '它的落点是 (5,2)');

  // 3) 走完自动翻开，归属不变
  var next = E.apply(st, step[0]);
  eq(next.board[5][2].up, 1, '走完立刻翻开（规则 4）');
  eq(next.board[5][2].s, BLACK, '翻开的棋子归属不变 —— 这就是「替对手推了一步」');
  eq(next.turn, BLACK, '走完轮到对手');
  eq(st.board[6][2].up, 0, 'apply 不修改原状态');
  eq(st.board[5][2], null, 'apply 不修改原状态（目标格原本是空的）');
})();

/* ============ 14. 胜负 ============ */
section('胜负');
(function () {
  var st = emptyState();
  st.turn = RED;
  put(st, 1, 4, RED, 'R', true);
  put(st, 0, 4, BLACK, 'K', true);
  put(st, 9, 4, RED, 'K', true);
  var next = E.apply(st, { kind: 'move', from: [1, 4], to: [0, 4] });
  ok(next.over, '吃掉对方将/帅立即终局');
  eq(next.winner, RED, '吃将方获胜');
  eq(next.reason, 'king', '终局原因是吃将');
  eq(next.captured.b.length, 1, '被吃的将进入战利品栏');
})();

/* ============ 15. 困毙 ============ */
section('困毙');
(function () {
  // 取消「原地翻开」之后，困毙不再「几乎不可能」：一方半场里的暗子若全被堵死、
  // 明子也被堵死，它就真的无子可动 → 判负。（这里用人工状态覆盖该判定分支）
  var st = emptyState();
  put(st, 0, 4, BLACK, 'K', true);
  st.turn = BLACK;
  eq(E.allActions(st, RED).length, 0, '红方在这个局面里没有任何合法行动');
  var next = E.apply(st, { kind: 'move', from: [0, 4], to: [0, 3] });
  ok(next.over, '轮到无子可动的一方时立即终局');
  eq(next.winner, BLACK, '困毙方判负');
  eq(next.reason, 'stuck', '终局原因是困毙');

  // 反向验证：己方半场还有「走得动」的暗子，就一定有合法行动
  var st2 = emptyState();
  put(st2, 9, 4, RED, 'K', true);
  put(st2, 0, 4, BLACK, 'K', true);
  put(st2, 6, 2, BLACK, 'R', false);       // 兵位上的暗子，前方 (5,2) 是空的
  ok(E.allActions(st2, RED).length > 0, '己方半场有能走动的暗子时，就存在合法行动');

  // 再反向：暗子被彻底堵死 → 它提供不了任何行动
  var st3 = emptyState();
  put(st3, 9, 4, RED, 'K', true);
  put(st3, 0, 4, BLACK, 'K', true);
  put(st3, 6, 2, BLACK, 'R', false);       // 兵位暗子
  put(st3, 5, 2, RED, 'P', true);          // 堵死它唯一的去路
  eq(E.allActions(st3, RED).filter(function (a) { return a.from[0] === 6 && a.from[1] === 2; }).length, 0,
     '被堵死的暗子一步都走不了 —— 它永远翻不开，成为一堵永久的墙');
})();

/* ============ 16. 和棋阈值 ============ */
section('和棋');
(function () {
  var st = emptyState();
  st.turn = RED;
  put(st, 9, 4, RED, 'K', true);
  put(st, 0, 4, BLACK, 'K', true);
  put(st, 9, 0, RED, 'R', true);
  st.quiet = 119;
  var next = E.apply(st, { kind: 'move', from: [9, 0], to: [8, 0] });
  ok(next.over && next.winner === 'draw', '连续 120 个半步无吃子无翻牌判和');
})();

/* ============ 17. AI ============ */
section('AI');
(function () {
  var st = emptyState();
  st.turn = RED;
  put(st, 1, 4, RED, 'R', true);
  put(st, 0, 4, BLACK, 'K', true);
  put(st, 9, 4, RED, 'K', true);
  var a = E.aiChoose(st, RED, seeded(42), 2);
  ok(a && a.kind === 'move' && a.to[0] === 0 && a.to[1] === 4, 'AI 会走出吃将的制胜着');

  // 批量对局：全部正常收场，没有异常、没有死循环
  var M = 20, ended = 0, draws = 0, maxLen = 0, minLen = 1e9;
  for (var i = 0; i < M; i++) {
    var g = E.newGame(seeded(i * 65537 + 11)), n = 0;
    while (!g.over && n < 1500) {
      var act = E.aiChoose(g, g.turn, seeded(n * 31 + 1), 2);
      if (!act) break;
      g = E.apply(g, act); n++;
    }
    if (g.over) ended++;
    if (g.reason === 'draw') draws++;
    if (n > maxLen) maxLen = n;
    if (n < minLen) minLen = n;
  }
  eq(ended, M, M + ' 局 AI 对局全部正常收场（手数 ' + minLen + '–' + maxLen + '）');
  ok(draws < M, 'AI 之间并非局局和棋（' + (M - draws) + '/' + M + ' 局分出胜负）');
})();

/* ============ 海外版：棋子英文名表 ============ */
section('海外版：棋子英文名表（NAME_EN）');

eq(typeof E.NAME_EN, 'object', '引擎导出 NAME_EN');
eq(Object.keys(E.NAME_EN).length, 7, '7 种棋子都有英文名');
eq(E.NAME_EN.K, 'General', 'K → General');
eq(E.NAME_EN.A, 'Advisor', 'A → Advisor');
eq(E.NAME_EN.E, 'Elephant', 'E → Elephant');
eq(E.NAME_EN.R, 'Chariot', 'R → Chariot');
eq(E.NAME_EN.H, 'Horse', 'H → Horse');
eq(E.NAME_EN.C, 'Cannon', 'C → Cannon');
eq(E.NAME_EN.P, 'Soldier', 'P → Soldier');
E.TYPES.forEach(function (t) {
  ok(typeof E.NAME_EN[t] === 'string' && E.NAME_EN[t].length > 0, t + ' 有非空英文名');
});
// 关键约束：英文化**只加注记**，棋子面必须仍是汉字
E.TYPES.forEach(function (t) {
  ok(/[\u4e00-\u9fa5]/.test(E.NAME[t][E.RED]) && /[\u4e00-\u9fa5]/.test(E.NAME[t][E.BLACK]),
     t + ' 棋子面仍是汉字（' + E.NAME[t][E.RED] + '/' + E.NAME[t][E.BLACK] + '）');
});

/* ============ 汇总 ============ */
console.log('\n──────────────────────────────');
console.log(fail === 0 ? '✅ 全部通过：' + pass + ' 项断言' : '❌ ' + fail + ' 项失败 / 共 ' + (pass + fail) + ' 项');
if (fail) { console.log('失败明细：'); failures.forEach(function (f) { console.log(' - ' + f); }); }
