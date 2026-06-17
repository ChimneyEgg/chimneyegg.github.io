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

State :: enum {IDLE, RIGHT, CROUCH_RIGHT, CROUCHING, CROUCH_LEFT, LEFT, JUMP_LEFT, JUMPING, JUMP_RIGHT, PUNCH, KICK, FIREBALL, SUPER_KICK}

State_Time :: struct {
	state: State, 
	time: i32,
}

Character :: struct {
	pos: rl.Vector2,
	right: bool,
	health: i32,
	history: [10]State_Time,
	aerial: bool,
}

player : Character
enemy : Character

// player_pos : rl.Vector2 = {0, GROUND_LEVEL}
// enemy_pos : rl.Vector2 = {GAME_WIDTH - 80, GROUND_LEVEL}

// player_right : bool = true  
// enemy_right : bool = false

// player_health : i32 = 0 
// enemy_health : i32 = 0

// player_time : i32 = 0 
// enemy_time : i32 = 0

// player_mhistory : [10]State_Time 
// enemy_mhistory : [10]State_Time 

MAX_HEALTH :: 200

sol_texture : rl.Texture 
background_texture : rl.Texture 
health_texture : rl.Texture
timer_texture : rl.Texture
sad_texture : rl.Texture
boom_texture : rl.Texture
splash_texture : rl.Texture
loading_texture : rl.Texture
ready_texture : rl.Texture

grayscale_shader : rl.Shader

bg_music : rl.Sound
boom_fx : rl.Sound
disk_fx : rl.Sound

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
	boom_texture = rl.LoadTexture("assets/boom.png")	
	splash_texture = rl.LoadTexture("assets/splash.png")
	loading_texture = rl.LoadTexture("assets/loading.png")
	ready_texture = rl.LoadTexture("assets/ready.png")

	bg_music = rl.LoadSound("assets/tower_of_lakes.ogg")
	boom_fx = rl.LoadSound("assets/boom.ogg")
	disk_fx = rl.LoadSound("assets/disk.ogg")

	grayscale_shader = rl.LoadShader("", "assets/grayscale.fs")

	render_target = rl.LoadRenderTexture(GAME_WIDTH, GAME_HEIGHT)

	camera.zoom = 1
	camera.target = {HALF_GAME_WIDTH, HALF_GAME_HEIGHT}
	camera.offset = {HALF_GAME_WIDTH, HALF_GAME_HEIGHT}

	player.pos = {0, GROUND_LEVEL}
	enemy.pos = {GAME_WIDTH - 80, GROUND_LEVEL}

	//rl.PlaySound(bg_music)
}
 
draw_character :: proc(gamepad: i32, character: Character) {
	if character.history[0].state == .IDLE {
		rl.DrawTextureRec(sol_texture, {f32((i32(f32(character.history[0].time) * 0.1) * 80) % 320), 0, 80 if character.right else -80, 136}, character.pos, rl.WHITE)
	} else if character.history[0].state == .RIGHT || character.history[0].state == .LEFT {
		rl.DrawTextureRec(sol_texture, {f32((i32(f32(character.history[0].time) * 0.33) * 80) % 240), 136, 80 if character.right else -80, 136}, character.pos, rl.WHITE)
	} else if character.history[0].state == .JUMPING || character.history[0].state == .JUMP_LEFT || character.history[0].state == .JUMP_RIGHT {
		rl.DrawTextureRec(sol_texture, {240, 136, -80 if !character.right else 80, 136}, character.pos, rl.WHITE)
	} else if character.history[0].state == .CROUCHING || character.history[0].state == .CROUCH_LEFT || character.history[0].state == .CROUCH_RIGHT {
		rl.DrawTextureRec(sol_texture, {0, 272, -80 if !character.right else 80, 136}, character.pos, rl.WHITE)
	} else if character.history[0].state == .PUNCH {
		rl.DrawTextureRec(sol_texture, {80 if character.history[0].time < -4 else 160, 272, -80 if !character.right else 80, 136}, character.pos, rl.WHITE)
	} else if character.history[0].state == .KICK {
		rl.DrawTextureRec(sol_texture, {0 if character.history[0].time < -6 else 80, 408, -80 if !character.right else 80, 136}, character.pos, rl.WHITE)
	}  else if character.history[0].state == .SUPER_KICK {
		rl.DrawTextureRec(sol_texture, {160, 408, -160 if !character.right else 160, 136}, character.pos, rl.WHITE)
	} else if character.history[0].state == .FIREBALL {
		i := u8(-character.history[0].time * 5)

		rl.DrawTextureRec(sol_texture, {80 if character.history[0].time < -32 else 160, 272, -80 if !character.right else 80, 136}, character.pos, rl.WHITE)
		rl.DrawTextureEx(boom_texture, {character.pos[0] + (f32(character.history[0].time + 48) * (1 if character.right else -1)) * 4, character.pos[1] + 32}, 0, 0.1, 
			{255, 255, 255, i})
	}
}

