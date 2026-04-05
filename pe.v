`timescale 1ns / 1ps
module pe (
    input wire clk,
    input wire rst_n,
    input wire exe,
    input wire shift_val_x,
    input wire [7:0] a_ip,
    input wire [7:0] b_ip,
    output reg [15:0] result
);

// register banks
reg [7:0] A [2:0];//weights 
reg [7:0] B [2:0];//ip vals

integer i;

// load registers
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i = 0; i < 3; i = i + 1) begin
            A[i] <= 0;
            B[i] <= 0;
        end
    end
    else if(shift_val_x) begin 
        A[0] <= A[0]; A[1] <= A[1]; A[2] <= A[2];
        B[0] <= b_ip;B[1] <= B[0]; B[2] <= B[1];
    end
    else begin
        A[0] <= A[0]; A[1] <= A[1]; A[2] <= A[2];
        B[0] <= B[0];B[1] <= B[1]; B[2] <= B[2];
    end
end

// multiply-accumulate
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        result <= 0;
    end else if (exe) begin
        result <= (A[0]*B[0]) + (A[1]*B[1]) + (A[2]*B[2]);
    end
end

endmodule