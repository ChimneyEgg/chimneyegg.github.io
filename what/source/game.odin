package game

import rl "vendor:raylib"
import mt "core:math"
// import "core:log"
// import fm "core:fmt"
import "core:c"

run: bool

GAME_WIDTH :: 720 / 2
GAME_HEIGHT :: 480 / 2

SCREEN_WIDTH :: 720 // GAME_WIDTH * 2
SCREEN_HEIGHT :: 480 // GAME_HEIGHT * 2

HALF_GAME_WIDTH :: GAME_WIDTH / 2
HALF_GAME_HEIGHT :: GAME_HEIGHT / 2

GAME_LEFT :: 0 
GAME_RIGHT :: 640

GROUND_LEVEL :: 96

render_target : rl.RenderTexture
camera : rl.Camera2D

State :: enum {IDLE, RIGHT, CROUCH_RIGHT, CROUCHING, CROUCH_LEFT, LEFT, JUMP_LEFT, JUMPING, JUMP_RIGHT, PUNCH, KICK}

State_Time :: struct {
	state: State, 
	time: i32,
}

player_pos : rl.Vector2 = {0, GROUND_LEVEL}
enemy_pos : rl.Vector2 = {GAME_WIDTH - 80, GROUND_LEVEL}

player_right : bool = true  
enemy_right : bool = false

player_health : i32 = 0 
enemy_health : i32 = 0

player_time : i32 = 0 
enemy_time : i32 = 0

player_mhistory : [10]State_Time 
enemy_mhistory : [10]State_Time 

MAX_HEALTH :: 100

sol_texture : rl.Texture 
background_texture : rl.Texture 
health_texture : rl.Texture
timer_texture : rl.Texture
sad_texture : rl.Texture
boom_texture : rl.Texture
splash_texture : rl.Texture

bg_music : rl.Sound
boom_fx : rl.Sound

sad_timer : u8

add_to_history :: proc(s: State_Time, ss: ^[10]State_Time) {
	s := s
	for i := 0; i < 10; i += 1 {
		old_s := ss[i] 
		ss[i] = s 
		s = old_s
	}
}

init :: proc() {
	run = true

	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Sol Fighter")
	rl.SetTargetFPS(60)
	rl.DisableCursor()

	rl.InitAudioDevice()

	sol_texture = rl.LoadTexture("assets/sol_badguy.png")
	background_texture = rl.LoadTexture("assets/background.png")
	health_texture = rl.LoadTexture("assets/health_bar.png")
	timer_texture = rl.LoadTexture("assets/timer.png")
	sad_texture = rl.LoadTexture("assets/sad.png")
	boom_texture = rl.LoadTexture("assets/boom.gif")	
	splash_texture = rl.LoadTexture("assets/splash.png")

	bg_music = rl.LoadSound("assets/tower_of_lakes.ogg")
	boom_fx = rl.LoadSound("assets/boom.ogg")

	render_target = rl.LoadRenderTexture(GAME_WIDTH, GAME_HEIGHT)

	camera.zoom = 1
	camera.target = {HALF_GAME_WIDTH, HALF_GAME_HEIGHT}
	camera.offset = {HALF_GAME_WIDTH, HALF_GAME_HEIGHT}

	rl.PlaySound(bg_music)
}

