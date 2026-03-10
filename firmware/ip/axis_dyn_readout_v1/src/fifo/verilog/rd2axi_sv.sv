module rd2axi_sv #(parameter B = 16)
    (   input logic rstn, clk,
        output logic fifo_rd_en,
        input logic [B-1:0] fifo_dout,
        input logic fifo_empty,
        input logic rd_en,
        output logic [B-1:0] dout,
        output logic empty);


    typedef enum logic [2:0] {WAIT_EMPTY_ST, READ_FIRST_ST, READ_ST, READ_LAST_ST} statetype;

    statetype current_state, next_state;

    logic wait_empty_state, read_first_state, read_state, fifo_rd_en_i, empty_i;

    always_ff @(posedge clk) begin
        if (rstn == 0) begin
            current_state <= WAIT_EMPTY_ST;
        end else begin
            current_state <= next_state;
        end
    end

    // Next State Logic
    always_comb begin
        case (current_state)
            WAIT_EMPTY_ST: begin
                if (fifo_empty == 1) begin
                    next_state = WAIT_EMPTY_ST;
                end else begin
                    next_state = READ_FIRST_ST;
                end
            end
            READ_FIRST_ST: begin
                next_state = READ_ST;
            end
            READ_ST: begin
                if (fifo_empty == 0) begin
                    next_state = READ_ST;
                end else begin
                    if (rd_en == 1) begin
                        next_state = WAIT_EMPTY_ST;
                    end else begin
                        next_state = READ_LAST_ST;
                    end
                end
            end
            READ_LAST_ST: begin
                if (rd_en == 0) begin
                    next_state = READ_LAST_ST;
                end else begin
                    next_state = WAIT_EMPTY_ST;
                end
            end
        endcase
    end

    // Output Logic
    always_comb begin
        case (current_state)
            WAIT_EMPTY_ST: begin
                wait_empty_state = 1;
                read_first_state = 0;
                read_state = 0;
                empty_i = 1;
            end
            READ_FIRST_ST: begin
                wait_empty_state = 0;
                read_first_state = 1;
                read_state = 0;
                empty_i = 1;
            end
            READ_ST: begin
                wait_empty_state = 0;
                read_first_state = 0;
                read_state = 1;
                empty_i = 0;
            end
            READ_LAST_ST: begin
                wait_empty_state = 0;
                read_first_state = 0;
                read_state = 0;
                empty_i = 0;
            end
            default: begin
                wait_empty_state = 0;
                read_first_state = 0;
                read_state = 0;
                empty_i = 0;
            end
        endcase
    end

    // FIFO Read Enable Signal
    assign fifo_rd_en_i = read_first_state | (read_state & rd_en);

    // Outputs
    assign fifo_rd_en = fifo_rd_en_i;
    assign dout = (empty_i == 0) ? fifo_dout : 0;
    assign empty = empty_i;
endmodule