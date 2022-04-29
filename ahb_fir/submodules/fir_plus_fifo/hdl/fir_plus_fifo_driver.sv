`timescale 1ns / 1ps

import fir_pkg::*;

module fir_plus_fifo_driver (
	// Global signals
	output logic                clk      ,
	output logic                rst_n    ,
	// FIR signals
	output logic                fir_en   ,
	output logic [BIT_PREC-1:0] in_wave  ,
	// FIFO signals
	output logic                read_en  ,
	output logic                write_en ,
	input  logic                empty_flg,
	input  logic                full_flg ,
	input  logic [  DWIDTH-1:0] rdata
);

	int                infileptr, outfileptr, count;
	logic              is_done  ;
	logic [DWIDTH-1:0] read_wave;

	always #(TCLK/2) clk=!clk;

	initial begin
		clk = 1'b1;
		rst_n = 1'b0;
		is_done = 1'b0;
		fir_en = 1'b0;
		read_en = 1'b0;
		write_en = 1'b0;
		#(5*TCLK);

		#(TCLK/10) rst_n = 1'b1;
		fir_en = 1'b1;
		write_en = 1'b1;
		write();
		write_en = 1'b0;
		fir_en = 1'b0;
		#(5*TCLK);

		read_en = 1'b1;
	end

	task automatic write();
		infileptr = $fopen(in_wave_filepath,"r");

		while (!$feof(infileptr)) begin
			count = $fscanf(infileptr,"%b",read_wave);
			@ (posedge clk);
		end

		#(TCLK/10) fir_en = 1'b0;
		is_done = 1'b1;
		//#(10*TCLK);

		$fclose(infileptr);
	endtask

	initial begin
		outfileptr = $fopen(out_wave_filepath,"w");
	end

	assign in_wave = read_wave[BIT_PREC-1:0];

	always_ff @(posedge clk) begin
		if (read_en&&empty_flg) begin
			$fclose(outfileptr);
			$stop;
		end else if (read_en) begin
			$fwrite(outfileptr,"%b\n", rdata);
		end

	end

endmodule // fir_plus_fifo_driver