update_character :: proc(gamepad: i32, pos: ^rl.Vector2, face_right: bool, mhistory: ^[10]State_Time) {
	switch mhistory[0].state {
		case .IDLE:

		if rl.IsGamepadButtonDown(gamepad, rl.GamepadButton.LEFT_FACE_LEFT) {
			if rl.IsGamepadButtonDown(gamepad, rl.GamepadButton.LEFT_FACE_DOWN) {
				add_to_history({.CROUCH_LEFT, 0}, mhistory)
			} else if rl.IsGamepadButtonDown(gamepad, rl.GamepadButton.LEFT_FACE_UP) {
				add_to_history({.JUMP_LEFT, 0}, mhistory)
			} else {
				add_to_history({.LEFT, 0}, mhistory)
			}
		} else if rl.IsGamepadButtonDown(gamepad, rl.GamepadButton.LEFT_FACE_RIGHT) {
			if rl.IsGamepadButtonPressed(gamepad, rl.GamepadButton.LEFT_FACE_DOWN) {
				add_to_history({.CROUCH_RIGHT, 0}, mhistory)
			} else if rl.IsGamepadButtonDown(gamepad, rl.GamepadButton.LEFT_FACE_UP) {
				add_to_history({.JUMP_RIGHT, 0}, mhistory)
			} else {
				add_to_history({.RIGHT, 0}, mhistory)
			}
		} else if rl.IsGamepadButtonDown(gamepad, rl.GamepadButton.LEFT_FACE_UP) {
			add_to_history({.JUMPING, 0}, mhistory)
		} else if rl.IsGamepadButtonDown(gamepad, rl.GamepadButton.LEFT_FACE_DOWN) {
			add_to_history({.CROUCHING, 0}, mhistory)
		} else if rl.IsGamepadButtonPressed(gamepad, rl.GamepadButton.RIGHT_FACE_DOWN) {
			add_to_history({.PUNCH, -8}, mhistory)
		} else if rl.IsGamepadButtonPressed(gamepad, rl.GamepadButton.RIGHT_FACE_RIGHT) {
			add_to_history({.KICK, -12}, mhistory)
		}

		break
		case .RIGHT:
			pos[0] += 3
			if rl.IsGamepadButtonReleased(gamepad, rl.GamepadButton.LEFT_FACE_RIGHT) {
				add_to_history({.IDLE, 0}, mhistory)
			} else if rl.IsGamepadButtonDown(gamepad, rl.GamepadButton.LEFT_FACE_UP) {
				add_to_history({.JUMP_RIGHT, 0}, mhistory)
			} else if rl.IsGamepadButtonDown(gamepad, rl.GamepadButton.LEFT_FACE_DOWN) {
				add_to_history({.CROUCH_RIGHT, 0}, mhistory)
			}
		break
		case .CROUCH_RIGHT:
			if rl.IsGamepadButtonReleased(gamepad, rl.GamepadButton.LEFT_FACE_DOWN) {
				add_to_history({.IDLE, 0}, mhistory)
			}
		break
		case .CROUCHING:
			if rl.IsGamepadButtonReleased(gamepad, rl.GamepadButton.LEFT_FACE_DOWN) {
				add_to_history({.IDLE, 0}, mhistory)
			}
		break
		case .CROUCH_LEFT:
			if rl.IsGamepadButtonReleased(gamepad, rl.GamepadButton.LEFT_FACE_DOWN) {
				add_to_history({.IDLE, 0}, mhistory)
			}
		break
		case .LEFT:
			pos[0] -= 3
			if rl.IsGamepadButtonReleased(gamepad, rl.GamepadButton.LEFT_FACE_LEFT) {
				add_to_history({.IDLE, 0}, mhistory)
			} else if rl.IsGamepadButtonDown(gamepad, rl.GamepadButton.LEFT_FACE_UP) {
				add_to_history({.JUMP_LEFT, 0}, mhistory)
			} else if rl.IsGamepadButtonDown(gamepad, rl.GamepadButton.LEFT_FACE_DOWN) {
				add_to_history({.CROUCH_LEFT, 0}, mhistory)
			}
		break
		case .JUMP_LEFT:
			pos[0] -= 4
			pos[1] -= mt.cos(f32(mhistory[0].time) * 0.075) * 8
			if pos[1] >= GROUND_LEVEL {
				pos[1] = GROUND_LEVEL
				add_to_history({.IDLE, 0}, mhistory)
			}
		break
		case .JUMPING:
			pos[1] -= mt.cos(f32(mhistory[0].time) * 0.075) * 10
			if pos[1] >= GROUND_LEVEL {
				pos[1] = GROUND_LEVEL
				add_to_history({.IDLE, 0}, mhistory)
			}
		break
		case .JUMP_RIGHT:
			pos[0] += 4
			pos[1] -= mt.cos(f32(mhistory[0].time) * 0.075) * 8
			if pos[1] >= GROUND_LEVEL {
				pos[1] = GROUND_LEVEL
				add_to_history({.IDLE, 0}, mhistory)
			}
		break
		case .PUNCH:
			if mhistory[0].time >= 0 {
				add_to_history({.IDLE, 0}, mhistory)
			}
		break
		case .KICK:
			if mhistory[0].time >= 0 {
				add_to_history({.IDLE, 0}, mhistory)
			}
		break
	}
}

