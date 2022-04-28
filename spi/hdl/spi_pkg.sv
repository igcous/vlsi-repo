`timescale 1ns / 1ps

package spi_pkg;
	parameter TCLK = 2;
	parameter input_filepath = "C:/Users/AK124602/Documents/vlsi-repo/new_spi_v8/python/in_instr_2.mem";
	parameter output_filepath = "C:/Users/AK124602/Documents/vlsi-repo/new_spi_v8/python/out.mem";

	parameter DWIDTH     = 32                            ; // MAX

	// Memory-specific
	parameter MEM_WIDTH  = 32                            ;
	parameter MEM_HEIGHT = 1024                          ;
	parameter AWIDTH     = $clog2(MEM_WIDTH*MEM_HEIGHT/8); // Byte addresed memory
	// Note: address width is linked to slave memory size

	// Related to number of slaves
	parameter NSLAVES       = 4                 ; // Number of slaves
	parameter S_ADDR_WIDTH = $clog2(NSLAVES)    ; // Number of slave addresses

	
endpackage : spi_pkg