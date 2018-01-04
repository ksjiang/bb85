;****************************************************************
;* 8085 I2C Library                                             *
;* Description: A collection of system routines for I2C master  *
;communication                                                  *
;* Date: January 1, 2018                                        *
;****************************************************************

; SECTION 1: Constant Definitions
; These are specific to the implemented memory and I/O.

rombase EQU 0000H
rambase EQU 8000H
stkbase EQU 83FFH	;bottom of stack @ top of RAM

inputport EQU 00H
ledctrlport EQU 01H

stddelay EQU 02H	;call delay with this to delay 51us
wdtimeout EQU 8000H	;cycles before timeout (clock stretching)

; SECTION 2: Data Definitions
; Values and labels to be loaded into memory.

.ORG rambase
;I2C global variables
;size: 2 bytes
state:
	.DB 00H			;bits 2 and 3 are CLK and DATA
started:
	.DB 00H			;whether or not com has already begun

; SECTION 3: Programs

.ORG rombase
	;initialization
	LXI SP, stkbase
	;(program code here)
	HLT

.ORG 7000H
;general-purpose delay
;input: loops (1 byte on stack)
;output: none
;returns: none
;size: 14 bytes
delay:
	PUSH H
	PUSH PSW
	LXI H, 0007H
	DAD SP
	MOV A, M		;total 47 states
delay1:
	DCR A
	JNZ delay1		;total 14X + 44 states
	POP PSW
	POP H
	RET				;total 14X + 74 states

;pulls the I2C bus CLK line low
;input: none
;output: none
;returns: none
;size: 14 bytes
i2cClearSCL:
	PUSH H
	PUSH PSW
	LXI H, state
	MOV A, M
	ORI 00000100B	;pull CLK low by setting A[2] = 1
	MOV M, A
	OUT ledctrlport
	POP PSW
	POP H
	RET

;releases the I2C bus CLK line
;input: none
;output: none
;returns: none
;size: 14 bytes
i2cSetSCL:
	PUSH H
	PUSH PSW
	LXI H, state
	MOV A, M
	ANI 11111011B	;release CLK by setting A[2] = 0
	MOV M, A
	OUT ledctrlport
	POP PSW
	POP H
	RET

;pulls the I2C bus DATA line low
;input: none
;output: none
;returns: none
;size: 14 bytes
i2cClearSDA:
	PUSH H
	PUSH PSW
	LXI H, state
	MOV A, M
	ORI 00001000B	;pull DATA low by setting A[3] = 1
	MOV M, A
	OUT ledctrlport
	POP PSW
	POP H
	RET

;releases the I2C bus CLK line
;input: none
;output: none
;returns: none
;size: 14 bytes
i2cSetSDA:
	PUSH H
	PUSH PSW
	LXI H, state
	MOV A, M
	ANI 11110111B	;release DATA by setting A[3] = 0
	MOV M, A
	OUT ledctrlport
	POP PSW
	POP H
	RET

;samples the I2C bus CLK line
;input: none
;output: none
;returns: CLK reading, in the CY flag
;size: 16 bytes
i2cReadSCL:
	PUSH PSW
	IN inputport
	RAR
	RAR
	RAR
	JC i2cReadSCL1
	POP PSW
	STC
	CMC
	RET
i2cReadSCL1:
	POP PSW
	STC
	RET

;samples the I2C bus DATA line
;input: none
;output: none
;returns: DATA reading, in the CY flag
;size: 17 bytes
i2cReadSDA:
	PUSH PSW
	IN inputport
	RAR
	RAR
	RAR
	RAR
	JC i2cReadSDA1
	POP PSW
	STC
	CMC
	RET
i2cReadSDA1:
	POP PSW
	STC
	RET

;the action was successful, return, set state[7:5]
;input: none
;output: none
;returns: none
;size: 12 bytes
i2cActionOkay:
	PUSH H
	PUSH PSW
	LXI H, state
	MOV A, M
	ANI 00011111B	;noerr
	MOV M, A
	POP PSW
	POP H
	RET

