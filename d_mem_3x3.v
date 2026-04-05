`timescale 1ns / 1ps


module d_mem_3x3(
input wire clk,valid,
input wire rst_n,reset,updt,ptr_incr,
input wire [4-1:0] y_dim_ip ,
input wire [8-1:0] data,
output wire [8-1:0] output_data_ch_1,output_data_ch_2,output_data_ch_3,output_data_ch_4,output_data_ch_5
    );

reg [8-1:0] output_ptr [0:5-1];
reg [8-1:0] mem[0:16*5-1];
reg [8-1:0] mem_cntr;
reg [2-1:0] ptr_cntr;
reg [4-1:0] y_dim;
reg [7-1:0] temp;
integer i;

assign output_data_ch_1 = mem[output_ptr[0]];
assign output_data_ch_2 = mem[output_ptr[1]];
assign output_data_ch_3 = mem[output_ptr[2]];
assign output_data_ch_4 = mem[output_ptr[3]];
assign output_data_ch_5 = mem[output_ptr[4]];


//mem recieve ops
always @(posedge clk , negedge rst_n) begin 
   if(!rst_n)begin 
    for(i = 0 ; i <80 ; i=i+1)mem[i] <= 8'b0;
    y_dim <= 4'b00; 
   end
   else if (updt)begin
    mem_cntr <= 8'b0;
    y_dim <= y_dim_ip;
   end
   else if (valid)begin 
    mem_cntr <= mem_cntr + 8'b0001;
    mem[mem_cntr] <= data;
   end
   else begin 
   mem_cntr <= mem_cntr;
   mem[mem_cntr] <= mem[mem_cntr];
   end
end

//mem trasnmit ops
always @(posedge clk , negedge rst_n) begin 
   if(!rst_n || reset)begin 
    temp = 0;
    for(i=0;i<5;i=i+1) begin
        output_ptr[i] <= temp;
        temp = temp + y_dim;
    end
   end
   else if(ptr_incr) for(i = 0 ; i < 5; i=i+1)output_ptr[i] <= output_ptr[i] + 4'b01;
   else for(i = 0 ; i < 5; i=i+1)output_ptr[i] <= output_ptr[i];
end 

endmodule
