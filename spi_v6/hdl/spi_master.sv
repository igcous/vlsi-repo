`timescale 1ns / 1ps

import spi_pkg::*;

module spi_master_v2 (
	// Driver-Master
	input  logic                         clk         ,
	input  logic                         rst_n       ,
	input  logic                         master_en   ,
	input  logic [DWIDTH+AWIDTH+3+2-1:0] driver_data ,
	input  logic [                  1:0] driver_cfg  ,
	output                               driver_read ,
	output logic [           AWIDTH-1:0] spi_slv_addr,
	output logic [           DWIDTH-1:0] spi_slv_data,
	// SPI Master-Slave
	output logic                         sck         ,
	input  logic                         miso        ,
	output logic                         mosi        ,
	output logic [                  3:0] ss_n
);

////////////////////////////////////////////////////////////////////////
// Driver-Master signals declaration
////////////////////////////////////////////////////////////////////////

	logic [1:0] ss_addr;
	logic       write  ;
	logic [1:0] size   ;
	logic [1:0] mode   ;
	logic       cpol   ;
	logic       cpha   ;

////////////////////////////////////////////////////////////////////////
// Master-Slave signals declaration
////////////////////////////////////////////////////////////////////////

// State flags
	logic req_flag ;
	logic load_flag;
	logic tx_flag  ;
	logic wait_flag;
	logic rx_flag  ;

// TX and RX shift registers
	logic [DWIDTH+AWIDTH+3-1:0] tx_shift_reg;
	logic [         DWIDTH-1:0] rx_shift_reg;

// TX, wait and RX counters
	logic [5:0] tx_cnt    ;
	logic [5:0] wait_cnt  ;
	logic [5:0] rx_cnt    ;
	logic [5:0] tx_nbits  ;
	logic [5:0] wait_nbits;
	logic [5:0] rx_nbits  ;
	logic [5:0] data_size ;
	logic       tx_done   ;
	logic       wait_done ;
	logic       rx_done   ;

// Posedge and negedge clock-triggered  registers and flags
	logic s_cnt; // sample counter
	logic c_cnt; // change counter

	logic sample_flag;
	logic change_flag;

// State Machine
	typedef enum {RESET, LOAD, TX, WAIT, RX} state_type;
	state_type state;
	state_type next ;

// Input-Output
	logic bit_in    ; // debug
	logic bit_out   ;
	logic out_enable;

////////////////////////////////////////////////////////////////////////
// Driver-Master combinational logic
////////////////////////////////////////////////////////////////////////

	assign write   = driver_data[0];
	//assign write   = 1'b1;
	assign size    = driver_data[2:1];
	assign ss_addr = driver_data[DWIDTH+AWIDTH+3+2-1:DWIDTH+AWIDTH+3];
	assign mode    = driver_cfg;
	assign cpha    = mode[0];
	assign cpol    = mode[1];

	// Deco, slave select from instruction
	always_comb begin
		ss_n = 4'b1111;
		case (ss_addr)
			2'b00 : ss_n = 4'b1110;
			2'b01 : ss_n = 4'b1101;
			2'b10 : ss_n = 4'b1011;
			2'b11 : ss_n = 4'b0111;
		endcase
	end

	assign driver_read = req_flag;

////////////////////////////////////////////////////////////////////////
// Master-Slave combinational logic
////////////////////////////////////////////////////////////////////////


	// SCK generation from counter
	assign sck = s_cnt; // SCK is the sample_cnt
	// Note: when CPHA = 1, the first bit in the data is thrown away (there is a CHANGE before the first SAMPLE,
	// i.e., the loaded register is shifted before outputing any data)
	// TO SOLVE LATER (maybe), potential disaster because the first bit indicates the transfer (write or read)
	//assign change_flag = 1'b1;
	//assign sample_flag = 1'b1;
	assign sample_flag = ((~cpol)&&(s_cnt)&&(~c_cnt))||((cpol)&&(~s_cnt)&&(c_cnt));
	assign change_flag = ((~cpol)&&(~s_cnt)&&(c_cnt))||((cpol)&&(s_cnt)&&(~c_cnt));

	// TX and RX bits according to instruction write and size
	always_comb begin
		case (size)
			2'b00   : data_size = 8;
			2'b01   : data_size = 16;
			2'b10   : data_size = 32;
			//2'b11 : $error("SIZE ASSIGNMENT ERROR (MASTER).");
		endcase
		if (~write) begin
			tx_nbits = AWIDTH+3;
			rx_nbits = data_size;
		end else if (write) begin
			tx_nbits = AWIDTH+3+data_size;
			rx_nbits = '0;
		end
	end
	// assign tx_nbits   = 4;
	// assign rx_nbits   = 4;

	assign wait_nbits = 1;
	// Note: wait_nbits = wait cycles for slave to have data available in read transfer,
	// assumed known for both slave and master

	// TX, wait and RX done flags
	assign tx_done   = (tx_cnt==(tx_nbits));
	assign wait_done = (wait_cnt==(wait_nbits));
	assign rx_done   = (rx_cnt==(rx_nbits));

	// State Machine
	always_comb begin
		req_flag   = 1'b0;
		load_flag  = 1'b0;
		tx_flag    = 1'b0;
		wait_flag  = 1'b0;
		rx_flag    = 1'b0;
		out_enable = 1'b0;
		case (state)
			RESET : begin
				req_flag = 1'b1;
				next = LOAD;
			end
			LOAD : begin
				load_flag = 1'b1;
				next      = TX;
			end
			TX : begin
				tx_flag = 1'b1;
				out_enable = 1'b1;
				if (tx_done) begin
					if (write) begin
						req_flag = 1'b1;
						next = LOAD;
					end else begin
						next = WAIT;
					end
				end			
			end
			WAIT : begin
				wait_flag = 1'b1;
				out_enable = 1'b1;
				if (wait_done) begin
					next = RX;
				end	
			end
			RX : begin
				rx_flag = 1'b1;
				out_enable = 1'b1;
				if (rx_done) begin
					req_flag = 1'b1;
					next = LOAD;
				end
			end
		endcase // state
	end

////////////////////////////////////////////////////////////////////////
// Master-Slave sequential logic
////////////////////////////////////////////////////////////////////////

	// Next state logic
	always_ff @(posedge clk or negedge rst_n) begin
		if (~rst_n) begin
			state <= RESET;
		end else if (master_en) begin
			state <= next;
		end
	end

	// Load register (LOAD state)
	always_ff @(posedge clk) begin
		if (master_en) begin
			if (load_flag) begin
				tx_shift_reg <= driver_data[DWIDTH+AWIDTH+3-1:0];
			end
		end
	end

	// SCK generation
	always_ff @(posedge clk) begin
		if (req_flag) begin // for mode 0 as reference, change_cnt = 1 and sample_cnt = 0
			if (~cpha) begin
				c_cnt <= 1'b1;
				s_cnt <= 1'b0;
			end else begin
				c_cnt <= 1'b0;
				s_cnt <= 1'b1;
			end
		end else begin
			c_cnt <= c_cnt + 1'b1;
			s_cnt <= s_cnt + 1'b1;
		end
	end

	// TX, wait and RX counter operation (count should go up along with sampling)
	always_ff @(posedge s_cnt or posedge c_cnt or posedge load_flag) begin
		if (load_flag) begin
			tx_cnt   <= '0;
			wait_cnt <= '0;
			rx_cnt   <= '0;
		end else if (sample_flag) begin
			if (tx_flag) begin
				tx_cnt <= tx_cnt + 1'b1;
			end
			if (wait_flag) begin
				wait_cnt <= wait_cnt + 1'b1;
			end
			if (rx_flag) begin
				rx_cnt <= rx_cnt + 1'b1;
			end
		end
	end

	// Shift register (TX or RX states) -> For mode 0 (cpol=0, cpha=0), SPI CHANGE on falling edge
	always_ff @(posedge s_cnt or posedge c_cnt) begin

		if (change_flag) begin
			if (tx_flag) begin
				tx_shift_reg <= (tx_shift_reg>>1);
			end
			if (rx_flag) begin
				rx_shift_reg <= (rx_shift_reg<<1);
			end
		end

	end

	// Sample input to registers (TX or RX states) -> For mode 0 (cpol=0, cpha=0), SPI SAMPLE on rising edge
	always_ff @(posedge s_cnt or posedge c_cnt) begin

		if (sample_flag) begin
			if (rx_flag) begin
				rx_shift_reg[$high(rx_shift_reg)] <= miso; // Fixed miso, for reading debug
			end
		end

	end

////////////////////////////////////////////////////////////////////////
// Debug stuff
////////////////////////////////////////////////////////////////////////

	assign bit_in  = rx_shift_reg[$low(rx_shift_reg)];
	assign bit_out = tx_shift_reg[$low(tx_shift_reg)];
	assign mosi    = out_enable ? bit_out : 'z;

endmodule // spi_master_v2