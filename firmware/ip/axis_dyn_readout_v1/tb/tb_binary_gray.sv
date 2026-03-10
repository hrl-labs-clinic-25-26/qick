module tb_binary_gray #(parameter B = 8) ();

    // Common Inputs
    logic clk;
    logic [B-1:0] din;

    // Outputs
    logic [B-1:0] dout_b2g_vhdl, dout_g2b_vhdl;
    logic [B-1:0] dout_b2g_sv, dout_g2b_sv;

    // VHDL Instantiation
    bin2gray dut_b2g_vhdl(din, dout_b2g_vhdl);
    gray2bin dut_g2b_vhdl(din, dout_g2b_vhdl);

    // Translated System Verilog Instantiation
    bin2gray_sv dut_b2g_sv(din, dout_b2g_sv);
    gray2bin_sv dut_g2b_sv(din, dout_g2b_sv);
    
    // Generate Clock
    always begin
        clk = 1; #5;
        clk = 0; #5;
    end

    // Randomize Inputs
    always_ff @(posedge clk) begin
        din = $urandom();
    end

    // assert output equivalency on falling edge
    always_ff @(negedge clk) begin
        assert(dout_b2g_vhdl == dout_b2g_sv) else $error("b2g mismatch. vhdl: %d, sv: %d", dout_b2g_vhdl, dout_b2g_sv);
        assert(dout_g2b_vhdl == dout_g2b_sv) else $error("g2b mismatch. vhdl: %d, sv: %d", dout_g2b_vhdl, dout_g2b_sv);
    end
endmodule