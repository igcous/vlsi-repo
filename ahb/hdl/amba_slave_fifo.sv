`timescale 1ns / 1ps

import amba_pkg::*;

// Is this tested?

// This is the interface from AMBA AHB to the FIFO slave
// Idea is to write and read from it without changing its internal design

module amba_slave_fifo #(parameter MEM_BYTE=4) (
	// Global signals
	input  logic              clk      ,
	input  logic              rst_n    ,
	// Master-Slave
	input  logic              hsel     ,
	input  logic [AWIDTH-1:0] haddr    ,
	input  logic [       2:0] hsize    ,
	input  logic              hwrite   ,
	input  logic [       1:0] htrans   ,
	input  logic [DWIDTH-1:0] hwdata   ,
	input  logic              hready   ,
	output logic              hreadyout,
	output logic              hresp    ,
	output logic [DWIDTH-1:0] hrdata   ,

	// input  logic [DWIDTH-1:0] wdata    ,
	// input  logic              read_en  ,
	// input  logic              write_en ,
	// output logic [DWIDTH-1:0] rdata    ,
	// output logic              empty_flg,
	// output logic              full_flg ,
	// output logic              error_flg
);

	// MEM_BYTE check
	generate
		if (2**$clog2(MEM_BYTE) != MEM_BYTE) begin
			$error("The MEM_BYTE parameter must be a power of two.");
		end
	endgenerate

	parameter ADDRWIDTH = $clog2(MEM_BYTE);

	logic [ DWIDTH-1:0] mem [0:MEM_BYTE/4-1];
	logic [ADDRWIDTH:0] wptr                   ;
	logic [ADDRWIDTH:0] rptr                   ;

	logic                        hsel_1  ;
	logic [$clog2(MEM_BYTE)-1:0] haddr_1 ;
	logic                        hwrite_1;
	logic [                 2:0] hsize_1 ;
	logic [                 1:0] htrans_1;

	///////////////////////////////////////////////////////////////////////
	// SAVE AHB CONTROL SIGNALS
	///////////////////////////////////////////////////////////////////////

	always_ff @(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
			hsel_1   <= '0;
			haddr_1  <= '0;
			hwrite_1 <= '0;
			hsize_1  <= '0;
			htrans_1 <= '0;

			wptr      <= '0;
			rptr      <= '0;
			error_flg <= '0;

		end else if (hready) begin
			hsel_1   <= hsel;
			haddr_1  <= haddr[$high(haddr_1):$low(haddr_1)];
			hwrite_1 <= hwrite;
			hsize_1  <= hsize;
			htrans_1 <= htrans;

			wptr      <= '0;
			rptr      <= '0;
			error_flg <= '0;
		end
	end


	/////////////////////////////////////////////////////////////////
	// WRITE
	/////////////////////////////////////////////////////////////////

	logic [3:0] en_byte;

	// Select enable logic
	always_comb begin
		en_byte = 4'b0000;
		for (int ii=0; ii<4; ii++) begin
			case (hsize_1)
				0 : begin
					if (ii == wptr[1:0]) begin
						en_byte[ii] = 1'b1;
					end
				end
				1 : begin
					if (ii[1] == wptr[1]) begin
						en_byte[ii] = 1'b1;
					end
				end
				2 : begin
					en_byte[ii] = 1'b1;
				end
			endcase
		end
	end

	// Word-addressed memory
	always_ff @(posedge clk) begin
		if ((htrans_1[1])&&(hwrite_1)&&(hsel_1)) begin
			for (int ii=0;ii<4;ii++) begin
				if (en_byte[ii]) begin
					mem[wptr[$high(wptr)-1:2]][8*ii+:8] <= hwdata[8*ii+:8];
				end
			end
			wptr <= wptr+4'b1;
		end
	end

	/////////////////////////////////////////////////////////////////
	// READ
	/////////////////////////////////////////////////////////////////

	always_comb begin
		if ((htrans_1[1])&&(~hwrite_1)&&(hsel_1)) begin
			hrdata = mem[rptr[$high(rptr)-1:2]];
		end
	end

	always_ff @(posedge clk) begin
		if ((htrans_1[1])&&(~hwrite_1)&&(hsel_1)) begin
			rptr <= rptr+1'b1;
		end
	end

	/////////////////////////////////////////////////////////////////
	// FLAGS
	/////////////////////////////////////////////////////////////////

	always_ff @(posedge clk or negedge rst_n) begin

		if ((full_flg&&hwrite_1)||(empty_flg&&~hwrite_1)) begin // Check
			error_flg <= '1;
		end
	end

	assign empty_flg = (wptr==rptr);
	assign full_flg  = ({~wptr[ADDRWIDTH],wptr[ADDRWIDTH-1:0]}==rptr);

	assign hresp = error_flg;
	assign hreadyout = 1'b1;

endmodule