;ERR: TIMEOUT, exit com and return to calling procedure, set state[7:5]
;input: none
;output: none
;returns: none
;size: 25 bytes
i2cTimeoutErr:
	PUSH H
	PUSH PSW
	CALL i2cSetSCL
	CALL i2cSetSDA
	LXI H, state
	MOV A, M
	ANI 10011111B	;errcode 00: TIMEOUT
	ORI 10000000B
	MOV M, A
	LXI H, started
	MVI M, 00H		;com has ended
	POP PSW
	POP H
	RET

;ERR: ARBLOST, exit com and return to calling procedure, set state[7:5]
;input: none
;output: none
;returns: none
;size: 25 bytes
i2cArbLostErr:
	PUSH H
	PUSH PSW
	CALL i2cSetSCL
	CALL i2cSetSDA
	LXI H, state
	MOV A, M
	ANI 10111111B	;errcode 01: ARBLOST (arbitration lost)
	ORI 10100000B
	MOV M, A
	LXI H, started
	MVI M, 00H		;com has ended
	POP PSW
	POP H
	RET

;ERR: NACK, exit com and return to calling procedure, set state[7:5]
;input: none
;output: none
;returns: none
;size: 25 bytes
i2cNACKErr:
	PUSH H
	PUSH PSW
	CALL i2cSetSCL
	CALL i2cSetSDA
	LXI H, state
	MOV A, M
	ANI 11011111B	;errcode 10: NACK (no acknowledge)
	ORI 11000000B
	MOV M, A
	LXI H, started
	MVI M, 00H		;com has ended
	POP PSW
	POP H
	RET

;initiate I2C communication with start condition
;input: none
;output: none
;returns: none
;size: ### bytes
i2cStart:
	PUSH H
	PUSH PSW
	PUSH B
	LXI H, started	;check if com has already started
	MOV A, M
	ORA A
	JZ i2cStart3
	CALL i2cSetSDA
	MVI A, stddelay
	PUSH PSW
	CALL delay
	CALL i2cSetSCL
	;implemented clock-stretching
	LXI B, wdtimeout	;timeout
i2cStart1:
	CALL i2cReadSCL
	JC i2cStart2
	DCX B
	MOV A, B
	ORA C
	JNZ i2cStart1
	POP PSW
	POP B
	POP PSW
	POP H
	JMP i2cTimeoutErr
i2cStart2:
	CALL delay
	POP PSW
i2cStart3:
	CALL i2cReadSDA
	JC i2cStart4
	POP B
	POP PSW
	POP H
	JMP i2cArbLostErr
i2cStart4:
	CALL i2cClearSDA
	MVI A, stddelay
	PUSH PSW
	CALL delay
	POP PSW
	CALL i2cClearSCL
	LXI H, started
	MVI M, 01H		;com has started
	POP B
	POP PSW
	POP H
	JMP i2cActionOkay

;stop I2C communication with stop condition
;input: none
;output: none
;returns: none
;size: ### bytes
i2cStop:
	PUSH PSW
	PUSH B
	PUSH H
	CALL i2cClearSDA
	MVI A, stddelay	;delay 51us
	PUSH PSW
	CALL delay
	CALL i2cSetSCL
	LXI B, wdtimeout	;clock-stretching
i2cStop1:
	CALL i2cReadSCL
	JC i2cStop2
	DCX B
	MOV A, B
	ORA C
	JNZ i2cStop1
	POP PSW
	POP H
	POP B
	POP PSW
	JMP i2cTimeoutErr
i2cStop2:
	CALL delay
	CALL i2cSetSDA
	CALL delay
	POP PSW
	CALL i2cReadSDA
	JC i2cStop3
	POP H
	POP B
	POP PSW
	JMP i2cArbLostErr
i2cStop3:
	LXI H, started
	MVI M, 00H		;com has ended
	POP H
	POP B
	POP PSW
	JMP i2cActionOkay

