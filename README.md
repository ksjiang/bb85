# BB85
Intel 8085 I2C library

Written by K. Jiang

## General Information and Hardware
The BB85 (Bit-Banged '85) is a ready-to-use program template to implement I2C with the Intel 8085. If used as configured, input port 00H must be equipped with a buffer; connect bit 2 to SCL (pulled-up via resistor to 5V) and bit 3 to SDA (also pulled-up to 5V). In addition, output port 01H should also be equipped with a buffer; buffer bit 2 should be fed into the gate of a transistor with emitter tied to 0V and collector connected to SCL, while buffer bit 3 fed into the gate of another transistor with emitter also tied to 0V and collector connected to SDA. Otherwise, the desired ports to be modified in Section 1 are INPUTPORT (input) and LEDCTRLPORT (output). However, it is best to stick with bits 2 and 3 associated with SCL and SDA, respectively. Notice that for output using a non-inverting buffer, pulling a line low means setting the corresponding bit, which may cause some confusion. The code is implemented assuming all non-inverting buffers.

The described layout is provided below. The data lines (D0 - D7) are the demultiplexed AD0 - AD7 from the 8085. IO00 and IO01 are signals that represent activated I/O ports 00H and 01H, respectively.

<img width="913" alt="screenshot 2018-01-03 22 59 58" src="https://user-images.githubusercontent.com/25142270/34550922-7fd3eb20-f0da-11e7-8a59-e44e789ddfba.png">

## How to Use the Library
BB85 contains full functionality for the Intel 8085 to serve as an I2C master. No slave functionality is included. Full consideration has been given to features such as loss of arbitration in multi-master implmentations, slave clock stretching, and restarts. Simply CALL a desired function, placing appropriate arguments (if required) onto the stack or in the CY flag. All pertinent information can be found in the library. The library supports operations at the sub-bit, bit, byte, and bytestream layers, but higher-level functionality can be implemented by creating [your own extensions](#creating-extensions).

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

### Functions at the Bytestream Level
11. Send Byte Stream (argc, \*bytesToSend): i2cSendByteStream
12. Read Byte Stream (argc, \*bytesToStore): i2cReadByteStream

## Error Handling
All of the included functions, upon reaching an error in communication, will immediately quit the communication, set the most significant bit of the STATE global variable, and write an error code to bits 6 and 5 of STATE. The possible combinations of STATE[7:5] after an operation are:

1. 000: OK (action was successful)
2. 100: TimeoutError (waited too long for slave to let go of SCL)
3. 101: ArbLostError (8085 was beaten by another master for control of the bus)
4. 110: NACKError (slave did not understand or was unable to process the data)

## Creating Extensions
Creating extensions on top of BB85 is simple, provided you know at least the fundamentals of assembly for the Intel processors. As an example, let us create a function that reads a byte of data from a random address of the [24AA64 64-KBit EEPROM](http://ww1.microchip.com/downloads/en/DeviceDoc/21189f.pdf).

First create the header:

```assembly
;reads a byte of data from the 24AA64 EEPROM (1010XXXR)
;input: data store address (1 byte on the stack), data read address (1 byte on the stack, big-endian), EEPROM hardwired address (last 3 bits of 1 byte on the stack)
;output: none
;returns: errorcode (accumulator)
;size: ### bytes
```

We first save the registers we will be using (usually the last step, after the procedure has been written):
```assembly
EEPROMrread:
  PUSH H
  PUSH D
  PUSH PSW
```

Next, we set up HL as a secondary stack pointer, pointing to our first argument (the EEPROM hardwired address):

```assembly
  LXI H, 0009H
  DAD SP
```

We begin communication by sending a Start condition and checking for errors:

```assembly
  LXI D, state
  CALL i2cStart
  LDAX D
  RAL
  JNC EEPROMrread1
  ;(error handling here)
  MVI E, 10000000B  ;errorcode for failed at Start
  JMP EEPROMrread8
```

Now we form the I2C address of the slave and send that:

```assembly
EEPROMrread1:
  MOV A, M
  RLC
  ANI 10101110B     ;set bitmasks
  ORI 10100000B
  PUSH PSW
  CALL i2cSendByte
  LDAX D            ;we don't POP PSW yet because we will reuse
  RAL
  JNC EEPROMrread2
  ;(error handling here)
  MVI E, 10000001B  ;errorcode for failed at address send
  POP PSW
  JMP EEPROMrread8
```

Next we send the address of the memory we want to access:

```assembly
EEPROMrread2:
  INX H
  PUSH H
  MVI A, 02H
  PUSH PSW
  CALL i2cSendByteStream
  POP PSW
  POP H
  LDAX D
  RAL
  JNC EEPROMrread3
  ;(error handling here)
  MVI E, 10000010B  ;errorcode for failed at memory address send
  POP PSW
  JMP EEPROMrread8
```

We send a repeated start:

```assembly
EEPROMrread3:
  CALL i2cStart
  LDAX D
  RAL
  JNC EEPROMrread4
  ;(error handling here)
  MVI E, 10000011B  ;errorcode for failed at repeated Start
  POP PSW
  JMP EEPROMrread8
```

Resend I2C address of slave:

```assembly
EEPROMrread4:
  POP PSW
  ANI 11111110B     ;reading now
  PUSH PSW
  CALL i2cSendByte
  POP PSW
  LDAX D
  RAL
  JNC EEPROMrread5
  ;(error handling here)
  MVI E, 10000100B  ;errorcode for failed at address send
  JMP EEPROMrread8
```

Then read:

```assembly
EEPROMrread5:
  INX H
  INX H
  MOV E, M
  INX H
  MOV D, M
  PUSH D
  MVI A, 01H        ;1 byte only
  PUSH PSW
  CALL i2cReadByteStream
  POP PSW
  POP D
  LXI D, state
  LDAX D
  RAL
  JNC EEPROMrread6
  ;(error handling here)
  MVI E, 10000101B  ;errorcode for failed at memory address send
  JMP EEPROMrread8
```

Finally, we stop the communication:

```assembly
EEPROMrread6:
  CALL i2cStop
  LDAX D
  RAL
  JNC EEPROMrread7
  ;(error handling here)
  MVI E, 10000110B  ;errorcode for failed at stop
  JMP EEPROMrread8
```

And if everything was good, we return 0:

```assembly
EEPROMrread7:
  MVI E, 00000000B  ;no error
EEPROMrread8:
  POP PSW
  MOV A, E
  POP D
  POP H
  RET
```

## References and ACKnowledgements :)
1. Mr. Hassman - thank you for all the hardware and support.
2. [Understanding the I2C Bus](http://www.ti.com/lit/an/slva704/slva704.pdf) (Texas Instruments)
3. [8080 / 8085 Assembly Language Programming](https://www.tramm.li/i8080/Intel%208080-8085%20Assembly%20Language%20Programming%201977%20Intel.pdf) (Intel)
