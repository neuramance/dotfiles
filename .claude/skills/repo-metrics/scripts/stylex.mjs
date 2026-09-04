import ts from "typescript";

export function countStylex(file, content) {
  if (!/\.[cm]?[jt]sx?$/.test(file) || !content.includes("@stylexjs/stylex"))
    return 0;
  const source = ts.createSourceFile(
    file,
    content,
    ts.ScriptTarget.Latest,
    true,
  );
  if (source.parseDiagnostics.length) {
    throw new Error(
      `Cannot measure StyleX in ${file}: ${ts.flattenDiagnosticMessageText(source.parseDiagnostics[0].messageText, " ")}`,
    );
  }
  const options = { noLib: true, noResolve: true, allowJs: true };
  const host = ts.createCompilerHost(options);
  host.getSourceFile = (name) => (name === file ? source : undefined);
  const checker = ts.createProgram([file], options, host).getTypeChecker();
  const bindings = new Map(
    [...importBindings(source), ...requireBindings(source, checker)].map(
      ([name, method]) => [checker.getSymbolAtLocation(name), method],
    ),
  );
  const methods = new Set([
    "create",
    "keyframes",
    "defineVars",
    "defineConsts",
    "createTheme",
  ]);
  const lines = content.split(/\r\n|\r|\n/);
  const counted = new Set();
  function mark(node) {
    if (
      node.kind >= ts.SyntaxKind.FirstJSDocNode &&
      node.kind <= ts.SyntaxKind.LastJSDocNode
    )
      return;
    if (!ts.isToken(node)) {
      node.getChildren(source).forEach(mark);
      return;
    }
    const first = source.getLineAndCharacterOfPosition(
      node.getStart(source),
    ).line;
    const last = source.getLineAndCharacterOfPosition(node.getEnd() - 1).line;
    for (let line = first; line <= last; line++)
      if (lines[line].trim()) counted.add(line);
  }
  function visit(node) {
    if (ts.isCallExpression(node)) {
      const callee = node.expression;
      const imported = bindings.get(checker.getSymbolAtLocation(callee));
      const method = ts.isPropertyAccessExpression(callee)
        ? callee.name.text
        : ts.isElementAccessExpression(callee) &&
            ts.isStringLiteral(callee.argumentExpression)
          ? callee.argumentExpression.text
          : null;
      const member =
        methods.has(method) &&
        bindings.get(checker.getSymbolAtLocation(callee.expression)) === "*";
      if (methods.has(imported) || member) {
        mark(node);
        return;
      }
    }
    ts.forEachChild(node, visit);
  }
  visit(source);
  return counted.size;
}

function importBindings(source) {
  const result = [];
  for (const statement of source.statements.filter(ts.isImportDeclaration)) {
    if (statement.moduleSpecifier.text !== "@stylexjs/stylex") continue;
    const clause = statement.importClause;
    if (!clause || clause.isTypeOnly) continue;
    if (clause.name) result.push([clause.name, "*"]);
    const bindings = clause.namedBindings;
    if (!bindings) continue;
    if (ts.isNamespaceImport(bindings)) result.push([bindings.name, "*"]);
    else
      for (const binding of bindings.elements.filter(
        (binding) => !binding.isTypeOnly,
      ))
        result.push([
          binding.name,
          (binding.propertyName ?? binding.name).text,
        ]);
  }
  return result;
}

function requireBindings(source, checker) {
  return source.statements
    .filter(ts.isVariableStatement)
    .flatMap((statement) => statement.declarationList.declarations)
    .flatMap((declaration) => {
      const initializer = declaration.initializer;
      if (
        !initializer ||
        !ts.isCallExpression(initializer) ||
        !ts.isIdentifier(initializer.expression) ||
        initializer.expression.text !== "require" ||
        initializer.arguments.length !== 1 ||
        !ts.isStringLiteral(initializer.arguments[0]) ||
        initializer.arguments[0].text !== "@stylexjs/stylex" ||
        checker.getSymbolAtLocation(initializer.expression)?.declarations
      )
        return [];
      if (ts.isIdentifier(declaration.name)) return [[declaration.name, "*"]];
      if (!ts.isObjectBindingPattern(declaration.name)) return [];
      return declaration.name.elements
        .filter(
          (binding) => ts.isIdentifier(binding.name) && !binding.dotDotDotToken,
        )
        .map((binding) => [
          binding.name,
          (binding.propertyName ?? binding.name).text,
        ]);
    });
}
