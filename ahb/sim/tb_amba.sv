`timescale 1ns / 1ps

import amba_pkg::*;

module tb_amba ();
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
	// Master-Slave
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

	generate
		for (genvar ii=4;ii<SWIDTH;ii++) begin
			assign hreadyout_slv_n[ii] = '1;
			assign hresp_slv_n[ii]     = '1;
		end
	endgenerate

	amba_driver u_amba_driver (
		.clk          (clk          ),
		.rst_n        (rst_n        ),
		.amba_wr_flg  (amba_wr_flg  ),
		.instr_rd     (instr_rd     ),
		.amba_slv_data(amba_slv_data),
		.amba_slv_addr(amba_slv_addr),
		.amba_instr   (amba_instr   ),
		.amba_en      (amba_en      )
	);

	amba_master u_amba_master (
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

	amba_slave_mem #(.MEM_BYTE(4096)) u_amba_slave_mem_0 (
		.clk      (clk               ),
		.rst_n    (rst_n             ),
		.hready   (hready            ),
		.haddr    (haddr             ),
		.hwrite   (hwrite            ),
		.hsize    (hsize             ),
		.htrans   (htrans            ),
		.hwdata   (hwdata            ),
		.hsel     (sel_slv[0]        ),
		.hrdata   (hrdata_slv_n[0]   ),
		.hreadyout(hreadyout_slv_n[0]),
		.hresp    (hresp_slv_n[0]    )
	);

	amba_slave_mem #(.MEM_BYTE(4096)) u_amba_slave_mem_1 (
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
		.hresp    (hresp_slv_n[1]    )
	);

	amba_slave_mem #(.MEM_BYTE(4096)) u_amba_slave_mem_2 (
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
		.hresp    (hresp_slv_n[2]    )
	);

	amba_slave_mem #(.MEM_BYTE(4096)) u_amba_slave_mem_3 (
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
		.hresp    (hresp_slv_n[3]    )
	);

	amba_deco u_amba_deco (
		.haddr  (haddr  ),
		.sel_slv(sel_slv),
		.sel_mux(sel_mux)
	);

	amba_mux u_amba_mux (
		.clk            (clk            ),
		.rst_n          (rst_n          ),
		.hrdata_slv_n   (hrdata_slv_n   ),
		.hreadyout_slv_n(hreadyout_slv_n),
		.sel_mux        (sel_mux        ),
		.hrdata         (hrdata         ),
		.hready         (hready         )
	);


endmodule