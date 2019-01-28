-------------------------------------------------------------------------------
--
-- Title       : int_spdf_single_fft
-- Design      : FFT SPDF
-- Author      : Kapitanov Alexander
-- Company     : 
-- E-mail      : sallador@bk.ru
--
-------------------------------------------------------------------------------
--
-- Version 1.0 : 26.01.2019
--
-- Description : FFT core + bit-reverse components.
--
--               FFT:
--                 Fully pipelined integer FFT core.
--                 Integer (Unscaled / Scaled) Forward Fast Fourier Transform,
--                 N = 8 to 512K (points of data),      
--                 For N > 512K you should use 2D-FFT scheme
--                 Algorithm: Single-Path Delay-Feedback butterfly Radix-2 (DIF*)
--
-- * - Decimation in frequency. Radix-2: 2 data words per clock.
--
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

entity int_spdf_single_fft is
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
end int_spdf_single_fft;

architecture int_spdf_single_fft of int_spdf_single_fft is

---------------- Output data ----------------
signal fft_re     : std_logic_vector(FORMAT*NFFT+DATA_WIDTH-1 downto 0);
signal fft_im     : std_logic_vector(FORMAT*NFFT+DATA_WIDTH-1 downto 0);
signal fft_vl     : std_logic;            
    
signal rev_re      : std_logic_vector(FORMAT*NFFT+DATA_WIDTH-1 downto 0);
signal rev_im      : std_logic_vector(FORMAT*NFFT+DATA_WIDTH-1 downto 0);
signal rev_vl      : std_logic;

begin

    xFFTK: entity work.int_spdf_fftNk
        generic map (
            XUSE         => XUSE,
            XSER         => XSER,
            
            FORMAT       => FORMAT,
            RNDMODE      => RNDMODE,

            DATA_WIDTH   => DATA_WIDTH,
            TWDL_WIDTH   => TWDL_WIDTH,
            NFFT         => NFFT
        )   
        port map ( 
            ---- Common signals ----
            RST          => RST,    
            CLK          => CLK,    
            ---- Input data ----
            DI_RE        => DI_RE,
            DI_IM        => DI_IM,
            DI_EN        => DI_EN,
            ---- Output data ----
            DO_RE        => fft_re,
            DO_IM        => fft_im,
            DO_VL        => fft_vl
        );

    -------------------- BIT REVERSE ORDER --------------------
    xBR_RE : entity work.int_bitrev_order
        generic map (
            PAIR       => FALSE,
            STAGES     => NFFT,
            NWIDTH     => FORMAT*NFFT+DATA_WIDTH
        )
        port map (
            clk        => clk,
            reset      => RST,
    
            di_dt      => fft_re,
            di_en      => fft_vl,
            do_dt      => rev_re,
            do_vl      => rev_vl
        );
    
    xBR_IM : entity work.int_bitrev_order
        generic map (
            PAIR       => FALSE,        
            STAGES     => NFFT,
            NWIDTH     => FORMAT*NFFT+DATA_WIDTH
        )
        port map (
            clk        => clk,
            reset      => RST,
    
            di_dt      => fft_im,
            di_en      => fft_vl,
            do_dt      => rev_im,
            do_vl      => open
        );

DO_RE <= rev_re;
DO_IM <= rev_im;
DO_VL <= rev_vl;

end int_spdf_single_fft;