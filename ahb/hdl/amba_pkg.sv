`timescale 1ns / 1ps

package amba_pkg;

	parameter DWIDTH         = 32                ;
	parameter AWIDTH         = 32                ;
	parameter TCLK           = 10                ;
	parameter MEM_HEIGHT     = 1024              ;
	parameter MEM_WIDTH      = 32                ;
	parameter MEM_ADDR_WIDTH = $clog2(MEM_HEIGHT);
	parameter SWIDTH         = 16                ;
	parameter S_ADDR_WIDTH   = $clog2(SWIDTH)    ;

	parameter input_filepath = "C:/Users/AK124602/Documents/Vivado/2021.2/ahb_v1/scripts/python/in_instr.mem";
	parameter output_filepath = "C:/Users/AK124602/Documents/Vivado/2021.2/ahb_v1/scripts/python/out.mem";

endpackage : amba_pkg