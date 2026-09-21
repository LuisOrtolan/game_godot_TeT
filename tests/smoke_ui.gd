extends SceneTree

## Smoke test da UI de batalha, sem janela: instancia a cena, "clica" nos botões habilitados
## até o combate acabar e confere invariantes da apresentação.
##
## Rodar:
##   godot --headless --path . --script res://tests/smoke_ui.gd
##   godot --headless --path . --script res://tests/smoke_ui.gd -- --partidas=50
##   godot --headless --path . --script res://tests/smoke_ui.gd -- --partidas=3 --pausa=0.05
## `--pausa` liga as esperas com Timer entre as ações (default 0 = tudo síncrono).
##
## Exit code: 0 = tudo certo, 1 = alguma checagem falhou.
## Não valida o visual (layout, cores): isso só se vê abrindo o jogo.

const CENA := "res://scenes/batalha_ui.tscn"

var _falhas: Array[String] = []
var _pausa: float = 0.0


func _initialize() -> void:
	var partidas := 20
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--partidas="):
			partidas = arg.substr(11).to_int()
		elif arg.begins_with("--pausa="):
			_pausa = arg.substr(8).to_float()

	var cena := load(CENA) as PackedScene
	if cena == null:
		printerr("Não carregou %s" % CENA)
		quit(1)
		return

	var vitorias := 0
	for n in partidas:
		if await _jogar_uma(cena, n):
			vitorias += 1

	print("%d partida(s) pela UI: %d vitória(s), %d derrota(s)" % [partidas, vitorias, partidas - vitorias])
	if _falhas.is_empty():
		print("OK: nenhuma checagem falhou.")
		quit(0)
	else:
		for f in _falhas:
			printerr("FALHOU: " + f)
		quit(1)


## Joga uma partida clicando num botão habilitado aleatório. Retorna true se o jogador venceu.
func _jogar_uma(cena: PackedScene, n: int) -> bool:
	var ui := cena.instantiate()
	ui.pausa_entre_acoes = _pausa
	root.add_child(ui)
	await process_frame         # o _ready() da cena só roda depois de um frame
	var batalha: Batalha = ui.batalha
	if batalha == null:
		_falhar(n, "a cena não criou a Batalha no _ready()")
		ui.queue_free()
		return false
	var menu: HFlowContainer = ui.get_node("%MenuAcoes")
	var reiniciar: Button = ui.get_node("%BotaoReiniciar")

	var cliques := 0
	while not reiniciar.visible and cliques < 100:
		if not batalha.aguardando_jogador:
			_falhar(n, "batalha parou sem aguardar o jogador nem terminar (estado %s)" % Batalha.Estado.keys()[batalha.estado])
			break

		var habilitados: Array[Button] = []
		for b: Button in menu.get_children():
			var custo: int = b.get_meta("custo")
			var deveria_desabilitar := custo > batalha.jogador.canalizacao_atual
			if b.disabled != deveria_desabilitar:
				_falhar(n, "botão '%s' com disabled=%s, mas custo=%d e canalização=%d" % [
					b.text, b.disabled, custo, batalha.jogador.canalizacao_atual])
			if not b.disabled:
				habilitados.append(b)

		if habilitados.is_empty():
			_falhar(n, "nenhum botão habilitado (o cajado deveria estar sempre disponível)")
			break
		habilitados.pick_random().pressed.emit()
		cliques += 1

		# Logo após o clique a batalha ainda não devolveu a vez ao jogador (com pausa > 0 isso
		# leva alguns frames): os botões precisam estar desabilitados.
		if not batalha.aguardando_jogador and batalha.estado != Batalha.Estado.FIM_DE_BATALHA:
			for b: Button in menu.get_children():
				if not b.disabled:
					_falhar(n, "botão '%s' habilitado fora da vez do jogador" % b.text)
		while not batalha.aguardando_jogador and batalha.estado != Batalha.Estado.FIM_DE_BATALHA:
			await process_frame

	if not reiniciar.visible:
		_falhar(n, "a batalha não terminou em %d cliques" % cliques)
	if batalha.estado != Batalha.Estado.FIM_DE_BATALHA:
		_falhar(n, "UI mostra fim, mas o estado é %s" % Batalha.Estado.keys()[batalha.estado])

	# Barras e textos batem com o estado real.
	var barra_pv: ProgressBar = ui.get_node("%BarraPVJogador")
	var barra_inimigo: ProgressBar = ui.get_node("%BarraPVInimigo")
	var barra_mana: ProgressBar = ui.get_node("%BarraCanalizacao")
	if int(barra_pv.value) != batalha.jogador.pv_atual:
		_falhar(n, "barra de PV do jogador (%d) != estado (%d)" % [barra_pv.value, batalha.jogador.pv_atual])
	if int(barra_inimigo.value) != batalha.inimigo.pv_atual:
		_falhar(n, "barra de PV do inimigo (%d) != estado (%d)" % [barra_inimigo.value, batalha.inimigo.pv_atual])
	if int(barra_mana.value) != batalha.jogador.canalizacao_atual:
		_falhar(n, "barra de canalização (%d) != estado (%d)" % [barra_mana.value, batalha.jogador.canalizacao_atual])
	if (ui.get_node("%Log") as RichTextLabel).get_parsed_text().strip_edges().is_empty():
		_falhar(n, "log vazio")

	var venceu := batalha.vencedor() == Batalha.Lado.JOGADOR
	ui.queue_free()
	await process_frame  # deixa a cena sair da árvore antes da próxima partida
	return venceu


func _falhar(n: int, msg: String) -> void:
	_falhas.append("partida %d: %s" % [n, msg])
