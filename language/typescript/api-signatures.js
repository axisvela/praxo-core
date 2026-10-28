const fs = require("node:fs");
const path = require("node:path");
const ts = require("typescript");

function isPrivate(symbol) {
  return (symbol.declarations || []).some((declaration) => {
    if (declaration.name && ts.isPrivateIdentifier(declaration.name)) {
      return true;
    }
    return (declaration.modifiers || []).some(
      (modifier) => modifier.kind === ts.SyntaxKind.PrivateKeyword
    );
  });
}

function optional(symbol) {
  return (symbol.declarations || []).some(
    (declaration) => declaration.questionToken !== undefined
  );
}

function callable(name, type, checker, declaration) {
  const lines = [];
  for (const signature of type.getCallSignatures()) {
    lines.push(
      `${name}${checker.signatureToString(
        signature,
        declaration,
        ts.TypeFormatFlags.NoTruncation
      )}`
    );
  }
  return lines;
}

function properties(type, checker, declaration) {
  const lines = [];
  for (const symbol of type.getProperties()) {
    if (isPrivate(symbol)) {
      continue;
    }
    const name = symbol.getName();
    const memberType = checker.getTypeOfSymbolAtLocation(symbol, declaration);
    const methods = callable(name, memberType, checker, declaration);
    if (methods.length > 0) {
      lines.push(...methods);
      continue;
    }
    lines.push(
      `${name}${optional(symbol) ? "?" : ""}: ${checker.typeToString(
        memberType,
        declaration,
        ts.TypeFormatFlags.NoTruncation
      )}`
    );
  }
  return lines;
}

function declarationLines(name, symbol, checker) {
  const declaration = symbol.declarations && symbol.declarations[0];
  if (!declaration) {
    return [`${name}: <no declaration>`];
  }
  const type = checker.getDeclaredTypeOfSymbol(symbol);
  if (symbol.flags & ts.SymbolFlags.Class) {
    const lines = [`class ${name}`];
    const constructorType = checker.getTypeOfSymbolAtLocation(symbol, declaration);
    for (const signature of constructorType.getConstructSignatures()) {
      lines.push(
        `constructor${checker.signatureToString(
          signature,
          declaration,
          ts.TypeFormatFlags.NoTruncation
        )}`
      );
    }
    lines.push(...properties(type, checker, declaration));
    return lines;
  }
  if (symbol.flags & ts.SymbolFlags.Interface) {
    return [
      `interface ${name}`,
      ...properties(type, checker, declaration),
      ...callable("call", type, checker, declaration),
    ];
  }
  if (symbol.flags & ts.SymbolFlags.Function) {
    const callableType = checker.getTypeOfSymbolAtLocation(symbol, declaration);
    return [`function ${name}`, ...callable(name, callableType, checker, declaration)];
  }
  if (symbol.flags & ts.SymbolFlags.TypeAlias) {
    return [
      `type ${name} = ${checker.typeToString(
        type,
        declaration,
        ts.TypeFormatFlags.NoTruncation
      )}`,
    ];
  }
  if (symbol.flags & ts.SymbolFlags.Enum) {
    const members = (symbol.exports ? Array.from(symbol.exports.keys()) : []).sort();
    return [`enum ${name}`, ...members.map((member) => `member ${member}`)];
  }
  const typeOfSymbol = checker.getTypeOfSymbolAtLocation(symbol, declaration);
  return [
    `const ${name}: ${checker.typeToString(
      typeOfSymbol,
      declaration,
      ts.TypeFormatFlags.NoTruncation
    )}`,
  ];
}

function snapshot(root, specVersion) {
  const pkg = JSON.parse(
    fs.readFileSync(path.join(root, "package.json"), "utf8")
  );
  const config = ts.readConfigFile(path.join(root, "tsconfig.json"), ts.sys.readFile);
  const parsed = ts.parseJsonConfigFileContent(config.config, ts.sys, root);
  const program = ts.createProgram(
    [path.join(root, "src", "index.ts")],
    { ...parsed.options, noEmit: true }
  );
  const checker = program.getTypeChecker();
  const source = program.getSourceFile(path.join(root, "src", "index.ts"));
  const moduleSymbol = checker.getSymbolAtLocation(source);
  if (!moduleSymbol) {
    throw new Error("no module symbol for src/index.ts");
  }
  const exports = checker
    .getExportsOfModule(moduleSymbol)
    .filter((symbol) => symbol.getName() !== "default")
    .sort((left, right) => left.getName().localeCompare(right.getName()));
  const lines = [
    `# PRAXO-CORE TypeScript API Signatures ${pkg.version}`,
    `# SPEC_VERSION ${specVersion}`,
    "# Format 1: source declarations and public members",
    "",
  ];
  for (const exported of exports) {
    const symbol =
      exported.flags & ts.SymbolFlags.Alias
        ? checker.getAliasedSymbol(exported)
        : exported;
    lines.push(`## ${exported.getName()}`);
    lines.push(...declarationLines(exported.getName(), symbol, checker));
    lines.push("");
  }
  return lines.join("\n");
}

function main() {
  const root = __dirname;
  const specVersion = fs
    .readFileSync(path.join(root, "..", "..", "spec", "SPEC_VERSION"), "utf8")
    .trim();
  const pkg = JSON.parse(
    fs.readFileSync(path.join(root, "package.json"), "utf8")
  );
  const check = process.argv.includes("--check");
  const target = path.join(root, "api", `${pkg.version}.signatures.txt`);
  const content = snapshot(root, specVersion);
  if (check) {
    if (!fs.existsSync(target)) {
      console.error(`missing signature snapshot: ${target}`);
      process.exitCode = 1;
    } else if (fs.readFileSync(target, "utf8") !== content) {
      console.error(`signature snapshot is stale: ${target}`);
      process.exitCode = 1;
    } else {
      console.log(`signature snapshot is current: ${target}`);
    }
    return;
  }
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, content);
  console.log(`wrote ${target}`);
}

if (require.main === module) {
  main();
}

module.exports = { snapshot };
