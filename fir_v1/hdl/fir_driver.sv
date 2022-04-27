`timescale 1ns / 1ps

import fir_pkg::*;

module fir_driver (
	// Global signals
	output logic                           clk     ,
	output logic                           rst_n   ,
	// FIR signals
	output logic                           fir_en  ,
	output logic [           BIT_PREC-1:0] in_wave ,
	input  logic [2*BIT_PREC+(TAPS-1)-1:0] out_wave
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
		#(5*TCLK);
		#(TCLK/10) rst_n = 1'b1;
		fir_en = 1'b1;
		run;
	end

	task automatic run();
		infileptr = $fopen(in_wave_filepath,"r");


		//#(TCLK/10) fir_en = 1'b1;

		while (!$feof(infileptr)) begin
			count = $fscanf(infileptr,"%b",read_wave);
			@ (posedge clk);
		end

		#(TCLK/10) fir_en = 1'b0;
		is_done = 1'b1;
		#(10*TCLK);

		$fclose(infileptr);
		$fclose(outfileptr);
		$stop;

	endtask

	initial begin
		outfileptr = $fopen(out_wave_filepath,"w");
	end

	assign in_wave = read_wave[BIT_PREC-1:0];

	always_ff @(posedge clk) begin
		if (fir_en) begin
			$fwrite(outfileptr,"%b\n", out_wave);
		end
		if(is_done) begin
			$fclose(outfileptr);
			$stop;
		end

	end

endmodule // fir_driver