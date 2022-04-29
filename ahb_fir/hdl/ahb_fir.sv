`timescale 1ns / 1ps

import ahb_fir_pkg::*;

module ahb_fir (
	// Global signals
	input  logic                clk                ,
	input  logic                rst_n              ,
	// AHB Master-Slave
	input  logic                hsel               ,
	input  logic [  AWIDTH-1:0] haddr              ,
	input  logic [         2:0] hsize              ,
	input  logic                hwrite             ,
	input  logic [         1:0] htrans             ,
	input  logic [  DWIDTH-1:0] hwdata             ,
	input  logic                hready             ,
	output logic                hreadyout          ,
	output logic                hresp              ,
	output logic [  DWIDTH-1:0] hrdata             ,
	// mem-FIR
	input  logic [BIT_PREC-1:0] fircoefs [0:TAPS-1],
	// FIR-FIFO
	output logic [OUT_SIZE-1:0] out_wave           ,
	output logic                write_en
);

	//******************************************************************************************//
	//************************************ Signals declaration
	//******************************************************************************************//

	// AHB
	logic              hsel_1  ;
	logic [AWIDTH-1:0] haddr_1 ;
	logic              hwrite_1;
	logic [       2:0] hsize_1 ;
	logic [       1:0] htrans_1;

	// FIR
	logic [  BIT_PREC-1:0] in_wave              ;
	logic fir_en;
	logic [2*BIT_PREC-1:0] mult   [    0:TAPS-1];
	logic [  OUT_SIZE-1:0] sum    [    0:TAPS-1];
	logic [  OUT_SIZE-1:0] sum_reg[0:(TAPS-1)-1];

	//******************************************************************************************//
	//************************************ AHB
	//******************************************************************************************//

	// Save AHB control signals
	always_ff @(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
			hsel_1   <= '0;
			haddr_1  <= '0;
			hwrite_1 <= '0;
			hsize_1  <= '0;
			htrans_1 <= '0; // Only that MUST BE reset
		end else if (hready) begin
			hsel_1   <= hsel;
			haddr_1  <= haddr[$high(haddr_1):$low(haddr_1)];
			hwrite_1 <= hwrite;
			hsize_1  <= hsize;
			htrans_1 <= htrans;
		end
	end

	// AHB write
	always_comb begin
		if ((htrans_1[1])&&(hwrite_1)&&(hsel_1)) begin
			in_wave = hwdata[BIT_PREC-1:0];
		end else begin
			in_wave = {BIT_PREC{1'b0}};
		end
	end

	assign hreadyout = 1'b1;
	assign hresp     = 1'b0;

	//******************************************************************************************//
	//************************************ FIR
	//******************************************************************************************//

	assign fir_en = hsel_1;

	// Multiplication

	// Steps:
	// 1. Double precision for each operand (with sign extension)
	// 2. Direct multiplication (discard any excess bits beyond the double precision)

	generate
		for (genvar i=0; i<TAPS; i++) begin
			assign mult[i] = {{BIT_PREC{fircoefs[TAPS-1-i][BIT_PREC-1]}},fircoefs[TAPS-1-i]} * {{BIT_PREC{in_wave[BIT_PREC-1]}},in_wave};
		end
	endgenerate

	// Sum

	// Steps
	// 1. Sign extend mult to have the same precision as sum_reg
	// 2. Direct sum (ignore carry)

	generate
		assign sum[0] = {{$clog2(TAPS-1){mult[0][2*BIT_PREC-1]}},mult[0]};
		for (genvar i=1; i<TAPS; i++) begin
			assign sum[i] = {{$clog2(TAPS-1){mult[i][2*BIT_PREC-1]}},mult[i]} + sum_reg[i-1];
		end
	endgenerate

	// Delay
	always_ff @(posedge clk or negedge rst_n) begin
		if (~rst_n) begin
			for (int i=0; i<(TAPS-1); i++) begin
				sum_reg[i] <= '0;
			end
		end else if (fir_en) begin
			for (int i=0; i<(TAPS-1); i++) begin
				sum_reg[i] <= sum[i];
			end
		end
	end

	// Output for FIFO
	assign out_wave = sum[TAPS-1][OUT_SIZE-1:0];
	assign write_en = hsel_1;


endmodule
