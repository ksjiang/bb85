# bb85
Complete Intel 8085 I2C library (bit-banged)

## General Information and Hardware
The BB85 (Bit-Banged '85) is a ready-to-use program template to implement I2C with the Intel 8085. If used as configured, input port 00H must be equipped with a buffer; connect bit 2 to SCL (pulled-up via resistor to 5V) and bit 3 to SDA (also pulled-up to 5V). In addition, output port 01H should also be equipped with a buffer; buffer bit 2 should be fed into the gate of a transistor with emitter tied to 0V and collector connected to SCL, while buffer bit 3 fed into the gate of another transistor with emitter also tied to 0V and collector connected to SDA. Otherwise, the desired ports to be modified in Section 1 are INPUTPORT (input) and LEDCTRLPORT (output). However, it is best to stick with bits 2 and 3 associated with SCL and SDA, respectively. Notice that for output using a non-inverting buffer, pulling a line low means setting the corresponding bit, which may cause some confusion. The code is implemented assuming all non-inverting buffers.

## How to Use the Library
BB85 contains full functionality for the Intel 8085 to serve as an I2C master. No slave functionality is included. Full consideration has been given to features such as loss of arbitration in multi-master implmentations, slave clock stretching, and restarts. Simply CALL a desired function, placing appropriate arguments (if required) onto the stack or in the CY flag. All pertinent information can be found in the library. The library only supports operations at the sub-bit, bit and byte layers, so higher-level functionality has to be implemented by creating [your own extensions](#creating-extensions).

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
All of the included functions, upon reaching an error in communication, will immediately quit the communication, set the most significant bit of the STATE global variable, and write an error code to bits 6 and 5 of STATE. The possible combinations of STATE[7:5] after an operation are:

1. 000: OK (action was successful)
2. 100: TimeoutError (waited too long for slave to let go of SCL)
3. 101: ArbLostError (8085 was beaten by another master for control of the bus)
4. 110: NACKError (slave did not understand or was unable to process the data)

## Creating Extensions
Creating extensions on top of BB85 is extremely easy (provided you know at least the fundamentals of assembly for the Intel processors). As an example, let us create a function that writes a byte of data to an address of the [24AA64 64-KBit EEPROM](http://ww1.microchip.com/downloads/en/DeviceDoc/21189f.pdf).

```assembly
  MVI A, 0C3H       ;data
  PUSH PSW
  LXI H, 1000H      ;address
  PUSH H
  MVI A, 00000101B  ;device address (configured via hardware)
  PUSH PSW
  CALL i2c2464BW
...
;write a byte of data to the 24AA64 EEPROM
;inputs: data, address, device address bits (lower 3) (total 4 bytes on stack)
;output: none
;returns: none
i2c2464BW:
    PUSH H
    PUSH PSW
    PUSH D
    LXI H, 0009H
    DAD SP
    LXI D, state    ;for error checking
;********************************
    CALL i2cStart   ;start transmission
    LDAX D
    RAL
    JC i2c2464BW2
;********************************
    MOV A, M        ;send high-order address byte
    RLC             ;bit[0] = 0 (write), and bit[3:1] are device address
    PUSH PSW
    CALL i2cSendByte
    POP PSW
    LDAX D
    RAL             ;to reveal error bit
    JC i2c2464BW2   ;failed!
;********************************
    INX H
    MOV A, M        ;send low-order address byte
    PUSH PSW
    CALL i2cSendByte
    POP PSW
    LDAX D          ;check for errors
    RAL
    JC i2c2464BW2
;********************************
    INX H
    MOV A, M        ;send low-order address byte
    PUSH PSW
    CALL i2cSendByte
    POP PSW
    LDAX D          ;check for errors
    RAL
    JC i2c2464BW2
;********************************
    INX H
    INX H
    MOV A, M        ;send data byte
    PUSH PSW
    CALL i2cSendByte
    POP PSW
    LDAX D
    RAL
    JC i2c2464BW2
;********************************
    CALL i2cStop    ;no error checking needed since this is last step
i2c2464BW2:         ;exit
    POP D
    POP PSW
    POP H
    RET
```

Notice that code between the breaks are extremely similar. They generally set the memory address of the parameter (here placed on the stack), place it into a register, do some processing, PUSH the register, and call a BB85 procedure. Finally, STATE is checked after each transmission action, and if an error is encountered, the communication is halted (for more precise behavior, error handling based on STATE can be implemented).

So why did I not create higher-level procedures to wrap the byte level? There really wasn't justification for all the added complexity. Each slave device has its own I2C requirements; beyond some general start plus 8-byte address plus 8-byte data devices, it would be impossible to write all of them. In any case, we observe that implemented code would not particulaly benefit from procedures of higher layers; as BB85's I2C has already been sufficiently abstracted.

## References and ACKnowledgements :)
1. [Understanding the I2C Bus](http://www.ti.com/lit/an/slva704/slva704.pdf) (Texas Instruments)
2. [8080 / 8085 Assembly Language Programming](https://www.tramm.li/i8080/Intel%208080-8085%20Assembly%20Language%20Programming%201977%20Intel.pdf) (Intel)
