// Post-patch of the main renderer chunk (parse-only; nothing from the bundle is executed).
//  1. New installs start in English: user store default `language:NC` -> `language:"en-US"`.
//  2. Chinese UI keeps working: add English->Chinese entries to the zh-CN / zh-TW "legacy"
//     tables that the app's DOM translator uses, since source text is now English.
// Usage: node postpatch.js <patchedAssetsDir> <dict.json> <tables.json>
const T = '';
const fs = require('fs'), path = require('path');
const parser = require(T + '@babel/parser');
const traverse = require(T + '@babel/traverse').default;
const t = require(T + '@babel/types');
const [dir, dictFile, tablesFile] = process.argv.slice(2);
const dict = JSON.parse(fs.readFileSync(dictFile, 'utf8'));
const VC = JSON.parse(fs.readFileSync(tablesFile, 'utf8')).VC;
// Data values kept in Chinese (compared in code / sent to the server) that still appear as text.
const DISPLAY_ONLY = { '默认': 'Default', '设备连接': 'Device connection' };
// Exact one-off source fixes: [file regex, search, replace]. Each must match exactly once.
const FIXES = [
  // EQ band names under the chart: English words are wider, so ECharts auto-hid them. Show all.
  [/^adjust-.*\.js$/, 'axisLabel:{color:"#333",fontSize:13,align:"center",fontWeight:500}', 'axisLabel:{color:"#333",fontSize:13,align:"center",fontWeight:500,interval:0}'],
];
for (const [re, a, b] of FIXES) {
  const file = fs.readdirSync(dir).find(f => re.test(f));
  const s = fs.readFileSync(path.join(dir, file), 'utf8');
  if (s.split(a).length !== 2) throw new Error(`fix not unique in ${file}: ${a}`);
  fs.writeFileSync(path.join(dir, file), s.replace(a, b));
  console.log(`${file}: fix applied`);
}

const f = fs.readdirSync(dir).find(f => /^index-.*\.js$/.test(f) && fs.readFileSync(path.join(dir, f), 'utf8').includes('const NC="zh-CN",VC='));
let src = fs.readFileSync(path.join(dir, f), 'utf8');
const ast = parser.parse(src, { sourceType: 'module' });
const keyName = p => t.isIdentifier(p.key) ? p.key.name : t.isStringLiteral(p.key) ? p.key.value : null;
const edits = [];

traverse(ast, {
  // 1. default language in the persisted "user" store
  ObjectProperty(p) {
    if (keyName(p.node) === 'language' && t.isIdentifier(p.node.value, { name: 'NC' }) &&
        p.parentPath.node.properties.some(q => keyName(q) === 'closeOption')) {
      edits.push([p.node.value.start, p.node.value.end, '"en-US"', 'default language']);
    }
  },
  // 2. reverse entries in VC["zh-CN"] / VC["zh-TW"]
  VariableDeclarator(p) {
    if (!t.isIdentifier(p.node.id, { name: 'VC' }) || !t.isObjectExpression(p.node.init)) return;
    // Chinese strings that must stay Chinese in code (data values) but are shown on screen.
    const enProp = p.node.init.properties.find(q => keyName(q) === 'en-US');
    const enHave = new Set(enProp.value.properties.map(keyName));
    const enAdd = Object.entries(DISPLAY_ONLY).filter(([k]) => !enHave.has(k)).map(([k, v]) => `${JSON.stringify(k)}:${JSON.stringify(v)}`);
    edits.push([enProp.value.end - 1, enProp.value.end - 1, ',' + enAdd.join(','), `en-US +${enAdd.length}`]);
    for (const loc of ['zh-CN', 'zh-TW']) {
      const prop = p.node.init.properties.find(q => keyName(q) === loc);
      const existing = new Set(prop.value.properties.map(keyName));
      const add = [];
      for (const [zh, en] of Object.entries(dict)) {
        if (zh === en || en !== en.trim() || existing.has(en) || /[㐀-鿿]/.test(en)) continue;
        const target = (VC[loc] && VC[loc][zh]) || zh;
        add.push(`${JSON.stringify(en)}:${JSON.stringify(target)}`);
        existing.add(en);
      }
      const end = prop.value.end - 1; // position of closing brace
      edits.push([end, end, (prop.value.properties.length ? ',' : '') + add.join(','), `${loc} +${add.length}`]);
    }
  }
});
if (!edits.some(e => e[3] === 'default language')) throw new Error('default language site not found');
edits.sort((a, b) => b[0] - a[0]).forEach(([s, e, r]) => { src = src.slice(0, s) + r + src.slice(e); });
fs.writeFileSync(path.join(dir, f), src);
console.log(f, edits.map(e => e[3]).join(', '));
