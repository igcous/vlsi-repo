`timescale 1ns / 1ps

package spic_pkg;
	parameter TCLK = 2;
	parameter input_filepath = "C:/Users/AK124602/Documents/vlsi-repo/spic/python/in_instr.mem";
	parameter output_filepath = "C:/Users/AK124602/Documents/vlsi-repo/spic/python/out.mem";

	parameter DWIDTH = 32; // MAX

	// Memory-specific
	parameter MEM_WIDTH  = 32  ;
	parameter MEM_HEIGHT = 1024;

	// Instruction size
	parameter AWIDTH     = 32                     ; // Byte addresed memory, fixed for AHB
	parameter INSTR_SIZE = AWIDTH+DWIDTH+6        ; // ss+t_type+size+addr+data
	parameter S_DATA_SIZE  = INSTR_SIZE-S_ADDR_WIDTH; // SPI data size

	// Related to number of slaves
	parameter NSLAVES      = 4              ; // Number of slaves
	parameter S_ADDR_WIDTH = $clog2(NSLAVES); // Number of slave addresses


endpackage : spic_pkg