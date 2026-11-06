// Parse-only inventory of Han-containing string literals / template quasis in renderer chunks.
// Usage: node inventory.js <assetsDir> <out.json>
// Skips: console.* arguments, locale tables of libraries (objects with name/code "zh-CN"/"zh-TW"),
// the app's own zh i18n tables (VC["zh-CN"/"zh-TW"], messages "zh-CN"/"zh-TW"), echarts ZH locale.
const T = '';
const fs = require('fs'), path = require('path');
const parser = require(T + '@babel/parser');
const traverse = require(T + '@babel/traverse').default;
const t = require(T + '@babel/types');
const HAN = /[㐀-鿿，：！？、。（）]/;
const [dir, out] = process.argv.slice(2);

function keyName(p) { return t.isIdentifier(p.key) ? p.key.name : t.isStringLiteral(p.key) ? p.key.value : null; }
function isSkippedObject(node) {
  if (!t.isObjectExpression(node)) return false;
  for (const p of node.properties) {
    if (!t.isObjectProperty(p)) continue;
    const k = keyName(p);
    if ((k === 'name' || k === 'code') && t.isStringLiteral(p.value) && /^zh-(CN|TW)$/.test(p.value.value)) return true;
    // echarts ZH locale: {time:{month:["一月",...]}, legend:..., toolbox:..., series:{typeNames:...}, aria:...}
    if (k === 'toolbox' && node.properties.some(q => keyName(q) === 'aria')) return true;
  }
  return false;
}
function skipped(path) {
  let p = path;
  while (p) {
    const n = p.node;
    if (t.isCallExpression(n) && t.isMemberExpression(n.callee) && t.isIdentifier(n.callee.object, { name: 'console' })) return 'console';
    if (isSkippedObject(n)) return 'libLocale';
    if (t.isObjectProperty(n) && /^zh-(CN|TW)$/.test(keyName(n) || '')) return 'zhTable';
    if (t.isVariableDeclarator(n) && t.isIdentifier(n.id, { name: 'VC' })) return 'vc';
    if (t.isObjectExpression(n) && n.properties.some(q => ['lessThanXSeconds','lastWeek','abbreviated'].includes(keyName(q)))) return 'dateFns';
    if (t.isFunctionDeclaration(n) && /'(下个|上个|上個|下個)'/.test(p.toString?.().slice(0,300)||'')) return 'dateFns';
    p = p.parentPath;
  }
  return null;
}
const result = {};
for (const f of fs.readdirSync(dir).filter(f => f.endsWith('.js'))) {
  const src = fs.readFileSync(path.join(dir, f), 'utf8');
  if (!HAN.test(src)) continue;
  const ast = parser.parse(src, { sourceType: 'module' });
  const items = [];
  traverse(ast, {
    StringLiteral(p) { if (p.parentPath.isObjectProperty() && p.parentPath.node.key === p.node) return; if (HAN.test(p.node.value) && !skipped(p)) items.push({ kind: 'str', v: p.node.value }); },
    TemplateLiteral(p) {
      if (!p.node.quasis.some(q => HAN.test(q.value.cooked ?? q.value.raw))) return;
      if (skipped(p)) return;
      items.push({ kind: 'tpl', v: src.slice(p.node.start, p.node.end) });
    },
    DirectiveLiteral(p) {}
  });
  if (items.length) result[f] = [...new Map(items.map(i => [i.kind + i.v, i])).values()];
}
fs.writeFileSync(out, JSON.stringify(result, null, 1));
let total = 0; for (const [f, v] of Object.entries(result)) { total += v.length; console.log(v.length, f); }
console.log('total', total);
