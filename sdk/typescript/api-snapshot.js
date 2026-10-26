const fs = require("node:fs");
const path = require("node:path");
const ts = require("typescript");

const root = __dirname;
const pkg = JSON.parse(
  fs.readFileSync(path.join(root, "package.json"), "utf8")
);
const specVersion = fs
  .readFileSync(path.join(root, "..", "..", "spec", "SPEC_VERSION"), "utf8")
  .trim();

function snapshot() {
  const config = ts.readConfigFile(
    path.join(root, "tsconfig.json"),
    ts.sys.readFile
  );
  const parsed = ts.parseJsonConfigFileContent(
    config.config,
    ts.sys,
    root
  );
  const program = ts.createProgram(
    [path.join(root, "src", "index.ts")],
    { ...parsed.options, noEmit: true }
  );
  const checker = program.getTypeChecker();
  const source = program.getSourceFile(path.join(root, "src", "index.ts"));
  const symbol = checker.getSymbolAtLocation(source);
  const names = symbol
    ? checker
        .getExportsOfModule(symbol)
        .map((item) => item.getName())
        .filter((name) => name !== "default")
        .sort()
    : [];
  return [
    `# PRAXO-CORE TypeScript API ${pkg.version}`,
    `# SPEC_VERSION ${specVersion}`,
    "",
    ...names,
    "",
  ].join("\n");
}

const check = process.argv.includes("--check");
const target = path.join(root, "api", `${pkg.version}.txt`);
const content = snapshot();
if (check) {
  if (!fs.existsSync(target)) {
    console.error(`missing snapshot: ${target}`);
    process.exitCode = 1;
  } else if (fs.readFileSync(target, "utf8") !== content) {
    console.error(`snapshot is stale: ${target}`);
    process.exitCode = 1;
  } else {
    console.log(`snapshot is current: ${target}`);
  }
} else {
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, content);
  console.log(`wrote ${target}`);
}
