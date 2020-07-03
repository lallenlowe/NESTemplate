.segment "HEADER" ; iNES Header
    .byte "NES"
    .byte $1a ; iNES header indicator
    .byte $02 ; PRG Rom data, 16384 * x bytes
    .byte $01 ; CHR Rom data, 8192 * y bytes
    .byte %00000000 ; Mapper, mirroring, battery, trainer
    .byte $00
    .byte $00
    .byte $00 ; NTSC
    .byte $00
    .byte $00, $00, $00, $00, $00 ; filler bytes
.segment "ZEROPAGE" ; $00 - $FF
.segment "STARTUP"

.segment "CODE"

WAITVBLANK:
:
    BIT $2002 ; Query PPU for vblank status
    BPL :-
    RTS

Reset:
    SEI ; Disables all interrupts
    CLD ; Disable decimal mode

    ; Disable sound IRQ
    LDX #$40
    STX $4017

    ; Initialize the stack register
    LDX #$FF
    TXS

    INX ; Increment X from 255 to 0

    ; Zero out PPU registers
    STX $2000
    STX $2001

    STX $4010 ; Disable PCM channel

    JSR WAITVBLANK

    TXA ; A is now also 0

; Initialize all memory addresses
CLEARMEM:
    STA $0000, X ; Zero out $0000 - $00FF
    STA $0100, X ; Zero out $0100 - $01FF
    STA $0300, X ; Zero out $0300 - $03FF
    STA $0400, X
    STA $0500, X
    STA $0600, X
    STA $0700, X
    LDA #$FF
    STA $0200, X ; Fill $0200 - $02FF with $FF for sprite data
    LDA #$00 ; Set A back to 0 for next loop
    INX
    BNE CLEARMEM

    JSR WAITVBLANK

    ; Copy sprite data from $0200 into PPU memory
    LDA #$02
    STA $4014 ; OAM DMA register
    NOP ; Burn a cycle for PPU to be done with memory transfer

    ; $3F00, get PPU ready to load palette data
    LDA #$3F ; Most significant byte
    STA $2006 ; write to PPUADDR register
    LDA #$00 ; Least significant byte
    STA $2006 ; write to PPUADDR register

    LDX #$00

LoadPalettes:
    LDA PaletteData, X
    STA $2007 ; Store each palette byte into PPU memory $3F00 - $3F1F
    INX
    CPX #$20 ; 32 memory addresses to load
    BNE LoadPalettes

    LDX #$00

LoadSprites:
    LDA SpriteData, X
    STA $0200, X
    INX
    CPX #$20 ; 32 memory addresses to load
    BNE LoadSprites

    ; Enable interrupts
    CLI

    LDA #%10010000 ; enable NMI, and set background table address to $1000
    STA $2000
    ; Enable sprite and background drawing
    LDA #%00011110
    STA $2001

Loop:
    JMP Loop

NMI:
    ; Copy sprite data from $0200 into PPU memory for display
    LDA #$02
    STA $4014 ; OAM DMA register

LatchController:
    LDA #$01
    STA $4016
    LDA #$00
    STA $4016 ; tell both the controllers to latch buttons

ReadControllerOne:
    LDA $4016     ; player 1 - A
    LDA $4016     ; player 1 - B
    LDA $4016     ; player 1 - Select
    LDA $4016     ; player 1 - Start

ReadUp:
    LDA $4016     ; player 1 - Up
    AND #%00000001
    BEQ ReadUpDone

    LDA $0204
    SEC
    SBC #$01
    STA $0204

ReadUpDone:

ReadDown:
    LDA $4016     ; player 1 - Down
    AND #%00000001
    BEQ ReadDownDone

    LDA $0204
    CLC
    ADC #$01
    STA $0204

ReadDownDone:

ReadLeft:
    LDA $4016     ; player 1 - Left
    AND #%00000001
    BEQ ReadLeftDone

    LDA $0207
    SEC         ; make sure carry flag is set
    SBC #$01    ; A = A - 1
    STA $0207

ReadLeftDone:

ReadRight:
    LDA $4016     ; player 1 - Right
    AND #%00000001
    BEQ ReadRightDone

    LDA $0207   ; load sprite X (horizontal) position
    CLC         ; make sure the carry flag is clear
    ADC #$01    ; A = A + 1
    STA $0207   ; save sprite X (horizontal) position

ReadRightDone:

ReadControllerTwo:
    LDA $4017     ; player 1 - A
    LDA $4017     ; player 1 - B
    LDA $4017     ; player 1 - Select
    LDA $4017     ; player 1 - Start

ReadUpTwo:
    LDA $4017     ; player 1 - Up
    AND #%00000001
    BEQ ReadUpDoneTwo

    LDA $0200
    SEC
    SBC #$01
    STA $0200

ReadUpDoneTwo:

ReadDownTwo:
    LDA $4017     ; player 1 - Down
    AND #%00000001
    BEQ ReadDownDoneTwo

    LDA $0200
    CLC
    ADC #$01
    STA $0200

ReadDownDoneTwo:

ReadLeftTwo:
    LDA $4017     ; player 1 - Left
    AND #%00000001
    BEQ ReadLeftDoneTwo

    LDA $0203
    SEC         ; make sure carry flag is set
    SBC #$01    ; A = A - 1
    STA $0203

ReadLeftDoneTwo:

ReadRightTwo:
    LDA $4017     ; player 1 - Right
    AND #%00000001
    BEQ ReadRightDoneTwo

    LDA $0203   ; load sprite X (horizontal) position
    CLC         ; make sure the carry flag is clear
    ADC #$01    ; A = A + 1
    STA $0203   ; save sprite X (horizontal) position

ReadRightDoneTwo:

    RTI

PaletteData:
  .byte $22,$29,$1A,$0F,$22,$36,$17,$0f,$22,$30,$21,$0f,$22,$27,$17,$0F  ; Background palette
  .byte $22,$16,$27,$18,$22,$1A,$30,$27,$22,$16,$30,$27,$22,$0F,$36,$17  ; Sprite palette

SpriteData:
  .byte $08, $00, $00, $08 ; place first sprite near corner
  .byte $74, $01, $00, $7B ; perfectly center the second sprite 
  .byte $10, $02, $00, $08
  .byte $10, $03, $00, $10
  .byte $18, $04, $00, $08
  .byte $18, $05, $00, $10
  .byte $20, $06, $00, $08
  .byte $20, $07, $00, $10

.segment "VECTORS" ; NMI, RESET, IRQ
    .word NMI
    .word Reset
    .word 0; IRQ unused
.segment "CHARS"
    .incbin "template.chr"