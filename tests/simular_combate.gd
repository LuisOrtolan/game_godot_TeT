extends SceneTree

## Simula 1 combate Xamã de Teste vs Cão, sem cena nenhuma, imprimindo cada turno no console.
##
## Rodar:
##   godot --headless --path . --script res://tests/simular_combate.gd
##   godot --headless --path . --script res://tests/simular_combate.gd -- --seed=42
##
## Exit code: 0 = jogador venceu, 1 = inimigo venceu, 2 = erro ao carregar/simular.

const XAMA := "res://resources/personagens/xama_teste.tres"
const CAO := "res://resources/inimigos/cao.tres"


func _init() -> void:
	var seed_rng := _ler_seed()
	var personagem := load(XAMA) as Personagem
	var inimigo := load(CAO) as Inimigo
	if personagem == null or inimigo == null:
		printerr("Falha ao carregar os Resources de teste.")
		quit(2)
		return

	var batalha := Batalha.new(personagem, inimigo, seed_rng)
	batalha.escolher_acao = _ia_jogador
	_conectar_console(batalha)

	print("=== %s (PV %d, CA %d) vs %s (PV %d, CA %d) | seed=%d ===" % [
		batalha.jogador.nome, batalha.jogador.pv_maximo, batalha.jogador.ca,
		batalha.inimigo.nome, batalha.inimigo.pv_maximo, batalha.inimigo.ca,
		seed_rng])

	var vencedor := batalha.rodar()
	_desconectar_tudo(batalha)
	quit(0 if vencedor == Batalha.Lado.JOGADOR else 1)


## Os lambdas capturam `batalha` e ela guarda os lambdas (referência circular; RefCounted
## não coleta ciclo). Desfazer as conexões antes de sair evita o aviso de vazamento.
func _desconectar_tudo(batalha: Batalha) -> void:
	for nome_signal in ["estado_mudou", "turno_iniciado", "acao_resolvida", "turno_finalizado", "batalha_terminada"]:
		for conexao in batalha.get_signal_connection_list(nome_signal):
			batalha.disconnect(nome_signal, conexao["callable"])
	batalha.escolher_acao = Callable()


func _ler_seed() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			return arg.substr(7).to_int()
	return randi_range(1, 999999)  # sempre imprime a seed, pra dar pra reproduzir


## IA de teste do jogador: cura se PV baixo, senão usa um ritual ofensivo sorteado;
## sem canalização, cai no cajado. Só existe pra o teste rodar sozinho.
func _ia_jogador(batalha: Batalha) -> Dictionary:
	var p := batalha.jogador
	var curas: Array[Ritual] = []
	var ofensivos: Array[Ritual] = []
	for r in p.rituais:
		if r.custo_canalizacao > p.canalizacao_atual:
			continue
		if r.cura_dado != "":
			curas.append(r)
		else:
			ofensivos.append(r)

	if p.pv_atual <= p.pv_maximo / 2 and not curas.is_empty():
		return {"tipo": "ritual", "ritual": curas[0]}
	if not ofensivos.is_empty():
		var i := batalha.rng().randi_range(0, ofensivos.size() - 1)
		return {"tipo": "ritual", "ritual": ofensivos[i]}
	return {"tipo": "arma"}


func _conectar_console(batalha: Batalha) -> void:
	batalha.estado_mudou.connect(func(novo: Batalha.Estado) -> void:
		print("  [estado] -> %s" % Batalha.Estado.keys()[novo]))
	batalha.turno_iniciado.connect(func(lado: Batalha.Lado) -> void:
		if lado == Batalha.Lado.JOGADOR:
			print("\n--- Rodada %d ---" % batalha.rodada)
		print("Turno de %s" % (batalha.jogador.nome if lado == Batalha.Lado.JOGADOR else batalha.inimigo.nome)))
	batalha.acao_resolvida.connect(func(r: Dictionary) -> void:
		for linha in r["linhas"]:
			print("  " + linha)
		print("  PV: %s %d/%d | %s %d/%d | canalização %d/%d" % [
			batalha.jogador.nome, r["pv_jogador"], batalha.jogador.pv_maximo,
			batalha.inimigo.nome, r["pv_inimigo"], batalha.inimigo.pv_maximo,
			batalha.jogador.canalizacao_atual, batalha.jogador.canalizacao_maxima]))
	batalha.batalha_terminada.connect(func(vencedor: Batalha.Lado) -> void:
		var nome := batalha.jogador.nome if vencedor == Batalha.Lado.JOGADOR else batalha.inimigo.nome
		print("\n=== FIM: %s venceu em %d rodada(s) ===" % [nome, batalha.rodada]))