update_character :: proc(gamepad: i32, character: ^Character) {
	switch character.history[0].state {
		case .IDLE:
		character.aerial = false
		if rl.IsGamepadButtonDown(gamepad, rl.GamepadButton.LEFT_FACE_LEFT) {
			if rl.IsGamepadButtonDown(gamepad, rl.GamepadButton.LEFT_FACE_DOWN) {
				add_to_history({.CROUCH_LEFT, 0}, &character.history)
			} else if rl.IsGamepadButtonDown(gamepad, rl.GamepadButton.LEFT_FACE_UP) {
				add_to_history({.JUMP_LEFT, 0}, &character.history)
			} else {
				add_to_history({.LEFT, 0}, &character.history)
			}
		} else if rl.IsGamepadButtonDown(gamepad, rl.GamepadButton.LEFT_FACE_RIGHT) {
			if rl.IsGamepadButtonPressed(gamepad, rl.GamepadButton.LEFT_FACE_DOWN) {
				add_to_history({.CROUCH_RIGHT, 0}, &character.history)
			} else if rl.IsGamepadButtonDown(gamepad, rl.GamepadButton.LEFT_FACE_UP) {
				add_to_history({.JUMP_RIGHT, 0}, &character.history)
			} else {
				add_to_history({.RIGHT, 0}, &character.history)
			}
		} else if rl.IsGamepadButtonDown(gamepad, rl.GamepadButton.LEFT_FACE_UP) {
			add_to_history({.JUMPING, 0}, &character.history)
		} else if rl.IsGamepadButtonDown(gamepad, rl.GamepadButton.LEFT_FACE_DOWN) {
			add_to_history({.CROUCHING, 0}, &character.history)
		} else if rl.IsGamepadButtonPressed(gamepad, rl.GamepadButton.RIGHT_FACE_DOWN) {
			add_to_history({.PUNCH, -8}, &character.history)
		} else if rl.IsGamepadButtonPressed(gamepad, rl.GamepadButton.RIGHT_FACE_RIGHT) {
			add_to_history({.KICK, -12}, &character.history)
		}

		break
		case .RIGHT:
			character.aerial = false
			character.pos[0] += 3
			if rl.IsGamepadButtonReleased(gamepad, rl.GamepadButton.LEFT_FACE_RIGHT) {
				add_to_history({.IDLE, 0}, &character.history)
			} else if rl.IsGamepadButtonDown(gamepad, rl.GamepadButton.LEFT_FACE_UP) {
				add_to_history({.JUMP_RIGHT, 0}, &character.history)
			} else if rl.IsGamepadButtonDown(gamepad, rl.GamepadButton.LEFT_FACE_DOWN) {
				add_to_history({.CROUCH_RIGHT, 0}, &character.history)
			} else if rl.IsGamepadButtonPressed(gamepad, rl.GamepadButton.RIGHT_FACE_DOWN) {
			add_to_history({.PUNCH, -8}, &character.history)
			} else if rl.IsGamepadButtonPressed(gamepad, rl.GamepadButton.RIGHT_FACE_RIGHT) {
				add_to_history({.KICK, -12}, &character.history)
			}
		break
		case .CROUCH_RIGHT:
		character.aerial = false
			if rl.IsGamepadButtonReleased(gamepad, rl.GamepadButton.LEFT_FACE_RIGHT) && rl.IsGamepadButtonReleased(gamepad, rl.GamepadButton.LEFT_FACE_DOWN) {
				add_to_history({.IDLE, 0}, &character.history)
			} else if rl.IsGamepadButtonReleased(gamepad, rl.GamepadButton.LEFT_FACE_RIGHT) {
				add_to_history({.CROUCHING, 0}, &character.history)
			} else if rl.IsGamepadButtonReleased(gamepad, rl.GamepadButton.LEFT_FACE_DOWN) {
				add_to_history({.RIGHT, 0}, &character.history)
			} else if rl.IsGamepadButtonPressed(gamepad, rl.GamepadButton.RIGHT_FACE_DOWN) {
				add_to_history({.PUNCH, -8}, &character.history)
			} else if rl.IsGamepadButtonPressed(gamepad, rl.GamepadButton.RIGHT_FACE_RIGHT) {
				add_to_history({.KICK, -12}, &character.history)
			}
		break
		case .CROUCHING:
		character.aerial = false
			if rl.IsGamepadButtonReleased(gamepad, rl.GamepadButton.LEFT_FACE_DOWN) {
				add_to_history({.IDLE, 0}, &character.history)
			} else if rl.IsGamepadButtonDown(gamepad, rl.GamepadButton.LEFT_FACE_LEFT) {
				add_to_history({.CROUCH_LEFT, 0}, &character.history)
			} else if rl.IsGamepadButtonDown(gamepad, rl.GamepadButton.LEFT_FACE_RIGHT) {
				add_to_history({.CROUCH_RIGHT, 0}, &character.history)
			} else if rl.IsGamepadButtonPressed(gamepad, rl.GamepadButton.RIGHT_FACE_DOWN) {
			add_to_history({.PUNCH, -8}, &character.history)
			} else if rl.IsGamepadButtonPressed(gamepad, rl.GamepadButton.RIGHT_FACE_RIGHT) {
				add_to_history({.KICK, -12}, &character.history)
			}
		break
		case .CROUCH_LEFT:
		character.aerial = false
			if rl.IsGamepadButtonReleased(gamepad, rl.GamepadButton.LEFT_FACE_LEFT) && rl.IsGamepadButtonReleased(gamepad, rl.GamepadButton.LEFT_FACE_DOWN) {
				add_to_history({.IDLE, 0}, &character.history)
			} else if rl.IsGamepadButtonReleased(gamepad, rl.GamepadButton.LEFT_FACE_LEFT) {
				add_to_history({.CROUCHING, 0}, &character.history)
			} else if rl.IsGamepadButtonReleased(gamepad, rl.GamepadButton.LEFT_FACE_DOWN) {
				add_to_history({.LEFT, 0}, &character.history)
			} else if rl.IsGamepadButtonPressed(gamepad, rl.GamepadButton.RIGHT_FACE_DOWN) {
			add_to_history({.PUNCH, -8}, &character.history)
			} else if rl.IsGamepadButtonPressed(gamepad, rl.GamepadButton.RIGHT_FACE_RIGHT) {
				add_to_history({.KICK, -12}, &character.history)
			}
		break
		case .LEFT:
		character.aerial = false
			character.pos[0] -= 3
			if rl.IsGamepadButtonReleased(gamepad, rl.GamepadButton.LEFT_FACE_LEFT) {
				add_to_history({.IDLE, 0}, &character.history)
			} else if rl.IsGamepadButtonDown(gamepad, rl.GamepadButton.LEFT_FACE_UP) {
				add_to_history({.JUMP_LEFT, 0}, &character.history)
			} else if rl.IsGamepadButtonDown(gamepad, rl.GamepadButton.LEFT_FACE_DOWN) {
				add_to_history({.CROUCH_LEFT, 0}, &character.history)
			} else if rl.IsGamepadButtonPressed(gamepad, rl.GamepadButton.RIGHT_FACE_DOWN) {
				add_to_history({.PUNCH, -8}, &character.history)
			} else if rl.IsGamepadButtonPressed(gamepad, rl.GamepadButton.RIGHT_FACE_RIGHT) {
				add_to_history({.KICK, -12}, &character.history)
			}
		break
		case .JUMP_LEFT:
		character.aerial = true
			character.pos[0] -= 4
			character.pos[1] -= mt.cos(f32(character.history[0].time) * 0.075) * 8
			if character.pos[1] >= GROUND_LEVEL {
				character.pos[1] = GROUND_LEVEL
				add_to_history({.IDLE, 0}, &character.history)
			}
		break
		case .JUMPING:
		character.aerial = true
			character.pos[1] -= mt.cos(f32(character.history[0].time) * 0.075) * 10
			if character.pos[1] >= GROUND_LEVEL {
				character.pos[1] = GROUND_LEVEL
				add_to_history({.IDLE, 0}, &character.history)
			}
		break
		case .JUMP_RIGHT:
		character.aerial = true
			character.pos[0] += 4
			character.pos[1] -= mt.cos(f32(character.history[0].time) * 0.075) * 8
			if character.pos[1] >= GROUND_LEVEL {
				character.pos[1] = GROUND_LEVEL
				add_to_history({.IDLE, 0}, &character.history)
			}
		break
		case .PUNCH:
		character.aerial = false
			if !character.right {
				if character.history[1].state == .LEFT && character.history[2].state == .CROUCH_LEFT {
					add_to_history({.FIREBALL, -48}, &character.history)
					break
				} 
			} else {
				if character.history[1].state == .RIGHT && character.history[2].state == .CROUCH_RIGHT {
					add_to_history({.FIREBALL, -48}, &character.history)
					break
				} 
			}		
			if character.history[0].time >= 0 {
				add_to_history({.IDLE, 0}, &character.history)
			}
		break
		case .KICK:
		character.aerial = false
			if character.right {
				if character.history[1].state == .LEFT && character.history[2].state == .CROUCH_LEFT {
					add_to_history({.SUPER_KICK, 0}, &character.history)
					break
				} 
			} else {
				if character.history[1].state == .RIGHT && character.history[2].state == .CROUCH_RIGHT {
					add_to_history({.SUPER_KICK, 0}, &character.history)
					break
				} 
			}

			if character.history[0].time >= 0 {
				add_to_history({.IDLE, 0}, &character.history)
			}
		break
		case .SUPER_KICK:
		character.aerial = true
			character.pos[0] += 6 if character.right else -6
			character.pos[1] -= mt.cos(f32(character.history[0].time) * 0.075) * 4
			if character.pos[1] >= GROUND_LEVEL {
				character.pos[1] = GROUND_LEVEL
				add_to_history({.IDLE, 0}, &character.history)
			}
		break
		case .FIREBALL:
		character.aerial = true

			if character.history[0].time >= 0 {
				add_to_history({.IDLE, 0}, &character.history)
			}		
		break
	}
}

