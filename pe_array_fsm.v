`timescale 1ns / 1ps

module pe_array_fsm(
input wire clk , rst_n , exe , load_x , load_w, p_sum_trans_done,
input wire [4-1:0] y_dim,
output reg shift_x ,exe_p_array , exe_psum_trans,
output wire done_load_x,done_load_w  
    );
reg [4-1:0] counter;
reg [3-1:0] next_state , state_reg;
//wire done_load_x , done_load_w ;
localparam IDLE = 3'b000,
           SHIFT_X = 3'b001,
           EXE_P_ARRAY = 3'b010,
           EXE_PSUM_TRANS  = 3'b011,
           LOAD_X = 3'b100,
           LOAD_W = 3'b101;
           
//next_state logic
always @(*) begin 
   case(state_reg)
   
   IDLE:begin 
   if(load_x) next_state = LOAD_X;
   else if(load_w) next_state = LOAD_W;
   else if(exe) next_state = EXE_P_ARRAY;
   else next_state = IDLE;
   end
   
   SHIFT_X:next_state = EXE_P_ARRAY;
   
   EXE_P_ARRAY:next_state = EXE_PSUM_TRANS;
   
   EXE_PSUM_TRANS:next_state = (p_sum_trans_done)?IDLE:SHIFT_X;
   
   LOAD_X:next_state = (done_load_x)?IDLE:LOAD_X;
   
   LOAD_W:next_state = (done_load_w)?IDLE:LOAD_W;
   
   default:next_state = IDLE;
   
   endcase 
end 
//state reg updt 
always @(posedge clk , negedge rst_n) begin 
  if(!rst_n) state_reg <= IDLE;
  else state_reg <= next_state; 
end 
//output logic 
//shift_w , shift_x , done ,exe_p_array , exe_psum_trans
//reg [2-1:0] counter;
//reg done_load_x , done_load_y , done_exe;
always @(posedge clk , negedge rst_n) begin 
   if(!rst_n) begin
      shift_x <= 1'b1;
      exe_p_array <= 1'b0;
      exe_psum_trans <= 1'b0;
      counter <= 4'b0000; 
   end 
   else 
   case(state_reg)
     IDLE:begin
        shift_x <= 1'b1;
        exe_p_array <= 1'b0;
        exe_psum_trans <= 1'b0;
        counter <= 4'b0000; 
     end 
     LOAD_X: begin 
        shift_x <= (done_load_x)?1'b0:1'b1;
        exe_p_array <= 1'b0;
        exe_psum_trans <= 1'b0;
        counter <= (done_load_x)?4'b0000:counter + 4'b0001;
     end
     LOAD_W:begin
        shift_x <= 1'b1;
        exe_p_array <= 1'b0;
        exe_psum_trans <= 1'b0;
        counter <= (done_load_w)?4'b0000:counter + 4'b0001;
     end 
     EXE_P_ARRAY:begin
        shift_x <= 1'b0;
        exe_p_array <= 1'b1;
        exe_psum_trans <= 1'b0;
        counter <= 4'b0000; 
     end
     EXE_PSUM_TRANS:begin
        shift_x <= 1'b0;
        exe_p_array <= 1'b0;
        exe_psum_trans <= 1'b1;
        counter <= 4'b0000; 
     end
     SHIFT_X:begin
        shift_x <= 1'b1;
        exe_p_array <= 1'b0;
        exe_psum_trans <= 1'b0;
        counter <= 4'b0000; 
     end
   endcase
end 

assign done_load_x = (state_reg == LOAD_X && counter == 4'b0011);
assign done_load_w = (state_reg == LOAD_W && counter == 4'b0011);
endmodule
