# FPGA-Based Video Chat System

## Project Description
This project implements real-time, bidirectional video communication between two hosts on the same LAN, one side of which is implemented in hardware (for both transmision and reception). 

Transmission Components
- I2C-like (SCCB) protocol support
- Video stream decoding logic
- Frame buffer (transmission)
- Video frame divider and packetizer
- UDP/IP packetizer


Reception Components
- Frame depacketizer
- Video decode logic
- Frame buffer (reception)
- Video display logic


## Platform and Dependencies    
This project targets the Nexys A7 (AMD Artix-7 platform) development board, and was developed in Vivado (contraints are specified in an Xilinx Design Contraints file). 
To support the Ethernet port on the Nexys A7 board, the [LiteEth core](https://github.com/enjoy-digital/liteeth) from the [LiteX IP library](https://github.com/enjoy-digital/litex).

LLMs were used in the creation of:
- cam_i2c (reg_trans.sv)
- recvvideo.c
- sendvideo.cpp

The following modules were adapted from HDL provided by ECE 385 at the University of Illinois Urbana Champaign:
- hex_driver (hex_driver.sv)
- sync_debounce (sync_debounce.sv)

## Repository Structure
```
FPGA-Video-Chat/
├── constr/
│   ├── Vivado constraints and liteeth configuration
├── design/
│   └── Synthesizable SystemVerilog modules
├── dsp-demo/
│   └── Demo Python code for JPEG compression (WORK IN PROGRESS)
├── src/
│   └── Software (for laptop host)
└── verif/
    └── Simulation SystemVerilog modules
```