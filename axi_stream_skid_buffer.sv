`timescale 1ns / 1ps
`include "config_pkg.svh"

module skid_buffer #(
    parameter SKID_DATA_WIDTH = 16
)(
    input  logic                        clk,         
    input  logic                        reset,      

    // AXI-Stream Slave Interface
    input  logic                        s_valid,    
    input  logic [SKID_DATA_WIDTH-1:0]  s_data,     
    output logic                        s_ready,    

    // AXI-Stream Master Interface
    output logic                        m_valid,
    output logic [SKID_DATA_WIDTH-1:0]  m_data,  
    input  logic                        m_ready,

    // Config interface (renamed to config_r)
    input  config_k                     config_r,
    input  logic                        config_valid,
    output logic                        config_ready,

    // Outputs derived from config
    output logic [3:0]                  n_out,
    output logic [15:0]                 total_samples
);

    // ------------------------------
    // Config Handshake + Registering
    // ------------------------------
    logic        config_loaded;
    logic [3:0]  n_reg;

    assign config_ready   = ~config_loaded;
    assign n_out          = n_reg;
    assign total_samples  = 1 << n_reg;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            config_loaded <= 1'b0;
            n_reg         <= 4'd0;
        end else begin
            if (config_valid && config_ready) begin
                n_reg         <= config_r.n;
                config_loaded <= 1'b1;
            end
        end
    end

    // ------------------------------
    // Skid Buffer Logic 
    // ------------------------------
    logic [SKID_DATA_WIDTH-1:0] skid_data;  
    logic                       skid_valid; 

    always_ff @(posedge clk) begin
        if (reset) begin
            skid_data  <= '0;
            skid_valid <= 1'b0;
        end else begin
            if (!m_ready && !skid_valid && s_valid) begin
                skid_data  <= s_data;
                skid_valid <= 1'b1;
            end else if (m_ready && skid_valid) begin
                skid_data  <= '0;
                skid_valid <= 1'b0;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            m_data  <= '0;
            m_valid <= 1'b0;
        end else begin
            if (m_ready && skid_valid) begin
                m_data  <= skid_data;
                m_valid <= 1'b1;
            end else if (m_ready && !skid_valid && s_valid) begin
                m_data  <= s_data;
                m_valid <= 1'b1;
            end else begin
                if (!m_ready) begin
                    m_valid <= m_valid;
                    m_data  <= m_data;
                end else begin
                    m_valid <= 1'b0;
                    m_data  <= m_data;
                end
            end
        end
    end

    assign s_ready = m_ready || !skid_valid;


logic [15:0] input_count;
logic [15:0] output_count;

always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        input_count <= 0;
    end else if (config_loaded && s_valid && s_ready && input_count < total_samples) begin
        input_count <= input_count + 1;
    end
end

always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        output_count <= 0;
    end else if (config_loaded && m_valid && m_ready && output_count < total_samples) begin
        output_count <= output_count + 1;
    end
end


logic input_done  = config_loaded && (input_count  == total_samples);
logic output_done = config_loaded && (output_count == total_samples);


endmodule
