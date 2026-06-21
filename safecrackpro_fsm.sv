module safecrackpro_fsm (
    input  logic        clk,
    input  logic        rstn,
    input  logic [2:0]  btn,
    output logic [3:0][3:0] digits,
    output logic [1:0]  current_position_idx,
    output logic [17:0] led_red,
    output logic [8:0]  led_green
);

    // Parâmetros de Temporização (50 MHz)
    localparam int TIME_3S = 150_000_000;
    localparam int TIME_5S = 250_000_000;

    // Detectores de Borda (Edge Detection) para os botões invertidos
    logic [2:0] btn_prev, btn_pos, btn_edge;
    
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) btn_prev <= 3'b000;
        else       btn_prev <= btn_pos;
    end
    
    assign btn_pos = ~btn;
    assign btn_edge = btn_pos & ~btn_prev;

    // Definição dos Estados da FSM baseados no seu diagrama e no testbench
    typedef enum logic [2:0] {
        START,
        CURRENT_POSITION,
        CHECK_PASSWORD,
        WAIT_GREEN_LED_TIME,
        WAIT_RED_LED_TIME
    } state_t;

    state_t state, next_state;
    
    // Variáveis sequenciais e combinacionais
    logic [31:0] led_time_cnt, next_led_time_cnt;
    logic [1:0]  next_position;
    logic [3:0][3:0] next_digits;

    // Bloco Sequencial (Registradores)
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state                <= START;
            led_time_cnt         <= 0;
            current_position_idx <= 2'b00;
            digits               <= 16'h0000;
        end else begin
            state                <= next_state;
            led_time_cnt         <= next_led_time_cnt;
            current_position_idx <= next_position;
            digits               <= next_digits;
        end
    end

    // Bloco Combinacional (Transições e Lógica do Datapath)
    always_comb begin
        // Valores default para evitar inferência de Latch
        next_state        = state;
        next_led_time_cnt = led_time_cnt;
        next_position     = current_position_idx;
        next_digits       = digits;

        led_red           = 18'h00000;
        led_green         = 9'h000;

        case (state)
            // Estado de inicialização e reset dos dígitos
            START: begin
                next_digits       = 16'h0000;
                next_position     = 2'b00;
                next_led_time_cnt = 0;
                next_state        = CURRENT_POSITION;
            end

            // Estado de navegação e edição
            CURRENT_POSITION: begin
                if (btn_edge[1]) begin // BTN[1] - Incrementa o dígito
                    if (next_digits[current_position_idx] == 4'd9)
                        next_digits[current_position_idx] = 4'd0;
                    else
                        next_digits[current_position_idx] = next_digits[current_position_idx] + 1;
                end
                else if (btn_edge[2]) begin // BTN[2] - Decrementa o dígito
                    if (next_digits[current_position_idx] == 4'd0)
                        next_digits[current_position_idx] = 4'd9;
                    else
                        next_digits[current_position_idx] = next_digits[current_position_idx] - 1;
                end
                else if (btn_edge[0]) begin // BTN[0] - Confirma (Avança Posição)
                    if (current_position_idx == 2'd3) begin
                        next_state = CHECK_PASSWORD;
                    end else begin
                        next_position = current_position_idx + 1;
                    end
                end
            end

            
            CHECK_PASSWORD: begin
                if (digits[0] == 4'd5 && digits[1] == 4'd6 && digits[2] == 4'd7 && digits[3] == 4'd3) begin
                    next_state = WAIT_GREEN_LED_TIME;
                    next_led_time_cnt = TIME_5S;
                end else begin
                    next_state = WAIT_RED_LED_TIME;
                    next_led_time_cnt = TIME_3S;
                end
            end

            // Sucesso: Mantém LEDs verdes acesos
            WAIT_GREEN_LED_TIME: begin
                led_green = 9'h1FF;
                if (led_time_cnt > 0) begin
                    next_led_time_cnt = led_time_cnt - 1;
                end else begin
                    next_state = START;
                end
            end

            // Erro: Mantém LEDs vermelhos acesos
            WAIT_RED_LED_TIME: begin
                led_red = 18'h3FFFF;
                if (led_time_cnt > 0) begin
                    next_led_time_cnt = led_time_cnt - 1;
                end else begin
                    next_state = START;
                end
            end

            default: next_state = START;
        endcase
    end
endmodule