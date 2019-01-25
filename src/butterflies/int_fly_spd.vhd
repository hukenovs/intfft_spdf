-------------------------------------------------------------------------------
--
-- Title       : int_fly_spd
-- Design      : FFT
-- Author      : Kapitanov Alexander
-- Company     : 
-- E-mail      : sallador@bk.ru
--
-------------------------------------------------------------------------------
-- 
-- Version 1.0 : 14.01.2019
--
-- Description : Single-Path Delay-Feedback butterfly Radix-2
--
-- X = (A+B)
-- Y = (A-B)
--
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--
--  GNU GENERAL PUBLIC LICENSE
--  Version 3, 29 June 2007
--
--  Copyright (c) 2018 Kapitanov Alexander
--
--  This program is free software: you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation, either version 3 of the License, or
--  (at your option) any later version.
--
--  You should have received a copy of the GNU General Public License
--  along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
--  THERE IS NO WARRANTY FOR THE PROGRAM, TO THE EXTENT PERMITTED BY
--  APPLICABLE LAW. EXCEPT WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT 
--  HOLDERS AND/OR OTHER PARTIES PROVIDE THE PROGRAM "AS IS" WITHOUT WARRANTY 
--  OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, 
--  THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR 
--  PURPOSE.  THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE PROGRAM 
--  IS WITH YOU.  SHOULD THE PROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST OF 
--  ALL NECESSARY SERVICING, REPAIR OR CORRECTION. 
-- 
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity int_fly_spd is
    generic (   
        NFFT       : integer:=0;  --! log2 of N points
        STAGE      : integer:=0;  --! Butterfly stages
        DTW        : integer:=16; --! Data width
        XUSE       : boolean:=FALSE; --! Use Add/Sub scheme or use delay data path
        XSER       : string:="OLD" --! Xilinx series: NEW - DSP48E2, OLD - DSP48E1
    );
    port (
        DI_RE      : in  std_logic_vector(DTW-1 downto 0); --! Re even input data
        DI_IM      : in  std_logic_vector(DTW-1 downto 0); --! Im even input data
        DI_EN      : in  std_logic; --! Data clock enable

        DO_RE      : out std_logic_vector(DTW downto 0); --! Re even output data
        DO_IM      : out std_logic_vector(DTW downto 0); --! Im even output data
        DO_VL      : out std_logic;    --! Output data valid            
        
        RST        : in  std_logic; --! Global Reset
        CLK        : in  std_logic --! DSP Clock    
    );
end int_fly_spd;

architecture int_fly_spd of int_fly_spd is

---- Find delay for add/sub butterfly function ----
function addsub_delay(iDW: integer) return integer is
    variable ret_val : integer:=0;
begin
    if (iDW < 48) then
        ret_val := 2+2;
    else 
        ret_val := 3+2;
    end if;
    return ret_val; 
end function addsub_delay;

constant ADD_DELAY    : integer:=addsub_delay(DTW);

type std_delayN is array (ADD_DELAY-1 downto 0) of std_logic_vector(DTW downto 0);
type std_addrsN is array (ADD_DELAY-1 downto 0) of std_logic_vector(STAGE-1 downto 0);


---------------- Multiplexers 0/1 ----------------
signal mux_sel        : std_logic:='0';

signal mux0_ia_re     : std_logic_vector(DTW downto 0):=(others=>'0');
signal mux0_ia_im     : std_logic_vector(DTW downto 0):=(others=>'0');
signal mux0_ib_re     : std_logic_vector(DTW downto 0):=(others=>'0');
signal mux0_ib_im     : std_logic_vector(DTW downto 0):=(others=>'0');

signal mux1_ia_re     : std_logic_vector(DTW downto 0):=(others=>'0');
signal mux1_ia_im     : std_logic_vector(DTW downto 0):=(others=>'0');
signal mux1_ib_re     : std_logic_vector(DTW downto 0):=(others=>'0');
signal mux1_ib_im     : std_logic_vector(DTW downto 0):=(others=>'0');

signal mux0_re        : std_logic_vector(DTW downto 0):=(others=>'0');
signal mux0_im        : std_logic_vector(DTW downto 0):=(others=>'0');
signal mux1_re        : std_logic_vector(DTW downto 0):=(others=>'0');
signal mux1_im        : std_logic_vector(DTW downto 0):=(others=>'0');

signal ib_re          : std_logic_vector(DTW-1 downto 0):=(others=>'0');
signal ib_im          : std_logic_vector(DTW-1 downto 0):=(others=>'0');
signal ia_re          : std_logic_vector(DTW-1 downto 0):=(others=>'0');
signal ia_im          : std_logic_vector(DTW-1 downto 0):=(others=>'0');

signal iz_re          : std_logic_vector(DTW-1 downto 0):=(others=>'0');
signal iz_im          : std_logic_vector(DTW-1 downto 0):=(others=>'0');

signal oa_re          : std_logic_vector(DTW downto 0):=(others=>'0');
signal oa_im          : std_logic_vector(DTW downto 0):=(others=>'0');
signal ob_re          : std_logic_vector(DTW downto 0):=(others=>'0');
signal ob_im          : std_logic_vector(DTW downto 0):=(others=>'0');

