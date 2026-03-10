module bram_simple_dp_sv #(
    parameter int N = 16,
    parameter int B = 16
)(
    input  logic             clk,
    input  logic             ena,
    input  logic             enb,
    input  logic             wea,
    input  logic [N-1:0]     addra,
    input  logic [N-1:0]     addrb,
    input  logic [B-1:0]     dia,
    output logic [B-1:0]     dob
);

logic [B-1:0] RAM [0:(1<<N)-1];

always_ff @(posedge clk) begin
    if (ena && wea)
        RAM[addra] <= dia;
end

always_ff @(posedge clk) begin
    if (enb)
        dob <= RAM[addrb];
end

endmodule