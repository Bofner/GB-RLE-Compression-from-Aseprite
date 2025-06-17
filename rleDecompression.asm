; ==============================================================
;  Handles decompressing and writing tiles and maps
; ==============================================================
; 
; Parameters: DE = Source, HL = (TILE_VRAM_8000, TILE_VRAM_8800, TILE_VRAM_9000)
; 							   (MAP_VRAM_9800,                  MAP_VRAM_9C00 )
; Returns: None
; Affects: TBD
; Header byte follows this format:
; 7:     1 = TILE, 0 = MAP
; 6:     1 = Uncompressed
; 5 & 4: 00 = SCRN, 01 = TALL
;        10 = WIDE, 11 = FULL
; 0-3: Unused but set to 1
TileAndMapHandler:
; Use our header byte to jump to the appropriate subroutine
	ld a, (de)
	bit 6, a
	jp nz, @WriteRawData
; Our data is compressed, and TILEs, FULL and WIDE will all be written in the same way
	bit 7, a
	jp nz, @WriteFullOrWideOrTiles
; If BIT 5 is 0, then we are writing either a TALL or SCRN map
	bit 5, a
	jp z, @WriteTallOrScreen
; Otherwise we are writing TILEs, or a FULL/WIDE background map, which are written in the same way
	@WriteFullOrWideOrTiles:
		; push af
	--:
		; pop af
		inc de
	; Start by loading in our data byte
		ld a, (de)
	; And save it in C for now
		ld c, a
	; Then load our RUN LENGTH byte
		inc de
		ld a, (de)
	; Check for our terminator byte
		cp $00						
		ret z
	; If not at the end, then save it in B and bring our data byte back into A
		ld b, a
		ld a, c
	-:
		ld (hli), a
	; Continue writing either the same run or check for a new run
		dec b
		jp nz, -
		jr --
		; End
	ret

; We are either writing TALL or SCRN, which are written in the same way
	@WriteTallOrScreen:
		push af							; We need to use A for a lot, like data AND condition checks
	--:
		pop af
		inc de
	; Start by loading in our data byte
		ld a, (de)
	; And save it in C for now
		ld c, a
	; Then load our RUN LENGTH byte
		inc de
		ld a, (de)
	; Check for our terminator byte
		cp $00						
		ret z
	; If not at the end, then save it in B and bring our data byte back into A
		ld b, a
		ld a, c
		push af
	-:
		pop af
		ld (hli), a
	; Check if we are at the edge of the GB's display
		push af
		ld a, l
		and LCD_WIDTH
		cp LCD_WIDTH
		call z, @@DrawNextLine
	; Continue writing either the same run or check for a new run
		dec b
		jp nz, -
		jr --
		pop af							; Just for keeping Push and Pop color in check
		; End
		@@DrawNextLine:
		; Save registers
			push de
				ld a, l
				ld e, a
				ld a, h
				ld d, a
			; Update drawing position
				ld hl,  LCD_NEXT_LINE
				add hl, de
			; Return Register
			pop de
			ret
		; End
	ret

; Our data is NOT compressed
	@WriteRawData:
	; First we need to find out how big our data is, so load the SIZE word (Little Endian)
		push af							; Save our header
			inc de
			ld a, (de)
			ld c, a
			inc de
			ld a, (de)
			ld b, a
		pop af							; Restore our header
	; BC now contains our file size
	; Our data is raw, but TILEs, FULL and WIDE will all be written in the same way
		bit 7, a
		jp nz, @@WriteFullOrWideOrTiles
	; If BIT 5 is 0, then we are writing either a TALL or SCRN map
		bit 5, a
		jp z, @@WriteTallOrScreen
	; If not, then we MUST be writing TILEs, WIDE or FULL, which all write in the same way
	; We are either writing TILEs, or a FULL/WIDE background map
		@@WriteFullOrWideOrTiles:
		-:
		; Our loop for writing data to VRAM
			inc de
			ld a, (de)
			ld (hli), a
			dec bc
			ld a, b
			or c
			jr nz, -
			; End
		; End
	ret

	; We are either writing a TALL or SCRN background map, which are written in the same way
		@@WriteTallOrScreen:
			inc de
			ld a, (de)
			ld (hli), a
		; Check if we are at the edge of the GB's display
			ld a, l
			and LCD_WIDTH
			cp LCD_WIDTH
			call z, @@@DrawNextLine
		; Proceed to next tile (if there is one)
			dec bc
			ld a, b
			or a, c
			jp nz, @@WriteTallOrScreen

			ret
			@@@DrawNextLine:
			; Save registers
				push de
					ld a, l
					ld e, a
					ld a, h
					ld d, a
				; Update drawing position
					ld hl,  LCD_NEXT_LINE
					add hl, de
				; Return Register
				pop de
				ret
			; End
		; End
	ret