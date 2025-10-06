module skid_buffer #(
    parameter SKID_DATA_WIDTH = 32  // Width of the AXI data bus
) (
    input  logic                        clk,         
    input  logic                        reset,      
    input  logic                        s_valid,    
    input  logic [SKID_DATA_WIDTH-1:0]  s_data,     
    output logic                        s_ready,    

    output logic                        m_valid,
    output logic [SKID_DATA_WIDTH-1:0]  m_data,  
    input  logic                        m_ready    
);

    // Internal buffer signals
    logic [SKID_DATA_WIDTH-1:0] skid_data;  
    logic                       skid_valid; 

    // Skid Buffer Logic: Capture input data when output is not ready
    always_ff @(posedge clk) begin
        if (reset) begin
            skid_data  <= '0;
            skid_valid <= 1'b0;
        end else begin
            // Case 1: Buffer empty, but output not ready  store input
            if (!m_ready && !skid_valid && s_valid) begin
                skid_data  <= s_data;
                skid_valid <= 1'b1;

            // Case 2: Output accepted skid buffer content clear buffer
            end else if (m_ready && skid_valid) begin
                skid_data  <= '0;
                skid_valid <= 1'b0;
            end
        end
    end

    // Output logic
    always_ff @(posedge clk) begin
        if (reset) begin
            m_data  <= '0;
            m_valid <= 1'b0;
        end else begin
            // Case 1: Output ready, and buffer has valid data
            if (m_ready && skid_valid) begin
                m_data  <= skid_data;
                m_valid <= 1'b1;

            // Case 2: Output ready, and input has new data (no buffer needed)
            end else if (m_ready && !skid_valid && s_valid) begin
                m_data  <= s_data;
                m_valid <= 1'b1;

            // Case 3: Output not ready hold current output valid
            end else begin
                if (!m_ready) begin
                    m_valid <= m_valid;
                    m_data  <= m_data;
                    end
                else
                    m_valid <= 1'b0;
                    m_data <= m_data; 
            end
        end
    end
    assign s_ready = m_ready || !skid_valid;
endmodule
