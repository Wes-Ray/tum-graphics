// Project 2: Procedure Modelling
package main

import "core:fmt"
import "core:math"
import "core:os"
import rl "vendor:raylib"

GEN_TARGET :: "gen.obj"
// width must be 2^n + 1
WIDTH :: 3

print_grid :: proc(grid: [WIDTH][WIDTH]f64) {
	for y in 0 ..< WIDTH {
		for x in 0 ..< WIDTH {
			fmt.printf("%f\t", grid[y][x])
		}
		fmt.println()
	}
}

get_grid_value :: proc(tx: int, ty: int, grid: ^[WIDTH][WIDTH]f64) -> (bool, f64) {
	if tx >= WIDTH || ty >= WIDTH || tx < 0 || ty < 0 {
		return false, -1
	}

	return true, grid[ty][tx]
}

square_step :: proc(tx: int, ty: int, dist: int, grid: ^[WIDTH][WIDTH]f64) {
	sum := 0.
	count := 0.
	// [y, x]
	dirs := [][]int{{-1, -1}, {1, -1}, {-1, 1}, {1, 1}}
	for dir in dirs {
		targx := (dir[1] * dist) + tx
		targy := (dir[0] * dist) + ty
		// fmt.println("dir: ", dir)
		// fmt.println("getting: ", targx, targy)
		ok, out := get_grid_value(targx, targy, grid)
		if ok {
			sum += out
			count += 1
		}
	}

	// fmt.println("sum: %f", sum)
	// fmt.println("count: %f", count)
	grid^[ty][tx] = sum / count

}

diamond_step :: proc(tx: int, ty: int, dist: int, grid: ^[WIDTH][WIDTH]f64) {
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

	grid^[ty][tx] = sum / count
}

main :: proc() {
	target_obj: cstring = GEN_TARGET

	//
	// gen height map grid
	//

	grid: [WIDTH][WIDTH]f64

	high := WIDTH - 1
	low := 0

	grid[low][low] = 0
	grid[low][high] = 1
	grid[high][low] = 1.2
	grid[high][high] = 2

	current_width := WIDTH

	for current_width >= 3 {
		// fmt.println("current_width: ", current_width)

		stride := current_width - 1
		half := stride / 2

		for y := half; y < WIDTH; y += stride {
			for x := half; x < WIDTH; x += stride {
				square_step(x, y, half, &grid)
			}
		}

		for y := 0; y < WIDTH; y += half {
			start_x := half if (y % stride == 0) else 0
			for x := start_x; x < WIDTH; x += stride {
				diamond_step(x, y, half, &grid)
			}
		}

		// print_grid(grid)
		current_width = (current_width / 2) + 1
	}
	fmt.println("[*] Grid input")
	print_grid(grid)

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

	y: f64 = -1.
	for x in 0 ..< WIDTH {
		for z in 0 ..< WIDTH {
			y = grid[x][z]
			fmt.printf("v %d %f %d\n", x, y, z)
			fmt.fprintf(file_handle, "v %d %f %d\n", x, y, z)
		}
	}

	// Example square obj
	//   x y z  (y is up)
	// v 0 0 0
	// v 0 0 1
	// v 1 0 0
	// v 1 0 1
	// f 1// 2// 3//
	// f 2// 4// 3//

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
			fmt.printfln("f %d// %d// %d//", tl, tr, bl)
			fmt.fprintf(file_handle, "f %d// %d// %d//\n", tl, tr, bl)

			// Triangle 2: Top-Right, Bottom-Right, Bottom-Left
			fmt.printfln("f %d// %d// %d//", tr, br, bl)
			fmt.fprintf(file_handle, "f %d// %d// %d//\n", tr, br, bl)
		}
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
