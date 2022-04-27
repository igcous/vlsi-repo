`timescale 1ns / 1ps

import fir_pkg::*;

// Transposed structure FIR
module fir_v2 (
	// Global signals
	input  logic                           clk     ,
	input  logic                           rst_n   ,
	// FIR signals
	input  logic                           fir_en  ,
	input  logic [         2*BIT_PREC-1:0] in_wave ,
	output logic [(2*BIT_PREC+TAPS-1)-1:0] out_wave
);

	int                infileptr          ;
	logic [DWIDTH-1:0] in_coefs [0:TAPS-1];

	initial begin
		$readmemb(in_coefs_filepath, in_coefs);
	end

	logic [(2*BIT_PREC+TAPS-1)-1:0] delay_reg[0:(TAPS-1)-1]; // BIT_PREC x 2 (mult) + TAPS - 1 (sums), same number as summators
	logic [         2*BIT_PREC-1:0] mult     [    0:TAPS-1];
	logic [(2*BIT_PREC+TAPS-1)-1:0] sum      [    0:TAPS-1]; // +1 because of sum[0]

	generate
		for (genvar i=0;i<TAPS;i++) begin
			assign mult[i][2*BIT_PREC-1:0] = in_wave * in_coefs[TAPS-1-i][2*BIT_PREC-1:0];
		end

		//assign sum[0] = mult[0];
		for (genvar i=0;i<TAPS;i++) begin
			case (i)
				0: begin;
					assign sum[i]                                       = mult[i];
					assign sum[i][(2*BIT_PREC+TAPS-1)-1:(2*BIT_PREC+i)] = sum[i][2*BIT_PREC-1+i]; // sign extension
				end
				TAPS-1: begin
					assign sum[i][2*BIT_PREC-1+i:0] = delay_reg[i-1] + mult[i];
					// max_size, no sign extension
				end
				default: begin
					assign sum[i][2*BIT_PREC-1+i:0] = delay_reg[i-1] + mult[i];
					assign sum[i][(2*BIT_PREC+TAPS-1)-1:(2*BIT_PREC+i)] = sum[i][2*BIT_PREC-1+i]; // sign extension
				end
			endcase
		end
	endgenerate


	always_ff @(posedge clk or negedge rst_n) begin
		if (~rst_n) begin
			for (int i=0; i<(TAPS-1); i++) begin
				delay_reg[i] <= '0;
			end
		end else begin
			for (int i=0; i<(TAPS-1); i++) begin
				delay_reg[i] <= sum[i];
			end
		end
	end

	assign out_wave = sum[TAPS-1];

	logic [19:0] temp;
	assign temp = out_wave[19:0];

endmodule // fir_v2