`timescale 1ns / 1ps

import spi_pkg::*;

module tb_spi ();

	// Global signals
	logic clk  ;
	logic rst_n;

	// Driver-Master
	logic                         driver_read ;
	logic                         master_en   ;
	logic [DWIDTH+AWIDTH+3+2-1:0] driver_data ;
	logic [                  1:0] driver_cfg  ;
	logic [           AWIDTH-1:0] spi_slv_addr;
	logic [           DWIDTH-1:0] spi_slv_data;

	// SPI Master-Slave
	logic       sck       ;
	logic       mosi      ;
	logic       miso      ;
	logic [NSLAVES-1:0] ss_n_slave;

	spi_driver u_spi_driver (
		.clk         (clk         ),
		.rst_n       (rst_n       ),
		.driver_read (driver_read ),
		.master_en   (master_en   ),
		.driver_data (driver_data ),
		.driver_cfg  (driver_cfg  ),
		.spi_slv_addr(spi_slv_addr),
		.spi_slv_data(spi_slv_data)
	);

	spi_master u_spi_master (
		.clk         (clk         ),
		.rst_n       (rst_n       ),
		.master_en   (master_en   ),
		.driver_data (driver_data ),
		.driver_cfg  (driver_cfg  ),
		.driver_read (driver_read ),
		.spi_slv_addr(spi_slv_addr),
		.spi_slv_data(spi_slv_data),
		.sck         (sck         ),
		.mosi        (mosi        ),
		.miso        (miso        ),
		.ss_n        (ss_n_slave  )
	);

	spi_slave u_spi_slave (
		.driver_cfg(driver_cfg   ),
		.sck       (sck          ),
		.mosi      (mosi         ),
		.miso      (miso         ),
		.ss_n      (ss_n_slave[0])
	);

endmodule // tb_spi