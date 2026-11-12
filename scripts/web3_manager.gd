extends Node

const BRIDGE_URL := "http://127.0.0.1:3845"
const SAVE_PATH := "user://save_data.cfg"
const SEPOLIA_CHAIN_ID := 11155111

const SKIN_TOKEN_IDS := {
	"archer_emas": 1,
	"archer_elven": 2,
	"archer_steampunk": 3,
	"archer_es": 4,
	"ice_emas": 5,
	"ice_elven": 6,
	"ice_steampunk": 7,
	"ice_api": 8,
	"cannon_emas": 9,
	"cannon_elven": 10,
	"cannon_steampunk": 11,
	"cannon_api": 12,
	"tesla_emas": 13,
	"tesla_elven": 14,
	"tesla_steampunk": 15,
	"tesla_api": 16,
}

signal state_changed()
signal profile_synced()
signal tx_finished(success: bool, tx_type: String, message: String)

var bridge_online: bool = false
var contracts_deployed: bool = false
var wallet_connected: bool = false
var wallet_address: String = ""
var eth_balance: String = "0.0000"
var onchain_coins: int = 0
var onchain_gems: int = 0
var has_claimed_starter: bool = false
var onchain_owned_skins: Array[String] = []
var skins_contract: String = ""
var coin_contract: String = ""
var gem_contract: String = ""

var pending_claim_coins: int = 0
var pending_claim_gems: int = 0

var is_waiting_connect: bool = false
var active_tx_id: String = ""
var active_tx_type: String = ""
var active_tx_status: String = ""
var active_tx_label: String = ""
var active_tx_hash: String = ""
var active_tx_error: String = ""
var last_bought_skin_key: String = ""
var last_status_message: String = ""

var _poll_timer: Timer
var _poll_busy: bool = false
var _last_synced_address: String = ""
var _active_tx_skin_key: String = ""


func _ready() -> void:
	_load_pending_rewards()
	_poll_timer = Timer.new()
	_poll_timer.wait_time = 1.5
	_poll_timer.one_shot = false
	_poll_timer.timeout.connect(_on_poll_timer_timeout)
	add_child(_poll_timer)
	_poll_timer.start()
	call_deferred("check_bridge_status")


func is_onchain_mode() -> bool:
	return bridge_online and wallet_connected and contracts_deployed and wallet_address != ""


func short_address(addr: String = "") -> String:
	var target := addr if addr != "" else wallet_address
	if target.length() < 12:
		return target
	return "%s...%s" % [target.substr(0, 6), target.substr(target.length() - 4, 4)]


func add_pending_reward(coins_gain: int, gems_gain: int) -> void:
	pending_claim_coins += maxi(0, coins_gain)
	pending_claim_gems += maxi(0, gems_gain)
	_save_pending_rewards()
	state_changed.emit()


func has_pending_reward() -> bool:
	return pending_claim_coins > 0 or pending_claim_gems > 0


func is_tx_busy() -> bool:
	return active_tx_id != "" and (active_tx_status == "waiting_wallet" or active_tx_status == "submitted")


func open_companion_in_browser(tx_id: String = "") -> void:
	var url := BRIDGE_URL
	if tx_id != "":
		url = "%s/?txId=%s" % [BRIDGE_URL, tx_id]
	OS.shell_open(url)


func check_bridge_status() -> void:
	if _poll_busy:
		return
	_poll_busy = true
	var res := await _http_get_json("%s/api/status" % BRIDGE_URL)
	_poll_busy = false

	if not res.get("ok", false):
		var was_online := bridge_online
		bridge_online = false
		contracts_deployed = false
		wallet_connected = false
		if was_online:
			last_status_message = "Bridge Web3 terputus."
			state_changed.emit()
		return

	bridge_online = true
	contracts_deployed = bool(res.get("contractsDeployed", false))
	skins_contract = String(res.get("skinsContract", ""))
	coin_contract = String(res.get("coinContract", ""))
	gem_contract = String(res.get("gemContract", ""))

	var w: Dictionary = res.get("wallet", {})
	var new_connected := bool(w.get("connected", false))
	var new_addr := String(w.get("address", ""))

	var changed := (new_connected != wallet_connected) or (new_addr != wallet_address)
	wallet_connected = new_connected
	wallet_address = new_addr

	if wallet_connected and wallet_address != "":
		is_waiting_connect = false
		if changed or _last_synced_address != wallet_address:
			last_status_message = "MetaMask terhubung (%s)" % short_address()
			await refresh_profile()
		else:
			state_changed.emit()
	else:
		_last_synced_address = ""
		onchain_owned_skins.clear()
		onchain_coins = 0
		onchain_gems = 0
		has_claimed_starter = false
		if changed:
			last_status_message = "Wallet belum terhubung."
		state_changed.emit()


