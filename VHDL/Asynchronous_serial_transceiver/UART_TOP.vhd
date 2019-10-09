----------------------------------------------------------------------------------
-- Create Date: 2019/09/24 16:38:01
-- Module Name: UART_TOP - Behavioral
-- Description: 
--   an asynchronous serial transceiver
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity UART_TOP is
    Port ( 
           Rst_n  : in STD_LOGIC;
           Clk_in : in STD_LOGIC;
           
           TX_en     : in STD_LOGIC;
--           TX_Frame_data  : in STD_LOGIC_VECTOR(Frame_data_num -1 downto 0);
           
           SDI : in STD_LOGIC;   -- UART inputs
           SDO : out STD_LOGIC   -- UART output
           );
end UART_TOP;

architecture Behavioral of UART_TOP is
-------------------------------------------------------
-- The following may need to be modified
-- sys work clock frequence
constant work_clk_freq          : integer   := 163840e3;
-- UART work clock frequence
constant uart_clk_freq          : integer   := 1e6;
constant K                      : integer   := (work_clk_freq/uart_clk_freq)/2;
-- Number of multiple frames
constant Frame_num              : integer   := 10;  
-- One frame consists of Frame_head+Frame_data+Frame_check;
constant Frame_head_bit_num         : integer   := 2;
constant Frame_data_bit_num         : integer   := 8;
constant Frame_check_bit_num        : integer   := 2;
-- Frame_head's structure and first bit must be '0'
constant Frame_head             : STD_LOGIC_VECTOR(Frame_head_bit_num -1 downto 0) := "01";
---------------------------------------------------------
    component TX_Mod is
    generic (
        Frame_head_num          : integer   := Frame_head_bit_num;
        Frame_data_num          : integer   := Frame_data_bit_num;
        Frame_check_num         : integer   := Frame_check_bit_num;
        K                       : integer   := K
    );
    Port ( 
        Rst_n       : in STD_LOGIC;
        Clk_in      : in STD_LOGIC;
        
        TX_Frame_head  : in STD_LOGIC_VECTOR(Frame_head_bit_num -1 downto 0);
           
        TX_data_en     : in STD_LOGIC;
        TX_Frame_data  : in STD_LOGIC_VECTOR(Frame_data_bit_num -1 downto 0);
        TX_ready       : out STD_LOGIC;
        
        SDO            : out STD_LOGIC   -- UART output
        );
    end component;
    
    component RX_Mod is
    generic (
        Frame_head_num          : integer   := Frame_head_bit_num;
        Frame_data_num          : integer   := Frame_data_bit_num;
        Frame_check_num         : integer   := Frame_check_bit_num;
        K                       : integer   := K
    );
    Port ( 
        Rst_n       : in STD_LOGIC;
        Clk_in      : in STD_LOGIC;
        
        RX_Frame_head  : in STD_LOGIC_VECTOR(Frame_head_bit_num -1 downto 0);
           
        RX_Frame_data  : out STD_LOGIC_VECTOR(Frame_head_bit_num -1 downto 0);
        RX_valid       : out STD_LOGIC;
        RX_error       : out STD_LOGIC;
        
        SDI            : in  STD_LOGIC   -- UART output
    );
    end component;
 


SIGNAL TX_ready       : STD_LOGIC;
SIGNAL TX_data_en     : STD_LOGIC;
SIGNAL TX_Frame_data  : STD_LOGIC_VECTOR(Frame_data_bit_num -1 downto 0);

SIGNAL RX_valid       : STD_LOGIC;
SIGNAL RX_error       : STD_LOGIC;
SIGNAL RX_Frame_data  : STD_LOGIC_VECTOR(Frame_data_bit_num -1 downto 0);

---------------------------------------------------------------------------
TYPE matrix_index is array (Frame_num-1 downto 0) of STD_LOGIC_VECTOR(Frame_data_bit_num-1 downto 0);
TYPE TX_state_type is(
    ilde,
    start,
    working,
    ending
);
SIGNAL TX_state   : TX_state_type;
SIGNAL TX_count   : integer range 0 to Frame_num-1;
SIGNAL TX_buffer  : matrix_index;

TYPE RX_state_type is(
    waiting,
    working,
    ending
);
SIGNAL RX_state   : RX_state_type;
SIGNAL RX_count   : integer range 0 to Frame_num;
SIGNAL RX_buffer  : matrix_index;
---------------------------------------------------------------------------
constant Frame_length   : integer := Frame_head_bit_num + Frame_data_bit_num + Frame_check_bit_num;
constant Time_cnt_limit : integer := 2 *(2*K)*(Frame_length+1)*Frame_num;
SIGNAL RX_Time_out_cnt    : integer range 0 to Time_cnt_limit-1;
begin
--------------------------------------------
-- The following may need to be modified    
-- These are the data waiting to be sent
-- You also can assign values from outside of module

    TX_buffer(0) <= "00000001";
    TX_buffer(1) <= "00000010";
    TX_buffer(2) <= "00000011";
    TX_buffer(3) <= "00000100";
    TX_buffer(4) <= "00000101";
    TX_buffer(5) <= "00000110";
    TX_buffer(6) <= "00000111";
    TX_buffer(7) <= "00001000";
    TX_buffer(8) <= "00001001";
    TX_buffer(9) <= "00001010";

