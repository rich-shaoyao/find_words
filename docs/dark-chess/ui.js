/*
 * 暗棋原型交互层（依赖 engine.js 暴露的全局 DarkChess）
 * 纯 DOM，无第三方库；直接双击 prototype.html 或用 http.server 打开即可下棋。
 */
if (typeof document !== 'undefined') (function () {
  'use strict';

  var E = DarkChess;
  var PAD = 60, CELL = 100, VBW = 920, VBH = 1020;
  var LEVEL_NAME = { 1: 'Easy', 2: 'Normal', 3: 'Hard' };

  var state = null;
  var stack = [];            // 悔棋栈：每次行动前的局面快照
  var selected = null;       // {r,c}
  var moves = [];            // 当前选中子的合法落点
  var hint = null;           // {kind, from?, to} 提示高亮
  var mode = 'ai';           // 'ai' | 'pvp'
  var mySide = E.RED;
  var level = 2;
  var busy = false;
  var soundOn = true;
  var actx = null;

  function $(id) { return document.getElementById(id); }
  function X(c) { return PAD + c * CELL; }
  function Y(r) { return PAD + r * CELL; }

  /* ---------------- 音效（WebAudio 合成，无外部资源） ---------------- */
  function beep(freq, dur, type, vol) {
    if (!soundOn) return;
    try {
      if (!actx) actx = new (window.AudioContext || window.webkitAudioContext)();
      var o = actx.createOscillator(), g = actx.createGain(), t = actx.currentTime;
      o.type = type || 'sine';
      o.frequency.value = freq;
      g.gain.setValueAtTime(0.0001, t);
      g.gain.exponentialRampToValueAtTime(vol || 0.1, t + 0.012);
      g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
      o.connect(g); g.connect(actx.destination);
      o.start(t); o.stop(t + dur + 0.03);
    } catch (e) { /* 音频不可用时静默 */ }
  }

  /* ---------------- 棋盘底纹（只画一次） ---------------- */
  function buildGrid() {
    var s = '';
    var i;
    s += '<rect class="frame-out" x="' + (X(0) - 14) + '" y="' + (Y(0) - 14) +
         '" width="' + (8 * CELL + 28) + '" height="' + (9 * CELL + 28) + '" rx="6"/>';
    for (i = 0; i < 10; i++)
      s += '<line x1="' + X(0) + '" y1="' + Y(i) + '" x2="' + X(8) + '" y2="' + Y(i) + '"/>';
    for (i = 0; i < 9; i++) {
      if (i === 0 || i === 8) {
        s += '<line x1="' + X(i) + '" y1="' + Y(0) + '" x2="' + X(i) + '" y2="' + Y(9) + '"/>';
      } else {
        s += '<line x1="' + X(i) + '" y1="' + Y(0) + '" x2="' + X(i) + '" y2="' + Y(4) + '"/>';
        s += '<line x1="' + X(i) + '" y1="' + Y(5) + '" x2="' + X(i) + '" y2="' + Y(9) + '"/>';
      }
    }
    // 九宫斜线
    s += '<line class="palace-x" x1="' + X(3) + '" y1="' + Y(0) + '" x2="' + X(5) + '" y2="' + Y(2) + '"/>';
    s += '<line class="palace-x" x1="' + X(5) + '" y1="' + Y(0) + '" x2="' + X(3) + '" y2="' + Y(2) + '"/>';
    s += '<line class="palace-x" x1="' + X(3) + '" y1="' + Y(7) + '" x2="' + X(5) + '" y2="' + Y(9) + '"/>';
    s += '<line class="palace-x" x1="' + X(5) + '" y1="' + Y(7) + '" x2="' + X(3) + '" y2="' + Y(9) + '"/>';
    s += '<rect class="frame" x="' + X(0) + '" y="' + Y(0) + '" width="' + (8 * CELL) + '" height="' + (9 * CELL) + '" fill="none"/>';
    s += '<text class="river-txt" x="' + (X(2)) + '" y="' + (Y(4) + CELL / 2 + 19) + '">CHU RIVER</text>';
    s += '<text class="river-txt" x="' + (X(6)) + '" y="' + (Y(4) + CELL / 2 + 19) + '">HAN BORDER</text>';
    $('grid').innerHTML = s;
  }

  /* ---------------- 渲染 ---------------- */
  function pieceSVG(p, r, c) {
    var cls = 'piece ' + (p.up ? (p.s === E.RED ? 'red' : 'black') : 'hidden');
    if (p.t === 'K') cls += ' king';
    if (selected && selected.r === r && selected.c === c) cls += ' selected';
    // 所有可动内容包在 .piece-inner 里：外层 <g> 用 translate 定位，
    // 动画的 CSS transform 只作用在内层，否则会覆盖 translate 把棋子甩到原点。
    var inner = '<ellipse class="p-shadow" cx="0" cy="6" rx="44" ry="44"/>';
    if (p.t === 'K') inner += '<circle class="p-halo" r="50"/>';
    inner += '<circle class="p-body" r="44"/><circle class="p-ring" r="36"/>';
    if (p.t === 'K') inner += '<circle class="p-crown" r="47"/>';
    if (p.up) {
      // 棋子面**只留汉字并居中**：棋子大小完全由传统比例决定，不因文字被撑大。
      // 英文名不再常驻在盘面上（那会把棋子挤大），改成**长按**时弹出说明。
      inner += '<text class="p-text" dy="0.35em">' + E.name(p) + '</text>';
    } else inner += '<text class="p-glyph" dy="0.35em">?</text>';
    if (selected && selected.r === r && selected.c === c) inner += '<circle class="sel-ring" r="51"/>';
    return '<g class="' + cls + '" data-cell="' + r + '-' + c + '" transform="translate(' +
           X(c) + ',' + Y(r) + ')"><g class="piece-inner">' + inner + '</g></g>';
  }

  function marksSVG() {
    var s = '', i, m, occ;
    if (state.last) {
      if (state.last.kind === 'move') {
        s += '<circle class="last-from" cx="' + X(state.last.from[1]) + '" cy="' + Y(state.last.from[0]) + '" r="46"/>';
        s += '<circle class="last-to" cx="' + X(state.last.to[1]) + '" cy="' + Y(state.last.to[0]) + '" r="46"/>';
      } else if (state.last.kind === 'flip') {
        s += '<circle class="last-to" cx="' + X(state.last.to[1]) + '" cy="' + Y(state.last.to[0]) + '" r="46"/>';
      }
    }
    for (i = 0; i < moves.length; i++) {
      m = moves[i]; occ = state.board[m.r][m.c];
      if (occ) {
        s += '<circle class="mark-dot-cap" cx="' + X(m.c) + '" cy="' + Y(m.r) + '" r="43"/>';
        s += '<circle class="mark-cap" cx="' + X(m.c) + '" cy="' + Y(m.r) + '" r="45"/>';
      } else {
        s += '<circle class="mark-dot" cx="' + X(m.c) + '" cy="' + Y(m.r) + '" r="15"/>';
      }
    }
    if (hint) {
      if (hint.kind === 'move') {
        s += '<circle class="hint-ring" cx="' + X(hint.from[1]) + '" cy="' + Y(hint.from[0]) + '" r="47"/>';
        s += '<circle class="hint-ring" cx="' + X(hint.to[1]) + '" cy="' + Y(hint.to[0]) + '" r="47"/>';
      } else {
        s += '<circle class="hint-ring" cx="' + X(hint.c) + '" cy="' + Y(hint.r) + '" r="47"/>';
      }
    }
    return s;
  }

  function lootHTML(list, side) {
    var out = '';
    for (var i = 0; i < list.length; i++) {
      var x = list[i];
      out += '<span class="loot ' + (side === E.RED ? 'r' : 'b') + (x.up ? '' : ' hid') + '">' +
             (x.up ? E.NAME[x.t][side] : '?') + '</span>';
    }
    return out;
  }

  function updateHud() {
    // 「本方暗子」= 自己半场还剩多少枚暗子（对方半场的碰不得，也揭不开）
    $('botHidden').textContent = 'Hidden ' + E.countHiddenInHalf(state.board, E.RED);
    $('topHidden').textContent = 'Hidden ' + E.countHiddenInHalf(state.board, E.BLACK);
    $('hudBottom').classList.toggle('active', !state.over && state.turn === E.RED);
    $('hudTop').classList.toggle('active', !state.over && state.turn === E.BLACK);
    $('botTray').innerHTML = lootHTML(state.captured[E.RED], E.RED);
    $('topTray').innerHTML = lootHTML(state.captured[E.BLACK], E.BLACK);
  }

  function updateBanner() {
    var b = $('banner');
    b.className = 'banner';
    if (!state) return;
    if (state.over) { b.textContent = 'Game over'; return; }
    if (mode === 'ai' && state.turn !== mySide) { b.textContent = 'Opponent is thinking…'; return; }
    var label = mode === 'ai' ? 'Your turn' : (state.turn === E.RED ? 'Red to move' : 'Black to move');
    if (selected) {
      var sel = state.board[selected.r][selected.c];
      b.textContent = label + (sel && !sel.up
        ? ': hidden piece — tap a destination to push it, and it flips as it moves. Tap it again to cancel'
        : ': pick a destination. Tap an empty spot to cancel');
    } else {
      b.textContent = label + ': tap one of your pieces to step it (hidden pieces move too, and flip after moving)';
    }
  }

  function render() {
    var s = '', r, c;
    for (r = 0; r < 10; r++) for (c = 0; c < 9; c++) {
      var p = state.board[r][c];
      if (p) s += pieceSVG(p, r, c);
    }
    $('pieces').innerHTML = s;
    $('marks').innerHTML = marksSVG();
    updateHud();
    updateBanner();
    $('btnUndo').disabled = stack.length === 0 || busy || state.over;
  }

  /* ---------------- 点击 → 棋盘坐标 ---------------- */
  function hitCell(ev) {
    var rect = $('board').getBoundingClientRect();
    var scale = Math.min(rect.width / VBW, rect.height / VBH);
    var offX = (rect.width - VBW * scale) / 2;
    var offY = (rect.height - VBH * scale) / 2;
    var x = (ev.clientX - rect.left - offX) / scale;
    var y = (ev.clientY - rect.top - offY) / scale;
    var c = Math.round((x - PAD) / CELL), r = Math.round((y - PAD) / CELL);
    if (r < 0 || r > 9 || c < 0 || c > 8) return null;
    var dx = x - X(c), dy = y - Y(r);
    if (dx * dx + dy * dy > 54 * 54) return null;
    return { r: r, c: c };
  }

  /* ---------------- 行动 ---------------- */
  // ⚠️ 本作**没有「原地翻开」**：想知道一枚暗子是谁的，唯一的办法是把它走一步（走完自动翻开）。
  //    所以这里只有 doMove 一个行动入口，不存在 doFlip。

  function doMove(from, to) {
    busy = true;
    var mover = state.board[from.r][from.c];
    var cap = state.board[to.r][to.c];
    var willReveal = !!(mover && !mover.up);   // 规则 4：暗子走完必须立刻翻开
    beep(cap ? 190 : 300, cap ? 0.17 : 0.08, cap ? 'square' : 'triangle', cap ? 0.13 : 0.1);
    stack.push(state);
    state = E.apply(state, { kind: 'move', from: [from.r, from.c], to: [to.r, to.c] });
    selected = null; moves = []; hint = null; busy = false;
    render();
    if (willReveal) {
      var el = document.querySelector('[data-cell="' + to.r + '-' + to.c + '"]');
      if (el) el.classList.add('appear');
    }
    afterMove();
  }

  function afterMove() {
    if (state.over) { setTimeout(showResult, 460); return; }
    if (mode === 'ai' && state.turn !== mySide) {
      busy = true;
      render();
      setTimeout(aiTurn, 640);
    }
  }

  function aiTurn() {
    busy = false;
    if (!state || state.over) { render(); return; }
    var a = E.aiChoose(state, state.turn, Math.random, level);
    if (!a) { render(); return; }
    doMove({ r: a.from[0], c: a.from[1] }, { r: a.to[0], c: a.to[1] });
  }

  function onCell(r, c) {
    if (!state || state.over || busy) return;
    if (mode === 'ai' && state.turn !== mySide) return;
    var p = state.board[r][c], i;

    // 1) 点的是高亮落点 → 走子（暗子走完会自动翻开）
    for (i = 0; i < moves.length; i++)
      if (moves[i].r === r && moves[i].c === c) { doMove(selected, { r: r, c: c }); return; }

    // 2) 点自己的明棋 → 选中、显示落点；再点一次取消选择
    if (p && p.up && p.s === state.turn) {
      if (selected && selected.r === r && selected.c === c) {
        selected = null; moves = [];
        render();
        return;
      }
      selected = { r: r, c: c };
      moves = E.legalMoves(state, r, c);
      hint = null;
      beep(680, 0.04, 'sine', 0.06);
      render();
      return;
    }

    // 3) 点自己半场的暗子 → 选中，按「所在点位的标准棋子」亮出落点。
    //    落点绝不能按归属过滤：否则「有没有落点」会反过来泄露这枚暗子是谁的。
    //    选中后**只能靠走出去来揭开它**（走完自动翻开），再点一次是取消选中。
    if (p && !p.up && E.ownsHalf(state.turn, r)) {
      if (selected && selected.r === r && selected.c === c) {
        selected = null; moves = []; render(); return;   // 再点一次 = 取消（已不能原地翻开）
      }
      selected = { r: r, c: c };
      moves = E.legalMoves(state, r, c);
      hint = null;
      beep(680, 0.04, 'sine', 0.06);
      render();
      return;
    }

    // 4) 对方半场的暗子 / 对方的明棋 → 拦下
    //    提示必须排在 render 之后：render 会走 updateBanner，把 flash 的文案冲掉
    selected = null; moves = [];
    render();
    if (p && !p.up) flash("That hidden piece is in the opponent's half — you can only reveal it once it comes over", 'bad');
    else if (p) flash("That's the opponent's piece", 'bad');
  }

  /* ---------------- 工具栏 ---------------- */
  function undo() {
    if (busy || !state || state.over || !stack.length) return;
    if (mode === 'ai') {
      var idx = -1, i;
      for (i = stack.length - 1; i >= 0; i--) if (stack[i].turn === mySide) { idx = i; break; }
      if (idx < 0) return;
      var target = stack[idx];
      stack = stack.slice(0, idx);
      state = target;
    } else {
      state = stack.pop();
    }
    selected = null; moves = []; hint = null;
    render();
  }

  function showHint() {
    if (busy || !state || state.over) return;
    if (mode === 'ai' && state.turn !== mySide) return;
    var a = E.aiChoose(state, state.turn, Math.random, 3);
    if (!a) return;
    hint = a;
    render();
    setTimeout(function () { if (hint === a) { hint = null; render(); } }, 2400);
  }

  function giveUp() {
    if (!state || state.over) return;
    var loser = mode === 'ai' ? mySide : state.turn;
    state = E.clone(state);
    state.over = true;
    state.reason = 'resign';
    state.winner = loser === E.RED ? E.BLACK : E.RED;
    selected = null; moves = []; hint = null;
    render();
    showResult();
  }

  function flash(text, cls) {
    var b = $('banner');
    b.className = 'banner ' + (cls || '');
    b.textContent = text;
    setTimeout(updateBanner, 1700);
  }

  /* ---------------- 弹窗 ---------------- */
  function openModal(title, bodyHTML, buttons) {
    $('mTitle').textContent = title;
    $('mBody').innerHTML = bodyHTML;
    var wrap = $('mBtns');
    wrap.innerHTML = '';
    buttons.forEach(function (b) {
      var el = document.createElement('button');
      el.className = 'btn' + (b.primary ? ' primary' : '');
      el.textContent = b.label;
      el.onclick = b.fn;
      wrap.appendChild(el);
    });
    $('modal').classList.remove('hidden');
  }
  function closeModal() { $('modal').classList.add('hidden'); }

  function showResult() {
    var body = '', title = '';
    var win = state.winner;
    var reason = {
      king: 'The General was captured.',
      stuck: 'The opponent has no legal move left.',
      draw: 'No capture and no flip for 60 moves each — a draw.',
      resign: 'A player resigned.'
    }[state.reason] || '';

    if (mode === 'ai') {
      if (win === 'draw') { title = 'Draw'; body = reason; }
      else if (win === mySide) { title = 'You win'; body = 'You captured the enemy General. ' + reason; beep(660, .12, 'sine', .1); }
      else { title = 'You lose'; body = reason; beep(200, .3, 'sawtooth', .09); }
    } else {
      if (win === 'draw') { title = 'Draw'; body = reason; }
      else { title = (win === E.RED ? 'Red wins' : 'Black wins'); body = reason; }
    }

    openModal(title, '<p class="center">' + body + '</p>', [
      { label: 'Play again', primary: true, fn: function () { closeModal(); startGame(mode); } },
      { label: 'Back to menu', fn: function () { closeModal(); backToMenu(); } }
    ]);
  }

  function showHelp() {
    openModal('How to Play',
      '<ul>' +
      '<li><b>Setup</b> — All 32 standard Xiangqi points are filled. Both <b>Generals start face-up</b> on their own back-rank centre; the remaining <b>30 pieces are face-down and shuffled together</b> — Red and Black mixed. You never know who stands where, or whose piece it is. <b>Long-press any piece</b> for about half a second to see its English name and how it moves.</li>' +
      '<li><b>Turn</b> — Each turn you <b>step one of your pieces</b>. There is <b>no “flip in place”</b> — the only way to reveal a hidden piece is to move it.</li>' +
      '<li><b>Reveal by pushing</b> — A hidden piece <b>flips face-up the moment it finishes its move</b>. So “pushing a hidden piece” is the core action: it may turn out to be your Chariot, or your opponent’s — you only find out by moving it.</li>' +
      '<li><b>Hidden pieces move</b> — A face-down piece moves <b>according to the standard piece of the point it occupies</b> — on a back-rank Chariot point it slides like a Chariot, on a Soldier point it steps one square forward. It flips after moving, and from then on follows its <b>real identity</b>.</li>' +
      '<li><b>Capturing</b> — Only two things can be captured: the <b>opponent’s face-up pieces</b>, and <b>hidden pieces sitting in the opponent’s half</b> (no matter who they really belong to). <b>Hidden pieces in your own half can never be captured</b> — push them out to deal with them. Sides are judged only from open information.</li>' +
      '<li><b>Movement</b> — Once face-up, standard Xiangqi rules apply: the Chariot slides, the Horse moves in an L (its leg can be blocked), the Cannon captures over exactly one screen. <b>Screens may be face-down</b>, and <b>a Cannon can capture the General</b> — but a face-down Cannon can only sit on a Cannon point, which cannot reach the enemy back-rank centre, so a one-move kill has to wait until a Cannon is revealed.</li>' +
      '<li><b>House rules</b> — Advisor and Elephant are <b>not restricted to their own side</b> — they may cross the river and enter the palace. The General may only move inside its own 3×3 palace. Soldiers never move backward and may step sideways once across the river.</li>' +
      '<li><b>Winning</b> — Capture the enemy General to win. A side with no legal move loses. 60 moves each with no capture and no flip is a draw.</li>' +
      '</ul>',
      [{ label: 'Got it', primary: true, fn: closeModal }]);
  }

  /* ---------------- 开局 / 返回 ---------------- */
  function startGame(m) {
    mode = m;
    mySide = E.RED;
    stack = []; selected = null; moves = []; hint = null; busy = false;
    state = E.newGame();
    $('menu').classList.remove('active');
    $('game').classList.add('active');
    $('topName').textContent = mode === 'ai' ? 'Computer · ' + LEVEL_NAME[level] : 'Black';
    $('botName').textContent = mode === 'ai' ? 'You · Red' : 'Red';
    buildGrid();
    render();
    flash('Dice roll: ' + (state.turn === E.RED ? 'Red' : 'Black') + ' moves first', 'good');
    if (mode === 'ai' && state.turn !== mySide) { busy = true; render(); setTimeout(aiTurn, 820); }
  }

  function backToMenu() {
    busy = false;
    $('game').classList.remove('active');
    $('menu').classList.add('active');
  }

  /* ---------------- 长按：查看棋子的英文说明 ---------------- */
  // 盘面只保留汉字（传统比例，不因文字被撑大），海外玩家认牌靠长按。
  // **只讲公开信息**：暗子只说「它按所在点位的哪种棋子走」，绝不透露真实归属，
  // 否则长按就成了作弊器（引擎里暗示归属的字段一个都不用）。
  var PRESS_MS = 520;
  var pressTimer = null, pressCell = null, pressAt = null, pressFired = 0;

  function cancelPress() {
    if (pressTimer !== null) { clearTimeout(pressTimer); pressTimer = null; }
    pressCell = null; pressAt = null;
  }

  function pieceInfo(p, r, c) {
    if (p.up) {
      return E.name(p) + ' · ' + E.NAME_EN[p.t] +
             '　(' + (p.s === E.RED ? 'Red' : 'Black') + ' — face-up, moves as a normal ' +
             E.NAME_EN[p.t] + ')';
    }
    // 暗子：只按「所在点位」说话。暗子移动后必须立刻翻开，所以它永远停在开局点位上；
    // 兜底到 P 只是为了保证 homeType 万一返回 null 时不产出 undefined。
    var ht = E.homeType(r, c) || 'P';
    return 'Face-down piece on a ' + E.NAME_EN[ht] + ' point — it moves like a ' +
           E.NAME_EN[ht] + ' while hidden, and flips the moment it moves';
  }

  function beginPress(r, c, x, y) {
    cancelPress();
    pressCell = { r: r, c: c };
    pressAt = { x: x, y: y };
    pressTimer = setTimeout(function () {
      pressTimer = null;
      var cell = pressCell;
      cancelPress();
      if (!cell || !state) return;
      var p = state.board[cell.r][cell.c];
      if (!p) return;
      pressFired = Date.now();       // 吞掉紧随其后的 click，别让长按又走一步棋
      flash(pieceInfo(p, cell.r, cell.c), 'good');
    }, PRESS_MS);
  }

  /* ---------------- 事件绑定 ---------------- */
  // 长按 = 看说明，短点击 = 走棋。用 pointer 事件统一鼠标与触摸。
  $('board').addEventListener('pointerdown', function (ev) {
    var cell = hitCell(ev);
    if (cell) beginPress(cell.r, cell.c, ev.clientX, ev.clientY);
  });
  $('board').addEventListener('pointermove', function (ev) {
    if (!pressAt) return;
    // 手指按下时难免微动，给 12px 宽容度；超过才算「拖走」，取消长按
    if (Math.abs(ev.clientX - pressAt.x) + Math.abs(ev.clientY - pressAt.y) > 12) cancelPress();
  });
  $('board').addEventListener('pointerup', cancelPress);
  $('board').addEventListener('pointercancel', cancelPress);
  $('board').addEventListener('pointerleave', cancelPress);

  $('board').addEventListener('click', function (ev) {
    // 刚完成一次长按：这次 click 属于那次长按，吞掉
    if (pressFired && Date.now() - pressFired < 700) { pressFired = 0; return; }
    pressFired = 0;
    var cell = hitCell(ev);
    if (cell) onCell(cell.r, cell.c);
  });

  $('btnAI').onclick = function () { startGame('ai'); };
  $('btnPvP').onclick = function () { startGame('pvp'); };
  $('btnHelp').onclick = showHelp;
  $('btnUndo').onclick = undo;
  $('btnHint').onclick = showHint;
  $('btnGiveUp').onclick = giveUp;
  $('btnBack').onclick = backToMenu;
  $('chkSound').onchange = function () { soundOn = this.checked; if (soundOn) beep(660, .06, 'sine', .08); };

  Array.prototype.forEach.call($('levelSeg').querySelectorAll('button'), function (b) {
    b.onclick = function () {
      level = parseInt(b.getAttribute('data-level'), 10);
      Array.prototype.forEach.call($('levelSeg').querySelectorAll('button'), function (x) {
        x.classList.toggle('on', x === b);
      });
    };
  });
})();
