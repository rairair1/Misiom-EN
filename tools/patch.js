// Parse-only English patcher for the O HUB renderer bundle (no bundle code is executed).
// Usage:
//   node patch.js report <assetsDir> <dict.json>            -> prints strings missing from dict
//   node patch.js apply  <assetsDir> <dict.json> <outDir>   -> writes patched chunks to outDir
// dict.json maps trimmed Chinese text -> English. Leading/trailing whitespace is preserved.
const T = '';
const fs = require('fs'), path = require('path');
const parser = require(T + '@babel/parser');
const traverse = require(T + '@babel/traverse').default;
const t = require(T + '@babel/types');
const HAN = /[㐀-鿿]/;
const [mode, dir, dictFile, outDir] = process.argv.slice(2);
const dict = JSON.parse(fs.readFileSync(dictFile, 'utf8'));

const DATA_KEYS = new Set(['name', 'value', 'key', 'preset', 'type', 'id', 'command', 'editType']);
const keyName = p => t.isIdentifier(p.key) ? p.key.name : t.isStringLiteral(p.key) ? p.key.value : null;

function isLibLocale(n) {
  if (!t.isObjectExpression(n)) return false;
  return n.properties.some(p => t.isObjectProperty(p) && (
    ((keyName(p) === 'name' || keyName(p) === 'code') && t.isStringLiteral(p.value) && /^zh-(CN|TW)$/.test(p.value.value)) ||
    ['lessThanXSeconds', 'lastWeek', 'abbreviated'].includes(keyName(p)) ||
    (keyName(p) === 'toolbox' && n.properties.some(q => keyName(q) === 'aria'))));
}
function skipReason(p) {
  const parent = p.parentPath;
  if (parent.isObjectProperty() && parent.node.key === p.node) return 'key';
  if (parent.isObjectProperty() && DATA_KEYS.has(keyName(parent.node))) return 'data';
  if (parent.isBinaryExpression() && /^[!=]==?$/.test(parent.node.operator)) return 'compare';
  if (parent.isSwitchCase()) return 'compare';
  if (t.isStringLiteral(p.node) && p.node.value.startsWith('legacy.')) return 'i18nKey';
  for (let q = p; q; q = q.parentPath) {
    const n = q.node;
    if (t.isCallExpression(n) && t.isMemberExpression(n.callee) && t.isIdentifier(n.callee.object, { name: 'console' })) return 'console';
    if (t.isCallExpression(n) && commentFns.has(calleeName(n))) return 'comment';
    if (isLibLocale(n)) return 'lib';
    if (t.isVariableDeclarator(n) && t.isIdentifier(n.id, { name: 'VC' })) return 'vc';
    if (t.isObjectProperty(n) && /^zh-(CN|TW)$/.test(keyName(n) || '')) return 'zhTable';
    if (t.isFunctionDeclaration(n) && n.body.body.length < 4 && /'(下个|上个|上個|下個)'/.test(JSON.stringify(n.body).slice(0, 2000))) return 'lib';
    if (t.isCallExpression(n) && t.isFunctionExpression(n.callee) === false && t.isArrowFunctionExpression(n.callee) === false) {
      // echarts China map patch: "china"===t&&"台湾"===e.name  -> handled by 'compare'
    }
  }
  return null;
}
const calleeName = n => t.isIdentifier(n.callee) ? n.callee.name : null;
let commentFns = new Set();

function translate(raw) {
  const lead = raw.match(/^\s*/)[0], trail = raw.slice(lead.length).match(/\s*$/)[0];
  const core = raw.slice(lead.length, raw.length - trail.length);
  if (!HAN.test(core)) return raw;
  if (!(core in dict)) return null;
  return lead + dict[core] + trail;
}

const missing = new Map();
const files = fs.readdirSync(dir).filter(f => f.endsWith('.js'));
for (const f of files) {
  const src = fs.readFileSync(path.join(dir, f), 'utf8');
  if (!HAN.test(src)) { if (mode === 'apply') fs.copyFileSync(path.join(dir, f), path.join(outDir, f)); continue; }
  const ast = parser.parse(src, { sourceType: 'module' });
  // comment-vnode helpers: callees whose single string arg is a "------" banner or an HTML fragment
  commentFns = new Set();
  traverse(ast, { CallExpression(p) {
    const a = p.node.arguments;
    if (a.length === 1 && t.isStringLiteral(a[0]) && /^-{6,}|^\s*<\/?[a-zA-Z]/.test(a[0].value) && calleeName(p.node)) commentFns.add(calleeName(p.node));
  } });
  const edits = [];
  traverse(ast, {
    StringLiteral(p) {
      if (!HAN.test(p.node.value) || skipReason(p)) return;
      const tr = translate(p.node.value);
      if (tr === null) { missing.set(p.node.value.trim(), f); return; }
      edits.push([p.node.start, p.node.end, JSON.stringify(tr)]);
    },
    TemplateElement(p) {
      const raw = p.node.value.raw;
      if (!HAN.test(raw) || skipReason(p.parentPath)) return;
      const tr = translate(raw);
      if (tr === null) { missing.set(raw.trim(), f + ' (template part)'); return; }
      edits.push([p.node.start, p.node.end, tr.replace(/`/g, '\\`').replace(/\$\{/g, '\\${')]);
    }
  });
  if (mode === 'apply') {
    let out = src;
    edits.sort((a, b) => b[0] - a[0]).forEach(([s, e, r]) => { out = out.slice(0, s) + r + out.slice(e); });
    fs.writeFileSync(path.join(outDir, f), out);
    console.log(`${f}: ${edits.length} replacements`);
  }
}
if (missing.size) { console.log(`MISSING ${missing.size}:`); for (const [k, f] of missing) console.log(JSON.stringify(k), '\t', f); }
else console.log('dictionary covers every translatable string');
