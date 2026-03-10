`include "axi/typedef.svh"
`include "axi/assign.svh"

module axi_lite_interconnect_wrapper #(
    parameter int unsigned NO_SLV_PORTS = 1,
    parameter int unsigned NO_MST_PORTS = 16,
    parameter int unsigned AXI_ADDR_WIDTH = 32,
    parameter int unsigned AXI_DATA_WIDTH = 32,
    parameter logic [63:0] ADDR_RANGES [NO_MST_PORTS] = '{default: 0} 
) (
    input logic clk_i,
    input logic rst_ni,

    // Slave Interface (From Testbench VIP)
    input  logic [AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input  logic [2:0]                s_axi_awprot,
    input  logic                      s_axi_awvalid,
    output logic                      s_axi_awready,
    input  logic [AXI_DATA_WIDTH-1:0] s_axi_wdata,
    input  logic [AXI_DATA_WIDTH/8-1:0] s_axi_wstrb,
    input  logic                      s_axi_wvalid,
    output logic                      s_axi_wready,
    output logic [1:0]                s_axi_bresp,
    output logic                      s_axi_bvalid,
    input  logic                      s_axi_bready,
    input  logic [AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    input  logic [2:0]                s_axi_arprot,
    input  logic                      s_axi_arvalid,
    output logic                      s_axi_arready,
    output logic [AXI_DATA_WIDTH-1:0] s_axi_rdata,
    output logic [1:0]                s_axi_rresp,
    output logic                      s_axi_rvalid,
    input  logic                      s_axi_rready,

    // Master Interfaces (To QICK IPs)
    output logic [NO_MST_PORTS-1:0][AXI_ADDR_WIDTH-1:0] m_axi_awaddr,
    output logic [NO_MST_PORTS-1:0][2:0]                m_axi_awprot,
    output logic [NO_MST_PORTS-1:0]                     m_axi_awvalid,
    input  logic [NO_MST_PORTS-1:0]                     m_axi_awready,
    output logic [NO_MST_PORTS-1:0][AXI_DATA_WIDTH-1:0] m_axi_wdata,
    output logic [NO_MST_PORTS-1:0][AXI_DATA_WIDTH/8-1:0] m_axi_wstrb,
    output logic [NO_MST_PORTS-1:0]                     m_axi_wvalid,
    input  logic [NO_MST_PORTS-1:0]                     m_axi_wready,
    input  logic [NO_MST_PORTS-1:0][1:0]                m_axi_bresp,
    input  logic [NO_MST_PORTS-1:0]                     m_axi_bvalid,
    output logic [NO_MST_PORTS-1:0]                     m_axi_bready,
    output logic [NO_MST_PORTS-1:0][AXI_ADDR_WIDTH-1:0] m_axi_araddr,
    output logic [NO_MST_PORTS-1:0][2:0]                m_axi_arprot,
    output logic [NO_MST_PORTS-1:0]                     m_axi_arvalid,
    input  logic [NO_MST_PORTS-1:0]                     m_axi_arready,
    input  logic [NO_MST_PORTS-1:0][AXI_DATA_WIDTH-1:0] m_axi_rdata,
    input  logic [NO_MST_PORTS-1:0][1:0]                m_axi_rresp,
    input  logic [NO_MST_PORTS-1:0]                     m_axi_rvalid,
    output logic [NO_MST_PORTS-1:0]                     m_axi_rready
);

    localparam int unsigned StrbWidth = AXI_DATA_WIDTH / 8;
    typedef logic [AXI_ADDR_WIDTH-1:0]   addr_t;
    typedef logic [AXI_DATA_WIDTH-1:0]   data_t;
    typedef logic [StrbWidth-1:0]        strb_t;

    `AXI_LITE_TYPEDEF_AW_CHAN_T(aw_chan_t, addr_t)
    `AXI_LITE_TYPEDEF_W_CHAN_T(w_chan_t, data_t, strb_t)
    `AXI_LITE_TYPEDEF_B_CHAN_T(b_chan_t)
    `AXI_LITE_TYPEDEF_AR_CHAN_T(ar_chan_t, addr_t)
    `AXI_LITE_TYPEDEF_R_CHAN_T(r_chan_t, data_t)
    `AXI_LITE_TYPEDEF_REQ_T(axi_req_t, aw_chan_t, w_chan_t, ar_chan_t)
    `AXI_LITE_TYPEDEF_RESP_T(axi_resp_t, b_chan_t, r_chan_t)
    
    axi_req_t  [NO_SLV_PORTS-1:0] slv_reqs;
    axi_resp_t [NO_SLV_PORTS-1:0] slv_resps;
    axi_req_t  [NO_MST_PORTS-1:0] mst_reqs;
    axi_resp_t [NO_MST_PORTS-1:0] mst_resps;

    // Use xbar_rule_32_t to match 32-bit AXI address width
    axi_pkg::xbar_rule_32_t [NO_MST_PORTS-1:0] addr_map;
    
    for (genvar i = 0; i < NO_MST_PORTS; i++) begin : gen_addr_map
        assign addr_map[i].idx = i;
        // Correctly extract 32-bit start/end addresses from the 64-bit parameter
        assign addr_map[i].start_addr = ADDR_RANGES[i][63:32];
        assign addr_map[i].end_addr   = ADDR_RANGES[i][31:0];
    end

    localparam axi_pkg::xbar_cfg_t XbarCfg = '{
        NoSlvPorts:         NO_SLV_PORTS,
        NoMstPorts:         NO_MST_PORTS,
        MaxMstTrans:        1,
        MaxSlvTrans:        1,
        FallThrough:        1'b0,
        LatencyMode:        axi_pkg::CUT_ALL_PORTS,
        AxiAddrWidth:       AXI_ADDR_WIDTH, // Ensure this matches exactly!
        AxiDataWidth:       AXI_DATA_WIDTH,
        NoAddrRules:        NO_MST_PORTS,
        default:            '0
    };

    axi_lite_xbar #(
        .Cfg(XbarCfg),
        .aw_chan_t(aw_chan_t), .w_chan_t(w_chan_t), .b_chan_t(b_chan_t),
        .ar_chan_t(ar_chan_t), .r_chan_t(r_chan_t), .axi_req_t(axi_req_t),
        .axi_resp_t(axi_resp_t), .rule_t(axi_pkg::xbar_rule_32_t)
    ) i_xbar (
        .clk_i, .rst_ni, .test_i(1'b0),
        .slv_ports_req_i(slv_reqs), .slv_ports_resp_o(slv_resps),
        .mst_ports_req_o(mst_reqs), .mst_ports_resp_i(mst_resps),
        .addr_map_i(addr_map),
        .en_default_mst_port_i('0), .default_mst_port_i('0)
    );

    // Casting: Flat Wires <-> Structs
    
    // Slave
    assign slv_reqs[0].aw.addr = s_axi_awaddr;
    assign slv_reqs[0].aw.prot = s_axi_awprot;
    assign slv_reqs[0].aw_valid = s_axi_awvalid;
    assign s_axi_awready = slv_resps[0].aw_ready;
    
    assign slv_reqs[0].w.data = s_axi_wdata;
    assign slv_reqs[0].w.strb = s_axi_wstrb;
    assign slv_reqs[0].w_valid = s_axi_wvalid;
    assign s_axi_wready = slv_resps[0].w_ready;
    
    assign s_axi_bresp  = slv_resps[0].b.resp;
    assign s_axi_bvalid = slv_resps[0].b_valid;
    assign slv_reqs[0].b_ready = s_axi_bready;

    assign slv_reqs[0].ar.addr = s_axi_araddr;
    assign slv_reqs[0].ar.prot = s_axi_arprot;
    assign slv_reqs[0].ar_valid = s_axi_arvalid;
    assign s_axi_arready = slv_resps[0].ar_ready;

    assign s_axi_rdata  = slv_resps[0].r.data;
    assign s_axi_rresp  = slv_resps[0].r.resp;
    assign s_axi_rvalid = slv_resps[0].r_valid;
    assign slv_reqs[0].r_ready = s_axi_rready;

    // Masters
    for (genvar i = 0; i < NO_MST_PORTS; i++) begin : gen_mst_cast
        assign m_axi_awaddr[i]  = mst_reqs[i].aw.addr;
        assign m_axi_awprot[i]  = mst_reqs[i].aw.prot;
        assign m_axi_awvalid[i] = mst_reqs[i].aw_valid;
        assign mst_resps[i].aw_ready = m_axi_awready[i];

        assign m_axi_wdata[i]   = mst_reqs[i].w.data;
        assign m_axi_wstrb[i]   = mst_reqs[i].w.strb;
        assign m_axi_wvalid[i]  = mst_reqs[i].w_valid;
        assign mst_resps[i].w_ready = m_axi_wready[i];

        assign mst_resps[i].b.resp  = m_axi_bresp[i];
        assign mst_resps[i].b_valid = m_axi_bvalid[i];
        assign m_axi_bready[i]  = mst_reqs[i].b_ready;
        
        assign m_axi_araddr[i]  = mst_reqs[i].ar.addr;
        assign m_axi_arprot[i]  = mst_reqs[i].ar.prot;
        assign m_axi_arvalid[i] = mst_reqs[i].ar_valid;
        assign mst_resps[i].ar_ready = m_axi_arready[i];

        assign mst_resps[i].r.data = m_axi_rdata[i];
        assign mst_resps[i].r.resp = m_axi_rresp[i];
        assign mst_resps[i].r_valid = m_axi_rvalid[i]; // Fixed from .r.valid
        assign m_axi_rready[i]  = mst_reqs[i].r_ready;
    end
endmodule