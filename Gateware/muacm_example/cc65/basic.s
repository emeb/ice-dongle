; ---------------------------------------------------------------------------
; basic.s - BASIC interface routines
; 2019-04-05 E. Brombaugh
; Portions (c) 1977 Microsoft
; ---------------------------------------------------------------------------
;

.import		_spi_tx_byte
.import		_spi_flash_read
.import		_hexout
.import		_strout
.import		_acia_tx_chr
.import		_acia_rx_nb
.import		_spi_flash_read
.import		_spi_flash_rdreg
.import		_spi_flash_status
.import		_spi_flash_busy_wait
.import		_spi_flash_eraseblk
.import		_spi_flash_writepg

.export		_basic_init
.export		_input
.export		_output
.export		BAS_COLDSTART
.export		BAS_WARMSTART

; routines in BASIC that are refrenced here
BAS_BASE		= $A000		; BASIC base offset
BAS_WARMSTART	= $A274		; Warm start BASIC
BAS_COLDSTART	= $BD11		; Cold start BASIC
BAS_NXT_INTARG	= $AAAD		; fetch next integer argument on BASIC line
BAS_GET_INTARG	= $AE05		; get integer argument into BAS_INTLO/BAS_INTHI
BAS_OUT_ERR		= $A24E		; output error from value in X
BAS_HNDL_CTRLC	= $A636		; handle Control-C
BAS_VIDTXT		= $BF2D		; send text to video screen
BAS_PATCHDST    = $A364		; location to patch backspace

; variables
BAS_INTLO		= $AF		; low byte of converted integer
BAS_INTHI		= $AE		; high byte of converted integer

.segment	"BAS_VEC"

; table of vectors used by BASIC
input_vec:	.word		$0000
output_vec:	.word		$0000
ctrl_c_vec:	.word		$0000
load_vec:	.word		$0000
save_vec:	.word		$0000

.segment	"CODE"

; ---------------------------------------------------------------------------
; load and init BASIC

.proc _basic_init: near
; Init jump tab
			ldx #$0A				; init X 
jmplp:		lda init_tab,X
			sta input_vec,X
			dex
			bpl jmplp

; load & lock RAM1
			; read 8kB from flash into RAM
			lda #$00				; count 7:0
			sta $fc
			lda #$20				; count 15:8
			sta $fd
			lda #.lobyte(BAS_BASE)	; dest addr
			sta $fe
			lda #.hibyte(BAS_BASE)
			sta $ff
			ldx #$0a				; source addr 23:16
			ldy #$00				; source addr 15:8
			lda #$00				; source addr 7:0
			jsr _spi_flash_read
			
			; patch backspace key
			ldx #$10
			ldy #$00
ptchlp:		lda PATCHSRC,y
			sta BAS_PATCHDST,y
			iny
			dex
			bne ptchlp
			
			; protect BASIC
			lda #$0C
			sta $F203
			
			; print msg
			lda #.lobyte(loadmsg)
			ldy #.hibyte(loadmsg)
			jsr _strout
			rts
.endproc

; ---------------------------------------------------------------------------
; combined serial & ps2 inputs

.proc _chrin: near
			jsr _acia_rx_nb			; check for serial input
			cpx #1
			rts
.endproc

; ---------------------------------------------------------------------------
; BASIC input vector 

.proc _input: near
			stx invec_x				; save X
in_lp:		jsr _chrin				; get character
			bne	in_lp				; if none keep waiting
			ldx invec_x				; restore X
			rts
.endproc

; ---------------------------------------------------------------------------
; BASIC output vector 

.proc _output: near
			jsr _acia_tx_chr
			rts
.endproc

; ---------------------------------------------------------------------------
; ctrl-c vector 

.proc _ctrl_c: near
			jsr _chrin				; get char - serial or PS/2
			bne ctrl_c_sk			; return if no new char
ctrl_c_nk:	cmp #$03				; check for ctrl-c
			bne ctrl_c_sk			; return if not ctrl-c
			jmp BAS_HNDL_CTRLC		; go to ctrl-c handler
ctrl_c_sk:	rts
.endproc

; ---------------------------------------------------------------------------
; Compute flash addr from slot # - used by both save and load

.proc _get_slot_addr: near
; get argument after SAVE 
			jsr BAS_NXT_INTARG	; fetch next arg on BASIC line
			jsr	BAS_GET_INTARG	; Convert arg to 16-bit signed integer
			
; enforce 0-99 range
			lda BAS_INTHI		; get high byte
			beq sv_hiok
