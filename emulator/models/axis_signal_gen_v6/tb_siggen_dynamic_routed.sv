`include "axi/typedef.svh"
`include "axi/assign.svh"

`timescale 1ns / 1ns

module tb_siggen_dynamic_routed();

parameter N    = 10;
parameter N_DDS = 4;

// Clocks and Resets
reg s_axi_aclk;
reg s_axi_aresetn;
reg aresetn;
reg aclk;
reg aclk4;

// 1. VIP MASTER INTERFACE
localparam int unsigned AxiAddrWidth = 32;
localparam int unsigned AxiDataWidth = 32;

AXI_LITE #( .AXI_ADDR_WIDTH(32), .AXI_DATA_WIDTH(32) ) vip_master_IF ();
AXI_LITE_DV #( .AXI_ADDR_WIDTH(32), .AXI_DATA_WIDTH(32) ) vip_master_dv_IF (s_axi_aclk);
`AXI_LITE_ASSIGN(vip_master_IF, vip_master_dv_IF)

// 2. INTERCONNECT SIGNALS
localparam NO_MST_PORTS = 1;

logic [NO_MST_PORTS-1:0][AxiAddrWidth-1:0] m_axi_awaddr;
logic [NO_MST_PORTS-1:0][2:0]                m_axi_awprot;
logic [NO_MST_PORTS-1:0]                     m_axi_awvalid;
logic [NO_MST_PORTS-1:0]                     m_axi_awready;
logic [NO_MST_PORTS-1:0][AxiDataWidth-1:0] m_axi_wdata;
logic [NO_MST_PORTS-1:0][AxiDataWidth/8-1:0] m_axi_wstrb;
logic [NO_MST_PORTS-1:0]                     m_axi_wvalid;
logic [NO_MST_PORTS-1:0]                     m_axi_wready;
logic [NO_MST_PORTS-1:0][1:0]                m_axi_bresp;
logic [NO_MST_PORTS-1:0]                     m_axi_bvalid;
logic [NO_MST_PORTS-1:0]                     m_axi_bready;
logic [NO_MST_PORTS-1:0][AxiAddrWidth-1:0] m_axi_araddr;
logic [NO_MST_PORTS-1:0][2:0]                m_axi_arprot;
logic [NO_MST_PORTS-1:0]                     m_axi_arvalid;
logic [NO_MST_PORTS-1:0]                     m_axi_arready;
logic [NO_MST_PORTS-1:0][AxiDataWidth-1:0] m_axi_rdata;
logic [NO_MST_PORTS-1:0][1:0]                m_axi_rresp;
logic [NO_MST_PORTS-1:0]                     m_axi_rvalid;
logic [NO_MST_PORTS-1:0]                     m_axi_rready;

