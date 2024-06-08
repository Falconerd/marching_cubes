package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

sunlight_dir := linalg.normalize([3]f32{0.3, 0.8, 0.3})
ambient_light: f32 = 0.2
adjust_color := proc(n: [3]f32, c: rl.Color) -> rl.Color {
	intensity := linalg.dot(n, sunlight_dir) * 50.00
	intensity = math.max(0, intensity)
	intensity = intensity * (1.0 - ambient_light) + ambient_light
	r := u8(linalg.clamp(f32(f32(c.r) / 255.0) * intensity, 0, 1) * 255)
	g := u8(linalg.clamp(f32(f32(c.g) / 255.0) * intensity, 0, 1) * 255)
	b := u8(linalg.clamp(f32(f32(c.b) / 255.0) * intensity, 0, 1) * 255)
	return {r, g, b, c.a}
}

scalar_field_size := [3]i32{3, 3, 3}
scalar_field := []f32 {
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
}

coords_from_index :: proc(index: i32, size: [3]i32) -> [3]i32 {
	return {index % size.x, (index / size.x) % size.y, index / (size.x * size.y)}
}

pos_from_index :: proc(index: i32, size: [3]i32) -> [3]f32 {
	return {f32(index % size.x), f32((index / size.x) % size.y), f32(index / (size.x * size.y))}
}

index_from_coords :: proc(coords: [3]i32, size: [3]i32) -> i32 {
	return coords.x + coords.y * size.x + coords.z * size.x * size.y
}

cube_from_cube_index :: proc(
	index: i32,
	size: [3]i32,
	allocator := context.allocator,
) -> (
	[]i32,
	bool,
) {
	return {}, false
}

cube_indices_from_cube_coords :: proc(
	coords: [3]i32,
	size: [3]i32,
	allocator := context.allocator,
) -> []i32 {
	base_index := index_from_coords(coords, size)
	indices := make([]i32, 8, allocator)
	indices[0] = base_index
	indices[1] = base_index + 1
	indices[2] = base_index + 1 + size.x
	indices[3] = base_index + size.x
	indices[4] = base_index + size.x * size.y
	indices[5] = base_index + 1 + size.x * size.y
	indices[6] = base_index + 1 + size.x * (size.y + 1)
	indices[7] = base_index + size.x * (size.y + 1)
	return indices[:]
}

vertex_interpolate :: proc(sf: []f32, size: [3]i32, index_a, index_b: i32) -> [3]f32 {
	a := pos_from_index(index_a, size)
	b := pos_from_index(index_b, size)
	r := sf[index_a]
	s := sf[index_b]
	if math.abs(-r) < 0.00001 do return a
	if math.abs(-s) < 0.00001 do return b
	if math.abs(r - s) < 0.00001 do return a
	mu := -r / (s - r)
	return {a.x + mu * (b.x - a.x), a.y + mu * (b.y - a.y), a.z + mu * (b.z - a.z)}
	// return (a + b) / 2
}

polygonize :: proc(
	sf: []f32,
	indices: []i32,
	size: [3]i32,
	allocator := context.allocator,
) -> [][3][3]f32 {
	cube_index := 0
	for i: u64 = 0; i < 8; i += 1 {
		if (sf[indices[i]] < 0) {
			cube_index |= 1 << i
		}
	}
	vertices := make([dynamic][3]f32, allocator)

	if edge_table[cube_index] == 0 {
		return {}
	}
	// Should check powers of 2 for optimisation
	// if EDGE_TABLE[cube_index] & 1 > 0 do append(&vertices, vertex_interpolate(voxels, indices[0], indices[1]))
	// if EDGE_TABLE[cube_index] & 2 > 0 do append(&vertices, vertex_interpolate(voxels, indices[1], indices[2]))
	// ...
	// FIXME: I don't know why the lookup is getting out of bounds triangles
	// I'll have to really break down the whole algorith more
	append(&vertices, vertex_interpolate(sf, size, indices[0], indices[1]))
	append(&vertices, vertex_interpolate(sf, size, indices[1], indices[2]))
	append(&vertices, vertex_interpolate(sf, size, indices[2], indices[3]))
	append(&vertices, vertex_interpolate(sf, size, indices[3], indices[0]))
	append(&vertices, vertex_interpolate(sf, size, indices[4], indices[5]))
	append(&vertices, vertex_interpolate(sf, size, indices[5], indices[6]))
	append(&vertices, vertex_interpolate(sf, size, indices[6], indices[7]))
	append(&vertices, vertex_interpolate(sf, size, indices[7], indices[4]))
	append(&vertices, vertex_interpolate(sf, size, indices[0], indices[4]))
	append(&vertices, vertex_interpolate(sf, size, indices[1], indices[5]))
	append(&vertices, vertex_interpolate(sf, size, indices[2], indices[6]))
	append(&vertices, vertex_interpolate(sf, size, indices[3], indices[7]))

	triangles := make([dynamic][3][3]f32, allocator)

	for i := 0; triangle_table[cube_index][i] != -1; i += 3 {
		append(
			&triangles,
			[3][3]f32 {
				vertices[triangle_table[cube_index][i + 0]],
				vertices[triangle_table[cube_index][i + 1]],
				vertices[triangle_table[cube_index][i + 2]],
			},
		)
	}

	return triangles[:]
}

