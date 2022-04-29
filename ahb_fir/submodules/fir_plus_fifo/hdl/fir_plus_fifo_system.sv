`timescale 1ns / 1ps

import fir_pkg::*;

module fir_plus_fifo_system (
	// Global signals
	input  logic                clk      ,
	input  logic                rst_n    ,
	// FIR signals
	input  logic                fir_en   ,
	input  logic [BIT_PREC-1:0] in_wave  ,
	// FIFO signals
	input  logic                read_en  ,
	input  logic                write_en ,
	output logic                empty_flg,
	output logic                full_flg ,
	output logic [  DWIDTH-1:0] rdata
);

	logic [OUT_SIZE-1:0] out_wave;
	logic [  DWIDTH-1:0] wdata   ;

	assign wdata = {{(DWIDTH-OUT_SIZE){1'b0}},out_wave};

	fir u_fir (
		.clk     (clk     ),
		.rst_n   (rst_n   ),
		.fir_en  (fir_en  ),
		.in_wave (in_wave ),
		.out_wave(out_wave)
	);

	drop_out_fifo #(.DWIDTH(32), .MEM_SIZE(1024)) u_drop_out_fifo (
		.clk      (clk      ),
		.rst_n    (rst_n    ),
		.read_en  (read_en  ),
		.write_en (write_en ),
		.wdata    (wdata  ),
		.empty_flg(empty_flg),
		.full_flg (full_flg ),
		.rdata    (rdata    )
	);

endmodule :  fir_plus_fifo_system