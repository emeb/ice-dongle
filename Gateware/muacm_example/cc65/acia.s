; ---------------------------------------------------------------------------
; acia.s
; icestick_6502 ACIA interface routines
; 03-04-19 E. Brombaugh
; ---------------------------------------------------------------------------
;
; Write a string to the ACIA TX

.define   ACIA_CTRL $F000    ;  ACIA control register location
.define   ACIA_DATA $F001    ;  ACIA data register location

.export         _acia_init
.export         _acia_tx_str
.export         _acia_tx_chr
.export         _acia_rx_chr
.export         _acia_isr
.exportzp       _acia_data: near

.zeropage

_acia_data:     .res 2, $00        ;  Reserve a local zero page pointer

.segment  "CODE"

; ---------------------------------------------------------------------------
; initialize the ACIA

.proc _acia_init: near
		lda 	#$03			; reset ACIA
		sta		ACIA_CTRL
		lda		#$00			; normal running
		sta		ACIA_CTRL
        rts						;  Return
.endproc
        
; ---------------------------------------------------------------------------
; send a string to the ACIA

.proc _acia_tx_str: near

; ---------------------------------------------------------------------------
; Store pointer to zero page memory and load first character

        sta     _acia_data       ;  Set zero page pointer to string address
        stx     _acia_data+1     ;    (pointer passed in via the A/X registers)
        ldy     #00              ;  Initialize Y to 0
        lda     (_acia_data),y   ;  Load first character

; ---------------------------------------------------------------------------
; Main loop:  read data and store to FIFO until \0 is encountered

loop:   jsr     _acia_tx_chr     ;  Loop:  send char to ACIA
        iny                      ;         Increment Y index
        lda     (_acia_data),y   ;         Get next character
        bne     loop             ;         If character == 0, exit loop
        rts                      ;  Return
.endproc
        
; ---------------------------------------------------------------------------
; wait for TX empty and send single character to ACIA

.proc _acia_tx_chr: near

        pha                      ; temp save char to send
txw:    lda      ACIA_CTRL       ; wait for TX empty
        and      #$02
        beq      txw
        pla                      ; restore char
        sta      ACIA_DATA       ; send
        rts

.endproc

; ---------------------------------------------------------------------------
; wait for RX full and get single character from ACIA

.proc _acia_rx_chr: near

rxw:    lda      ACIA_CTRL       ; wait for RX full
        and      #$01
        beq      rxw
        lda      ACIA_DATA       ; receive
        rts

.endproc

; ---------------------------------------------------------------------------
; check ACIA for IRQ and echo
.proc _acia_isr: near
		LDA 	ACIA_CTRL
		AND 	#$80               ; IRQ bit set?
		BEQ 	iexit                ; no - skip

; Echo RX char
		JSR 	_acia_rx_chr       ; get RX char
		JSR 	_acia_tx_chr       ; send TX char
iexit:	rts

.endproc