in_menu : bool = true 
in_game : bool = false 
booming : bool = false

update :: proc() {
	if in_menu {
		if rl.IsGamepadButtonPressed(0, rl.GamepadButton.MIDDLE_RIGHT) {
			in_menu = false 
			in_game = true 
			return
		}

		rl.BeginDrawing()
		rl.BeginTextureMode(render_target)

		rl.ClearBackground(rl.BLACK)

		rl.DrawTexture(splash_texture, 0, 0, rl.WHITE)

		rl.EndTextureMode()

		// Draw stretched render_target, switch?
		rl.DrawTexturePro(render_target.texture, {0, 0, f32(render_target.texture.width), -f32(render_target.texture.height)}, 
			{0, 0, SCREEN_WIDTH, SCREEN_HEIGHT}, {0, 0}, 0, rl.WHITE)	

		rl.EndDrawing()		

	}
	else if in_game {
		if booming {
			if !rl.IsSoundPlaying(boom_fx) {
				in_game = false
			}
			return						
		}

		if !rl.IsSoundPlaying(bg_music) {
			rl.PlaySound(bg_music)
		}

		player_time += 1 
		enemy_time += 1

		/*if rl.IsKeyPressed(rl.KeyboardKey.LEFT) {
			player_health += 5
		}

		if rl.IsKeyPressed(rl.KeyboardKey.RIGHT) {
			enemy_health += 5
			if enemy_health > MAX_HEALTH {
				enemy_health = 0
			}
		}*/

		player_mhistory[0].time += 1
		enemy_mhistory[0].time += 1

		if player_mhistory[0].state != .JUMPING && player_mhistory[0].state != .JUMP_LEFT && player_mhistory[0].state != .JUMP_RIGHT {
			if player_pos[0] > enemy_pos[0] {
				player_right = false 
			} else {
				player_right = true
			}		
		}

		if enemy_mhistory[0].state != .JUMPING && enemy_mhistory[0].state != .JUMP_LEFT && enemy_mhistory[0].state != .JUMP_RIGHT {
			if player_pos[0] > enemy_pos[0] {
				enemy_right = true 
			} else {
				enemy_right = false
			}		
		}

		if !rl.IsGamepadAvailable(1) {
			if enemy_mhistory[0].time == 4 && enemy_pos[1] == GROUND_LEVEL {
				val := State(rl.GetRandomValue(0, 12))
				t : i32 = 0 if val != .PUNCH else -8
				t = 0 if val != .KICK else -12
				add_to_history({val, t}, &enemy_mhistory)
			}
		}

		update_character(0, &player_pos, player_right, &player_mhistory)
		update_character(1, &enemy_pos, enemy_right, &enemy_mhistory)			

		if rl.Vector2Distance(player_pos, enemy_pos) < 16 {
			if player_right {
				player_pos[0] -= 6
				enemy_pos[0] += 6
			} else {
				player_pos[0] += 6
				enemy_pos[0] -= 6			
			}
		}
		if rl.Vector2Distance(player_pos, enemy_pos) < 32 {
			if player_mhistory[0].state == .PUNCH {
				if player_mhistory[0].time == -3 {
					enemy_health += 10 if rl.IsGamepadAvailable(1) else 1
					if enemy_right {
						player_pos[0] += 16
						enemy_pos[0] -= 16

					} else {
						player_pos[0] -= 16
						enemy_pos[0] += 16
					}
				}
			}
			if enemy_mhistory[0].state == .PUNCH {
				if enemy_mhistory[0].time == -3 {
					player_health += 10
					if enemy_right {
						player_pos[0] += 8
						enemy_pos[0] -= 8

					} else {
						player_pos[0] -= 8
						enemy_pos[0] += 8
					}
				}
			}
		}

		if rl.Vector2Distance(player_pos, enemy_pos) < 64 {
			if player_mhistory[0].state == .KICK {
				if player_mhistory[0].time == -6 {
					enemy_health += 20 if rl.IsGamepadAvailable(1) else 1

					if enemy_right {
						player_pos[0] += 8
						enemy_pos[0] -= 8

					} else {
						player_pos[0] -= 8
						enemy_pos[0] += 8
					}
				}
			}
			if enemy_mhistory[0].state == .KICK {
				if enemy_mhistory[0].time == -6 {
					player_health += 20

					if enemy_right {
						player_pos[0] += 8
						enemy_pos[0] -= 8

					} else {
						player_pos[0] -= 8
						enemy_pos[0] += 8
					}
				}
			}
		}

		player_pos[0] = clamp(player_pos[0], 0, GAME_WIDTH-80)
		enemy_pos[0] = clamp(enemy_pos[0], 0, GAME_WIDTH-80)

		rl.BeginDrawing()
		rl.BeginTextureMode(render_target)

		rl.ClearBackground(rl.WHITE)

		rl.BeginMode2D(camera)

		rl.DrawTexture(background_texture, -24, 0, rl.WHITE)

		// TODO: put this in a function. Wait this is a shitpost, why would I put that much effort into this
		if player_mhistory[0].state == .IDLE {
			rl.DrawTextureRec(sol_texture, {f32((i32(f32(player_mhistory[0].time) * 0.1) * 80) % 320), 0, 80 if player_right else -80, 136}, player_pos, rl.WHITE)
		} else if player_mhistory[0].state == .RIGHT || player_mhistory[0].state == .LEFT {
			rl.DrawTextureRec(sol_texture, {f32((i32(f32(player_mhistory[0].time) * 0.33) * 80) % 240), 136, 80 if player_right else -80, 136}, player_pos, rl.WHITE)
		} else if player_mhistory[0].state == .JUMPING || player_mhistory[0].state == .JUMP_LEFT || player_mhistory[0].state == .JUMP_RIGHT {
			rl.DrawTextureRec(sol_texture, {240, 136, -80 if !player_right else 80, 136}, player_pos, rl.WHITE)
		} else if player_mhistory[0].state == .CROUCHING || player_mhistory[0].state == .CROUCH_LEFT || player_mhistory[0].state == .CROUCH_RIGHT {
			rl.DrawTextureRec(sol_texture, {0, 272, -80 if !player_right else 80, 136}, player_pos, rl.WHITE)
		} else if player_mhistory[0].state == .PUNCH {
			rl.DrawTextureRec(sol_texture, {80 if player_mhistory[0].time < -4 else 160, 272, -80 if !player_right else 80, 136}, player_pos, rl.WHITE)
		} else if player_mhistory[0].state == .KICK {
			rl.DrawTextureRec(sol_texture, {0 if player_mhistory[0].time < -6 else 80, 408, -80 if !player_right else 80, 136}, player_pos, rl.WHITE)
		}

		if enemy_mhistory[0].state == .IDLE {
			rl.DrawTextureRec(sol_texture, {f32((i32(f32(enemy_mhistory[0].time) * 0.1) * 80) % 320), 0, -80 if !enemy_right else 80, 136}, enemy_pos, rl.WHITE)
		} else if enemy_mhistory[0].state == .RIGHT || enemy_mhistory[0].state == .LEFT {
			rl.DrawTextureRec(sol_texture, {f32((i32(f32(enemy_mhistory[0].time) * 0.33) * 80) % 240), 136, -80 if !enemy_right else 80, 136}, enemy_pos, rl.WHITE)
		} else if enemy_mhistory[0].state == .JUMPING || enemy_mhistory[0].state == .JUMP_LEFT || enemy_mhistory[0].state == .JUMP_RIGHT {
			rl.DrawTextureRec(sol_texture, {240, 136, -80 if !enemy_right else 80, 136}, enemy_pos, rl.WHITE)
		} else if enemy_mhistory[0].state == .CROUCHING || enemy_mhistory[0].state == .CROUCH_LEFT || enemy_mhistory[0].state == .CROUCH_RIGHT {
			rl.DrawTextureRec(sol_texture, {0, 272, -80 if !enemy_right else 80, 136}, enemy_pos, rl.WHITE)
		} else if enemy_mhistory[0].state == .PUNCH {
			rl.DrawTextureRec(sol_texture, {80 if enemy_mhistory[0].time < -4 else 160, 272, -80 if !enemy_right else 80, 136}, enemy_pos, rl.WHITE)
		} else if enemy_mhistory[0].state == .KICK {
			rl.DrawTextureRec(sol_texture, {0 if enemy_mhistory[0].time < -6 else 80, 408, -80 if !enemy_right else 80, 136}, enemy_pos, rl.WHITE)
		}

		if player_health > MAX_HEALTH || enemy_health > MAX_HEALTH {
			rl.DrawTexture(boom_texture, i32(player_pos[0]) - HALF_GAME_WIDTH, i32(player_pos[1]) - HALF_GAME_HEIGHT, rl.WHITE)
		}
		
		rl.EndMode2D()

		rl.DrawTexture(health_texture, 0, 0, rl.WHITE)

		rl.DrawRectangleGradientH(48 + player_health, 25, 113 - player_health, 13, rl.RED, rl.GREEN)
		rl.DrawRectangleGradientH(195, 25, 113 - enemy_health, 13, rl.GREEN, rl.RED)

		rl.DrawTexture(timer_texture, 0, 0, rl.WHITE)

		// DEBUG
		/*for i := 0; i < 10; i += 1 {
			rl.DrawText(fm.ctprint(player_mhistory[i].state, player_mhistory[i].time), 0, i32(i * 12), 12, {0, 0, 0, 64})
			rl.DrawText(fm.ctprint(enemy_mhistory[i].state, enemy_mhistory[i].time), GAME_WIDTH-100, i32(i * 12), 12, {0, 0, 0, 64})		
		}*/

		rl.EndTextureMode()

		// Draw stretched render_target, switch?
		rl.DrawTexturePro(render_target.texture, {0, 0, f32(render_target.texture.width), -f32(render_target.texture.height)}, 
			{0, 0, SCREEN_WIDTH, SCREEN_HEIGHT}, {0, 0}, 0, rl.WHITE)	

		rl.EndDrawing()		


		if player_health > MAX_HEALTH || enemy_health > MAX_HEALTH {
			rl.PlaySound(boom_fx)
			booming = true 
			return
		}		

	} else {
		if rl.IsSoundPlaying(bg_music) {
			rl.StopSound(bg_music)
		}

		sad_timer += 2
		if sad_timer > 252 {
			sad_timer = 252
		}

		rl.BeginDrawing()
		rl.BeginTextureMode(render_target)

		rl.ClearBackground(rl.BLACK)

		rl.DrawTexture(sad_texture, 0, 64, {sad_timer, sad_timer, sad_timer, sad_timer})

		rl.EndTextureMode()

		// Draw stretched render_target, switch?
		rl.DrawTexturePro(render_target.texture, {0, 0, f32(render_target.texture.width), -f32(render_target.texture.height)}, 
			{0, 0, SCREEN_WIDTH, SCREEN_HEIGHT}, {0, 0}, 0, rl.WHITE)	

		rl.EndDrawing()			
	}
	
	free_all(context.temp_allocator)
}

parent_window_size_changed :: proc(w, h: int) {
	rl.SetWindowSize(c.int(w), c.int(h))
}

shutdown :: proc() {
	rl.CloseWindow()
}

should_run :: proc() -> bool {
	when ODIN_OS != .JS {
		if rl.WindowShouldClose() {
			run = false
		}
	}

	return run
}