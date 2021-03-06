  
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all; 
use work.Image_Data_Package.all;

      
ENTITY Object_Recognition IS

PORT (
  CLK : IN STD_LOGIC;
  Camera_CLK_Lane      : IN     STD_LOGIC;
  Camera_Data_Lane     : IN     STD_LOGIC_VECTOR (1 downto 0);
  Camera_Enable        : OUT    STD_LOGIC;
  Camera_SCL           : INOUT  STD_LOGIC;
  Camera_SDA           : INOUT  STD_LOGIC;
  oHDMI_TX             : OUT    STD_LOGIC_VECTOR(2 downto 0);
  oHDMI_CLK            : OUT    STD_LOGIC;
  iHDMI_HPD            : IN     STD_LOGIC

);
END Object_Recognition;

ARCHITECTURE BEHAVIORAL OF Object_Recognition IS

  CONSTANT CLK_Frequency : NATURAL := 48000000;
  CONSTANT Row_Buf  : BOOLEAN := true;
  CONSTANT Debug_Mode  : NATURAL := 0;
  CONSTANT CC_G_Mult : NATURAL := 3;
  CONSTANT CC_G_Div  : NATURAL := 5;
  CONSTANT CC_B_Mult : NATURAL := 1;
  CONSTANT CC_B_Div  : NATURAL := 1;
  CONSTANT Ye_H_Min : NATURAL := 170;
  CONSTANT Ye_H_Max : NATURAL := 45;
  CONSTANT Ye_S_Min : NATURAL := 100;
  CONSTANT Ye_V_Min : NATURAL := 60;
  CONSTANT Bk_H_Min : NATURAL := 0;
  CONSTANT Bk_H_Max : NATURAL := 255;
  CONSTANT Bk_S_Max : NATURAL := 70;
  CONSTANT Bk_V_Max : NATURAL := 60;
  CONSTANT Bl_H_Min : NATURAL := 105;
  CONSTANT Bl_H_Max : NATURAL := 150;
  CONSTANT Bl_S_Min : NATURAL := 120;
  CONSTANT Bl_V_Min : NATURAL := 50;
  CONSTANT Wh_H_Min : NATURAL := 0;
  CONSTANT Wh_H_Max : NATURAL := 255;
  CONSTANT Wh_S_Max : NATURAL := 120;
  CONSTANT Wh_V_Min : NATURAL := 200;
  CONSTANT Enable_Compression  : BOOLEAN := true;
  CONSTANT Max_Area            : NATURAL := 4;
  CONSTANT Min_Area            : NATURAL := 2;
  CONSTANT Min_Pixel_Num       : NATURAL := ((Max_Area**2)/2)*1;
  CONSTANT Blob_Min_H  : NATURAL := 3;
  CONSTANT Blob_Min_W  : NATURAL := 3;
  CONSTANT Blob_Max_H  : NATURAL := 20;
  CONSTANT Blob_Max_W  : NATURAL := 40;
  CONSTANT Cone_31_Dist_Mult : NATURAL := 3;
  CONSTANT Cone_32_Dist_Mult : NATURAL := 2;
  CONSTANT Capture_Output      : NATURAL := 6;
  CONSTANT Force_Mono          : BOOLEAN := false;
  CONSTANT Capture_Color_Depth : NATURAL := 1;
  CONSTANT Capture_Compression : NATURAL := 2;
  CONSTANT Full_Image          : BOOLEAN := true;
  SIGNAL Color_Select          : NATURAL range 0 to 3 := 2;
  SIGNAL Camera_Stream         : rgb_stream;
  SIGNAL Color_Correction_Stream     : rgb_stream;
  SIGNAL S_CC_G_Mult : NATURAL := 3;
  SIGNAL S_CC_G_Div  : NATURAL := 5;
  SIGNAL S_CC_B_Mult : NATURAL := 1;
  SIGNAL S_CC_B_Div  : NATURAL := 1;
  SIGNAL RGB2HSV_Stream       : rgb_stream;
  SIGNAL Yellow_Filter_Stream   : rgb_stream;
  SIGNAL S_Ye_H_Min : NATURAL := 170;
  SIGNAL S_Ye_H_Max : NATURAL := 45;
  SIGNAL S_Ye_S_Min : NATURAL := 100;
  SIGNAL S_Ye_V_Min : NATURAL := 60;
  SIGNAL S_Bk_H_Min : NATURAL := 0;
  SIGNAL S_Bk_H_Max : NATURAL := 255;
  SIGNAL S_Bk_S_Max : NATURAL := 70;
  SIGNAL S_Bk_V_Max : NATURAL := 60;
  SIGNAL S_Bl_H_Min : NATURAL := 105;
  SIGNAL S_Bl_H_Max : NATURAL := 150;
  SIGNAL S_Bl_S_Min : NATURAL := 120;
  SIGNAL S_Bl_V_Min : NATURAL := 50;
  SIGNAL S_Wh_H_Min : NATURAL := 0;
  SIGNAL S_Wh_H_Max : NATURAL := 255;
  SIGNAL S_Wh_S_Max : NATURAL := 120;
  SIGNAL S_Wh_V_Min : NATURAL := 200;
  SIGNAL Black_Filter_Stream   : rgb_stream;
  SIGNAL Blue_Filter_Stream   : rgb_stream;
  SIGNAL White_Filter_Stream   : rgb_stream;
  SIGNAL Area_Compression_Pixel     : STD_LOGIC_VECTOR(3 downto 0);
  SIGNAL Area_Compression_New_Pixel : STD_LOGIC;
  SIGNAL Area_Compression_Column    : NATURAL range 0 to 639;
  SIGNAL Area_Compression_Row       : NATURAL range 0 to 479;
  TYPE Blob_Data IS RECORD
  Busy       : STD_LOGIC;
  Blobs      : NATURAL   range 0 to 32;
  Addr       : NATURAL   range 0 to 31;
  X0         : NATURAL   range 0 to Image_Width-1;
  X1         : NATURAL   range 0 to Image_Width-1;
  Y0         : NATURAL   range 0 to Image_Height-1;
  Y1         : NATURAL   range 0 to Image_Height-1;
  END RECORD Blob_Data;
  TYPE blob_array IS ARRAY (0 to 3) OF Blob_Data;
  SIGNAL blob_data_array : blob_array;
  TYPE Cone_Data IS RECORD
  Busy     : STD_LOGIC;
  Cones    : NATURAL   range 0 to 16;
  Addr     : NATURAL   range 0 to 16-1;
  X        : NATURAL   range 0 to Image_Width-1;
  Y        : NATURAL   range 0 to Image_Height-1;
  END RECORD Cone_Data;
  TYPE cone_array IS ARRAY (0 to 1) OF Cone_Data;
  SIGNAL cone_data_array : cone_array;
  SIGNAL Square_iStream : rgb_stream;
  SIGNAL Blob_Out           : Blob_Data;
  SIGNAL Square_oStream : rgb_stream;
  SIGNAL Cross_oStream : rgb_stream;
  SIGNAL Cross1_oStream : rgb_stream;
  SIGNAL Combine_Stream : rgb_stream;
  SIGNAL ISSP_source  : std_logic_vector (7 downto 0);
  SIGNAL ISSP1_source : std_logic_vector (7 downto 0);
  SIGNAL ISSP2_source : std_logic_vector (7 downto 0);
  SIGNAL ISSP3_source : std_logic_vector (7 downto 0);
  SIGNAL ISSP4_source : std_logic_vector (7 downto 0);
  SIGNAL ISSP_probe   : std_logic_vector (31 downto 0);
  SIGNAL ISSP1_probe  : std_logic_vector (31 downto 0);
  SIGNAL ISSP2_probe  : std_logic_vector (31 downto 0);
  SIGNAL ISSP3_probe  : std_logic_vector (31 downto 0);
  SIGNAL ISSP4_probe  : std_logic_vector (31 downto 0);
  SIGNAL Camera_Capture_iStream     : rgb_stream;
  SIGNAL Camera_Capture_Read_Column    : NATURAL          range 0 to 639;
  SIGNAL Camera_Capture_Read_Row       : NATURAL          range 0 to 479;
  SIGNAL Camera_Capture_Read_Data      : STD_LOGIC_VECTOR (23 downto 0);
  SIGNAL Camera_Capture_SDRAM_Read_Ena : STD_LOGIC;
  CONSTANT RGB   : BOOLEAN := (Capture_Output < 2 OR Capture_Output > 4) AND NOT Force_Mono;
  SIGNAL HDMI_Out_VS_PCLK   : STD_LOGIC;
  SIGNAL HDMI_Out_VS_SCLK   : STD_LOGIC;
  SIGNAL HDMI_Out_VS_R      : STD_LOGIC_VECTOR (7 downto 0);
  SIGNAL HDMI_Out_VS_G      : STD_LOGIC_VECTOR (7 downto 0);
  SIGNAL HDMI_Out_VS_B      : STD_LOGIC_VECTOR (7 downto 0);
  SIGNAL HDMI_Out_VS_HS     : STD_LOGIC;
  SIGNAL HDMI_Out_VS_VS     : STD_LOGIC;
  SIGNAL HDMI_Out_VS_DE     : STD_LOGIC;
  COMPONENT CSI_Camera IS
  GENERIC (
      CLK_Frequency : NATURAL := 12000000;
    Row_Buf       : BOOLEAN := false; 
    CLK_as_PCLK   : BOOLEAN := false 

  );
  PORT (
    CLK : IN STD_LOGIC;
    Reset     : IN STD_LOGIC := '0';                
    CLK_Lane  : IN STD_LOGIC;                       
    Data_Lane : IN STD_LOGIC_VECTOR(1 downto 0);    
    SCL       : INOUT STD_LOGIC;
    SDA       : INOUT STD_LOGIC;
    oStream   : OUT rgb_stream

  );
  END COMPONENT;
  COMPONENT Color_Correction_Filter IS
  GENERIC (
      CLK_Edge    : BOOLEAN := true 

  );
  PORT (
    CLK : IN STD_LOGIC;
    R_Multiplier : IN NATURAL range 0 to 15 := 1;
    R_Divider    : IN NATURAL range 0 to 15 := 1;
    R_Add        : IN INTEGER range -64 to 63 := 0;
    G_Multiplier : IN NATURAL range 0 to 15 := 1;
    G_Divider    : IN NATURAL range 0 to 15 := 1;
    G_Add        : IN INTEGER range -64 to 63 := 0;
    B_Multiplier : IN NATURAL range 0 to 15 := 1;
    B_Divider    : IN NATURAL range 0 to 15 := 1;
    B_Add        : IN INTEGER range -64 to 63 := 0;
    iStream      : in   rgb_stream;
    oStream      : out  rgb_stream

  );
  END COMPONENT;
  COMPONENT RGB2HSV_Filter IS
  GENERIC (
      CLK_Edge    : BOOLEAN := true 

  );
  PORT (
    CLK : IN STD_LOGIC;
    iStream    : in   rgb_stream;
    oStream    : out  rgb_stream

  );
  END COMPONENT;
  COMPONENT Color_Threshold_HSV_Filter IS
  GENERIC (
      CLK_Edge    : BOOLEAN := true 

  );
  PORT (
    CLK : IN STD_LOGIC;
    H_Min : IN NATURAL := 0;   
    H_Max : IN NATURAL := 255; 
    S_Min : IN NATURAL := 0;   
    S_Max : IN NATURAL := 255; 
    V_Min : IN NATURAL := 0;   
    V_Max : IN NATURAL := 255; 
    iStream    : in   rgb_stream;
    oStream    : out  rgb_stream

  );
  END COMPONENT;
  COMPONENT AreaLimitedCompression IS
  GENERIC (
      Min_Pixel_Num  : NATURAL := 4;  
    MAX_Area    : NATURAL range 1 to 24 := 10; 
    MIN_Area    : NATURAL range 1 to 24 := 1;
    Colors      : NATURAL := 1;
    Start_Row   : NATURAL := 0;
    CLK_Edge    : BOOLEAN := true 

  );
  PORT (
    CLK : IN STD_LOGIC;
    iPixel     : IN STD_LOGIC_VECTOR(Colors-1 downto 0);
    iColumn    : IN NATURAL range 0 to Image_Width-1;
    iRow       : IN NATURAL range 0 to Image_Height-1;
    iNew_Pixel : IN STD_LOGIC;
    oPixel     : OUT STD_LOGIC_VECTOR(Colors-1 downto 0);
    oColumn    : OUT NATURAL range 0 to Image_Width-1;
    oRow       : OUT NATURAL range 0 to Image_Height-1;
    oNew_Pixel : OUT STD_LOGIC

  );
  END COMPONENT;
  COMPONENT Blob_Detect IS
  GENERIC (
      Blob_Number     : NATURAL := 32;
    Blob_Buffer     : NATURAL := 8;
    Edge_Reg_Size   : NATURAL := 3;
    Min_Blob_Width  : NATURAL := 4;
    Min_Blob_Height : NATURAL := 2;
    Max_Blob_Width  : NATURAL := 20;
    Max_Blob_Height : NATURAL := 15;
    Upscale_Mult    : NATURAL := 4;
    Upscale_Start   : NATURAL := 100 

  );
  PORT (
    CLK : IN STD_LOGIC;
    New_Pixel : IN STD_LOGIC;
    Pixel_In  : IN STD_LOGIC; 
    Column    : IN NATURAL range 0 to 639;
    Row       : IN NATURAL range 0 to 479;
    Blob_Busy : OUT STD_LOGIC := '0';
    Blobs     : OUT NATURAL range 0 to Blob_Number;
    Blob_Addr : IN  NATURAL range 0 to Blob_Number-1;
    Blob_X0   : OUT NATURAL range 0 to Image_Width-1;
    Blob_X1   : OUT NATURAL range 0 to Image_Width-1;
    Blob_Y0   : OUT NATURAL range 0 to Image_Height-1;
    Blob_Y1   : OUT NATURAL range 0 to Image_Height-1

  );
  END COMPONENT;
  COMPONENT Cone_Detection IS
  GENERIC (
      Blob_Number     : NATURAL := 32;
    Cone_Number     : NATURAL := 16;
    Max_11Dist_Mult : NATURAL := 2;  
    Max_11Dist_Div  : NATURAL := 1;
    Max_12Dist_Mult : NATURAL := 1;  
    Max_12Dist_Div  : NATURAL := 1

  );
  PORT (
    CLK : IN STD_LOGIC;
    New_Pixel    : IN STD_LOGIC;
    Blob_Busy_1  : IN STD_LOGIC;
    iBlobs_1     : IN NATURAL range 0 to Blob_Number-1;
    iBlob_Addr_1 : OUT  NATURAL range 0 to Blob_Number-1;
    iBlob_X0_1   : IN NATURAL range 0 to Image_Width-1;
    iBlob_X1_1   : IN NATURAL range 0 to Image_Width-1;
    iBlob_Y0_1   : IN NATURAL range 0 to Image_Height-1;
    iBlob_Y1_1   : IN NATURAL range 0 to Image_Height-1;
    Blob_Busy_2  : IN STD_LOGIC;
    iBlobs_2     : IN NATURAL range 0 to Blob_Number-1;
    iBlob_Addr_2 : OUT  NATURAL range 0 to Blob_Number-1;
    iBlob_X0_2   : IN NATURAL range 0 to Image_Width-1;
    iBlob_X1_2   : IN NATURAL range 0 to Image_Width-1;
    iBlob_Y0_2   : IN NATURAL range 0 to Image_Height-1;
    iBlob_Y1_2   : IN NATURAL range 0 to Image_Height-1;
    oBusy        : OUT STD_LOGIC;
    oCones       : OUT NATURAL range 0 to Cone_Number;
    oCones_Addr  : IN  NATURAL range 0 to Cone_Number-1;
    oCones_X     : OUT NATURAL range 0 to Image_Width-1;
    oCones_Y     : OUT NATURAL range 0 to Image_Height-1

  );
  END COMPONENT;
  COMPONENT Draw_Squares IS
  GENERIC (
      Max_Square_Number : NATURAL := 32;
    Width             : NATURAL := 4;
    Color             : STD_LOGIC_VECTOR(23 downto 0) := x"FF0000" 

  );
  PORT (
    CLK : IN STD_LOGIC;
    Squares     : IN  NATURAL range 0 to Max_Square_Number;
    Square_Addr : BUFFER NATURAL range 0 to Max_Square_Number-1;
    Square_X0   : IN  NATURAL range 0 to Image_Width-1;
    Square_X1   : IN  NATURAL range 0 to Image_Width-1;
    Square_Y0   : IN  NATURAL range 0 to Image_Height-1;
    Square_Y1   : IN  NATURAL range 0 to Image_Height-1;
    iStream    : in   rgb_stream;
    oStream    : out  rgb_stream

  );
  END COMPONENT;
  COMPONENT Draw_Crosses IS
  GENERIC (
      Max_Cross_Number  : NATURAL := 32;
    Width             : NATURAL := 4;
    Length            : NATURAL := 8;
    Color             : STD_LOGIC_VECTOR(23 downto 0) := x"FF0000" 

  );
  PORT (
    CLK : IN STD_LOGIC;
    Crosses     : IN  NATURAL range 0 to Max_Cross_Number;
    Cross_Addr  : BUFFER NATURAL range 0 to Max_Cross_Number-1;
    Cross_X     : IN NATURAL range 0 to Image_Width-1;
    Cross_Y     : IN NATURAL range 0 to Image_Height-1;
    iStream    : in   rgb_stream;
    oStream    : out  rgb_stream

  );
  END COMPONENT;
  COMPONENT ISSP IS
  
  PORT (
    source : out std_logic_vector(7 downto 0);                      
    probe  : in  std_logic_vector(31 downto 0)  := (others => 'X') 

  );
  END COMPONENT;
  COMPONENT Camera_Capture IS
  GENERIC (
      Compression : NATURAL := 3;  
    Width       : NATURAL := 4;  
    Full_Image  : BOOLEAN := true; 
    RGB         : BOOLEAN := true;
    CLK_Edge    : BOOLEAN := true 

  );
  PORT (
    CLK : IN STD_LOGIC;
    New_Pixel   : IN     STD_LOGIC := '0';
    Column      : IN     NATURAL range 0 to Image_Width-1 := 0;
    Row         : IN     NATURAL range 0 to Image_Height-1 := 0;
    Pixel_R     : IN     STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    Pixel_G     : IN     STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    Pixel_B     : IN     STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    Read_Column : IN     NATURAL range 0 to 639 := 0;
    Read_Row    : IN     NATURAL range 0 to 479 := 0;
    Read_Data   : OUT    STD_LOGIC_VECTOR(23 downto 0) := (others => '0')

  );
  END COMPONENT;
  COMPONENT CRT_Controller IS
  GENERIC (
      image_size_div : NATURAL := 1

  );
  PORT (
    CLK : IN STD_LOGIC;
    Read_Column : OUT    NATURAL range 0 to 639 := 0;
    Read_Row    : OUT    NATURAL range 0 to 479 := 0;
    Read_Data   : IN     STD_LOGIC_VECTOR(23 downto 0) := (others => '0');
    Read_Ena    : OUT    STD_LOGIC := '0';
    VS_PCLK    : OUT    STD_LOGIC;
    VS_SCLK    : OUT    STD_LOGIC;
    VS_R       : OUT    STD_LOGIC_VECTOR (7 downto 0);
    VS_G       : OUT    STD_LOGIC_VECTOR (7 downto 0);
    VS_B       : OUT    STD_LOGIC_VECTOR (7 downto 0);
    VS_HS      : OUT    STD_LOGIC;
    VS_VS      : OUT    STD_LOGIC;
    VS_DE      : OUT    STD_LOGIC

  );
  END COMPONENT;
  COMPONENT HDMI_Out IS
  
  PORT (
    CLK : IN STD_LOGIC;
    VS_PCLK    : IN  STD_LOGIC;
    VS_SCLK    : IN  STD_LOGIC;
    VS_R       : IN  STD_LOGIC_VECTOR (7 downto 0);
    VS_G       : IN  STD_LOGIC_VECTOR (7 downto 0);
    VS_B       : IN  STD_LOGIC_VECTOR (7 downto 0);
    VS_HS      : IN  STD_LOGIC;
    VS_VS      : IN  STD_LOGIC;
    VS_DE      : IN  STD_LOGIC;
    oHDMI_DATA : OUT STD_LOGIC_VECTOR(2 downto 0);
    oHDMI_CLK  : OUT STD_LOGIC;
    iHDMI_HPD  : IN  STD_LOGIC

  );
  END COMPONENT;
  
