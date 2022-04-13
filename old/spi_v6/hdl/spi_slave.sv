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
// Master-Slave signals declaration
////////////////////////////////////////////////////////////////////////

	// Transfer settings
	logic              write  ;
	logic [       1:0] size   ; // TO DO: where are these read from?
	logic [       1:0] mode   ; // {cpol,cpha}, fixed
	logic              cpol   ;
	logic              cpha   ;
	logic [AWIDTH-1:0] addr   ;
	logic [DWIDTH-1:0] data   ;
	logic              write_1;
	logic [       1:0] size_1 ;

	// State flags
	logic idle_flag   ;
	logic rx_ctrl_flag;
	logic rx_data_flag;
	logic wait_flag   ;
	logic tx_flag     ;

	// TX and RX shift registers
	logic [DWIDTH+AWIDTH+3-1:0] rx_shift_reg;
	logic [         DWIDTH-1:0] tx_shift_reg;

	// TX, wait and RX counters
	logic [5:0] rx_ctrl_cnt  ;
	logic [5:0] rx_data_cnt  ;
	logic [5:0] wait_cnt     ;
	logic [5:0] tx_cnt       ;
	logic [5:0] rx_ctrl_nbits;
	logic [5:0] rx_data_nbits;
	logic [5:0] wait_nbits   ;
	logic [5:0] tx_nbits     ;
	logic [5:0] data_size    ;
	logic       rx_ctrl_done ;
	logic       rx_data_done ;
	logic       wait_done    ;
	logic       tx_done      ;

	// SCK and flags
	logic s_cnt      ; // s_cnt and c_cnt are used to keep the same notation used in the master
	logic c_cnt      ;
	logic sample_flag;
	logic change_flag;

	// State Machine
	typedef enum {IDLE, RX_CONTROL, RX_DATA, WAIT, TX} state_type;
	state_type state;
	state_type next ;

	// Input-Output
	//logic bit_in    ;
	logic bit_out   ;
	logic out_enable;

////////////////////////////////////////////////////////////////////////
// Memory-specific signals declaration
////////////////////////////////////////////////////////////////////////

	logic [MEM_WIDTH-1:0] mem      [0:MEM_HEIGHT-1];
	logic                 write_mem                ; // 1 for write, 0 for read
	logic [          3:0] en_byte                  ;

////////////////////////////////////////////////////////////////////////
// Master-Slave combinational logic
////////////////////////////////////////////////////////////////////////

	// Transfer settings
	assign write = rx_shift_reg[DWIDTH];
	//assign write = 1'b1;
	assign size = rx_shift_reg[DWIDTH+2:DWIDTH+1];
	assign mode = driver_cfg;
	assign cpha = mode[0];
	assign cpol = mode[1];

	always_comb begin
		case ({write_1,size_1})
			3'b000 : addr = rx_shift_reg[$high(rx_shift_reg)-:AWIDTH];
			3'b001 : addr = rx_shift_reg[$high(rx_shift_reg)-:AWIDTH];
			3'b010 : addr = rx_shift_reg[$high(rx_shift_reg)-:AWIDTH];
			3'b100 : begin
				data = rx_shift_reg[$high(rx_shift_reg)-:8];
				addr = rx_shift_reg[$high(rx_shift_reg)-8-:AWIDTH];
			end
			3'b101 : begin
				data = rx_shift_reg[$high(rx_shift_reg)-:16];
				addr = rx_shift_reg[$high(rx_shift_reg)-16-:AWIDTH];
			end
			3'b110 : begin
				data = rx_shift_reg[$high(rx_shift_reg)-:32];
				addr = rx_shift_reg[$high(rx_shift_reg)-32-:AWIDTH];
			end
		endcase
	end

	// SCK generation from counter
	assign s_cnt       = sck;
	assign c_cnt       = ~sck;
	assign sample_flag = ((~cpol)&&(s_cnt)&&(~c_cnt))||((cpol)&&(~s_cnt)&&(c_cnt));
	assign change_flag = ((~cpol)&&(~s_cnt)&&(c_cnt))||((cpol)&&(s_cnt)&&(~c_cnt));

	// TX and RX bits according to instruction write and size
	always_comb begin
		case (size_1)
			2'b00 : data_size = 8;
			2'b01 : data_size = 16;
			2'b10 : data_size = 32;
		endcase
		if (~write_1) begin
			rx_data_nbits = '0;
			tx_nbits      = data_size;
		end else if (write) begin
			rx_data_nbits = data_size;
			tx_nbits      = '0;
		end
	end
	assign rx_ctrl_nbits = AWIDTH+3;
	// assign rx_data_nbits = 4;
	// assign tx_nbits      = 4;
	assign wait_nbits = 1;
	// TO DO: These amount of bits could be set as a design parameter (rx_ctrl_nbits and wait_nbits would be parameters)
	// or through the loaded instruction

	// TX, wait and RX done flags
	assign rx_ctrl_done = (rx_ctrl_cnt==(rx_ctrl_nbits));
	assign rx_data_done = (rx_data_cnt==(rx_data_nbits));
	assign wait_done    = (wait_cnt==(wait_nbits));
	assign tx_done      = (tx_cnt==(tx_nbits));

	// State Machine
	always_comb begin
		idle_flag    = 1'b0;
		rx_ctrl_flag = 1'b0;
		rx_data_flag = 1'b0;
		wait_flag    = 1'b0;
		tx_flag      = 1'b0;
		write_mem    = 1'b0;
		case (state)
			IDLE : begin
				idle_flag = 1'b1;
				next      = RX_CONTROL;
			end
			RX_CONTROL : begin
				rx_ctrl_flag = 1'b1;
				if (rx_ctrl_done) begin
					if (write) begin
						next = RX_DATA;
					end else begin
						next = WAIT;
					end
				end
			end
			RX_DATA : begin
				rx_data_flag = 1'b1;
				if (rx_data_done) begin
					write_mem = 1'b1;
					next      = RX_CONTROL;
				end
			end
			WAIT : begin
				wait_flag = 1'b1;
				if (wait_done) begin
					next = TX;
				end
			end
			TX : begin
				tx_flag = 1'b1;
				if (tx_done) begin
					next = RX_CONTROL;
				end
			end
		endcase // state
	end

