`timescale 1ns / 1ps
module top(
    input CLK,                  // board clock: 100 MHz
    input RST_BTN,              // reset button    
    input BTNC,                 // center button
    input SW0,                  // test switch 0 
    input SW1,                  // test switch 1
    input [3:0]BTN,             //  BTN  Up_Down_Left_Right
    output wire led,            // test LED
    output wire VGA_HS_O,       // horizontal sync output
    output wire VGA_VS_O,       // vertical sync output
    output wire [3:0] VGA_R,    // 4-bit VGA red output
    output wire [3:0] VGA_G,    // 4-bit VGA green output
    output wire [3:0] VGA_B     // 4-bit VGA blue output
    );

    wire rst = ~RST_BTN;        // reset is active low on Nexys 4

    // generate a 65 MHz pixel CLK
    reg [47:0] cnt;
    reg pix_CLK;
    always @(posedge CLK)   // ���W
        {pix_CLK, cnt} <= cnt + 48'hA666_6666_6666; // 1024*768 65MHz

    wire [10:0] x;        // current pixel x position
    wire [10:0] y;        // current pixel y position
    wire animate;         // high for one tick at end of active drawing
    
    //  VGA Display Module
    VGA1024x768 display (
        .i_clk(CLK),
        .i_pix_stb(pix_CLK),
        .i_rst(rst),
        .o_hs(VGA_HS_O), 
        .o_vs(VGA_VS_O), 
        .o_x(x), 
        .o_y(y),
        .o_animate(animate)
    );
    
    reg [11:0]vga_out; // VGA ��X
    wire [11:0]game1_out, game2_out, start_out, win_out, lose_out; // �U�صe������X�T��
    
    //      Start  Screen
    wire [10:0] start_Y,start_X;    // Zooming �� X, Y
    assign start_Y =  y [10:2];     // X  ��j8�� 
    assign start_X =  x [10:2];     // Y  ��j8��
    reg [15:0] Addr_start = 16'd0;  // block memory �� Address
    blk_mem_gen_5 start (          // block memory for Start Screen
      .clka(pix_CLK),             // input wire clka
      .addra(Addr_start),         // input wire [17 : 0] addra
      .douta(start_out)           // output wire [11 : 0] douta
    );
    //      Win  Screen
    wire [10:0] win_Y,win_X;      // Zooming �� X, Y
    assign win_Y =  y [10:2];     // X  ��j8�� 
    assign win_X =  x [10:2];     // Y  ��j8��
    reg [15:0] Addr_win = 16'd0;  // block memory �� Address
    blk_mem_gen_6 win (          // block memory for Win Screen
      .clka(pix_CLK),            // input wire clka
      .addra(Addr_win),          // input wire [17 : 0] addra
      .douta(win_out)            // output wire [11 : 0] douta
    );
    //      Lose  Screen
    wire [10:0] lose_Y,lose_X;      // Zooming �� X, Y
    assign lose_Y =  y [10:2];     // X  ��j8�� 
    assign lose_X =  x [10:2];     // Y  ��j8��
    reg [15:0] Addr_lose = 16'd0;  // block memory �� Address
    blk_mem_gen_7 lose (          // block memory for Lose Screen
      .clka(pix_CLK),             // input wire clka
      .addra(Addr_lose),          // input wire [17 : 0] addra
      .douta(lose_out)            // output wire [11 : 0] douta
    );
    
    ////    �]�m�e��  address
    always @(posedge pix_CLK)
    begin
    if (rst)                  // reset  address �k�s
        begin
            Addr_start = 16'd0;
            Addr_win = 16'd0;
            Addr_lose = 16'd0;
        end
    else
        begin                 // �]�w�U�e��Address
            Addr_start <= {start_Y[7:0], start_X[7:0]};
            Addr_win <= {win_Y[7:0], win_X[7:0]};
            Addr_lose <= {lose_Y[7:0], lose_X[7:0]};
        end
     end
     
     //     ����C���i��ΰѼ�
     reg game_1_start = 0, start_1 = 0, game_2_start = 0, start_2 = 0;
     wire over_1, resault_1, over_2, resault_2;
     
    //       �C���y�{����
    always @(posedge pix_CLK)
    begin
        if(rst)     // reset �Ѽƥ���l��
        begin
            vga_out <= start_out;
            game_1_start = 0;
            start_1 = 0;
            start_2 = 0;
        end
        else
        begin
            if (BTNC)   //   ���s�}�l�C��
            begin
                game_1_start = 1;
                start_1 = 1;
            end
            else if (game_1_start == 0 )    //  �٨S�}�l�C�� ��ܶ}�l�e��
            vga_out <= start_out;
            else if (game_1_start == 1)     // �Ĥ@���C��
            begin
                start_1 = 0;
                if(over_1 == 0)
                begin
                    vga_out <= game1_out; // ��ܲĤ@��
                    start_2 = 1;
                end
                else if (over_1 == 1)   // �Ĥ@������
                begin
                    start_2 = 0;
                    if (resault_1 == 0) vga_out <= lose_out;   // �Ĥ@������
                    if (resault_1 == 1)                      // �Ĥ@���ӧQ
                    begin
                        vga_out <= game2_out; // ��ܲĤG��
                        if (over_2 == 1)    // �ĤG������
                        begin
                            if (resault_2 == 0) vga_out <= lose_out;    // �ĤG������
                            if (resault_2 == 1) vga_out <= win_out;     // �ĤG���ӧQ
                        end
                    end
                end
            end
        end
    end
     

    // �Ĥ@�� module
     game1 game1(
    .vga_out(game1_out),
    .vgaPixel_Y(y),
    .vgaPixel_X(x),
    .pCLK(CLK),
    .pCLK2(pix_CLK),
    .pReset(rst),
    .BTN(BTN),
    .animate(animate),
    .start(start_1),
    .over(over_1),
    .resault(resault_1)
    );

    // �ĤG�� module    
     game2 game2(
    .vga_out(game2_out),
    .vgaPixel_Y(y),
    .vgaPixel_X(x),
    .pCLK(CLK),
    .pCLK2(pix_CLK),
    .pReset(rst),
    .BTN(BTN),
    .animate(animate),
    .start(start_2),
    .over(over_2),
    .resault(resault_2)
    );
    
    // vga_out to VGA_R, VGA_G, VGA_B
    color color(
    .clk(pix_CLK),
    .vga_out(vga_out),
    .RST(rst),
    .VGA_R(VGA_R),
    .VGA_G(VGA_G),
    .VGA_B(VGA_B)
    );

endmodule