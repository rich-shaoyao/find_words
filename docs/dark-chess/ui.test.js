/*
 * 交互层回归测试：JavaScriptCore + 手写 DOM 桩
 *   cd docs/dark-chess && jsc ui.test.js
 *
 * 为什么不用浏览器：本机没有 node，Chrome headless 在无图形会话的沙箱里会崩。
 * 这个桩只实现 ui.js 真正用到的那点 DOM API，用「点击坐标 → 事件」的方式
 * 驱动真实交互序列，验证渲染产出与状态流转（不覆盖 CSS/SVG 的视觉呈现）。
 */
var DIR = './';
load(DIR + 'engine.js');

var pass = 0, fail = 0, failures = [];
function ok(cond, msg) { if (cond) pass++; else { fail++; failures.push(msg); print('  x ' + msg); } }
function eq(a, b, msg) { ok(a === b, msg + ' (期望 ' + JSON.stringify(b) + '，实际 ' + JSON.stringify(a) + ')'); }
function section(t) { print('\n▶ ' + t); }

/* ================= 最小 DOM 桩 ================= */
var PIECES_INDEX = {};

function El(id) {
  this.id = id || '';
  this.html = '';
  this.textContent = '';
  this.className = '';
  this.disabled = false;
  this.style = {};
  this.kids = [];
  this.handlers = {};
  this.onclick = null;
  this.onchange = null;
  var s = {};
  this.classList = {
    add: function (c) { s[c] = 1; },
    remove: function (c) { delete s[c]; },
    contains: function (c) { return !!s[c]; },
    toggle: function (c, on) {
      if (on === undefined) on = !s[c];
      if (on) s[c] = 1; else delete s[c];
      return !!s[c];
    }
  };
}
El.prototype.querySelector = function (sel) {
  if (sel === 'button') return this.kids.length ? this.kids[0] : null;
  return null;
};
El.prototype.querySelectorAll = function (sel) {
  if (sel === 'button') return this.kids.slice();
  return [];
};
El.prototype.appendChild = function (el) { this.kids.push(el); };
El.prototype.getAttribute = function (k) { return this.attrs ? this.attrs[k] : undefined; };
El.prototype.addEventListener = function (t, fn) { this.handlers[t] = fn; };
El.prototype.getBoundingClientRect = function () { return { left: 0, top: 0, width: 420, height: 900 }; };
El.prototype.setAttribute = function (k, v) { (this.attrs = this.attrs || {})[k] = v; };

function setHTML(el, v) {
  el.html = String(v);
  if (el.id === 'pieces') {          // 从渲染出的 SVG 里重建可查询的棋子索引
    PIECES_INDEX = {};
    var re = /<g class="([^"]*)" data-cell="(\d+)-(\d+)"/g, m;
    while ((m = re.exec(el.html))) {
      var e = new El();
      var cls = m[1].split(/\s+/);
      for (var i = 0; i < cls.length; i++) if (cls[i]) e.classList.add(cls[i]);
      PIECES_INDEX[m[2] + '-' + m[3]] = e;
    }
  }
}
Object.defineProperty(El.prototype, 'innerHTML', {
  get: function () { return this.html; },
  set: function (v) { setHTML(this, v); }
});

var ELS = {};
var document = {
  getElementById: function (id) { return ELS[id] || (ELS[id] = new El(id)); },
  createElement: function () { return new El(); },
  addEventListener: function () {},
  querySelector: function (sel) {
    var m = /^\[data-cell="(\d+)-(\d+)"\]$/.exec(sel);
    if (m) return PIECES_INDEX[m[1] + '-' + m[2]] || null;
    return null;
  }
};
(function () {   // 预置难度分段控件里的三个按钮（带 data-level）
  var seg = document.getElementById('levelSeg');
  [1, 2, 3].forEach(function (lv) {
    var b = new El(); b.attrs = { 'data-level': String(lv) }; seg.kids.push(b);
  });
})();

/* jsc 无计时器：把 setTimeout 做成可手动 flush 的队列，按入队顺序同步执行。
   条目带 id 与 dead 标记，这样 clearTimeout 能真正取消（长按靠它实现）。 */