sv_overr:	ldx #$0a			; throw overflow error if slot > 255
			jmp BAS_OUT_ERR
sv_hiok:	lda BAS_INTLO		; get low byte
			cmp #$64
			bpl sv_overr		; throw overflow error if slot > 99
			
; compute block address
			clc
			adc #$20			; offset to start of region $100000
			ror					; adjust for 32k
			sta $f9				; save high addr (Note - Big Endian!)
			lda	#$00
			ror
			sta $fa				; save mid addr
			rol
			sta $fb				; clear low addr
			rts
.endproc

;; ---------------------------------------------------------------------------
; LOAD vector - sets up to inject text from flash

.proc _load: near
; get slot address into zp locs f9-fb
			jsr _get_slot_addr
			
; read 256B from flash into RAM
			lda #$00				; count 7:0
			sta $fc
			lda #$01				; count 15:8
			sta $fd
			lda #.lobyte(flash_buf)	; dest addr
			sta $fe
			lda #.hibyte(flash_buf)
			sta $ff
			ldx $f9					; source addr 23:16
			ldy $fa					; source addr 15:8
			lda $fb					; source addr 7:0
			jsr _spi_flash_read

; set up input buffer
			ldy #$00
			sty $f8
			lda #.lobyte(flash_buf)	; src addr
			sta $fe
			lda #.hibyte(flash_buf)
			sta $ff

; redirect input vector during load
			lda #.lobyte(ld_chrin)
			sta input_vec
			lda #.hibyte(ld_chrin)
			sta input_vec+1

			rts
.endproc

; ---------------------------------------------------------------------------
; text input redirected during load

.proc ld_chrin: near
; save regs
			txa
			pha
			tya
			pha
			
; get next key data
			ldy $f8
			lda ($fe),y				; get byte
			iny						; advance ptr
			sty $f8
			bne ld_noread			; skip if not all 256 used
			sta $f7					; save char while reading next pg
			lda #.lobyte(flash_buf)	; dest addr
			sta $fe
			lda #.hibyte(flash_buf)
			sta $ff
			lda #$00				; reset pg cnt
			sta $fc					; count 7:0
			lda #$01				; count 15:8
			sta $fd
			ldx $f9					; load & inc src ptr into regs for read fn
			ldy $fa
			iny
			sty $fa
			lda $fb
			jsr _spi_flash_read		; load next 256
			lda #.lobyte(flash_buf)	; src addr
			sta $fe
			lda #.hibyte(flash_buf)
			sta $ff
			lda $f7					; restore char
ld_noread:	cmp #$FF				; end of text?
			bne ld_done				; no, skip to done
			
; finish up - restore input vector
			lda #.lobyte(_input)
			sta input_vec
			lda #.hibyte(_input)
			sta input_vec+1
			lda #$0d				; final CR
			
; restore regs and return w/ key data
ld_done:	sta $f7
			pla
			tay
			pla
			tax
			lda $f7
			rts
.endproc

; ---------------------------------------------------------------------------
; SAVE vector - sets up to capture text to flash

.proc _save: near
; get slot address
			jsr _get_slot_addr
			
; erase page
			jsr _spi_flash_eraseblk
			jsr _spi_flash_busy_wait
			
; init src addr & count
			lda #.lobyte(flash_buf)	;low source addr
			sta $fe
			lda #.hibyte(flash_buf)	; high source addr
			sta $ff
			lda #$00
			sta $fc					; byte counter
			sta $fd					; page counter
			
; redirect output to special routine
			lda #.lobyte(sv_chrout)
			sta output_vec
			lda #.hibyte(sv_chrout)
			sta output_vec+1
			
; list all
			jsr sv_list
			
; check if any data remaining in buffer
			lda $fc					; skip if byte counter = 0
			beq sv_rst
			jsr sv_flsh_wrt			; write last buffer
			lda #'*'				; send * to output for final
			jsr _output
			
; restore output vector
sv_rst:		lda #.lobyte(_output)
			sta output_vec
			lda #.hibyte(_output)
			sta output_vec+1

			rts
.endproc

; ---------------------------------------------------------------------------
; list BASIC program - ganked from ROM & MS source

.proc sv_list: near
sv_GOLST:   LDA #$0				; FORCE MIN LINE # = 0
			STA $11				; LINNUM
			STA $12				; LINNUM+1
			JSR $A432			; FNDLIN - GET LOW LINE # IN LOWTR
sv_LSTEND:	LDA #$FF			; FORCE MAX LINE # = 65535
			STA $11
			STA $12
