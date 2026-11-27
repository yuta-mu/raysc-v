    // 2画素クラスタ閾値 (0..35 を1回ずつ)。index = {cy, cx} = cy*8 + cx
    function automatic logic [5:0] thr_alt_f(input logic [2:0] cy, input logic [2:0] cx);
        begin
            case ({cy, cx})
                6'd0 : thr_alt_f = 6'd0;
                6'd1 : thr_alt_f = 6'd1;
                6'd2 : thr_alt_f = 6'd12;
                6'd3 : thr_alt_f = 6'd13;
                6'd4 : thr_alt_f = 6'd24;
                6'd5 : thr_alt_f = 6'd25;
                6'd8 : thr_alt_f = 6'd18;
                6'd9 : thr_alt_f = 6'd19;
                6'd10: thr_alt_f = 6'd30;
                6'd11: thr_alt_f = 6'd31;
                6'd12: thr_alt_f = 6'd6;
                6'd13: thr_alt_f = 6'd7;
                6'd16: thr_alt_f = 6'd26;
                6'd17: thr_alt_f = 6'd27;
                6'd18: thr_alt_f = 6'd2;
                6'd19: thr_alt_f = 6'd3;
                6'd20: thr_alt_f = 6'd14;
                6'd21: thr_alt_f = 6'd15;
                6'd24: thr_alt_f = 6'd8;
                6'd25: thr_alt_f = 6'd9;
                6'd26: thr_alt_f = 6'd20;
                6'd27: thr_alt_f = 6'd21;
                6'd28: thr_alt_f = 6'd32;
                6'd29: thr_alt_f = 6'd33;
                6'd32: thr_alt_f = 6'd34;
                6'd33: thr_alt_f = 6'd35;
                6'd34: thr_alt_f = 6'd10;
                6'd35: thr_alt_f = 6'd11;
                6'd36: thr_alt_f = 6'd22;
                6'd37: thr_alt_f = 6'd23;
                6'd40: thr_alt_f = 6'd16;
                6'd41: thr_alt_f = 6'd17;
                6'd42: thr_alt_f = 6'd28;
                6'd43: thr_alt_f = 6'd29;
                6'd44: thr_alt_f = 6'd4;
                6'd45: thr_alt_f = 6'd5;
                default: thr_alt_f = 6'd0;
            endcase
        end
    endfunction
