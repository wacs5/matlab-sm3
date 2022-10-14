function [SM3Code,SM3CodeSpace]=sm3(Src,SrcIsHex,debug)
%%=================================================================================
%%  FileName            :   sm3.m
%%  Function            :   sm3
%%  Version             :   V1.0
%%  Author              :   wacs5
%%  email               :   wacs5@126.com
%%  Date                :   20221011(yyyymmdd)
%%  Description         :   Computes the hash value (SM3) of the string
%%  Argument            :
%%      Input
%%          Src         :   Input String
%%          SrcIsHex    :   Flag of String type(0 is ascii and GB2312, 1 is hex)
%%          debug       :   if debug=1, output the Intermediate calculation process
%%      Output
%%          SM3Code     :   SM3 of the string
%%          SM3CodeSpace:   SM3 of the string, split of space in 4 bytes (32bits)
%%  Example             :   
%%      (1) SM3Code=sm3('abc')          % return the sm3 of 'abc'
%%      (2) SM3Code=sm3('616263')       % return the sm3 of '616263'
%%      (3) SM3Code=sm3('616263',1)     % return the sm3 of 'abc'(Hex code:0x616263)
%%      (4) all(sm3('abc')-sm3('0X616263',1)==0)    % return true
%%      (5) SM3Code=sm3('a王')          % return the sm3 of string 'a王' in GBK(GB2312)
%%      (6) all(sm3('a王')-sm3('61CDF5',1)==0)    
%%=================================================================================
%%************START: argument check **************
%   the first argument is input string, default is abc
if nargin<1 || isempty(Src)
    disp('input string set to the default value: abc');
	Src='abc';		%default string for SM3
end
%   the second argument is string type, default is ascii and GBK
if nargin<2 || isempty(SrcIsHex)
	SrcIsHex=0;		%default string is ascii and GBK
end
%   the third argument is flag of debug
if nargin<3 || isempty(debug)
	debug=0;		%default debug is off
