extends RefCounted
class_name Batalha

## Lógica de combate por turnos, sem nenhuma dependência de UI ou de cena.
## É uma máquina de estados simples; quem quiser reagir (console, UI, som) conecta nos Signals.
##
## Regras assumidas pro MVP (não vêm prontas do SRD, ajustar livremente):
##  - Ataque de arma: d20 + bônus de ataque >= CA do alvo.
##  - Salvamento: d20 >= valor de salvamento do alvo (passou = resistiu).
##  - Dano de ritual com salvamento: falhou = dano cheio; passou = nada, ou metade se o
##    ritual tiver `salvamento_reduz_metade` (hoje só a Brasa Ancestral).
##  - Dardo de Espinho: se falhar no salvamento, o segundo dano cai no início do próximo turno do inimigo.
##  - Correia de Vinha: se falhar no salvamento, o inimigo perde o próximo turno.

enum Estado { INATIVO, TURNO_JOGADOR, TURNO_INIMIGO, RESOLVENDO_ACAO, FIM_DE_BATALHA }
enum Lado { JOGADOR, INIMIGO }

signal estado_mudou(novo: Estado)
signal turno_iniciado(lado: Lado)
## `resultado` é um Dictionary: {ator, alvo, acao, linhas: PackedStringArray, pv_jogador, pv_inimigo}
signal acao_resolvida(resultado: Dictionary)
signal turno_finalizado(lado: Lado)
signal batalha_terminada(vencedor: Lado)
## Emitido quando é a vez do jogador e não há `escolher_acao`: a UI responde com `enviar_acao()`.
signal aguardando_acao_jogador

var jogador: Personagem
var inimigo: Inimigo
var estado: Estado = Estado.INATIVO
var rodada: int = 0

## Formato de uma ação do jogador: {"tipo": "ritual", "ritual": Ritual} | {"tipo": "arma"} | {"tipo": "passar"}.
##
## Duas formas de o jogador decidir:
##  - síncrona: `escolher_acao` = Callable(batalha) -> Dictionary (IA do teste headless);
##  - assíncrona: sem `escolher_acao`, a batalha para em `aguardando_jogador`, emite
##    `aguardando_acao_jogador` e espera `enviar_acao()` (UI com botões).
var escolher_acao: Callable

## true enquanto a batalha está parada esperando o jogador clicar.
var aguardando_jogador: bool = false

var _rng := RandomNumberGenerator.new()
var _acao_pendente: Dictionary = {}
var _lado_atual: Lado = Lado.JOGADOR
var _veneno_pendente: String = ""   # dado do 2º dano do Dardo de Espinho, "" = nenhum
var _inimigo_imobilizado: bool = false


## Duplica os Resources: pv_atual/canalizacao_atual mudam durante a luta, e sem isso
## o .tres carregado ficaria "sujo" pro resto do processo.
func _init(p_jogador: Personagem, p_inimigo: Inimigo, seed_rng: int = 0) -> void:
	jogador = p_jogador.duplicate()
	inimigo = p_inimigo.duplicate()
	jogador.pv_atual = jogador.pv_maximo
	jogador.canalizacao_atual = jogador.canalizacao_maxima
	inimigo.pv_atual = inimigo.pv_maximo
	if seed_rng != 0:
		_rng.seed = seed_rng
	else:
		_rng.randomize()


func rng() -> RandomNumberGenerator:
	return _rng


## Roda a batalha inteira até alguém morrer. Retorna o vencedor.
## Só serve pro modo síncrono; se não houver `escolher_acao`, o jogador ataca com a arma.
func rodar() -> Lado:
	if not escolher_acao.is_valid():
		escolher_acao = func(_b: Batalha) -> Dictionary: return {"tipo": "arma"}
	while estado != Estado.FIM_DE_BATALHA:
		avancar()
	return vencedor()


## Executa UM passo da máquina de estados. A UI chama isso no ritmo que quiser
## (com pausas entre os passos); `rodar()` chama em loop sem pausa.
## Se a batalha ficar esperando o jogador, `aguardando_jogador` fica true e nada avança
## até `enviar_acao()`.
func avancar() -> void:
	if aguardando_jogador:
		return
	match estado:
		Estado.INATIVO:
			_mudar_estado(Estado.TURNO_JOGADOR)
		Estado.TURNO_JOGADOR:
			_turno_jogador()
		Estado.TURNO_INIMIGO:
			_turno_inimigo()
		Estado.RESOLVENDO_ACAO:
			_resolver_acao()


