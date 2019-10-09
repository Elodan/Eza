----------------------------------------------------------------------------------
-- Create Date: 2019/09/24 16:38:01
-- Module Name: TX_Mod - Behavioral
-- Description: 
--     Send a multi-bit frame at uart rate
--     multi-bit include :
--        1.1. First bit must be '0'
--        1.2. An ability to customize the header
--        2.   Data bit
--        3.1. Parity bit(Frame_check)
--        3.2. Last bit is set to '0'
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_unsigned.ALL;

entity TX_Mod is
    generic (
        Frame_head_num          : integer   := 2;
        Frame_data_num          : integer   := 8;
        Frame_check_num         : integer   := 2;
        
        K                       : integer   := 50
    );
    Port ( 
        Rst_n       : in STD_LOGIC;
        Clk_in      : in STD_LOGIC;
        
        TX_Frame_head  : in STD_LOGIC_VECTOR(Frame_head_num -1 downto 0);
           
        TX_data_en     : in  STD_LOGIC;
        TX_Frame_data  : in  STD_LOGIC_VECTOR(Frame_data_num -1 downto 0);
        TX_ready       : out STD_LOGIC;
        
        SDO            : out STD_LOGIC   -- UART output
        );
end TX_Mod;

architecture Behavioral of TX_Mod is
    constant Frame_length   : integer := Frame_head_num + Frame_data_num + Frame_check_num;

    SIGNAL Counter          : integer range 0 to K-1;
    SIGNAL TX_bit_num_count : integer range 0 to Frame_length;
    
    SIGNAL TX_working       : STD_LOGIC;
    SIGNAL TX_clk           : STD_LOGIC;
    SIGNAL Data_buf         : STD_LOGIC_VECTOR(Frame_length-1 downto 0);
    
    SIGNAL TX_Frame_check   : STD_LOGIC_VECTOR(Frame_check_num-1 downto 0);
    
    function Check(data : in STD_LOGIC_VECTOR) return STD_LOGIC is
        variable check_bit : STD_LOGIC := '0';
    begin
        for i in data'range loop
            check_bit := check_bit xor data(i);
        end loop;
        return check_bit;
    end function;
    
begin
    
    -- Data Buff
    process(Rst_n,Clk_in)
    begin
        if Rst_n = '0' then
            Data_buf <= (others => '1');
        elsif rising_edge(Clk_in) then
            if TX_data_en = '1' and TX_working = '0' then
                Data_buf <= TX_Frame_head & TX_Frame_data & TX_Frame_check;
            elsif Counter = K-1 and TX_clk = '0' then
                Data_buf <= Data_buf(Frame_length-2 downto 0) & '1' ;
            else
                Data_buf <= Data_buf;
            end if;
        end if;
    end process;

    TX_Frame_check <= Check(TX_Frame_data) & '0';
    -- Data output
    process(Rst_n,TX_clk)
    begin
        if Rst_n = '0' then
            sdo <= '1';
        elsif falling_edge(TX_clk) then
            if TX_bit_num_count = 0 then
                sdo <= '1';
            else
                sdo <= Data_buf(Frame_length-1);
            end if;
        end if;
    end process;
    
    
    --Data bit count and state ctrl
    process(Rst_n,Clk_in)
    begin
        if Rst_n = '0' then
            TX_bit_num_count <= 0;
            TX_working         <= '0';
        elsif rising_edge(Clk_in) then
            if TX_data_en = '1' then
                TX_bit_num_count <= Frame_length+1;
            elsif TX_bit_num_count = 0 then
                TX_bit_num_count <= TX_bit_num_count;
            elsif Counter = K-1 and TX_clk = '0' then
                TX_bit_num_count <= TX_bit_num_count - 1;
            else
                TX_bit_num_count <= TX_bit_num_count;
            end if;
            
            if TX_data_en = '1' then
                TX_working <= '1';
            elsif TX_bit_num_count = 0 then
                TX_working <= '0';
            else
                TX_working <= TX_working;
            end if;
        end if;
    end process;
    TX_ready <= not(TX_working);
    
    -- TX CLK gen
    process(Rst_n,Clk_in)
    begin
        if Rst_n = '0' then
            Counter <= 0;
            TX_clk  <= '0';
        elsif rising_edge(Clk_in) then
            if TX_data_en = '1' then
                Counter <= 0;
                TX_clk  <= '1';
            else
                if TX_bit_num_count = 0 then
                    Counter <= 0;
                    TX_clk  <= '0';
                elsif TX_bit_num_count = 1 and Counter = K - 1 then
                    Counter <= 0;
                    TX_clk  <= '0';
                else
                    if Counter = K - 1 then
                        Counter <= 0;
                        TX_clk  <= not(TX_clk);
                    else
                        Counter <= Counter + 1;
                        TX_clk  <= TX_clk;
                    end if;
                end if;
            end if;
        end if;
    end process;  

end Behavioral;
