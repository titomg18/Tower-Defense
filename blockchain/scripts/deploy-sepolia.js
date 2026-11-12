const fs = require("fs");
const path = require("path");
const { ethers } = require("ethers");

const ROOT_DIR = path.resolve(__dirname, "..");
const CONFIG_PATH = path.join(ROOT_DIR, "config.json");
const ARTIFACTS_DIR = path.join(ROOT_DIR, "artifacts");

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

async function main() {
  loadEnv();
  const cfg = JSON.parse(fs.readFileSync(CONFIG_PATH, "utf8"));
  const rpcUrl = process.env.SEPOLIA_RPC_URL || cfg.rpcUrl;
  const privateKey = process.env.PRIVATE_KEY;

  if (!privateKey) {
    console.error("ERROR: PRIVATE_KEY belum diisi di blockchain/.env");
    console.error("Alternatif paling mudah tanpa private key: jalankan `npm start` lalu buka http://127.0.0.1:3845 untuk deploy langsung via MetaMask!");
    process.exit(1);
  }

  const coinPath = path.join(ARTIFACTS_DIR, "ForestTrailCoin.json");
  const gemPath = path.join(ARTIFACTS_DIR, "ForestTrailGem.json");
  const skinsPath = path.join(ARTIFACTS_DIR, "ForestTrailSkins.json");
  if (!fs.existsSync(coinPath) || !fs.existsSync(gemPath) || !fs.existsSync(skinsPath)) {
    console.error("Artifact belum ada. Jalankan `npm run compile` terlebih dahulu.");
    process.exit(1);
  }

  const coinArt = JSON.parse(fs.readFileSync(coinPath, "utf8"));
  const gemArt = JSON.parse(fs.readFileSync(gemPath, "utf8"));
  const skinsArt = JSON.parse(fs.readFileSync(skinsPath, "utf8"));

  const provider = new ethers.JsonRpcProvider(rpcUrl, 11155111, { staticNetwork: true });
  const wallet = new ethers.Wallet(privateKey, provider);
  const balanceWei = await provider.getBalance(wallet.address);
  console.log(`Deployer: ${wallet.address}`);
  console.log(`Saldo Sepolia ETH: ${ethers.formatEther(balanceWei)} ETH`);
  if (balanceWei === 0n) {
    throw new Error("Saldo Sepolia ETH 0! Isi faucet Sepolia dulu.");
  }

  const startNonce = await provider.getTransactionCount(wallet.address, "pending");
  const expectedSkinsAddr = ethers.getCreateAddress({ from: wallet.address, nonce: startNonce + 2 });

  console.log("1/3 Deploy ForestTrailCoin (FTC)...");
  const coinFac = new ethers.ContractFactory(coinArt.abi, coinArt.bytecode, wallet);
  const coin = await coinFac.deploy(expectedSkinsAddr);
  await coin.waitForDeployment();
  const coinAddr = await coin.getAddress();
  console.log(`  FTC deployed: ${coinAddr}`);

  console.log("2/3 Deploy ForestTrailGem (FTG)...");
  const gemFac = new ethers.ContractFactory(gemArt.abi, gemArt.bytecode, wallet);
  const gem = await gemFac.deploy(expectedSkinsAddr);
  await gem.waitForDeployment();
  const gemAddr = await gem.getAddress();
  console.log(`  FTG deployed: ${gemAddr}`);

  const signerAddr = process.env.REWARD_SIGNER_ADDRESS || ethers.ZeroAddress;
  const baseUri = `http://127.0.0.1:${process.env.BRIDGE_PORT || 3845}/api/metadata/`;

  console.log("3/3 Deploy ForestTrailSkins (ERC-1155 NFT Hub)...");
  const skinsFac = new ethers.ContractFactory(skinsArt.abi, skinsArt.bytecode, wallet);
  const skins = await skinsFac.deploy(coinAddr, gemAddr, baseUri, signerAddr);
  const tx = skins.deploymentTransaction();
  console.log(`  Tx Hash: ${tx.hash}`);
  await skins.waitForDeployment();
  const skinsAddr = await skins.getAddress();

  if (skinsAddr.toLowerCase() !== expectedSkinsAddr.toLowerCase()) {
    console.log("  Menyesuaikan gameHub pada FTC & FTG...");
    await (await coin.setGameHub(skinsAddr)).wait();
    await (await gem.setGameHub(skinsAddr)).wait();
  }

  const nextCfg = {
    ...cfg,
    rpcUrl,
    skinsContract: skinsAddr,
    coinContract: coinAddr,
    gemContract: gemAddr,
    deployerAddress: wallet.address,
    deployTxHash: tx.hash
  };
  fs.writeFileSync(CONFIG_PATH, JSON.stringify(nextCfg, null, 2));

  console.log("\n=== DEPLOY SEPOLIA SUKSES ===");
  console.log(`ForestTrailSkins (ERC-1155) : ${skinsAddr}`);
  console.log(`ForestTrailCoin  (ERC-20 FTC): ${coinAddr}`);
  console.log(`ForestTrailGem   (ERC-20 FTG): ${gemAddr}`);
  console.log(`Config tersimpan ke: ${CONFIG_PATH}`);
}

main().catch((err) => {
  console.error("Deploy gagal:", err);
  process.exit(1);
});