var TIMERS = [], TIMER_ID = 0;
function setTimeout(fn) { TIMERS.push({ id: ++TIMER_ID, fn: fn, dead: false }); return TIMER_ID; }
function clearTimeout(id) {
  for (var i = 0; i < TIMERS.length; i++) if (TIMERS[i].id === id) TIMERS[i].dead = true;
}
// 只跑队列里最靠前的一个。长按测试必须用它：flash 内部还会排一个 1700ms 的
// 「复原提示条」定时器，若跟 runTimers 一起全跑掉，说明刚弹出就被覆盖回去了。
function flushOne() {
  var guard = 0;
  while (TIMERS.length && guard++ < 500) {
    var t = TIMERS.shift();
    if (t.dead) continue;
    t.fn();
    return;
  }
}
function runTimers() {
  var guard = 0;
  while (TIMERS.length && guard++ < 500) { var t = TIMERS.shift(); if (!t.dead) t.fn(); }
}
window = { AudioContext: undefined, webkitAudioContext: undefined };  // beep 走 try/catch 静默分支

/* ================= 载入被测对象 ================= */
var loadError = null;
try { load(DIR + 'ui.js'); } catch (e) { loadError = e; }

/* ================= 工具 ================= */
function el(id) { return document.getElementById(id); }
function pieces() { return el('pieces').html; }
function marks() { return el('marks').html; }
function countHidden() { return (pieces().match(/class="piece hidden/g) || []).length; }
function countPiece() { return (pieces().match(/<g class="piece /g) || []).length; }
function faceUpCells(side) {
  var out = [], re = new RegExp('class="piece ' + side + '[^"]*" data-cell="(\\d+)-(\\d+)"', 'g'), m;
  while ((m = re.exec(pieces()))) out.push([+m[1], +m[2]]);
  return out;
}
function myTurn() { return el('hudBottom').classList.contains('active') ? 'red' : 'black'; }
function bannerIsOver() { return el('banner').textContent.indexOf('Game over') >= 0; }
function clickCell(r, c) {
  var rect = el('board').getBoundingClientRect();
  var scale = Math.min(rect.width / 920, rect.height / 1020);
  var offX = (rect.width - 920 * scale) / 2, offY = (rect.height - 1020 * scale) / 2;
  el('board').handlers.click({
    clientX: rect.left + offX + (60 + c * 100) * scale,
    clientY: rect.top + offY + (60 + r * 100) * scale
  });
}
// 长按：pointerdown 之后把 PRESS_MS 的定时器 flush 掉，即可触发说明
function press(r, c) {
  TIMERS = [];                                   // 清掉历史定时器，确保接下来触发的是长按那一个
  var rect = el('board').getBoundingClientRect();
  var scale = Math.min(rect.width / 920, rect.height / 1020);
  var offX = (rect.width - 920 * scale) / 2, offY = (rect.height - 1020 * scale) / 2;
  el('board').handlers.pointerdown({
    clientX: rect.left + offX + (60 + c * 100) * scale,
    clientY: rect.top + offY + (60 + r * 100) * scale
  });
  flushOne();
}
function findFirstMark() {
  var dm = /<circle class="(mark-dot|mark-cap)" cx="(\d+)" cy="(\d+)"/.exec(marks());
  return dm ? { r: Math.round((+dm[3] - 60) / 100), c: Math.round((+dm[2] - 60) / 100), cap: dm[1] === 'mark-cap' } : null;
}
// 自己半场里第一枚还能翻的暗子（对方半场的翻不得）
function findMyHidden(side) {
  var re = /class="piece hidden" data-cell="(\d+)-(\d+)"/g, m;
  while ((m = re.exec(pieces()))) {
    var r = +m[1];
    if ((side === 'red' && r >= 5) || (side === 'black' && r <= 4)) return { r: r, c: +m[2] };
  }
  return null;
}

/* ================= 断言 ================= */
section('载入');
ok(!loadError, 'ui.js 加载并初始化无异常' + (loadError ? '：' + loadError.message : ''));
ok(typeof el('btnAI').onclick === 'function', '主菜单按钮已绑定事件');
ok(typeof el('board').handlers.click === 'function', '棋盘点击已绑定');

section('开局（用本地双人模式，排除 AI 干扰）');
el('btnPvP').onclick();
eq(el('game').classList.contains('active'), true, '进入对局页');
eq(el('menu').classList.contains('active'), false, '主菜单被隐藏');
eq(el('topName').textContent, 'Black', '上方面板为黑方');
eq(el('botName').textContent, 'Red', '下方面板为红方');
eq(countPiece(), 32, '棋盘渲染 32 枚棋子');
eq(countHidden(), 30, '其中 30 枚扣着');
eq((pieces().match(/class="piece (red|black)[^"]* king/g) || []).length, 2, '恰好 2 枚明牌将/帅');
ok(pieces().indexOf('class="piece red king"') >= 0, '红帅为明牌');
ok(pieces().indexOf('class="piece black king"') >= 0, '黑将为明牌');
ok(el('grid').html.indexOf('CHU RIVER') >= 0 && el('grid').html.indexOf('HAN BORDER') >= 0, '棋盘底纹含河界（英文）');
eq(el('hudBottom').classList.contains('active') || el('hudTop').classList.contains('active'), true, '当前行动方 HUD 高亮');

section('揭开暗子：只能靠走动（没有原地翻开）');
runTimers();
var side0 = myTurn();
var t0 = findMyHidden(side0);
ok(!!t0, '自己半场存在暗子');

// 对方半场的暗子：点它完全不生效
(function () {
  var re = /class="piece hidden" data-cell="(\d+)-(\d+)"/g, m, opp = null;
  while ((m = re.exec(pieces()))) {
    var r = +m[1];
    if ((side0 === 'red' && r <= 4) || (side0 === 'black' && r >= 5)) { opp = { r: r, c: +m[2] }; break; }
  }
  if (!opp) return;
  var hh = countHidden();
  clickCell(opp.r, opp.c);
  eq(countHidden(), hh, '点对方半场的暗子 → 完全不生效');
  ok(el('banner').textContent.indexOf("opponent's half") >= 0, '提示「那是对方半场的暗子」（英文）');
  runTimers();
})();

// 己方半场的暗子：选中 → 出落点；再点一次只是取消，不会翻开
var h0 = countHidden();
clickCell(t0.r, t0.c);
eq(PIECES_INDEX[t0.r + '-' + t0.c].classList.contains('selected'), true, '点击暗子进入「选中」态');
ok(!!findFirstMark(), '选中暗子后亮出落点');
clickCell(t0.r, t0.c);               // 第二下：取消（不再是原地翻开）
runTimers();
eq(countHidden(), h0, '再点一次不会翻开它（暗子数不变）');
eq(PIECES_INDEX[t0.r + '-' + t0.c].classList.contains('selected'), false, '再点一次只是取消选中');

// 真的走一步 → 走完自动翻开
clickCell(t0.r, t0.c);
runTimers();
var mk0 = findFirstMark();
ok(!!mk0, '重新选中后有落点可走');
clickCell(mk0.r, mk0.c);
runTimers();
eq(countHidden(), h0 - 1, '走完自动翻开 → 暗子数恰好 -1');
ok(marks().indexOf('last-to') >= 0, '走动后留下「最近一步」标记');

section('暗棋落点不泄露归属');
(function () {
  // 己方半场的暗子必须**全部**能出落点 —— 一旦按归属过滤（不给对方子落点），
  // 「有没有落点」本身就会泄露这枚暗子是谁的，直接破坏「归属不公开」这条支点规则。
  // 取消点固定用红帅 (9,4)：轮红方时点两次＝选中/取消；轮黑方时它是对方明棋，一次点击就清空选中。
  // 黑方暗子一步绝无可能吃到 (9,4)，所以这个取消点不会误触发走子。
  var all = [], re = /class="piece hidden" data-cell="(\d+)-(\d+)"/g, mm;
  while ((mm = re.exec(pieces()))) all.push([+mm[1], +mm[2]]);
  var hiddenBefore = countHidden();
  var withMark = [], top = 0, bottom = 0;
  for (var i = 0; i < all.length; i++) {
    clickCell(all[i][0], all[i][1]);
    if (findFirstMark()) { withMark.push(all[i]); if (all[i][0] <= 4) top++; else bottom++; }
    clickCell(9, 4); clickCell(9, 4);
  }
  print('  debug: 暗子 ' + all.length + ' 枚 → 能出落点 ' + withMark.length
        + ' 枚（上半场 ' + top + ' / 下半场 ' + bottom + '）'
        + '  hudBottom.active=' + el('hudBottom').classList.contains('active')
        + '  banner="' + el('banner').textContent + '"');
  eq(withMark.length, 15, '恰好「己方半场」的 15 枚暗子都能出落点（另 15 枚在对方半场，翻不得也走不得）');
  ok((top === 15 && bottom === 0) || (top === 0 && bottom === 15),
     '能出落点的 15 枚全部集中在同一侧，不会两头都冒出来');
  eq(countHidden(), hiddenBefore, '整个选取过程没有翻动或吃掉任何棋子');
})();

section('走子');
var side = myTurn();
ok(side === 'red' || side === 'black', '能识别当前行动方');
var picked = null, ups = faceUpCells(side);
for (var i = 0; i < ups.length; i++) {
  clickCell(ups[i][0], ups[i][1]);
  if (findFirstMark()) { picked = ups[i]; break; }
  clickCell(ups[i][0], ups[i][1]);   // 取消选择
}
ok(!!picked, '选中己方明子后出现合法落点提示（候选 ' + ups.length + ' 枚）');
if (picked) {
  ok(PIECES_INDEX[picked[0] + '-' + picked[1]].classList.contains('selected'), '被选中的棋子带 .selected 样式');
  var mk = findFirstMark();
  ok(!!mk, '落点标记可解析');
  clickCell(mk.r, mk.c);
  runTimers();
  ok(new RegExp('class="piece ' + side + '[^"]*" data-cell="' + mk.r + '-' + mk.c + '"').test(pieces()),
     '棋子已移动到目标格 (' + mk.r + ',' + mk.c + ')');
  ok(marks().indexOf('last-from') >= 0, '移动后留下起点标记');
  ok(marks().indexOf('mark-dot') < 0 && marks().indexOf('mark-cap') < 0, '走完后落点提示被清除');
}

section('悔棋');
// 悔棋回退一步后，最可靠的观测点是「轮到谁」和「最近一步标记」——
// 只比暗子数会漏判（上一手走的是明子时，暗子数本来就不变）
var bBefore = el('banner').textContent, mb = marks();
el('btnUndo').onclick();
runTimers();
ok(el('banner').textContent !== bBefore || marks() !== mb,
   '悔棋后局面发生回退（行动方 / 最近一步标记被还原）');

section('弹窗与模式');
el('btnBack').onclick();
eq(el('menu').classList.contains('active'), true, '「菜单」返回主菜单');
el('btnHelp').onclick();
eq(el('modal').classList.contains('hidden'), false, '玩法说明弹窗打开');
ok(el('mBody').html.indexOf('flip in place') > 0, '玩法说明含规则正文（英文）');
ok(el('mBody').html.indexOf('not restricted to their own side') > 0, '玩法说明写明了仕/相不限区域（英文）');
el('mBtns').kids[0].onclick();
eq(el('modal').classList.contains('hidden'), true, '弹窗可关闭');

section('海外版：棋子面只留汉字（居中）+ 长按看英文说明');
el('btnPvP').onclick();
ok(el('topName').textContent === 'Black' && el('botName').textContent === 'Red', '上下双方名称为英文');
ok(el('botHidden').textContent.indexOf('Hidden ') === 0, '暗子计数为英文');

// 棋子面：只有汉字，不常驻任何英文（英文会把棋子撑大）
eq((pieces().match(/class="p-en"/g) || []).length, 0, '棋子面不再常驻英文注记');
eq((pieces().match(/class="p-text"/g) || []).length, 2, '开局只有 2 枚明棋（将帅）带汉字');
ok(pieces().indexOf('>帅</text>') >= 0 && pieces().indexOf('>将</text>') >= 0, '棋子面仍是汉字（帅 / 将）');
ok(pieces().indexOf('dy="0.35em">帅</text>') >= 0, '汉字在棋子内垂直居中');
ok(pieces().indexOf('class="piece hidden"') >= 0, '暗棋仍是背面 ?');

// 长按明棋：给出汉字 + 英文 + 归属
press(9, 4);                                   // 红帅
var info = el('banner').textContent;
ok(info.indexOf('帅') >= 0, '长按红帅 → 说明里同时有汉字');
ok(info.indexOf('General') >= 0, '长按红帅 → 说明里有英文 General');
ok(info.indexOf('Red') >= 0, '长按红帅 → 说明里标出归属 Red');

// 长按后紧跟的 click 必须被吞掉，否则长按会顺带走出一步棋
var beforePress = pieces();
press(9, 4);
clickCell(9, 4);
eq(pieces(), beforePress, '长按后的 click 被吞掉，局面纹丝不动');

// 长按暗棋：只说「按所在点位怎么走」，绝不泄露真实归属
var hid = findMyHidden(myTurn());
runTimers();
var hiddenBefore = countHidden();
press(hid.r, hid.c);
var hinfo = el('banner').textContent;
ok(hinfo.indexOf('Face-down') >= 0, '长按暗棋 → 说明它是暗子');
ok(hinfo.indexOf('point') >= 0, '长按暗棋 → 说明按「所在点位」的棋子走');
ok(hinfo.indexOf('Red') < 0 && hinfo.indexOf('Black') < 0,
   '长按暗棋**不泄露归属**（既不说 Red 也不说 Black）');
eq(countHidden(), hiddenBefore, '长按不改动局面');

// 长按期间拖走（超 12px）→ 定时器作废，不弹说明
(function () {
  runTimers();                                   // 先把上一次长按的 flash 复原跑干净
  TIMERS = [];
  var b = el('banner').textContent;
  var rect = el('board').getBoundingClientRect();
  var scale = Math.min(rect.width / 920, rect.height / 1020);
  var x = rect.left + (rect.width - 920 * scale) / 2 + (60 + 4 * 100) * scale;
  var y = rect.top + (rect.height - 1020 * scale) / 2 + (60 + 9 * 100) * scale;
  el('board').handlers.pointerdown({ clientX: x, clientY: y });
  eq(TIMERS.length, 1, '按下 → 排入一个长按定时器');
  el('board').handlers.pointermove({ clientX: x + 60, clientY: y });   // 拖走 60px
  eq(TIMERS.filter(function (t) { return !t.dead; }).length, 0, '拖走 → 长按定时器作废');
  runTimers();
  eq(el('banner').textContent, b, '拖走取消 → 不弹说明，提示条不变');
  // 短距离抖动（12px 以内）不应取消
  TIMERS = [];
  el('board').handlers.pointerdown({ clientX: x, clientY: y });
  el('board').handlers.pointermove({ clientX: x + 6, clientY: y + 5 });  // 抖动 11px < 12px
  eq(TIMERS.filter(function (t) { return !t.dead; }).length, 1, '手指微动 11px → 长按仍然有效');
  el('board').handlers.pointerup({});
  eq(TIMERS.filter(function (t) { return !t.dead; }).length, 0, '抬手 → 长按取消');
})();

section('人机对局 100 局模拟');
(function () {
  var games = 0, ended = 0, crashes = 0, err = null;
  try {
    for (var g = 0; g < 100; g++) {
      PIECES_INDEX = {}; TIMERS = [];
      el('menu').classList.add('active');
      el('game').classList.remove('active');
      el('btnAI').onclick();
      runTimers();                       // 若 AI 先手，先让它走
      games++;
      var steps = 0;
      while (steps++ < 600 && !bannerIsOver()) {
        // 没有「原地翻开」了：候选 = 自己的明子 + 自己半场的暗子，动作一律是「走一步」
        var side = myTurn();
        var cands = faceUpCells(side);
        var re2 = /class="piece hidden" data-cell="(\d+)-(\d+)"/g, mm2;
        while ((mm2 = re2.exec(pieces()))) {
          var rr2 = +mm2[1];
          if ((side === 'red' && rr2 >= 5) || (side === 'black' && rr2 <= 4)) cands.push([rr2, +mm2[2]]);
        }
        var moved = false;
        for (var k = 0; k < cands.length && !moved; k++) {
          clickCell(cands[k][0], cands[k][1]);
          var mk = findFirstMark();
          if (mk) { clickCell(mk.r, mk.c); moved = true; }
          else clickCell(cands[k][0], cands[k][1]);
        }
        if (!moved) break;
        runTimers();
      }
      if (bannerIsOver()) ended++;
      if (countPiece() < 2) crashes++;
    }
  } catch (e) { err = e; }
  ok(!err, '100 局连续对局无异常抛出' + (err ? '：' + err.message : ''));
  eq(games, 100, '跑满 100 局');
  eq(crashes, 0, '没有一局出现棋盘崩塌');
  ok(ended >= 95, '绝大多数对局能正常收场（' + ended + '/100）');
})();

print('\n──────────────────────────────');
print(fail === 0 ? '✅ 全部通过：' + pass + ' 项断言' : '❌ ' + fail + ' 项失败 / 共 ' + (pass + fail) + ' 项');
if (fail) failures.forEach(function (f) { print(' - ' + f); });
