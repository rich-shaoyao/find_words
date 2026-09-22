/*
 * 暗棋（翻棋）规则引擎 —— 纯逻辑，无 DOM 依赖
 * 可被浏览器 / JavaScriptCore(jsc) / 移植到 Swift 时逐条对照
 *
 * 棋盘坐标：9 列(c: 0..8) × 10 行(r: 0..9)，棋子放在交叉点上
 *   黑方半场 = 行 0..4（九宫 行 0..2, 列 3..5）
 *   红方半场 = 行 5..9（九宫 行 7..9, 列 3..5）
 *   河界在 行 4 与 行 5 之间
 *
 * 布阵（见 HOME / KING_HOME）：
 *   1. 红帅固定 (9,4)、黑将固定 (0,4)，正面朝上 —— 全场仅此两枚明棋
 *   2. 其余 30 枚（红 15 + 黑 15）全部背面朝上、混合洗牌后，
 *      铺在中国象棋标准格局的其余 30 个点位上。
 *      **每个点是哪个子、属于谁，全都不公开** —— 这是本玩法的核心。
 *
 * 回合（二选一）：
 *   · 翻开：翻开一枚「自己半场」的暗棋（可能翻出自己的，也可能翻出对手的）
 *   · 移动：移动一枚自己的棋子。暗棋也能走（按它的真实身份走），走完必须翻开
 *
 * 吃子（规则 5）：
 *   · 暗棋 只能吃 对方的明棋
 *   · 明棋 可以吃 任意暗棋（吃到自己的算自残）+ 对方的明棋
 */