func connect_metamask() -> void:
	is_waiting_connect = true
	last_status_message = "Memeriksa Bridge Web3..."
	state_changed.emit()

	var res := await _http_get_json("%s/api/status" % BRIDGE_URL)
	if not res.get("ok", false):
		is_waiting_connect = false
		bridge_online = false
		last_status_message = "Bridge Web3 offline! Jalankan start-web3-bridge.bat dulu."
		state_changed.emit()
		return

	bridge_online = true
	contracts_deployed = bool(res.get("contractsDeployed", false))
	skins_contract = String(res.get("skinsContract", ""))
	coin_contract = String(res.get("coinContract", ""))
	gem_contract = String(res.get("gemContract", ""))

	var w: Dictionary = res.get("wallet", {})
	if bool(w.get("connected", false)) and String(w.get("address", "")) != "":
		wallet_connected = true
		wallet_address = String(w.get("address", ""))
		is_waiting_connect = false
		await refresh_profile()
		if not contracts_deployed:
			last_status_message = "Deploy kontrak Sepolia 1-klik di browser companion."
			open_companion_in_browser()
			state_changed.emit()
		return

	last_status_message = "Menunggu koneksi MetaMask di browser..."
	open_companion_in_browser()
	state_changed.emit()


func disconnect_wallet() -> void:
	is_waiting_connect = false
	active_tx_id = ""
	active_tx_status = ""
	_active_tx_skin_key = ""
	last_bought_skin_key = ""
	await _http_post_json("%s/api/session/disconnect" % BRIDGE_URL, {})
	wallet_connected = false
	wallet_address = ""
	_last_synced_address = ""
	onchain_coins = 0
	onchain_gems = 0
	has_claimed_starter = false
	onchain_owned_skins.clear()
	last_status_message = "Kembali ke Mode Lokal."
	state_changed.emit()


func refresh_profile() -> void:
	if not bridge_online or not wallet_connected or wallet_address == "":
		return
	var res := await _http_get_json("%s/api/profile?address=%s" % [BRIDGE_URL, wallet_address.uri_encode()])
	if not res.get("ok", false):
		last_status_message = String(res.get("error", "Gagal membaca saldo Sepolia."))
		state_changed.emit()
		return

	contracts_deployed = bool(res.get("contractsDeployed", false))
	eth_balance = String(res.get("ethBalance", "0.0000"))
	onchain_coins = int(res.get("coinBalance", 0))
	onchain_gems = int(res.get("gemBalance", 0))
	has_claimed_starter = bool(res.get("hasClaimedStarter", false))

	onchain_owned_skins.clear()
	var raw_owned: Variant = res.get("ownedSkinIds", [])
	if raw_owned is Array:
		for s in raw_owned:
			onchain_owned_skins.append(String(s))

	_last_synced_address = wallet_address
	if not contracts_deployed:
		last_status_message = "Kontrak Sepolia belum di-deploy."
	elif not is_tx_busy():
		last_status_message = "Sepolia OK | %s ETH" % eth_balance

	profile_synced.emit()
	state_changed.emit()


func request_claim_starter() -> void:
	if not _ensure_ready_for_tx():
		return
	await _start_tx("starter", {
		"type": "starter",
		"address": wallet_address,
	})


func request_claim_wave_rewards() -> void:
	if not _ensure_ready_for_tx():
		return
	if not has_pending_reward():
		last_status_message = "Belum ada reward wave untuk diklaim."
		state_changed.emit()
		return
	var claim_c: int = mini(pending_claim_coins, 500)
	var claim_g: int = mini(pending_claim_gems, 150)
	await _start_tx("claim_reward", {
		"type": "claim_reward",
		"address": wallet_address,
		"coinAmount": claim_c,
		"gemAmount": claim_g,
	})


func request_buy_skin(skin_key: String) -> void:
	if not _ensure_ready_for_tx():
		return
	await _start_tx("buy_skin", {
		"type": "buy_skin",
		"address": wallet_address,
		"skinKey": skin_key,
	})


func _ensure_ready_for_tx() -> bool:
	if is_tx_busy():
		open_companion_in_browser(active_tx_id)
		last_status_message = "Selesaikan transaksi yang sedang menunggu di MetaMask."
		state_changed.emit()
		return false
	if not bridge_online or not wallet_connected or wallet_address == "":
		last_status_message = "Hubungkan MetaMask terlebih dahulu."
		state_changed.emit()
		return false
	if not contracts_deployed:
		open_companion_in_browser()
		last_status_message = "Deploy kontrak Sepolia terlebih dahulu di browser companion."
		state_changed.emit()
		return false
	return true


