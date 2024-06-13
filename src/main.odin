package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:strings"
import rl "vendor:raylib"

// Create a cube from a mask of vertex values
// bits of 0 will be below isolevel
// bits of 1 will be above isolevel
cube_from_mask :: proc(m: u8, allocator := context.temp_allocator) -> []u8 {
	cube := make([]u8, 8, allocator)
	for i in 0 ..= 7 {
		cube[i] = u8(rand.uint32() % 8)
		if m & (1 << u8(i)) > 0 {
			cube[i] += 8
		}
	}
	return cube[:]
}

// Determine the configuration based on the cube values
determine_configuration :: proc(cube: []u8) -> u8 {
	configuration := u8(0)
	for v, i in cube {
		if v >= 8 {
			configuration |= 1 << u8(i)
		}
	}
	return configuration
}

vertex_interpolate :: proc(edge: u8) -> [3]f32 {
	// Edges follow ascending path 0 -> 1, 1 -> 2...
	// Vertical edges are last following the same order
	// So 0 -> 4, 1 -> 5...
	//
	//    4+-------+5     +---4---+     +-------+ 
	//    /|      /|     7|      5|    /|      /|
	//   / |     / |    / |     / |   / 8     / 9
	// 7+--|----+6 |   +--|6---+  |  +--|----+  |
	//  |  |    |  |   |  |    |  |  |  |    |  |
	//  | 0+-------+1  |  +--0----+  11 +-------+
	//  | /     | /    | 3     | 1   | /     | /
	//  |/      |/     |/      |/    |/      |/
	// 3+-------+2     +---2---+     +-------+

	a, b: [3]f32
	switch edge {
	case 0:
		b.x = 1
	case 1:
		a.x = 1
		b.x = 1
		b.z = 1
	case 2:
		a.x = 1
		a.z = 1
		b.z = 1
	case 3:
		b.z = 1
	case 4:
		a.y = 1
		b.y = 1
		b.x = 1
	case 5:
		a.y = 1
		b.y = 1
		a.x = 1
		b.x = 1
		b.z = 1
	case 6:
		a.y = 1
		b.y = 1
		a.x = 1
		a.z = 1
		b.z = 1
	case 7:
		a.y = 1
		b.y = 1
		b.z = 1
	case 8:
		b.y = 1
	case 9:
		b.y = 1
		a.x = 1
		b.x = 1
	case 10:
		b.y = 1
		a.x = 1
		b.x = 1
		a.z = 1
		b.z = 1
	case 11:
		b.y = 1
		a.z = 1
		b.z = 1
	}

	// TODO: Non-midpoint
	return a + (b - a) / 2
}

// Given 8 scalar field vaules as a cube, generate the triangles
generate_triangles :: proc(cube: []u8, offset: [3]f32, scale: f32) -> [][3][3]f32 {
	triangles := make([dynamic][3][3]f32)
	configuration := determine_configuration(cube)

	if configuration != 0 && configuration != 255 {
		vertices := make([][3]f32, 12)

		// TODO: Figure out how to skip edges only using required ones
		for edge: u8 = 0; edge < 12; edge += 1 {
			vertices[edge] = vertex_interpolate(edge) * scale + offset
		}
		for i in 0 ..= 11 {
			fmt.print(i, ":", vertices[i], " ")
		}
		fmt.println("indices:", triangle_table[configuration])

		for indices in triangle_table[configuration] {
			append(
				&triangles,
				[3][3]f32{vertices[indices.x], vertices[indices.y], vertices[indices.z]},
			)
		}
	}
	return triangles[:]
}

cube_corner_pos_from_index :: proc(index: int) -> [3]f32 {
	base_positions := [][3]f32{{}, {1, 0, 0}, {1, 0, 1}, {0, 0, 1}}

	top_offset := [3]f32{0, 1, 0}

	if index < 4 {
		return base_positions[index]
	} else {
		return base_positions[index - 4] + top_offset
	}
}

main :: proc() {
	rl.InitWindow(1280, 720, "Marching Cubes")

	camera := rl.Camera {
		position   = {-1.25, 0.7, -0.8},
		target     = {0.5, 0.5, 0.5},
		up         = {0, 1, 0},
		fovy       = 85,
		projection = rl.CameraProjection.PERSPECTIVE,
	}

	rl.DisableCursor()
	rl.SetTargetFPS(60)

	render_texture := rl.LoadRenderTexture(1280, 720)
	defer rl.UnloadRenderTexture(render_texture)

	// cube := cube_from_mask(0b00000000)
	// triangles := generate_triangles(cube[:], {}, 1)
	mask: u8
	timer: f32
	started := false
	cube := cube_from_mask(mask)
	fmt.println("cube:", cube)
	triangles := generate_triangles(cube[:], {}, 1)

	for !rl.WindowShouldClose() {
		if started {
			timer += rl.GetFrameTime()
		}
		if rl.IsKeyPressed(rl.KeyboardKey.N) {
			started = true
		}
		if timer >= 0.6 {
			timer = 0
			mask += 1
			mask = mask % u8(255)
			cube = cube_from_mask(mask)
			triangles = generate_triangles(cube[:], {}, 1)
		}

		rl.UpdateCamera(&camera, rl.CameraMode.ORBITAL)

		rl.BeginTextureMode(render_texture)
		{
			rl.ClearBackground(rl.BLACK)

			rl.BeginMode3D(camera)
			{
				rl.DrawCubeWires({0.5, 0.5, 0.5}, 1, 1, 1, {255, 255, 255, 100})

				for t in triangles {
					rl.DrawTriangle3D(t.x, t.y, t.z, {255, 255, 255, 128})
					rl.DrawLine3D(t.x, t.y, rl.RED)
					rl.DrawLine3D(t.y, t.z, rl.GREEN)
					rl.DrawLine3D(t.z, t.x, rl.WHITE)
				}

				for corner, i in cube {
					pos := cube_corner_pos_from_index(i)
					if corner >= 8 {
						rl.DrawCubeV(pos, {0.05, 0.05, 0.05}, rl.RED)
					} else {
						rl.DrawCubeV(pos, {0.05, 0.05, 0.05}, rl.BLUE)
					}
				}

				rl.DrawLine3D({}, {0.1, 0, 0}, rl.BLUE)
				rl.DrawLine3D({}, {0, 0.1, 0}, rl.GREEN)
				rl.DrawLine3D({}, {0, 0, 0.1}, rl.RED)
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
				{0, 0, 1280, 720},
				{0, 0},
				0,
				rl.WHITE,
			)

			s := fmt.ctprintf("Variant: %d", mask)
			rl.DrawText(s, 4, 4, 10, rl.WHITE)
		}
		rl.EndDrawing()
	}
}
