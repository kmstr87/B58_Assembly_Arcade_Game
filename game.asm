#####################################################################
#
# CSCB58 Winter 2023 Assembly Final Project
# University of Toronto, Scarborough
#
# Student: In Kim, 1007757973, kimin5, in.kim0128@gmail.com
#
# Bitmap Display Configuration:
# - Unit width in pixels: 8 (update this as needed)
# - Unit height in pixels: 8 (update this as needed)
# - Display width in pixels: 512 (update this as needed)
# - Display height in pixels: 512 (update this as needed)
# - Base Address for Display: 0x10008000 ($gp)
#
# Which milestones have been reached in this submission?
# (See the assignment handout for descriptions of the milestones)
# - Milestone 1/2/3 (choose the one the applies)
# Milestone 1, 2, 3 were all reached
#
# Which approved features have been implemented for milestone 3?
# (See the assignment handout for the list of additional features)
# 1. Health
# 2. Fail Condition
# 3. Moving objects
# 4. Moving platforms
# 5. Pick-up effects (green = extra heal (max. of 5), pink = extra time before fireball, purple = make fireball disappear)
#
# Link to video demonstration for final submission:
# - (insert YouTube / MyMedia / other URL here). Make sure we can view it!
#
# Are you OK with us sharing the video with people outside course staff?
# - yes / no / yes, and please share this project github link as well!
#
# Any additional information that the TA needs to know:
# - (write here, if any)
#
#####################################################################

.eqv BASE_ADDRESS 	0x10008000
.eqv CHAR_START		0x10009428		# BASE_ADDRESS + (64 * 20 + 10) * 4

.eqv PLATFORM_HIGH	0x10009248		# BASE_ADDRESS + (64 * 18 + 18) * 4
.eqv PLATFORM_HIGH_END  0x100092B4		# BASE_ADDRESS + (64 * 18 + 45) * 4 (inclusive) 
.eqv PLATFORM_MEDIUM	0x10009F00		# BASE_ADDRESS + (64 * 31) * 4
.eqv PLATFORM_MED_RESET	0x10009FC0		# BASE_ADDRESS + (64 * 31 + 48) * 4
.eqv PLATFORM_LOW	0x1000AC48		# BASE_ADDRESS + (64 * 44 + 18) * 4
.eqv PLATFORM_LOW_END	0x1000ACB4		# BASE_ADDRESS + (64 * 44 + 45) * 4 (inclusive) 

.eqv SHIFT_NEXT_Y	256			# next y shift = width of units * sizeof(byte) = 64 * 4 = 256

.eqv COLOR_BLACK	0x000000
.eqv COLOR_WHITE	0xFFFFFF
.eqv COLOR_RED		0xFF0000
.eqv COLOR_BLUE		0x0000FF
.eqv COLOR_PLATFORM	0x999191
.eqv COLOR_FIRE_MIDDLE	0xFA7907
.eqv COLOR_FIRE_INSIDE	0xDDFF00
.eqv COLOR_EXTRA_HEALTH	0x00FF00
.eqv COLOR_RESET_ITEMT	0xFFC0CB
.eqv COLOR_RESET_FIRE	0xA020F0
.eqv COLOR_HEALTH	0x32CD32

.eqv AIR_LIMIT		14

.eqv TEMP_SHIFT_I	32
.eqv CHAR_FEET_SHIFT	2816		# From CHAR_START to the position of its feet + 256 to see if char is standing on platform
.eqv PLATFORM_SHORT_END	60		# # of units needed to reach end of short platform (inclusive)
.eqv PLATFORM_MOVE_TIME 2
.eqv SPAWN_RATE		100

.data
PlatCheck: .word 0x10009F2C 0x10009F98
SpawnLocation: .word 0x10008038 0x10008078 0x100080B8
fireballLocation: .word 0 0 0
powerupLocation: .word 0 0
healthLocation: .word 0x10008104

.text
.globl main

init:
	li $s0, CHAR_START	# current position
	## Gonna get the first address of the moving platform into s1
	## Need to see if need to make moving platform short due to new platform coming in
	li $s1, PLATFORM_MOVE_TIME
	li $s2, 1		# Platform collision
	li $s3, 0		# Fireball collision
	li $s4, 0		# air time
	li $s5, 3		# # lives
	li $s6, 10	# Spawn rate for items
	li $s7, 3		# Fireball counter. When 0, drop item instead
	
	jal init_health
	
	
	jal draw_char
	
	li $a0, PLATFORM_HIGH
	
	jal draw_long
	
	la $t0, PlatCheck
	lw $a0, 0($t0)
	jal platform_update
	
	li $a0, PLATFORM_LOW
	
	jal draw_long
	
	li $s0, CHAR_START

main:	la $t9, fireballLocation
	lw $t8, 0($t9)
	
	
keypress:
	li $t8, 0xFFFF0000
	lw $t9, 0($t8)
	bne $t9, 1, shift
	lw $t9, 4($t8)
	beq $t9, 0x73, keypress_s
	beq $t9, 0x61, keypress_a
	beq $t9, 0x64, keypress_d
	beq $t9, 0x20, keypress_space

shift:
	bgtz $s4, move_up
	beqz $s2, keypress_s