---------------- Ramb nets ----------------
signal wr_dat         : std_logic_vector(2*DTW+1 downto 0);
signal rd_dat         : std_logic_vector(2*DTW+1 downto 0);

signal wr_ena         : std_logic:='0';

signal wr_adr         : std_logic_vector(STAGE-1 downto 0);
signal rd_adr         : std_logic_vector(STAGE-1 downto 0);

---------------- Align delays ----------------
signal dz0_re         : std_delayN;
signal dz0_im         : std_delayN;
signal dz1_re         : std_delayN;
signal dz1_im         : std_delayN;

signal di_ez          : std_logic:='0';

signal wr_adrz        : std_addrsN;

signal mux_ena        : std_logic_vector(ADD_DELAY-1 downto 0):=(others=>'0');

signal rd_cnt         : std_logic_vector(STAGE downto 0);
signal rd_del         : std_logic_vector(ADD_DELAY-1 downto 0):=(others=>'0');
signal rd_out         : std_logic:='0';

signal wr_del         : std_logic_vector(ADD_DELAY-1 downto 0):=(others=>'0');
signal wr_out         : std_logic:='0';

signal cnt_i1         : std_logic_vector(STAGE+1 downto 0):=(others=>'0');
signal cnt_i2         : std_logic_vector(STAGE   downto 0):=(others=>'0');
signal cnt_i3         : std_logic_vector(STAGE   downto 0):=(others=>'0');
signal cnt_en         : std_logic:='0';
signal cnt_vl         : std_logic:='0';

begin

