-------------------------------------------------------------------------------
--
-- Title       : int_spdf_dif2
-- Design      : FFT SPDF
-- Author      : Kapitanov Alexander
-- Company     : 
-- E-mail      : sallador@bk.ru
--
-------------------------------------------------------------------------------
--
-- Version 1.0 : 11.01.2019
--
-- Description : Single-Path Delay-Feedback butterfly Radix-2 (DIF*)
--
-- * - Decimation in frequency. 2 points per clock.
--
-- Algorithm: Decimation in frequency
--
--    X = (A+B), 
--    Y = (A-B)*W; 
--
-- Algorithm: Decimation in time
--
--    X = A+B*W, 
--    Y = A-B*W; 
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

entity int_spdf_dif2 is
    generic (
        FORMAT     : string:="SCALED"; --integer:=1; --! 1 - Uscaled, 0 - Scaled
        RNDMODE    : string:="TRUNCATE"; --integer:=0; --! 0 - Truncate, 1 - Rounding (FORMAT should be = 0)
        NFFT       : integer:=0;  --! log2 of N points
        STAGE      : integer:=0;  --! Butterfly stages
        DATA_WIDTH : integer:=16; --! Data width
        TWDL_WIDTH : integer:=16; --! Twiddle width
        XUSE       : boolean:=FALSE; --! Use Add/Sub scheme or use delay data path
        XSER       : string:="OLD" --! Xilinx series: NEW - DSP48E2, OLD - DSP48E1
    );
    port (
        DI_RE      : in  std_logic_vector(DATA_WIDTH-1 downto 0); --! Re even input data
        DI_IM      : in  std_logic_vector(DATA_WIDTH-1 downto 0); --! Im even input data
        DI_EN      : in  std_logic; --! Data clock enable

        DO_RE      : out std_logic_vector(DATA_WIDTH downto 0); --! Re even output data
        DO_IM      : out std_logic_vector(DATA_WIDTH downto 0); --! Im even output data
        DO_VL      : out std_logic; --! Output data valid
        
        RST        : in  std_logic; --! Global Reset
        CLK        : in  std_logic --! DSP Clock
    );
end int_spdf_dif2;

architecture int_spdf_dif2 of int_spdf_dif2 is

---- Find data width for output signal ----
function fn_addsub_width(ifmt, imod: string) return integer is
    variable ret_val : integer:=0;
begin
    if (ifmt = "UNSCALED") then
        ret_val := 1;
    elsif (ifmt = "SCALED") then 
        ret_val := 0;
        --if (imode = "TRUNCATE") then
        --    ret_val := 0;
        --elsif (imode = "ROUND") then
        --    ret_val := 1;
        --end if;
    else 
        ret_val := -2;
    end if;
    return ret_val; 
end function;

function fn_twd_delay(ivar : integer) return integer is
    variable ret_val   : integer;
begin
    if (ivar < 11) then
        ret_val := 2;
    else
        ret_val := 7;
    end if;
    return ret_val; 
end function;

constant FMODE     : integer:=fn_addsub_width(FORMAT, RNDMODE);
constant FTWDL     : integer:=fn_twd_delay(STAGE);

type std_logic_delayN is array (FTWDL-1 downto 0) of std_logic_vector(DATA_WIDTH+FMODE-1 downto 0);
signal dre_zz      : std_logic_delayN;
signal dim_zz      : std_logic_delayN;
signal ena_zz      : std_logic_vector(FTWDL-1 downto 0);

signal das_re      : std_logic_vector(DATA_WIDTH downto 0);
signal das_im      : std_logic_vector(DATA_WIDTH downto 0);
signal das_vl      : std_logic;

signal fmt_re      : std_logic_vector(DATA_WIDTH+FMODE-1 downto 0);
signal fmt_im      : std_logic_vector(DATA_WIDTH+FMODE-1 downto 0);
signal fmt_vl      : std_logic;

signal ww_re       : std_logic_vector(TWDL_WIDTH-1 downto 0);
signal ww_im       : std_logic_vector(TWDL_WIDTH-1 downto 0);

