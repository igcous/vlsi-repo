`timescale 1ns / 1ps

import fir_pkg::*;

module tb_fir ();

	logic                clk     ;
	logic                rst_n   ;
	logic                fir_en  ;
	logic [BIT_PREC-1:0] in_wave ;
	logic [OUT_SIZE-1:0] out_wave;

	fir_driver u_fir_driver (
		.clk     (clk     ),
		.rst_n   (rst_n   ),
		.fir_en  (fir_en  ),
		.in_wave (in_wave ),
		.out_wave(out_wave)
	);

	fir u_fir (
		.clk     (clk     ),
		.rst_n   (rst_n   ),
		.fir_en  (fir_en  ),
		.in_wave (in_wave ),
		.out_wave(out_wave)
	);



endmodule // tb_fir