sv_LIST4:	LDY #$01
			STY $60				; DORES - 
			LDA ($AA),Y			; LOWTR
			BEQ sv_GORDY
			JSR $A629			; CHECK FOR CTRL-C
			JSR $A86C			; PRINT CRLF
			INY
			LDA ($AA),Y
			TAX
			INY
			LDA ($AA),Y
			CMP $12
			BNE sv_TSTDUN
			CPX $11
			BEQ sv_TYPLIN
sv_TSTDUN:	BCS sv_GORDY
sv_TYPLIN:	STY $97
			JSR $B95E
			LDA #$20
sv_PRIT4:	LDY $97
			AND #$7F
sv_PLOOP:	JSR sv_chrout
			CMP #$22
			BNE sv_PLOOP1
			LDA $60
			EOR #$FF
			STA $60
sv_PLOOP1:	INY
			LDA ($AA),Y
			BNE sv_QPLOP
			TAY
			LDA ($AA),Y
			TAX
			INY
			LDA ($AA),Y
			STX $AA
			STA $AB
			BNE sv_LIST4
sv_GORDY:	RTS
sv_QPLOP:	BPL sv_PLOOP
			CMP #$FF
			BEQ sv_PLOOP
			BIT $60
			BMI sv_PLOOP
			SEC
			SBC #$7F
			TAX
			STY $97
			LDY #$FF
sv_RESRCH:	DEX
			BEQ sv_PRIT3
sv_RESCR1:	INY
			LDA $A084,Y			; RESLST - RESERVED WORD LIST
			BPL sv_RESCR1
			BMI sv_RESRCH
sv_PRIT3:	INY
			LDA $A084,Y
			BMI sv_PRIT4
			JSR sv_chrout
			BNE sv_PRIT3
.endproc

; ---------------------------------------------------------------------------
; write save buffer to flash
.proc sv_flsh_wrt: near
			lda $fd					; skip write if pg count > 127
			bmi sfw_end
			jsr _spi_flash_writepg	; send buffer to flash
			inc $fa					; adjust destination addr 
			inc $fd					; inc page counter
sfw_end:	rts
.endproc

; ---------------------------------------------------------------------------
; text output redirected to save buffer

.proc sv_chrout: near
			sta temp0		; save a, x, y
			stx temp1
			sty temp2
			ldy $fc			; get count
			sta ($fe),y		; save in src+cnt
			iny
			sty $fc			; update count
			bne sv_outdone	; skip if buffer not full
			jsr	sv_flsh_wrt	; else write full buffer
			lda #'-'		; send '-' to output for progress
			jsr _output
sv_outdone:	ldy temp2		; restore a, x, y
			ldx temp1
			lda temp0
			rts
.endproc

loadmsg:
.byte		10,13,"BASIC loaded, patched and locked", 0

; patch to use backspace instead of underline
; --------- original ---------- ; --- new -------
;A364   C9 20      CMP #$20		; cmp #$08	c9 08
;A366   90 F1      BCC $A359	; beq $a34b	f0 e3
;A368   C9 7D      CMP #$7D		; cmp #$20	c9 20
;A36A   B0 ED      BCS $A359	; bcc $a359	90 ed
;A36C   C9 40      CMP #$40		; cmp #$7d	c9 7d
;A36E   F0 E1      BEQ $A351	; bcs $a359	b0 e9
;A370   C9 5F      CMP #$5F		; cmp #$40	c9 40
;A372   F0 D7      BEQ $A34B	; beq $a351	f0 dd
PATCHSRC:
.byte		$c9, $08, $f0, $e3, $c9, $20, $90, $ed
.byte		$c9, $7d, $b0, $e9, $c9, $40, $f0, $dd

; ---------------------------------------------------------------------------
; BASIC vector init table

init_tab:
.addr		_input					; input
.addr		_output					; output
.addr		_ctrl_c					; ctrl-c
.addr		_load					; load
.addr		_save					; save

.segment	"HI_RAM"
flash_buf:	.res $100				; 256 bytes flash data buffer
temp0:		.res 1					; temp vars
temp1:		.res 1					; temp vars
temp2:		.res 1					; temp vars
invec_x:	.res 1					; X reg save for input vec

; ---------------------------------------------------------------------------
; table of vectors for BASIC

.segment  "JMPTAB"

			JMP (input_vec)			;
			JMP (output_vec)		;
			JMP (ctrl_c_vec)		;
			JMP (load_vec)			;
			JMP (save_vec)			;