;send a bit over the I2C bus
;input: bit to send, via the CY flag
;output: none
;returns: none
;size: ### bytes
i2cSendBit:
	PUSH PSW
	PUSH B
	PUSH PSW		;CY will be checked later
	JNC i2cSendBit1
	CALL i2cSetSDA
	JMP i2cSendBit2
i2cSendBit1:
	CALL i2cClearSDA
i2cSendBit2:
	MVI A, stddelay
	PUSH PSW
	CALL delay
	CALL i2cSetSCL
	CALL delay
	POP PSW
	LXI B, wdtimeout	;clock-stretching
i2cSendBit3:
	CALL i2cReadSCL
	JC i2cSendBit4
	DCX B
	MOV A, B
	ORA C
	JNZ i2cSendBit3
	POP PSW
	POP B
	POP PSW
	JMP i2cTimeoutErr
i2cSendBit4:
	POP PSW			;restore CY to check arblost
	JNC i2cSendBit5
	CALL i2cReadSDA
	JC i2cSendBit5
	POP B
	POP PSW
	JMP i2cArbLostErr
i2cSendBit5:
	CALL i2cClearSCL
	POP B
	POP PSW
	RET

;read a bit on the I2C bus
;input: none
;output: none
;returns: reading via the CY flag
;size: ### bytes
i2cReadBit:
	PUSH PSW
	PUSH B
	CALL i2cSetSDA
	MVI A, stddelay
	PUSH PSW
	CALL delay
	CALL i2cSetSCL
	LXI B, wdtimeout	;clock-stretching
i2cReadBit1:
	CALL i2cReadSCL
	JC i2cReadBit2
	DCX B
	MOV A, B
	ORA C
	JNZ i2cReadBit1
	POP PSW
	POP B
	POP PSW
	JMP i2cTimeoutErr
i2cReadBit2:
	CALL delay
	POP PSW
	CALL i2cReadSDA
	CALL i2cClearSCL
	POP B
	JC i2cReadBit3
	POP PSW
	STC
	CMC
	JMP i2cActionOkay
i2cReadBit3:
	POP PSW
	STC
	JMP i2cActionOkay

;writes a byte to the I2C bus
;input: data (1 byte on the stack)
;output: none
;returns: none
;size: ### bytes
i2cSendByte:
	PUSH H
	PUSH PSW
	PUSH B
	LXI H, 0009H
	DAD SP
	MOV A, M
	LXI H, state
	MVI C, 08H		;bit counter
i2cSendByte1:
	RAL
	MOV B, A		;save byte
	CALL i2cSendBit
	MOV A, M
	RAL
	JNC i2cSendByte2
	POP B			;bit-level error, com stopped, return
	POP PSW
	POP H
	RET
i2cSendByte2:
	MOV A, B		;restore byte
	DCR C
	JNZ i2cSendByte1
	CALL i2cReadBit	;byte send complete, check for ACK
	POP B
	JNC i2cSendByte3
	POP PSW
	POP H
	JMP i2cNACKErr
i2cSendByte3:
	POP PSW
	POP H
	JMP i2cActionOkay

;reads a byte from the I2C bus
;input: ACK bit via CY flag
;output: none
;returns: accumulator with 8-bit data
;size: ### bytes
i2cReadByte:
	PUSH H
	PUSH B
	PUSH PSW		;save CY for later
	LXI H, state
	MVI C, 08H		;bit counter
	XRA A			;clear accumulator
i2cReadByte1:
	CALL i2cReadBit
	RAR
	MOV B, A		;save byte so far
	MOV A, M
	RAL
	JNC i2cReadByte2
	POP PSW
	POP B			;bit-level error
	POP H
	RET
i2cReadByte2:
	MOV A, B		;restore byte so far
	DCR C
	JNZ i2cReadByte1
	MOV B, A		;save completed byte
	POP PSW
	CALL i2cSendBit
	MOV A, B		;restore completed byte
	POP B
	POP H
	JMP i2cActionOkay
