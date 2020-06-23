


reserves = [{"ida": 0, "amoaunta": 5*10**18, "idb": 1, "amoauntb": 10*10**18}, {"ida": 1, "amoaunta": 10*10**18, "idb": 6, "amoauntb": 20*10**18}]


def getCurrencys():
    return ['Coin1', 'Coin2', 'VLSUSD', 'VLSEUR', 'VLSGBP', 'VLSJPY', 'VLSSGD']

def getReserves(CoinA, CoinB):
    (id1, id2) = (CoinA, CoinB)
    sw_flag = False
    if id1 > id2:
        (id1, id2) =  (id2, id1)
        sw_flag = True
    for r in reserves:
        if r['ida'] == id1 and r['idb'] ==id2:
            if sw_flag:
                return (r['amoauntb'], r['amoaunta'])
            else:
                return (r['amoaunta'], r['amoauntb'])
    return (0, 0)

def quote(amountA, reserveA, reserveB):
    assert amountA > 0 and reserveA > 0 and reserveB > 0
    amountB = amountA * reserveB // reserveA
    return amountB

def getAmountOut(amountIn, reserveIn, reserveOut):
    assert amountIn > 0 and reserveIn > 0 and reserveOut
    amountInWithFee = amountIn * 997;
    numerator = amountInWithFee * reserveOut;
    denominator = reserveIn * 1000 + amountInWithFee;
    amountOut = numerator // denominator;
    return amountOut

def getAmountIn(amountOut, reserveIn, reserveOut):
    assert amountOut > 0 and reserveIn > 0 and reserveOut
    numerator = reserveIn * amountOut * 1000;
    denominator = (reserveOut - amountOut) * 997;
    amountIn = numerator // denominator + 1;
    return amountIn

def getAmountsOut(amountIn, path):
    assert amountIn > 0 and len(path) >= 2
    amounts = []
    amounts.append(amountIn)
    for i in range(len(path)):
        (reserveIn, reserveOut) = getReserves(path[i], path[i] + 1)
        assert reserveIn > 0 and reserveOut > 0
        amountOut = getAmountOut(amounts[i], reserveIn, reserveOut)
        amounts.append(amountOut)
    return amounts

def getAmountsIn(amountOut, path):
    assert amountOut > 0 and len(path) >= 2
    amounts = []
    amounts.append(amountOut)
    for i in range(len(path)-1, 0, -1):
        (reserveIn, reserveOut) = getReserves(path[i - 1], path[i])
        assert reserveIn > 0 and reserveOut > 0
        amountIn = getAmountIn(amounts[i], reserveIn, reserveOut)
        amounts.insert(0, amountIn)
    return amounts


if __name__ == "__main__":
    print(getAmountOut(10 ** 13, 83375020843756, 60000000000000))