library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity SPI_Master_V2_tb is
end SPI_Master_V2_tb;

architecture sim of SPI_Master_V2_tb is

    constant clk_hz    : integer := 100_000_000;
    constant sclk_hz   : integer := 25_000_000;
    constant data_size : integer := 8;

    signal clk           : std_logic := '0';
    signal rst           : std_logic := '1';
    signal start_spi     : std_logic := '0';
    signal miso          : std_logic := '0';
    signal transmit_data : std_logic_vector(data_size-1 downto 0) := (others => '0');
    signal s_clk         : std_logic;
    signal mosi          : std_logic;
    signal receive_data  : std_logic_vector(data_size-1 downto 0);
    signal com_complete_o: std_logic;

begin

    -- DUT (Device Under Test)
    uut: entity work.ent
        generic map (
            clk_hz    => clk_hz,
            sclk_hz   => sclk_hz,
            data_size => data_size
        )
        port map (
            clk           => clk,
            rst           => rst,
            start_spi     => start_spi,
            miso          => miso,
            transmit_data => transmit_data,
            s_clk         => s_clk,
            mosi          => mosi,
            receive_data  => receive_data,
            com_complete_o=> com_complete_o
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
        start_spi <= '1';
        wait for 20 ns;
        start_spi <= '0';

        -- Transferin tamamlanmasını bekle
        wait until com_complete_o = '1';
        wait for 30 ns;
        
        
        -- Veri yükle
        transmit_data <= "11110000";

        -- SPI başlat sinyali (1 clock süresinden uzun)
        start_spi <= '1';
        wait for 20 ns;
        start_spi <= '0';

        -- Transferin tamamlanmasını bekle
        wait until com_complete_o = '1';
        wait for 10 ns;
 -- Veri yükle
        transmit_data <= "00011100";

        -- SPI başlat sinyali (1 clock süresinden uzun)
        start_spi <= '1';
        wait for 20 ns;
        start_spi <= '0';
        wait for 50 ns;
        rst <= '1';
        wait for 20 ns;
        rst <= '0';
        wait for 20 ns;

   
        -- Transferin tamamlanmasını bekle
        wait until com_complete_o = '1';
        wait for 10 ns;
        -- Sonuçları kontrol et
        assert receive_data = "11001101"
            report "MISO verisi beklenenle uyusmuyor!" severity warning;

        -- MOSI sonunda 0 olabilir, ama garanti değil - o yüzden istersen bu kontrolü kaldır
        assert mosi = '0'
            report " MOSI hatti transfer sonrasi hala aktif" severity note;

        -- Bitir
        wait for 2 us;
        report "Test tamamlandi" severity note;
        wait;
    end process;

    -- MISO slave simülasyonu: düşen s_clk kenarında veri hazırlar
miso_slave_proc : process
    variable caunter : integer range 0 to 4:=0; 
    variable miso_data : std_logic_vector(7 downto 0) := "11111101";
    variable bit_idx   : integer range 0 to 7;
begin
        if(caunter=0)then
            miso_data:="11111101";
            
        elsif(caunter=1) then
          miso_data:="10101010";
      
        elsif(caunter=2) then
            miso_data:="10000001";

        end if;

    --wait until rst = '0'; -- Reset bekleniyor
    wait until start_spi = '1'; -- SPI başlangıç sinyali bekleniyor
    wait until start_spi = '0'; -- SPI başlangıç sinyalinin düşen kenarı bekleniyor

    -- Her transfer için bit_idx'i sıfırla
    bit_idx := 7; 

    -- İlk biti, ilk saat kenarı gelmeden önce MISO hattına koy
    -- Bu, Master'ın ilk saat kenarında bu biti örnekleyebilmesini sağlar.
    miso <= miso_data(bit_idx);

    -- Kalan 7 bit için döngü
    -- (bit_idx = 6'dan 0'a kadar olan bitler)
    for i in 1 to 7 loop 
        wait until s_clk'event and s_clk = '0'; -- Saat sinyalinin düşen kenarını bekle
         bit_idx := bit_idx - 1;
        miso <= miso_data(bit_idx);
    end loop;
    wait until com_complete_o='1';
    caunter:=caunter+1;
    miso <= '0'; -- Transfer sonrası MISO hattını sıfırla (varsayılan duruma getir)
    --wait; -- Sürecin askıya alınması
end process;

end architecture;