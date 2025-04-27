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
        transmit_data   : in  std_logic_vector (7 downto 0);
        start_com       : in  std_logic;

        cs_o            : out std_logic;
        s_clk           : out std_logic;
        mosi            : out std_logic;
        receive_data    : out std_logic_vector (7 downto 0);
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

    signal buffer_r      : std_logic_vector (data_size-1 downto 0) := (others => '0');
    signal r_complete    : std_logic := '0';
    signal r_buf_cnt     : integer range 0 to data_size-1 := data_size-1;

    signal internal_com_complete : std_logic := '0';
    signal com_complete_r_reg  : std_logic := '0';

begin

    start_ctrl : process (clk, rst)
    begin
        if rst = '1' then
            clk_enable <= '0';
            cs_o <= '1';
            buffer_t <= (others => '0');
        elsif rising_edge(clk) then
            if start_com = '1' then
                clk_enable <= '1';
                cs_o <= '0';
                buffer_t <= transmit_data;
            elsif internal_com_complete = '1' then 
                clk_enable <= '0';
                cs_o <= '1';
            end if;
        end if;
    end process start_ctrl;


    sclk_generator : process (clk, rst)
    begin
        if rst = '1' then
            clk_counter   <= 0;
            s_rise_edge   <= '0';
            s_fall_edge   <= '0';
            clk_s         <= '0';
        elsif rising_edge(clk) then
            if clk_enable = '1' then
                if clk_counter = half_clk_count * 2 - 1 then
                    clk_s         <= not clk_s;
                    clk_counter   <= 0;
                    s_rise_edge   <= '0';
                    s_fall_edge   <= '1';

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
            end if;
        end if;
    end process sclk_generator;

    miso_p : process (clk, rst)
    begin
        if rst = '1' then
            r_complete <= '0';
            r_buf_cnt <= data_size-1;
            buffer_r <= (others => '0');
            receive_data<= (others => '0');
        elsif rising_edge(clk) then
            if r_buf_cnt = 0 then
                r_complete <= '1';
                receive_data <= buffer_r;
                r_buf_cnt<=data_size-1;
            elsif s_rise_edge = '1' then
                r_complete <= '0';
                buffer_r(r_buf_cnt) <= miso;
                r_buf_cnt <= r_buf_cnt - 1;
            end if;
        end if;
    end process miso_p;


    mosi_p : process (clk, rst)
    begin
        if rst = '1' then
            t_complete <= '0';
            t_buf_cnt <= data_size-1;
            mosi <= '0';
        elsif rising_edge(clk) then
            if clk_enable = '1' then
                t_complete <= '0';
                mosi <= buffer_t(t_buf_cnt);
                if s_fall_edge = '1' then
                    if t_buf_cnt = 0 then
                        t_buf_cnt <= data_size-1;
                        t_complete <= '1';
                    else
                        t_buf_cnt <= t_buf_cnt - 1;
                    end if;
                end if;
            end if;
        end if;
    end process mosi_p;

    complete_com : process (clk, rst)
    begin
        if rst = '1' then
            internal_com_complete <= '0';
            com_complete_r_reg <= '0';
        elsif rising_edge(clk) then
            if t_complete = '1' and r_complete = '1' then
                internal_com_complete <= '1';
            else
                internal_com_complete <= '0';
            end if;
            com_complete_r_reg <= internal_com_complete; 
        end if;
    end process complete_com;


    s_clk <= clk_s;
    com_complete_o <= com_complete_r_reg;

end architecture Behavioral;