## Resposta assíncrona do jogador (ver `aguardando_acao_jogador`).
func enviar_acao(acao: Dictionary) -> void:
	if not aguardando_jogador:
		return
	aguardando_jogador = false
	_acao_pendente = acao
	_mudar_estado(Estado.RESOLVENDO_ACAO)


func vencedor() -> Lado:
	return Lado.JOGADOR if jogador.pv_atual > 0 else Lado.INIMIGO


func _mudar_estado(novo: Estado) -> void:
	estado = novo
	estado_mudou.emit(novo)


# --- Turno do jogador -------------------------------------------------------

func _turno_jogador() -> void:
	_lado_atual = Lado.JOGADOR
	rodada += 1
	turno_iniciado.emit(Lado.JOGADOR)
	if escolher_acao.is_valid():
		_acao_pendente = escolher_acao.call(self)
		_mudar_estado(Estado.RESOLVENDO_ACAO)
	else:
		aguardando_jogador = true
		aguardando_acao_jogador.emit()


# --- Turno do inimigo -------------------------------------------------------

func _turno_inimigo() -> void:
	_lado_atual = Lado.INIMIGO
	turno_iniciado.emit(Lado.INIMIGO)
	_acao_pendente = {"tipo": "ataque_inimigo"}
	_mudar_estado(Estado.RESOLVENDO_ACAO)


# --- Resolução (compartilhada pelos dois lados) -----------------------------

func _resolver_acao() -> void:
	var linhas := PackedStringArray()
	var ator := ""
	var alvo := ""
	var nome_acao := ""

	if _lado_atual == Lado.JOGADOR:
		ator = jogador.nome
		alvo = inimigo.nome
		match _acao_pendente.get("tipo", "passar"):
			"ritual":
				nome_acao = _acao_pendente["ritual"].nome
				_resolver_ritual(_acao_pendente["ritual"], linhas)
			"arma":
				nome_acao = jogador.arma_nome
				_resolver_ataque_jogador(linhas)
			_:
				nome_acao = "Passar"
				linhas.append("%s passa o turno." % ator)
	else:
		ator = inimigo.nome
		alvo = jogador.nome
		nome_acao = inimigo.nome_ataque
		_resolver_turno_inimigo(linhas)

	acao_resolvida.emit({
		"ator": ator, "alvo": alvo, "acao": nome_acao, "linhas": linhas,
		"pv_jogador": jogador.pv_atual, "pv_inimigo": inimigo.pv_atual,
	})
	turno_finalizado.emit(_lado_atual)

	if jogador.pv_atual <= 0 or inimigo.pv_atual <= 0:
		_mudar_estado(Estado.FIM_DE_BATALHA)
		batalha_terminada.emit(vencedor())
	elif _lado_atual == Lado.JOGADOR:
		_mudar_estado(Estado.TURNO_INIMIGO)
	else:
		_mudar_estado(Estado.TURNO_JOGADOR)


func _resolver_ataque_jogador(linhas: PackedStringArray) -> void:
	var d := Dados.d20(_rng)
	var total := d + jogador.bonus_ataque
	var acertou := total >= inimigo.ca
	linhas.append("Ataque com %s: d20=%d %s = %d vs CA %d -> %s" % [
		jogador.arma_nome, d, _fmt_bonus(jogador.bonus_ataque), total, inimigo.ca,
		"ACERTOU" if acertou else "errou"])
	if acertou:
		var dano := Dados.rolar(jogador.dano_arma, _rng)
		_aplicar_dano_inimigo(dano["total"], "%s [%s]" % [jogador.dano_arma, _fmt_rolagens(dano)], linhas)


