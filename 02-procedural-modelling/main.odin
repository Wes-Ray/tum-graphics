// Project 2: Procedure Modelling
package main

import "core:fmt"
import "core:os"
import rl "vendor:raylib"

GEN_TARGET :: "gen.obj"
// should be an odd number to have a defined center
GRID_WIDTH :: 2

main :: proc() {
	target_obj: cstring
	if len(os.args) < 2 {
		target_obj = GEN_TARGET
	} else {
		target_obj = fmt.ctprintf("%s.obj", os.args[1])
	}

	//
	// generate object
	//

	if target_obj == GEN_TARGET {
		fmt.println("[*] Generating object...")
		flags := os.O_WRONLY | os.O_CREATE | os.O_TRUNC
		file_handle, err := os.open(GEN_TARGET, flags)
		if err != os.ERROR_NONE {
			fmt.println("error opening file")
			return
		}
		defer os.close(file_handle)

		grid: [GRID_WIDTH][GRID_WIDTH]f32
		fmt.println(grid)

		// fill in obj vertex by vertex
		// x y(height) z
		y := 0
		for x in 0 ..< GRID_WIDTH {
			for z in 0 ..< GRID_WIDTH {
				fmt.fprintf(file_handle, "v %d %d %d\n", x, y, z)
			}
		}
		fmt.fprintf(file_handle, "f 1// 2// 3// 4//\n")
		fmt.fprintf(file_handle, "f 3// 2// 4//\n")
	}

	//
	// make render target_obj
	//

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

	rl.SetTargetFPS(120)

	for !rl.WindowShouldClose() {

		ctrl_down := rl.IsKeyDown(.LEFT_CONTROL)
		if ctrl_down && rl.IsKeyPressed(.C) {
			break
		}

		mouse1_down := rl.IsMouseButtonDown(.LEFT)
		if mouse1_down {
			rl.UpdateCamera(&camera, .THIRD_PERSON)
			// rl.DisableCursor()
		} else {
			// rl.EnableCursor()
		}

		// Shader uniform updates
		current_time := cast(f32)rl.GetTime()
		rl.SetShaderValue(shader, time_loc, &current_time, .FLOAT)

		rl.BeginDrawing()
		rl.ClearBackground(rl.GRAY)

		//
		// 3D drawing
		//

		rl.BeginMode3D(camera)

		// rl.DrawModel(model, {0., 0., 0.}, 1., rl.WHITE)
		rl.DrawModelWires(model, {0., 0., 0.}, 1., rl.DARKGRAY)
		// rl.DrawGrid(10, 1.)

		rl.EndMode3D()

		//
		// 2D drawing
		//

		rl.DrawText("ctrl-c to close", 30, 30, 40, rl.DARKGRAY)
		rl.DrawText("mouse1 for camera", 30, 80, 40, rl.DARKGRAY)

		rl.EndDrawing()
	}
}
