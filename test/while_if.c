int main() {
    int a = 0;
    int b = 1;
    while (a / 3 < 20) {
        int b = 1;
        while (b < 10)
            if (a>2)
                b = b*3;
            else if (a<2)
                b = b*2;
        a = a + b;
    }
    return a;
}
