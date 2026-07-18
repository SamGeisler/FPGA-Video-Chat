# FPGA-Based Video Chat System

## Project Description

## Platform and Dependencies    
This project targets the Nexys A7 (AMD Artix-7 platform) development board, and was developed in Vivado (contraints are specified in an Xilinx Design Contraints file). 
To support the Ethernet port on the Nexys A7 board, the [LiteEth core](https://github.com/enjoy-digital/liteeth) from the [LiteX IP library](https://github.com/enjoy-digital/litex).

LLMs were used in the creation of the following modules:
- cam_i2c (reg_trans.sv)

The following modules were adapted from HDL provided by ECE 385 at the University of Illinois Urbana Champaign:
- hex_driver (hex_driver.sv)
- sync_debounce (sync_debounce.sv)
## Repository Structure

## Hardware Architecture