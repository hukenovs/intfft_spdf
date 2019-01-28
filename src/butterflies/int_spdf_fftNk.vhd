-------------------------------------------------------------------------------
--
-- Title       : int_spdf_fftNk
-- Design      : FFT SPDF
-- Author      : Kapitanov Alexander
-- Company     : 
-- E-mail      : sallador@bk.ru
--
-------------------------------------------------------------------------------
--
-- Version 1.0 : 22.01.2019
--
-- Description : Fully pipelined integer FFT core.
--               Integer (Unscaled / Scaled) Forward Fast Fourier Transform,
--               N = 8 to 512K (points of data),      
--               For N > 512K you should use 2D-FFT scheme
--               Algorithm: Single-Path Delay-Feedback butterfly Radix-2 (DIF*)
--
-- * - Decimation in frequency. Radix-2: 2 data words per clock.
--
-- Decimation in frequency:
--
--    X = (A+B),
--    Y = (A-B)*W;
--
--    FORMAT        : 1 - Unscaled, 0 - Scaled data output
--    RNDMODE       : Rounding (round), Truncate (floor)
--    NFFT          : Number of FFT stages [ =log2(N) ]
--    DATA_WIDTH    : Input data width **
--    TWDL_WIDTH    : Twiddles data width (depends on precision of twiddle factor)
--    TWDL_WIDTH    : Twiddles data width (precision of twiddle factor)
--    XUSE          : TRUE / FALSE: Use math calculation or use delay data path
--    XSER          : "NEW" / "OLD": Xilinx series: NEW - DSP48E2, OLD - DSP48E1
--
-- ** - Note: for Unscaled mode: output data width = input data width + log2(N)
--
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--
--  GNU GENERAL PUBLIC LICENSE
--  Version 3, 29 June 2007
--
--  Copyright (c) 2019 Kapitanov Alexander
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

entity int_spdf_fftNk is
    generic (
        FORMAT     : integer:=1; --! 1 - Uscaled, 0 - Scaled
        RNDMODE    : string:="TRUNCATE"; --integer:=0; --! 0 - Truncate, 1 - Rounding (FORMAT should be = 0)
        NFFT       : integer:=12; --! log2 of N points
        DATA_WIDTH : integer:=16; --! Data width
        TWDL_WIDTH : integer:=16; --! Twiddle width
        XUSE       : boolean:=TRUE; --! Use Add/Sub scheme or use delay data path
        XSER       : string:="NEW" --! Xilinx series: NEW - DSP48E2, OLD - DSP48E1
    );
    port (
        DI_RE      : in  std_logic_vector(DATA_WIDTH-1 downto 0); --! Re even input data
        DI_IM      : in  std_logic_vector(DATA_WIDTH-1 downto 0); --! Im even input data
        DI_EN      : in  std_logic; --! Data clock enable

        DO_RE      : out std_logic_vector(DATA_WIDTH+FORMAT*NFFT-1 downto 0); --! Re even output data
        DO_IM      : out std_logic_vector(DATA_WIDTH+FORMAT*NFFT-1 downto 0); --! Im even output data
        DO_VL      : out std_logic; --! Output data valid
        
        RST        : in  std_logic; --! Global Reset
        CLK        : in  std_logic --! DSP Clock
    );
end int_spdf_fftNk;

architecture int_spdf_fftNk of int_spdf_fftNk is

type complex_XxN is array (NFFT-0 downto 0) of std_logic_vector(FORMAT*NFFT+DATA_WIDTH-1 downto 0);
type complex_YxN is array (NFFT-1 downto 0) of std_logic_vector(FORMAT*NFFT+DATA_WIDTH-1 downto 0);

signal fi_re        : complex_XxN := (others => (others => '0'));
signal fi_im        : complex_XxN := (others => (others => '0'));
signal fo_re        : complex_YxN := (others => (others => '0'));
signal fo_im        : complex_YxN := (others => (others => '0'));
signal fi_en        : std_logic_vector(NFFT-0 downto 0) := (others => '0');
signal fo_en        : std_logic_vector(NFFT-1 downto 0) := (others => '0');

begin

    fi_re(0)(DATA_WIDTH-1 downto 0) <= DI_RE;
    fi_im(0)(DATA_WIDTH-1 downto 0) <= DI_IM;
    fi_en(0) <= DI_EN;

    xFFTK: for ii in 0 to NFFT-1 generate
    begin
        xSPDF_DIF2: entity work.int_spdf_dif2
            generic map (
                FORMAT        => FORMAT,
                RNDMODE       => RNDMODE,
                NFFT          => NFFT,
                STAGE         => NFFT-ii-1,
                DATA_WIDTH    => DATA_WIDTH+ii*FORMAT,
                TWDL_WIDTH    => TWDL_WIDTH,
                XUSE          => XUSE,
                XSER          => XSER
            )
            port map (
                RST          => RST,
                CLK          => CLK,

                DI_RE        => fi_re(ii)(DATA_WIDTH-1+ii*FORMAT downto 0),
                DI_IM        => fi_im(ii)(DATA_WIDTH-1+ii*FORMAT downto 0),
                DI_EN        => fi_en(ii),

                DO_RE        => fo_re(ii)(DATA_WIDTH-1+(ii+1)*FORMAT downto 0),
                DO_IM        => fo_im(ii)(DATA_WIDTH-1+(ii+1)*FORMAT downto 0),
                DO_VL        => fo_en(ii)
            );

        fi_re(ii+1) <= fo_re(ii) after 1 ns when rising_edge(clk);
        fi_im(ii+1) <= fo_im(ii) after 1 ns when rising_edge(clk);
        fi_en(ii+1) <= fo_en(ii) after 1 ns when rising_edge(clk);
    end generate;

    DO_RE <= fo_re(NFFT-1) after 1 ns when rising_edge(clk);
    DO_IM <= fo_im(NFFT-1) after 1 ns when rising_edge(clk);
    DO_VL <= fo_en(NFFT-1) after 1 ns when rising_edge(clk);

end int_spdf_fftNk;