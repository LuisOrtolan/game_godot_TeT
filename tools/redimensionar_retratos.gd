extends SceneTree

## Gera as cópias de retrato usadas no jogo a partir dos originais em `arte/retratos/`.
## Originais (2000x2000) ficam fora do import (arte/.gdignore); o jogo usa as cópias de
## `assets/retratos/`, bem menores, pra não inflar o export Web nem a memória de textura.
##
## Rodar (depois de adicionar/trocar um retrato em arte/retratos/):
##   godot --headless --path . --script res://tools/redimensionar_retratos.gd
## e em seguida `godot --headless --path . --import` pro Godot importar as cópias novas.

const ORIGEM := "res://arte/retratos"
const DESTINO := "res://assets/retratos"
const LADO := 512
const QUALIDADE := 0.9


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DESTINO))
	var feitos := 0
	for arquivo in DirAccess.get_files_at(ORIGEM):
		if arquivo.get_extension().to_lower() not in ["jpg", "jpeg", "png", "webp"]:
			continue
		var img := Image.load_from_file("%s/%s" % [ORIGEM, arquivo])
		if img == null or img.is_empty():
			printerr("Falha ao abrir %s" % arquivo)
			quit(1)
			return
		img.resize(LADO, LADO, Image.INTERPOLATE_LANCZOS)
		var saida := "%s/%s.jpg" % [DESTINO, arquivo.get_basename()]
		var erro := img.save_jpg(saida, QUALIDADE)
		if erro != OK:
			printerr("Falha ao salvar %s (erro %d)" % [saida, erro])
			quit(1)
			return
		print("%s -> %s (%dx%d)" % [arquivo, saida, LADO, LADO])
		feitos += 1
	print("%d retrato(s) gerado(s)." % feitos)
	quit(0)
