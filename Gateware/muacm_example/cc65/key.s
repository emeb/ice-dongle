; ---------------------------------------------------------------------------
; key.s - ps2 interface routines
; 2022/12/10 E. Brombaugh
; Note - requires 65C02 support
; ---------------------------------------------------------------------------
;

.segment	"KEY_DAT"

; storage for key processing @ $0213-$0216
cl_state:	.byte		$00
key_temp:	.byte		$00
x_temp:		.byte		$00
