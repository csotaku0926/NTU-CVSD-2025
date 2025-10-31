def main():
    fn = "./img1_030101_00.dat"
    wfn = "./img1_030101_00_reverse.dat"

    pixels = []
    N = 4096
    with open(fn) as f:
        for i in range(N):
            ln = f.readline()
            num = int(ln[:-1], 16)
            pixels.append(ln)
        
    R = 64
    C = 64
    with open (wfn, "w") as wf:
        for r in range(R):
            for c in range(C): 
                wf.write(pixels[64*(63-r) + c])

if __name__ == '__main__':
    main()