itemShift:
	bnez $s1, platform_static_stand
	jal platform_update
	jal fireball_update
	jal item_update

platform_static_stand:
	move $t0, $s0
	add $t0, $t0, CHAR_FEET_SHIFT
	
	sle $t1, $t0, PLATFORM_HIGH_END
	sge $t2, $t0, PLATFORM_HIGH
	and $t3, $t1, $t2
	
	sle $t1, $t0, PLATFORM_LOW_END
	sge $t2, $t0, PLATFORM_LOW
	and $t4, $t1, $t2
	
	or $t1 $t3, $t4
	
	la $t2, PlatCheck
	lw $t3, 0($t2)
	add $t4, $t3, PLATFORM_SHORT_END
	
	sle $t5, $t0, $t4
	sge $t6, $t0, $t3
	and $t2, $t6, $t5
	or $t1, $t1, $t2
	
	la $t2, PlatCheck
	lw $t3, 4($t2)
	add $t4, $t3, PLATFORM_SHORT_END
	
	sle $t5, $t0, $t4
	sge $t6, $t0, $t3
	and $t2, $t6, $t5
	or $t1, $t1, $t2
	
	move $t2, $s2
	move $s2, $t1
	sub $t2, $t2, $t1
	bgtz $t2, reset_gravity
	beqz $t1, itemSpawn
	li $s2, 1

# Spawn item here, shift the items in itemShift. Need to figure out how to store the positions (prob another array)
itemSpawn:
	beqz $s6, spawnItem
	subi $s6, $s6, 1

draw:
	li $a0, PLATFORM_HIGH
	jal draw_long
	li $a0, PLATFORM_LOW
	jal draw_long
	jal draw_fireball
	
	
fireball_collision:
	li $t0, COLOR_FIRE_MIDDLE
	li $t1, COLOR_FIRE_INSIDE
	move $t2, $s0
	
	lw $t3, 0($t2)
	beq $t0, $t3, decrease_health
	beq $t1, $t3, decrease_health
	addi $t2, $t2, 12
	lw $t3, 0($t2)
	beq $t0, $t3, decrease_health
	beq $t1, $t3, decrease_health
	addi $t2, $t2, 2560
	beq $t0, $t3, decrease_health
	beq $t1, $t3, decrease_health
	addi $t2, $t2, -12
	lw $t3, 0($t2)
	beq $t0, $t3, decrease_health
	beq $t1, $t3, decrease_health
powerup_collision:
	li $t0, COLOR_EXTRA_HEALTH
	li $t1, COLOR_RESET_ITEMT
	li $4, COLOR_RESET_FIRE
	move $t2, $s0
	la $t9, powerupLocation
	lw $t8, 0($t9)
	lw $t7, 4($t9)
	beq $t7, $t0, eh_coll
	beq $t7, $t1, ri_coll
	
	beq $t2, $t8, reset_fire
	addi $t8, $t8, 4
	beq $t2, $t8, reset_fire
	addi $t2, $t2, 12
	beq $t2, $t8, reset_fire
	addi $t8, $t8, -4
	beq $t2, $t8, reset_fire
	addi $t2, $t2, 2560
	beq $t2, $t8, reset_fire
	addi $t8, $t8, 4
	beq $t2, $t8, reset_fire
	addi $t2, $t2, -12
	beq $t2, $t8, reset_fire
	addi $t8, $t8, -4
	beq $t2, $t8, reset_fire
	
	j nowdraw_char
	
ri_coll:
	beq $t2, $t8, reset_itemt
	addi $t8, $t8, 4
	beq $t2, $t8, reset_itemt
	addi $t2, $t2, 12
	beq $t2, $t8, reset_itemt
	addi $t8, $t8, -4
	beq $t2, $t8, reset_itemt
	addi $t2, $t2, 2560
	beq $t2, $t8, reset_itemt
	addi $t8, $t8, 4
	beq $t2, $t8, reset_itemt
	addi $t2, $t2, -12
	beq $t2, $t8, reset_itemt
	addi $t8, $t8, -4
	beq $t2, $t8, reset_itemt
	
	j nowdraw_char

eh_coll:
	beq $t2, $t8, increase_health_i
	addi $t8, $t8, 4
	beq $t2, $t8, increase_health_i
	addi $t2, $t2, 12
	beq $t2, $t8, increase_health_i
	addi $t8, $t8, -4
	beq $t2, $t8, increase_health_i
	addi $t2, $t2, 2560
	beq $t2, $t8, increase_health_i
	addi $t8, $t8, 4
	beq $t2, $t8, increase_health_i
	addi $t2, $t2, -12
	beq $t2, $t8, increase_health_i
	addi $t8, $t8, -4
	beq $t2, $t8, increase_health_i
	
nowdraw_char:
	jal draw_char
	


sleeper:
	# Wait .02 (20 milliseconds)
	li $v0, 32
	li $a0, 100
	syscall
	beqz $s1, reset_plat
	subi $s1, $s1, 1
	j loop
	
reset_plat:
	li $s1, PLATFORM_MOVE_TIME
	
loop:	j main
	
