
// Project 2: Procedure Modelling
package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:os"
import "core:strings"
import rl "vendor:raylib"

GEN_TARGET :: "gen.obj"
// width must be 2^n + 1
WIDTH :: 129
ROUGHNESS :: .25

print_grid :: proc(grid: [WIDTH][WIDTH]f64) {
	for y in 0 ..< WIDTH {
		for x in 0 ..< WIDTH {
			fmt.printf("%f\t", grid[y][x])
		}
		fmt.println()
	}
}

get_rand :: proc(weight: f64) -> f64 {
	return rand.float64_normal(0, weight)
}

get_grid_value :: proc(tx: int, ty: int, grid: ^[WIDTH][WIDTH]f64) -> (bool, f64) {
	if tx >= WIDTH || ty >= WIDTH || tx < 0 || ty < 0 {
		return false, -1
	}

	return true, grid[ty][tx]
}

square_step :: proc(tx: int, ty: int, dist: int, grid: ^[WIDTH][WIDTH]f64, weight: f64) {
	sum := 0.
	count := 0.
	// [y, x]
	dirs := [][]int{{-1, -1}, {1, -1}, {-1, 1}, {1, 1}}
	for dir in dirs {
		targx := (dir[1] * dist) + tx
		targy := (dir[0] * dist) + ty
		ok, out := get_grid_value(targx, targy, grid)
		if ok {
			sum += out
			count += 1
		}
	}

	grid^[ty][tx] = (sum / count) + get_rand(weight)
}

diamond_step :: proc(tx: int, ty: int, dist: int, grid: ^[WIDTH][WIDTH]f64, weight: f64) {
	sum := 0.
	count := 0.
	dirs := [][]int{{-1, 0}, {1, 0}, {0, 1}, {0, -1}}
	for dir in dirs {
		targx := (dir[1] * dist) + tx
		targy := (dir[0] * dist) + ty

		ok, out := get_grid_value(targx, targy, grid)
		if ok {
			sum += out
			count += 1
		}
	}

	grid^[ty][tx] = (sum / count) + get_rand(weight)
}

build_object :: proc() {
	target_obj: cstring = GEN_TARGET

	//
	// gen height map grid
	//

	grid: [WIDTH][WIDTH]f64

	high := WIDTH - 1
	low := 0

	grid[low][low] = 0
	grid[low][high] = 2
	grid[high][low] = 2
	grid[high][high] = 10

	current_width := WIDTH
	current_weight := 1.5
	roughness := ROUGHNESS

	for current_width >= 3 {
		stride := current_width - 1
		half := stride / 2

		for y := half; y < WIDTH; y += stride {
			for x := half; x < WIDTH; x += stride {
				square_step(x, y, half, &grid, current_weight)
			}
		}

		for y := 0; y < WIDTH; y += half {
			start_x := half if (y % stride == 0) else 0
			for x := start_x; x < WIDTH; x += stride {
				diamond_step(x, y, half, &grid, current_weight)
			}
		}

		current_width = (current_width / 2) + 1
		current_weight = current_weight / (math.pow(2, roughness))
	}
	fmt.println("[*] Grid input")

	//
	// generate obj file
	//

	fmt.println("[*] Generating object...")
	flags := os.O_WRONLY | os.O_CREATE | os.O_TRUNC
	file_handle, err := os.open(GEN_TARGET, flags)
	if err != os.ERROR_NONE {
		fmt.println("error opening file")
		return
	}
	defer os.close(file_handle)

	fmt.println("[*] building vertices")

	// Calculate offset to center the mesh at 0,0,0
	offset := WIDTH / 2
	y: f64 = -1.
	for x in 0 ..< WIDTH {
		for z in 0 ..< WIDTH {
			y = grid[x][z]
			// Subtract the offset from x and z coordinates
			fmt.fprintf(file_handle, "v %d %f %d\n", x - offset, y, z - offset)
		}
	}

	fmt.println("[*] writing edges")

	// Iterate through every vertex except the last row and last column
	for y in 0 ..< WIDTH - 1 {
		for x in 0 ..< WIDTH - 1 {
			// Calculate the 1-based index for the current Top-Left corner
			// +1 because OBJ indices start at 1
			tl := (y * WIDTH) + x + 1
			tr := tl + 1
			bl := tl + WIDTH
			br := bl + 1

			// Triangle 1: Top-Left, Top-Right, Bottom-Left
			fmt.fprintf(file_handle, "f %d// %d// %d//\n", tl, tr, bl)

			// Triangle 2: Top-Right, Bottom-Right, Bottom-Left
			fmt.fprintf(file_handle, "f %d// %d// %d//\n", tr, br, bl)
		}
	}
}

main :: proc() {

	skip_build := false
	target_shader := "shader.fs"
	for arg in os.args {
		if strings.contains(arg, "shader") {
			new_shader_args := strings.split_after(arg, "=")
			fmt.println("targeting shader: ", new_shader_args[1])
			target_shader = new_shader_args[1]
			if !os.exists(target_shader) {
				fmt.println("[!] target shader not found, exiting...")
				return
			}
		}
		if arg == "skip_build" {
			skip_build = true
		}
	}

	if skip_build {
		fmt.println("[*] skipping build step")
	} else {
		build_object()
	}

	//
	// make render target_obj
	//

	target_obj: cstring = GEN_TARGET

	rl.InitWindow(1920, 1080, "Test")
	defer rl.CloseWindow()

	camera := rl.Camera3D {
		position   = {64.0, 45.0, 64.0},
		target     = {0.0, 0.0, 0.0},
		up         = {0.0, 1.0, 0.0},
		fovy       = 45.0,
		projection = .PERSPECTIVE,
	}

	model := rl.LoadModel(target_obj)
	defer rl.UnloadModel(model)

	c_target_shader := strings.clone_to_cstring(target_shader)
	shader := rl.LoadShader(nil, c_target_shader)
	defer rl.UnloadShader(shader)

	model.materials[0].shader = shader

	time_loc := rl.GetShaderLocation(shader, "time")

	rl.SetTargetFPS(120)

	for !rl.WindowShouldClose() {

		ctrl_down := rl.IsKeyDown(.LEFT_CONTROL)
		if ctrl_down && rl.IsKeyPressed(.C) {
			break
		}

		camera_button_down := rl.IsKeyDown(.SPACE)
		if camera_button_down {
			rl.UpdateCamera(&camera, .THIRD_PERSON)
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

		rl.DrawModelWires(model, {0., 0., 0.}, 1., rl.DARKGRAY)

		rl.EndMode3D()

		//
		// 2D drawing
		//

		rl.DrawText("ctrl-c to close", 30, 30, 40, rl.DARKGRAY)
		rl.DrawText("space for camera", 30, 80, 40, rl.DARKGRAY)

		rl.EndDrawing()
	}
}
