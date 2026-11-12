const fs = require("fs");
const path = require("path");
const solc = require("solc");

const ROOT_DIR = path.resolve(__dirname, "..");
const CONTRACTS_DIR = path.join(ROOT_DIR, "contracts");
const ARTIFACTS_DIR = path.join(ROOT_DIR, "artifacts");
const NODE_MODULES_DIR = path.join(ROOT_DIR, "node_modules");

function findImports(importPath) {
  const candidates = [
    path.join(CONTRACTS_DIR, importPath),
    path.join(NODE_MODULES_DIR, importPath),
  ];
  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
      return { contents: fs.readFileSync(candidate, "utf8") };
    }
  }
  return { error: `File not found: ${importPath}` };
}

function compileAll() {
  const sources = {};
  for (const file of fs.readdirSync(CONTRACTS_DIR)) {
    if (file.endsWith(".sol")) {
      sources[file] = {
        content: fs.readFileSync(path.join(CONTRACTS_DIR, file), "utf8"),
      };
    }
  }

  const input = {
    language: "Solidity",
    sources,
    settings: {
      evmVersion: "cancun",
      viaIR: true,
      optimizer: {
        enabled: true,
        runs: 1,
      },
      outputSelection: {
        "*": {
          "*": ["abi", "evm.bytecode.object", "evm.deployedBytecode.object"],
        },
      },
    },
  };

  const output = JSON.parse(solc.compile(JSON.stringify(input), { import: findImports }));

  let hasError = false;
  if (output.errors) {
    for (const err of output.errors) {
      if (err.severity === "error") {
        hasError = true;
        console.error(err.formattedMessage);
      } else {
        console.warn(err.formattedMessage);
      }
    }
  }

  if (hasError) {
    process.exit(1);
  }

  fs.mkdirSync(ARTIFACTS_DIR, { recursive: true });

  const targetContracts = new Set(["ForestTrailCoin", "ForestTrailGem", "ForestTrailSkins"]);
  for (const existing of fs.readdirSync(ARTIFACTS_DIR)) {
    if (existing.endsWith(".json")) {
      fs.unlinkSync(path.join(ARTIFACTS_DIR, existing));
    }
  }

  for (const [sourceFile, contracts] of Object.entries(output.contracts)) {
    for (const [contractName, compiled] of Object.entries(contracts)) {
      if (!targetContracts.has(contractName)) continue;
      const bytecode = "0x" + compiled.evm.bytecode.object;
      const initCodeBytes = compiled.evm.bytecode.object.length / 2;
      const deployedSize = compiled.evm.deployedBytecode.object.length / 2;
      const artifact = {
        contractName,
        sourceFile,
        abi: compiled.abi,
        bytecode,
        initCodeBytes,
        deployedBytecodeBytes: deployedSize,
      };
      const outPath = path.join(ARTIFACTS_DIR, `${contractName}.json`);
      fs.writeFileSync(outPath, JSON.stringify(artifact, null, 2));
      console.log(`Compiled ${contractName}: runtime=${deployedSize}B (<=24576), initcode=${initCodeBytes}B (<=49152)`);
    }
  }
}

compileAll();
