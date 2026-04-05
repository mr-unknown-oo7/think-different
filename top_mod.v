`timescale 1ns / 1ps

module top_mod(
input wire [4-1:0] y_dim_ip,         //holds 16-bit address for exe cmd and y dims(4) for update cmd
input wire [8-1:0] in_int8_bus,
input wire ins_valid,                  //input data bus
input wire [4-1:0] ctrl,              //opcode
input wire rst_n,                    //global reset
input wire mem_clk , compute_clk,     //clk of memory , clk of compute core
input wire wr_valid,        //last of write op from main mem, valid from main mem for write 
output wire [16-1:0] out_int32_data,  //output data
output wire [32-1:0] out_addr,        //address for writing to the main mem
output wire r_valid , r_last ,        //valid data for main mem to read , last trasnmissio to main mem
output wire exe_done , wr_ready ,      //marks the end of execution , fifo ready to read next val 
output wire full
    );
    
//wire [32-1:0] opcode = {ctrl,addr_ch};
wire r_en , w_en , valid_in , valid_out , full_in , full_out,r_en_ins;
wire valid_from_fifo , valid_to_fifo , empty_from_fifo , empty_to_fifo;
wire [16-1:0] write_data;
wire op_fifo_full;
reg [4-1:0] ctrl_ip;
reg [4-1:0] y_dim;

always @(posedge mem_clk)begin 
  ctrl_ip <= (ins_valid)?ctrl:ctrl_ip;
  y_dim <= (ins_valid)?y_dim_ip:y_dim;
end

async_fifo #(.DATA_WIDTH(8), .ADDR_WIDTH(20)) IN_FIFO ( //1MB storage
  .wr_clk(mem_clk),
  .rd_clk(compute_clk),
  .rst_n(rst_n),
  .wr_en(valid),
  .wr_data(in_int8_bus),
  .full(full),
  .rd_en(r_en),
  .rd_data(int8_rd_data),
  .empty(empty_from_fifo)
);

comp_core_v1_3x3 u_comp_core_v1_3x3 (
    .clk(compute_clk),
    .rst_n(rst_n),
    .valid_from_fifo(empty_from_fifo),
    .ip_fifo_empty(empty_from_fifo),
    .data(int8_rd_data),
    .ctrl(ctrl_ip),
    .y_dim(y_dim),
    .valid_to_fifo(empty_to_fifo),
    .op_fifo_full(op_fifo_full),
    .op_data_bus(write_data),
    .r_en_ins(r_en_ins),
    .r_en(r_en)
);

async_fifo #(.DATA_WIDTH(16), .ADDR_WIDTH(4)) OUT_FIFO ( //1MB storage 
  .wr_clk(compute_clk),
  .rd_clk(mem_clk),
  .rst_n(rst_n),
  .wr_en(w_en),
  .wr_data(wr_data),
  .full(op_fifo_full),
  .rd_en(r_en),
  .rd_data(rd_data),
  .empty(empty_to_fifo)
);

endmodule