BEGIN

  Camera_Enable <= '1';

   S_CC_G_Mult <= TO_INTEGER(UNSIGNED(ISSP1_source)) when Debug_Mode = 1 else CC_G_Mult;
   S_CC_G_Div  <= TO_INTEGER(UNSIGNED(ISSP2_source)) when Debug_Mode = 1 else CC_G_Div;
   S_CC_B_Mult <= TO_INTEGER(UNSIGNED(ISSP3_source)) when Debug_Mode = 1 else CC_B_Mult;
   S_CC_B_Div  <= TO_INTEGER(UNSIGNED(ISSP4_source)) when Debug_Mode = 1 else CC_B_Div;

   S_Ye_H_Min <= TO_INTEGER(UNSIGNED(ISSP1_source)) when Debug_Mode = 2 else Ye_H_Min;
    S_Ye_H_Max <= TO_INTEGER(UNSIGNED(ISSP2_source)) when Debug_Mode = 2 else Ye_H_Max;
   S_Ye_S_Min <= TO_INTEGER(UNSIGNED(ISSP3_source)) when Debug_Mode = 2 else Ye_S_Min;
    S_Ye_V_Min <= TO_INTEGER(UNSIGNED(ISSP4_source)) when Debug_Mode = 2 else Ye_V_Min;
     S_Bk_H_Min <= TO_INTEGER(UNSIGNED(ISSP1_source)) when Debug_Mode = 3 else Bk_H_Min;
   S_Bk_H_Max <= TO_INTEGER(UNSIGNED(ISSP2_source)) when Debug_Mode = 3 else Bk_H_Max;
    S_Bk_S_Max <= TO_INTEGER(UNSIGNED(ISSP3_source)) when Debug_Mode = 3 else Bk_S_Max;
    S_Bk_V_Max <= TO_INTEGER(UNSIGNED(ISSP4_source)) when Debug_Mode = 3 else Bk_V_Max;
   S_Bl_H_Min <= TO_INTEGER(UNSIGNED(ISSP1_source)) when Debug_Mode = 4 else Bl_H_Min;
   S_Bl_H_Max <= TO_INTEGER(UNSIGNED(ISSP2_source)) when Debug_Mode = 4 else Bl_H_Max;
   S_Bl_S_Min <= TO_INTEGER(UNSIGNED(ISSP3_source)) when Debug_Mode = 4 else Bl_S_Min;
    S_Bl_V_Min <= TO_INTEGER(UNSIGNED(ISSP4_source)) when Debug_Mode = 4 else Bl_V_Min;
     S_Wh_H_Min <= TO_INTEGER(UNSIGNED(ISSP1_source)) when Debug_Mode = 5 else Wh_H_Min;
   S_Wh_H_Max <= TO_INTEGER(UNSIGNED(ISSP2_source)) when Debug_Mode = 5 else Wh_H_Max;
   S_Wh_S_Max <= TO_INTEGER(UNSIGNED(ISSP3_source)) when Debug_Mode = 5 else Wh_S_Max;
   S_Wh_V_Min <= TO_INTEGER(UNSIGNED(ISSP4_source)) when Debug_Mode = 5 else Wh_V_Min;

  Square_iStream.R         <= (others => Area_Compression_Pixel(color_select));
  Square_iStream.G         <= (others => Area_Compression_Pixel(color_select));
  Square_iStream.B         <= (others => Area_Compression_Pixel(color_select));
  Square_iStream.Column    <= Area_Compression_Column;
  Square_iStream.Row       <= Area_Compression_Row;
  Square_iStream.New_Pixel <= Area_Compression_New_Pixel;

  Blob_Out.Busy  <= Blob_data_array(color_select).Busy;
  Blob_Out.Blobs <= Blob_data_array(color_select).Blobs;
  Blob_Out.X0    <= Blob_data_array(color_select).X0;
  Blob_Out.X1    <= Blob_data_array(color_select).X1;
  Blob_Out.Y0    <= Blob_data_array(color_select).Y0;
  Blob_Out.Y1    <= Blob_data_array(color_select).Y1;

  Combine_Stream.R         <= (others => (Area_Compression_Pixel(0) OR Area_Compression_Pixel(1)));
  Combine_Stream.G         <= (others => (Area_Compression_Pixel(2) OR Area_Compression_Pixel(1)));
  Combine_Stream.B         <= (others => Area_Compression_Pixel(3));
  Combine_Stream.Column    <= Area_Compression_Column;
  Combine_Stream.Row       <= Area_Compression_Row;
  Combine_Stream.New_Pixel <= Area_Compression_New_Pixel;
  Camera_Capture_iStream <= Camera_Stream when Capture_Output = 0 else
  Color_Correction_Stream when Capture_Output = 1 else
  RGB2HSV_Stream when Capture_Output = 2 else
  Yellow_Filter_Stream when Capture_Output = 3 AND Color_Select = 0 else
  Black_Filter_Stream when Capture_Output = 3 AND Color_Select = 1 else
  Blue_Filter_Stream when Capture_Output = 3 AND Color_Select = 2 else
  White_Filter_Stream when Capture_Output = 3 AND Color_Select = 3 else
  Square_iStream when Capture_Output = 4 else
  Square_oStream when Capture_Output = 5 else
  Cross_oStream when Capture_Output = 6 else
  Combine_Stream;
  ISSP_probe  <= STD_LOGIC_VECTOR(TO_UNSIGNED(cone_data_array(0).Cones, 32)) when Capture_Output = 6 else STD_LOGIC_VECTOR(TO_UNSIGNED(Blob_Out.Blobs, 32))          when Capture_Output = 5 else (others => '0');
  ISSP1_probe <= STD_LOGIC_VECTOR(TO_UNSIGNED(cone_data_array(1).Cones, 32)) when Capture_Output = 6 else STD_LOGIC_VECTOR(TO_UNSIGNED(Blob_Out.X0, 32))             when Capture_Output = 5 else (others => '0');
  ISSP2_probe <= STD_LOGIC_VECTOR(TO_UNSIGNED(cone_data_array(0).X, 32))     when Capture_Output = 6 else STD_LOGIC_VECTOR(TO_UNSIGNED(Blob_Out.Y0, 32))             when Capture_Output = 5 else (others => '0');
  ISSP3_probe <= STD_LOGIC_VECTOR(TO_UNSIGNED(cone_data_array(1).X, 32))     when Capture_Output = 6 else STD_LOGIC_VECTOR(TO_UNSIGNED(Blob_Out.X1-Blob_Out.X0, 32)) when Capture_Output = 5 else (others => '0');
  ISSP4_probe <= STD_LOGIC_VECTOR(TO_UNSIGNED(cone_data_array(0).Y, 32))     when Capture_Output = 6 else STD_LOGIC_VECTOR(TO_UNSIGNED(Blob_Out.Y1-Blob_Out.Y0, 32)) when Capture_Output = 5 else (others => '0');
  CSI_Camera1 : CSI_Camera
  GENERIC MAP (
      CLK_Frequency => CLK_Frequency,
    CLK_as_PCLK   => Row_Buf

  ) PORT MAP (
    CLK => CLK,
    Reset         => '0',
    CLK_Lane      => Camera_CLK_Lane,
    Data_Lane     => Camera_Data_Lane,
    SCL           => Camera_SCL,
    SDA           => Camera_SDA,
    oStream       => Camera_Stream

    
  );
  Color_Correction_Filter1 : Color_Correction_Filter
  GENERIC MAP (
      CLK_Edge     => false

  ) PORT MAP (
    CLK => CLK,
    R_Multiplier => 1,
    R_Divider    => 1,
    R_Add        => 0,
    G_Multiplier => S_CC_G_Mult,
    G_Divider    => S_CC_G_Div,
    G_Add        => 0,
    B_Multiplier => S_CC_B_Mult,
    B_Divider    => S_CC_B_Div,
    B_Add        => 0,
    iStream      => Camera_Stream,
    oStream      => Color_Correction_Stream

    
  );
  RGB2HSV_Filter1 : RGB2HSV_Filter
  GENERIC MAP (
      CLK_Edge => true

  ) PORT MAP (
    CLK => CLK,
    iStream  => Color_Correction_Stream,
    oStream  => RGB2HSV_Stream

    
  );
  Color_Threshold_HSV_Filter1 : Color_Threshold_HSV_Filter
  GENERIC MAP (
      CLK_Edge   => false

  ) PORT MAP (
    CLK => CLK,
    H_Min      => S_Ye_H_Min,
    H_Max      => S_Ye_H_Max,
    S_Min      => S_Ye_S_Min,
    S_Max      => 255,
    V_Min      => S_Ye_V_Min,
    V_Max      => 255,
    iStream    => RGB2HSV_Stream,
    oStream    => Yellow_Filter_Stream

    
  );
  Color_Threshold_HSV_Filter2 : Color_Threshold_HSV_Filter
  GENERIC MAP (
      CLK_Edge   => false

  ) PORT MAP (
    CLK => CLK,
    H_Min      => S_Bk_H_Min,
    H_Max      => S_Bk_H_Max,
    S_Min      => 0,
    S_Max      => S_Bk_S_Max,
    V_Min      => 0,
    V_Max      => S_Bk_V_Max,
    iStream    => RGB2HSV_Stream,
    oStream    => Black_Filter_Stream

    
  );
  Color_Threshold_HSV_Filter3 : Color_Threshold_HSV_Filter
  GENERIC MAP (
      CLK_Edge   => false

  ) PORT MAP (
    CLK => CLK,
    H_Min      => S_Bl_H_Min,
    H_Max      => S_Bl_H_Max,
    S_Min      => S_Bl_S_Min,
    S_Max      => 255,
    V_Min      => S_Bl_V_Min,
    V_Max      => 255,
    iStream    => RGB2HSV_Stream,
    oStream    => Blue_Filter_Stream

    
  );
  Color_Threshold_HSV_Filter4 : Color_Threshold_HSV_Filter
  GENERIC MAP (
      CLK_Edge   => false

  ) PORT MAP (
    CLK => CLK,
    H_Min      => S_Wh_H_Min,
    H_Max      => S_Wh_H_Max,
    S_Min      => 0,
    S_Max      => S_Wh_S_Max,
    V_Min      => S_Wh_V_Min,
    V_Max      => 255,
    iStream    => RGB2HSV_Stream,
    oStream    => White_Filter_Stream

    
  );
  Generate1 : if Enable_Compression GENERATE
    AreaLimitedCompression1 : AreaLimitedCompression
  GENERIC MAP (
      Min_Pixel_Num => Min_Pixel_Num,  
      MAX_Area      => Max_Area,
      MIN_Area      => Min_Area,
      Start_Row     => 0,
      Colors        => 4,
      CLK_Edge      => true

  ) PORT MAP (
      CLK => CLK,
      iNew_Pixel    => Yellow_Filter_Stream.New_Pixel,
      iColumn       => Yellow_Filter_Stream.Column,
      iRow          => Yellow_Filter_Stream.Row,
      iPixel(0)     => Yellow_Filter_Stream.R(0),
      iPixel(1)     => Black_Filter_Stream.R(0),
      iPixel(2)     => Blue_Filter_Stream.R(0),
      iPixel(3)     => White_Filter_Stream.R(0),
      oNew_Pixel    => Area_Compression_New_Pixel,
      oColumn       => Area_Compression_Column,
      oRow          => Area_Compression_Row,
      oPixel        => Area_Compression_Pixel

      
    );
  END GENERATE Generate1;
  Generate2 : if NOT Enable_Compression GENERATE
    Area_Compression_New_Pixel <= Yellow_Filter_Stream.New_Pixel;
    Area_Compression_Column    <= Yellow_Filter_Stream.Column;
    Area_Compression_Row       <= Yellow_Filter_Stream.Row;
    Area_Compression_Pixel(0)  <= Yellow_Filter_Stream.R(0);
    Area_Compression_Pixel(1)  <= Black_Filter_Stream.R(0);
    Area_Compression_Pixel(2)  <= Blue_Filter_Stream.R(0);
    Area_Compression_Pixel(3)  <= White_Filter_Stream.R(0);
  END GENERATE Generate2;
  Generate3 : for i in 0 to 3 GENERATE
    Blob_Detect1 : Blob_Detect
  GENERIC MAP (
      Blob_Number     => 32,
      Blob_Buffer     => 8,
      Min_Blob_Width  => Blob_Min_W,
      Min_Blob_Height => Blob_Min_H,
      Max_Blob_Width  => Blob_Max_W,
      Max_Blob_Height => Blob_Max_H,
      Upscale_Mult    => 1,
      Upscale_Start   => 0

  ) PORT MAP (
      CLK => CLK,
      New_Pixel       => Area_Compression_New_Pixel,
      Pixel_In        => Area_Compression_Pixel(i),
      Column          => Area_Compression_Column,
      Row             => Area_Compression_Row,
      Blob_Busy       => blob_data_array(i).Busy,
      Blobs           => blob_data_array(i).Blobs,
      Blob_Addr       => blob_data_array(i).Addr,
      Blob_X0         => blob_data_array(i).X0,
      Blob_X1         => blob_data_array(i).X1,
      Blob_Y0         => blob_data_array(i).Y0,
      Blob_Y1         => blob_data_array(i).Y1

      
    );
  END GENERATE Generate3;
  Generate4 : if Capture_Output = 6 GENERATE
    Generate5 : for i in 0 to 1 GENERATE
      Cone_Detection1 : Cone_Detection
  GENERIC MAP (
      Blob_Number     => 32,
        Cone_Number     => 16,
        Max_11Dist_Mult => Cone_31_Dist_Mult,
        Max_11Dist_Div  => 1,
        Max_12Dist_Mult => Cone_32_Dist_Mult,
        Max_12Dist_Div  => 1

  ) PORT MAP (
        CLK => CLK,
        New_Pixel       => Area_Compression_New_Pixel,
        Blob_Busy_1     => blob_data_array(i*2).Busy,
        iBlobs_1        => blob_data_array(i*2).Blobs,
        iBlob_Addr_1    => blob_data_array(i*2).Addr,
        iBlob_X0_1      => blob_data_array(i*2).X0,
        iBlob_X1_1      => blob_data_array(i*2).X1,
        iBlob_Y0_1      => blob_data_array(i*2).Y0,
        iBlob_Y1_1      => blob_data_array(i*2).Y1,
        Blob_Busy_2     => blob_data_array(i*2+1).Busy,
        iBlobs_2        => blob_data_array(i*2+1).Blobs,
        iBlob_Addr_2    => blob_data_array(i*2+1).Addr,
        iBlob_X0_2      => blob_data_array(i*2+1).X0,
        iBlob_X1_2      => blob_data_array(i*2+1).X1,
        iBlob_Y0_2      => blob_data_array(i*2+1).Y0,
        iBlob_Y1_2      => blob_data_array(i*2+1).Y1,
        oBusy           => cone_data_array(i).Busy,
        oCones          => cone_data_array(i).Cones,
        oCones_Addr     => cone_data_array(i).Addr,
        oCones_X        => cone_data_array(i).X,
        oCones_Y        => cone_data_array(i).Y

        
      );
    END GENERATE Generate5;
  END GENERATE Generate4;
  Generate6 : if Capture_Output < 6 GENERATE
    Blob_data_array(color_select).Addr <= Blob_Out.Addr;
  END GENERATE Generate6;
  Draw_Squares1 : Draw_Squares
  GENERIC MAP (
      Max_Square_Number => 32,
    Width             => 8,
    Color             => x"FF0000"

  ) PORT MAP (
    CLK => CLK,
    Squares           => Blob_Out.Blobs,
    Square_Addr       => Blob_Out.Addr,
    Square_X0         => Blob_Out.X0,
    Square_X1         => Blob_Out.X1,
    Square_Y0         => Blob_Out.Y0,
    Square_Y1         => Blob_Out.Y1,
    iStream           => Square_iStream,
    oStream           => Square_oStream

    
  );
  Draw_Crosses1 : Draw_Crosses
  GENERIC MAP (
      Max_Cross_Number => 16,
    Width            => 4,
    Length           => 20,
    Color            => x"00FF00"

  ) PORT MAP (
    CLK => CLK,
    Crosses     => cone_data_array(0).Cones,
    Cross_Addr  => cone_data_array(0).Addr,
    Cross_X     => cone_data_array(0).X,
    Cross_Y     => cone_data_array(0).Y,
    iStream     => Combine_Stream,
    oStream     => Cross1_oStream

    
  );
  Draw_Crosses2 : Draw_Crosses
  GENERIC MAP (
      Max_Cross_Number => 16,
    Width            => 4,
    Length           => 20,
    Color            => x"FF0000"

  ) PORT MAP (
    CLK => CLK,
    Crosses     => cone_data_array(1).Cones,
    Cross_Addr  => cone_data_array(1).Addr,
    Cross_X     => cone_data_array(1).X,
    Cross_Y     => cone_data_array(1).Y,
    iStream     => Cross1_oStream,
    oStream     => Cross_oStream

    
  );
  ISSP1 : ISSP  PORT MAP (
    source => ISSP_source,
    probe  => ISSP_probe

    
  );
  ISSP2 : ISSP  PORT MAP (
    source => ISSP1_source,
    probe  => ISSP1_probe

    
  );
  ISSP3 : ISSP  PORT MAP (
    source => ISSP2_source,
    probe  => ISSP2_probe

    
  );
  ISSP4 : ISSP  PORT MAP (
    source => ISSP3_source,
    probe  => ISSP3_probe

    
  );
  ISSP5 : ISSP  PORT MAP (
    source => ISSP4_source,
    probe  => ISSP4_probe

    
  );
  Camera_Capture1 : Camera_Capture
  GENERIC MAP (
      Compression => capture_compression,
    Width       => Capture_Color_Depth,
    Full_Image  => Full_Image,
    RGB         => RGB,
    CLK_Edge    => false

  ) PORT MAP (
    CLK => CLK,
    New_Pixel   => Camera_Capture_iStream.New_Pixel,
    Column      => Camera_Capture_iStream.Column,
    Row         => Camera_Capture_iStream.Row,
    Pixel_R     => Camera_Capture_iStream.R,
    Pixel_G     => Camera_Capture_iStream.G,
    Pixel_B     => Camera_Capture_iStream.B,
    Read_Column => Camera_Capture_Read_Column,
    Read_Row    => Camera_Capture_Read_Row,
    Read_Data   => Camera_Capture_Read_Data

    
  );
  CRT_Controller1 : CRT_Controller
  GENERIC MAP (
      image_size_div => 1

  ) PORT MAP (
    CLK => CLK,
    Read_Column => Camera_Capture_Read_Column,
    Read_Row    => Camera_Capture_Read_Row,
    Read_Data   => Camera_Capture_Read_Data,
    Read_Ena    => Camera_Capture_SDRAM_Read_Ena,
    VS_PCLK     => HDMI_Out_VS_PCLK,
    VS_SCLK     => HDMI_Out_VS_SCLK,
    VS_R        => HDMI_Out_VS_R,
    VS_G        => HDMI_Out_VS_G,
    VS_B        => HDMI_Out_VS_B,
    VS_HS       => HDMI_Out_VS_HS,
    VS_VS       => HDMI_Out_VS_VS,
    VS_DE       => HDMI_Out_VS_DE

    
  );
  HDMI_Out1 : HDMI_Out  PORT MAP (
    CLK => CLK,
    VS_PCLK    => HDMI_Out_VS_PCLK,
    VS_SCLK    => HDMI_Out_VS_SCLK,
    VS_R       => HDMI_Out_VS_R,
    VS_G       => HDMI_Out_VS_G,
    VS_B       => HDMI_Out_VS_B,
    VS_HS      => HDMI_Out_VS_HS,
    VS_VS      => HDMI_Out_VS_VS,
    VS_DE      => HDMI_Out_VS_DE,
    oHDMI_DATA => oHDMI_TX,
    oHDMI_CLK  => oHDMI_CLK,
    iHDMI_HPD  => iHDMI_HPD
  );
  
END BEHAVIORAL;