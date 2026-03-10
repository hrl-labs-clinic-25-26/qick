module bin2gray_sv #(parameter B = 8) ( // Data Width
    input [B-1:0] din,
    output [B-1:0] dout);

    // Internal Logic
    logic [B-1:0] gray;

    // MSB always match.
    assign gray[B-1] = din[B-1];

    generate
        genvar idx;
        for (idx = 0; idx <= B-2; idx++) begin
            assign gray[idx] = din[idx+1] ^ din[idx];	
        end
    endgenerate

    // Assign Output
    assign dout = gray;
endmodule