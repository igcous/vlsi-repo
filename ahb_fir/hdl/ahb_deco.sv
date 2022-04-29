`timescale 1ns / 1ps

import ahb_fir_pkg::*;

module ahb_deco (
	input  logic [      AWIDTH-1:0] haddr  ,
	output logic [      SWIDTH-1:0] sel_slv,
	output logic [S_ADDR_WIDTH-1:0] sel_mux
);

	always_comb begin
		sel_slv = '0;
		sel_mux = '1;
		for (int ii = 0; ii < SWIDTH; ii++) begin
			if (haddr[AWIDTH-1:AWIDTH-S_ADDR_WIDTH] == ii) begin
				sel_slv[ii] = 1'b1;
				sel_mux = ii;
			end
		end
	end

endmodule :  ahb_deco