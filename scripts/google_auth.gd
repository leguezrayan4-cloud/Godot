extends Node
## OAuth 2.0 Google (autoload « GoogleAuth ») : flux PKCE avec redirection loopback.
##
## Nécessite un Client ID OAuth (type « application de bureau ») créé dans la
## console Google Cloud, à renseigner dans les Réglages. Sans identifiant, un
## mode démo clairement étiqueté est utilisé (aucune requête réseau).
##
## Remarque : la redirection loopback (127.0.0.1) fonctionne sur ordinateur ;
## sur mobile, elle nécessite un schéma d'URI personnalisé côté application.

signal flow_state(state: String)

const AUTH_ENDPOINT := "https://accounts.google.com/o/oauth2/v2/auth"
const TOKEN_ENDPOINT := "https://oauth2.googleapis.com/token"
const USERINFO_ENDPOINT := "https://www.googleapis.com/oauth2/v3/userinfo"
const SCOPE := "openid email profile"

var client_id: String = ""
var client_secret: String = ""

var _server: TCPServer
var _port: int = 0
var _verifier: String = ""
var _state: String = ""


func configured() -> bool:
	return not client_id.strip_edges().is_empty()


func set_credentials(id: String, secret: String = "") -> void:
	client_id = id.strip_edges()
	client_secret = secret.strip_edges()


## Lance la connexion. À attendre. Renvoie {ok, email, name, demo, error}.
func sign_in() -> Dictionary:
	if not configured():
		return await _demo_sign_in()

	flow_state.emit("Ouverture du navigateur…")
	_verifier = _random_urlsafe(64)
	_state = _random_urlsafe(16)
	if not _listen_free():
		return {"ok": false, "error": "Impossible d'ouvrir un port local."}
	var redirect := "http://127.0.0.1:%d" % _port

	var params := {
		"client_id": client_id,
		"redirect_uri": redirect,
		"response_type": "code",
		"scope": SCOPE,
		"code_challenge": _code_challenge(_verifier),
		"code_challenge_method": "S256",
		"state": _state,
		"access_type": "offline",
		"prompt": "select_account",
	}
	OS.shell_open(AUTH_ENDPOINT + "?" + _encode_params(params))

	flow_state.emit("En attente de l'autorisation…")
	var received := await _wait_for_callback()
	if is_instance_valid(_server):
		_server.stop()
	_server = null
	if not received.get("ok", false):
		return received
	if str(received.get("state", "")) != _state:
		return {"ok": false, "error": "État OAuth invalide (possible attaque CSRF)."}

	flow_state.emit("Échange du jeton…")
	var token_res := await _exchange_code(str(received.get("code", "")), redirect)
	if not token_res.get("ok", false):
		return token_res

	flow_state.emit("Récupération du profil…")
	var profile := await _fetch_profile(str(token_res.get("access_token", "")))
	if not profile.get("ok", false):
		return profile

	var info: Dictionary = profile.get("info", {})
	return {
		"ok": true,
		"demo": false,
		"email": str(info.get("email", "")),
		"name": str(info.get("name", info.get("email", "Compte Google"))),
	}


func _demo_sign_in() -> Dictionary:
	flow_state.emit("Mode démo (aucun Client ID configuré)")
	await get_tree().create_timer(0.9).timeout
	return {"ok": true, "demo": true, "email": "utilisateur@gmail.com", "name": "Compte Google"}


func _listen_free() -> bool:
	for _i in range(24):
		var port: int = randi_range(49152, 65535)
		var server := TCPServer.new()
		if server.listen(port, "127.0.0.1") == OK:
			_server = server
			_port = port
			return true
	return false


func _wait_for_callback() -> Dictionary:
	var deadline: int = Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.2).timeout
		if _server == null:
			break
		if _server.is_connection_available():
			var peer: StreamPeerTCP = _server.take_connection()
			var guard: int = 0
			while peer.get_available_bytes() < 4 and guard < 60:
				await get_tree().create_timer(0.05).timeout
				guard += 1
			var request := peer.get_utf8_string(peer.get_available_bytes())
			_respond(peer)
			peer.disconnect_from_host()
			return _parse_callback(request)
	return {"ok": false, "error": "Délai d'autorisation dépassé."}


