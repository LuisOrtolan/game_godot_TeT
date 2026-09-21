extends Control

## UI de batalha (placeholder): só apresenta o estado da `Batalha` e converte cliques em ações.
## Toda a regra de combate vive em `Batalha`; aqui só ouvimos os Signals e atualizamos os nós.
## Fluxo: a UI chama `batalha.avancar()` com uma pausa entre as ações, até a batalha parar
## esperando o jogador (`aguardando_acao_jogador`); o clique num botão chama `enviar_acao()`.

const XAMA := "res://resources/personagens/xama_teste.tres"
const CAO := "res://resources/inimigos/cao.tres"

## Pausa (segundos) depois de cada ação resolvida, pra dar tempo de ler o log.
@export var pausa_entre_acoes: float = 0.8

var batalha: Batalha

var _botoes: Array[Button] = []
var _pausar: bool = false  # true = a última etapa resolveu uma ação (vale a pausa)

@onready var _indicador_turno: Label = %IndicadorTurno
@onready var _retrato_inimigo: TextureRect = %RetratoInimigo
@onready var _nome_inimigo: Label = %NomeInimigo
@onready var _barra_pv_inimigo: ProgressBar = %BarraPVInimigo
@onready var _texto_pv_inimigo: Label = %TextoPVInimigo
@onready var _retrato_jogador: TextureRect = %RetratoJogador
@onready var _nome_jogador: Label = %NomeJogador
@onready var _barra_pv_jogador: ProgressBar = %BarraPVJogador
@onready var _texto_pv_jogador: Label = %TextoPVJogador
@onready var _barra_canalizacao: ProgressBar = %BarraCanalizacao
@onready var _texto_canalizacao: Label = %TextoCanalizacao
@onready var _log: RichTextLabel = %Log
@onready var _menu_acoes: HFlowContainer = %MenuAcoes
@onready var _botao_reiniciar: Button = %BotaoReiniciar


func _ready() -> void:
	var personagem := load(XAMA) as Personagem
	var inimigo := load(CAO) as Inimigo
	batalha = Batalha.new(personagem, inimigo)

	batalha.turno_iniciado.connect(_ao_iniciar_turno)
	batalha.aguardando_acao_jogador.connect(_ao_aguardar_jogador)
	batalha.acao_resolvida.connect(_ao_resolver_acao)
	batalha.batalha_terminada.connect(_ao_terminar)
	_botao_reiniciar.pressed.connect(func() -> void: get_tree().reload_current_scene())

	_retrato_jogador.texture = batalha.jogador.retrato
	_retrato_inimigo.texture = batalha.inimigo.retrato
	_nome_jogador.text = batalha.jogador.nome
	_nome_inimigo.text = batalha.inimigo.nome
	_montar_menu()
	_atualizar_barras()
	_escrever_log("=== %s vs %s ===" % [batalha.jogador.nome, batalha.inimigo.nome])
	_executar()


## Um botão por ritual (lido de `personagem.rituais`) + o ataque com a arma.
func _montar_menu() -> void:
	for ritual in batalha.jogador.rituais:
		var b := Button.new()
		b.text = "%s (%d)" % [ritual.nome, ritual.custo_canalizacao]
		b.tooltip_text = ritual.efeito
		b.set_meta("custo", ritual.custo_canalizacao)
		b.pressed.connect(_ao_escolher.bind({"tipo": "ritual", "ritual": ritual}))
		_menu_acoes.add_child(b)
		_botoes.append(b)

	var arma := Button.new()
	arma.text = "%s (sem custo)" % batalha.jogador.arma_nome
	arma.tooltip_text = "Ataque com a arma: %s" % batalha.jogador.dano_arma
	arma.set_meta("custo", 0)
	arma.pressed.connect(_ao_escolher.bind({"tipo": "arma"}))
	_menu_acoes.add_child(arma)
	_botoes.append(arma)

	_habilitar_menu(false)


## Avança a batalha, com pausa depois de cada ação, até ela pedir a decisão do jogador
## (ou terminar). Com `pausa_entre_acoes = 0` roda sem esperar (usado pelo teste headless).
func _executar() -> void:
	while batalha.estado != Batalha.Estado.FIM_DE_BATALHA:
		_pausar = false
		batalha.avancar()
		if batalha.aguardando_jogador:
			return
		if _pausar and pausa_entre_acoes > 0.0:
			await get_tree().create_timer(pausa_entre_acoes).timeout


func _ao_escolher(acao: Dictionary) -> void:
	if not batalha.aguardando_jogador:
		return
	_habilitar_menu(false)
	batalha.enviar_acao(acao)
	_executar()


# --- Reações aos Signals da Batalha -----------------------------------------

func _ao_iniciar_turno(lado: Batalha.Lado) -> void:
	if lado == Batalha.Lado.JOGADOR:
		_indicador_turno.text = "Rodada %d — sua vez" % batalha.rodada
	else:
		_indicador_turno.text = "Rodada %d — turno de %s" % [batalha.rodada, batalha.inimigo.nome]


func _ao_aguardar_jogador() -> void:
	_habilitar_menu(true)


func _ao_resolver_acao(r: Dictionary) -> void:
	_pausar = true
	_escrever_log("\n%s -> %s" % [r["ator"], r["acao"]])
	for linha in r["linhas"]:
		_escrever_log("  " + linha)
	_atualizar_barras()


func _ao_terminar(vencedor: Batalha.Lado) -> void:
	_habilitar_menu(false)
	var venceu := vencedor == Batalha.Lado.JOGADOR
	_indicador_turno.text = "VITÓRIA!" if venceu else "DERROTA..."
	_escrever_log("\n=== %s ===" % ("Você venceu" if venceu else "Você foi derrotado"))
	_botao_reiniciar.visible = true


# --- Helpers de apresentação ------------------------------------------------

## Liga/desliga o menu. Ao ligar, desabilita rituais que a canalização atual não paga.
func _habilitar_menu(ativo: bool) -> void:
	for b in _botoes:
		b.disabled = not ativo or b.get_meta("custo") > batalha.jogador.canalizacao_atual


func _atualizar_barras() -> void:
	var j := batalha.jogador
	var i := batalha.inimigo
	_barra_pv_jogador.max_value = j.pv_maximo
	_barra_pv_jogador.value = j.pv_atual
	_texto_pv_jogador.text = "PV %d/%d" % [j.pv_atual, j.pv_maximo]
	_barra_canalizacao.max_value = j.canalizacao_maxima
	_barra_canalizacao.value = j.canalizacao_atual
	_texto_canalizacao.text = "Canalização %d/%d" % [j.canalizacao_atual, j.canalizacao_maxima]
	_barra_pv_inimigo.max_value = i.pv_maximo
	_barra_pv_inimigo.value = i.pv_atual
	_texto_pv_inimigo.text = "PV %d/%d" % [i.pv_atual, i.pv_maximo]


## `add_text` (não `append_text`): o log tem colchetes tipo "[3]" que o BBCode interpretaria.
func _escrever_log(texto: String) -> void:
	_log.add_text(texto + "\n")
