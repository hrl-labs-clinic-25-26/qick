// ============================================================
// fifo_axi.sv
// ============================================================

module fifo_axi_sv #(
    // Data width.
    parameter int B = 16,

    // FIFO depth.
    parameter int N = 4
)(
    input  logic                 rstn,
    input  logic                 clk,

    // Write I/F
    input  logic                 wr_en,
    input  logic [B-1:0]         din,

    // Read I/F
    input  logic                 rd_en,
    output logic [B-1:0]         dout,

    // Flags
    output logic                 full,
    output logic                 empty
);

    logic                 rd_en_i;
    logic [B-1:0]         dout_i;
    logic                 empty_i;

    fifo_sv #(
        .B (B),
        .N (N)
    ) fifo_i (
        .rstn   (rstn),
        .clk    (clk),

        // Write I/F
        .wr_en  (wr_en),
        .din    (din),

        // Read I/F
        .rd_en  (rd_en_i),
        .dout   (dout_i),

        // Flags
        .full   (full),
        .empty  (empty_i)
    );

    rd2axi_sv #(
        .B (B)
    ) rd2axi_i (
        .rstn         (rstn),
        .clk          (clk),

        // FIFO Read I/F
        .fifo_rd_en   (rd_en_i),
        .fifo_dout    (dout_i),
        .fifo_empty   (empty_i),

        // Read I/F
        .rd_en        (rd_en),
        .dout         (dout),
        .empty        (empty)
    );

endmodule