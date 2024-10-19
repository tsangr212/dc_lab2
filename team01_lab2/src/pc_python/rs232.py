#!/usr/bin/env python
from serial import Serial, EIGHTBITS, PARITY_NONE, STOPBITS_ONE
from sys import argv


assert len(argv) == 2
s = Serial(
    port=argv[1],
    baudrate=115200,
    bytesize=EIGHTBITS,
    parity=PARITY_NONE,
    stopbits=STOPBITS_ONE,
    xonxoff=False,
    rtscts=False
)
def decode(s, infile, outfile):
    fp_key = open('key.bin', 'rb')
    fp_enc = open('./golden/' + infile + '.bin', 'rb')
    #fp_enc = open('./enc.bin', 'rb')
    fp_dec = open(outfile + '.bin', 'wb')
    assert fp_key and fp_enc and fp_dec

    stop = "@"
    stopline = stop*32

    key = fp_key.read(64)
    enc = fp_enc.read()
    enc = enc + stopline
    print(len(enc))
    assert len(enc) % 32 == 0


    s.write(key)
    for i in range(0, len(enc), 32):
        s.write(enc[i:i+32])
        
        if (i != len(enc)-32):       # skip final ending protocol
            dec = s.read(31)
            fp_dec.write(dec)
        #print(type(enc[i:i+32]))

    #print(len(dec))
    fp_key.close()
    fp_enc.close()
    fp_dec.close()

# decode(Serial, "input file name in ./golden", "output file name in ./" )
decode(s,'enc1','dec1')
decode(s,'enc2','dec2')
decode(s,'enc3','dec3')
decode(s,'cipher_20230330','hidden_dec')