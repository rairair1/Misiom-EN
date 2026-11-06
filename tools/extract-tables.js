// Read the app's built-in "legacy" translation tables (VC = { "zh-CN": {...}, "zh-TW": {...}, "en-US": {...} })
// out of the main renderer chunk. Parse-only: literals are read from the syntax tree, nothing is executed.
// Usage: node extract-tables.js <assetsDir> <out.json>
const fs = require('fs'), path = require('path');
const parser = require('@babel/parser');
const traverse = require('@babel/traverse').default;
const t = require('@babel/types');
const [dir, out] = process.argv.slice(2);

const f = fs.readdirSync(dir).find(f => /^index-.*\.js$/.test(f) &&
  fs.readFileSync(path.join(dir, f), 'utf8').includes('const NC="zh-CN",VC='));
if (!f) throw new Error('main chunk with the VC table not found (different O HUB version?)');
const ast = parser.parse(fs.readFileSync(path.join(dir, f), 'utf8'), { sourceType: 'module' });

function literal(n) {
  if (t.isStringLiteral(n)) return n.value;
  if (t.isObjectExpression(n)) {
    const o = {};
    for (const p of n.properties) {
      if (!t.isObjectProperty(p) || p.computed) throw new Error('non-literal property in VC');
      o[t.isIdentifier(p.key) ? p.key.name : p.key.value] = literal(p.value);
    }
    return o;
  }
  throw new Error('non-literal value in VC: ' + n.type);
}
let VC;
traverse(ast, { VariableDeclarator(p) { if (t.isIdentifier(p.node.id, { name: 'VC' })) { VC = literal(p.node.init); p.stop(); } } });
fs.writeFileSync(out, JSON.stringify({ index: f, VC }, null, 1));
for (const [k, v] of Object.entries(VC)) console.log(k, Object.keys(v).length);
