`timescale 1ns / 1ps

import ahb_fir_pkg::*;

module ahb_master (
	// Global signals
	input  logic                             clk          ,
	input  logic                             rst_n        ,
	// Driver-Master signals
	input  logic [(DWIDTH+AWIDTH+3+2+1)-1:0] amba_instr   ,
	input  logic                             amba_en      ,
	output logic                             amba_wr_flg  ,
	output logic                             instr_rd     ,
	output logic [               DWIDTH-1:0] amba_slv_data,
	output logic [               AWIDTH-1:0] amba_slv_addr,
	// Master-Slave
	input  logic                             hready       ,
	input  logic [               DWIDTH-1:0] hrdata       ,
	output logic [               AWIDTH-1:0] haddr        ,
	output logic                             hwrite       ,
	output logic [                      2:0] hsize        ,
	output logic [                      1:0] htrans       ,
	output logic [               DWIDTH-1:0] hwdata
);

	///////////////////////////////////////////////////////////////////////////
	// Driver-Master
	///////////////////////////////////////////////////////////////////////////

	logic hwrite_1;
	logic valid_transaction;

	assign instr_rd = hready;
	assign amba_slv_data = hrdata;
	assign amba_wr_flg = hready && (~hwrite_1) && valid_transaction;

	always_ff @(posedge clk or negedge rst_n) begin
		if (~rst_n) begin
			hwrite_1      <= '1;  // This hwrite is unrelated to the AHB transfer hwrite, its just to record its value to assert amba_wr_flag
			amba_slv_addr <= '0;
		end else if (hready) begin
			// Save operation, address and data
			if (amba_en) begin
				valid_transaction <= 1'b1;
				hwrite_1      <= hwrite; // Save to check for READ
				amba_slv_addr <= amba_instr[DWIDTH+AWIDTH-1:DWIDTH];
			end else begin
				valid_transaction <= 1'b0;
			end

		end
	end

	///////////////////////////////////////////////////////////////////////////
	// Master-Slave
	///////////////////////////////////////////////////////////////////////////

	// Instruction word decomposition, assign transfer control outputs
	// Note: Cleared outputs for the start of the pipeline, using amba_en
	assign haddr  = amba_en ? amba_instr[DWIDTH+AWIDTH-1:DWIDTH] : '0;
	assign hwrite = amba_en ? amba_instr[DWIDTH+AWIDTH+2+3] : '0;
	assign hsize  = amba_en ? amba_instr[DWIDTH+AWIDTH+2+3-1:DWIDTH+AWIDTH+2] : '0;
	assign htrans = amba_en ? amba_instr[DWIDTH+AWIDTH+2-1:DWIDTH+AWIDTH] : 2'b00;

	// If it is a WRITE transfer, send the data to the slave (repeat on bus according to hsize)
	always_ff @(posedge clk) begin
		if ((hwrite)&&(hready)) begin
			case (hsize)
				0 : begin // byte
					hwdata <= {4{amba_instr[8-1:0]}};
				end
				1 : begin // half word
					hwdata <= {2{amba_instr[16-1:0]}};
				end
				2 : begin // word
					hwdata <= amba_instr[DWIDTH-1:0];
				end
			endcase
		end
	end


endmodule
