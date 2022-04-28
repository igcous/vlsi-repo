`timescale 1ns / 1ps

package fir_pkg;
	parameter TCLK = 2;
	parameter in_wave_filepath = "C:/Users/AK124602/Documents/vlsi-repo/fir/python/inwave.mem";
	parameter in_coefs_filepath = "C:/Users/AK124602/Documents/vlsi-repo/fir/python/incoefs.mem";
	parameter out_wave_filepath = "C:/Users/AK124602/Documents/vlsi-repo/fir/python/outwave.mem";

	parameter DWIDTH   = 32                              ;
	parameter TAPS     = 20                              ;
	parameter BIT_PREC = 8                               ;
	parameter OUT_SIZE = 2*BIT_PREC+$clog2(TAPS-1);

endpackage : fir_pkg