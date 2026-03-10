module tb_synchronizer_vect #(parameter N = 2, parameter B = 8) ();

    // common inputs
    logic rstn, clk;
    logic [B-1:0] data_in;

    // outputs
    logic [B-1:0] data_out_vhdl;    // VHDL
    logic [B-1:0] data_out_sv;      // SV
    
    synchronizer_vect vhdl_dut(rstn, clk, data_in, data_out_vhdl);
    synchronizer_vect_sv sv_dut(rstn, clk, data_in, data_out_sv);

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
            data_in <= $urandom();
        end else begin
            data_in <= 0;
        end
    end

    // assert output equivalency on falling edge
    always_ff @(negedge clk) begin
        assert(data_out_vhdl == data_out_sv) else $error("data_out mismatch. vhdl: %d, sv: %d", data_out_vhdl, data_out_sv);
    end
endmodule