end:	
	jal reset_screen
	
	li $t9, 0x10008104
	li $t8, 0xFFFFFF
	sw $t8, 0($t9)
	sw $t8, 4($t9)
	sw $t8, 8($t9)
	sw $t8, 12($t9)
	sw $t8, 20($t9)
	sw $t8, 24($t9)
	sw $t8, 28($t9)
	sw $t8, 32($t9)
	addi $t9, $t9, SHIFT_NEXT_Y
	sw $t8, 0($t9)
	sw $t8, 20($t9)
	addi $t9, $t9, SHIFT_NEXT_Y
	sw $t8, 0($t9)
	sw $t8, 12($t9)
	sw $t8, 20($t9)
	sw $t8, 32($t9)
	addi $t9, $t9, SHIFT_NEXT_Y
	sw $t8, 0($t9)
	sw $t8, 4($t9)
	sw $t8, 8($t9)
	sw $t8, 12($t9)
	sw $t8, 20($t9)
	sw $t8, 24($t9)
	sw $t8, 28($t9)
	sw $t8, 32($t9)
	addi $t9, $t9, -SHIFT_NEXT_Y
	addi $t9, $t9, -SHIFT_NEXT_Y
	addi $t9, $t9, -SHIFT_NEXT_Y
	addi $t9, $t9, 80
	
	sw $t8, 0($t9)
	sw $t8, 12($t9)
	addi $t9, $t9, SHIFT_NEXT_Y
	sw $t8, 0($t9)
	sw $t8, 4($t9)
	sw $t8, 12($t9)
	addi $t9, $t9, SHIFT_NEXT_Y
	sw $t8, 0($t9)
	sw $t8, 8($t9)
	sw $t8, 12($t9)
	addi $t9, $t9, SHIFT_NEXT_Y
	sw $t8, 0($t9)
	sw $t8, 12($t9)
	addi $t9, $t9, -SHIFT_NEXT_Y
	addi $t9, $t9, -SHIFT_NEXT_Y
	addi $t9, $t9, -SHIFT_NEXT_Y
	addi $t9, $t9, 20
	
	addi $t9, $t9, -SHIFT_NEXT_Y
	sw $t8, 4($t9)
	sw $t8, 8($t9)
	addi $t9, $t9, SHIFT_NEXT_Y
	sw $t8, 0($t9)
	addi $t9, $t9, SHIFT_NEXT_Y
	sw $t8, 0($t9)
	sw $t8, 4($t9)
	addi $t9, $t9, SHIFT_NEXT_Y
	sw $t8, 0($t9)
	addi $t9, $t9, SHIFT_NEXT_Y
	sw $t8, 0($t9)
	sw $t8, 4($t9)
	sw $t8, 8($t9)
	addi $t9, $t9, -SHIFT_NEXT_Y
	addi $t9, $t9, -SHIFT_NEXT_Y
	addi $t9, $t9, -SHIFT_NEXT_Y
	addi $t9, $t9, 20
	
	sw $t8, 0($t9)
	sw $t8, 16($t9)
	addi $t9, $t9, SHIFT_NEXT_Y
	sw $t8, 0($t9)
	sw $t8, 8($t9)
	sw $t8, 16($t9)
	addi $t9, $t9, SHIFT_NEXT_Y
	sw $t8, 0($t9)
	sw $t8, 8($t9)
	sw $t8, 16($t9)
	addi $t9, $t9, SHIFT_NEXT_Y
	sw $t8, 0($t9)
	sw $t8, 4($t9)
	sw $t8, 12($t9)
	sw $t8, 16($t9)
	addi $t9, $t9, -SHIFT_NEXT_Y
	addi $t9, $t9, 28
	sw $t8, 0($t9)
	sw $t8, 4($t9)
	addi $t9, $t9, 8
	addi $t9, $t9, -SHIFT_NEXT_Y
	addi $t9, $t9, -SHIFT_NEXT_Y
	addi $t9, $t9, -SHIFT_NEXT_Y
	addi $t9, $t9, 8
	
	sw $t8, 4($t9)
	sw $t8, 8($t9)
	addi $t9, $t9, SHIFT_NEXT_Y
	sw $t8, 0($t9)
	sw $t8, 12($t9)
	addi $t9, $t9, SHIFT_NEXT_Y
	sw $t8, 0($t9)
	sw $t8, 4($t9)
	sw $t8, 8($t9)
	addi $t9, $t9, SHIFT_NEXT_Y
	sw $t8, 0($t9)
	addi $t9, $t9, SHIFT_NEXT_Y
	sw $t8, 0($t9)
	
end_wait:
	li $t8, 0xFFFF0000
	lw $t9, 0($t8)
	bne $t9, 1, end_reset
	lw $t9, 4($t8)
	beq $t9, 0x70, new_game
end_reset: 
	j end_wait
new_game:
	la $t9, PlatCheck
	li $t8, 0x10009f2C
	li $t7, 0x10009F98
	li $t6, 0x100080B8
	sw $t8, 0($t9)
	sw $t7, 4($t9)
	
	la $t9, SpawnLocation
	li $t8, 0x10008038
	li $t7, 0x10008078
	sw $t8, 0($t9)
	sw $t7, 4($t9)
	sw $t6, 8($t9)
	
	la $t9, fireballLocation
	li $t8, 0
	li $t7, 0
	li $t6, 0
	sw $t8, 0($t9)
	sw $t7, 4($t9)
	sw $t6, 8($t9)
	
	la $t9, powerupLocation
	sw $t8, 0($t9)
	sw $t7, 4($t9)
	
	la $t9, healthLocation
	li $t8, 0x10008104
	sw $t8, 0($t9)
	jal reset_screen
	j init
	
