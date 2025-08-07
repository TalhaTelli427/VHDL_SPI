library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ent is
    generic (
        clk_hz      : integer := 100_000_000;
        sclk_hz     : integer := 5_000_000;
        data_size   : integer := 8
    );
    port (
        clk             : in  std_logic;
        rst             : in  std_logic;
        start_spi       : in  std_logic;
        miso            : in  std_logic;
        transmit_data   : in  std_logic_vector(data_size-1 downto 0);

        s_clk           : out std_logic;
        mosi            : out std_logic;
        receive_data    : out std_logic_vector(data_size-1 downto 0);
        com_complete_o  : out std_logic
    );
end ent;

architecture rtl of ent is

    constant half_clk_count : integer := clk_hz / (sclk_hz * 2);

    signal clk_enable        : std_logic := '0';
    signal clk_counter       : integer range 0 to half_clk_count := 0;
    signal edge_counter      : integer range 0 to (data_size * 2) := 0;

    signal T_Data_counter    : integer range 0 to data_size := data_size-1;
    signal R_Data_counter    : integer range 0 to data_size := data_size-1;

    signal sclk_prev         : std_logic := '0';
    signal buf_s_clk         : std_logic := '0';
    signal rx_reset_cnt      :std_logic  :='0';
    type edge_type is (NONE, POS_EDGE, NEG_EDGE);
    signal edge_state        : edge_type := NONE;
    signal reg_com_complete_o : std_logic := '0';
    signal reg_com_complete_o_1 : std_logic := '0';
    signal reg_com_complete_o_2 : std_logic := '0';
	signal buf_s_clk_1          : std_logic :='0'; 
    signal  buf_recieve_data : std_logic_vector (data_size-1 downto 0);
    signal  buf_transmit_data : std_logic_vector (data_size-1 downto 0);

    signal start_spi_sync1 : std_logic := '0';
    signal start_spi_sync2 : std_logic := '0';
    signal start_spi_synced_pulse : std_logic := '0'; 

begin
	
    
    
    Start_SPI_Synchronizer_PROC : process(clk, rst)
    begin
        if rst = '1' then
            start_spi_sync1 <= '0';
            start_spi_sync2 <= '0';
            start_spi_synced_pulse <= '0';
        elsif rising_edge(clk) then
            start_spi_sync1 <= start_spi;
            start_spi_sync2 <= start_spi_sync1;

            if start_spi_sync2 = '1' and start_spi_sync1 = '0' then
              start_spi_synced_pulse <= '1';
            else
              start_spi_synced_pulse <= '0';
            end if;
        end if;
    end process;
   
    Enabler_PROC : process(clk, rst)
    begin
        if rst = '1' then
            clk_enable <= '0';
            reg_com_complete_o <= '0';
            buf_transmit_data<= (others => '0');
        elsif rising_edge(clk) then
            if start_spi_synced_pulse = '1' then
                buf_transmit_data<=transmit_data;
                clk_enable <= '1';
                reg_com_complete_o <= '0';
            elsif edge_counter = (data_size * 2) then
                clk_enable <= '0';
                reg_com_complete_o_2<='1';
                reg_com_complete_o_1 <= reg_com_complete_o_2;
                reg_com_complete_o<=reg_com_complete_o_1;
            	buf_transmit_data<= (others => '0');
            else
                reg_com_complete_o_2 <= '0';
                reg_com_complete_o_1 <= reg_com_complete_o_2;
                reg_com_complete_o<=reg_com_complete_o_1;

            end if;
        end if;
    end process;

	

    
    -- SPI saat üretimi
    Sclk_Generator_PROC : process(clk, rst)
    begin
        if rst = '1' then
            clk_counter <= 0;
            edge_counter <= 0;
            buf_s_clk <= '0';
        elsif rising_edge(clk) then
            if clk_enable = '1' then
                if clk_counter = half_clk_count - 1 then
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


Sclk_Edge_Detector_PROC : process(clk, rst)
begin
    if rst = '1' then
        sclk_prev <= '0';
        edge_state <= NONE;
    elsif rising_edge(clk) then
        if (sclk_prev = '0' and buf_s_clk = '1') then
            edge_state <= POS_EDGE;
        elsif (sclk_prev = '1' and buf_s_clk = '0') then
            edge_state <= NEG_EDGE;
        else
            edge_state <= NONE;
        end if;
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
                    mosi <= buf_transmit_data(data_size-1);
                    T_Data_counter <= data_size - 2;
                elsif edge_state = NEG_EDGE then
                    mosi <= buf_transmit_data(T_Data_counter);
                    if T_Data_counter > 0 then
                        T_Data_counter <= T_Data_counter - 1;
                    end if;
                end if;
            else
                mosi <= '0';
                T_Data_counter <= data_size-1;
            end if;
        end if;
    end process;

MISO_PROC : process(clk, rst)
begin
    if rst = '1' then
        receive_data <= (others => '0');
        buf_recieve_data<= (others => '0');
        R_Data_counter <= data_size - 1;
        
    elsif rising_edge(clk) then
        if(start_spi_sync2 = '1' and start_spi_sync1 = '0') then
            
              buf_recieve_data<= (others => '0');
              receive_data <= (others => '0');
              
            end if;

        if clk_enable = '1' then
            if edge_state = POS_EDGE then
                buf_recieve_data(R_Data_counter) <= miso;
                if R_Data_counter > 0 then
                    R_Data_counter <= R_Data_counter - 1;
                end if;
            end if;
        else
            receive_data<=buf_recieve_data;
            R_Data_counter <= data_size - 1; 
        end if;
    end if;
end process;

  SPI_Clock : process (clk, rst)
  begin
    if rst = '1' then
    com_complete_o<='0';
      s_clk  <= '0';
      buf_s_clk_1<='0';
    elsif rising_edge(clk) then
        buf_s_clk_1 <= buf_s_clk;
        s_clk<=buf_s_clk_1;
        com_complete_o <= reg_com_complete_o;
   
    end if;
  end process SPI_Clock;

   end architecture;