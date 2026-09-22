/*
 * opening-baseline.js — 跨端对拍脚本（engine.js 侧）
 *
 * 与 swift-verify/main.swift 使用**同一个 Park-Miller RNG**，各自摆一局，
 * 输出 90 格棋盘 + 关键统计，逐行 diff 即可确认 Swift 移植没有走样。
 *
 * 用法：
 *   jsc docs/dark-chess/swift-verify/opening-baseline.js > /tmp/js.txt
 *   （Swift 侧见 main.swift 顶部注释，输出 /tmp/swift.txt，然后 diff）
 */
var E = require(__dirname + '/../engine.js');
var seed = 12345;
function rnd() { seed = (seed * 16807) % 2147483647; return seed / 2147483647; }
var s = E.newGame(rnd);
var cells = [];
for (var r = 0; r < 10; r++) for (var c = 0; c < 9; c++) {
  var p = s.board[r][c];
  cells.push(p ? (p.t + p.s + (p.up ? '1' : '0')) : '...');
}
var pieces = 0, hidden = 0, kk = 0;
for (var r = 0; r < 10; r++) for (var c = 0; c < 9; c++) {
  var p = s.board[r][c]; if (!p) continue;
  pieces++; if (!p.up) hidden++;
  if (p.t === 'K' && p.up) kk++;
}
var bt = {};
Object.keys(E.HOME_TYPE).forEach(function (k) { var t = E.HOME_TYPE[k]; bt[t] = (bt[t] || 0) + 1; });
var td = ['K','A','E','R','H','C','P'].map(function (t) { return t + '=' + (bt[t] || 0); }).join(' ');
var kr = E.findKing(s.board, 'r'), kb = E.findKing(s.board, 'b');
console.log('pieces=' + pieces + ' hidden=' + hidden + ' faceUpKings=' + kk);
console.log('redK=' + kr.r + ',' + kr.c + ' blackK=' + kb.r + ',' + kb.c);
console.log('homeType ' + td + ' total=' + Object.keys(E.HOME_TYPE).length);
console.log('openSpots=' + E.openSpots().length + ' darkPool=' + E.darkPool().length + ' turn=' + s.turn);
console.log('board=' + cells.join(','));
console.log('legalMoves=' + E.allActions(s, s.turn).length);
