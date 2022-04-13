`timescale 1ns / 1ps

import spi_pkg::*;

module spi_master (
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

	logic [       1:0] mode       ;
	logic [DWIDTH-1:0] data       ;
	logic [AWIDTH-1:0] addr       ;
	logic [       1:0] size       ;
	logic              write      ;
	logic [       1:0] ss_addr    ;

	logic cpol, cpha;

	////////////////////////////////////////////////////////////////////////
	// Master-Slave signals declaration
	////////////////////////////////////////////////////////////////////////

	// ASM
	typedef enum {LOAD,TX_CTRL, TX_DATA} state_type;
	state_type current_state, next_state;

	// ASM Flags
	logic load_flag, tx_ctrl_flag, tx_data_flag; // current state indicator

	// Sck generation logic
	parameter                       MAX_CLK_CNT  = 4;
	logic [$clog2(MAX_CLK_CNT)-1:0] fast_clk_cnt    ; // fast-clock counter
	logic                           c_pl, s_pl; // change and sample pulses
	logic                           slow_clk, slow_clk_1;

	// TX shift register
	logic [DWIDTH+AWIDTH+3-1:0] tx_shift_reg;

	// TX amount of bits
	parameter   TX_CTRL_NBITS = AWIDTH+3;
	logic [5:0] tx_ctrl_cnt             ;
	logic       tx_ctrl_done            ;

	logic [5:0] tx_data_cnt  ;
	logic       tx_data_done ;

	logic [5:0] data_size;

	// Output
	logic out_enable;

	////////////////////////////////////////////////////////////////////////
	// Driver-Master combinational logic
	////////////////////////////////////////////////////////////////////////

	assign mode        = driver_cfg;
	assign data        = driver_data[$high(driver_data)-2-:DWIDTH];
	assign addr        = driver_data[$high(driver_data)-2-DWIDTH-:AWIDTH];
	assign size        = driver_data[2:1];
	assign write       = driver_data[0];
	assign driver_read = (load_flag && master_en);
	assign ss_addr     = driver_data[$high(driver_data)-:1];

	assign cpha = mode[0];
	assign cpol = mode[1];

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
			2'b00 : data_size = 8;
			2'b01 : data_size = 16;
			2'b10 : data_size = 32;
		endcase
	end

	////////////////////////////////////////////////////////////////////////
	// Master-Slave combinational logic
	////////////////////////////////////////////////////////////////////////

	always_comb begin
		load_flag    = 1'b0;
		tx_ctrl_flag = 1'b0;
		tx_data_flag = 1'b0;
		next_state = current_state;
		case (current_state)
			LOAD : begin	// replaces first change flag in some way?
				load_flag = 1'b1;
				next_state      = TX_CTRL;
			end
			TX_CTRL : begin
				tx_ctrl_flag = 1'b1;
				if (tx_ctrl_done) begin
					next_state = TX_DATA;
				end
			end
			TX_DATA : begin
				tx_data_flag = 1'b1;
				if (tx_data_done) begin
					next_state = LOAD;
				end
			end
		endcase
	end

	assign c_pl = ((~slow_clk)&&(slow_clk_1)); // falling edge
	assign s_pl = ((slow_clk)&&(~slow_clk_1)); // rising edge

	assign tx_ctrl_done = (tx_ctrl_cnt==TX_CTRL_NBITS);
	assign tx_data_done = (tx_data_cnt==data_size);

	////////////////////////////////////////////////////////////////////////
	// Driver-Master sequential logic
	////////////////////////////////////////////////////////////////////////

	////////////////////////////////////////////////////////////////////////
	// Master-Slave sequential logic
	////////////////////////////////////////////////////////////////////////

	// Counter for sck and pulses generation
	always_ff @(posedge clk) begin

		if (load_flag) begin
			fast_clk_cnt <= '0;
			slow_clk     <= 1'b0;
			slow_clk_1   <= 1'b0;
			tx_ctrl_cnt  <= '0;
			tx_data_cnt  <= '0;

		end else begin

			// for pulse generation
			slow_clk_1 <= slow_clk;

			// count
			fast_clk_cnt <= fast_clk_cnt + 1'b1;

			// toggle slow clock on max counter condition
			if (fast_clk_cnt==(MAX_CLK_CNT-1)) begin
				slow_clk <= ~slow_clk;
			end
		end
	end

	// Next state
	always_ff @(posedge clk or negedge rst_n) begin : proc_
		if (~rst_n) begin
			current_state <= LOAD;
		end else if (master_en) begin
			current_state <= next_state;
		end
	end

	// Load shift register
	always_ff @(posedge clk) begin
		if (load_flag) begin
			tx_shift_reg <= {write,size,addr,data};
		end
	end

	// Change
	always_ff @(posedge c_pl) begin
		if ((tx_ctrl_flag)||tx_data_flag) begin
			tx_shift_reg <= (tx_shift_reg<<1);
		end
	end

	// Sample
	always_ff @(posedge c_pl) begin
		// Note: This is counting the change pulses as the number of bits transmitted.
		// Pro: Easier way to get complete pulses in mode 00.
		// Con: There is an additional shift in the register, not important because the tx register is loaded in next cycle.
		if (tx_ctrl_flag) begin
			tx_ctrl_cnt <= tx_ctrl_cnt + 1'b1;
		end
		if (tx_data_flag) begin
			tx_data_cnt <= tx_data_cnt + 1'b1;
		end
		// if (rx_flag) begin
		// 	rx_shift_reg[0] <= miso;
		// end
	end

	////////////////////////////////////////////////////////////////////////
	// SPI outputs
	////////////////////////////////////////////////////////////////////////

	assign out_enable = ((tx_ctrl_flag)||(tx_data_flag));
	assign mosi       = (tx_ctrl_flag||tx_data_flag) ? tx_shift_reg[$high(tx_shift_reg)] : 'z;
	assign sck        = slow_clk;


endmodule // spi_master