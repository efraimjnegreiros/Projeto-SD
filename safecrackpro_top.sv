module safecrackpro_top (
    input  logic        clk,
    input  logic        rstn,
    input  logic [2:0]  btn,
    output logic [6:0]  seg_pos1,  // 7-seg do dígito 0 (menos significativo)
    output logic [6:0]  seg_pos2,  // 7-seg do dígito 1
    output logic [6:0]  seg_pos3,  // 7-seg do dígito 2
    output logic [6:0]  seg_pos4,  // 7-seg do dígito 3 (mais significativo)
    output logic [6:0]  seg_cur_pos,     // 7-seg do índice da posição atual
    output logic [17:0] led_red,     // 18 LEDs vermelhos (senha errada)
    output logic [8:0]  led_green    // 9 LEDs verdes (senha correta)
);

    logic [3:0][3:0] digits;
    logic [1:0]      position;
	 
	
    logic [24:0] blink_cnt;
    logic        blink_state;
    logic        is_configuring;

    assign is_configuring = (led_red == 18'b0 && led_green == 9'b0);

    always_ff @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            blink_cnt   <= 0;
            blink_state <= 0;
        end else begin
            if (blink_cnt >= 25_000_000) begin
                blink_cnt   <= 0;
                blink_state <= ~blink_state;
            end else begin
                blink_cnt   <= blink_cnt + 1;
            end
        end
    end

    safecrackpro_fsm fsm_inst (
        .clk                  (clk),
        .rstn                 (rstn),
        .btn                  (btn),
        .digits               (digits),
        .current_position_idx (position),
        .led_red              (led_red),
        .led_green            (led_green)
    ); 

    bcd_to_7segment_anodo dec_pos1 (
        .bcd (digits[0]),
        .seg (seg_pos1)
    );

    bcd_to_7segment_anodo dec_pos2 (
        .bcd (digits[1]),
        .seg (seg_pos2)
    );

    bcd_to_7segment_anodo dec_pos3 (
        .bcd (digits[2]),
        .seg (seg_pos3)
    );

    bcd_to_7segment_anodo dec_pos4 (
        .bcd (digits[3]),
        .seg (seg_pos4)
    );

    bcd_to_7segment_anodo dec_cur_pos (
        .bcd ({2'b00, position} + 4'd1),
        .seg (seg_cur_pos)
    );

endmodule
