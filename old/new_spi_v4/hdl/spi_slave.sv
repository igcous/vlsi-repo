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
	typedef enum {RX_CTRL, RX_DATA, WAIT, TX} state_type;
	state_type current_state, next_state;

	// ASM Flags
	logic rx_ctrl_flag, rx_data_flag, wait_flag, tx_flag; // current state indicator

	// RX and TX shift register
	logic [DWIDTH+AWIDTH+3-1:0] rx_shift_reg;
	logic [         DWIDTH-1:0] tx_shift_reg;

	// TX, RX and wait amount of bits
	parameter   RX_CTRL_NBITS = AWIDTH+3;
	logic [5:0] rx_ctrl_cnt             ;
	logic       rx_ctrl_done            ;

	logic [5:0] rx_data_cnt ;
	logic       rx_data_done;

	parameter   WAIT_NBITS = 1;
	logic [5:0] wait_cnt      ;
	logic       wait_done     ;

	logic [5:0] tx_cnt ;
	logic       tx_done;

	logic [5:0] data_size;

	// Transfer
	logic [AWIDTH-1:0] addr  ;
	logic [AWIDTH-1:0] addr_1;
	logic [DWIDTH-1:0] data  ;
	logic [       1:0] size  ;
	logic              write ;

	// Control variables registers (opcode)
	logic [1:0] size_1 ;
	logic       write_1;

	// Output
	logic out_enable;

	////////////////////////////////////////////////////////////////////////
	// Memory-specific signal declarations
	////////////////////////////////////////////////////////////////////////

	logic [MEM_WIDTH-1:0] mem    [0:MEM_HEIGHT-1];
	logic [          3:0] en_byte                ;

	////////////////////////////////////////////////////////////////////////
	// Driver-Slave combinational logic
	////////////////////////////////////////////////////////////////////////

	assign mode = driver_cfg;
	assign cpha = mode[0];
	assign cpol = mode[1];

	////////////////////////////////////////////////////////////////////////
	// Master-Slave combinational logic
	////////////////////////////////////////////////////////////////////////

	assign rx_ctrl_done = (rx_ctrl_cnt==RX_CTRL_NBITS);
	assign rx_data_done = (rx_ctrl_flag) ? 1'b0 : (rx_data_cnt==data_size-1);
	assign wait_done    = (wait_cnt==WAIT_NBITS);
	assign tx_done      = (tx_flag) ? 1'b0 :(tx_cnt==data_size); // data_size still not assigned during rx_ctrl phase

	assign write = rx_shift_reg[AWIDTH+2];
	assign size  = rx_shift_reg[AWIDTH+1:AWIDTH];

	always_comb begin
		rx_ctrl_flag = 1'b0;
		rx_data_flag = 1'b0;
		wait_flag    = 1'b0;
		tx_flag      = 1'b0;
		next_state   = current_state;
		case (current_state)
			RX_CTRL : begin
				rx_ctrl_flag = 1'b1;
				if (rx_ctrl_done) begin
					if (write) begin
						next_state = RX_DATA;
					end else begin
						next_state = WAIT;
					end
				end
			end
			RX_DATA : begin
				rx_data_flag = 1'b1;
			end
			WAIT : begin
				wait_flag = 1'b1;
				if (wait_done) begin
					next_state = TX;
				end
			end
			TX : begin
				tx_flag = 1'b1;
			end
		endcase // state
	end

	// // Set data_size according to opcode receiving in control data
	always_comb begin
		case (size_1)
			2'b00 : data_size = 8;
			2'b01 : data_size = 16;
			2'b10 : data_size = 32;
		endcase
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

	// Save control variables
	// For write
	always_ff @(posedge sck) begin
		if (write&&rx_ctrl_done) begin
			size_1 <= size;
		end
	end

	// For read
	always_ff @(posedge sck) begin
		if (~write&&rx_ctrl_done) begin
			addr_1 <= rx_shift_reg[0+:AWIDTH];
			size_1 <= size;
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
			wait_cnt <= '0;
		end else if (wait_flag) begin
			wait_cnt <= wait_cnt + 1'b1;
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

	// Sample
	always_ff @(posedge sck) begin
		if (rx_ctrl_flag||rx_data_flag) begin
			rx_shift_reg <= {rx_shift_reg[$high(rx_shift_reg)-1:0],mosi};
		end
	end

	// Change
	always_ff @(negedge sck) begin
		if (wait_flag) begin
			tx_shift_reg <= mem[addr_1[$high(addr_1):2]];
		end
		if (tx_flag) begin
			tx_shift_reg <= (tx_shift_reg<<1);
		end
	end

	////////////////////////////////////////////////////////////////////////
	// Memory-specific logic
	////////////////////////////////////////////////////////////////////////

	// Data and address
	always_comb begin
		case (size_1)
			0 : begin
				data = {4{rx_shift_reg[0+:8]}};
				addr = rx_shift_reg[8+:AWIDTH];
			end
			1 : begin
				data = {2{rx_shift_reg[0+:16]}};
				addr = rx_shift_reg[16+:AWIDTH];
			end
			2 : begin
				data = rx_shift_reg[0+:32];
				addr = rx_shift_reg[32+:AWIDTH];
			end
		endcase // size
	end

	// Select enable logic
	always_comb begin
		en_byte = 4'b0000;
		for (int ii=0; ii<4; ii++) begin
			case (size_1)
				0 : begin
					if (ii == addr[1:0]) begin
						en_byte[ii] = 1'b1;
					end
				end
				1 : begin
					if (ii[1] == addr[1]) begin
						en_byte[ii] = 1'b1;
					end
				end
				2 : begin
					en_byte[ii] = 1'b1;
				end
			endcase
		end
	end

	// Write memory
	always_ff @(negedge sck) begin
		if (rx_data_flag && rx_data_done) begin
			for (int ii=0;ii<4;ii++) begin
				if (en_byte[ii]) begin
					mem[addr[$high(addr):2]][8*ii+:8] <= data[8*ii+:8];
				end
			end
		end
	end

	// // Load from memory (combinational?)
	// always_comb begin
	// 	if (wait_flag) begin
	// 		tx_shift_reg = mem[addr_1[$high(addr_1):2]];
	// 	end
	// end

	// Load from memory (combinational?)
	always_ff @ (posedge sck) begin
		if (wait_flag) begin
			case (size_1)
				0 : tx_shift_reg[$high(tx_shift_reg)-:8] <= mem[addr_1[$high(addr_1):2]][8*addr_1[1:0]+:8];
				1 : tx_shift_reg[$high(tx_shift_reg)-:16] <= mem[addr_1[$high(addr_1):2]][16*addr_1[1]+:16];
				2 : tx_shift_reg <= mem[addr_1[$high(addr_1):2]];
			endcase // size_1
		end
	end

	////////////////////////////////////////////////////////////////////////
	// SPI output
	////////////////////////////////////////////////////////////////////////

	assign out_enable = tx_flag;
	assign miso       = out_enable ? tx_shift_reg[$high(tx_shift_reg)] : 'z;


endmodule : spi_slave