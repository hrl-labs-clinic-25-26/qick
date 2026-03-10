module tb_rd2_axi #(parameter B = 16) ();

    // Common Inputs
    logic rstn, clk, fifo_empty, rd_en;
    logic [B-1:0] fifo_dout;

    // Outputs
    logic fifo_rd_en_vhdl, empty_vhdl;
    logic [B-1:0] dout_vhdl;
    logic fifo_rd_en_sv, empty_sv;
    logic [B-1:0] dout_sv;

    // VHDL Instantiation
    rd2axi vhdl_dut (rstn, clk, fifo_rd_en_vhdl, fifo_dout, fifo_empty, rd_en, dout_vhdl, empty_vhdl);

    // Translated System Verilog Instantiation
    rd2axi_sv sv_dut (rstn, clk, fifo_rd_en_sv, fifo_dout, fifo_empty, rd_en, dout_sv, empty_sv);

    // Pulse Reset
    initial begin
        rstn = 0; #22;
        rstn = 1;
    end
    
    // Generate Clock
    always begin
        clk = 1; #5;
        clk = 0; #5;
    end

    // Randomize Inputs
    always_ff @(posedge clk) begin
        if (rstn == 1) begin
            fifo_empty <= $urandom();
            rd_en <= $urandom();
            fifo_dout <= $urandom();
        end else begin
            fifo_empty <= 0;
            rd_en <= 0;
            fifo_dout <= 0;
        end
    end

    // assert output equivalency on falling edge
    always_ff @(negedge clk) begin
        assert(fifo_rd_en_vhdl == fifo_rd_en_sv) else $error("fifo_rd_en mismatch. vhdl: %d, sv: %d", fifo_rd_en_vhdl, fifo_rd_en_sv);
        assert(dout_vhdl == dout_sv) else $error("dout mismatch. vhdl: %d, sv: %d", dout_vhdl, dout_sv);
        assert(empty_vhdl == empty_sv) else $error("empty mismatch. vhdl: %d, sv: %d", empty_vhdl, empty_sv);
    end
endmodule