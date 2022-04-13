`timescale 1ns / 1ps

import amba_pkg::*;

module amba_driver (
	// Global signals
	output logic                             clk          ,
	output logic                             rst_n        ,
	// Driver-Master signals
	input  logic                             amba_wr_flg  ,
	input  logic                             instr_rd     ,
	input  logic [               DWIDTH-1:0] amba_slv_data,
	input  logic [               AWIDTH-1:0] amba_slv_addr,
	output logic [(DWIDTH+AWIDTH+3+2+1)-1:0] amba_instr   ,
	output logic                             amba_en
);

	int          outfileptr, infileptr, count;
	logic        isdone    ;
	logic [63:0] amba_word ;

// TestBench clocks
	always #(TCLK/2) clk=!clk;

	initial begin
		clk = 1'b1;
		rst_n = 1'b0;
		isdone = 1'b0;
		amba_en = 1'b0;
		#(2);
		#(10*TCLK);
		rst_n = 1'b1;
		file_to_amba;
		#(10*TCLK);
		isdone = 1'b1;
	end

	task automatic file_to_amba();
		begin
			infileptr = $fopen(input_filepath,"r");
			@ (posedge clk);
			$display("Sending instructions to AMBA Master...");
			while (!$feof(infileptr)) begin
				#(TCLK/10) amba_en = 1;
				count = $fscanf(infileptr,"%b",amba_instr);
				$display("INSTRUCTION CTRL: HWRITE = %b, HSIZE = %b, HTRANS = %b",amba_instr[69], amba_instr[68:66], amba_instr[65:64]);
				@ (posedge clk);
				while (!instr_rd) begin // wait for instruction read
					@ (posedge clk);
				end
			end
			#(TCLK/10) amba_en = 0;
			$fclose(infileptr);
		end
	endtask

	initial begin
		outfileptr = $fopen(output_filepath,"w");
	end

	assign amba_word = {amba_slv_addr,amba_slv_data};

	always_ff @(posedge clk) begin
		if (amba_wr_flg) begin
			$fwrite(outfileptr,"Address: %b \tData: %b\n", amba_slv_addr, amba_slv_data);
			$display("Address: %d \tData: %d", amba_slv_addr, amba_slv_data);
		end
		if(isdone) begin
			$fclose(outfileptr);
			$stop;
		end

	end



endmodule