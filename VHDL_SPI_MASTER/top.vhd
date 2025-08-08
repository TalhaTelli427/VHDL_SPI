library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top is
    generic (
        clk_hz         : integer := 100_000_000; -- Sistem saat frekansı
        sclk_hz        : integer := 1_000_000;   -- SPI saat frekansı
        data_size      : integer := 8;          -- Veri bit uzunluğu
        cs_wait_cycles : integer := 30           -- CS sonrası bekleme süresi (clk cycle)
    );
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;
        miso         : in  std_logic;
        send_message : in  std_logic;

        cs_o         : out std_logic;
        s_clk        : out std_logic;
        mosi         : out std_logic
    );
end entity top;

architecture Behavioral of top is

    -- Veri ve kontrol sinyalleri
    signal data_value        : integer range 0 to 255 := 0;
    signal transmit_data     : std_logic_vector(data_size-1 downto 0) := (others => '0');
    signal receive_data      : std_logic_vector(data_size-1 downto 0);
    signal start_CS          : std_logic := '0';
    signal send_message_prev : std_logic := '0';
    signal active            : std_logic := '0';

    -- CS_Controller’dan gelen tamamlanma sinyali
    signal spi_com_complete  : std_logic := '0';

    -- FSM kontrolü için durumlar (Nihai Hal)
    type fsm_state_type is (IDLE, LOAD_DATA, START_SPI, WAIT_COMPLETE, INTER_BYTE_DELAY);
    signal fsm_state : fsm_state_type := IDLE;

begin

    -- CS Controller instantiation
    uut: entity work.CS_Controller
        generic map (
            clk_hz         => clk_hz,
            sclk_hz        => sclk_hz,
            data_size      => data_size,
            cs_wait_cycles => cs_wait_cycles
        )
        port map (
            clk              => clk,
            rst              => rst,
            start_CS         => start_CS,
            miso             => miso,
            transmit_data    => transmit_data,
            cs_n             => cs_o,
            s_clk            => s_clk,
            mosi             => mosi,
            receive_data     => receive_data,
            spi_com_complete => spi_com_complete
        );

    process(clk, rst)
    begin
        if rst = '1' then
            fsm_state         <= IDLE;
            send_message_prev <= '0';
            active            <= '0';
            start_CS          <= '0';
            data_value        <= 0;
            transmit_data     <= (others => '0');
            
        elsif rising_edge(clk) then
            send_message_prev <= send_message;
            if (fsm_state = IDLE) and (send_message = '1' and send_message_prev = '0') then
                active <= '1';
            end if;

            start_CS <= '0';

            case fsm_state is
                when IDLE =>
                    if active = '1' then
                        transmit_data <= std_logic_vector(to_unsigned(data_value, data_size));
                        fsm_state     <= LOAD_DATA;
                    end if;

                when LOAD_DATA =>
                    start_CS  <= '1';
                    fsm_state <= START_SPI;

                when START_SPI =>
                    fsm_state <= WAIT_COMPLETE;
                
                when WAIT_COMPLETE =>
                    if spi_com_complete = '1' then
                        if data_value = 255 then
                            data_value <= 0;
                            active     <= '0'; 
                            fsm_state  <= IDLE;
                        else
                            data_value <= data_value + 1;
                            fsm_state  <= INTER_BYTE_DELAY;
                        end if;
                    end if;

                when INTER_BYTE_DELAY =>
                    fsm_state <= IDLE;
                
                when others =>
                    fsm_state <= IDLE;
            end case;
        end if;
    end process;

end architecture Behavioral;
