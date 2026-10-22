// Static AST inspection only: never imports or executes the application or test module.
const fs = require("node:fs");
const ts = require("/opt/homebrew/lib/node_modules/typescript");
const source = ts.createSourceFile("integration.ts", fs.readFileSync("integrations/pi/iTermate-integration.ts", "utf8"), ts.ScriptTarget.Latest, true);
const fixture = ts.createSourceFile("fixture.mjs", fs.readFileSync("integrations/pi/local-llm-selection.test.mjs", "utf8"), ts.ScriptTarget.Latest, true, ts.ScriptKind.JS);
const imports = {};
for (const node of source.statements) {
  if (!ts.isImportDeclaration(node) || node.importClause?.isTypeOnly) continue;
  const bindings = node.importClause?.namedBindings;
  if (!bindings || !ts.isNamedImports(bindings)) continue;
  imports[node.moduleSpecifier.text] = bindings.elements.filter(item => !item.isTypeOnly)
    .map(item => (item.propertyName ?? item.name).text);
}
const candidates = [];
function findMocks(node) {
  if (ts.isVariableDeclaration(node) && node.name.getText(fixture) === "mocks") candidates.push(node.initializer);
  ts.forEachChild(node, findMocks);
}
findMocks(fixture);
if (candidates.length !== 1 || !ts.isObjectLiteralExpression(candidates[0])) throw new Error("Ambiguous mock definition");
const exportsByModule = {};
for (const module of candidates[0].properties) {
  if (!ts.isPropertyAssignment(module) || !ts.isObjectLiteralExpression(module.initializer)) throw new Error("Unsupported mock shape");
  const names = new Set();
  for (const property of module.initializer.properties) {
    if (ts.isPropertyAssignment(property) || ts.isShorthandPropertyAssignment(property)) names.add(property.name.text);
    else if (ts.isSpreadAssignment(property)) {
      const visit = node => {
        if (ts.isArrayLiteralExpression(node) && node.elements.length && node.elements.every(ts.isStringLiteral)) {
          for (const element of node.elements) names.add(element.text);
        }
        ts.forEachChild(node, visit);
      };
      visit(property.expression);
    } else throw new Error("Unsupported mock member");
  }
  exportsByModule[module.name.text] = [...names].sort();
}
const missing = [];
for (const [module, names] of Object.entries(imports)) {
  for (const name of names) if (!exportsByModule[module]?.includes(name)) missing.push({ module, name });
}
console.log(JSON.stringify({ mode: "static AST only", imports, exportsByModule, missing,
  limitation: "未加载或链接被检查模块 未执行测试 不代表测试行为通过" }, null, 2));
process.exitCode = missing.length ? 1 : 0;
