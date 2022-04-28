`timescale 1ns / 1ps

import fir_pkg::*;

// Transposed structure FIR
module fir (
	// Global signals
	input  logic                clk     ,
	input  logic                rst_n   ,
	// FIR signals
	input  logic                fir_en  ,
	input  logic [BIT_PREC-1:0] in_wave ,
	output logic [OUT_SIZE-1:0] out_wave
);

	///////////////////////////////////////////////////////////////////
	// Signals
	///////////////////////////////////////////////////////////////////

	logic [  DWIDTH-1:0] in_coefs[0:TAPS-1];
	logic [BIT_PREC-1:0] coefs   [0:TAPS-1];

	logic [         2*BIT_PREC-1:0] mult   [    0:TAPS-1];
	logic [OUT_SIZE-1:0] sum    [    0:TAPS-1];
	logic [OUT_SIZE-1:0] sum_reg[0:(TAPS-1)-1];

	///////////////////////////////////////////////////////////////////
	// Reading coefficients from mem file
	///////////////////////////////////////////////////////////////////

	initial begin
		$readmemb(in_coefs_filepath, in_coefs);
	end

	generate
		for (genvar i=0; i<TAPS; i++) begin
			assign coefs[i][BIT_PREC-1:0] = in_coefs[i][BIT_PREC-1:0];
		end
		// Note: coefficients in the mem file are already sign extended but that is not considered
		// i.e. coefficients are read up to the specified bit precision and sign extension is done here
	endgenerate

	///////////////////////////////////////////////////////////////////
	// Multiplication
	///////////////////////////////////////////////////////////////////

	// Steps:
	// 1. Double precision for each operand (with sign extension)
	// 2. Direct multiplication (discard any excess bits beyond the double precision)

	generate
		for (genvar i=0; i<TAPS; i++) begin
			assign mult[i] = {{BIT_PREC{coefs[TAPS-1-i][BIT_PREC-1]}},coefs[TAPS-1-i]} * {{BIT_PREC{in_wave[BIT_PREC-1]}},in_wave};
		end
	endgenerate

	///////////////////////////////////////////////////////////////////
	// Sum
	///////////////////////////////////////////////////////////////////

	// Steps
	// 1. Sign extend mult to have the same precision as sum_reg
	// 2. Direct sum (ignore carry)

	generate
		assign sum[0] = {{$clog2(TAPS-1){mult[0][2*BIT_PREC-1]}},mult[0]};
		for (genvar i=1; i<TAPS; i++) begin
			assign sum[i] = {{$clog2(TAPS-1){mult[i][2*BIT_PREC-1]}},mult[i]} + sum_reg[i-1];
		end
	endgenerate

	///////////////////////////////////////////////////////////////////
	// Delay
	///////////////////////////////////////////////////////////////////

	always_ff @(posedge clk or negedge rst_n) begin
		if (~rst_n) begin
			for (int i=0; i<(TAPS-1); i++) begin
				sum_reg[i] <= '0;
			end
		end else begin
			for (int i=0; i<(TAPS-1); i++) begin
				sum_reg[i] <= sum[i];
			end
		end
	end

	///////////////////////////////////////////////////////////////////
	// Output
	///////////////////////////////////////////////////////////////////

	assign out_wave = sum[TAPS-1];

	// Visualization

	logic [16:0] temp;
	assign temp = out_wave[16:0];

endmodule // fir