true_end:
	li $v0, 10 	# end the program gracefully
	syscall
	
#################################
# Functions #
#################################

reset_screen:
	li $t0, BASE_ADDRESS
	addi    $t1, $zero, 0
start_loop:
    	add    $t2, $t0, $t1
    	li    $t3, COLOR_BLACK
    	sw    $t3, 0($t2)
    
    	addi    $t1, $t1, 4
    	ble    $t1, 16380, start_loop
    
    	jr    $ra


reset_fire:
	la $t0, fireballLocation
	lw $t1, 0($t0)
	lw $t2, 4($t0)
	lw $t3, 8($t0)
	move $a0, $t1
	jal clear_fireball
	sw $v0, 0($t0)
	move $a0, $t2
	jal clear_fireball
	sw $v0, 4($t0)
	move $a0, $t3
	jal clear_fireball
	sw $v0, 8($t0)

	la $t9, powerupLocation
	lw $a0, 0($t9)
	jal clear_item
	sw $v0, 0($t9)
	j nowdraw_char
	
reset_itemt:
	li $s6, SPAWN_RATE
	
	la $t5, powerupLocation
	lw $t6, 0($t5)
	move $a0, $t6
	jal clear_item
	move $t1, $v0
	sw $t1, 0($t5)
	
	j nowdraw_char

increase_health_i:
	li $t9, 4
	bgt $s5, $t9, inc_health_i_end
	la $t0, healthLocation
	lw $t1, 0($t0)
	li $t2, COLOR_HEALTH
	
	addi $t1, $t1, 12
	sw $t2, 0($t1)
	sw $t2, 4($t1)
	addi $t1, $t1, SHIFT_NEXT_Y
	sw $t2, 0($t1)
	sw $t2, 4($t1)
	addi $t1, $t1, -SHIFT_NEXT_Y
	
	addi $s5, $s5, 1
	addi $t1, $t1, 12
	sw $t1, 0($t0)
	
inc_health_i_end:
	la $t0, powerupLocation
	lw $t1, 0($t0)
	move $a0, $t1
	jal clear_item
	sw $v0, 0($t0)
	
	j nowdraw_char

init_health:
	la $t0, healthLocation
	lw $t1, 0($t0)
	li $t2, COLOR_HEALTH
	
	sw $t2, 0($t1)
	sw $t2, 4($t1)
	addi $t1, $t1, SHIFT_NEXT_Y
	sw $t2, 0($t1)
	sw $t2, 4($t1)
	addi $t1, $t1, -SHIFT_NEXT_Y
	addi $t1, $t1, 12
	
	sw $t2, 0($t1)
	sw $t2, 4($t1)
	addi $t1, $t1, SHIFT_NEXT_Y
	sw $t2, 0($t1)
	sw $t2, 4($t1)
	addi $t1, $t1, -SHIFT_NEXT_Y
	addi $t1, $t1, 12
	
	sw $t2, 0($t1)
	sw $t2, 4($t1)
	addi $t1, $t1, SHIFT_NEXT_Y
	sw $t2, 0($t1)
	sw $t2, 4($t1)
	addi $t1, $t1, -SHIFT_NEXT_Y
	
	sw $t1, 0($t0)
	
	jr $ra

end_health:
	li $t1, 0x10008104
	li $t2, COLOR_BLACK
	
	sw $t2, 0($t1)
	sw $t2, 4($t1)
	addi $t1, $t1, SHIFT_NEXT_Y
	sw $t2, 0($t1)
	sw $t2, 4($t1)
	addi $t1, $t1, -SHIFT_NEXT_Y
	addi $t1, $t1, 12
	
	sw $t2, 0($t1)
	sw $t2, 4($t1)
	addi $t1, $t1, SHIFT_NEXT_Y
	sw $t2, 0($t1)
	sw $t2, 4($t1)
	addi $t1, $t1, -SHIFT_NEXT_Y
	addi $t1, $t1, 12
	
	sw $t2, 0($t1)
	sw $t2, 4($t1)
	addi $t1, $t1, SHIFT_NEXT_Y
	sw $t2, 0($t1)
	sw $t2, 4($t1)
	addi $t1, $t1, -SHIFT_NEXT_Y
	addi $t1, $t1, 12
	
	sw $t2, 0($t1)
	sw $t2, 4($t1)
	addi $t1, $t1, SHIFT_NEXT_Y
	sw $t2, 0($t1)
	sw $t2, 4($t1)
	addi $t1, $t1, -SHIFT_NEXT_Y
	addi $t1, $t1, 12
	
	sw $t2, 0($t1)
	sw $t2, 4($t1)
	addi $t1, $t1, SHIFT_NEXT_Y
	sw $t2, 0($t1)
	sw $t2, 4($t1)
	addi $t1, $t1, -SHIFT_NEXT_Y
	addi $t1, $t1, 12
	
	li $s5, 0
	
	jr $ra

	