pr_cnt: process(clk) is
begin
    if rising_edge(clk) then
        if (RST = '1') then
            cnt_i1 <= (0 => '1', others => '0');
            cnt_i2 <= (others => '0');    
            cnt_i3 <= (0 => '1', others => '0');
            cnt_en <= '0';
            cnt_vl <= '0';
        else
            ---- Counter 1: Skip to read ----
            if (di_en = '1') then
                if (cnt_i1(cnt_i1'left) = '0') then
                    cnt_i1 <= cnt_i1 + '1';
                else
                    cnt_i1 <= (0 => '1', others => '0');
                end if;
            end if;

            ---- Counter 2: First read enable ----
            if (cnt_i3(cnt_i3'left) = '1') then
                cnt_i2 <= (others => '0');
            else
                if (di_en = '1') then
                    if (cnt_en = '1') then
                        cnt_i2 <= cnt_i2 + '1';
                    end if;
                end if;
            end if;
            
            ---- Counter 3: Second read enable ----
            if cnt_i3(cnt_i3'left) = '1' then
                cnt_i3 <= (0 => '1', others => '0');
            else
                if (cnt_i2(cnt_i2'left) = '1') then
                    cnt_i3 <= cnt_i3 + '1';
                end if;    
            end if;    
            
            ---- Read enable for RAMB ----
            if (cnt_i1(cnt_i1'left-1) = '1') then
                if (di_en = '1') then
                    cnt_en <= '1';
                end if;
            else
                if (cnt_i3(cnt_i3'left) = '1') then
                    cnt_en <= '0';
                end if;
            end if;            
            cnt_vl <= (cnt_en and di_en) or (cnt_i2(cnt_i2'left));
            
        end if;
    end if;
end process;

rd_del <= rd_del(rd_del'left-1 downto 0) & cnt_vl when rising_edge(clk);
rd_out <= rd_del(rd_del'left);

-------- Counter for multiplexer 0 and RAMB adress (write) --------
pr_addr: process(clk) is
begin
    if rising_edge(clk) then
        if (RST = '1') then
            rd_cnt <= (others => '0');
        else
            if (di_en = '1') then
                rd_cnt <= rd_cnt + '1';
            end if;
        end if;
    end if;
end process;

pr_mux: process(clk) is
begin
    if rising_edge(clk) then
        ---- Mux data A / B datapath ----
        mux_sel <= mux_ena(mux_ena'left-1);
        mux_ena <= mux_ena(mux_ena'left-1 downto 0) & rd_cnt(STAGE);
        ---- Align input data and ramb output ----
        dz0_re <= dz0_re(ADD_DELAY-2 downto 0) & (di_re(DTW-1) & di_re);
        dz0_im <= dz0_im(ADD_DELAY-2 downto 0) & (di_im(DTW-1) & di_im);
    end if;
end process;

-------- Select data for input multiplexer "0" --------
mux0_ia_re <= dz0_re(ADD_DELAY-1);
mux0_ia_im <= dz0_im(ADD_DELAY-1);

mux0_ib_re <= ob_re;
mux0_ib_im <= ob_im;

pr_mux0: process(clk) is
begin
    if rising_edge(clk) then
        if (mux_sel = '0') then
            mux0_re <= mux0_ia_re;
            mux0_im <= mux0_ia_im;
        else
            mux0_re <= mux0_ib_re;
            mux0_im <= mux0_ib_im;
        end if;
    end if;
end process;


-------- Align input data and ramb output --------
dz1_re <= dz1_re(ADD_DELAY-2 downto 0) & rd_dat(1*(DTW+1)-1 downto 0*(DTW+1)) when rising_edge(clk);
dz1_im <= dz1_im(ADD_DELAY-2 downto 0) & rd_dat(2*(DTW+1)-1 downto 1*(DTW+1)) when rising_edge(clk);

-------- Select data for input multiplexer "1" --------
mux1_ia_re <= oa_re;
mux1_ia_im <= oa_im;

mux1_ib_re <= dz1_re(dz1_re'left-2);
mux1_ib_im <= dz1_im(dz1_im'left-2);

pr_mux1: process(clk) is
begin
    if rising_edge(clk) then
        if (mux_sel = '1') then
            mux1_re <= mux1_ia_re;
            mux1_im <= mux1_ia_im;
        else
            mux1_re <= mux1_ib_re;
            mux1_im <= mux1_ib_im;
        end if;
    end if;
end process;

-------- Ramb delay mapping --------
wr_del <= wr_del(wr_del'left-1 downto 0) & di_en when rising_edge(clk);
wr_out <= wr_del(wr_del'left) when rising_edge(clk);

wr_adrz <= wr_adrz(wr_adrz'left-1 downto 0) & rd_cnt(STAGE-1 downto 0) when rising_edge(clk);

wr_dat <= mux0_im & mux0_re;
wr_adr <= wr_adrz(wr_adrz'left) when rising_edge(clk);

pr_rd_adr: process(clk) is
begin
    if rising_edge(clk) then
        if (RST = '1') then
            rd_adr <= (others => '0');
        else
            if (cnt_vl = '1') then
                rd_adr <= rd_adr + '1';
            end if;
        end if;
    end if;
end process;

xRAM_DL: entity work.ramb_dp_one_clk
    generic map (
        DATA        => 2*(DTW+1),
        ADDR        => STAGE
    )
    port map (
        A_WR        => wr_out,
        A_DIN       => wr_dat,
        A_ADDR      => wr_adr,

        B_RD        => cnt_vl,
        B_DOUT      => rd_dat,
        B_ADDR      => rd_adr,

        CLK         => clk
    );    

-------- Input data for Butterfly --------
iz_re <= di_re when rising_edge(clk) and (di_en = '1'); 
iz_im <= di_im when rising_edge(clk) and (di_en = '1');
ib_re <= iz_re when rising_edge(clk);
ib_im <= iz_im when rising_edge(clk);
ia_re <= rd_dat(1*(DTW+0)-1 downto 0*(DTW+0));
ia_im <= rd_dat(2*(DTW+1)-2 downto 1*(DTW+1));

-------- Delay imitation Add/Sub logic --------
xLOGIC: if (XUSE = FALSE) generate
    type std_delayX is array (ADD_DELAY-1-2 downto 0) of std_logic_vector(DTW-1 downto 0);
    signal add_re, add_im, sub_re, sub_im   : std_delayX;
begin
    add_re <= add_re(add_re'left-1 downto 0) & ia_re when rising_edge(clk);
    add_im <= add_im(add_im'left-1 downto 0) & ia_im when rising_edge(clk);
    sub_re <= sub_re(sub_re'left-1 downto 0) & ib_re when rising_edge(clk);
    sub_im <= sub_im(sub_im'left-1 downto 0) & ib_im when rising_edge(clk);

    oa_re <= add_re(add_re'left)(DTW-1) & add_re(add_re'left);
    oa_im <= add_im(add_im'left)(DTW-1) & add_im(add_im'left);
    ob_re <= sub_re(sub_re'left)(DTW-1) & sub_re(sub_re'left);
    ob_im <= sub_im(sub_im'left)(DTW-1) & sub_im(sub_im'left);
    -- oa_re <= x"A" & add_re(add_re'left)(DTW-4 downto 0);
    -- oa_im <= x"A" & add_im(add_im'left)(DTW-4 downto 0);
    -- ob_re <= x"C" & sub_re(sub_re'left)(DTW-4 downto 0);
    -- ob_im <= x"C" & sub_im(sub_im'left)(DTW-4 downto 0);    
end generate;


-------- Output data --------
pr_dout: process(clk) is
begin
    if rising_edge(clk) then
        if (rd_out = '1') then
            do_re <= mux1_re;
            do_im <= mux1_im;
        end if;
        do_vl <= rd_out;
    end if;
end process;

-------- SUM = (A + B), DIF = (A - B) --------
xADDSUB: if (XUSE = TRUE) generate
    xDSP: entity work.int_addsub_dsp48
        generic map (
            DSPW      => DTW,
            XSER      => XSER
        )
        port map (
            IA_RE     => ia_re,
            IA_IM     => ia_im,
            IB_RE     => ib_re,
            IB_IM     => ib_im,

            OX_RE     => oa_re,
            OX_IM     => oa_im,
            OY_RE     => ob_re,
            OY_IM     => ob_im,

            RST       => rst,
            CLK       => clk
        );
end generate;

end int_fly_spd;