library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity CS_Controller_tb is
end CS_Controller_tb;

architecture sim of CS_Controller_tb is

    constant clk_hz    : integer := 100_000_000;
    constant sclk_hz   : integer := 25_000_000;
    constant data_size : integer := 8;
    constant cs_wait_cycles : integer := 6;

    signal clk           : std_logic := '0';
    signal rst           : std_logic := '1';
    signal start_CS      : std_logic := '0';
    signal miso          : std_logic := '0';
    signal cs_n          : std_logic := '1';

    signal transmit_data : std_logic_vector(data_size-1 downto 0) := (others => '0');
    signal s_clk         : std_logic;
    signal mosi          : std_logic;
    signal receive_data  : std_logic_vector(data_size-1 downto 0);
    signal spi_com_complete: std_logic;

begin

    -- DUT (Device Under Test)
    uut: entity work.CS_Controller
        generic map (
            clk_hz    => clk_hz,
            sclk_hz   => sclk_hz,
            data_size => data_size,
            cs_wait_cycles=> cs_wait_cycles
        )
        port map (
            clk           => clk,
            rst           => rst,
            start_CS      => start_CS,
            miso          => miso,
            transmit_data => transmit_data,
            cs_n          => cs_n,
            s_clk         => s_clk,
            mosi          => mosi,
            receive_data  => receive_data,
            spi_com_complete => spi_com_complete
        );

    -- 100 MHz clock generation
    clk_process : process
    begin
        while true loop
            clk <= '0';
            wait for 5 ns;
            clk <= '1';
            wait for 5 ns;
        end loop;
    end process;

    -- Test stimulus
    stim_proc: process
    begin
        -- Reset
        rst <= '1';
        wait for 20 ns;
        rst <= '0';
        wait for 20 ns;

        -- Veri yükle
        transmit_data <= "10101010";

        -- SPI başlat sinyali (1 clock süresinden uzun)
        start_CS <= '1';
        wait for 20 ns;
        start_CS <= '0';

        -- Transferin tamamlanmasını bekle
        wait until spi_com_complete = '1';
        wait for 10 ns;

        -- Sonuçları kontrol et
        assert receive_data = "11001101"
            report "MISO verisi beklenenle uyusmuyor!" severity warning;

        assert mosi = '0'
            report "MOSI hatti transfer sonrasi hala aktif" severity note;

        wait for 2 us;
        report "Test tamamlandi" severity note;
        wait;
    end process;

    -- MISO slave simülasyonu: düşen s_clk kenarında veri hazırlar
    miso_slave_proc : process
        variable miso_data : std_logic_vector(7 downto 0) := "11001101";
        variable bit_idx   : integer range 0 to 7;
    begin
        wait until rst = '0'; -- Reset bekleniyor
        wait until cs_n = '0'; -- CS aktif olunca başla

        bit_idx := 7;
        miso <= miso_data(bit_idx);

        for i in 1 to 7 loop
            wait until s_clk'event and s_clk = '0'; -- Saat sinyalinin düşen kenarını bekle
            bit_idx := bit_idx - 1;
            miso <= miso_data(bit_idx);
        end loop;

        wait until cs_n = '1'; -- Transfer ve bekleme bitince CS tekrar pasif olur
        miso <= '0'; -- Transfer sonrası MISO hattını sıfırla
        wait;
    end process;

end architecture;
