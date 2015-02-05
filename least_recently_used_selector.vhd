-----------------------------------------------------------------------------------
--!     @file    least_recently_used_selector.vhd
--!     @brief   Least-Recently-Used Selector
--!              最も過去に選択したエントリを選択するモジュール.
--!     @version 1.0.0
--!     @date    2015/2/5
--!     @author  Ichiro Kawazome <ichiro_k@ca2.so-net.ne.jp>
-----------------------------------------------------------------------------------
--
--      Copyright (C) 2014-2015 Ichiro Kawazome
--      All rights reserved.
--
--      Redistribution and use in source and binary forms, with or without
--      modification, are permitted provided that the following conditions
--      are met:
--
--        1. Redistributions of source code must retain the above copyright
--           notice, this list of conditions and the following disclaimer.
--
--        2. Redistributions in binary form must reproduce the above copyright
--           notice, this list of conditions and the following disclaimer in
--           the documentation and/or other materials provided with the
--           distribution.
--
--      THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
--      "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
--      LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
--      A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT
--      OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
--      SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
--      LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
--      DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
--      THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
--      (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
--      OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--
-----------------------------------------------------------------------------------
library ieee;
use     ieee.std_logic_1164.all;
-----------------------------------------------------------------------------------
--! @brief   Least_Recently_Used_Selector : 最も過去に選択したエントリを選択するモジュール
-----------------------------------------------------------------------------------
entity  Least_Recently_Used_Selector is
    generic (
        NUM_SETS    : integer := 4
    );
    port (
        CLK         : in  std_logic; 
        RST         : in  std_logic;
        CLR         : in  std_logic;
        I_SEL       : in  std_logic_vector(NUM_SETS-1 downto 0);
        Q_SEL       : out std_logic_vector(NUM_SETS-1 downto 0);
        O_SEL       : out std_logic_vector(NUM_SETS-1 downto 0)
    );
end Least_Recently_Used_Selector;
-----------------------------------------------------------------------------------
-- 
-----------------------------------------------------------------------------------
library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
architecture RTL of Least_Recently_Used_Selector is
begin
    -------------------------------------------------------------------------------
    -- セット数が１しかない場合...
    -------------------------------------------------------------------------------
    ONE_SET: if (NUM_SETS = 1) generate
        Q_SEL(0) <= '1';
        O_SEL(0) <= '1';
    end generate;
    -------------------------------------------------------------------------------
    -- セット数が２以上の場合は最も過去に選択したエントリを選択する
    -------------------------------------------------------------------------------
    -- セット数が４の場合の動作例
    --
    -- I_SEL(0)                     0               0                1
    -- I_SEL(1)                     1               0                0
    -- I_SEL(2)                     0               0                0
    -- I_SEL(3)                     0               1                0
    --                 +-----+      |  +-----+      |  +-----+       |  +-----+
    -- HIT_FLAG_TYPE   |0 1 2|      |  |0 1 2|      |  |0 1 2|       |  |0 1 2|
    --                 +-----+      V  +-----+      V  +-----+       V  +-----+
    -- curr_hit_flag(0)|1 1 1|<-LRU 0  |1 1 1|<-LRU 0  |1 1 1|<-LRU+-1->|0 0 0|
    -- curr_hit_flag(1)|0 1 1|---+--1->|0 0 0|      0  |0 0 1|     | 0  |0 1 1|
    -- curr_hit_flag(2)|0 0 1|   |  0  |0 1 1|      0  |0 1 1|     | 0  |1 1 1|<-LRU
    -- curr_hit_flag(3)|0 0 0|   |  0  |0 0 1|---+--1->|0 0 0|     | 0  |0 0 1|
    --                 +-----+   |     +-----+   |     +-----+     |    +-----+
    --                           |               |                 |
    -- sel_hit_flag              +----> 0 1 1    +----> 0 0 1      +---> 1 1 1 
    --
    -- O_SEL(0)         1               1               1                0
    -- O_SEL(1)         0               0               0                0
    -- O_SEL(2)         0               0               0                1
    -- O_SEL(3)         0               0               0                0
    -------------------------------------------------------------------------------
    ANY_SET: if (NUM_SETS > 1) generate
        subtype  HIT_FLAG_TYPE   is std_logic_vector(0 to NUM_SETS-2);
        type     HIT_FLAG_VECTOR is array (0 to NUM_SETS-1) of HIT_FLAG_TYPE;
        function MAKE_INIT_HIT_FLAG return HIT_FLAG_VECTOR is
            variable init_hit_flag : HIT_FLAG_VECTOR;
        begin
            for i in HIT_FLAG_VECTOR'range loop
                for j in HIT_FLAG_TYPE'range loop
                    if (j >= i) then
                        init_hit_flag(i)(j) := '1';
                    else
                        init_hit_flag(i)(j) := '0';
                    end if;
                end loop;
            end loop;
            return init_hit_flag;
        end function;
        constant INIT_HIT_FLAG   : HIT_FLAG_VECTOR := MAKE_INIT_HIT_FLAG;
        signal   curr_hit_flag   : HIT_FLAG_VECTOR;
        signal   next_hit_flag   : HIT_FLAG_VECTOR;
    begin
        process (curr_hit_flag, I_SEL, CLR)
            variable  sel_hit_flag  : HIT_FLAG_TYPE;
            variable  hit_vec       : std_logic_vector(HIT_FLAG_VECTOR'range);
            function  or_reduce(Arg : std_logic_vector) return std_logic is
                variable result : std_logic;
            begin
                result := '0';
                for i in Arg'range loop
                    result := result or Arg(i);
                end loop;
                return result;
            end function;
        begin
            if (CLR = '1') then
                next_hit_flag <= INIT_HIT_FLAG;
            else
                for j in HIT_FLAG_TYPE'range loop
                    for i in HIT_FLAG_VECTOR'range loop
                        if (I_SEL(i) = '1') then
                            hit_vec(i) := curr_hit_flag(i)(j);
                        else
                            hit_vec(i) := '0';
                        end if;
                    end loop;
                    sel_hit_flag(j) := or_reduce(hit_vec);
                end loop;
                for i in HIT_FLAG_VECTOR'range loop
                    for j in HIT_FLAG_TYPE'range loop
                        if    (I_SEL(i) = '1') then
                            next_hit_flag(i)(j) <= '0';
                        elsif (sel_hit_flag(j) = '0') then
                            next_hit_flag(i)(j) <= curr_hit_flag(i)(j);
                        elsif (j < HIT_FLAG_TYPE'high) then
                            next_hit_flag(i)(j) <= curr_hit_flag(i)(j+1);
                        else
                            next_hit_flag(i)(j) <= '1';
                        end if;
                    end loop;
                end loop;
            end if;
        end process;
        process(CLK, RST) begin
            if (RST = '1') then
                curr_hit_flag <= INIT_HIT_FLAG;
            elsif (CLK'event and CLK = '1') then
                curr_hit_flag <= next_hit_flag;
            end if;
        end process;
        SEL: for i in 0 to NUM_SETS-1 generate
            O_SEL(i) <= next_hit_flag(i)(0);
            Q_SEL(i) <= curr_hit_flag(i)(0);
        end generate;
    end generate;
end RTL;
