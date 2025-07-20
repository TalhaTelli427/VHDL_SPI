library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity ent is
    generic (
    clk_hz  : integer := 100_000_000;
    sclk_hz : integer := 1_000_000;
    data_size:integer :=8;
 );

    port (
        clk : in std_logic;
        rst : in std_logic;
        start_spi : in std_logic;
        miso            : in  std_logic;
        transmit_data   : in  std_logic_vector (data_size-1 downto 0);

        s_clk           : out std_logic;
        mosi            : out std_logic;
        receive_data    : out std_logic_vector (data_size-1 downto 0);
        com_complete_o  : out std_logic


        
    );
end ent;

architecture rtl of ent is

    constant half_clk_count : integer := clk_hz / (sclk_hz * 2);
    signal clk_enable    : std_logic := '0';
    signal clk_counter   : integer range 0 to half_clk_count * 2 := 0;
    signal edge_counter  : integer range 0 to (data_size*2):=0;
    signal T_Data_counter : integer range 0 to data_size :==data_size-1;
    signal R_Data_counter : integer range 0 to data_size :==data_size-1;

    signal sclk_prev : std_logic := '0';
    type edge_type is (NONE, POS_EDGE, NEG_EDGE);
    signal edge_state : edge_type := NONE;
    signal buf_s_clk : std_logic :=0; 
    signal reg_com_complete_o : std_logic := '0';
begin
 
    Enabler_PROC : process(clk, rst)
    begin
       if rst = '1' then
        clk_enable <= '0';
        reg_com_complete_o <= '0';
    elsif rising_edge(clk) then
        if start_spi = '1' then
            clk_enable <= '1';
            reg_com_complete_o <= '0';
            T_Data_counter <= data_size-1;
            R_Data_counter <= data_size-1;
        elsif edge_counter = (data_size*2) then 
            clk_enable <= '0';
            reg_com_complete_o <= '1'; -- Haberleşme bitti
        else
            reg_com_complete_o <= '0'; -- Transfer devam ediyor
        end if;
    end if;
    end process;

    com_complete_o <= reg_com_complete_o;

    Sclk_Generator_PROC : process(clk, rst)
    begin
        if rst = '1' then
            clk_counter <= 0;
            edge_counter <= 0;
            buf_s_clk <= '0';
        elsif rising_edge(clk) then
            if clk_enable = '1' then
                if clk_counter = half_clk_count-1 then
                    buf_s_clk <= not buf_s_clk;
                    clk_counter <= 0;
                    edge_counter <= edge_counter + 1;
                else
                    clk_counter <= clk_counter + 1;
                end if;
            else
                clk_counter <= 0;
                edge_counter <= 0;
                buf_s_clk <= '0';
            end if;
        end if;
    end process;
    sclk <= buf_s_clk;
    -- Edge detector process
    Sclk_Edge_Detector_PROC : process(clk, rst)
    begin
        if rst = '1' then
            sclk_prev <= '0';
            edge_state <= NONE;
        elsif rising_edge(clk) then
            case (sclk_prev & buf_s_clk) is
                when "01" => edge_state <= POS_EDGE; 
                when "10" => edge_state <= NEG_EDGE; 
                when others => edge_state <= NONE;
            end case;
            sclk_prev <= buf_s_clk;
        end if;
    end process;

    MOSI_PROC : process(clk, rst)
    begin
        if rst = '1' then
            mosi <= '0';         
            T_Data_counter <= data_size-1;
        elsif rising_edge(clk) then
            if clk_enable = '1' then
                if edge_counter = 0 then
                    -- İlk bit, transfer başlarken
                    mosi <= transmit_data(data_size-1);
                    T_Data_counter <= data_size-2;
                elsif edge_state = NEG_EDGE then
                    -- Her düşen kenarda sıradaki bit
                    mosi <= transmit_data(T_Data_counter);
                    T_Data_counter <= T_Data_counter - 1;
                end if;
            else
                T_Data_counter <= data_size-1;
                mosi <= '0';
            end if;
        end if;
    end process;

    MISO_PROC : process(clk, rst)
    begin
        if rst = '1' then
            receive_data <= (others => '0');
            R_Data_counter <= data_size-1;
        elsif rising_edge(clk) then
            if clk_enable = '1' then
                if edge_state = POS_EDGE then
                    receive_data(R_Data_counter) <= miso;
                    R_Data_counter <= R_Data_counter - 1;
                end if;
            else
                R_Data_counter <= data_size-1;
            end if;
        end if;
    end process;


end architecture;
