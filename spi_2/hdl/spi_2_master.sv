`timescale 1ns / 1ps

import spi_2_pkg::*;

module spi_2_master (
	// Driver-Master
	input  logic                         clk              ,
	input  logic                         rst_n            ,
	input  logic                         master_en        ,
	input  logic [DWIDTH+AWIDTH+3+2-1:0] driver_data      ,
	input  logic [                  1:0] driver_cfg       ,
	output                               driver_read      ,
	output logic [           DWIDTH-1:0] spi_slv_read_data,
	// SPI Master-Slave
	output logic                         sck              ,
	input  logic                         miso             ,
	output logic                         mosi             ,
	output logic [          NSLAVES-1:0] ss_n
);

///////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////// SIGNALS DECLARATION /////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////

	////////////////////////////////////////////////////////////////////////
	// Driver-Master
	////////////////////////////////////////////////////////////////////////

	logic [1:0] mode;
	logic       cpol, cpha;

	logic [       1:0] ss_addr;
	logic [       1:0] t_type ;
	logic [       1:0] size   ;
	logic [AWIDTH-1:0] addr   ;
	logic [DWIDTH-1:0] data   ;

	////////////////////////////////////////////////////////////////////////
	// Master-Slave
	////////////////////////////////////////////////////////////////////////

	// State machine
	typedef enum {RESET, LOAD,TX_CTRL, TX_DATA, RX, TX_BURST, RX_BURST} state_type;
	state_type current_state, next_state;

	// State machine flags
	logic reset_flag, load_flag, tx_ctrl_flag, tx_data_flag, rx_flag; // current state indicator
	logic tx_burst_flag, rx_burst_flag; 

	// sck generation
	parameter                       MAX_CLK_CNT  = 4;
	logic [$clog2(MAX_CLK_CNT)-1:0] fast_clk_cnt    ; // fast-clock counter
	logic                           c_pl, s_pl; // change and sample pulses
	logic                           slow_clk, slow_clk_1;

	// TX and RX shift registers
	logic [DWIDTH+AWIDTH+3-1:0] tx_shift_reg;
	logic [         DWIDTH-1:0] rx_shift_reg;

	// TX and RX counters
	parameter   TX_CTRL_NBITS = AWIDTH+3;
	logic [5:0] data_size               ;
	logic [5:0] tx_ctrl_cnt, tx_data_cnt, rx_cnt;
	logic       tx_ctrl_done, tx_data_done, rx_done;

	// Output
	logic out_enable;

///////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////// LOGIC ////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////

	////////////////////////////////////////////////////////////////////////
	// Driver-Master
	////////////////////////////////////////////////////////////////////////

	// Instruction separation (for debug)
	assign ss_addr = driver_data[$high(driver_data)-:S_ADDR_WIDTH];
	assign t_type  = driver_data[$high(driver_data)-S_ADDR_WIDTH-:2];
	assign size    = driver_data[$high(driver_data)-S_ADDR_WIDTH-2-:2];
	assign addr    = driver_data[DWIDTH+:AWIDTH];
	assign data    = driver_data[0+:DWIDTH];

	assign mode = driver_cfg;
	assign cpha = mode[0];
	assign cpol = mode[1];

	// Note: INSTRUCTION FORMAT
	// [T_TYPE (2b) | SIZE (2b) | T_TYPE (2b) | ADDR (32b) | DATA (32b)]
	// - Data is completed via instruction with zeros if its size is less than 32b
	// - The first bit sent is WRITE (MSB)

	assign driver_read       = load_flag;
	assign spi_slv_read_data = rx_shift_reg;

	// Deco, slave select from instruction
	always_comb begin
		ss_n = 4'b1111;
		if (~load_flag) begin
			case (ss_addr)
				2'b00 : ss_n = 4'b1110;
				2'b01 : ss_n = 4'b1101;
				2'b10 : ss_n = 4'b1011;
				2'b11 : ss_n = 4'b0111;
			endcase
		end
	end

	// Data size selection from instruction
	always_comb begin
		case (size)
			0 : data_size = 8;
			1 : data_size = 16;
			2 : data_size = 32;
		endcase
	end

	////////////////////////////////////////////////////////////////////////
	// Master-Slave
	////////////////////////////////////////////////////////////////////////

	// Next state assignment
	always_comb begin
		reset_flag   = 1'b0;
		load_flag    = 1'b0;
		tx_ctrl_flag = 1'b0;
		tx_data_flag = 1'b0;
		rx_flag      = 1'b0;
		tx_burst_flag = 1'b0;
		rx_burst_flag = 1'b0;
		next_state   = current_state;
		case (current_state)
			RESET : begin
				reset_flag = 1'b1;
				next_state = LOAD;
			end
			LOAD : begin
				load_flag  = 1'b1;
				next_state = TX_CTRL;
			end
			TX_CTRL : begin
				tx_ctrl_flag = 1'b1;
				if (tx_ctrl_done) begin
					case (t_type)
						2'b00: next_state = TX_DATA;
						2'b01: next_state = RX;
						2'b10: next_state = TX_BURST;
						2'b11: next_state = RX_BURST;
					endcase // t_type
				end
			end
			TX_DATA : begin
				tx_data_flag = 1'b1;
				if (tx_data_done) begin
					next_state = LOAD;
				end
			end
			RX : begin
				rx_flag = 1'b1;
				if (rx_done) begin
					next_state = LOAD;
				end
			end
			TX_BURST : begin
				tx_burst_flag = 1'b1;
				// Never leaves this state unless reset by driver
			end
			RX_BURST : begin
				rx_burst_flag = 1'b1;
				// Never leaves this state unless reset by driver
			end
		endcase
	end

	// Change and sample pulses
	assign c_pl = ((~slow_clk)&&(slow_clk_1)); // falling edge
	assign s_pl = ((slow_clk)&&(~slow_clk_1)); // rising edge

	// Max counter flags
	assign tx_ctrl_done = (tx_ctrl_cnt==TX_CTRL_NBITS);
	assign tx_data_done = (tx_data_cnt==data_size);
	assign rx_done      = (rx_cnt==data_size);

	// sck generation
	always_ff @(posedge clk) begin
		if (load_flag) begin
			fast_clk_cnt <= '0;
			slow_clk     <= 1'b0;
			slow_clk_1   <= 1'b0;
		end else begin
			fast_clk_cnt <= fast_clk_cnt + 1'b1; // count
			slow_clk_1   <= slow_clk; // for pulse generation, i.e., detect rising or falling edge
			if (fast_clk_cnt==(MAX_CLK_CNT-1)) begin // toggle slow clock on max counter condition
				slow_clk <= ~slow_clk;
			end
		end
	end

	// Next state
	always_ff @(posedge clk or negedge rst_n) begin : proc_
		if (~rst_n) begin
			current_state <= RESET;
		end else if (master_en) begin
			current_state <= next_state;
		end
	end

	// Load shift register
	always_ff @(posedge clk) begin
		if (load_flag) begin
			tx_shift_reg <= driver_data[$high(driver_data)-2:0];
		end
	end

	// Sample RX
	always_ff @(posedge s_pl) begin
		if (rx_flag) begin
			rx_shift_reg <= {rx_shift_reg[$high(rx_shift_reg)-1:0],miso};
		end
	end

	// Change TX
	always_ff @(posedge c_pl) begin
		if (tx_ctrl_flag||tx_data_flag)||(tx_burst_flag) begin
			tx_shift_reg <= (tx_shift_reg<<1);
		end
	end

	// Note: This counters use the change pulses as the number of bits transmitted.
	// Pro: Easier way to get complete pulses in mode 00.
	// Con: There is an additional shift in the TX register, not important because the tx register is loaded in next cycle.

	// Note2: For mode 00, imagine an only transfer (e.g. 8 bits in one direction). Counter has to use change pulse,
	// otherwise last sck pulse is incomplete.

	always_ff @(posedge c_pl or negedge rst_n) begin
		if (~rst_n) begin
			tx_ctrl_cnt <= '0;
		end else if (tx_ctrl_flag) begin
			tx_ctrl_cnt <= tx_ctrl_cnt + 1'b1;
		end else if (tx_ctrl_done) begin
			tx_ctrl_cnt <= '0;
		end
	end
	always_ff @(posedge c_pl or negedge rst_n) begin
		if (~rst_n) begin
			tx_data_cnt <= '0;
		end else if (tx_data_flag) begin
			tx_data_cnt <= tx_data_cnt + 1'b1;
		end else if (tx_data_done) begin
			tx_data_cnt <= '0;
		end
	end
	always_ff @(posedge c_pl or negedge rst_n) begin
		if (~rst_n) begin
			rx_cnt <= '0;
		end else if (rx_flag) begin
			rx_cnt <= rx_cnt + 1'b1;
		end else if (rx_done) begin
			rx_cnt <= '0;
		end
	end

	////////////////////////////////////////////////////////////////////////
	// SPI outputs
	////////////////////////////////////////////////////////////////////////

	assign out_enable = (tx_ctrl_flag||tx_data_flag)||(tx_burst_flag);
	assign mosi       = out_enable ? tx_shift_reg[$high(tx_shift_reg)] : 'z;
	assign sck        = slow_clk;

endmodule // spi_2_master