`timescale 1ns / 1ps

module comp_core_v1_3x3(
input wire clk ,rst_n,valid_from_fifo,
input wire ip_fifo_empty,
input wire [8-1:0] data , 
input wire [4-1:0] ctrl,
input wire [4-1:0] y_dim,
output wire valid_to_fifo,op_fifo_full,
output wire [16-1:0] op_data_bus,
output reg r_en_ins,
output wire r_en
    );
    
    
wire p_sum_trans_done;
wire exe_ready , exe_done;
wire [8-1:0] w_output [0:3-1];
wire [8-1:0] x_output [0:5-1];
wire [16-1:0] pe_transmission[0:3-1];
wire exe_p_array , exe_psum_trans;
wire shift_x;
//muxed signals from fifo
reg  updt_x , pntr_incr_x ;
reg  updt_w , pntr_incr_w ;
reg [8-1:0] data_x , data_w;
reg valid_from_fifo_x , valid_from_fifo_w;
//mux signal 
wire mux_ctrl;
wire load_x , load_w , done_load_x , done_load_w ;
wire reset_w_mem , reset_d_mem;
wire pntr_incr_x,pntr_incr_y;

always @(*) begin 
   if(mux_ctrl == 1'b0) begin //x in action 
     data_x = data ;
     valid_from_fifo_x = valid_from_fifo;
   end 
   else begin //w in action 
     data_w = data;
     valid_from_fifo_w = valid_from_fifo;
   end
end
w_mem_3x3 w_mem_3x3_inst (
    .clk(clk),
    .valid(valid_from_fifo_w),
    .rst_n(rst_n),
    .reset(reset_w_mem),
    .updt(updt_w),
    .ptr_incr(pntr_incr_x),
    .data(data_w),
    .output_data_ch_1(w_output[0]),
    .output_data_ch_2(w_output[1]),
    .output_data_ch_3(w_output[2])
);

d_mem_3x3 d_mem_3x3_inst (
    .clk(clk),
    .valid(valid_from_fifo_y),
    .rst_n(rst_n),
    .reset(reset_d_mem),
    .updt(updt_x),
    .ptr_incr(pntr_incr_y),
    .y_dim_ip(y_dim),
    .data(data_w),
    .output_data_ch_1(x_output[0]),
    .output_data_ch_2(x_output[1]),
    .output_data_ch_3(x_output[2]),
    .output_data_ch_4(x_output[3]),
    .output_data_ch_5(x_output[4])
);

//master fsm inst 
master_fsm master_fsm_inst (
    .ctrl(ctrl),
    .clk(clk),
    .rst_n(rst_n),
    .exe_done(exe_done),
    .mux_ctrl(mux_ctrl),
    .next(r_en_ins),
    .exe_ready(exe_ready),
    .load_x(load_x),
    .load_w(load_w),
    .done_load_x(done_load_x),
    .done_load_y(done_load_w),
    .reset_w_men(reset_w_mem),
    .reset_d_mem(reset_d_mem),
    .empty_d_mem(ip_fifo_empty),
    .empty_w_mem(ip_fifo_empty),
    .pntr_incr_x(pntr_incr_x),
    .pntr_incr_y(pntr_incr_y),
    .updt_x(updt_x),
    .updt_y(updt_w)
    
);

//pe array 
pe_array pe_array_inst (
    .exe(exe_p_array),
    .clk(clk),
    .shift_x(shift_x),
    .rst_n(rst_n),
    .w_bus_1(w_output[0]),
    .w_bus_2(w_output[1]),
    .w_bus_3(w_output[2]),
    .x_bus_1(x_output[0]),
    .x_bus_2(x_output[1]),
    .x_bus_3(x_output[2]),
    .x_bus_4(x_output[3]),
    .x_bus_5(x_output[4]),
    .op_val_1(pe_transmission[0]),
    .op_val_2(pe_transmission[1]),
    .op_val_3(pe_transmission[2])
);

//pe array fsm inst 
pe_array_fsm inst_pe_array_fsm (
    .clk(clk),
    .rst_n(rst_n),
    .exe(exe_ready),
    .load_x(load_x),
    .load_w(load_w),
    .p_sum_trans_done(p_sum_trans_done),
    .y_dim(y_dim),
    .shift_x(shift_x),
    .exe_p_array(exe_p_array),
    .exe_psum_trans(exe_psum_trans),
    .done_load_x(done_load_x),
    .done_load_w(done_load_w)
);

//psum transmitter 
psum_trasnmitter u_psum_trasnmitter (
    .op_val_1(pe_transmission[0]),
    .op_val_2(pe_transmission[1]),
    .op_val_3(pe_transmission[2]),
    .clk(clk),
    .rst_n(rst_n),
    .exe(exe_p_sum_trans),
    .ready(p_sum_trans_done),
    .full(op_fifo_full),
    .op_data_bus(op_data_bus),
    .done(exe_done),
    .valid(valid_to_fifo)
);
endmodule
