module gray2bin_sv #(parameter B = 8) ( // Data Width
    input [B-1:0] din,
    output [B-1:0] dout);

    // Internal Logic
    logic [B-1:0] bin;

    // MSB always match.
    assign bin[B-1] = din[B-1];

    generate
        genvar idx;
        for (idx = 0; idx <= B-2; idx++) begin
            assign bin[idx] = bin[idx+1] ^ din[idx];	
        end
    endgenerate

    // Assign Output
    assign dout = bin;
endmodule