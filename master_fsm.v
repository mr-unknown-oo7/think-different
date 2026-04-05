module master_fsm(
input wire [4-1:0] ctrl,                           //opcode
input wire clk,rst_n,exe_done,         //clock , master reset , exe completion signal
input wire empty_from_fifo,
input wire done_load_x , done_load_y,
output reg mux_ctrl,load_x,load_w,     //ctrl signal for mux  , state exe completion signal 
output reg next,exe_ready,          //exe progrss signal , ctrl retrieval signal , ready for exe (compute core),selection b/w x and w mem
output wire reset_w_mem,reset_d_mem,
output wire pntr_incr_x , pntr_incr_d,
output reg updt_x , updt_y
);

localparam IDLE = 4'b0000,
           RESET_X = 4'b0001,
           RESET_Y = 4'b0010, //cmd to updt data mem 
           UPDT_X = 4'b0011,  //cmd to updt weight mem 
           UPDT_Y = 4'b0100,  //cmd to updt data mem 
           EXE = 4'b0101,     //cmd to execute
           RETRIEVE = 4'b0110,//retrieving the next cmd
           PRE_UPDT_X = 4'b0111,
           PRE_UPDT_Y = 4'b1000; 
           

reg [4-1:0] state_reg , next_state;
reg exe_reset_x ,exe_reset_y ,exe_updt_x ,exe_updt_y; 
wire done_reset_x ,done_reset_y ,done_updt_x ,done_updt_y,done_exe; 
reg [2-1:0] weight_cntr;
reg [8-1:0] data_mem_pointer [5-1:0];
wire reset_x,reset_y;

//-----sub fsm instantiations------ 

reset_x_fsm reset_x_fsm_inst (
    .clk(clk),
    .rst_n(rst_n),
    .exe(exe_reset_x),
    .reset(reset_d_mem),
    .done(done_reset_x)
);

reset_y_fsm reset_y_fsm_inst (
    .clk(clk),
    .rst_n(rst_n),
    .exe(exe_reset_y),
    .reset(reset_w_mem),
    .done(done_reset_y)
);

updt_x_fsm updt_x_fsm_inst (
    .clk(clk),
    .rst_n(rst_n),
    .exe(exe_updt_x),
    .empty(empty_d_mem),
    .done(done_updt_x),
    .ptr_incr(pntr_incr_x),
    .load_x(load_x),
    .done_load_x(done_load_x)
);

updt_y_fsm u_updt_y_fsm (
    .clk(clk),
    .rst_n(rst_n),
    .exe(exe_updt_y),
    .empty(empty_from_fifo),
    .y_dim_ip(),
    .done(done_updt_y),
    .ptr_incr(pntr_incr_y),
    .load_y(load_w),
    .done_load_y(done_load_y)
);


