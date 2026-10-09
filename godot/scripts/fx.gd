class_name Fx

## Emits through the level's Particles node (see particles.gd), with the options of
## particles.emit() in src/render/particles.ts.
static func burst(from: Node, at: Vector2, o: Dictionary) -> void:
	var p: Particles = from.get_tree().get_first_node_in_group("particles")
	if p:
		p.emit(at, o)

