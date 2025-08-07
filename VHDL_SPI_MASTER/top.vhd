library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top is
    generic (
        clk_hz         : integer := 100_000_000;
        sclk_hz        : integer := 25_000_000;
        data_size      : integer := 8;
        cs_wait_cycles : integer := 20
    );
    port (
        clk             : in  std_logic;
        rst             : in  std_logic;
        miso            : in  std_logic;
        send_message    : in  std_logic;

        cs_o            : out std_logic;
        s_clk           : out std_logic;
        mosi            : out std_logic
    );
end entity top;

architecture Behavioral of top is

    -- Sabit veri
    signal  data : integer range 0 to 255 :=0;

    -- Dahili sinyaller
    signal transmit_data        : std_logic_vector(data_size-1 downto 0) := (others => '0');
    signal receive_data         : std_logic_vector(data_size-1 downto 0);
    signal start_CS             : std_logic := '0';
    signal send_message_prew    : std_logic := '0';

begin

    -- CS_Controller instantiate
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
            receive_data     => receive_data
        );

    -- Transmit verisi sabit atanıyor
    data_load: process(clk, rst)
    begin
        if rst = '1' then
            transmit_data <= (others => '0');
        elsif rising_edge(clk) then
            transmit_data <= std_logic_vector(TO_UNSIGNED(data,8));
        end if;
    end process;

    -- Start_CS tetiklemesi (rising edge detect)
    com_starter: process(clk, rst)
    begin
        if rst = '1' then
            start_CS <= '0';
            send_message_prew <= '0';
            data<=0;
        elsif rising_edge(clk) then
            send_message_prew <= send_message;
            if (send_message = '1' and send_message_prew = '0') then
                if(data= 255) then
                    data <= 00;
                    else 
                    data <=data+1;
                end if;
                start_CS <= '1'; -- sadece 1 clk tetikleme


            else
                start_CS <= '0';
            end if;
        end if;
    end process;

end architecture Behavioral;
