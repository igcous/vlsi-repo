`timescale 1ns / 1ps

package spi_pkg;
	parameter TCLK = 2;
	parameter input_filepath = "C:/Users/AK124602/Documents/vlsi-repo/new_spi_v4/python/in_instr.mem";
	parameter output_filepath = "C:/Users/AK124602/Documents/vlsi-repo/new_spi_v4/python/out.mem";

	// SPI
	parameter MEM_WIDTH  = 32                            ;
	parameter MEM_HEIGHT = 1024                          ;
	parameter AWIDTH     = $clog2(MEM_WIDTH*MEM_HEIGHT/8); // Byte addresed memory
	parameter DWIDTH     = 32                            ; // MAX

	// Use only one slave for now
	parameter NSLAVES       = 4                 ; // Number of slaves
	parameter S_ADDR_WIDTH = $clog2(NSLAVES)    ; // Number of slave addresses

	
endpackage : spi_pkg