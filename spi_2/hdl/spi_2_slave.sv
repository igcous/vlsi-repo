`timescale 1ns / 1ps

import spi_2_pkg::*;

module spi_2_slave (
	input  logic [1:0] driver_cfg, // not SPI, for mode config testing
	input  logic       sck       ,
	input  logic       mosi      ,
	output logic       miso      ,
	input  logic       ss_n
);

///////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////// SIGNALS DECLARATION /////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////

	////////////////////////////////////////////////////////////////////////
	// Driver-Slave
	////////////////////////////////////////////////////////////////////////

	logic [1:0] mode;
	logic       cpol, cpha;

	////////////////////////////////////////////////////////////////////////
	// Master-Slave
	////////////////////////////////////////////////////////////////////////

	// ASM
	typedef enum {RX_CTRL, RX_DATA, TX} state_type;
	state_type current_state, next_state;

	// ASM Flags
	logic rx_ctrl_flag, rx_data_flag, tx_flag; // current state indicator

	// RX and TX shift register
	logic [DWIDTH+AWIDTH+3-1:0] rx_shift_reg;
	logic [         DWIDTH-1:0] tx_shift_reg;

	// TX, RX amount of bits
	parameter   RX_CTRL_NBITS = AWIDTH+3;
	logic [5:0] rx_ctrl_cnt             ;
	logic       rx_ctrl_done            ;

	logic [5:0] rx_data_cnt ;
	logic       rx_data_done;

	logic [5:0] tx_cnt ;
	logic       tx_done;

	logic [5:0] data_size;

	// Transfer
	logic [       1:0] size  ;
	logic [AWIDTH-1:0]  addr;
	logic              write ;

	// Control variables registers (opcode)
	logic [1:0] size_1 ;
	logic       write_1;
	logic [AWIDTH-1:0] addr_1;

	// Output
	logic out_enable;

	////////////////////////////////////////////////////////////////////////
	// Memory-specific signal declarations
	////////////////////////////////////////////////////////////////////////

	logic [MEM_WIDTH-1:0] mem    [0:MEM_HEIGHT-1];
	logic [          3:0] en_byte                ;

///////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////// LOGIC ////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////

	////////////////////////////////////////////////////////////////////////
	// Driver-Slave
	////////////////////////////////////////////////////////////////////////

	assign mode = driver_cfg;
	assign cpha = mode[0];
	assign cpol = mode[1];

	////////////////////////////////////////////////////////////////////////
	// Master-Slave
	////////////////////////////////////////////////////////////////////////

	assign rx_ctrl_done = (rx_ctrl_cnt==RX_CTRL_NBITS);
	assign rx_data_done = (rx_ctrl_flag) ? 1'b0 : (rx_data_cnt==data_size-1); // data_size not assigned/known during rx_ctrl phase, set to 0
	assign tx_done      = (rx_ctrl_flag) ? 1'b0 : (tx_cnt==data_size-1);  	// data_size not assigned/known during rx_ctrl phase, set to 0

	assign addr = rx_shift_reg[0+:AWIDTH];
	assign write = rx_shift_reg[AWIDTH+2];
	assign size  = rx_shift_reg[AWIDTH+1:AWIDTH];

	// Next state assignment
	always_comb begin
		rx_ctrl_flag = 1'b0;
		rx_data_flag = 1'b0;
		tx_flag      = 1'b0;
		next_state   = current_state;
		case (current_state)
			RX_CTRL : begin
				rx_ctrl_flag = 1'b1;
				if (rx_ctrl_done) begin
					if (write) begin
						next_state = RX_DATA;
					end else begin
						next_state = TX;
					end
				end
			end
			RX_DATA : begin
				rx_data_flag = 1'b1;
			end
			TX : begin
				tx_flag = 1'b1;
			end
		endcase // state
	end

	// Set data_size according to opcode receiving in control data
	always_comb begin
		case (size_1)
			2'b00 : data_size = 8;
			2'b01 : data_size = 16;
			2'b10 : data_size = 32;
		endcase
	end

	// Next state
	always_ff @(posedge ss_n or posedge sck) begin
		if (ss_n) begin
			current_state <= RX_CTRL;
		end else begin
			current_state <= next_state;
		end
	end

	// Save control variables
	always_ff @(posedge sck) begin
		if (rx_ctrl_done) begin
			write_1 <= write;
			addr_1 <= addr;
			size_1 <= size;
		end
	end

	// Counters
	always_ff @(posedge ss_n or posedge sck) begin
		if (ss_n) begin
			rx_ctrl_cnt <= '0;
		end else if (rx_ctrl_flag) begin
			rx_ctrl_cnt <= rx_ctrl_cnt + 1'b1;
		end
	end
	always_ff @(posedge ss_n or posedge sck) begin
		if (ss_n) begin
			rx_data_cnt <= '0;
		end else if (rx_data_flag) begin
			rx_data_cnt <= rx_data_cnt + 1'b1;
		end else if (rx_data_done) begin
			rx_data_cnt <= '0;
		end
	end
	always_ff @(posedge ss_n or posedge sck) begin
		if (ss_n) begin
			tx_cnt <= '0;
		end else if (tx_flag) begin
			tx_cnt <= tx_cnt + 1'b1;
		end else if (tx_done) begin
			tx_cnt <= '0;
		end
	end

	// Sample RX
	always_ff @(posedge sck) begin
		if (rx_ctrl_flag||rx_data_flag) begin
			if ((~rx_ctrl_done)||(rx_ctrl_done&&write)) begin // remove additional sample
				rx_shift_reg <= {rx_shift_reg[$high(rx_shift_reg)-1:0],mosi};
			end
		end
	end

	// Change TX
	always_ff @(negedge sck) begin
		if (tx_flag&&(~tx_done)) begin
			tx_shift_reg <= (tx_shift_reg<<1);
		end
	end

	////////////////////////////////////////////////////////////////////////
	// Memory-specific
	////////////////////////////////////////////////////////////////////////

	// Write memory, use change flank
	always_ff @(negedge sck) begin
		if (rx_data_flag && rx_data_done) begin
			case (size_1)
				0 : mem[addr_1[$high(addr_1):2]][8*addr_1[1:0]+:8] <= rx_shift_reg[0+:8];
				1 : mem[addr_1[$high(addr_1):2]][16*addr_1[1]+:16] <= rx_shift_reg[0+:16];
				2 : mem[addr_1[$high(addr_1):2]] <= rx_shift_reg;
			endcase // size_1
		end
	end

	// Load from memory (note: combinational)
	always_comb begin
		if ((rx_ctrl_flag && rx_ctrl_done)&&(~write)) begin
			case (size_1)
				0 : tx_shift_reg[$high(tx_shift_reg)-:8] <= mem[addr[$high(addr):2]][8*addr[1:0]+:8];
				1 : tx_shift_reg[$high(tx_shift_reg)-:16] <= mem[addr[$high(addr):2]][16*addr[1]+:16];
				2 : tx_shift_reg <= mem[addr[$high(addr):2]];
			endcase // size_1
		end
	end

	////////////////////////////////////////////////////////////////////////
	// SPI output
	////////////////////////////////////////////////////////////////////////

	assign out_enable = (((~write)&&rx_ctrl_done)||tx_flag); // need to enable miso only for read transfer (~write) when rx_ctrl_done
	assign miso       = out_enable ? tx_shift_reg[$high(tx_shift_reg)] : 'z;


endmodule : spi_2_slave