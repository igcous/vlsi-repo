`timescale 1ns / 1ps

import spic_pkg::*;

module spic_slave (
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
	typedef enum {RX_CTRL, RX_SD, TX_SD, RX_BURST, TX_BURST} state_type;
	state_type current_state, next_state;

	// ASM Flags
	logic rx_ctrl_flag ; // current state indicator
	logic rx_sd_flag, tx_sd_flag;
	logic rx_burst_flag, tx_burst_flag;

	// RX and TX shift register
	logic [S_DATA_SIZE-1:0] rx_shift_reg;
	logic [     DWIDTH-1:0] tx_shift_reg;

	// TX, RX amount of bits
	parameter   RX_CTRL_NBITS = AWIDTH+4;
	logic [5:0] rx_ctrl_cnt             ;
	logic [5:0] rx_sd_cnt, tx_sd_cnt;
	logic [5:0] rx_burst_cnt, tx_burst_cnt;

	logic rx_ctrl_done ;
	logic rx_sd_done, tx_sd_done;
	logic rx_burst_done, tx_burst_done;

	logic [5:0] data_size;

	// Transfer
	logic [       1:0] size  ;
	logic [       1:0] t_type;
	logic [AWIDTH-1:0] addr  ;


	// Control variables registers (opcode)
	logic [       1:0] size_1  ;
	logic [       1:0] t_type_1;
	logic [AWIDTH-1:0] addr_1  ;

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

	assign rx_ctrl_done  = (rx_ctrl_cnt==RX_CTRL_NBITS);
	assign rx_sd_done    = (rx_ctrl_flag) ? 1'b0 : (rx_sd_cnt==data_size-1); // data_size not assigned/known during rx_ctrl phase, set to 0
	assign tx_sd_done    = (rx_ctrl_flag) ? 1'b0 : (tx_sd_cnt==data_size-1);
	assign rx_burst_done = (rx_ctrl_flag) ? 1'b0 : (rx_burst_cnt==data_size-1);
	assign tx_burst_done = (rx_ctrl_flag) ? 1'b0 : (tx_burst_cnt==data_size-1);

	assign t_type = rx_shift_reg[AWIDTH+2+:2];
	assign size   = rx_shift_reg[AWIDTH+:2];
	assign addr   = rx_shift_reg[0+:AWIDTH];

	// Next state assignment
	always_comb begin
		rx_ctrl_flag  = 1'b0;
		rx_sd_flag    = 1'b0;
		tx_sd_flag    = 1'b0;
		rx_burst_flag = 1'b0;
		tx_burst_flag = 1'b0;
		next_state    = current_state;
		case (current_state)
			RX_CTRL : begin
				rx_ctrl_flag = 1'b1;
				if (rx_ctrl_done) begin
					case (t_type)
						2'b00 : next_state = TX_SD;
						2'b01 : next_state = RX_SD;
						2'b10 : next_state = TX_BURST;
						2'b11 : next_state = RX_BURST;
					endcase
				end
			end
			RX_SD : begin
				rx_sd_flag = 1'b1;
			end
			TX_SD : begin
				tx_sd_flag = 1'b1;
			end
			RX_BURST : begin
				rx_burst_flag = 1'b1;
			end
			TX_BURST : begin
				tx_burst_flag = 1'b1;
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
			t_type_1 <= t_type;
			addr_1   <= addr;
			size_1   <= size;
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
			rx_sd_cnt <= '0;
		end else if (rx_sd_flag) begin
			rx_sd_cnt <= rx_sd_cnt + 1'b1;
		end else if (rx_sd_done) begin
			rx_sd_cnt <= '0;
		end
	end
	always_ff @(posedge ss_n or posedge sck) begin
		if (ss_n) begin
			tx_sd_cnt <= '0;
		end else if (tx_sd_flag) begin
			tx_sd_cnt <= tx_sd_cnt + 1'b1;
		end else if (tx_sd_done) begin
			tx_sd_cnt <= '0;
		end
	end
	always_ff @(posedge ss_n or posedge sck) begin
		if (ss_n) begin
			rx_burst_cnt <= '0;
		end else if (rx_burst_flag) begin
			rx_burst_cnt <= rx_burst_cnt + 1'b1;
		end else if (rx_burst_done) begin
			rx_burst_cnt <= '0;
		end
	end
	always_ff @(posedge ss_n or posedge sck) begin
		if (ss_n) begin
			tx_burst_cnt <= '0;
		end else if (tx_burst_flag) begin
			tx_burst_cnt <= tx_burst_cnt + 1'b1;
		end else if (tx_burst_done) begin
			tx_burst_cnt <= '0;
		end
	end

	// Sample RX
	always_ff @(posedge sck) begin
		if (rx_ctrl_flag||rx_sd_flag||rx_burst_flag) begin
			if ((~rx_ctrl_done)||(rx_ctrl_done&&t_type[0])) begin // remove additional sample
				rx_shift_reg <= {rx_shift_reg[$high(rx_shift_reg)-1:0],mosi};
			end
		end
	end

	// Change TX
	always_ff @(negedge sck) begin
		if ((tx_sd_flag&&(~tx_sd_done))||tx_burst_flag) begin
			tx_shift_reg <= (tx_shift_reg<<1);
		end
	end

	////////////////////////////////////////////////////////////////////////
	// Memory-specific
	////////////////////////////////////////////////////////////////////////

	// Write memory, use change flank
	always_ff @(negedge sck) begin
		if ((rx_sd_flag && rx_sd_done)||(rx_burst_flag && rx_burst_done)) begin
			case (size_1)
				0 : mem[addr_1[$high(addr_1):2]][8*addr_1[1:0]+:8] <= rx_shift_reg[0+:8];
				1 : mem[addr_1[$high(addr_1):2]][16*addr_1[1]+:16] <= rx_shift_reg[0+:16];
				2 : mem[addr_1[$high(addr_1):2]] <= rx_shift_reg;
			endcase // size_1
		end
	end

	// Load from memory (note: combinational)
	always_comb begin
		if ((rx_ctrl_flag && rx_ctrl_done)&&(~t_type[0])) begin
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

	assign out_enable = (((~t_type[0])&&rx_ctrl_done)||(tx_sd_flag||tx_burst_flag)); // need to enable miso only for read transfer (~write) when rx_ctrl_done
	assign miso       = out_enable ? tx_shift_reg[$high(tx_shift_reg)] : 'z;


endmodule : spic_slave