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

	// ASM
	typedef enum {RX_CTRL, RX_DATA} state_type;
	state_type current_state, next_state;

	// ASM Flags
	logic rx_ctrl_flag, rx_data_flag; // current state indicator

	// RX and TX shift register
	logic [DWIDTH+AWIDTH+3-1:0] rx_shift_reg;

	// TX, RX and wait amount of bits
	parameter   RX_CTRL_NBITS = AWIDTH+3;
	logic [5:0] rx_ctrl_cnt             ;
	logic       rx_ctrl_done            ;

	logic [5:0] rx_data_nbits;
	logic [5:0] rx_data_cnt  ;
	logic       rx_data_done ;

	logic [5:0] data_size;

	logic size_1 ;
	logic write_1; // Not yet used

	logic [AWIDTH-1:0] addr ;
	logic [DWIDTH-1:0] data ;
	logic [       1:0] size ;
	logic              write;

	////////////////////////////////////////////////////////////////////////
	// Memory-specific signal declarations
	////////////////////////////////////////////////////////////////////////

	logic [MEM_WIDTH-1:0] mem[0:MEM_HEIGHT-1];

	////////////////////////////////////////////////////////////////////////
	// Driver-Slave combinational logic
	////////////////////////////////////////////////////////////////////////

	assign mode = driver_cfg;
	assign cpha = mode[0];
	assign cpol = mode[1];

	////////////////////////////////////////////////////////////////////////
	// Master-Slave combinational logic
	////////////////////////////////////////////////////////////////////////

	assign rx_ctrl_done  = (rx_ctrl_cnt==RX_CTRL_NBITS);
	assign rx_data_done  = (rx_data_cnt==rx_data_nbits-1);
	assign rx_data_nbits = DWIDTH;

	assign size  = rx_shift_reg[AWIDTH+3-:2];
	assign write = rx_shift_reg[AWIDTH+3-1];

	always_comb begin
		rx_ctrl_flag = 1'b0;
		rx_data_flag = 1'b0;
		next_state   = current_state;
		case (current_state)
			RX_CTRL : begin
				rx_ctrl_flag = 1'b1;
				if (rx_ctrl_done) begin
					next_state = RX_DATA;
				end
			end
			RX_DATA : begin
				rx_data_flag = 1'b1;
			end
		endcase // state
	end

	////////////////////////////////////////////////////////////////////////
	// Master-Slave sequential logic
	////////////////////////////////////////////////////////////////////////

	always_ff @(posedge ss_n or posedge sck) begin
		if (ss_n) begin
			current_state <= RX_CTRL;
		end else begin
			current_state <= next_state;
		end
	end
	always_ff @(posedge ss_n or posedge sck) begin
		if (ss_n) begin
			rx_ctrl_cnt <= '0;
		end else if (rx_ctrl_flag) begin
			rx_ctrl_cnt <= rx_ctrl_cnt + 1'b1;
		end
	end
	always_ff @(posedge ss_n or posedge sck) begin
		if(ss_n) begin
			rx_data_cnt <= '0;
		end else if (rx_data_flag) begin
			rx_data_cnt <= rx_data_cnt + 1'b1;
		end else if (rx_data_done) begin
			rx_data_cnt <= '0;
		end
	end

	// Sample
	always_ff @(posedge sck) begin
		rx_shift_reg <= {rx_shift_reg[$high(rx_shift_reg)-1:0],mosi};
	end

	////////////////////////////////////////////////////////////////////////
	// Memory-specific logic
	////////////////////////////////////////////////////////////////////////

	assign addr = rx_shift_reg[DWIDTH+:AWIDTH];
	assign data = rx_shift_reg[DWIDTH-1:0];

	always_ff @(negedge sck) begin
		if (rx_data_flag && rx_data_done) begin
			mem[addr[$high(addr):2]] <= data;
		end
	end


endmodule : spi_slave