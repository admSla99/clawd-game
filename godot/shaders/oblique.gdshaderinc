// 2.5D projection. The camera looks straight down -z (orthographic, see GameCamera); depth is drawn in
// vertex() by every 3D material:
// - Oblique: every point moves up by -z * OBLIQUE (OBLIQUE = tan(GameCamera.PITCH) = 1/3), so top faces
//   show as bands of 3 px of depth per view row, as if the camera were pitched down.
// - Perspective: a point `behind` metres behind its reference plane moves towards the view centre by
//   behind * PERSPECTIVE of its distance from it, so blocks right of the centre show their left side,
//   blocks left of it their right side, and top bands grow towards the bottom of the view and thin
//   towards the top. Nothing in front of the reference plane moves: for the level that plane is the
//   gameplay plane z = 0, so Clawd, the enemies and the block fronts (z = +1.5) stay exactly one level
//   pixel per view pixel. Faces crossing z = 0 must have vertices there (BoxMesh subdivide_depth,
//   Voxel.mesh() splits its side faces), since the mapping bends at z = 0.
// Fragment code keeps the real world position.
const float OBLIQUE = 1.0 / 3.0;
const float PERSPECTIVE = 0.03;

vec4 oblique_world(vec4 w, mat4 inv_view, float behind) {
	vec2 centre = inv_view[3].xy;
	w.xy -= behind * PERSPECTIVE * (w.xy - centre);
	w.y -= w.z * OBLIQUE;
	return w;
}

// Level geometry and sprites: the reference plane is the gameplay plane z = 0.
vec4 oblique_position(mat4 model, mat4 view, mat4 inv_view, mat4 projection, vec3 vertex) {
	vec4 w = model * vec4(vertex, 1.0);
	return projection * (view * oblique_world(w, inv_view, max(-w.z, 0.0)));
}
