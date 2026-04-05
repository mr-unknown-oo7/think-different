`timescale 1ns / 1ps


module psum_trasnmitter(
input wire [16-1:0] op_val_1,op_val_2,op_val_3,
input wire clk,rst_n,exe,ready,full,
output reg [16-1:0] op_data_bus,
output reg done,valid
    );
localparam IDLE   = 2'b00,
           TRANS_1= 2'b01,
           TRANS_2= 2'b10,
           TRANS_3= 2'b11;
           
reg [2-1:0] next_state,state_reg;

//next_state logic 
always @(*)begin 
   case(next_state)
   IDLE:next_state = (exe)?TRANS_1:IDLE;
   TRANS_1:next_state = (!full)?TRANS_2:TRANS_1;
   TRANS_2:next_state = (!full)?TRANS_3:TRANS_2;
   TRANS_3:next_state = (!full)?IDLE:TRANS_3;
   default : next_state = IDLE; 
   endcase
end 
//state_reg_updt
always @(posedge clk or negedge rst_n) begin
   if(!rst_n) state_reg <= IDLE;
   else state_reg <= next_state;
end 
//output logic               
always @(*) begin 
   case(state_reg) 
   
   IDLE:begin
   done = 1'b0;
   valid = 1'b0;
   op_data_bus = 16'b0;
   end 
   
   TRANS_1:begin
   done = 1'b0;
   valid = (full)?1'b0:1'b1;
   op_data_bus = (full)?16'b0:op_val_1;
   end 
   
   TRANS_2:begin
   done = 1'b0;
   valid = (full)?1'b0:1'b1;
   op_data_bus = (full)?16'b0:op_val_2;
   end 
   
   TRANS_3:begin
   done = (full)?1'b0:1'b1;
   valid = (full)?1'b0:1'b1;
   op_data_bus = (full)?16'b0:op_val_3;
   end 
   
   default: begin
   done = 1'b0;
   valid = 1'b0;
   op_data_bus = 16'b0;
   end 
   
   endcase
end 
endmodule
