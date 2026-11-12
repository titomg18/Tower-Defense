const http = require("http");
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const { ethers } = require("ethers");
const { SKINS_CATALOG } = require("../scripts/skins-catalog");

const ROOT_DIR = path.resolve(__dirname, "..");
const CONFIG_PATH = path.join(ROOT_DIR, "config.json");
const ARTIFACT_PATH = path.join(ROOT_DIR, "artifacts", "ForestTrailSkins.json");
const COIN_ARTIFACT_PATH = path.join(ROOT_DIR, "artifacts", "ForestTrailCoin.json");
const GEM_ARTIFACT_PATH = path.join(ROOT_DIR, "artifacts", "ForestTrailGem.json");
const ETHERS_UMD_PATH = path.join(ROOT_DIR, "node_modules", "ethers", "dist", "ethers.umd.min.js");
const PUBLIC_DIR = path.join(__dirname, "public");
const GAME_IMAGES_DIR = path.resolve(ROOT_DIR, "..", "assets", "images");

function loadEnv() {
  const envPath = path.join(ROOT_DIR, ".env");
  if (!fs.existsSync(envPath)) return;
  for (const rawLine of fs.readFileSync(envPath, "utf8").split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) continue;
    const eq = line.indexOf("=");
    if (eq > 0) {
      const k = line.slice(0, eq).trim();
      const v = line.slice(eq + 1).trim();
      if (!(k in process.env)) process.env[k] = v;
    }
  }
}

loadEnv();

const PORT = Number(process.env.BRIDGE_PORT || 3845);
const ALLOWED_IMAGES = new Set([
  "icon_coin.png",
  "icon_gem.png",
  "archer_tower.png",
  "ice_tower.png",
  "cannon_tower.png",
  "tesla_tower.png",
  ...SKINS_CATALOG.map((s) => s.image)
]);

let walletSession = {
  connected: false,
  address: "",
  chainId: 0,
  updatedAt: 0
};

const txQueue = new Map();
let latestTxId = "";

function readConfig() {
  const cfg = JSON.parse(fs.readFileSync(CONFIG_PATH, "utf8"));
  if (process.env.SEPOLIA_RPC_URL) {
    cfg.rpcUrl = process.env.SEPOLIA_RPC_URL;
  }
  return cfg;
}

function writeConfig(nextCfg) {
  fs.writeFileSync(CONFIG_PATH, JSON.stringify(nextCfg, null, 2));
}

function getArtifact(filePath = ARTIFACT_PATH) {
  if (!fs.existsSync(filePath)) {
    throw new Error("Contract artifacts missing. Run `npm run compile` in blockchain/.");
  }
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function getProvider(cfg) {
  return new ethers.JsonRpcProvider(cfg.rpcUrl, {
    chainId: Number(cfg.chainId || 11155111),
    name: "sepolia"
  });
}

function sendJson(res, statusCode, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type"
  });
  res.end(body);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let raw = "";
    req.on("data", (chunk) => {
      raw += chunk;
      if (raw.length > 1024 * 1024) {
        reject(new Error("Payload too large"));
        req.destroy();
      }
    });
    req.on("end", () => {
      if (!raw) return resolve({});
      try {
        resolve(JSON.parse(raw));
      } catch {
        reject(new Error("Invalid JSON body"));
      }
    });
    req.on("error", reject);
  });
}

function getActivePendingTx() {
  if (!latestTxId || !txQueue.has(latestTxId)) return null;
  const tx = txQueue.get(latestTxId);
  if (Date.now() - tx.createdAt > 10 * 60 * 1000) {
    txQueue.delete(latestTxId);
    latestTxId = "";
    return null;
  }
  return tx;
}

