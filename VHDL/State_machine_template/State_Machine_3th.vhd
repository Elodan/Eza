----------------------------------------------------------------------------------
-- template of 3-stage state machine
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity State_Machine is
    Port ( 
           rst_n : in STD_LOGIC;
           clk : in STD_LOGIC;
           data_out : OUT STD_LOGIC
		   );
end State_Machine;

architecture Behavioral of State_Machine is

--状态定义
TYPE state_type is(
    init,
    write,
    read,
    finish
);

--状态结束标志位
SIGNAL init_end : STD_LOGIC;
SIGNAL write_end : STD_LOGIC;
SIGNAL read_end : STD_LOGIC;
SIGNAL finish_end : STD_LOGIC;

--当前状态和下个状态
SIGNAL curr_state : state_type;
SIGNAL next_state : state_type;

begin

--第一段 时序逻辑
PROCESS(rst_n,clk)
BEGIN
    IF rst_n = '0' THEN
        curr_state <= init;
    ELSIF rising_edge(clk) THEN
        curr_state <= next_state;
    END IF;
END PROCESS;

--第二段 组合逻辑
PROCESS(curr_state,next_state,
        init_end,write_end,read_end,finish_end
        )
BEGIN
    CASE curr_state IS
        WHEN init =>
            IF init_end = '1' THEN
                next_state <= write;
            ELSE
                next_state <= init;
            END IF;
        WHEN write =>
            IF write_end = '1' THEN
                next_state <= read;
            ELSE
                next_state <= write;
            END IF;
        WHEN read =>
            IF read_end = '1' THEN
                next_state <= finish;
            ELSE
                next_state <= read;
            END IF;
        WHEN finish =>
            IF finish_end = '1' THEN
                next_state <= finish;
            ELSE
                next_state <= finish;
            END IF;
        WHEN OTHERS =>
            next_state <= init;
    END CASE;
END PROCESS;

--第三段 时序或组合逻辑均可 
PROCESS(rst_n,clk)
BEGIN
    IF rst_n = '0' THEN
        data_out <= '0';
        
        init_end <= '0';
        write_end <= '0';
        read_end <= '0';
        finish_end <= '0';
    ELSIF rising_edge(clk) THEN
		CASE curr_state IS
			WHEN init =>
				data_out <= '0';
				init_end <= '1';
			WHEN write =>
				data_out <= '1';
				write_end <= '1';
			WHEN read =>
				data_out <= '1';
				read_end <= '1';
			WHEN finish =>
				data_out <= '0';
				finish_end <= '1';
			WHEN OTHERS =>
				data_out <= '1';
				
		END CASE;
    END IF;

END PROCESS;

end Behavioral;