decrease_health:
	la $t0, healthLocation
	lw $t1, 0($t0)
	li $t2, COLOR_BLACK
	
	sw $t2, 0($t1)
	sw $t2, 4($t1)
	addi $t1, $t1, SHIFT_NEXT_Y
	sw $t2, 0($t1)
	sw $t2, 4($t1)
	addi $t1, $t1, -SHIFT_NEXT_Y
	
	addi $s5, $s5, -1
	
	blez $s5, end
	
	addi $t1, $t1, -12
	sw $t1, 0($t0)
	
	j powerup_collision

spawnItem:
	li $s6, SPAWN_RATE	# Since time until spawn hit zero, reset it
	la $t0, SpawnLocation	# Load address of the variable which contains an array of 3 spawn location
	
	# Pseudorandom integer generator from 0-2
	li $a1, 3
	li $v0, 42
	syscall
	
	move $t1, $a0
	li $t2, 4		
	mul $t1, $t1, $t2	# Mult. the pseudorandom # * 4
	add $t2, $t0, $t1	# Addr. of SpawnLocation arrauy + result from above
	
	lw $t1, 0($t2)		# Get the new spawn location for next item
	move $a0, $t1
	
	bnez $s7 fireballSpawn
	li $s7, 3
	
powerupSpawn:
	la $t0, powerupLocation
	
	sw $t1, 0($t0)
	# Pseudorandom integer generator from 0-2
	li $a1, 3
	li $v0, 42
	syscall

	beqz, $a0, go_reset_fire		# purple
	li $t2, 1
	beq $a0, $t2, go_reset_itemt	# pink
extraHealth:				# Green
	li $t2, COLOR_EXTRA_HEALTH
	sw $t2, 4($t0)
	j draw
go_reset_itemt:	
	li $t2, COLOR_RESET_ITEMT
	sw $t2, 4($t0)
	j draw

go_reset_fire: 
	li $t2, COLOR_RESET_FIRE
	sw $t2, 4($t0)
	j draw
	
fireballSpawn:
	addi $s7, $s7, -1
	la $t0, fireballLocation
	lw $t1, 0($t0)
	
	li $t8, 0
	
fireballLoop:
	li $t9, 8
	bgt $t8, $t9, end
	move $a1, $t8
	beqz $t1, fireballStart
	addi $t8, $t8, 4
	add $t0, $t0, $t8
	lw $t1, 0($t0)
	j fireballLoop

### Need to make a start_fireball label which draws the first fireball. Also, need to check if the new location will be stored properly
fireballStart:
	move $t0, $a0
	li $t4, COLOR_BLACK
	li $t5, COLOR_FIRE_MIDDLE
	li $t6, COLOR_FIRE_INSIDE
	
	sw $t4, 0($t0)
	sw $t4, 4($t0)
	sw $t5, 8($t0)
	sw $t4, 12($t0)
	sw $t4, 16($t0)
	addi $t0, $t0, SHIFT_NEXT_Y
	sw $t4, 0($t0)
	sw $t5, 4($t0)
	sw $t5, 8($t0)
	sw $t6, 12($t0)
	sw $t4, 16($t0)
	addi $t0, $t0, SHIFT_NEXT_Y
	sw $t5, 0($t0)
	sw $t6, 4($t0)
	sw $t6, 8($t0)
	sw $t5, 12($t0)
	sw $t5, 16($t0)
	addi $t0, $t0, SHIFT_NEXT_Y
	sw $t5, 0($t0)
	sw $t5, 4($t0)
	sw $t5, 8($t0)
	sw $t6, 12($t0)
	sw $t5, 16($t0)
	addi $t0, $t0, SHIFT_NEXT_Y
	sw $t5, 0($t0)
	sw $t6, 4($t0)
	sw $t5, 8($t0)
	sw $t5, 12($t0)
	sw $t5, 16($t0)
	addi $t0, $t0, SHIFT_NEXT_Y
	sw $t5, 4($t0)
	sw $t6, 8($t0)
	sw $t5, 12($t0)
	addi $t0, $t0, SHIFT_NEXT_Y
	sw $t5, 8($t0)

fireballEnd:
	la $t0, fireballLocation
	add $t0, $t0, $a1
	sw $a0, 0($t0)
	
	j draw


### Keypress	

keypress_s:
	bnez $s4, move_up
	li $t9, BASE_ADDRESS
	addi $t9, $t9, 13824
	bgt $s0, $t9, end
	bnez $s4, itemShift
	
	li $t1, COLOR_BLACK
	sw $t1, 0($s0)
	sw $t1, 4($s0)
	sw $t1, 8($s0)
	sw $t1, 12($s0)
	addi $s0, $s0, SHIFT_NEXT_Y
	
	j itemShift
	
keypress_space:
	bnez $s4, move_up
	beqz $s2, keypress_s
	li $s4, AIR_LIMIT
	j move_up

move_up:
	li $t9, BASE_ADDRESS
	blt $s0, $t9, end
	
	addi $s4, $s4, -1
	move $a0, $s0
	li $t0, SHIFT_NEXT_Y
	li $t1, 10
	mul $t1, $t1, $t0
	add $s0, $s0, $t1
	li $t1, COLOR_BLACK
	sw $t1, 0($s0)
	sw $t1, 4($s0)
	sw $t1, 8($s0)
	sw $t1, 12($s0)
	move $s0, $a0
	addi $s0, $s0, -SHIFT_NEXT_Y
	
	j itemShift
	
