// Testy řešiče rozmístění kusů na trubky. Spuštění: node --test "kalkulacka-trubek/test/*.test.js"
// Řešič je přímo v index.html, test si ho z něj vyřízne a spustí.
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const html = fs.readFileSync(path.join(__dirname, "..", "index.html"), "utf8");
const a = html.indexOf("/* ---------- Solver");
const b = html.indexOf("/* ---------- Render");
assert.ok(a > 0 && b > a, "v index.html se nenašel blok s řešičem");
const solve = new Function(html.slice(a, b) + "\nreturn solve;")();

const STOCK = 6000, KERF = 3;
const demand = (...pairs) => pairs.map(([len, qty]) => ({ len, qty }));
const bars = (...pairs) => solve(STOCK, KERF, demand(...pairs)).bars.length;

test("jeden kus na délku trubky vyjde na jednu trubku", () => {
  assert.equal(bars([6000, 1]), 1);
});

test("tři kusy po 2000 mm se kvůli prořezu nevejdou na jednu trubku", () => {
  assert.equal(bars([2000, 3]), 2);
});

test("šest kusů po 1000 mm jsou dvě trubky", () => {
  assert.equal(bars([1000, 6]), 2);
});

test("příklad z kalkulačky: 10×3740, 12×2465, 23×860 je 16 trubek", () => {
  assert.equal(bars([3740, 10], [2465, 12], [860, 23]), 16);
});

test("velké kusy s drobným doplňkem: 3×5990 a 1×3 jsou tři trubky", () => {
  assert.equal(bars([5990, 3], [3, 1]), 3);
});

// jednoduchý generátor, aby byly náhodné testy opakovatelné
function rng(seed) {
  let s = seed >>> 0;
  return () => { s = (Math.imul(s, 1664525) + 1013904223) >>> 0; return s / 4294967296; };
}

function randomDemand(rnd) {
  const types = 1 + Math.floor(rnd() * 5);
  const d = [];
  for (let i = 0; i < types; i++) d.push({ len: 20 + Math.floor(rnd() * 5980), qty: 1 + Math.floor(rnd() * 8) });
  return Object.values(Object.fromEntries(d.map((x) => [x.len, x]))); // bez duplicitních délek
}

test("každý kus je umístěn právě jednou a trubka není přeplněná", () => {
  const rnd = rng(12345);
  for (let n = 0; n < 150; n++) {
    const d = randomDemand(rnd);
    const res = solve(STOCK, KERF, d);
    const placed = {};
    res.bars.forEach((bar) => {
      bar.pieces.forEach((l) => { placed[l] = (placed[l] || 0) + 1; });
      const used = bar.pieces.reduce((s, l) => s + l, 0) + (bar.pieces.length - 1) * KERF;
      assert.ok(used <= STOCK + 1e-6, "trubka je přeplněná: " + JSON.stringify(bar));
      const leftover = Math.round((STOCK - used) * 10) / 10;
      const endCut = leftover > 0;
      assert.equal(bar.endCut, endCut, "chybně určený řez před zbytkem");
      assert.ok(Math.abs(bar.rest - Math.max(0, Math.round((leftover - (endCut ? KERF : 0)) * 10) / 10)) < 1e-6, "chybný odřezek");
    });
    d.forEach(({ len, qty }) => assert.equal(placed[len] || 0, qty, "počet kusů " + len + " mm nesedí"));
    assert.ok(res.bars.length >= res.lower, "méně trubek než dolní mez");
  }
});

// přesné minimum pro malá zadání (dynamické programování přes podmnožiny)
function bruteForce(d) {
  const items = [];
  d.forEach(({ len, qty }) => { for (let i = 0; i < qty; i++) items.push(len + KERF); });
  const n = items.length, cap = STOCK + KERF, full = (1 << n) - 1;
  const sum = new Array(1 << n).fill(0);
  for (let m = 1; m <= full; m++) { const low = m & -m; sum[m] = sum[m ^ low] + items[31 - Math.clz32(low)]; }
  const dp = new Array(1 << n).fill(Infinity); dp[0] = 0;
  for (let m = 1; m <= full; m++) {
    const first = m & -m;
    for (let s = m; s; s = (s - 1) & m) if ((s & first) && sum[s] <= cap) dp[m] = Math.min(dp[m], dp[m ^ s] + 1);
  }
  return dp[full];
}

test("u malých zadání řešič najde skutečné minimum trubek", () => {
  const rnd = rng(777);
  let checked = 0;
  while (checked < 120) {
    const d = randomDemand(rnd);
    if (d.reduce((s, x) => s + x.qty, 0) > 9) continue;
    assert.equal(solve(STOCK, KERF, d).bars.length, bruteForce(d), "není optimální: " + JSON.stringify(d));
    checked++;
  }
});

test("výsledek se tvrdí jako ověřený jen tehdy, když sedí s dolní mezí nebo přesným hledáním", () => {
  const rnd = rng(99);
  for (let n = 0; n < 80; n++) {
    const d = randomDemand(rnd);
    if (d.reduce((s, x) => s + x.qty, 0) > 9) continue;
    const res = solve(STOCK, KERF, d);
    if (res.proven) assert.equal(res.bars.length, bruteForce(d), "ověřeno, ale není optimální: " + JSON.stringify(d));
  }
});
