// -----------------------------------------------------------------------------
// data_reader.sv  
// VHDL translation for the average buffer block
// -----------------------------------------------------------------------------
module data_reader_sv #(
  // Address width
  parameter int N = 8,
  // Data width
  parameter int B = 16
) (
  // Reset and clock
  input  logic             rstn,
  input  logic             clk,

  // Memory I/F
  output logic             mem_en,
  output logic             mem_we,
  output logic [N-1:0]     mem_addr,
  input  logic [B-1:0]     mem_dout,

  // Data out
  output logic [B-1:0]     dout,
  input  logic             dready,
  output logic             dvalid,
  output logic             dlast,

  // Registers
  input  logic             START_REG,
  input  logic [N-1:0]     ADDR_REG,
  input  logic [N-1:0]     LEN_REG
);

  localparam int NPOW = (1 << N);

  // FSM
  typedef enum logic [2:0] {
    INIT_ST,
    REGS_ST,
    READ_BRAM_ST,
    WRITE_FIFO_ST,
    FIFO_ST,
    END_ST
  } fsm_state_t;

  fsm_state_t current_state, next_state;

  logic init_state; 
  logic regs_state; 
  logic read_state; 
  logic write_state; 
  logic fifo_state;
  logic read_en;

  // Counters fir memory address and samples
  logic [N-1:0] cnt_wr;
  logic [N-1:0] cnt_rd;
  logic [N-1:0] addr_cnt;

  // Length register
  logic [N-1:0] len_r;

  // FIFO signals
  logic             fifo_wr_en;
  logic             fifo_rd_en;
  logic [B-1:0]     fifo_din;
  logic [B-1:0]     fifo_dout;
  logic             fifo_full;
  logic             fifo_empty;

  // FIFO
  fifo_axi_sv #(
    .B(B),
    .N(4)
  ) fifo_i (
    .rstn (rstn),
    .clk  (clk),

    .wr_en(fifo_wr_en),
    .din  (fifo_din),

    .rd_en(fifo_rd_en),
    .dout (fifo_dout),

    .full (fifo_full),
    .empty(fifo_empty)
  );

  // FIFO connections - write
  assign fifo_wr_en = write_state && !fifo_full;
  assign fifo_din   = mem_dout;

  // FIFO connections - read
  assign fifo_rd_en = read_en && !fifo_empty && dready;

  // Sequential logic
  always_ff @(posedge clk) begin
    if (!rstn) begin
      current_state <= INIT_ST;

      cnt_wr   <= '0;
      cnt_rd   <= '0;
      addr_cnt <= '0;
      len_r    <= '0;
    end else begin
      current_state <= next_state;

      // Memory address and data related registers
      if (init_state) begin
        cnt_wr   <= '0;
        addr_cnt <= '0;
        len_r    <= '0;
      end else if (regs_state) begin
        cnt_wr   <= '0;
        addr_cnt <= ADDR_REG;
        len_r    <= LEN_REG;
        cnt_rd   <= (LEN_REG - {{(N-1){1'b0}},1'b1}); // LEN_REG - 1
      end

      if (read_state) begin
        cnt_wr <= cnt_wr + {{(N-1){1'b0}},1'b1};
      end

      if (fifo_rd_en) begin
        cnt_rd <= cnt_rd - {{(N-1){1'b0}},1'b1};
      end

      if (write_state && !fifo_full) begin
        addr_cnt <= addr_cnt + {{(N-1){1'b0}},1'b1};
      end
    end
  end

  // Next state logic
  always_comb begin
    next_state = current_state;

    unique case (current_state)
      INIT_ST: begin
        if (!START_REG) next_state = INIT_ST;
        else            next_state = REGS_ST;
      end

      REGS_ST: begin
        next_state = READ_BRAM_ST;
      end

      READ_BRAM_ST: begin
        next_state = WRITE_FIFO_ST;
      end

      WRITE_FIFO_ST: begin
        if (fifo_full) begin
          next_state = WRITE_FIFO_ST;
        end else if (cnt_wr < len_r) begin
          next_state = READ_BRAM_ST;
        end else begin
          next_state = FIFO_ST;
        end
      end

      FIFO_ST: begin
        if ((cnt_rd == '0) && fifo_rd_en) next_state = END_ST;
        else                              next_state = FIFO_ST;
      end

      END_ST: begin
        if (START_REG) next_state = END_ST;
        else           next_state = INIT_ST;
      end

      default: next_state = INIT_ST;
    endcase
  end

  // Output decode (state -> control signals)
  always_comb begin
    init_state  = 1'b0;
    regs_state  = 1'b0;
    read_state  = 1'b0;
    write_state = 1'b0;
    fifo_state  = 1'b0;
    read_en     = 1'b0;

    unique case (current_state)
      INIT_ST: begin
        init_state = 1'b1;
      end

      REGS_ST: begin
        regs_state = 1'b1;
      end

      READ_BRAM_ST: begin
        read_state = 1'b1;
        read_en    = 1'b1;
      end

      WRITE_FIFO_ST: begin
        write_state = 1'b1;
        read_en     = 1'b1;
      end

      FIFO_ST: begin
        fifo_state = 1'b1;
        read_en    = 1'b1;
      end

      END_ST: begin
         // nothing
      end

      default: begin
         // nothing
      end
    endcase
  end

  // Assign outputs
  assign mem_en   = 1'b1;
  assign mem_we   = 1'b0;
  assign mem_addr = addr_cnt;

  assign dout   = fifo_dout;
  assign dvalid = fifo_rd_en && dready;  
  assign dlast  = (cnt_rd == '0) ? 1'b1 : 1'b0;

endmodule
