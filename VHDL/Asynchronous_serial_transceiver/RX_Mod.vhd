----------------------------------------------------------------------------------
-- Create Date: 2019/09/24 16:38:01
-- Module Name: TX_Mod - Behavioral
-- Description: 
--     Receive a multi-bit frame at uart rate
--     multi-bit include :
--        1.1. First bit must be '0'
--        1.2. An ability to customize the header
--        2.   Data bit
--        3.1. Parity bit(Frame_check)
--        3.2. Last bit is set to '0'
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity RX_Mod is
    generic (
        Frame_head_num          : integer   := 2;
        Frame_data_num          : integer   := 8;
        Frame_check_num         : integer   := 2;
        
        K                       : integer   := 50
    );
    Port ( 
        Rst_n       : in STD_LOGIC;
        Clk_in      : in STD_LOGIC;
        
        RX_Frame_head  : in STD_LOGIC_VECTOR(Frame_head_num -1 downto 0);
           
        RX_Frame_data  : out STD_LOGIC_VECTOR(Frame_data_num -1 downto 0);
        RX_valid       : out STD_LOGIC;
        RX_error       : out STD_LOGIC;
        
        SDI            : in  STD_LOGIC   -- UART output
    );
end RX_Mod;

architecture Behavioral of RX_Mod is
    constant Frame_length   : integer := Frame_head_num + Frame_data_num + Frame_check_num;
    constant head_start     : integer := Frame_length-1;
    constant head_end       : integer := head_start-(Frame_head_num-1);
    constant data_start     : integer := head_end-1;
    constant data_end       : integer := data_start-(Frame_data_num-1);    
    constant check_start    : integer := data_end-1;
    constant check_end      : integer := check_start-(Frame_check_num-1);   
    
    SIGNAL Counter          : integer range 0 to K-1;
    SIGNAL RX_bit_num_count : integer range 0 to Frame_length;
    
    SIGNAL RX_head_buffer    : STD_LOGIC_VECTOR(Frame_head_num -1 downto 0);
    SIGNAL RX_check_buffer   : STD_LOGIC_VECTOR(Frame_check_num-1 downto 0);
    SIGNAL RX_data_buffer    : STD_LOGIC_VECTOR(Frame_data_num -1 downto 0);
    SIGNAL RX_valid_buffer   : STD_LOGIC;
    
    SIGNAL SDI_d1       : STD_LOGIC;
    SIGNAL SDI_d2       : STD_LOGIC;
    SIGNAL SDI_d3       : STD_LOGIC;
    
    SIGNAL RX_working       : STD_LOGIC;
    SIGNAL RX_clk           : STD_LOGIC;
    SIGNAL Data_buf         : STD_LOGIC_VECTOR(Frame_length-1 downto 0);
    
    SIGNAL outputflag       : STD_LOGIC;
    
    function Check(data : in STD_LOGIC_VECTOR) return STD_LOGIC is
        variable check_bit : STD_LOGIC := '0';
    begin
        for i in data'range loop
            check_bit := check_bit xor data(i);
        end loop;
        return check_bit;
    end function;
    
begin
    
    --RX SDI buffer
    process(Rst_n,Clk_in)
    begin
        if Rst_n = '0' then
            SDI_d1  <= '1';
            SDI_d2  <= '1';
            SDI_d3  <= '1';
        elsif rising_edge(Clk_in) then
            SDI_d1 <= SDI;
            SDI_d2 <= SDI_d1;
            SDI_d3 <= SDI_d2;
        end if;
    
    end process;

    --RX state ctl
    process(Rst_n,Clk_in)
    begin
        if Rst_n = '0' then
            RX_working <= '0';
        elsif rising_edge(Clk_in) then
            if RX_bit_num_count = 0 then
                RX_working <= '0';
            else
                RX_working <= '1';
            end if;
        end if;
    end process;
    
    --RX data bit count
    process(Rst_n,Clk_in)
    begin
        if Rst_n = '0' then
            RX_bit_num_count <= 0;
        elsif rising_edge(Clk_in) then
            if SDI_d1 = '0' and SDI_d2 = '1' and RX_working = '0' then
                RX_bit_num_count <= Frame_length;
            elsif Counter = K-1 and RX_clk = '0' then
                RX_bit_num_count <= RX_bit_num_count - 1;
            else
                RX_bit_num_count <= RX_bit_num_count;
            end if;
        end if;
    end process;
    
    -- RX Data Shift Register
    process(Rst_n,RX_clk)
    begin
        if Rst_n = '0' then
            Data_buf <= (others => '0');
        elsif falling_edge(RX_clk) then
            if RX_working = '1' then
                Data_buf(0) <= SDI_d3;
                Data_buf(Frame_length-1 downto 1) <= Data_buf(Frame_length-2 downto 0);
            else
                Data_buf <= (others => '0');
            end if;
        end if;
    end process;
    
    -- RX Check the frame header and output
    process(Rst_n,Clk_in)
    begin
        if Rst_n = '0' then
            RX_head_buffer  <= (others => '0');
            RX_data_buffer  <= (others => '0');
            RX_check_buffer <= (others => '0');
            RX_valid_buffer <= '0';
        
            RX_Frame_data <= (others => '0');
            RX_valid      <= '0';
            RX_error      <= '0';
            outputflag    <= '0';
        elsif rising_edge(Clk_in) then
            if RX_bit_num_count = 1 and Counter = K-1 and RX_clk = '0' and outputflag = '0' then
                RX_head_buffer  <= Data_buf(head_start  downto head_end);
                RX_data_buffer  <= Data_buf(data_start  downto data_end);
                RX_check_buffer <= Data_buf(check_start downto check_end);
                RX_valid_buffer <= '1';
                outputflag      <= '1';
            else
                RX_head_buffer  <= (others => '0');
                RX_data_buffer  <= (others => '0');
                RX_check_buffer <= (others => '0');
                RX_valid_buffer <= '0';
                outputflag    <= '0';
            end if;
            
            if outputflag = '1' then
                RX_Frame_data  <= RX_data_buffer;
                if Check(RX_data_buffer) = RX_check_buffer(1) then
                    RX_error       <= '0';
                else
                    RX_error       <= '1';
                end if;
                
                if RX_Frame_head = RX_head_buffer then
                    RX_valid       <= RX_valid_buffer;
                else
                    RX_valid       <= '0';
                end if;
            else
                RX_Frame_data  <= (others => '0');
                RX_valid       <= '0';
                RX_error       <= '0';
            end if;
        end if;
    end process;

    -- RX clk generate
    process(Rst_n,Clk_in)
    begin
        if Rst_n = '0' then
            Counter <= 0;
            RX_clk  <= '0';
        elsif rising_edge(Clk_in) then
            if SDI_d1 = '0' and SDI_d2 = '1' then
                Counter <= 0;
                RX_clk  <= '1';
            else
                if RX_bit_num_count = 0 then
                    Counter <= 0;
                    RX_clk  <= '0';
                elsif RX_bit_num_count = 1 and Counter = K - 1 then
                    Counter <= 0;
                    RX_clk  <= '0';
                else
                    if Counter = K - 1 then
                        Counter <= 0;
                        RX_clk  <= not(RX_clk);
                    else
                        Counter <= Counter + 1;
                        RX_clk  <= RX_clk;
                    end if;
                end if;
            end if;
        end if;
    end process;

    
end Behavioral;