(function (global) {
  'use strict';

  var COLS = 9, ROWS = 10;
  var RED = 'r', BLACK = 'b';
  var DIRS4 = [[-1, 0], [1, 0], [0, -1], [0, 1]];
  var DIAG1 = [[-1, -1], [-1, 1], [1, -1], [1, 1]];
  var DIAG2 = [[-2, -2], [-2, 2], [2, -2], [2, 2]];
  // 马：[dr, dc, 马腿 dr, 马腿 dc]
  var HORSE = [
    [-2, -1, -1, 0], [-2, 1, -1, 0], [2, -1, 1, 0], [2, 1, 1, 0],
    [-1, -2, 0, -1], [1, -2, 0, -1], [-1, 2, 0, 1], [1, 2, 0, 1]
  ];
  var PALACE = {
    r: { r0: 7, r1: 9, c0: 3, c1: 5 },
    b: { r0: 0, r1: 2, c0: 3, c1: 5 }
  };
  var TYPES = ['K', 'A', 'E', 'R', 'H', 'C', 'P'];
  var NAME = {
    K: { r: '帅', b: '将' }, A: { r: '仕', b: '士' }, E: { r: '相', b: '象' },
    R: { r: '车', b: '车' }, H: { r: '马', b: '马' }, C: { r: '炮', b: '炮' },
    P: { r: '兵', b: '卒' }
  };
  // 海外版：棋子面**仍只画汉字**（国风视觉的锚点，不被文字撑大）；
  // 英文名不常驻盘面，改为**长按棋子**时由 ui.js 取这张表弹出说明。
  // 采用国际通行的象棋译名。
  var NAME_EN = {
    K: 'General', A: 'Advisor', E: 'Elephant', R: 'Chariot',
    H: 'Horse', C: 'Cannon', P: 'Soldier'
  };
  // 每方 16 枚：1 将/帅 + 2 仕 + 2 相 + 2 车 + 2 马 + 2 炮 + 5 兵
  var SIDE_PIECES = ['K', 'A', 'A', 'E', 'E', 'R', 'R', 'H', 'H', 'C', 'C', 'P', 'P', 'P', 'P', 'P'];
  var VALUE = { K: 1000, R: 9, C: 4.5, H: 4, A: 2, E: 2, P: 1 };

  function inBoard(r, c) { return r >= 0 && r < ROWS && c >= 0 && c < COLS; }
  function opp(s) { return s === RED ? BLACK : RED; }
  function name(p) { return NAME[p.t][p.s]; }
  function inPalace(side, r, c) {
    var p = PALACE[side];
    return r >= p.r0 && r <= p.r1 && c >= p.c0 && c <= p.c1;
  }
  // 该行是否属于 side 的半场
  function ownsHalf(side, r) { return side === RED ? r >= 5 : r <= 4; }

  /* ---------------- 布局 ---------------- */

  function shuffle(arr, rand) {
    for (var i = arr.length - 1; i > 0; i--) {
      var j = Math.floor(rand() * (i + 1));
      var t = arr[i]; arr[i] = arr[j]; arr[j] = t;
    }
    return arr;
  }

  // 中国象棋的标准开局点位（每方 16 个）
  //   红方：底线 9 点（r9,c0-8）+ 炮位 2 点（r7,c1/c7）+ 兵位 5 点（r6,c0/2/4/6/8）
  //   黑方：底线 9 点（r0,c0-8）+ 炮位 2 点（r2,c1/c7）+ 卒位 5 点（r3,c0/2/4/6/8）
  var HOME = {
    r: [[9, 0], [9, 1], [9, 2], [9, 3], [9, 4], [9, 5], [9, 6], [9, 7], [9, 8],
        [7, 1], [7, 7],
        [6, 0], [6, 2], [6, 4], [6, 6], [6, 8]],
    b: [[0, 0], [0, 1], [0, 2], [0, 3], [0, 4], [0, 5], [0, 6], [0, 7], [0, 8],
        [2, 1], [2, 7],
        [3, 0], [3, 2], [3, 4], [3, 6], [3, 8]]
  };
  // 将/帅的固定位置：各自底线正中，正面朝上
  var KING_HOME = { r: [9, 4], b: [0, 4] };

  // 「这个点位在中国象棋开局时站着的是什么棋子」—— 暗棋就按它走。
  // 暗棋一移动就必须翻开，所以它永远只在标准点位上站过，这张表永远有定义。
  var HOME_TYPE = {};
  (function () {
    var BACK = ['R', 'H', 'E', 'A', 'K', 'A', 'E', 'H', 'R'];   // 底线的九枚
    [RED, BLACK].forEach(function (side) {
      var backRow = side === RED ? 9 : 0, cannonRow = side === RED ? 7 : 2;
      HOME[side].forEach(function (p) {
        HOME_TYPE[p[0] + ',' + p[1]] =
          p[0] === backRow ? BACK[p[1]] : (p[0] === cannonRow ? 'C' : 'P');
      });
    });
  })();
  // 取某点位对应的「标准棋子」类型；不是标准点位则返回 null
  function homeType(r, c) { return HOME_TYPE[r + ',' + c] || null; }

  // 标准 32 点里去掉被将帅占掉的 2 点 —— 剩下 30 个「暗棋点位」
  function openSpots() {
    var out = [];
    [RED, BLACK].forEach(function (side) {
      var kh = KING_HOME[side];
      HOME[side].forEach(function (p) {
        if (p[0] === kh[0] && p[1] === kh[1]) return;
        out.push(p);
      });
    });
    return out;                                  // 长度恒为 30
  }

  // 30 枚暗棋：红黑各 15 枚（不含将帅）
  function darkPool() {
    var pool = [];
    [RED, BLACK].forEach(function (side) {
      SIDE_PIECES.slice(1).forEach(function (t) { pool.push({ s: side, t: t }); });
    });
    return pool;                                 // 长度恒为 30
  }

  function newGame(rand) {
    rand = rand || Math.random;
    var board = [];
    for (var r = 0; r < ROWS; r++) {
      board.push([]);
      for (var c = 0; c < COLS; c++) board[r].push(null);
    }
    // 1) 将帅明牌，固定摆在各自主场的底线正中
    board[KING_HOME.r[0]][KING_HOME.r[1]] = { s: RED, t: 'K', up: 1 };
    board[KING_HOME.b[0]][KING_HOME.b[1]] = { s: BLACK, t: 'K', up: 1 };
    // 2) 30 枚暗棋混合洗牌，铺满其余 30 个标准点位（归属同样不确定）
    var pool = shuffle(darkPool(), rand);
    var spots = shuffle(openSpots(), rand);
    for (var i = 0; i < pool.length; i++)
      board[spots[i][0]][spots[i][1]] = { s: pool[i].s, t: pool[i].t, up: 0 };
    return {
      board: board,
      // 先手随机：双方情报完全对称，红先并不构成优势
      turn: rand() < 0.5 ? RED : BLACK,
      first: null,
      quiet: 0,            // 连续「无吃子且无翻牌」的半步数，用于判和
      captured: { r: [], b: [] }, // 被吃掉的棋子（含明暗状态）
      last: null,          // 最近一步，用于 UI 高亮
      over: false,
      winner: null,        // RED / BLACK / 'draw'
      reason: null         // 'king' | 'stuck' | 'draw'
    };
  }

  /* ---------------- 目标格判定（规则 5） ---------------- */

  // 吃子判定。原则：**只依赖公开信息**（棋盘、谁在走、点位的标准归属），
  // 绝不使用暗棋的真实归属 p.s —— 否则玩家能从「能不能吃」反推出这枚暗子是谁的，
  // 破坏「归属不公开」这条支点规则。
  // 明棋与暗棋用**同一套**判敌我标准：
  //   · 目标是明棋：只能吃**移动方的对手**（明棋的归属本来就是公开的）
  //   · 目标是暗棋：只能吃**位于对方半场**的暗棋（那一格的标准棋子本就属于对方）
  //     → 所以明棋也**吃不了自家阵地里的暗棋**，哪怕那枚暗子的真实归属是对方。
  //       「自残」仍然存在，但它只会发生在**对方半场**：明棋推进过去，吃到了自家埋在敌阵里的子。
  function canLand(p, target, mover, tr, tc) {
    if (!target) return true;                                   // 空格
    if (target.up) return target.s !== mover;                   // 目标是明棋：只能吃对手的
    return !ownsHalf(mover, tr);                                // 目标是暗棋：只能吃对方半场的
  }

  /* ---------------- 走法生成 ---------------- */

  // 走法生成。
  //   明棋：按它**真实的身份**走（规则 6）。
  //   暗棋：按**它所在点位对应的标准象棋棋子**走（规则 3）—— 位置是公开的，
  //         所以「选中暗棋看落点」不泄露任何情报。暗棋一移动就必须翻开，
  //         因此它永远只站在标准点位上，homeType 永远取得到值。
  function legalMoves(state, r, c) {
    var board = state.board, p = board[r][c], out = [];
    if (!p) return out;
    var mover = state.turn;   // 吃子判敌我的基准是「谁在走」，不是暗棋的真实归属
    function push(tr, tc) {
      if (inBoard(tr, tc) && canLand(p, board[tr][tc], mover, tr, tc)) out.push({ r: tr, c: tc });
    }
    var mt = p.up ? p.t : (homeType(r, c) || p.t);   // 走法依据的类型
    // 兵/卒的朝向：明棋看归属（它可能已经杀到对方半场），暗棋看它所在的半场
    var forward = (p.up ? p.s === RED : r >= 5) ? -1 : 1;
    var i, dr, dc, tr, tc, t;
    switch (mt) {
      case 'R': // 车：直线，路径须为空
        for (i = 0; i < DIRS4.length; i++) {
          dr = DIRS4[i][0]; dc = DIRS4[i][1];
          tr = r + dr; tc = c + dc;
          while (inBoard(tr, tc)) {
            t = board[tr][tc];
            if (!t) out.push({ r: tr, c: tc });
            else { if (canLand(p, t, mover, tr, tc)) out.push({ r: tr, c: tc }); break; }
            tr += dr; tc += dc;
          }
        }
        break;
      case 'C': // 炮：不吃子时走法同车；吃子须恰隔一个「炮架」
        // 炮架**明暗皆可**（暗子也是棋盘上的实体），目标也可以是对方的**将/帅**。
        // 注意：放开这两条后，红炮只要落在 (6,4)（红方兵位），就能隔着必定存在的
        // (3,4) 一步打死 (0,4) 的黑将 —— 实测约 3.3% 的对局开局第一手即终局。见方案 §2.9。
        for (i = 0; i < DIRS4.length; i++) {
          dr = DIRS4[i][0]; dc = DIRS4[i][1];
          tr = r + dr; tc = c + dc;
          var jumped = false;
          while (inBoard(tr, tc)) {
            t = board[tr][tc];
            if (!jumped) {
              if (!t) out.push({ r: tr, c: tc });
              else jumped = true;                // 明子暗子都能当架
            } else if (t) {
              if (canLand(p, t, mover, tr, tc)) out.push({ r: tr, c: tc });
              break;
            }
            tr += dr; tc += dc;
          }
        }
        break;
      case 'H': // 马：走日，马腿有子（明暗皆算）则蹩
        for (i = 0; i < HORSE.length; i++) {
          dr = HORSE[i][0]; dc = HORSE[i][1];
          var lr = r + HORSE[i][2], lc = c + HORSE[i][3];
          if (!inBoard(lr, lc) || board[lr][lc]) continue;
          push(r + dr, c + dc);
        }
        break;
      case 'E': // 相/象：走田，塞象眼；规则 8 特权：不受区域限制，可过河
        for (i = 0; i < DIAG2.length; i++) {
          dr = DIAG2[i][0]; dc = DIAG2[i][1];
          tr = r + dr; tc = c + dc;
          if (!inBoard(tr, tc)) continue;
          if (board[r + dr / 2][c + dc / 2]) continue;
          push(tr, tc);
        }
        break;
      case 'A': // 仕/士：斜一步；规则 8 特权：不受区域限制，可过河
        for (i = 0; i < DIAG1.length; i++) push(r + DIAG1[i][0], c + DIAG1[i][1]);
        break;
      case 'K': // 帅/将（规则 7）：直线一步，且必须落在己方九宫内
        for (i = 0; i < DIRS4.length; i++) {
          tr = r + DIRS4[i][0]; tc = c + DIRS4[i][1];
          if (!inPalace(p.s, tr, tc)) continue;
          push(tr, tc);
        }
        break;
      case 'P': // 兵/卒（规则 9）：未过河只能向前一步，过河后可左右平移，永不后退
        push(r + forward, c);
        // 过河按**实际所在行**判定（红兵 r<=4、黑卒 r>=5）。
        // 暗棋只可能站在己方兵/卒位上，所以暗着的兵/卒必定尚未过河。
        var crossed = forward === -1 ? r <= 4 : r >= 5;
        if (crossed) { push(r, c - 1); push(r, c + 1); }
        break;
    }
    return out;
  }

  // 规则 1：只能翻开「己方半场」的暗棋，严禁碰对方半场
  function flippable(state, side) {
    side = side || state.turn;
    var out = [];
    for (var r = 0; r < ROWS; r++) {
      if (!ownsHalf(side, r)) continue;
      for (var c = 0; c < COLS; c++) {
        var p = state.board[r][c];
        if (p && !p.up) out.push({ r: r, c: c });
      }
    }
    return out;
  }

  // 这枚棋子能不能被 side 操作？
  //   明棋：只有自己的能动（归属本来就是公开信息）
  //   暗棋：只看**点位**（是否落在己方半场），绝不看它的真实归属 ——
  //         否则「能不能操作」会反过来泄露这枚暗子是谁的，也会和玩家侧的交互不对等。
  function canPick(state, r, c, side) {
    var p = state.board[r][c];
    if (!p) return false;
    if (p.up) return p.s === side;
    return ownsHalf(side, r);
  }

  // 某方全部合法行动。
  //   ⚠️ 本作**没有「原地翻开」这个动作**：暗棋必须走一步，走完自动翻开（规则 4）。
  //      所以己方半场里的某枚暗子若被彻底堵死、一步都走不了，它就永远翻不开，
  //      会变成一堵永久的墙 —— 这是本规则已知且被接受的代价。
  function allActions(state, side) {
    side = side || state.turn;
    var acts = [];
    for (var r = 0; r < ROWS; r++)
      for (var c = 0; c < COLS; c++) {
        if (!canPick(state, r, c, side)) continue;
        var ms = legalMoves(state, r, c);
        for (var k = 0; k < ms.length; k++)
          acts.push({ kind: 'move', from: [r, c], to: [ms[k].r, ms[k].c] });
      }
    return acts;
  }

  /* ---------------- 执行一步 ---------------- */

  function cloneBoard(board) {
    var out = [];
    for (var r = 0; r < ROWS; r++) {
      out.push([]);
      for (var c = 0; c < COLS; c++) {
        var p = board[r][c];
        out[r].push(p ? { s: p.s, t: p.t, up: p.up } : null);
      }
    }
    return out;
  }

  function clone(state) {
    return {
      board: cloneBoard(state.board),
      turn: state.turn,
      first: state.first,
      quiet: state.quiet,
      captured: { r: state.captured.r.slice(), b: state.captured.b.slice() },
      last: state.last,
      over: state.over,
      winner: state.winner,
      reason: state.reason
    };
  }

  // 返回新状态；不改动传入的 state
  function apply(state, a) {
    var s = clone(state);
    var moved = null, revealed = false;
    if (a.kind === 'flip') {
      s.board[a.r][a.c].up = 1;
      revealed = true;
      s.last = { kind: 'flip', to: [a.r, a.c], side: state.turn,
                 side2: s.board[a.r][a.c].s, type2: s.board[a.r][a.c].t, own: s.board[a.r][a.c].s === state.turn };
    } else {
      var fr = a.from[0], fc = a.from[1], tr = a.to[0], tc = a.to[1];
      moved = s.board[fr][fc];
      var cap = s.board[tr][tc];
      s.board[tr][tc] = moved;
      s.board[fr][fc] = null;
      if (cap) s.captured[cap.s].push({ t: cap.t, up: cap.up });
      // 规则 4：暗棋每走一步后，必须立即翻开、亮明身份
      if (!moved.up) { moved.up = 1; revealed = true; }
      s.last = { kind: 'move', from: [fr, fc], to: [tr, tc], side: state.turn,
                 cap: cap ? cap.t : null, capSide: cap ? cap.s : null,
                 capWasDark: cap ? cap.up === 0 : false, revealed: revealed };
      if (cap && cap.t === 'K') {
        s.over = true; s.winner = moved.s; s.reason = 'king';
        s.turn = opp(state.turn);
        return s;
      }
    }
    // 和棋计时：只有「吃子」或「有棋子翻面」才算有进展
    s.quiet = revealed ? 0 : state.quiet + 1;
    s.turn = opp(state.turn);
    // 终局判定：困毙（无任何合法行动）→ 该方负；双方各 60 手无进展 → 和
    if (allActions(s, s.turn).length === 0) {
      s.over = true; s.winner = opp(s.turn); s.reason = 'stuck';
    } else if (s.quiet >= 120) {
      s.over = true; s.winner = 'draw'; s.reason = 'draw';
    }
    return s;
  }

  function findKing(board, side) {
    for (var r = 0; r < ROWS; r++)
      for (var c = 0; c < COLS; c++) {
        var p = board[r][c];
        if (p && p.s === side && p.t === 'K') return { r: r, c: c };
      }
    return null;
  }

  // 统计某方的暗棋（按真实归属，UI 请改用 countHiddenInHalf）
  function countHidden(board, side) {
    var n = 0;
    for (var r = 0; r < ROWS; r++)
      for (var c = 0; c < COLS; c++) {
        var p = board[r][c];
        if (p && !p.up && p.s === side) n++;
      }
    return n;
  }

  // 统计「某方半场上还剩多少枚暗棋」—— 这是玩家真正能翻的范围
  function countHiddenInHalf(board, side) {
    var n = 0;
    for (var r = 0; r < ROWS; r++) {
      if (!ownsHalf(side, r)) continue;
      for (var c = 0; c < COLS; c++) if (board[r][c] && !board[r][c].up) n++;
    }
    return n;
  }

  /* ---------------- 简易 AI ---------------- */

  // 己方将/帅在「一步之内」被对方明棋瞄准的总威胁
  // 只算明棋：暗棋的身份双方都看不见，AI 不该拿它当已知情报
  function kingDanger(state, side) {
    var k = findKing(state.board, side);
    if (!k) return 0;
    var danger = 0;
    for (var r = 0; r < ROWS; r++)
      for (var c = 0; c < COLS; c++) {
        var p = state.board[r][c];
        if (!p || !p.up || p.s === side) continue;
        var ms = legalMoves(state, r, c);
        for (var i = 0; i < ms.length; i++)
          if (ms[i].r === k.r && ms[i].c === k.c) { danger += VALUE[p.t] * 0.7; break; }
      }
    return danger;
  }

  // 「推进度」：己方明棋离对方将/帅越近，越有形成实际威胁的可能。
  // 斩首必须先把棋子压到九宫附近，没有这一项 AI 会一直原地倒子（取消原地翻开后尤其明显）。
  function advance(state, side) {
    var kOpp = findKing(state.board, opp(side));
    if (!kOpp) return 0;
    var sum = 0;
    for (var r = 0; r < ROWS; r++)
      for (var c = 0; c < COLS; c++) {
        var p = state.board[r][c];
        if (!p || !p.up || p.s !== side || p.t === 'K') continue;
        var dist = Math.abs(r - kOpp.r) + Math.abs(c - kOpp.c);
        sum += (18 - Math.min(dist, 18)) * 0.18;   // 权重实测：0.06 时和棋 87%，0.18 时降到 39%
      }
    return sum;
  }

  // 暗棋是红黑混装、归属未知，对双方的期望贡献相抵，因此只评估明棋
  function evaluate(state, side) {
    var score = 0;
    for (var r = 0; r < ROWS; r++)
      for (var c = 0; c < COLS; c++) {
        var p = state.board[r][c];
        if (!p || !p.up) continue;
        var v = VALUE[p.t];
        if (p.t === 'P' && (p.s === RED ? r <= 4 : r >= 5)) v = 2.2;
        score += (p.s === side ? v : -v);
      }
    // 老将的安全：被对方明棋瞄准要扣分，瞄准对方要加分
    score -= kingDanger(state, side);
    score += kingDanger(state, opp(side));
    // 推进度：把子力往对方九宫压
    score += advance(state, side) - advance(state, opp(side));
    return score;
  }

  function actionScore(state, a, side) {
    var next = apply(state, a);
    var mover = a.kind === 'move' ? state.board[a.from[0]][a.from[1]] : null;
    var blind = !!(mover && !mover.up);           // 这一步是「盲走暗棋」
    // 盲走时不让 AI 偷看翻出来的身份：把目标格的棋子按「仍然扣着」来估值
    // （暗棋对双方的期望价值相抵），否则 AI 会用人类不可能拥有的情报挑最优的那枚
    if (blind) next.board[a.to[0]][a.to[1]].up = 0;
    var sc = evaluate(next, side) - evaluate(state, side);
    if (a.kind === 'move') {
      var t = state.board[a.to[0]][a.to[1]];
      if (t && t.t === 'K' && t.s !== side) return 1e6;
      if (t) {
        if (!t.up) sc += VALUE[t.t] * 0.5 + 1;          // 吃暗棋：一半概率是对方的，也是探路
        else if (t.s !== side) sc += VALUE[t.t] * 0.6 + 1.5;
        else sc -= VALUE[t.t] * 0.8;                     // 自残
      }
      // 盲走暗棋的代价：走完即暴露，还可能替对手推了一步。
      // 但不能罚太重 —— 取消「原地翻开」之后，「推暗子」是**唯一**的揭面手段，
      // 罚狠了 AI 就会一直倒明子、把局面拖成 90% 和棋。推出去也算拿到情报，所以只留一点点代价。
      if (blind) sc -= 0.15;
    }
    return sc;
  }

  function aiChoose(state, side, rand, level) {
    rand = rand || Math.random;
    level = level || 2;
    var acts = allActions(state, side);
    if (!acts.length) return null;
    if (level <= 1) {
      // 入门：能杀就杀，否则随机
      for (var i = 0; i < acts.length; i++) {
        var a = acts[i];
        if (a.kind === 'move') {
          var t = state.board[a.to[0]][a.to[1]];
          if (t && t.t === 'K' && t.s !== side) return a;
        }
      }
      return acts[Math.floor(rand() * acts.length)];
    }
    var best = null, bestSc = -Infinity;
    for (var j = 0; j < acts.length; j++) {
      var sc = actionScore(state, acts[j], side);
      if (level >= 3 && acts[j].kind === 'move') {
        // 困难：再看对手最佳反击一手
        var nx = apply(state, acts[j]);
        if (!nx.over) {
          var reps = allActions(nx, nx.turn), worst = 0;
          for (var k = 0; k < reps.length; k++) {
            var rs = actionScore(nx, reps[k], nx.turn);
            if (rs > worst) worst = rs;
          }
          sc -= worst * 0.85;
        }
      }
      sc += rand() * 0.05;                 // 加入噪声，避免每局完全同解
      if (sc > bestSc) { bestSc = sc; best = acts[j]; }
    }
    return best;
  }

  var api = {
    COLS: COLS, ROWS: ROWS, RED: RED, BLACK: BLACK,
    PALACE: PALACE, HOME: HOME, KING_HOME: KING_HOME, HOME_TYPE: HOME_TYPE, homeType: homeType,
    TYPES: TYPES, NAME: NAME, NAME_EN: NAME_EN, VALUE: VALUE,
    newGame: newGame, legalMoves: legalMoves, flippable: flippable,
    allActions: allActions, apply: apply, clone: clone, canLand: canLand, canPick: canPick,
    findKing: findKing, countHidden: countHidden, countHiddenInHalf: countHiddenInHalf,
    evaluate: evaluate, aiChoose: aiChoose, name: name,
    inPalace: inPalace, ownsHalf: ownsHalf, openSpots: openSpots, darkPool: darkPool
  };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  global.DarkChess = api;
})(typeof globalThis !== 'undefined' ? globalThis : this);
