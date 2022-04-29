`timescale 1ns / 1ps

import ahb_fir_pkg::*;

module ahb_mem #(parameter MEM_BYTE=1024) (
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
	output logic [BIT_PREC-1:0] fircoefs [0:TAPS-1]
);

	//******************************************************************************************//
	//************************************ Checks
	//******************************************************************************************//

	// MEM_BYTE check
	generate
		if (2**$clog2(MEM_BYTE) != MEM_BYTE) begin
			$error("The MEM_BYTE parameter must be a power of two.");
		end
	endgenerate

	//******************************************************************************************//
	//************************************ Signals declaration
	//******************************************************************************************//

	// Memory
	logic [DWIDTH-1:0] mem[0:MEM_BYTE/4-1]; // byte addresable, always
	logic [3:0] en_byte;

	// AHB
	logic                        hsel_1  ;
	logic [$clog2(MEM_BYTE)-1:0] haddr_1 ;
	logic                        hwrite_1;
	logic [                 2:0] hsize_1 ;
	logic [                 1:0] htrans_1;

	//******************************************************************************************//
	//************************************ AHB
	//******************************************************************************************//

	// Save control signals
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

	// // Select enable logic
	// always_comb begin
	// 	en_byte = 4'b0000;
	// 	for (int ii=0; ii<4; ii++) begin
	// 		case (hsize_1)
	// 			0 : begin
	// 				if (ii == haddr_1[1:0]) begin
	// 					en_byte[ii] = 1'b1;
	// 				end
	// 			end
	// 			1 : begin
	// 				if (ii[1] == haddr_1[1]) begin
	// 					en_byte[ii] = 1'b1;
	// 				end
	// 			end
	// 			2 : begin
	// 				en_byte[ii] = 1'b1;
	// 			end
	// 		endcase
	// 	end
	// end

	// // AHB Write for word-addressed memory
	// always_ff @(posedge clk) begin
	// 	if ((htrans_1[1])&&(hwrite_1)&&(hsel_1)) begin
	// 		for (int ii=0;ii<4;ii++) begin
	// 			if (en_byte[ii]) begin
	// 				mem[haddr_1[$high(haddr_1):2]][8*ii+:8] <= hwdata[8*ii+:8];
	// 			end
	// 		end
	// 	end
	// end

	// // AHB Read

	// always_comb begin
	// 	hrdata = mem[haddr_1[$size(haddr_1)-1:2]];	// [AWIDTH-4-1:2] -> bits used to adress memory by bytes, 4 bits used to select slave
	// end

	assign hreadyout = 1'b1;
	assign hresp     = 1'b0;

	//******************************************************************************************//
	//************************************ FIR
	//******************************************************************************************//

	// Output FIR coefficients
	// Note: Coefficients are loaded from file for now, but they could be loaded by amba instructions
	
	initial begin
		$readmemb(incoefs_filepath, mem);
	end

	always_comb begin
		for (int ii=0;ii<TAPS;ii++) begin
			fircoefs[ii][BIT_PREC-1:0] = mem[ii][BIT_PREC-1:0];
		end
	end

endmodule
