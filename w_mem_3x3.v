`timescale 1ns / 1ps


module w_mem_3x3(
input wire clk , valid , rst_n , reset,updt,ptr_incr,
input wire [8-1:0] data,
output wire [8-1:0] output_data_ch_1,output_data_ch_2,output_data_ch_3
    );

reg [2-1:0] output_ptr [3-1:0];
reg [8-1:0] mem [9-1:0];
reg [4-1:0] mem_cntr;
reg [2-1:0] ptr_cntr;
integer i;
localparam SKIP_VAL = 3; 

assign output_data_ch_1 = mem[output_ptr[0]];
assign output_data_ch_2 = mem[output_ptr[1]];
assign output_data_ch_3 = mem[output_ptr[2]];


//mem recieve ops
always @(posedge clk , negedge rst_n) begin 
   if(!rst_n)for(i = 0 ; i <9 ; i=i+1)mem[i] <= 8'b0; 
   else if (updt) mem_cntr <= 4'b0;
   else if (valid)begin 
    mem_cntr <= mem_cntr + 4'b0001;
    mem[mem_cntr] <= data;
   end
   else begin 
   mem_cntr <= mem_cntr;
   mem[mem_cntr] <= mem[mem_cntr];
   end
end

//mem trasnmit ops
always @(posedge clk , negedge rst_n) begin 
   if(!rst_n || reset || updt) for(i = 0 ; i < 3; i=i+1)output_ptr[i] <= SKIP_VAL*i;
   else if(ptr_incr) for(i = 0 ; i < 3; i=i+1)output_ptr[i] <= output_ptr[i] + 2'b01;
   else for(i = 0 ; i < 3; i=i+1)output_ptr[i] <= output_ptr[i];
end 

endmodule
