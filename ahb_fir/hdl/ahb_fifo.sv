`timescale 1ns / 1ps

import ahb_fir_pkg::*;

module ahb_fifo #(
	parameter MEM_SIZE = 4,
	parameter DWIDTH   = 8
) (
	// Global signals
	input  logic                clk      ,
	input  logic                rst_n    ,
	// AHB Master-Slave
	input  logic                hsel     ,
	input  logic [  AWIDTH-1:0] haddr    ,
	input  logic [         2:0] hsize    ,
	input  logic                hwrite   ,
	input  logic [         1:0] htrans   ,
	input  logic [  DWIDTH-1:0] hwdata   ,
	input  logic                hready   ,
	output logic                hreadyout,
	output logic                hresp    ,
	output logic [  DWIDTH-1:0] hrdata   ,
	// FIR-FIFO
	input  logic [OUT_SIZE-1:0] out_wave ,
	input  logic                write_en
);

	//******************************************************************************************//
	//************************************ Checks
	//******************************************************************************************//

	// MEM_BYTE check
	generate
		if (2**$clog2(MEM_SIZE) != MEM_SIZE) begin
			$error("The MEM_BYTE parameter must be a power of two.");
		end
	endgenerate

	//******************************************************************************************//
	//************************************ Signals declaration
	//******************************************************************************************//

	// FIFO
	parameter          AWIDTH                  = $clog2(MEM_SIZE);
	logic [DWIDTH-1:0] mem      [0:MEM_SIZE-1]                   ;
	logic [  AWIDTH:0] wptr                                      ; // AWIDTH-1+1 : addresses+1, extra bit is used to check for empty or full
	logic [  AWIDTH:0] rptr                                      ;
	logic              empty_flg                                 ;
	logic              full_flg                                  ;
	logic [DWIDTH-1:0] wdata                                     ;
	logic              write_en                                  ;
	logic              read_en                                   ;
	logic [DWIDTH-1:0] mem_out;

	// AHB
	logic                        hsel_1  ;
	logic [$clog2(MEM_SIZE)-1:0] haddr_1 ;
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

	assign hreadyout = 1'b1;
	assign hresp     = 1'b0;
	assign mem_out = mem[rptr[AWIDTH-1:0]];

	// AHB Read
	always_comb begin
		hrdata = {empty_flg,mem_out[DWIDTH-2:0]};
		// Note: First bit indicates if the read data is valid (i.e. if this bit is 1, data was read from an empty fifo = data invalid)
	end

	// // AHB Read
	// always_comb begin
	// 	hrdata = mem[rptr[AWIDTH-1:0]];
	// end

	//******************************************************************************************//
	//************************************ FIFO
	//******************************************************************************************//

	assign wdata   = {{(DWIDTH-OUT_SIZE){1'b0}},out_wave};
	assign read_en = hsel_1;

	always_ff @(posedge clk or negedge rst_n) begin
		if (~rst_n) begin
			wptr <= '0;
			rptr <= '0;

		end else if (write_en) begin
			if (~full_flg) begin // Normal function
				mem[wptr[AWIDTH-1:0]] <= wdata;
				wptr                  <= wptr+1'b1;
			end else begin // WRITE + FULL handling
				mem[wptr[AWIDTH-1:0]] <= wdata;
				wptr                  <= wptr+1'b1;
				rptr                  <= rptr+1'b1;
			end

		end else if (read_en) begin
			if (~empty_flg) begin // Normal function
				rptr <= rptr+1'b1;
			end else begin // READ + EMPTY handling
				rptr <= rptr+1'b1;
				wptr <= wptr+1'b1;
			end
		end

	end

	assign empty_flg = (wptr==rptr);
	assign full_flg  = ({~wptr[AWIDTH],wptr[AWIDTH-1:0]}==rptr);


endmodule