keypress_d:
	li $t1, COLOR_BLACK
	
	li $t8, SHIFT_NEXT_Y
	div $s0, $t8
	mfhi $t9
	subi $t8, $t8, 16
	beq $t9, $t8, itemShift
	
	move $a0, $s0
	
	sw $t1, 0($s0)
	addi $s0, $s0, SHIFT_NEXT_Y
	sw $t1, 0($s0)
	addi $s0, $s0, SHIFT_NEXT_Y
	sw $t1, 0($s0)
	addi $s0, $s0, SHIFT_NEXT_Y
	sw $t1, 0($s0)
	addi $s0, $s0, SHIFT_NEXT_Y
	sw $t1, 0($s0)
	addi $s0, $s0, SHIFT_NEXT_Y
	sw $t1, 0($s0)
	addi $s0, $s0, SHIFT_NEXT_Y
	sw $t1, 0($s0)
	addi $s0, $s0, SHIFT_NEXT_Y
	sw $t1, 0($s0)
	addi $s0, $s0, SHIFT_NEXT_Y
	sw $t1, 0($s0)
	addi $s0, $s0, SHIFT_NEXT_Y
	sw $t1, 0($s0)
	addi $s0, $s0, SHIFT_NEXT_Y
	sw $t1, 0($s0)
	
	move $s0, $a0
	addi $s0, $s0, 4
	
	j shift
	
keypress_a:
	li $t1, COLOR_BLACK
	
	li $t8, SHIFT_NEXT_Y
	div $s0, $t8
	mfhi $t9
	beqz $t9, itemShift
	
	move $a0, $s0
		
	addi $s0, $s0, 12
	sw $t1, 0($s0)
	addi $s0, $s0, SHIFT_NEXT_Y
	sw $t1, 0($s0)
	addi $s0, $s0, SHIFT_NEXT_Y
	sw $t1, 0($s0)
	addi $s0, $s0, SHIFT_NEXT_Y
	sw $t1, 0($s0)
	addi $s0, $s0, SHIFT_NEXT_Y
	sw $t1, 0($s0)
	addi $s0, $s0, SHIFT_NEXT_Y
	sw $t1, 0($s0)
	addi $s0, $s0, SHIFT_NEXT_Y
	sw $t1, 0($s0)
	addi $s0, $s0, SHIFT_NEXT_Y
	sw $t1, 0($s0)
	addi $s0, $s0, SHIFT_NEXT_Y
	sw $t1, 0($s0)
	addi $s0, $s0, SHIFT_NEXT_Y
	sw $t1, 0($s0)
	addi $s0, $s0, SHIFT_NEXT_Y
	sw $t1, 0($s0)
	
	move $s0, $a0
	addi $s0, $s0, -4	
	
	j shift
	
reset_gravity:
	li $s2, 0
	j itemSpawn
		
item_update:
	la $t0, powerupLocation
	lw $t1, 0($t0)
	lw $t2, 4($t0)
	li $t3, BASE_ADDRESS
	addi $t3, $t3, 15360
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
item_check:
	beqz $t1, redraw_item
	addi $t1, $t1, SHIFT_NEXT_Y
	move $a0, $t1
	blt $t1, $t3, redraw_item
	jal clear_item
	move $t1, $v0
	sw $t1, 0($t0)
	jr $ra
	
redraw_item:
	move $a0, $t1
	la $t0, powerupLocation
	sw $t1, 0($t0)
	sw $t2, 4($t0)
	jal draw_item
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
	
fireball_update:
	la $t0, fireballLocation
	lw $t1, 0($t0)
	lw $t2, 4($t0)
	lw $t3, 8($t0)
	li $t4, BASE_ADDRESS
	addi $t4, $t4, 14848
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
fireball_one_update:
	beqz $t1, fireball_two_update
	addi $t1, $t1, SHIFT_NEXT_Y
	move $a0, $t1
	blt $t1, $t4, fireball_two_update
	jal clear_fireball
	move $t1, $v0
fireball_two_update:
	beqz $t2, fireball_three_update
	addi $t2, $t2, SHIFT_NEXT_Y
	move $a0, $t2
	blt $t2, $t4, fireball_three_update
	jal clear_fireball
	move $t2, $v0
fireball_three_update:
	beqz $t3, redraw_fireball
	addi $t3, $t3, SHIFT_NEXT_Y
	move $a0, $t3
	blt $t3, $t4, redraw_fireball
	jal clear_fireball
	move $t3, $v0
redraw_fireball:
	la $t0, fireballLocation
	sw $t1, 0($t0)
	sw $t2, 4($t0)
	sw $t3, 8($t0)
	jal draw_fireball
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra

platform_update:
	la $t0, PlatCheck
	lw $t1, 0($t0)
	lw $t2, 4($t0)
	ble $t1, PLATFORM_MEDIUM, update_plat_one
	addi $t1, $t1, -4
	ble $t2, PLATFORM_MEDIUM, update_plat_two
	addi $t2, $t2, -4
	li $t3, 0
	j draw_short
	
update_plat_one:
	move $t3, $t1
	li $t1, PLATFORM_MED_RESET
	addi $t2, $t2, -4
	j draw_short