async function handleApi(req, res, urlObj) {
  const pathname = urlObj.pathname;
  const cfg = readConfig();
  const contractsDeployed = Boolean(cfg.skinsContract && ethers.isAddress(cfg.skinsContract));

  if (req.method === "GET" && pathname === "/api/config") {
    return sendJson(res, 200, {
      ok: true,
      networkName: cfg.networkName,
      chainId: cfg.chainId,
      chainHex: cfg.chainHex,
      rpcUrl: cfg.rpcUrl,
      explorerUrl: cfg.explorerUrl,
      skinsContract: cfg.skinsContract,
      coinContract: cfg.coinContract,
      gemContract: cfg.gemContract,
      deployerAddress: cfg.deployerAddress,
      deployTxHash: cfg.deployTxHash,
      contractsDeployed,
      skinsCatalog: SKINS_CATALOG
    });
  }

  if (req.method === "GET" && pathname === "/api/deploy-artifact") {
    const skinsArt = getArtifact(ARTIFACT_PATH);
    const coinArt = getArtifact(COIN_ARTIFACT_PATH);
    const gemArt = getArtifact(GEM_ARTIFACT_PATH);
    let signerAddress = process.env.REWARD_SIGNER_ADDRESS || "";
    if (!signerAddress && process.env.REWARD_SIGNER_PRIVATE_KEY) {
      signerAddress = new ethers.Wallet(process.env.REWARD_SIGNER_PRIVATE_KEY).address;
    }
    return sendJson(res, 200, {
      ok: true,
      abi: skinsArt.abi,
      bytecode: skinsArt.bytecode,
      coin: { abi: coinArt.abi, bytecode: coinArt.bytecode },
      gem: { abi: gemArt.abi, bytecode: gemArt.bytecode },
      skins: { abi: skinsArt.abi, bytecode: skinsArt.bytecode },
      defaultBaseUri: `http://127.0.0.1:${PORT}/api/metadata/`,
      rewardSignerAddress: signerAddress && ethers.isAddress(signerAddress) ? signerAddress : ethers.ZeroAddress
    });
  }

  if (req.method === "POST" && pathname === "/api/config/deployed") {
    const body = await readBody(req);
    const skinsAddress = ethers.getAddress(String(body.skinsContract || ""));
    const deployTxHash = String(body.deployTxHash || "");
    const deployerAddress = body.deployerAddress && ethers.isAddress(body.deployerAddress)
      ? ethers.getAddress(body.deployerAddress)
      : "";

    const artifact = getArtifact();
    const provider = getProvider(cfg);

    let code = "0x";
    for (let attempt = 0; attempt < 6; attempt++) {
      code = await provider.getCode(skinsAddress);
      if (code && code !== "0x") break;
      await new Promise((r) => setTimeout(r, 1500));
    }
    if (!code || code === "0x") {
      return sendJson(res, 400, { ok: false, error: "Kontrak belum terdeteksi di RPC Sepolia. Coba refresh sebentar lagi." });
    }

    const contract = new ethers.Contract(skinsAddress, artifact.abi, provider);
    const coinAddr = await contract.coinToken();
    const gemAddr = await contract.gemToken();

    const nextCfg = {
      ...cfg,
      skinsContract: skinsAddress,
      coinContract: coinAddr,
      gemContract: gemAddr,
      deployerAddress: deployerAddress || cfg.deployerAddress,
      deployTxHash: deployTxHash || cfg.deployTxHash
    };
    writeConfig(nextCfg);
    return sendJson(res, 200, { ok: true, config: nextCfg });
  }

  if (req.method === "GET" && pathname === "/api/status") {
    return sendJson(res, 200, {
      ok: true,
      bridgeOnline: true,
      contractsDeployed,
      networkName: cfg.networkName,
      chainId: cfg.chainId,
      explorerUrl: cfg.explorerUrl,
      skinsContract: cfg.skinsContract,
      coinContract: cfg.coinContract,
      gemContract: cfg.gemContract,
      wallet: walletSession,
      pendingTx: getActivePendingTx()
    });
  }

  if (req.method === "POST" && pathname === "/api/session/connect") {
    const body = await readBody(req);
    const addr = String(body.address || "");
    if (!ethers.isAddress(addr)) {
      return sendJson(res, 400, { ok: false, error: "Invalid EVM address" });
    }
    walletSession = {
      connected: true,
      address: ethers.getAddress(addr),
      chainId: Number(body.chainId || 0),
      updatedAt: Date.now()
    };
    return sendJson(res, 200, { ok: true, wallet: walletSession });
  }

  if (req.method === "POST" && pathname === "/api/session/disconnect") {
    walletSession = {
      connected: false,
      address: "",
      chainId: 0,
      updatedAt: Date.now()
    };
    latestTxId = "";
    txQueue.clear();
    return sendJson(res, 200, { ok: true, wallet: walletSession });
  }

  if (req.method === "GET" && pathname === "/api/profile") {
    const rawAddr = urlObj.searchParams.get("address") || walletSession.address;
    if (!rawAddr || !ethers.isAddress(rawAddr)) {
      return sendJson(res, 400, { ok: false, error: "Wallet belum terhubung" });
    }
    const address = ethers.getAddress(rawAddr);
    const provider = getProvider(cfg);
    const ethWei = await provider.getBalance(address);
    const ethBalance = Number(ethers.formatEther(ethWei)).toFixed(4);

    if (!contractsDeployed) {
      return sendJson(res, 200, {
        ok: true,
        contractsDeployed: false,
        address,
        ethBalance,
        coinBalance: 0,
        gemBalance: 0,
        hasClaimedStarter: false,
        ownedSkinIds: [],
        ownedTokenIds: [],
        playerNonce: 0
      });
    }

    const artifact = getArtifact();
    const contract = new ethers.Contract(cfg.skinsContract, artifact.abi, provider);
    const [coinBalance, gemBalance, hasClaimedStarter, skinOwned, playerNonce] =
      await contract.getPlayerProfile(address);

    const ownedSkinIds = [];
    const ownedTokenIds = [];
    for (let i = 0; i < SKINS_CATALOG.length; i++) {
      if (BigInt(skinOwned[i]) > 0n) {
        ownedSkinIds.push(SKINS_CATALOG[i].id);
        ownedTokenIds.push(SKINS_CATALOG[i].tokenId);
      }
    }

    return sendJson(res, 200, {
      ok: true,
      contractsDeployed: true,
      address,
      ethBalance,
      coinBalance: Number(coinBalance),
      gemBalance: Number(gemBalance),
      hasClaimedStarter: Boolean(hasClaimedStarter),
      ownedSkinIds,
      ownedTokenIds,
      playerNonce: Number(playerNonce)
    });
  }

  if (req.method === "POST" && pathname === "/api/tx/request") {
    if (!contractsDeployed) {
      return sendJson(res, 400, {
        ok: false,
        error: "Smart contract Sepolia belum di-deploy. Buka companion browser untuk deploy 1-klik dengan MetaMask."
      });
    }
    const body = await readBody(req);
    const rawAddr = String(body.address || walletSession.address || "");
    if (!ethers.isAddress(rawAddr)) {
      return sendJson(res, 400, { ok: false, error: "Wallet belum terhubung." });
    }
    const address = ethers.getAddress(rawAddr);
    const type = String(body.type || "");
    const artifact = getArtifact();
    const iface = new ethers.Interface(artifact.abi);

    let label = "";
    let description = "";
    let calldata = "";
    const params = {};

    if (type === "starter") {
      label = "Klaim Starter Pack Web3";
      description = "Mint 250 FTC (Koin Toko) + 50 FTG (Berlian) ke wallet Sepolia kamu (1x per wallet).";
      calldata = iface.encodeFunctionData("claimStarterPack", []);
    } else if (type === "claim_reward") {
      const coinAmount = Math.max(0, Math.floor(Number(body.coinAmount || 0)));
      const gemAmount = Math.max(0, Math.floor(Number(body.gemAmount || 0)));
      if (coinAmount === 0 && gemAmount === 0) {
        return sendJson(res, 400, { ok: false, error: "Tidak ada reward untuk diklaim." });
      }
      params.coinAmount = coinAmount;
      params.gemAmount = gemAmount;

      let signature = "0x";
      if (process.env.REWARD_SIGNER_PRIVATE_KEY) {
        const provider = getProvider(cfg);
        const contract = new ethers.Contract(cfg.skinsContract, artifact.abi, provider);
        const nonce = await contract.nonces(address);
        const payloadHash = ethers.solidityPackedKeccak256(
          ["uint256", "address", "address", "uint256", "uint256", "uint256"],
          [Number(cfg.chainId), cfg.skinsContract, address, coinAmount, gemAmount, nonce]
        );
        const signerWallet = new ethers.Wallet(process.env.REWARD_SIGNER_PRIVATE_KEY);
        signature = await signerWallet.signMessage(ethers.getBytes(payloadHash));
      }

      label = "Klaim Reward Wave On-Chain";
      description = `Mint +${coinAmount} FTC (Koin) dan +${gemAmount} FTG (Berlian) ke wallet kamu di Sepolia.`;
      calldata = iface.encodeFunctionData("claimWaveReward", [coinAmount, gemAmount, signature]);
    } else if (type === "buy_skin") {
      const skinKey = String(body.skinKey || "");
      const skinEntry = SKINS_CATALOG.find((s) => s.id === skinKey || s.tokenId === Number(body.tokenId));
      if (!skinEntry) {
        return sendJson(res, 400, { ok: false, error: `Skin tidak dikenali: ${skinKey}` });
      }
      params.tokenId = skinEntry.tokenId;
      params.skinKey = skinEntry.id;
      params.price = skinEntry.price;
      params.currencyLabel = skinEntry.currencyLabel;
      params.image = skinEntry.image;
      label = `Mint Skin NFT: ${skinEntry.name}`;
      description = `${skinEntry.towerName} (${skinEntry.name}) - Token #${skinEntry.tokenId} | Harga: ${skinEntry.price} ${skinEntry.currencyLabel}`;
      calldata = iface.encodeFunctionData("buySkin", [skinEntry.tokenId]);
    } else {
      return sendJson(res, 400, { ok: false, error: `Unknown tx type: ${type}` });
    }

    const txId = crypto.randomBytes(8).toString("hex");
    const txJob = {
      id: txId,
      type,
      label,
      description,
      address,
      to: cfg.skinsContract,
      data: calldata,
      params,
      status: "waiting_wallet",
      txHash: "",
      error: "",
      createdAt: Date.now()
    };

    txQueue.set(txId, txJob);
    latestTxId = txId;
    return sendJson(res, 200, { ok: true, tx: txJob });
  }

  if (req.method === "GET" && pathname === "/api/tx/pending") {
    return sendJson(res, 200, { ok: true, tx: getActivePendingTx() });
  }

  if (req.method === "GET" && pathname === "/api/tx/status") {
    const txId = urlObj.searchParams.get("txId") || latestTxId;
    const tx = txQueue.get(txId);
    if (!tx) {
      return sendJson(res, 404, { ok: false, error: "Transaction job not found" });
    }
    return sendJson(res, 200, { ok: true, tx });
  }

  if (req.method === "POST" && pathname === "/api/tx/update") {
    const body = await readBody(req);
    const txId = String(body.txId || "");
    const tx = txQueue.get(txId);
    if (!tx) {
      return sendJson(res, 404, { ok: false, error: "Transaction job not found" });
    }
    const allowed = new Set(["waiting_wallet", "submitted", "confirmed", "rejected", "failed"]);
    const nextStatus = String(body.status || "");
    if (!allowed.has(nextStatus)) {
      return sendJson(res, 400, { ok: false, error: "Invalid status" });
    }
    tx.status = nextStatus;
    if (body.txHash) tx.txHash = String(body.txHash);
    if (body.error) tx.error = String(body.error);
    tx.updatedAt = Date.now();
    return sendJson(res, 200, { ok: true, tx });
  }

  if (req.method === "GET" && pathname.startsWith("/api/metadata/")) {
    const rawId = pathname.replace("/api/metadata/", "").replace(".json", "");
    const tokenId = Number(rawId);
    const skin = SKINS_CATALOG.find((s) => s.tokenId === tokenId);
    if (!skin) {
      return sendJson(res, 404, { error: "Skin metadata not found" });
    }
    return sendJson(res, 200, {
      name: `${skin.towerName} - ${skin.name}`,
      description: `NFT Skin resmi untuk ${skin.towerName} (${skin.name}) di game Tower Defense: Forest Trail (Sepolia ERC-1155).`,
      image: `http://127.0.0.1:${PORT}/skins/${skin.image}`,
      attributes: [
        { trait_type: "Tower", value: skin.towerName },
        { trait_type: "Skin", value: skin.name },
        { trait_type: "Skin Code", value: skin.id },
        { trait_type: "Currency", value: skin.currencyLabel },
        { trait_type: "Price", value: skin.price }
      ]
    });
  }

  return sendJson(res, 404, { ok: false, error: "Not found" });
}

