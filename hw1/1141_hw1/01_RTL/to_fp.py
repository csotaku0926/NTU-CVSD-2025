def to_fixed_point(num: float, n_frac=12):
    fp_result = ""

    for i in range(n_frac):
        num *= 2.0
        if (num >= 1.0):
            fp_result += "1"
            num -= 1.0
        else:
            fp_result += "0"

    return fp_result

def to_dec(num_str="1111111110001000", n_dec=6, n_frac=10):
    num = 0
    for i in range(n_dec-1):
        if (num_str[1+i] == "1"):
            num += 1 >> (n_dec-i)


if __name__ == '__main__':
    n1 = 1.0/6.0
    n2 = 1.0/2.0/4.0/15.0
    print(f"{n1} --> {to_fixed_point(n1)}")
    print(f"{n2} --> {to_fixed_point(n2)}")