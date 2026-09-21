extends Resource
class_name Inimigo

## Ficha de um inimigo, no formato reduzido do Bestiário (HD, CA, ataque, moral).

@export var nome: String = ""
@export var dados_de_vida: String = "1"

@export_group("Pontos de Vida")
@export var pv_maximo: int = 1
@export var pv_atual: int = 1

@export_group("Combate")
@export var ca: int = 10
@export var bonus_ataque: int = 0
@export var nome_ataque: String = "Ataque"
@export var dano_ataque: String = "1d4"

@export_group("Salvamentos")
@export var salvamento_fisico: int = 15
@export var salvamento_mental: int = 16

@export_group("Outros")
@export var movimento: int = 60
@export var moral: int = 6
@export var especial: String = ""
