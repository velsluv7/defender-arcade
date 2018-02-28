;----------------------------------------------------------------------
; defender arcade.asm
; Author - velappan ramasamy
; A welcome screen is displayed asking the user to play or see the instruction for playing the game 
; Use keyboard arrows to select the options
; using the specified directions keys the space ship is moved and then fired  
; Alien shooting is also done 
;Power management is also achieved. Press P will pause the game
; the mountains are scrolled as and when u shoot
; 3 lifes are given for you to win
; scores increases as and when u shoot the alien
; you can quit the game any time and it will give u the game statistics
; little bit of graphics is also given to the hyper terminal
;----------------------------------------------------------------------
;       m a i n    p r o g r a m
; ----------------------------------------------------------------------
#include <sfr51.inc>         ; 8051 SFR and ports are defined here
; --------------------------    Assign labels to inputs and outputs
STACK     equ      40h    	; Stack pointer starting address(growing upward)
value2    equ      b7h		; timer values
value1    equ      ffh		; timer values
timecnt   equ      30h		; time count address 
TAR       equ     0c7h      ; Time access register

DATA_LED        bit     P2.2    ; spi data bit
ENABLE_LED      bit     P2.0    ; spi enable bit
CLK_LED         bit     P2.1    ; spi clock bit
LED_GREEN       bit     P1.0    ; Green LED at Port 1, bit 0             
LED_RED         bit     P1.1    ; Red LED at Port 1, bit 1



