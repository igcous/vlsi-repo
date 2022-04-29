`timescale 1ns / 1ps

import fir_pkg::*;

module tb_fir_plus_fifo ();

	logic                clk      ;
	logic                rst_n    ;
	logic                fir_en   ;
	logic [BIT_PREC-1:0] in_wave  ;
	logic                read_en  ;
	logic                write_en ;
	logic                empty_flg;
	logic                full_flg ;
	logic [  DWIDTH-1:0] rdata    ;

	fir_plus_fifo_driver u_fir_plus_fifo_driver (
		.clk      (clk      ),
		.rst_n    (rst_n    ),
		.fir_en   (fir_en   ),
		.in_wave  (in_wave  ),
		.read_en  (read_en  ),
		.write_en (write_en ),
		.empty_flg(empty_flg),
		.full_flg (full_flg ),
		.rdata    (rdata    )
	);

	fir_plus_fifo_system u_fir_plus_fifo_system (
		.clk      (clk      ),
		.rst_n    (rst_n    ),
		.fir_en   (fir_en   ),
		.in_wave  (in_wave  ),
		.read_en  (read_en  ),
		.write_en (write_en ),
		.empty_flg(empty_flg),
		.full_flg (full_flg ),
		.rdata    (rdata    )
	);


endmodule // tb_fir_plus_fifo