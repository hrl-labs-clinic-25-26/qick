// uses the following files
// sv: synchronizer_n_sv (provided as synchronizer_n.sv)
// vhdl: synchronizer_n (provided as synchronizer_n.vhd)

module tb_synchronizer_n #(parameter N = 2) ();

    // Common Inputs
    logic clk, rstn, data_in;

    // System Verilog Outputs
    logic data_out_sv;

    // VHDL Outputs
    logic data_out_vhdl;

    // System Verilog Module Inst
    sv_synchronizer_n #(.N(N))
    sv_dut( 
        .clk(clk), 
        .rstn(rstn), 
        .data_in(data_in), 
        .data_out(data_out_sv)
    );

    // VHDL Module Inst
    synchronizer_n #(.N(N))
    vhdl_dut( 
        .rstn(rstn), 
        .clk(clk), 
        .data_in(data_in), 
        .data_out(data_out_vhdl)
    );

    // Generate Clock
    always begin
        clk = 1;
        #5;
        clk = 0;
        #5;
    end

    // Pulse Reset
    initial begin
        rstn = 0;
        #22;
        rstn = 1;
    end

    // randomize inputs
    always @(posedge clk) begin
        // rstn active-low
        #($urandom_range(2,28));
        if (rstn) begin
            data_in <= $urandom;
        end else begin
            // reset
            data_in <= 1'b0;
        end
    end

    // assert output equivalency on falling edge
    always @(negedge clk) begin
        if (rstn) begin
            assert(data_out_sv == data_out_vhdl)  else $error("data_out mismatch: sv: %b, vhdl: %b", data_out_sv, data_out_vhdl);
        end
    end
endmodule