begin

    ----------------------------------------------------------------------------
    -- Select output format after Add/Sub operation ----------------------------
    ----------------------------------------------------------------------------
    xROUND: if ((FORMAT = "SCALED") and (RNDMODE = "ROUNDING")) generate
    begin   
        ---- Rounding mode: +/- 0.5 ----
        pr_rnd: process(clk) is
        begin
            if rising_edge(clk) then
                fmt_vl <= das_vl;
                if (das_re(0) = '0') then
                    fmt_re <= das_re(DATA_WIDTH downto 1);
                else
                    fmt_re <= das_re(DATA_WIDTH downto 1) + '1';
                end if;
                if (das_im(0) = '0') then
                    fmt_im <= das_im(DATA_WIDTH downto 1);
                else
                    fmt_im <= das_im(DATA_WIDTH downto 1) + '1';
                end if;
            end if;
        end process;
    end generate;

    xTRUNCATE: if ((FORMAT = "SCALED") and (RNDMODE = "TRUNCATE")) generate
    begin   
        --pr_rnd: process(clk) is
        --begin
        --    if rising_edge(clk) then
                fmt_re <= das_re(DATA_WIDTH downto 1-FMODE);
                fmt_im <= das_im(DATA_WIDTH downto 1-FMODE);
                fmt_vl <= das_vl;
        --    end if;
        --end process;
    end generate;

    xUNSCALED: if (FORMAT = "UNSCALED") generate
    begin
        fmt_re <= das_re(DATA_WIDTH downto 1-FMODE);
        fmt_im <= das_im(DATA_WIDTH downto 1-FMODE);
        fmt_vl <= das_vl;
    end generate;

    ----------------------------------------------------------------------------
    -- Add/Sub & Delay-Feedback ------------------------------------------------
    ----------------------------------------------------------------------------
    xSPDF_ADDSUB: entity work.int_fly_addsub
        generic map (
            STAGE        => STAGE,
            NFFT         => NFFT,
            DTW          => DATA_WIDTH,
            XUSE         => XUSE,
            XSER         => XSER
        )
        port map (
            RST          => RST,
            CLK          => CLK,

            DI_RE        => DI_RE,
            DI_IM        => DI_IM,
            DI_EN        => DI_EN,
            
            DO_RE        => das_re,
            DO_IM        => das_im,
            DO_VL        => das_vl
        );
    ----------------------------------------------------------------------------
    -- Align data and twiddles -------------------------------------------------
    ----------------------------------------------------------------------------
    pr_del: process(clk) is
    begin
        if rising_edge(clk) then
            dre_zz <= dre_zz(FTWDL-2 downto 0) & fmt_re;
            dim_zz <= dim_zz(FTWDL-2 downto 0) & fmt_im;
            ena_zz <= ena_zz(FTWDL-2 downto 0) & fmt_vl;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- Complex multiplier and delay --------------------------------------------
    ----------------------------------------------------------------------------
    xSPDF_TWDLS: entity work.int_fly_twd
        generic map (
            STAGE        => STAGE,
            NFFT         => NFFT,
            DTW          => DATA_WIDTH+FMODE,
            XSER         => XSER
        )
        port map (
            RST          => RST,
            CLK          => CLK,

            DI_RE        => dre_zz(FTWDL-1),
            DI_IM        => dim_zz(FTWDL-1),
            DI_EN        => ena_zz(FTWDL-1),

            WW_RE        => ww_re,
            WW_IM        => ww_im,
            
            DO_RE        => DO_RE,
            DO_IM        => DO_IM,
            DO_VL        => DO_VL
        );

    ----------------------------------------------------------------------------
    -- Twiddle factor ----------------------------------------------------------
    ----------------------------------------------------------------------------
    xTWIDDLE: entity work.rom_twiddle_int
        generic map (
            AWD      => TWDL_WIDTH,
            NFFT     => NFFT,
            STAGE    => STAGE,
            XSER     => XSER,
            USE_MLT  => FALSE
        )
        port map (
            CLK      => CLK,
            RST      => rst,
            WW_EN    => das_vl,
            WW_RE    => ww_re,
            WW_IM    => ww_im
        );

end int_spdf_dif2;