library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity spi_master is
    generic (
        clk_hz  : integer := 100_000_000;
        sclk_hz : integer := 1_000_000;
        data_size:integer :=8
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
end entity spi_master;

architecture Behavioral of spi_master is

    constant half_clk_count : integer := clk_hz / (sclk_hz * 2);
    signal clk_idle      : std_logic := '0';
    signal clk_enable    : std_logic := '0';
    signal clk_counter   : integer range 0 to half_clk_count * 2 := 0;
    signal s_rise_edge   : std_logic := '0';
    signal s_fall_edge   : std_logic := '0';
    signal clk_s         : std_logic := '0';

    signal buffer_t      : std_logic_vector (data_size-1 downto 0) := (others => '0');
    signal t_buf_cnt     : integer range 0 to data_size-1 :=data_size-1;
    signal t_complete    : std_logic := '0';
	signal clk_step	 : integer range 0 to (data_size*2) := 0;
    
    signal r_buf_cnt     : integer range 0 to data_size-1 := data_size-1;

    signal internal_com_complete : std_logic := '0';
    signal r_buffer          :std_logic_vector(data_size-1 downto 0 );
begin


    

cs_controller: process(clk,rst) begin
        if rst = '1' then
            cs_o <= '1'; 
            
        elsif rising_edge(clk) then
            if(clk_enable ='1')then
                cs_o <= '0';
            elsif(t_complete ='1')then
                   cs_o <= '1'; 
        
    end if;
    end if;
end process cs_controller;


    sclk_generator : process (clk, rst)
    begin
        if rst = '1' then
            clk_counter   <= 0;
            s_rise_edge   <= '0';
            s_fall_edge   <= '0';
            clk_s         <= '0';
			t_complete <= '0';
			clk_step <= 0;
			clk_enable <= '0';
            buffer_t <= (others => '0');

        elsif rising_edge(clk) then
            if clk_enable = '1' then
                if clk_counter = half_clk_count * 2 - 1 then
                    clk_s         <= not clk_s;
                    clk_counter   <= 0;
                    s_rise_edge   <= '0';
                    s_fall_edge   <= '1';
					clk_step <= clk_step+1;

                elsif clk_counter = half_clk_count - 1 then
                    clk_s         <= not clk_s;
                    s_rise_edge   <= '1';
                    s_fall_edge   <= '0';
                    clk_counter   <= clk_counter + 1;

                else
                    clk_counter   <= clk_counter + 1;
                    s_rise_edge   <= '0';
                    s_fall_edge   <= '0';
                end if;
            else
                clk_s         <= clk_idle;
                clk_counter   <= 0;
                s_rise_edge   <= '0';
                s_fall_edge   <= '0';
				clk_step <=  0;
				t_complete <= '0';
				buffer_t<=(others => '0');
                clk_enable<='0';
            end if;
			if(clk_step = data_size ) then
                clk_enable <= '0';
                t_complete<='1';
        elsif start_com = '1' then
                clk_enable <= '1';
                buffer_t <= transmit_data;

			end if;
        end if;
    end process sclk_generator;

miso_p : process (clk, rst)
begin
    if rst = '1' then
        r_buf_cnt <= data_size-1;
        receive_data <= (others => '0');
    elsif rising_edge(clk) then
        
        if clk_enable = '1' then
            if s_rise_edge = '1' then
                receive_data(r_buf_cnt) <= miso;
                
                if r_buf_cnt = 0 then
                    r_buf_cnt <= data_size-1;
                else
                    r_buf_cnt <= r_buf_cnt - 1;
                end if;
            end if;
        end if;
        if(internal_com_complete='1') then
           receive_data <= (others => '0');
        end if;
    end if;
end process;


    mosi_p : process (clk, rst)
    begin
        if rst = '1' then
        mosi<='0';
        t_buf_cnt <= data_size-1;
        elsif rising_edge(clk) then
           
            if clk_enable = '1' then
                mosi <= buffer_t(t_buf_cnt);
                 end if;
                if(s_fall_edge='1' and t_buf_cnt > 0) then
                t_buf_cnt <= t_buf_cnt - 1;

            end if;
            if t_complete = '1'  then
                       mosi<='0';
                end if;
            if( start_com ='1')then
              t_buf_cnt <= data_size-1;
              end if;
        end if;
    end process mosi_p;
    
      complete_com : process (clk, rst)
    begin
        if rst = '1' then
            internal_com_complete <= '0';
            com_complete_r_reg <= '0';
        elsif rising_edge(clk) then
            if t_complete = '1'  then
                internal_com_complete <= '1';
            else
                internal_com_complete <= '0';
            end if;
            --com_complete_r_reg <= internal_com_complete; 
        end if;
    end process complete_com;



    process(clk)begin
    if rising_edge(clk) then
    s_clk <= clk_s;
    end if;
    end process;
    com_complete_o <= internal_com_complete;
end architecture Behavioral;