update_plat_two:
	move $t3, $t2
	li $t2, PLATFORM_MED_RESET
	j draw_short
## Drawing

draw_short:
	sw $t1, 0($t0)
	sw $t2, 4($t0)
	li $t4, COLOR_PLATFORM
	li $t5, COLOR_BLACK
	sw $t4, 0($t1)
	sw $t4, 4($t1)
	sw $t4, 8($t1)
	sw $t4, 12($t1)
	sw $t4, 16($t1)
	sw $t4, 20($t1)
	sw $t4, 24($t1)
	sw $t4, 28($t1)
	sw $t4, 32($t1)
	sw $t4, 36($t1)
	sw $t4, 40($t1)
	sw $t4, 44($t1)
	sw $t4, 48($t1)
	sw $t4, 52($t1)
	sw $t4, 56($t1)
	sw $t4, 60($t1)
	sw $t5, 64($t1)
	
	sw $t4, 0($t2)
	sw $t4, 4($t2)
	sw $t4, 8($t2)
	sw $t4, 12($t2)
	sw $t4, 16($t2)
	sw $t4, 20($t2)
	sw $t4, 24($t2)
	sw $t4, 28($t2)
	sw $t4, 32($t2)
	sw $t4, 36($t2)
	sw $t4, 40($t2)
	sw $t4, 44($t2)
	sw $t4, 48($t2)
	sw $t4, 52($t2)
	sw $t4, 56($t2)
	sw $t4, 60($t2)
	sw $t5, 64($t2)
	
	bnez $t3, clear
	
	jr $ra
	
clear:
	sw $t5, 0($t3)
	sw $t5, 4($t3)
	sw $t5, 8($t3)
	sw $t5, 12($t3)
	sw $t5, 16($t3)
	sw $t5, 20($t3)
	sw $t5, 24($t3)
	sw $t5, 28($t3)
	sw $t5, 32($t3)
	sw $t5, 36($t3)
	sw $t5, 40($t3)
	sw $t5, 44($t3)
	sw $t5, 48($t3)
	sw $t5, 52($t3)
	sw $t5, 56($t3)
	sw $t5, 60($t3)
	
	jr $ra
	
draw_long:
	move $t0, $a0
	li $t4, COLOR_PLATFORM
	sw $t4, 0($t0)
	sw $t4, 4($t0)
	sw $t4, 8($t0)
	sw $t4, 12($t0)
	sw $t4, 16($t0)
	sw $t4, 20($t0)
	sw $t4, 24($t0)
	sw $t4, 28($t0)
	sw $t4, 32($t0)
	sw $t4, 36($t0)
	sw $t4, 40($t0)
	sw $t4, 44($t0)
	sw $t4, 48($t0)
	sw $t4, 52($t0)
	sw $t4, 56($t0)
	sw $t4, 60($t0)
	sw $t4, 64($t0)
	sw $t4, 68($t0)
	sw $t4, 72($t0)
	sw $t4, 76($t0)
	sw $t4, 80($t0)
	sw $t4, 84($t0)
	sw $t4, 88($t0)
	sw $t4, 92($t0)
	sw $t4, 96($t0)
	sw $t4, 100($t0)
	sw $t4, 104($t0)
	sw $t4, 108($t0)
	
	jr $ra
	
draw_char:
	move $t0, $s0
	li $t1, COLOR_BLUE
	li $t2, COLOR_WHITE 
	li $t3, COLOR_RED
	li $t4, COLOR_BLACK
	sw $t3, 0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 12($t0)
	addi $t0, $t0, SHIFT_NEXT_Y
	sw $t2, 0($t0) 		
	sw $t2, 4($t0)	 	
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	addi $t0, $t0, SHIFT_NEXT_Y
	sw $t2, 0($t0) 		
	sw $t2, 4($t0)	 	
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	addi $t0, $t0, SHIFT_NEXT_Y
	sw $t2, 0($t0) 		
	sw $t2, 4($t0)	 	
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	addi $t0, $t0, SHIFT_NEXT_Y
	sw $t4, 0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t4, 12($t0)
	addi $t0, $t0, SHIFT_NEXT_Y
	sw $t3, 0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 12($t0)
	addi $t0, $t0, SHIFT_NEXT_Y
	sw $t4, 0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t4, 12($t0)
	addi $t0, $t0, SHIFT_NEXT_Y
	sw $t4, 0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t4, 12($t0)
	addi $t0, $t0, SHIFT_NEXT_Y
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	addi $t0, $t0, SHIFT_NEXT_Y
	sw $t1, 0($t0)
	sw $t4, 4($t0)
	sw $t4, 8($t0)
	sw $t1, 12($t0)
	addi $t0, $t0, SHIFT_NEXT_Y
	sw $t1, 0($t0)
	sw $t4, 4($t0)
	sw $t4, 8($t0)
	sw $t1, 12($t0)
	jr $ra
	