func _parse_callback(request: String) -> Dictionary:
	var lines := request.split("\r\n", false)
	if lines.is_empty():
		return {"ok": false, "error": "Réponse invalide du navigateur."}
	var parts := lines[0].split(" ")
	if parts.size() < 2:
		return {"ok": false, "error": "Réponse invalide du navigateur."}
	var target: String = parts[1]
	var query := ""
	var q := target.find("?")
	if q != -1:
		query = target.substr(q + 1)
	var params := {}
	for pair in query.split("&", false):
		var kv := pair.split("=", false)
		if kv.size() == 2:
			params[kv[0]] = kv[1].uri_decode()
	if params.has("error"):
		return {"ok": false, "error": "Autorisation refusée : %s" % params["error"]}
	if not params.has("code"):
		return {"ok": false, "error": "Aucun code reçu."}
	return {"ok": true, "code": params["code"], "state": params.get("state", "")}


func _respond(peer: StreamPeerTCP) -> void:
	var html := "<html><body style='font-family:sans-serif;background:#0F1116;color:#eee;text-align:center;padding-top:80px'><h2>MyTaskUp</h2><p>Connexion réussie — vous pouvez fermer cette fenêtre.</p></body></html>"
	var body := html.to_utf8_buffer()
	var header := "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % body.size()
	peer.put_data((header + html).to_utf8_buffer())


func _exchange_code(code: String, redirect: String) -> Dictionary:
	var fields := {
		"code": code,
		"client_id": client_id,
		"grant_type": "authorization_code",
		"redirect_uri": redirect,
		"code_verifier": _verifier,
	}
	if not client_secret.is_empty():
		fields["client_secret"] = client_secret
	return await _http_form(TOKEN_ENDPOINT, fields)


func _fetch_profile(access_token: String) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)
	var headers := PackedStringArray(["Authorization: Bearer " + access_token])
	if http.request(USERINFO_ENDPOINT, headers, HTTPClient.METHOD_GET) != OK:
		http.queue_free()
		return {"ok": false, "error": "Requête profil impossible."}
	var result: Array = await http.request_completed
	http.queue_free()
	var code: int = result[1]
	var body: PackedByteArray = result[3]
	if code != 200:
		return {"ok": false, "error": "Profil indisponible (HTTP %d)." % code}
	var info: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(info) != TYPE_DICTIONARY:
		return {"ok": false, "error": "Profil illisible."}
	return {"ok": true, "info": info}


func _http_form(url: String, fields: Dictionary) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/x-www-form-urlencoded"])
	if http.request(url, headers, HTTPClient.METHOD_POST, _encode_params(fields)) != OK:
		http.queue_free()
		return {"ok": false, "error": "Requête réseau impossible."}
	var result: Array = await http.request_completed
	http.queue_free()
	var code: int = result[1]
	var body: PackedByteArray = result[3]
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if code != 200:
		var detail := ""
		if typeof(parsed) == TYPE_DICTIONARY:
			detail = " (%s)" % str(parsed.get("error", ""))
		return {"ok": false, "error": "Échec de l'échange de jeton (HTTP %d)%s." % [code, detail]}
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": "Réponse du serveur illisible."}
	return {"ok": true, "access_token": str(parsed.get("access_token", ""))}


func _encode_params(params: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in params:
		parts.append("%s=%s" % [str(key).uri_encode(), str(params[key]).uri_encode()])
	return "&".join(parts)


func _code_challenge(verifier: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(verifier.to_utf8_buffer())
	return _b64url(ctx.finish())


func _random_urlsafe(size: int) -> String:
	return _b64url(Crypto.new().generate_random_bytes(size))


func _b64url(data: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(data).replace("+", "-").replace("/", "_").replace("=", "")