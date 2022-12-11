; ---------------------------------------------------------------------------
; video.s - video interface routines
; 2019-03-20 E. Brombaugh
; Note - requires 65C02 support
; ---------------------------------------------------------------------------
;
; ---------------------------------------------------------------------------
; table of data for video driver

.segment  "VIDTAB"

vidtab:
.byte		$2c					; $FFE0 - default starting cursor location
.byte		$48					; $FFE1 - default width
.byte		$00					; $FFE0 - vram size: 0 for 1k, !0 for 2k


