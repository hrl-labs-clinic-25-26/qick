module synchronizer_vect_sv #(parameter N = 2, parameter B = 8)
    (   input logic rstn, clk,
        input logic [B-1:0] data_in,
        output logic [B-1:0] data_out);

    // Internal register
    (* async_reg = "true" *) logic [B-1:0] data_int_reg [N-1:0];
    
    always_ff @(posedge clk) begin
        if (rstn == 0) begin
            data_int_reg <= '{default: '0};
        end else begin
            data_int_reg[0] <= data_in;
            data_int_reg[N-1:1] <= data_int_reg[N-2:0];
        end
    end

    // assign output
    assign data_out = data_int_reg[N-1];
endmodule