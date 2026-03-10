module fifo_dc_sv #(parameter B = 16, parameter N = 4) (
    input logic wr_rstn, wr_clk, rd_rstn, rd_clk, wr_en,
    input logic [B-1:0] din,
    input logic rd_en,
    output logic [B-1:0] dout,
    output logic full, empty);

    // Number of bits of depth
    localparam N_LOG2 = $clog2(N);

    // Pointers
    logic [N_LOG2-1:0] wptr, wptr_g, wptr_gc, wptr_c, rptr, rptr_g, rptr_gc, rptr_c;

    // Memory Signals
    logic mem_wea;
    logic [B-1:0] mem_dib, mem_doa, mem_dob;

    // Flags
    logic full_i, empty_i;

    // wptr_i: Binary to gray converter
    bin2gray_sv #(.B(N_LOG2)) wptr_i (
        .din(wptr),
        .dout(wptr_g));
    
    // wptr_g_i: Vector synchronizer (only for gray coded)
    synchronizer_vect_sv #(.N(N), .B(N_LOG2)) wptr_g_i (
        .rstn(rd_rstn),
        .clk(rd_clk),
        .data_in(wptr_g),
        .data_out(wptr_gc));

    // wptr_gc_i: Gray to binary converter
    gray2bin_sv #(.B(N_LOG2)) wptr_gc_i (
        .din(wptr_gc),
        .dout(wptr_c));

    // -----

    // rptr_i: Binary to gray converter
    bin2gray_sv #(.B(N_LOG2)) rptr_i (
        .din(rptr),
        .dout(rptr_g));

    // rptr_g_i: Vector synchronizer (only for gray coded)
    synchronizer_vect_sv #(.N(2), .B(N_LOG2)) rptr_g_i (
        .rstn(wr_rstn),
        .clk(wr_clk),
        .data_in(rptr_g),
        .data_out(rptr_gc));

    // rptr_gc_i: Gray to binary converter
    gray2bin_sv #(.B(N_LOG2)) rptr_gc_i (
        .din(rptr_gc),
        .dout(rptr_c));

    // FIFO memory
    bram_dp_behav #(.N(N_LOG2), .B(B)) mem_i (
        .clka(wr_clk),
        .clkb(rd_clk),
        .ena(1),
        .enb(rd_en),
        .wea(mem_wea),
        .web(0),
        .addra(wptr),
        .addrb(rptr),
        .dia(din),
        .dib(mem_dib),
        .doa(mem_doa),
        .dob(mem_dob));
    
    // Memory Connections
    assign mem_wea = (full_i == 0) ? wr_en : 0;
    assign mem_dib = '0;

    // Full and Empty signals
    assign full_i = (wptr == rptr_c - 1) ? 1 : 0;
    assign empty_i = (wptr_c == rptr) ? 1 : 0;

    // wr_clk registers
    always_ff @(posedge wr_clk) begin
        if (wr_rstn == 0) begin
            wptr <= '0;
        end else begin
            // Write
            if ((wr_en == 1) && (full_i == 0)) begin
                // write data
                // increment pointer
                wptr <= wptr + 1;
            end
        end
    end

    // rd_clk registers
    always_ff @(posedge rd_clk) begin
        if (rd_rstn == 0) begin
            rptr <= '0;
        end else begin
            // Read
            if ((rd_en == 1) && (empty_i == 0)) begin
                // read data
                // increment pointer
                rptr <= rptr + 1;
            end
        end
    end

    // Assign outputs
    assign dout = mem_dob;
    assign full = full_i;
    assign empty = empty_i;
endmodule