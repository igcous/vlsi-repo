`timescale 1ns / 1ps

module tb_drop_out_fifo ();

	parameter TCLK   = 10;
	parameter DWIDTH = 8 ;

	logic              clk      ;
	logic              rst_n    ;
	logic [DWIDTH-1:0] wdata    ;
	logic              read_en  ;
	logic              write_en ;
	logic [DWIDTH-1:0] rdata    ;
	logic              empty_flg;
	logic              full_flg ;

	drop_out_fifo #(.DWIDTH(DWIDTH), .MEM_SIZE(4)) u_drop_out_fifo 
		(
		.clk      (clk      ),
		.rst_n    (rst_n    ),
		.read_en  (read_en  ),
		.write_en (write_en ),
		.wdata    (wdata    ),
		.empty_flg(empty_flg),
		.full_flg (full_flg ),
		.rdata    (rdata    )
	);

	initial begin
		clk = 1'b1;
		rst_n = 1'b0;
	end

	always #(TCLK/2) clk = !clk;

	task reset();
		clk = '1;
		rst_n = '0;
		read_en = '0;
		write_en = '0;
		wdata = '0;
		#(TCLK-TCLK/10);
		rst_n = '1;
	endtask : reset

	task write(input int times);
		write_en = '1;
		read_en = '0;
		for (int ii=0; ii<times; ii++) begin
			//wdata = $urandom_range(2**(DWIDTH)-1,0);
			wdata = ii[DWIDTH-1:0];
			#(TCLK);
		end
	endtask : write

	task read(input int times);
		write_en = '0;
		read_en = '1;
		for (int ii=0; ii<times; ii++) begin
			#(TCLK);
		end
	endtask : read

	initial begin
		reset();
		write(6);
		read(6);
		#(TCLK/10);
		$stop;
	end



endmodule // tb_drop_out_fifo