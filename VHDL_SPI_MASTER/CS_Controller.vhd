library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity CS_Controller is
    generic (
        clk_hz         : integer := 100_000_000;
        sclk_hz        : integer := 1_000_000;
        data_size      : integer := 8;
        cs_wait_cycles : integer := 20 -- bekleme süresi (clock cinsinden)
    );
    port (
        clk             : in  std_logic;
        rst             : in  std_logic;
        start_CS        : in  std_logic;
        miso            : in  std_logic;
        transmit_data   : in  std_logic_vector(data_size-1 downto 0);

        cs_n            : out std_logic;
        s_clk           : out std_logic;
        mosi            : out std_logic;
        receive_data    : out std_logic_vector(data_size-1 downto 0);
        spi_com_complete  : out std_logic
    );
end CS_Controller;

architecture rtl of CS_Controller is

    type state_type is (IDLE, WAIT_BEFORE, SPI_RUN, WAIT_AFTER);
    signal state : state_type := IDLE;

    signal cs_n_int           : std_logic := '1';
    signal com_complete_o     : std_logic := '0';

    signal wait_counter       : integer range 0 to cs_wait_cycles := 0;

    signal s_clk_int          : std_logic := '0';
    signal mosi_int           : std_logic := '0';
    signal receive_data_int   : std_logic_vector(data_size-1 downto 0) := (others => '0');

    signal start_spi_pulse    : std_logic := '0';
    signal spi_com_complete_int : std_logic := '0';

begin

    process(clk, rst)
    begin
        if rst = '1' then
            state <= IDLE;
            cs_n_int <= '1';
            wait_counter <= 0;
            start_spi_pulse <= '0';
            spi_com_complete_int <= '0';
        elsif rising_edge(clk) then
            -- Default pulse sinyalleri
            start_spi_pulse <= '0';
            spi_com_complete_int <= '0';

            case state is
                when IDLE =>
                    cs_n_int <= '1';
                    wait_counter <= 0;
                    if start_CS = '1' then
                        state <= WAIT_BEFORE;
                    end if;

                when WAIT_BEFORE =>
                    cs_n_int <= '0';
                    if wait_counter < cs_wait_cycles then
                        wait_counter <= wait_counter + 1;
                    else
                        wait_counter <= 0;
                        start_spi_pulse <= '1'; -- Sadece 1 clock pulse!
                        state <= SPI_RUN;
                    end if;

                when SPI_RUN =>
                    cs_n_int <= '0';
                    if com_complete_o = '1' then
                        state <= WAIT_AFTER;
                        wait_counter <= 0;
                    end if;

                when WAIT_AFTER =>
                    cs_n_int <= '0';
                    if wait_counter < cs_wait_cycles then
                        wait_counter <= wait_counter + 1;
                    else
                        wait_counter <= 0;
                        spi_com_complete_int <= '1'; -- Sadece 1 clock pulse!
                        state <= IDLE;
                    end if;

                when others =>
                    state <= IDLE;
            end case;
        end if;
    end process;

    -- Çıkış atamaları
    cs_n         <= cs_n_int;
    s_clk        <= s_clk_int;
    mosi         <= mosi_int;
    receive_data <= receive_data_int;
    spi_com_complete <= spi_com_complete_int;

    -- SPI Master instantiation
    spi_master_inst: entity work.ent
        generic map (
            clk_hz    => clk_hz,
            sclk_hz   => sclk_hz,
            data_size => data_size
        )
        port map (
            clk            => clk,
            rst            => rst,
            start_spi      => start_spi_pulse,
            miso           => miso,
            transmit_data  => transmit_data,
            s_clk          => s_clk_int,
            mosi           => mosi_int,
            receive_data   => receive_data_int,
            com_complete_o => com_complete_o
        );

end rtl;