triangle_normal :: proc(t: [3][3]f32) -> [3]f32 {
	u := t.y - t.x
	v := t.z - t.x
	n := linalg.cross(u, v)
	return linalg.normalize(n)
}

main :: proc() {
	rl.InitWindow(1080, 720, "Marching Cubes")

	camera := rl.Camera {
		position   = {-2, 1, -2},
		target     = {0, 0, 0},
		up         = {0, 1, 0},
		fovy       = 85,
		projection = rl.CameraProjection.PERSPECTIVE,
	}

	rl.DisableCursor()
	rl.SetTargetFPS(60)

	render_texture := rl.LoadRenderTexture(640, 360)
	defer rl.UnloadRenderTexture(render_texture)

	cube_count := (scalar_field_size.x - 1) * (scalar_field_size.y - 1) * (scalar_field_size.z - 1)

	cube_index: i32 = 0
	current_coords := [3]i32{}
	cube := cube_indices_from_cube_coords(current_coords, scalar_field_size)
	triangles := make([dynamic][3][3]f32)
	append(&triangles, ..polygonize(scalar_field, cube, scalar_field_size))

	fmt.println(triangles)

	for !rl.WindowShouldClose() {
		if rl.IsKeyPressed(rl.KeyboardKey.N) {
			if cube_index < cube_count - 1 {
				cube_index += 1
			}
			current_coords = coords_from_index(cube_index, scalar_field_size - {1, 1, 1})
			cube = cube_indices_from_cube_coords(current_coords, scalar_field_size)
			append(&triangles, ..polygonize(scalar_field, cube, scalar_field_size))

			fmt.println(triangles)
		}

		rl.UpdateCamera(&camera, rl.CameraMode.FREE)

		rl.BeginTextureMode(render_texture)
		{
			rl.ClearBackground(rl.BLACK)

			rl.BeginMode3D(camera)
			{
				rl.DrawGrid(32, 1)

				for v, i in scalar_field {
					pos := pos_from_index(i32(i), scalar_field_size)
					rl.DrawCube(pos, 0.1, 0.1, 0.1, {200, 200, 200, 255})
				}

				for i in cube {
					rl.DrawCube(pos_from_index(i, scalar_field_size), 0.15, 0.15, 0.15, rl.RED)
				}

				for t in triangles {
					normal := triangle_normal(t)
					rl.DrawTriangle3D(t.x, t.y, t.z, adjust_color(normal, {0, 255, 255, 255}))
				}

				// for i in 0 ..< cube_count {
				// 	pos := pos_from_index(i32(i), scalar_field_size - {1, 1, 1})
				// 	rl.DrawCube(pos + {0.5, 0.5, 0.5}, 0.1, 0.1, 0.1, {0, 255, 255, 100})
				// }
				rl.DrawLine3D({}, {1, 0, 0}, rl.RED)
				rl.DrawLine3D({}, {0, 1, 0}, rl.GREEN)
				rl.DrawLine3D({}, {0, 0, 1}, rl.BLUE)
			}
			rl.EndMode3D()
		}
		rl.EndTextureMode()

		rl.BeginDrawing()
		{
			rl.ClearBackground(rl.BLACK)
			rl.DrawTexturePro(
				render_texture.texture,
				{0, 0, f32(render_texture.texture.width), -f32(render_texture.texture.height)},
				{0, 0, 1080, 720},
				{0, 0},
				0,
				rl.WHITE,
			)


			rl.DrawText(
				fmt.caprintf("cube_count: %d\ntriangle_count: %d", cube_count, len(triangles)),
				8,
				8,
				10,
				rl.WHITE,
			)
		}
		rl.EndDrawing()

	}
}