////////////////////////////////////////////////////////////////////////
// Master-Slave sequential logic
////////////////////////////////////////////////////////////////////////

	always_ff @(posedge s_cnt or posedge c_cnt or posedge ss_n) begin
		if (ss_n) begin
			state <= RX_CONTROL;
		end else if (sample_flag) begin
			state <= next;
		end
	end

	// TX, wait and RX counter operation (count should go up along with sampling)
	always_ff @(posedge s_cnt or posedge c_cnt or posedge ss_n) begin
		if (ss_n) begin
			rx_ctrl_cnt <= '0;
			rx_data_cnt <= '0;
			wait_cnt    <= '0;
			tx_cnt      <= '0;
		end else begin
			if (sample_flag) begin
				if (rx_ctrl_flag) begin
					rx_ctrl_cnt <= rx_ctrl_cnt + 1'b1;
				end
				if (rx_data_flag) begin
					rx_data_cnt <= rx_data_cnt + 1'b1;
				end
				if (wait_flag) begin
					wait_cnt <= wait_cnt + 1'b1;
				end
				if (tx_flag) begin
					tx_cnt <= tx_cnt + 1'b1;
				end
			end
		end
	end

	// Shift register (TX or RX states) -> For mode 0 (cpol=0, cpha=0), SPI CHANGE on falling edge
	always_ff @(posedge s_cnt or posedge c_cnt) begin

		if (change_flag) begin
			if (tx_flag) begin
				tx_shift_reg <= (tx_shift_reg<<1);
			end
			if (((rx_ctrl_flag)||(rx_data_flag))&&((~rx_ctrl_done)||(~rx_data_done))) begin
				//if ((rx_ctrl_flag)||(rx_data_flag)) begin
				rx_shift_reg <= (rx_shift_reg>>1);
			end
		end

	end

	// Sample input to registers (TX or RX states)
	always_ff @(posedge s_cnt or posedge c_cnt) begin
		if (sample_flag) begin
			//if (((rx_ctrl_flag&&(rx_ctrl_cnt!='0)))||(rx_data_flag)) begin
			if ((rx_ctrl_flag)||(rx_data_flag)) begin
				rx_shift_reg[$high(rx_shift_reg)] <= mosi;
			end
		end

	end

	always_ff @(posedge s_cnt or posedge c_cnt) begin
		if (sample_flag) begin
			if (rx_ctrl_done) begin
				write_1 <= write;
				size_1  <= size;
			end
		end
	end


////////////////////////////////////////////////////////////////////////
// Memory-specific combinational logic
////////////////////////////////////////////////////////////////////////

	// Some memory logic for data selection like in AMBA AHB
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

////////////////////////////////////////////////////////////////////////
// Memory-specific sequential logic
////////////////////////////////////////////////////////////////////////

	always_ff @(posedge s_cnt) begin

		if (write_mem) begin	// Write
			for (int ii=0;ii<4;ii++) begin
				if (en_byte[ii]) begin
					mem[addr[$high(addr):2]][8*ii+:8] <= data[8*ii+:8];
				end
			end
		end else if (~write_mem) begin	// Read and load TX shift register
			tx_shift_reg <= mem[addr[$size(addr)-1:2]];
		end
	end

////////////////////////////////////////////////////////////////////////
// Debug stuff
////////////////////////////////////////////////////////////////////////

	assign bit_in     = rx_shift_reg[$high(rx_shift_reg)];
	assign bit_out    = tx_shift_reg[$high(tx_shift_reg)];
	assign out_enable = tx_flag;
	assign miso       = out_enable ? bit_out : 'z;


endmodule : spi_slave