// 3. INTERCONNECT WRAPPER
axi_lite_interconnect_wrapper #(
    .NO_SLV_PORTS(1),
    .NO_MST_PORTS(NO_MST_PORTS),
    .AXI_ADDR_WIDTH(AxiAddrWidth),
    .AXI_DATA_WIDTH(AxiDataWidth),
    .ADDR_RANGES('{0: 64'h40000000_40010000, default: 0}) 
) i_interconnect (
    .clk_i          ( s_axi_aclk              ),
    .rst_ni         ( s_axi_aresetn           ),
    
    // Slave Port (Input from VIP)
    .s_axi_awaddr   ( vip_master_IF.aw_addr   ),
    .s_axi_awprot   ( vip_master_IF.aw_prot   ),
    .s_axi_awvalid  ( vip_master_IF.aw_valid  ),
    .s_axi_awready  ( vip_master_IF.aw_ready  ),
    .s_axi_wdata    ( vip_master_IF.w_data    ),
    .s_axi_wstrb    ( vip_master_IF.w_strb    ),
    .s_axi_wvalid   ( vip_master_IF.w_valid   ),
    .s_axi_wready   ( vip_master_IF.w_ready   ),
    .s_axi_bresp    ( vip_master_IF.b_resp    ),
    .s_axi_bvalid   ( vip_master_IF.b_valid   ),
    .s_axi_bready   ( vip_master_IF.b_ready   ),
    .s_axi_araddr   ( vip_master_IF.ar_addr   ),
    .s_axi_arprot   ( vip_master_IF.ar_prot   ),
    .s_axi_arvalid  ( vip_master_IF.ar_valid  ),
    .s_axi_arready  ( vip_master_IF.ar_ready  ),
    .s_axi_rdata    ( vip_master_IF.r_data    ),
    .s_axi_rresp    ( vip_master_IF.r_resp    ),
    .s_axi_rvalid   ( vip_master_IF.r_valid   ),
    .s_axi_rready   ( vip_master_IF.r_ready   ),

    // Master Ports (Outputs to DUTs)
    .m_axi_awaddr   ( m_axi_awaddr  ),
    .m_axi_awprot   ( m_axi_awprot  ),
    .m_axi_awvalid  ( m_axi_awvalid ),
    .m_axi_awready  ( m_axi_awready ),
    .m_axi_wdata    ( m_axi_wdata   ),
    .m_axi_wstrb    ( m_axi_wstrb   ),
    .m_axi_wvalid   ( m_axi_wvalid  ),
    .m_axi_wready   ( m_axi_wready  ),
    .m_axi_bresp    ( m_axi_bresp   ),
    .m_axi_bvalid   ( m_axi_bvalid  ),
    .m_axi_bready   ( m_axi_bready  ),
    .m_axi_araddr   ( m_axi_araddr  ),
    .m_axi_arprot   ( m_axi_arprot  ),
    .m_axi_arvalid  ( m_axi_arvalid ),
    .m_axi_arready  ( m_axi_arready ),
    .m_axi_rdata    ( m_axi_rdata   ),
    .m_axi_rresp    ( m_axi_rresp   ),
    .m_axi_rvalid   ( m_axi_rvalid  ),
    .m_axi_rready   ( m_axi_rready  )
);

// 4. DUT INSTANTIATION
reg s0_axis_aclk; reg s0_axis_aresetn; reg [31:0] s0_axis_tdata; wire s0_axis_tready; reg s0_axis_tvalid;
reg [159:0] s1_axis_tdata; wire s1_axis_tready; reg s1_axis_tvalid;
wire [N_DDS*16-1:0] m_axis_tdata; reg m_axis_tready = 1; wire m_axis_tvalid;

axis_signal_gen_v6 #(
    .N(N), 
    .N_DDS(N_DDS), 
    .GEN_DDS("FALSE"), 
    .ENVELOPE_TYPE("REAL"),
    .EMULATOR(1) // <-- NEW: Force the IP to use Emulator Behavioral Models
) DUT ( 
    .s_axi_aclk    ( s_axi_aclk              ),
    .s_axi_aresetn ( s_axi_aresetn           ),
    
    // Config interface (connected to interconnect)
    .s_axi_awaddr  ( m_axi_awaddr[0][5:0]    ), 
    .s_axi_awprot  ( m_axi_awprot[0]         ),
    .s_axi_awvalid ( m_axi_awvalid[0]        ),
    .s_axi_awready ( m_axi_awready[0]        ),
    .s_axi_wdata   ( m_axi_wdata[0]          ),
    .s_axi_wstrb   ( m_axi_wstrb[0][3:0]     ), 
    .s_axi_wvalid  ( m_axi_wvalid[0]         ),
    .s_axi_wready  ( m_axi_wready[0]         ),
    .s_axi_bresp   ( m_axi_bresp[0]          ),
    .s_axi_bvalid  ( m_axi_bvalid[0]         ),
    .s_axi_bready  ( m_axi_bready[0]         ),
    .s_axi_araddr  ( m_axi_araddr[0][5:0]    ),
    .s_axi_arprot  ( m_axi_arprot[0]         ),
    .s_axi_arvalid ( m_axi_arvalid[0]        ),
    .s_axi_arready ( m_axi_arready[0]        ),
    .s_axi_rdata   ( m_axi_rdata[0]          ),
    .s_axi_rresp   ( m_axi_rresp[0]          ),
    .s_axi_rvalid  ( m_axi_rvalid[0]         ),
    .s_axi_rready  ( m_axi_rready[0]         ),

    // Memory load interface
    .s0_axis_aclk(s0_axis_aclk), 
    .s0_axis_aresetn(s0_axis_aresetn), 
    .s0_axis_tdata(s0_axis_tdata), 
    .s0_axis_tvalid(s0_axis_tvalid), 
    .s0_axis_tready(s0_axis_tready),
    
    // Core Clock and Reset
    .aresetn(aresetn), 
    .aclk(aclk),
    
    // Command interface
    .s1_axis_tdata(s1_axis_tdata), 
    .s1_axis_tvalid(s1_axis_tvalid), 
    .s1_axis_tready(s1_axis_tready),
    
    // Output interface
    .m_axis_tready(m_axis_tready), 
    .m_axis_tvalid(m_axis_tvalid), 
    .m_axis_tdata(m_axis_tdata)
);

