`timescale 1ns / 1ps

package ahb_fir_pkg;

	// AHB
	parameter DWIDTH         = 32                ;
	parameter AWIDTH         = 32                ;
	parameter TCLK           = 10                ;

	parameter SWIDTH         = 16                ;
	parameter S_ADDR_WIDTH   = $clog2(SWIDTH)    ;

	parameter input_filepath = "C:/Users/AK124602/Documents/vlsi-repo/ahb_fir/python/in_amba_instr.mem";
	parameter output_filepath = "C:/Users/AK124602/Documents/vlsi-repo/ahb_fir/python/out_wave.mem";

	// MEM
	parameter MEM_HEIGHT     = 1024              ;
	parameter MEM_WIDTH      = 32                ;
	parameter MEM_ADDR_WIDTH = $clog2(MEM_HEIGHT);
	parameter incoefs_filepath = "C:/Users/AK124602/Documents/vlsi-repo/ahb_fir/python/in_coefs.mem";

	// FIR and MEM
	parameter BIT_PREC = 8;
	parameter TAPS = 20;
	parameter OUT_SIZE = 2*BIT_PREC+$clog2(TAPS-1);

endpackage : ahb_fir_pkg