clear_item:
	li $t4, COLOR_BLACK
	addi $a0, $a0, -SHIFT_NEXT_Y
	
	sw $t4, -4($a0)
	sw $t4, 0($a0)
	sw $t4, 4($a0)
	sw $t4, 8($a0)
	addi $a0, $a0, SHIFT_NEXT_Y
	sw $t4, -4($a0)
	sw $t4, 0($a0)
	sw $t4, 4($a0)
	sw $t4, 8($a0)
	addi $a0, $a0, SHIFT_NEXT_Y
	sw $t4, -4($a0)
	sw $t4, 0($a0)
	sw $t4, 4($a0)
	sw $t4, 8($a0)
	addi $a0, $a0, SHIFT_NEXT_Y
	sw $t4, -4($a0)
	sw $t4, 0($a0)
	sw $t4, 4($a0)
	sw $t4, 8($a0)
	
	li $v0, 0
	
	jr $ra

clear_fireball:
	li $t5, COLOR_BLACK
	beqz $a0, clear_fireball_end
	addi $a0, $a0, -SHIFT_NEXT_Y
	
	sw $t5, 0($a0)
	sw $t5, 4($a0)
	sw $t5, 8($a0)
	sw $t5, 12($a0)
	sw $t5, 16($a0)
	addi $a0, $a0, SHIFT_NEXT_Y
	sw $t5, 0($a0)
	sw $t5, 4($a0)
	sw $t5, 8($a0)
	sw $t5, 12($a0)
	sw $t5, 16($a0)
	addi $a0, $a0, SHIFT_NEXT_Y
	sw $t5, 0($a0)
	sw $t5, 4($a0)
	sw $t5, 8($a0)
	sw $t5, 12($a0)
	sw $t5, 16($a0)
	addi $a0, $a0, SHIFT_NEXT_Y
	sw $t5, 0($a0)
	sw $t5, 4($a0)
	sw $t5, 8($a0)
	sw $t5, 12($a0)
	sw $t5, 16($a0)
	addi $a0, $a0, SHIFT_NEXT_Y
	sw $t5, 0($a0)
	sw $t5, 4($a0)
	sw $t5, 8($a0)
	sw $t5, 12($a0)
	sw $t5, 16($a0)
	addi $a0, $a0, SHIFT_NEXT_Y
	sw $t5, 0($a0)
	sw $t5, 4($a0)
	sw $t5, 8($a0)
	sw $t5, 12($a0)
	sw $t5, 16($a0)
	addi $a0, $a0, SHIFT_NEXT_Y
	sw $t5, 4($a0)
	sw $t5, 8($a0)
	sw $t5, 12($a0)
	addi $a0, $a0, SHIFT_NEXT_Y
	sw $t5, 8($a0)
	
	li $v0, 0

clear_fireball_end:
	jr $ra

draw_item:
	la $t9, powerupLocation
	lw $t0, 0($t9)
	lw $t5, 4($t9)
	li $t4, COLOR_BLACK

	beqz $t0, draw_powerup_end
	addi $t0, $t0, -SHIFT_NEXT_Y
	sw $t4, 0($a0)
	sw $t4, 4($a0)
	addi $a0, $a0, SHIFT_NEXT_Y
	sw $t5, 0($a0)
	sw $t5, 4($a0)
	addi $a0, $a0, SHIFT_NEXT_Y
	sw $t5, 0($a0)
	sw $t5, 4($a0)
	
draw_powerup_end:
	jr $ra

draw_fireball:
	la $t9, fireballLocation
	li $t8, 0
	add $t7, $t8, $t9
	lw $t0, 0($t7)
draw_fireball_start:
	beqz $t0, draw_fireball_loop
	addi $t0, $t0, -SHIFT_NEXT_Y
	
	li $t4, COLOR_BLACK
	li $t5, COLOR_FIRE_MIDDLE
	li $t6, COLOR_FIRE_INSIDE
	
	sw $t4, 8($t0)
	addi $t0, $t0, SHIFT_NEXT_Y
	sw $t4, 0($t0)
	sw $t4, 4($t0)
	sw $t5, 8($t0)
	sw $t4, 12($t0)
	sw $t4, 16($t0)
	addi $t0, $t0, SHIFT_NEXT_Y
	sw $t4, 0($t0)
	sw $t5, 4($t0)
	sw $t5, 8($t0)
	sw $t6, 12($t0)
	sw $t4, 16($t0)
	addi $t0, $t0, SHIFT_NEXT_Y
	sw $t5, 0($t0)
	sw $t6, 4($t0)
	sw $t6, 8($t0)
	sw $t5, 12($t0)
	sw $t5, 16($t0)
	addi $t0, $t0, SHIFT_NEXT_Y
	sw $t5, 0($t0)
	sw $t5, 4($t0)
	sw $t5, 8($t0)
	sw $t6, 12($t0)
	sw $t5, 16($t0)
	addi $t0, $t0, SHIFT_NEXT_Y
	sw $t5, 0($t0)
	sw $t6, 4($t0)
	sw $t5, 8($t0)
	sw $t5, 12($t0)
	sw $t5, 16($t0)
	addi $t0, $t0, SHIFT_NEXT_Y
	sw $t5, 4($t0)
	sw $t6, 8($t0)
	sw $t5, 12($t0)
	addi $t0, $t0, SHIFT_NEXT_Y
	sw $t5, 8($t0)
	
draw_fireball_loop:
	addi $t8, $t8, 4
	li $t2, 8
	bgt $t8, $t2, draw_fireball_end
	add $t7, $t8, $t9
	lw $t0, 0($t7)
	j draw_fireball_start
	
draw_fireball_end:
	jr $ra