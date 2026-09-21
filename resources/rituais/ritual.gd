extends Resource
class_name Ritual

## Dados de um ritual (feitiço) do SRD de Trilhas & Tesouros.
## Grandeza, dano e salvamento seguem os valores base (sem dado extra de canalização).

@export var nome: String = ""
@export var elemento: String = ""
@export var grandeza: int = 1
@export var descricao_alvo: String = ""
@export var efeito: String = ""
@export var requisito: String = "Nenhum"

@export_group("Dano")
@export var dano_dado: String = ""           # ex: "1d4". Vazio = ritual não causa dano direto.
@export var dano_secundario_dado: String = "" # ex: "1d4" no turno seguinte (Dardo de Espinho)

@export_group("Cura")
@export var cura_dado: String = ""            # ex: "1d6". Vazio = ritual não cura.

@export_group("Salvamento")
@export var atributo_salvamento: String = ""  # "CON", "DES", "VON" ou "" (nenhum)
@export var efeito_salvamento: String = ""
@export var salvamento_reduz_metade: bool = false  # true = passar no salvamento reduz o dano à metade (senão anula)

@export_group("Controle")
@export var imobiliza: bool = false

@export var custo_canalizacao: int = 1  # quanto do pool de canalização (mana) o ritual gasta
