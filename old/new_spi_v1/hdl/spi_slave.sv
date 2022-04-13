`timescale 1ns / 1ps

import spi_pkg::*;

module spi_slave (
	input  logic [1:0] driver_cfg, // not SPI, for mode config testing
	input  logic       sck       ,
	input  logic       mosi      ,
	output logic       miso      ,
	input  logic       ss_n
);

	////////////////////////////////////////////////////////////////////////
	// Driver-Slave signals declaration
	////////////////////////////////////////////////////////////////////////

	logic [1:0] mode;
	logic       cpol, cpha;

	////////////////////////////////////////////////////////////////////////
	// Master-Slave signals declaration
	////////////////////////////////////////////////////////////////////////

	// RX and TX shift register
	logic [DWIDTH+AWIDTH+3-1:0] rx_shift_reg;

	// TX, RX and wait amount of bits
	parameter   RX_NBITS = DWIDTH+AWIDTH+3;
	logic [5:0] rx_cnt                    ;
	logic       rx_done                   ;

	////////////////////////////////////////////////////////////////////////
	// Driver-Slave combinational logic
	////////////////////////////////////////////////////////////////////////

	assign mode = driver_cfg;
	assign cpha = mode[0];
	assign cpol = mode[1];

	////////////////////////////////////////////////////////////////////////
	// Master-Slave combinational logic
	////////////////////////////////////////////////////////////////////////

	assign rx_done = (rx_cnt==RX_NBITS);

	////////////////////////////////////////////////////////////////////////
	// Master-Slave sequential logic
	////////////////////////////////////////////////////////////////////////

	always_ff @(posedge ss_n or posedge sck) begin
		if (ss_n) begin
			rx_cnt <= '0;
		end else begin

			rx_cnt <= rx_cnt + 1'b1;
		end
	end

	// Change
	always_ff @(negedge sck) begin
		if ((~ss_n)&&(~rx_done)) begin
			rx_shift_reg <= (rx_shift_reg>>1);
		end
	end

	// Sample
	always_ff @(posedge sck) begin
		if (~ss_n) begin
			rx_shift_reg[DWIDTH+AWIDTH+3-1] <= mosi;
		end
	end


endmodule : spi_slave