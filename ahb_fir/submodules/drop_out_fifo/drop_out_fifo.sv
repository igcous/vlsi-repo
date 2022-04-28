`timescale 1ns / 1ps

module drop_out_fifo #(
	parameter MEM_SIZE = 4,
	parameter DWIDTH   = 8
) (
	input  logic              clk      ,
	input  logic              rst_n    ,
	input  logic              read_en  ,
	input  logic              write_en ,
	input  logic [DWIDTH-1:0] wdata    ,
	output logic              empty_flg,
	output logic              full_flg ,
	output logic [DWIDTH-1:0] rdata
);

	parameter AWIDTH = $clog2(MEM_SIZE);

	logic [DWIDTH-1:0] mem [0:MEM_SIZE-1];
	logic [  AWIDTH:0] wptr              ; // AWIDTH-1+1 : addresses+1, extra bit is used to check for empty or full
	logic [  AWIDTH:0] rptr              ;

	always_ff @(posedge clk or negedge rst_n) begin
		if (~rst_n) begin
			wptr <= '0;
			rptr <= '0;

		end else if (write_en) begin
			if (~full_flg) begin // Normal function
				mem[wptr[AWIDTH-1:0]] <= wdata;
				wptr                  <= wptr+1'b1;
			end else begin // WRITE + FULL handling
				mem[wptr[AWIDTH-1:0]] <= wdata;
				wptr                  <= wptr+1'b1;
				rptr                  <= rptr+1'b1;
			end

		end else if (read_en) begin
			if (~empty_flg) begin // Normal function
				rptr <= rptr+1'b1;
			end else begin // READ + EMPTY handling
				rptr <= rptr+1'b1;
				wptr <= wptr+1'b1;
			end
		end

	end

	always_comb begin
		rdata = mem[rptr[AWIDTH-1:0]];
	end

	assign empty_flg = (wptr==rptr);
	assign full_flg  = ({~wptr[AWIDTH],wptr[AWIDTH-1:0]}==rptr);

endmodule // drop_out_fifo