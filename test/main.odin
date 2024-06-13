package test

import marching_cubes "../src"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:strings"
import rl "vendor:raylib"

main :: proc() {
	using marching_cubes

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

	mask: u8
	timer: f32
	started := false
	cube := cube_from_mask(mask)
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
