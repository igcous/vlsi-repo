`timescale 1ns / 1ps

import spi_pkg::*;

module spi_driver (
	// Global signals
	output logic                         clk              , // Global clock
	output logic                         rst_n            ,
	// Driver signals
	input  logic                         driver_read      ,
	input  logic [           DWIDTH-1:0] spi_slv_read_data,
	output logic                         master_en        ,
	output logic [DWIDTH+AWIDTH+3+2-1:0] driver_data      ,
	output logic [                  1:0] driver_cfg
);

	int                           outfileptr, infileptr, count;
	logic                         is_done      ;
	logic                         was_write;
	logic [DWIDTH+AWIDTH+3+2-1:0] driver_data_1;

	always #(TCLK/2) clk=!clk;

	initial begin
		clk = 1'b1;
		rst_n = 1'b0;
		initialize;
		#(2);
		#(5*TCLK);
		rst_n = 1'b1;
		file_to_spi;
	end

	task automatic initialize();
		begin
			is_done = 1'b0;
			master_en = 1'b0;
			driver_cfg = 2'b00;
		end
	endtask

	task automatic file_to_spi();
		begin
			infileptr = $fopen(input_filepath,"r");
			$display("Sending instructions to SPI Master...");

			#(TCLK/10) master_en = 1;

			while (!$feof(infileptr)) begin

				if (driver_read) begin

					count = $fscanf(infileptr,"%b",driver_data);

					if (was_write) begin

						$display("INSTRUCTION CTRL: SS = %b ", driver_data_1[$high(driver_data_1)-:S_ADDR_WIDTH],
							"WR_EN = %b ", driver_data_1[$high(driver_data_1)-S_ADDR_WIDTH],
							"SIZE = %b ", driver_data_1[$high(driver_data_1)-S_ADDR_WIDTH-1-:2],
							"ADDR = %b ", driver_data_1[DWIDTH+:AWIDTH],
							"WDATA = %b ", driver_data_1[0+:DWIDTH]);
					end

				end

				@ (posedge clk);

			end

			while (!driver_read) begin
				@ (posedge clk);
			end
			// Note: wait for one more driver_read to close

			#(TCLK/10) master_en = 1'b0;
			is_done = 1'b1;
			#(10*TCLK);

			$fclose(infileptr);
			//$fclose(outfileptr);
			$stop;

		end
	endtask

	initial begin
		outfileptr = $fopen(output_filepath,"w");
	end

	always_ff @(posedge clk) begin
		if (driver_read) begin
			driver_data_1 <= driver_data;
		end
	end

	assign is_write  = driver_data[$high(driver_data)-S_ADDR_WIDTH];
	assign was_write = driver_data_1[$high(driver_data_1)-S_ADDR_WIDTH];

	always_ff @(posedge clk) begin
		if ((driver_read)&&(~was_write)&&(master_en)) begin
			//$fwrite(outfileptr,"Data: %b\n", spi_slv_read_data);
			$display("INSTRUCTION CTRL: SS = %b ", driver_data_1[$high(driver_data_1)-:S_ADDR_WIDTH],
				"WR_EN = %b ", driver_data_1[$high(driver_data_1)-S_ADDR_WIDTH],
				"SIZE  = %b ", driver_data_1[$high(driver_data_1)-S_ADDR_WIDTH-1-:2],
				"ADDR  = %b ", driver_data_1[DWIDTH+:AWIDTH],
				"RDATA = %b ", spi_slv_read_data);
		end
	end

endmodule