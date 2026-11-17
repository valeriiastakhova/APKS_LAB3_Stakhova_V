`timescale 1ns / 1ps

// ============================================================================
// Модуль: spi_slave_rx
// Опис:   Приймач (Slave) інтерфейсу SPI (Mode 0: CPOL=0, CPHA=0, 8 біт, MSB)
//         Використовує синхронізатори для надійного виявлення фронтів SCK
//         та CS_N у домені системного тактового сигналу clk.
// ============================================================================
module spi_slave_rx (
    // Системні сигнали
    input  wire       clk,         // Системний тактовий сигнал ПЛІС
    input  wire       rst_n,       // Асинхронний скид (активний низький рівень '0')
    
    // Інтерфейс користувача
    input  wire [7:0] tx_data,     // Байт, який Slave відправить у відповідь по MISO
    output reg  [7:0] rx_data,     // Прийнятий від Master 8-бітний пакет
    output reg        rx_valid,    // Імпульс валідності прийнятого байта (на 1 такт clk)
    
    // Фізичні лінії інтерфейсу SPI
    input  wire       sck,         // Вхідний тактовий сигнал від Master
    input  wire       mosi,        // Вхід даних від Master
    output reg        miso,        // Вихід даних до Master
    input  wire       cs_n         // Сигнал вибору кристала від Master (активний '0')
);

    // Багатокаскадні регістри для синхронізації зовнішніх асинхронних сигналів SPI
    reg [2:0] sck_sync;
    reg [2:0] cs_sync;
    reg [1:0] mosi_sync;

    // Внутрішні зсувні регістри та лічильник бітів
    reg [7:0] rx_shift;
    reg [7:0] tx_shift;
    reg [2:0] bit_cnt;

    // Детектування станів та фронтів сигналів SPI
    wire cs_active   = ~cs_sync[1];                 // Активний рівень CS_N == 0
    wire cs_falling  = (cs_sync[2:1] == 2'b10);     // Початок передачі (спад CS_N)
    wire sck_rising  = (sck_sync[2:1] == 2'b01);    // Передній фронт SCK (читаємо MOSI)
    wire sck_falling = (sck_sync[2:1] == 2'b10);    // Задній фронт SCK (зсуваємо MISO)

    // Синхронізація вхідних ліній шини SPI із системним тактовим сигналом clk
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sck_sync  <= 3'b000;
            cs_sync   <= 3'b111;
            mosi_sync <= 2'b00;
        end else begin
            sck_sync  <= {sck_sync[1:0], sck};
            cs_sync   <= {cs_sync[1:0], cs_n};
            mosi_sync <= {mosi_sync[0], mosi};
        end
    end

    // Логіка прийому (з MOSI) та передачі (на MISO)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_shift <= 8'd0;
            tx_shift <= 8'd0;
            rx_data  <= 8'd0;
            rx_valid <= 1'b0;
            bit_cnt  <= 3'd0;
            miso     <= 1'b0;
        end else begin
            rx_valid <= 1'b0;

            if (cs_falling) begin
                // Початок нової транзакції: готуємо дані для відправки по MISO
                tx_shift <= tx_data;
                miso     <= tx_data[7]; // Виставляємо старший біт на MISO одразу
                bit_cnt  <= 3'd0;
                rx_shift <= 8'd0;
            end else if (cs_active) begin
                if (sck_rising) begin
                    // По наростаючому фронту SCK фіксуємо біт із лінії MOSI
                    rx_shift <= {rx_shift[6:0], mosi_sync[1]};

                    if (bit_cnt == 3'd7) begin
                        // Прийнято останній (8-й) біт байта
                        rx_data  <= {rx_shift[6:0], mosi_sync[1]};
                        rx_valid <= 1'b1;
                        bit_cnt  <= 3'd0;
                    end else begin
                        bit_cnt  <= bit_cnt + 1'b1;
                    end
                end else if (sck_falling) begin
                    // По спадаючому фронту SCK виставляємо наступний біт відповіді на MISO
                    tx_shift <= {tx_shift[6:0], 1'b0};
                    miso     <= tx_shift[6];
                end
            end else begin
                // Коли CS_N == 1, приймач перебуває у режимі очікування
                miso    <= 1'b0;
                bit_cnt <= 3'd0;
            end
        end
    end

endmodule