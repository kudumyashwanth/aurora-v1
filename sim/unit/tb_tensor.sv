`timescale 1ns/1ps
module tb_tensor;
  logic clk = 0, rst_n = 0;
  always #5 clk = ~clk;

  logic [31:0] awaddr = 0, wdata = 0, araddr = 0, rdata;
  logic awvalid = 0, wvalid = 0, bvalid, bready = 1;
  logic arvalid = 0, rvalid, rready = 1;
  logic awready, wready, arready;
  logic [3:0] done_irq;

  tensor_cluster_top dut (
    .clk(clk), .rst_n(rst_n),
    .s_axi_awaddr(awaddr), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
    .s_axi_wdata(wdata), .s_axi_wvalid(wvalid), .s_axi_wready(wready),
    .s_axi_bvalid(bvalid), .s_axi_bready(bready),
    .s_axi_araddr(araddr), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
    .s_axi_rdata(rdata), .s_axi_rvalid(rvalid), .s_axi_rready(rready),
    .core_done_irq(done_irq)
  );

  task axi_write(input [31:0] a, input [31:0] d);
    @(negedge clk); awaddr = a; wdata = d; awvalid = 1; wvalid = 1;
    @(negedge clk); awvalid = 0; wvalid = 0;
    wait (bvalid); @(negedge clk);
  endtask

  task axi_read(input [31:0] a, output [31:0] d);
    @(negedge clk); araddr = a; arvalid = 1;
    @(negedge clk); arvalid = 0;
    wait (rvalid); d = rdata; @(negedge clk);
  endtask

  logic [31:0] st;
  initial begin
    repeat (4) @(negedge clk); rst_n = 1;
    repeat (4) @(negedge clk);

    axi_read(32'h04, st);
    $display("status before start = %h", st);

    axi_write(32'h00, 32'h2);   // reset
    axi_write(32'h00, 32'h0);
    axi_write(32'h08, 32'h10000000); // A addr
    axi_write(32'h14, 32'h101010);   // config
    axi_write(32'h00, 32'h1);   // start

    repeat (50) @(negedge clk); // let FSM run, then poll late (like a CPU would)
    axi_read(32'h04, st);
    $display("status after start+50 = %h  (done bit2 = %b)", st, st[2]);
    if (st[2]) $display("PASS: sticky done visible");
    else       $display("FAIL: done bit not set");
    $finish;
  end
endmodule
