module data_writer_sv #(
    parameter int NT = 16, 
    parameter int N = 16, 
    parameter int B = 16
) (
    input logic clk,
    input logic rstn,

    // AXI Stream I/F
    output logic            s_axis_tready,
    input logic [B-1:0]     s_axis_tdata,
    input logic             s_axis_tvalid,

    // Memory I/F
    output logic [NT-1:0]   mem_en,
    output logic            mem_we,
    output logic [N-1:0]    mem_addr,
    output logic [B-1:0]    mem_di,

    // Registers
    input logic [31:0]      START_ADDR_REG,
    input logic             WE_REG 
);

    localparam int NT_LOG2 = $clog2(NT);

    // State machine states
    typedef enum logic [1:0] {INIT_ST, READ_START_ADDR_ST, WAIT_TVALID_ST, RW_TDATA_ST} statetype;
    statetype state;

    // WE_REG_resync
    logic WE_REG_resync;

    // Synchronizer (Use the SV version)
    synchronizer_n_sv #(.N(2)) sync0(
        .clk(clk), 
        .rstn(rstn), 
        .data_in(WE_REG), 
        .data_out(WE_REG_resync)
    );

    // Axis registers
    logic tready_i;
    logic tready_r;
    logic [B-1:0] tdata_r, tdata_rr, tdata_rrr;
    logic tvalid_r, tvalid_rr, tvalid_rrr;

    // Memory Enable
    logic [NT-1:0] mem_en_i;
    logic [NT-1:0] mem_en_r;

    // Memory address space
    logic [NT_LOG2 + N - 1 : 0] mem_addr_full;
    logic [NT_LOG2-1:0] mem_addr_low;
    logic [N-1:0] mem_addr_high;
    logic [N-1:0] mem_addr_high_r;

    // -----------------------------------------------------------------------
    // FIX: Use integer '1' (32-bit) to prevent truncation during shift
    // -----------------------------------------------------------------------
    assign mem_en_i = (1 << mem_addr_low);

    always_ff @(posedge clk) begin 
        if (~rstn) begin
            // Axis registers
            tready_r   <= 0;
            tdata_r    <= 0;
            tdata_rr   <= 0;
            tdata_rrr  <= 0;
            tvalid_r   <= 0;
            tvalid_rr  <= 0;
            tvalid_rrr <= 0;

            // Memory address
            mem_addr_full   <= 0;
            mem_addr_high_r <= 0;
            mem_en_r        <= 0;
        end else begin 
            // Axis registers
            tready_r <= tready_i;
            tdata_r  <= s_axis_tdata;
            tvalid_r <= s_axis_tvalid;

            // Extra registers to account pipe of state machine
            tdata_rr   <= tdata_r;
            tdata_rrr  <= tdata_rr;
            tvalid_rr  <= tvalid_r;
            tvalid_rrr <= tvalid_rr;

            // Memory address
            if (state == READ_START_ADDR_ST) begin 
                // TODO: check which option to keep
                // (current change)
                mem_addr_full <= $unsigned(int'(START_ADDR_REG));
                // (incoming change)
                // mem_addr_full <= $unsigned(START_ADDR_REG[NT_LOG2+N-1:0]);
            end else if (state == RW_TDATA_ST) begin 
                mem_addr_full <= mem_addr_full + 1;
            end

            mem_addr_high_r <= mem_addr_high;
            mem_en_r        <= mem_en_i;
        end
    end

    // Address computation
    assign mem_addr_low  = mem_addr_full[NT_LOG2-1:0];
    assign mem_addr_high = mem_addr_full[NT_LOG2+N-1:NT_LOG2];

    // Finite State Machine
    always_ff @(posedge clk) begin 
        if (~rstn) 
            state <= INIT_ST;
        else 
            case (state)
                INIT_ST: 
                    if (WE_REG_resync) state <= READ_START_ADDR_ST;
                READ_START_ADDR_ST:    state <= WAIT_TVALID_ST;
                WAIT_TVALID_ST: 
                    if (WE_REG_resync) begin 
                        if (~tvalid_r) 
                            state <= WAIT_TVALID_ST;
                        else 
                            state <= RW_TDATA_ST;
                    end else begin
                        state <= INIT_ST; 
                    end
                RW_TDATA_ST: 
                    if (~tvalid_r)
                        state <= WAIT_TVALID_ST;
            endcase
    end

    // Output logic
    always_comb begin 
        tready_i = 0;
        case (state)
            WAIT_TVALID_ST: tready_i = 1;
            RW_TDATA_ST:    tready_i = 1;
            default:        tready_i = 0;
        endcase
    end

    // Assign output
    assign s_axis_tready = tready_r;
    assign mem_en        = mem_en_r;
    assign mem_we        = tvalid_rrr;
    assign mem_addr      = mem_addr_high_r;
    assign mem_di        = tdata_rrr;

endmodule
