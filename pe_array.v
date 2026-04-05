`timescale 1ns / 1ps


module pe_array(
input wire exe , clk,shift_x,rst_n,
input wire [8-1:0] w_bus_1,w_bus_2,w_bus_3, 
input wire [8-1:0] x_bus_1,x_bus_2,x_bus_3,x_bus_4,x_bus_5 ,
output wire [16-1:0] op_val_1,op_val_2,op_val_3 
    );

localparam ROWS = 3,
           COLS = 3;

wire [8-1:0] w_bus [3-1:0];
wire [8-1:0] x_bus [5-1:0];
wire [16-1:0] result [9-1:0];
reg [16-1:0] sum [3-1:0];
integer k;

assign w_bus[0] = w_bus_1;
assign w_bus[1] = w_bus_2;
assign w_bus[2] = w_bus_3;
assign op_val_1 = sum[0];
assign op_val_2 = sum[1];
assign op_val_3 = sum[2];

assign x_bus[0] = x_bus_1;
assign x_bus[1] = x_bus_2;
assign x_bus[2] = x_bus_3;
assign x_bus[3] = x_bus_3;
assign x_bus[4] = x_bus_4;

genvar i, j;
generate
  for (i = 0; i < ROWS; i = i + 1) begin : row
    for (j = 0; j < COLS; j = j + 1) begin : col
      pe u_pe (
        .clk(clk),
        .rst_n(rst_n),
        .exe(exe),
        .shift_val_x(shift_x),
        .a_ip(w_bus[i]),
        .b_ip(x_bus[i+j]),
        .result(result[i+3*j])
      );
    end
  end
endgenerate

always @(posedge clk , negedge rst_n) begin
    if (!rst_n)
       for(k = 0; k < 3 ; k = k + 1)sum[k] <= 10'b0;
    else
        for(k = 0; k < 3 ; k = k + 1)sum[k] <= result[3*k]+result[3*k+1]+result[3*k+2];
end

endmodule
