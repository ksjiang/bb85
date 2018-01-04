# bb85
Complete Intel 8085 I2C library (bit-banged)

## General Information and Hardware
The BB85 (Bit-Banged '85) is a ready-to-use program template to implement I2C with the Intel 8085. If used as configured, input port 00H
must be equipped with a buffer; connect bit 2 to SCL (pulled-up via resistor to 5V) and bit 3 to SDA (also pulled-up to 5V). In addition,
output port 01H should also be equipped with a buffer; buffer bit 2 should be fed into the gate of a transistor with emitter tied to 0V and
collector connected to SCL, while buffer bit 3 fed into the gate of another transistor with emitter also tied to 0V and collector connected
to SDA. Otherwise, the desired ports to be modified in Section 1 are INPUTPORT (input) and LEDCTRLPORT (output). However, it is best to
stick with bits 2 and 3 associated with SCL and SDA, respectively. Notice that for output using a non-inverting buffer, pulling a line low
means setting the corresponding bit, which may cause some confusion. The code is implemented assuming all non-inverting buffers.

## How to Use the Library
BB85 contains full functionality for the Intel 8085 to serve as an I2C master. No slave functionality is included. Full consideration has
been given to features such as loss of arbitration in multi-master implmentations, slave clock stretching, and restarts. Simply CALL a
desired function, placing appropriate arguments (if required) onto the stack or in the CY flag. All pertinent information can be found in
the library. The library only supports operations at the sub-bit, bit and byte layers, so higher-level functionality has to be implemented
by creating [your own extensions](#creating-extensions).

### Functions at the Sub-Bit Level
1. Set / Clear SCL (): i2cSetSCL / i2cClearSCL
2. Set / Clear SDA (): i2cSetSDA / i2cClearSDA
3. Read SCL (): i2cReadSCL
4. Read SDA (): i2cReadSDA

### Functions at the Bit Level
5. Start Condition (): i2cStart
6. Stop Condition (): i2cStop
7. Send Bit (CY): i2cSendBit
8. Read Bit (): i2cReadBit

### Functions at the Byte Level
9. Send Byte (byte): i2cSendByte
10. Read Byte (): i2cReadByte

## Error Handling
All of the included functions, upon reaching an error in communication, will immediately quit the communication, set the most significant
bit of the STATE global variable, and write an error code to bits 6 and 5 of STATE. The possible combinations of STATE[7:5] after an
operation are:

1. 000: OK (action was successful)
2. 100: TimeoutError (waited too long for slave to let go of SCL)
3. 101: ArbLostError (8085 was beaten by another master for control of the bus)
4. 110: NACKError (slave did not understand or was unable to process the data)

## Creating Extensions
Creating extensions on top of BB85 is extremely easy (provided you know at least the fundamentals of assembly for the Intel processors).
As an example, let us create a function that writes a byte of data to an address of the 24AA64 64-KBit EEPROM.

```
  LXI H, 1000H
  PUSH H
  MVI A, 0C3H
  PUSH PSW
  CALL i2c2464BW
...
;write a byte of data to the 24AA64 EEPROM
;inputs: 2-byte address, byte to write (total 3 bytes on stack)
;output: none
;returns: none
i2c2464BW:
    PUSH H
    PUSH PSW
    PUSH D
    CALL i2cStart
    LXI H, 0008H
    DAD SP
    MOV A, M        ;send high-order address byte
    PUSH PSW
    CALL i2cSendByte
    POP PSW
    LXI D, state    ;check if everything was ok
    LDAX D
    RAL             ;to reveal error bit
    JC i2c2464BW2   ;failed!
    INX H
    MOV A, M        ;send low-order address byte
    PUSH PSW
    CALL i2cSendByte
    POP PSW
    LDAX D          ;check for errors
    RAL
    JC i2c2464BW2
    DCX H
    DCX H
    DCX H
    MOV A, M        ;send data byte
    PUSH PSW
    CALL i2cSendByte
    POP PSW
i2c2464BW2:         ;exit
    POP D
    POP PSW
    POP H
    RET
```
