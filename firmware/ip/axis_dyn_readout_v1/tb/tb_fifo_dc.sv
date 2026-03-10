module tb_fifo_dc #(parameter B = 16, parameter N = 4) ();

    // Common Inputs
    logic wr_rstn, wr_clk, rd_rstn, rd_clk, wr_en;
    logic [B-1:0] din;
    logic rd_en;

    // Outputs
    logic [B-1:0] dout_vhdl, dout_sv;
    logic full_vhdl, full_sv, empty_vhdl, empty_sv;

    // VHDL Instantiation
    fifo_dc vhdl_dut    (wr_rstn, wr_clk, rd_rstn, rd_clk, wr_en, din, rd_en, dout_vhdl, full_vhdl, empty_vhdl);

    // Translated System Verilog Instantiation
    fifo_dc_sv sv_dut   (wr_rstn, wr_clk, rd_rstn, rd_clk, wr_en, din, rd_en, dout_sv, full_sv, empty_sv);

    // Pulse Reset
    initial begin
        wr_rstn = 0; rd_rstn = 0;
        #22;
        wr_rstn = 1; rd_rstn = 1;
    end
    
    // Generate Write Clock
    always begin
        wr_clk = 1; #5;
        wr_clk = 0; #5;
    end

    // Generate Read Clock
    always begin
        rd_clk = 1; #7;
        rd_clk = 0; #7;
    end

    // Randomize Inputs
    always_ff @(posedge wr_clk) begin
        if (wr_rstn == 1) begin
            wr_en <= ($urandom_range(100) < 40); // 40% chance of write
            din   <= $urandom();
        end else begin
            wr_en <= 0;
            din   <= '0;
        end
    end

    always_ff @(posedge rd_clk) begin
        if (rd_rstn == 1) begin
            rd_en <= ($urandom_range(100) < 35); // 35% chance of read
        end else begin
            rd_en <= 0;
        end
    end

    // assert output equivalency on falling edge
    always_ff @(negedge wr_clk) begin
        if (wr_rstn == 1) begin
            assert(full_vhdl == full_sv) else $error("Full Flag mismatch. VHDL: %d, SV: %d", full_vhdl, full_sv);
        end
    end
    always @(negedge rd_clk) begin
        if (rd_rstn == 1) begin
            if (empty_vhdl == 0 && empty_sv == 0) begin
                assert(dout_vhdl == dout_sv) else $error("dout mismatch. VHDL: %h, SV: %h", dout_vhdl, dout_sv);
            end
            assert(empty_vhdl == empty_sv) else $error("Empty flag mismatch. VHDL: %b, SV: %b", empty_vhdl, empty_sv);
        end
    end
endmodule