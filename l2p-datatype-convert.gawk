#
# gawk-script to convert hex strings to their
# decimal equivalents depending on the given datatype
# using ieee 754 standard.
# requires gawk to be installed (awk is not enough because
# of binary operations)
#
# example of usage:
# > echo "BE S8 81" | gawk -f l2p-datatype-convert.gawk
# gives a -1 as result (BE=Big Endian, S8=Signed 8 bit).
#
#
# (c) 2012, Ondics GmbH | githubler@ondics.de | www.ondics.de
#
# This program is licensed under GPL Version 3 license.
# As free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#




# input format: "<e> <dt> <hex>"
# <e>   ... endianess: BE..big endian, LE..little endian
# <dt>  ... datatype: U8,U16,U32, S8,S16,S32,FLOAT
#                     DOUBLE is not emplemented yet
# <hex> ... hexstring (with or without trailing spaces)
# example: "BE U16 12 AB" => converts to 4779



# convert 4 byte string to decimal value
# this function borrows from http://awk.freeshell.org/ConvertHexToFloatingPoint
function IEEE754_HexToFloat(b3,b2,b1,b0) {
	fval = 0
	bias=127
	# convert the character bytes into numbers
	i3=strtonum("0x" b3)
	i2=strtonum("0x" b2)
	i1=strtonum("0x" b1)
	i0=strtonum("0x" b0)
	# first, we need to separate all the parts of the floating point
	# upper most bit is the sign
	sign=and(i3, 0x80)
	# bits 23-30 (next 8) are the exponent
	exponent=and(i3,0x7F)
	tmp=and(i2,0x80)
	tmp=rshift(tmp, 7)
	exponent=lshift(exponent, 1)			
	exponent=or(exponent,tmp)	
	# bits 0-22 are the fraction
	fraction=and(i2,0x7F)
	fraction=lshift(fraction,8)
	fraction=or(fraction,i1)
	fraction=lshift(fraction,8)
	fraction=or(fraction,i0)
	#convert the fraction part into a decimal. need to look at the 
	# individual bits and compute the base 10 value
	decfrac=0
	for(i=22;i>=0;i--) {			
		if( and( fraction , lshift(0x01,i) ))
			decfrac = decfrac+2^(i-23)
	}
	fval=(1+decfrac) * 2^(exponent-bias)
	if(sign) fval=fval*-1
	return fval 
}

# convert hex string to decimal value (big endian)
function Hex2Dec(hexval) {
	val=0
	for (i=1; i<=length(hexval); i++) {
		digit = strtonum("0x0" substr(hexval,i,1));
		val=val*16+digit;
	}
	return val 
}

# convert hex string to decimal value with highest bit as sign (big endian)
function Signed2Dec(hexval) {
	sign=and(strtonum("0x" substr(hexval,1,2)), 0x80);
	valhi=sprintf("%02x",and(strtonum("0x" substr(hexval,1,2)), 0x7f));
	val=Hex2Dec(valhi (length(hexval)>2?substr(hexval,3):"") );
	return (sign>0?-1:1)*val;
}

# reverse string (bytewise), e.g. "123456"->"563412"
function reverse(s) {
	p = ""
	for(i=length(s)-1; i > 0; i-=2) { p = p substr(s, i, 2) }
    return p
}

# kill spaces in e.g. "12 34 56"->"123456"
# prepend "0" if uneven length
function x(s) {
	gsub(/[ ]+/,"",s);
	if (length(s)%2==1) s="0" s;
	return s
}


# big or little endians for one byters are the same
/^(BE|LE) U8/	{ printf("%d",    Hex2Dec(x(substr($0,7)))); ok=1 }
/^(BE|LE) S8/	{ printf("%d", Signed2Dec(x(substr($0,7)))); ok=1 }

# big endians 
/^BE U16/		{ printf("%d",    Hex2Dec(x(substr($0,8)))); ok=1 }
/^BE S16/		{ printf("%d", Signed2Dec(x(substr($0,8)))); ok=1 }
/^BE U32/		{ printf("%d",    Hex2Dec(x(substr($0,8)))); ok=1 }
/^BE S32/		{ printf("%d", Signed2Dec(x(substr($0,8)))); ok=1 }
/^BE FLOAT/ && NF==6 { printf("%f", IEEE754_HexToFloat($3,$4,$5,$6)); ok=1 }
/^BE FLOAT/ && NF==3 { printf("%f", IEEE754_HexToFloat(substr($3,1,2),substr($3,3,2),
                                                       substr($3,5,2),substr($3,7,2))); ok=1 }

# little endians 
/^LE U16/	{ printf("%d",    Hex2Dec(reverse(x(substr($0,8))))); ok=1 }
/^LE S16/	{ printf("%d", Signed2Dec(reverse(x(substr($0,8))))); ok=1 }
/^LE U32/	{ printf("%d",    Hex2Dec(reverse(x(substr($0,8))))); ok=1 }
/^LE S32/	{ printf("%d", Signed2Dec(reverse(x(substr($0,8))))); ok=1 }
/^LE FLOAT/ && NF==6 { printf("%f", IEEE754_HexToFloat($6,$5,$4,$3)); ok=1 }
/^LE FLOAT/ && NF==3 { printf("%f", IEEE754_HexToFloat(substr($3,7,2),substr($3,5,2),
                                                       substr($3,3,2),substr($3,1,2))); ok=1 }

END { if (!ok) printf "error.\n" }
