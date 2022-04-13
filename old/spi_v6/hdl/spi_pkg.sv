`timescale 1ns / 1ps

package spi_pkg;
	parameter TCLK = 2;
	parameter input_filepath = "C:/Users/AK124602/Documents/Vivado/2021.2/spi_v5/scripts/python/in_instr.mem";
	parameter output_filepath = "C:/Users/AK124602/Documents/Vivado/2021.2/spi_v5/scripts/python/out.mem";

	// SPI
	parameter MEM_WIDTH  = 32                            ;
	parameter MEM_HEIGHT = 1024                          ;
	parameter AWIDTH     = $clog2(MEM_WIDTH*MEM_HEIGHT/8); // Byte addresed memory
	parameter DWIDTH     = 32                            ; // MAX
	//parameter CONTROL_SIZE = AWIDTH+2+1                    ; // (15)=ADDR(12)+SIZE(2)+WR_EN(1)
	//parameter INSTR_SIZE = DWIDTH+AWIDTH+2+1; // (45)=WDATA(32)+ADDR(10)+SIZE(2)+WR_EN(1)

	// Use only one slave for now
	//parameter SWIDTH       = 4                 ; // Number of slaves
	//parameter S_ADDR_WIDTH = $clog2(SWIDTH)    ; // Number of slave addresses

	
endpackage : spi_pkg