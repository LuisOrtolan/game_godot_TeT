extends Resource
class_name Personagem

## Ficha de um personagem jogável (trilha), reduzida ao que o combate do MVP precisa.
## Atributos e salvamentos seguem o SRD de Trilhas & Tesouros; canalização é
## simplificada pro MVP: um pool de pontos (mana) por combate, onde cada ritual
## gasta `custo_canalizacao`, sem depleção aleatória.

@export var nome: String = ""
@export var trilha: String = ""
@export var retrato: Texture2D  # arte estática de UI (assets/retratos/)
@export var nivel: int = 1

@export_group("Pontos de Vida")
@export var pv_maximo: int = 1
@export var pv_atual: int = 1

@export_group("Combate")
@export var ca: int = 10
@export var bonus_ataque: int = 0
@export var arma_nome: String = ""
@export var dano_arma: String = ""

@export_group("Atributos")
@export var forca: int = 10
@export var destreza: int = 10
@export var constituicao: int = 10
@export var inteligencia: int = 10
@export var vontade: int = 10
@export var carisma: int = 10

@export_group("Salvamentos")
@export var salvamento_fisico: int = 16
@export var salvamento_mental: int = 16

@export_group("Canalização")
@export var canalizacao_maxima: int = 10
@export var canalizacao_atual: int = 10

@export_group("Rituais")
@export var rituais: Array[Ritual] = []