func _resolver_ritual(ritual: Ritual, linhas: PackedStringArray) -> void:
	if jogador.canalizacao_atual < ritual.custo_canalizacao:
		linhas.append("Canalização insuficiente pra %s — o ritual falha." % ritual.nome)
		return
	jogador.canalizacao_atual -= ritual.custo_canalizacao
	linhas.append("%s conjura %s (canalização restante: %d/%d)" % [
		jogador.nome, ritual.nome, jogador.canalizacao_atual, jogador.canalizacao_maxima])

	if ritual.cura_dado != "":
		var cura := Dados.rolar(ritual.cura_dado, _rng)
		var antes := jogador.pv_atual
		jogador.pv_atual = mini(jogador.pv_maximo, jogador.pv_atual + cura["total"])
		linhas.append("Cura %s [%s] -> PV %d -> %d" % [
			ritual.cura_dado, _fmt_rolagens(cura), antes, jogador.pv_atual])
		return

	# Ritual ofensivo: salvamento do inimigo, se o ritual tiver um.
	var resistiu := false
	if ritual.atributo_salvamento != "":
		var d := Dados.d20(_rng)
		resistiu = d >= inimigo.salvamento_fisico
		linhas.append("Salvamento (%s) de %s: d20=%d vs %d -> %s" % [
			ritual.atributo_salvamento, inimigo.nome, d, inimigo.salvamento_fisico,
			"RESISTIU" if resistiu else "falhou"])

	var metade := ritual.salvamento_reduz_metade
	if resistiu and not metade:
		return

	if ritual.dano_dado != "":
		var dano := Dados.rolar(ritual.dano_dado, _rng)
		var valor: int = dano["total"]
		var desc := "%s [%s]" % [ritual.dano_dado, _fmt_rolagens(dano)]
		if resistiu and metade:
			valor = maxi(1, valor / 2)
			desc += " pela metade"
		_aplicar_dano_inimigo(valor, desc, linhas)

	if not resistiu:
		if ritual.dano_secundario_dado != "" and inimigo.pv_atual > 0:
			_veneno_pendente = ritual.dano_secundario_dado
			linhas.append("%s está envenenado: sofrerá %s no próximo turno." % [inimigo.nome, _veneno_pendente])
		if ritual.imobiliza and inimigo.pv_atual > 0:
			_inimigo_imobilizado = true
			linhas.append("%s está preso e perderá o próximo turno." % inimigo.nome)


func _resolver_turno_inimigo(linhas: PackedStringArray) -> void:
	# Efeitos que vencem no início do turno do inimigo.
	if _veneno_pendente != "":
		var veneno := Dados.rolar(_veneno_pendente, _rng)
		_veneno_pendente = ""
		_aplicar_dano_inimigo(veneno["total"], "veneno [%s]" % _fmt_rolagens(veneno), linhas)
		if inimigo.pv_atual <= 0:
			return

	if _inimigo_imobilizado:
		_inimigo_imobilizado = false
		linhas.append("%s está preso e perde o turno." % inimigo.nome)
		return

	var d := Dados.d20(_rng)
	var total := d + inimigo.bonus_ataque
	var acertou := total >= jogador.ca
	linhas.append("%s usa %s: d20=%d %s = %d vs CA %d -> %s" % [
		inimigo.nome, inimigo.nome_ataque, d, _fmt_bonus(inimigo.bonus_ataque), total, jogador.ca,
		"ACERTOU" if acertou else "errou"])
	if acertou:
		var dano := Dados.rolar(inimigo.dano_ataque, _rng)
		var antes := jogador.pv_atual
		jogador.pv_atual = maxi(0, jogador.pv_atual - dano["total"])
		linhas.append("Dano %s [%s] -> PV de %s: %d -> %d" % [
			inimigo.dano_ataque, _fmt_rolagens(dano), jogador.nome, antes, jogador.pv_atual])


# --- Helpers ----------------------------------------------------------------

func _aplicar_dano_inimigo(valor: int, descricao: String, linhas: PackedStringArray) -> void:
	var antes := inimigo.pv_atual
	inimigo.pv_atual = maxi(0, inimigo.pv_atual - valor)
	linhas.append("Dano %s = %d -> PV de %s: %d -> %d" % [descricao, valor, inimigo.nome, antes, inimigo.pv_atual])


static func _fmt_rolagens(dano: Dictionary) -> String:
	return ",".join(PackedStringArray((dano["rolagens"] as Array).map(str)))


static func _fmt_bonus(b: int) -> String:
	return "%+d" % b
