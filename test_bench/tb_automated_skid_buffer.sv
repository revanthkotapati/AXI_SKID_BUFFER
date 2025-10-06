`timescale 1ns/1ps

module tb_skid_buffer;

  parameter int SKID_DATA_WIDTH = 32;

  // 1. Port List
  logic clk;
  logic reset;

  logic s_valid;
  logic [SKID_DATA_WIDTH-1:0] s_data;
  logic s_ready;

  logic m_valid;
  logic [SKID_DATA_WIDTH-1:0] m_data;
  logic m_ready;

  // 2. Internal Variables
  int read_fd;
  int expected_fd;
  int wait_n;
  int data_counter;
  logic [31:0] input_val, expected_val;

  // 3. Input/Output File Paths
  localparam string INPUT_DATA_FILE      = "skid_input.csv";
  localparam string EXPECTED_OUTPUT_FILE = "skid_expected_output.csv";

  // 4. DUT Instantiation
  skid_buffer #(.SKID_DATA_WIDTH(SKID_DATA_WIDTH)) DUT (
    .clk(clk),
    .reset(reset),
    .s_valid(s_valid),
    .s_data(s_data),
    .s_ready(s_ready),
    .m_valid(m_valid),
    .m_data(m_data),
    .m_ready(m_ready)
  );

  // 5. Clock Generation
  always #5 clk = ~clk;

  // 6. Reset Task
  task automatic reset_task;
  begin
    reset <= 1;
    repeat (3) @(posedge clk);
    reset <= 0;
    $display("INFO: Reset applied.");
  end
  endtask

  // 7. Main Initial Block
  initial begin
    clk = 0;
    reset = 0;
    s_valid = 0;
    s_data  = 0;
    m_ready = 0;
    data_counter = 0;

    repeat (5) @(posedge clk);
    reset_task();

    fork
      send_input_from_file(INPUT_DATA_FILE, 2);
      begin
      repeat(1) @(posedge clk);
      read_and_check_output(EXPECTED_OUTPUT_FILE,3);
      end
    join_any

    $display("TESTBENCH: Simulation completed.");
    #1000;
    $finish;
  end

  // 8. Input Driver Task
  task automatic send_input_from_file(input string FILE_NAME, input int throttle);
  begin
    read_fd = $fopen(FILE_NAME, "r");
    if (read_fd == 0) $fatal("ERROR: Could not open input file.");

    while ($fscanf(read_fd, "%h\n", input_val) == 1) begin
      @(posedge clk);
      s_data  <= input_val;
      s_valid <= 1;
      data_counter++;
      $display("INFO: file content at line %0d is = %0h",data_counter,input_val);


      while (!s_ready) @(posedge clk);
      @(posedge clk);
      s_valid <= 0;

      wait_n = $urandom % throttle;
      repeat (wait_n) @(posedge clk);
    end

    $fclose(read_fd);
    $display("INFO: Input data sent successfully.");
  end
  endtask

  // 9. Output Checker Task
  task automatic read_and_check_output(input string FILE_NAME, input int throttle);
  begin
    expected_fd = $fopen(FILE_NAME, "r");
    if (expected_fd == 0) $fatal("ERROR: Could not open expected output file.");
      
    while (!$feof(expected_fd)) begin
      @(posedge clk);
       m_ready <= 1;

      if (m_valid) begin
        $fscanf(expected_fd, "%h\n", expected_val);

        if (m_data === expected_val) begin
          $display("PASS: Output = %h, Expected = %h", m_data, expected_val);
        end else begin
          $display("FAIL: Output = %h, Expected = %h", m_data, expected_val);
          $stop;
        end

        m_ready <= 0;
        wait_n = $urandom % throttle;
        repeat (wait_n) @(posedge clk);
      end
    end

    $fclose(expected_fd);
    $display("INFO: Output data verified.");
  end
  endtask

endmodule
