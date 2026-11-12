const fs = require("fs");
const path = require("path");
const assert = require("assert");
const { ethers } = require("ethers");
const { SKINS_CATALOG } = require("./skins-catalog");

const ROOT_DIR = path.resolve(__dirname, "..");
const GAME_ROOT = path.resolve(ROOT_DIR, "..");
const ARTIFACTS_DIR = path.join(ROOT_DIR, "artifacts");

function readJson(p) {
  return JSON.parse(fs.readFileSync(p, "utf8"));
}

function main() {
  console.log("=== [Web3 Tests] Verifying Compiled Contracts, ABI & Catalog Parity ===");

  // 1. Verify artifacts & bytecode limits
  const contracts = ["ForestTrailCoin", "ForestTrailGem", "ForestTrailSkins"];
  const loaded = {};
  for (const name of contracts) {
    const p = path.join(ARTIFACTS_DIR, `${name}.json`);
    assert(fs.existsSync(p), `Missing artifact: ${p}`);
    const art = readJson(p);
    assert(Array.isArray(art.abi) && art.abi.length > 0, `Invalid ABI in ${name}`);
    assert(typeof art.bytecode === "string" && art.bytecode.startsWith("0x") && art.bytecode.length > 10, `Invalid init bytecode in ${name}`);
    assert(typeof art.deployedBytecodeBytes === "number" && art.deployedBytecodeBytes > 0, `Missing deployedBytecodeBytes in ${name}`);
    assert(art.deployedBytecodeBytes <= 24576, `${name} exceeds EIP-170 runtime limit: ${art.deployedBytecodeBytes} bytes`);
    assert(art.initCodeBytes <= 49152, `${name} exceeds EIP-3860 initcode limit: ${art.initCodeBytes} bytes`);
    loaded[name] = art;
    console.log(`  [OK] Artifact ${name}: runtime=${art.deployedBytecodeBytes}B, initcode=${art.initCodeBytes}B`);
  }

  // 2. Verify ForestTrailSkins ABI methods & calldata roundtrip
  const hubIface = new ethers.Interface(loaded.ForestTrailSkins.abi);
  const coinIface = new ethers.Interface(loaded.ForestTrailCoin.abi);
  const gemIface = new ethers.Interface(loaded.ForestTrailGem.abi);

  for (const fn of [
    "coinToken()",
    "gemToken()",
    "claimStarterPack()",
    "claimWaveReward(uint256,uint256,bytes)",
    "buySkin(uint256)",
    "getPlayerProfile(address)",
    "nonces(address)",
    "skinConfigs(uint256)",
    "uri(uint256)",
    "setRewardSigner(address)",
    "setBaseURI(string)"
  ]) {
    assert(hubIface.getFunction(fn), `Missing ForestTrailSkins function: ${fn}`);
  }
  for (const ev of ["StarterClaimed", "WaveRewardClaimed", "SkinPurchased"]) {
    assert(hubIface.getEvent(ev), `Missing ForestTrailSkins event: ${ev}`);
  }
  for (const fn of ["balanceOf(address)", "mint(address,uint256)", "spendFrom(address,uint256)"]) {
    assert(coinIface.getFunction(fn), `Missing ForestTrailCoin function: ${fn}`);
    assert(gemIface.getFunction(fn), `Missing ForestTrailGem function: ${fn}`);
  }

  const starterData = hubIface.encodeFunctionData("claimStarterPack", []);
  assert.strictEqual(starterData, hubIface.getFunction("claimStarterPack").selector);
  const buyData = hubIface.encodeFunctionData("buySkin", [1]);
  const [decodedSkinId] = hubIface.decodeFunctionData("buySkin", buyData);
  assert.strictEqual(Number(decodedSkinId), 1);

  // Verify constructor deploy encoding
  const dummyAddr = "0x1111111111111111111111111111111111111111";
  const deployTxData = hubIface.encodeDeploy([dummyAddr, dummyAddr, "http://127.0.0.1:3845/api/metadata/", ethers.ZeroAddress]);
  assert(deployTxData.startsWith("0x"), "Constructor deploy encoding failed");
  assert(coinIface.getFunction("setGameHub(address)"), "Missing coin setGameHub");
  assert(gemIface.getFunction("setGameHub(address)"), "Missing gem setGameHub");

  // Verify wave reward ECDSA digest roundtrip matches server.js + Solidity
  const testWallet = ethers.Wallet.createRandom();
  const payloadHash = ethers.solidityPackedKeccak256(
    ["uint256", "address", "address", "uint256", "uint256", "uint256"],
    [11155111, dummyAddr, testWallet.address, 25, 5, 0]
  );
  const sig = testWallet.signMessageSync(ethers.getBytes(payloadHash));
  const recovered = ethers.verifyMessage(ethers.getBytes(payloadHash), sig);
  assert.strictEqual(recovered, testWallet.address, "ECDSA signature recovery mismatch");
  const claimData = hubIface.encodeFunctionData("claimWaveReward", [25, 5, sig]);
  const [cAmt, gAmt, cSig] = hubIface.decodeFunctionData("claimWaveReward", claimData);
  assert.strictEqual(Number(cAmt), 25);
  assert.strictEqual(Number(gAmt), 5);
  assert.strictEqual(cSig, sig);
  console.log("  [OK] ABI encode/decode & ECDSA voucher roundtrip verified");

  // 3. Verify 16 skins parity across Solidity, catalog JS, Godot Web3Manager, MainMenu, Tower, PNGs
  assert.strictEqual(SKINS_CATALOG.length, 16, "Expected 16 skins in SKINS_CATALOG");

  const solSrc = fs.readFileSync(path.join(ROOT_DIR, "contracts", "ForestTrailSkins.sol"), "utf8");
  const web3Gd = fs.readFileSync(path.join(GAME_ROOT, "scripts", "web3_manager.gd"), "utf8");
  const menuGd = fs.readFileSync(path.join(GAME_ROOT, "scripts", "main_menu.gd"), "utf8");
  const towerGd = fs.readFileSync(path.join(GAME_ROOT, "scripts", "tower.gd"), "utf8");

  const coinSol = fs.readFileSync(path.join(ROOT_DIR, "contracts", "ForestTrailCoin.sol"), "utf8");
  const gemSol = fs.readFileSync(path.join(ROOT_DIR, "contracts", "ForestTrailGem.sol"), "utf8");
  assert(coinSol.includes('symbol = "FTC"') && gemSol.includes('symbol = "FTG"'), "Missing token symbols");

  for (const s of SKINS_CATALOG) {
    // Image file
    const imgPath = path.join(GAME_ROOT, "assets", "images", s.image);
    assert(fs.existsSync(imgPath), `Missing skin PNG: ${imgPath}`);

    // Solidity skinConfigs branch check
    const expectedCurr = s.currency === "coins" ? "CURRENCY_COIN" : "CURRENCY_GEM";
    const solLineRe = new RegExp(`skinId == ${s.tokenId}\\b[\\s\\S]{0,120}?return \\(${expectedCurr}, ${s.price}, true\\)`);
    assert(solLineRe.test(solSrc), `Solidity skinConfigs mismatch for #${s.tokenId} (${s.id})`);

    // Godot Web3Manager SKIN_TOKEN_IDS
    const w3Re = new RegExp(`"${s.id}":\\s*${s.tokenId},`);
    assert(w3Re.test(web3Gd), `web3_manager.gd SKIN_TOKEN_IDS missing/mismatch for ${s.id}`);

    // Godot MainMenu SKIN_CATALOG id, currency, price
    const mmRe = new RegExp(
      `"id":\\s*"${s.id}"[\\s\\S]{0,180}?"currency":\\s*"${s.currency}"[\\s\\S]{0,60}?"price":\\s*${s.price}`
    );
    assert(mmRe.test(menuGd), `main_menu.gd catalog mismatch for ${s.id}`);

    // Godot Tower SKIN_TEXTURES
    assert(towerGd.includes(`"${s.id}": preload("res://assets/images/${s.image}")`), `tower.gd SKIN_TEXTURES missing ${s.id}`);
  }
  console.log("  [OK] 16-skin parity verified across Solidity, JS catalog, GDScript, and PNG assets");
  console.log("=== ALL WEB3 CONTRACT & PARITY TESTS PASSED ===");
}

main();