const server = http.createServer(async (req, res) => {
  if (req.method === "OPTIONS") {
    res.writeHead(204, {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type"
    });
    return res.end();
  }

  const urlObj = new URL(req.url, `http://127.0.0.1:${PORT}`);
  const pathname = urlObj.pathname;

  try {
    if (pathname.startsWith("/api/")) {
      return await handleApi(req, res, urlObj);
    }

    if (req.method === "GET" && (pathname === "/" || pathname === "/index.html")) {
      const html = fs.readFileSync(path.join(PUBLIC_DIR, "index.html"), "utf8");
      res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
      return res.end(html);
    }

    if (req.method === "GET" && pathname === "/ethers.umd.min.js") {
      const js = fs.readFileSync(ETHERS_UMD_PATH, "utf8");
      res.writeHead(200, { "Content-Type": "application/javascript; charset=utf-8" });
      return res.end(js);
    }

    if (req.method === "GET" && pathname.startsWith("/skins/")) {
      const fname = path.basename(pathname.slice("/skins/".length));
      if (!ALLOWED_IMAGES.has(fname)) {
        res.writeHead(404);
        return res.end("Not found");
      }
      const imgPath = path.join(GAME_IMAGES_DIR, fname);
      if (!fs.existsSync(imgPath)) {
        res.writeHead(404);
        return res.end("Not found");
      }
      res.writeHead(200, { "Content-Type": "image/png" });
      return fs.createReadStream(imgPath).pipe(res);
    }

    res.writeHead(404);
    res.end("Not found");
  } catch (err) {
    console.error("[Bridge Error]", err);
    sendJson(res, 500, { ok: false, error: err.message || "Internal bridge error" });
  }
});

server.listen(PORT, "127.0.0.1", () => {
  const cfg = readConfig();
  console.log("=======================================================");
  console.log(" Tower Defense: Forest Trail - Web3 MetaMask Bridge");
  console.log(` Companion URL : http://127.0.0.1:${PORT}`);
  console.log(` Network       : ${cfg.networkName} (Chain ID ${cfg.chainId})`);
  console.log(` Skins Contract: ${cfg.skinsContract || "(Belum di-deploy - buka Companion URL untuk deploy 1-klik!)"}`);
  console.log("=======================================================");
});
