`timescale 1ns / 1ps

import amba_pkg::*;

module amba_mux (
	input  logic                    clk                         ,
	input  logic                    rst_n                       , // not used?
	input  logic [      DWIDTH-1:0] hrdata_slv_n [0:SWIDTH-1]   ,
	input  logic                    hreadyout_slv_n [0:SWIDTH-1],
	input  logic                    hresp_slv_n [0:SWIDTH-1]    ,
	input  logic [S_ADDR_WIDTH-1:0] sel_mux                     ,
	output logic [      DWIDTH-1:0] hrdata                      ,
	output logic                    hready                      ,
	output logic                    hresp
);

	logic [S_ADDR_WIDTH-1:0] sel_mux_1;

	always_ff @(posedge clk or negedge rst_n) begin
		if (~rst_n) begin
			sel_mux_1 <= '1;
		end else if (hready) begin
			sel_mux_1 <= sel_mux; // Keep the selected output
		end
	end

	always_comb begin
		hrdata = '0;
		hresp  = '0;
		hready = '1;
		for (int ii = 0; ii < SWIDTH; ii++) begin
			if (sel_mux_1 == ii) begin
				hrdata = hrdata_slv_n[ii];
				hresp  = hresp_slv_n[ii];
				hready = hreadyout_slv_n[ii];
			end
		end
	end

endmodule