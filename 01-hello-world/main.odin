package main

import "core:fmt"
import "core:os"
import rl "vendor:raylib"

main :: proc() {
	target_obj: cstring
	if len(os.args) < 2 {
		target_obj = "test1.obj"
	} else {
		target_obj = fmt.ctprintf("%s.obj", os.args[1])
	}

	rl.InitWindow(1920, 1080, "Test")
	defer rl.CloseWindow()

	camera := rl.Camera3D {
		position   = {5.0, 5.0, 5.0}, // Where the camera is
		target     = {0.0, 0.0, 0.0}, // What the camera is looking at
		up         = {0.0, 1.0, 0.0}, // Which way is 'up' (usually Y)
		fovy       = 45.0, // Field of view
		projection = .PERSPECTIVE, // Standard 3D perspective
	}

	model := rl.LoadModel(target_obj)
	defer rl.UnloadModel(model)

	shader := rl.LoadShader(nil, "shader.fs")
	defer rl.UnloadShader(shader)

	model.materials[0].shader = shader

	time_loc := rl.GetShaderLocation(shader, "time")

	rl.DisableCursor()
	rl.SetTargetFPS(120)

	for !rl.WindowShouldClose() {

		ctrl_down := rl.IsKeyDown(.LEFT_CONTROL)
		if ctrl_down && rl.IsKeyPressed(.C) {
			break
		}

		// Shader uniform updates
		current_time := cast(f32)rl.GetTime()
		rl.SetShaderValue(shader, time_loc, &current_time, .FLOAT)

		mouse1_down := rl.IsMouseButtonDown(.LEFT)
		if mouse1_down {
			rl.UpdateCamera(&camera, .THIRD_PERSON)
		}

		rl.BeginDrawing()
		rl.ClearBackground(rl.GRAY)

		//
		// 3D drawing
		//

		rl.BeginMode3D(camera)

		rl.DrawModel(model, {0., 0., 0.}, 1., rl.WHITE)
		rl.DrawGrid(10, 1.)

		rl.EndMode3D()

		//
		// 2D drawing
		//

		rl.DrawText("ctrl-c to close", 30, 30, 40, rl.DARKGRAY)
		rl.DrawText("mouse1 for camera", 30, 80, 40, rl.DARKGRAY)

		rl.EndDrawing()
	}
}
