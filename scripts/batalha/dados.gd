extends RefCounted
class_name Dados

## Rolagem de dados no formato "XdY" ou "XdY+Z" (ex: "1d4", "2d6+1").
## Recebe o RandomNumberGenerator de fora pra que a batalha possa ser reproduzida com seed.

## Retorna {"total": int, "rolagens": Array[int], "bonus": int, "notacao": String}.
static func rolar(notacao: String, rng: RandomNumberGenerator) -> Dictionary:
	var regex := RegEx.new()
	regex.compile("^\\s*(\\d+)d(\\d+)\\s*([+-]\\s*\\d+)?\\s*$")
	var m := regex.search(notacao)
	if m == null:
		push_error("Notação de dado inválida: '%s'" % notacao)
		return {"total": 0, "rolagens": [], "bonus": 0, "notacao": notacao}

	var quantidade := m.get_string(1).to_int()
	var faces := m.get_string(2).to_int()
	var bonus := 0
	if m.get_string(3) != "":
		bonus = m.get_string(3).replace(" ", "").to_int()

	var rolagens: Array[int] = []
	var total := bonus
	for i in quantidade:
		var r := rng.randi_range(1, faces)
		rolagens.append(r)
		total += r
	return {"total": total, "rolagens": rolagens, "bonus": bonus, "notacao": notacao}


static func d20(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(1, 20)
