// 2.5D oblique projection. The camera looks straight down -z (orthographic, see GameCamera); depth is
// drawn by moving every point up by -z * OBLIQUE (OBLIQUE = tan(GameCamera.PITCH) = 1/3), so top faces
// show as bands of 3 px of depth per view row and one level pixel stays exactly one view pixel on both
// axes (a pitched orthographic camera would foreshorten one axis). Every 3D material calls this from
// vertex(); fragment code keeps the real world position.
const float OBLIQUE = 1.0 / 3.0;

vec4 oblique_position(mat4 model, mat4 view, mat4 projection, vec3 vertex) {
	vec4 w = model * vec4(vertex, 1.0);
	w.y -= w.z * OBLIQUE;
	return projection * (view * w);
}
