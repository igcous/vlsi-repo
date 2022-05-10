import fir_pkg::*;

module top_module (
	input  logic                clk     ,
	input  logic                rst_n   ,
	input  logic                fir_en  ,
	input  logic [BIT_PREC-1:0] in_wave ,
	output logic [OUT_SIZE-1:0] out_wave
);

	logic                clk     ;
	logic                rst_n   ;
	logic                fir_en  ;
	logic [BIT_PREC-1:0] in_wave ;
	logic [OUT_SIZE-1:0] out_wave;

	fir u_fir (
		.clk     (clk     ),
		.rst_n   (rst_n   ),
		.fir_en  (fir_en  ),
		.in_wave (in_wave ),
		.out_wave(out_wave)
	);

endmodule // top_module