end
%%************ END : argument check **************
%%************START: preprocess **************
%   if input string is a hexadecimal number, convert to decimal integer
if SrcIsHex
    % get the length of hex string
	len=length(Src);
    % if length of hex string is odd, return an error.
	if mod(len,2)==1
		error([mfilename,' error: Input Hex string length is odd.']);
	end
    % if the first two characters are '0X', skip those two characters.
    if Src(1)=='0' && upper(Src(2))=='X'
        % skip the '0x' or '0X'
        Src(1:2)=[]; 
        % Recalculate the length of input string
        len=length(Src);
    end
    % Convert the hexadecimal number to decimal integer in two characters.
    % (1)Convert the row vector to two lines
    % (2)transpose the two lines vector to two column matrix
    % (3)convert each row (hex) to decimal integer
	Src=hex2dec(reshape(Src,2,len/2)');
    % Convert to a row vector in decimal integer
	Src=Src(:)';	
else
    %Src is an ascii or GBK string.
	%the code of matlab is unicode(2 bytes).  
	%	dec2hex(double('王'))=0X738B=0111 001110 001011 (4bit+6bit+6bit)
	%		first  byte of UTF：1110 + 4bit=1110 0111=0XE7
	%		second byte of UTF: 10 + 6bit=10 001110=0X8E
	%		third  byte of UTF: 10 + 6bit=10 001011=0X8B
	%		UTF8 of '王'=0XE78E8B
	%convert to GB2312 or GBK ('王'=CDF5)
	Src=double(unicode2native(Src,'gbk'));		%Convert String to GBK.
end
%   the Src is an ascii string.
%%************ END : preprocess **************
%%************START: main **************
%%STEP1: Padding the string to a multiple of 512 bits
%   length of src in bits
LenSrcBits=length(Src)*8;
%   the first fill bit is 1
%   the last fill length(8 bytes,64bits) of src string in bits.
%   total length=length of Src + 1 (fill 1) + 64 (length of Src) before fill 0
%   Each block is 512 bits after filling.
%   Calculate the number of Block.
BlockN=ceil((LenSrcBits+1+64)/512);
%   Calculate the number of fill zero.
FillZeroN=BlockN*512-(LenSrcBits+1+64);
%   combine src string and Fill 1-bit 1 and 7-bit 0
SrcInfo=[Src,128];	% add binary:1000000 (0X80)
%   Fill in 0 and fill in 8-bit 0 each time
for i=8:8:FillZeroN
    %fill in 8-bit 0 every time
	SrcInfo=[SrcInfo,0];	% add binary:00000000 (0X00)
end
%   Fill 8 bytes for length of Src in bits.
%   (1) convert LenSrcBits to 8 bytes in hex(16 characters)
%   (2) convert a 16 character to 2 rows and 8 column matrix
%   (3) transpose to 8 rows and 2 column matrix
%   (4) convert to 8 character from 0 to 256 with hex2dec.
SrcInfo=[SrcInfo,hex2dec(reshape(dec2hex(LenSrcBits,16),2,8)')'];
%% Output the calculate process if debug.
if debug
    % convert ascii array to hexadecimal string
	tmp=AscArray2HexStr(SrcInfo);
    % display information of step
	disp(['After fill zero(len=',num2str(length(tmp)*4),'bits):']);
    % display hex string
	disp(tmp);
end
%%************START: initial **************
%% initial value of V
Src_V0='7380166F4914B2B9172442D7DA8A0600A96F30BC163138AAE38DEE4DB0FB0E4E';
%% split to 8 variable and convert to decimal
for i=1:8
	V0(i)=hex2dec(Src_V0(8*i-8+[1:8]));
end
%% Output the calculate process if debug.
if debug
    dec2hex(V0)
end
V=V0;
VV=[];      %save the process variable
%%************ END : initial **************
%%************START: Iterative compression **************
for block=1:BlockN
    %Clear the intermediate variables
	Info=[];
    % step a in 5.3.2: calculate B
	for i=1:16
        %combine 4 byte to a 32-bit integer
		W(i)=SrcInfo((block-1)*16*4+4*i-4+[1:4])*[16777216;65536;256;1];
		%save the intermediate variables (8 hex character, 32bit)
		Info=[Info,dec2hex(W(i),8),'	'];
        %256bit( 8 group of 8 hex character) per line
		if mod(i,8)==0
            %add a line
			Info=[Info,char(13)];
		end
	end
    %% Output the calculate process if debug.
	if debug
        %% w0-15
		disp(['W0-W15:',char(13),Info]);
	end
	%% step b in 5.3.2: calculate w17 to w68	
	for j=17:68
        %w(j-3)<<15
		[a10,a16]=bitCircleShift(W(j- 3),15);
        %w(j-13)<<7
		[b10,b16]=bitCircleShift(W(j-13), 7);
        %w(j-16) ^ w(j-9)
		tmp1=bitxor(W(j-16),W(j-9));
        %w(j-16) ^ w(j-9) ^ (w(j-3)<<15)
		tmp2=bitxor(tmp1,a10);
        %P1( w(j-16)^w(j-9)^(w(j-3)<<15)  )
		[c10,c16]=P1(tmp2);
        %P1(w(j-16)^w(j-9)^(w(j-3)<<15)) ^ (w(j-13)<<7)
		tmp3=bitxor(c10,b10);
        %P1(w(j-16)^w(j-9)^(w(j-3)<<15))^(w(j-13)<<7)  ^  w(j-6)
		tmp4=bitxor(tmp3,W(j-6));
		%[num2str(j),'	',dec2hex(tmp1,8),'	',dec2hex(tmp2,8),...
        %'	P1=',dec2hex(c10,8),'	',dec2hex(tmp3,8),'	W=',dec2hex(tmp4,8)];
        %W(j)=P1(w(j-16)^w(j-9)^(w(j-3)<<15))^(w(j-13)<<7)^w(j-6)
		W(j)=tmp4;
		%save the intermediate variables (8 hex character, 32bit)
		Info=[Info,dec2hex(W(j),8),'	'];
        %256bit( 8 group of 8 hex character) per line
		if mod(j,8)==0
            %add a line
			Info=[Info,char(13)];
		end
	end
    %% Output the calculate process if debug.
	if debug
        %% w1-68
		disp(['W0-W67:',char(13),Info]);
	end
	%% step c in 5.3.2: calculate W', remark w1
	Info=[];
	for j=1:64
        %w'j=w(j)^w(j+4)
		W1(j)=bitxor(W(j),W(j+4));
		%save the intermediate variables (8 hex character, 32bit)
		Info=[Info,dec2hex(W1(j),8),'	'];
        %256bit( 8 group of 8 hex character) per line
		if mod(j,8)==0
            %add a line
			Info=[Info,char([13])];
		end
	end
    %% Output the calculate process if debug.
	if debug
        %% w'1-w'64
		disp(['W''1-W''64:',char(13),Info]);
	end
	%% step initial in 5.3.3: Compress function
    %       ABCDEFGH
	for i=1:8
		eval(['A'+i-1,'=V(',num2str(i),');']);
	end
    %% Output the calculate process if debug.
	if debug
		disp('Get the value of: ABCDEFGH')
		disp(['Block: ',num2str(block)])
	end
	%% step loop in 5.3.3: Compress function
	for j=1:64
        % const variable 
		if j<=16
			Tj=hex2dec('79CC4519');
		else
			Tj=hex2dec('7a879d8A');
		end
        %Calculate SS1
        %   (1) (A<<<12) + E + (Tj<<<((j-1)%32))
        %   (2) get the right 32 bit, and circle left shift 7 bit
		SS1=bitCircleShift( bitand(hex2dec('FFFFFFFF'),...
                                   bitCircleShift(A,12)+E+bitCircleShift(Tj,mod(j-1,32))),7);
        %calculate SS2=SS1^(A<<<12)
		SS2=bitxor(SS1,bitCircleShift(A,12));
		%calculate TT1=FFJ(A,B,C)+D+SS2+W1(j)
		TT1=bitand(hex2dec('FFFFFFFF'),FFj(A,B,C,j)+D+SS2+W1(j));
        %calculate TT2=GGJ(E,F,G)+H+SS1+W(j)
		TT2=bitand(hex2dec('FFFFFFFF'),GGj(E,F,G,j)+H+SS1+W(j));
		%update DCBA
		D=C;
		C=bitCircleShift(B,9);
		B=A;
		A=TT1;
		%update HGFE
		H=G;
		G=bitCircleShift(F,19);
		F=E;
		E=P0(TT2);
		%convert ABCDEFGH to hexadecimal in 8 character with 8 rows
		Info=dec2hex([A,B,C,D,E,F,G,H],8);
        %transpose and add a table(\t) character
		Info=[reshape(Info',8,8);9*ones(1,8)];
        %convert to a row vector with table
		Info=Info(:)';
        %% Output the calculate process if debug.
		if debug
            % with a line number
			disp([num2str(j-1,'%02d'),'	',Info]);	 
		end
	end	
    %% Output the calculate process if debug.
	if debug
		disp('Update the V');
	end
	%clear variable
	Info=[];
	for i=1:8
        % let tmp= A,B,C,D,E,F,G,H
		eval(['tmp=','A'+i-1,';']);
        % update V
		V(i)=bitxor(V(i),tmp);		
		Info=[Info,dec2hex(V(i),8),'	'];
	end
    %% Output the calculate process if debug.
	if debug; 	
		disp(Info);
	end
    %save process variable
	VV=[VV;V(1),V(2),V(3),V(4),V(5),V(6),V(7),V(8)];
end
%%************ END : Iterative compression **************
% return value
SM3Code=replace(Info,'	','');
SM3CodeSpace=Info;
%%===============================End Function: sm3==============================
function [Y10,Y16]=bitCircleShift(X16,n)
%%=================================================================================
%%  FileName            :   sm3.m
%%  Function            :   bitCircleShift
%%  Version             :   V1.0
%%  Author              :   wacs5
%%  email               :   wacs5@126.com
%%  Date                :   20221011(yyyymmdd)
%%  Description         :   Circle left shift operation
%%  Argument            :
%%      Input
%%          X16         :   first argument.  Decimal and hexadecimal is allowed.
%%          n           :   circle left shift bit
%%      Output
%%          Y10         :   decimal of return value
%%          Y16         :   hexadecimal of return value
%%=================================================================================
%% Decimal and hexadecimal is allowed.
%       hexadecimal, convert to decimal
if ~isnumeric(X16);		
    X=hex2dec(X16);		
else; 
    X=X16;	
end
%(32-n) bit 0 and n-bit 1
Mask1=2^n-1;
%(32-n) bit 1 and n-bit 0
Mask2=bitxor(hex2dec('FFFFFFFF'),Mask1);
% step 1: left shift n bit and bitand with Mask2 (delete last n bit,reserve left 32-n bits)
% step 2: right shift 32-n bit and bitand with Mask1 (delete left 32-n bit,reserve right n bits)
% step 3: combine with left 32-n bit in (1) and right n bit in (2)
Y10=bitor(...
		bitand(bitshift(X,n   ),Mask2),...
		bitand(bitshift(X,n-32),Mask1)...
		);
% convert hexadecimal to decimal
Y16=dec2hex(Y10);
%%===============================End Function: bitCircleShift==============================
function [W10,W16]=P0(X16)
%%=================================================================================
%%  FileName            :   sm3.m
%%  Function            :   P0
%%  Version             :   V1.0
%%  Author              :   wacs5
%%  email               :   wacs5@126.com
%%  Date                :   20221011(yyyymmdd)
%%  Description         :   replacement function in sm3
%%  Argument            :
%%      Input
%%          X16         :   first argument.  Decimal and hexadecimal is allowed.
%%      Output
%%          W10         :   decimal of return value
%%          W16         :   hexadecimal of return value
%%=================================================================================
%% Decimal and hexadecimal is allowed.
%       hexadecimal, convert to decimal
if ~isnumeric(X16);		
    X=hex2dec(X16);		
else; 
    X=X16;	
end
W10=bitxor( bitxor(X,bitor( bitand(bitshift(X, 9   ),hex2dec('FFFFFE00')),...
                            bitand(bitshift(X, 9-32),hex2dec('000001FF')) )),...
                     bitor( bitand(bitshift(X,17   ),hex2dec('FFFE0000')),...
                            bitand(bitshift(X,17-32),hex2dec('0001FFFF')) ));
% convert hexadecimal to decimal
W16=dec2hex(W10);
%%===============================End Function: P0==============================
function [W10,W16]=P1(X16)
%%=================================================================================
%%  FileName            :   sm3.m
%%  Function            :   P1
%%  Version             :   V1.0
%%  Author              :   wacs5
%%  email               :   wacs5@126.com
%%  Date                :   20221011(yyyymmdd)
%%  Description         :   replacement function in sm3
%%  Argument            :
%%      Input
%%          X16         :   first argument.  Decimal and hexadecimal is allowed.
%%      Output
%%          W10         :   decimal of return value
%%          W16         :   hexadecimal of return value
%%=================================================================================
%% Decimal and hexadecimal is allowed.
%       hexadecimal, convert to decimal
if ~isnumeric(X16);		
    X=hex2dec(X16);		
else; 
    X=X16;	
end
W10=bitxor(bitxor(X,bitor(  bitand(bitshift(X,15   ),hex2dec('FFFF8000')),...
                            bitand(bitshift(X,15-32),hex2dec('00007FFF')) )),...
					bitor(  bitand(bitshift(X,23   ),hex2dec('FF800000')),...
                            bitand(bitshift(X,23-32),hex2dec('007FFFFF')) ));
% convert hexadecimal to decimal
W16=dec2hex(W10);
%%===============================End Function: P1==============================
function [W10,W16]=FFj(X16,Y16,Z16,j)
%%=================================================================================
%%  FileName            :   sm3.m
%%  Function            :   FFj
%%  Version             :   V1.0
%%  Author              :   wacs5
%%  email               :   wacs5@126.com
%%  Date                :   20221011(yyyymmdd)
%%  Description         :   Boolean functions FFJ in SM3
%%  Argument            :
%%      Input
%%          X16         :   first argument.  Decimal and hexadecimal is allowed.
%%          Y16         :   second argument  Decimal and hexadecimal is allowed.
%%          Z16         :   third argument   Decimal and hexadecimal is allowed.
%%          j           :   index order
%%      Output
%%          W10         :   decimal of return value
%%          W16         :   hexadecimal of return value
%%=================================================================================
%%************START: argument check **************
% j from 1 to 64
if j<1 || j>64
	error('Parameter error: 1<=j<=64')
end
%%************ END : argument check **************
%% Decimal and hexadecimal is allowed.
%       hexadecimal, convert to decimal
if ~isnumeric(X16);		
    X=hex2dec(X16);		
else; 
    X=X16;	
end
%       hexadecimal, convert to decimal
if ~isnumeric(Y16);		
    Y=hex2dec(Y16);		
else; 
    Y=Y16;	
end
%       hexadecimal, convert to decimal
if ~isnumeric(Z16);		
    Z=hex2dec(Z16);		
else; 
    Z=Z16;	
end
%% j from 1 to 16
if j>=1 && j<=16
    %W= X ^ Y ^ Z
    %   (1) X ^ Y     = bitxor(X,Y)
    %   (2) X ^ Y ^ Z = bitxor(bitxor(X,Y),Z)
	W10=bitxor(bitxor(X,Y),Z);
    % convert hexadecimal to decimal
	W16=dec2hex(W10);
else
    %W= ( X & Y ) | ( X & Z ) | ( Y & Z )
    %   (1) ( X & Y )  = bitand(X,Y)
    %   (2) ( X & Z )  = bitand(X,Z)
    %   (3) ( X & Y ) | ( X & Z )  = bitor(bitand(X,Y),bitand(X,Z))
    %   (4) (X&Y)|(X&Z)|(Y&Z)=bitor(bitor(bitand(X,Y),bitand(X,Z)),bitand(Y,Z))
	W10=bitor(bitor(bitand(X,Y),bitand(X,Z)),bitand(Y,Z));
    % convert hexadecimal to decimal
	W16=dec2hex(W10);
end
%%===============================End Function: FFj==============================
function [W10,W16]=GGj(X16,Y16,Z16,j)
%%=================================================================================
%%  FileName            :   sm3.m
%%  Function            :   GGj
%%  Version             :   V1.0
%%  Author              :   wacs5
%%  email               :   wacs5@126.com
%%  Date                :   20221011(yyyymmdd)
%%  Description         :   Boolean functions GGJ in SM3
%%  Argument            :
%%      Input
%%          X16         :   first argument.  Decimal and hexadecimal is allowed.
%%          Y16         :   second argument  Decimal and hexadecimal is allowed.
%%          Z16         :   third argument   Decimal and hexadecimal is allowed.
%%          j           :   index order
%%      Output
%%          W10         :   decimal of return value
%%          W16         :   hexadecimal of return value
%%=================================================================================
%%************START: argument check **************
% j from 1 to 64
if j<1 || j>64
	error('Parameter error: 1<=j<=64')
end
%%************ END : argument check **************
%% Decimal and hexadecimal is allowed.
%       hexadecimal, convert to decimal
if ~isnumeric(X16);		
    X=hex2dec(X16);		
else; 
    X=X16;	
end
%       hexadecimal, convert to decimal
if ~isnumeric(Y16);		
    Y=hex2dec(Y16);		
else; 
    Y=Y16;	
end
%       hexadecimal, convert to decimal
if ~isnumeric(Z16);		
    Z=hex2dec(Z16);
else; 
    Z=Z16;	
end
%% j from 1 to 16
if j>=1 && j<=16
    %W= X ^ Y ^ Z
    %   (1) X ^ Y     = bitxor(X,Y)
    %   (2) X ^ Y ^ Z = bitxor(bitxor(X,Y),Z)
	W10=bitxor(bitxor(X,Y),Z);
    % convert hexadecimal to decimal
	W16=dec2hex(W10);
else
    %W= ( X & Y ) | ( !X & Z )
    %   (1) ( X & Y )  = bitand(X,Y)
    %   (2) !X=bitxor(X,hex2dec('FFFFFFFF'))
    %           because of 0^1=1 and 1^1=0. reverse(X)=xor(X,0XFFFFFFFF)
    %   (3) ( !X & Z ) = bitand(bitxor(X,hex2dec('FFFFFFFF')),Z)
    %   (4) (X&Y)|(!X&Z)=bitor(bitand(X,Y),bitand(bitxor(X,hex2dec('FFFFFFFF')),Z))
	W10=bitor(bitand(X,Y),bitand(bitxor(X,hex2dec('FFFFFFFF')),Z));
    % convert hexadecimal to decimal
	W16=dec2hex(W10);
end
%%===============================End Function: GGj==============================
function HexStr=AscArray2HexStr(AsciiArray)
%%=================================================================================
%%  FileName            :   sm3.m
%%  Function            :   AscArray2HexStr
%%  Version             :   V1.0
%%  Author              :   wacs5
%%  email               :   wacs5@126.com
%%  Date                :   20221011(yyyymmdd)
%%  Description         :   convert the array of ascii to hexadecimal 
%%  Argument            :
%%      Input
%%          AsciiArray  :   Input array with ascii or GBK
%%      Output
%%          HexStr      :   Output string of hexadecimal
%%  Example             :   
%%      HexStr=AscArray2HexStr('abc')   % return the hexadecmial of 'abc'='616263'
%%      HexStr=AscArray2HexStr('中国')  % return the hexadecmial of '中国'='4E2D56FD'
%%=================================================================================
% convert AsciiArray to hexadecmial, the return is a multi-row matrix
% one line represents one character. Transpose to 2 row and multi-column matrix.
tmp=dec2hex(AsciiArray)';
% combine to a column vector and transpose to a row vector.
HexStr=tmp(:)';
%%===============================End Function: AscArray2HexStr==============================