`timescale 1ns / 1ps

package fir_pkg;
	parameter TCLK = 2;
	parameter in_wave_filepath = "C:/Users/AK124602/Documents/vlsi-repo/fir_v1/python/inwave.mem";
	parameter in_coefs_filepath = "C:/Users/AK124602/Documents/vlsi-repo/fir_v1/python/incoefs.mem";
	parameter out_wave_filepath = "C:/Users/AK124602/Documents/vlsi-repo/fir_v1/python/outwave.mem";

	parameter TAPS     = 20;
	parameter BIT_PREC = 4 ;
	parameter DWIDTH   = 32;

endpackage : fir_pkg