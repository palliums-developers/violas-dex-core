def swap_input(input_amount, input_reserve, output_reserve):
    input_amount_with_fee = input_amount * 997
    numerator = input_amount_with_fee * output_reserve
    denominator = input_reserve * 1000 + input_amount_with_fee
    return numerator // denominator

def swap_output(output_amount, input_reserve, output_reserve):
    numerator = input_reserve * output_amount * 1000
    denominator = (output_reserve - output_amount) * 997
    return numerator // denominator + 1


if __name__ == "__main__":
    result = swap_output(28436782158339, 5*10000000000000, 20*10000000000000)
    print(result)
    result = swap_output(result, 10*10000000000000, 5*10000000000000)
    print(result)
