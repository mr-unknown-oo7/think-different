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
module updt_x_fsm(
input wire clk , rst_n , exe, empty,done_load_x,
output wire done ,
output reg ptr_incr,load_x
);
reg [4-1:0] counter;
reg [3-1:0] next_state , state_reg;
wire done_temp,done_exe;
assign done_temp = (counter == 4'b1000 && done_load_x == 1'b1)? 1'b1:1'b0;
assign done = done_temp;
assign done_exe = (counter == 4'b1000)? 1'b1:1'b0;

localparam START_EXE = 3'b000,
           MID_EXE = 3'b001,
           DONE = 3'b010,
           IDLE = 3'b011,
           BUFF = 3'b100;

//next_state logic 
always @(*) begin  
     case(state_reg)
     IDLE: next_state = (exe)?START_EXE:IDLE;
     START_EXE:next_state = (empty)?START_EXE:MID_EXE;
     MID_EXE:next_state = (done_temp)?BUFF:MID_EXE;
     DONE:next_state = IDLE;
     BUFF: next_state = (done)?DONE:BUFF;
     default : next_state = IDLE;
     endcase
end

//state_reg updt
always @(posedge clk , negedge rst_n) state_reg <= (!rst_n)?IDLE:next_state; 

//output logic 
always @(posedge clk , negedge rst_n) begin
     if(!rst_n) begin 
         counter <= 4'b0000;
         ptr_incr <= 1'b0;
//         valid <= 1'b0;
     end
       
     case(state_reg) 
        IDLE: begin
         counter <= 4'b0000;
         ptr_incr <= 1'b0;
//         valid <= 1'b0;
         load_x <= 1'b0;
        end
        
        START_EXE: begin
         counter <= (empty)?4'b0000:4'b0001;
         ptr_incr <= (empty)?1'b0:1'b1;
//         valid <= (empty)?1'b0:1'b1;
         load_x <= 1'b0;
        end
        
        MID_EXE: begin
         counter <= (empty||done_exe)?counter:counter+4'b0001;
         ptr_incr <= (empty||done_exe)?1'b0:1'b1;
//         valid <= (empty||done_exe)?1'b0:1'b1;
         load_x <= 1'b0;
        end
        
        BUFF: begin
            load_x <= 1'b1;
        end 
        DONE: begin
         load_x <= 1'b0;
         counter <= 4'b0000;
         ptr_incr <= 1'b0;
//         valid <= 1'b0;
        end
     endcase 
end

endmodule