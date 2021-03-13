function math.lowerRandom(min, max, p)
    p = p or 3
    return min + (max - min) * math.pow(math.random(), p)
end
