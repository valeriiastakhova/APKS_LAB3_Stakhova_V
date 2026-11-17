`timescale 1ns / 1ps

// ============================================================================
// Модуль: tb_spi
// Опис:   Testbench для функціональної верифікації повнодуплексного обміну SPI
//         між модулями spi_master_tx (Tx) та spi_slave_rx (Rx).
// ============================================================================
module tb_spi;

    // Параметри симуляції
    localparam CLK_PERIOD = 10; // Період тактового сигналу 10 нс (100 МГц)
    localparam CLK_DIV    = 8;  // Частота SCK = 100 МГц / 16 = 6.25 МГц

    // Сигнали тактування та скидання
    reg        clk;
    reg        rst_n;

    // Сигнали керування Master (Tx)
    reg        start;
    reg  [7:0] master_tx_data;
    wire [7:0] master_rx_data;
    wire       busy;
    wire       done;

    // Сигнали керування Slave (Rx)
    reg  [7:0] slave_tx_data;
    wire [7:0] slave_rx_data;
    wire       rx_valid;

    // Фізичні лінії шини SPI, що з'єднують Master та Slave
    wire       sck;
    wire       mosi;
    wire       miso;
    wire       cs_n;

    // Екземпляр передавача (SPI Master)
    spi_master_tx #(
        .CLK_DIV(CLK_DIV)
    ) uut_master (
        .clk     (clk),
        .rst_n   (rst_n),
        .start   (start),
        .tx_data (master_tx_data),
        .rx_data (master_rx_data),
        .busy    (busy),
        .done    (done),
        .sck     (sck),
        .mosi    (mosi),
        .miso    (miso),
        .cs_n    (cs_n)
    );

    // Екземпляр приймача (SPI Slave)
    spi_slave_rx uut_slave (
        .clk      (clk),
        .rst_n    (rst_n),
        .tx_data  (slave_tx_data),
        .rx_data  (slave_rx_data),
        .rx_valid (rx_valid),
        .sck      (sck),
        .mosi     (mosi),
        .miso     (miso),
        .cs_n     (cs_n)
    );

    // Генератор системного тактового сигналу (100 МГц)
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // Сценарій тестування
    initial begin
        // Ініціалізація сигналів
        rst_n          = 1'b0;
        start          = 1'b0;
        master_tx_data = 8'h00;
        slave_tx_data  = 8'h00;

        // Утримуємо скидання протягом 5 тактів
        #(CLK_PERIOD * 5);
        rst_n = 1'b1;
        #(CLK_PERIOD * 5);

        // --------------------------------------------------------------------
        // ТЕСТ 1: Повнодуплексний обмін (Master: 0xA5 <-> Slave: 0x3C)
        // --------------------------------------------------------------------
        master_tx_data = 8'hA5; // Двійковий код: 1010_0101
        slave_tx_data  = 8'h3C; // Двійковий код: 0011_1100

        @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        // Очікуємо завершення транзакції від Master
        wait (done == 1'b1);
        #(CLK_PERIOD * 5);

        // Автоматична перевірка результатів першої транзакції
        if (slave_rx_data === 8'hA5 && master_rx_data === 8'h3C) begin
            $display("[PASS] Тест 1 пройдено! Slave отримав 0x%h, Master отримав 0x%h",
                     slave_rx_data, master_rx_data);
        end else begin
            $display("[FAIL] Тест 1 провалено! Очікувалось Slave=0xA5, Master=0x3C. Отримано: Slave=0x%h, Master=0x%h",
                     slave_rx_data, master_rx_data);
        end

        #(CLK_PERIOD * 10);

        // --------------------------------------------------------------------
        // ТЕСТ 2: Повторний обмін іншими даними (Master: 0x5A <-> Slave: 0xC3)
        // --------------------------------------------------------------------
        master_tx_data = 8'h5A; // Двійковий код: 0101_1010
        slave_tx_data  = 8'hC3; // Двійковий код: 1100_0011

        @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        wait (done == 1'b1);
        #(CLK_PERIOD * 5);

        if (slave_rx_data === 8'h5A && master_rx_data === 8'hC3) begin
            $display("[PASS] Тест 2 пройдено! Slave отримав 0x%h, Master отримав 0x%h",
                     slave_rx_data, master_rx_data);
        end else begin
            $display("[FAIL] Тест 2 провалено! Очікувалось Slave=0x5A, Master=0xC3. Отримано: Slave=0x%h, Master=0x%h",
                     slave_rx_data, master_rx_data);
        end

        #(CLK_PERIOD * 10);
        $display("Симуляцію успішно завершено.");
        $finish;
    end

endmodule