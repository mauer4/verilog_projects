`timescale 1 ps / 1 ps
`define Fifty_M 26'b10111110101111000010000000

// add counter logic_range
// check why time resets when going from SET to CLK

module sec_inc_clk(input logic [5:0] sec_in, input logic [5:0] min_in, input logic [4:0] hr_in,
               input logic set_AMPM,
               output logic [5:0] sec_out, output logic [5:0] min_out, output logic [4:0] hr_out);
   always_comb begin
       min_out = min_in;
       hr_out = hr_in;
       if(sec_in < 6'd59)
         sec_out = sec_in + 1'b1;
       else begin
         sec_out = 0;
         if(min_in < 6'd59)
           min_out = min_in + 1'b1;
         else begin
           min_out = 0;
           if(hr_in < 4'd23)
             hr_out = hr_in + 1'b1;
           else
             hr_out = 0;
         end
       end
   end

endmodule: sec_inc_clk


module CLOCK(input logic clk, input logic rst,
             input logic set_min, input logic set_hr, input logic AM2PM,
             output logic [5:0] sec, output logic [5:0] min, output logic [4:0] hr);

    enum bit [1:0] {WAIT, CLK_SET, CLK_RUN} state, next_state;

    logic [25:0] counter, next_counter;

    // register for the time
    logic [5:0] next_sec, next_min;
    logic [4:0] next_hr;

    // registers for the set mechanism
    logic [5:0] add_min, next_add_min;
    logic [4:0] add_hr, next_add_hr;

    //input and output of the increase time module
    logic [5:0] sec_increased_out, min_increased_out;
    logic [4:0] hr_increased_out;

    sec_inc_clk increase_second(sec, min, hr, set_AMPM, sec_increased_out, min_increased_out, hr_increased_out);

    //state transition logic
    always_ff @(negedge rst)
      state <= next_state;

    always_comb begin
      next_state = WAIT;
      case(state)
        WAIT: next_state = CLK_SET;
        CLK_SET: next_state = CLK_RUN;
        CLK_RUN: next_state = CLK_SET;
      endcase
    end

    //clk time registers
    always_ff @(posedge clk) begin
      if(~rst && state == WAIT) {sec, min, hr, counter} <= 43'b0;
      else if(counter == 26'b0) {sec, min, hr} <= {next_sec, next_min, next_hr};

      counter <= next_counter;
      if(counter == `Fifty_M)
        counter <= 0;
    end

    always_comb begin
      {next_sec, next_min, next_hr} = {sec, min, hr};
      case(state)
        WAIT: {next_sec, next_min, next_hr, next_counter} = 43'b0;
        CLK_SET: {next_sec, next_min, next_hr, next_counter} = {7'b0, next_add_min, next_add_hr, 26'b0};
        CLK_RUN: {next_sec, next_min, next_hr, next_counter} = {sec_increased_out, min_increased_out, hr_increased_out, counter + 1'b1};
      endcase
    end

    //SET_CLK register logic
    always_ff @(posedge set_min, negedge rst) begin
      //if(~rst) add_min <= min;
      //else
      add_min <= next_add_min;
    end

    always_ff @(posedge set_hr, negedge rst) begin
      if(~rst) add_hr <= hr;
      else if(AM2PM) add_hr <= (next_add_hr < 5'd12) ? next_add_hr + 5'd12 - 1'b1 : next_add_hr - 5'd12 - 1'b1;
      else add_hr <= next_add_hr;
    end

    always_comb begin
      {next_add_min, next_add_hr} = {add_min, add_hr};
      case(state)
        WAIT: {next_add_min, next_add_hr} = {12'b0};
        CLK_SET: begin
          next_add_min = (add_min < 6'd59) ? add_min + 1'b1 : 0;
          next_add_hr = (add_hr < 5'd23) ? add_hr + 1'b1 : 0;
        end
        CLK_RUN: {next_add_min, next_add_hr} = {min, hr};
      endcase
    end

endmodule: CLOCK