// Verilator 5.x fix
AXI_BUS_DV #(.AXI_ADDR_WIDTH(32), .AXI_DATA_WIDTH(32), .AXI_ID_WIDTH(1), .AXI_USER_WIDTH(1)) dummy_dv_if (s_axi_aclk);

// Waveform Fields.
reg [31:0] freq_r, phase_r; reg [15:0] addr_r, gain_r, nsamp_r;
reg [1:0] outsel_r; reg mode_r, stdysel_r, phrst_r;

// Assignment of data out for debugging.
wire [15:0] dout_ii [0:N_DDS-1];
generate
genvar ii;
for (ii = 0; ii < N_DDS; ii = ii + 1) begin : GEN_debug
    assign dout_ii[ii] = m_axis_tdata[16*ii +: 16];
end
endgenerate

// Fix: Match exactly the 159-bit concatenation from the reference
assign s1_axis_tdata = {{10{1'b0}}, phrst_r, stdysel_r, mode_r, outsel_r, nsamp_r, {16{1'b0}}, gain_r, {16{1'b0}}, addr_r, phase_r, freq_r};

// Trace Dump
initial begin
   $dumpfile("obj_dir/waveform_dynamic_routed.vcd");
   $dumpvars(0, tb_siggen_dynamic_routed);
end

// Simulation Control Flags
reg   tb_load_mem       = 0;
reg   tb_load_mem_done  = 0;
reg   tb_load_wave      = 0;
reg   tb_load_wave_done = 0;
reg   tb_write_out      = 0;

// AXI Replay Logic
initial begin
   automatic axi_test::axi_lite_rand_master #(.AW(32), .DW(32)) lite_axi_master = new ( vip_master_dv_IF, "VIP_MST");
   automatic axi_pkg::resp_t resp;
   integer fd, scan_res;
   string cmd;
   logic [31:0] addr_val, data_val;

   s_axi_aresetn <= 0; s0_axis_aresetn <= 0; aresetn <= 0;
   lite_axi_master.reset();
   #500; s_axi_aresetn <= 1; s0_axis_aresetn <= 1; aresetn <= 1;
   #1000;

   fd = $fopen("axi_replay.dat", "r");
   if (fd == 0) begin
       $display("ERROR: axi_replay.dat not found.");
       $finish;
   end

   while (!$feof(fd)) begin
       scan_res = $fscanf(fd, "%s %h %h\n", cmd, addr_val, data_val);
       if (scan_res == 3 && cmd == "w") begin
           $display("t = %0t : Replaying to Interconnect: Addr=%h Data=%h", $time, addr_val, data_val);
           lite_axi_master.write(addr_val, axi_pkg::prot_t'('0), data_val, 8'hF, resp);

           // Detect WE for memory loading
           if (addr_val == 32'h40000004 && data_val == 32'h00000001) begin
               tb_load_mem <= 1;
               wait (tb_load_mem_done);
               tb_load_mem <= 0;
           end
       end
   end
   $fclose(fd);

   #1000;
   
   // Start Waveform Generation
   tb_write_out   <= 1;
   tb_load_wave   <= 1;
   wait (tb_load_wave_done);

   #25us;
   tb_write_out   <= 0;
   #5us;
   $finish;
end

// Failsafe Timeout
initial begin
    #1000000; 
    $display("ERROR: Simulation Timed Out!");
    $finish;
end

// Memory Loading Logic
initial begin
   int fd,vali,valq;
   bit signed [15:0] ii,qq;
   s0_axis_tvalid <= 0;
   s0_axis_tdata  <= 0;
   wait (tb_load_mem);
   fd = $fopen("./gauss.txt","r");
   wait (s0_axis_tready);
   while($fscanf(fd,"%d,%d", vali,valq) == 2) begin
      ii = vali; qq = valq;
      @(posedge s0_axis_aclk);
      s0_axis_tvalid <= 1;
      s0_axis_tdata  <= {qq,ii};
   end
   @(posedge s0_axis_aclk);
   s0_axis_tvalid <= 0;
   $fclose(fd);
   tb_load_mem_done <= 1;
end

// Waveform Command Logic - Matched to Golden Trace Sequence
initial begin
   s1_axis_tvalid <= 0;
   freq_r <= 0; phase_r <= 0; addr_r <= 0; gain_r <= 0; nsamp_r <= 0;
   outsel_r <= 0; mode_r <= 0; stdysel_r <= 0; phrst_r <= 0;

   wait (tb_load_wave);
   wait (s1_axis_tready);
   @(posedge aclk);
   
   // Phase 1: Product Mode (25 pulses)
   $display("t = %0t : Starting Phase 1 (Product)", $time);
   gain_r <= 1000;
   repeat (25) begin
      @(negedge aclk);
      if (~s1_axis_tready) begin s1_axis_tvalid <= 0; wait (s1_axis_tready); end
      s1_axis_tvalid <= 1;
      freq_r <= 0; // DC mode for matching golden
      phase_r <= 0; addr_r <= 22;
      gain_r <= (gain_r + 1001) % 10000;
      nsamp_r <= 80; outsel_r <= 0; mode_r <= 0; stdysel_r <= 0; phrst_r <= 0;
      @(posedge aclk);
   end
   @(posedge aclk);
   s1_axis_tvalid <= 0;
   repeat(50) @(posedge aclk);

   // Phase 2: DDS Only (25 pulses)
   $display("t = %0t : Starting Phase 2 (DDS Only)", $time);
   gain_r <= 1000;
   repeat (25) begin
      @(negedge aclk);
      if (~s1_axis_tready) begin s1_axis_tvalid <= 0; wait (s1_axis_tready); end
      s1_axis_tvalid <= 1;
      freq_r <= 0; 
      phase_r <= 0; addr_r <= 22;
      gain_r <= (gain_r + 1001) % 10000;
      nsamp_r <= 80; outsel_r <= 1; mode_r <= 0; stdysel_r <= 0; phrst_r <= 0;
      @(posedge aclk);
   end
   @(posedge aclk);
   s1_axis_tvalid <= 0;
   repeat(50) @(posedge aclk);

   // Phase 3: Memory Only (25 pulses)
   $display("t = %0t : Starting Phase 3 (Mem Only)", $time);
   gain_r <= 12000;
   repeat (25) begin
      @(negedge aclk);
      if (~s1_axis_tready) begin s1_axis_tvalid <= 0; wait (s1_axis_tready); end
      s1_axis_tvalid <= 1;
      freq_r <= 0; 
      phase_r <= 0; addr_r <= 22;
      nsamp_r <= 80; outsel_r <= 2; mode_r <= 0; stdysel_r <= 0; phrst_r <= 0;
      @(posedge aclk);
   end
   
   @(posedge aclk);
   s1_axis_tvalid <= 0;
   tb_load_wave_done <= 1;
end

// Data Writer
initial begin
   int fd;
   int i;
   shortint real_d;
   fd = $fopen("obj_dir/dout.csv","w");
   $fdisplay(fd, "valid, idx, real");
   wait (tb_write_out);
   while (tb_write_out) begin
      @(posedge aclk);
      for (i=0; i<N_DDS; i = i+1) begin
         real_d = dout_ii[i][15:0];
         // Matched exact spacing of golden trace CSV
         $fdisplay(fd, "%d,           %d,   %d", m_axis_tvalid, i, real_d);
      end
   end
   $fclose(fd);
end

// Clocks
always begin s_axi_aclk <= 0; #10; s_axi_aclk <= 1; #10; end
always begin s0_axis_aclk <= 0; #10; s0_axis_aclk <= 1; #10; end
always begin
   aclk <= 0; aclk4 <= 0; #1; aclk4 <= 1; #1;
   aclk4 <= 0; #1; aclk4 <= 1; #1;
   aclk <= 1; aclk4 <= 0; #1; aclk4 <= 1; #1;
   aclk4 <= 0; #1; aclk4 <= 1; #1;
end  

function [31:0] freq_calc;
    input int fclk; input int ndds; input int f;
    real fs,temp;
    if (fclk == 0) return 0;
    fs = fclk*ndds;
    temp = f/fs*2**30;
    freq_calc = {int'(temp),2'b00};
endfunction

endmodule