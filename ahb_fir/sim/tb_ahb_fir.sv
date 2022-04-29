`timescale 1ns / 1ps

import ahb_fir_pkg::*;

module tb_ahb_fir ();
	// Global signals
	logic clk  ;
	logic rst_n;
	// Driver-Master signals
	logic                             amba_wr_flg  ;
	logic                             instr_rd     ;
	logic [               DWIDTH-1:0] amba_slv_data;
	logic [               AWIDTH-1:0] amba_slv_addr;
	logic [(DWIDTH+AWIDTH+3+2+1)-1:0] amba_instr   ;
	logic                             amba_en      ;
	// AHB Master-Slave
	logic              hready;
	logic [DWIDTH-1:0] hrdata;
	logic [AWIDTH-1:0] haddr ;
	logic              hwrite;
	logic [       2:0] hsize ;
	logic [       1:0] htrans;
	logic [DWIDTH-1:0] hwdata;
	logic              hresp ;
	// Mux/Deco
	logic [      DWIDTH-1:0] hrdata_slv_n   [0:SWIDTH-1];
	logic                    hreadyout_slv_n[0:SWIDTH-1];
	logic                    hresp_slv_n    [0:SWIDTH-1];
	logic [S_ADDR_WIDTH-1:0] sel_mux                    ;
	logic [      SWIDTH-1:0] sel_slv                    ;
	// Slaves interconnect
	logic [BIT_PREC-1:0] fircoefs[0:TAPS-1]; // mem-FIR
	logic [OUT_SIZE-1:0] out_wave          ; // FIR-FIFO

	generate
		assign hreadyout_slv_n[0] = 1'b1; // Slave 0 = No slave selected
		assign hresp_slv_n[0] = 1'b0;
		for (genvar ii=4;ii<SWIDTH;ii++) begin
			assign hreadyout_slv_n[ii] = 1'b1;
			assign hresp_slv_n[ii]     = 1'b0;
		end
	endgenerate

	ahb_driver u_ahb_driver (
		.clk          (clk          ),
		.rst_n        (rst_n        ),
		.amba_wr_flg  (amba_wr_flg  ),
		.instr_rd     (instr_rd     ),
		.amba_slv_data(amba_slv_data),
		.amba_slv_addr(amba_slv_addr),
		.amba_instr   (amba_instr   ),
		.amba_en      (amba_en      )
	);

	ahb_master u_ahb_master (
		.clk          (clk          ),
		.rst_n        (rst_n        ),
		.amba_wr_flg  (amba_wr_flg  ),
		.instr_rd     (instr_rd     ),
		.amba_slv_data(amba_slv_data),
		.amba_slv_addr(amba_slv_addr),
		.amba_instr   (amba_instr   ),
		.amba_en      (amba_en      ),
		.hready       (hready       ),
		.hrdata       (hrdata       ),
		.haddr        (haddr        ),
		.hwrite       (hwrite       ),
		.hsize        (hsize        ),
		.htrans       (htrans       ),
		.hwdata       (hwdata       )
	);

	ahb_deco u_ahb_deco (
		.haddr  (haddr  ),
		.sel_slv(sel_slv),
		.sel_mux(sel_mux)
	);

	ahb_mux u_ahb_mux (
		.clk            (clk            ),
		.rst_n          (rst_n          ),
		.hrdata_slv_n   (hrdata_slv_n   ),
		.hreadyout_slv_n(hreadyout_slv_n),
		.sel_mux        (sel_mux        ),
		.hrdata         (hrdata         ),
		.hready         (hready         )
	);

	// Slave 1: FIR
	ahb_fir u_ahb_fir (
		.clk      (clk               ),
		.rst_n    (rst_n             ),
		.hready   (hready            ),
		.haddr    (haddr             ),
		.hwrite   (hwrite            ),
		.hsize    (hsize             ),
		.htrans   (htrans            ),
		.hwdata   (hwdata            ),
		.hsel     (sel_slv[1]        ),
		.hrdata   (hrdata_slv_n[1]   ),
		.hreadyout(hreadyout_slv_n[1]),
		.hresp    (hresp_slv_n[1]    ),
		// mem-FIR
		.fircoefs (fircoefs          ),
		// FIR-FIFO
		.out_wave (out_wave          ),
		.write_en (write_en          )
	);

	// Slave 2: FIFO
	ahb_fifo #(.MEM_SIZE(1024), .DWIDTH(32)) u_ahb_fifo (
		.clk      (clk               ),
		.rst_n    (rst_n             ),
		.hready   (hready            ),
		.haddr    (haddr             ),
		.hwrite   (hwrite            ),
		.hsize    (hsize             ),
		.htrans   (htrans            ),
		.hwdata   (hwdata            ),
		.hsel     (sel_slv[2]        ),
		.hrdata   (hrdata_slv_n[2]   ),
		.hreadyout(hreadyout_slv_n[2]),
		.hresp    (hresp_slv_n[2]    ),
		// FIR-FIFO
		.out_wave (out_wave          ),
		.write_en (write_en          )
	);

	// Slave 3: Memory
	ahb_mem #(.MEM_BYTE(1024)) u_ahb_mem (
		.clk      (clk               ),
		.rst_n    (rst_n             ),
		.hready   (hready            ),
		.haddr    (haddr             ),
		.hwrite   (hwrite            ),
		.hsize    (hsize             ),
		.htrans   (htrans            ),
		.hwdata   (hwdata            ),
		.hsel     (sel_slv[3]        ),
		.hrdata   (hrdata_slv_n[3]   ),
		.hreadyout(hreadyout_slv_n[3]),
		.hresp    (hresp_slv_n[3]    ),
		// mem-FIR
		.fircoefs (fircoefs          )
	);

endmodule