`timescale 1ns/1ps

// Testbench para safecrackpro_top
// Execute no ModelSim compilando todos os arquivos .sv em src/ e simulando este módulo.
//
// Mapeamento de botões (ativo baixo no hardware, btn_pos = ~btn na FSM):
//   btn[0] = BTN1 → INC_POSITION
//   btn[1] = BTN2 → INC_DIGIT
//   btn[2] = BTN3 → DEC_DIGIT
//
// Senha correta: 1-2-3-4  (digits[0..3] = 1,2,3,4)
//
// Para evitar simular 50 M ciclos nos estados de espera dos LEDs,
// o testbench força o contador interno a zero (via 'force').

module tb_safecrackpro_top;

    // -----------------------------------------------------------------
    // Parâmetros e sinais
    // -----------------------------------------------------------------
    localparam int CLK_PERIOD = 20; // 20 ns → 50 MHz

    logic        clk;
    logic        rstn;
    logic [2:0]  btn;
    logic [6:0]  seg_pos1, seg_pos2, seg_pos3, seg_pos4, seg_cur_pos;
    logic [17:0] led_red;
    logic [8:0]  led_green;

    // -----------------------------------------------------------------
    // DUT
    // -----------------------------------------------------------------
    safecrackpro_top dut (
        .clk         (clk),
        .rstn        (rstn),
        .btn         (btn),
        .seg_pos1    (seg_pos1),
        .seg_pos2    (seg_pos2),
        .seg_pos3    (seg_pos3),
        .seg_pos4    (seg_pos4),
        .seg_cur_pos (seg_cur_pos),
        .led_red     (led_red),
        .led_green   (led_green)
    );

    // -----------------------------------------------------------------
    // Clock
    // -----------------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // -----------------------------------------------------------------
    // Contadores de resultado
    // -----------------------------------------------------------------
    int pass_cnt = 0, fail_cnt = 0, test_num = 0;

    task automatic check(input string nome, input logic condicao);
        test_num++;
        if (condicao) begin
            $display("  [PASS] #%0d: %s", test_num, nome);
            pass_cnt++;
        end else begin
            $display("  [FAIL] #%0d: %s  (t=%0t ns)", test_num, nome, $time);
            fail_cnt++;
        end
    endtask

    // -----------------------------------------------------------------
    // Tarefa: reset
    // -----------------------------------------------------------------
    task do_reset();
        rstn = 1'b0;
        btn  = 3'b111; // sem botão pressionado (ativo baixo → todos em '1')
        repeat(4) @(posedge clk);
        @(negedge clk); rstn = 1'b1;  // libera reset na borda negativa
        @(posedge clk);                // START → CURRENT_POSITION
    endtask

    // -----------------------------------------------------------------
    // Tarefa: pressionar botão
    //
    // btn_mask: máscara com os bits 'ativos' em nível alto (e.g., 3'b001 = BTN[0])
    //           A tarefa inverte para gerar o nível baixo ativo no hardware.
    // hold_cycles: número de bordas positivas que o botão fica pressionado.
    //              3 ciclos é suficiente para qualquer transição de estado.
    // -----------------------------------------------------------------
    task automatic press_btn(input logic [2:0] btn_mask, input int hold_cycles = 3);
        @(negedge clk);
        btn = ~btn_mask;               // lógica invertida: ativo baixo
        repeat(hold_cycles) @(posedge clk);
        @(negedge clk);
        btn = 3'b111;                  // soltar botão
        @(posedge clk);                // ciclo extra para estabilizar
    endtask

    // -----------------------------------------------------------------
    // Tarefa: pular a espera dos LEDs
    //
    // Força o contador interno a 0 para que a FSM saia imediatamente do
    // estado WAIT_RED_LED_TIME ou WAIT_GREEN_LED_TIME sem aguardar 3s/5s.
    // -----------------------------------------------------------------
    task skip_led_wait();
        force dut.fsm_inst.led_time_cnt = '0;
        @(posedge clk);                // FSM: WAIT_x → START
        release dut.fsm_inst.led_time_cnt;
        @(posedge clk);                // FSM: START → CURRENT_POSITION (dígitos zerados)
    endtask

    // -----------------------------------------------------------------
    // Sequência principal de testes
    // -----------------------------------------------------------------
    initial begin
        $display("================================================");
        $display("   SafeCrackPro – Testbench ModelSim");
        $display("================================================");

        // =============================================================
        // TESTE 1: Reset
        // =============================================================
        $display("\n[Teste 1] Reset inicial");
        do_reset();

        check("Digitos todos zerados apos reset",
              dut.fsm_inst.digits == 16'h0000);
        check("Posicao inicial = 0",
              dut.fsm_inst.current_position_idx == 2'b00);
        check("LEDs vermelhos apagados",   dut.led_red   == 18'h00000);
        check("LEDs verdes apagados",      dut.led_green == 9'h000);
        // seg_cur_pos deve exibir '1' (posicao 0 + 1): 7-seg ativo-baixo = 7'b1001111
        check("seg_cur_pos exibe posicao 1", dut.seg_cur_pos == 7'b1001111);
        // seg_posX deve exibir '0': 7'b0000001
        check("seg_pos1 exibe '0'", dut.seg_pos1 == 7'b0000001);
        check("seg_pos2 exibe '0'", dut.seg_pos2 == 7'b0000001);
        check("seg_pos3 exibe '0'", dut.seg_pos3 == 7'b0000001);
        check("seg_pos4 exibe '0'", dut.seg_pos4 == 7'b0000001);

        // =============================================================
        // TESTE 2: Incrementar dígito (BTN[1])
        // =============================================================
        $display("\n[Teste 2] Incremento de digito – BTN[1]");

        press_btn(3'b010); // INC_DIGIT: digito[0] 0 → 1
        check("Digito[0] = 1 apos 1 press BTN[1]",
              dut.fsm_inst.digits[0] == 4'd1);
        check("seg_pos1 exibe '1' (7'b1001111)",
              dut.seg_pos1 == 7'b1001111);

        press_btn(3'b010); // INC_DIGIT: digito[0] 1 → 2
        check("Digito[0] = 2 apos 2 presses BTN[1]",
              dut.fsm_inst.digits[0] == 4'd2);
        check("seg_pos1 exibe '2' (7'b0010010)",
              dut.seg_pos1 == 7'b0010010);

        // =============================================================
        // TESTE 3: Decrementar dígito (BTN[2])
        // =============================================================
        $display("\n[Teste 3] Decremento de digito – BTN[2]");

        press_btn(3'b100); // DEC_DIGIT: digito[0] 2 → 1
        check("Digito[0] = 1 apos DEC_DIGIT",
              dut.fsm_inst.digits[0] == 4'd1);
        check("seg_pos1 exibe '1' (7'b1001111)",
              dut.seg_pos1 == 7'b1001111);

        // =============================================================
        // TESTE 4: Wrap-around decremento 0 → 9
        // =============================================================
        $display("\n[Teste 4] Wrap-around DEC: 0 -> 9");

        press_btn(3'b100); // 1 → 0
        press_btn(3'b100); // 0 → 9 (wrap)
        check("Digito[0] = 9 apos wrap-around DEC",
              dut.fsm_inst.digits[0] == 4'd9);
        check("seg_pos1 exibe '9' (7'b0000100)",
              dut.seg_pos1 == 7'b0000100);

        // =============================================================
        // TESTE 5: Wrap-around incremento 9 → 0
        // =============================================================
        $display("\n[Teste 5] Wrap-around INC: 9 -> 0");

        press_btn(3'b010); // 9 → 0 (wrap)
        check("Digito[0] = 0 apos wrap-around INC",
              dut.fsm_inst.digits[0] == 4'd0);
        check("seg_pos1 exibe '0' (7'b0000001)",
              dut.seg_pos1 == 7'b0000001);

        // =============================================================
        // TESTE 6: Senha correta — sequência 1-2-3-4
        // =============================================================
        $display("\n[Teste 6] Senha correta: 1-2-3-4");
        do_reset();

        // Posição 0: colocar dígito 1
        press_btn(3'b010);                          // 0 → 1
        check("Pos0: digito[0] = 1",
              dut.fsm_inst.digits[0] == 4'd1);

        // Avançar para posição 1
        press_btn(3'b001);                          // INC_POSITION: 0 → 1
        check("Posicao = 1",
              dut.fsm_inst.current_position_idx == 2'd1);
        check("seg_cur_pos exibe '2' (7'b0010010)",
              dut.seg_cur_pos == 7'b0010010);

        // Posição 1: colocar dígito 2
        press_btn(3'b010); press_btn(3'b010);       // 0 → 1 → 2
        check("Pos1: digito[1] = 2",
              dut.fsm_inst.digits[1] == 4'd2);

        // Avançar para posição 2
        press_btn(3'b001);                          // INC_POSITION: 1 → 2
        check("Posicao = 2",
              dut.fsm_inst.current_position_idx == 2'd2);
        check("seg_cur_pos exibe '3' (7'b0000110)",
              dut.seg_cur_pos == 7'b0000110);

        // Posição 2: colocar dígito 3
        press_btn(3'b010); press_btn(3'b010); press_btn(3'b010); // 0 → 1 → 2 → 3
        check("Pos2: digito[2] = 3",
              dut.fsm_inst.digits[2] == 4'd3);

        // Avançar para posição 3 (última)
        press_btn(3'b001);                          // INC_POSITION: 2 → 3
        check("Posicao = 3",
              dut.fsm_inst.current_position_idx == 2'd3);
        check("seg_cur_pos exibe '4' (7'b1001100)",
              dut.seg_cur_pos == 7'b1001100);

        // Posição 3: colocar dígito 4
        press_btn(3'b010); press_btn(3'b010);
        press_btn(3'b010); press_btn(3'b010);       // 0 → 1 → 2 → 3 → 4
        check("Pos3: digito[3] = 4",
              dut.fsm_inst.digits[3] == 4'd4);

        // INC_POSITION na posição 3 → CHECK_PASSWORD → WAIT_GREEN_LED_TIME
        press_btn(3'b001);
        check("LEDs verdes acesos: senha CORRETA!",
              dut.led_green == 9'h1FF);
        check("LEDs vermelhos apagados",
              dut.led_red == 18'h00000);

        // Pular os 5 s de espera
        skip_led_wait();
        check("Sistema reiniciou apos LEDs verdes (digitos = 0)",
              dut.fsm_inst.digits == 16'h0000);

        // =============================================================
        // TESTE 7: Senha errada — sequência 0-0-0-0
        // =============================================================
        $display("\n[Teste 7] Senha errada: 0-0-0-0");
        do_reset();

        // Avança posições sem alterar dígitos (todos permanecem 0)
        press_btn(3'b001); // pos 0 → 1
        press_btn(3'b001); // pos 1 → 2
        press_btn(3'b001); // pos 2 → 3
        press_btn(3'b001); // pos 3 → CHECK_PASSWORD → WAIT_RED_LED_TIME

        check("LEDs vermelhos acesos: senha ERRADA!",
              dut.led_red == 18'h3FFFF);
        check("LEDs verdes apagados",
              dut.led_green == 9'h000);

        // Pular os 3 s de espera
        skip_led_wait();
        check("Sistema reiniciou apos LEDs vermelhos (digitos = 0)",
              dut.fsm_inst.digits == 16'h0000);

        // =============================================================
        // TESTE 8: Independência das posições
        // =============================================================
        $display("\n[Teste 8] Independencia dos digitos por posicao");
        do_reset();

        // Digito 5 na posição 0
        repeat(5) press_btn(3'b010);                // 0→1→2→3→4→5
        check("Digito[0] = 5",
              dut.fsm_inst.digits[0] == 4'd5);

        press_btn(3'b001);                          // INC_POSITION: 0 → 1
        check("Digito[1] = 0 (nao foi alterado)",
              dut.fsm_inst.digits[1] == 4'd0);

        // Digito 7 na posição 1 (sem afetar posição 0)
        repeat(7) press_btn(3'b010);                // 0→1→…→7
        check("Digito[1] = 7",
              dut.fsm_inst.digits[1] == 4'd7);
        check("Digito[0] = 5 (inalterado apos editar posicao 1)",
              dut.fsm_inst.digits[0] == 4'd5);
        check("Digito[2] = 0 (nao foi alterado)",
              dut.fsm_inst.digits[2] == 4'd0);

        // =============================================================
        // TESTE 9: Verificar que digits permanecem em CURRENT_POSITION
        //          quando nenhum botão é pressionado
        // =============================================================
        $display("\n[Teste 9] Sem botao: estado estavel em CURRENT_POSITION");
        do_reset();

        repeat(10) @(posedge clk); // 10 ciclos sem pressionar nada
        check("Digitos inalterados sem botao pressionado",
              dut.fsm_inst.digits == 16'h0000);
        check("Posicao inalterada sem botao pressionado",
              dut.fsm_inst.current_position_idx == 2'b00);
        check("Sem LEDs vermelhos",  dut.led_red   == 18'h00000);
        check("Sem LEDs verdes",     dut.led_green == 9'h000);

        // =============================================================
        // Resultado final
        // =============================================================
        $display("\n================================================");
        $display("   RESULTADO FINAL: %0d / %0d testes passaram",
                 pass_cnt, test_num);
        if (fail_cnt == 0)
            $display("   TODOS OS TESTES PASSARAM!");
        else
            $display("   %0d TESTE(S) FALHARAM!", fail_cnt);
        $display("================================================");

        $stop;
    end

endmodule
