library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_spi_master is
end entity tb_spi_master;

architecture sim of tb_spi_master is

    -- Component declaration
    component spi_master
        generic (
            clk_hz  : integer := 100_000_000;
            sclk_hz : integer := 1_000_000;
            data_size: integer := 16
        );
        port (
            clk             : in  std_logic;
            rst             : in  std_logic;
            miso            : in  std_logic;
            transmit_data   : in  std_logic_vector (data_size-1 downto 0);
            start_com       : in  std_logic;
            cs_o            : out std_logic;
            s_clk           : out std_logic;
            mosi            : out std_logic;
            receive_data    : out std_logic_vector (data_size-1 downto 0);
            com_complete_o  : out std_logic
        );
    end component;

    -- Signals
    signal clk             : std_logic := '0';
    signal rst             : std_logic := '1';
    signal miso            : std_logic := '0';
    signal transmit_data   : std_logic_vector(15 downto 0) := (others => '0');
    signal start_com       : std_logic := '0';
    signal cs_o            : std_logic;
    signal s_clk           : std_logic;
    signal mosi            : std_logic;
    signal receive_data    : std_logic_vector(15 downto 0);
    signal com_complete_o  : std_logic;
  
    constant clk_period : time := 10 ns; -- 100 MHz

begin

    -- Instantiate SPI master
    uut: spi_master
        generic map (
            clk_hz => 100_000_000,
            sclk_hz => 1_000_000,
            data_size => 16
        )
        port map (
            clk => clk,
            rst => rst,
            miso => miso,
            transmit_data => transmit_data,
            start_com => start_com,
            cs_o => cs_o,
            s_clk => s_clk,
            mosi => mosi,
            receive_data => receive_data,
            com_complete_o => com_complete_o
        );

    -- Clock generation
    clk_process : process
    begin
        while true loop
            clk <= '0';
            wait for clk_period / 2;
            clk <= '1';
            wait for clk_period / 2;
        end loop;
    end process;

    -- Stimulus
    stim_proc: process
        variable miso_data : std_logic_vector(15 downto 0);
        variable bit_idx : integer;
    begin
        -- Reset
        rst <= '1';
        wait for 50 ns;
        rst <= '0';
        wait for 50 ns;

        -- Test 1: transmit 0xA5, receive 0x3C
        transmit_data <= x"A5A5";
        miso_data := "1100001111000011"; -- 0xC3
        start_com <= '1';
        wait for clk_period;
        start_com <= '0';

        bit_idx := 15;

        while bit_idx >= 0 loop
            -- SCLK falling edge bekle

            -- k???k bir gecikme ile MISO'yu s?r
            wait for 1 ns;
            miso <= miso_data(bit_idx);
			wait for 1 ns;

			wait until falling_edge(s_clk);
            bit_idx := bit_idx - 1;
        end loop;

        -- Communication complete bekle
        wait until com_complete_o = '1';

        -- Gelen veriyi kontrol et
        assert receive_data = x"C3C3"
        report "Test 1 Failed: Received data is not 0xC3C3" severity error;

        -- Test 2: transmit 0x5A, receive 0xC3
        wait for 1000 ns;
        transmit_data <= x"A5A5";
        miso_data := "0011110000111100"; -- 0x3C3C
        start_com <= '1';
        wait for clk_period;
        start_com <= '0';

        bit_idx := 15;

        while bit_idx >= 0 loop
            wait for 1 ns;
            miso <= miso_data(bit_idx);
            wait for 1 ns;

            wait until falling_edge(s_clk);
            
            bit_idx := bit_idx - 1;
        end loop;

        wait until com_complete_o = '1';

        assert receive_data = x"3C"
        report "Test 2 Failed: Received data is not 0x3C" severity error;

        -- Simulation done
        wait;
    end process stim_proc;

end architecture sim;