bseg
data_txn:    		dbit 1      ;flag used for transmitting 
inst_flag: 		    dbit 1		;instructions page flag		
start_flag: 		dbit 1		;start page flag
esc_flag:   		dbit 1		;flag used for ESC - 1B
bracket_flag: 		dbit 1		;flag used for [ - 5B
uplock: 			dbit 1		;flag used to check for cursor moving - up
downlock:   		dbit 1		;flag used to check for cursor moving  - down
second_page:    	dbit 1		;flag used in second page
main_page:  		dbit 1		;main screnn flag
play_flag:  		dbit 1		;flag set during the game
end_shoot: 			dbit 1		;flag used for shooting
alien_up_flag:  	dbit 1		;flag for the alien movement
one_sec:   			dbit 1		;one sec flag
bullet_sent: 		dbit 1		;flag to check the bullet
alien_shoot_flag: 	dbit 1		;flag to check whether alien shooting 
game_over_flag: 	dbit 1		;flag to check whether game over or not 
game_end_flag: 		dbit 1		;flag to come out of the game screen	
ship_dead_flag: 	dbit 1		;flag to check whether ship dead or alive
suspend:        	dbit 1		;flag to check for suspend mode 
end               				; end of bseg


dseg at 30h						;non-volatile segment
SAVESP:     	ds 1		    ;byte for saving stack pointer
ship_row:   	ds 1			;byte for storing ship row
ship_colm:  	ds 1			;byte for storing ship column
alien_row:  	ds 1			;byte for storing aliens row
alien_colm: 	ds 1			;byte for storing aliens colm
alien_row_1: 	ds 1			;byte after splitin aliens row
alien_row_2: 	ds 1			;byte after splitin aliens row
alien_col_1: 	ds 1			;byte for splitin aliens colm
alien_col_2: 	ds 1			;byte for splitin aliens colm
score:			ds 1			;byte to calculate the score
ship_pos:   	ds 1			;byte for ship position
ship_life:		ds 1			;byte for ships life
mount_colm: 	ds 1			;byte for mount colm

end


; ----------------------------- Start execution at 0000h after reset/power-up
cseg at 0                       ; absolute code segment starting at 0000h
    ajmp   Start                ; first instruction is to jump to user program
cseg at 0003h					; Interrupt 0 Vector address
    ljmp INT0_ISR 				; jump to EX0-ISR
cseg at 0bh                     ; Timer 0 interrupt Vector address
    ljmp   Timer0_ISR			; jump to TIMER-ISR
cseg at 23h                     ;Serial interrupt Vector address
    ljmp    Serial_ISR			; jump to jump to serial-ISR
; ----------------------------- Start of user program 
cseg at 90h  
	dec_1:  db      "*********************************************************************"
	welc:   db      "*                      DEFENDER ARCADE                              *"
	dec_2:  db      "*********************************************************************"
	menu:   db      "MENU SELECTION"                                    
	item_1: db      "1.Instructions and credits"
	item_2: db      "2.Start Game              "
	item_3: db      "Press Q for Quit"
	arrow:  db      "<-"
	info:   db      "*     ---velappan--- embeddedd Systems--- EPP lab assessment ----   *"      		
	inst1:  db      "move left  -- a"
	inst2:  db      "move right -- d"
	inst3:  db      "move up    -- w"
	inst4:  db      "move down  -- s"
	inst5:  db      "shoot  -- space"
	inst6:	db		"quit   -- q    "
	inst7:  db 		"                        SCORE 10 TO WIN                              "
	alien:  db      "<_**_>"
	ship:   db      "+\''/+"
	bullet: db      "<" 
	mount:  db      "#"
	score1:	db 		"SCORE: "
	life1:  db		"LIFE:" 
	g_over:	db      "GAME OVER"
	g_score: db 	"YOUR SCORE IS "
	anykey: db 		"PRESS ANY KEY"
	win:	db 		"YOU WON :-)"
	status: db   "SUSPEND MODE"
	pause1:	db   "PAUSE - P"
Start:
	mov     a,PCON
    anl     a,#40h
    cjne    a,#40h,power_reset_mode
    mov     SP, SAVESP
    pop     PSW
    pop     acc
    mov     TAR, #aah
    mov     TAR, #55h
    anl     PCON, #BCh
    clr     suspend
    lcall Init_Serial 
	lcall   Init_int0
	lcall Init_Timer0
	setb TR0
	ajmp main_loop


power_reset_mode:
    mov    SP,#STACK                                          ; Set up the stack pointer
  	lcall Init_Serial                                         
    lcall   clear_page
	lcall   Init_int0
	lcall display_menu
    clr   LED_RED
    clr   LED_GREEN
    clr esc_flag
    clr bracket_flag
    setb start_flag
    clr inst_flag
    clr esc_flag
    clr bracket_flag
    clr uplock
    clr play_flag
    clr end_shoot
	clr bullet_sent
	clr alien_shoot_flag
	clr  game_over_flag
	clr game_end_flag
	clr ship_dead_flag
	setb downlock
   

main_loop:
    orl PCON,#01h
	jb alien_up_flag,alien_right
serial_inputs:	
	jbc data_txn,check
    ajmp main_loop
check:
     ajmp check_key  
game_won:
	clr TR0
	lcall clear_page
	lcall display_game_won
	ajmp exit
game_over:
	clr TR0
	lcall clear_page
	acall display_game_over
	acall press_any
	acall display_game_score 
exit:
	setb game_end_flag
	ajmp main_loop
alien_right:
	clr alien_up_flag
	mov a,alien_colm
	mov R3,a
	mov a,ship_colm
	subb a,R3
	cjne a,#0,do_next
	mov a,alien_row
	mov R3,a
	mov a,ship_row
	subb a,R3
	cjne a,#0,new_alien
	setb ship_dead_flag
	ajmp restart_ship
do_next:
	
	jc new_alien
	mov a,alien_row
	cjne a,ship_row,check_direct
	lcall save_cursor  
	lcall delete_alien
    clr a 
    mov a,alien_colm
	cjne a,#73,move_alien
	clr TR0
	lcall delete_alien
	lcall alien_display_new
	mov alien_row,#2
    mov alien_colm,#2
	lcall restore_cursor
	setb TR0
	ajmp main_loop
new_alien:
	lcall save_cursor
	clr TR0
	lcall delete_alien
	lcall alien_display_new
	mov alien_row,#2
    mov alien_colm,#2
	lcall restore_cursor
	setb TR0
	ajmp main_loop	
check_direct:
	mov R6,a
	mov a,ship_row
	subb a,R6
	
	jc alien_move_up
	lcall save_cursor  
	lcall delete_alien
	lcall cursor_down
	lcall cursor_right
	mov a,alien_colm
	inc a
	mov alien_colm,a
	mov a,alien_row
	inc a
	mov alien_row,a
	acall shoot_alien
	jb ship_dead_flag,re_born
    lcall alien_move_display
	CPL LED_RED
    lcall restore_cursor
	ajmp main_loop

alien_move_up:
	lcall save_cursor  
	lcall delete_alien
	lcall cursor_up
	lcall cursor_right
	mov a,alien_colm
	inc a
	mov alien_colm,a
	mov a,alien_row
	dec a
	mov alien_row,a
	acall shoot_alien
	jb ship_dead_flag,re_born
    lcall alien_move_display
	CPL LED_RED
    lcall restore_cursor
	ajmp main_loop

    
move_alien:
	inc a
    mov alien_colm,a
	acall shoot_alien
	jb ship_dead_flag,re_born
    lcall alien_move_display
	CPL LED_RED
    lcall restore_cursor
	ajmp main_loop
re_born:
	clr TR0
	lcall restore_cursor
restart_ship: 
	lcall delete_ship
	mov a,ship_life
	dec a
	cjne a,#00h,saved_ship
	ajmp game_over
saved_ship:
	mov ship_life,a
	lcall new_life
	lcall ship_display
    mov ship_row,#5
    mov ship_colm,#73
	clr ship_dead_flag
	setb TR0
	ajmp main_loop
shoot_alien:
	mov a,alien_colm
	mov b,#5
	div AB
    mov A,B
	cjne A,#0,dont_shoot
	mov a,alien_colm
	add a,#6
	mov R1,a
	mov a,#80
	subb a,R1
	mov R1,a
	lcall cursor_right_6
	mov a,alien_row
	cjne a,ship_row,not_kill
	
	mov a,alien_colm
	mov R4,a
	mov a,ship_colm
	subb a,R4
	jc wrong_shoot
	
	mov a,ship_colm
	mov R2,a
	mov a,#80
	subb a,R2
    mov ship_pos,a
s1:
	cjne a,ship_pos,proceed
	setb ship_dead_flag
	ajmp dont_shoot
proceed:
	lcall display_bullet
	lcall cursor_left
	lcall delete_bullet
	djnz R1,s1
dont_shoot:
	ret
wrong_shoot:
	clr c 
not_kill:
	lcall display_bullet
	lcall cursor_left
	lcall delete_bullet
	djnz R1,not_kill
	ajmp dont_shoot
check_key:
	jb game_end_flag,quit_game
    jnb play_flag,quit_key
	cjne a,#70h,left_key
	setb suspend
	lcall init_suspend
	
left_key:	
  	cjne a,#61h,up_key 
    clr end_shoot
    clr a
    mov a,ship_colm
    cjne a,#2,move_left
    ajmp main_loop     
move_left:
    clr a                   ; move left
    mov a,ship_colm
    dec a 
    mov ship_colm,a
    lcall ship_left
    ajmp main_loop
up_key:
	cjne a,#77h,down_key
    clr a
    mov a,ship_row
    cjne a,#2,move_up
    ajmp main_loop
move_up:    
    clr a
    mov a,ship_row
    dec a
    mov ship_row,a
    lcall ship_up
    ajmp main_loop
down_key:
    cjne a,#73h,right_key
    clr a
    mov a,ship_row
    cjne a,#20,move_down
    ajmp main_loop
move_down:
    clr a
    mov a,ship_row
    inc a 
    mov ship_row,a
    lcall ship_down
    ajmp main_loop
right_key:
    cjne a,#64h,space_key
    clr a 
    mov a,ship_colm
    cjne a,#74,move_right
    setb end_shoot
    ajmp main_loop
move_right:
    clr a
    mov a,ship_colm
    inc a
    mov ship_colm,a
    lcall ship_right
    ajmp main_loop
quit_key:
    cjne a,#71h,enter_key
    clr TR0
quit_game:
	lcall clear_page
	jbc game_end_flag,quit
	jb  game_over_flag,disp_game
quit:
	clr game_over_flag
	lcall display_menu
    jbc second_page,clear
    clr main_page
    clr play_flag
    clr uplock
    setb downlock
    ajmp main_loop	
disp_game:
	lcall clear_page
	acall display_game_over
	acall press_any
	acall display_game_score 
	setb game_end_flag
	ajmp main_loop
space_key:
    cjne a,#20h,quit_key
	mov a,ship_row
	cjne a,alien_row,no_alien_hit
	clr TR0
	setb bullet_sent
no_alien_hit:
	jb end_shoot,begin1
    lcall save_cursor
    lcall ship_shoot
   	CPL LED_GREEN
	jb bullet_sent,late_restore
	jc cont_alien
	lcall move_mount
	lcall restore_cursor
	ajmp main_loop
late_restore:
	lcall alien_display_new
	mov alien_row,#2
    mov alien_colm,#2
	clr bullet_sent
	lcall move_mount
	lcall restore_cursor
cont_alien:
	setb TR0
	clr c 
	lcall restore_cursor
	ajmp main_loop

clear:
    setb downlock
    clr uplock
begin1:
    ajmp main_loop
enter_key:
    cjne a,#0dh,not_enter
	jb second_page,begin1
    jb downlock,game_begin
    jb uplock,inst
    ajmp main_loop
game_begin:
    ajmp game    
not_enter:
    jb play_flag,begin
    cjne a,#1Bh,check_next
    setb esc_flag  
    ajmp main_loop    
check_next:
    jb esc_flag,check_bracket
    jb bracket_flag,options
    ajmp main_loop
check_bracket:
    cjne a,#5Bh,begin
    clr esc_flag
    setb bracket_flag
    ajmp main_loop
options:
    clr bracket_flag
    cjne a,#41h,next_key1
    jb uplock,begin
    setb inst_flag
    clr start_flag
    lcall delete_arrow
    lcall cursor_left
    lcall cursor_left
    lcall cursor_up
    mov DPTR, #arrow
    mov R7, #02h
    lcall disp_msg_ht
    lcall cursor_left
    lcall cursor_left
    setb uplock
    clr downlock
    ajmp main_loop
 next_key1:
    cjne a,#42h,begin
    jb downlock,begin
    clr inst_flag
    setb start_flag
    lcall delete_arrow
    lcall cursor_left
    lcall cursor_left
    lcall cursor_down
    mov DPTR, #arrow
    mov R7, #02h
    lcall disp_msg_ht
    lcall cursor_left
    lcall cursor_left
    setb downlock
    clr uplock
begin:
    ajmp main_loop
inst: 
    lcall clear_page
    acall inst_pos
    mov DPTR, #inst1
    mov R7, #0fh
    lcall disp_msg_ht
    lcall carriage_ret
    mov DPTR, #inst2
    mov R7, #0fh
    lcall disp_msg_ht
    lcall carriage_ret
    mov DPTR, #inst3
    mov R7, #0fh
    lcall disp_msg_ht
    lcall carriage_ret
    mov DPTR, #inst4
    mov R7, #0fh
    lcall disp_msg_ht
    lcall carriage_ret
    mov DPTR, #inst5
    mov R7, #0fh
    lcall disp_msg_ht
    lcall carriage_ret
	
	mov DPTR, #inst6
    mov R7, #0fh
    lcall disp_msg_ht
    lcall carriage_ret
	
    lcall cursor_down_7
    mov DPTR, #info
    mov R7, #45h
    lcall disp_msg_ht
    lcall carriage_ret
    lcall cursor_down
    mov DPTR, #item_3
    mov R7, #10h
    lcall disp_msg_ht
    setb second_page
    setb uplock
    setb downlock
    ajmp main_loop
;========================================================================
; routine to display any key
;========================================================================
press_any:
    mov A,#1Bh
    lcall transmit
    mov A,#5Bh
    lcall transmit
    mov A,#31h
    lcall transmit
	mov A,#32h
    lcall transmit
    mov A,#3Bh
    lcall transmit
    mov A,#33h
    lcall transmit
    mov A,#30h
    lcall transmit
	mov A,#66h
    lcall transmit
    mov DPTR, #anykey
    mov R7, #13
    lcall disp_msg_ht
	ret
;========================================================================
; routine to display game score 
;========================================================================
display_game_score:

    mov A,#1Bh
    lcall transmit
    mov A,#5Bh
    lcall transmit
    mov A,#31h
    lcall transmit
	mov A,#36h
    lcall transmit
    mov A,#3Bh
    lcall transmit
    mov A,#33h
    lcall transmit
    mov A,#30h
    lcall transmit
	mov A,#66h
    lcall transmit
    mov DPTR, #g_score
    mov R7, #14
    lcall disp_msg_ht
	mov a,score
	mov b,#10
	div AB
	add a,#30h
	lcall transmit
	mov a,b
	add a,#30h
	lcall transmit
	ret  
;========================================================================
; routine to display game over 
;========================================================================
display_game_over:	
	mov A,#1Bh
    lcall transmit
    mov A,#5Bh
    lcall transmit
    mov A,#31h
    lcall transmit
	mov A,#30h
    lcall transmit
    mov A,#3Bh
    lcall transmit
    mov A,#33h
    lcall transmit
    mov A,#30h
    lcall transmit
    mov A,#66h
    lcall transmit
   	mov DPTR, #g_over
    mov R7, #09h
    lcall disp_msg_ht
   ret	
;========================================================================
; routine to display won 
;========================================================================
won:	
	mov A,#1Bh
    lcall transmit
    mov A,#5Bh
    lcall transmit
    mov A,#31h
    lcall transmit
	mov A,#30h
    lcall transmit
    mov A,#3Bh
    lcall transmit
    mov A,#33h
    lcall transmit
    mov A,#30h
    lcall transmit
    mov A,#66h
    lcall transmit
   	mov DPTR, #win
    mov R7, #0Bh
    lcall disp_msg_ht
   ret	  
;========================================================================
; routine to keep the cursor for the instruction page 
;========================================================================
inst_pos:
    mov A,#1Bh
    lcall transmit
    mov A,#5Bh
    lcall transmit
    mov A,#31h
    lcall transmit
    mov A,#3Bh
    lcall transmit
    mov A,#31h
    lcall transmit
    mov A,#66h
    lcall transmit
    ret
;=========================================================================
; routine to perform the game
;========================================================================
game:
    lcall clear_page				;clear the page
	mov a,#0						;initialize the scores
	mov score,a
	lcall mountains					;call the routine to display the mountains
	mov mount_colm,#40				;set its values
	lcall foreground_red			;routine to make the forground colour red 
	acall pause_display				;routine to display pause
	acall score_display				;routine to display the score
	lcall life_display				;routine to display the life
	lcall reset_attributes			;routine to reset the attributes
	lcall bright_display			;routine to display it bright
	lcall foreground_blue			;routine to make the forground colour blue
	
    setb main_page					;set the main page flag
    setb play_flag					;set the play flag 
    lcall alien_display				;display the aliens
    mov alien_row,#10				;initialize the aliens row
    mov alien_colm,#25				;initialize the aliens colm
    lcall Init_Timer0				;initialize the timer routine
    lcall ship_display				;display the ship
    mov ship_row,#5					;initialize the ship row
    mov ship_colm,#73               ;initialize the ship colm
	setb game_over_flag				;set the game over flag
	clr ship_dead_flag				;clear the ship dead flag
	setb TR0						;set the timer
    ajmp main_loop					;jump to main loop

;========================================================================
; routine to display the pause
;========================================================================
pause_display:
	acall pause_cursor
	mov DPTR, #pause1
    mov R7, #09h
    lcall disp_msg_ht
    ret
;=========================================================================
; routine to initialize the cursor during pause
;========================================================================	
pause_cursor:
	mov A,#1Bh
    lcall transmit
    mov A,#5Bh
    lcall transmit
    mov A,#31h
    lcall transmit
    mov A,#3Bh
    lcall transmit
    mov A,#32h
    lcall transmit
    mov A,#30h
    lcall transmit
    mov A,#66h
    lcall transmit
    ret
;========================================================================
; routine to display the score
;========================================================================
score_display:
	acall score_cursor
	mov DPTR, #score1
    mov R7, #07h
    lcall disp_msg_ht
    ret
;=========================================================================	
; routine to initialize the cursor during score
;========================================================================	
score_cursor:
	mov A,#1Bh
    lcall transmit
    mov A,#5Bh
    lcall transmit
    mov A,#31h
    lcall transmit
    mov A,#3Bh
    lcall transmit
    mov A,#33h
    lcall transmit
    mov A,#30h
    lcall transmit
    mov A,#66h
    lcall transmit
    ret
;========================================================================	
; ; routine to display the life of the ship
;========================================================================
new_life:
	mov A,#1Bh
    lcall transmit
    mov A,#5Bh
    lcall transmit
    mov A,#31h
    lcall transmit
    mov A,#3Bh
    lcall transmit
    mov A,#34h
    lcall transmit
    mov A,#39h
    lcall transmit
    mov A,#66h
    lcall transmit
   	mov a,ship_life
	add a,#30h
	lcall transmit
	ret
;========================================================================
; routine to display the life 
;========================================================================
life_display:
	lcall life_cursor
	mov DPTR, #life1
    mov R7, #05h
    lcall disp_msg_ht
	mov ship_life,#3
	mov a,ship_life
	add a,#30h
	lcall transmit
    ret
;=========================================================================	
; routine to initialize the cursor during life 
;========================================================================	
life_cursor:
	mov A,#1Bh
    lcall transmit
    mov A,#5Bh
    lcall transmit
    mov A,#31h
    lcall transmit
    mov A,#3Bh
    lcall transmit
    mov A,#34h
    lcall transmit
    mov A,#34h
    lcall transmit
    mov A,#66h
    lcall transmit
    ret
;========================================================================
; routine to perform the mountain display
;========================================================================	
mountains:
    lcall force_mountain
    lcall mount_disp
    lcall mount_disp
    ret
;=======================================================================
; routine to perform the mountain display with some graphics
;========================================================================	
mount_disp:  
	lcall foreground_red
	lcall display_blink
    
	lcall display_mount
    lcall cursor_right
    lcall cursor_up
	lcall reset_attributes
	lcall foreground_red
    lcall display_mount
    lcall cursor_right
    lcall cursor_up
	
	lcall foreground_red
	lcall display_blink
	
    lcall display_mount
    lcall cursor_right
    lcall cursor_up
	lcall reset_attributes
	lcall foreground_red
    lcall display_mount
    lcall cursor_right
    lcall cursor_down
	
	lcall foreground_red
	lcall display_blink
	lcall display_mount
    lcall cursor_right
    lcall cursor_down
	
	lcall reset_attributes
	lcall foreground_red
    lcall display_mount
    lcall cursor_right
    lcall cursor_down
	
	lcall foreground_red
	lcall display_blink
    lcall display_mount
    lcall cursor_right
    lcall cursor_right
    lcall cursor_right
	lcall reset_attributes
    ret
;========================================================================
force_mountain:
    mov A,#1Bh
    lcall transmit
    mov A,#5Bh
    lcall transmit
    mov A,#32h
    lcall transmit
    mov A,#34h
    lcall transmit
    mov A,#3Bh
    lcall transmit
    mov A,#34h
    lcall transmit
    mov A,#30h
    lcall transmit
    mov A,#66h
    lcall transmit
    ret
;========================================================================
move_mount:
  	mov a,mount_colm
	cjne a,#10,move_now
	acall mountains
	mov mount_colm,#40
	ret
move_now:
	acall delete_mount
	mov a,mount_colm
	dec a
	mov mount_colm,a
	acall disp_mount_again
 	ret
;=====================================================================	
delete_mount:
	mov A,#1Bh
    acall transmit
    mov A,#5Bh
    acall transmit
    mov A,#32h
    acall transmit
    mov A,#31h
    acall transmit
    mov A,#3Bh
    acall transmit
    mov A,#31h
    acall transmit
    mov A,#66h
    acall transmit
    acall delete_line
	mov a,#0ah
	acall transmit
	acall delete_line
	mov a,#0ah
	acall transmit
	acall delete_line
	mov a,#0ah
	acall transmit
	acall delete_line
	ret
;====================================================================
disp_mount_again:
	mov A,#1Bh
    acall transmit
    mov A,#5Bh
    acall transmit
    mov A,#32h
    acall transmit
    mov A,#34h
    acall transmit
    mov A,#3Bh
    acall transmit
    mov A,mount_colm
	mov B,#10
	div AB
	add a,#30h
    acall transmit
    mov A,B
	add a,#30h
    acall transmit
    mov A,#66h
    acall transmit
	acall mount_disp
	acall cursor_right_6
	acall mount_disp
    ret
    
;=======================================================================
delete_line:
	 mov A,#1Bh
    acall transmit
    mov A,#5Bh
    acall transmit
    mov A,#32h
    acall transmit
    mov A,#4Bh
    acall transmit
	ret	
;=======================================================================
alien_move_display:
    lcall alien_pos_split
    acall alien_cursor
    lcall display_alien
    ret
;===========================================================================
alien_cursor:
    mov A,#1Bh
    lcall transmit
    mov A,#5Bh
    lcall transmit
    mov a,alien_row_1
    add a,#30h
    lcall transmit
    mov a,alien_row_2
    add a,#30h  
    lcall transmit
    mov A,#3Bh
    lcall transmit
    mov a,alien_col_1
    add a,#30h
	lcall transmit
    mov a,alien_col_2
    add a,#30h
	lcall transmit
    mov A,#66h
    lcall transmit
    ret
;=========================================================================    
alien_pos_split:
    mov B,#10
    mov A,alien_row
    div AB
    mov alien_row_1,A
    mov alien_row_2,B
    mov B,#10
    mov A,alien_colm
    div AB
    mov alien_col_1,A
    mov alien_col_2,B
    ret
;========================================================================
alien_display_new:
	mov A,#1Bh
    lcall transmit
    mov A,#5Bh
    lcall transmit
    mov A,#32h
    lcall transmit
    mov A,#3Bh
    lcall transmit
    mov A,#32h
    lcall transmit
    mov A,#66h
    lcall transmit
    acall display_alien
    ret
;========================================================================
alien_display:
    mov A,#1Bh
    lcall transmit
    mov A,#5Bh
    lcall transmit
    mov A,#31h
    lcall transmit
    mov A,#30h
    lcall transmit
    mov A,#3Bh
    lcall transmit
    mov A,#32h
    lcall transmit
    mov A,#35h
    lcall transmit
    mov A,#66h
    lcall transmit
    acall display_alien
    ret
;======================================================================
display_alien:
    mov DPTR, #alien
    mov R7, #06h
    lcall disp_msg_ht
    ret
;===============================================================================
delete_alien:
    lcall alien_pos_split
  	lcall alien_cursor
    lcall del_alien
    lcall cursor_left_6
    ret
;===============================================================================
ship_display:
    mov A,#1Bh
    lcall transmit
    mov A,#5Bh
    lcall transmit
    mov A,#35h
    lcall transmit
    mov A,#3Bh
    lcall transmit
    mov A,#37h
    lcall transmit
    mov A,#33h
    lcall transmit
    mov A,#66h
    lcall transmit
    mov DPTR, #ship
    mov R7, #06h
    lcall disp_msg_ht
    lcall cursor_left_6
    ret
;==================================================================================  
ship_shoot:
    mov R1,ship_colm
    lcall cursor_left
    dec R1
    acall disp_bullet_left
    ret  
;=============================================================================
disp_bullet_left:
	jb bullet_sent,alien_dead
normal:
	cjne R1,#1,fire
del:
    acall delete_bullet
	ret
fire:
    lcall cursor_left
    lcall display_bullet
    lcall cursor_left
    acall delete_bullet
    lcall cursor_left
    djnz R1,normal
    ajmp del
delete_bullet:
    mov A,#20h
    lcall transmit
    ret
alien_dead:
	mov A,alien_colm
	mov R1,A
	mov A,ship_colm
	subb A,R1
    jc no_credit
	mov R1,A
shoot:	
	lcall cursor_left
	lcall display_bullet
	lcall cursor_left
	lcall delete_bullet
    lcall cursor_left
	djnz R1,shoot
	jnb bullet_sent,no_inc_score
	mov a,score
	inc a
	cjne a,#10,inc_score
	ljmp game_won
inc_score:	
	mov score,a
	acall cal_score
no_inc_score:
	ljmp del
no_credit:
    clr bullet_sent
	mov A,ship_colm
	mov R1,A
	ljmp shoot
;==================================================================================      
save_cursor:
    mov A,#1Bh
    lcall transmit
    mov A,#37h
    lcall transmit
    ret
;================================================================================== 
restore_cursor:
    mov A,#1Bh
    lcall transmit
    mov A,#38h
    lcall transmit
    ret
;==================================================================================  
display_bullet:
    mov DPTR, #bullet
    mov R7,# 01h
    lcall disp_msg_ht
    ret
;==================================================================================  
cal_score:
	mov A,#1Bh
    lcall transmit
    mov A,#5Bh
    lcall transmit
    mov A,#31h
    lcall transmit
    mov A,#3Bh
    lcall transmit
    mov A,#33h
    lcall transmit
    mov A,#38h
    lcall transmit
    mov A,#66h
    lcall transmit
    mov a,score
	mov b,#10
	div AB
	add a,#30h
	lcall transmit
	mov a,b
	add a,#30h
	lcall transmit
	ret
;==================================================================================
; routine to display the mount character '#'
;========================================================================	
display_mount:
    mov DPTR, #mount
    mov R7,# 01h
    lcall disp_msg_ht
    ret
;==================================================================================  
; routine to display the arrow
;==================================================================================  
delete_arrow:
    mov A, #20h
    lcall transmit
    mov A, #20h
    lcall transmit
    ret    
;==================================================================================
; routine to delete the ship
;==================================================================================  
delete_ship:
    lcall delete_arrow
    lcall delete_arrow
    lcall delete_arrow
    ret    
;=======================================================================    
; routine to delete the alien
;==================================================================================  
del_alien:
	lcall delete_arrow
    lcall delete_arrow
    lcall delete_arrow
    ret    
;=======================================================================   
; routine to move the cursor up
;==================================================================================   
cursor_up:
    mov A, #1Bh
    lcall transmit
    mov A, #5Bh
    lcall transmit
    mov A, #41h
    lcall transmit
    ret
;==================================================================
; routine to move the cursor right
;==================================================================================   
cursor_right:
    mov A, #1Bh
    lcall transmit
    mov A, #5Bh
    lcall transmit
    mov A, #43h
    lcall transmit
    ret
;==================================================================
; routine to move the cursor right 6 times
;==================================================================================   
cursor_right_6:
    mov A, #1Bh
    lcall transmit
    mov A, #5Bh
    lcall transmit
    mov A, #36h
    lcall transmit
    mov A, #43h
    lcall transmit
    ret
;===============================================================================
; routine to move the cursor left
;==================================================================================   
cursor_left:
    mov A, #1Bh
    acall transmit
    mov A, #5Bh
    acall transmit
    mov A, #44h
    acall transmit
    ret
;===============================================================================
; routine to move the cursor left 6 times
;==================================================================================   
cursor_left_6:
    mov A, #1Bh
    acall transmit
    mov A, #5Bh
    acall transmit
    mov A, #36h
    acall transmit
    mov A, #44h
    acall transmit
    ret
;===============================================================================
; routine to move the cursor down
;==================================================================================   
cursor_down:
    mov A, #1Bh
    acall transmit
    mov A, #5Bh
    acall transmit
    mov A, #42h
    acall transmit
    ret 
;=============================================================================== 
; routine to move the cursor down 7 times
;==================================================================================   
cursor_down_7:
    mov A, #1Bh
    acall transmit
    mov A, #5Bh
    acall transmit
    mov A, #37h
    acall transmit
    mov A, #42h
    acall transmit
    ret  
;===============================================================================
; routine to move the ship up
;==================================================================================   
ship_up:
    lcall delete_ship
    acall cursor_left_6
    lcall cursor_up
    mov DPTR, #ship
    mov R7, #06h
    lcall disp_msg_ht
    acall cursor_left_6
    ret
;===============================================================================    
; routine to move the ship right
;==================================================================================   
ship_right:
    lcall delete_ship
    acall cursor_left_6
    lcall cursor_right
    mov DPTR, #ship
    mov R7, #06h
    lcall disp_msg_ht
    lcall cursor_left_6
    ret    
;===============================================================================
; routine to move the ship left
;==================================================================================   
ship_left:
    lcall delete_ship
    lcall cursor_left_6
    lcall cursor_left
    mov DPTR, #ship
    mov R7, #06h
    lcall disp_msg_ht
    lcall cursor_left_6
    ret
;===============================================================================
; routine to move the ship down
;==================================================================================   
ship_down:
    lcall delete_ship
    lcall cursor_left_6
    lcall cursor_down
    mov DPTR, #ship
    mov R7, #06h
    lcall disp_msg_ht
    lcall cursor_left_6
    ret

;===============================================================================
; routine to transmit the data
;==================================================================================   
transmit:                                    ; transmit data that is passed through the accumulator
      clr  TI  
      mov  SBUF,a     
      jnb  TI,$                 ; loop here until data is sent(TI will be set)
      clr  TI   
      ret	
;===============================================================================
; routine to display the main menu
;==================================================================================   
display_menu:
	acall background_display
	acall bright_display
    mov A,#1Bh
    acall transmit
    mov A,#5Bh
    acall transmit
    mov A,#31h
    acall transmit
    mov A,#3Bh
    acall transmit
    mov A,#31h
    acall transmit
    mov A,#48h
    acall transmit
	
	acall foreground_blue
    mov DPTR, #dec_1
    mov R7, #45h
    acall disp_msg_ht
    acall carriage_ret
	
	acall display_blink

    mov DPTR, #welc
    mov R7, #45h
    acall disp_msg_ht
    acall carriage_ret
   
   acall reset_attributes
   acall foreground_blue
   acall bright_display
    mov DPTR, #dec_2
    mov R7, #45h
    acall disp_msg_ht
    lcall carriage_ret
   
    mov DPTR, #menu
    mov R7, #0eh
    acall disp_msg_ht
    acall carriage_ret
  
 
    mov DPTR, #item_1
    mov R7, #1ah
    acall disp_msg_ht
    acall carriage_ret
	lcall save_cursor
	acall dis_won
	lcall restore_cursor
	acall bright_display
	acall foreground_blue
     mov DPTR, #item_2
    mov R7, #1ah
    acall disp_msg_ht
     
    mov DPTR, #arrow
    mov R7, #02h
    acall disp_msg_ht
    lcall cursor_left
    lcall cursor_left
ret  
;========================================================
; routine to dispaly score ten to win
;==================================================================================   
dis_won:
	acall display_blink 
    mov A,#1Bh
    lcall transmit
    mov A,#5Bh
    lcall transmit
    mov A,#31h
    lcall transmit
    mov A,#30h
    lcall transmit
    mov A,#3Bh
    lcall transmit
    mov A,#31h
    lcall transmit
    mov A,#30h
    lcall transmit
    mov A,#66h
    lcall transmit
	mov DPTR, #inst7
    mov R7, #45h
    acall disp_msg_ht
	acall reset_attributes
    ret
;======================================================
; routine to display the game is won
;======================================================   
display_game_won: 
	lcall won
	lcall press_any
	ret
;======================================================
; routine to make the screnn blink
;======================================================   
display_blink:
	mov a,#1Bh
	acall transmit
	mov a,#5Bh
	acall transmit
	mov a,#35h
	acall transmit
	mov a,#6Dh
	acall transmit
	ret
;======================================================
; routine to reset the attributes set in the screen
;======================================================   
reset_attributes:
	mov a,#1Bh
	acall transmit
	mov a,#5Bh
	acall transmit
	mov a,#30h
	acall transmit
	mov a,#6Dh
	acall transmit
	ret		
;======================================================
; routine to display the back ground
;======================================================   
background_display:
	mov a,#1Bh
	acall transmit
	mov a,#5Bh
	acall transmit
	mov a,#34h
	acall transmit
	mov a,#30h
	acall transmit
	mov a,#6Dh
	acall transmit
	ret		
;========================================================
; routine to display it in bright
;======================================================   
bright_display:
	mov a,#1Bh
	acall transmit
	mov a,#5Bh
	acall transmit
	mov a,#31h
	acall transmit
	mov a,#6Dh
	acall transmit
	ret
;======================================================
; routine to display the foreground blue
;======================================================   
foreground_blue:
	mov a,#1Bh
	acall transmit
	mov a,#5Bh
	acall transmit
	mov a,#33h
	acall transmit
	mov a,#34h
	acall transmit
	mov a,#6Dh
	acall transmit
	ret				
;======================================================
; routine to display the foreground red
;======================================================   
foreground_red:
	mov a,#1Bh
	acall transmit
	mov a,#5Bh
	acall transmit
	mov a,#33h
	acall transmit
	mov a,#31h
	acall transmit
	mov a,#6Dh
	acall transmit
	ret						
;======================================================
; routine to dislay the message asked to send
;======================================================   
disp_msg_ht:
    clr A
    movc A, @A+DPTR
    inc DPTR
    lcall transmit
    djnz R7, disp_msg_ht
    ret    
;===========================================================================
; routine to do carriage return as well move the cursor to the next line
;======================================================   
carriage_ret:
    mov A, #0dh
    lcall transmit
    mov A, #0ah
    lcall transmit
    ret
;============================================================================
; routine to clear the page
;======================================================   
clear_page:
    mov     A,#1Bh
    lcall   transmit
    mov     A,#5Bh
    lcall   transmit
    mov     A,#32h
    lcall   transmit
    mov     A,#4Ah
    lcall   transmit
    ret
;=================================================================================
; routine to initialize the interrupt EX0
;======================================================   
Init_int0:
    clr EA
    setb EX0;
    setb IT0;
    clr IE0 
    setb EA
    ret	
;=======================================================
; routine to perform when suspend mode is achieved 
;======================================================   
init_suspend:
    push     P1
    push     acc
    push     PSW
    mov      SAVESP, SP
    clr      LED_GREEN
    clr      LED_RED
    mov      TAR,#AAh
    mov      TAR,#55h
    orl      PCON,#42h
    ret 	

;=============================================================================
; routine to initialize the serial Interrupt
;======================================================   
Init_Serial:                        ; routine to initialize Timer 0          
    clr     ES
    mov  SCON,#70h         ; Set serial port(mode 1 : 8-bit variable baudrate)
    clr data_txn
    mov     TMOD,#20h    ; Timer 1 mode 2 : 8-bit auto reload mode
    mov     TH1, #FDh    ; Reload value for 9600 baudrate
    orl   PCON,#80h 
    clr     ET1        ; Disable timer 1 interrupt - not needed
    setb TR1        ; Start timer 1
    setb ES
    setb EA
    ret
 ;=============================================================================
 ; routine to initialize the timer Interrupt
;======================================================   
Init_Timer0:                       ; routine to initialize Timer 0
    clr EA
    clr ET0               ; disable timer0 interrupt
    clr TR0               ; stop timer0
    clr ET1          ; Disable serial port interrupt
    clr TR1
    mov TH1, #fdh         ; Reload value for 9600 baudrate
    clr one_sec               ; counter
    mov timecnt,#32h      ; do whatever is necessary here to set up a 1-sec
    orl TMOD,#01h   
    mov TL0,#value1       ; load timer value
    mov TH0,#value2
    setb ET0               ; timer 0 interrupt enabled
    setb TR1          ; Start timer 1
    setb EA                ; enable CPU to be interrupted
    ret
;=======================================================================
; timer ISR
;======================================================   
Timer0_ISR:                             ; interrupt service routine of Timer 0
    clr     TR0                       ; stop timer0
    mov     TL0,#value1               ; load timer value again
    mov     TH0,#value2
    djnz    timecnt,not_one_sec       ; do whatever is necessary here to check
    setb    one_sec                   ; whether 1 sec has elapsed and may be set a 1-sec flag if so
    mov timecnt,#10h
not_one_sec:
    mov     R5,timecnt
    cjne    R5,#0Ah,return
    setb    alien_up_flag
    setb    TR0 
    reti     
return:  
    setb    TR0         
    reti                              ; return from interrupt
;==========================================================================
; EX0 ISR
;======================================================   
INT0_ISR:
    clr      IE0 
    setb suspend
    reti 
;=============================================================================
;       serial ISR
;=============================================================================
Serial_Isr:
    jb  RI, rx
    reti
rx:
    clr a
    mov a,SBUF
    setb data_txn
    clr RI
    reti

end ;End of Program code - Assembler will ignore anything after this