Game_State :: enum {IN_MENU, IN_LOADING, IN_GAME, IN_DEATH}

game_load_in_time := 0

game_state : Game_State
booming : bool = false

update :: proc() {
	if game_state == .IN_MENU {
		if rl.IsGamepadButtonPressed(0, rl.GamepadButton.MIDDLE_RIGHT) {
			game_state = .IN_LOADING
			rl.PlaySound(disk_fx)
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
	else if game_state == .IN_LOADING {
		if rl.IsSoundPlaying(bg_music) {
			rl.PauseSound(bg_music)
		}		

		if rl.IsGamepadButtonPressed(0, rl.GamepadButton.MIDDLE_LEFT) {
			game_state = .IN_GAME
			rl.StopSound(disk_fx)
			return
		}

		if !rl.IsSoundPlaying(disk_fx) {
			game_state = .IN_GAME
			return
		}	

		rl.BeginDrawing()
		rl.BeginTextureMode(render_target)

		rl.ClearBackground(rl.BLACK)

		rl.DrawTexture(loading_texture, 0, 0, rl.WHITE)

		rl.EndTextureMode()

		// Draw stretched render_target, switch?
		rl.DrawTexturePro(render_target.texture, {0, 0, f32(render_target.texture.width), -f32(render_target.texture.height)}, 
			{0, 0, SCREEN_WIDTH, SCREEN_HEIGHT}, {0, 0}, 0, rl.WHITE)	

		rl.EndDrawing()		
	}
	else if game_state == .IN_GAME {
		game_load_in_time += 1 

		if game_load_in_time > 120 {
if booming {
			if !rl.IsSoundPlaying(boom_fx) {
				game_state = .IN_DEATH
			}
			return						
		}

		if !rl.IsSoundPlaying(bg_music) {
			rl.PlaySound(bg_music)
		}
		if rl.IsSoundPlaying(disk_fx) {
			rl.StopSound(disk_fx)
		}

		/*if rl.IsKeyPressed(rl.KeyboardKey.LEFT) {
			player_health += 5
		}

		if rl.IsKeyPressed(rl.KeyboardKey.RIGHT) {
			enemy_health += 5
			if enemy_health > MAX_HEALTH {
				enemy_health = 0
			}
		}*/

		player.history[0].time += 1
		enemy.history[0].time += 1

		if !player.aerial && player.history[0].time > 0 {
			if player.pos[0] > enemy.pos[0] {
				player.right = false 
			} else {
				player.right = true
			}		
		}

		if !enemy.aerial && enemy.history[0].time > 0 {
			if player.pos[0] > enemy.pos[0] {
				enemy.right = true 
			} else {
				enemy.right = false
			}		
		}

		if !rl.IsGamepadAvailable(1) {
			if enemy.history[0].time == 8 && enemy.pos[1] == GROUND_LEVEL {
				val := State(rl.GetRandomValue(0, 13))
				t : i32 = 0 if val != .PUNCH else -8
				t = 0 if val != .KICK else -12
				t = 0 if val != .FIREBALL else -48
				add_to_history({val, t}, &enemy.history)
			}
		}

		update_character(0, &player)
		update_character(1, &enemy)			

		if rl.Vector2Distance(player.pos, enemy.pos) < 16 {
			if player.right {
				player.pos[0] -= 6
				enemy.pos[0] += 6
			} else {
				player.pos[0] += 6
				enemy.pos[0] -= 6			
			}
		}

		if player.history[0].state == .FIREBALL {
			if rl.Vector2Distance(player.pos + {(f32(player.history[0].time + 48) * (1 if player.right else -1)) * 4, 32}, enemy.pos) < 64 {
				enemy.health += 1				
			}
		}
		if enemy.history[0].state == .FIREBALL {
			if rl.Vector2Distance(enemy.pos + {(f32(enemy.history[0].time + 48) * (1 if enemy.right else -1)) * 4, 32}, player.pos) < 64 {
				player.health += 1				
			}
		}

		if rl.Vector2Distance(player.pos, enemy.pos) < 32 {
			if player.history[0].state == .PUNCH {
				if player.history[0].time == -3 {
					enemy.health += 2
					if enemy.right {
						player.pos[0] += 16
						enemy.pos[0] -= 16

					} else {
						player.pos[0] -= 16
						enemy.pos[0] += 16
					}
				}
			}
			if enemy.history[0].state == .PUNCH {
				if enemy.history[0].time == -3 {
					player.health += 2 if rl.IsGamepadAvailable(1) else 10
					if enemy.right {
						player.pos[0] += 8
						enemy.pos[0] -= 8

					} else {
						player.pos[0] -= 8
						enemy.pos[0] += 8
					}
				}
			}



			if player.history[0].state == .SUPER_KICK {
				enemy.health += 2

				if enemy.right {
					player.pos[0] += 8
					enemy.pos[0] -= 8

				} else {
					player.pos[0] -= 8
					enemy.pos[0] += 8
				}
			}
			if enemy.history[0].state == .SUPER_KICK {
				player.health += 2 

				if enemy.right {
					player.pos[0] += 8
					enemy.pos[0] -= 8

				} else {
					player.pos[0] -= 8
					enemy.pos[0] += 8
				}
			}					
		}

		if rl.Vector2Distance(player.pos, enemy.pos) < 64 {
			if player.history[0].state == .KICK {
				if player.history[0].time == -6 {
					enemy.health += 10

					if enemy.right {
						player.pos[0] += 8
						enemy.pos[0] -= 8

					} else {
						player.pos[0] -= 8
						enemy.pos[0] += 8
					}
				}
			}
			if enemy.history[0].state == .KICK {
				if enemy.history[0].time == -6 {
					player.health += 10 if rl.IsGamepadAvailable(1) else 20

					if enemy.right {
						player.pos[0] += 8
						enemy.pos[0] -= 8

					} else {
						player.pos[0] -= 8
						enemy.pos[0] += 8
					}
				}
			}
			
		}

		player.pos[0] = clamp(player.pos[0], 0, GAME_WIDTH-80)
		enemy.pos[0] = clamp(enemy.pos[0], 0, GAME_WIDTH-80)

		}

		
		rl.BeginDrawing()
		rl.BeginTextureMode(render_target)

		if game_load_in_time < 120 {
			rl.BeginShaderMode(grayscale_shader)
		}

		rl.ClearBackground(rl.WHITE)

		rl.BeginMode2D(camera)

		rl.DrawTexture(background_texture, -24, 0, rl.WHITE)

		draw_character(0, player)
		draw_character(0, enemy)

		if player.health > MAX_HEALTH || enemy.health > MAX_HEALTH {
			rl.DrawTexture(boom_texture, i32(player.pos[0]) - HALF_GAME_WIDTH, i32(player.pos[1]) - HALF_GAME_HEIGHT, rl.WHITE)
		}
		
		rl.EndMode2D()

		rl.DrawTexture(health_texture, 0, 0, rl.WHITE)

		rl.DrawRectangleGradientH(48 + player.health, 25, 113 - player.health, 13, rl.RED, rl.GREEN)
		rl.DrawRectangleGradientH(195, 25, 113 - enemy.health, 13, rl.GREEN, rl.RED)

		rl.DrawTexture(timer_texture, 0, 0, rl.WHITE)

		// DEBUG
		//for i := 0; i < 10; i += 1 {
		//	rl.DrawText(fm.ctprint(player.history[i].state, player.history[i].time), 0, i32(i * 12), 12, {0, 0, 0, 64})
		//	rl.DrawText(fm.ctprint(enemy.history[i].state, enemy.history[i].time), GAME_WIDTH-100, i32(i * 12), 12, {0, 0, 0, 64})		
		//}

		if game_load_in_time < 120 {
			rl.EndShaderMode()
		}

		rl.EndTextureMode()

		// Draw stretched render_target, switch?
		rl.DrawTexturePro(render_target.texture, {0, 0, f32(render_target.texture.width), -f32(render_target.texture.height)}, 
			{0, 0, SCREEN_WIDTH, SCREEN_HEIGHT}, {0, 0}, 0, rl.WHITE)	

		rl.EndDrawing()		


		if player.health > MAX_HEALTH || enemy.health > MAX_HEALTH {
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