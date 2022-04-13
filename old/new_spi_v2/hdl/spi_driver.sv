`timescale 1ns / 1ps

import spi_pkg::*;

module spi_driver (
	// Global signals
	output logic                         clk         , // Global clock
	output logic                         rst_n       ,
	// Driver signals
	input  logic                         driver_read ,
	input  logic [           AWIDTH-1:0] spi_slv_addr,
	input  logic [           DWIDTH-1:0] spi_slv_data,
	output logic                         master_en   ,
	output logic [DWIDTH+AWIDTH+3+2-1:0] driver_data ,
	output logic [                  1:0] driver_cfg
);

	int                       outfileptr, infileptr, count;
	logic                     isdone    ;
	logic [DWIDTH+AWIDTH-1:0] spi_word  ;

	always #(TCLK/2) clk=!clk;

	initial begin
		clk = 1'b1;
		rst_n = 1'b0;
		initialize;
		#(2);
		#(5*TCLK);
		rst_n = 1'b1;
		file_to_spi;
		#(5*TCLK);
	end

	task automatic initialize();
		begin
			isdone = 1'b0;
			master_en = 1'b0;
			driver_cfg = 2'b00;
		end
	endtask

	task automatic file_to_spi();
		begin
			infileptr = $fopen(input_filepath,"r");
			$display("Sending instructions to SPI Master...");

			#(TCLK/10) master_en = 1;
			@ (posedge driver_read);
			
			while (!$feof(infileptr)) begin

				count = $fscanf(infileptr,"%b",driver_data);
				$display("INSTRUCTION CTRL: SS = %b ", driver_data[DWIDTH+AWIDTH+3+2-1:DWIDTH+AWIDTH+3],
					"WDATA = %b ", driver_data[DWIDTH+AWIDTH+3-1:AWIDTH+3],
					"ADDR = %b ", driver_data[AWIDTH+3-1:3],
					"SIZE = %b ", driver_data[2:1],
					"WR_EN = %b ", driver_data[0]);

				if (!$feof(infileptr)) begin
					@ (posedge driver_read);
				end

			end

			master_en = 0;
			isdone = 1'b1;

			$fclose(infileptr);
			$stop;
		end
	endtask

endmodule