//-----next_state-------
always @(*) begin 
   if(!rst_n) begin 
     next_state = IDLE;
   end
   
   else begin    
   case(state_reg)
     IDLE: begin
       next_state = RETRIEVE;
     end
     
     RESET_X: begin
       if(done_reset_x == 1'b1)next_state = RETRIEVE;
       else next_state = RESET_X;  
     end
     
     RESET_Y: begin
       if(done_reset_y == 1'b1)next_state = RETRIEVE;       
       else next_state = RESET_Y;
     end
     
     PRE_UPDT_X:begin
        next_state = UPDT_X; 
     end
     
     PRE_UPDT_Y:begin 
        next_state = UPDT_Y;
     end 
     
     UPDT_X: begin
       if(done_updt_x == 1'b1)next_state = RETRIEVE;
       else next_state = UPDT_X;
     end
     
     UPDT_Y: begin
       if(done_updt_y == 1'b1)next_state = RETRIEVE;
       else next_state = UPDT_Y;
     end   
     
     EXE:begin 
       if(exe_done == 1'b1) next_state = RETRIEVE;
       else next_state = EXE;
     end 
     
     RETRIEVE: begin 
        if(ctrl == 4'b0000) next_state = IDLE;
         else if (ctrl == 4'b0001) next_state = RESET_X;
         else if (ctrl == 4'b0010) next_state = RESET_Y;
         else if (ctrl == 4'b0011) next_state = PRE_UPDT_X;
         else if (ctrl == 4'b0100) next_state = PRE_UPDT_Y;
         else if (ctrl == 4'b0101) next_state = EXE;
         else next_state = IDLE;
     end 
     
     default: next_state = IDLE;
   endcase
   end
end

//-------state_reg_updt------
always @(posedge clk, negedge rst_n) begin 
  state_reg <= next_state;
end

//-------output_logic------
always @(*) begin 
   if(!rst_n)begin 
      mux_ctrl = 1'b0;
      next = 1'b0;
      exe_ready = 1'b0;
      exe_reset_x = 1'b0;
      exe_updt_x = 1'b0;
      exe_reset_y = 1'b0;
      exe_updt_y = 1'b0;
   end 
   else begin   
   case (state_reg)
       IDLE:begin 
          updt_x = 1'b0;
          updt_y = 1'b0;
          mux_ctrl = 1'b0;
          next = 1'b0;
          exe_ready = 1'b0;
          exe_ready = 1'b0;
          exe_reset_x = 1'b0;
          exe_updt_x = 1'b0;
          exe_reset_y = 1'b0;
          exe_updt_y = 1'b0;
       end
       RESET_X:begin 
          updt_x = 1'b0;
          updt_y = 1'b0;
          mux_ctrl = 1'b0;
          next = 1'b0; 
          exe_ready = 1'b0;
          exe_reset_x = 1'b1;
          exe_updt_x = 1'b0;
          exe_reset_y = 1'b0;
          exe_updt_y = 1'b0;
       end
       RESET_Y:begin 
          updt_x = 1'b0;
          updt_y = 1'b0;
          mux_ctrl = 1'b1;
          next = 1'b0;
          exe_ready = 1'b0;
          exe_reset_x = 1'b0;
          exe_updt_x = 1'b0;
          exe_reset_y = 1'b1;
          exe_updt_y = 1'b0;
       end
       PRE_UPDT_X: begin 
          updt_x = 1'b1;
          updt_y = 1'b0;
          mux_ctrl = 1'b0;
          next = 1'b0;
          exe_ready = 1'b0;
          exe_ready = 1'b0;
          exe_reset_x = 1'b0;
          exe_updt_x = 1'b0;
          exe_reset_y = 1'b0;
          exe_updt_y = 1'b0;
       end
       UPDT_X:begin 
          updt_x = 1'b0;
          updt_y = 1'b0;
          mux_ctrl = 1'b0;
          next = 1'b0; 
          exe_ready = 1'b0;
          exe_reset_x = 1'b0;
          exe_updt_x = 1'b1;
          exe_reset_y = 1'b0;
          exe_updt_y = 1'b0;
       end
       PRE_UPDT_Y:begin 
          updt_y = 1'b1;
          updt_x = 1'b0;
          mux_ctrl = 1'b0;
          next = 1'b0;
          exe_ready = 1'b0;
          exe_ready = 1'b0;
          exe_reset_x = 1'b0;
          exe_updt_x = 1'b0;
          exe_reset_y = 1'b0;
          exe_updt_y = 1'b0;
       end 
       UPDT_Y:begin 
          updt_x = 1'b0;
          updt_y = 1'b0;
          mux_ctrl = 1'b1;
          next = 1'b0;
          exe_ready = 1'b0;
          exe_reset_x = 1'b0;
          exe_updt_x = 1'b0;
          exe_reset_y = 1'b0;
          exe_updt_y = 1'b1;
       end
       EXE:begin 
          updt_x = 1'b0;
          updt_y = 1'b0;
          mux_ctrl = 1'b0;
          next = 1'b0;
          exe_ready = 1'b1;
          exe_reset_x = 1'b0;
          exe_updt_x = 1'b0;
          exe_reset_y = 1'b0;
          exe_updt_y = 1'b0;
       end
       RETRIEVE:begin 
          updt_x = 1'b0;
          updt_y = 1'b0;
          mux_ctrl = 1'b0;
          next = 1'b1; 
          exe_ready = 1'b0;
          exe_reset_x = 1'b0;
          exe_updt_x = 1'b0;
          exe_reset_y = 1'b0;
          exe_updt_y = 1'b0;
       end
   endcase
   end
end

//assign done = (state_reg == IDLE)?1'b1:1'b0;

endmodule