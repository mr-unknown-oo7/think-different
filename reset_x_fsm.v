`timescale 1ns / 1ps

//w_mem_3x3 w_mem_3x3_inst (
//    .clk(clk),
//    .valid(valid),
//    .rst_n(rst_n),
//    .reset(reset),
//    .updt(updt),
//    .ptr_incr(ptr_incr),
//    .data(data),
//    .output_data_ch_1(output_data_ch_1),
//    .output_data_ch_2(output_data_ch_2),
//    .output_data_ch_3(output_data_ch_3)
//);

//     d_mem_3x3 d_mem_3x3_inst (
//    .clk(clk),
//    .valid(valid),
//    .rst_n(rst_n),
//    .reset(reset),
//    .updt(updt),
//    .ptr_incr(ptr_incr),
//    .y_dim_ip(y_dim_ip),
//    .data(data),
//    .output_data_ch_1(output_data_ch_1),
//    .output_data_ch_2(output_data_ch_2),
//    .output_data_ch_3(output_data_ch_3),
//    .output_data_ch_4(output_data_ch_4),
//    .output_data_ch_5(output_data_ch_5)
//);

//  master_fsm master_fsm_inst (
//    .ctrl(ctrl),
//    .clk(clk),
//    .rst_n(rst_n),
//    .exe_done(exe_done),
//    .mux_ctrl(mux_ctrl),
//    .done(done),
//    .busy(busy),
//    .next(next),
//    .exe_ready(exe_ready),
//    .mem_select(mem_select)
//);
module reset_x_fsm(
input wire clk , rst_n, exe ,
output reg reset ,done 
    );
    
    wire done_temp;
    reg state_reg , next_state;
    localparam IDLE = 1'b0,
               EXE = 1'b1;
    
    //----next_state logic-----------
    always @(*) begin
      if(!rst_n) next_state = IDLE;
      else case(state_reg)
             IDLE : next_state = (exe)?EXE:IDLE;
             EXE : next_state = (done_temp)?IDLE:EXE;
           endcase 
    end 
    //----state_reg updt-----------
    
    always @(posedge clk) state_reg <= next_state;
    //----output logic-----------
    always @(*) begin 
       case(state_reg)
       IDLE: begin  
         reset = 1'b0;
         done = 1'b0;
       end
       EXE: begin 
         reset = 1'b1;
         done = 1'b1;
       end
      endcase
    end 
    
endmodule