---------------------------------------------------------------------------
    -- RX state ctl machine
    process(Rst_n,Clk_in)
    begin
        if Rst_n = '0' then
            RX_state <= waiting;
        elsif rising_edge(Clk_in) then
            if RX_state = waiting and RX_valid = '1' and RX_error = '0' then
                RX_state <= working;        
            elsif RX_state = working and RX_count = Frame_num then
                RX_state <= ending;
            elsif RX_Time_out_cnt = Time_cnt_limit-1 then
                RX_state <= ending;
            elsif RX_state = ending then
                RX_state <= waiting;
            else
                RX_state <= RX_state;
            end if;
        end if;
    end process;
    
    -- RX time out ctl
    process(Rst_n,Clk_in)
    begin
        if Rst_n = '0' then
            RX_Time_out_cnt <= 0;
        elsif rising_edge(Clk_in) then
            if RX_state = waiting then
                RX_Time_out_cnt <= 0;        
            elsif RX_state = working then
                if RX_Time_out_cnt = Time_cnt_limit-1 then
                    RX_Time_out_cnt <= RX_Time_out_cnt;
                else
                    RX_Time_out_cnt <= RX_Time_out_cnt + 1;
                end if;
            else
                RX_Time_out_cnt <= RX_Time_out_cnt;
            end if;
        end if;
    end process;
    
    -- RX frame count
    process(Rst_n,Clk_in)
    begin
        if Rst_n = '0' then
            RX_count <= 0;
            for k in Frame_num-1 downto 0 loop
                RX_buffer(k) <= (others => '0');
            end loop;
        elsif rising_edge(Clk_in) then
            if RX_state = ending then
                RX_count  <= 0;
            else
                if RX_valid = '1' then
                    if RX_count = Frame_num then
                        RX_count <= 0;
                    else
                        RX_count <= RX_count + 1;
                    end if;
                end if;
            end if;
            if RX_valid = '1' and RX_error = '0' then
                RX_buffer(RX_count) <= RX_Frame_data;
            end if;
        end if;
    end process;
---------------------------------------------------------------------------
    -- TX state ctl machine
    process(Rst_n,Clk_in)
    begin
        if Rst_n = '0' then
            TX_state <= ilde;
        elsif rising_edge(Clk_in) then
            if TX_state = ilde and TX_en = '1' then
                TX_state <= start;
            elsif TX_state = start and TX_ready = '0' then
                TX_state <= working;
            elsif TX_state = working and TX_ready = '1' then
                TX_state <= ending;
            elsif TX_state = ending and TX_count < Frame_num-1 then
                TX_state <= start;
            elsif TX_state = ending then
                TX_state <= ilde;
            else
                TX_state <= TX_state;
            end if;
        end if;
    end process;
    
    -- TX frame count
    process(Rst_n,Clk_in)
    begin
        if Rst_n = '0' then
            TX_count <= 0;
            
            TX_data_en <= '0';
            TX_Frame_data <= (others => '0');
        elsif rising_edge(Clk_in) then
            if TX_state = start then
                TX_data_en    <= '1';
                TX_Frame_data <= TX_buffer(TX_count);
            else    
                TX_data_en    <= '0';
                TX_Frame_data <= (others => '0'); 
            end if;
            if TX_state = ending then
                if TX_count = Frame_num-1 then
                    TX_count  <= 0;
                else
                    TX_count  <= TX_count + 1;
                end if;
            else
                TX_count <= TX_count;
            end if;
        end if;
    end process;
---------------------------------------------------------------------------
    U_TX_mod:TX_Mod
    Port map( 
       Rst_n  =>Rst_n,
       Clk_in =>Clk_in,

       TX_Frame_head    =>Frame_head,       
       TX_data_en       =>TX_data_en,       
       TX_Frame_data    =>TX_Frame_data,    
       TX_ready         =>TX_ready,        
       SDO              =>SDO               
   );
   
   U_RX_mod:RX_Mod
   Port map( 
      Rst_n  =>Rst_n,
      Clk_in =>Clk_in,

      RX_Frame_head     =>Frame_head,      
      RX_valid          =>RX_valid,        
      RX_error          =>RX_error,        
      RX_Frame_data     =>RX_Frame_data,   
      SDI               =>SDI              
  );
end Behavioral;