func _start_tx(tx_type: String, payload: Dictionary) -> void:
	last_status_message = "Menyiapkan transaksi MetaMask..."
	state_changed.emit()

	var res := await _http_post_json("%s/api/tx/request" % BRIDGE_URL, payload)
	if not res.get("ok", false):
		var err_msg := String(res.get("error", "Gagal membuat permintaan transaksi."))
		last_status_message = err_msg
		tx_finished.emit(false, tx_type, err_msg)
		state_changed.emit()
		return

	var tx: Dictionary = res.get("tx", {})
	active_tx_id = String(tx.get("id", ""))
	active_tx_type = tx_type
	active_tx_status = String(tx.get("status", "waiting_wallet"))
	active_tx_label = String(tx.get("label", ""))
	active_tx_hash = ""
	active_tx_error = ""
	_active_tx_skin_key = String(payload.get("skinKey", "")) if tx_type == "buy_skin" else ""
	if tx_type == "buy_skin":
		last_bought_skin_key = ""
	last_status_message = "Konfirmasi di popup MetaMask pada browser..."
	open_companion_in_browser(active_tx_id)
	state_changed.emit()


func _on_poll_timer_timeout() -> void:
	if active_tx_id != "" and (active_tx_status == "waiting_wallet" or active_tx_status == "submitted"):
		await _poll_active_tx()
	elif is_waiting_connect or (bridge_online and not contracts_deployed) or (not bridge_online):
		await check_bridge_status()


func _poll_active_tx() -> void:
	if _poll_busy or active_tx_id == "":
		return
	_poll_busy = true
	var res := await _http_get_json("%s/api/tx/status?txId=%s" % [BRIDGE_URL, active_tx_id.uri_encode()])
	_poll_busy = false

	if not res.get("ok", false):
		return

	var tx: Dictionary = res.get("tx", {})
	var st := String(tx.get("status", ""))
	var tx_hash := String(tx.get("txHash", ""))
	var err_msg := String(tx.get("error", ""))

	if st == active_tx_status and tx_hash == active_tx_hash:
		return

	active_tx_status = st
	active_tx_hash = tx_hash
	active_tx_error = err_msg

	if st == "submitted":
		last_status_message = "Menunggu konfirmasi block Sepolia..."
		state_changed.emit()
	elif st == "confirmed":
		var finished_type := active_tx_type
		var params: Dictionary = tx.get("params", {})
		if finished_type == "claim_reward":
			var claimed_c: int = int(params.get("coinAmount", 0))
			var claimed_g: int = int(params.get("gemAmount", 0))
			pending_claim_coins = maxi(0, pending_claim_coins - claimed_c)
			pending_claim_gems = maxi(0, pending_claim_gems - claimed_g)
			_save_pending_rewards()
		elif finished_type == "buy_skin":
			var bought_key := String(params.get("skinKey", _active_tx_skin_key))
			last_bought_skin_key = bought_key
			if bought_key != "" and not onchain_owned_skins.has(bought_key):
				onchain_owned_skins.append(bought_key)

		_active_tx_skin_key = ""
		active_tx_id = ""
		last_status_message = "Transaksi Sepolia berhasil dikonfirmasi!"
		await refresh_profile()
		tx_finished.emit(true, finished_type, "Transaksi berhasil di Sepolia!")
		state_changed.emit()
	elif st == "rejected" or st == "failed":
		var failed_type := active_tx_type
		_active_tx_skin_key = ""
		active_tx_id = ""
		last_status_message = err_msg if err_msg != "" else "Transaksi dibatalkan / gagal."
		tx_finished.emit(false, failed_type, last_status_message)
		state_changed.emit()


func _load_pending_rewards() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		pending_claim_coins = int(config.get_value("web3", "pending_coins", 0))
		pending_claim_gems = int(config.get_value("web3", "pending_gems", 0))


func _save_pending_rewards() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("web3", "pending_coins", pending_claim_coins)
	config.set_value("web3", "pending_gems", pending_claim_gems)
	config.save(SAVE_PATH)


func _http_get_json(url: String) -> Dictionary:
	return await _http_request_json(url, HTTPClient.METHOD_GET, "")


func _http_post_json(url: String, payload: Dictionary) -> Dictionary:
	return await _http_request_json(url, HTTPClient.METHOD_POST, JSON.stringify(payload))


func _http_request_json(url: String, method: HTTPClient.Method, body_text: String) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 8.0
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var err := http.request(url, headers, method, body_text)
	if err != OK:
		http.queue_free()
		return {"ok": false, "error": "HTTP request init error: %d" % err}

	var result: Array = await http.request_completed
	http.queue_free()

	var req_result: int = int(result[0])
	var resp_code: int = int(result[1])
	var resp_body: PackedByteArray = result[3]
	if req_result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "Bridge tidak terjangkau (kode %d)" % req_result}

	var txt := resp_body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(txt)
	if not (parsed is Dictionary):
		return {"ok": false, "error": "Respons JSON tidak valid (HTTP %d)" % resp_code}
	return parsed as Dictionary
